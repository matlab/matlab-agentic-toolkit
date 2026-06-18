# Reference: Validation Detail (Phases 7-8 Detail)

Loaded by the validate skill for extended code examples.

## Zero-Crossing Capture (Triggered Subsystem Method)

**Preferred** over logging full waveform. More precise, more memory-efficient.

```matlab
% Create Triggered Subsystem
trigSys = [model '/ZC Capture'];
add_block('simulink/Ports & Subsystems/Triggered Subsystem', trigSys);
set_param(trigSys, 'Position', [700, 100, 880, 200]);
set_param([trigSys '/Trigger'], 'TriggerType', 'rising');

% Remove default In1/Out1 wiring
delete_line(trigSys, 'In1/1', 'Out1/1');
delete_block([trigSys '/In1']);
delete_block([trigSys '/Out1']);

% Add Digital Clock -> To Workspace inside
add_block('simulink/Sources/Digital Clock', [trigSys '/Clock']);
set_param([trigSys '/Clock'], 'SampleTime', '-1', ...
    'Position', [50, 50, 130, 80]);
add_block('simulink/Sinks/To Workspace', [trigSys '/Log ZC']);
set_param([trigSys '/Log ZC'], 'VariableName', 'zc_times', ...
    'SaveFormat', 'Array', 'Position', [200, 50, 300, 80]);
add_line(trigSys, 'Clock/1', 'Log ZC/1');

% Connect VCO output to trigger port
rt = {'autorouting', 'smart'};
add_line(model, 'VCO/1', 'ZC Capture/Trigger', rt{:});
```

After simulation, retrieve timestamps: `zc_times = simOut.zc_times;`
(goes to simOut with `ReturnWorkspaceOutputs='on'`, P31).

## PLL Testbench Configuration for Architecture Blocks (P43)

```matlab
tbPath = [model '/PLL Testbench'];
add_block('msbPllMeasurements/PLL Testbench', tbPath, ...
    'Position', [80, 50, 430, 350]);

% Set via mask to avoid callback conflicts
mask = Simulink.Mask.get(tbPath);
mask.getParameter('PhaseNoiseFreqOffset').Value = mat2str(Foffset);
mask.getParameter('TargetPhaseNoiseVector').Value = mat2str(phaseNoise);
mask.getParameter('ResBandwidth').Value = num2str(min(Foffset)/2);

set_param(tbPath, ...
    'Fo',                   num2str(fRef), ...     % Reference freq (NOT fVco)
    'ExpectedFreq',         num2str(fVCO), ...
    'TargetFreq',           num2str(fVCO), ...
    'SampleRate',           num2str(8*fVCO), ...
    'SpectralAverages',     '2', ...
    'HoldOffTime',          num2str(5*lock_time), ...
    'PlotAndLogPhaseNoise', 'on', ...
    'PhaseNoiseOption',     'on');
```

## Retrieving Testbench Results from Model Workspace (P53)

```matlab
% Get SID suffix for variable naming
sid = Simulink.ID.getSID(tbPath);
sidParts = split(sid, ':');
sidSuffix = sidParts{2};

% Read results from model workspace
mdlWs = get_param(model, 'ModelWorkspace');
freq = evalin(mdlWs, ['Frequency_' sidSuffix]);
lockTime = evalin(mdlWs, ['LockTime_' sidSuffix]);
```

## Post-Simulation Results Plotting (P68)

MCP preserves only one figure. Create all results in a single tiledlayout:

```matlab
set(0, 'DefaultFigureVisible', 'on');
pnOut = evalin('base', 'pll_phase_noise_out');
f = pnOut.PnFOffset; pn = pnOut.Pn;
validIdx = f > 0; f = f(validIdx); pn = pn(validIdx);

fig = figure('Name', 'PLL Results', 'Position', [100 150 1200 500], 'Visible', 'on');
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile;
semilogx(pnOut.phaseNoiseFreq, pnOut.phaseNoiseLevel, 'b-o', 'LineWidth', 2);
xlabel('Frequency Offset (Hz)'); ylabel('Phase Noise (dBc/Hz)');
title('Measured Phase Noise'); grid on;

nexttile;
semilogx(f, pn, 'b-', 'LineWidth', 1.2);
xlabel('Frequency Offset (Hz)'); ylabel('Phase Noise (dBc/Hz)');
title('Full Spectrum (Spur Analysis)'); grid on;
drawnow;
```

## Dual-Modulus Prescaler Spur Analysis (P66)

```matlab
% Sub-harmonic spurs occur at fRef*k/N (especially fRef/P)
% Example: P=4, P+1=5, S=2, N=12 -> divide-by-50
% Spurs at 20 MHz (fRef/5), 40 MHz, 80 MHz in addition to fRef spur

% Include sub-harmonic frequencies in offset vector
fRef = 100e6; P = 4;
subHarmonics = fRef .* (1:P) ./ (P+1);  % [20e6 40e6 60e6 80e6]
Foffset = sort(unique([1e6 10e6 subHarmonics fRef 1.2*fRef]));

% Examine full spectrum for spurs
pnOut = evalin('base', 'pll_phase_noise_out');
semilogx(pnOut.PnFOffset, pnOut.Pn);  % 301-point array shows all spurs
```

---

Copyright 2026 The MathWorks, Inc.
