---
name: matlab-generate-wlan-waveform
description: >
  Generate standard-compliant IEEE 802.11 waveforms using MATLAB WLAN Toolbox.
  Use when creating WLAN waveforms, PPDU packets, or the transmit side of a
  link-level simulation. Covers all formats: Non-HT (802.11a/g), HT (802.11n),
  VHT (802.11ac), HE-SU/HE-MU/HE-TB (802.11ax), EHT-MU/EHT-TB (802.11be),
  UHR-MU/UHR-TB/UHR-ELR (802.11bn). Handles single-user, MU-MIMO, OFDMA,
  trigger-based uplink, extended range, preamble puncturing, UEQM, and DRU.
  Use when asked to generate test waveforms, create packets with MAC frames,
  configure OFDMA resource units, build trigger-based uplink transmissions,
  target a specific transmit duration, or build multi-packet waveforms.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Generate WLAN Waveforms

Generate standard-compliant IEEE 802.11 waveforms for device testing, link-level
simulation, or signal analysis. This skill covers the transmit chain: configure
the PHY format, size the payload, generate the time-domain IQ waveform, and plot.

## When to Use

- Generating WLAN/Wi-Fi test waveforms for any 802.11 standard
- Creating the transmit side of a link-level simulation
- Building packets with specific MAC frame types (Data, Block Ack, Beacon, etc.)
- Configuring OFDMA resource unit allocations (HE-MU, EHT-MU, or UHR-MU)
- Configuring MU-MIMO transmissions (VHT, HE, EHT, UHR)
- UHR features: UEQM (per-stream MCS), DRU, LDPC2x, ELR (enhanced long range)
- Targeting a specific packet duration or transmit time

## When NOT to Use

- Channel modeling, receiver processing, EVM/spectral mask — not covered
- Non-WLAN waveforms (5G NR, LTE, Bluetooth)

**UHR (802.11bn) requires R2026a or later.** If the user requests a UHR waveform
and their release is older, inform them that UHR support was introduced in R2026a
and recommend upgrading.

## Workflow

Every waveform generation follows this pipeline:

1. **Select format** → create the config object (see Format Selection)
2. **Configure PHY** → set bandwidth, MCS, spatial streams, antennas
3. **Size the payload** → set PSDU/APEP length directly or from a target duration
4. **Create payload bits** → random bits or MAC frame via `wlanMACFrame`
5. **Generate waveform** → `wlanWaveformGenerator(bits, cfg)`
6. **Plot and verify** → time-domain magnitude, `showAllocation` for HE/EHT/UHR configs

## Format Selection

| Standard | Marketing | Config Object | Users |
|----------|-----------|---------------|-------|
| 802.11b | Wi-Fi 1 | `wlanNonHTConfig` (DSSS) | SU only |
| 802.11a/g | Wi-Fi 1/3 | `wlanNonHTConfig` | SU only |
| 802.11n | Wi-Fi 4 | `wlanHTConfig` | SU only |
| 802.11ac | Wi-Fi 5 | `wlanVHTConfig` | SU or MU-MIMO |
| 802.11ax | Wi-Fi 6 | `wlanHESUConfig` | SU only |
| 802.11ax | Wi-Fi 6 | `wlanHESUConfig` (ExtendedRange) | SU — extended range |
| 802.11ax | Wi-Fi 6 | `wlanHEMUConfig(allocIdx)` | OFDMA and/or MU-MIMO |
| 802.11ax | Wi-Fi 6 | `wlanHETBConfig` | SU uplink (trigger-based) |
| 802.11be | Wi-Fi 7 | `wlanEHTMUConfig(allocIdx)` | OFDMA and/or MU-MIMO / MRU |
| 802.11be | Wi-Fi 7 | `wlanEHTMUConfig("CBW...")` | Non-OFDMA MU-MIMO (full-band RU) |
| 802.11be | Wi-Fi 7 | `wlanEHTMUConfig("CBW...", EHTDUPMode=true)` | SU — DUP mode (MCS 14 only) |
| 802.11be | Wi-Fi 7 | `wlanEHTTBConfig` | SU uplink (trigger-based) |
| 802.11bn | Wi-Fi 8 | `uhrMUConfig(allocIdx)` | OFDMA / MU-MIMO / UEQM (example helpers) |
| 802.11bn | Wi-Fi 8 | `uhrMUConfig("CBW...")` | Non-OFDMA MU-MIMO (example helpers) |
| 802.11bn | Wi-Fi 8 | `uhrTBConfig` | SU uplink / DRU (example helpers) |
| 802.11bn | Wi-Fi 8 | `uhrELRConfig` | SU enhanced long range (example helpers) |

