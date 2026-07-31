# Accelerate MATLAB with Generated MEX

Speed up MATLAB functions by generating MEX with MATLAB Coder, profiling the generated code to identify hotspots, and iterating on optimizations.

## Workflow

### Step 1: Establish Baseline with coder.timeit

Measure both MATLAB and MEX execution time using `coder.timeit`. This generates MEX internally, runs it multiple times, and returns the median execution time.

```matlab
% Measure generated MEX execution time
numOutputs = 1;
runtimeArgs = {randn(1000, 1), int32(64)};
[t, trObj] = coder.timeit('myFunction', numOutputs, runtimeArgs);
fprintf('MEX median time: %.4f s\n', t);
```

**Critical:** `coder.timeit` takes a function name as a string, NOT a function handle. The third argument is a cell array of runtime input values.

To also measure MATLAB execution time for comparison, use `coder.perfCompare`:

```matlab
numOutputs = 1;
runtimeArgs = {randn(1000, 1), int32(64)};
t = coder.perfCompare('myFunction', numOutputs, runtimeArgs);
disp(t)
```

This returns a table with columns for MATLAB and MEX execution times.

#### Reusing a Config (avoid redundant codegen)

If you already have a codegen config or want specific settings for the MEX:

```matlab
cfg = coder.config('mex');
cfg.TargetLang = 'C++';

numOutputs = 1;
runtimeArgs = {randn(1000, 1), int32(64)};
[t, trObj] = coder.timeit('myFunction', numOutputs, runtimeArgs, CoderConfig=cfg);
```

#### Using CompileArgs for Input Types

When you need compile-time input type specifications (e.g., variable-size arrays) instead of inferring types from runtime values:

```matlab
numOutputs = 1;
compileArgs = {coder.typeof(zeros(1000, 1)), coder.typeof(int32(0))};
runtimeArgs = {randn(1000, 1), int32(64)};

[t, trObj] = coder.timeit('myFunction', numOutputs, runtimeArgs, ...
    CompileArgs=compileArgs);
```

#### Specifying a Work Directory

Control where generated code is placed:

```matlab
numOutputs = 1;
[t, trObj] = coder.timeit('myFunction', numOutputs, runtimeArgs, ...
    WorkDirectory=fullfile(pwd, 'perf_codegen'));
```

### Step 2: Generate MEX with Profiling Enabled

To identify *where* time is spent inside the generated code, generate MEX with profiling instrumentation:

```matlab
cfg = coder.config('mex');
cfg.EnableMexProfiling = true;

inputTypes = {coder.typeof(zeros(1000, 1)), coder.typeof(int32(0))};
codegen -config cfg myFunction -args inputTypes
```

`EnableMexProfiling = true` instruments the generated MEX so the MATLAB Profiler can attribute time to individual lines of the original MATLAB source.

### Step 3: Profile the Generated MEX

Run the profiled MEX under the MATLAB Profiler and extract hotspot data:

```matlab
profile on
for k = 1:100
    myFunction_mex(testInput1, testInput2);
end
profile off

profData = profile('info');
funcTable = profData.FunctionTable;

% Find the entry for our function
idx = find(strcmp({funcTable.FunctionName}, 'myFunction_mex'));
if ~isempty(idx)
    fprintf('Total time: %.4f s\n', funcTable(idx).TotalTime);
    fprintf('Number of calls: %d\n', funcTable(idx).NumCalls);
end
```

**Critical:** Profile the MEX function (`myFunction_mex`), NOT the interpreted MATLAB function. Profiling interpreted MATLAB tells you nothing about where the generated code spends time — the performance characteristics are completely different.

### Step 4: Optimize, Re-profile, and Re-measure

Based on profiling results, apply optimizations to the **entrypoint function** and/or the **codegen config**, then re-profile and re-measure with `coder.timeit` to confirm improvement.

#### Function-Level Optimizations

Common optimizations to the MATLAB source that improve generated code performance:

