# Streaming Spectral Analysis

Use streaming (frame-based) spectral tools when data arrives continuously in frames rather than as a single batch vector. Streaming tools maintain internal state (averaging, hold traces) across calls and are designed for real-time or near-real-time processing loops.

## When to Use Streaming

| Indicator | Use streaming |
|-----------|--------------|
| Data arrives frame-by-frame (sensor, ADC, audio device) | Yes |
| Processing inside a `while`/`for` loop feeding frames | Yes |
| Need live-updating visualization | Yes — `spectrumAnalyzer` |
| Need programmatic spectrum output each frame | Yes — `dsp.SpectrumEstimator` |
| Entire signal already in workspace | No — use batch (`pwelch`, `pspectrum`, etc.) |
| One-shot analysis of a recording | No — use batch |

## Streaming Tools (DSP System Toolbox required)

### spectrumAnalyzer — Live Visualization

Real-time spectrum display. Use when you need to **see** the power spectrum or PSD updating live. **Note:** `spectrumAnalyzer` also supports spectrogram and combined views (`ViewType="spectrogram"` or `"spectrum-and-spectrogram"`), but those are time-frequency analysis — out of scope for this skill.

```matlab
Fs = 44100;
frameLen = 1024;

scope = spectrumAnalyzer( ...
    SampleRate=Fs, ...
    Method="filter-bank", ...
    SpectrumType="power-density", ...
    PlotAsTwoSidedSpectrum=false, ...
    FrequencyScale="linear", ...
    ViewType="spectrum");

% Streaming loop
for k = 1:numFrames
    x = audioIn();  % acquire frame
    scope(x);       % update display
end
release(scope);
```

**Key properties:**

| Property | Values | Notes |
|----------|--------|-------|
| `Method` | `"welch"`, `"filter-bank"` | **Prefer `"filter-bank"`** for accurate noise floor and minimal leakage; use `"welch"` only when matching batch `pwelch` results. **Caveat:** filter-bank has narrow pass-bands — tones between bins lose up to 3 dB (worse than Welch). Fix: choose `frameLen` so target frequencies land on bin centers (`frameLen = Fs/desiredResolution`, e.g., `frameLen = Fs` for 1 Hz bins). |
| `ViewType` | `"spectrum"` (in scope), `"spectrogram"`, `"spectrum-and-spectrogram"` | Spectrogram/combined views are time-frequency (out of scope) |
| `SpectrumType` | `"power"`, `"power-density"`, `"rms"` | Same meaning as batch |
| `RBWSource` | `"auto"`, `"property"` | Controls frequency resolution |
| `AveragingMethod` | `"vbw"`, `"exponential"`, `"running"` | VBW = video bandwidth (default) |
| `PlotMaxHoldTrace` | `true`/`false` | Overlay max-hold envelope |
| `PlotMinHoldTrace` | `true`/`false` | Overlay min-hold envelope |
| `FrequencyScale` | `"linear"`, `"log"` | Log useful for wideband |

**Built-in measurements** (enable via properties):
- `PeakFinder` — locate and label top N peaks on the display
- `DistortionMeasurements` — THD, SINAD, SNR, SFDR (harmonic or intermodulation)
- `CursorMeasurements` — interactive frequency/power readout
- `ChannelMeasurements` — power in user-defined bands
- `PhaseNoise` — phase noise measurement (dBc/Hz at specified offsets)
- `SpectralMask` — pass/fail testing against a user-defined spectral mask

```matlab
scope.PeakFinder.Enabled = true;
scope.PeakFinder.NumPeaks = 5;
scope.DistortionMeasurements.Enabled = true;
```

**ChannelMeasurements — ACPR usage:**

```matlab
scope.ChannelMeasurements.Enabled          = true;
scope.ChannelMeasurements.Type             = "acpr";  % MUST set explicitly (default is "occupied-bandwidth")
scope.ChannelMeasurements.FrequencySpan    = "span-and-center-frequency";
scope.ChannelMeasurements.CenterFrequency  = 150;
scope.ChannelMeasurements.Span             = 120;
scope.ChannelMeasurements.NumOffsets       = 1;
scope.ChannelMeasurements.ACPROffsets      = 100;
scope.ChannelMeasurements.AdjacentBW       = 80;
```

**ChannelMeasurements gotchas:**
- Default `Type` is `"occupied-bandwidth"` — ACPR properties are **silently ignored** unless you set `Type="acpr"`
- Read results with `m = getMeasurementsData(scope); m.ChannelMeasurements` — fields are `ChannelPower`, `ACPRLower`, `ACPRUpper`
- DC boundary: ensure `CenterFrequency - ACPROffsets - AdjacentBW/2 > 0`, otherwise lower ACPR = NaN

### dsp.SpectrumEstimator — Programmatic Output

Returns the spectrum as a numeric vector each frame. Use when you need the **data** (not just visualization) for downstream processing, thresholding, or logging.

