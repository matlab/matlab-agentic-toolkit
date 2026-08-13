# Time-Frequency Method Selection Guide

## Diagnostic Workflow

When a user asks for time-frequency analysis without specifying a method, examine the signal and recommend the best approach.

### Step 1: Gather signal properties

```matlab
fs = ...; % sample rate (ask user if not provided)
Nx = length(x);
duration = Nx / fs;

% Quick spectral overview
[pxx, f] = pwelch(x, [], [], [], fs);

% Transient indicators
K = kurtosis(x);  % K >> 3 suggests impulsive/transient content

% Bandwidth estimate (3 dB bandwidth around peak)
[~, ipk] = max(pxx);
fpeak = f(ipk);
pxx_norm = pxx / max(pxx);
bw3dB = f(find(pxx_norm > 0.5, 1, 'last')) - f(find(pxx_norm > 0.5, 1, 'first'));
fractionalBW = bw3dB / fpeak;  % > 1 = broadband, < 0.1 = narrowband
```

### Step 2: Classify and recommend

| Signal characteristic | Indicator | Recommended method |
|---|---|---|
| Sharp transients at multiple scales (ECG QRS, impacts, clicks) | Kurtosis >> 3, short-duration bursts | **CWT** (`cwt`) |
| Closely-spaced tones at HIGH frequencies | `Δf/fc < 1/Q` (CWT can't resolve) | **STFT** (`spectrogram` or `stft`) |
| Slowly varying frequency content, stationary-ish | Low kurtosis, spectral content stable over time | **STFT** (`spectrogram` or `stft`) |
| Need to modify spectrum and reconstruct | User says "filter", "remove", "denoise" in frequency domain | **stft/istft** |
| Closely-spaced narrowband tones (same octave band) | Multiple peaks within a 2:1 frequency ratio | **modwptdetails** or **vmd** |
| Well-separated frequency bands (different octaves) | Peaks in different octave bands | **modwt + modwtmra** |
| Non-linear oscillatory modes, AM/FM | Amplitude or frequency modulation visible | **EMD** (if few modes) or **VMD** (if count known) |
| Log-frequency analysis (music, audio) | Musical pitch tracking, harmonic structure | **cqt/icqt** |
| Need sharp instantaneous frequency tracks | Chirps, frequency sweeps | **fsst** (STFT-based) or **wsst** (wavelet-based) |
| High time-frequency resolution (research) | Need Wigner-Ville without cross-terms | **wvd** (single component) or **wsst** (multi-component) |
| Additive decomposition into frequency bands | User wants "components that sum to original" | **modwtmra** or **modwptdetails** |

### Step 3: Validate the recommendation

After choosing a method, run a quick sanity check:

```matlab
% For CWT recommendation — verify it reveals structure STFT misses
figure
tiledlayout(2,1)
nexttile
cwt(x, fs)
title("CWT (scalogram)")
nexttile
pspectrum(x, fs, "spectrogram")
title("Spectrogram")
```

Show both to the user and explain why one is better for their signal.

## Decision Tree (quick reference)

```
Does the user need to modify and reconstruct the signal?
├── YES → stft/istft (check length condition and COLA)
└── NO
    ├── Does the signal have sharp transients or multi-scale structure?
    │   ├── YES → CWT (cwt)
    │   └── NO
    │       ├── Are there closely-spaced frequency components?
    │       │   ├── YES, known count → VMD
    │       │   ├── YES, want uniform bands → modwptdetails
    │       │   └── NO
    │       │       ├── Want additive time-domain components?
    │       │       │   ├── Components in different octaves → modwt + modwtmra
    │       │       │   └── Components in same octave → modwptdetails
    │       │       └── Want time-frequency display?
    │       │           ├── Need sharp IF tracks → fsst or wsst
    │       │           ├── Log-frequency (music) → cqt
    │       │           └── General purpose → spectrogram
    └── SPECIAL CASES
        ├── Complex-valued signal → modwt/modwtmra or modwptdetails (not EMD/VMD)
        ├── Only have STFT magnitude → stftmag2sig
        └── ML feature extraction → modwt or modwtLayer (deterministic, fixed structure)
```

## Example: Why CWT for ECG

```matlab
load wecg.mat
fs = 180;
```

ECG signals have:
- **Sharp QRS complexes** (5–25 Hz energy, ~100 ms duration) — need fine time resolution
- **Slow P and T waves** (0.5–5 Hz) — need fine frequency resolution
- **Multi-scale structure** — different clinically relevant features at different scales

CWT provides fine time resolution at high frequencies (resolves QRS timing) AND fine frequency resolution at low frequencies (separates P/T waves) simultaneously. STFT with a fixed window forces a single time-frequency tradeoff — a window short enough to resolve QRS timing gives poor frequency resolution for the slow waves.

```matlab
% CWT reveals multi-scale ECG structure
figure
cwt(wecg, fs)

% Compare: spectrogram struggles with the tradeoff
figure
pspectrum(wecg, fs, "spectrogram")
```

## Example: Why STFT for closely-spaced high-frequency tones

CWT has constant-Q: bandwidth = center_frequency / Q. At high frequencies, this means **wide bandwidth** — poor frequency resolution. STFT has constant bandwidth (fs/M) at all frequencies.

```matlab
% DTMF example: tones at 3600 and 3700 Hz (100 Hz apart), fs = 8000 Hz
% STFT resolution: 8000/256 = 31.25 Hz — easily resolves both tones
% CWT at 3650 Hz (Q~20 for bump wavelet): bandwidth ~182 Hz — CANNOT resolve them

% STFT wins for closely-spaced high-frequency components
[S,F,T] = stft(x, fs, Window=hamming(256), OverlapLength=250, FrequencyRange="onesided");
```

**Rule of thumb:** If the tone separation `Δf` is small relative to the center frequency (i.e., `Δf/fc < 1/Q`), CWT cannot resolve the components. Use STFT instead.

Note: Synchrosqueezing (`wsst`) can sharpen CWT frequency localization and partially overcome this limitation — covered in the synchrosqueezing reference.

## Example: Why STFT for steady-state vibration

A machine vibration signal with constant-speed rotation has:
- Stationary harmonic content (shaft frequency + harmonics)
- No rapid transients during normal operation
- Need to track amplitude of specific harmonics over time

STFT is ideal: fixed frequency resolution tuned to the harmonic spacing, uniform time grid for trending.

```matlab
% For harmonics spaced 25 Hz apart at fs = 10000:
M = ceil(2 * fs / 25);  % ~800 samples for Hann window
spectrogram(x, hann(M), round(0.75*M), 2*M, fs, 'yaxis')
```


----

Copyright 2026 The MathWorks, Inc.

----
