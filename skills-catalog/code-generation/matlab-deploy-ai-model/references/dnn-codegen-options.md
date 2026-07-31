# DNN-Specific Codegen Options

Options that only apply to deep-learning inference codegen. For generic
codegen tuning (SIMD instruction sets, OpenMP multi-threading, MEX SIMD,
`OptimizeReductions`, the MATLAB Coder ↔ Simulink Coder naming duality),
see `codegen-performance-options.md`.

**When to read this file:** you're generating code from a `.pt2` or
`.tflite` model and want to (a) route around third-party DL libraries,
(b) serialize weights to data files, or (c) understand DNN-inference
specifics of `SIMDAcceleration` on MEX.

## 1. Deep learning target library — different name per API

To use the plain-C codegen path (no third-party DL library backends like
cuDNN, MKL-DNN), disable the DL library backend:

```matlab
% MATLAB Coder
cfg.DeepLearningConfig = coder.DeepLearningConfig("none");

% Simulink Coder — set BOTH. SimDLTargetLibrary controls simulation
% (normal-mode / sim()); DLTargetLibrary controls slbuild-time code
% generation. They are independent parameters — setting one does NOT set
% the other, so setting only DLTargetLibrary leaves simulation still
% routing inference through the DL library.
set_param(modelName, "SimDLTargetLibrary", "none");   % simulation
set_param(modelName, "DLTargetLibrary",    "none");   % code generation
```

Setting a target library routes inference through the library at runtime
and bypasses `InstructionSetExtensions`, OpenMP, and
`LargeConstantGeneration` — those parameters only affect generated source
code, not library calls. For plain-C DNN inference on host CPU or embedded
targets, `"none"` is the correct choice; the perf knobs from
`codegen-performance-options.md` (SIMD, OpenMP, `OptimizeReductions`) then
take effect on the generated inference code.

## 2. Large DNN constants (weights) — `LargeConstantGeneration` (R2024a+)

Model weight constants can either be embedded directly in generated source
(`"KeepInSourceFiles"`) or written to binary data files that the generated
code loads at run time (`"WriteOnlyDNNConstantsToDataFiles"`, for constants
above `LargeConstantThreshold`, default 131072 bytes). Embedding blows up
compile time and binary size for larger models but has no filesystem
dependency; the data-files path is smaller and faster to compile but
requires the deployment target to have a filesystem.

Since R2024a, defaults vary by codegen path — only `ert.tlc` defaults to
the inline path:

| Path | Default |
|---|---|
| MATLAB Coder `coder.config("lib")` (ecoder or not) | `"WriteOnlyDNNConstantsToDataFiles"` |
| Simulink `grt.tlc` | `"WriteOnlyDNNConstantsToDataFiles"` |
| Simulink `ert.tlc` | `"KeepInSourceFiles"` — must flip to `"WriteOnlyDNNConstantsToDataFiles"` for the data-files path |

Same property name on both APIs. **Requires MATLAB R2024a or later** — the property does not exist in earlier releases.

```matlab
% MATLAB Coder (requires R2024a+)
cfg.LargeConstantGeneration = "WriteOnlyDNNConstantsToDataFiles";
% cfg.LargeConstantThreshold = 131072;   % optional (bytes)

% Simulink Coder (requires R2024a+)
set_param(modelName, "MATLABDynamicMemAlloc", "on");
set_param(modelName, "LargeConstantGeneration", "WriteOnlyDNNConstantsToDataFiles");
```

The generated loader needs dynamic memory allocation at runtime. Defaults
vary by codegen path:

| Path | Property | Default |
|---|---|---|
| MATLAB Coder `coder.config("lib")` (ecoder or not) | `EnableDynamicMemoryAllocation` (boolean) | `true` |
| Simulink `grt.tlc` | `MATLABDynamicMemAlloc` (`"on"`/`"off"`) | `"on"` |
| Simulink `ert.tlc` | `MATLABDynamicMemAlloc` (`"on"`/`"off"`) | `"off"` — must flip to `"on"` |

