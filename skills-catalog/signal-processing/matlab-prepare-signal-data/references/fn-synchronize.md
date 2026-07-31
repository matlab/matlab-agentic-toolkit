# Function: `synchronize`

> Used in: wf-align-channels.md
> Toolbox: MATLAB (base) — timetable method

The one-shot merge primitive for bringing several timetables onto a shared
time base.
It collects the variables from all input timetables, builds a common time
vector, adjusts each variable onto it, and returns a single timetable.

Reach for `synchronize` whenever you have two or more timetables at different
rates or offsets that need to become one aligned table.
Do not hand-orchestrate `retime` per channel and then concatenate — that is
the multi-step path `synchronize` collapses into one call.

## Signature

```matlab
TT = synchronize(TT1, TT2)                                  % union of times, no interpolation
TT = synchronize(TT1, TT2, newTimeBasis, method)            % common basis + adjust rule
TT = synchronize(TT1, TT2, newTimeStep, method)             % 'hourly', 'daily', ...
TT = synchronize(TT1, TT2, 'regular', method, 'SampleRate', Fs)
TT = synchronize(TT1, TT2, 'regular', method, 'TimeStep', dt)
TT = synchronize(TT1, TT2, newTimes, method)                % explicit target time vector
TT = synchronize(TT1, ..., TTN, ___)                        % N timetables at once
```

`newTimeBasis` picks where the common row times come from:

| `newTimeBasis` | Common time vector is | Use when |
|---|---|---|
| `'union'` (default) | every distinct time across all inputs | you want to keep all samples and fill the rest |
| `'intersection'` | only times present in every input | you want rows that already line up, no interpolation |
| `'commonrange'` | inputs' overlapping span, at union times inside it | you want the overlap only, dropping non-overlapping tails |
| `'first'` | `TT1`'s row times | you want everything on the first table's grid |
| `'last'` | `TTN`'s row times | you want everything on the last table's grid |
| `'regular'` | a uniform grid (needs `SampleRate` or `TimeStep`) | you want a clean uniform output rate |

`method` is the adjustment rule applied to each variable at the new times.
Same vocabulary as `retime` (see fn-retime.md): `'fillwithmissing'` (default
when no method given), `'linear'`, `'spline'`, `'pchip'`, `'makima'`,
`'previous'`, `'next'`, `'nearest'`, plus aggregation rules (`'mean'`,
`'sum'`, ...) and `'fillwithconstant'`.

## Name-value pairs

| NV-pair | Default | Purpose |
|---|---|---|
| `EndValues` | `'extrap'` | Extrapolation rule for interpolation methods. `'extrap'` extends the trend past the data (can invent values); set to a scalar to clip instead. |
| `Constant` | — | Fill value when `method` is `'fillwithconstant'`. |
| `IncludedEdge` | `'left'` | Which bin edge is included when aggregating. |

## The default is fill-with-missing, not interpolation

`synchronize(TT1, TT2)` with **no method** uses the union of times and
inserts `NaN` (or `NaT`/`<undefined>`) wherever a variable has no sample.
It does not interpolate.

```matlab
TT = synchronize(A, B);          % union grid, NaNs at non-overlapping times
```

This is the honest default — it never fabricates values.
It also means align typically **creates missing data** at times where one
channel has no sample, so it precedes a fill step.
See wf-repair-missing.md for the fill that follows.

To adjust onto the grid instead of NaN-filling, pass a method:

```matlab
TT = synchronize(A, B, 'first', 'linear');   % B interpolated onto A's times
```

## Gotchas

- **No method = NaN fill.** If you expected interpolated values and got NaNs, you omitted the `method` argument. The two-argument form never interpolates.
- **`'linear'` extrapolates by default.** With `EndValues='extrap'` (the default), a channel that starts later than the common grid gets values extended backward past its first real sample. Pass `EndValues=NaN` (or a scalar) to refuse extrapolation, then fill deliberately.
- **`'union'` keeps every time from every input** — the output can be much longer than any single input and mostly NaN before filling. Use `'first'`/`'last'`/`'regular'` when you want a controlled grid size.
- **Row times must be sorted and unique per input.** Duplicate times need a resolution rule; `synchronize` errors otherwise. Deduplicate with `retime`/`unique` first.
- **All inputs must use the same time type** (all `duration`, or all `datetime`). Mixed `duration`/`datetime` inputs error.

## See also

- fn-retime.md — the single-timetable sibling. `synchronize` is essentially `retime` applied across several tables at once, plus the merge.
- fn-resample.md — for antialiased rate conversion of a signal (not a timetable merge).
- wf-align-channels.md — the end-to-end alignment workflow.
- wf-repair-missing.md — the fill step that follows a NaN-producing align.

----

Copyright 2026 The MathWorks, Inc.

----