For OFDMA formats (HE-MU, EHT-MU), the constructor takes **allocation indices**,
not RU sizes. See [references/he-allocation-indices.md](references/he-allocation-indices.md)
and [references/eht-allocation-indices.md](references/eht-allocation-indices.md).

**UHR (802.11bn / Wi-Fi 8) uses example helper files**, not built-in toolbox objects.
Copy helpers into the script's working folder with
`setupExample("wlan/UHRParameterizationExample", scriptFolder)`. UHR supports
UEQM (per-stream MCS), DRU, LDPC2x, ELR (enhanced long range), and new MCS
values (15-23). Same allocation indices as EHT. See
[references/uhr-waveform-generation.md](references/uhr-waveform-generation.md).

See **Critical Rules** for format-specific constraints (allocation index schemes,
HT MCS encoding, DSSS properties).

**EHT DUP mode** duplicates the signal across subchannels for robust coverage.
Set at construction: `wlanEHTMUConfig("CBW80", EHTDUPMode=true)`. Constraints:
MCS 14 (BPSK-DCM) only, single user, 1 spatial stream, no puncturing,
80/160/320 MHz. `EHTDUPMode` is read-only after construction.

## Duration Targeting

Calculate payload size from target duration. All values are **integer microseconds**.

| Config | Function | Example |
|--------|----------|---------|
| `wlanNonHTConfig` | `wlanPSDULength(cfg, 'TxTime', us)` | `cfg.PSDULength = wlanPSDULength(cfg, 'TxTime', 500);` |
| `wlanHTConfig` | `wlanPSDULength(cfg, 'TxTime', us)` | `cfg.PSDULength = wlanPSDULength(cfg, 'TxTime', 1000);` |
| `wlanVHTConfig` (SU only) | `wlanAPEPLength(cfg, 'TxTime', us)` | `cfg.APEPLength = wlanAPEPLength(cfg, 'TxTime', 2000);` |
| `wlanHESUConfig` | `wlanAPEPLength(cfg, 'TxTime', us)` | `cfg.APEPLength = wlanAPEPLength(cfg, 'TxTime', 3000);` |
| `wlanEHTMUConfig` (SU non-OFDMA) | `wlanAPEPLength(cfg, 'TxTime', us)` | `cfg.User{1}.APEPLength = wlanAPEPLength(cfg, 'TxTime', 1000);` |
| Any MU/OFDMA config | Iterative `transmitTime` loop | See below — `wlanAPEPLength` errors on MU/OFDMA |

**Duration argument is integer microseconds, not seconds.** Pass `2000`, not `2e-3`.

### MU Duration Targeting (iterative)

For any MU config (homogeneous users — same MCS, RU size, and spatial streams):

```matlab
targetDuration = 1e-3; apepLen = 2000; % initial guess
for iter = 1:10
    for u = 1:numUsers, cfg.User{u}.APEPLength = apepLen; end
    txTime = transmitTime(cfg);
    if abs(txTime - targetDuration)/targetDuration < 0.01, break; end
    apepLen = round(apepLen * targetDuration / txTime);
end
```

**Heterogeneous users (different MCS/RU/STS):** Lowest-capacity user sets duration.
Set per-user APEPLength based on traffic demand; use `transmitTime(cfg)`.

## PSDU Length Access

The way to get PSDU length varies by format. Using the wrong pattern throws errors.

| Config | How to get PSDU length | Notes |
|--------|----------------------|-------|
| `wlanNonHTConfig` | `cfg.PSDULength` | Settable property |
| `wlanHTConfig` | `cfg.PSDULength` | Settable property |
| `wlanVHTConfig` | `cfg.PSDULength` | Read-only property (derived from APEPLength). Vector for MU. |
| `wlanHESUConfig` | `getPSDULength(cfg)` | Method call. Not a property. |
| `wlanHEMUConfig` | `getPSDULength(cfg)` | Method call. Returns vector (one per user). |
| `wlanHETBConfig` | `getPSDULength(cfg)` | Method call. Same as HE-SU/HE-MU. |
| `wlanEHTMUConfig` | `psduLength(cfg)` | **Different method name** from HE. Returns vector. |
| `wlanEHTTBConfig` | `psduLength(cfg)` | Same method name as EHT-MU. |

