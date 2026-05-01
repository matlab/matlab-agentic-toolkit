# Simulink SerDes Simulation Scripting

Run SerDes Simulink models programmatically with `sim()`, sweep parameters
with `parsim`, configure blocks with `set_param`/`get_param`, and correlate
behavioral models against third-party IBIS-AMI DLLs using the AMI block.

## When to Use sim() vs analysis()

| Criterion | `analysis(sys)` | `sim(mdl)` |
|-----------|-----------------|------------|
| Domain | Statistical (Init path) | Time-domain (GetWave path) |
| Speed | Fast (~1 s) | Slow (~10-60 s per run) |
| DFE adaptation | Optimized but not converged | Fully converged per-sample |
| CDR convergence | Not modeled | Full bang-bang/baud-rate |
| Waveform output | Synthetic from pulse | Actual sample-by-sample |
| Third-party DLL | Not supported | Supported via AMI block |
| Parameter sweep | Loop over `analysis()` | `parsim` with `SimulationInput` |

**Simulink `sim()` is the preferred time-domain approach** — it is the ground
truth for adaptive systems. Use it for: DFE/CDR adaptation, waveform-level
debugging, AMI DLL correlation, or access to per-sample signal logging.
System objects chains and AMI DLL chains serve as cross-checks against Simulink.

## Model Structure After exportToSimulink

After `exportToSimulink(sys)`, the Simulink model contains:

```
mdl/
├── Tx/
│   ├── FFE              % serdes.FFE block
│   ├── VGA              % (if present)
│   └── SaturatingAmplifier  % (if present)
├── Analog Channel/      % serdes.ChannelLoss or ChannelImpulse
├── Rx/
│   ├── CTLE             % serdes.CTLE block
│   ├── DFECDR           % serdes.DFECDR block
│   └── AGC              % (if present)
├── Configuration        % SerDes system parameters + IbisAmiManager
└── Stimulus             % serdes.Stimulus block
```

Block paths follow the pattern `[mdl '/Tx/FFE']`, `[mdl '/Rx/CTLE']`, etc.

## Model Workspace

The model workspace contains `Simulink.Signal` objects (not plain doubles):

| Variable | Type | Description |
|----------|------|-------------|
| `SymbolTime` | `Simulink.Signal` | Symbol period (s) |
| `SampleInterval` | `Simulink.Signal` | Sample interval (s) |
| `TargetBER` | `Simulink.Signal` | Target bit error rate |
| `Modulation` | `Simulink.Signal` | Number of levels (2, 4, ...) |

**Access:**
```matlab
mdlWks = get_param(mdl, 'ModelWorkspace');
symTime = mdlWks.getVariable('SymbolTime');
% symTime is a Simulink.Signal — read .InitialValue for the numeric value
```

## Running sim()

```matlab
% 1. Export and open model
exportToSimulink(sys);
mdl = "mySerDesModel";  % model name from exportToSimulink

% 2. Configure simulation
set_param(mdl, 'StopTime', '5e-8');  % 50 ns

% 3. Run simulation
out = sim(mdl);

% 4. Extract logged signals from SimulationOutput
% Signal logging depends on model configuration.
% Access via out.logsout if signal logging is enabled:
%   logsout = out.logsout;
%   txOut = logsout.getElement('TxOut').Values;
```

**Critical:** `sim()` returns a `Simulink.SimulationOutput` object, not
workspace variables. Access results through the output object's fields.

## set_param / get_param

All parameter values in `set_param` are **strings** — use `num2str` or
`mat2str` to convert numeric values.

### Common SerDes Block Parameters

