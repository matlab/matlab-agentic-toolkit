---
name: matlab-generate-5g-waveform
description: >
  Generate 3GPP-compliant 5G NR downlink and uplink baseband waveforms.
  Use to create NR signals, test model (TM) waveforms, fixed reference
  channels (FRC), test and measurement (T&M) signals, or test vectors for
  conformance testing. Covers configuring data, control, and broadcast
  channels and signals: PDSCH, PUSCH, PDCCH, PUCCH, SRS, SSBurst, CSI-RS,
  DM-RS, PT-RS, CORESET, and BWP parameters including bandwidth,
  subcarrier spacing (SCS), modulation (QPSK, QAM), numerology, FR1, FR2,
  TDD, FDD, and multi-bandwidth-part setups. Use for signal generation, RF
  instrument playback, or IQ baseband synthesis. Requires 5G Toolbox.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2024b"
metadata:
  author: MathWorks
  version: "1.0"
---

# Generate 5G NR Waveforms

Generate standard-compliant 5G NR downlink and uplink waveforms for test and
measurement, simulation, and verification using `nrWaveformGenerator`.

## When to Use

- Generate a 5G, NR, or New Radio waveform
- Create DL waveforms with PDSCH, PDCCH, SSBurst, CSI-RS
- Create UL waveforms with PUSCH, PUCCH, SRS
- Generate NR test model (TM) or fixed reference channel (FRC) waveforms
- Configure waveform parameters: bandwidth, SCS, modulation, power levels
- Create multi-bandwidth-part waveforms

## When NOT to Use

- Channel modeling or propagation — use `nrCDLChannel`, `nrTDLChannel`
- Receiver processing or decoding — use `nrPDSCHDecode`, `nrDLSCHDecoder`
- Link-level simulation end-to-end

## API Choice

| Need | API | Notes |
|------|-----|-------|
| Standard test model (TM) | `hNRReferenceWaveformGenerator` | Predefined 3GPP configs. See [test-models-and-frc.md](references/test-models-and-frc.md) |
| Fixed reference channel (FRC) | `hNRReferenceWaveformGenerator` | DL and UL FRCs |
| Custom DL waveform | `nrDLCarrierConfig` + `nrWaveformGenerator` | Full control over all DL channels |
| Custom UL waveform | `nrULCarrierConfig` + `nrWaveformGenerator` | Full control over all UL channels |

**Do NOT use primitive-level functions** (`nrCarrierConfig` + `nrPDSCH` +
`nrOFDMModulate`) for waveform generation. These are for individual channel
signal processing, not waveform construction. `nrWaveformGenerator` handles
channel multiplexing, power scaling, and OFDM modulation correctly.

## Workflow

### Custom DL or UL Waveform

1. **Create carrier config** using the simplified constructor (R2026a+):

```matlab
cfg = nrDLCarrierConfig('FR1', 20, 30);  % DL: FR1, 20 MHz, 30 kHz SCS
cfg = nrULCarrierConfig('FR1', 20, 15);  % UL: FR1, 20 MHz, 15 kHz SCS
```

This auto-populates SCSCarriers, BandwidthParts, SSBurst/CORESET (DL only),
and a default PDSCH or PUSCH with valid parameters sized to the bandwidth.

**Requires R2026a or later.** On earlier releases, use the manual approach
shown in the Narrow Bandwidth DL pattern — create `nrDLCarrierConfig` with
no arguments and set SCSCarriers, BandwidthParts, and channels explicitly.

**Constructor side effect:** For DL, the constructor adds a dedicated SCS
carrier for SSBurst if the requested SCS doesn't match the default SSB
numerology. For example, `nrDLCarrierConfig('FR1', 5, 30)` creates a hidden
15 kHz carrier (20 RBs) for SSBurst Case A. Use manual config instead when
you need exact control over the number of SCS carriers.

2. **Customize channels** — modify defaults or add channels:

