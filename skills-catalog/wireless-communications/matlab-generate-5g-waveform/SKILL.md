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
metadata:
  author: MathWorks
  version: "1.1"
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

## When Not to Use

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

**Do not use primitive-level functions** (`nrCarrierConfig` + `nrPDSCH` +
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

2. **Customize channels** — set only the properties the task requires; never restate
   a default (`NumSubframes = 10`, `Modulation = 'QPSK'`, `Enable = true`, `RNTI = 1`).
   Worse, never *overwrite* a constructor-placed value with a **different** one (e.g.
   forcing a BWP's `NStartBWP` to 0 when the constructor centered it at 1) — that breaks
   the validated layout. Exception: a value the user asked for — write it with a comment.

```matlab
cfg.PDSCH{1}.Modulation = '64QAM';       % non-default (the default is QPSK)
cfg.NumSubframes = 20;                    % 20 subframes = 20 ms; the default is 10
```

`Power` and `DMRSPower` (dB) are optional. `DMRSPower` is DM-RS power relative to data
REs; per TS 38.214 Table 4.1-1 it is boosted 0, 3, or 4.77 dB for 1, 2, or 3 CDM groups
without data. On R2026b+, `DMRSPower = []` applies this automatically.

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

Then generate. Pass only the arguments the task specifies — trailing arguments
(duplex mode, cell identity) default to `'FDD'` and `1`; omit them unless the
task requires a specific value:

```matlab
% Model, bandwidth, and SCS only — duplex mode defaults to 'FDD', ncellid to 1
wavegen = hNRReferenceWaveformGenerator('NR-FR1-TM1.1', '10MHz', '15kHz');
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
| `nrWavegenPDSCHConfig` | PDSCH: `Modulation`, `Power`, `DMRSPower` (see DM-RS power note), `PRBSet` |
| `nrWavegenPUSCHConfig` | PUSCH: `Modulation`, `Power`, `DMRSPower` (see DM-RS power note) |
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

| Use with `nrWaveformGenerator` | Do not use with `nrWaveformGenerator` |
|-------------------------------|--------------------------------------|
| `nrDLCarrierConfig` / `nrULCarrierConfig` | `nrCarrierConfig` |
| `nrWavegenPDSCHConfig` | `nrPDSCHConfig` |
| `nrWavegenPUSCHConfig` | `nrPUSCHConfig` |

## Critical Rules

These parameter constraints cause the most errors. Check all of them before
calling `nrWaveformGenerator`.

### Set Only What the Task Requires

Configure the minimum set of properties. Do **not** restate a value the
constructor or object already holds (`RNTI = 1`, `NumLayers = 1`,
`CyclicPrefix = 'normal'`, `BlockPattern = 'Case A'`, a `BandwidthPartID` or
`RBOffset` equal to its default, an `NStartGrid`/`NStartBWP` the constructor
set). Do **not** set cosmetic or auto fields (`Label`, `NCellID`,
`WindowingPercent`, an explicit `SampleRate = []`). Do **not** set `Modulation`,
DM-RS, or `NumLayers` unless the prompt names them. Enabling a component the
prompt asks for (`CSIRS.Enable = true`, `SSBurst.Enable = true`) **is** required
— that is not over-config. A comment explaining a default is fine; assigning it
is not.

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
matches the user's SCS carrier so no extra carrier is needed: 15 kHz → Case A,
30 kHz → Case B, 60 kHz → Case B (FR1; add a 30 kHz carrier if none exists),
120 kHz → Case D.

**When the user explicitly requests SSB parameters** that require a different
SCS than the main carrier, add a dedicated SCS carrier for the SSB:

```matlab
% Example: user wants Case A (15 kHz SSB) on a 30 kHz carrier
scsSSB = nrSCSCarrierConfig;
scsSSB.SubcarrierSpacing = 15;
scsSSB.NSizeGrid = 20;        % Minimum for SSB
cfg.SCSCarriers{end+1} = scsSSB;
cfg.SSBurst.BlockPattern = 'Case A';
```

**Disable SSBurst** (`cfg.SSBurst.Enable = false`) only when the carrier is too
narrow to support any SSB (e.g., 5 MHz / 30 kHz → 11 RBs at 30 kHz, no room for
a 20-RB carrier at any SSB numerology).

### Point A Centering Constrains Multi-Carrier Layouts

When multiple SCS carriers coexist, Point A is positioned so the
**highest-SCS carrier is centered** within the channel bandwidth, so the
lower-SCS carrier may need fewer RBs than the bandwidth table maximum (e.g.
40 MHz with a full 30 kHz carrier of 106 RBs fits only 214 RBs at 15 kHz, not
the table's 216). Call `validateConfig(cfg)` and reduce `NSizeGrid` if needed.

### CSI-RS Must Not Conflict With Other Channels

Within the same BWP, `nrWaveformGenerator` automatically reserves REs for
CSI-RS — conflicts only arise between DM-RS and CSI-RS. Across different
BWPs that overlap in frequency, CSI-RS defaults span the full BWP and can
collide with PDSCH, PDCCH, or SSBurst. Fix with `NumRB` and `RBOffset`:

```matlab
csirs1 = nrWavegenCSIRSConfig;   % targets BWP 1 (BandwidthPartID default 1 — don't restate it)
csirs1.NumRB = 106;       % Match PDSCH1 frequency region
csirs1.RBOffset = 0;
csirs1.SymbolLocations = 6;  % Avoid PDCCH symbols 0-2

csirs2 = nrWavegenCSIRSConfig;
csirs2.BandwidthPartID = 2;  % Set BandwidthPartID only where it differs from the default 1
```

The CSI-RS/SSBurst clash is **wider than it looks**: across different SCS (SSBurst
Case A 15 kHz vs CSI-RS on a 30 kHz BWP) one SSB symbol maps to several on the CSI-RS
grid, so a small SSB footprint forbids a broad band and a mid-slot guess (e.g. 8) lands
inside it. Check every CSI-RS on any BWP; resolve in order, then **re-run
`nrWaveformGenerator` to confirm clean**: (1) **`CSIRSPeriod`** *(most robust)* — steer
CSI-RS to a slot the SSBurst skips (`CSIRSPeriod = [10 1]`), any numerology; (2)
**`NumRB`/`RBOffset`** — a region clear of the SSBurst carrier; (3) **`SymbolLocations`**
*(last resort)* — place at the slot **end** (`13`/`12`), never mid-slot.

### PDCCH Conflicts With PDSCH Across BWPs or RNTIs

Within the same BWP and RNTI, `nrWaveformGenerator` automatically reserves
REs for PDCCH (via the CORESET region). PDCCH conflicts with PDSCH when:

- They are on **different overlapping BWPs**
- They have **different RNTIs** on the same BWP

To resolve, separate them in time (`SymbolAllocation`, `SlotAllocation`) or
frequency (`PRBSet`).

### PDSCH/PUSCH PRBSet Must Fit Within BWP

Every RB in `PRBSet` must lie inside the BWP:

```
max(PRBSet) < NSizeBWP
```

**Always set `PRBSet` explicitly to fit the BWP** — `PRBSet = 0:NSizeBWP-1` for
full-band. An over-range `PRBSet` is invalid, and the reaction is
release-dependent (through R2026a it errors; R2026b silently clips), so rely on
neither. The default `0:51` overflows any BWP under 52 RBs (e.g. an 11-RB 5 MHz /
30 kHz carrier). `PRBSet` sets frequency allocation only — waveform length is
fixed by bandwidth, SCS, and `NumSubframes`.

### PDCCH Links Through SearchSpace to CORESET

`PDCCH.SearchSpaceID` must reference a valid `SearchSpace`, which must
reference a valid `CORESET` via `CORESETID`. All IDs must exist.

## Patterns

### Basic DL Waveform

```matlab
% 20 MHz, 30 kHz SCS downlink waveform with 64QAM PDSCH
cfg = nrDLCarrierConfig('FR1', 20, 30);
cfg.PDSCH{1}.Modulation = '64QAM';       % non-default (the default is QPSK)

[waveform, info] = nrWaveformGenerator(cfg);

% Plot resource grid. SSBurst (enabled by default) lives in a SEPARATE
% grid, so plot both the BWP data grid and the SS burst.
figure; tiledlayout(1,2);
nexttile; imagesc(abs(info.ResourceGrids(1).ResourceGridBWP(:,:,1)));
axis xy; xlabel('OFDM Symbols'); ylabel('Subcarriers'); title('DL Resource Grid (BWP)'); colorbar;
nexttile; imagesc(abs(info.ResourceGridSSBurst.ResourceGrid(:,:,1)));
axis xy; xlabel('OFDM Symbols'); ylabel('Subcarriers'); title('SS Burst Grid'); colorbar;
```

### Basic UL Waveform

```matlab
% 20 MHz, 15 kHz SCS uplink waveform with QPSK PUSCH
cfg = nrULCarrierConfig('FR1', 20, 15);
cfg.PUSCH{1}.Modulation = 'QPSK';         % explicit per request (also the default)

[waveform, info] = nrWaveformGenerator(cfg);
```

### Plot the Power Spectrum

For the power spectrum (rather than the resource grid), pass the waveform and
its sample rate to `pspectrum` — `sr` puts the frequency axis in real Hz:

```matlab
sr = info.ResourceGrids(1).Info.SampleRate;
figure;
pspectrum(waveform(:,1), sr);   % first antenna; sr -> Hz frequency axis
title('5G NR Waveform Power Spectrum');
```

`spectrumAnalyzer` and `pwelch` also work; all need the sample rate.

### Narrow Bandwidth DL (11-RB carriers: 5 MHz/30 kHz, 10 MHz/60 kHz)

Common configs like 5 MHz/30 kHz and 10 MHz/60 kHz resolve to just **11 RBs**
(TS 38.104) — too narrow for the default CORESET and a >=20-RB SSB carrier, so
the defaults fail on generation.

**On R2026a+, prefer the simplified constructor** — it right-sizes the SSB
carrier, BlockPattern, and CORESET automatically:

```matlab
cfg = nrDLCarrierConfig('FR1', 5, 30);    % R2026a+; auto-adds a 15 kHz SSB carrier
% cfg = nrDLCarrierConfig('FR1', 10, 60); % likewise: auto-adds a 30 kHz Case B SSB carrier
[waveform, info] = nrWaveformGenerator(cfg);
```

**On the manual path, three defaults fail on an 11-RB carrier** (all fixed below):
`SSBurst` Case A/15 kHz needs a 15 kHz carrier (disable it, or add an SSB carrier +
`Case B` at 60 kHz); CORESET `FrequencyResources` (~48 RB) overflows (shrink to `1`);
PDCCH `AggregationLevel = 8` needs 8 CCEs, a 1-group CORESET gives 2 (use AL1/AL2).

**Use the manual pattern below** on pre-R2026a releases, or to keep a
single-SCS-carrier layout (no auto-added SSB carrier):

```matlab
cfg = nrDLCarrierConfig;
cfg.ChannelBandwidth = 5;

% 5 MHz at 30 kHz -> 11 RBs (TS 38.104 bandwidth table)
cfg.SCSCarriers{1}.SubcarrierSpacing = 30;
cfg.SCSCarriers{1}.NSizeGrid = 11;

% BWP matches the SCS carrier (link the values so they can't drift apart)
cfg.BandwidthParts{1}.SubcarrierSpacing = cfg.SCSCarriers{1}.SubcarrierSpacing;
cfg.BandwidthParts{1}.NSizeBWP = cfg.SCSCarriers{1}.NSizeGrid;

cfg.SSBurst.Enable = false;   % no 20-RB SSB carrier fits in 11 RBs

% CORESET: 6 RBs per set bit; 1 group (6 RBs) is the max that fits 11 RBs.
% Keep Duration at its default 2 — a 1-group CORESET fails at Duration 1.
cfg.CORESET{1}.FrequencyResources = 1;

% Keep a working PDCCH in the narrow band: AggregationLevel 1 (1 CCE) fits.
cfg.SearchSpaces{1}.NumCandidates = [8 0 0 0 0];   % candidates only at AL1
cfg.PDCCH{1}.AggregationLevel = 1;                 % or cfg.PDCCH{1}.Enable = false

% PDSCH: fill the BWP. Required — the default 0:51 is invalid for 11 RBs
% (errors through R2026a, silently clips in R2026b), so set it by hand.
cfg.PDSCH{1}.PRBSet = 0:cfg.BandwidthParts{1}.NSizeBWP-1;

[waveform, info] = nrWaveformGenerator(cfg);
```

### Test Model Waveform

```matlab
% NR-FR1-TM1.1 at 10 MHz, 15 kHz SCS
% Only the requested arguments; duplex mode defaults to 'FDD', ncellid to 1
wavegen = hNRReferenceWaveformGenerator('NR-FR1-TM1.1', '10MHz', '15kHz');
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
  2. Plot the resource grid from `info.ResourceGrids(k).ResourceGridBWP` (BWP-sized, one per BWP); use `ResourceGridInCarrier` only for a full-carrier view. The SS burst is a **separate grid** — when `SSBurst.Enable` is true and the SS burst is asked for, also plot `info.ResourceGridSSBurst.ResourceGrid` (it is not part of `ResourceGridBWP`)
  3. Save the generation code as a `.m` script and open it in the MATLAB editor with `edit('scriptName.m')`
- Use `nrWaveformGenerator`, not primitive functions (`nrPDSCH` + `nrOFDMModulate`)
- Start with the simplified constructor `nrDLCarrierConfig('FR1', bw, scs)` when possible
- Use `nrWavegenPDSCHConfig` (not `nrPDSCHConfig`) with `nrWaveformGenerator`
- **Correct property names:** `DMRSPower` (not PowerDMRS), `PTRSPower` (not PowerPTRS), `NSizeGrid` (not NRB), `ChannelBandwidth` (not Bandwidth)
- `SCSCarriers`, `BandwidthParts`, `CORESET`, `PDSCH`, `PUSCH` are **cell arrays** — use `{}`
- `SSBurst` is a **direct object** — use `.` not `{}`
- Use `tiledlayout`/`nexttile` for multi-panel figures
- Always label axes with units and include figure titles
- Comment non-obvious, interdependent choices (why a given `NSizeGrid`, why SSBurst is disabled, why a specific `AggregationLevel`) so the code explains itself

Copyright 2026 The MathWorks, Inc.
