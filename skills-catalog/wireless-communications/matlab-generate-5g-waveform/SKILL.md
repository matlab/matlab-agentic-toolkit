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
  version: "1.3"
---

# Generate 5G NR Waveforms

Generate standard-compliant 5G NR downlink and uplink waveforms for test and
measurement, simulation, and verification using `nrWaveformGenerator`.

## When to Use

- Generate a 5G, NR, or New Radio waveform (DL: PDSCH, PDCCH, SSBurst, CSI-RS;
  UL: PUSCH, PUCCH, SRS)
- Generate NR test model (TM) or fixed reference channel (FRC) waveforms
- Configure bandwidth, SCS, modulation, power, or multi-bandwidth-part layouts

## When Not to Use

- Channel modeling or propagation — use `nrCDLChannel`, `nrTDLChannel`
- Receiver processing or decoding — use `nrPDSCHDecode`, `nrDLSCHDecoder`
- Link-level simulation end-to-end
- 6G / pre-6G waveforms (`pre6G*`) and 5G or 6G ISAC (sensing with a 5G waveform, TR 38.901 ISAC channel) — use `matlab-simulate-6g-system`

## API Choice

| Need | API |
|------|-----|
| Custom DL waveform | `nrDLCarrierConfig` + `nrWaveformGenerator` |
| Custom UL waveform | `nrULCarrierConfig` + `nrWaveformGenerator` |
| Standard test model (TM) or FRC | `hNRReferenceWaveformGenerator` |

**Do not use primitive-level functions** (`nrCarrierConfig` + `nrPDSCH` +
`nrOFDMModulate`) for waveform generation, and do not mix primitive config
objects (`nrPDSCHConfig`, `nrPUSCHConfig`, `nrCarrierConfig`) with
`nrWaveformGenerator` — use the `nrWavegen*` objects. `nrWaveformGenerator`
handles channel multiplexing, power scaling, and OFDM modulation correctly.
Full function catalog, property names, and the incompatible-object table:
[references/api-reference.md](references/api-reference.md).

## Core Workflow (custom DL/UL)

1. **Create the carrier config** with the simplified constructor (R2026a+),
   which auto-sizes SCSCarriers, BandwidthParts, SSBurst/CORESET (DL), and a
   default PDSCH/PUSCH to the bandwidth:

```matlab
cfg = nrDLCarrierConfig('FR1', 20, 30);  % DL: FR1, 20 MHz, 30 kHz SCS
cfg = nrULCarrierConfig('FR1', 20, 15);  % UL: FR1, 20 MHz, 15 kHz SCS
```

For DL, if the requested SCS differs from the default SSB numerology the
constructor adds a dedicated SSB SCS carrier (e.g. `nrDLCarrierConfig('FR1', 5, 30)`
adds a hidden 15 kHz carrier). Pre-R2026a, or to control the SCS-carrier count
exactly, build manually with `nrDLCarrierConfig` (no args).

2. **Customize only what the task requires** (see the rule below). Set
   non-defaults such as `cfg.PDSCH{1}.Modulation = '64QAM';`. Never *overwrite* a
   constructor-placed value with a different one (e.g. forcing `NStartBWP = 0`
   when the constructor centered it) — that breaks the validated layout.

3. **Generate** — `validateConfig` checks structural rules but does **not**
   catch channel conflicts (overlapping PDSCH/CSI-RS, CSI-RS/SSBurst); always
   run the generator, which returns the waveform and the resource-grid info:

```matlab
[waveform, info] = nrWaveformGenerator(cfg);
```

**What the simplified constructor builds is generation-ready as-is** — an
unedited `nrDLCarrierConfig(fr, bw, scs)` or `nrULCarrierConfig(fr, bw, scs)`
generates for every FR1/FR2 bandwidth/SCS combination, so do not re-check what
it set. This does **not** apply to the no-argument `nrDLCarrierConfig` /
`nrULCarrierConfig`, whose defaults (15 kHz, Case A SSB, 52-RB `PRBSet`) must be
resized by hand. One silent caveat: at **3 MHz / 15 kHz** the SSB is wider than
the 15-RB carrier, so the PBCH is punctured — this is expected; keep the SSB
(details in Critical Rules). Check the [Critical Rules](references/critical-rules.md) for
whatever you **change or build by hand**: a no-argument (manual) carrier, an
edited `NSizeGrid`/BWP/CORESET/`PRBSet`, a `BlockPattern` override, an added SCS
carrier or BWP (Point A centering), CSI-RS or PDCCH across BWPs, or 2 codewords
(layers/DM-RS). Those edits cause the most generation failures.