```matlab
cfg.PDSCH{1}.Modulation = '64QAM';
cfg.PDSCH{1}.Power = -3;
cfg.PDSCH{1}.DMRSPower = -6;
cfg.NumSubframes = 10;
```

3. **Oversample (optional)** — set sample rate before generation for DAC playback:

```matlab
cfg.SampleRate = 245.76e6;  % Oversampled rate (default: minimum for the BW)
```

4. **Validate** — check the critical rules in the next section before generating.

5. **Generate and verify** — `validateConfig` checks structural rules but does
   **not** detect channel conflicts (e.g., overlapping PDSCH/CSI-RS, CSI-RS/SSBurst).
   Always call `nrWaveformGenerator` to catch these:

```matlab
[waveform, info] = nrWaveformGenerator(cfg);
```

6. **Visualize** — open the config in the 5G Waveform Generator app:

```matlab
openInGenerator(cfg);
```

7. **Inspect output**:

```matlab
sr = info.ResourceGrids(1).Info.SampleRate;
grid = info.ResourceGrids(1).ResourceGridBWP;
```

### Test Model or FRC

`hNRReferenceWaveformGenerator` is an example helper — set up a working
directory with `setupExample` before use (no path modification needed):

```matlab
[exDir, ~] = setupExample('5g/NRTestModelWaveformGenerationExample', fullfile(tempdir, 'tmfrc'));
workDir = fullfile(tempdir, 'myTMWaveform');
mkdir(workDir);
copyfile(fullfile(exDir, '*'), workDir);
cd(workDir);
```

Then generate:

```matlab
wavegen = hNRReferenceWaveformGenerator('NR-FR1-TM1.1', '10MHz', '15kHz', 'FDD');
[waveform, waveinfo] = generateWaveform(wavegen);
displayResourceGrid(wavegen);
```

See [references/test-models-and-frc.md](references/test-models-and-frc.md) for
all valid model names and options.

## Key Functions

| Function / Class | Purpose |
|-----------------|---------|
| `nrWaveformGenerator` | Generate time-domain waveform from carrier config |
| `nrDLCarrierConfig` | DL carrier config (wraps all DL channels) |
| `nrULCarrierConfig` | UL carrier config (wraps all UL channels) |
| `nrSCSCarrierConfig` | SCS carrier: `SubcarrierSpacing`, `NSizeGrid`, `NStartGrid` |
| `nrWavegenBWPConfig` | BWP: `SubcarrierSpacing`, `NSizeBWP`, `NStartBWP` |
| `nrWavegenPDSCHConfig` | PDSCH: `Modulation`, `Power`, `DMRSPower`, `PRBSet` |
| `nrWavegenPUSCHConfig` | PUSCH: `Modulation`, `Power`, `DMRSPower` |
| `nrWavegenPUCCH0Config` .. `nrWavegenPUCCH4Config` | PUCCH formats 0–4 |
| `nrWavegenSRSConfig` | SRS config |
| `nrWavegenPDCCHConfig` | PDCCH config (links via `SearchSpaceID`) |
| `nrCORESETConfig` | CORESET: `FrequencyResources`, `Duration` |
| `nrSearchSpaceConfig` | Links PDCCH to CORESET via IDs |
| `nrWavegenSSBurstConfig` | SS burst: `BlockPattern`, `TransmittedBlocks` |
| `nrWavegenCSIRSConfig` | CSI-RS config |
| `hNRReferenceWaveformGenerator` | Standard TMs and FRCs (example helper) |
| `validateConfig` | Check structural rules (method on carrier config) |
| `openInGenerator` | Open config in 5G Waveform Generator app |

If you need to verify property names, check valid values for a config
object, or look up parameters not covered in this skill, consult the online
documentation links in [references/documentation-links.md](references/documentation-links.md).

**Do not mix API levels.** These primitive objects are incompatible with
`nrWaveformGenerator`:

