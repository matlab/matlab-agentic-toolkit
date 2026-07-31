# Function: `detrend`

> Used in: wf-detrend-smooth-deoutlier.md
> Toolbox: MATLAB (base)

Removes a best-fit polynomial trend from data.
The degree argument `n` is the whole story: `n=0` removes the mean, `n=1`
removes a straight-line trend, `n=2` a quadratic, `n=3` a cubic, and so on.

When the drift genuinely is a polynomial, `detrend(x, n)` removes it exactly
and has unity passband gain (it does not touch the signal band). That is the
reason to prefer it over `highpass` whenever the drift has a describable
smooth shape. `highpass` is the frequency-domain alternative when the drift
band is well below the signal band but its shape is not describable.

## Signature

```matlab
D = detrend(A)                        % n = 1 (linear) by default
D = detrend(A, n)                     % n-th degree polynomial
D = detrend(A, n, bp)                 % piecewise trend with breakpoints
D = detrend(___, nanflag)             % "omitnan" to ignore NaN in the fit
D = detrend(___, Name=Value)
```

`n` is a nonnegative integer, or the string `"constant"` (= 0) or `"linear"`
(= 1).

## Name-value pairs / arguments

| Argument | Default | Purpose |
|---|---|---|
| `n` (positional) | `1` | Polynomial degree. `0` = remove mean, `1` = linear, `2` = quadratic, `3` = cubic. **Escalate this before abandoning polynomial for `highpass`** (see gotcha below). |
| `bp` (positional) | none | Breakpoints defining piecewise segments. Sample-point values or a logical vector the length of the data. |
| `nanflag` | `"includemissing"` | `"omitnan"` / `"omitmissing"` ignores NaN when fitting the trend. Default lets any NaN in the operating dimension poison the fit. |
| `Continuous` | `true` | `false` allows the fitted trend to have discontinuities at breakpoints. Use with `bp` for sensor-reset / calibration-event drift. |
| `SamplePoints` | `[1 2 3 ...]` | x-axis locations of the data. Not supported for timetables (they use row times). |
| `DataVariables` | all numeric | For table/timetable input: which variables to detrend. |
| `ReplaceValues` | `true` | For table/timetable input: `false` appends detrended variables instead of replacing. |

## Escalate the polynomial degree before switching to a filter

A common failure: an agent ran `detrend(x)` (default `n=1`, linear), saw a residual
sub-Hz wiggle, concluded "the drift is wavy, a polynomial will not fit it,"
and switched to `highpass(x, 0.5, fs)`. The planted drift was a smooth cubic.
`detrend(x, 3)` would have removed it exactly.

Rule: if linear detrend leaves a residual with a smooth shape (not an
oscillation, not broadband noise), the drift is a higher-order polynomial.
Escalate `n` 1 -> 2 -> 3 before reaching for `highpass`.

```matlab
xd = detrend(x, 1);        % try linear first
% residual still has a smooth low-frequency bend? escalate:
xd = detrend(x, 2);
xd = detrend(x, 3);        % a cubic drift is removed exactly here
```

Polynomial detrending has unity passband gain, so it costs the signal band
nothing. `highpass` has a transition band that rolls off content just above
the cutoff, touching the signal of interest. If a polynomial fits, it is
strictly better.

When a polynomial is the *wrong* tool entirely - oscillatory drift, drift that
is non-stationary with no clean breakpoints, or a record much longer than any
plausible drift period - the switch to `highpass` or a local regression
(`x - smoothdata(x, "lowess"|"loess", win)`) is the workflow decision: see
wf-detrend-smooth-deoutlier.md (Step 2).

For drift with discontinuities at *known* points (sensor reset, calibration),
stay with `detrend` but pass breakpoints:

```matlab
xd = detrend(x, 1, bp, Continuous=false);   % piecewise linear, jumps allowed
```

## Gotchas

- **`detrend(x)` defaults to `n=1`.** "Default detrend" is ambiguous in code
  review. Always write the degree explicitly (`detrend(x, 1)`) so the intent
  is on the page.
- **Operates column-wise on matrices**, like `smoothdata` and `filloutliers`.
  For row-wise trends, transpose or use the appropriate `dim`/`SamplePoints`.
- **NaN poisons the fit by default.** Pass `"omitnan"` if the signal still has
  gaps at detrend time. Better: fill first (see fn-fillmissing.md /
  fn-fillgaps.md) so the fit sees a complete record.
- **`detrend(x, 0)` and `x - mean(x)` are the same thing** (mean removal).

## See also

- `highpass` — the frequency-domain alternative when drift shape is not describable.
- fn-smoothdata.md — `x - smoothdata(x, "lowess", win)` for non-stationary
  drift that no polynomial fits.
- wf-detrend-smooth-deoutlier.md — where detrend sits in the outliers ->
  detrend -> smooth recipe.

----

Copyright 2026 The MathWorks, Inc.

----
