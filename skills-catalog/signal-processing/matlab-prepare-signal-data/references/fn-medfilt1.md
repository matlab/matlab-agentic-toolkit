# Function: `medfilt1`

> Used in: wf-detrend-smooth-deoutlier.md
> Toolbox: Signal Processing Toolbox

One-dimensional median filter. Every output sample is the median of an
`n`-sample window around it. This is a **denoiser, not an outlier tool**: it
replaces every sample, distorting clean samples along with corrupted ones. It
belongs in the outlier discussion only as the escape hatch for *dense* impulse
noise, where windowed outlier detection breaks down.

On a matrix, it filters each column.

## Signature

```matlab
y = medfilt1(x)                                  % n=3
y = medfilt1(x, n)                               % nth-order median filter
y = medfilt1(x, n, [], dim)                      % operate along dim
y = medfilt1(___, nanflag, padding)              % NaN + edge handling
```

## Arguments

| Argument | Default | Purpose |
|---|---|---|
| `n` | `3` | Filter order. For odd `n`, `y(k)` is the median of `x(k-(n-1)/2 : k+(n-1)/2)`. For even `n`, it averages the two middle sorted values. Larger `n` = more smoothing = more clean-sample distortion. |
| `dim` | first non-singleton | Dimension to filter along. Pass `medfilt1(x, n, [], 2)` for row-wise. The `blksz` slot before `dim` is legacy and ignored (pass `[]`). |
| `nanflag` | `'includenan'` | `'includenan'` makes any window containing NaN produce NaN. `'omitnan'` computes the median of the non-NaN values instead. |
| `padding` | `'zeropad'` | `'zeropad'` treats the signal as 0 beyond the ends (biases end samples toward 0). `'truncate'` computes medians of shorter end-segments instead. |

## Why it is the dense-noise escape hatch

`medfilt1` sidesteps outlier *detection* entirely: it median-filters every
sample, accepting the distortion of clean samples as the price. That is exactly
what you want when impulse noise is dense enough that windowed detectors break
down - a `filloutliers`/`hampel` window needs a normal majority to estimate a
clean local median, and when the burst dominates the window, the local median
*is* the noise and detection fails.

The sparse-vs-dense choice between this and the windowed detectors (and the
density threshold that separates them) is the workflow decision - see
wf-detrend-smooth-deoutlier.md (Step 1).

## Gotchas

- **Not an outlier remover.** It has no detection step and no threshold. It
  median-filters every sample regardless of whether it was an outlier. Do not
  reach for it to clean a few spikes out of an otherwise-clean signal.
- **Default zero padding biases the endpoints.** The first/last `n/2` samples
  are pulled toward 0. Use `medfilt1(x, n, [], 1, "omitnan", "truncate")` to
  compute shorter-segment medians at the edges instead.
- **NaN defaults to propagating** (`'includenan'`): any window covering a NaN
  gap returns NaN, widening the gap. Pass `'omitnan'` to median the non-NaN
  values, or fill gaps first (fn-fillmissing.md / fn-fillgaps.md).
- **Distorts peak shapes.** Median filtering flattens narrow peaks. If peak
  shape matters, use `sgolayfilt` (Savitzky-Golay) instead.

## See also

- fn-filloutliers.md / fn-hampel.md — the sparse-spike alternatives that only
  touch flagged samples.
- `sgolayfilt` — shape-preserving smoother when peaks matter.
- `median` / `movmedian` — the underlying statistic as a primitive.

----

Copyright 2026 The MathWorks, Inc.

----
