# Computing Total Signal Power from Spectrum

How to compute total average signal power from a power spectral density (PSD) or power spectrum. Use this to verify Parseval's theorem, validate spectral estimates, or convert between time-domain and frequency-domain power measurements.

## Quick Reference

| Output Type | Total Power Formula | RBW |
|:-----------:|---------------------|-----|
| PSD (with Fs) | `sum(PSD) * df` | — |
| PSD (no Fs) | `sum(PSD) * dω` | — |
| Power spectrum (with Fs) | `sum(PS) * df / RBW` | `enbw(win) * Fs/Nw` |
| Power spectrum (no Fs) | `sum(PS) * dω / RBW` | `enbw(win) * 2π/Nw` |

These formulas work regardless of:
- One-sided or two-sided spectrum (MATLAB handles the doubling internally)
- Whether NFFT equals Nw or NFFT > Nw (zero-padding)
- Which window is used

## Key Definitions

- **`df`** = frequency bin spacing = `f(2)-f(1)` = `Fs/NFFT` (Hz) or `2π/NFFT` (rad/sample)
- **`Nw`** = window length (segment length)
- **`NFFT`** = number of FFT points (≥ Nw)
- **`RBW`** = resolution bandwidth = `enbw(win) * Fs/Nw` — the noise-equivalent width of the window in Hz
- **`enbw(win)`** = equivalent noise bandwidth of the window in bins (1.0 for rectangular, 1.5 for Hann, 1.36 for Hamming)

## Why `sum(PS)` Does NOT Give Total Power

The power spectrum output (`'power'`) scales each bin by the resolution bandwidth RBW so that discrete tones read their true power directly from the peak value. This is useful for reading off individual tone amplitudes, but it means:

- `PS[k] = PSD[k] * RBW`
- `sum(PS) = sum(PSD) * RBW = P_total * (RBW/df)`
- `sum(PS)` overestimates total power by a factor of `RBW/df = enbw(win) * NFFT/Nw`

To recover total power: divide by this factor, or equivalently use `sum(PS) * df / RBW`.

For a **rectangular window with NFFT = Nw**: `enbw = 1`, `RBW = df`, and `sum(PS) = P_total` directly. This is the only case where naive summation works.

## Complete Example

```matlab
L = 500000;           % signal length
Nw = L/200;           % window length
win = hamming(Nw);    % window
NFFT = 2^nextpow2(Nw); % FFT points (NFFT > Nw)
Fs = 1000;            % sample rate

% Signal: random noise with known variance
y = sqrt(0.175)*randn(L,1);

% --- Time-domain power ---
pTime = sum(y.^2)/length(y);

% --- From PSD ---
[psd,f] = pwelch(y,win,0,NFFT,Fs);
df = f(2)-f(1);
pFromPSD = sum(psd)*df;

% --- From Power Spectrum ---
[ps,f] = pwelch(y,win,0,NFFT,Fs,'power');
RBW = enbw(win)*Fs/Nw;
pFromPS = sum(ps)*df/RBW;

% --- Verify ---
fprintf("Time-domain power:  %.6f\n",pTime);
fprintf("From PSD:           %.6f\n",pFromPSD);
fprintf("From Power Spectrum: %.6f\n",pFromPS);
```

## Normalized Frequency (No Fs)

When no sample rate is specified, `pwelch` returns frequency in rad/sample [0, π] (one-sided) or [0, 2π) (two-sided):

```matlab
[psd,w] = pwelch(y,win,0,NFFT,'psd');
dw = w(2)-w(1);
pFromPSD = sum(psd)*dw;

[ps,w] = pwelch(y,win,0,NFFT,'power');
RBW = enbw(win)*2*pi/Nw;
pFromPS = sum(ps)*dw/RBW;
```

## Why There Is a Small Residual Error (~0.5%)

The spectral estimate computes a **window-weighted** power:

```
P_spectral = sum(x² · w²) / sum(w²)
```

This is not exactly `sum(x²)/N` unless the window is rectangular. The bias is small for stationary signals and decreases with more averaging (more segments in Welch). It is not an error in the formula — it reflects the window's weighting of the data.

## Summary

- **To compute total power:** use PSD output and integrate — `sum(PSD) * df`. Simplest and safest.
- **From power spectrum:** must divide by RBW — `sum(PS) * df / RBW`.
- **RBW depends on window and segment length**, not on NFFT.
- **`enbw(win)`** is the key: it equals 1 for rectangular and > 1 for all other windows.
- Works with `periodogram`, `pwelch`, or any function returning calibrated PSD/power spectrum.

----

Copyright 2026 The MathWorks, Inc.

----