```matlab
Fs = 1000;
frameLen = 256;

se = dsp.SpectrumEstimator( ...
    SampleRate=Fs, ...
    SpectrumType="Power density", ...
    FrequencyRange="onesided", ...
    Method="Welch", ...
    Window="Hann", ...
    AveragingMethod="Running", ...
    SpectralAverages=8);

for k = 1:numFrames
    x = sensorRead();
    pxx = se(x);           % [frameLen/2+1 x 1] PSD vector
end
f = getFrequencyVector(se);  % corresponding frequency axis
release(se);
```

**Key properties:**

| Property | Values | Notes |
|----------|--------|-------|
| `Method` | `"Welch"`, `"Filter bank"` | Same algorithms as spectrumAnalyzer. Filter bank: same coherent-frame-length caveat applies (choose `frameLen` so tones land on bin centers). |
| `SpectrumType` | `"Power"`, `"Power density"` | Power = PS, Power density = PSD |
| `FrequencyRange` | `"onesided"`, `"twosided"`, `"centered"` | Use onesided for real signals |
| `AveragingMethod` | `"Running"`, `"Exponential"` | Exponential forgets old frames (tunable `ForgettingFactor`) |
| `SpectralAverages` | integer (default 8) | How many frames to average (Running mode) |
| `OutputMaxHoldSpectrum` | `true`/`false` | Second output = max-hold |
| `OutputMinHoldSpectrum` | `true`/`false` | Third output = min-hold |
| `PowerUnits` | `"Watts"`, `"dBW"`, `"dBm"` | Output units |

**Getting the frequency vector:** Call `f = getFrequencyVector(se)` after at least one call to the object.

### dsp.CrossSpectrumEstimator — Streaming Cross-Spectrum

Computes cross-power spectral density between two signals frame-by-frame. Use for streaming coherence analysis, transfer path estimation, or correlation tracking.

```matlab
Fs = 1000;
frameLen = 256;

cse = dsp.CrossSpectrumEstimator( ...
    FrequencyRange="onesided", ...
    Window="Hann", ...
    AveragingMethod="Running", ...
    SpectralAverages=8);

for k = 1:numFrames
    x = inputSignal();
    y = outputSignal();
    pxy = cse(x,y);  % complex cross-spectrum
end
release(cse);
```

**Notes:**
- Output is complex — use `abs(pxy)` for magnitude, `angle(pxy)` for phase
- Both inputs must have the same frame size and data type
- No `SampleRate` property — frequency axis is normalized; scale manually: `f = (0:numel(pxy)-1)' * Fs/frameLen` (for onesided, up to Fs/2)

### dsp.TransferFunctionEstimator — Streaming H(f)

Estimates the transfer function H(f) = Pxy/Pxx between input and output signals. Optionally outputs coherence.

```matlab
tfe = dsp.TransferFunctionEstimator( ...
    FrequencyRange="onesided", ...
    Window="Hann", ...
    SpectralAverages=16, ...
    OutputCoherence=true);

for k = 1:numFrames
    x = excitation();
    y = response();
    [H,C] = tfe(x,y);  % transfer function + coherence
end
release(tfe);
```

## Batch vs Streaming Decision

Ask (or infer) early:

1. **Is all data already available?** → Batch (`pwelch`, `pspectrum`, `periodogram`, etc.)
2. **Does data arrive in frames for continuous processing?** → Streaming (System objects above)
3. **Need live visualization during acquisition?** → `spectrumAnalyzer`
4. **Need spectrum values for real-time decision-making?** → `dsp.SpectrumEstimator`

## Mapping Batch to Streaming Equivalents

| Batch function | Streaming equivalent | Notes |
|----------------|---------------------|-------|
| `pwelch` | `dsp.SpectrumEstimator(Method="Welch")` | Averaging across frames instead of segments |
| `cpsd` | `dsp.CrossSpectrumEstimator` | Same Welch averaging |
| `mscohere` | `dsp.TransferFunctionEstimator(OutputCoherence=true)` | Coherence as second output |
| `periodogram` | `dsp.SpectrumEstimator(SpectralAverages=1)` | Single-frame, no averaging |
| `pspectrum` (visualization) | `spectrumAnalyzer` | Live equivalent with built-in measurements |

## Common Patterns

### Detect threshold crossing in real time

```matlab
se = dsp.SpectrumEstimator(SampleRate=Fs,FrequencyRange="onesided",SpectrumType="Power density");
threshold_dBHz = -40;

for k = 1:numFrames
    x = acquire(frameLen);
    pxx = se(x);
    f = getFrequencyVector(se);
    if any(pow2db(pxx(f > 100 & f < 500)) > threshold_dBHz)
        disp("Alert: signal detected in 100-500 Hz band")
    end
end
release(se);
```

### Exponential averaging (track slow changes, forget transients)

```matlab
se = dsp.SpectrumEstimator( ...
    SampleRate=Fs, ...
    FrequencyRange="onesided", ...
    AveragingMethod="Exponential", ...
    ForgettingFactor=0.95);  % 0.9 = fast adaptation, 0.99 = slow/smooth
```

## Requirements

- **DSP System Toolbox** is required for all streaming System objects
- Signal Processing Toolbox alone only provides batch functions
- `spectrumAnalyzer` replaced `dsp.SpectrumAnalyzer` in R2022a (same functionality, simplified name)

----

Copyright 2026 The MathWorks, Inc.