**`getPSDULength` and `psduLength` are not interchangeable.** HE uses
`getPSDULength`. EHT uses `psduLength`.

## Key Functions

| Function | Purpose |
|----------|---------|
| `wlanWaveformGenerator(bits, cfg)` | Generate time-domain IQ waveform |
| `wlanSampleRate(cfg)` | Get sample rate for the configuration — always use this |
| `wlanHETBConfig` | Configure HE trigger-based uplink (single STA) |
| `wlanEHTTBConfig` | Configure EHT trigger-based uplink (single STA) |
| `wlanMACFrame(payload, cfgMAC)` | Generate MAC frame bits (see [references/mac-frame-properties.md](references/mac-frame-properties.md)) |
| `wlanAPEPLength(cfg, 'TxTime', us)` | APEP length for target duration (VHT-SU, HE-SU, EHT-MU single-user) |
| `wlanPSDULength(cfg, 'TxTime', us)` | PSDU length for target duration (NonHT/HT) |
| `transmitTime(cfg)` or `transmitTime(cfg, 'microseconds')` | Get transmit time — use unit argument instead of `* 1e6` |
| `showAllocation(cfg)` or `showAllocation(cfg, ax)` | Plot RU allocation — pass axes handle to embed in tiledlayout |
| `ruInfo(cfg)` | Query RU sizes, indices, user counts |

If you need to verify property names, check valid values for a config
object, or look up parameters not covered in this skill, consult the online
documentation links in [references/documentation-links.md](references/documentation-links.md).

## Patterns

### Single-User Waveform with Target Duration

```matlab
cfg = wlanVHTConfig;
cfg.ChannelBandwidth = 'CBW80';
cfg.MCS = 9;
cfg.NumTransmitAntennas = 4;
cfg.NumSpaceTimeStreams = 4;
cfg.SpatialMapping = 'Fourier';

% Size payload for 2 ms transmit time
cfg.APEPLength = wlanAPEPLength(cfg, 'TxTime', 2000);

% Generate waveform: 3 packets, 20 us idle
psduBits = randi([0 1], cfg.PSDULength * 8, 1);
waveform = wlanWaveformGenerator(psduBits, cfg, ...
    'NumPackets', 3, 'IdleTime', 20e-6);

fs = wlanSampleRate(cfg);
```

### DSSS (802.11b) Waveform

```matlab
cfg = wlanNonHTConfig;
cfg.Modulation = 'DSSS';
cfg.DataRate = '11Mbps';   % '1Mbps', '2Mbps', '5.5Mbps', or '11Mbps'
cfg.PSDULength = 1000;

psduBits = randi([0 1], cfg.PSDULength * 8, 1);
waveform = wlanWaveformGenerator(psduBits, cfg);
fs = wlanSampleRate(cfg);  % 11 MHz (chip rate)
```

### HE-MU OFDMA Waveform

For OFDMA, the constructor takes **allocation indices** per 20 MHz subchannel.
Read [references/he-allocation-indices.md](references/he-allocation-indices.md) for
the full index-to-RU mapping.

```matlab
% 80 MHz, four 242-tone RUs (index 192 = one 242-tone RU per subchannel)
cfg = wlanHEMUConfig([192 192 192 192]);
cfg.NumTransmitAntennas = 4;

% Configure per-user parameters
for u = 1:4
    cfg.User{u}.MCS = u + 6;               % MCS 7, 8, 9, 10
    cfg.User{u}.NumSpaceTimeStreams = 1;
    cfg.User{u}.APEPLength = 4000;
    cfg.User{u}.ChannelCoding = 'LDPC';
end

% Use Fourier spatial mapping when NumSTS < NumTransmitAntennas per RU
for r = 1:numel(cfg.RU)
    cfg.RU{r}.SpatialMapping = 'Fourier';
end

% Generate PSDU bits per user
psduLen = getPSDULength(cfg);
txData = cell(1, numel(psduLen));
for u = 1:numel(psduLen)
    txData{u} = randi([0 1], psduLen(u) * 8, 1);
end

waveform = wlanWaveformGenerator(txData, cfg);
showAllocation(cfg);
```

**Common HE allocation indices (per 20 MHz subchannel):**

