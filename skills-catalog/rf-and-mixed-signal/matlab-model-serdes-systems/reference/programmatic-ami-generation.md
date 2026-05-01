# Programmatic AMI Generation

Build `.ami`, `.ibs`, and compiled `.dll` (Windows) or `.so` (Linux) files
without the IbisAmiManager GUI.

## serdes.AMIExport (R2026a+) — Recommended

New in R2026a, `serdes.AMIExport` provides full programmatic control over AMI
export. It mirrors the IbisAmiManager GUI — changes in either are synchronized
in real-time.

### Construction

```matlab
AMIExport = serdes.AMIExport              % from currently selected model
AMIExport = serdes.AMIExport("modelName") % from a specific model
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `ModelName` | (read-only) | Simulink model name |
| `ModelConfiguration` | `"TxandRx"` | `"TxandRx"`, `"IO"`, `"Redriver"`, `"Retimer"` |
| `ModelNameTx` | string | Transmitter model name |
| `ModelNameRx` | string | Receiver model name |
| `ModelTypeTx` | `"Dual model"` | `"Dual model"`, `"GetWave only"`, `"Init only"` |
| `ModelTypeRx` | `"Dual model"` | `"Dual model"`, `"GetWave only"`, `"Init only"` |
| `ModelsToExport` | `"Both Tx and Rx"` | `"Both Tx and Rx"`, `"Tx only"`, `"Rx only"` |
| `IBISFile` | `true` | Export `.ibs` file |
| `AMIFiles` | `true` | Export `.ami` files |
| `DLLFiles` | `true` | Export compiled DLL/SO |
| `LinuxCrossCompile` | `false` | Build Linux `.so` from Windows |
| `LinuxSourceCode` | `false` | Export Linux C source code |
| `Obfuscate` | `false` | Obfuscate executables (IP protection) |
| `TargetDir` | string | Output directory |
| `IBISFileName` | char | IBIS file name |
| `CornerFactor` | scalar | Corner factor (0-50) |
| `BitsToIgnoreTx` | integer | Bits to skip in Tx time-domain sim |
| `BitsToIgnoreRx` | integer | Bits to skip in Rx time-domain sim |
| `CheckAMIValue` | `true` | Validate input string against IBIS standard |
| `QuietStatus` | `false` | Suppress verbose output |

### Methods

| Method | Description |
|--------|-------------|
| `export(AMIExport)` | Export with current settings |
| `getExportSettings(AMIExport)` | Display current settings |

### Full Workflow Example

```matlab
% 1. Design and export to Simulink
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE('TapWeights', [-0.1 0.8 -0.1])}), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE, serdes.DFECDR}), ...
    'SymbolTime', 100e-12, ...
    'SamplesPerSymbol', 16);
exportToSimulink(sys);

% 2. Configure and export programmatically
AMIExport = serdes.AMIExport("untitled");
AMIExport.ModelsToExport = "Both Tx and Rx";
AMIExport.ModelTypeTx = "Init only";
AMIExport.ModelTypeRx = "Dual model";
AMIExport.DLLFiles = true;
AMIExport.LinuxCrossCompile = true;
AMIExport.TargetDir = fullfile(pwd, "export");
AMIExport.Obfuscate = false;

% 3. Review and export
getExportSettings(AMIExport);
export(AMIExport);
```

### Repeater Configurations (Redriver and Retimer)

`ModelConfiguration` controls the IBIS model type:

| Config | Use Case | Typical Blocks | CDR? |
|--------|----------|----------------|------|
| `"TxAndRx"` | Standard endpoint | FFE + CTLE + DFECDR | Yes |
| `"Redriver"` | Linear repeater | FFE + CTLE + VGA (no CDR) | No |
| `"Retimer"` | Regenerating repeater | FFE + CTLE + DFECDR | Yes |
| `"IO"` | I/O buffer model | Varies | Varies |

**Key behavior:** For `"Redriver"` and `"Retimer"`, the export generates
separate Tx and Rx DLLs and `.ami` files, but `AMIExport.export()` builds
only the Tx DLL in a single pass. To get the Rx DLL, either:
1. Call `export()` twice (once with `"Tx only"`, once re-generating Rx via `slbuild`), or
2. Use `slbuild(mdl + "/Rx")` directly to generate Rx code, then compile.

#### Redriver Design Pattern

A Redriver is a linear repeater — no CDR, no data recovery. It amplifies and
equalizes the signal without retiming. Use CTLE + VGA (Variable Gain Amplifier)
on the Rx side, with no DFECDR block.

```matlab
% Redriver: linear amplifier (CTLE + VGA, no CDR)
% Rx side: CTLE for frequency-dependent EQ, VGA for flat gain
sysRD = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE('TapWeights', [-0.1 0.8 -0.1])}), ...
    'RxModel', Receiver('Blocks', ...
        {serdes.CTLE('Specification', "DC Gain and AC Gain", 'DCGain', 0, 'ACGain', 10), ...
         serdes.VGA('Gain', 1.5)}), ...
    'SymbolTime', 100e-12, 'SamplesPerSymbol', 16, 'Modulation', 2);