| Use with `nrWaveformGenerator` | Do NOT use with `nrWaveformGenerator` |
|-------------------------------|--------------------------------------|
| `nrDLCarrierConfig` / `nrULCarrierConfig` | `nrCarrierConfig` |
| `nrWavegenPDSCHConfig` | `nrPDSCHConfig` |
| `nrWavegenPUSCHConfig` | `nrPUSCHConfig` |

## Critical Rules

These parameter constraints cause the most errors. Check all of them before
calling `nrWaveformGenerator`.

### NSizeGrid Must Match Channel Bandwidth

Look up `NSizeGrid` from the bandwidth tables. The simplified constructor
(R2026a+) handles this automatically. To look up values programmatically:

```matlab
nrDLCarrierConfig.FR1BandwidthTable
nrDLCarrierConfig.FR2BandwidthTable
```

### BWP Must Fit Within SCS Carrier

```
NStartBWP >= NStartGrid
NStartBWP + NSizeBWP <= NStartGrid + NSizeGrid
```

The BWP `SubcarrierSpacing` must exactly match one SCS carrier's
`SubcarrierSpacing`.

### CORESET Must Fit Within BWP

Each bit set to 1 in `FrequencyResources` allocates **6 RBs**. Total must
not exceed `NSizeBWP`:

```
6 * sum(FrequencyResources) <= NSizeBWP
```

Max bits to set: `floor(NSizeBWP / 6)`. For narrow bandwidths:

| NSizeBWP | Max bits | Example FrequencyResources |
|----------|----------|---------------------------|
| 11       | 1        | `[1 zeros(1,44)]` |
| 24       | 4        | `[1 1 1 1 zeros(1,41)]` |
| 51       | 8        | `[ones(1,8) zeros(1,37)]` |

### SSB Carrier Must Be at Least 20 RBs

The SCS carrier at the SSB numerology must have `NSizeGrid >= 20`.

| BlockPattern | SSB SCS |
|-------------|---------|
| Case A      | 15 kHz  |
| Case B      | 30 kHz  |
| Case C      | 30 kHz  |
| Case D      | 120 kHz |
| Case E      | 240 kHz |

**When the user does not specify SSB parameters**, choose a BlockPattern that
matches the user's SCS carrier so no extra carrier is needed:

| User's SCS | Use BlockPattern | SSB SCS |
|------------|-----------------|---------|
| 15 kHz     | Case A          | 15 kHz  |
| 30 kHz     | Case B          | 30 kHz  |
| 60 kHz     | Case B (FR1)    | 30 kHz — add a 30 kHz carrier if none exists |
| 120 kHz    | Case D          | 120 kHz |

**When the user explicitly requests SSB parameters** that require a different
SCS than the main carrier, add a dedicated SCS carrier for the SSB:

```matlab
% Example: user wants Case A (15 kHz SSB) on a 30 kHz carrier
scsSSB = nrSCSCarrierConfig;
scsSSB.SubcarrierSpacing = 15;
scsSSB.NSizeGrid = 20;        % Minimum for SSB
scsSSB.NStartGrid = 0;
cfg.SCSCarriers{end+1} = scsSSB;
cfg.SSBurst.BlockPattern = 'Case A';
```

**Disable SSBurst only** when the carrier is too narrow to support any SSB
(e.g., 5 MHz / 30 kHz → 11 RBs at 30 kHz, and no room for a 20-RB carrier
at any SSB numerology):

```matlab
cfg.SSBurst.Enable = false;
```

### Point A Centering Constrains Multi-Carrier Layouts

When multiple SCS carriers coexist, Point A is positioned so the
**highest-SCS carrier is centered** within the channel bandwidth. This means
the lower-SCS carrier may need fewer RBs than the bandwidth table maximum.
For example, 40 MHz with a full 30 kHz carrier (106 RBs) only fits 214 RBs
at 15 kHz, not the table value of 216. Always call `validateConfig(cfg)` to
check, and reduce `NSizeGrid` if needed.

### CSI-RS Must Not Conflict With Other Channels