## Set Only What the Task Requires

Set every property the task requires — including parameters **forced** by a
requested feature, even when the prompt never names them — and nothing else. For
example, 2 codewords → `NumLayers` 5–8 → a DM-RS that supports more than 4 ports
(see [Critical Rules](references/critical-rules.md)); a requested CSI-RS →
`CSIRS{1}.Enable = true` (off by default). These are required, not over-config.
`SSBurst` is already enabled by default, so a requested SS burst needs no
`Enable` line.

## Recipes and References

Open the reference that matches the task; each has copy-ready, verified code:

- **Common single-carrier waveforms** (Basic DL with dual-grid plot, Basic UL,
  power spectrum): [references/patterns.md](references/patterns.md)
- **Narrow-band 11-RB carriers, manual build only** (5 MHz/30 kHz, 10 MHz/60 kHz).
  The simplified constructor already handles these — skip this reference when you
  use it. Open it only for a no-argument build (pre-R2026a, or to avoid the
  auto-added SSB carrier), where the defaults fail and need `NSizeGrid = 11`, a
  disabled/rehomed SSB, a shrunk CORESET, AL1, and an explicit `PRBSet`:
  [references/narrow-band-manual-config.md](references/narrow-band-manual-config.md)
- **Multi-BWP / multi-numerology** layouts:
  [references/multi-bwp-guidance.md](references/multi-bwp-guidance.md)
- **Test models (TM) and fixed reference channels (FRC)** — use the example
  helper `hNRReferenceWaveformGenerator(RC, BW, SCS)` (e.g. `'DL-FRC-FR1-64QAM'`,
  `'NR-FR1-TM1.1'`), then `generateWaveform` + `displayResourceGrid`. It is **not
  on the path by default**: first make it available with a **portable** setup
  (`setupExample('5g/NRTestModelWaveformGenerationExample', ...)` + `copyfile` +
  `cd`, or `openExample`) — never a hardcoded path, never a made-up namespaced
  name. Valid names, portable-setup block, and `makeConfigWritable` edits:
  [references/test-models-and-frc.md](references/test-models-and-frc.md)
- **Full API catalog + output structure** (fields of `info`, correct property
  names): [references/api-reference.md](references/api-reference.md)
- **Online documentation links**:
  [references/documentation-links.md](references/documentation-links.md)

## Conventions

- **After generating a waveform**, unless the user asks for something specific:
  1. Tell the user the waveform variable name and that it is in the workspace
  2. Plot the resource grid from `info.ResourceGrids(k).ResourceGridBWP` (BWP-sized, one per BWP); use `ResourceGridInCarrier` only for a full-carrier view. The SS burst is a **separate grid** — when `SSBurst.Enable` is true and the SS burst is asked for, also plot `info.ResourceGridSSBurst.ResourceGrid` (it is not part of `ResourceGridBWP`)
  3. Save the generation code as a `.m` script and open it in the MATLAB editor with `edit('scriptName.m')`
- Start with the simplified constructor `nrDLCarrierConfig('FR1', bw, scs)` when possible
- **Correct property names:** `DMRSPower` (not PowerDMRS), `PTRSPower` (not PowerPTRS), `NSizeGrid` (not NRB), `ChannelBandwidth` (not Bandwidth)
- `SCSCarriers`, `BandwidthParts`, `CORESET`, `PDSCH`, `PUSCH` are **cell arrays** — use `{}`; `SSBurst` is a **direct object** — use `.` not `{}`
- Use `tiledlayout`/`nexttile` for multi-panel figures; always label axes with units and include figure titles
- Comment non-obvious, interdependent choices (why a given `NSizeGrid`, why SSBurst is disabled, why a specific `AggregationLevel`) so the code explains itself

Copyright 2026 The MathWorks, Inc.
