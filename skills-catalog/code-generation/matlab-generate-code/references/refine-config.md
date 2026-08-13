# Refine Codegen Config

Tune `coder.MexCodeConfig`, `coder.CodeConfig`, or `coder.EmbeddedCodeConfig` properties for a specific deployment goal after code generation is already working.

## Workflow

### Step 1: Identify the Goal

Ask the user which goal drives their config tuning:

| Goal | Key constraint |
|------|---------------|
| **Memory-constrained embedded** | No heap allocation, bounded stack, minimal footprint |
| **Maximum speed** | Aggressive inlining, SIMD, parallelization, memcpy |
| **Readable / traceable output** | Preserved names, source comments, minimal inlining |
| **Minimal code size** | No inlining, no unrolling, conditional features disabled |
| **Safety / compliance** | Runtime checks, saturation, MISRA justification |

If the user has multiple goals, identify the primary one and note which tradeoffs are acceptable.

### Step 2: Select Config Type

```matlab
cfg = coder.config('mex');   % MEX targets (acceleration/verification)
cfg = coder.CodeConfig;      % lib/dll/exe — MATLAB Coder only
cfg = coder.config('lib');   % lib/dll/exe — Embedded Coder when installed
```

`coder.config('lib')` returns `coder.EmbeddedCodeConfig` when Embedded Coder is installed, otherwise `coder.CodeConfig`. Confirm with `class(cfg)` after construction.

### Step 3: Inspect the Live Config Object

Property names, defaults, and availability per config type drift across MATLAB releases. Before recommending settings, introspect the user's actual config via `mcp__matlab__evaluate_matlab_code`:

```matlab
cfg = coder.config('lib');     % or 'mex', or coder.CodeConfig
class(cfg)                     % confirm config class
properties(cfg)                % full property list for this version
disp(cfg)                      % current values for every property
isprop(cfg, 'EnableStrengthReduction')   % check a specific property
```

Use this when you are unsure whether a property exists on the current config type, what values it accepts, or what the default is in the user's release. Treat the live introspection — not memory of past releases — as ground truth.

### Step 4: Apply Goal-Specific Properties

The blocks below name the properties most directly fit-for-purpose for each goal. They are starting points, not exhaustive — verify each property exists on the current config type via `isprop(cfg, 'PropName')` before setting.

#### Memory-Constrained Embedded

```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C';
cfg.EnableDynamicMemoryAllocation = false;
cfg.EnableRuntimeRecursion = false;
cfg.EnableMemcpy = false;
cfg.StackUsageMax = 524288;                 % 512 KB; tune to target
cfg.SupportNonFinite = false;
cfg.EnableVariableSizing = true;            % keep on; see interactions
```

Optional on `coder.EmbeddedCodeConfig`: `cfg.PurelyIntegerCode = true` if the entire call graph is integer-only.

For source-code patterns that avoid dynamic memory allocation (preallocation, bounded varsize, no array growth/deletion), see `references/write-performance.md` §DMA-Off.

#### Maximum Speed

```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C++';
cfg.BuildConfiguration = 'Faster Runs';
cfg.InlineBetweenUserFunctions = 'Speed';
cfg.InlineBetweenMathWorksFunctions = 'Speed';
cfg.InlineBetweenUserAndMathWorksFunctions = 'Speed';
cfg.EnableMemcpy = true;
cfg.EnableOpenMP = true;
cfg.EnableAutoParallelization = true;
cfg.OptimizeReductions = true;              % requires InstructionSetExtensions ~= "None" (or SIMDAcceleration ~= "None" for MEX)
cfg.RuntimeChecks = false;                  % lib/dll/exe only — not on MexCodeConfig
cfg.UseBuiltinFFTWLibrary = true;           % lib/dll/exe only — speeds up fft if used
```

`RuntimeChecks` and `UseBuiltinFFTWLibrary` are properties of `coder.CodeConfig` / `coder.EmbeddedCodeConfig` only; do not set them on `coder.MexCodeConfig`. Confirm with `isprop(cfg, 'PropName')` before assigning.

**`InstructionSetExtensions`** — emits SIMD intrinsics (`_mm_add_ps`, etc.) for `coder.config("lib"|"exe"|"dll")` targets. NOT available on `coder.MexCodeConfig` — assigning it on a MEX config throws an unrecognized-property error; use `SIMDAcceleration` for MEX instead.

Full value list: `"SSE"`, `"SSE2"`, `"SSE4.1"`, `"AVX"`, `"AVX2"`, `"FMA"`, `"AVX512F"`, `"None"`. Levels are cumulative — selecting `"AVX2"` also enables `AVX`, `SSE4.1`, `SSE2`, `SSE`. Set `ProdHWDeviceType` first so only valid values are accepted. If the compiler cannot emit the required flags (custom toolchain), set to `"None"`.

```matlab
cfg = coder.config("lib");
cfg.HardwareImplementation.ProdHWDeviceType = "Intel->x86-64 (Linux 64)";
cfg.InstructionSetExtensions = "AVX2";
codegen -config cfg -args {inputArg} entryPoint
```

For MEX speed specifically:

```matlab
cfg = coder.config('mex');
cfg.SIMDAcceleration = 'Full';
cfg.IntegrityChecks = false;            % see safety note below
cfg.ResponsivenessChecks = false;
cfg.ExtrinsicCalls = false;
```