| Index | RU Layout | Users |
|-------|-----------|-------|
| 0 | Nine 26-tone | 9 |
| 96 | Two 106-tone | 2 |
| 112 | Four 52-tone | 4 |
| 192 | One 242-tone | 1 |
| 193 | One 242-tone | 2 (MU-MIMO) |
| 200 | One 484-tone (40 MHz pair) | 1 |
| 208 | One 996-tone (80 MHz quad) | 1 |

For 40 MHz, provide 2 indices. For 80 MHz, provide 4. For 160 MHz, provide 8.

### EHT-MU OFDMA Waveform (with MRU)

EHT allocation indices support Multi-Resource Units (MRU) — non-contiguous tone
blocks assigned to a single user. Read
[references/eht-allocation-indices.md](references/eht-allocation-indices.md) for
the full mapping.

```matlab
% 80 MHz: 484+242 MRU on subchannels 1-3, 106+26+106 on subchannel 4
% Index 120 = 484+242 MRU (1 MU-MIMO user), 29/28 = continuation, 25 = 106+26+106
cfg = wlanEHTMUConfig([120 29 28 25]);
cfg.NumTransmitAntennas = 2;

% Set APEPLength appropriate to RU size (26-tone RUs have low throughput)
apepPerUser = [2000, 500, 100, 500]; % MRU, 106-tone, 26-tone, 106-tone
mcsPerUser  = [7, 4, 2, 4];
for u = 1:numel(cfg.User)
    cfg.User{u}.APEPLength = apepPerUser(u);
    cfg.User{u}.MCS = mcsPerUser(u);
    cfg.User{u}.NumSpaceTimeStreams = 1;
    cfg.User{u}.ChannelCoding = 'LDPC';
end

for r = 1:numel(cfg.RU)
    cfg.RU{r}.SpatialMapping = 'Fourier';
end

% EHT uses psduLength(), NOT getPSDULength()
psduLens = psduLength(cfg);
txData = cell(1, numel(psduLens));
for u = 1:numel(psduLens)
    txData{u} = randi([0 1], psduLens(u) * 8, 1);
end

waveform = wlanWaveformGenerator(txData, cfg);
showAllocation(cfg);
```

**EHT continuation indices:** When an RU spans multiple 20 MHz subchannels, use
continuation indices for the additional subchannels:
- **28** — subchannel is part of a larger 242-tone allocation
- **29** — subchannel is part of a 484-tone allocation
- **30** — subchannel is part of a 996-tone allocation

### VHT MU-MIMO Waveform

```matlab
cfg = wlanVHTConfig;
cfg.ChannelBandwidth = 'CBW80';
cfg.NumUsers = 2;
cfg.NumTransmitAntennas = 4;
cfg.NumSpaceTimeStreams = [2 2];
cfg.MCS = [8 8];
cfg.APEPLength = [1024 1024];
cfg.GroupID = 2;                    % MU-MIMO: must be 1-62
cfg.SpatialMapping = 'Fourier';    % Required when total STS < NumTxAntennas

psduLen = cfg.PSDULength;           % Read-only vector for MU
txData = cell(1, cfg.NumUsers);
for u = 1:cfg.NumUsers
    txData{u} = randi([0 1], psduLen(u) * 8, 1);
end

waveform = wlanWaveformGenerator(txData, cfg);
```

### Non-OFDMA MU-MIMO Waveform (EHT and HE)

When the user requests MU-MIMO **without OFDMA** (all users share a single
full-bandwidth RU), use these patterns. **If the user says "MU-MIMO" without
mentioning OFDMA or multiple RUs, default to non-OFDMA.**

**EHT** — use the string constructor (no allocation indices needed):

```matlab
% 80 MHz, 2 MU-MIMO users on a single 996-tone RU (non-OFDMA)
cfg = wlanEHTMUConfig("CBW80", NumUsers=2);
cfg.NumTransmitAntennas = 4;
cfg.User{1}.NumSpaceTimeStreams = 2;
cfg.User{1}.MCS = 9;
cfg.User{1}.APEPLength = 4000;
cfg.User{1}.ChannelCoding = 'LDPC';
cfg.User{2}.NumSpaceTimeStreams = 2;
cfg.User{2}.MCS = 7;
cfg.User{2}.APEPLength = 4000;
cfg.User{2}.ChannelCoding = 'LDPC';
cfg.RU{1}.SpatialMapping = 'Fourier';

psduLens = psduLength(cfg);
txData = cell(1, numel(psduLens));
for u = 1:numel(psduLens)
    txData{u} = randi([0 1], psduLens(u) * 8, 1);
end
waveform = wlanWaveformGenerator(txData, cfg);
```

