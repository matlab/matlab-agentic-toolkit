# Function: `fillgaps`

> Used in: wf-repair-missing.md
> Toolbox: Signal Processing Toolbox

Fills NaN gaps by autoregressive modeling: it fits forward and reverse AR
models to the non-missing samples and extrapolates them into each gap. Because
the AR model continues the signal's dominant oscillation, it preserves the
spectrum across long gaps where interpolation would inject a spurious
low-frequency ramp.

This is the function cold agents miss and invent names for (`regularizeNaNs`,
`inpaintn` do not exist). It is SPT-only. When the gap is long AND the signal
is oscillatory AND downstream is spectral, this is the right call over
`fillmissing`. See wf-repair-missing.md.

On a matrix, each column is an independent channel.

## Signature

```matlab
y = fillgaps(x)                     % maxlen = all samples, order = "aic"
y = fillgaps(x, maxlen)             % cap samples used per fit
y = fillgaps(x, maxlen, order)      % explicit AR order
fillgaps(___)                       % no output: plots original + reconstruction
```

`x` carries NaN at the missing samples. Output `y` is the same size with the
gaps reconstructed.

## Arguments

| Argument | Default | Purpose |
|---|---|---|
| `maxlen` | all available samples | Maximum number of samples on each side of a gap to use in the AR fit. Cap it when the signal is not well described by a single AR process across its whole range (non-stationary), so each gap is modeled from a local window. |
| `order` | `"aic"` | AR model order. `"aic"` auto-selects the order minimizing the Akaike information criterion. Pass a positive integer to fix it. Order is truncated when there are not enough samples. |

## Why it preserves the spectrum (the mechanism)

Because the forward/reverse AR models continue the signal's dominant
oscillation through the gap, `fillgaps` keeps the spectrum intact where a plain
interpolation (`fillmissing("pchip")`) would draw a smooth ramp across the gap —
flattening the tone and injecting a spurious low-frequency bump into the FFT.
That advantage is real **only when the signal is AR-suitable** (oscillatory /
quasi-stationary); on noise-like data, a monotonic trend, or a lone transient
the AR fit has nothing to continue and `fillmissing` is as good or better.

The full `fillmissing`-vs-`fillgaps` decision (both gates: gap-width and
AR-suitability) is the workflow's — see wf-repair-missing.md.

## Gotchas

- **SPT required.** The only function in the missing-data set that is not base
  MATLAB.
- **`order="aic"` can over-fit on short signals.** With fewer than ~50
  non-missing samples, pass a small explicit order (e.g. 4-8) rather than
  letting AIC choose.
- **Very high orders misbehave.** Large `order` values hit finite-precision
  problems and can produce a worse reconstruction than a moderate order. The
  doc shows order 70 reconstructing worse than order 40.
- **Per-channel on matrices.** Each column is fit independently, so expect
  different AR orders per column unless you fix `order`.
- **NaN-only.** It fills NaN gaps; it does not resample onto a new grid (that
  is `interp1` / `retime`) or remove outliers (that is fn-filloutliers.md).

## See also

- fn-fillmissing.md — interpolation-based filler for short gaps.
- wf-repair-missing.md — the full `fillmissing` vs `fillgaps` decision.
- `arburg` — the AR-estimation primitive underneath.

----

Copyright 2026 The MathWorks, Inc.

----