```matlab
% FFE tap weights
set_param([mdl '/Tx/FFE'], 'TapWeights', mat2str([-0.1 0.7 -0.2]));

% CTLE gain (depends on Specification)
set_param([mdl '/Rx/CTLE'], 'ACGain', num2str(12));
set_param([mdl '/Rx/CTLE'], 'DCGain', num2str(0));

% DFECDR tap weights
set_param([mdl '/Rx/DFECDR'], 'TapWeights', mat2str(zeros(1, 10)));

% Channel loss
set_param([mdl '/Analog Channel'], 'Loss', num2str(15));
set_param([mdl '/Analog Channel'], 'TargetFrequency', num2str(14e9));

% Read current values
currentTaps = get_param([mdl '/Tx/FFE'], 'TapWeights');  % returns char
tapValues = str2num(currentTaps);  %#ok<ST2NM> — needed for mat2str'd arrays
```

### Stimulus Configuration

The Stimulus block mask uses `so` prefix for parameters (e.g., `soSpecification`
instead of `Specification`). Jitter units default to **UI** — override with `so*Unit` params.

```matlab
set_param([mdl '/Stimulus'], 'soSpecification', 'Serial PRBS');
set_param([mdl '/Stimulus'], 'soOrder', '11');
set_param([mdl '/Stimulus'], 'soRjUnit', 'Seconds');  % default is UI — must override
set_param([mdl '/Stimulus'], 'soRj', '1e-12');         % 1 ps RMS random jitter
set_param([mdl '/Stimulus'], 'soDjUnit', 'Seconds');
set_param([mdl '/Stimulus'], 'soDj', '3e-12');         % 3 ps deterministic jitter
```

## parsim Parameter Sweeps

Use `Simulink.SimulationInput` arrays for parallel or sequential sweeps.

```matlab
% Sweep CTLE AC gain from 0 to 20 dB
acGainValues = 0:2:20;
N = numel(acGainValues);

% Build SimulationInput array
simIn(1:N) = Simulink.SimulationInput(mdl);
for k = 1:N
    simIn(k) = simIn(k).setBlockParameter(...
        [mdl '/Rx/CTLE'], 'ACGain', num2str(acGainValues(k)));
end

% CRITICAL: save model before parsim
save_system(mdl);

% Run sweep (sequential by default; use 'UseFastRestart', 'on' for speed)
out = parsim(simIn, 'ShowProgress', 'on', 'UseFastRestart', 'on');

% Extract results from each run
for k = 1:N
    % Access simulation output for run k
    simOut = out(k);
    % Process results...
end
```

### Multi-Parameter Sweep

```matlab
% 2D sweep: FFE taps × channel loss
ffeTapSets = {[-0.05 0.9 -0.05], [-0.1 0.8 -0.1], [-0.15 0.7 -0.15]};
lossValues = [8, 12, 16, 20];
idx = 0;

for i = 1:numel(ffeTapSets)
    for j = 1:numel(lossValues)
        idx = idx + 1;
        simIn(idx) = Simulink.SimulationInput(mdl);
        simIn(idx) = simIn(idx).setBlockParameter(...
            [mdl '/Tx/FFE'], 'TapWeights', mat2str(ffeTapSets{i}), ...
            [mdl '/Analog Channel'], 'Loss', num2str(lossValues(j)));
    end
end

save_system(mdl);
out = parsim(simIn, 'ShowProgress', 'on');
```

## Simulink SerDes Block Reference

### serdes.Stimulus

PRBS pattern generator with jitter injection.

| Property | Default | Description |
|----------|---------|-------------|
| `Specification` | `"Random Symbols"` | Pattern type (10 options — see below) |
| `Modulation` | 2 | Symbol levels: 2 (NRZ) to 32 |
| `Order` | 7 | PRBS order (scalar or vector for parallel) |
| `Seed` | `{[0 1 0 1 0 1 0]}` | PRBS seed (cell of binary vectors) |
| `Dj` | 0 | Deterministic jitter |
| `Rj` | 0 | Random jitter (std dev) |
| `DCD` | 0 | Duty cycle distortion |
| `Sj` | 0 | Sinusoidal jitter |
| `SjFrequency` | 0 | Sj frequency (Hz) |
| `BinaryToPAMnMapping` | `"Default"` | Mapping: `"Default"`, `"ETH_100BASE_T1"`, `"USB4V2"`, `"Uniform"` |
| `SymbolTime` | 100e-12 | Symbol period (s) |
| `SampleInterval` | 6.25e-12 | Sample interval (s) |

