---
name: matlab-optimize-performance
description: "Read BEFORE optimizing any MATLAB code for speed. Without this workflow, agents commonly optimize the wrong target, fabricate speedup claims without measurement, or introduce regressions. Guides the 7-step workflow: baseline, profile, identify, optimize, measure, verify, report."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Performance Optimization Workflow

Systematic 7-step workflow for finding and fixing performance bottlenecks in MATLAB code.

## When to Use

- User asks to speed up or optimize MATLAB code
- User wants to find why their MATLAB code is slow
- User has a function or script that takes too long to run
- User asks to benchmark or time MATLAB code
- User wants to compare performance before and after a change
- User asks about MATLAB performance best practices

## When NOT to Use

- Optimizing Simulink model simulation speed (use Simulink Profiler)
- The bottleneck is in compiled C/MEX code that can't be changed at the M-code level
- The performance issue is purely I/O-bound (file reads, network, database)
- User wants to write performance *tests* (use the `writing-matlab-perf-tests` skill)

## The 7-Step Workflow

### Step 1: Establish Baseline

Measure current performance so you have a number to improve against.

**For a single function:**
```matlab
f = @() targetFunction(input1, input2);
baseline = timeit(f);
fprintf('Baseline: %.4f s\n', baseline);
```

**For GPU code:**
```matlab
f = @() gpuFunction(gpuInput);
baseline = gputimeit(f);
```

**For a script or multi-step workflow:**
```matlab
% Warmup run (first call includes JIT compilation)
myWorkflow(inputs);

% Timed run
tic;
myWorkflow(inputs);
baseline = toc;
fprintf('Baseline: %.4f s\n', baseline);
```

`timeit` is preferred because it handles warmup and runs multiple samples automatically.

### Step 2: Profile and Analyze

Find where the time is actually spent. Do NOT guess — always profile.

```matlab
profile on;
targetFunction(input1, input2);
profile off;
profile viewer;
```

**Reading profiler results:**

1. **Function summary** — shows total time and self-time per function. Self-time is time spent in that function, not its callees. Start with the highest self-time.
2. **Per-line detail** — click a function name to see time spent on each line. This reveals the exact bottleneck lines.
3. **Call count** — functions called thousands/millions of times are prime optimization targets.

**Tips:**
- Run the profiled code multiple times (in a loop) if it's very fast, so the profiler collects enough samples
- Look at self-time, not total time, to find the true bottleneck
- Drill into functions — the summary page only tells part of the story

### Step 3: Identify Optimization Opportunities

Based on profiling results, identify which patterns apply. Read `references/optimization-patterns.md` for the full catalog.

**High-impact patterns:**

| Pattern | Typical Speedup | Look For |
|---------|----------------|----------|
| Vectorization | 2–200x | Loops doing element-wise math on arrays |
| Preallocation | 2–100x | Arrays growing inside loops (`x = [x; newRow]`) |
| Unnecessary recomputation | 2–50x | Same expensive expression computed multiple times |
| `discretize`/`histcounts` | 2–50x | Loops binning or classifying data |
| Persistent caching | 1.5–95x | Repeated `load()` or expensive object creation |
| Logical indexing | 1.2–5x | Using `find()` just to index into an array |
| `arguments` block | 1.1–1.8x | Functions using `inputParser` |
| Algebraic simplification | 1.5–3x | Redundant `sqrt`, `abs`, or matrix ops |

**Before optimizing, verify the target is worth it:**
- Is self-time > 10% of total? If not, optimizing it won't matter much.
- Is it called in a tight loop? High call count × small time = big total.
- Is it M-code or a built-in? You can't make a built-in faster, but you can often call it fewer times (e.g., pass a matrix to `filtfilt`/`filter` instead of looping over columns).

### Step 4: Implement Optimizations

Apply the patterns identified in Step 3. See `references/optimization-patterns.md` for the full catalog with before/after code examples.

