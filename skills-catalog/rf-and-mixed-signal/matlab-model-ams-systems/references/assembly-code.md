# Reference: Assembly Code Examples (Phases 3-4 Detail)

Loaded by the core skill when building or customizing PLL models.

## 3.1 Adding CP Broadband Noise (Post-Flatten)

After `editSystem`, inject noise between Charge Pump and Loop Filter.
Place blocks with NO overlap (P53):

```matlab
% Delete CP -> LF line (it branches to cp_out terminator too)
cpPH = get_param([blk '/Charge Pump'], 'PortHandles');
delete_line(get_param(cpPH.Outport(1), 'Line'));

% Add Sum block in the CP-to-LF gap
add_block('simulink/Math Operations/Add', [blk '/CP_Noise_Sum'], ...
    'Inputs', '+++', 'Position', [480, 55, 510, 115]);

% Add Band-Limited White Noise BELOW forward path
add_block('simulink/Sources/Band-Limited White Noise', ...
    [blk '/CP_Broadband_Noise'], 'Position', [380, 180, 460, 210]);

% Add CP Spur Source (Pulse Generator) BELOW broadband noise
add_block('simulink/Sources/Pulse Generator', ...
    [blk '/CP_Spur_Source'], 'Position', [380, 240, 460, 270]);

% Configure noise power from datasheet PNSYNTH
%   Si_cp = 10^((PNSYNTH + 10*log10(fPFD) - 10*log10(2*pi^2) + 20*log10(Icp))/10)
set_param([blk '/CP_Broadband_Noise'], ...
    'Cov', num2str(Si_cp), 'Ts', num2str(1/fPFD));

% Configure spur source (P54)
set_param([blk '/CP_Spur_Source'], ...
    'Amplitude', num2str(Icp * cp_mismatch_frac), ...
    'Period', num2str(1/fPFD), ...
    'PulseWidth', num2str(deadband_ns*1e-9/(1/fPFD)*100));

% Rewire
rt = {'autorouting', 'smart'};
add_line(blk, 'Charge Pump/1',        'CP_Noise_Sum/1',  rt{:});
add_line(blk, 'CP_Broadband_Noise/1', 'CP_Noise_Sum/2',  rt{:});
add_line(blk, 'CP_Spur_Source/1',     'CP_Noise_Sum/3',  rt{:});
add_line(blk, 'CP_Noise_Sum/1',       'Loop Filter/1',   rt{:});
add_line(blk, 'Charge Pump/1',        'cp_out/1',        rt{:});
```

## 3.2 Adding Reference Path (Post-Flatten or External)

Add before the architecture block's input port:

```
REFIN --> [x2 Doubler] --> [divR Counter] --> [div2 Divider] --> PLL/clk in
```

Output frequency: `f_PFD = f_REFIN * (1 + D) / (R * (1 + T))`

**Implementation (external to PLL block):**

```matlab
% Reference path parameters
fRefIn = 100e6;   % Crystal oscillator
R = 2;            % R-counter divider
D = 0;            % Doubler off (0) or on (1)
T = 0;            % RDIV2 off (0) or on (1)
fComp = fRefIn * (1 + D) / (R * (1 + T));  % = 50 MHz

% Add Fractional Clock Divider as R-counter (integer divide-by-R)
rBlk = [model '/R Counter'];
add_block('msbPllFoundation/Fractional Clock Divider with DSM', rBlk);
set_param(rBlk, 'N', num2str(R), 'Nmin', '1');
% DSM order = 1, but integer N means no fractional noise

% Wire: PLL Testbench output → R-counter → PLL input
add_line(model, 'PLL Testbench/1', 'R Counter/1', 'autorouting', 'smart');
add_line(model, 'R Counter/1', 'PLL/1', 'autorouting', 'smart');

% CRITICAL: Update PLL Testbench Fo to fRefIn (it generates the crystal freq)
set_param(tbBlk, 'Fo', num2str(fRefIn));

% CRITICAL: In-band noise penalty — effective N is now larger
N_eff = fVco / fComp;  % e.g., 6 GHz / 50 MHz = 120 (not 6 GHz / 100 MHz = 60)
% In-band PN ≈ PNSYNTH + 10*log10(fComp) + 20*log10(N_eff)
% Compare to no R-counter: 20*log10(120) - 20*log10(60) = +6 dB penalty
```

**When to use R-counter:**
- Channel spacing requires fComp < fRef (e.g., 200 kHz channels from 10 MHz ref → R=50)
- Datasheet specifies R > 1

**When to avoid:**
- fRef already equals desired fComp — use R=1 (direct)
- N is already large (>200) — R makes it worse

## 3.3 Adding RF Output Divider (Post-Flatten or External)

Post-VCO programmable divider after the architecture block's output:

```
PLL/clk out --> [RF Divider] --> RFOUT
```

Parameter: `RFDividerSelect` (popup: 1, 2, 4, 8, 16, 32, 64)

## 3.4 Feedback Select Mux

Only needed if the IC feeds back from the divided output instead of VCO.
This affects the effective N value:
- Fundamental: `N_eff = INT + FRAC/MOD`
- Divided: `N_eff = (INT + FRAC/MOD) * RF_DIV`

## 4.3 Foundation Block Assembly (Strategy B Full Code)

> **BATCH ALL COMMANDS BELOW INTO A SINGLE `mcp__matlab__evaluate_matlab_code` CALL.**
> Do not execute `add_block`, `set_param`, or `add_line` individually.