**Specification options:** `"Random Symbols"`, `"Symbol Pattern"`,
`"Serial PRBS"`, `"Binary Pattern"`, `"Symbol Voltage Pattern"`,
`"Sampled Voltage"`, `"Parallel PRBS"`, `"PRBS"`, `"PAMn"`, `"Data Pattern"`

**Jitter units default to UI** (not Seconds). Set `soRjUnit`/`soDjUnit`/`soDCDUnit`/`soSjUnit`
to `'Seconds'` for absolute values. Passing seconds values without overriding the unit
silently treats them as UI fractions (e.g., `1e-12` UI ≈ zero jitter).

### serdes.ChannelLoss

Simple lossy transmission line model (IEEE 802.3bj-2014).

| Property | Default | Description |
|----------|---------|-------------|
| `Loss` | 8 | Channel power loss at target frequency (dB) |
| `TargetFrequency` | 10e9 | Frequency for specified loss (Hz) |
| `dt` | 1e-12 | Sample interval (s) |
| `Zc` | 100 | Differential characteristic impedance (ohms) |
| `TxR` / `RxR` | 50 | Single-ended Tx/Rx impedance (ohms) |
| `TxC` / `RxC` | 1e-12 | Single-ended Tx/Rx capacitance (F) |
| `RiseTime` | 10e-12 | 20-80% rise time of stimulus (s) |
| `VoltageSwingIdeal` | 1 | Vpp at Tx analog model input (V) |
| `EnableCrosstalk` | false | Include crosstalk in simulation |
| `CrosstalkSpecification` | `"CEI-28G-SR"` | Spec: `"CEI-25G-LR"`, `"CEI-28G-VSR"`, `"100GBASE-CR4"`, `"Custom"` |
| `FEXTICN` / `NEXTICN` | 15e-3 / 10e-3 | Desired ICN levels (V RMS) |

### serdes.ChannelImpulse

Channel modeled by user-provided impulse response(s).

| Property | Default | Description |
|----------|---------|-------------|
| `ImpulseMatrix` | — | Column matrix of impulse responses (Nx1 or Nx2xM for crosstalk) |
| `SampleInterval` | — | Time step of impulse responses (s) |

For multi-lane with crosstalk, the step method accepts multiple scalar
inputs (one per lane) and returns multiple outputs:
```matlab
convImp = serdes.ChannelImpulse('ImpulseMatrix', imp, 'SampleInterval', dt);
[yThru, yFext, yNext] = convImp(stimMain, stimFext, stimNext);
```

### serdes.EyeAnalyzer

Waveform-based eye diagram analyzer. **MATLAB-only — do not add to Simulink.**

| Property | Default | Description |
|----------|---------|-------------|
| `SymbolTime` | — | Symbol period (s) |
| `SampleInterval` | — | Sample interval (s) |
| `ClockMode` | `"Clocked"` | `"Clocked"`, `"Ideal"`, `"Convolved"` |
| `IgnoreSymbols` | 0 | Skip initial symbols (CDR convergence) |
| `Dj`/`Rj`/`DCD`/`Sj` | 0 | Receiver jitter impairments |
| `GaussianNoise` | 0 | Additive Gaussian noise std dev (V) |
| `UniformNoise` | 0 | Additive uniform noise half-Vpp (V) |
| `ReceiverSensitivity` | 0 | Metastability voltage (V) |
| `ClockIsInput` | false | Set true when providing clock waveform |
| `ThresholdIsInput` | false | Set true when providing threshold waveform |

**Read-only outputs:** `EyeHistogram`, `EyeTime`, `EyeVoltage`, `ClockPDF`

