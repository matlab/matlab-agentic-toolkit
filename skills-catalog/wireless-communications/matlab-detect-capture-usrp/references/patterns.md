# Code Patterns (A–G)

Copy-ready capture patterns for `matlab-detect-capture-usrp`. Pick the pattern the Decision Tree in `SKILL.md` selected, then:

- Replace every value marked `% <- set` with the user's radio and signal parameters.
- Validate those values against `references/api.md` ranges (SKILL.md Step 3) **before** running.
- For loopback bring-up (SMA cable, transmit-then-detect), use the Local Hardware Testing table at the end of this file.

| Pattern | Detector | Threshold | Use case |
|---------|----------|-----------|----------|
| A | `energyDetector` | adaptive | Wake-on-signal capture on an energy rise |
| B | `energyDetector` | fixed | Capture above a fixed power level |
| C | `preambleDetector` | adaptive | Capture on correlation with a known preamble |
| D | `preambleDetector` | fixed | Preamble capture / `plotThreshold` calibration |
| E | `energyDetector` | adaptive | Multiple consecutive captures with timestamps |
| F | `energyDetector` | adaptive | Transmit-then-detect (loopback) |
| G | `preambleDetector` | adaptive | Frequency-scanning loop (WLAN channel scan) |

## Pattern A: Energy Detection with Adaptive Threshold

```matlab
%% Energy Detection - Adaptive Threshold
% Detect and capture signal when energy increases above threshold.
clear ed pd
radioName = "MyN310";              % <- set: your radio configuration name
ed = energyDetector(radioName);

% Configure RF parameters
ed.CenterFrequency = 2.45e9;       % <- set: Hz
ed.SampleRate = 30.72e6;           % <- set: Hz
ed.RadioGain = 30;                 % <- set: dB (device-dependent range)
ed.CaptureDataType = "double";

% Configure adaptive threshold
ed.ThresholdMethod = "adaptive";
ed.MinimumEnergy = 0.1;            % <- set: energy floor [0, 8191]; use 0 over loopback (let the dB delta trigger)
ed.EnergyDeltaThreshold = 3;       % <- set: dB rise that triggers capture
ed.WindowLength = 300;             % <- set: integration window [0, 4095]

% Optional: visualize energy curves before capturing (TX must be running for transmit-then-detect)
% plotDetectionSignals(ed, milliseconds(2));

% Capture data upon detection
[data, timestamp, droppedSamples, status] = capture(ed, milliseconds(5), seconds(2));

%% Verify
if status == 1
    fprintf("Captured %d samples at %s (dropped: %d).\n", length(data), string(timestamp), droppedSamples);
else
    warning("No detection before timeout (status 0) - expected with no active signal; to tune see references/threshold-calibration.md.");
end
```

### Pattern A — Calibration

If Pattern A fires unreliably (timeouts despite a real signal, false positives on noise, or captures of pure baseline), route into the threshold calibration sub-workflow:

> **-> Load `references/threshold-calibration.md` (Sub-Workflow A: energyDetector Calibration)**

The sub-workflow walks `plotDetectionSignals` -> diagnose curves -> tune `MinimumEnergy` / `EnergyDeltaThreshold` -> post-capture sanity ratio in four steps, with a combined symptom-cause-fix table at the end.

## Pattern B: Energy Detection with Fixed Threshold

```matlab
%% Energy Detection - Fixed Threshold
% Detect and capture signal when energy exceeds fixed level.
clear ed pd
radioName = "TestX410";            % <- set: your radio configuration name
ed = energyDetector(radioName);

% Configure RF parameters
ed.CenterFrequency = 3.5e9;        % <- set: Hz
ed.SampleRate = 122.88e6;          % <- set: Hz
ed.RadioGain = 30;                 % <- set: dB (device-dependent range)
ed.CaptureDataType = "double";

% Configure fixed threshold
ed.ThresholdMethod = "fixed";
ed.FixedThreshold = 500;           % <- set: fixed power threshold [0, 8191]; over loopback, measure it (see Loopback) — 500 is an OTA placeholder
ed.WindowLength = 300;             % <- set: integration window [0, 4095]

% Capture data upon detection
[data, timestamp, droppedSamples, status] = capture(ed, milliseconds(1), seconds(1));

%% Verify
if status == 1
    fprintf("Captured %d samples at %s (dropped: %d).\n", length(data), string(timestamp), droppedSamples);
else
    warning("No detection before timeout (status 0) - signal did not exceed the fixed threshold; measure it (see references/threshold-calibration.md).");
end
```

