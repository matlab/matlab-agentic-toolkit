# Function: `retime`

> Used in: wf-uniform-rate.md, wf-align-channels.md
> Toolbox: MATLAB (base) — timetable method

Resample or aggregate the data in a **single** timetable onto a new set of
row times.
Use it to put one timetable onto a uniform grid, change its rate, or move it
onto an explicit time vector.

For merging several timetables onto a shared time base, use `synchronize`
(fn-synchronize.md) — `retime` operates on one table at a time.

## Signature

```matlab
TT2 = retime(TT1, newTimeStep, method)                     % 'hourly', 'daily', ...
TT2 = retime(TT1, 'regular', method, 'SampleRate', Fs)     % uniform at Fs
TT2 = retime(TT1, 'regular', method, 'TimeStep', dt)       % uniform at spacing dt
TT2 = retime(TT1, newTimes, method)                        % explicit target time vector
TT2 = retime(TT1, ___)                                     % method omitted -> fillwithmissing
```

`method` selects how each variable is adjusted at the new times.

### Interpolating / carrying methods (upsampling, arbitrary times)

| `method` | Behavior | Reach for when |
|---|---|---|
| `'linear'` | Linear interpolation | Default first reach. Signal is smooth, no invented bandwidth. |
| `'pchip'` | Shape-preserving cubic | You want smoothness without linear kinks; no overshoot. |
| `'spline'` | Cubic spline | Signal is known-smooth (physical model); tolerate edge overshoot. |
| `'makima'` | Modified Akima | Smoother than pchip, still shape-preserving; fewer oscillations than spline. |
| `'previous'` / `'next'` | Hold the previous / next sample | Zero-order hold; signal is a held setting (throttle, valve state). |
| `'nearest'` | Nearest sample in time | Categorical or quantized data where interpolation is meaningless. |
| `'fillwithmissing'` (default) | Insert `NaN` at new times | You want the grid changed but no values fabricated. |
| `'fillwithconstant'` | Insert a constant (`Constant` NV) | You have a known default for absent samples. |

### Aggregating methods (downsampling into bins)

`'mean'`, `'sum'`, `'prod'`, `'min'`, `'max'`, `'median'`, `'mode'`,
`'firstvalue'`, `'lastvalue'`, `'count'` — each new time is a bin, and the
rule collapses the samples that fall in it.
Use these when the new rate is **coarser** than the input (many samples per
new time), not when interpolating up.

## Name-value pairs

| NV-pair | Default | Purpose |
|---|---|---|
| `EndValues` | `'extrap'` | Extrapolation rule for interpolation methods. `'extrap'` extends past the data; a scalar clips to that value at the ends. |
| `Constant` | — | Fill value when `method` is `'fillwithconstant'`. |
| `IncludedEdge` | `'left'` | Bin edge included when aggregating (`'left'` or `'right'`). |

## Rule selection is the whole decision

**Pick the right adjust method.** The split:

- **Upsampling / arbitrary new times -> interpolating method.** Choose by signal character: `'linear'` unless you can justify smoothness (`'pchip'`/`'makima'`) or a held value (`'previous'`).
- **Downsampling -> aggregating method.** `'mean'` decimates with averaging; `'lastvalue'` takes a snapshot. Do not use an interpolating method to downsample — it ignores the samples between grid points.

## Gotchas

- **Method omitted = `fillwithmissing`.** `retime(TT, newTimes)` with no method inserts `NaN`, it does not interpolate. Same trap as `synchronize`.
- **`'linear'` extrapolates by default** (`EndValues='extrap'`). New times outside the input span get extended trend values. Pass `EndValues=NaN` to refuse.
- **Interpolating to a coarser grid loses information.** If the new spacing is wider than the input, an interpolating method samples the curve at the new times and silently drops everything between — use an aggregation rule instead.
- **No antialiasing — do not use `retime` to downsample a signal.** Interpolating (or even aggregating) onto a coarser grid does not run an anti-alias filter, so real bandwidth folds back into the band silently. For any genuine rate *reduction* of signal content, use `resample` / `decimate` (fn-resample.md); reserve `retime` for regularizing jitter or upsampling.
- **`'regular'` needs a rate.** `retime(TT,'regular',method)` alone errors; supply `'SampleRate'` or `'TimeStep'`.
- **Duplicate or unsorted row times** must be resolved first; `retime` errors on duplicates unless the method is an aggregation rule that bins them.

## See also

- fn-synchronize.md — the multi-timetable sibling (same method vocabulary, merges several tables).
- fn-resample.md — antialiased rate conversion for a signal / timetable; use when you need the FIR antialiasing filter, not plain interpolation.
- wf-uniform-rate.md — non-uniform timestamps to a uniform grid.
- wf-align-channels.md — bringing multi-rate channels together.

----

Copyright 2026 The MathWorks, Inc.

----