`ert.tlc` (Embedded Coder) is the one where the flip is genuinely required —
a fresh model that switches to `ert.tlc` gets `MATLABDynamicMemAlloc = "off"`.
On the MATLAB Coder side use `cfg.EnableDynamicMemoryAllocation`, NOT
`cfg.MATLABDynamicMemAlloc` (that's the Simulink `set_param` name and throws
an unrecognized-property error on `coder.EmbeddedCodeConfig`).

Notes:
- Applies only to code that does NOT depend on third-party deep learning
  libraries (the `loadPyTorchExportedProgram` / `loadLiteRTModel` codegen path
  qualifies).
- Non-DNN constants are always inlined in source, regardless of size.
- The binary data files land in the code generation folder. If you relocate
  them at deploy time, set the `CODER_DATA_PATH` environment variable to the
  new location before running the generated code.
- The deployment target must have a filesystem so the generated code can read
  the data files at runtime — not suitable for bare-metal MCU targets. For
  bare-metal, use `"KeepInSourceFiles"` (already the default on `ert.tlc`;
  must be set explicitly on MATLAB Coder and `grt.tlc`) (see
  `matlab-deploy-embedded-code`).

## 3. MEX SIMD ceiling (DNN-inference context)

Generic `SIMDAcceleration` values are documented in `codegen-performance-options.md`.
The DNN-inference-specific note:

**MEX SIMD is capped at AVX2** via `"Full"` — there is no AVX512 option for
MEX, even on AVX512-capable hosts. For AI model MEX inference where the user
wants maximum SIMD throughput, `"Full"` is the ceiling. If a user needs AVX512
for their DNN inference, ask whether generating a library
(`coder.config("lib")`) instead of a MEX is acceptable — MEX and lib serve
different purposes (host-side iteration vs. deployable artifact), so don't
switch on their behalf.

## DNN-Inference Quick Recipe

Plain-C DNN inference with maximum vectorization + multi-threading (Intel/AMD
host, Embedded Coder available):

**Simulink:**
```matlab
set_param(modelName, "SystemTargetFile", "ert.tlc");
set_param(modelName, "ProdHWDeviceType", "Intel->x86-64 (Windows64)");
% set_param(modelName, "ProdHWDeviceType", "Intel->x86-64 (Linux 64)");  % Linux host
set_param(modelName, "InstructionSetExtensions", "AVX512F");            % see generic ref for SIMD ladder
set_param(modelName, "OptimizeReductions", "on");
set_param(modelName, "MultiThreadedLoops", "on");
set_param(modelName, "DLTargetLibrary", "none");                        % plain-C path
% For large models, serialize weights to data files:
set_param(modelName, "MATLABDynamicMemAlloc", "on");
set_param(modelName, "LargeConstantGeneration", "WriteOnlyDNNConstantsToDataFiles");
```

**MATLAB Coder:**
```matlab
cfg = coder.config("lib", "ecoder", true);
cfg.HardwareImplementation.ProdHWDeviceType = "Intel->x86-64 (Windows64)";
% cfg.HardwareImplementation.ProdHWDeviceType = "Intel->x86-64 (Linux 64)";  % Linux host
cfg.InstructionSetExtensions = "AVX512F";
cfg.OptimizeReductions = "on";
cfg.EnableOpenMP = true;
cfg.DeepLearningConfig = coder.DeepLearningConfig("none");              % plain-C path
% EnableDynamicMemoryAllocation is true by default on ecoder configs.
cfg.LargeConstantGeneration = "WriteOnlyDNNConstantsToDataFiles";
```

For target-hardware-specific config (device selection,
`EnableDynamicMemoryAllocation`, `StackUsageMax`, `CodeReplacementLibrary`
catalog, PIL/SIL, hardware boards, target-connection), see the
`matlab-deploy-embedded-code` skill.

----

Copyright 2026 The MathWorks, Inc.

----