Within the same BWP, `nrWaveformGenerator` automatically reserves REs for
CSI-RS — conflicts only arise between DM-RS and CSI-RS. Across different
BWPs that overlap in frequency, CSI-RS defaults span the full BWP and can
collide with PDSCH, PDCCH, or SSBurst. Fix with `NumRB` and `RBOffset`:

```matlab
csirs1 = nrWavegenCSIRSConfig;
csirs1.BandwidthPartID = 1;
csirs1.NumRB = 106;       % Match PDSCH1 frequency region
csirs1.RBOffset = 0;
csirs1.SymbolLocations = 6;  % Avoid PDCCH symbols 0-2
```

CSI-RS can also conflict with SSBurst when their frequency regions overlap.
This applies to any CSI-RS on any BWP — check each one. To resolve, try
these approaches in order:

1. **`NumRB`/`RBOffset`** — narrow the CSI-RS to a frequency region that
   does not overlap the SSBurst carrier (works when SSBurst does not span
   the full bandwidth)
2. **`SymbolLocations`** — move CSI-RS to symbols not used by SSBurst
3. **`CSIRSPeriod`** — adjust periodicity and slot offset so CSI-RS avoids
   slots containing SSBurst

The right fix depends on the overall parameter set. Always call
`nrWaveformGenerator` to verify no conflicts remain.

### PDCCH Conflicts With PDSCH Across BWPs or RNTIs

Within the same BWP and RNTI, `nrWaveformGenerator` automatically reserves
REs for PDCCH (via the CORESET region). PDCCH conflicts with PDSCH when:

- They are on **different overlapping BWPs**
- They have **different RNTIs** on the same BWP

To resolve, separate them in time (`SymbolAllocation`, `SlotAllocation`) or
frequency (`PRBSet`).

### PDSCH/PUSCH PRBSet Must Fit Within BWP

```
max(PRBSet) < NSizeBWP
```

For full-band allocation: `PRBSet = 0:NSizeBWP-1`.

### PDCCH Links Through SearchSpace to CORESET

`PDCCH.SearchSpaceID` must reference a valid `SearchSpace`, which must
reference a valid `CORESET` via `CORESETID`. All IDs must exist.

## Patterns

### Basic DL Waveform

```matlab
% 20 MHz, 30 kHz SCS downlink waveform with 64QAM PDSCH
cfg = nrDLCarrierConfig('FR1', 20, 30);
cfg.PDSCH{1}.Modulation = '64QAM';
cfg.NumSubframes = 10;

[waveform, info] = nrWaveformGenerator(cfg);

% Plot resource grid
figure;
imagesc(abs(info.ResourceGrids(1).ResourceGridBWP(:,:,1)));
axis xy;
xlabel('OFDM Symbols');
ylabel('Subcarriers');
title('5G NR DL Resource Grid');
colorbar;
```

### Basic UL Waveform

```matlab
% 20 MHz, 15 kHz SCS uplink waveform with QPSK PUSCH
cfg = nrULCarrierConfig('FR1', 20, 15);
cfg.PUSCH{1}.Modulation = 'QPSK';
cfg.NumSubframes = 10;

[waveform, info] = nrWaveformGenerator(cfg);
```

### Narrow Bandwidth DL (5 MHz, 30 kHz SCS)

Narrow bandwidths need manual config because CORESET defaults are too wide.
SSBurst must be disabled here because there is no SCS carrier at the SSB
numerology. (The simplified constructor avoids this by adding one automatically.)

