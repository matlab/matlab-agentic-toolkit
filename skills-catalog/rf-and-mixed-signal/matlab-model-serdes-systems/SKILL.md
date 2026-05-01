---
name: matlab-model-serdes-systems
description: >
  Model, simulate, and optimize Serializer/Deserializer (SerDes) systems — serial and parallel links — using MATLAB SerDes Toolbox.
  Design NRZ and PAM-N links (PAM3 through PAM16) — explore equalization architectures
  (FFE, CTLE, DFE), sweep or optimize parameters with genetic algorithms, and characterize
  channels from loss models, S-parameter files, or crosstalk scenarios. Process captured
  waveforms through equalization chains, build eye diagrams, and decompose jitter. Deliver
  IBIS-AMI models for Tx, Rx, Redriver, or Retimer by exporting to Simulink and compiling
  .ami/.ibs/.dll/.so files. Covers the full arc from initial design exploration and parameter
  optimization to compliance testing and compiled model validation, including custom datapath blocks for nonstandard equalization.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Modeling and Simulating SerDes Systems

Design, analyze, and deliver high-speed serial link models using SerDes Toolbox. From
architecture exploration through IBIS-AMI model generation, covers the full workflow
for NRZ and PAM-N links (PAM3 through PAM16).

## When to Use

**System design and architecture exploration**
- Designing SerDes links for a target data rate, signaling scheme (NRZ, PAM4, PAM-N), and channel loss
- Evaluating equalization architectures (FFE, CTLE, DFE) and optimizing tap settings
- Sweeping design parameters to find optimal configurations
- Using industry reference designs (PCIe, USB4, DDR5, CEI, UCIe) as starting points
- Characterizing Tx/Rx analog effects (parasitic capacitance, rise time, termination impedance)
- Building custom datapath blocks for nonstandard equalization

**Channel modeling and characterization**
- Loading S-parameter Touchstone files into SerdesSystem
- Modeling channels with loss profiles, crosstalk (FEXT/NEXT), and aggressors
- Fitting CTLE transfer functions from measured data via `ctlefit`

**IBIS-AMI model generation**
- Building IBIS-AMI models for Tx, Rx, Redriver, or Retimer configurations
- Exporting to Simulink, configuring AMI parameters, and compiling `.ami`/`.ibs`/`.dll`/`.so`
- Scripting Simulink simulations and parameter sweeps with `sim`/`parsim`

**Analysis and validation**
- Running statistical and time-domain simulations
- Processing eye diagrams (eye height, eye width, COM, VEC, bathtub curves)
- Decomposing jitter (TJ, RJ, DJ, DDJ, DCD, ISI)
- Validating compiled AMI models against behavioral baselines
- Running compliance checks with eye masks and jitter budgets

## When NOT to Use

- RF/microwave circuit design, antenna modeling, or baseband DSP filter design
- General Simulink model scripting unrelated to SerDes

## Must-Follow Rules

### System Setup
- **SymbolTime / SampleInterval must yield an integer SamplesPerSymbol** — fractional ratios cause silent errors
- **`TxModel`/`RxModel` are `Transmitter`/`Receiver` objects** — not cell arrays. Construct with `Transmitter('Blocks', {block1, block2})`. **`Transmitter` requires single-quoted property names** — `Transmitter("Blocks", ...)` throws an `ismember` error. `Receiver` and all other classes accept double quotes
- **Signal conversion functions require column vectors** — `impulse2pulse`, `pulse2stateye`, etc. error on row vectors
- **Include `AnalogModel` and `JitterAndNoise`** for realistic results — bare `Transmitter`/`Receiver` without analog models produce optimistic COM (1-2 dB higher). See `reference/equalization-tuning.md` for parameter guidance (rise time, parasitic C, termination R)

### Equalization
- **Set `WaveType` explicitly** when using datapath blocks directly in MATLAB — Simulink sets this automatically, but MATLAB defaults to `"Sample"`
- **Adapted DFE/CTLE parameters are in `results.outparams`** — NOT on the block object. After `analysis()`, `sys.RxModel.Blocks{k}.TapWeights` still holds initial values. In system objects chains, adapted taps are the **second output**: `[y, taps] = dfecdr(x)`
- **DFECDR Mode=0 is passthrough in Sample mode** — DFE only applies with Mode≥1. Pre-load adapted taps from `outparams` with Mode=1 for instant convergence, or use Mode=2 with 10x `EqualizationGain` (9.6e-04) for self-converging chains
- **Set `Modulation` on DFECDR for PAM-N** in system objects chains — Simulink inherits it from the model workspace, but MATLAB defaults to 2 (NRZ). Without this, PAM4 DFE adaptation fails silently

