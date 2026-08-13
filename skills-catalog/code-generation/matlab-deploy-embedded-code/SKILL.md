---
name: matlab-deploy-embedded-code
description: >
  Deploy MATLAB-generated code to embedded hardware using Embedded Coder. Use when
  configuring code generation for microcontrollers (STM32, Raspberry Pi, ARM Cortex),
  setting up PIL/SIL verification, disabling dynamic memory allocation, or configuring
  hardware-specific code generation settings. Covers ERT-based configurations,
  processor-in-the-loop testing, memory constraints, and the MEX→SIL→PIL verification
  progression.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.2"
---

# Deploy Embedded Code

Configure MATLAB Coder with Embedded Coder for production-quality code generation
targeting embedded hardware, and verify correctness with processor-in-the-loop (PIL)
testing.

## When to Use

- Generating C/C++ code for a microcontroller or embedded Linux board
- Setting up PIL or SIL verification for generated code
- Configuring code generation with no dynamic memory allocation
- Configuring Embedded Coder for an AI model entry-point function prepared by `matlab-deploy-embedded-ai`; for the full AI compression and model-loading workflow, trigger `matlab-deploy-embedded-ai` first
- Selecting a hardware target board (STM32, Raspberry Pi)

## When NOT to Use

- Generating MEX or desktop libraries — use standard `codegen` workflows
- Simulink-based deployment — use Simulink Coder / Embedded Coder workflows directly
- GPU code generation (CUDA) — use GPU Coder

## Workflow

### 1. Create an ERT-Based Configuration

```matlab
cfg = coder.config("lib", "ecoder", true);
```

The `"ecoder", true` flag creates an ERT-based (Embedded Real-Time) configuration
that generates production-quality code with no OS dependencies.

### 2. Select Target Hardware

With `coder.hardware`:

```matlab
cfg.Hardware = coder.hardware("STM32F746G-Discovery");
```

Without the support package, configure hardware manually:

```matlab
cfg.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM Cortex-M';
cfg.HardwareImplementation.ProdBitPerFloat = 32;
cfg.HardwareImplementation.ProdBitPerDouble = 64;
```

See `references/supported-hardware.md` for the full list of supported boards and
their constraints.

### 3. Configure Memory for Bare-Metal Targets

```matlab
cfg.EnableDynamicMemoryAllocation = false;
cfg.StackUsageMax = 512;
```

- `EnableDynamicMemoryAllocation = false` — disables `malloc`/`free` for targets
  where heap is unavailable or non-deterministic. All arrays must be bounded at
  compile time.
- `StackUsageMax` — set based on target SRAM. The code generation report shows
  actual usage after compilation.

For entry-points that use deep learning inference (`invoke`, `predict`):

```matlab
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');
cfg.LargeConstantGeneration = "KeepInSourceFiles";
```

- `DeepLearningConfig('none')` — generates C with no external DL library dependencies
  (MKL-DNN, cuDNN, TensorRT). Required for bare-metal targets. Without this, codegen
  may attempt to link an unavailable library and fail.
- `LargeConstantGeneration = "KeepInSourceFiles"` — keeps weight constants in source
  files rather than separate data files. Needed for bare-metal targets where external
  data file linking is unsupported.

### 4. Configure Performance (SIMD and OpenMP)

**SIMD vectorization for embedded ARM targets:**

```matlab
cfg.InstructionSetExtensions = 'Neon v7';  % ARM Cortex-A (128-bit, 4x float32)
```

| Target | Value | Notes |
|--------|-------|-------|
| ARM Cortex-A (Raspberry Pi) | `'Neon v7'` | 128-bit SIMD |
| ARM Cortex-M | Do not set — use `CodeReplacementLibrary` instead | Different mechanism |

For non-embedded targets (Intel x86-64 and the full `InstructionSetExtensions`
ladder), `OptimizeReductions`, and OpenMP, see the `matlab-generate-code` skill.
For the MATLAB Coder ↔ Simulink Coder property naming duality, see
`references/simulink-config.md`.

**Code replacement library (CRL)** — routes supported ops to vendor-optimized
math library implementations.

**On Cortex-A: set BOTH `InstructionSetExtensions` AND a non-SIMD `CodeReplacementLibrary`.**
They target different layers. ISE emits NEON SIMD intrinsics inline for
vectorizable loops in generated code. A non-SIMD CRL routes higher-level math
ops — trig, filtering, matrix — to library implementations you don't have to
generate. `ARM Cortex-A CMSIS` maps to the ARM CMSIS-DSP library (hand-tuned
Cortex-A kernels shipped by ARM); it does not itself emit NEON, so it composes
with an explicit `InstructionSetExtensions = 'Neon v7'`. Setting only one of
ISE or CRL leaves performance on the table:

```matlab
cfg.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM Cortex-A';
cfg.InstructionSetExtensions = 'Neon v7';           % SIMD intrinsics (also shown in §4 above)
cfg.CodeReplacementLibrary   = 'ARM Cortex-A CMSIS'; % non-SIMD CRL — routes math ops to CMSIS-DSP
```

For Cortex-M, select the CRL matching your compiler (e.g. `'ARM Cortex-M'` for
generic; vendor-specific CRLs are shipped with the corresponding support
package). Cortex-M does not use `InstructionSetExtensions`.

**OpenMP** — enable on multi-core targets (Cortex-A); disable on single-core
(Cortex-M — no OS/threading support, will fail to compile):

