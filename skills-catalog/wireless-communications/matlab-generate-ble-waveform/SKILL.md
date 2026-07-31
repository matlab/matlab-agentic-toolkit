---
name: matlab-generate-ble-waveform
description: >
  Generate Bluetooth Low Energy (BLE) PHY waveforms. Read BEFORE writing any
  BLE waveform code to avoid hallucinating API patterns.
  Covers bleWaveformGenerator, bleIdealReceiver, bleCTEIQSample,
  bleAngleEstimate, bluetoothTestWaveform for LE1M/LE2M/LE500K/LE125K.
  Bluetooth Toolbox R2022a+.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2022a"
metadata:
  author: MathWorks
  version: "1.0"
---

# BLE Waveform Generation

## Routing

| Intent | Cues | Pattern |
|--------|------|---------|
| Basic generation | "generate", "waveform" | Single-Mode |
| Compare modes | "compare", "all modes" | All-Mode |
| Direction finding | "CTE", "AoA", "AoD" | CTE |
| RF-PHY compliance | "compliance", "RF-PHY" | RF-PHY Test |
| Coexistence | "WLAN", "interference" | WLAN Coexistence |
| TX measurements | "PAPR", "OBW", "power" | TX Measurements |
| Localization | "RSSI", "beacon", "distance" | RSSI Localization |
| BER/receiver | "BER", "noise", "sensitivity" | BER Simulation |
| Multi-packet | "burst", "IFS" | Multi-Packet |
| Spectrum | "spectrum", "spectral mask" | Spectral Analysis |
| Whitening | "whitening", "scrambling" | Whitening Comparison |
| Impairments | "CFO", "practical", "realistic" | End-to-End |

Default (ambiguous request): LE1M, 37-byte payload, channel 37.

## When To Use

Use this skill when the user asks to generate, simulate, or analyze BLE PHY-layer waveforms — including mode comparisons, CTE/direction finding, RF-PHY compliance testing, BER simulations, TX measurements, WLAN coexistence, or RSSI localization. Applies to any task involving `bleWaveformGenerator`, `bleIdealReceiver`, `bleCTEIQSample`, `bleAngleEstimate`, or `bluetoothTestWaveform`.

## When Not To Use

- BR/EDR (Classic Bluetooth) → use `bluetoothWaveformGenerator` (covered by a separate BR/EDR skill)
- Channel Sounding (CS) → use `bleCSWaveform(bleCSConfig)` (R2024b+); CS has its own ranging/distance-measurement pipeline and is not part of PHY waveform generation
- Network-level simulation → use `bluetoothLENode` for link-layer/network modeling
- Path loss modeling → use `bluetoothPathLoss` for propagation/channel modeling

## PHY Modes

| Mode | symbolRate | Data Rate | Coding | Duration (37 B) |
|------|:----------:|:---------:|--------|:---------------:|
| `"LE1M"` | 1e6 | 1 Mbps | None | ~336 us |
| `"LE2M"` | **2e6** | 2 Mbps | None | ~172 us |
| `"LE500K"` | 1e6 | 500 kbps | FEC S=2 | ~974 us |
| `"LE125K"` | 1e6 | 125 kbps | FEC S=8 | ~2768 us |

## References

For detailed guidance beyond what's in this file, see:

- [functionalAPI.md](references/functionalAPI.md) — Full API reference for bleWaveformGenerator Name-Value pairs
- [phy-modes-and-timing.md](references/phy-modes-and-timing.md) — Detailed timing calculations per PHY mode
- [cte-direction-finding.md](references/cte-direction-finding.md) — CTE pipeline: generation, IQ sampling, constraints
- [direction-finding.md](references/direction-finding.md) — AoA/AoD angle estimation with bleAngleEstimate
- [rfphy-compliance-testing.md](references/rfphy-compliance-testing.md) — RF-PHY test waveform patterns and config
- [transmitter-measurements.md](references/transmitter-measurements.md) — OBW, PAPR, power measurement patterns
- [practical-receiver-simulation.md](references/practical-receiver-simulation.md) — BER simulation and impaired receiver
- [wlan-coexistence.md](references/wlan-coexistence.md) — WLAN interference and coexistence scenarios
- [rssi-localization.md](references/rssi-localization.md) — RSSI beacon and distance estimation patterns
- [data-whitening.md](references/data-whitening.md) — Whitening on/off comparison and internals

