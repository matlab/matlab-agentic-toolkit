# Generate C/C++ Code from MATLAB

Generate production-quality C/C++ or CUDA code from MATLAB functions using MATLAB Coder or GPU Coder's `codegen` command.

## Workflow

### Step 0: Class Input — Try Direct Class Code Generation First

If the user's source is a **MATLAB class** (classdef file), attempt direct class code generation with `coder.ClassSignature` before falling back to a wrapper function. This produces a proper C++ class with methods, which is almost always what the user intends when they say "generate C++ class code."

**PREREQUISITE:** Run `enableCodegenForEntryPointClasses` before attempting class code generation. Without this, `codegen` will reject the class with an error saying entry points must be MATLAB functions. This is a Tech Preview feature (R2026a+) that must be enabled once per MATLAB session.

See `references/write-class-limitations.md` → "Direct class code generation with `coder.ClassSignature`" for the full workflow. If it fails or is unavailable, continue below with a wrapper function.

### Step 1: Clarify Requirements

Before generating code, ask the user (if not already clear):

1. **Target type:** MEX (test/accelerate), static library, shared library, or executable?
2. **Language:** C, C++, or CUDA (GPU)?
3. **Constraints:** Memory limits? No dynamic allocation? Embedded target?
4. **Input types:** Fixed-size or variable-size? What dimensions?

For GPU targets, use `coder.gpuConfig` instead of `coder.config`:

```matlab
cfg = coder.gpuConfig('mex');  % or 'lib', 'dll', 'exe'
```

This returns the same config type with GPU code generation enabled (`cfg.GpuConfig.Enabled = true`). The rest of the workflow (screening, input types, codegen command) is identical.

If uncertain, default to MEX first (fastest iteration, verifies correctness against MATLAB).

### Step 2: Screen for Readiness

Always run `coder.screener` programmatically before attempting `codegen`:

```matlab
res = coder.screener('myFunction');
disp(res.UnsupportedCalls)
disp(res.Messages)
```

**Critical:** Capture the return value. Calling `coder.screener('myFunction')` without capturing opens the GUI with no command-line output.

**Inspect both fields:**
- `res.UnsupportedCalls` — functions that cannot be compiled (must fix or make extrinsic)
- `res.Messages` — language constructs that may cause issues (e.g., try-catch, eval)

Run via `mcp__matlab__evaluate_matlab_code`. If there are unsupported calls or messages, proceed to Step 3 before generating code.

### Step 3: Fix Unsupported Constructs

Before changing the user's source, summarize the proposed edits and confirm with the user — see the cross-cutting rule "Never modify the user's source without authorization" in `SKILL.md`. The screener's findings are the *case* for editing, not the authorization to edit.

For each issue found by the screener:

**Unsupported function calls** — two approaches:

1. **Constant-fold with extrinsic** (when the result is constant at compile time):

```matlab
coder.extrinsic('unsupportedFunc');
result = coder.const(unsupportedFunc(args));
```

The `coder.extrinsic` declaration tells codegen not to analyze the function body. Then `coder.const` evaluates it at compile time and embeds the result. Both lines are required together.

Alternatively, use `feval`:

```matlab
result = coder.const(feval('unsupportedFunc', args));
```

2. **Replace with codegen-compatible alternative** (when result varies at runtime):
   - `containers.Map` → struct with named fields
   - `eval` / `evalc` → direct function calls
   - `inputname` / `dbstack` → remove or pass as input argument
   - `Java/COM objects` → remove or make extrinsic
   - Try-catch → conditional checks (or keep if MEX target only)

**Unsupported language constructs:**
- Dynamic field access with runtime strings → explicit field access
- Cell arrays of mixed types → separate variables or struct
- Object polymorphism → code pattern restructuring

After fixing, re-run `coder.screener` to confirm zero issues.

For comprehensive codegen language constraints and authoring patterns, see `references/write-codegen-ready.md`.

### Step 4: Generate MEX (Verify Correctness)

Before generating, screen for any remaining issues (even if Step 2 was done earlier — the function may have changed):

```matlab
res = coder.screener('myFunction');
disp(res.UnsupportedCalls)
disp(res.Messages)
```

