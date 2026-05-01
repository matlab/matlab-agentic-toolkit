# SerDes Toolbox Class and Function Reference

## SerdesSystem

Top-level design and analysis object.

### Construction

```matlab
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {block1, block2}), ...
    'RxModel', Receiver('Blocks', {block3, block4}), ...
    'SymbolTime', 100e-12, ...
    'SamplesPerSymbol', 16, ...
    'Modulation', 2, ...
    'Signaling', "Differential", ...
    'BERtarget', 1e-6);
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `TxModel` | `Transmitter` | Tx container with `Blocks`, `RiseTime`, `VoltageSwingIdeal`, `AnalogModel` |
| `RxModel` | `Receiver` | Rx container with `Blocks`, `AnalogModel` |
| `Name` | string | System name |
| `SymbolTime` | double | Duration of one symbol (s) |
| `SamplesPerSymbol` | integer | Samples per symbol (default 16; valid: 8, 16, 32, 64, 128). `dt = SymbolTime / SamplesPerSymbol` |
| `Modulation` | integer | Modulation levels: 2 (NRZ), 3 (PAM3), 4 (PAM4), up to 16 |
| `Signaling` | string | `"Differential"` or `"Single Ended"` |
| `BERtarget` | double | Target BER for statistical analysis (default `1e-6`) |
| `ChannelData` | `ChannelData` | Channel specification (see below) |
| `JitterAndNoise` | `JitterAndNoise` | Jitter/noise parameters (see below) |
| `dt` | double | Read-only. Computed sample interval |
| `ImpulseResponse` | double | Read-only. Channel impulse response after analysis |
| `Eye` | struct | Read-only. Statistical eye results |
| `Wave` | struct | Read-only. Equalized/unequalized waveforms |
| `Metrics` | struct | Read-only. BER eye contours and bathtub data |

#### Choosing BERtarget

`BERtarget` sets the BER contour at which eye height and eye width are measured. It does not affect COM (which uses its own internal BER assumption). Common values:

| Standard | BERtarget | Notes |
|----------|-----------|-------|
| IEEE 802.3 (Ethernet) | `1e-6` | Default; used for 100G/200G/400G/800G specs |
| OIF CEI | `1e-15` | More conservative; tighter eye opening |
| PCIe Gen5/6 | `1e-6` | Post-FEC target |
| USB4 | `1e-4` | Relaxed pre-FEC target |

Lower BERtarget → smaller reported EH/EW (the eye is measured further into the tails of the distribution). When comparing results across designs, keep BERtarget consistent.

### Metrics.summary Fields

After `analysis(sys)`, `sys.Metrics.summary` contains:

| Field | Type | Units | Description |
|-------|------|-------|-------------|
| `COMestimate` | scalar | dB | Channel Operating Margin |
| `EH` | vector | **Volts** | Eye height at BERtarget. PAM-N returns N-1 values (e.g., PAM4: 3, PAM8: 7) |
| `bestEH` | vector | **Volts** | Best-case eye height (optimistic sampling) |
| `EW` | vector | **Picoseconds** (already scaled — do NOT multiply by 1e12) | Eye width at BERtarget |
| `VEC` | scalar | Percent | Vertical eye closure |
| `eyeAreas` | vector | — | Normalized eye area per eye opening |
| `eyeLinearity` | scalar | Ratio | PAM-N level linearity (1.0 = perfectly symmetric) |

**Units warning:** `EH` is in volts (multiply by 1e3 for mV), but `EW` is already in picoseconds. This is inconsistent with every other timing value in the toolbox (which use seconds).

### analysis() outparams — Adapted Block Parameters

`results.outparams` is a **cell array** with one entry per datapath block (Tx blocks first, then Rx blocks in order). Each cell is either a double (e.g., FFE output) or a struct keyed by block class name.

**Adapted DFE/CTLE parameters live here, NOT on the block object.** After `analysis()`, `sys.RxModel.Blocks{k}.TapWeights` still holds the *initial* values. The solver's adapted values are only in `outparams`.

```matlab
% With Tx FFE + Rx CTLE + Rx DFECDR:
% results.outparams{1} — FFE (double)
% results.outparams{2} — CTLE (struct with field 'CTLE')
% results.outparams{3} — DFECDR (struct with field 'DFECDR')

