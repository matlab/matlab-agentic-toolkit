# Simulink Coder Property Mapping for Embedded Targets

This file documents the Simulink Coder (`set_param`) property names for embedded
code generation. The MATLAB Coder equivalents (`cfg.*`) are documented in
`matlab-generate-code`.

## Property Reference

| Property | Value Type / Values | Purpose |
|----------|---------------------|---------|
| `MaxStackSize` | numeric (bytes) | Stack size cap (MATLAB Coder: `StackUsageMax`) |
| `MultiThreadedLoops` | `'on'` / `'off'` | OpenMP multi-threading (MATLAB Coder: `EnableOpenMP`) |
| `DLTargetLibrary` | `'none'`, `'mkl-dnn'`, `'cudnn'`, `'tensorrt'` | DL inference library for code generation (`slbuild`); MATLAB Coder equivalent: `coder.DeepLearningConfig(...)` |
| `SimDLTargetLibrary` | `'none'`, `'mkl-dnn'`, `'cudnn'`, `'tensorrt'` | DL inference library for simulation (`sim()`); must match `DLTargetLibrary` — setting only one leaves simulation and code generation on different library paths |
| `InstructionSetExtensions` | `'AVX2'`, `'Neon v7'`, etc. | SIMD instruction set (same name on both sides) |
| `OptimizeReductions` | `'on'` / `'off'` | Vectorize reduction loops; same name on MATLAB Coder side (`cfg.OptimizeReductions = true`); available on both `grt.tlc` and `ert.tlc` (no Embedded Coder license required); requires `InstructionSetExtensions` ≠ `'None'` |

**Note:** `ProdHWDeviceType` is not listed here — see `supported-hardware.md` for hardware target configuration.

## Both Sides Fail Loud

Using the wrong-side property name raises an error immediately:

- Simulink `set_param(model, 'EnableOpenMP', ...)` throws an **invalid-parameter** error — `EnableOpenMP` is not a valid Simulink model parameter.
- MATLAB Coder `cfg.MultiThreadedLoops = 'on'` throws an **unrecognized-property** error — `MultiThreadedLoops` is not a property of the coder config object.

There is no silent cross-side fallback.

## Example: Simulink Embedded Codegen Configuration

```matlab
set_param(modelName, 'ProdHWDeviceType', 'Intel->x86-64 (Linux 64)');
set_param(modelName, 'InstructionSetExtensions', 'AVX2');
set_param(modelName, 'MultiThreadedLoops', 'on');
set_param(modelName, 'MaxStackSize', 2048);
set_param(modelName, 'DLTargetLibrary', 'none');
slbuild(modelName);
```

## Notes on MultiThreadedLoops

`MultiThreadedLoops` is valid on both `grt.tlc` and `ert.tlc` — it is NOT gated
behind Embedded Coder. Requires an OpenMP-capable compiler. Do NOT enable on
single-core targets (Cortex-M).

## Notes on InstructionSetExtensions

Valid values depend on the system target file and device vendor:

| Target × device | Valid values | Default |
|---|---|---|
| `grt.tlc`, Intel/AMD | `SSE2`, `None` | `SSE2` |
| `ert.tlc`, Intel/AMD | `SSE`, `SSE2`, `SSE4.1`, `AVX`, `AVX2`, `FMA`, `AVX512F`, `None` | `SSE` |
| `ert.tlc`, Apple silicon / ARM Cortex-A | `Neon v7`, `None` | `None` |

Levels are cumulative — selecting `AVX2` also enables `AVX`, `SSE4.1`, `SSE2`, `SSE`.

With `grt.tlc` (Simulink Coder without Embedded Coder), `InstructionSetExtensions`
is capped at `'SSE2'` on x86 and has no effect on ARM — higher levels (`'AVX'`,
`'AVX2'`, `'AVX512F'`, `'Neon v7'`) require `ert.tlc` (Embedded Coder). Use
`set_param(modelName, 'SystemTargetFile', 'ert.tlc')` before setting ISE.

Set `ProdHWDeviceType` before `InstructionSetExtensions` so only valid values
are accepted for the selected device. If the compiler does not emit the
required flags (e.g., a custom toolchain), set `InstructionSetExtensions` to
`'None'` to avoid compilation failures.

## Notes on OptimizeReductions

`OptimizeReductions` vectorizes reduction loops (sum, product, softmax
denominators, etc.). It is available on **both `grt.tlc` and `ert.tlc`** —
Simulink Coder users without an Embedded Coder license CAN use it. It is not
gated behind Embedded Coder.

```matlab
set_param(modelName, 'OptimizeReductions', 'on');   % Simulink Coder
```

----

Copyright 2026 The MathWorks, Inc.

----
