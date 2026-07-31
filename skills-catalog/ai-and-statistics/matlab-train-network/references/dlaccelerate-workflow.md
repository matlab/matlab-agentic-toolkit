# dlaccelerate Diagnostic/Fix/Improve Workflow

Step-by-step process for diagnosing and fixing dlaccelerate tracing issues, and improving execution speed of deep learning workflows.

## How Tracing Works

`dlaccelerate` wraps a function and caches its execution trace. On the first call it records every operation and builds an optimized computation graph. On subsequent calls, if the signature matches a cached trace, the cached version is reused without re-executing the original code.

**Signature matching rules:**

| Input Type | What triggers a NEW trace |
|-----------|---------------------------|
| `dlarray` | Different size, format, or datatype (value changes are fine) |
| `dlnetwork` | Different learnable/state sizes, formats, or datatypes |
| Scalars, strings, other non-dlarray variables | ANY change in value (each unique value = new trace) |
| Function outputs | Different number of output arguments requested |

**Key insight:** dlarray values DON'T trigger re-tracing EXCEPT if their shape/type/format change, but non-dlarray values DO. This is the source of most performance bugs.

A non-dlarray input that is constant (same value every call) is perfectly safe — it produces exactly one cached trace. Only values that change between calls cause retracing. Do not defensively wrap constants as dlarray.

**Cache properties:** Default `CacheSize` is 50. `Occupancy` is a percentage (0–100) indicating how full the cache is. Each unique signature occupies one slot. `clearCache(accFcn)` forces re-tracing on next call.

## Step 0: Assess Whether dlaccelerate Applies

Before measuring or fixing, determine whether `dlaccelerate` is already in use or should be added.

**If the code already uses `dlaccelerate`** → proceed to Step 1.

**If `trainnet` with a custom loss function handle (R2026a+)** → see [dlaccelerate-trainnet-custom-loss.md](dlaccelerate-trainnet-custom-loss.md).

**If the code uses `dlfeval`/`dlgradient` WITHOUT `dlaccelerate`:**

1. Check the "Scenarios Where dlaccelerate Provides No Benefit" table below. If any scenario applies, stop and inform the user that dlaccelerate is not suitable here
2. Identify the function passed to `dlfeval` (typically the gradient/loss function)
3. Check these requirements before adding dlaccelerate:
   - No `extractdata` inside the function (would produce stale cached values, see Pattern 5 fix strategy in [dlaccelerate-antipatterns.md](dlaccelerate-antipatterns.md))
   - No data-dependent control flow inside `forward(net, x)` if a network is involved (check custom layers for `if`/`while`/`for`/`break`/`continue` on dlarray values)
   - Non-dlarray arguments that CHANGE between calls are wrapped as `dlarray` (constant non-dlarray arguments are safe as-is, they produce one trace)
   - Custom layers in the network inherit `nnet.layer.Acceleratable` (or accept fragmented acceleration)
   - If any check fails, fix the issue first. Do NOT wrap with dlaccelerate until all checks pass
4. Wrap it with `dlaccelerate`:
   ```matlab
   accFcn = dlaccelerate(@modelGradient);
   ```
5. Replace the `dlfeval` call to use the accelerated function:
   ```matlab
   [loss, gradients, state] = dlfeval(accFcn, net, X, T);
   ```
6. Scan the function for antipatterns in Step 1 before running and fix any obvious issues first
7. Proceed to Step 3 to verify acceleration works

## Step 1: Identify Breaking Patterns

Scan the traced function for antipatterns that cause retracing. See [dlaccelerate-antipatterns.md](dlaccelerate-antipatterns.md) for the full catalog with BAD/GOOD code examples.

