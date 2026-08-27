# Spectral Analysis Troubleshooting

Common diagnostic questions and their solutions.

## "I have two tones but only see one peak"

Two possible causes:

### 1. Insufficient Frequency Resolution

The two tones are closer than `Fs/N` Hz apart and merge into a single peak. The FFT cannot resolve frequencies separated by less than one bin width.

- **Check**: `df = Fs/N`. If your tones are separated by less than `df`, they cannot be resolved.
- **Fix**: Acquire more data (increase N), or use a parametric method (`pmusic`, `rootmusic`) for super-resolution.
- **Why zero-padding doesn't help**: Zero-padding interpolates the spectrum (smoother appearance) but does NOT improve the ability to separate two close frequencies.

### 2. Sidelobe Masking

A strong tone's window sidelobes hide a nearby weak tone. If the weak tone is below the sidelobe level of the window, it will be buried in the leakage from the strong tone.

Sidelobe levels by window:
- Rectangular: -13 dB
- Hann: -32 dB
- Hamming: -43 dB
- Blackman-Harris: -92 dB
- Kaiser(N,15): ~-70 dB
- Kaiser(N,20): ~-55 dB

- **Fix**: Use a window with lower sidelobes than the amplitude difference between tones.
- **Diagnostic**: If you switch to `blackmanharris(N)` and the second peak appears, it was being masked by sidelobes.
- **Trade-off**: Lower sidelobes means wider main lobe — you may lose resolution. Only suppress sidelobes as much as your dynamic range requires.

```matlab
% Example: 50 Hz tone at 0 dB, 55 Hz tone at -40 dB, N=1000, Fs=1000
% df = 1 Hz, tones are 5 bins apart — resolution is fine
% Problem is sidelobe masking: hann sidelobes at -32 dB hide the -40 dB tone
Fs = 1000; N = 1000;
t = (0:N-1)/Fs;
x = sin(2*pi*50*t) + 0.01*sin(2*pi*55*t);  % -40 dB second tone

[pxx1,f] = periodogram(x,hann(N),[],Fs);           % weak tone hidden
[pxx2,f] = periodogram(x,blackmanharris(N),[],Fs);  % weak tone visible

figure
tiledlayout(2,1)
nexttile
plot(f,pow2db(pxx1))
title("Hann window — weak tone masked by sidelobes")
xlim([40 65]); ylabel("PSD (dB/Hz)")

nexttile
plot(f,pow2db(pxx2))
title("Blackman-Harris — weak tone revealed")
xlim([40 65]); xlabel("Frequency (Hz)"); ylabel("PSD (dB/Hz)")
```

### Decision Flowchart

1. Are the tones separated by more than `Fs/N`?
   - **No** → Resolution problem. Get more data or use `pmusic`/`rootmusic`.
   - **Yes** → Continue to step 2.
2. Is the weak tone more than 30 dB below the strong tone?
   - **Yes** → Likely sidelobe masking. Use lower-sidelobe window.
   - **No** → Check if tones are within one main-lobe width of each other (resolution issue even though > 1 bin apart, depending on window main-lobe width).

## "My tone doesn't show the expected power"

This is **scalloping loss** — the tone frequency falls between two FFT bins, so its energy is spread across adjacent bins and the peak reads lower than the true amplitude.

### How It Happens

FFT frequency bins are spaced at `Fs/N` Hz. If a tone frequency is not an exact multiple of `Fs/N`, it falls between bins. The peak bin captures only part of the energy.

### Worst-Case Scalloping Loss by Window

Tone falls exactly midway between two bins:

| Window | Scalloping loss | Notes |
|--------|----------------|-------|
| Rectangular | -3.9 dB | Severe — nearly half the power lost from peak |
| Hann | -1.4 dB | Moderate |
| Hamming | -1.8 dB | Moderate |
| Blackman-Harris | -0.8 dB | Small |
| Flat Top | -0.01 dB | Essentially zero — designed for this |
| Kaiser (beta=20) | ~-0.9 dB | Small |

### Fixes

1. **Use a flat-top window** (`flattopwin(N)`) for accurate amplitude measurement — designed specifically to minimize scalloping loss at the expense of wider main lobe.

2. **Zero-pad** (increase NFFT without adding data) to interpolate between bins and get a sample closer to the true peak. This reduces the error but doesn't eliminate it completely (unless you interpolate to infinite density).

3. **Parabolic interpolation** of the 3 bins around the peak to estimate the true peak location and amplitude. This is what many measurement instruments do internally.

### Code Example

```matlab
% Demonstrate scalloping: 50.5 Hz tone (falls between bins at Fs=1000, N=1000)
Fs = 1000; N = 1000;
t = (0:N-1)/Fs;
x = sin(2*pi*50.5*t);  % true power = 0.5 (-3.01 dB)

[ps_hann,f] = periodogram(x,hann(N),[],Fs,'power');
[ps_flat,f] = periodogram(x,flattopwin(N),[],Fs,'power');

fprintf("Hann peak: %.2f dB (expect -3.01 dB)\n",pow2db(max(ps_hann)))
fprintf("Flat-top peak: %.2f dB (expect -3.01 dB)\n",pow2db(max(ps_flat)))
% Hann shows ~-4.4 dB (1.4 dB scalloping loss), flat-top shows ~-3.01 dB
```

### When Scalloping Doesn't Matter

- Comparing relative peak heights (all peaks are affected similarly)
- Measuring broadband noise (scalloping averages out across many bins)
- Using `pwelch` with many segments (statistical averaging smooths it out)
- Frequency estimation (peak location is still approximately correct)

----

Copyright 2026 The MathWorks, Inc.

----
