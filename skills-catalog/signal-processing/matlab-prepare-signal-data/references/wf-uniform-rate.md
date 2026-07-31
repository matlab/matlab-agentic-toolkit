# Workflow: put one channel on a uniform rate (regularize / resample)

> Functions used: `retime`, `resample`, `decimate`, `interp`, `interp1`, `isregular`

A single channel goes onto a uniform grid at a chosen rate — whether it started
with irregular/jittery timestamps OR is already uniform but at the wrong rate.

> **Off-ramp.** Two or more channels that need a shared grid is align, not
> regularize — see wf-align-channels.md.

## When to use

One channel that you need on a uniform grid at a chosen rate. Two entry cases,
same machinery:

- **Non-uniform / jittery timestamps -> uniform grid.** The decision is which
  `retime` adjust method, and whether you need antialiasing (`resample`).
- **Already uniform, but the wrong rate -> new rate** (e.g. 1 kHz -> 400 Hz for a
  downstream pipeline). This is a pure rate change — pick the function from the
  table below.

## Pick the rate-change function first

`resample` is the general default, but it is NOT always right. Choose before you
code:

| Your situation | Reach for | Why / not `resample` |
|---|---|---|
| Non-integer or arbitrary ratio; non-uniform input | `resample(x, p, q)` (`[p,q]=rat(fsNew/fsOld)`) or `resample(x, tx, fs)` | The generalist: rational ratio, antialiased, linear phase, delay-compensated. |
| Integer factor, waveform SHAPE / peak timing must survive | `decimate(x, r, 'fir')` (down) / `interp(x, r)` (up) | `decimate`'s DEFAULT filter is IIR (nonlinear phase) -> distorts pulse shape; the `'fir'` flag is linear phase. |
| Integer factor, must PRESERVE original samples exactly | `interp(x, r)` or `interp1` on the original grid | `resample` filters *every* value, so it MODIFIES the original samples. `interp` passes originals through unchanged. |
| You will supply your own antialias/anti-image filter | `upfirdn` | Full control of the polyphase filter. |

**Never** `downsample`/`upsample` alone — they only stride / zero-stuff with no
filter, so they alias (down) or leave spectral images (up). Use them only with
your own filter or on already-band-limited data.

**`resample` gotchas** (once you have chosen it): integer `p,q` (never a float);
and the endpoint assumption — it treats the signal as zero outside the span, so a
large offset/trend rings at the edges (detrend -> resample -> re-trend). Full
contract: fn-resample.md.

## Recipe

### Step 1 — Confirm it is actually non-uniform

```matlab
isregular(TT)          % false => needs regularizing
```

### Step 2 — Put it on a uniform grid

Timetable path (the usual reach):

```matlab
TT2 = retime(TT, 'regular', 'linear', 'SampleRate', fs);
```

Numeric-vector path, or when you want antialiasing:

```matlab
[y, ty] = resample(x, tx, fs);     % non-uniform tx -> uniform fs, antialiased
```

### Step 3 — Pick the adjust rule deliberately

Rule selection is the one real decision here: pick `'linear'` (honest default)
unless the signal justifies something else - `'pchip'`/`'makima'` for known-smooth
no-kinks, `'previous'` for a held setting (throttle/valve, where interpolation
would be wrong), aggregation for coarser-than-input output. Do not default to
`'spline'` for "smoothness". The full method table is in fn-retime.md.

### `retime` vs `resample` here

- `resample(x, tx, fs)` / `resample(xTT)` — antialiased. **The default for any rate *reduction*** (target rate at or below the signal's content bandwidth). Applies the FIR anti-alias filter so nothing folds back into the band.
- `retime(...,'linear',...)` — plain interpolation, **no antialiasing**. Only for jitter cleanup or upsampling at the same-or-higher rate. **Never use it to lower the rate below the signal's content — it aliases silently.** See fn-resample.md.

## Gotchas

- **Method omitted = NaN fill**, not interpolation. `retime(TT, newTimes)` alone inserts `NaN`.
- **`'linear'` extrapolates by default** (`EndValues='extrap'`). Pass `EndValues=NaN` to keep from inventing values past the data span, then fill deliberately (wf-repair-missing.md).
- **`'regular'` needs `SampleRate` or `TimeStep`** — it errors alone.

## See also

- fn-retime.md — method vocabulary and rule selection.
- fn-resample.md — antialiased alternative.
- wf-align-channels.md — the multi-channel case.
- wf-repair-missing.md — fill any NaNs left behind.

----

Copyright 2026 The MathWorks, Inc.

----