```matlab
% Create model
model = 'ADF4351_PLL';
new_system(model); open_system(model);

% Set solver (must be VariableStepDiscrete for MSB)
set_param(model, 'SolverType', 'Variable-step', ...
                 'Solver', 'VariableStepDiscrete');

% Add PLL Testbench (provides reference clock, measures VCO)
add_block('msbPllMeasurements/PLL Testbench', [model '/PLL Testbench']);
set_param([model '/PLL Testbench'], 'Position', [-360, 65, -80, 285]);

% Add foundation blocks -- forward path (horizontal row)
add_block('msbPllFoundation/PFD',           [model '/PFD']);
add_block('msbPllFoundation/Charge Pump',   [model '/Charge Pump']);
add_block('msbPllFoundation/Loop Filter',   [model '/Loop Filter']);
add_block('msbPllFoundation/Ring Oscillator VCO', [model '/VCO']);

set_param([model '/PFD'],         'Position', [45, 148, 210, 252]);
set_param([model '/Charge Pump'], 'Position', [320, 148, 420, 252]);
set_param([model '/Loop Filter'], 'Position', [490, 148, 590, 252]);
set_param([model '/VCO'],         'Position', [660, 148, 820, 252]);

% Add feedback path blocks -- below, mirrored for clean routing
add_block('msbPllFoundation/Fractional Clock Divider with DSM', ...
          [model '/Frac-N Divider']);
set_param([model '/Frac-N Divider'], 'Position', [340, 350, 500, 430]);
set_param([model '/Frac-N Divider'], 'BlockMirror', 'on');

add_block('simulink/Sources/Constant', [model '/N']);
set_param([model '/N'], 'Value', num2str(N));
set_param([model '/N'], 'Position', [545, 398, 595, 422]);
set_param([model '/N'], 'BlockMirror', 'on');

% Add Clock Jitter Measurement block
add_block('msbUtilities/Clock Jitter Measurement', [model '/Clock Jitter']);
set_param([model '/Clock Jitter'], ...
    'Frequency',    num2str(fVCO), ...
    'Threshold',    '0', ...
    'PeriodOption', 'on', ...
    'C2cOption',    'on', ...
    'DcdOption',    'off');
set_param([model '/Clock Jitter'], 'Position', [690, 310, 850, 410]);

% Clock Jitter Measurement outputs MUST be connected (P28)
add_block('simulink/Sinks/Display', [model '/Period Jitter']);
set_param([model '/Period Jitter'], 'Position', [900, 315, 1000, 345]);
add_block('simulink/Sinks/Display', [model '/C2C Jitter']);
set_param([model '/C2C Jitter'], 'Position', [900, 375, 1000, 405]);

% Connect blocks with smart autorouting
rt = {'autorouting', 'smart'};

add_line(model, 'PLL Testbench/1',   'PFD/1',            rt{:});
add_line(model, 'PFD/1',             'Charge Pump/1',    rt{:});
add_line(model, 'PFD/2',             'Charge Pump/2',    rt{:});
add_line(model, 'Charge Pump/1',     'Loop Filter/1',    rt{:});
add_line(model, 'Loop Filter/1',     'VCO/1',            rt{:});
add_line(model, 'VCO/1',             'Frac-N Divider/1', rt{:});
add_line(model, 'VCO/1',             'PLL Testbench/1',  rt{:});
add_line(model, 'VCO/1',             'Clock Jitter/1',   rt{:});
add_line(model, 'N/1',               'Frac-N Divider/2', rt{:});
add_line(model, 'Frac-N Divider/1',  'PFD/2',            rt{:});
add_line(model, 'Clock Jitter/1',    'Period Jitter/1',  rt{:});
add_line(model, 'Clock Jitter/2',    'C2C Jitter/1',     rt{:});
```

## 4.4 Set Block Parameters (Strategy B)

> **Include this in the SAME batched script as Section 4.3 above.**

```matlab
% VCO parameters (from datasheet noise table)
% Never use offsets below 100 kHz (P13) -- require extremely long sim times
Foffset    = [100e3 1e6 3e6 10e6];
phaseNoise = [-111 -134 -145 -152];
carrierFreq = 3.3e9;

set_param([model '/VCO'], ...
    'SpecifyUsing', 'Voltage sensitivity', ...
    'Kvco',       '40e6', ...
    'Fo',         num2str(carrierFreq), ...
    'Amplitude',  '1', ...
    'AddPhaseNoise', 'on', ...
    'Foffset',    mat2str(Foffset), ...
    'PhaseNoise', mat2str(phaseNoise));

% Estimate and apply PeriodJitter & CornerFrequency
[periodJitter, cornerFreq] = msblks.VCO.estimatePhaseNoiseCore(carrierFreq, Foffset, phaseNoise);
set_param([model '/VCO'], ...
    'PeriodJitter',    num2str(periodJitter), ...
    'CornerFrequency', num2str(cornerFreq), ...
    'FlickerExponent', '1.0');

% Charge pump impairments
cpMismatch_pct = 2;
set_param([model '/Charge Pump'], ...
    'OutputCurrent',            '2.5e-3', ...
    'EnableCurrentImpairments', 'on', ...
    'CurrentImbalance',         num2str(cpMismatch_pct/100 * 2.5e-3), ...
    'EnableTimingImpairments',  'off');

% Loop filter (3rd order passive)
set_param([model '/Loop Filter'], ...
    'FilterType', '3rd order passive', ...
    'C1', '1.31e-12', 'C2', '1.44e-11', 'C3', '9.41e-14', ...
    'R2', '1.33e4',   'R3', '1.7e5', ...
    'EnableImpairments', 'on', ...
    'Temperature', '25');

% N divider DSM order
set_param([model '/Frac-N Divider'], 'dsm', '3rd order');
```

---

Copyright 2026 The MathWorks, Inc.
