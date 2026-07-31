# Function: `resample`

> Used in: wf-uniform-rate.md, wf-align-channels.md
> Toolbox: Signal Processing Toolbox

Rate conversion with a built-in **antialiasing filter**.
Unlike `retime`'s plain interpolation, `resample` applies an FIR lowpass
filter and compensates for its delay, so it does not alias when it changes
the rate.

Two argument families:
- **Rational-factor form** `resample(x, p, q)` — resample uniform data at `p/q` times its rate.
- **Time-vector form** `resample(x, tx, fs)` — resample a **non-uniformly sampled** signal directly onto a uniform rate `fs`, no timetable needed.

The time-vector form is the reach for regularizing a jittery time base
when you want antialiasing that `retime`/`interp1` do not provide.

## Signature

```matlab
% Rational factor (uniform input)
y = resample(x, p, q)                    % p/q times the original rate
y = resample(x, p, q, n)                 % antialias filter order 2*n*max(p,q)
y = resample(x, p, q, n, beta)           % Kaiser window shape parameter

% Time-vector form (non-uniform input) -> uniform output
y            = resample(x, tx)           % uniform grid, same endpoints/count as tx
y            = resample(x, tx, fs)       % uniform rate fs, polyphase antialiasing
y            = resample(x, tx, fs, p, q) % via intermediate grid (p/q)/fs
[y, ty]      = resample(x, tx, ___)      % ty = output sample instants
y            = resample(x, tx, ___, method)   % 'linear' (default) | 'pchip' | 'spline'

% Timetable in, timetable out
yTT = resample(xTT, p, q, ___)           % uniform xTT
yTT = resample(xTT, ___)                 % non-uniform xTT -> uniform, same endpoints/count
```

## Arguments

| Argument | Default | Purpose |
|---|---|---|
| `p`, `q` | — | Positive integers; output rate is `p/q` times input. Use `rat(fsNew/fsOld)` to derive. |
| `tx` | — | Sample instants (numeric or `datetime`). Must increase monotonically, need not be uniform. `NaN`/`NaT` treated as missing and ignored. |
| `fs` | — | Target uniform sample rate (Hz if `tx` is in seconds). |
| `n` | `10` | Neighbor term; antialias FIR order is `2*n*max(p,q)`. `n=0` gives nearest-neighbor. Larger `n` = more accuracy, more compute. |
| `beta` | `5` | Kaiser window shape parameter for the antialias filter. Higher widens the mainlobe, deepens sidelobe attenuation. |
| `method` | `'linear'` | Interpolation onto the intermediate grid (time-vector form only): `'linear'`, `'pchip'`, or `'spline'`. |
| `Dimension` | first dim > 1 | `Dimension=dim` selects the axis to operate along. Must be 1 for timetable input. |

## Time-vector form is the non-uniform path

```matlab
% Irregular instants tx -> uniform 100 Hz, antialiased:
[y, ty] = resample(x, tx, 100);
```

The function interpolates `x` onto a close-rational uniform grid, filters,
and returns the resampled signal plus the matching instants `ty`.
For a non-uniform timetable, the same happens in one call:

```matlab
yTT = resample(xTT);          % nonuniform xTT -> uniform, endpoints preserved
```

Unlike `retime`'s plain interpolation, `resample` applies an FIR anti-alias
filter — which is exactly why it is the default whenever the target rate is at
or below the signal's content bandwidth (any downsampling). The choose-between
decision (and when plain `retime` is still fine) is the workflow's: see
wf-uniform-rate.md.

## Gotchas

- **Endpoint assumption.** `resample` assumes the signal is zero before and after the samples given. Large nonzero endpoints produce edge transients. Detrend (subtract the endpoint line), resample, then add the trend back — see the endpoint-effects recipe in wf-align-channels.md.
- **Output rate must clear Nyquist.** For the time-vector form `resample(x, tx, fs)`, the output rate is `fs`, so `fs` must be at least twice the highest frequency of interest in `x`. If the non-uniform samples are locally denser than `fs` (content oscillates faster than the target grid resolves), raise `fs` or the signal aliases.
- **`p`, `q` must be integers.** Derive them with `rat`; do not pass a floating ratio.
- **Not a timetable merge.** `resample` changes one signal's rate. To bring several channels onto one grid, use `synchronize` (fn-synchronize.md).
- **Codegen / GPU limits.** Timetable inputs are not supported for C/C++ or GPU code generation; `'pchip'` is unsupported on GPU arrays.

## See also

- fn-retime.md — plain (non-antialiased) timetable rate change / interpolation.
- fn-synchronize.md — merge several timetables onto a shared grid.
- `fillgaps` — AR-based reconstruction of missing samples (wf-repair-missing.md).
- wf-uniform-rate.md, wf-align-channels.md — the workflows that use `resample`.

----

Copyright 2026 The MathWorks, Inc.

----
