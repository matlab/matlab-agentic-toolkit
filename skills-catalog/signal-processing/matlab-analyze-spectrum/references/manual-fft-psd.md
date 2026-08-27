# Manual FFT-Based PSD

Prefer `periodogram` or `pwelch` — they handle windowing, normalization, and one-sided folding correctly. Use this pattern only when the user explicitly needs manual FFT code.

## PSD from FFT (No Window, Real-Valued Signal)

```matlab
Fs = 1000;
N = length(x);
xdft = fft(x);

% Keep only positive frequencies (DC to Nyquist)
xdft = xdft(1:N/2+1);

% PSD: normalize by Fs*N, double interior bins (not DC or Nyquist)
psdx = (1/(Fs*N)) * abs(xdft).^2;
psdx(2:end-1) = 2*psdx(2:end-1);

% Frequency vector
f = (0:N/2) * Fs/N;

% Verify: should match periodogram(x,[],[],Fs)
figure
plot(f,pow2db(psdx))
xlabel("Frequency (Hz)")
ylabel("PSD (dB/Hz)")
title("PSD via Manual FFT")
```

## Key Points

- **Normalization**: `1/(Fs*N)` for PSD (power/Hz); just `1/N` for power spectrum (power/bin)
- **Doubling**: Only interior bins (indices 2 through end-1). DC and Nyquist have no mirror image — doubling them overestimates power
- **Windowed variant**: Apply `xw = x .* win` then normalize: `psdx = (1/(Fs*sum(win.^2))) * abs(fft(xw)).^2`
- **Normalized frequency** (no Fs): scale by `1/(2*pi*N)` instead of `1/(Fs*N)`
- This produces identical output to `periodogram(x,[],[],Fs)` (rectangular window)

## With a Window

```matlab
Fs = 1000;
N = length(x);
win = hann(N);
xw = x(:) .* win;

xdft = fft(xw);
xdft = xdft(1:N/2+1);

% Window-corrected PSD: normalize by Fs * sum(win.^2)
psdx = (1/(Fs * sum(win.^2))) * abs(xdft).^2;
psdx(2:end-1) = 2*psdx(2:end-1);

f = (0:N/2) * Fs/N;

% Verify: should match periodogram(x,win,[],Fs)
```

## Power Spectrum (Not PSD) from FFT

```matlab
% Power spectrum: normalize by sum(win)^2 (coherent gain squared)
xw = x(:) .* win;
xdft = fft(xw);
xdft = xdft(1:N/2+1);

psx = (1/sum(win)^2) * abs(xdft).^2;
psx(2:end-1) = 2*psx(2:end-1);

% Verify: should match periodogram(x,win,[],Fs,'power')
```

## Complex-Valued Signal (Two-Sided)

```matlab
% For complex signals, keep all N frequency bins (no doubling)
xdft = fft(x);
psdx = (1/(Fs*N)) * abs(xdft).^2;  % no doubling
f = (0:N-1) * Fs/N;  % or use fftshift for centered view
```

## Reference

See MathWorks documentation: [Power Spectral Density Estimates Using FFT](https://www.mathworks.com/help/signal/ug/power-spectral-density-estimates-using-fft.html)

----

Copyright 2026 The MathWorks, Inc.

----
