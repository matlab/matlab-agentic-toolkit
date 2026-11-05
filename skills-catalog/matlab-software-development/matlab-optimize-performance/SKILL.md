---
name: matlab-optimize-performance
description: "Use when MATLAB code is too slow or the user wants it faster, or asks to profile it, find its hot line or where the time goes, count how many times a function runs, or benchmark or compare timings. Profiles before changing code (Sampling Profiler on R2026b+), checks the output against the original, and reports only measured speedups. Not for writing performance tests."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Performance Optimization Workflow

Systematic 7-step workflow for finding and fixing performance bottlenecks in MATLAB code.

## When to Use

- User asks to speed up MATLAB code, or to optimize it for execution time
- User wants to find why their MATLAB code is slow
- User has a function or script that takes too long to run
- User asks to benchmark or time MATLAB code in the current session (a one-off timing or an A/B of two versions)
- User wants to compare performance before and after a change
- User asks about MATLAB performance best practices

## When NOT to Use

- Optimizing Simulink model simulation speed (use Simulink Profiler)
- Speeding code up by compiling it with MATLAB Coder (`codegen`, MEX), or tuning generated MEX (use the `matlab-generate-code` skill)
- The problem is memory, not speed: out-of-memory errors or peak memory (use the `matlab-optimize-memory` skill)
- The performance issue is purely I/O-bound (file reads, network, database)
- User wants to write performance *tests*, or track timings across builds or in CI (use the `matlab-write-performance-tests` skill)
- Note: for *exact* invocation counts, or a sub-10 ms / MEX / parallel workload, use the MATLAB profiler (`profile`) rather than the Sampling Profiler (Step 2) — that's a profiler choice, not a reason to skip the skill

## The 7-Step Workflow

### Step 1: Establish Baseline

Measure current performance so you have a number to improve against:

```matlab
f = @() targetFunction(input1, input2);
baseline = timeit(f);   % handles warm-up and repeats; prefer it to tic/toc
```

For GPU code use `gputimeit`. For a script, run it once to warm up, then time a second run with `tic`/`toc`. Templates: `assets/measurement-templates.md`.

### Step 2: Profile and Analyze

Find where the time actually goes — don't guess, profile.

**Pick the profiler first: check, don't assume.** In R2026b+ the Sampling Profiler is the default: a
low-overhead statistical profiler that samples the execution thread at ~100 Hz. This skill's
`sampling_profiler` helper drives it, and `sampling_profiler('available')` tells you whether this MATLAB
has it. Use the MATLAB profiler (`profile`) only when `available` is false, when you need exact call
counts, or for a one-shot call too short to loop, or MEX or parallel code.

```matlab
% Sampling Profiler — use when sampling_profiler('available') is true (clean up after)
addpath(fullfile(skillRoot, "scripts"));   % skillRoot = directory containing this SKILL.md
assert(sampling_profiler('available'));     % false -> use the MATLAB profiler block below
nReps = 1;   % raise until the loop below runs several seconds (~10 s is ideal)
sampling_profiler('on');
sampling_profiler('pause');
targetFunction(input1, input2);            % warm-up: pays first-call cost, not collected
sampling_profiler('clear');
sampling_profiler('resume');
for r = 1:nReps, targetFunction(input1, input2); end
[~, stacks] = sampling_profiler('off');
sampling_profiler('destroy');              % mandatory cleanup: skipping it corrupts later runs
```
```matlab
% MATLAB profiler — any release; use when the Sampling Profiler isn't available
profile on; targetFunction(input1, input2); profile off; profile viewer;
```

**Reading the sampler:**
- **Run several seconds; ~10 s is ideal** (~1000 samples; ~100 is the bare minimum). Loop a quick
  workload by raising `nReps`, and keep the warm-up call. If it can't be looped, use `profile`.
- **The counts describe the profiled run** (`stacks.TotalSamples/100` is close to its wall clock) and
  include **no** invocation counts. For how many *times* something ran, use `profile`, and record
  `"call_count_source": "builtin_profile_numcalls"`, `"sampling_can_count_invocations": false` and
  `"sampling_profiler_samples"` in `perf_report.json`.
- **Neither profiler sees inside a builtin or P-coded frame**: the time lands on the call site with no
  line detail. Confirm such a hotspot by removing it and re-timing (Step 5).

**Work from the profile to a change:**
- **Rank functions by self time, then read the lines inside the top one.** Per-line time includes
  callees, so a line that only makes a call can outrank the line doing the work.
- **Before changing anything, say from the code why that line is slow:** a real mechanism (a
  reallocation in a loop, a builtin on a large array), not just a big percentage.
- **Step 5 is the proof:** if re-timing doesn't move the clock, your explanation was wrong; profile again.

For the full Sampling Profiler API, results model, traps, and helpers, see `references/sampling-profiler.md`.

### Step 3: Identify Optimization Opportunities

Based on profiling results, identify which patterns apply. Read `references/optimization-patterns.md` for the full catalog.

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
- Is it called in a tight loop? High call count × small time = big total.
- Is it M-code or a built-in? You can't make a built-in faster, but you can often call it fewer times (e.g., pass a matrix to `filtfilt`/`filter` instead of looping over columns).

### Step 4: Implement Optimizations

Apply the patterns from Step 3, starting with the highest-impact one. Before/after examples are in `references/optimization-patterns.md`.

- Move invariant work out of loops (object creation, option parsing, constant expressions)
- Replace element-wise loops with array operations where possible
- Use purpose-built functions (`discretize`, `cumsum`, `hypot`) instead of hand-written equivalents
- For large data, batch the vectorization to control memory (see Pattern 9 in catalog)
- Try each new variant on a small slice of the input first: a wrong orientation in implicit expansion can build a huge array