exportToSimulink(sysRD);

ae = serdes.AMIExport("untitled");
ae.ModelConfiguration = "Redriver";
ae.TargetDir = fullfile(pwd, "export_redriver");
export(ae);  % builds AMI/IBIS/DLL for Tx; Rx code requires slbuild
```

**Design considerations for Redrivers:**
- VGA gain compensates for insertion loss without frequency shaping
- CTLE provides frequency-dependent equalization (peaking at Nyquist)
- No DFE or CDR — jitter passes through (jitter amplification is a concern)
- Typical use: PCIe/USB mid-board repeaters for long backplane traces

#### Retimer Design Pattern

A Retimer recovers the clock and data, then retransmits — it includes CDR and
DFE for full signal regeneration. Jitter is cleaned (not passed through).

```matlab
% Retimer: regenerating repeater (full CDR + DFE)
% Rx side: CTLE + DFECDR with adaptation for clock/data recovery
sysRT = SerdesSystem(...
    'TxModel', Transmitter('Blocks', ...
        {serdes.FFE('TapWeights', [-0.1 0.7 -0.2])}), ...
    'RxModel', Receiver('Blocks', ...
        {serdes.CTLE('Specification', "DC Gain and AC Gain", ...
            'DCGain', 0, 'ACGain', 12, 'PeakingFrequency', 14e9), ...
         serdes.DFECDR('Mode', 2, 'TapWeights', zeros(1, 5), ...
            'SymbolTime', 1/28e9, 'Modulation', 4)}), ...
    'SymbolTime', 1/28e9, 'SamplesPerSymbol', 16, 'Modulation', 4);
exportToSimulink(sysRT);

ae = serdes.AMIExport("untitled");
ae.ModelConfiguration = "Retimer";
ae.ModelTypeTx = "Dual model";
ae.ModelTypeRx = "Dual model";
ae.TargetDir = fullfile(pwd, "export_retimer");
export(ae);
```

**Design considerations for Retimers:**
- Full signal regeneration — jitter is cleaned, not amplified
- CDR loop bandwidth determines jitter transfer characteristics
- DFE in adaptive mode (Mode=2) handles varying channel conditions
- Typical use: PCIe 5.0/6.0 retimers, 400G Ethernet, USB4

#### Redriver vs Retimer Selection Guide

| Criterion | Redriver | Retimer |
|-----------|----------|---------|
| Latency | Low (~1 UI) | Higher (~100s of UI for CDR lock) |
| Jitter | Passes through (amplifies) | Cleans (CDR filtering) |
| Power | Lower | Higher |
| Complexity | Simpler (no CDR) | More complex |
| Channel loss budget | Moderate (< 20 dB) | High (> 20 dB) |
| Standard compliance | Simpler AMI model | Full AMI with Init + GetWave |

### Batch Export Script

```matlab
models = {"pcie5_link", "cei56g_link", "usb4_link"};
configs = {"Dual model", "Dual model", "Init only"};

for i = 1:numel(models)
    load_system(models{i});
    ae = serdes.AMIExport(models{i});
    ae.ModelsToExport = "Both Tx and Rx";
    ae.ModelTypeRx = configs{i};
    ae.DLLFiles = true;
    ae.LinuxCrossCompile = true;
    ae.TargetDir = fullfile(pwd, "export", models{i});
    export(ae);
    close_system(models{i}, 0);