| # | Pattern | What breaks | Quick fix |
|---|---------|-------------|-----------|
| 1 | Data-dependent branches | `if`/`switch` on dlarray values or `rand()`, branch baked into cache | Branch-free arithmetic: `min(t/norm, 1)` |
| 2 | Logical indexing with count-dependent ops | `mean`/`var`/`std`/`numel`/`size` on selection baked as constant | Mask-based: `sum(x.*mask,'all') / sum(mask,'all')` |
| 3 | Random numbers without tracing | `rand(sz)` without `'like'` becomes a constant | `rand(sz, 'like', x)` |
| 4 | Side effects | `disp`, `fprintf`, file I/O skipped after first trace | Move outside the traced function |
| 5 | `extractdata` inside traced function | Removes value from the trace, becomes stale constant | Try `stripdims` first; move outside `dlfeval` if not needed in accelerated function |
| 6 | Enclosing workspace variables | Captured as constants at trace time, stale if changed | Pass as explicit function inputs |
| 7 | Recreated anonymous function handles | Each new instance triggers retrace | Assign to a variable once, reuse |
| 8 | Variable-length sequence inputs | Different sizes = new trace per batch | See [dlaccelerate-variable-length-sequences.md](dlaccelerate-variable-length-sequences.md) |
| 9 | Custom layer without `Acceleratable` | Fragmented acceleration, multiple boundary crossings | See [dlaccelerate-custom-layers.md](dlaccelerate-custom-layers.md) |

**Note:** Patterns 6 and 7 are special cases of a general rule: non-dlarray inputs are matched by exact value/identity. This is only a problem when the value CHANGES between calls. Constant non-dlarray inputs (fixed hyperparameters, static strings, named function handles) are safe and should NOT be wrapped as dlarray.

## Step 2: Apply Fixes

Apply the matching fix patterns from Step 1. Safe patterns that need no fix:

- **Branching on constant non-dlarray inputs:** `if ~isinf(gradientThreshold)` is evaluated at trace time, correct if the value never changes between calls
- **Constant non-dlarray inputs** (scalars, strings, function handles assigned once): If the value never changes between calls, it produces one cached trace and is safe. Only wrap as `dlarray` if the value changes between calls.
- **`forward(net, x)` / `predict(net, x)` inside a traced function:** Network execution is compatible, **provided all custom layers in the network are trace-compatible** (no data-dependent control flow such as `if extractdata(...) < tol, break` inside their `predict`/`forward` methods). If a custom layer has data-dependent branches, the first branch path gets baked into the trace and subsequent calls with different paths silently produce wrong results.
- **`rand(sz, 'like', x)`:** With `x` being a dlarray, it is traced correctly because it's linked to a dlarray.
- **`sum(x.^2, 'all')`:** Format-safe reduction (assuming `x` being a dlarray)

## Step 3: Verify Acceleration

After applying fixes (or after adding `dlaccelerate` for the first time), verify with three checks. All three are required, skipping any one can hide a different type of bug.

**Check 1: HitRate and Occupancy** — confirm traces are being reused:

```matlab
accFcn = dlaccelerate(@myFunction);
clearCache(accFcn);

for i = 1:20
    x = ...;  % generate new inputs each iteration
    y = ...;
    result = dlfeval(accFcn, x, y);
    ...       % update network weights if applicable
end

fprintf('HitRate: %.1f%%\n', accFcn.HitRate);
fprintf('Occupancy: %.1f%%\n', accFcn.Occupancy);
```

Both are percentages (0–100). With default `CacheSize=50`, an Occupancy of 10% means 5 cached traces.

**Interpreting results:**

| Observation | Meaning |
|------------|---------|
| Occupancy stable, HitRate converging upward | Healthy |
| HitRate = 0% | Every call retraces (performance disaster) |
| Occupancy growing toward 100% | Inputs vary too much, cache filling with unique traces |
| HitRate declining over time | Growing number of unique signatures evicting each other |

- **Healthy:** Occupancy stops growing AND HitRate converges upward (normally >90%, but see [dlaccelerate-variable-length-sequences.md](dlaccelerate-variable-length-sequences.md) if using bucketed or variable-length inputs).
- **Unhealthy:** If HitRate stays low or Occupancy keeps growing, the software spends time creating new caches that do not get reused often. Revisit Step 1.