% Extract adapted DFE taps
for p = 1:numel(results.outparams)
    if isstruct(results.outparams{p}) && isfield(results.outparams{p}, 'DFECDR')
        adaptedTaps = results.outparams{p}.DFECDR.TapWeights;
        adaptedPhase = results.outparams{p}.DFECDR.Phase;
    end
end
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `analysis(sys)` | struct with `t1`, `impulse`, `pulse`, `t2`, `wave`, `outparams` | Run statistical analysis |
| `plotStatEye(sys)` | — | Plot statistical eye diagram |
| `plotImpulse(sys)` | — | Plot equalized/unequalized impulse |
| `plotPulse(sys)` | — | Plot equalized/unequalized pulse |
| `plotAlignedPulse(sys)` | — | Plot aligned pulse response |
| `plotWavePattern(sys)` | — | Plot PRBS waveform |
| `analysisReport(sys)` | — | Print analysis summary to command window |
| `exportToSimulink(sys)` | — | Export to Simulink model |
| `validateSerdesSystem(sys)` | — | Validate system configuration |

## ChannelData

Three channel definition modes (mutually exclusive):

1. **Lossy model** (default): `ChannelLossdB` + `ChannelLossFreq` + `ChannelDifferentialImpedance`
2. **S-parameter model**: via serdesDesigner export
3. **Direct impulse**: `Impulse` + `dt`

**IMPORTANT:** To select impulse mode, pass `"Impulse"` and `"dt"` as constructor name-value pairs. Assigning `sys.ChannelData.Impulse = ...` after construction does NOT switch the mode — the loss model silently takes priority.

```matlab
% CORRECT -- impulse mode via constructor
channel = ChannelData("Impulse", impulseVector, "dt", sampleInterval);
sys = SerdesSystem("ChannelData", channel, ...);

% WRONG -- loss model runs, impulse is ignored
sys.ChannelData.Impulse = impulseVector;
sys.ChannelData.dt = sampleInterval;
```

| Property | Description |
|----------|-------------|
| `ChannelLossdB` | Channel loss in dB at `ChannelLossFreq` |
| `ChannelLossFreq` | Frequency for loss specification (Hz). **Default: 5 GHz** — almost always wrong. Set to Nyquist: `1/(2*SymbolTime)` |
| `ChannelDifferentialImpedance` | Differential impedance (ohms) |
| `Impulse` | Direct impulse response (column vector) |
| `dt` | Sample interval for direct impulse (s) |
| `EnableCrosstalk` | Enable crosstalk modeling (ICN mode only — multi-column impulse auto-enables) |
| `CrosstalkSpecification` | `"CEI-28G-SR"` (default), `"CEI-25G-LR"`, `"CEI-28G-VSR"`, `"100GBASE-CR4"`, or `"Custom"` |
| `FEXTICN` | FEXT integrated crosstalk noise (V RMS, default 0.015). Only with `"Custom"` spec |
| `NEXTICN` | NEXT integrated crosstalk noise (V RMS, default 0.010). Only with `"Custom"` spec |
| `fb` | Baud rate for ICN noise shaping (Hz, auto-derived from SymbolTime) |
| `Aft` / `Ant` | Aggressor amplitude for FEXT/NEXT (Vpp, default 1.2) |
| `Tft` / `Tnt` | Aggressor rise time for FEXT/NEXT (s, default 9.6e-12) |
| `OptionSel` | Read-only. Internal mode selector (1=impulse, 3=loss model) |

## JitterAndNoise

IBIS 7.0 compliant jitter and noise parameters. Each jitter property is a
`SimpleJitter` object with `Value`, `Type`, and `Include` fields. Assign a
scalar to set the value directly; access the sub-fields for unit control.

### RxClockMode

Controls how the Rx sampling clock is modeled:

| Mode | Description |
|------|-------------|
| `"ideal"` | Perfect clock — no Rx clock jitter. Rx_Clock_Recovery_* parameters ignored |
| `"clocked"` | Clock with jitter — Rx_Clock_Recovery_* parameters affect the sampling eye |
| `"convolved"` | Convolves clock jitter with data jitter (statistical combination) |
| `"normal"` | Normal clock recovery model |

**Key rule:** Set `RxClockMode` to `"clocked"` for Rx clock recovery jitter to
affect analysis. With `"ideal"`, all `Rx_Clock_Recovery_*` parameters are ignored.