## Pattern C: Preamble Detection with Adaptive Threshold

For loopback bring-up, start with Pattern D (fixed threshold) and use `plotThreshold` to read the noise floor; move to Pattern C only after the path is calibrated.

```matlab
%% Preamble Detection - Adaptive Threshold
% Detect and capture signal by correlating with known preamble.
clear ed pd
radioName = "SigRadio";            % <- set: your radio configuration name
pd = preambleDetector(radioName);

% Configure RF parameters
pd.CenterFrequency = 2.2e9;        % <- set: Hz
pd.SampleRate = 10.24e6;           % <- set: Hz
pd.RadioGain = 30;                 % <- set: dB (device-dependent range)
pd.CaptureDataType = "double";

% Define preamble sequence (e.g., normalized Zadoff-Chu)
seq = zadoffChuSeq(38, 137);       % <- set: root index, sequence length [4, 1024]
preamble = seq / norm(seq, 2);
pd.Preamble = preamble;

% Configure adaptive threshold
pd.ThresholdMethod = "adaptive";
pd.AdaptiveThresholdGain = 0.3;    % <- set: typical 4-16 OTA, 0.1-0.9 loopback (boundary at 1.0)
pd.AdaptiveThresholdOffset = 0.001; % <- set: start at 0; raise only if false triggers occur

% Optional: visualize threshold curve before capturing (TX must be running)
% plotThreshold(pd, milliseconds(1));

% Capture data upon preamble detection
[data, timestamp, droppedSamples, status] = capture(pd, milliseconds(10), seconds(1));

%% Verify
if status == 1
    fprintf("Captured %d samples at %s (dropped: %d).\n", length(data), string(timestamp), droppedSamples);
else
    warning("No detection before timeout (status 0) - preamble not correlated; to tune see references/threshold-calibration.md.");
end
```

### Pattern C — Calibration

If Pattern C fires unreliably (timeouts over loopback, false positives over OTA, or captures full of noise), route into the threshold calibration sub-workflow:

> **-> Load `references/threshold-calibration.md` (Sub-Workflow B: preambleDetector Calibration)**

The sub-workflow walks `plotThreshold` -> diagnose curves -> tune `AdaptiveThresholdGain` / `AdaptiveThresholdOffset` -> post-capture peak/baseline sanity ratio in four steps, with a combined symptom-cause-fix table at the end.

## Pattern D: Preamble Detection with Fixed Threshold

```matlab
%% Preamble Detection - Fixed Threshold
% Detect preamble using fixed correlation power threshold.
clear ed pd
radioName = "MyX310";              % <- set: your radio configuration name
pd = preambleDetector(radioName);

% Configure RF parameters
pd.CenterFrequency = 2.4e9;        % <- set: Hz
pd.SampleRate = 30.72e6;           % <- set: Hz
pd.RadioGain = 30;                 % <- set: dB (device-dependent range)
pd.CaptureDataType = "double";

% Define preamble sequence
seq = zadoffChuSeq(25, 63);        % <- set: root index, sequence length [4, 1024]
preamble = seq / norm(seq, 2);
pd.Preamble = preamble;

% Configure fixed threshold
pd.ThresholdMethod = "fixed";
pd.FixedThreshold = 0.1;           % <- set: fixed correlation threshold [0, 4095]

% Plot threshold to calibrate (this pattern's purpose)
plotThreshold(pd, milliseconds(1));

% Capture data upon preamble detection
[data, timestamp, droppedSamples, status] = capture(pd, milliseconds(10), seconds(1));

%% Verify
if status == 1
    fprintf("Captured %d samples at %s (dropped: %d).\n", length(data), string(timestamp), droppedSamples);
else
    warning("No detection before timeout (status 0) - preamble not above the fixed threshold; to tune see references/threshold-calibration.md.");
end
```

## Pattern E: Multi-Capture Energy Detection with Timestamps

