# Function: `filloutliers`

> Used in: wf-repair-missing.md, wf-detrend-smooth-deoutlier.md
> Toolbox: MATLAB (base)

Detects outliers and replaces them in one call. Detection and fill are
decoupled: you pick the detector (`findmethod`) and, separately, the fill
rule (`fillmethod`). That decoupling is the whole point of the function.

By default an outlier is a value more than three scaled MAD from the median.
On a matrix, `filloutliers` operates column-wise; on a table/timetable, per
variable.

## Signature

```matlab
B = filloutliers(A, fillmethod)                          % detect (median) + fill
B = filloutliers(A, fillmethod, findmethod)              % choose detector
B = filloutliers(A, fillmethod, movmethod, window)       % local (Hampel) detector
B = filloutliers(A, fillmethod, "percentiles", [lo hi])
[B, TF, L, U, C] = filloutliers(___)                     % TF mask + thresholds/center
```

`fillmethod` (required, no default): a numeric scalar, or one of `"center"`,
`"clip"`, `"previous"`, `"next"`, `"nearest"`, `"linear"`, `"spline"`,
`"pchip"`, `"makima"`.

`findmethod` (default `"median"`): `"median"`, `"mean"`, `"quartiles"`,
`"grubbs"`, `"gesd"`. Or a moving detector `"movmedian"` / `"movmean"` (which
requires a `window`).

## Fill methods (the `fillmethod` argument)

| Fill | Replaces each outlier with |
|---|---|
| `"center"` | Center value from the detector (the local/global median for `"median"`/`"movmedian"`). Default-feeling, most readable. |
| `"clip"` | The nearer threshold value (lower threshold if below, upper if above). |
| `"linear"` / `"pchip"` / `"spline"` / `"makima"` | Interpolation across the outlier from neighboring non-outlier samples. Use when you want a smooth fill, not a flat local median. |
| `"previous"` / `"next"` / `"nearest"` | Nearest non-outlier value. |
| numeric scalar | That constant. |

## Detection methods (the `findmethod` argument)

| `findmethod` | When |
|---|---|
| `"median"` (default) | Robust; the threshold computation itself resists outliers. First reach. |
| `"movmedian"` (Hampel) | Signal is non-stationary (drifting baseline, changing variance). Requires a `window`. This is literally "the Hampel filter" per the doc. See fn-hampel.md when you also want the audit-trail outputs. |
| `"mean"` / `"movmean"` | Faster, less robust. Only for known-Gaussian data clean apart from the spikes. |
| `"quartiles"` | Non-Gaussian (skewed, heavy-tailed) distribution. |
| `"grubbs"` / `"gesd"` | Hypothesis-testing; `"gesd"` for multiple masking outliers. Niche. |

## The Hampel equivalence

`filloutliers(x, "center", "movmedian", 2*k+1, ThresholdFactor=nsigma)` is the
same algorithm as `hampel(x, k, nsigma)`. Reach for `filloutliers` when you
want control over the fill rule (e.g. `"linear"` instead of local median).
Reach for `hampel` when you want the outlier mask and local median/sigma back
for an audit trail. See fn-hampel.md.

## Skip detection when locations are known

If upstream logic already flagged the outliers, pass them as a mask and skip
detection entirely:

```matlab
B = filloutliers(x, "linear", OutlierLocations=mask);   % mask is logical, size(x)
```

## Name-value pairs

| NV-pair | Default | Purpose |
|---|---|---|
| `ThresholdFactor` | `3` (MAD/std methods), `1.5` (`"quartiles"`), `0.05` (`"grubbs"`/`"gesd"`) | Loosen or tighten detection. For `"median"`/`"movmedian"` this is the number of scaled MAD. |
| `SamplePoints` | `[1 2 3 ...]` | Sample-point vector; windows for moving methods are relative to it. Not supported for timetables (row times are used). |
| `OutlierLocations` | unset | Logical mask of known outliers; bypasses detection. Same size as `A`. |
| `DataVariables` | all `double`/`single` | Which table variables to operate on. |
| `MaxNumOutliers` | ~10% of elements | Cap for the `"gesd"` method only. |
| `ReplaceValues` | `true` | `false` appends filled variables instead of overwriting (table only). |
| `dim` | first non-singleton | Operate along rows (`2`) instead of columns. Not supported for tables. |

## Gotchas

- **`fillmethod` has no default** and comes first. `filloutliers(x)` is an
  error. Decide the fill rule before calling.
- **`"movmedian"` / `"movmean"` require a `window` argument** with no default.
  Pick a window larger than the typical spike but smaller than the slowest
  feature you want to preserve.
- **All detection changes non-outlier regions too** when the window is large
  or the threshold loose. Always take the `TF` output and check `nnz(TF)` is
  what you expected.
- **Column-wise on matrices.** Like `detrend`, `smoothdata`, and `hampel`. For
  row-wise pass `dim=2`.
- **Dense impulse noise defeats it.** Windowed detection needs a "normal"
  local majority; if the burst is >~10% of samples, the local median *is* the
  noise. Use `medfilt1` there instead (see fn-medfilt1.md).

## See also

- fn-hampel.md — same algorithm as `"movmedian"`, plus mask + local
  median/sigma outputs.
- fn-medfilt1.md — the denser-noise alternative (distorts clean samples).
- `isoutlier(x)` — detector only (returns the mask, no fill).

----

Copyright 2026 The MathWorks, Inc.

----