```matlab
cfg.EnableOpenMP = true;   % multi-core targets (Cortex-A)
cfg.EnableOpenMP = false;  % single-core targets (Cortex-M)
```

### 5. Set Up PIL Verification

PIL compiles the generated code, deploys it to the physical board, sends test
vectors, and compares outputs against MATLAB. This catches precision differences,
stack overflows, and memory issues that SIL cannot detect.

**Cortex-M (serial transport):**

```matlab
cfg.VerificationMode = "PIL";
cfg.Hardware.PILInterface = "Serial";
cfg.Hardware.PILCOMPort = "COM4";  % adjust to your system
```

**Cortex-A / Raspberry Pi (SSH transport):**

```matlab
cfg.VerificationMode = "PIL";
cfg.Hardware = coder.hardware("Raspberry Pi");
cfg.Hardware.DeviceAddress = "192.168.1.10";
cfg.Hardware.Username = "<your-pi-username>";
cfg.Hardware.Password = "<your-pi-password>";
cfg.Hardware.BuildDir = "/home/pi/mymodel";  % optional: defaults to /home/pi/MATLAB_ws/<release>
```

Pi PIL runs over SSH (not serial). The support package uses `DeviceAddress`,
`Username`, and `Password` to establish the SSH connection. `BuildDir` specifies
where the compiled binary is deployed on the target; if omitted, defaults to
`/home/pi/MATLAB_ws/<release>/`. Do not set `PILInterface` or `PILCOMPort` — those
are for serial-connected bare-metal boards only.

### 6. Generate Code

```matlab
cfg.TargetLang = "C";
codegen -config cfg -args {inputArgs} myEntryPoint
```

### 7. Verify with the MEX → SIL → PIL Progression

For confidence in deployment, follow this sequence:

1. **MEX** — verify on host, fast iteration
2. **SIL** (Software-in-the-Loop) — run generated code on host, compare to MATLAB
3. **PIL** (Processor-in-the-Loop) — run on actual hardware, compare to MATLAB

```matlab
cfgSil = coder.config("lib", "ecoder", true);
cfgSil.VerificationMode = "SIL";
codegen -config cfgSil -args {inputArgs} myEntryPoint
```

## Key Properties

| Property | Values | Purpose |
|----------|--------|---------|
| `VerificationMode` | `"PIL"`, `"SIL"`, `"None"` | Enable in-the-loop verification |
| `Hardware` | `coder.hardware(boardName)` | Select target board |
| `Hardware.PILInterface` | `"Serial"` | PIL communication type |
| `Hardware.PILCOMPort` | `"COM4"`, `"/dev/ttyACM0"` | Serial port |
| `EnableDynamicMemoryAllocation` | `true` (default), `false` | Master switch for heap |
| `DynamicMemoryAllocationThreshold` | numeric (bytes), default 65536 | Arrays above this use heap |
| `LargeConstantGeneration` | `"KeepInSourceFiles"`, `"WriteOnlyDNNConstantsToDataFiles"` | Where to put large constants |
| `StackUsageMax` | numeric (bytes) | Stack limit for generated code (Simulink: `MaxStackSize`) |
| `EnableOpenMP` | boolean | OpenMP multi-threading (Simulink: `MultiThreadedLoops`) |
| `CodeReplacementLibrary` | `"ARM Cortex-A CMSIS"`, `"GCC ARM Cortex-A"` (SIMD), `"ARM Cortex-M"`, … | Vendor-optimized op replacements. `GCC ARM Cortex-A` is a SIMD CRL — do not pair with an explicit ISE. MATLAB warns it is not recommended; use `"ARM Cortex-A CMSIS"` instead |
| `TargetLang` | `"C"`, `"C++"` | Output language |

> **Simulink Coder path (`slbuild`):** properties in the "Simulink:" column above are
> set via `set_param(modelName, 'PropertyName', value)` directly on the model name.
> See `references/simulink-config.md` for the full Simulink Coder property mapping and code examples.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `DynamicMemoryAllocation = "Off"` | Wrong property name and type | `EnableDynamicMemoryAllocation = false` (boolean) |
| Skipping SIL before PIL | PIL failures on hardware are harder to debug | Always validate with SIL first |
| Not setting `StackUsageMax` | Default may exceed target SRAM | Set explicitly based on hardware constraints |
| Using `cfg = coder.config("lib")` without `"ecoder", true` | Creates a generic config, not ERT-based | Always pass `"ecoder", true` for embedded targets |

## Conventions

- Always: use `coder.config("lib", "ecoder", true)` for embedded targets
- Always: disable dynamic memory for bare-metal Cortex-M targets
- Always: follow MEX → SIL → PIL verification order
- Never: use `DynamicMemoryAllocation` (wrong property name — it's `EnableDynamicMemoryAllocation`)
- Prefer: `TargetLang = "C"` for Cortex-M targets (smaller code footprint)

## References

- `references/supported-hardware.md` — board specs, support packages, and PIL interface details
- `references/simulink-config.md` — Simulink Coder property naming, `set_param` patterns, and `slbuild` code examples

## See Also

- `matlab-generate-code` — generic codegen foundation: coder directives, screener, MEX generation, SIL, config tuning, SIMD/OpenMP for non-embedded targets
- `matlab-deploy-ai-model` — full AI model codegen pipeline (load, verify, generate MEX/lib)

----

Copyright 2026 The MathWorks, Inc.

----