## Parameters (bleWaveformGenerator)

| Param | Default | Range |
|-------|---------|-------|
| `Mode` | `"LE1M"` | LE1M, LE2M, LE500K, LE125K |
| `ChannelIndex` | 37 | 0-39 |
| `SamplesPerSymbol` | 8 | >=1 (use >=4 for plots) |
| `WhitenStatus` | `"On"` | On, Off |
| `DFPacketType` | `"Disabled"` | Disabled, ConnectionCTE, ConnectionlessCTE |
| `AccessAddress` | adv default | 32-bit binary col vector |
| `ModulationIndex` | 0.5 | [0.45, 0.55] |
| `PulseLength` | 1 | [1, 4] |

## Core Recipe

```matlab
messageBits = randi([0 1], payloadLenBytes*8, 1);
waveform = bleWaveformGenerator(messageBits, ...
    Mode=phyMode, SamplesPerSymbol=sps, ...
    ChannelIndex=ch, WhitenStatus="On");
symbolRate = 1e6 + 1e6*(phyMode=="LE2M");
fs = symbolRate * sps;
```

## Patterns

### All-Mode Comparison

```matlab
phyModes = ["LE1M","LE2M","LE500K","LE125K"];
sps = 8;
messageBits = randi([0 1], 37*8, 1);
figure; tl = tiledlayout(4,2,TileSpacing="compact",Padding="compact");
title(tl,"BLE - All PHY Modes")
for idx = 1:4
    wf = bleWaveformGenerator(messageBits, ...
        Mode=phyModes(idx), SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="On");
    sr = 1e6 + 1e6*(phyModes(idx)=="LE2M");
    fs = sr*sps; t = (0:length(wf)-1)/fs*1e6;
    nexttile; plot(t,real(wf),t,imag(wf))
    xlabel("Time (\mus)"); ylabel("Amplitude"); title(phyModes(idx)+" - IQ")
    legend("I","Q"); grid on; xlim([0 min(80,t(end))])
    nexttile; N=length(wf); f=(-N/2:N/2-1)*(fs/N)/1e6;
    plot(f, 20*log10(abs(fftshift(fft(wf)))/N+eps))
    xlabel("Frequency (MHz)"); ylabel("dB"); title(phyModes(idx)+" - Spectrum")
    grid on; xlim([-3 3]); ylim([-80 0])
end
```

### Multi-Packet Burst (T_IFS = 150 us)

```matlab
sps = 8; fs = 1e6*sps;
messageBits = randi([0 1], 37*8, 1);
ifsGap = complex(zeros(round(150e-6*fs), 1));
burst = complex(zeros(0,1));
for pkt = 1:3
    wf = bleWaveformGenerator(messageBits, Mode="LE1M", SamplesPerSymbol=sps, ChannelIndex=37);
    burst = [burst; wf; ifsGap]; %#ok<AGROW>
end
```

### Round-Trip Decode

```matlab
messageBits = randi([0 1], 37*8, 1); sps = 8;
wf = bleWaveformGenerator(messageBits, Mode="LE1M", SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="On");
rxBits = bleIdealReceiver(wf, Mode="LE1M", SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="On");
assert(isequal(rxBits, messageBits))
```

### Data Channel + Custom Access Address

```matlab
accessAddr = randi([0 1], 32, 1);
wf = bleWaveformGenerator(randi([0 1],27*8,1), ...
    Mode="LE2M", SamplesPerSymbol=8, ChannelIndex=9, ...
    AccessAddress=accessAddr, WhitenStatus="On");
fs = 2e6 * 8;
```

