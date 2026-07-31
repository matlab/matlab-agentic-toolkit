---
name: vibration
description: "Convert and condition raw vibration measurements from accelerometers, velocity sensors, or displacement sensors before feature extraction. Use when preparing vibration sensor data from rotating machinery for condition monitoring."
---

# Vibration Data Processing

Condition raw vibration measurements before extracting features. A single vibration sensor measures acceleration, velocity, or displacement; deriving baseline-corrected and filtered versions of all three quantities makes downstream feature extraction more reliable.

## When to Use

- Preparing raw accelerometer, velocity, or displacement measurements for feature extraction.
- Deriving acceleration, velocity, and displacement signals from a single vibration sensor.
- Removing baseline offset and drift from vibration measurements.

## When NOT to Use

- When the measurements are not vibration signals (e.g., electrical or environmental sensors).

## Workflow

- Use `convertVibration` to compute baseline-corrected and filtered acceleration, velocity, and displacement signals from a single sensor output.
- Follow the main rotating machinery feature extraction workflow for downstream processing and feature extraction.

## API Reference

The signature below is the one needed for this workflow. Follow it exactly; consult the linked documentation for name-value arguments not shown here.

### Vibration Data Processing

- **`convertVibration`** (Predictive Maintenance Toolbox, R2024a) — compute baseline-corrected and filtered acceleration, velocity, and displacement signals from a single accelerometer, velocity, or displacement sensor.
  - `[A,V,D] = convertVibration(X,Fs)` — `X` measured vibration vector, `Fs` sampling rate; returns acceleration `A`, velocity `V`, displacement `D`. For a timetable, use `convertVibration(T,Variable=var)`. `[___,Options] = convertVibration(___)` also returns the options struct.
  - Name-value: `Type` (`"acceleration"` default | `"velocity"` | `"displacement"`), `Fmin` (default `Fs/500`), `Fmax` (default `Fs/5`).
  - **Available from R2024a** — for earlier releases, condition the signal manually.
  - Docs: <https://www.mathworks.com/help/signal/ref/convertVibration.html>

### Reference Examples
- [Vibration Analysis of Rotating Machinery](https://www.mathworks.com/help/signal/ug/vibration-analysis-of-rotating-machinery.html)

----

Copyright 2026 The MathWorks, Inc.