end
```

---

## slbuild (R2025b and earlier)

For releases before R2026a, use `slbuild` with Simulink Coder and Embedded Coder.

### Prerequisites

| Requirement | Why |
|-------------|-----|
| Simulink Coder | Code generation from Simulink model |
| Embedded Coder | Standalone executable / shared library build |
| C/C++ compiler | MSVC (Windows), GCC (Linux), or MinGW |
| Configured Simulink model | Must have AMI parameter tree set up |

## Workflow

### Step 1: Design and Export

```matlab
% Design the SerDes system
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE('TapWeights', [-0.1 0.8 -0.1])}), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE, serdes.DFECDR}), ...
    'SymbolTime', 100e-12, ...
    'SamplesPerSymbol', 16, ...
    'Modulation', 2);

% Export to Simulink — creates a model with Tx, Rx, and Configuration blocks
exportToSimulink(sys);
mdl = 'untitled';  % default model name
```

### Step 2: Configure AMI Parameters

Before building, the AMI parameter tree must be configured. This is typically
done once via the IbisAmiManager GUI, then saved in the Simulink model.
The configuration persists in the model file (`.slx`), so subsequent builds
via `slbuild` reuse it automatically.

For first-time configuration:
1. Open the exported Simulink model
2. Double-click the Configuration block
3. Click "Open SerDes IBIS-AMI Manager"
4. Configure: AMI parameter tree, IBIS component/model/pin data, output paths
5. Click "Apply" to save configuration to the model (do not need to "Generate" from GUI)
6. Save the model

### Step 3: Build Programmatically

```matlab
% Build Tx and Rx AMI models
% Note: slbuild produces .ami/.ibs/.dll only when IbisAmiManager has been
% configured and saved in the model. Without configuration, slbuild
% generates only the .dll/.so (code generation without AMI metadata).
slbuild([mdl '/Tx']);
slbuild([mdl '/Rx']);

% Output directory structure (with IbisAmiManager configured):
%   <modelName>_build/
%   ├── Tx/
%   │   ├── <TxModelName>.ami
%   │   ├── <TxModelName>.ibs
%   │   └── <TxModelName>.dll  (or .so on Linux)
%   └── Rx/
%       ├── <RxModelName>.ami
%       ├── <RxModelName>.ibs
%       └── <RxModelName>.dll  (or .so on Linux)
%
% Output directory structure (without IbisAmiManager configured):
%   <modelName>_build/
%   ├── Tx/
%   │   └── <TxModelName>.dll  (or .so on Linux)  ← no .ami or .ibs
%   └── Rx/
%       └── <RxModelName>.dll  (or .so on Linux)
```

### Step 4: Validate

Chain the compiled Tx and Rx DLLs and compare against the Simulink behavioral
reference from `analysis()`.

**DLL naming:** `export()` produces `serdes_tx_win64.dll` and `serdes_rx_win64.dll`.
The `LibraryName` is the filename without extension (`"serdes_tx_win64"`).
The `InputString` root name comes from the `.ami` file (`"(serdes_tx)"`).

```matlab
% Get reference from behavioral analysis
results = analysis(sys);
channelImpulse = results.impulse(:, 1);  % unequalized channel
simReference   = results.impulse(:, 2);  % equalized (behavioral)
N = numel(channelImpulse);
exportDir = fullfile(pwd, "export");

% Tx Init
txAmi = serdes.AMI;
txAmi.LibraryName = "serdes_tx_win64";
txAmi.LibraryPath = exportDir;
txAmi.SymbolTime = sys.SymbolTime;
txAmi.SampleInterval = sys.dt;
txAmi.InitOnly = true;
txAmi.RowSize = N;
txAmi.InputString = "(serdes_tx)";  % root name from .ami file
[~, txOut] = txAmi(zeros(N,1), channelImpulse, -1);

% Rx Init
rxAmi = serdes.AMI;
rxAmi.LibraryName = "serdes_rx_win64";
rxAmi.LibraryPath = exportDir;
rxAmi.SymbolTime = sys.SymbolTime;
rxAmi.SampleInterval = sys.dt;
rxAmi.InitOnly = true;
rxAmi.RowSize = N;
rxAmi.InputString = "(serdes_rx)";
[~, rxOut] = rxAmi(zeros(N,1), txOut, -1);