### Metrics and Waveforms
- **`Metrics.summary.EW` is in picoseconds** (already scaled) — do NOT multiply by 1e12. `EH` is in volts. PAM-N returns N-1 values per metric (e.g., PAM4 → 3 eyes, PAM8 → 7 eyes)
- **Channel impulse from `analysis()` is in V/s** — when using `filter()` for time-domain convolution, multiply by `dt`: `filter(impulse * dt, 1, wave)`. Without scaling, amplitudes blow up by ~10^11
- **`pulse2wave` operates on the stimulus provided** — the output modulation depends on the input pattern (NRZ or PAM-N)

### AMI and Simulink
- **Init-Only models cannot adapt** — if DFE taps or CDR converge at runtime, you need a Dual model (both Init and GetWave)
- **AMI validation requires Signal Integrity Toolbox** — `serdes.AMI` runner and the AMI Simulink block need both SerDes Toolbox and Signal Integrity Toolbox
- **AMI GetWave: call in a chunked loop** — `serdes.AMI` passes `BlockSize` (default 1024) to `AMI_GetWave`, so only `BlockSize` samples are processed per call. You **must** call the object in a `for` loop with `BlockSize`-length chunks. State is preserved between calls via the DLL memory handle
- **AMI GetWave: set `SkipFirstBlock = false`** when calling from MATLAB — the default (`true`) is for Simulink's internal signal buffering and causes the first block to pass through unprocessed
- **AMI Init: `RowSize` must match impulse length** — `serdes.AMI` crashes MATLAB (process termination, no error) if `RowSize` doesn't match `numel(impulse)`
- **AMI generation requires Simulink model** — use `IbisAmiManager` GUI or `serdes.AMIExport` with `export()` programmatically (see Programmatic AMI Generation)

## Workflow

### Design Exploration

Most projects start here. The goal is to find the right equalization architecture and settings for your channel.

1. **Design** — Create a `SerdesSystem` with Tx/Rx blocks and channel (loss model or S-parameters)
2. **Analyze** — Run `analysis` for statistical results, `plotStatEye` for eye diagrams, `analysisReport` for metrics
3. **Sweep** — Vary channel loss, FFE taps, CTLE gain, DFE taps, or jitter to map the design space
4. **Compare** — Evaluate architectures (FFE-only vs FFE+CTLE vs FFE+CTLE+DFE) using COM, eye height, eye width
5. **Select** — Choose the configuration that meets margin targets, then freeze equalization settings

Use `SerdesSystem` for programmatic exploration; `serdesDesigner` for interactive GUI work.

### Waveform Processing

When you have a captured or imported waveform (e.g., from an oscilloscope or simulation) and want to equalize and analyze it directly:

1. **Load** — Import the waveform and define timing (`SampleInterval`, `SymbolTime`)
2. **Equalize** — Stream through datapath blocks (FFE, CTLE, DFECDR) with `WaveType = "Sample"`
3. **Analyze** — Build an eye diagram with `eyeDiagramSI`, extract metrics (eye height, COM, VEC)
4. **Decompose jitter** — Run `jitter()` on the equalized waveform for TJ, RJ, DJ, DDJ, ISI breakdown

DFECDR and DFE require a sample-by-sample `for` loop in Sample mode; FFE and CTLE accept full vectors. See `reference/waveform-processing.md` for the Direct Equalization pattern.

### IBIS-AMI Model Delivery

When you need compiled models (.ami/.ibs/.dll/.so) for EDA tools or IP delivery:

1. **Export** — Call `exportToSimulink(sys)` to generate a Simulink model from the frozen design
2. **Configure** — Set AMI parameters, IBIS component/pin data, and model type via `IbisAmiManager` or `serdes.AMIExport`
3. **Generate** — Build `.ami`/`.ibs` and compile `.dll`/`.so` via `serdes.AMIExport` with `export()`
4. **Validate** — Load compiled DLL/SO with `serdes.AMI`, compare against behavioral reference (Init for impulse, GetWave for waveform)
5. **Cross-check** — The Simulink path (`sim` with Rx WaveOut) is the preferred time-domain reference. Compare against: statistical `analysis()`, system objects direct chain, and compiled AMI DLLs. See `reference/simulink-serdes-simulation.md`
6. **Iterate** — Fix discrepancies, re-export, re-validate until all paths agree

### AMI Model Types

Choose the model type based on which equalization blocks need to adapt at runtime:

