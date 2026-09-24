# Function Arguments Reference

## Psychoacoustic Metrics

### acousticLoudness

```matlab
loudness = acousticLoudness(audioIn, fs, calibrationFactor)
[loudness, specificLoudness] = acousticLoudness(audioIn, fs, calibrationFactor)
[loudness, specificLoudness, perc] = acousticLoudness(___, TimeVarying=true, Percentiles=p)
```

| Argument | Default | Values |
|----------|---------|--------|
| `calibrationFactor` | `sqrt(8)` | Positive scalar (3rd positional arg) |
| `Method` | `"ISO 532-1"` | `"ISO 532-1"` (Zwicker), `"ISO 532-2"` (Moore-Glasberg) |
| `TimeVarying` | `false` | `true` enables time-varying analysis |
| `SoundField` | `"free"` | `"free"`, `"diffuse"`, `"eardrum"`, `"earphones"` |
| `EarphoneResponse` | `[0,0]` | M-by-2 matrix (for earphones mode) |
| `PressureReference` | `20e-6` | Positive scalar (Pa) |
| `Percentiles` | `[0,5]` | Vector of percentile values [0–100] |
| `TimeResolution` | `"standard"` | `"standard"` (2 ms), `"high"` |

Alternative input: `acousticLoudness(SPLIn)` where SPLIn is 1-by-28-by-C (ISO 532-1) or 1-by-29-by-C (ISO 532-2) sound pressure levels in dB.

### acousticSharpness

```matlab
sharpness = acousticSharpness(audioIn, fs, calibrationFactor)
```

| Argument | Default | Values |
|----------|---------|--------|
| `calibrationFactor` | `sqrt(8)` | Positive scalar (3rd positional arg) |
| `Weighting` | `"DIN 45692"` | `"DIN 45692"`, `"Aures"`, `"von Bismarck"` |
| `SoundField` | `"free"` | `"free"`, `"diffuse"` |
| `TimeVarying` | `false` | `true` for time-varying output |
| `PressureReference` | `20e-6` | Positive scalar (Pa) |

Alternative inputs: `acousticSharpness(SPLIn)` or `acousticSharpness(specificLoudnessIn)`.

### acousticRoughness

```matlab
[roughness, specificRoughness, fMod] = acousticRoughness(audioIn, fs, calibrationFactor)
```

| Argument | Default | Values |
|----------|---------|--------|
| `calibrationFactor` | `sqrt(8)` | Positive scalar (3rd positional arg) |
| `ModulationFrequency` | `"auto-detect"` | Scalar or two-element vector [1, 1000] Hz |
| `SoundField` | `"free"` | `"free"`, `"diffuse"` |
| `PressureReference` | `20e-6` | Positive scalar (Pa) |

Alternative input: `acousticRoughness(specificLoudnessIn)`.

### acousticFluctuation

```matlab
[fluctuation, specificFluctuation, fMod] = acousticFluctuation(audioIn, fs, calibrationFactor)
```

| Argument | Default | Values |
|----------|---------|--------|
| `calibrationFactor` | `sqrt(8)` | Positive scalar (3rd positional arg) |
| `ModulationFrequency` | `"auto-detect"` | Scalar or two-element vector [0.1, 100] Hz |
| `SoundField` | `"free"` | `"free"`, `"diffuse"` |
| `PressureReference` | `20e-6` | Positive scalar (Pa) |

Alternative input: `acousticFluctuation(specificLoudnessIn)`.

## Speech Quality

### visqol

```matlab
[metric, ftable, ttable] = visqol(degraded, reference, fs)
```

| Argument | Default | Values |
|----------|---------|--------|
| `Mode` | `"audio"` | `"audio"` (general), `"speech"` (narrowband/wideband speech) |
| `OutputMetric` | `"MOS"` | `"MOS"`, `"NSIM"`, `"MOS and NSIM"` |
| `ScaleMOS` | `true` | `true` (scale to [1,5]), `false` (raw) |
| `SearchWindowSize` | `60` | Nonneg integer (alignment search window in frames) |

`visqol` handles internal alignment — no need to pre-align signals.

### stoi

```matlab
metric = stoi(processed, reference, fs)
```

No name-value arguments. Output is a scalar in [-1, 1].

**Argument order:** `(processed, reference, fs)` — processed signal FIRST.

## Broadcast Loudness

### integratedLoudness

```matlab
[loudness, loudnessRange] = integratedLoudness(audioIn, fs)
[loudness, loudnessRange] = integratedLoudness(audioIn, fs, channelWeights)
```