### CTE Generation

```matlab
messageBits = randi([0 1], 20*8, 1); sps = 8; fs = 1e6*sps;
wf_noCTE = bleWaveformGenerator(messageBits, Mode="LE1M", ...
    SamplesPerSymbol=sps, ChannelIndex=10, WhitenStatus="On");
wf_conn = bleWaveformGenerator(messageBits, Mode="LE1M", ...
    SamplesPerSymbol=sps, ChannelIndex=10, WhitenStatus="On", DFPacketType="ConnectionCTE");
wf_cless = bleWaveformGenerator(messageBits, Mode="LE1M", ...
    SamplesPerSymbol=sps, ChannelIndex=10, WhitenStatus="On", DFPacketType="ConnectionlessCTE");

% CTE appends unmodulated constant tone for antenna switching (typ. 72-216 us)
cteDelta_conn_us = (length(wf_conn) - length(wf_noCTE)) / fs * 1e6;
cteDelta_cless_us = (length(wf_cless) - length(wf_noCTE)) / fs * 1e6;
```

### CTE Full Pipeline (Tx → Rx → Angle)

```matlab
pduHex = '02049B03270102030405';  % 10-byte PDU (>=6 bytes needed for >=11 IQ samples)
pdu = int2bit(hex2dec(reshape(pduHex, 2, [])'), 8, false);
pdu = pdu(:);
cfgCRC = crcConfig(Polynomial="z^24+z^10+z^9+z^6+z^4+z^3+z+1", ...
    InitialConditions=int2bit(hex2dec('555551'),24), DirectMethod=true);
pduCRC = crcGenerate(pdu, cfgCRC);
txWf = bleWaveformGenerator(pduCRC, ChannelIndex=36, DFPacketType="ConnectionlessCTE");
[~, ~, iqSamples] = bleIdealReceiver(txWf, ChannelIndex=36, ...
    DFPacketType="ConnectionlessCTE", SlotDuration=2);
cfgAngle = bleAngleEstimateConfig;
cfgAngle.ArraySize = 4; cfgAngle.SlotDuration = 2; cfgAngle.SwitchingPattern = [1 2 3 4];
angle = bleAngleEstimate(iqSamples, cfgAngle);
```

Alternative (R2022a+): `iqSamples = bleCTEIQSample(cteSamples, Mode="LE1M", SlotDuration=2);`

### BER Simulation

```matlab
messageBits = randi([0 1], 100*8, 1); sps = 8; phyMode = "LE1M";
snrValues = 0:4:20; berResults = zeros(size(snrValues));
for idx = 1:length(snrValues)
    wf = bleWaveformGenerator(messageBits, Mode=phyMode, SamplesPerSymbol=sps, ChannelIndex=5, WhitenStatus="On");
    sigPower = mean(abs(wf).^2);
    rxWf = awgn(wf, snrValues(idx), 10*log10(sigPower));
    rxBits = bleIdealReceiver(rxWf, Mode=phyMode, SamplesPerSymbol=sps, ChannelIndex=5, WhitenStatus="On");
    n = min(length(messageBits), length(rxBits));
    berResults(idx) = sum(messageBits(1:n) ~= double(rxBits(1:n))) / n;
end
semilogy(snrValues, berResults, "-o"); xlabel("SNR (dB)"); ylabel("BER"); grid on
```

`bleIdealReceiver` returns `int8` — cast with `double()`. For Eb/No conversion: `snr = convertSNR(EbNo,"ebno","snr",SamplesPerSymbol=sps)`.

### RF-PHY Test Waveform

