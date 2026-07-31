# Function: `hampel`

> Used in: wf-detrend-smooth-deoutlier.md
> Toolbox: Signal Processing Toolbox

Sliding-window outlier detector-and-replacer. For each sample it computes the
median of a window (the sample plus `k` neighbors per side) and estimates the
local standard deviation from the median absolute deviation. A sample more
than `nsigma` local standard deviations from the local median is replaced with
that median.

SPT-only. Use it when you want the same result as
`filloutliers(..., "movmedian")` *plus* the outlier mask and local statistics.

On a matrix, each column is an independent channel.

## Signature

```matlab
y = hampel(x)                              % k=3 (window 7), nsigma=3
y = hampel(x, k)                           % window = 2*k+1
y = hampel(x, k, nsigma)
[y, j] = hampel(___)                       % j = logical outlier mask
[y, j, xmedian, xsigma] = hampel(___)      % local median + local sigma
hampel(___)                                % no output: plots signal + flagged outliers
```

## Arguments

| Argument | Default | Purpose |
|---|---|---|
| `k` | `3` | Neighbors per side. Window length is `2*k+1` (so default is 7). |
| `nsigma` | `3` | A sample must differ from the local median by more than `nsigma` local standard deviations to be flagged. |

## Outputs (the audit trail)

| Output | What it is |
|---|---|
| `y` | Filtered signal (outliers replaced with local median). |
| `j` | Logical mask, same size as `x`, true at flagged outliers. |
| `xmedian` | Local median at every sample. |
| `xsigma` | Estimated local standard deviation at every sample. |

The `[y, j, xmedian, xsigma]` outputs are the reason to pick `hampel` over
`filloutliers`: you get the flagged locations and the local median/sigma
bands, which plot directly as detection thresholds.

## Relationship to `filloutliers`

`hampel(x, k, nsigma)` is the same algorithm as:

```matlab
filloutliers(x, "center", "movmedian", 2*k+1, ThresholdFactor=nsigma)
```

The doc names the `"movmedian"` method "the Hampel filter." Choose between
them on outputs, not on the underlying math:

- Want a smooth interpolated fill instead of local median? `filloutliers`
  with `"linear"`/`"pchip"`. See fn-filloutliers.md.
- Want the mask and local statistics for an audit trail? `hampel`.

## Gotchas

- **Default window is only 7 samples** (`k=3`). At `fs=1 kHz` that is 7 ms,
  too short for many physiological signals. Bump `k` to roughly `fs/100` or
  `fs/50` for a 10-20 ms window.
- **Endpoints use a truncated window.** Samples within `k` of the edge are
  compared to a smaller window; the doc shows they can be flagged as outliers
  more readily. Inspect the ends of `j`.
- **Column-wise on matrices.** Each column is an independent channel; expect
  per-channel behavior.
- **Sparse spikes only.** Like `filloutliers`, it needs a normal local
  majority. For dense impulse noise (>~10% of samples) use `medfilt1`
  (fn-medfilt1.md).
- **Handles NaN in the window** but does not target NaN gaps. To fill missing
  samples, that is fn-fillmissing.md / fn-fillgaps.md, not `hampel`.

## See also

- fn-filloutliers.md — same algorithm, control over the fill rule.
- fn-medfilt1.md — the dense-noise alternative.
- `isoutlier(x, "movmedian", win)` — detection mask only, no fill.

----

Copyright 2026 The MathWorks, Inc.

----