- **Preallocate arrays** — dynamic growth in loops generates realloc calls
- **Use fixed-size arrays** where possible — lets the compiler optimize more aggressively
- **Replace logical indexing with explicit loop indexing** — logical indexing often generates temporary arrays and branch-heavy code; explicit C-style for-loops give the compiler a predictable iteration pattern
- **Ensure loops can be auto-parallelized** — `EnableAutoParallelization` is on by default, but only works for loops with no loop-carried dependencies. Refactor loops to be iteration-independent if profiling shows they are not parallelized
- **Move invariant computations** out of loops — codegen may not hoist all invariants
- **Use `coder.const`** for values computable at compile time — eliminates runtime computation
- **Avoid `varargin`/`varargout`** — use explicit arguments for predictable code paths
- **Reduce function call overhead** — inline small helpers or mark them with `coder.inline('always')`

#### Config-Level Optimizations

`EnableAutoParallelization` and `EnableOpenMP` are on by default. The main config knobs for additional speed:

```matlab
cfg = coder.config('mex');
cfg.TargetLang = 'C++';

% Reduce runtime checks (safe when you trust input validity)
cfg.IntegrityChecks = false;        % Skip array bounds, dimension checks
cfg.ResponsivenessChecks = false;   % Skip Ctrl+C polling in loops
cfg.SaturateOnIntegerOverflow = false; % Skip overflow saturation

% Inlining control (default is 'Speed'; use 'Always' to force full inlining)
cfg.InlineBetweenUserFunctions = 'Always';
cfg.InlineBetweenUserAndMathWorksFunctions = 'Always';
cfg.InlineBetweenMathWorksFunctions = 'Always';
```

#### Re-measure After Optimization

```matlab
numOutputs = 1;
runtimeArgs = {randn(1000, 1), int32(64)};
[tOptimized, trObj] = coder.timeit('myFunction', numOutputs, runtimeArgs, ...
    CoderConfig=cfg);
fprintf('Optimized MEX time: %.4f s (was %.4f s)\n', tOptimized, tBaseline);
```

Compare multiple configs side-by-side:

```matlab
cfgBase = coder.config('mex');
cfgOpt = coder.config('mex');
cfgOpt.IntegrityChecks = false;
cfgOpt.ResponsivenessChecks = false;
cfgOpt.InlineBetweenUserFunctions = 'Always';

numOutputs = 1;
runtimeArgs = {randn(1000, 1), int32(64)};
t = coder.perfCompare('myFunction', numOutputs, runtimeArgs, {cfgBase, cfgOpt}, ...
    ConfigNames={'Baseline MEX', 'Optimized MEX'});
disp(t)
```

#### Re-profile After Optimization

After applying function-level or config changes, re-run the profiling workflow (Steps 2-3) on the optimized MEX to verify hotspots have shifted or been eliminated. Iterate until the dominant hotspot is inherent to the algorithm rather than an artifact of suboptimal code patterns.

## Key Functions

| Function | Purpose | Toolbox | Since |
|----------|---------|---------|-------|
| `coder.timeit` | Measure execution time of generated code | MATLAB Coder | R2024b |
| `coder.perfCompare` | Compare MATLAB vs MEX (or multiple configs) | MATLAB Coder | R2024b |
| `coder.config('mex')` | Create MEX config with `EnableMexProfiling` | MATLAB Coder | R2012a |
| `profile on/off` | MATLAB Profiler — works with profiling-enabled MEX | (core MATLAB) | — |
| `coder.inline` | Control function inlining in generated code | MATLAB Coder | R2011a |

## Conventions

- Always establish a baseline with `coder.timeit` before optimizing
- Use `coder.perfCompare` when comparing MATLAB vs MEX or multiple configurations
- Pass `CoderConfig` to `coder.timeit` to reuse an existing config and avoid redundant code generation
- Pass `CompileArgs` when input types differ from the runtime values (e.g., variable-size)
- Profile the generated MEX (`_mex` suffix), never the interpreted MATLAB function
- Optimize the entrypoint function first (preallocation, vectorization, coder.const), then tune config settings
- Re-measure after every optimization to confirm improvement — some "optimizations" can be neutral or harmful
- Use `EnableMexProfiling` only when you need line-level hotspot data; it adds overhead to the MEX. Use `coder.timeit` without it for clean timing measurements

## Related references

- `references/generate-code.md` — generating MEX before profiling
- `references/write-performance.md` — source-code-level performance patterns (vectorization, loop fusion, column-major access, DMA-off)
- `references/refine-config.md` — broader config tuning beyond speed
- `references/verify-code.md` — verify correctness before optimizing aggressively

----

Copyright 2026 The MathWorks, Inc.

----