```matlab
cfg = bluetoothTestWaveformConfig;
cfg.Mode = "LE1M"; cfg.PayloadLength = 37;
cfg.PacketType = "Disabled"; cfg.ModulationIndex = 0.5;
testWf = bluetoothTestWaveform(cfg);

rfCfg = bluetoothRFPHYTestConfig;
rfCfg.Test = "Output power"; rfCfg.Mode = "LE1M";
rfCfg.PayloadLength = 37; rfCfg.OutputPower = 0; rfCfg.CenterFrequency = "Mid";
```

### WLAN Coexistence

```matlab
sps = 8; fs = 1e6*sps;
bleWf = bleWaveformGenerator(randi([0 1],37*8,1), Mode="LE1M", SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="On");
t = (0:length(bleWf)-1)'/fs;
wlanInterferer = 0.1*complex(randn(length(bleWf),1),randn(length(bleWf),1)) .* exp(1j*2*pi*3e6*t);
combined = bleWf + wlanInterferer;
CIR_dB = 10*log10(mean(abs(bleWf).^2) / mean(abs(wlanInterferer).^2));
```

### TX Measurements (Power, OBW, PAPR)

```matlab
sps = 8; wf = bleWaveformGenerator(randi([0 1],255*8,1), Mode="LE1M", ...
    SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="On", ModulationIndex=0.5);
fs = 1e6*sps; N = length(wf);
avgPower_dBm = 10*log10(mean(abs(wf).^2)) + 30;
spec = abs(fftshift(fft(wf))).^2; cumP = cumsum(spec)/sum(spec);
f = (-N/2:N/2-1)*(fs/N);
occBW_MHz = (f(find(cumP>=0.995,1)) - f(find(cumP>=0.005,1))) / 1e6;
papr_dB = 10*log10(max(abs(wf).^2) / mean(abs(wf).^2));
```

### Whitening Comparison

```matlab
bits = randi([0 1], 37*8, 1); sps = 8;
wfOn  = bleWaveformGenerator(bits, Mode="LE1M", SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="On");
wfOff = bleWaveformGenerator(bits, Mode="LE1M", SamplesPerSymbol=sps, ChannelIndex=37, WhitenStatus="Off");
```

### Advertising PDU (ADV_IND)

```matlab
cfgAdv = bleLLAdvertisingChannelPDUConfig;
cfgAdv.PDUType = "Advertising indication";
cfgAdv.AdvertiserAddress = "A1B2C3D4E5F6";
cfgAdv.AdvertiserAddressType = "Random";
cfgAdv.AdvertisingData = "0201060709546573744245020A00";
pduBits = bleLLAdvertisingChannelPDU(cfgAdv);
wf = bleWaveformGenerator(pduBits, Mode="LE1M", SamplesPerSymbol=8, ChannelIndex=37);
```

PDUType values: `"Advertising indication"`, `"Scan request"`, `"Scan response"`, `"Connection indication"`, `"Advertising direct indication"`, `"Advertising non connectable indication"`.
Addresses: 12-char hex string (no colons). AdvertisingData: hex string (length-type-value AD structs).

### Data Channel PDU

```matlab
cfgData = bleLLDataChannelPDUConfig;
cfgData.LLID = "Data (start fragment/complete)";
cfgData.SequenceNumber = 1;
cfgData.NESN = 0;
cfgData.MoreData = false;
payload = dec2hex(randi([0 255], 50, 1))';  % 50-byte hex payload
payload = reshape(payload', 1, []);
pduBits = bleLLDataChannelPDU(cfgData, payload);
wf = bleWaveformGenerator(pduBits, Mode="LE2M", SamplesPerSymbol=8, ChannelIndex=15);
```

LLID values: `"Data (continuation fragment/empty)"`, `"Data (start fragment/complete)"`, `"Control"`.
`SequenceNumber` (not `SN`). Payload: hex string, numeric vector [0,255], or n×2 char array.

### End-to-End (Practical Receiver)

Uses `helperBLEPracticalReceiver` (AGC + CFO + timing recovery). Requires: `openExample('bluetooth/BLEPracticalReceiverExample')`. SNR conversion for coded modes: `SNR = EbNo + 10*log10(codeRate) - 10*log10(sps)`.