**General principles:**
- Start with the highest-impact pattern from profiling
- Move invariant work out of loops (object creation, option parsing, constant expressions)
- Replace element-wise loops with array operations where possible
- Use purpose-built functions (`discretize`, `cumsum`, `hypot`) instead of hand-written equivalents
- For large data, batch the vectorization to control memory (see Pattern 9 in catalog)

**Example — move invariant work out of loops:**
```matlab
% Before: repeated expensive setup
for i = 1:n
    opts = optimoptions('fminunc', 'Display', 'off');
    result(i) = fminunc(@(x) cost(x, data(i)), x0, opts);
end

% After: setup once
opts = optimoptions('fminunc', 'Display', 'off');
for i = 1:n
    result(i) = fminunc(@(x) cost(x, data(i)), x0, opts);
end
```

### Step 5: Measure Optimized Performance

Re-measure using the same method as Step 1:

```matlab
f = @() optimizedFunction(input1, input2);
optimized = timeit(f);
speedup = baseline / optimized;
fprintf('Optimized: %.4f s (%.2fx speedup)\n', optimized, speedup);
```

A speedup of 1.2x or more is considered significant. Below that, measurement noise makes it hard to be confident the change helped.

### Step 6: Verify Correctness

Every optimization must produce the same results as the original:

```matlab
original = originalFunction(input1, input2);
fast = optimizedFunction(input1, input2);

% Numeric comparison (allows floating-point tolerance)
maxErr = max(abs(original(:) - fast(:)));
fprintf('Max error: %.2e\n', maxErr);
assert(maxErr < 1e-10, 'Results differ beyond tolerance!');
```

For non-numeric outputs:
```matlab
assert(isequal(original, fast), 'Results differ!');
```

If results differ slightly due to floating-point reordering (e.g., summing in a different order), that's usually acceptable. Document the expected tolerance.

### Step 7: Report Results

Summarize what was done and the improvement achieved:

```matlab
fprintf('\n=== Performance Optimization Report ===\n');
fprintf('Target: %s\n', funcName);
fprintf('Baseline: %.4f s\n', baseline);
fprintf('Optimized: %.4f s\n', optimized);
fprintf('Speedup: %.2fx\n', speedup);
fprintf('Correctness: max error = %.2e\n', maxErr);
fprintf('Pattern applied: %s\n', patternName);
```

**For multiple optimizations**, report each speedup individually and the overall end-to-end improvement.

## Key Rules

1. **Always profile before optimizing** — never guess where the bottleneck is
2. **One change at a time** — measure after each optimization to know what helped
3. **Verify correctness** — every optimization must produce equivalent output
4. **1.2x threshold** — speedups below 1.2x are not reliably distinguishable from noise
5. **GPU timing** — always `wait(gpuDevice)` before and after timing GPU code
6. **Use `timeit`** — it handles warmup and averaging; avoid raw `tic/toc` for benchmarks

## Common Mistakes

| Mistake | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| Optimizing without profiling | You'll fix the wrong thing | Profile first (Step 2) |
| Single `tic/toc` without warmup | Includes JIT compilation time | Use `timeit` or add a warmup call |
| Timing GPU code without sync | GPU ops are async; `toc` fires early | `wait(gpuDevice)` before and after |
| Growing arrays in loops | Each append copies the entire array | Preallocate before the loop |
| Vectorizing huge arrays blindly | May exceed memory | Use chunked processing for large data |
| Reporting only subfunction speedup | Misleading if subfunction is 5% of total | Always report end-to-end timing |
| Assuming faster = correct | Bugs can make code fast (by skipping work) | Always verify results match (Step 6) |

## Reference Files

- `references/optimization-patterns.md` — Full catalog of optimization patterns with code examples and measured speedups
- `references/measurement-templates.md` — Ready-to-use MATLAB script templates for each workflow step

Copyright 2026 The MathWorks, Inc.