| Type | Init_Returns_Impulse | GetWave_Exists | Use For |
|------|---------------------|----------------|---------|
| Init-Only | true | false | LTI equalization (fixed FFE, CTLE). Supports statistical analysis |
| GetWave-Only | false | true | Time-domain only. No statistical analysis |
| Dual | true | true | Adaptive equalization (DFE, CDR). All analysis types |

Every IBIS-AMI model implements `AMI_Init` (required), `AMI_GetWave` (optional), and `AMI_Close` (required) per the IBIS standard.

## Key Classes

| Class | Purpose |
|-------|---------|
| `SerdesSystem` | Top-level system. Methods: `analysis`, `plotStatEye`, `plotImpulse`, `plotPulse`, `plotAlignedPulse`, `plotWavePattern`, `analysisReport`, `exportToSimulink` |
| `Transmitter` | Tx container. Construct: `Transmitter('Blocks', {serdes.FFE(...)})` |
| `Receiver` | Rx container. Construct: `Receiver('Blocks', {serdes.CTLE(...), serdes.DFECDR(...)})` |
| `ChannelData` | Channel spec. Props: `ChannelLossdB`, `ChannelLossFreq` (**default 5 GHz — must override to Nyquist**), `ChannelDifferentialImpedance`, or `Impulse`/`dt` |
| `JitterAndNoise` | IBIS 7.0 jitter/noise. 4 groups: Tx jitter (Rj/Dj/DCD/Sj), Rx jitter, Rx clock recovery (5 params, active with `RxClockMode='clocked'`, `'convolved'`, or `'normal'`), Rx noise. Values in seconds (default) or UI. See `reference/serdes-api-reference.md` |
| `serdes.AMI` | Run compiled AMI DLLs/SOs. Call: `[waveOut, impulseOut] = ami(waveIn, impulseIn, clockIn)` |
| `serdes.AMIExport` | Programmatic AMI export (R2026a+). Methods: `export`, `getExportSettings`. Props: `ModelTypeTx`, `DLLFiles`, `LinuxCrossCompile` |
| `SParameterChannel` | S-parameter to impulse response. Handles `.s4p` through `.s16p` (multi-port returns Nx(K) matrix: col 1=thru, cols 2+=aggressors). Props: `FileName`, `SampleInterval`, `StopTime`, `PortOrder` |
| `eyeDiagramSI` | Waveform eye diagram (R2024a+). Step: `eyeObj(wave)` — no output. Metrics: `eyeHeight`, `eyeWidth`, `com`, `vec`, `margin` |
| `ctlefit` | CTLE pole/zero fitter. Import: `ctlefit.readcsv`. Output: `GPZ` matrix for `serdes.CTLE("Specification", "GPZ Matrix")` |

### Datapath Blocks

| Block | Role | Mode Values | Key Properties |
|-------|------|-------------|----------------|
| `serdes.FFE` | Feed-forward equalizer | 0, 1 | `TapWeights`, `TapSpacing`, `Normalize` |
| `serdes.CTLE` | Continuous-time linear EQ | 0, 1, 2 | `Specification`, `DCGain`, `ACGain`, `PeakingGain`, `GPZ` |
| `serdes.DFECDR` | DFE + clock recovery | 0, 1, 2 | `TapWeights`, `CDRMode`, `PhaseDetector`, `Count` |
| `serdes.DFE` | Standalone DFE | 0, 1, 2 | `TapWeights`, `EqualizationGain`, `EqualizationStep` |
| `serdes.CDR` | Standalone CDR | 0, 1 | `CDRMode`, `Count`, `Step`, `Sensitivity`. Mode is deprecated |
| `serdes.AGC` | Auto gain control | 0, 1 | `TargetRMSVoltage`, `MaxGain`, `AveragingLength` |
| `serdes.VGA` | Variable gain amplifier | 0, 1 | `Gain` |
| `serdes.SaturatingAmplifier` | Limiting amplifier | 0, 1 | `Limit`, `LinearGain`, `Specification` |
| `serdes.PassThrough` | No-op placeholder | — | — |

**Mode values:** 0 = Fixed (not exported), 1 = Fixed (exported as AMI parameter), 2 = Adaptive (GetWave). Only CTLE, DFECDR, and DFE support Mode=2.

Set CTLE `Specification` before setting gain properties — using `ACGain` with the default spec triggers a warning. **GPZ Matrix requires `Mode=1`** for `ConfigSelect` to switch rows. See `reference/equalization-tuning.md` for the 4 specification options.

## Patterns

Each reference file includes executable code patterns for its topic. Load the relevant reference before writing code — it contains correct calling conventions, constructor arguments, and property names. See the References table in Conventions below for the full routing map.

