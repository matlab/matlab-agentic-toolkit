# Detect and Capture RF Signals - Overview

## Architecture

Wireless Testbench provides two detection application objects for triggered capture:

| Object | Trigger Mechanism | Use When |
|--------|-------------------|----------|
| `energyDetector` | Signal power exceeds threshold | No known preamble; detect any signal appearance |
| `preambleDetector` | Correlation with known sequence | Known preamble (Zadoff-Chu, L-LTF, PSS, etc.) |

Both objects require exclusive access to radio hardware. Only one application object per radio can exist at a time.

## Detection Workflow

1. **Create** - Instantiate detector with radio config name
2. **Configure** - Set CenterFrequency, SampleRate, threshold parameters
3. **Calibrate** - Use `plotDetectionSignals` (energy) or `plotThreshold` (preamble) to tune
4. **Capture** - Call `capture(detector, length, timeout)` to wait for detection
5. **Cleanup** - Call `stopTransmission()` if transmitting; clear object

## Energy Detection

The energy detector integrates signal power over a sliding window and triggers when:
- **Adaptive mode**: Energy exceeds `MinimumEnergy` AND energy ratio between adjacent windows exceeds `EnergyDeltaThreshold` (in dB)
- **Fixed mode**: Integrated energy exceeds `FixedThreshold`

Key concept: EnergyDeltaThreshold is a ratio in dB between current and previous window energy. 3 dB = 2x power increase, 20 dB = 100x increase.

## Preamble Detection

The preamble detector correlates the received signal with a known sequence using a programmable FIR filter and triggers when:
- **Adaptive mode**: Correlator output power exceeds `AdaptiveThresholdGain * avgPower + AdaptiveThresholdOffset`
- **Fixed mode**: Correlator output power exceeds `FixedThreshold`

The preamble must have good autocorrelation properties. Zadoff-Chu sequences are ideal.

## Adaptive vs Fixed Thresholds

| Aspect | Adaptive | Fixed |
|--------|----------|-------|
| Best for | Varying noise environments | Known SNR conditions |
| Adjusts to | Channel noise floor | Does not adjust |
| Risk | Missed detections in high noise | False triggers in noise |
| Calibration | Tune gain/offset/delta params | Set single value |

## Threshold Tuning Symptoms

When a detector fires unreliably (timeouts on a real signal, false positives on noise, saturated
or baseline captures), the full symptom -> cause -> fix table and the step-by-step plot ->
diagnose -> tune procedure live in `threshold-calibration.md`. Load that file for calibration.
First diagnostic for any preamble threshold issue is `plotThreshold(pd, milliseconds(1))` while
TX is running; for energy threshold issues use `plotDetectionSignals(ed, milliseconds(2))`.

## Multi-Capture Mode (Since R2024a)

Use `"NumCaptures"` name-value argument with `capture()` to capture N consecutive signals in one call. Set `TimestampUnit="sample-clock-cycle"` to get relative timestamps between captures.

## Transmit-Then-Detect

Both detector objects support `transmit(detector, waveform, "continuous")` to send a test waveform while simultaneously detecting. This enables self-test and loopback verification without a separate basebandTransmitter.

## Frequency Scanning

To scan multiple channels (e.g., WLAN bands):
1. Create one detector object
2. Loop over center frequencies, updating `CenterFrequency` each iteration
3. Call `capture()` with a short timeout per channel
4. Collect results from channels where detection succeeds

Note: Changing `CenterFrequency` adds a few seconds delay to the next function call.

## Key Constraints

1. Objects require exclusive radio access - clear previous objects first
2. Preamble max length: 1024 samples (elements in [-1, 1])
3. WindowLength max: 4095 samples
4. First function call after object creation takes extra seconds (FPGA load)
5. Changing SampleRate or ThresholdMethod requires stopping transmission first
6. Onboard buffer shared between transmit and capture/plot data

----

Copyright 2026 The MathWorks, Inc.

----