| Argument | Default | Values |
|----------|---------|--------|
| `channelWeights` | `[1.0, 1.0, 1.0, 1.41, 1.41]` | Nonneg row vector (3rd positional arg) |

Standard channel order: L, R, C, Ls, Rs. Surround channels weighted +1.5 dB per ITU-R BS.1770.

## Room Acoustics

### rt60

```matlab
rtsummary = rt60(ir, fs)
```

| Argument | Default | Values |
|----------|---------|--------|
| `Bandwidth` | `"1 octave"` | `"1 octave"`, `"1/3 octave"` |
| `FilterOrder` | `10` | Positive even integer |
| `FrequencyRange` | — | Two-element row vector [fLow fHigh] Hz |
| `FilterDirection` | `"forward"` | `"forward"`, `"zero-phase"`, `"backward"` |
| `NoiseCompensation` | `"truncate-correct"` | `"truncate-correct"`, `"subtract-truncate-correct"` |

Output `rtsummary` is a table with columns for center frequency, T20, T30, EDT, and reliability metrics.

## Tonality

### acousticToneToNoiseRatio

```matlab
[tnr, tnrFreq, isProminent, timestamps] = acousticToneToNoiseRatio(audioIn, fs)
```

| Argument | Default | Values |
|----------|---------|--------|
| `TimeVarying` | `false` | `true` for time-varying analysis |
| `FFTLength` | `min(N, 2^nextpow2(0.2*fs))` | Positive integer |
| `Window` | `hann(FFTLength,"periodic")` | Vector |
| `OverlapLength` | `round(numel(Window)/2)` | Positive integer |
| `FrequencyRange` | `[89.1 11200]` | Two-column matrix or two-element vector (Hz) |
| `ReturnProminentOnly` | `false` | `true` to filter to prominent tones only |
| `CombineProximalTones` | `true` | Combine nearby tone detections |

### acousticProminenceRatio

```matlab
[pr, prFreq, isProminent, timestamps] = acousticProminenceRatio(audioIn, fs)
```

| Argument | Default | Values |
|----------|---------|--------|
| `TimeVarying` | `false` | `true` for time-varying analysis |
| `FFTLength` | `min(N, 2^nextpow2(0.2*fs))` | Positive integer |
| `Window` | `hann(FFTLength,"periodic")` | Vector |
| `OverlapLength` | `round(numel(Window)/2)` | Positive integer |
| `FrequencyRange` | `[89.1 11200]` | Two-element row vector (Hz) |

## SPL Measurement

### splMeter (System object)

```matlab
spl = splMeter(SampleRate=fs, Bandwidth="1 octave", ...)
[Lt, Leq, Lpeak, Lmax] = spl(audioIn);
```

| Property | Default | Values |
|----------|---------|--------|
| `Bandwidth` | `"Full band"` | `"Full band"`, `"1 octave"`, `"2/3 octave"`, `"1/3 octave"` |
| `FrequencyRange` | `[22 22050]` | Two-element vector (Hz) |
| `OctaveFilterOrder` | `2` | Even integer (8+ recommended for accuracy) |
| `FrequencyWeighting` | `"A-weighting"` | `"A-weighting"`, `"C-weighting"`, `"Z-weighting"` |
| `TimeWeighting` | `"fast"` | `"fast"`, `"slow"`, `"custom"` |
| `AttackTime` | `0.125` | Positive scalar (s) — only with `"custom"` |
| `ReleaseTime` | `0.125` | Positive scalar (s) — only with `"custom"` |
| `PressureReference` | `2e-5` | Positive scalar (Pa) |
| `TimeInterval` | `1` | Positive scalar (s) — set to signal duration for offline |
| `CalibrationFactor` | `1` | Positive scalar or vector |
| `SampleRate` | `44100` | Positive scalar (Hz) |

**Offline usage:** Set `TimeInterval` to the full signal duration for a single-shot measurement.

## Utility Functions

### calibrateMicrophone

```matlab
calibrationFactor = calibrateMicrophone(micRecording, fs, SPLreading)
```

| Argument | Default | Values |
|----------|---------|--------|
| `PressureReference` | `20e-6` | Positive scalar (Pa) |
| `FrequencyWeighting` | `"A-weighting"` | `"A-weighting"`, `"C-weighting"`, `"Z-weighting"` |

Input `micRecording` must be a 1 kHz calibration tone recording. `SPLreading` is the known SPL from a physical meter (dB).

### sone2phon / phon2sone

```matlab
phon = sone2phon(sone, Method)
sone = phon2sone(phon, Method)
```

Method: `"ISO 532-1"` or `"ISO 532-2"`.

----

Copyright 2026 The MathWorks, Inc.

----