Valid bandwidths: `"CBW20"`, `"CBW40"`, `"CBW80"`, `"CBW160"`, `"CBW320"`.
Up to 8 users. Supports puncturing via `PuncturedChannelFieldValue`.

**HE** — no string constructor; use full-band allocation indices:

| Bandwidth | Index for N users | Zero-user index |
|-----------|-------------------|-----------------|
| 20 MHz | `192 + N - 1` | N/A |
| 40 MHz | `[200 + N - 1, 114]` | 114 |
| 80 MHz | `[208 + N - 1, 115, 115, 115]` | 115 |
| 160 MHz | `[216 + N - 1, 115, 115, 115, 115, 115, 115, 115]` | 115 |

Follow the same per-user/per-RU pattern as EHT above, using `getPSDULength(cfg)`
instead of `psduLength(cfg)`. Example: `cfg = wlanHEMUConfig([209 115 115 115])`
for 80 MHz with 2 users.

### MAC Frame Payload

See [references/mac-frame-properties.md](references/mac-frame-properties.md) for:
- Argument order, payload format (hex octets), and PHY config requirements
- Frame types, properties, and aggregation (A-MSDU, A-MPDU)
- Common mistakes and calling conventions

### Multi-Packet Waveforms

See [references/multi-packet-waveforms.md](references/multi-packet-waveforms.md) for:
- **A-MPDU aggregation** with `wlanMSDULengths` (cell array of uint8 MSDUs)
- **Multi-packet waveforms** — identical (`NumPackets`, `IdleTime`) or mixed-format
  concatenation with SIFS/DIFS/PIFS spacing

Quick reference — inter-frame spacing: SIFS=16 μs, DIFS=34 μs, PIFS=25 μs.

### Trigger-Based (TB) Uplink

See [references/trigger-based-uplink.md](references/trigger-based-uplink.md) for:
- **HE TB** (`wlanHETBConfig`), **EHT TB** (`wlanEHTTBConfig`), **UHR TB** (`uhrTBConfig`)
- `RUSize`/`RUIndex` from `ruInfo(cfgMU)`, LTF symbols, `OversamplingFactor`
- **UHR DRU** — distributed resource units with DBW/RU size rules

## Conventions

- **After generating a waveform**, unless the user asks for something specific:
  1. Tell the user the waveform variable name, size, and sample rate
  2. Plot the time-domain waveform magnitude with a time axis in milliseconds
  3. For HE, EHT, or UHR configurations, call `showAllocation(cfg)`
  4. Save the generation code as a **plain-text Live Code `.m` file** using the
     `matlab-create-live-script` skill format (`%[text]` markup, `%%` sections,
     required appendix). Open it in the editor with `edit('scriptName.m')`.
- **UHR scripts use a working folder** — copy helpers into the same folder as
  the script with `setupExample`. See
  [references/uhr-waveform-generation.md](references/uhr-waveform-generation.md).
- **Single-user payload is a plain column vector** — use a cell array only for
  multi-user. `wlanWaveformGenerator(bits, cfg)` not `wlanWaveformGenerator({bits}, cfg)`.
- **Always use `wlanSampleRate(cfg)`** — never hardcode. For UHR configs use
  `wlanSampleRate(cfg.ChannelBandwidth)` (UHR objects are not yet supported).
- **OFDMA bandwidth is read-only** — inferred from allocation index vector
  length (1→20, 2→40, 4→80, 8→160 MHz).
- **Units:** `IdleTime` in seconds (`20e-6`). Duration functions in integer
  microseconds (`2000`). `OversamplingFactor` multiplies `wlanSampleRate`.
  `transmitTime(cfg, 'microseconds')` — use the unit argument for display,
  not `* 1e6`. Valid units: `'seconds'`, `'milliseconds'`, `'microseconds'`,
  `'nanoseconds'`.
- **Verify multi-user configs with `ruInfo(cfg)`** — after constructing any
  OFDMA or MU-MIMO config, call `ruInfo` and check `NumUsers`, `NumUsersPerRU`,
  and `RUSizes` match what was requested. Wrong allocation indices silently
  produce wrong user counts.
- **ruInfo:** HE returns numeric arrays. EHT returns cell arrays (MRU support).
- **Plotting:** `tiledlayout`/`nexttile` (not `subplot`).
  `showAllocation(cfg, ax)` embeds in existing layout.

## Critical Rules

These constraints cause the most errors. Check them before calling
`wlanWaveformGenerator`.

