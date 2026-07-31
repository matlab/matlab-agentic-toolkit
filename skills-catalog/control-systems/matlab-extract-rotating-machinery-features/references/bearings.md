---
name: bearing-faults
description: "Extract features suitable for detecting faults in ball and roller bearings. Geometric parameters of the bearing, along with its rotational speed, help identify characteristic fault frequencies. Use when developing condition monitoring or fault detection capabilities for bearing components in rotating machinery."
---

# Extract Features from Bearing Vibration Signals

Extract predictive features from bearing vibration signals for condition monitoring and fault detection. This skill covers the essential feature extraction techniques specialized to bearings.

Bearing vibration data exhibits high-frequency structural resonances modulated by low-frequency impacts. Bearing faults change the characteristics of these impacts. Therefore envelope analysis is the primary technique for bearing fault detection, including `envelope`, `envspectrum`, and `bandpass` processing of vibration data.

Bearings exhibit characteristic faults at the following frequencies:
- Outer race defect frequency, Fo, and its harmonics
- Inner race defect frequency, Fi, its harmonics and sidebands at shaft rpm, Fr
- Rolling element (ball) defect frequency, Fb, its harmonics and sidebands at Fc
- Cage (train) defect frequency, Fc

The characteristic frequencies depend on the geometry of the bearing and the shaft speed, Fr. Ask the user the following information:
- Rotational speed of the shaft or inner race
- Number of balls or rollers
- Diameter of the ball or roller
- Pitch diameter
- Contact angle

Specialized features for bearing condition monitoring, computed on the envelope signal, include:
- Root-mean square
- Kurtosis
- Crest factor

## When to Use

- User wants to generate features for bearing condition monitoring.
- User knows the geometric parameter values to characterize the bearing fault frequencies.
- User wants to identify frequencies of interest for bearing condition monitoring.

## When NOT to Use

- When the rotation speed (rpm) of the bearing races during data collection is highly variable. However, order tracking `ordertrack` can be used as a preliminary step.

## Workflow

- Use the same steps as the main rotating machinery feature extraction workflow plus the specialized steps below for bearings.
- Determine the geometric parameters of the bearing.
- Identify characteristic fault frequencies based on bearing geometry (`bearingFaultBands`) and the rotation speed.
- Use `bandpass` filtering (around structural resonances) and envelope demodulation as the main data processing steps. Use `kurtogram` or `spectralKurtosis` to identify bandpass center frequencies.
- Identify fault metrics relevant to bearings using `faultBandMetrics` or statistical metrics such as `kurtosis`, `rms`, or `peak2rms`.

## API Reference

The signatures below are the ones needed for this workflow. Follow them exactly; consult the linked documentation for name-value arguments not shown here.

### Data Processing

- See [tsa.md](tsa.md) for time series data processing techniques suitable for time-synchronous data.
- See [spectral.md](spectral.md) for spectral data processing techniques suitable for modulated time series data.

- **`envspectrum`** (Signal Processing Toolbox, R2017b) — envelope spectrum for machinery diagnosis.
  - `[es,f,env,t] = envspectrum(x,fs)` — pass a timetable `xt` in place of `(x,fs)`; returns envelope spectrum, frequency vector, envelope signal, and time vector.
  - Name-value: `Method` (`"demod"` default | `"hilbert"`), `Band` (two-element band, default `[fs/4 fs*3/8]`), `FilterOrder`.
  - Docs: <https://www.mathworks.com/help/signal/ref/envspectrum.html>

- **`envelope`** (Signal Processing Toolbox, R2015b) — signal envelope.
  - `[yupper,ylower] = envelope(x)` (analytic, default); other methods: `envelope(x,fl,'analytic')` / `envelope(x,wl,'rms')` / `envelope(x,np,'peak')`.
  - Docs: <https://www.mathworks.com/help/signal/ref/envelope.html>

- **`kurtogram`** (Signal Processing Toolbox, R2018a) — fast kurtogram to select a bandpass band.
  - `[kgram,f,w,fc,wc,bw] = kurtogram(x,sampx)` — `sampx` is sample rate or sample time (or pass a timetable `xt`). `fc` is the center frequency of maximal spectral kurtosis and `bw` the suggested bandwidth: use `[fc-bw/2 fc+bw/2]` for `bandpass`/`envspectrum`.
  - Docs: <https://www.mathworks.com/help/signal/ref/kurtogram.html>

- **`spectralKurtosis`** (Signal Processing Toolbox, R2019a) — spectral kurtosis of a signal.
  - `kurtosis = spectralKurtosis(x,f)` — `f` is the sample rate/time or frequency vector (or pass a timetable `xt`).
  - Docs: <https://www.mathworks.com/help/signal/ref/spectralkurtosis.html>

### Characteristic Fault Frequencies

- **`bearingFaultBands`** (Predictive Maintenance Toolbox, R2019b) — frequency bands around bearing characteristic fault frequencies.
  - `[FB,info] = bearingFaultBands(FR,NB,DB,DP,beta)` — `FR` shaft/inner-race speed (positive scalar), `NB` number of balls/rollers (positive integer), `DB` ball/roller diameter, `DP` pitch diameter, `beta` contact angle **in degrees** (non-negative scalar). `FB` is the Nx2 band array; `info` exposes the characteristic frequencies in `info.Centers` and their names (`1Fo`, `1Fi`, `1Fb`, `1Fc`) in `info.Labels`. **2-output form — there is no 4-output form.**
  - Name-value: `Harmonics` (default 1), `Sidebands` (default 0), `Width`, `Domain` (`'frequency'` default | `'order'`).
  - Docs: <https://www.mathworks.com/help/predmaint/ref/bearingfaultbands.html>

- **`faultBands`** (Predictive Maintenance Toolbox, R2019b) — generic fault frequency bands from a fundamental and its sidebands.
  - `[FB,info] = faultBands(F0,N0)`, or add sideband spacing/orders with `faultBands(F0,N0,F1,N1)`.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/faultbands.html>

### Spectral Feature (Metrics) Extraction

- **`faultBandMetrics`** (Predictive Maintenance Toolbox, R2019b) — spectral metrics for the specified fault bands of a PSD.
  - `spectralMetrics = faultBandMetrics(psd,freqGrid,FB)` — `psd` power spectral density, `freqGrid` matching frequency vector, `FB` the Nx2 band array from `bearingFaultBands`/`faultBands`. **Three positional inputs; do not pass labels or an info struct.**
  - **Output shape:** `spectralMetrics` is a one-row table with a `PeakAmplitude`_k_, `PeakFrequency`_k_, `BandPower`_k_ triplet **per band** (k = 1…N for the N rows of `FB`) plus a final `TotalBandPower`. There is **no scalar `BandPower` column** — index a specific band as `spectralMetrics.BandPower1`, or use `spectralMetrics.TotalBandPower` for the aggregate.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/faultbandmetrics.html>

### Reference Examples

- When applicable, fetch [Vibration Analysis of Rotating Machinery](https://www.mathworks.com/help/signal/ug/vibration-analysis-of-rotating-machinery.html).
- When applicable, fetch [Rolling Element Bearing Fault Diagnosis](https://www.mathworks.com/help/predmaint/ug/Rolling-Element-Bearing-Fault-Diagnosis.html).

----

Copyright 2026 The MathWorks, Inc.

