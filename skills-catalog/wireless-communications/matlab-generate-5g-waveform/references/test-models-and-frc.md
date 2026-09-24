# Test Models and Fixed Reference Channels

Use `hNRReferenceWaveformGenerator` to generate standard-defined NR test model
(TM) and fixed reference channel (FRC) waveforms. This is an example helper
shipped with 5G Toolbox (see the
[5G NR TM Waveform Generation](https://mathworks.com/help/5g/ug/5g-nr-tm-waveform-generation.html)
example).

## Basic Usage

```matlab
wavegen = hNRReferenceWaveformGenerator(RC, BW, SCS, DM, NCELLID);
[waveform, waveinfo] = generateWaveform(wavegen);
```

| Argument | Description | Default |
|----------|-------------|---------|
| `RC` | Reference channel identifier (see tables below) | Required |
| `BW` | Channel bandwidth: `'10MHz'`, `10`, or `"10MHz"` | 10 MHz (FR1), 100 MHz (FR2) |
| `SCS` | Subcarrier spacing: `'15kHz'`, `15`, or `"15kHz"` | 15 kHz (FR1), 120 kHz (FR2) |
| `DM` | Duplex mode: `'FDD'` or `'TDD'` | FDD (FR1), TDD (FR2) |
| `NCELLID` | Physical cell ID | 1 (DL), 0 (UL) |

The BW and SCS combination must be valid per the bandwidth table.

`RC`, `BW`, and `SCS` are the arguments you normally supply. `DM` and
`NCELLID` are optional — pass them only when the task specifies a particular
duplex mode or cell ID. Restating their defaults (`'FDD'`, `1`) adds nothing:

```matlab
% Requested: model, bandwidth, SCS only
wavegen = hNRReferenceWaveformGenerator('NR-FR1-TM1.1', '10MHz', '15kHz');
```

## Valid FR1 Test Models

| Identifier | Description |
|-----------|-------------|
| `'NR-FR1-TM1.1'` | Full-band QPSK, single PDSCH |
| `'NR-FR1-TM1.2'` | Full-band QPSK with boosted/deboosted PRBs |
| `'NR-FR1-TM2'` | Full-band 64QAM |
| `'NR-FR1-TM2a'` | Full-band 256QAM |
| `'NR-FR1-TM2b'` | Full-band 1024QAM |
| `'NR-FR1-TM3.1'` | Partial-band 16QAM |
| `'NR-FR1-TM3.1a'` | Partial-band 16QAM, variant |
| `'NR-FR1-TM3.1b'` | Partial-band 16QAM, variant |
| `'NR-FR1-TM3.2'` | Partial-band 16QAM/QPSK |
| `'NR-FR1-TM3.3'` | Partial-band QPSK |

## Valid FR2 Test Models

| Identifier | Description |
|-----------|-------------|
| `'NR-FR2-TM1.1'` | Full-band QPSK |
| `'NR-FR2-TM2'` | Full-band 64QAM |
| `'NR-FR2-TM2a'` | Full-band 256QAM |
| `'NR-FR2-TM3.1'` | Partial-band 16QAM |
| `'NR-FR2-TM3.1a'` | Partial-band 16QAM, variant |

## Valid DL Fixed Reference Channels

**FR1:** `'DL-FRC-FR1-QPSK'`, `'DL-FRC-FR1-64QAM'`, `'DL-FRC-FR1-256QAM'`,
`'DL-FRC-FR1-1024QAM'`

**FR2:** `'DL-FRC-FR2-QPSK'`, `'DL-FRC-FR2-16QAM'`, `'DL-FRC-FR2-64QAM'`,
`'DL-FRC-FR2-256QAM'`

## Valid UL Fixed Reference Channels

**FR1:** `'G-FR1-Ax-y'` format, where x = 1-5 and y varies. Examples:
`'G-FR1-A1-1'` through `'G-FR1-A5-14'`. Full list available via:

```matlab
hNRReferenceWaveformGenerator.FR1UplinkFRC
```

**FR2:** `'G-FR2-Ax-y'` format. Full list:

```matlab
hNRReferenceWaveformGenerator.FR2UplinkFRC
```

## Visualizing the Resource Grid

```matlab
displayResourceGrid(wavegen);
```

## Modifying Test Model Parameters

The `Config` property is read-only by default. To customize:

```matlab
wavegen = makeConfigWritable(wavegen);

% Example: enable transport coding on all PDSCHs
pdschArray = [wavegen.Config.PDSCH{:}];
[pdschArray.Coding] = deal(true);
wavegen.Config.PDSCH = num2cell(pdschArray);

[waveform, waveinfo] = generateWaveform(wavegen);
```

The `Config` property is an `nrDLCarrierConfig` or `nrULCarrierConfig` object,
so all the same customization patterns apply.

## Output Structure

```matlab
[waveform, waveinfo] = generateWaveform(wavegen);
```

| Field | Contents |
|-------|----------|
| `waveinfo.ResourceGridBWP` | Resource grid (subcarriers x symbols) |
| `waveinfo.Info.SampleRate` | Waveform sample rate |
| `waveinfo.Info.Nfft` | FFT size |

## Common Mistakes

- **Wrong model name format:** Use `'NR-FR1-TM1.1'` not `'FR1-TM1.1'` or
  `'TM1.1'`. The `NR-` prefix is required.
- **Function does not exist:** If `hNRReferenceWaveformGenerator` is not found,
  open the example first:
  [5G NR TM Waveform Generation](https://mathworks.com/help/5g/ug/5g-nr-tm-waveform-generation.html).
  This adds the helper to the MATLAB path.
- **Hallucinated alternatives:** `nrTMWaveformGenerator`, `h5gNRTMConfig`,
  `nrTestModel`, `nrRMCDL` do **not exist**. Only
  `hNRReferenceWaveformGenerator` is available.

Copyright 2026 The MathWorks, Inc.