### Step 5: Measure Optimized Performance

**Quick check**, while you are still iterating: re-time with `timeit` as in Step 1 and compare with the baseline. A speedup of 1.2x or more is considered significant; below that, measurement noise makes it hard to be confident the change helped.

**Verified result** — required whenever the user asks for a number to report, commit, or share, when they gave you a hypothesis about what is slow, or when two profilers disagree. Follow `references/measurement-protocol.md` in full:

1. **Measure the ceiling before optimizing** — delete or hoist the suspected work, re-time end-to-end, and compute what fraction of total time it actually accounted for; profiler attribution has been observed to overstate it by more than 10x. (This removal-and-re-time step is called *ablation*, and is recorded as `adjudication_method: "removal_ablation"`.)
2. **Correctness gate** against the original in the same session, with a tolerance scaled to the output (`100*eps(max(abs(original(:))))`), plus an independent witness statistic of the output.
3. **Mutation test** — perturb the input; the output must change. Catches code that is fast because it stopped doing the work.
4. **Interleaved paired timing**, one session, N ≥ 5, `median(tb ./ to)`. Never compare across sessions or in sequential blocks — machine drift lands entirely on one arm.
5. **Write `perf_report.json`** — every field from a variable a run of the current code computed, never a typed-in literal. Run each step in its own tool call and `save` its results to a `.mat` as it finishes, so a fix to the report re-writes it from those files instead of re-running the steps.

The headline `speedup_median` is always end-to-end. A sub-kernel number goes in `kernel_speedup`. A refuted hypothesis is a result: report it with the honest speedup, including 1.0.

### Step 6: Verify Correctness

Every optimization must produce the same results as the original:

```matlab
original = originalFunction(input1, input2);
fast = optimizedFunction(input1, input2);

% Scale the tolerance to the output — a fixed 1e-10 is wrong in both directions
tol = 100 * eps(max(abs(original(:))));
maxErr = max(abs(original(:) - fast(:)));
fprintf('Max error: %.2e (tol %.2e)\n', maxErr, tol);
assert(isequal(isnan(original), isnan(fast)) && maxErr <= tol, 'Results differ beyond tolerance!');   % max skips NaN
```

For non-numeric outputs:
```matlab
assert(isequal(original, fast), 'Results differ!');
```

Error at or below `eps(max(abs(original(:))))` is floating-point reordering noise — acceptable; document it. Error orders of magnitude above it is a bug, however clean the algebra looked. Watch for **catastrophic cancellation**: an algebraically exact shortcut (e.g. the running-sums variance formula) can be dramatically faster and still wrong on data with a large mean offset. Subtract the mean first, then check the result against the tolerance again.

An error of exactly `0` proves nothing on its own. Also record an independent statistic of the optimized output (`min(fast(:))`, a checksum) — see `references/measurement-protocol.md`.

### Step 7: Report Results

Report the baseline, the optimized time, the speedup (for each change and end to end), the max error, and the pattern applied. If you followed the verified-result protocol in Step 5, `perf_report.json` is the deliverable and this is its human-readable summary.

## Key Rules

1. **Always profile before optimizing** — never guess where the bottleneck is
2. **Measure the ceiling before you optimize** — remove or hoist the suspect and re-time end-to-end; that difference, not the profiler's `%` column, is the ceiling on what a rewrite can win (this step is *ablation*)
3. **One change at a time** — measure after each optimization to know what helped
4. **Verify correctness** — every optimization must produce equivalent output, with a tolerance scaled to the output
5. **Report end-to-end** — the headline number is the whole workload; a sub-kernel speedup is reported separately and labelled as such
6. **Every reported number comes from a variable** — computed by a run of the current code, never typed in from memory
7. **1.2x threshold** — speedups below 1.2x are not reliably distinguishable from noise
8. **GPU timing** — always `wait(gpuDevice)` before and after timing GPU code
9. **Use `timeit`** — it handles warmup and averaging; avoid raw `tic/toc` for benchmarks
10. **On R2026a, `clear` what you profiled before you time anything** — code run under `profile` on R2026a stays ~100x slower for the rest of the session until you `clear` it, so a baseline taken after a profiled run flatters every "after" number. R2026a also has no Sampling Profiler.

## Common Mistakes

| Mistake | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| Growing arrays in loops | Each append copies the entire array | Preallocate before the loop |
| Vectorizing huge arrays blindly | May exceed memory | Use chunked processing for large data |
| Assuming faster = correct | Bugs can make code fast (by skipping work) | Verify results match (Step 6) + mutation test |
| Fixed `assert(maxErr < 1e-10)` | Rejects clean results on large-magnitude data; passes broken ones on small | Scale tolerance to the output: `100*eps(max(abs(original(:))))` |
| Quoting a sub-kernel speedup as the headline | 8x on 20% of runtime is ~1.2x end-to-end | Headline is end-to-end; kernel number reported separately |
| Manufacturing a win when the hypothesis was wrong | A refuted hypothesis is a valid result | Report `speedup_median` honestly, including 1.0 |

## Reference Files

- `references/measurement-protocol.md` — the verified-result protocol for Step 5 and every `perf_report.json` field
- `references/sampling-profiler.md` — Sampling Profiler (R2026b+): commands, results model, traps, and the `scripts/` helper index
- `references/optimization-patterns.md` — the pattern catalog, with before/after code and measured speedups
- `assets/measurement-templates.md` — templates for a `timeit` baseline, GPU timing, and a scaling test
- `scripts/` — MATLAB helpers for the Sampling Profiler; `addpath` this folder to use them

Copyright 2026 The MathWorks, Inc.
