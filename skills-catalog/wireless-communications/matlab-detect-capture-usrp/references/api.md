# Detect and Capture RF Signals - API Reference

## energyDetector

### Creation

```matlab
% TEMPLATE — not executable (syntax signatures)
ed = energyDetector(radio)
ed = energyDetector(radio, PropertyName=Value)
```

**Input `radio`**: String scalar (config name) or radio object (since R2025a).

### Properties

| Property | Type | Range/Values | Default |
|----------|------|--------------|---------|
| `CenterFrequency` | double | Device-dependent (see below) | 2.4e9 |
| `SampleRate` | double | Device-dependent (see below) | Device max |
| `RadioGain` | double | Device-dependent (see below) | 10 |
| `Antennas` | string | Device-dependent | Device default |
| `CaptureDataType` | string | "int16", "single", "double" | "int16" |
| `WindowLength` | double | [0, 4095] | 300 |
| `TriggerOffset` | double | [-4095, 4096] | 0 |
| `ThresholdMethod` | string | "adaptive", "fixed" | "adaptive" |
| `FixedThreshold` | double | [0, 8191] | 1e-4 (when fixed) |
| `MinimumEnergy` | double | [0, 8191] (setter rejects >8191) | 1e-4 (when adaptive) |
| `EnergyDeltaThreshold` | double | dB value | 1 (when adaptive) |
| `TimestampUnit` | string | "datetime", "sample-clock-cycle" | "datetime" |
| `DroppedSamplesAction` | string | "error", "warning", "none" | "error" |

### Object Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `capture` | `[data,ts,dropped,status] = capture(ed,length,timeout)` | Triggered capture |
| `capture` | `[data,ts,dropped,status] = capture(ed,length,timeout,"NumCaptures",N)` | Multi-capture |
| `plotDetectionSignals` | `plotDetectionSignals(ed, length)` | Calibrate thresholds |
| `transmit` | `transmit(ed, waveform, "continuous", Name=Value)` | Send test waveform |
| `stopTransmission` | `stopTransmission(ed)` | Stop ongoing TX |

## preambleDetector

### Creation

```matlab
% TEMPLATE — not executable (syntax signatures)
pd = preambleDetector(radio)
pd = preambleDetector(radio, PropertyName=Value)
```

**Input `radio`**: String scalar (config name) or radio object (since R2025a).

### Properties

| Property | Type | Range/Values | Default |
|----------|------|--------------|---------|
| `CenterFrequency` | double | Device-dependent | 2.4e9 |
| `SampleRate` | double | Device-dependent | Device max |
| `RadioGain` | double | Device-dependent | 10 |
| `Antennas` | string | Device-dependent | Device default |
| `CaptureDataType` | string | "int16", "single", "double" | "int16" |
| `Preamble` | double column vector | Length [4, 1024], elements [-1, 1] | [16x1 default] |
| `TriggerOffset` | double | [-4095, 4096] | 0 |
| `ThresholdMethod` | string | "adaptive", "fixed" | "adaptive" |
| `FixedThreshold` | double | [0, 4095] | 0 (when fixed) |
| `AdaptiveThresholdGain` | double | [0, 64] (typical 4-16 OTA, 0.1-0.9 loopback) | 0 (when adaptive) |
| `AdaptiveThresholdOffset` | double | [0, 2] | 0 (when adaptive) |
| `TimestampUnit` | string | "datetime", "sample-clock-cycle" | "datetime" |
| `DroppedSamplesAction` | string | "error", "warning", "none" | "error" |

### Object Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `capture` | `[data,ts,dropped,status] = capture(pd,length,timeout)` | Triggered capture |
| `capture` | `[data,ts,dropped,status] = capture(pd,length,timeout,"NumCaptures",N)` | Multi-capture |
| `plotThreshold` | `plotThreshold(pd, length)` | Calibrate thresholds |
| `transmit` | `transmit(pd, waveform, "continuous", Name=Value)` | Send test waveform |
| `stopTransmission` | `stopTransmission(pd)` | Stop ongoing TX |

## Key Differences Between Detectors

| Aspect | energyDetector | preambleDetector |
|--------|---------------|-----------------|
| Since | R2023b | R2022a |
| Detection method | Energy integration | Preamble correlation |
| Calibration plot | `plotDetectionSignals(ed, len)` | `plotThreshold(pd, len)` |
| Adaptive params | MinimumEnergy + EnergyDeltaThreshold | AdaptiveThresholdGain + AdaptiveThresholdOffset |
| FixedThreshold range | [0, 8191] | [0, 4095] |
| Requires preamble | No | Yes (4-1024 samples) |
| WindowLength | Yes [0, 4095] | No (uses preamble length) |

## capture() Function Details

### Syntax

```matlab
% TEMPLATE — not executable (syntax signatures)
[data, timestamp, droppedSamples, status] = capture(detector, length, timeout)
[data, timestamp, droppedSamples, status] = capture(detector, length, timeout, "NumCaptures", N)
```

### Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `detector` | energyDetector or preambleDetector | Configured detector object |
| `length` | double or duration | Capture length (samples or time) |
| `timeout` | duration | Detection timeout |
| `NumCaptures` | positive integer (NV, since R2024a) | Number of consecutive captures |

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `data` | complex vector (or cell array if NumCaptures>1) | Captured IQ samples |
| `timestamp` | datetime or uint64 (depends on TimestampUnit) | Capture timestamp(s) |
| `droppedSamples` | logical | true if samples dropped |
| `status` | integer | 1=success, 0=timeout (or count if NumCaptures>1) |

## transmit() Function Details

### Syntax

```matlab
% TEMPLATE — not executable (syntax signatures)
transmit(detector, waveform, "continuous")
transmit(detector, waveform, "continuous", TransmitGain=gainDb)
transmit(detector, waveform, "continuous", TransmitCenterFrequency=freqHz)
transmit(detector, waveform, "continuous", TransmitAntennas=antennaStr)
```

### Name-Value Arguments

| Name | Type | Description |
|------|------|-------------|
| `TransmitGain` | double | TX gain in dB (device-dependent range) |
| `TransmitCenterFrequency` | double | TX center frequency in Hz |
| `TransmitAntennas` | string | TX antenna port |

## Device Constraints Quick Reference

### Center Frequency

| Device | Range |
|--------|-------|
| E320 | 70 MHz - 6 GHz |
| N300/N310/N320/N321 | 1 MHz - 6 GHz |
| X300/X310 + UBX 160 | 10 MHz - 6 GHz |
| X410 | 1 MHz - 8 GHz |

### Receive Gain

| Device | Range |
|--------|-------|
| E320 | 0 - 76 dB |
| N300/N310 | 0 - 75 dB |
| N320/N321 | 0 - 60 dB |
| X300/X310 + UBX/OBX | 0 - 31.5 dB |
| X410 | 0 - 60 dB |

### Onboard Buffer

| Device | Buffer | Max Samples |
|--------|--------|-------------|
| E320/N300/N310/N320/N321 | 2 GB | 2^29 |
| X300/X310 | 1 GB | 2^28 |
| X410 | 4 GB | 2^30 |

----

Copyright 2026 The MathWorks, Inc.

----
