---
name: matlab-design-adaptive-filter
description: >
  Design and implement adaptive filters using DSP System Toolbox System objects.
  Use when working with adaptive filtering, system identification, noise cancellation,
  echo cancellation, active noise control (ANC), channel equalization, inverse system
  identification, or adaptive prediction. Covers dsp.LMSFilter, dsp.RLSFilter,
  dsp.FilteredXLMSFilter, dsp.FrequencyDomainAdaptiveFilter, dsp.AffineProjectionFilter,
  dsp.BlockLMSFilter, dsp.AdaptiveLatticeFilter, dsp.FastTransversalFilter, maxstep(),
  and algorithm selection for adaptive filtering problems. Replaces deprecated
  adaptfilt.* objects (removed R2020a).
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2024b"
metadata:
  author: MathWorks
  version: "1.0"
---

# Adaptive Filtering

Implementation guideline — Use DSP System Toolbox System objects to implement adaptive filters. Do not implement manual weight-update loops.

## When to Use

- System identification — Model unknown FIR or IIR systems online
- Noise or interference cancellation — Recover signals from noise-corrupted measurement
- Echo cancellation — Suppress acoustic or line echo
- Active noise control — Feedforward ANC with secondary path
- Inverse system identification — Equalization and deconvolution
- Adaptive prediction — Linear prediction and speech coding
- Algorithm evaluation — Compare adaptive filter algorithm performance
- Migrating from deprecated `adaptfilt.*` objects — Replaced by `dsp.*Filter` System objects (removed in R2020a)
- Any task involving `dsp.LMSFilter`, `dsp.RLSFilter`, `dsp.FilteredXLMSFilter`, `dsp.FrequencyDomainAdaptiveFilter`, `dsp.AffineProjectionFilter`, or `maxstep()`

## When NOT to Use

- Static (non-adaptive) FIR/IIR filter design — Use `matlab-design-digital-filter`
- Kalman filtering or state estimation — Use Control System Toolbox
- Deep learning-based denoising — Use Deep Learning Toolbox
- Simulink adaptive filter blocks — Use when working in Simulink (different modeling workflow)

## Workflow

Every adaptive filtering task follows this five-step workflow:

### 1. Analyze the Problem

Before writing code, determine:
- **Topology** — System identification, inverse system identification, noise cancellation, ANC, or prediction?
- **Signal characteristics** — White or colored input? Stationary or time-varying?
- **Constraints** — Filter length, latency budget, computational cost, real-time?
- **Filter length** — Match or slightly exceed the unknown system order

### 2. Select Object and Method

Use the routing table to pick the right System object:

| Scenario | Object | Method/Config |
|----------|--------|---------------|
| General-purpose, white input | `dsp.LMSFilter` | `'Normalized LMS'` |
| Colored/correlated input | `dsp.AffineProjectionFilter` | `ProjectionOrder=4-8` |
| Fast convergence needed | `dsp.RLSFilter` | `ForgettingFactor=0.99` |
| Tracking time-varying system | `dsp.RLSFilter` | `ForgettingFactor=0.95-0.99` |
| Active noise control | `dsp.FilteredXLMSFilter` | Requires secondary path estimate |
| Long filters (>256 taps) | `dsp.FrequencyDomainAdaptiveFilter` | `'Constrained FDAF'` |
| Long filter + low latency | `dsp.FrequencyDomainAdaptiveFilter` | `'Partitioned constrained FDAF'` |
| Low-complexity (no multiplies) | `dsp.LMSFilter` | `'Sign-Data LMS'` or `'Sign-Sign LMS'` |

For detailed selection guidance, see [references/object-selection.md](references/object-selection.md).

### 3. Configure

**Step size (critical for stability):**

```matlab
lms = dsp.LMSFilter(Length=L, Method="Normalized LMS");
[muMax, muMaxMSE] = maxstep(lms, x);
lms.StepSize = 0.3 * muMaxMSE;
```

`maxstep()` is available only for:

- `dsp.LMSFilter` (Methods: `'LMS'`, `'Normalized LMS'`, `'Sign-Error LMS'`)
- `dsp.BlockLMSFilter`

For all other objects, see [references/maxstep-reference.md](references/maxstep-reference.md).

**Filter length:** Set to unknown system order + 1 (or slightly longer if order is uncertain).

### 4. Run in Streaming Loop

