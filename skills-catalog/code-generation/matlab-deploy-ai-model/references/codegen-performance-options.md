# Generic Codegen Performance Options

Generic performance knobs that apply to any MATLAB Coder / Simulink Coder /
Embedded Coder workflow — not specific to AI models. Kept here because
AI-model users routinely reach for them; the same content is useful for any
codegen tuning task.

For DNN-inference-specific options (`DLTargetLibrary` / `DeepLearningConfig`,
`LargeConstantGeneration` for weight serialization, MEX SIMD ceiling in a DNN
context), see `dnn-codegen-options.md`.

**When to read this file:** you're picking SIMD levels, deciding between
MATLAB Coder and Simulink Coder property names, or tuning `OptimizeReductions`
/ OpenMP. If you know exactly which property you want and just need syntax,
the MathWorks Simulink Coder / MATLAB Coder docs are the authoritative
reference; this file distills what most codegen users trip on.

## MATLAB Coder vs Simulink Coder — Same Feature, Different Names

Several performance features are exposed under different property names
depending on the codegen entry point:

| Feature | MATLAB Coder (`coder.config`) | Simulink Coder (`set_param`) |
|---|---|---|
| OpenMP multi-threading | `EnableOpenMP` (boolean) | `MultiThreadedLoops` (`"on"`/`"off"`) |
| Stack size cap | `StackUsageMax` (numeric) | `MaxStackSize` (numeric) |
| Disable third-party DL library | `DeepLearningConfig = coder.DeepLearningConfig("none")` | `DLTargetLibrary = "none"` |
| SIMD instruction sets (lib/exe) | `InstructionSetExtensions` | `InstructionSetExtensions` |
| SIMD (MEX only) | `SIMDAcceleration` (on `coder.MexCodeConfig`) | — |
| Device selection | `HardwareImplementation.ProdHWDeviceType` | `ProdHWDeviceType` |

Match the API to the codegen path. Using the wrong side's property name
raises an error at the point of the call:
- **MATLAB Coder `coder.config`/`coder.MexCodeConfig`**: assigning an
  unrecognized property (e.g., `cfg.MultiThreadedLoops = "on"` on a MEX
  config) throws an unrecognized-property error at assignment time.
- **Simulink `set_param(model, ...)`**: passing an invalid parameter name
  (e.g., `set_param(m, "EnableOpenMP", "on")`) throws an invalid-parameter
  error immediately.

Both sides fail loud; the fix is to switch to the right property name for
the codegen path in use.

For target hardware selection, PIL/SIL configuration, `EnableDynamicMemoryAllocation`,
and the board catalog, see the `matlab-deploy-embedded-code` skill.

## 1. SIMD instruction sets — `InstructionSetExtensions`

Emits SIMD intrinsics (e.g. `_mm_add_ps`, `vmulq_f32`) for supported ops.
Values depend on the system target file and device vendor:

| Target × device | Values | Default |
|---|---|---|
| `grt.tlc`, Intel/AMD | `SSE2`, `None` | `SSE2` |
| `ert.tlc`, Intel/AMD | `SSE`, `SSE2`, `SSE4.1`, `AVX`, `AVX2`, `FMA`, `AVX512F`, `None` | `SSE` |
| `ert.tlc`, Apple silicon / ARM Cortex-A | `Neon v7`, `None` | `None` |

Levels are cumulative — selecting `AVX2` also enables `AVX`, `SSE4.1`, `SSE2`,
`SSE`. Set `ProdHWDeviceType` first so only valid values are accepted.

`grt.tlc` caps `InstructionSetExtensions` at `SSE2` on Intel/AMD and offers
no NEON path — the higher levels and NEON require ert.tlc / Embedded Coder.

### MATLAB Coder (`codegen`)

```matlab
cfg = coder.config("lib");
cfg.HardwareImplementation.ProdHWDeviceType = "Intel->x86-64 (Windows64)";
% cfg.HardwareImplementation.ProdHWDeviceType = "Intel->x86-64 (Linux 64)";  % Linux host
cfg.InstructionSetExtensions = "AVX2";
codegen -config cfg -args {inputArg} entryPoint
```

### Simulink Coder (`slbuild`)

```matlab
set_param(modelName, "ProdHWDeviceType", "Intel->x86-64 (Windows64)");
% set_param(modelName, "ProdHWDeviceType", "Intel->x86-64 (Linux 64)");  % Linux host
set_param(modelName, "InstructionSetExtensions", "AVX2");
```

**Limitation:** custom toolchains that don't emit the required compiler flags
may fail to compile SIMD code — set to `"None"` in that case.

### MEX SIMD — `SIMDAcceleration` (R2023a+)

`InstructionSetExtensions` above is for `coder.config("lib" | "exe" | "dll")`
and `slbuild`. **MEX uses a different property** on `coder.MexCodeConfig`:

| Value | Instruction set |
|---|---|
| `"None"` | No SIMD |
| `"Portable"` (default) | SSE2 |
| `"Full"` | AVX2 |

Intel/AMD only; other platforms get plain C regardless. MATLAB Coder checks
the host CPU and compiler and uses compatible intrinsics up to the level
requested.

`InstructionSetExtensions` is not a property of `coder.MexCodeConfig`;
assigning `cfg.InstructionSetExtensions` on a MEX config throws an error
(unrecognized property). It is only a `coder.config("lib"|"exe"|"dll")` and
`slbuild` property. See `dnn-codegen-options.md` for the DNN-inference-specific
MEX SIMD ceiling note.

```matlab
cfg = coder.config("mex");
cfg.SIMDAcceleration = "Full";   % AVX2
codegen -config cfg -args {inputArg} entryPoint
```

## 2. Reduction-loop SIMD — `OptimizeReductions` (R2022a+)

Vectorizes reduction loops (sum, product, softmax denominators, etc.).
**Available on both `grt.tlc` and `ert.tlc`** — Simulink-Coder-only users
without an Embedded Coder license CAN use `OptimizeReductions` (paired with
the `SSE2` that `grt.tlc` allows). It is not gated behind Embedded Coder.
Requires `InstructionSetExtensions` to be set to something other than
`"None"`. Same property name on both APIs:

```matlab
cfg.OptimizeReductions = "on";                            % MATLAB Coder
set_param(modelName, "OptimizeReductions", "on");         % Simulink Coder
```

## 3. Multi-threading (OpenMP) — different name per API

Parallelizes independent loop iterations across cores via OpenMP. Requires
an OpenMP-capable compiler. `MultiThreadedLoops` is a valid Simulink Coder
parameter on both `grt.tlc` and `ert.tlc` — no ERT / Embedded Coder license
required for `set_param`-side use.

```matlab
cfg.EnableOpenMP = true;                                  % MATLAB Coder (boolean)
set_param(modelName, "MultiThreadedLoops", "on");         % Simulink Coder (char)
```

Do NOT enable on single-core targets (e.g. Cortex-M) — no OS/threading
support, will fail to compile.

----

Copyright 2026 The MathWorks, Inc.

----
