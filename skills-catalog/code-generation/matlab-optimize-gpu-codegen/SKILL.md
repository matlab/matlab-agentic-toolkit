---
name: matlab-optimize-gpu-codegen
description: >
  Optimize MATLAB design files for GPU Coder to generate faster CUDA code.
  Iteratively profiles, rewrites, and benchmarks until performance targets are
  met or diagnostics are resolved. Use when asked to: optimize for GPU Coder,
  improve GPU codegen performance, profile generated GPU/CUDA code, profile
  GPU MEX, fix gpuPerformanceAnalyzer diagnostics, speed up GPU MEX, reduce
  GPU memory transfers, improve kernel parallelism, rewrite MATLAB for CUDA,
  or run gpuPerformanceAnalyzer.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Optimize MATLAB for GPU Code Generation

Iteratively optimize a MATLAB design file for GPU Coder: compile, benchmark,
apply structural optimizations, profile with gpuPerformanceAnalyzer, fix
diagnostics, and verify numerical equivalence at every step.

## When to Use

- User has a MATLAB function and wants faster GPU MEX or CUDA code
- User mentions GPU Coder, codegen, CUDA, gpuPerformanceAnalyzer
- User asks to profile generated GPU/CUDA code or GPU MEX (profiling generated
  GPU code is the entry point to this skill's diagnostic-fix workflow)
- User wants to reduce GPU memory, improve kernel parallelism, or fix Performance Analyzer diagnostics
- User has a `.m` design file and representative inputs

## When NOT to Use

- Workflows with no codegen
- `coder.gpuConfig("exe")` — standalone executables cannot be benchmarked or
  equivalence-checked from MATLAB. Suggest the user switch to `mex` or `lib`/`dll` and regenerate `exe` from the final optimized source.
- Simulink GPU code generation
- Writing new MATLAB functions from scratch (this skill optimizes existing code)
- Optimizing helper functions called by the design file — this skill optimizes the main design file only
- Hardware setup or CUDA toolkit installation
- General MATLAB performance tuning without GPU involvement
- The user's prompt does not mention GPU, codegen, CUDA, MEX, or profiling.
  Activation must be driven by the user's prompt alone — do not infer GPU
  intent from filenames or function contents. If unsure, ask before activating.

## Workflow

### Setup — Create Session Directory

All codegen artifacts, profiling outputs, and optimized versions go in a
single temp directory for the entire session. `pwd` must be `sessionDir` for
every codegen/benchmark/PA call — otherwise compiled MEX and SIL binaries
land in the user's working directory.

Two helpers this skill calls — `benchmarkMex` and `extractDiagnostics` — live
in the `scripts/` subfolder of this skill (the folder containing this
SKILL.md). A MATLAB function is only callable by name when its folder is on the
path, so add `scripts/` to the path in Setup and remove it in the cleanup. Then
call the helpers by bare name (`benchmarkMex(...)`, `extractDiagnostics(...)`).

```matlab
% TEMPLATE — not executable
sessionDir = fullfile(tempdir, "gpu_opt_" + string(datetime("now", Format="yyyyMMdd_HHmmss")));
mkdir(sessionDir);
scriptsDir = fullfile("<skill_dir>", "scripts");   % this skill's scripts/ folder (absolute)
addedDir = fileparts(which("<designFile>"));
addpath(scriptsDir, addedDir);
oldDir = cd(sessionDir);
cleanupCd = onCleanup(@() (cd(oldDir), rmpath(scriptsDir), rmpath(addedDir)));   %#ok<NASGU>
```

Write all artifacts to `sessionDir` only — never to the user's working directory.

### Step 1 — Codegen on Original

Run `codegen` on the unmodified design file to discover what actually fails.
Do NOT guess which functions are unsupported — let the compiler tell you.

**1a. Pick the codegen config.** Use the config the user provides. If none specified, default to MEX:

```matlab
cfg = coder.gpuConfig("mex");  % default — replace if user specifies a config
```

**Supported targets:** `mex`, `lib`, `dll`. The `exe` target is **not
supported** by this skill, so Steps 2–5 cannot benchmark or verify equivalence. 
If the user provides `coder.gpuConfig("exe")`, stop and ask them to either:

- switch to `mex` for the optimization workflow (recommended — fastest
  iteration), or
- switch to `lib`/`dll` if they need a deployable artifact (the skill will
  enable SIL to benchmark via a generated MEX).

Once optimization is complete, the user can regenerate with `exe` from the
final optimized source.

**1b. For lib/dll configs: enable SIL.** This is mandatory — without SIL
there is no callable MEX, so Steps 2–5 cannot benchmark. Set this *before*
calling codegen:

```matlab
% TEMPLATE — not executable
if ~isa(cfg, 'coder.MexCodeConfig')
    cfg.VerificationMode = 'SIL';   % required for benchmarking lib/dll targets
end
```

If SIL fails or is unavailable (e.g., Embedded Coder license missing), report
this and stop — do not silently skip benchmarking.

**1c. Resolve inputs.** If the user provided concrete input values, use them
as-is. If the user provided only types/sizes (e.g., "two double vectors of
size 1024x1"), synthesize inputs matching the spec — record exactly what
you generated (type, size, location, generator) so the Final Report can list
it. A reasonable default is `randn` with a fixed `rng` seed for floats,
`randi` for integers, `rand > 0.5` for logicals; keep inputs on the CPU
unless the user said otherwise or PA later flags `UseGpuInput`. If the user
gave neither values nor types/sizes, ask for representative sizes and types —
`codegen -args` needs a concrete signature and the input shape drives which
optimizations win.

**1d. Run codegen:**

```matlab
% TEMPLATE — not executable
codegen -config cfg <designFile> -args {<inputs>}
```

If codegen fails, read the errors and fix only what is reported as unsupported. 
Save the fixed file as `<designFile>_v1.m` in `sessionDir`.

**v1 must successfully codegen.** Re-run codegen until it passes. This
produces the baseline MEX: `<designFile>_v1_mex` (for lib/dll configs, the
SIL-generated MEX has the same name and is callable identically).

### Step 2 — Baseline Benchmark

Use the MEX generated in Step 1 directly — do not re-codegen. Benchmark with
the convergence-based helper:

```matlab
% TEMPLATE — not executable
baseline = benchmarkMex("<designFile>_v1_mex", {<inputs>});
baselineTime = baseline.MedianTime;
fprintf("Baseline: %.4f ms\n", baselineTime*1000);
```

**Rules:**
- Always use `benchmarkMex` (or `gputimeit`) — never use `tic/toc` for GPU timing (GPU ops are async)
- `benchmarkMex` handles warmup and convergence automatically
- Record `baselineTime` — all improvements are measured against this

### Step 3 — Structural Optimization Loop

Apply optimizations iteratively. Each iteration:

1. Create `<designFile>_v<N>.m` in `sessionDir` with the next optimization
2. Verify numerical equivalence against the original (multi-input — see Step 3b)
3. Run codegen to `sessionDir` — if it fails, fix or revert
4. Benchmark the new MEX with `benchmarkMex` — compare against best so far
5. Keep the fastest passing version as the current best

**MATLAB-level restructuring patterns** (rewrites that improve codegen
regardless of which GPU primitive you eventually choose):

| Pattern in Source | Optimization | Effect on Generated CUDA |
|---|---|---|
| Array-valued expression inside a loop that does not depend on the loop variable (e.g., `w = weights / sum(weights)` recomputed every iteration) | Hoist the expression above the loop | Eliminates redundant per-thread computation. GPU Coder cannot always prove loop-invariance for array expressions — it inlines them into the kernel, so every thread recomputes the same work. |
| Implicit expansion could replace an explicit loop (e.g., `for i=1:N, out(i,:) = A(i,:) + B; end` where `B` is a row vector) | Replace the loop with `out = A + B` using implicit expansion | GPU Coder generates a single fused kernel for implicit expansion. The explicit loop may also parallelize, but implicit expansion produces cleaner kernels with no loop overhead. |
| Divergent branching inside a parallelizable loop (e.g., `if x(i) > 0, a = f(x(i)); else, a = g(x(i)); end` where the condition varies unpredictably across elements) | Where both branches are cheap, compute both and select with a mask (e.g., `a = mask.*f(x) + (~mask).*g(x)`) | Divergent `if`/`else` causes warp divergence — threads in the same warp serialize across branches. A branchless mask keeps every thread on the same instruction path, restoring full warp throughput. |

The table above covers MATLAB-level restructuring only; it does not
enumerate GPU Coder primitives. Before committing to any optimization, read
`references/gpu-codegen-functions.md` end-to-end — it documents kernel
pragmas, parallel reductions and scans, atomics, stencils, and memory
placement. The right primitive depends on the loop's data-flow shape
(where the result lives, how dependencies chain, whether iterations
collide); the closest-looking table row is often not the right answer.
Match semantics to the loop, not surface appearance.

**Exit criteria for this loop:**
- Performance target met (if user specified one)
- No more structural optimizations the agent can identify
- Maximum 5 structural iterations (Step 5's diagnostic-fix loop has its own
  separate cap of 5 — the two are independent)

### Step 3b — Verify Numerical Equivalence

Run both original and optimized on up to 5 input sets. Use the user's
original inputs as the baseline, then generate variants matching the same
types and sizes. Match the generator to the input type (`randn` for float,
`randi` for integer, `rand > 0.5` for logical) and keep values in the type's
valid range.

```matlab
% TEMPLATE — not executable — float case; adapt generator to the input type
% Input sets — variants are built from in1, the first input resolved in Step 1c
in1 = <user_or_synthesized_input_from_step_1c>;     % original example
rng(42); in3 = randn(size(in1), 'like', in1);       % random
rng(99); in4 = randn(size(in1), 'like', in1) * 1e6; % large magnitude
```

Include an edge-case input only where it is valid for this function — an
all-zeros set exercises little and is degenerate if the function divides by
something derived from the input. Pick a variant that meaningfully stresses the
function instead.

Compare each output independently:

```matlab
% TEMPLATE — not executable
outOrig = <designFile>(testInput);
outOpt  = <designFile>_v<N>(testInput);

% Gather gpuArray outputs to CPU for comparison
if isa(outOpt, 'gpuArray'), outOpt = gather(outOpt); end

% If outputs can contain NaN, first check NaN positions match (see NaN rule
% below) — max() ignores NaN, so a corrupted NaN would otherwise pass silently.
denom = max(abs(outOrig(:)));
if denom == 0
    relErr = max(abs(outOpt(:)));  % absolute error when expected is zero
else
    relErr = max(abs(outOrig(:) - outOpt(:))) / denom;
end
fprintf("relErr = %.2e\n", relErr);
```

**Tolerance by output type:**

| Output Type | Tolerance |
|-------------|-----------|
| `double` | 1e-6 |
| `single` | 1e-3 |
| `half` | 1e-2 |
| Integer / logical | Exact (`isequal`) |

**Rules:**
- Always compare against the **original unmodified function**, not the previous version
- If the function has multiple outputs, check each with its own type-appropriate tolerance
- If output types differ between original and optimized, that's a bug — fix it
- Normalize relative error by `max(abs(expected))`, not element-wise
- Handle NaN: check NaN positions match (`isequal(isnan(a), isnan(b))`), then compare non-NaN elements
- gpuArray wrapping of inputs is allowed (e.g., after UseGpuInput fix) — it doesn't change the function contract


### Step 4 — Profile with gpuPerformanceAnalyzer

**Always run this step unless the user specified a performance target and it
was met in Step 3.** PA reveals issues (memory copies, low parallelism) that
benchmarks alone cannot detect.

Run PA on the current best version to find remaining bottlenecks. Pass the
same `cfg` from Step 1 so PA profiles the same target the user is
optimizing for:

```matlab
% TEMPLATE — not executable
paDir = fullfile(sessionDir, "pa_v<N>");
mkdir(paDir);

gpuPerformanceAnalyzer("<designFile>_v<N>", {<inputs>}, ...
    Config=cfg, ...
    OutFolder=paDir, ...
    LaunchReport=false);
```

**Key NVPs:**
- `Config=cfg` — reuse the codegen config from Step 1 (user-provided or
  the default `coder.gpuConfig("mex")`)
- `LaunchReport=false` — suppresses GUI report
- `OutFolder` — subdirectory within session dir

Extract diagnostics from the mldatx report:

```matlab
% TEMPLATE — not executable
mldatxFile = fullfile(paDir, "html", "gpuProfiler.mldatx");
results = extractDiagnostics(mldatxFile);
```

If `results.numDiagnostics == 0`, the profile is clean — skip to the Final Report.

The `results` struct contains:
- `results.numDiagnostics` — count of issues found
- `results.diagnostics(i).id` — namespaced ID (e.g., `"gpucoder:diagnostic:UseGpuInput"`)
- `results.diagnostics(i).message` — human-readable description
- `results.diagnostics(i).file` — path to the generated `.cu` file
- `results.diagnostics(i).line` — line number in the generated code

### Step 5 — Fix Diagnostics

Read `results.diagnostics` and apply targeted fixes. Each fix iteration:

1. Create `<designFile>_v<N+1>.m` in `sessionDir`
2. Run codegen — if it fails, fix or revert
3. **Verify equivalence against the original** (same procedure as Step 3b — same inputs, same tolerances, compare against the unmodified function)
4. Benchmark with `benchmarkMex` — compare against current best

**Diagnostic → Fix Mapping:**

| Diagnostic ID | Fix |
|---|---|
| `gpucoder:diagnostic:NoKernelFunPragma` | The named function has no kernel pragma, so no kernels are generated. Add `coder.gpu.kernelfun` to the named function. |
| `gpucoder:diagnostic:LargeLocalMemoryUsagePerThread` | The kernel uses a large amount of per-thread local memory. Simplify expressions inside the loop body: split compound expressions into fewer steps, extract large temporary arrays outside the loop, or reduce the number of intermediate variables to lower per-thread register/local memory pressure. |
| `gpucoder:diagnostic:UseGpuInput` | The flagged input is first used on the GPU, forcing a CPU→GPU memory copy. Convert **only** the flagged input to `gpuArray` before passing to codegen/PA. Do NOT speculatively convert other inputs. |
| `gpucoder:diagnostic:KernelDiagnosticsNotEnoughParallelism` | The kernel launches too few threads — each thread performs extensive work, so parallelism is low. Increase the number of independent iterations: reshape the computation so the parallelized loop covers more elements, split serial multi-step work into separate vectorized operations, or tile the data into more independent chunks. |
| `gpucoder:diagnostic:LongCPULoopHasLargeMemcpy` | A CPU-bound loop forces GPU-CPU synchronization on each pass. Restructure so GPU results are not read back to CPU within the loop. Keep intermediates on GPU until the loop completes. If the loop body launches kernels, parallelize the outer loop or merge it with the inner GPU work. |
| `gpucoder:diagnostic:LongRunningLoopLargeIteration` | A high-iteration loop dominates runtime and is not parallelized. Vectorize the loop body or restructure so iterations are independent (no loop-carried dependencies). If truly independent, `coder.gpu.kernelfun` or `coder.gpu.kernel` will map it to a kernel. |
| `gpucoder:diagnostic:KernelLaunchOverheadLargeInLoop` | Parallelized inner loops launch many trivial kernels with high overhead. Parallelize the outer (parent) loop instead of the inner loops. This fuses many small kernel launches into fewer, larger kernels. Use `coder.gpu.kernel` on the outer loop if the compiler won't auto-parallelize it. |
| `gpucoder:diagnostic:MemoryDiagnosticsRepeatedMemoryCopyInsideLoop` | A variable is copied between CPU and GPU every iteration, forcing synchronization. Move the variable's allocation and initialization outside the loop. If the variable is written on GPU and read on CPU (or vice versa) each iteration, restructure so it stays on one device for the entire loop duration. |
| `gpucoder:diagnostic:LongRunningLoopUnknownReason` | A CPU-bound loop contributes significant time for an undetermined reason. Investigate the loop body for serial dependencies. If independent: vectorize or add `coder.gpu.kernelfun`. If dependencies exist: check whether the dependent part can be separated from an independent part. If the loop calls functions that launch kernels internally, that prevents outer-loop parallelization — inline or restructure those calls. |

**Iteration cap:** Stop after 5 diagnostic-fix rounds (separate from Step 3's
structural-iteration cap). Report remaining issues if any cannot be resolved.

### Step 6 — Final Report

Present the best result:

```
# GPU Codegen Optimization Results

## Files
- Original: <designFile>.m
- Best version: <designFile>_v<N>.m
- Session directory: <sessionDir>

## Inputs Used
| Arg | Type | Size | Location | Source |
|-----|------|------|----------|--------|
| in1 | double | 1024x1 | CPU | user-provided / synthesized via `randn(1024,1)` with `rng(0)` |
| ... | ... | ... | ... | ... |

State "user-provided" when the user gave concrete values, or describe the
generator (function + seed) when inputs were synthesized. Reported timings
below are reproducible only with these inputs.

## Performance
| Version | Time (ms) | vs Baseline |
|---------|-----------|-------------|
| Baseline | X.XX | — |
| v2  | X.XX | Y% faster |
| v<N> | X.XX | Z% faster |

## Diagnostics Resolved
| Diagnostic | Status |
|---|---|
| <issue> | RESOLVED |
| <issue> | OPEN (reason) |

## Changes Applied
1. <change description>
2. <change description>

## Numerical Verification
All versions verified equivalent (max relErr below the type-appropriate
tolerance) across N test inputs.
```

The final deliverable is `<designFile>_v<N>.m` — the best-performing version
that passes equivalence checks.

## Conventions

- Never overwrite the original design file — always create `_v<N>` variants
- All artifacts go in a single session `tempdir`, never in the user's working directory
- Use `benchmarkMex` (or `gputimeit`) for all timing — never use `tic/toc` for GPU code
- Run codegen first to discover errors — never guess function support
- Verify equivalence with multiple diverse inputs after every change
- Use user-provided codegen config; default to `coder.gpuConfig("mex")` if unspecified
- Iterate: optimize → benchmark → repeat — stopping after one pass leaves performance on the table
- Only convert inputs to `gpuArray` where profiling shows a CPU→GPU copy — do not speculatively convert all inputs

----

Copyright 2026 The MathWorks, Inc.

----