**`SIMDAcceleration`** — the MEX-only SIMD property on `coder.MexCodeConfig`. Value table:

| Value | Instruction set |
|-------|----------------|
| `"None"` | No SIMD |
| `"Portable"` (default) | SSE2 |
| `"Full"` | AVX2 |

Intel/AMD only; other platforms get scalar (non-SIMD) code regardless. MATLAB Coder checks the host CPU and compiler and uses compatible intrinsics up to the requested level. Use `SIMDAcceleration` whenever the target is a MEX; use `InstructionSetExtensions` for lib/dll/exe targets.

**IntegrityChecks safety:** Before disabling, first generate and run the MEX with `IntegrityChecks = true` (the default). Exercise it with all expected runtime inputs and confirm no bounds or dimension errors occur. Only then set `IntegrityChecks = false` — without checks, out-of-bounds access crashes MATLAB with no diagnostic.

#### Readable / Traceable Output

```matlab
cfg = coder.config('lib');
cfg.PreserveVariableNames = 'All';
cfg.MATLABSourceComments = true;
cfg.GenerateComments = true;
cfg.InlineBetweenUserFunctions = 'Readability';
cfg.InlineBetweenMathWorksFunctions = 'Readability';
cfg.InlineBetweenUserAndMathWorksFunctions = 'Readability';
cfg.PreserveArrayDimensions = true;
cfg.UsePrecompiledLibraries = 'Avoid';   % emit source instead of linking precompiled libs
```

On `coder.EmbeddedCodeConfig`: `cfg.MATLABFcnDesc = true` and `cfg.EnableTraceability = true` for additional traceability.

#### Minimal Code Size

```matlab
cfg = coder.config('lib');
cfg.InlineBetweenUserFunctions = 'Never';
cfg.InlineBetweenMathWorksFunctions = 'Never';
cfg.InlineBetweenUserAndMathWorksFunctions = 'Never';
cfg.LoopUnrollThreshold = 0;
cfg.SupportNonFinite = false;
cfg.SaturateOnIntegerOverflow = false;
cfg.EnableImplicitExpansion = false;
```

On `coder.EmbeddedCodeConfig`: `cfg.ConvertIfToSwitch = true` lets the C compiler emit jump tables.

#### Safety / Compliance

```matlab
cfg = coder.config('lib');
cfg.RuntimeChecks = true;
cfg.SaturateOnIntegerOverflow = true;
cfg.SupportNonFinite = true;
```

On `coder.EmbeddedCodeConfig`: `cfg.JustifyMISRAViolations = true` and `cfg.GenerateDefaultInSwitch = true` for MISRA compliance.

### Step 5: Validate

After generating code with the new config, verify the constraints are met:

- **No dynamic memory:** Search generated `.c`/`.cpp` files for `malloc`, `free`, or `emxArray` — none should appear when `EnableDynamicMemoryAllocation = false`
- **Stack budget:** Codegen emits a warning if estimated stack exceeds `StackUsageMax`
- **No recursion:** When `EnableRuntimeRecursion = false`, codegen errors at build time if recursion is detected

## Property Interactions

These interactions are not obvious from any single property's documentation:

| If you set... | Then consider... | Because... |
|--------------|-----------------|------------|
| `EnableDynamicMemoryAllocation = false` | Keep `EnableVariableSizing = true` | Variable-size arrays get stack-allocated at worst-case bound; disabling both requires ALL colon operands to be compile-time constants, which fails if any library code uses runtime indexing |
| `EnableVariableSizing = false` | Ensure all dimensions are compile-time constants | Constants can come from `coder.Constant` entrypoint inputs, `coder.const(...)` expressions, or variables codegen can constant-fold from the calling context |
| `EnableDynamicMemoryAllocation = false` | Raise `StackUsageMax` | Worst-case arrays land on the stack; signal/image code commonly needs 512KB+ |
| `SaturateOnIntegerOverflow = false` | Verify overflow is impossible | Without saturation, overflow wraps silently (C behavior) |
| `IntegrityChecks = false` (MEX) | First run with checks enabled on all expected inputs | No runtime bounds checking — out-of-bounds crashes MATLAB without diagnostic |
| `EnableOpenMP = true` | Set `NumberOfCpuThreads` for determinism | `0` uses all cores; specific count gives reproducible behavior |
| `PurelyIntegerCode = true` | Audit the full call graph for floats | Codegen errors if any float operation exists, including in called library code |

See `references/config-properties.md` for additional non-obvious behavior notes and the introspection commands to query the live config object.

## Conventions

- All boolean config properties are `logical` — set to `true` or `false`, never `'On'`/`'Off'`
- Property names that gate a feature start with `Enable` (e.g., `EnableDynamicMemoryAllocation`, `EnableMemcpy`, `EnableRuntimeRecursion`)
- Inlining properties accept: `'Always'`, `'Speed'`, `'Readability'`, `'Never'`
- `PreserveVariableNames` accepts: `'None'`, `'UserNames'`, `'All'`
- Always start from a working `codegen` command before tuning — fix codegen errors first, then optimize
- Generate MEX and compare outputs to MATLAB before deploying lib/dll with aggressive optimizations (disabling saturation, runtime checks, or NaN support can mask bugs)
- When you are unsure whether a property exists on the current config type or what values it accepts, introspect the live `cfg` object via `mcp__matlab__evaluate_matlab_code` rather than relying on memorized tables

----

Copyright 2026 The MathWorks, Inc.

----
