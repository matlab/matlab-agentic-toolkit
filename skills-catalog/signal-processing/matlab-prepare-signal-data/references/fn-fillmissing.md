# Function: `fillmissing`

> Used in: wf-repair-missing.md
> Toolbox: MATLAB (base)

Fills missing entries (NaN for numeric/duration, NaT for datetime,
`<missing>` for string, etc.) using an interpolation or moving-window method.
This is the interpolation-based filler: it draws each fill value from
neighboring non-missing samples. For long gaps in oscillatory signals where
interpolation would inject spurious low-frequency content, use `fillgaps`
(AR-model) instead. See fn-fillgaps.md and wf-repair-missing.md.

On a matrix, operates column-wise; on a table/timetable, per variable.

## Signature

```matlab
F = fillmissing(A, method)                       % method REQUIRED, no default
F = fillmissing(A, "constant", v)
F = fillmissing(A, movmethod, window)            % "movmean" / "movmedian"
F = fillmissing(A, "knn")  |  fillmissing(A, "knn", k)
F = fillmissing(A, fillfun, gapwindow)           % custom function handle
F = fillmissing(___, dim)
[F, TF] = fillmissing(___)                        % TF = logical mask of filled entries
```

## Fill methods (the `method` argument)

| `method` | What it does |
|---|---|
| `"linear"` | Linear interpolation of neighbors. Honest; no invented curvature. Good when downstream is time-domain (statistics, plotting). |
| `"pchip"` | Shape-preserving cubic. No overshoot. Defensible default for short gaps in a smooth signal. |
| `"spline"` | Cubic spline. Can overshoot at gap edges. |
| `"makima"` | Modified Akima cubic. Shape-preserving, smoother than pchip. |
| `"nearest"` / `"previous"` / `"next"` | Nearest / previous / next non-missing value. |
| `"movmean"` / `"movmedian"` | Moving-window average / median (needs a `window`). |
| `"constant"` | A supplied scalar/vector `v`. |
| `"knn"` / `"knn", k` | Nearest-neighbor rows by Euclidean distance (matrix/table). |
| function handle | Custom fill over a `gapwindow` (see below). |
| `"mean"` / `"median"` / `"mode"` | Global statistic. *Since R2026a.* |

## Name-value pairs

| NV-pair | Default | Purpose |
|---|---|---|
| `MaxGap` | unfilled cap = none | Refuse to fill any gap wider than this (relative to `SamplePoints`). Use it to gate interpolation so wide gaps stay NaN instead of being fabricated. |
| `SamplePoints` | `[1 2 3 ...]` | Sample-point vector; interpolation and windows are relative to it. Not supported for timetables (row times are used) or `"knn"`. |
| `EndValues` | same as `method` | How to handle leading/trailing missing values. `"nearest"` clamps to the boundary value instead of extrapolating. |
| `MissingLocations` | auto by data type | Logical mask of non-standard missing values (e.g. treat `-99` as missing). *Since R2024a.* |
| `dim` | first non-singleton | Fill across rows (`2`) instead of columns. Not supported for tables. |
| `Distance` | Euclidean | Custom distance for `"knn"`. |

## Custom fill over a gap window

```matlab
F = fillmissing(A, @(xs, ts, tq) myfun(xs, ts, tq), gapwindow, SamplePoints=t);
```

The handle receives `xs` (surrounding sample values), `ts` (their locations),
and `tq` (the missing locations). The escape hatch for logic like
"forward-fill, but only within N samples of the gap."

## Gotchas

- **No method default.** `fillmissing(x)` is an error. The method is a
  required argument; pick it deliberately (usually `"linear"` or `"pchip"`).
- **Endpoints extrapolate by default.** Leading/trailing gaps use the same
  method, which can extrapolate poorly. Set `EndValues="nearest"` to clamp.
- **Wide gaps are silently interpolated** unless you set `MaxGap`. A 500-sample
  linear fill across a real dropout is a fabricated ramp. Use `MaxGap` to
  refuse, and disclose any gap you do fill.
- **Interpolation kills tones in long gaps.** In an oscillatory signal a
  smooth fill flattens the oscillation across the gap and adds a spurious
  low-frequency bump to the spectrum. If downstream is FFT/PSD and the gap is
  wider than ~half a cycle of the lowest frequency, use fn-fillgaps.md.

## See also

- fn-fillgaps.md — AR-model filler for long gaps in oscillatory signals.
- wf-repair-missing.md — the `fillmissing` (interp) vs `fillgaps` (AR)
  decision, end to end.
- `interp1` — general resampling onto an arbitrary output grid; `retime` for
  timetables.

----

Copyright 2026 The MathWorks, Inc.

----