% Compare against behavioral reference — expect correlation ≈ 1.0
corrCoef = corrcoef(simReference, rxOut);
fprintf("Correlation: %.6f\n", corrCoef(1,2));
```

## GetWave Validation (Waveform Chain)

Init-only validation (above) checks the impulse path. For full Dual-model
validation, run the compiled DLLs in GetWave mode and compare against
Simulink Rx WaveOut (the preferred ground truth) or the system objects direct chain.

**Critical:** `serdes.AMI` passes `BlockSize` (default 1024) to `AMI_GetWave` —
only that many samples are processed per call. You **must** call the object in a
`for` loop with `BlockSize`-length chunks. The DLL state (memory handle) is
preserved between calls, just as Simulink processes the waveform block by block.
Also set `SkipFirstBlock = false` when calling from MATLAB (the default `true` is
for Simulink's internal signal buffering).

The strongest validation is sample-for-sample comparison against Simulink: log the
channel output (`chOut`) from Simulink and feed the exact same waveform to the DLL.
This should achieve perfect correlation (max diff at machine epsilon).

**Note:** The Rx output (`rxOut`) is logged by default after `exportToSimulink`. The
channel output (`chOut`) is **not** — you must manually enable signal logging on the
Analog Channel output port and name it `chOut`.

```matlab
% 1. Run Simulink to get ground-truth channel output and Rx output
mdl = "mySerDesModel";
load_system(mdl);
% NOTE: 'rxOut' is logged by default. For 'chOut', manually enable signal
% logging on the Analog Channel output port in the Simulink model.
set_param(mdl, 'SaveOutput', 'on', 'SaveFormat', 'Dataset');
simOut = sim(mdl);
chSimWave = simOut.logsout.get('chOut').Values.Data(:);
rxSimWave = simOut.logsout.get('rxOut').Values.Data(:);

% 2. Set up Rx DLL
results = analysis(sys);
chImpulse = results.impulse(:, 1);
N = numel(chImpulse);
exportDir = fullfile(pwd, "export");
blockSize = 1024;

rxAmi = serdes.AMI;
rxAmi.LibraryName    = "serdes_rx_win64";
rxAmi.LibraryPath    = exportDir;
rxAmi.SymbolTime     = sys.SymbolTime;
rxAmi.SampleInterval = sys.dt;
rxAmi.InitOnly       = false;       % Init + GetWave
rxAmi.SkipFirstBlock = false;       % required when calling from MATLAB
rxAmi.RowSize        = N;           % must match numel(chImpulse)
rxAmi.BlockSize      = blockSize;
rxAmi.InputString    = "(serdes_rx)";

% 3. Run DLL in chunked loop — one call per BlockSize chunk
Nsim = numel(chSimWave);
nPad = ceil(Nsim / blockSize) * blockSize;
wavePad = [chSimWave; zeros(nPad - Nsim, 1)];
waveOut = zeros(nPad, 1);
clockIn = -ones(blockSize, 1);

for k = 1:nPad/blockSize
    idx = (k-1)*blockSize + (1:blockSize);
    [waveOut(idx), ~] = rxAmi(wavePad(idx), chImpulse, clockIn);
end
dllWave = waveOut(1:Nsim);

% 4. Verify sample-for-sample correlation
R = corrcoef(rxSimWave, dllWave);
fprintf("GetWave vs Simulink correlation: %.15f\n", R(1,2));  % expect 1.0
fprintf("Max abs diff: %.2e\n", max(abs(rxSimWave - dllWave)));

% 5. Analyze with eyeDiagramSI
eyeObj = eyeDiagramSI;
eyeObj.SampleInterval = sys.dt;
eyeObj.SymbolTime = sys.SymbolTime;
eyeObj.Modulation = sys.Modulation;
eyeObj(dllWave);
fprintf("AMI GetWave — EH: %.1f mV, EW: %.1f ps, COM: %.2f dB\n", ...
    eyeHeight(eyeObj)*1e3, eyeWidth(eyeObj)*1e12, com(eyeObj));
```

### System Objects Direct Chain

The same validation can be done using the system objects from `sys` directly,
without compiled DLLs. This exercises the behavioral MATLAB code path.

```matlab
% Extract blocks and set WaveType = "Sample"
txBlocks = sys.TxModel.Blocks;
rxBlocks = sys.RxModel.Blocks;
for i = 1:numel(txBlocks)
    txBlocks{i}.SymbolTime = sys.SymbolTime;
    txBlocks{i}.SampleInterval = sys.dt;
    txBlocks{i}.WaveType = "Sample";
end
for i = 1:numel(rxBlocks)
    rxBlocks{i}.SymbolTime = sys.SymbolTime;
    rxBlocks{i}.SampleInterval = sys.dt;
    rxBlocks{i}.WaveType = "Sample";