**Check 2: CheckMode** — confirm cached results are numerically correct:

```matlab
accFcn.CheckMode = "tolerance";
accFcn.CheckTolerance = 1e-4;
clearCache(accFcn);

for i = 1:20
    x = ...;
    y = ...;
    result = dlfeval(accFcn, x, y);
    ...       % update network weights if applicable
end

accFcn.CheckMode = "none";  % disable after verification
clearCache(accFcn);
```

If warnings appear ("Accelerated outputs differ from underlying function
outputs"), the function is NOT safe to accelerate — typically `extractdata`
inside the function produces stale cached values. See Pattern 5 in
[dlaccelerate-antipatterns.md](dlaccelerate-antipatterns.md).

**Why CheckMode is essential:** A function can show 90%+ HitRate yet produce
wrong outputs. HitRate only confirms the trace is reused, not that the reused
result is correct. For training loops, always include weight updates between
calls so CheckMode can detect stale-value bugs.

## Step 4: Measure Speedup

See [dlaccelerate-measure-speedup.md](dlaccelerate-measure-speedup.md) for the full benchmarking methodology (CPU and GPU timing, adaptive stopping, A/B via `accFcn.Enabled`). If tAccel > tBase, acceleration is harmful — return to Step 1.

## Step 5: Optimize Custom Training Loop Structure

If the code uses a custom training loop (manual `dlfeval`/`dlgradient` calls rather than `trainnet`), see [dlaccelerate-custom-training-loop.md](dlaccelerate-custom-training-loop.md) for strategies that maximize the accelerated boundary, including:
- 4 acceleration levels (model-only → full iteration including solver update)
- dlaccelerate-compatible L2 regularization and gradient clipping implementations
- Critical rules for wrapping iteration-varying inputs as `dlarray`

## Scenarios Where dlaccelerate Provides No Benefit

| Scenario | Reason |
|----------|--------|
| Input sizes change almost every call | Constant re-tracing, no speedup |
| Function has heavy side effects and requires them | Side effects lost after tracing |
| Function uses data-dependent control flow | Only one branch captured per trace |
| Very short functions (< 1ms) | Tracing overhead exceeds savings |
| `trainnet` with a built-in loss string or `minibatchpredict` | Redundant. trainnet and minibatchpredict handle it internally |
| Debugging / development | Hides errors, harder to step through |
| Very few iterations | Tracing cost may be greater than its performance benefit |
| Simulink export workflows (`exportNetworkToSimulink`, Predict block) | Different execution model, dlaccelerate does not apply |
| MEX/Coder/compilation workflows | Code generation has its own optimization path |
| `fitcnet` / `fitrnet` / `nlarx` models | These use different solvers and execution paths, not dlarray-based training |

### When dlaccelerate Doesn't Apply — Speed-Up Alternatives

**For custom training loops** (manual `dlfeval`/`dlgradient`), speed up without dlaccelerate by:

| Option | How |
|--------|-----|
| GPU training | Use `gpuArray` on input data, or `minibatchqueue(..., OutputEnvironment="gpu")` to send mini-batches to the GPU |
| Larger mini-batches | Increase batch size to improve GPU utilisation (try 2–4× current value) |
| Solver tuning | Increase `InitialLearnRate` with a decay schedule |

**For `trainnet` with a built-in loss string**, larger mini-batches and solver tuning still apply — configure via `trainingOptions`, plus:

| Option | How |
|--------|-----|
| GPU acceleration | `ExecutionEnvironment="gpu"` or `"auto"` |
| Background preprocessing | `PreprocessingEnvironment="background"` or `"parallel"` — fetches and preprocesses data asynchronously (stochastic solvers only, requires subsettable datastore) |

----

Copyright 2026 The MathWorks, Inc.