**Usage with CDR clock:**
```matlab
ea = serdes.EyeAnalyzer('SymbolTime', symbolTime, 'SampleInterval', dt, ...
    'ClockIsInput', true, 'IgnoreSymbols', ignoreSymbols);
ea(waveIn, clockTimes, clockValidOnRising);

% Visualize
cmap = serdes.utilities.SignalIntegrityColorMap;
figure; imagesc(ea.EyeTime, ea.EyeVoltage, ea.EyeHistogram);
axis xy; colormap(cmap); colorbar;
```

## Rx WaveOut Port and Time-Domain Capture

The Rx subsystem's `WaveOut` port provides the fully equalized output waveform —
after FFE, CTLE, DFE, and CDR have all processed the signal. This is the same
signal that feeds the Simulink Eye Diagram block.

To capture this waveform programmatically for external analysis (e.g., `eyeDiagramSI`):

1. Enable signal logging on the Rx `WaveOut` port (or use `out.yout` if configured)
2. Run `sim(mdl)` and extract from the `SimulationOutput` object
3. Feed the extracted waveform into `eyeDiagramSI` for independent metrics

### Simulink Results Viewer: Statistical vs Time-Domain

The Simulink SerDes model's built-in results viewer reports both **statistical**
and **time-domain** metrics. The statistical results use the same pulse-based
engine as `analysis(sys)`, so they should be **numerically identical** to
`sys.Metrics.summary`. The time-domain results come from the actual simulation.

This gives a natural cross-check: if the Simulink statistical results differ from
`analysis(sys)`, the model export or configuration has diverged.

## AMI Block for Third-Party DLL Correlation

Two paths for using vendor IBIS-AMI DLLs:

| Path | Tool | Use case |
|------|------|----------|
| **Simulink integration** | AMI Tx/Rx blocks in SerDes testbench | Full time-domain simulation with vendor DLLs inside the Simulink model. Import vendor .ami/.ibs/.dll files into the Configuration block via IbisAmiManager. |
| **Standalone validation** | `serdes.AMI` system object in MATLAB | Quick Init/GetWave correlation outside Simulink. Compare vendor DLL output against behavioral reference. |

For Simulink integration, use `exportToSimulink(sys)` to create the testbench, then open the Configuration block and load vendor AMI files via IbisAmiManager. For standalone validation, use `serdes.AMI` as shown below.

### serdes.AMI Configuration

```matlab
ami = serdes.AMI;
ami.LibraryName    = "vendor_tx";           % DLL filename without extension
ami.LibraryPath    = fullfile(pwd, "dlls"); % directory containing .dll/.so
ami.SymbolTime     = symbolTime;
ami.SampleInterval = dt;
ami.RowSize        = N;                     % must match numel(impulse)
ami.BlockSize      = 1024;                  % samples per GetWave call (default)
ami.InitOnly       = false;                 % true = Init only, false = Init + GetWave
ami.SkipFirstBlock = false;                 % set false when calling from MATLAB
ami.InputString    = "(vendor_tx)";         % root name from .ami file
```

**Important:** When `InitOnly = false`, call the object in a `for` loop with
`BlockSize`-length chunks — `AMI_GetWave` processes exactly `BlockSize` samples
per call. The DLL state persists between calls. See `reference/serdes-api-reference.md`
for the chunked loop pattern.

### Generating InputString for Third-Party .ami Files

```matlab
% Parse .ami file and generate default parameter string
inputStr = serdes.AMI.generateDefaultInputString("vendor_model.ami");
ami.InputString = inputStr;
```

### AMI Correlation Workflow