```matlab
%% Multi-Capture Energy Detection
% Capture multiple consecutive signals with sample clock timestamps.
% The "NumCaptures" name-value requires R2023b + R2024a or later (single capture works on R2023b).
clear ed pd
radioName = "MultiCap";            % <- set: your radio configuration name
ed = energyDetector(radioName, ...
    CaptureDataType="double", ...
    TimestampUnit="sample-clock-cycle");

% Configure RF parameters
ed.CenterFrequency = 3.5e9;        % <- set: Hz
ed.SampleRate = 245.76e6;          % <- set: Hz
ed.RadioGain = 30;                 % <- set: dB (device-dependent range)

% Configure threshold
ed.ThresholdMethod = "adaptive";
ed.MinimumEnergy = 0.1;            % <- set: energy floor [0, 8191]; use 0 over loopback (let the dB delta trigger)
ed.EnergyDeltaThreshold = 3;       % <- set: dB rise that triggers capture

% Capture N consecutive signals
numCaptures = 5;                   % <- set: number of consecutive captures (R2024a+)
[data, timestamp, droppedSamples, status] = capture(ed, ...
    milliseconds(1), seconds(3), "NumCaptures", numCaptures);

%% Verify
if status > 0
    fprintf("Successfully captured %d of %d requested signals.\n", status, numCaptures);
    fprintf("Timestamps (clock cycles): %s\n", mat2str(timestamp));
else
    warning("No signals captured before timeout - expected with no active signal; to tune see references/threshold-calibration.md.");
end
```

## Pattern F: Transmit-Then-Detect Workflow

```matlab
%% Transmit and Detect with Energy Detector
% Transmit a test waveform and capture upon energy detection.
clear ed pd
radioName = "TestN310";            % <- set: your radio configuration name
ed = energyDetector(radioName);

% Configure RF parameters
ed.CenterFrequency = 2.45e9;       % <- set: Hz
ed.SampleRate = 30.72e6;           % <- set: Hz
ed.Antennas = "RF0:RX2";  % loopback partner of RF0:TX/RX
ed.RadioGain = 30;                 % <- set: dB (typical 20-40 OTA, ~30 loopback)
ed.CaptureDataType = "double";

% Configure adaptive threshold
ed.ThresholdMethod = "adaptive";
ed.MinimumEnergy = 0;              % <- loopback: 0 lets the dB delta trigger (scale-invariant); see Loopback
ed.EnergyDeltaThreshold = 1.5;     % <- dB rise; loopback rise scales with TransmitGain: ~1.5 at TxGain 30, ~3 at 50 (see Loopback)

% Generate test waveform (chirp with zero padding) — keep it complex ('complex') and column-shaped for transmit
chirpSignal = single(chirp(0:1/1e3:2, 0, 0.5, 15, 'complex')).';
chirpSignal(end) = [];
padLen = 6500;
zeroPad = complex(zeros(padLen, 1), zeros(padLen, 1));
testWaveform = [zeroPad; chirpSignal * 0.999; zeroPad];

% Transmit test waveform continuously
transmit(ed, testWaveform, "continuous", ...
    TransmitAntennas="RF0:TX/RX", ...
    TransmitGain=50);  % <- set: typical 10-30 dB OTA, ~50 dB loopback

% Capture upon energy detection
[data, timestamp, droppedSamples, status] = capture(ed, milliseconds(3), seconds(2));

% Stop transmission
stopTransmission(ed);

%% Verify
if status == 1
    fprintf("Captured %d samples of test waveform (dropped: %d). Transmission stopped.\n", length(data), droppedSamples);
else
    warning("No detection before timeout (status 0) - raise TransmitGain/RadioGain or set MinimumEnergy=0; see references/threshold-calibration.md.");
end
```

## Pattern G: Frequency Scanning Loop (WLAN Channel Scan)