### Tx Jitter

| Property | Default | Convention |
|----------|---------|------------|
| `Tx_Rj` | 0 | Random jitter — **standard deviation** (not peak-to-peak) |
| `Tx_Dj` | 0 | Deterministic jitter — peak-to-peak |
| `Tx_DCD` | 0 | Duty cycle distortion — peak-to-peak |
| `Tx_Sj` | 0 | Sinusoidal jitter — peak-to-peak amplitude |
| `Tx_Sj_Frequency` | 0 | Sinusoidal jitter frequency (Hz, not UI) |

### Rx Jitter

**Requires `RxClockMode = "clocked"`** — Rx jitter is modeled as clock jitter
and has NO effect in `"ideal"` mode. Rx jitter and Rx Clock Recovery jitter
of the same type produce identical degradation.

| Property | Default | Convention |
|----------|---------|------------|
| `Rx_Rj` | 0 | Random jitter — **standard deviation** |
| `Rx_Dj` | 0 | Deterministic jitter — peak-to-peak |
| `Rx_DCD` | 0 | Duty cycle distortion — peak-to-peak |
| `Rx_Sj` | 0 | Sinusoidal jitter — peak-to-peak amplitude |

### Rx Clock Recovery Jitter

Only active when `RxClockMode` is `"clocked"`, `"convolved"`, or `"normal"`.
Ignored when `RxClockMode = "ideal"`.

| Property | Default | Convention |
|----------|---------|------------|
| `Rx_Clock_Recovery_Mean` | 0 | CDR mean phase offset. No measurable effect on COM in statistical analysis |
| `Rx_Clock_Recovery_Rj` | 0 | CDR random jitter — standard deviation |
| `Rx_Clock_Recovery_Dj` | 0 | CDR deterministic jitter — peak-to-peak |
| `Rx_Clock_Recovery_Sj` | 0 | CDR sinusoidal jitter — peak-to-peak |
| `Rx_Clock_Recovery_DCD` | 0 | CDR duty cycle distortion — peak-to-peak |

### Rx Noise

| Property | Default | Convention |
|----------|---------|------------|
| `Rx_Receiver_Sensitivity` | 0 | Minimum detectable voltage (V). No measurable effect on COM in statistical analysis |
| `Rx_GaussianNoise` | 0 | Additive Gaussian noise — RMS (V) |
| `Rx_UniformNoise` | 0 | Additive uniform noise — peak (V) |

### Units: Seconds or UI

Each jitter property wraps a `SimpleJitter` object with `Value`, `Type`, and
`Include` fields. The `Type` field accepts `"Float"` (seconds, default) or
`"UI"` (unit intervals). Both work correctly — `analysis()` converts UI values
to seconds using the system's `SymbolTime`.

**Critical:** `Include` defaults to `false`. Direct scalar assignment
(`jn.Tx_Rj = 1e-12`) auto-sets `Include = true` and `Type = "Float"`. When
constructing `SimpleJitter` manually, always set `Include = true` explicitly.

```matlab
% Direct assignment in seconds (simplest — auto-sets Include=true)
jn = JitterAndNoise('RxClockMode', 'clocked');
jn.Tx_Rj = 1e-12;     % 1 ps RMS (Type="Float", Include=true automatic)
jn.Tx_Dj = 5e-12;     % 5 ps peak-to-peak

% Using UI type via SimpleJitter constructor (Include=true required)
sj = SimpleJitter('Value', 0.05, 'Include', true, 'Type', 'UI');
jn.Tx_DCD = sj;       % 0.05 UI → analysis converts via SymbolTime

% Or convert from UI spec to seconds manually
uiSpec = 0.05;  % 5% UI from a datasheet
jn.Tx_DCD = uiSpec * symbolTime;  % explicit conversion

% Disable a specific jitter component
sj = jn.Rx_Sj;
sj.Include = false;
jn.Rx_Sj = sj;
```

### Construction Example