All adaptive filter System objects process data frame-by-frame:

```matlab
for k = 1:numFrames
    xFrame = x((k-1)*frameSize+1 : k*frameSize);
    dFrame = d((k-1)*frameSize+1 : k*frameSize);
    [y, err, wts] = lms(xFrame, dFrame);
end
```

In simulation, use `dsp.FIRFilter` or `dsp.IIRFilter` for the unknown system. These objects automatically maintain internal filter state across frames.

### 5. Verify Convergence and Extract Weights

Weight extraction differs by object and is a common source of errors:

| Object | Extraction Method |
|--------|-------------------|
| `dsp.LMSFilter` | Third output: `[y, e, w] = lms(x, d)` |
| `dsp.RLSFilter` | Property: `rls.Coefficients` |
| `dsp.FilteredXLMSFilter` | Property: `fxlms.Coefficients` (negated for ANC) |
| `dsp.FrequencyDomainAdaptiveFilter` | See [references/fdaf-filter.md](references/fdaf-filter.md) — partitioned vs non-partitioned differ |
| `dsp.AffineProjectionFilter` | Property: `ap.Coefficients` |

**Important:** `dsp.LMSFilter` does NOT have a `.Coefficients` property. The third output argument is the only way to access weights.

For full details, see [references/weight-extraction.md](references/weight-extraction.md).

## Key Functions

| Function/Object | Purpose | Toolbox |
|-----------------|---------|---------|
| `dsp.LMSFilter` | LMS/NLMS/Sign variants (5 methods) | DSP System Toolbox |
| `dsp.RLSFilter` | Recursive Least Squares (5 methods) | DSP System Toolbox |
| `dsp.AffineProjectionFilter` | Affine Projection (colored input) | DSP System Toolbox |
| `dsp.FilteredXLMSFilter` | Filtered-X LMS (ANC) | DSP System Toolbox |
| `dsp.FrequencyDomainAdaptiveFilter` | FDAF (long filters, 4 methods) | DSP System Toolbox |
| `dsp.BlockLMSFilter` | Block LMS (frame-based) | DSP System Toolbox |
| `dsp.AdaptiveLatticeFilter` | Lattice (numerical stability) | DSP System Toolbox |
| `dsp.FastTransversalFilter` | Fast transversal (O(*N*) RLS) | DSP System Toolbox |
| `maxstep()` | Maximum stable step size | DSP System Toolbox |
| `msesim()` | Simulated MSE learning curves | DSP System Toolbox |

## Patterns

### System Identification

```matlab
unknownSys = dsp.FIRFilter(Numerator=fir1(31, 0.4));
lms = dsp.LMSFilter(Length=32, Method="Normalized LMS");
[muMax, muMaxMSE] = maxstep(lms, randn(1000, 1));
lms.StepSize = 0.3 * muMaxMSE;

for k = 1:numFrames
    xFrame = randn(frameSize, 1);
    dFrame = unknownSys(xFrame);
    [~, ~, wts] = lms(xFrame, dFrame);
end
```

### Active Noise Control (Two-Stage)

```matlab
% Stage 1: Estimate the secondary path
estFilter = dsp.LMSFilter(Length=secPathLen, Method="Normalized LMS");
[~, ~, secPathEst] = estFilter(probeSignal, secPathOutput);

% Stage 2: Configure the FxLMS controller
fxlms = dsp.FilteredXLMSFilter(Length=ctrlLen, ...
    SecondaryPathCoefficients=secPathTrue, ...
    SecondaryPathEstimate=secPathEst.');
[y, e] = fxlms(reference, errorMic);
```

See [references/fxlms-filter.md](references/fxlms-filter.md) for the full ANC workflow.

### Low-Latency Long Filter (Partitioned FDAF)

Use partitioned FDAF when you need a long adaptive filter with low processing latency.

```matlab
fdaf = dsp.FrequencyDomainAdaptiveFilter( ...
    Length=2048, ...
    BlockLength=128, ...
    Method="Partitioned constrained FDAF", ...
    StepSize=0.5);

for k = 1:numBlocks
    xBlock = x((k-1)*128+1 : k*128);
    dBlock = d((k-1)*128+1 : k*128);
    [y, e] = fdaf(xBlock, dBlock);
end
% Latency = BlockLength/fs = 128/16000 = 8 ms
```