```matlab
cfg = nrDLCarrierConfig;
cfg.ChannelBandwidth = 5;

cfg.SCSCarriers = {nrSCSCarrierConfig};
cfg.SCSCarriers{1}.SubcarrierSpacing = 30;
cfg.SCSCarriers{1}.NSizeGrid = 11;   % 5 MHz at 30 kHz

cfg.BandwidthParts = {nrWavegenBWPConfig};
cfg.BandwidthParts{1}.SubcarrierSpacing = 30;
cfg.BandwidthParts{1}.NSizeBWP = 11;

% SSB needs 20 RBs — disable for 11-RB carrier
cfg.SSBurst.Enable = false;

% CORESET: max 1 group (6 RBs) for 11-RB BWP
cfg.CORESET{1}.FrequencyResources = [1 zeros(1,44)];
cfg.CORESET{1}.Duration = 2;  % Must be 2 for interleaved mapping with 1 group
cfg.PDCCH{1}.Enable = false;  % Only 2 CCEs — too few for default AggregationLevel

% PDSCH: fit within BWP
cfg.PDSCH{1}.PRBSet = 0:10;
cfg.PDSCH{1}.Power = -3;
cfg.PDSCH{1}.DMRSPower = -6;

[waveform, info] = nrWaveformGenerator(cfg);
```

### Test Model Waveform

```matlab
% NR-FR1-TM1.1 at 10 MHz, 15 kHz SCS
wavegen = hNRReferenceWaveformGenerator('NR-FR1-TM1.1', '10MHz', '15kHz', 'FDD');
[waveform, waveinfo] = generateWaveform(wavegen);
displayResourceGrid(wavegen);
```

To modify test model parameters (e.g., enable transport coding):

```matlab
wavegen = makeConfigWritable(wavegen);
pdschArray = [wavegen.Config.PDSCH{:}];
[pdschArray.Coding] = deal(true);
wavegen.Config.PDSCH = num2cell(pdschArray);
[waveform, waveinfo] = generateWaveform(wavegen);
```

### Multi-BWP Waveform

For waveforms with multiple bandwidth parts and numerologies, see
[references/multi-bwp-guidance.md](references/multi-bwp-guidance.md).

## Output Structure

`[waveform, info] = nrWaveformGenerator(cfg)` returns:

| Field | Contents |
|-------|----------|
| `waveform` | Complex time-domain samples (N x P, P = antennas) |
| `info.ResourceGrids(k).ResourceGridBWP` | Grid sized to BWP (NSizeBWP*12 subcarriers) |
| `info.ResourceGrids(k).ResourceGridInCarrier` | Grid sized to full carrier |
| `info.ResourceGrids(k).Info.SampleRate` | Waveform sample rate |
| `info.ResourceGridSSBurst.ResourceGrid` | SSB grid (DL only) |
| `info.WaveformResources.PDSCH` | Per-slot PDSCH resources (indices, symbols) |

**There is no field called `ResourceGrid` in `info.ResourceGrids`.** Use
`ResourceGridBWP` or `ResourceGridInCarrier`.

`[waveform, waveinfo] = generateWaveform(wavegen)` for
`hNRReferenceWaveformGenerator` returns:

| Field | Contents |
|-------|----------|
| `waveinfo.ResourceGridBWP` | Resource grid |
| `waveinfo.Info.SampleRate` | Sample rate |

## Conventions

- **After generating a waveform**, unless the user asks for something specific:
  1. Tell the user the waveform variable name and that it is in the workspace
  2. Plot the resource grid
  3. Save the generation code as a `.m` script and open it in the MATLAB editor with `edit('scriptName.m')`
- Use `nrWaveformGenerator`, not primitive functions (`nrPDSCH` + `nrOFDMModulate`)
- Start with the simplified constructor `nrDLCarrierConfig('FR1', bw, scs)` when possible
- Use `nrWavegenPDSCHConfig` (not `nrPDSCHConfig`) with `nrWaveformGenerator`
- **Correct property names:** `DMRSPower` (not PowerDMRS), `PTRSPower` (not PowerPTRS), `NSizeGrid` (not NRB), `ChannelBandwidth` (not Bandwidth)
- `SCSCarriers`, `BandwidthParts`, `CORESET`, `PDSCH`, `PUSCH` are **cell arrays** — use `{}`
- `SSBurst` is a **direct object** — use `.` not `{}`
- Use `tiledlayout`/`nexttile` for multi-panel figures
- Always label axes with units and include figure titles

Copyright 2026 The MathWorks, Inc.