```matlab
% Typical jitter budget for a 56 Gbps PAM4 link
jn = JitterAndNoise('RxClockMode', 'clocked');
jn.Tx_Rj = 0.5e-12;                  % 0.5 ps RMS
jn.Tx_Dj = 2e-12;                    % 2 ps p-p
jn.Tx_DCD = 1e-12;                   % 1 ps DCD
jn.Rx_Rj = 0.3e-12;                  % 0.3 ps RMS
jn.Rx_Clock_Recovery_Rj = 0.2e-12;   % 0.2 ps CDR RJ
jn.Rx_Clock_Recovery_Dj = 1e-12;     % 1 ps CDR DJ
jn.Rx_GaussianNoise = 0.5e-3;        % 0.5 mV RMS

sys = SerdesSystem('JitterAndNoise', jn, ...);
```

## serdes.AMI

Run and test compiled IBIS-AMI DLLs/SOs. Requires SerDes Toolbox + Signal Integrity Toolbox.

### Calling Convention

```matlab
[waveOut, impulseOut] = ami(waveIn, impulseIn, clockIn)
```

- `waveIn` — Input waveform (column vector of `BlockSize` length for GetWave). For Tx: stimulus. For Rx: channel output.
- `impulseIn` — Channel impulse response (column vector of `RowSize` length, optionally with aggressors).
- `clockIn` — Clock times vector of `BlockSize` length ending with `-1`, or just `-1` (scalar) for Init-only mode.
- `waveOut` — Output waveform.
- `impulseOut` — Output impulse response (modified by Init on first call, zeros on subsequent GetWave calls).

**GetWave chunked loop:** `AMI_GetWave` processes exactly `BlockSize` samples per call. When calling from MATLAB with a waveform longer than `BlockSize`, you **must** call the object in a `for` loop with `BlockSize`-length chunks. The DLL state is preserved between calls via the memory handle — Init fires only on the first call:

```matlab
nPad = ceil(N / blockSize) * blockSize;
wavePad = [wave; zeros(nPad - N, 1)];
waveOut = zeros(nPad, 1);
clockIn = -ones(blockSize, 1);
for k = 1:nPad/blockSize
    idx = (k-1)*blockSize + (1:blockSize);
    [waveOut(idx), ~] = ami(wavePad(idx), impulse, clockIn);
end
waveOut = waveOut(1:N);
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `LibraryName` | `''` | Name of the AMI DLL/SO (without extension) |
| `LibraryPath` | `''` | Path to the DLL/SO directory |
| `InputString` | `''` | AMI parameter input string |
| `SymbolTime` | `1e-10` | Symbol time (s) |
| `SampleInterval` | `6.25e-12` | Sample interval (s) |
| `BlockSize` | `1024` | Number of samples passed to each `AMI_GetWave` call |
| `RowSize` | `7065` | Impulse response length — **must match `numel(impulseIn)`** or MATLAB crashes |
| `Aggressors` | `0` | Number of aggressor channels |
| `PassThrough` | `false` | Pass-through mode (bypass DLL) |
| `InitOnly` | `true` | `true` = Init flow only, `false` = Init + GetWave |
| `SkipFirstBlock` | `true` | Skip first GetWave block. **Set `false` when calling from MATLAB** — the default `true` is for Simulink's internal signal buffering and causes the first block to pass through unprocessed |
| `OutputName` | `'AMIOut'` | Workspace variable name (Simulink only, ignored in MATLAB) |
| `AMIData` | struct | Output data structure from DLL |

Static method: `serdes.AMI.generateDefaultInputString(amiFilePath)` — parse `.ami` file and return default input string.

## serdes.AMIExport (R2026a+)

Programmatic AMI export object. Mirrors the IbisAmiManager GUI.

```matlab
AMIExport = serdes.AMIExport("modelName")
AMIExport.ModelsToExport = "Both Tx and Rx";
AMIExport.DLLFiles = true;
AMIExport.LinuxCrossCompile = true;
export(AMIExport);
```

| Property | Default | Description |
|----------|---------|-------------|
| `ModelName` | (read-only) | Simulink model name |
| `ModelConfiguration` | `"TxandRx"` | System model type |
| `ModelTypeTx` | `"Dual model"` | Tx export type: `"Dual model"`, `"GetWave only"`, `"Init only"` |
| `ModelTypeRx` | `"Dual model"` | Rx export type |
| `ModelsToExport` | `"Both Tx and Rx"` | Which models to export |
| `DLLFiles` | `true` | Export compiled DLL/SO |
| `AMIFiles` | `true` | Export .ami files |
| `IBISFile` | `true` | Export .ibs file |
| `LinuxCrossCompile` | `false` | Build Linux .so from Windows |
| `Obfuscate` | `false` | Obfuscate executables |
| `TargetDir` | string | Output directory |

Methods: `export(AMIExport)`, `getExportSettings(AMIExport)`.

## SParameterChannel

Convert S-parameter Touchstone files to time-domain impulse responses with analog Tx/Rx termination modeling. Uses rational fitting internally to produce a causal impulse response from frequency-domain S-parameter data.

### Construction

```matlab
spCh = SParameterChannel("FileName", "channel.s4p");
```

**IMPORTANT:** The constructor requires `"FileName"` as a name-value argument. Positional syntax (`SParameterChannel("channel.s4p")`) does not work.

### Properties — Input

| Property | Default | Description |
|----------|---------|-------------|
| `FileName` | `"default.s4p"` | Touchstone file path (`.s2p`, `.s4p`, `.s8p`, etc.) |
| `PortOrder` | `[]` | Port ordering `[in+ out+ in- out-]`. Empty = auto-detect. For files with convention `1=in+, 2=in-, 3=out+, 4=out-`, use `[1 3 2 4]` |
| `MaxNumberOfPoles` | `1000` | Maximum poles for rational model fit |
| `ErrorTolerance` | `-40` | Desired error tolerance (dB) for rational model fit |

### Properties — Timing

| Property | Default | Description |
|----------|---------|-------------|
| `SampleInterval` | `6.25e-12` | Output sample interval (s). Must match `SerdesSystem` dt |
| `StopTime` | `1e-7` | Impulse response duration (s). Use >= 60 ns for SerdesSystem integration |

### Properties — Analog Model

| Property | Default | Description |
|----------|---------|-------------|
| `TxAmplitude` | `1` | Stimulus input amplitude (V, single-ended) |
| `TxRiseTime` | `1e-11` | 20%-80% rise time of stimulus (s) |
| `TxR` | `50` | Tx termination resistance (ohms, single-ended) |
| `TxC` | `1e-13` | Tx termination capacitance (F) |
| `RxR` | `50` | Rx termination resistance (ohms, single-ended) |
| `RxC` | `2e-13` | Rx termination capacitance (F) |

### Properties — Read-Only Outputs

| Property | Description |
|----------|-------------|
| `ImpulseResponse` | Channel impulse response (column vector). Continuous-time scaling: `sum(ImpulseResponse) * SampleInterval` gives DC gain |
| `t` | Time vector (column, s) |
| `TransferFunction` | System transfer function (column vector, complex) |
| `ChannelTransferFunction` | Channel-only transfer function (excludes Tx/Rx analog model) |
| `f` | S-parameter frequency vector (column, Hz) |
| `RationalResults` | `rational` object with fitting statistics |
| `PortOrderUsed` | Actual port order used after auto-detection |
| `RiseTimeUncertainty` | Uncertainty due to rise time discretization (s, negative) |

### Integration with SerdesSystem

To feed an S-parameter impulse into `SerdesSystem`, construct `ChannelData` with `"Impulse"` and `"dt"` name-value pairs in the constructor. **Do NOT** assign `sys.ChannelData.Impulse` after construction — the internal mode selector stays on loss-model and ignores the impulse.

```matlab
% CORRECT -- use ChannelData constructor
spCh = SParameterChannel("FileName", "channel.s4p");
spCh.SampleInterval = symbolTime / samplesPerSymbol;
spCh.StopTime = 60e-9;
spCh.PortOrder = [1 3 2 4];

channel = ChannelData( ...
    "Impulse", spCh.ImpulseResponse, ...
    "dt", spCh.SampleInterval);

sys = SerdesSystem( ...
    "ChannelData", channel, ...
    "SymbolTime", symbolTime, ...
    "SamplesPerSymbol", samplesPerSymbol, ...
    ... );