### PSDU Length Method Varies by Format

Using the wrong accessor throws "Undefined function" or silent wrong results.

| Format | How to get PSDU length | Wrong approach |
|--------|----------------------|---------------|
| Non-HT, HT | `cfg.PSDULength` (property) | `getPSDULength(cfg)` — errors |
| VHT | `cfg.PSDULength` (read-only) | Setting it — errors |
| HE-SU, HE-MU, HE-TB | `getPSDULength(cfg)` | `psduLength(cfg)` — errors |
| EHT-MU, EHT-TB | `psduLength(cfg)` | `getPSDULength(cfg)` — errors |

### Allocation Indices Are Not RU Sizes

`wlanHEMUConfig(242)` is **invalid**. Use `wlanHEMUConfig(192)` for a
242-tone RU. `wlanEHTMUConfig(242)` is also invalid — use
`wlanEHTMUConfig(64)`. Always consult the allocation index reference tables.

**HE and EHT use completely different index schemes.** A 242-tone RU is
index 192 for HE but index 64 for EHT. Never mix them.

**HE-MU multi-subchannel RU indices signal users per content channel** — see
[references/he-allocation-indices.md](references/he-allocation-indices.md).

### Preamble Puncturing vs STAID=2046

| Goal | HE | EHT (OFDMA) | EHT (non-OFDMA) |
|------|-----|-------------|-----------------|
| Fully puncture subchannel | Allocation index **113** | Allocation index **26** | `PuncturedChannelFieldValue` at construction |
| Disable user data only | STAID=2046 | STAID=2046 | — |

STAID=2046 does **not** puncture — it only disables one user's data.

**Non-OFDMA puncturing** uses `PuncturedChannelFieldValue` (1–4 for 80 MHz,
mapping to subchannels 1–4). Must be set at construction:
`wlanEHTMUConfig("CBW80", NumUsers=2, PuncturedChannelFieldValue=3)`

### Spatial Mapping Rules

```
NumSpaceTimeStreams < NumTransmitAntennas per RU  →  SpatialMapping = 'Fourier'
NumSpaceTimeStreams == NumTransmitAntennas         →  SpatialMapping = 'Direct'
```

Using `'Direct'` when STS < antennas causes a dimension mismatch error.

### Non-OFDMA Is the Default for MU-MIMO

When the user says "MU-MIMO" without mentioning OFDMA or multiple RUs,
default to non-OFDMA (single full-bandwidth RU shared by all users):
- **EHT:** `wlanEHTMUConfig("CBW80", NumUsers=N)`
- **HE:** Full-band allocation indices (see Patterns section)

### Trigger-Based RUIndex From ruInfo

TB config `RUIndex` values are **subcarrier-based positions from
`ruInfo(cfgMU).RUIndices`**, not sequential RU numbers. Using wrong
indices causes subcarrier overlap errors.

### Construction-Time-Only Properties

`EHTDUPMode`, `PuncturedChannelFieldValue`, and `NumUsers` on `wlanEHTMUConfig`
are **read-only after construction** — pass them as name-value pairs in the
constructor. See [references/eht-allocation-indices.md](references/eht-allocation-indices.md)
for the full list and examples.

### Format-Specific Constraints

| Constraint | Details |
|-----------|---------|
| **HT MCS encodes streams** | MCS 0-7 = 1 SS, 8-15 = 2 SS, 16-23 = 3 SS, 24-31 = 4 SS. Set `NumSpaceTimeStreams = floor(MCS/8) + 1`. |
| **DSSS has no OFDM properties** | Use `DataRate` ('1Mbps'...'11Mbps'). No `ChannelBandwidth`, `MCS`, `NumTransmitAntennas`, or `NumSpaceTimeStreams`. |
| **HE ER + Upper106ToneRU** | Restricts MCS to 0. The 242-tone ER variant allows MCS 0-2. |
| **VHT GroupID** | 0/63 = SU. 1-62 = MU-MIMO. Silently accepts wrong values. |
| **`wlanAPEPLength` is SU-only** | Works for VHT-SU, HE-SU, and EHT-MU single-user (non-OFDMA). Errors on any MU/OFDMA config — use iterative `transmitTime` loop. |
| **Do not fabricate IEEE versions** | Direct the user to the [WLAN Toolbox Release Notes](https://mathworks.com/help/wlan/release-notes.html). |

----

Copyright 2026 The MathWorks, Inc.