end

% Stream through Tx chain (FFE accepts full vector)
w = prbsWave;
for i = 1:numel(txBlocks)
    w = txBlocks{i}(w);
end

% Stream through Rx chain — DFECDR/DFE require sample-by-sample
for i = 1:numel(rxBlocks)
    block = rxBlocks{i};
    if isa(block, 'serdes.DFECDR') || isa(block, 'serdes.DFE')
        wOut = zeros(size(w));
        for k = 1:numel(w)
            wOut(k) = block(w(k));
        end
        w = wOut;
    else
        w = block(w);
    end
end

% Analyze
eyeObj2 = eyeDiagramSI;
eyeObj2.SampleInterval = sys.dt;
eyeObj2.SymbolTime = sys.SymbolTime;
eyeObj2.Modulation = sys.Modulation;
eyeObj2(w);
fprintf("SysObj chain — EH: %.1f mV, EW: %.1f ps, COM: %.2f dB\n", ...
    eyeHeight(eyeObj2)*1e3, eyeWidth(eyeObj2)*1e12, com(eyeObj2));
```

## Toolchain Selection

The compiler used for DLL/SO generation is controlled by MATLAB's MEX
configuration. Check and change the active toolchain:

```matlab
% Check current C compiler
mex -setup C

% List available compilers
compilersC = mex.getCompilerConfigurations('C');
disp({compilersC.Name}')
```

### Supported Toolchains

| Platform | Toolchain | Output | Notes |
|----------|-----------|--------|-------|
| Windows | Microsoft Visual C++ (MSVC) | `.dll` | Default on Windows with Visual Studio |
| Windows | MinGW-w64 GCC | `.dll` | Free alternative; install via Add-Ons |
| Linux | GCC | `.so` | Default on Linux |
| Cross-compile | Linux cross-compiler | `.so` | Build Linux `.so` from Windows (see below) |

### Cross-Compilation for Linux `.so`

Build Linux-compatible `.so` files from a Windows machine using the
SerDes cross-compiler utility:

```matlab
% One-time setup — downloads and configures Linux GCC toolchain
% Takes ~2.5 hours, requires ~12.5 GB disk space
serdes.utilities.createCrossCompiler

% After setup, select the cross-compiler toolchain in IbisAmiManager
% or set it programmatically before slbuild:
%   Model Configuration Parameters > Code Generation > Toolchain
%   Select: "SerDes Linux Cross-Compiler"
```

## AMI Parameter Access (Programmatic)

Each SerDes block in the Simulink model exposes `*AMI` suffix parameters that
control which parameters appear in the exported `.ami` file. These are
accessible via `get_param`/`set_param`.

### Reserved AMI Parameter Names

The IBIS standard defines reserved parameter names that the framework manages
automatically. Do not use these as custom parameter names:

| Parameter | Description |
|-----------|-------------|
| `Init_Returns_Impulse` | `True` if Init modifies the impulse response |
| `GetWave_Exists` | `True` if the model implements GetWave |
| `Use_Init_Output` | `True` to use Init impulse for statistical analysis |
| `Max_Init_Aggressors` | Max number of aggressor channels for Init |
| `Ignore_Bits` | Number of initial bits to discard in GetWave |

These are set via `IbisAmiManager` or `serdes.AMIExport` model type settings —
not directly in the `.ami` file.

```matlab
% Check which FFE parameters will be exported to AMI
get_param('untitled/Tx/FFE', 'ModeAMI')         % 'on' or 'off'
get_param('untitled/Tx/FFE', 'TapWeightsAMI')   % 'on' or 'off'

% CTLE AMI parameters
get_param('untitled/Rx/CTLE', 'ModeAMI')
get_param('untitled/Rx/CTLE', 'ConfigSelectAMI')
get_param('untitled/Rx/CTLE', 'SliceSelectAMI')

% DFECDR AMI parameters
get_param('untitled/Rx/DFECDR', 'ModeAMI')
get_param('untitled/Rx/DFECDR', 'TapWeightsAMI')
get_param('untitled/Rx/DFECDR', 'PhaseOffsetAMI')
get_param('untitled/Rx/DFECDR', 'ReferenceOffsetAMI')

% Disable a parameter from AMI export
set_param('untitled/Tx/FFE', 'ModeAMI', 'off');
```

With R2026a, `serdes.AMIExport` handles the full export — no need for
internal APIs. The `*AMI` flags and block parameters persist in the model,
so `AMIExport.export()` picks them up automatically.

## Batch Build Script Example

```matlab
% Batch-build AMI models for multiple configurations
models = {"pcie5_link", "cei56g_link", "usb4_link"};
subsystems = {"Tx", "Rx"};

for i = 1:numel(models)
    mdl = models{i};
    load_system(mdl);
    for j = 1:numel(subsystems)
        fprintf("Building %s/%s...\n", mdl, subsystems{j});
        slbuild([mdl '/' subsystems{j}]);
    end
    close_system(mdl, 0);
end
fprintf("All builds complete.\n");
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `slbuild` error: "No compiler found" | No C compiler configured | Run `mex -setup C` and select a compiler |
| `slbuild` error: "License checkout failed" | Missing Simulink Coder or Embedded Coder | Install required toolboxes |
| `.so` needed but `.dll` generated | Building on Windows without cross-compiler | Set up cross-compiler via `serdes.utilities.createCrossCompiler` |
| AMI parameters missing in output | Configuration block not saved | Open IbisAmiManager, click Apply, save model |
| AMI parameter typo uses default silently | Parameter name mismatch in `.ami` file | AMI parameter name typos do NOT throw errors — the DLL silently uses defaults. Always validate parameter names against the `.ami` file and compare Init output against known-good reference |
| DLL loads in MATLAB but fails in EDA tool | 32-bit vs 64-bit DLL mismatch | EDA tools (ADS, Sigrity, HyperLynx) may require 32-bit or 64-bit DLLs. Check the EDA tool's documentation. Build both via separate MSVC targets or use `serdes.AMIExport` with appropriate toolchain |
| Build succeeds but DLL fails validation | Model changed after last IbisAmiManager config | Re-open IbisAmiManager, verify settings, Apply, rebuild |
| `slbuild` generates `.dll` but no `.ami`/`.ibs` | IbisAmiManager never configured on this model | Open IbisAmiManager, configure AMI parameter tree + IBIS data, Apply, save model, rebuild |
| `'Tx.bat' is not recognized` after `slbuild` or `export()` | Windows `NoDefaultCurrentDirectoryInExePath=1` prevents `.bat` files from being found in the current directory | See **Build Fails: Tx.bat Not Recognized** below |
| `serdes.AMI` error: "Unable to resolve 'lib.pointer'" | MATLAB Interface to Shared C Libraries component not installed | Install via Add-On Explorer: search "MATLAB Interface to Shared C Libraries" |
| DLL loads but `InputString` root name mismatch | Using model name as root instead of default `serdes_tx`/`serdes_rx` | Use `"(serdes_tx)"` or `"(serdes_rx)"` — or extract from `.ami` file via `generateDefaultInputString` |
| GetWave output only processes first 1024 samples, rest is passthrough | Passing full waveform in a single call with default `BlockSize=1024` | Call `serdes.AMI` in a `for` loop with `BlockSize`-length chunks. `AMI_GetWave` processes exactly `BlockSize` samples per call. State is preserved between calls via the DLL memory handle |
| GetWave first block is passthrough | `SkipFirstBlock` defaults to `true` (Simulink buffering) | Set `SkipFirstBlock = false` when calling from MATLAB |
| MATLAB crash (access violation) in AMI_Init | `RowSize` does not match the impulse array length | Always set `RowSize = numel(impulse)` — mismatched sizes cause buffer overrun in the DLL |

### Build Fails: Tx.bat Not Recognized

`export()` and `slbuild` generate `.bat` files (e.g., `Tx.bat`, `setup_msvc.bat`)
in the build directory and call them without path prefixes. When the Windows
environment variable `NoDefaultCurrentDirectoryInExePath` is set to `1`, `cmd.exe`
refuses to find `.bat` files in the current directory — causing the build to fail:

```
'Tx.bat' is not recognized as an internal or external command
```

This is common in enterprise environments with security hardening, and also
occurs when MATLAB is launched from Git Bash (which sets `SHELL` to bash).

**Root cause:** `NoDefaultCurrentDirectoryInExePath=1` is a Windows security
setting that prevents `cmd.exe` from searching `.` for executables. The build
system calls `Tx.bat` which calls `setup_msvc.bat` — both without `.\` prefixes.

**Fix:** Clear the env var before `export()` or `slbuild`:

```matlab
% Save and clear the security setting
origVal = getenv('NoDefaultCurrentDirectoryInExePath');
setenv('NoDefaultCurrentDirectoryInExePath', '');

% Run export — both Tx and Rx build successfully
ae = serdes.AMIExport(mdl);
ae.ModelsToExport = "Both Tx and Rx";
ae.DLLFiles = true;
ae.TargetDir = fullfile(pwd, "export");
export(ae);

% Restore
setenv('NoDefaultCurrentDirectoryInExePath', origVal);
```

**Note:** `setenv('SHELL', '')` alone is NOT sufficient — the `SHELL` variable
is not the root cause. The `.bat` resolution is blocked by the Windows security
setting regardless of which shell MATLAB uses.

## Pattern: Export to Simulink

```matlab
exportToSimulink(sys);
% Then: open model → Configuration block → "Open SerDes IBIS-AMI Manager"
% → configure AMI parameters + IBIS component/pin data → Generate
```

## Pattern: Validate Compiled AMI DLL/SO

```matlab
results = analysis(sys);
chImpulse = results.impulse(:, 1);  % unequalized channel
N = numel(chImpulse);
exportDir = fullfile(pwd, "export");

% LibraryName = DLL filename without .dll (export() produces serdes_tx_win64.dll)
% InputString root = .ami file root name (serdes_tx)
txAmi = serdes.AMI;
txAmi.LibraryName = "serdes_tx_win64";  txAmi.LibraryPath = exportDir;
txAmi.SymbolTime = sys.SymbolTime;      txAmi.SampleInterval = sys.dt;
txAmi.InitOnly = true;  txAmi.RowSize = N;  txAmi.InputString = "(serdes_tx)";
[~, txImp] = txAmi(zeros(N, 1), chImpulse, -1);

rxAmi = serdes.AMI;
rxAmi.LibraryName = "serdes_rx_win64";  rxAmi.LibraryPath = exportDir;
rxAmi.SymbolTime = sys.SymbolTime;      rxAmi.SampleInterval = sys.dt;
rxAmi.InitOnly = true;  rxAmi.RowSize = N;  rxAmi.InputString = "(serdes_rx)";
[~, rxImp] = rxAmi(zeros(N, 1), txImp, -1);

R = corrcoef(rxImp, results.impulse(:, 2));
fprintf("Init correlation: %.6f\n", R(1, 2));  % expect ≈ 1.0

% GetWave validation — chunked loop (requires manual signal logging on chOut)
% Log Analog Channel output in Simulink as 'chOut', Rx output as 'rxOut'
blockSize = 1024;
rxAmiGW = serdes.AMI;
rxAmiGW.LibraryName = "serdes_rx_win64";  rxAmiGW.LibraryPath = exportDir;
rxAmiGW.SymbolTime = sys.SymbolTime;      rxAmiGW.SampleInterval = sys.dt;
rxAmiGW.InitOnly = false;       rxAmiGW.SkipFirstBlock = false;
rxAmiGW.RowSize = N;            rxAmiGW.BlockSize = blockSize;
rxAmiGW.InputString = "(serdes_rx)";

Nsim = numel(chSimWave);  % chSimWave from Simulink logsout 'chOut'
nPad = ceil(Nsim / blockSize) * blockSize;
wavePad = [chSimWave; zeros(nPad - Nsim, 1)];
waveOut = zeros(nPad, 1);  clockIn = -ones(blockSize, 1);
for k = 1:nPad/blockSize
    idx = (k-1)*blockSize + (1:blockSize);
    [waveOut(idx), ~] = rxAmiGW(wavePad(idx), chImpulse, clockIn);
end
dllWave = waveOut(1:Nsim);
R = corrcoef(rxSimWave, dllWave);  % rxSimWave from Simulink logsout 'rxOut'
fprintf("GetWave vs Simulink: %.15f\n", R(1, 2));  % expect 1.0
```

## Pattern: Programmatic AMI Generation

```matlab
% R2026a+: Full programmatic control via serdes.AMIExport
AMIExport = serdes.AMIExport("mySerDesModel");
AMIExport.ModelsToExport = "Both Tx and Rx";
AMIExport.DLLFiles = true;
AMIExport.TargetDir = fullfile(pwd, "export");
export(AMIExport);  % generates .ami, .ibs, .dll/.so
```

----

Copyright 2026 The MathWorks, Inc.
----