```

```matlab
% WRONG -- impulse is silently ignored, loss model runs instead
sys.ChannelData.Impulse = spCh.ImpulseResponse;
sys.ChannelData.dt = spCh.SampleInterval;
```

### Key Gotchas

- **StopTime:** Use >= 60 ns for SerdesSystem integration. Short durations (e.g., 20 ns) produce too few samples and analysis may give incorrect metrics.
- **SampleInterval:** Must match `SerdesSystem.dt` (`SymbolTime / SamplesPerSymbol`).
- **PortOrder:** For 4-port files with convention `1=in+, 2=in-, 3=out+, 4=out-`, set `[1 3 2 4]`. Check `PortOrderUsed` after construction to verify.
- **Multi-port files:** `SParameterChannel` handles `.s8p`/`.s12p`/`.s16p` directly. `ImpulseResponse` returns an Nx(K) matrix: column 1 = victim thru, columns 2+ = aggressor coupling. Pass the full matrix to `ChannelData("Impulse", ir, "dt", dt)` to include crosstalk.

See `reference/channel-modeling.md` for a complete S-parameter workflow.

## Signal Conversion Functions

All functions require **column vector** inputs.

| Function | Signature | Description |
|----------|-----------|-------------|
| `impulse2pulse` | `P = impulse2pulse(I, N, dt)` | Impulse to pulse response |
| `impulse2step` | `S = impulse2step(I, dt)` | Impulse to step response |
| `pulse2impulse` | `I = pulse2impulse(P, N, dt)` | Pulse to impulse |
| `step2impulse` | `I = step2impulse(S, dt)` | Step to impulse |
| `pulse2wave` | `W = pulse2wave(P, D, N)` | Pulse + data to waveform |
| `wave2pulse` | `P = wave2pulse(W, D, N)` | Waveform to pulse |
| `prbs` | `[P, seed] = prbs(O, N, seed, reverse)` | PRBS generator. O = order (5-40), N = length. Returns column vector of 0/1. Optional seed for reproducibility, reverse for time-reversed LFSR |
| `pulse2stateye` | `[S, V, T] = pulse2stateye(P, N, M)` | Statistical eye. M = modulation levels |
| `pulse2pda` | `[E, T, D] = pulse2pda(P, N, M)` | Peak distortion analysis eye |
| `optPulseMetric` | `M = optPulseMetric(P, N, dt, BER)` | Returns struct with fields: `maxEyeHeight`, `maxMeanEyeHeight`, `maxCOM`, `eyeArea`, `eyeWidth`, `centerEyeHeight`, `centerMeanEyeHeight`, `centerCOM`, `SNR`, `usedBER`. LTI-only — does not account for jitter |
| `pulseRecoverClock` | `C = pulseRecoverClock(P, N)` | Clock recovery (hula-hoop algorithm) |
| `applyLinearFilter` | `[Y, Xh, Yh] = applyLinearFilter(X, Xh, Yh, B, A)` | Recursive filter (Direct Form I) |

## Waveform Analysis (R2024a+)

| Class/Function | Signature | Description |
|----------------|-----------|-------------|
| `eyeDiagramSI` | `eyeObj = eyeDiagramSI; eyeObj(wave)` | System object — builds 2-D eye histogram from waveform. **No output from step.** Do NOT name the variable `eye` — it shadows MATLAB's built-in `eye()`. Metrics via `eyeHeight`, `eyeWidth`, `com`, `vec`, `eyeArea`, `eyeLinearity`, `bathtub`, `margin` |
| `jitter` | `J = jitter(y, SampleInterval=s, SymbolTime=t, Plot=false)` | Jitter decomposition. Returns struct: `TJrms`, `TJpkpk`, `RJrms`, `DJpkpk`, `DDJpkpk`, `DCDrms`, `ISIpkpk`, `SJa`/`SJf`/`SJp` |

See `reference/visualization-and-metrics.md` for eyeDiagramSI/jitter property tables and
`reference/waveform-processing.md` for direct equalization patterns.

## Fitting Tools

### ctlefit

Programmatic interface to the CTLE Fitter. Fits rational pole/zero models to CTLE frequency response data and produces a GPZ matrix for `serdes.CTLE`.

#### Construction

```matlab
[f, H] = ctlefit.readcsv(csvFile);   % Import from CSV
obj = ctlefit('f', f, 'H', H, 'SampleInterval', dt, ...
    'MaxNumberOfPoles', 2, 'ErrorTolerance', -40, ...
    'TendsToZero', 1, 'UseCommonPoles', 0, 'PaddedPole', 1e11);
