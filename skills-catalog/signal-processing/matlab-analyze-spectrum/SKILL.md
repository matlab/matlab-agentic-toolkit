---
name: matlab-analyze-spectrum
description: >
  Analyze signal spectra in MATLAB using nonparametric and parametric estimators.
  Use when computing frequency content, PSD, power spectrum, spectral peaks,
  bandwidth, or streaming spectral analysis. Covers pspectrum, pwelch,
  periodogram, pmtm, pburg, pmusic, rootmusic, plomb, poctave, spectrumAnalyzer,
  dsp.SpectrumEstimator. TRIGGER: FFT, PSD, power spectrum, spectral analysis,
  frequency content, bandwidth measurement, spectral leakage, window selection,
  streaming spectrum, periodicity, resolve close frequencies, multitaper.
  DO NOT TRIGGER: filter design, spectrogram/time-frequency, audio features.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Analyze Signal Spectra in MATLAB

Compute, visualize, and extract measurements from signal spectra using Signal Processing Toolbox. Choose the right spectral estimator, avoid common FFT pitfalls, and use built-in measurement functions instead of reinventing them.

## When to Use

- Computing frequency content of a signal (FFT, periodogram, PSD, power spectrum)
- Estimating power spectral density (Welch, periodogram, parametric)
- Comparing frequency content of two signals (cross-spectrum, coherence)
- Finding spectral peaks (dominant frequencies, harmonics)
- Measuring bandwidth, band power, or occupied bandwidth
- Visualizing frequency-domain data
- Streaming (real-time, frame-by-frame) spectral analysis with `spectrumAnalyzer`, `dsp.SpectrumEstimator`, `dsp.CrossSpectrumEstimator`

## When NOT to Use

- Designing or applying filters -- use `matlab-design-digital-filter`
- Time-frequency/spectrogram analysis (including `spectrumAnalyzer` spectrogram ViewType, STFT, reassignment, CWT) -- use the time-frequency analysis skill (TBD)
- Audio-specific features (MFCC, pitch, auditory models) -- use Audio Toolbox
- Control system frequency response (Bode, Nyquist) -- use Control System Toolbox

## Workflow

1. **Batch or streaming?** -- Determine if data is already in workspace (batch) or arrives frame-by-frame (streaming). See below.
2. **Preliminary analysis** -- When user provides data, run diagnostics to inform technique selection (see below)
3. **Pre-process** -- Check for NaN/gaps (use `plomb` for non-uniform data). Apply `detrend(x)` only if DC/trend visibly distorts the spectrum
4. **Choose output type** -- PSD, power spectrum, amplitude spectrum, or octave bands (see below)
5. **Choose estimator** -- Use preliminary analysis results + Estimator Selection below
6. **Compute spectrum** -- Use the chosen function with explicit `Fs` (if available)
7. **Visualize** -- Plot with proper axis labels (Hz, dB or linear units)
8. **Extract metrics** -- Use `findpeaks`, `bandpower`, `obw`, `powerbw`. See `references/peak-detection.md`
9. **Verify** -- Parseval's theorem, known tone levels. See `references/power-from-spectrum.md`

## Batch vs Streaming

Determine the processing mode before choosing tools:

| Indicator | Mode | Tools |
|-----------|------|-------|
| Entire signal in workspace (vector/matrix) | **Batch** | `pwelch`, `pspectrum`, `periodogram`, `pburg`, etc. |
| Data arrives frame-by-frame (sensor, ADC, real-time loop) | **Streaming** | `spectrumAnalyzer`, `dsp.SpectrumEstimator`, `dsp.CrossSpectrumEstimator` |
| Need live-updating spectrum display | **Streaming** | `spectrumAnalyzer` (ViewType: spectrum) |
| Need spectrum values for real-time decisions | **Streaming** | `dsp.SpectrumEstimator` (returns numeric output each frame) |

**If streaming:** See `references/streaming-spectral-analysis.md` for System object APIs, properties, and patterns. DSP System Toolbox is required.

**The rest of this skill covers batch processing.** For streaming, the reference file provides full guidance including the batch-to-streaming mapping table.

## Preliminary Data Analysis

