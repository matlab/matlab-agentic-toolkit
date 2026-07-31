---
name: matlab-transmit-capture-usrp
description: >
  Transmit and capture RF waveforms using Wireless Testbench with NI USRP radios
  (X410, X310, N310, N320, N321, N300, X300, E320). Use when generating test signals,
  transmitting over the air, capturing IQ data, performing loopback tests, configuring
  multi-antenna setups, or troubleshooting dropped samples and gain settings. Covers
  basebandTransceiver, basebandTransmitter, basebandReceiver, continuous and once
  transmit modes, foreground and background capture, and UseRadioBuffer options.
  Also use when the user mentions transmit waveform, capture signal, IQ data,
  loopback, RF gain, sample rate, or antenna configuration.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Transmit and Capture Waveforms with Wireless Testbench

Generate, transmit, and capture RF waveforms using NI USRP radios in MATLAB.

## When to Use

- Transmitting a waveform (test tone, standard-compliant signal, custom IQ) over the air
- Capturing IQ data from a frequency band
- Loopback testing (transmit and capture on the same radio)
- Multi-antenna transmit or capture
- Continuous transmission for prolonged testing
- Background capture for long-duration acquisition

## When NOT to Use

- Setting up or connecting a USRP radio for the first time — use the **matlab-set-up-usrp-radio** skill
- FPGA targeting workflows — see [Target NI USRP Radios](https://www.mathworks.com/help/wireless-testbench/target-ni-usrp-devices.html)
- Intelligent capture with preamble/energy detection — see [Spectrum Monitoring](https://www.mathworks.com/help/wireless-testbench/spectrum-monitoring.html)
- Multi-device synchronization — see [Radio Management](https://www.mathworks.com/help/wireless-testbench/radio-management.html)

## Prerequisites

A saved radio configuration must exist before using any transmit/capture object. List available configurations and let the user choose which one to use:

```matlab
configs = radioConfigurations;
disp(configs)
```

If multiple configurations exist, ask the user which one they want to work with. If no configuration exists, guide the user to set one up first (see the **matlab-set-up-usrp-radio** skill).

Before generating code, confirm these parameters with the user if not already specified:
- **Center frequency** — Accept any numeric value within the radio's supported range. Do not present a constrained list of bands; let the user type a frequency.
- **Sample rate** — Ask what sample rate they need. Suggest common values (30.72 MHz, 61.44 MHz, 122.88 MHz, 245.76 MHz) but accept any valid rate.

## Choosing the Right Object

**Default to `basebandTransceiver`.** It supports all workflows — transmit only, capture only, or both simultaneously. Use it unless you have a specific reason not to.

| Object | When to Use |
|--------|-------------|
| `basebandTransceiver` | **Default choice.** Transmit, capture, or both. Works for loopback, signal generation, spectrum monitoring, and full-duplex |
| `basebandTransmitter` | Only when you need a dedicated transmit-only object (e.g., a separate script controlling TX independently) |
| `basebandReceiver` | Only when you need a dedicated receive-only object (e.g., a separate script controlling RX independently) |

**Why default to `basebandTransceiver`:** A single radio configuration can only be used by one object at a time. Since `basebandTransceiver` handles transmit, capture, or both, it covers the vast majority of workflows without needing to switch objects. The standalone objects (`basebandTransmitter`, `basebandReceiver`) are useful when separate scripts or applications each need independent control of one direction.

**Property naming differs between object types:**

| | basebandTransceiver | basebandTransmitter / basebandReceiver |
|--|-----|------|
| Gain | `TransmitRadioGain`, `CaptureRadioGain` | `RadioGain` |
| Frequency | `TransmitCenterFrequency`, `CaptureCenterFrequency` | `CenterFrequency` |
| Antennas | `TransmitAntennas`, `CaptureAntennas` | `Antennas` |

The transceiver uses `Transmit`/`Capture` prefixes to distinguish directions. The standalone objects do not need prefixes since they only handle one direction.

## Workflow

### Step 1: Create the Radio Object

```matlab
radio = radioConfigurations("MyN310");
bbtrx = basebandTransceiver(radio);
```

**Preload option:** Pass `Preload=true` to load the FPGA application at construction time rather than on first use. This avoids a multi-second delay on the first `transmit` or `capture` call.

```matlab
bbtrx = basebandTransceiver(radio, Preload=true);
```

**Standalone objects (only when needed for independent single-direction control):**

```matlab
bbtx = basebandTransmitter(radio);  % TX only
bbrx = basebandReceiver(radio);     % RX only
```

### Step 2: Configure Properties

Configure the object before transmitting or capturing. Setting properties after object creation is valid, but some changes cause a reload delay.

```matlab
bbtrx.SampleRate = 30.72e6;
bbtrx.TransmitCenterFrequency = 3.5e9;
bbtrx.CaptureCenterFrequency = 3.5e9;
bbtrx.TransmitRadioGain = 20;
bbtrx.CaptureRadioGain = 40;
```

Only set the properties for the direction you need. For transmit-only workflows, skip the `Capture*` properties (and vice versa).

**If using standalone objects** (`basebandTransmitter` / `basebandReceiver`), properties are unprefixed:

```matlab
bbtx.SampleRate = 30.72e6;
bbtx.CenterFrequency = 3.5e9;    % not TransmitCenterFrequency
bbtx.RadioGain = 20;              % not TransmitRadioGain
```

**Property guidance:**

| Property | Guidance |
|----------|----------|
| SampleRate | Must match waveform bandwidth. Common values: 30.72 MHz (LTE/NR), 61.44 MHz, 122.88 MHz, 245.76 MHz |
| TransmitRadioGain | Start low (10–20 dB) to avoid clipping. Increase until signal strength is adequate |
| CaptureRadioGain | Start moderate (30–40 dB). Too high clips the ADC; too low buries the signal in noise |
| TransmitCenterFrequency / CaptureCenterFrequency | Must be within the radio's supported range (device-dependent, typically 1 MHz – 6/8 GHz) |
| DroppedSamplesAction | Set to `"warning"` during development to continue despite drops; use `"error"` in production |

### Step 3: Prepare the Transmit Waveform

The waveform must be a complex column vector (single antenna) or complex matrix (multi-antenna, one column per antenna). Values must be normalized to the range [-1, 1].

**Test tone:**

```matlab
numSamples = 30720;
t = (0:numSamples-1)' / bbtrx.SampleRate;
txWaveform = 0.8 * exp(1j*2*pi*1e6*t);
```

**Random OFDM-like signal:**

```matlab
numSamples = 30720;
txWaveform = complex(randn(numSamples,1), randn(numSamples,1));
txWaveform = 0.7 * txWaveform / max(abs(txWaveform));
```

**Load a pre-generated waveform from file:**

```matlab
waveStruct = load("myWaveform.mat");
txWaveform = waveStruct.waveform;
txWaveform = 0.8 * txWaveform / max(abs(txWaveform));
```

Use this pattern with waveforms generated by 5G Toolbox, LTE Toolbox, WLAN Toolbox, or any custom signal generation workflow.

**Waveform requirements:**

| Requirement | Details |
|-------------|---------|
| Data type | Complex double, single, or int16 (controlled by `TransmitDataType`) |
| Amplitude | Peak magnitude ≤ 1.0 for double/single (values > 1 clip at the DAC) |
| Dimensions | Column vector (single antenna) or N×M matrix (M = number of TX antennas) |
| Row count | Must be an **even number** of rows |
| Minimum length | Waveforms < 513 samples reserve up to 1024 samples for underflow protection |

**Pass `TransmitDataType` to the constructor when using `Preload=true`:**

The FPGA application is configured for a specific transmit data class at construction time. Without preload, the class is inferred from the waveform on the first `transmit` call. With preload, the transceiver has no waveform to infer from, so pass `TransmitDataType` explicitly — otherwise the FPGA reloads on the first `transmit` call and defeats the point of preloading.

```matlab
bbtrx = basebandTransceiver(radio, Preload=true, TransmitDataType="double");
% ... configure frequency/gain/sample rate ...
transmit(bbtrx, txWaveform, "continuous");   % waveform class must match TransmitDataType
```

### Step 4: Transmit

**Once (single-shot) — transmit the waveform exactly once:**

```matlab
transmit(bbtrx, txWaveform, "once");
```

The radio transmits the waveform one time and then stops automatically. Use for pulsed or one-shot testing. Add a few redundant samples to the end of the waveform for reliability in this mode.

**Continuous — transmit repeatedly until stopped:**

```matlab
transmit(bbtrx, txWaveform, "continuous");
```

The waveform loops continuously on the radio until `stopTransmission` is called. Use for:
- Sustained interference or signal generation
- Loopback testing where capture timing is decoupled from transmit
- Over-the-air tests where a receiver needs a persistent signal

**Stop continuous transmission:**

```matlab
stopTransmission(bbtrx);
```

### Step 5: Capture

**Foreground capture (blocks MATLAB until complete):**

```matlab
[data, timestamp, droppedSamples] = capture(bbtrx, milliseconds(10));
```

The `length` argument accepts a `duration` value (e.g., `seconds(1)`, `milliseconds(10)`) or a sample count as a positive integer.

**Output arguments:**

| Output | Type | Description |
|--------|------|-------------|
| `data` | complex vector/matrix | IQ samples — rows = samples, columns = antennas. Data type matches `CaptureDataType` property. First samples may contain transients |
| `timestamp` | `datetime` | Timestamp created immediately before hardware capture request |
| `droppedSamples` | logical | `true` if samples were dropped (network/host issue), `false` if clean |

**`CaptureDataType` defaults to `int16` — cast before FFT, filtering, or arithmetic:**

The captured `data` is a complex vector/matrix whose class matches `CaptureDataType`. The default is `"int16"` (fixed-point) to minimize memory. Most MATLAB signal-processing functions — including `fft`, `abs`, `filter`, `bandpass`, `pwelch`, and element-wise math — **do not accept complex `int16`** and will error at runtime. Handle this in one of two ways:

```matlab
% Option A — set the property before capture (all downstream code sees double)
bbtrx.CaptureDataType = "double";
[data, ~, dropped] = capture(bbtrx, milliseconds(10));
X = fft(data);   % works

% Option B — cast after capture (keep the memory savings during transfer)
[data, ~, dropped] = capture(bbtrx, milliseconds(10));
data = double(data);
X = fft(data);   % works
```

Use Option A by default. Only prefer Option B when memory during capture is tight and you want the compact int16 payload until processing begins.

**Background capture (non-blocking):**

Use background capture when:
- Capture duration is long (> a few seconds) and MATLAB must remain responsive
- You want to do post-processing, display updates, or other work during acquisition
- You are combining capture with continuous transmit and need to monitor both

Use foreground capture (the default) when:
- Capture is short and you need the data immediately for the next step
- The script is linear (no concurrent work needed)

**Choosing the right pattern:**

| Scenario | Pattern |
|----------|---------|
| Short capture, need data now | `[data,~,dropped] = capture(bbtrx, milliseconds(100));` |
| Long capture, data fits in RAM | `capture(bbtrx, seconds(30), Background=true);` then `captureOutputs` |
| Long capture, too large for RAM | `capture(bbtrx, seconds(60), Background=true, SaveLocation="data.mat", UseRadioBuffer=false);` |
| Need notification when done | Add `CompletionFcn=@(data,ts,dropped) myCallback(data)` |

**Background capture with polling:**

```matlab
capture(bbtrx, seconds(30), Background=true);

% Poll until complete
while isCapturing(bbtrx)
    pause(1);
end

% Retrieve results
[data, timestamp, droppedSamples] = captureOutputs(bbtrx);
```

**Background capture with callback (no polling needed):**

```matlab
capture(bbtrx, seconds(30), Background=true, ...
    CompletionFcn=@(data, ts, dropped) handleCapture(data, dropped));
```

**Long capture to file (background + SaveLocation + direct-to-host):**

For captures that exceed onboard buffer or RAM, combine all three options:

```matlab
capture(bbtrx, seconds(60), ...
    Background=true, ...
    SaveLocation="captured_data.mat", ...
    UseRadioBuffer=false);

while isCapturing(bbtrx)
    pause(5);
end
filePath = captureOutputs(bbtrx);
fprintf("Saved to: %s\n", filePath);
```

When `SaveLocation` is specified, `captureOutputs` returns the file path instead of loading data into the workspace.

**Stop a background capture early:**

```matlab
stopCapture(bbtrx);
[data, timestamp, droppedSamples] = captureOutputs(bbtrx);
```

**UseRadioBuffer — choosing between radio buffer and direct-to-host:**

The `UseRadioBuffer` name-value argument controls where captured samples are stored during acquisition. The right choice depends on capture length, sample rate, and host network capability.

```matlab
% Radio buffer (default) — data is stored in onboard radio memory, then
% transferred to the host after capture completes. Most reliable option.
[data, ~, dropped] = capture(bbtrx, milliseconds(100));

% Direct-to-host — data streams continuously from radio to host over the
% network during the capture. Required when capture exceeds onboard memory.
[data, ~, dropped] = capture(bbtrx, seconds(30), UseRadioBuffer=false);
```

**Use `UseRadioBuffer=true` (default) when:**
- Capture length fits within the radio's onboard memory
- You want the most reliable capture (no dependency on sustained host throughput)
- Sample rate is high and you cannot tolerate any drops

**Use `UseRadioBuffer=false` when:**
- Capture length exceeds the radio's onboard buffer capacity (see table below)
- Using USRP X310 with TwinRX daughterboard capturing more than 2 antenna channels
- You need arbitrarily long captures (minutes or hours of data)

**Onboard buffer capacities (determines when direct-to-host is required):**

| Device | Max Samples | Approx Duration at 30.72 MHz |
|--------|-------------|------------------------------|
| USRP E320 / N-series | 2^29 (~537M) | ~17.5 s |
| USRP X300 / X310 | 2^28 (~268M) | ~8.7 s |
| USRP X410 | 2^30 (~1.07B) | ~34.8 s |

**Direct-to-host performance considerations:**

Direct-to-host capture requires sustained network throughput for the entire capture duration. The maximum achievable sample rate depends on host and network configuration and varies between runs depending on system load. If drops occur, either reduce the sample rate, reduce the number of antennas, or run `radioSetupWizard` to optimize host network settings for your platform.

**Evaluating host performance:** To find the maximum sustainable direct-to-host rate, iterate captures at decreasing sample rates with `DroppedSamplesAction="none"` until one succeeds:

```matlab
bbrx.DroppedSamplesAction = "none";
sampleRates = 245.76e6 : -10e6 : 10e6;
for idx = 1:numel(sampleRates)
    bbrx.SampleRate = sampleRates(idx);
    [~, ~, dropped] = capture(bbrx, 2*2^28, UseRadioBuffer=false);
    if ~dropped
        fprintf("Max sustained rate: %.1f MHz\n", sampleRates(idx)/1e6);
        break
    end
end
```

**Stop a background capture early:**

```matlab
stopCapture(bbtrx);
[data, timestamp, droppedSamples] = captureOutputs(bbtrx);
```

### Step 6: Loopback Test (Transmit + Capture on Same Radio)

A loopback test verifies the full TX/RX chain using `basebandTransceiver`. Set `TransmitCenterFrequency` and `CaptureCenterFrequency` to the same value so the signal couples internally.

**Method A: Continuous transmit then capture**

Start continuous transmission, allow a brief pause for the radio front-end to stabilize, then capture.

```matlab
radio = radioConfigurations("MyN310");
bbtrx = basebandTransceiver(radio, Preload=true);
bbtrx.SampleRate = 61.44e6;
bbtrx.TransmitCenterFrequency = 2.4e9;
bbtrx.CaptureCenterFrequency = 2.4e9;
bbtrx.TransmitRadioGain = 10;
bbtrx.CaptureRadioGain = 30;

% Generate test tone
numSamples = 61440;
t = (0:numSamples-1)' / bbtrx.SampleRate;
txWaveform = 0.8 * exp(1j*2*pi*1e6*t);

% Transmit continuously, pause for stabilization, then capture
transmit(bbtrx, txWaveform, "continuous");
pause(1);
[rxData, ~, droppedSamples] = capture(bbtrx, milliseconds(10));
stopTransmission(bbtrx);

% Verify
if ~droppedSamples
    fprintf("Loopback OK: captured %d samples, no drops.\n", size(rxData,1));
else
    warning("Samples were dropped during loopback.");
end

% Visualize
sa = spectrumAnalyzer(SampleRate=bbtrx.SampleRate);
sa(rxData);
```

### Step 7: Multi-Antenna Configuration

For MIMO or multi-channel operation, set antenna properties to arrays and provide a matrix waveform.

```matlab
radio = radioConfigurations("MyX410");
bbtrx = basebandTransceiver(radio);
bbtrx.SampleRate = 61.44e6;

% Configure 2 TX and 2 RX antennas
bbtrx.TransmitAntennas = ["DB0:RF0:TX/RX0", "DB0:RF1:TX/RX0"];
bbtrx.CaptureAntennas = ["DB0:RF0:RX1", "DB0:RF1:RX1"];
bbtrx.TransmitCenterFrequency = [3.5e9, 3.5e9];
bbtrx.CaptureCenterFrequency = [3.5e9, 3.5e9];
bbtrx.TransmitRadioGain = [15, 15];
bbtrx.CaptureRadioGain = [35, 35];

% Waveform: N×2 matrix (one column per TX antenna)
numSamples = 61440;
t = (0:numSamples-1)' / bbtrx.SampleRate;
tx1 = 0.7 * exp(1j*2*pi*1e6*t);
tx2 = 0.7 * exp(1j*2*pi*2e6*t);
txWaveform = [tx1, tx2];

transmit(bbtrx, txWaveform, "continuous");
[rxData, ~, dropped] = capture(bbtrx, milliseconds(10));
stopTransmission(bbtrx);

% rxData is N×2: one column per RX antenna
fprintf("Captured %d samples on %d antennas.\n", size(rxData,1), size(rxData,2));
```

**Antenna naming varies by device — TX and RX ports have different names:**

| Device | TransmitAntennas | CaptureAntennas |
|--------|------------------|-----------------|
| X410 | `"DB0:RF0:TX/RX0"`, `"DB0:RF1:TX/RX0"`, `"DB1:RF0:TX/RX0"`, `"DB1:RF1:TX/RX0"` | `"DB0:RF0:RX1"`, `"DB0:RF1:RX1"`, `"DB1:RF0:RX1"`, `"DB1:RF1:RX1"` |
| X310 (UBX) | `"RFA:TX/RX"`, `"RFB:TX/RX"` | `"RFA:RX2"`, `"RFB:RX2"` |
| N310 | `"RF0:TX/RX"`, `"RF1:TX/RX"`, `"RF2:TX/RX"`, `"RF3:TX/RX"` | `"RF0:RX2"`, `"RF1:RX2"`, `"RF2:RX2"`, `"RF3:RX2"` |
| N320/N321 | `"RF0:TX/RX"`, `"RF1:TX/RX"` | `"RF0:RX2"`, `"RF1:RX2"` |
| E320 | `"RFA:TX/RX"` | `"RFA:RX2"`, `"RFB:RX2"` |

Assign an invalid value to see the full list of accepted antenna names for your device.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Dropped samples | Host/network cannot sustain throughput | Run `radioSetupWizard` to optimize host settings, or reduce sample rate / antenna count |
| Captured signal clipped | CaptureRadioGain too high | Reduce gain until peak magnitude < 0.9 |
| Captured signal in noise floor | CaptureRadioGain too low | Increase gain incrementally |
| TX signal distorted | Waveform amplitude > 1.0 | Normalize: `waveform = waveform / max(abs(waveform))` |
| Multi-second delay on first call | FPGA application loading | Use `Preload=true` at construction |
| `"Resource not available"` error | Another object holds the radio | Clear existing objects: `clear bbtrx` |
| Capture length exceeds buffer | Onboard memory full | Use `UseRadioBuffer=false` for long captures |
| Background capture never finishes | Capture still running | Check `isCapturing()`, use `stopCapture()` if stuck |

## Key Functions Reference

| Function/Method | Purpose |
|-----------------|---------|
| `basebandTransceiver` | Create radio object (default — handles TX, RX, or both) |
| `basebandTransmitter` | Create TX-only radio object (standalone use only) |
| `basebandReceiver` | Create RX-only radio object (standalone use only) |
| `transmit(obj, waveform, "once")` | Single-shot transmit |
| `transmit(obj, waveform, "continuous")` | Continuous transmit (loops until stopped) |
| `stopTransmission(obj)` | Stop continuous transmission |
| `capture(obj, length)` | Foreground capture (blocking) |
| `capture(obj, length, Background=true)` | Background capture (non-blocking) |
| `captureOutputs(obj)` | Retrieve background capture results |
| `isCapturing(obj)` | Check if background capture is running |
| `stopCapture(obj)` | Stop a background capture |
| `radioConfigurations` | List/load saved radio configurations |

## Conventions

- **Default to `basebandTransceiver`.** Use it for transmit-only, capture-only, or both. Only use `basebandTransmitter`/`basebandReceiver` when a separate script needs independent single-direction control.
- **Normalize waveforms.** Always scale to peak magnitude ≤ 0.8 to leave headroom and avoid DAC clipping.
- **Start with low gain.** Begin TX gain at 10–20 dB and RX gain at 30–40 dB; adjust based on observed signal levels.
- **Continuous transmit before capture.** For loopback, start `transmit(..., "continuous")` first, then `capture`. This ensures the signal is present when capture begins.
- **Always stop transmission.** Call `stopTransmission` when done to release radio resources.
- **Check dropped samples.** Always inspect the third output of `capture` — it is logical (`true` = drops occurred). If `true`, run `radioSetupWizard` to optimize host settings or reduce sample rate.
- **Wait before retrieving outputs.** Never call `captureOutputs` until `isCapturing` returns `false` or `stopCapture` has been called. Calling it while capture is still running will error.
- **Use duration for capture length.** Prefer `milliseconds(N)` or `seconds(N)` over raw sample counts for readability and portability across sample rates.
- **Clean up objects.** Call `clear` on radio objects when finished to release hardware for other applications.

----

Copyright 2026 The MathWorks, Inc.

----