Then generate MEX to verify the generated code produces correct results:

```matlab
cfg = coder.config('mex');
cfg.TargetLang = 'C++';

% Define input types
inputTypes = {coder.typeof(zeros(100,1)), coder.typeof(int32(0))};

codegen -config cfg myFunction -args inputTypes
```

Then compare MEX output to MATLAB:

```matlab
matlabResult = myFunction(testInput1, testInput2);
mexResult = myFunction_mex(testInput1, testInput2);
maxDiff = max(abs(matlabResult(:) - mexResult(:)));
fprintf('Max difference: %g\n', maxDiff);
```

Small floating-point differences (< 1e-10 relative) are normal due to different math libraries in generated code vs. MATLAB interpreter.

### Step 5: Generate Final Target

Once MEX verifies correctly, generate the final target:

```matlab
cfg = coder.config('lib');  % or 'dll', 'exe'
cfg.TargetLang = 'C++';

% Apply constraints based on user requirements
% See references/refine-config.md for goal-specific tuning

codegen -config cfg myFunction -args inputTypes
```

Verify the output directory exists and contains expected files (`.a`/`.lib`, `.h`, `.cpp`/`.c`).

**Exe targets need a `main`.** When `cfg = coder.config('exe')`, codegen will not produce a runnable binary unless either (a) you set `cfg.GenerateExampleMain = 'GenerateCodeAndCompile'` or (b) you supply your own `main.c`/`main.cpp` via `cfg.CustomSource`. The factory default `'GenerateCodeOnly'` emits an example main source file but does not compile it — so a "successful" codegen run leaves you with no executable.

```matlab
% Option A: let codegen compile the example main into a real binary
cfg = coder.config('exe');
cfg.GenerateExampleMain = 'GenerateCodeAndCompile';
codegen('myFunction', '-config', cfg, '-args', inputTypes)
% Binary: <pwd>/myFunction (no extension on Linux/Mac, .exe on Windows).
% NOTE: the binary lands in the current working directory, not in -d outDir.
```

```matlab
% Option B: supply your own main and let codegen compile/link it
cfg = coder.config('exe');
cfg.GenerateExampleMain = 'DoNotGenerate';        % suppress the auto example
% File extension on cfg.CustomSource must match cfg.TargetLang ('C' -> main.c, 'C++' -> main.cpp).
cfg.CustomSource        = 'main.c';               % relative or absolute path
% Use cfg.CustomInclude / cfg.CustomLibrary if your main pulls in additional headers/libs.
codegen('myFunction', '-config', cfg, '-args', inputTypes)
```

`GenerateExampleMain` allowed values: `'GenerateCodeAndCompile'`, `'GenerateCodeOnly'` (default), `'DoNotGenerate'`. Pick one explicitly on every exe build — never leave it at the default if the user expects a runnable binary, and never assume the default did the right thing.

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `codegen` | Generate C/C++ code from MATLAB | MATLAB Coder |
| `coder.screener` | Check codegen readiness (capture return value!) | MATLAB Coder |
| `coder.config` | Create config object (`'mex'`, `'lib'`, `'dll'`, `'exe'`) | MATLAB Coder |
| `coder.gpuConfig` | Create GPU-enabled config (`'mex'`, `'lib'`, `'dll'`, `'exe'`) | GPU Coder |
| `coder.typeof` | Define input type with size and variability | MATLAB Coder |
| `coder.Constant` | Declare compile-time constant input | MATLAB Coder |
| `coder.extrinsic` | Declare function as extrinsic (not compiled) | MATLAB Coder |
| `coder.const` | Evaluate expression at compile time | MATLAB Coder |

## Patterns

### Input Type Specification

```matlab
% Fixed-size double vector (100x1)
t1 = coder.typeof(zeros(100, 1));

% Variable-size with upper bound (up to 1000 elements, 1 column)
t2 = coder.typeof(double(0), [1000 1], [true false]);

% Compile-time constant (baked into generated code)
t3 = coder.Constant(int32(256));

% Fixed-size struct
t4 = coder.typeof(struct('field1', 0, 'field2', zeros(3,1)));
```

### Constant-Folding Unsupported Functions

When an unsupported function produces a result that is constant at compile time (e.g., computing a lookup table, loading calibration data):

