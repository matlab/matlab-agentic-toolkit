# Spectral Windows

Choose the right window to control the trade-off between frequency resolution (narrow main lobe) and spectral leakage (low sidelobes).

## Core Trade-Off

Every window trades **main lobe width** (frequency resolution) against **sidelobe level** (leakage suppression):
- Narrow main lobe → better at resolving close frequencies, but more leakage from distant strong tones
- Low sidelobes → better at detecting weak tones near strong ones, but wider main lobe smears close frequencies

## Window Comparison Table

| Window | ENBW (bins) | Peak Sidelobe (dB) | Sidelobe Decay | Best For |
|--------|:-----------:|:-------------------:|:--------------:|----------|
| Rectangular | 1.00 | -13 | -6 dB/oct | Maximum resolution (only if signal is periodic in frame) |
| Hann | 1.50 | -32 | -18 dB/oct | General purpose, good default |
| Hamming | 1.36 | -43 | -6 dB/oct | Better sidelobe suppression than Hann, but slower decay |
| Blackman | 1.73 | -58 | -18 dB/oct | Low leakage, moderate resolution |
| Blackman-Harris | 2.01 | -92 | -6 dB/oct | Very low leakage, detecting weak tones near strong ones |
| Kaiser (beta=5) | 1.36 | -37 | tunable | Adjustable trade-off via beta parameter |
| Kaiser (beta=8) | 1.67 | -59 | tunable | Higher sidelobe suppression |
| Kaiser (beta=14) | 2.32 | -90 | tunable | Near Blackman-Harris performance |
| Flat Top | 3.77 | -0.01 (passband ripple) | -11 dB/oct | Amplitude accuracy (calibration) |
| Chebyshev (100 dB) | 1.94 | -100 (equiripple) | 0 (equiripple) | Guaranteed minimum sidelobe level |
| Nuttall | 2.02 | -98 | -18 dB/oct | Extremely low sidelobes with fast decay |

**ENBW** = Equivalent Noise Bandwidth in frequency bins. Multiply by `Fs/N` to get Hz. Lower = less noise in power estimates.

## Window Selection Guide

| Scenario | Recommended Window | Why |
|----------|-------------------|-----|
| General-purpose PSD | **Hann** | Good balance, fast sidelobe decay, 50% overlap is optimal |
| Resolving two close frequencies of similar amplitude | **Rectangular** or **Hann** | Narrowest main lobe (but rectangular only if signal is periodic in frame) |
| Weak tone near a strong tone (e.g., harmonic distortion) | **Blackman-Harris** or **Kaiser (beta>=10)** | Need very low sidelobes so the strong tone doesn't mask the weak one |
| Amplitude-accurate measurement (calibration) | **Flat Top** | Minimal scalloping loss (~0.01 dB) — amplitude reads correctly even between bins |
| Transient or short burst (don't want to taper edges) | **Rectangular** or **Tukey (r=0.1-0.25)** | Preserves signal energy at frame edges |
| Guaranteed sidelobe floor | **Chebyshev** or **Kaiser** | Both offer tunable sidelobe level |
| Welch PSD with maximum overlap efficiency | **Hann** with 50% overlap | Hann at 50% overlap gives uncorrelated segments with good variance reduction |

## Key Concepts

### ENBW (Equivalent Noise Bandwidth)

The width of an ideal rectangular filter that would pass the same noise power as the window. Critical for accurate noise floor measurements:

```matlab
N = 1024;
w = hann(N);
bw_bins = enbw(w);           % ENBW in bins
bw_hz = enbw(w,Fs);          % ENBW in Hz (if Fs known)
```

### Scalloping Loss

The worst-case amplitude error when a tone falls between DFT bins:

| Window | Scalloping Loss |
|--------|:--------------:|
| Rectangular | 3.92 dB |
| Hann | 1.42 dB |
| Hamming | 1.78 dB |
| Blackman-Harris | 0.83 dB |
| Flat Top | ~0.01 dB |

Use **Flat Top** when accurate amplitude measurement matters more than frequency resolution.

### Coherent Gain

The DC gain of the window (ratio of windowed signal amplitude to original). Functions like `periodogram` and `pwelch` compensate automatically. For manual FFT, divide by `mean(w)` for amplitude or by `rms(w)` for power.

### Overlap and Windows

| Window | Recommended Overlap | Why |
|--------|:------------------:|-----|
| Hann | 50% | Constant-overlap-add (COLA), uncorrelated segments |
| Hamming | 50% | Near-COLA |
| Blackman-Harris | 66.1% | COLA for 4-term window |
| Kaiser (beta=5) | 50% | Good compromise |
| Flat Top | 75-80% | Wide window needs more overlap to avoid data loss |

## Using Kaiser Window

Kaiser is the most flexible — one parameter (`beta`) controls the entire resolution/leakage trade-off:

```matlab
N = 1024;
Fs = 1000;

% Design Kaiser window for desired sidelobe attenuation
desiredAttenuation = 60;  % dB
beta = 0.1102*(desiredAttenuation - 8.7);  % Kaiser's formula
w = kaiser(N,beta);

[pxx,f] = periodogram(x,w,[],Fs);
```

**beta guidelines:**
| beta | Approx. Sidelobe Level | Similar To |
|:----:|:---------------------:|-----------|
| 0 | -13 dB | Rectangular |
| 5 | -37 dB | Hamming |
| 6 | -44 dB | — |
| 8 | -59 dB | Blackman |
| 10 | -72 dB | — |
| 14 | -90 dB | Blackman-Harris |

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using rectangular window without knowing it | -13 dB sidelobes mask weak signals | Apply `hann(N)` unless you have a reason not to |
| Choosing window only by sidelobe level | Sacrifices resolution unnecessarily | Match window to actual dynamic range requirement |
| Using Flat Top for frequency estimation | Wide main lobe smears peak location | Use Hann or Kaiser for frequency, Flat Top for amplitude |
| Zero overlap with Hann window | Loses 50% of data (tapered edges discarded) | Use 50% overlap with Hann |
| Not compensating window gain in manual FFT | Amplitude is wrong by coherent gain factor | Divide by `mean(w)` for amplitude, `rms(w)` for power |

## MATLAB Window Functions

| Function | Parameters | Notes |
|----------|-----------|-------|
| `rectwin(N)` | — | Equivalent to `ones(N,1)` |
| `hann(N)` | — | Most common general-purpose window |
| `hamming(N)` | — | Non-zero at edges (min value ~0.08) |
| `blackman(N)` | — | Good leakage suppression |
| `blackmanharris(N)` | — | 4-term, very low sidelobes |
| `kaiser(N,beta)` | beta: shape | Tunable — see beta table above |
| `flattopwin(N)` | — | For amplitude accuracy |
| `chebwin(N,attn)` | attn: sidelobe level (dB) | Equiripple sidelobes |
| `nuttallwin(N)` | — | 4-term, lowest sidelobes with fast decay |
| `tukeywin(N,r)` | r: taper fraction (0=rect, 1=hann) | Partial taper for transients |
| `gausswin(N,alpha)` | alpha: reciprocal std dev | Gaussian shape, no sidelobes in theory |

### Visualizing and Comparing Windows

```matlab
% Compare two windows in frequency domain
N = 256;
w1 = hann(N);
w2 = blackmanharris(N);

[W1,f1] = freqz(w1,1,[],Fs);
[W2,f2] = freqz(w2,1,[],Fs);

% Or use the Window Designer app
windowDesigner
```

### Using wvtool for Comparison

```matlab
wvtool(hann(256),blackmanharris(256),kaiser(256,8))
```

----

Copyright 2026 The MathWorks, Inc.

----