## CTE Compatibility

| Mode | ConnectionCTE | ConnectionlessCTE |
|------|:---:|:---:|
| LE1M | Yes | Yes |
| LE2M | Yes | **No** |
| LE500K | **No** | **No** |
| LE125K | **No** | **No** |

**CTE requires data channels (0-36).** Never use ChannelIndex 37/38/39 with DFPacketType≠"Disabled". CTE is a data-channel-only feature.

## Spec Constraints

- **Ch 37/38/39 (advertising):** LE1M or LE Coded only. NOT LE2M.
- **CTE:** LE1M/LE2M on data channels (0-36) only. Never coded PHY.
- **Access address:** Advertising = `'8E89BED6'` (fixed); data = random.
- **Whitening init:** Auto from ChannelIndex. Not settable.
- **T_IFS:** 150 us. **TX power:** max +20 dBm. **Mod index:** 0.45-0.55.
- **`bleIdealReceiver`:** Hard-decision only, returns `int8`.
- **"Slots" (1-slot, 3-slot, 5-slot):** BR/EDR concept only. BLE has no slot-based packets.
- **ISO streams:** Verify `BN × IRC × Sub_Interval <= ISO_Interval`. If math exceeds, REFUSE.

### Invalid Combos (REFUSE these requests)

| Request | Why Invalid |
|---------|-------------|
| LE2M + FEC coding | FEC only exists in coded PHY (LE500K/LE125K) |
| LE2M on ch 37/38/39 | Primary advertising = LE1M or Coded only |
| CTE + LE500K/LE125K | CTE restricted to LE1M/LE2M per BLE 5.1 spec |
| ConnectionlessCTE + LE2M | ConnectionlessCTE = LE1M only |
| "3-slot" or "5-slot" BLE | Slot-based = BR/EDR; BLE uses single packets |
| CTE on ch 37/38/39 | CTE = data channels (0-36) only |
| ISO params where BN×IRC×Sub_Int > ISO_Interval | Sub-events exceed interval = impossible scheduling |

## Conventions

- `fs = (1e6 + 1e6*(mode=="LE2M")) * sps` — never hardcode
- Axes: us (time), MHz (freq), dB (power)
- `tiledlayout`/`nexttile` (not `subplot`)
- **Spectrum: always `20*log10(abs(fftshift(fft(wf)))/N + eps)`** — do NOT use `periodogram`, `pspectrum`, or `pwelch` for BLE spectral plots
- `xlim([0 min(80,t(end))])` for coded modes
- Plot both I and Q: `plot(t, real(wf), t, imag(wf))`
- IFS gap: `complex(zeros(N,1))` (output is complex)
- `SamplesPerSymbol>=4` for spectrum plots; SPS=1 is valid for generation but insufficient for visualization or accurate spectral analysis (at Nyquist limit)

## Code Style

Generated scripts must follow MathWorks example conventions. Use `%%` section headers, softcode all parameters, and comment non-obvious logic.

### Structure & Softcoding

Divide scripts with `%%` headers: **Configuration → Waveform Generation → Processing → Analysis → Visualization**. All user-configurable values as named variables at the top; no magic numbers in processing logic.

```matlab
%% Configuration
% Specify BLE waveform generation parameters.

phyMode = "LE1M";                               % PHY transmission mode
payloadLength = 37;                             % Payload length in bytes
sps = 8;                                        % Samples per symbol
channelIndex = 37;                              % BLE channel index (0-39)

% Derived parameters
symbolRate = 1e6 + 1e6*(phyMode=="LE2M");       % 2 Msym/s for LE2M, 1 Msym/s otherwise
fs = sps * symbolRate;                          % Sample rate in Hz
numBits = payloadLength * 8;                    % Payload length in bits

%% Waveform Generation
% Generate BLE waveform from random payload bits.

messageBits = randi([0 1], numBits, 1);
waveform = bleWaveformGenerator(messageBits, ...
    Mode=phyMode, SamplesPerSymbol=sps, ChannelIndex=channelIndex);
```