When the user provides signal data (variable, file, or description), run diagnostic checks before recommending a technique. See `references/preliminary-analysis.md` for full code.

**Quick checks (run in order — stop early if decisive):**

1. **Sampling type** — Fs given → uniform. Time vector with small jitter (<5%) → `pspectrum(x,t)` (resamples internally). Large jitter or truly non-uniform → `plomb`
2. **Data quality** — NaN/Inf, DC offset, trend → preprocess first
3. **Length** — <128: parametric only. 128–1024: `periodogram`/`pburg`. >10k: `pwelch` preferred
4. **Spectral character** — Run `periodogram` (Hann), compute spectral flatness + peak count + **strongest peak width**:
   - Flatness >0.3 → wideband → `pwelch` (peaks are just noise fluctuations)
   - Flatness <0.1, strongest peak **narrow** (width < 10×df) → tonal → `periodogram(...,'power')` or `rootmusic`
   - Flatness <0.1, strongest peak **wide** (width ≥ 10×df) → wideband-structured (chirps, shaped bands) → `pwelch` + `obw`
   - Flatness 0.1–0.3, peaks present → mixed → `pwelch` + `findpeaks`
5. **AR fitness** — Fit AR models with `arburg`, track prediction error vs order. If error plateaus <10% at low order → `pburg` is strong candidate
6. **Tone count** — If tonal: count peaks with `findpeaks`, cross-check with eigenvalue drop. Known count + resolution-limited → `rootmusic(x,2*nTones,Fs)`

**Report findings to the user before computing the spectrum:**
```
Preliminary Analysis:
- Sampling: uniform at [Fs] Hz
- Duration: [X] s ([N] samples), resolution: [df] Hz
- Spectral character: [wideband/tonal/mixed]
- AR fit: [quality] (order [N], residual [X]%)
Recommendation: [estimator] because [justification]
```

## Output Type Selection

| User's Goal | Output Type | Function / Option |
|-------------|-------------|-------------------|
| Compare to a standard or another signal (length-independent) | **PSD** (power/Hz) | `pwelch` (default), `periodogram` |
| Read amplitude of a specific tone | **Power spectrum** → `sqrt` | `pspectrum(x,Fs)` (default); `periodogram(x,w,N,Fs,'power')` or `pwelch(x,w,[],[],Fs,'power')` for explicit control |
| Measure total power in a band | **PSD** then integrate, or use `bandpower` | `bandpower(x,Fs,[fLow fHigh])` |
| Octave-band levels (acoustics, vibration) | **Fractional-octave spectrum** | `poctave(x,Fs,'BandsPerOctave',3)` |
| Detect frequencies in nearly-uniform data (small jitter) | **Power spectrum** | `pspectrum(x,t)` — resamples internally |
| Detect frequencies in non-uniform/gapped data | **Lomb-Scargle** | `plomb(x,t)` |

**PSD vs Power Spectrum:** PSD (power/Hz) is resolution-independent — broadband noise stays flat when you change parameters. Power spectrum (power/bin) is tone-friendly — peak height equals true tone power. Use PSD for noise characterization and specs (g²/Hz, dBm/Hz); use power spectrum for reading tone amplitudes. Convert: `PS = PSD × RBW` where `RBW = enbw(win)*Fs/segLen`.

## Estimator Selection

**Decision tree** (simple → specialized):