## Common Mistakes

See `reference/common-mistakes.md` for 37 documented anti-patterns with wrong/correct code pairs covering API misuse, wrong property names, silent failures, and performance pitfalls.

## Conventions

### Design

- Use `SerdesSystem` for programmatic design; `serdesDesigner` for interactive exploration. Always run `analysis`/`plotStatEye` before exporting
- **CRITICAL:** `ChannelLossFreq` defaults to 5 GHz — **always override** to Nyquist (`1/(2*SymbolTime)`). Without this, 15 dB at 5 GHz becomes 40+ dB at Nyquist and the eye appears closed. Use `SParameterChannel` for real channels
- `analysis()` does not auto-optimize FFE taps — use canonical de-emphasis with `sum(abs(taps)) ≈ 1.0`
- DFE taps initialized to zero are optimized by the statistical solver automatically
- Industry reference designs: `serdesDesigner` or `openExample('serdes/PCIe5TransmitterReceiverIBISAMIModelExample')`. See `reference/equalization-tuning.md` for starting-point configurations

### Visualization and Metrics

- All `SerdesSystem` plot methods (`plotStatEye`, `plotImpulse`, `plotPulse`, `plotAlignedPulse`, `plotWavePattern`) render into the current axes — use `tiledlayout`/`nexttile` or `subplot` for multi-panel layouts
- `eyeDiagramSI` (R2024a+) for waveform eye diagrams; `jitter` (R2024b+) for jitter decomposition
- DFECDR/DFE in `"Sample"` WaveType require scalar (sample-by-sample) input; FFE/CTLE accept full vectors
- When generating PRBS waveforms via `pulse2wave`, ask the user for PRBS order and symbol count — default PRBS-10 (1023 symbols) if unspecified
- Use `serdes.utilities.SignalIntegrityColorMap` (not `hot`/`parula`) for `pulse2stateye` plots. For compliance, use `margin(eyeObj, eyeMask)`
- See `reference/visualization-and-metrics.md` for all plot methods, metrics fields/units, eyeDiagramSI, and jitter

### AMI Export and Validation

- Use `serdes.AMIExport` with `export()` for programmatic AMI generation — not `slbuild` (legacy, R2025b and earlier only)
- Validate compiled DLLs/SOs with `serdes.AMI` before sending to EDA tools — both Init (impulse correlation) and GetWave (waveform chain)
- **Simulink is the preferred time-domain path** — `sim()` with Rx WaveOut is the ground truth for adaptive systems. Compare against system objects chain and compiled AMI DLLs as cross-checks. Use the same PRBS stimulus across all time-domain paths
- AMI export parameters on Simulink blocks use `*AMI` suffix (`'ModeAMI'`, `'TapWeightsAMI'`); model-level settings go through `IbisAmiManager` or `serdes.AMIExport`
- No compiled DLLs/SOs ship with the toolbox. Cross-compile for Linux `.so` via `serdes.utilities.createCrossCompiler`

### Script-First Workflow

For design, analysis, or sweep tasks — write code to `.m` files on disk, not inline MCP snippets. For quick one-off checks, inline `evaluate_matlab_code` is fine.

1. **Create** a `.m` file (e.g., `serdes_pam4_design.m`), **run** via `run_matlab_file`, **iterate** by editing and re-running
2. **Deliver** a polished script — `%% Parameters` block at top, `%% Section` headers, summary `fprintf` at end

### References

| Load when... | Reference |
|-------------|-----------|
| Building or modifying a `SerdesSystem` | `reference/serdes-api-reference.md` |
| Debugging wrong API names or silent failures | `reference/common-mistakes.md` |
| Working with S-parameter files or crosstalk | `reference/channel-modeling.md` |
| Tuning CTLE, FFE, DFE, or fitting transfer functions | `reference/equalization-tuning.md` |
| Sweeping parameters or running GA optimization | `reference/optimization.md` |
| Plotting eyes, reading metrics, or decomposing jitter | `reference/visualization-and-metrics.md` |
| Equalizing captured or imported waveforms directly | `reference/waveform-processing.md` |
| Exporting to Simulink, compiling AMI DLLs, or validating AMI models | `reference/programmatic-ami-generation.md` |
| Scripting Simulink simulations or `parsim` sweeps | `reference/simulink-serdes-simulation.md` |
| Building custom datapath blocks | `reference/custom-datapath-blocks.md` |
| Looking up utility functions (SNR, ICN, resample) | `reference/serdes-utilities.md` |

----

Copyright 2026 The MathWorks, Inc.
----