### Comments

- **Inline** (right-aligned): units, range, or brief purpose — `% Eb/No in dB`
- **Block** (above 2-5 lines): intent or *why* — `% IFS gap must be complex (bleWaveformGenerator output is complex)`
- **Constraints**: spec reference — `% LE2M uses 2 Msym/s (only mode with 2x symbol rate)`
- **Do NOT** comment self-evident lines, every line mechanically, or closing `end` statements

### Naming

- **camelCase**: `messageBits`, `txWaveform`, `symbolRate`, `channelIndex`
- Descriptive loop counters: `countMode`, `pktIdx` (not `i`, `j`)
- Named constants: `bitsPerByte = 8`, `tIFS = 150e-6`
- Multi-init: `[numErrors, perCount] = deal(0, 0)`

## Gotchas

| Mistake | Fix |
|---------|-----|
| `bleWaveformConfig(...)` | Does not exist. Use `bleWaveformGenerator(bits, NV...)` directly |
| `bluetoothWaveformGenerator` for BLE | BR/EDR only. Use `bleWaveformGenerator` |
| `comm.BLEReceiver` | Does not exist. Use `bleIdealReceiver` |
| `symbolRate=1e6` for LE2M | LE2M = **2e6** |
| `'PHYMode'` as param name | Use `'Mode'` |
| `'LECODED'` as mode | Use `"LE500K"` or `"LE125K"` |
| Config object as 1st arg | Must be binary col vector `randi([0 1],N,1)` |
| Empty `[]` bits | Minimum 1 byte |
| Real `zeros()` for IFS | Use `complex(zeros(N,1))` |
| CTE + coded modes | CTE only on LE1M/LE2M |
| `ConnectionlessCTE` + LE2M | LE1M only |
| LE2M on ch 37/38/39 | Spec violation. Use LE1M or Coded |
| `CTELength`/`CTEType` as NV args | Not valid. Use `DFPacketType` |
| `bleAngleEstimate(wf, NV...)` | Use `bleAngleEstimate(iqSamples, bleAngleEstimateConfig)` |
| `bleWaveformGenerator` for RF-PHY | Use `bluetoothTestWaveformConfig` + `bluetoothTestWaveform` |
| AWGN without oversampling correction | Use `convertSNR(EbNo,"ebno","snr",SamplesPerSymbol=sps)`; pass explicit power to `awgn` (never use `"measured"`) |
| `bleIdealReceiver` with impairments | Use `helperBLEPracticalReceiver` |
| Eb/No for coded modes without code rate | `SNR = EbNo + 10*log10(codeRate) - 10*log10(sps)` |
| SPS=1 without warning | SPS=1 is at Nyquist limit — warn user: no spectral analysis, marginal decode performance |
| Timing ppm offset without `resample` | Apply clock drift via `resample(wf, 1e6+ppm, 1e6)` or fractional delay filter |
| Conformance Df1/Df2 without PRBS9 | Use `comm.PNSequence` (z^9+z^5+1) for TP/TRM/CA/BV-05-C; separate stable-bit (Df1) from alternating-bit (Df2) patterns |
| `periodogram`/`pwelch` for BLE spectrum | Use manual `fftshift(fft(wf))` — skill convention |
| `SN` as property name | Use `SequenceNumber` on `bleLLDataChannelPDUConfig` |
| Address with colons `"A1:B2:..."` | Use 12-char hex string without colons: `"A1B2C3D4E5F6"` |
| `PDUType="ADV_IND"` | Use full string: `"Advertising indication"` |
| Binary vector as AdvertisingData | Use hex string: `"0201060709..."` (length-type-value) |

----

Copyright 2026 The MathWorks, Inc.