```

#### Import

| Static Method | Description |
|---------------|-------------|
| `ctlefit.readcsv(filename)` | Read CTLE frequency response from CSV. Returns `[f, H]`. Header format: `freq,real,imag,real,imag,...` (also accepts `db,phaseDeg`, `db,phaseRad`, `mag,phaseDeg`, `mag,phaseRad`) |

#### Constructor Properties

| Property | Type | Description |
|----------|------|-------------|
| `f` | double vector | Frequency vector (Hz) |
| `H` | complex matrix | Complex transfer functions (`nFreq x nSettings`) |
| `SampleInterval` | double | Sample interval (s). Typically `SymbolTime / SamplesPerSymbol` |
| `MaxNumberOfPoles` | integer | Maximum number of poles per setting (1, 2, or 3). Default: 2 |
| `ErrorTolerance` | double | Maximum acceptable fit error (dB). Default: -40 |
| `TendsToZero` | logical | `1` = response rolls off at high frequency (typical for CTLE). `0` = flat |
| `UseCommonPoles` | logical | `1` = force all settings to share pole locations. `0` = independent poles |
| `PaddedPole` | double | Extra high-frequency pole (Hz) for rolloff. Example: `1e11` |

#### Output

| Property | Format | Description |
|----------|--------|-------------|
| `GPZ` | matrix | Fitted poles/zeros/gains. Format: `[Gain(dB) Pole1(Hz) Zero1(Hz) Pole2(Hz); ...]`. One row per CTLE gain setting. Poles/zeros are negative (left half-plane). Feeds directly into `serdes.CTLE('Specification', "GPZ Matrix", 'GPZ', gpz)` |

#### Preprocessing Methods

| Method | Description |
|--------|-------------|
| `truncateAbove(obj, fMax)` | Remove frequency data above `fMax` (Hz). Use `2 * fNyquist` to cut fitting noise |
| `truncateBelow(obj, fMin)` | Remove frequency data below `fMin` (Hz) |
| `resample(obj, fNew)` | Resample transfer functions onto new frequency vector |
| `removeDelay(obj)` | Remove group delay from transfer functions |

#### Visualization Methods

| Method | Description |
|--------|-------------|
| `plot(obj, format, which, plotType)` | Magnitude response. `format`: `"dB"`, `"mag"`. `which`: `"All"` or index. `plotType`: `"semilogx"`, `"plot"` |
| `plotPulse(obj, which)` | Pulse response of fitted model |
| `plotError(obj, which)` | Fit error (deviation between fitted and original) |
| `plotFitMetric(obj, which)` | Fit quality metric plot |
| `plotPoleZero(obj, which)` | Pole-zero map for each gain setting |

#### Typical Workflow

```matlab
[f, H] = ctlefit.readcsv("ctle_data.csv");
obj = ctlefit("f", f, "H", H, "SampleInterval", dt, "MaxNumberOfPoles", 2);
truncateAbove(obj, 2 * fNyquist);
gpz = obj.GPZ;
ctle = serdes.CTLE("Specification", "GPZ Matrix", "GPZ", gpz);
```

### Other Fitting Tools

| Tool | Description |
|------|-------------|
| `ctlefitter` | CTLE Fitter GUI app (interactive version of `ctlefit`) |
| `SParameterChannel` | S-parameter fitting (also listed above) |
| `sParameterFitter` | S-parameter Fitter GUI app |

## GUI Apps

| App | Launch | Purpose |
|-----|--------|---------|
| `serdesDesigner` | `serdesDesigner` | Main design app — design, analyze, export |
| `IbisAmiManager` | From Configuration block | AMI parameter tree, IBIS files, DLL generation |
| `ctlefitter` | `ctlefitter` | CTLE pole/zero fitting |
| `sParameterFitter` | `sParameterFitter` | S-parameter to impulse fitting |

## serdes.utilities Namespace

Signal quality metrics, signal manipulation, and formatting functions. All called
as `serdes.utilities.<FunctionName>(...)`. See `reference/serdes-utilities.md`
for full signatures, gotchas, and usage patterns.

| Function | Purpose | Key Output |
|----------|---------|------------|
| `SER` | Symbol error rate class | `.SymbolErrorRate` after `calculateSER()` |
| `SNR(P, N)` | Signal-to-noise ratio from pulse | Linear ratio (not dB) |
| `WaveEyeHeight(wave, N)` | Max eye height by waveform folding | `[maxEH, upper, lower]` in volts |
| `icn(f, Sxt, fb)` | Integrated crosstalk noise (OIF-CEI) | V RMS |
| `poleZeroDefine(NV)` | CTLE poles/zeros from peaking specs | `[G, P, Z]` or GPZ matrix |
| `SoftClipper(gain, limit)` | Cubic soft-clipper curve | `[Nx2]` Vin/Vout |
| `resampleImpulse(X, dtIn, dtOut, normalize)` | Resample impulse response | Column matrix |
| `shiftPulse(pulse, N)` | Center pulse for eye diagrams | Shifted pulse + cursor index |
| `floatingTaps(taps, fixed, groups, size)` | DFE floating tap placement | Constrained tap vector |
| `dt2Trf` / `trf2dt` | IBIS ↔ LTI rise time conversion | Rise time (s) |
| `db(x)` | `20*log10(abs(x))` | dB value |
| `num2prefix(X, unit)` | SI prefix formatting | `"100 ps"`, `"14.1 GHz"` |
| `SignalIntegrityColorMap` | Standard eye diagram colormap | Colormap matrix |
| `pulseRecoverClock(P, N)` | Clock recovery (hula-hoop) | Clock index |

## Simulink SerDes Blocks

System objects used as Simulink blocks in exported SerDes models. See
`reference/simulink-serdes-simulation.md` for scripted simulation workflows.

| Block | Purpose | Key Properties |
|-------|---------|----------------|
| `serdes.Stimulus` | PRBS pattern + jitter | `Specification` (10 options), `Modulation` (2-32), `Dj`/`Rj`/`DCD`/`Sj`, `BinaryToPAMnMapping` |
| `serdes.ChannelLoss` | Lossy transmission line (IEEE 802.3bj) | `Loss`, `TargetFrequency`, `Zc`, `TxR`/`RxR`/`TxC`/`RxC`, `EnableCrosstalk`, `FEXTICN`/`NEXTICN` |
| `serdes.ChannelImpulse` | Channel from impulse matrix | `ImpulseMatrix` (Nx1 or Nx2xM), `SampleInterval` |
| `serdes.EyeAnalyzer` | Waveform eye analysis (**MATLAB-only**) | `ClockMode`, `IgnoreSymbols`, jitter/noise impairments, `EyeHistogram` (read-only) |

## Pattern: Programmatic System Design and Analysis

```matlab
% Create a 56 Gbps PAM4 SerDes system with full analog models
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', ...
        {serdes.FFE('TapWeights', [-0.1 0.7 -0.2])}, ...
        'AnalogModel', AnalogModel('R', 50, 'C', 1e-13), ...
        'RiseTime', 1e-11, 'VoltageSwingIdeal', 1), ...
    'RxModel', Receiver('Blocks', ...
        {serdes.CTLE('Specification', "DC Gain and AC Gain", ...
                      'DCGain', 0, 'ACGain', 12, ...
                      'PeakingFrequency', 14e9), ...
         serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2)}, ...
        'AnalogModel', AnalogModel('R', 50, 'C', 2e-13)), ...
    'ChannelData', ChannelData('ChannelLossdB', 15, ...
        'ChannelLossFreq', 14e9, 'ChannelDifferentialImpedance', 100), ...
    'JitterAndNoise', JitterAndNoise('RxClockMode', 'clocked'), ...
    'SymbolTime', 35.71e-12, ...
    'SamplesPerSymbol', 16, ...
    'Modulation', 4, ...
    'Signaling', 'Differential', ...
    'BERtarget', 1e-6);

% Run analysis — returns struct with t1, impulse, pulse, t2, wave, outparams
results = analysis(sys);
plotStatEye(sys);
analysisReport(sys);

% Read metrics — EH is in volts, EW is in picoseconds (already scaled)
m = sys.Metrics.summary;
fprintf("COM: %.2f dB, EH: %.1f mV, EW: %.1f ps\n", m.COMestimate, m.EH(2)*1e3, m.EW(2));

% Read adapted DFE taps from outparams (NOT from the block object)
% outparams is a cell array — one entry per datapath block in Tx/Rx order
for p = 1:numel(results.outparams)
    if isstruct(results.outparams{p}) && isfield(results.outparams{p}, 'DFECDR')
        adaptedTaps = results.outparams{p}.DFECDR.TapWeights;
        fprintf("Adapted DFE taps: %s\n", mat2str(adaptedTaps, 4));
    end
end
```

----

Copyright 2026 The MathWorks, Inc.
----