```matlab
% 1. Design behavioral model
sys = SerdesSystem(...);
results = analysis(sys);
channelImpulse = results.impulse(:, 1);   % unequalized
simReference   = results.impulse(:, 2);   % equalized (behavioral)
N = numel(channelImpulse);

% 2. Run Tx DLL Init — LibraryName is DLL filename without .dll extension
exportDir = fullfile(pwd, "export");
txAmi = serdes.AMI;
txAmi.LibraryName = "serdes_tx_win64";  % from export(): serdes_tx_win64.dll
txAmi.LibraryPath = exportDir;
txAmi.SymbolTime = sys.SymbolTime;
txAmi.SampleInterval = sys.dt;
txAmi.InitOnly = true;
txAmi.InputString = "(serdes_tx)";      % root name from .ami file
txAmi.RowSize = N;
[~, txOut] = txAmi(zeros(N, 1), channelImpulse, -1);

% 3. Run Rx DLL Init
rxAmi = serdes.AMI;
rxAmi.LibraryName = "serdes_rx_win64";
rxAmi.LibraryPath = exportDir;
rxAmi.SymbolTime = sys.SymbolTime;
rxAmi.SampleInterval = sys.dt;
rxAmi.InitOnly = true;
rxAmi.InputString = "(serdes_rx)";
rxAmi.RowSize = N;
[~, rxOut] = rxAmi(zeros(N, 1), txOut, -1);

% 4. Compare
corrCoef = corrcoef(simReference, rxOut);
fprintf("Correlation: %.6f\n", corrCoef(1, 2));  % expect ≈ 1.0
```

**GetWave validation** — sample-for-sample comparison against Simulink:

Log the channel output from Simulink and feed the exact same waveform to the DLL
in a chunked loop. This achieves perfect correlation (max diff at machine epsilon).

**Note:** `rxOut` is logged by default after `exportToSimulink`. The channel output
(`chOut`) is **not** — you must manually enable signal logging on the Analog Channel
output port and name it `chOut`.

```matlab
% 1. Run Simulink to get ground truth
simOut = sim(mdl);
chSimWave = simOut.logsout.get('chOut').Values.Data(:);   % manual logging required
rxSimWave = simOut.logsout.get('rxOut').Values.Data(:);   % logged by default

% 2. Run Rx DLL in chunked loop
blockSize = 1024;
rxAmiGW = serdes.AMI;
rxAmiGW.LibraryName = "serdes_rx_win64";  rxAmiGW.LibraryPath = exportDir;
rxAmiGW.SymbolTime = sys.SymbolTime;      rxAmiGW.SampleInterval = sys.dt;
rxAmiGW.InitOnly = false;       rxAmiGW.SkipFirstBlock = false;
rxAmiGW.RowSize = N;            rxAmiGW.BlockSize = blockSize;
rxAmiGW.InputString = "(serdes_rx)";

Nsim = numel(chSimWave);
nPad = ceil(Nsim / blockSize) * blockSize;
wavePad = [chSimWave; zeros(nPad - Nsim, 1)];
waveOut = zeros(nPad, 1);
clockIn = -ones(blockSize, 1);
for k = 1:nPad/blockSize
    idx = (k-1)*blockSize + (1:blockSize);
    [waveOut(idx), ~] = rxAmiGW(wavePad(idx), channelImpulse, clockIn);
end
dllWave = waveOut(1:Nsim);

% 3. Compare — expect correlation = 1.0 and max diff ≈ 1e-15
R = corrcoef(rxSimWave, dllWave);
fprintf("GetWave vs Simulink: corr=%.15f, max diff=%.2e\n", R(1,2), max(abs(rxSimWave - dllWave)));
```

### AMI Data Output (Simulink AMI Block)

When using the AMI block in a Simulink model, the `AMIData` output port
provides a struct with:

| Field | Description |
|-------|-------------|
| `ImpulseIn` | Input impulse response (before AMI processing) |
| `ImpulseOut` | Output impulse response (after AMI Init) |
| `AMIMessages` | String messages from AMI_Init/AMI_GetWave |
| `InitStatus` | AMI_Init return status |
| `GetWaveStatus` | AMI_GetWave return status |
| `ClockTimesIn` | Input clock times |
| `ClockTimesOut` | Output clock times (after CDR) |
| `CloseStatus` | AMI_Close return status |

### InitPassThrough for Baseline Comparison

The AMI block's `InitPassThrough` checkbox runs only `AMI_Init` (skipping
GetWave), providing a behavioral baseline for comparison:

1. Run with `InitPassThrough = true` → captures Init-only impulse
2. Run with `InitPassThrough = false` → captures full Init + GetWave
3. Compare impulse responses to verify GetWave contribution

## Complete Scripted Workflow

```matlab
%% 1. Design
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE('TapWeights', [-0.1 0.7 -0.2])}), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE('Specification', "DC Gain and AC Gain", ...
        'DCGain', 0, 'ACGain', 10), serdes.DFECDR('TapWeights', zeros(1, 5))}), ...
    'SymbolTime', 35.71e-12, 'SamplesPerSymbol', 16, 'Modulation', 4);
sys.ChannelData.ChannelLossdB = 15;

%% 2. Statistical baseline
results = analysis(sys);
fprintf("Statistical COM: %.1f dB\n", sys.Metrics.summary.COMestimate);

%% 3. Export to Simulink
exportToSimulink(sys);
mdl = "mySerDesModel";

%% 4. Configure and simulate
set_param(mdl, 'StopTime', '1e-7');
out = sim(mdl);

%% 5. Sweep CTLE gain
acGains = 0:4:20;
simIn(1:numel(acGains)) = Simulink.SimulationInput(mdl);
for k = 1:numel(acGains)
    simIn(k) = simIn(k).setBlockParameter(...
        [mdl '/Rx/CTLE'], 'ACGain', num2str(acGains(k)));
end
save_system(mdl);
sweepOut = parsim(simIn, 'UseFastRestart', 'on');
```

## Common Mistakes

### 1. save_system Required Before parsim

```matlab
% WRONG — model not saved, parsim may use stale parameters
out = parsim(simIn);

% CORRECT — always save before parsim
save_system(mdl);
out = parsim(simIn);
```

### 2. Block Parameter Values Must Be Strings

```matlab
% WRONG — numeric value
set_param([mdl '/Rx/CTLE'], 'ACGain', 12);  % ERROR

% CORRECT — string value
set_param([mdl '/Rx/CTLE'], 'ACGain', num2str(12));
set_param([mdl '/Tx/FFE'], 'TapWeights', mat2str([-0.1 0.8 -0.1]));
```

### 3. Model Workspace whos Uses Lowercase Fields

```matlab
% WRONG — uppercase field names
mdlWks = get_param(mdl, 'ModelWorkspace');
varNames = {mdlWks.whos.Name};   % ERROR: Unrecognized field

% CORRECT — lowercase field names (name, class, size, bytes)
varNames = {mdlWks.whos.name};
varClasses = {mdlWks.whos.class};
```

### 4. sim() Returns SimulationOutput, Not Variables

```matlab
% WRONG — expecting workspace variables
out = sim(mdl);
wave = out.TxWave;  % May not exist as a direct field

% CORRECT — use logsout for logged signals
out = sim(mdl);
if ~isempty(out.logsout)
    txSig = out.logsout.getElement('TxOut').Values;
end
```

### 5. EyeAnalyzer Is MATLAB-Only

```matlab
% WRONG — adding to Simulink model
% serdes.EyeAnalyzer cannot be used as a Simulink block

% CORRECT — use in MATLAB post-processing after sim()
ea = serdes.EyeAnalyzer('SymbolTime', symbolTime, 'SampleInterval', dt);
ea(extractedWaveform);  % process waveform extracted from sim output
```

### 6. AMI LibraryName and InputString

```matlab
% WRONG — LibraryName must be the DLL filename (without .dll), not the .ami root
ami.LibraryName = "serdes_tx";         % ERROR: no file serdes_tx.dll
ami.InputString = "(myModel_tx)";      % ERROR: root name mismatch with .ami

% CORRECT — LibraryName = DLL filename; InputString root = .ami file root
ami.LibraryName = "serdes_tx_win64";   % matches serdes_tx_win64.dll
ami.InputString = "(serdes_tx)";       % matches root in serdes_tx.ami
% Or use generateDefaultInputString to parse from .ami file
```

----

Copyright 2026 The MathWorks, Inc.
----