See [references/fdaf-filter.md](references/fdaf-filter.md) for method strings and FFTCoefficients extraction.

### Freeze Adaptation (Stop Learning, Keep Filtering)

```matlab
% dsp.LMSFilter — use AdaptInputPort
lms = dsp.LMSFilter(Length=32, AdaptInputPort=true);
adaptFlag = true;
for k = 1:numFrames
    if k > freezeFrame, adaptFlag = false; end
    [y, e, w] = lms(xFrame, dFrame, adaptFlag);
end
```

For `dsp.FrequencyDomainAdaptiveFilter`, use `LockCoefficients` instead. This object does not support `AdaptInputPort`. See [references/fdaf-filter.md](references/fdaf-filter.md).

## Conventions

- **Always** use `dsp.*Filter` System objects — Never implement weight-update loops manually
- **Always** call `maxstep()` for step size when available (LMS, NLMS, Sign-Error, BlockLMS)
- **Always** use `AdaptInputPort=true` for freeze/adapt control — Never wrap in if/else
- **Always** use `dsp.FIRFilter` for unknown system simulation — It maintains state across frames
- **Never** access `.Coefficients` on `dsp.LMSFilter` — It doesn't exist; use third output
- **Never** access `.Coefficients` on `dsp.FrequencyDomainAdaptiveFilter` — Use `.FFTCoefficients` + IFFT
- **Never** use `adaptfilt.*` functions (`adaptfilt.lms`, `adaptfilt.nlms`, `adaptfilt.rls`, etc.) — The entire package was removed in R2020a and will error. Always use `dsp.*Filter` System objects.
- **Prefer** `'Normalized LMS'` over `'LMS'` as the default method — Robust to input power variations
- **Prefer** `'Constrained FDAF'` over `'Unconstrained FDAF'` — Prevents spectral leakage

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|------------------|
| Manual LMS loop (`w = w + mu*e*x`) | Error-prone, no state management, no optimized C code | Use `dsp.LMSFilter` with the appropriate Method |
| Hardcoded step size without stability check | May diverge or converge too slowly | Call `maxstep()` and use 30% of `muMaxMSE` |
| `filter(h, 1, x)` per frame without state | Breaks continuity at frame boundaries | Use `dsp.FIRFilter` (manages state internally) |
| `lms.Coefficients` | Property does not exist for `dsp.LMSFilter` | Use third output: `[y, e, w] = lms(x, d)` |
| `fdaf.Coefficients` | Property does not exist for FDAF | Use `real(ifft(fdaf.FFTCoefficients))` |
| `'Constrained FDAF'` with BlockLength < Length | Silently runs but does NOT partition | Must use `'Partitioned constrained FDAF'` |
| Standard LMS for ANC (ignoring secondary path) | Diverges — gradient is misaligned | Use `dsp.FilteredXLMSFilter` |
| `maxstep()` on Sign-Data or Sign-Sign LMS | Throws error — unsupported | Tune `StepSize` empirically (start small, e.g., 0.005) |
| Calling `maxstep()` on `dsp.RLSFilter` | Function does not exist for RLS | RLS uses `ForgettingFactor`, not step size |
| Sign-based LMS with default zero weights | `sign(0)=0` stalls adaptation permanently | Set `InitialConditions` to small nonzero values |
| Using `adaptfilt.*` (lms, nlms, rls, etc.) | **Entire package removed in R2020a**; code will not run | Replace with `dsp.LMSFilter`, `dsp.RLSFilter`, etc. |

## References

- [Object Selection Guide](references/object-selection.md) — Full decision matrix
- [dsp.LMSFilter](references/lms-filter.md) — methods, maxstep, AdaptInputPort, weights
- [dsp.RLSFilter](references/rls-filter.md) — ForgettingFactor, methods, coefficients
- [dsp.FilteredXLMSFilter](references/fxlms-filter.md) — ANC workflow, secondary path properties
- [dsp.FrequencyDomainAdaptiveFilter](references/fdaf-filter.md) — Partitioned mode, FFTCoefficients
- [Other Filters](references/other-filters.md) — AP, BlockLMS, Lattice, FTF
- [Weight Extraction](references/weight-extraction.md) — per-object coefficient access
- [maxstep Reference](references/maxstep-reference.md) — Compatibility and fallbacks

----

Copyright 2026 The MathWorks, Inc.

----