1. **Just want to see what frequencies are present?** → `pspectrum(x,Fs)`
2. **Need a smooth, low-variance PSD?** → `pwelch` (favored for long signals — segment averaging reduces variance) or `periodogram` (short signal, cannot segment)
3. **Need accurate tone amplitude from peaks?** → `periodogram(x,win,N,Fs,'power')` then `sqrt`
4. **Need octave-band levels (acoustics, vibration)?** → `poctave(x,Fs,'BandsPerOctave',3)`
5. **Comparing two signals at each frequency?** → `mscohere` (related?) / `cpsd` (shared content + phase)
6. **Data is nearly uniform (small jitter)?** → `pspectrum(x,t)` (resamples internally). **Truly non-uniform or large gaps?** → `plomb(x,t)`
7. **Need to resolve sinusoids closer than Fs/N?** → `rootmusic` / `pmusic` (must know # of sinusoids)
8. **Short data, want low-variance PSD without segmenting?** → `pmtm` (multitaper — uses orthogonal DPSS tapers on full record; no AR assumption)
9. **Short data, want smooth sidelobe-free PSD?** → `pburg` (assumes signal is AR-like)

**Quick reference table:**

| Goal | Function | When to use |
|------|----------|-------------|
| Quick look at frequency content | `pspectrum` | Default -- good defaults, tune `Leakage` (0–1) for resolution vs sidelobes |
| Single-sided amplitude spectrum | `periodogram` with `'power'` | Need amplitude per bin |
| PSD with low variance | `pwelch` | Long signals — averaging segments reduces variance; preferred when signal is long enough to segment |
| PSD of short signal, low variance | `pmtm` | Multitaper — uses full record with orthogonal DPSS tapers; no segmentation needed |
| PSD of short signal | `periodogram` | Too short to segment; high variance (single window) |
| Resolve closely-spaced sinusoids | `pmusic`, `rootmusic` | Known # of sinusoids, super-resolution |
| Smooth PSD of short AR-like data | `pburg` | No sidelobes; NOT for resolving tones |

**Default:** Start with `pspectrum`. Drop to `pwelch`/`periodogram` for explicit control. **Never use manual FFT** unless user explicitly asks — redirect to built-in functions.

**pspectrum vs pwelch**: `pspectrum` outputs power spectrum (Kaiser beta=20, ~76% overlap). `pwelch` defaults to PSD. They match within ~0.2 dB using equivalent parameters. See `references/pspectrum-equivalence.md` for exact mapping. **Resolution control in pspectrum**: Use `FrequencyResolution` (Hz) to set target resolution directly, or `Leakage` (0–1) to control the resolution/sidelobe trade-off indirectly. `TimeResolution` is spectrogram-only — do NOT use it for power spectrum. **Leakage parameter**: `pspectrum(x,Fs,Leakage=L)` where L ∈ [0,1] — 0 = minimum leakage (max sidelobe suppression, widest main lobe), 1 = maximum leakage (rectangular window, best resolution), default 0.5.

**Nonparametric vs Parametric:** Use nonparametric (FFT-based) when signal is long or spectral shape is unknown. Use parametric when data is short, signal matches an AR model, or you need super-resolution. See `references/estimator-comparison.md` for detailed trade-offs.

## Window Selection

| Goal | Window | Why |
|------|--------|-----|
| General-purpose PSD | **Hann** | Good balance, 50% overlap optimal |
| Detect weak tone near strong tone | **Blackman-Harris** or **Kaiser (beta≥10)** | Low sidelobes (-92 dB) |
| Resolve two close frequencies | **Hann** or **Kaiser (beta=5)** | Narrow main lobe |
| Accurate amplitude measurement | **Flat Top** | ~0.01 dB scalloping loss |
| Tunable trade-off | **Kaiser(N,beta)** | Single parameter controls curve |

**Key rule:** Higher sidelobe suppression costs wider main lobe. Only suppress as much as dynamic range requires. See `references/spectral-windows.md` for ENBW values and overlap guidelines.

## Key Functions

| Function | Purpose |
|----------|---------|
| `pspectrum` | Power spectrum with automatic defaults; `Leakage` parameter (0–1) controls resolution vs sidelobe suppression |
| `periodogram` | PSD or power spectrum via single-window DFT |
| `pwelch` | PSD via Welch's averaged periodogram |
| `pmtm` | PSD via Thomson's multitaper method (DPSS/Slepian tapers) |
| `cpsd` | Cross power spectral density |
| `mscohere` | Magnitude-squared coherence (0 to 1) |
| `pburg` / `pyulear` | AR PSD (Burg / Yule-Walker) |
| `pmusic` / `peig` | Pseudospectrum (MUSIC / eigenvector) |
| `rootmusic` | Frequency estimation via root-MUSIC |
| `findpeaks` | Locate spectral peaks |
| `refinepeaks` | Sub-bin peak frequency/amplitude refinement (use after `findpeaks`) |
| `bandpower` | Power in a frequency band |
| `obw` / `powerbw` | Occupied bandwidth / 3-dB power bandwidth |
| `meanfreq` / `medfreq` | Mean / median frequency of spectrum |
| `sfdr` | Spurious free dynamic range |
| `toi` | Third-order intercept point (two-tone intermodulation) |
| `spectralFlatness` | Spectral flatness (0=tonal, 1=white noise) |
| `spectralCrest` | Spectral peak-to-mean ratio |
| `spectralKurtosis` | Spectral kurtosis (transient/non-stationarity detection) |
| `poctave` | Fractional-octave spectrum |
| `plomb` | Lomb-Scargle periodogram (non-uniform data) |
| `spectralEntropy` | Spectral entropy (replaces deprecated `pentropy`) |
| `spectrumAnalyzer` | Live streaming spectrum/spectrogram display (DSP System Toolbox) |
| `dsp.SpectrumEstimator` | Streaming PSD/PS with numeric output (DSP System Toolbox) |
| `dsp.CrossSpectrumEstimator` | Streaming cross-spectrum between two signals (DSP System Toolbox) |

## Patterns

**Convention reminders** (apply to ALL code below):
- `pow2db(x)` for dB — NEVER `10*log10(x)`
- `detrend(x)` only when DC offset or trend is clearly an issue (e.g., large DC spike dominates spectrum)

### Single-Sided Amplitude Spectrum

```matlab
Fs = 1000;
N = length(x);
win = hann(N);

% periodogram with 'power' gives single-sided power per bin
% NFFT=N keeps df=Fs/N ([] defaults to nextpow2 which shifts grid)
[pxx,f] = periodogram(x,win,N,Fs,'power');
ampSpectrum = sqrt(pxx);  % power → RMS amplitude

figure
plot(f,ampSpectrum)
xlabel("Frequency (Hz)")
ylabel("Amplitude (RMS)")
title("Single-Sided Amplitude Spectrum")
```

Key points:
- Window correction handled automatically by `periodogram`
- Frequency resolution is always `Fs/N` — zero-padding only interpolates
- For manual FFT: multiply by `2/N` for single-sided amplitude, do NOT double DC

### PSD with Welch's Method

```matlab
Fs = 44100;
% x = detrend(x);  % uncomment if DC/trend distorts low-frequency estimates
segmentLength = round(Fs * 0.05);  % 50 ms → df = 20 Hz
win = hann(segmentLength);

[pxx,f] = pwelch(x,win,round(0.5*segmentLength),[],Fs);

figure
plot(f,pow2db(pxx))
xlabel("Frequency (Hz)")
ylabel("PSD (dB/Hz)")
title("Power Spectral Density (Welch)")
grid on
```

Key points:
- Segment length sets resolution: `df = Fs / segmentLength`
- More segments = lower variance but coarser resolution (trade-off)
- 50% overlap with Hann is optimal

### Spectral Peak Detection

See `references/peak-detection.md` for noise-floor-relative thresholds and harmonic detection.

```matlab
[pxx,f] = pwelch(x,hann(1024),[],[],Fs);
pxxDB = pow2db(pxx);

[peaks,locs] = findpeaks(pxxDB,f, ...
    MinPeakHeight=-20, ...
    MinPeakDistance=50, ...
    MinPeakProminence=10);

figure
plot(f,pxxDB)
hold on
plot(locs,peaks,"rv",MarkerFaceColor="r")
hold off
xlabel("Frequency (Hz)")
ylabel("Power/Frequency (dB/Hz)")
legend("PSD","Peaks")
```

### Band Power and Bandwidth

See `references/spectral-measurements.md` for full details including PSD input, power spectrum + rbw input, and spectral entropy.

```matlab
Fs = 1000;
pTotal = bandpower(x,Fs,[0 Fs/2]);
pBand = bandpower(x,Fs,[50 150]);
fracPower = pBand / pTotal;

bw = obw(x,Fs);       % 99% occupied bandwidth
pbw = powerbw(x,Fs);  % 3-dB bandwidth (narrowband/resonance signals only)
```

### Fractional-Octave Spectrum (poctave)

See `references/poctave-api.md` for full syntax, common mistakes, and octave smoothing pattern.

```matlab
Fs = 44100;

% 1/3-octave with A-weighting (environmental noise)
[p,cf] = poctave(x,Fs,'BandsPerOctave',3,'Weighting','A','FrequencyLimits',[20 20000]);

% From existing PSD (no recomputation needed)
[pxx,f] = pwelch(x,[],[],[],Fs);
[p,cf] = poctave(pxx,Fs,f,'BandsPerOctave',3);
```

Key points:
- **Use `'BandsPerOctave',3`** — do NOT use `'1/3 octave'` (invalid syntax)
- Only valid types: `'power'` (default), `'spectrogram'` — NO `'psd'` type
- Can accept pre-computed PSD: `poctave(pxx,Fs,f)` avoids reprocessing
- Output is always power — use `pow2db(p)` for dB display

### Cross-Spectral Comparison

```matlab
Fs = 1000;
segLen = 1024;
win = hann(segLen);

[pxy,f] = cpsd(x,y,win,segLen/2,[],Fs);
[cxy,f] = mscohere(x,y,win,segLen/2,[],Fs);

figure
tiledlayout(2,1)
nexttile
plot(f,pow2db(abs(pxy)))
ylabel("|CPSD| (dB)"); xlabel("Frequency (Hz)")
nexttile
plot(f,cxy)
ylabel("Coherence"); xlabel("Frequency (Hz)"); ylim([0 1])
```

Key points:
- `cpsd` is complex — use `abs` for magnitude, `angle` for phase lag
- Coherence ≈ 1: linearly related; ≈ 0: unrelated at that frequency
- Use same `win`/`overlap` as `pwelch` for consistent resolution

### Multitaper PSD (Thomson's Method)

```matlab
Fs = 1000;
nw = 4;  % time-halfbandwidth product (default); resolution bandwidth = 2*nw*Fs/N
[pxx,f] = pmtm(x,nw,[],Fs);

plot(f,pow2db(pxx))
xlabel("Frequency (Hz)"); ylabel("PSD (dB/Hz)")
```

Key points:
- Uses 2*nw-1 orthogonal DPSS (Slepian) tapers on the **full record** — no segmentation
- Variance reduction without sacrificing frequency resolution (unlike Welch)
- Resolution bandwidth = `2*nw*Fs/N` — increase `nw` for smoother PSD (wider bandwidth), decrease for finer resolution
- Ideal for short records where Welch can't segment, or when you need maximum spectral information from limited data
- Output is true PSD — directly comparable to `pwelch`
- Confidence intervals available: `[pxx,f,pxxc] = pmtm(x,nw,[],Fs,ConfidenceLevel=0.95)`
- **When to prefer over `pwelch`**: short data, can't afford to segment, or need optimal bias-variance without AR assumptions
- **When to prefer over `pburg`**: no prior knowledge that signal is AR-like; want a nonparametric estimate

### Parametric PSD (Burg Method)

```matlab
Fs = 1000;
modelOrder = 16;  % 2*numPeaks to 4*numPeaks
[pxx,f] = pburg(x,modelOrder,[],Fs);

plot(f,pow2db(pxx))
xlabel("Frequency (Hz)"); ylabel("PSD (dB/Hz)")
```

Key points:
- Order too low = over-smoothed; too high = spurious peaks
- Burg preferred over Yule-Walker (less biased for short data)
- Output is true PSD — comparable to `pwelch`

### Frequency Estimation with MUSIC

```matlab
Fs = 1000;
nSinusoids = 2;
p = 2*nSinusoids;  % subspace dim: 2 per real sinusoid (pos + neg freq)

[pseudoSpectrum,f] = pmusic(x,p,1024,Fs);
freqEstimates = rootmusic(x,p,Fs);  % more accurate than reading peaks
```

Key points:
- **MUSIC output is a pseudospectrum, NOT a PSD** — peak heights ≠ power
- **`p` = 2 × number of real sinusoids** — using `p = nSinusoids` gives wrong results
- `rootmusic` gives more accurate frequencies than reading `pmusic` peaks
- Works best for sinusoids in white noise; short data OK if SNR adequate

### Manual FFT-Based PSD (When User Insists)

Only when user explicitly needs manual FFT. See `references/manual-fft-psd.md` for windowed, power spectrum, and complex-valued variants.

Formula: `psdx = (1/(Fs*N)) * abs(fft(x)(1:N/2+1)).^2`, double interior bins only (not DC/Nyquist). Windowed: normalize by `1/(Fs*sum(win.^2))`.

## Conventions

- **Use `pspectrum` as default** — redirect manual FFT users to built-in functions
- **Detrend when warranted** — apply `detrend(x)` when DC/trend visibly dominates the spectrum or distorts low-frequency estimates; do not blindly detrend every signal
- **Label axes with units** — "Frequency (Hz)", "PSD (dB/Hz)", "Amplitude (V)"
- **`pow2db`/`db2pow`** for dB — never `10*log10(...)` manually. See `references/units-and-db.md` for domain-specific reference levels
- **Frequency resolution is `Fs/N`** — zero-padding only interpolates
- **Use built-in measurement functions** — `bandpower`, `obw`, `powerbw`, `findpeaks`
- **Favor convenience plots** — calling `pwelch(x,[],[],[],Fs)`, `pspectrum(x,Fs)`, `pburg(x,order,[],Fs)`, etc. without output arguments generates a labeled plot automatically; prefer this over manual plotting when a quick visualization is needed
- **Write a script** — when performing multi-step analysis, write the complete workflow as a `.m` script and run it with `run_matlab_file`, rather than executing code piecemeal across multiple `evaluate_matlab_code` calls. This produces a reviewable, reproducible artifact

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| `fft(x)` without window | Apply `hann(N)` or similar |
| `abs(fft(x)).^2` as "PSD" | Use `periodogram`/`pwelch`; if manual, scale by `1/(Fs*N)` and double interior only |
| Confusing PSD with power spectrum | PSD = power/Hz; PS = power/bin |
| Zero-padded FFT = higher resolution | Zero-padding interpolates, doesn't resolve |
| `10*log10(pxx)` | Use `pow2db` |
| Manual integration for band power | Use `bandpower(x,Fs,[fLow fHigh])` |
| Comparing `pspectrum` to `pwelch` directly | Different units (PS vs PSD). See `references/pspectrum-equivalence.md` |
| Using `pentropy` | Deprecated — use `spectralEntropy` instead |
| `pspectrum(...,'TimeResolution',val)` for power spectrum | `TimeResolution` is spectrogram-only. Use `'FrequencyResolution',val` or `'Leakage',val` |
| `obw(x,Fs,[],'Percentpower',pct)` | `obw` uses positional args, not name-value. Correct: `obw(x,Fs,[fLow fHigh],pct)` where `pct` is the 4th positional arg |
| Filter-bank tone power reads 1–3 dB low | Tone is between bins — filter-bank has narrow pass-bands. Fix: coherent frame length (`frameLen = Fs/df`) so tones land on bin centers |
| `snr(x,Fs)` unstable for multi-tone with harmonic relationships | `snr` classifies harmonics specially — 200 Hz = 2nd harmonic of 100 Hz causes inconsistent results. Use per-tone SNR from spectrum instead |

## Troubleshooting

See `references/troubleshooting.md` for detailed explanations and code examples.

- **"Two tones but only one peak"** — Resolution limit (`Fs/N`) or sidelobe masking. Fix: more data, lower-sidelobe window (`blackmanharris`, `kaiser(N,15)`), or reassigned periodogram (`[pxx,f,rpxx,fc] = periodogram(x,win,N,Fs,'reassigned')` — 4-output syntax returns reassigned PSD and center-of-energy frequencies for sharper peak localization).
- **"Tone power is wrong"** — Scalloping loss (tone between bins). Fix: `flattopwin(N)` for amplitude accuracy. Worst case: Hann loses 1.4 dB, Flat Top loses 0.01 dB.

## Verification

Verify with Parseval's theorem — total power from spectrum should match time-domain. See `references/power-from-spectrum.md` for formulas.

```matlab
pTime = sum(x.^2)/length(x);
pFreq = sum(pxx) * (f(2)-f(1));  % integrate PSD
assert(abs(pTime - pFreq)/pTime < 0.02,"Parseval check failed")
```

----

Copyright 2026 The MathWorks, Inc.

----
