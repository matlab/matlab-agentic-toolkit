---
name: spectral-data-processing
description: "Demodulate and analyze the spectral content of modulated rotating machinery vibration signals. Use when extracting spectral features from vibration data, especially envelope spectra for bearing and impact-driven faults."
---

# Spectral Data Processing

Extract spectral features from rotating machinery vibration signals. Rotating machinery faults produce modulated signals: high-frequency structural resonances carry low-frequency fault impacts. Demodulate first, then extract spectral features from the demodulated signal.

## When to Use

- Extracting spectral features (band power, peak frequencies) from vibration data.
- Analyzing modulated signals where fault impacts modulate a high-frequency carrier.
- Computing the envelope spectrum to expose bearing and impact-driven fault frequencies.

## When NOT to Use

- When the signal is periodic with shaft rotation and better handled by time-synchronous averaging (see [tsa.md](tsa.md)).
- When the data is very low-frequency and not suitable for spectral feature extraction.

## Workflow

- For modulated signals, demodulate using the signal envelope (`envelope`) or the envelope spectrum (`envspectrum`).
- For bearing signals, apply `bandpass` filtering around a structural resonance before demodulation; select the band with `kurtogram` or `spectralKurtosis`.
- Extract spectral features such as band power (`bandpower`) and spectral peaks and their frequencies.
- For fault-specific bands, compute spectral metrics with `faultBandMetrics` over bands from `bearingFaultBands` or `gearMeshFaultBands`.

## API Reference

The signatures below are the ones needed for this workflow. Follow them exactly; consult the linked documentation for name-value arguments not shown here.

### Spectral Analysis and Demodulation

- **`envspectrum`** (Signal Processing Toolbox, R2017b) — envelope spectrum for machinery diagnosis.
  - `[es,f,env,t] = envspectrum(x,fs)` — pass a timetable `xt` in place of `(x,fs)`; returns envelope spectrum, frequency vector, envelope signal, and time vector.
  - Name-value: `Method` (`"demod"` default | `"hilbert"`), `Band` (two-element band, default `[fs/4 fs*3/8]`), `FilterOrder`.
  - Docs: <https://www.mathworks.com/help/signal/ref/envspectrum.html>

- **`envelope`** (Signal Processing Toolbox, R2015b) — signal envelope.
  - `[yupper,ylower] = envelope(x)`; other methods: `envelope(x,fl,'analytic')` / `envelope(x,wl,'rms')` / `envelope(x,np,'peak')`.
  - Docs: <https://www.mathworks.com/help/signal/ref/envelope.html>

- **`bandpass`** (Signal Processing Toolbox, R2018a) — bandpass-filter a signal.
  - `[y,d] = bandpass(x,fpass,fs)` — `fpass` is a two-element `[low high]` band in Hz (elements in `(0, fs/2)`); pass a timetable `xt` in place of `(x,fs)`. `d` is the `digitalFilter` object.
  - Name-value: `ImpulseResponse` (`"auto"` default | `"fir"` | `"iir"`), `Steepness`, `StopbandAttenuation`.
  - Docs: <https://www.mathworks.com/help/signal/ref/bandpass.html>

- **`kurtogram`** (Signal Processing Toolbox, R2018a) — fast kurtogram to select a bandpass band.
  - `[kgram,f,w,fc,wc,bw] = kurtogram(x,sampx)` — `sampx` is sample rate or sample time (or pass a timetable `xt`); `fc` is the center frequency and `bw` the suggested bandwidth (use `[fc-bw/2 fc+bw/2]` as the bandpass band).
  - Docs: <https://www.mathworks.com/help/signal/ref/kurtogram.html>

- **`spectralKurtosis`** (Signal Processing Toolbox, R2019a) — spectral kurtosis of a signal.
  - `kurtosis = spectralKurtosis(x,f)` — `f` is the sample rate/time or frequency vector (or pass a timetable `xt`).
  - Docs: <https://www.mathworks.com/help/signal/ref/spectralkurtosis.html>

- **`bandpower`** (Signal Processing Toolbox, R2013a) — average band power.
  - `p = bandpower(x,Fs,freqRange)` from a time series (`freqRange` a two-element `[low high]` vector or M-by-2 matrix), or `p = bandpower(pxx,f,freqRange,"psd")` from a precomputed PSD `pxx` on frequency grid `f`.
  - Docs: <https://www.mathworks.com/help/signal/ref/bandpower.html>

### Spectral Feature (Metrics) Extraction

- **`faultBandMetrics`** (Predictive Maintenance Toolbox, R2019b) — spectral metrics for specified fault bands of a PSD.
  - `spectralMetrics = faultBandMetrics(psd,freqGrid,FB)` — `psd` power spectral density, `freqGrid` matching frequency vector, `FB` the Nx2 fault-band array from `bearingFaultBands`/`gearMeshFaultBands`/`faultBands`. **Three positional inputs; do not pass labels or an info struct.**
  - **Output shape:** `spectralMetrics` is a one-row table with a `PeakAmplitude`_k_, `PeakFrequency`_k_, `BandPower`_k_ triplet **per band** (k = 1…N for the N rows of `FB`) plus a final `TotalBandPower`. There is **no scalar `BandPower` column** — index a specific band as `spectralMetrics.BandPower1`, or use `spectralMetrics.TotalBandPower` for the aggregate.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/faultbandmetrics.html>

----

Copyright 2026 The MathWorks, Inc.

----