```matlab
%% WLAN Channel Scan with Preamble Detection
% Scan multiple WLAN channels for activity using preamble detection.
clear ed pd
radioName = "WiFiScanner";         % <- set: your radio configuration name
pd = preambleDetector(radioName);

% Configure preamble detector
pd.CaptureDataType = "double";
pd.ThresholdMethod = "adaptive";
pd.AdaptiveThresholdGain = 0.3;    % <- set: typical 4-16 OTA, 0.1-0.9 loopback
pd.AdaptiveThresholdOffset = 0.001; % <- set: start at 0; raise if false triggers occur
pd.RadioGain = 30;                 % <- set: dB (device-dependent range)

% Define WLAN L-LTF preamble (legacy long training field)
lltf = wlanLLTF(wlanNonHTConfig);
preamble = lltf(1:min(1024, length(lltf)));
preamble = preamble / max(abs(preamble));
pd.Preamble = preamble;

% Define channels to scan (e.g., 2.4 GHz band channels 1, 6, 11)
channelFreqs = [2.412e9, 2.437e9, 2.462e9];
channelNames = ["Ch1", "Ch6", "Ch11"];
sampleRate = 30.72e6;              % <- set: Hz
pd.SampleRate = sampleRate;

% Scan each channel
captures = struct([]);
for idx = 1:length(channelFreqs)
    pd.CenterFrequency = channelFreqs(idx);
    [data, timestamp, ~, detectionOk] = capture(pd, ...
        milliseconds(10), milliseconds(100));
    if detectionOk
        captures = [captures, struct( ...
            Channel=channelNames(idx), ...
            Frequency=channelFreqs(idx), ...
            Data=data, ...
            Timestamp=timestamp)]; %#ok<AGROW>
    end
end

%% Verify
fprintf("Scan complete. Detected activity on %d of %d channels.\n", ...
    length(captures), length(channelFreqs));
if ~isempty(captures)
    for k = 1:length(captures)
        fprintf("  %s (%.3f GHz): %d samples captured\n", ...
            captures(k).Channel, captures(k).Frequency/1e9, length(captures(k).Data));
    end
end
```

## Local Hardware Testing (Loopback)

Loopback (SMA cable from `RF0:TX/RX` to `RF0:RX2`) is the standard development path for transmit-then-detect workflows because it gives a deterministic, repeatable signal without relying on an external transmitter.

> **Absolute energy thresholds are radio-, gain-, and signal-specific — measure them, never hardcode.** Over loopback the integrated energy is tiny and scales with `RadioGain` (≈ 6e-5 at RadioGain 30, ≈ 0.1 at RadioGain 70 on an N310) — it never reaches the OTA-scale values in the pattern comments. Prefer **adaptive** detection: the `EnergyDeltaThreshold` dB-rise is scale-invariant. For a **fixed** threshold, measure first — see `references/threshold-calibration.md` (Sub-Workflow A, Step 0).

| Item | Value | Why |
|------|-------|-----|
| RX antenna | `Antennas="RF0:RX2"` | Loopback partner of RF0:TX/RX |
| TX antenna | `TransmitAntennas="RF0:TX/RX"` | Pass via `transmit()` Name-Value |
| RadioGain | 30–60 | Lifts the capture off the numerical floor. Amplifies signal **and** noise together, so it does not raise SNR — use `TransmitGain` for that. N310 has headroom to ~70 before the rail |
| TransmitGain | 50 | Drives the signal above the RX noise floor (this sets SNR / the sanity ratio) |
| `MinimumEnergy` (Pattern A/E/F) | **0** over loopback | Let `EnergyDeltaThreshold` trigger on the dB rise — scale-invariant, fires whatever the absolute energy. A nonzero floor must sit **below** the measured signal energy or it blocks the trigger (the old "1" sat far above it and timed out) |
| `FixedThreshold` (Pattern B) | **measure** (≈ ¼–½ of the measured peak) | Absolute → grab one reference with `FixedThreshold=1e-9`, compute `max(movsum(abs(x).^2,WindowLength))`, then set ¼–½ of that. The OTA example (500) sits far above a loopback signal and never fires |
| `EnergyDeltaThreshold` (Pattern A/E/F) | **1.5 dB** at modest TransmitGain (~30); ~3 dB at high TransmitGain (~50) | The achievable dB rise scales with TransmitGain (SNR): at ~30 dB TX the rise is only ~2–3 dB, so a 3 dB delta never crosses → timeout. Start low (1.5 dB); raise to 6 dB only if false positives |
| AdaptiveThresholdGain (Pattern C) | 0.5 | Default 8 in OTA examples is far too high for loopback's quiet baseline |
| `max\|data\|` | keep < 0.95 (hard rail 1.414) | √2 = int16 saturation; keep below the 0.95 guard band. At TxGain=50, N310 stays clean to ~RadioGain 70 (device-dependent: N310 0-75, N320/X410 0-60) |
| First test | Adaptive with `MinimumEnergy=0`, or fixed with a measured threshold | Both fire deterministically over loopback |

----

Copyright 2026 The MathWorks, Inc.
