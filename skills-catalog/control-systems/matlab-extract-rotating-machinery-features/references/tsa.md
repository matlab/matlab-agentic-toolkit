---
name: time-synchronous-averaging
description: "Apply time-synchronous averaging to time series data and extract periodic or residual components of the signals. Use when processing data from rotating machinery where the rotation speed (rpm) can be used to resample and clean the data before feature extraction."
---

# Time-Synchronous Averaging

Apply time-synchronous averaging (TSA) to rotating machinery vibration signals to average out non-periodic components and isolate signal content that is periodic with shaft rotation. TSA is the recommended preprocessing step before extracting gear and shaft features.

## When to Use

- Processing vibration data from rotating machinery where a tachometer signal or RPM profile is available.
- Isolating periodic (gear mesh, shaft) components from noise before feature extraction.
- Extracting the residual or difference signal to expose fault-related content.

## When NOT to Use

- When no tachometer or RPM information is available to define the rotation phase.
- When the rotation speed is highly variable (apply order tracking `ordertrack` first).

## Workflow

- If a tachometer signal is available, estimate the RPM with `tachorpm`.
- Compute the time-synchronous average with `tsa`.
- Extract the regular signal (`tsaregular`), difference signal (`tsadifference`), or residual signal (`tsaresidual`) to isolate fault-related content.

## API Reference

The signatures below are the ones needed for this workflow. A common mistake is calling the `tsa*` residual/difference/regular functions with just `(signal, fs)` — they also require the rotational speed and an order list. Follow the syntax exactly; consult the linked documentation for name-value arguments not shown here.

**Pulse times vs. tachometer waveform — read this first.** `tachorpm` takes a *raw tachometer pulse waveform* (the sampled voltage trace of the tach channel) and detects the pulses in it. It does **not** take a list of pulse *times*. `tsa`, by contrast, takes pulse *times* directly as its `tp` argument. So: **if you already have pulse times, pass them straight to `tsa` and do not call `tachorpm`.** Only call `tachorpm` when you have a raw tach channel and need to recover rpm/pulse locations from it.

### Time-Synchronous Data Processing

- **`tachorpm`** (Signal Processing Toolbox, R2016b) — extract an RPM signal from a raw tachometer **pulse waveform**.
  - `[rpm,t,tp] = tachorpm(x,Fs)` — `x` the sampled tach voltage trace (a waveform, **not** pulse times), `Fs` sample rate; returns the rpm profile, its time vector, and detected pulse locations `tp`.
  - Name-value: `PulsesPerRev` (default 1) — note the spelling (`PulsesPerRev`, not `PulsesPerRevolution`), `StateLevels`, `OutputFs`, `FitType`.
  - **Do not call this on a vector of pulse times** — it will report "no pulses detected". Pulse times go directly into `tsa`.
  - Docs: <https://www.mathworks.com/help/signal/ref/tachorpm.html>

- **`tsa`** (Signal Processing Toolbox, R2017b) — time-synchronous signal average.
  - `ta = tsa(x,fs,tp)` — `x` signal vector, `fs` sample rate, `tp` **pulse times** (scalar or vector). Pass a timetable `xt` in place of `(x,fs)`: `tsa(xt,tp)`.
  - `[ta,t,p,rpm] = tsa(___)` also returns sample times, phase, and the constant rotational speed.
  - Name-value: `Method` (`"linear"`|`"spline"`|`"pchip"`|`"fft"`), `NumRotations`, `PulsesPerRotation`, `ResampleFactor`.
  - Docs: <https://www.mathworks.com/help/signal/ref/tsa.html>

- **`tsaresidual`** (Predictive Maintenance Toolbox, R2018b) — residual signal of a TSA signal (removes shaft/gear-mesh orders and their harmonics).
  - `Y = tsaresidual(X,fs,rpm,orderList)` — `X` TSA signal vector, `fs` sample rate, `rpm` shaft speed (positive scalar), `orderList` orders to filter out. Pass a TSA timetable `XT` in place of `(X,fs)`: `tsaresidual(XT,rpm,orderList)`. **Requires `rpm` and `orderList` — not just `(signal,fs)`.**
  - `[Y,S] = tsaresidual(___)` also returns the amplitude spectrum.
  - Name-value: `NumHarmonics` (default 2), `NumRotations`, `Domain` (`'order'` default | `'frequency'`).
  - Docs: <https://www.mathworks.com/help/predmaint/ref/tsaresidual.html>

- **`tsadifference`** (Predictive Maintenance Toolbox, R2018b) — difference signal of a TSA signal.
  - `Y = tsadifference(X,fs,rpm,orderList)` — same argument pattern as `tsaresidual` (timetable form: `tsadifference(XT,rpm,orderList)`); `[Y,S] = tsadifference(___)` also returns the amplitude spectrum.
  - Name-value: `NumHarmonics`, `NumSidebands` (default 1), `NumRotations`, `Domain`.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/tsadifference.html>

- **`tsaregular`** (Predictive Maintenance Toolbox, R2018b) — regular signal of a TSA signal (retains specified orders).
  - `Y = tsaregular(X,fs,rpm,orderList)` — same argument pattern (timetable form: `tsaregular(XT,rpm,orderList)`); here `orderList` is the orders to *retain*. `[Y,S] = tsaregular(___)` also returns the amplitude spectrum.
  - Name-value: `NumHarmonics`, `NumSidebands` (default 0), `NumRotations`, `Domain`.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/tsaregular.html>

### Reference Examples
- [Vibration Analysis of Rotating Machinery](https://www.mathworks.com/help/signal/ug/vibration-analysis-of-rotating-machinery.html)

----

Copyright 2026 The MathWorks, Inc.

