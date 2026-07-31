# Function: `smoothdata`

> Used in: wf-detrend-smooth-deoutlier.md
> Toolbox: MATLAB (base)

The dispatcher for smoothing. One function, eight methods, an auto-window
heuristic. This is the default first reach for "make the signal less wiggly"
whenever you cannot name a cutoff frequency in Hz (if you can, use `lowpass`
instead).

`smoothdata` covers the common cases directly. Reach for `sgolayfilt`
(fn-sgolayfilt.md) only as the escape hatch: when you need a polynomial order
other than 2, or you want the filter's derivative output. For everything else
`smoothdata` is the more honest choice because you are not pretending to know
a frequency cutoff.

## Signature

```matlab
B = smoothdata(A)                       % "movmean", auto window
B = smoothdata(A, dim)
B = smoothdata(A, method)
B = smoothdata(A, method, window)
B = smoothdata(A, method, window, nanflag)
[B, winsize] = smoothdata(___)          % returns the window it chose
B = smoothdata(___, Name=Value)
```

## Methods (the `method` argument)

| Method | What it does | When |
|---|---|---|
| `"movmean"` (default) | Moving average. Hard-edged, reduces periodic trends. | Boring, defensible, no special story. |
| `"movmedian"` | Moving median. Robust to outliers; mean is not. | Outliers still in the signal that you did not pre-clean. |
| `"gaussian"` | Gaussian-weighted moving average. Smoother in the derivative than `movmean`. | Want a smooth result without hard window edges. |
| `"lowess"` | Local linear regression over each window. | **Trend extraction** - captures the slow component (see detrend use below). |
| `"loess"` | Local quadratic regression. | Trend with local curvature; slightly more expensive than lowess. |
| `"rlowess"` / `"rloess"` | Robust variants of lowess/loess. | Same as above but outlier-robust, at a speed cost. |
| `"sgolay"` | Savitzky-Golay (degree 2 by default). | Peak shapes matter. For degree != 2 or derivatives, use fn-sgolayfilt.md instead. |

## Name-value pairs / arguments

| Argument | Default | Purpose |
|---|---|---|
| `window` (positional) | auto (heuristic) | Window size. Scalar = centered length; `[b f]` = b preceding + current + f succeeding samples. `duration` when sample points are datetime/duration. |
| `nanflag` | `"omitmissing"` | Default **ignores** NaN. `"includenan"` makes any-NaN-in-window produce NaN (rarely wanted). |
| `SmoothingFactor` | `0.25` | Scales the auto window when `window` is not given. Near 0 = small window (less smoothing), near 1 = large. Cannot be combined with an explicit `window`. |
| `Degree` | `2` | Savitzky-Golay polynomial degree - only valid with `"sgolay"`. Must be less than the window size. |
| `SamplePoints` | `[1 2 3 ...]` | x-axis locations; windows are defined relative to these. Not for timetables (they use row times). |
| `DataVariables` | all numeric | Which table/timetable variables to smooth. |
| `ReplaceValues` | `true` | `false` appends smoothed variables instead of replacing (table/timetable only). |

## Using `smoothdata` for detrending

`"lowess"` / `"loess"` **estimate** a local trend - they do not subtract it.
To detrend a signal whose drift is non-stationary (no single polynomial fits),
estimate the trend and subtract it manually:

```matlab
trend = smoothdata(x, "lowess", win);   % local linear trend estimate
xd    = x - trend;                       % detrended signal
```

This is the alternative to `detrend(x, n)` when the drift shape varies across
the record. See fn-detrend.md for the polynomial path and when to prefer it.

## Verify the auto-chosen window

When you do not pass `window`, `smoothdata` picks one from a heuristic tied to
`SmoothingFactor` (it targets attenuating ~100*factor percent of the input
energy). Capture the choice so it is not a mystery:

```matlab
[B, winsize] = smoothdata(x, "gaussian");   % winsize tells you what it used
```

## Gotchas

- **NaN is ignored by default** (`"omitmissing"`). If you need NaN to
  propagate through the window, pass `"includenan"` explicitly.
- **`SmoothingFactor` and `window` are mutually exclusive.** Pass one or the
  other, not both.
- **`"movmean"` has hard window edges; `"gaussian"` is smoother** in the
  derivative. If a downstream step differentiates the signal, prefer gaussian.
- **`Degree` only applies to `"sgolay"`.** For a non-default polynomial order
  or for derivative output, `smoothdata` is the wrong tool - use
  fn-sgolayfilt.md, which exposes both directly.
- **Operates column-wise on matrices** by default; pass `dim` for row-wise.

## See also

- fn-sgolayfilt.md — the escape hatch for non-default polynomial order or
  derivative output.
- `lowpass` — use instead when you can name a cutoff frequency in Hz.
- fn-detrend.md — polynomial detrending; `smoothdata("lowess")` is the
  non-stationary-drift alternative.
- wf-detrend-smooth-deoutlier.md — where smoothing sits in the recipe.

----

Copyright 2026 The MathWorks, Inc.

----