```matlab
% In the function being compiled:
coder.extrinsic('computeLookupTable');
lut = coder.const(computeLookupTable(params));
```

Or equivalently with `feval`:

```matlab
lut = coder.const(feval('computeLookupTable', params));
```

The result is evaluated once during code generation and embedded as a constant in the generated code. Use this for initialization data, filter coefficients, lookup tables, or any value that does not change at runtime.

### Config for Embedded/Memory-Constrained Targets

```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C++';
cfg.EnableDynamicMemoryAllocation = false;
cfg.EnableRuntimeRecursion = false;
cfg.EnableMemcpy = false;
cfg.StackUsageMax = 524288;  % 512 KB
cfg.SupportNonFinite = false;
```

For deeper goal-specific tuning (max speed, readability, code size, MISRA), see `references/refine-config.md`.

### Inspecting the Config Object

Property names, defaults, and per-config-type availability drift across MATLAB releases. When you are unsure whether a property exists or what values it accepts, introspect the constructed config via `mcp__matlab__evaluate_matlab_code` rather than relying on memorized tables:

```matlab
cfg = coder.config('lib');     % or 'mex', or coder.gpuConfig(...)
class(cfg)                     % CodeConfig vs. EmbeddedCodeConfig vs. MexCodeConfig
properties(cfg)                % full property list for this version
disp(cfg)                      % current values
isprop(cfg, 'EnableMemcpy')    % does a candidate property exist?
```

### Config for GPU Targets

```matlab
cfg = coder.gpuConfig('lib');  % same args as coder.config: 'mex', 'lib', 'dll', 'exe'
cfg.TargetLang = 'C++';

% GPU-specific settings live under cfg.GpuConfig:
cfg.GpuConfig.MallocMode = 'discrete';       % 'discrete' or 'unified'
cfg.GpuConfig.EnableCUBLAS = true;            % Use cuBLAS for matrix ops
cfg.GpuConfig.EnableCUFFT = true;             % Use cuFFT for FFTs
cfg.GpuConfig.EnableCUSOLVER = true;          % Use cuSOLVER for linear algebra
cfg.GpuConfig.ComputeCapability = 'Auto';     % Or specific: '7.5', '8.6'
cfg.GpuConfig.StackLimitPerThread = 51200;    % Per-thread stack (bytes)

codegen('myFunction', '-config', cfg, '-args', inputTypes)
```

### Codegen Command Syntax

```matlab
% Basic: command syntax (fine when all arguments are literals or workspace variables)
codegen -config cfg myFunction -args {t1, t2, t3}

% With output directory: use function-call syntax to ensure path evaluates correctly
outDir = fullfile(pwd, 'codegen_output');
codegen('myFunction', '-config', cfg, '-args', {t1, t2}, '-d', outDir)
```

**Important:** Always use function-call syntax when passing variable paths to `-d`. The command-syntax form `-d (outDir)` can create literal directory names instead of evaluating the variable, especially when codegen is invoked programmatically.

## Conventions

- Always screen before generating: `res = coder.screener('func')` is fast and prevents wasted codegen attempts
- Always verify with MEX before generating lib/dll targets
- Use `coder.Constant` for inputs whose value is known at compile time (e.g., frame sizes, lookup dimensions) — this lets codegen resolve downstream array sizes statically
- For variable-size arrays: specify upper bounds with `coder.typeof(example, [maxDims], [variableFlags])`
- Config property names start with `Enable` for boolean switches (e.g., `EnableDynamicMemoryAllocation`, `EnableMemcpy`, `EnableRuntimeRecursion`)
- Config properties are logical (`true`/`false`), not char — never use `'On'`/`'Off'`

## Related references

- `references/write-codegen-ready.md` — authoring MATLAB code for codegen readiness (language constraints, directives, patterns)
- `references/config-properties.md` — introspect config properties in the user's MATLAB version
- `references/refine-config.md` — goal-specific config tuning (memory / speed / readability / size / safety)
- `references/verify-code.md` — verify the generated code matches MATLAB
- `references/accelerate-mex.md` — profile and optimize generated MEX

----

Copyright 2026 The MathWorks, Inc.

----
