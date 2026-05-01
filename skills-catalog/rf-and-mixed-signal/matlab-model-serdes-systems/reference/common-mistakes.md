# Common Mistakes with SerDes Toolbox

37 documented anti-patterns when generating SerDes Toolbox code. Each shows
the wrong pattern, the error it causes, and the correct approach.

**Classification:**
- HARD ERROR — throws an exception
- SILENT FAIL — runs without error but produces wrong results
- LOGICAL ERROR — code works but violates IBIS-AMI semantics
- MISCONCEPTION — common false assumption about API behavior
- PERF BUG — code works but degrades signal quality metrics

## 1. TxModel/RxModel as Cell Arrays [HARD ERROR]

```matlab
% WRONG — TxModel is not a cell array
sys.TxModel = {serdes.FFE('TapWeights', [-0.1 0.8 -0.1])};

% CORRECT — use Transmitter/Receiver wrapper objects
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE('TapWeights', [-0.1 0.8 -0.1])}), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE, serdes.DFECDR}));
```

## 2. ChannelData.Loss — Wrong Property Name [SILENT FAIL]

```matlab
% WRONG — Loss is a property of serdes.ChannelLoss, not ChannelData
sys.ChannelData.Loss = 15;
sys.ChannelData.TargetFrequency = 14e9;

% CORRECT — ChannelData uses ChannelLossdB and ChannelLossFreq
sys.ChannelData.ChannelLossdB = 15;
sys.ChannelData.ChannelLossFreq = 14e9;
sys.ChannelData.ChannelDifferentialImpedance = 100;
```

## 2b. ChannelLossFreq Left at Default [SILENT FAIL]

```matlab
% WRONG — ChannelLossFreq defaults to 5 GHz, far below Nyquist for most links.
% At 28 GBaud, Nyquist=14 GHz. Specifying 15 dB at 5 GHz means loss at 14 GHz
% is ~40+ dB — the eye appears closed even with strong equalization.
sys.ChannelData.ChannelLossdB = 15;
% ChannelLossFreq is still 5 GHz (default) — channel is MUCH lossier than intended

% CORRECT — always set ChannelLossFreq to Nyquist (BaudRate / 2)
sys.ChannelData.ChannelLossdB = 15;
sys.ChannelData.ChannelLossFreq = 1 / (2 * sys.SymbolTime);  % Nyquist frequency
```

## 3. CTLE ACGain with Wrong Specification [SILENT FAIL]

```matlab
% WRONG — default Specification is "DC Gain and Peaking Gain", ACGain is ignored
ctle = serdes.CTLE('DCGain', 0, 'ACGain', 12);  % Warning: ACGain not relevant

% CORRECT — set Specification first
ctle = serdes.CTLE('Specification', "DC Gain and AC Gain", ...
                    'DCGain', 0, 'ACGain', 12);
```

## 4. Mode=2 on Blocks That Don't Support It [HARD ERROR]

```matlab
% WRONG — FFE and AGC only support Mode 0 and 1
txFFE = serdes.FFE;
txFFE.Mode = 2;  % ERROR: not a valid value

% CORRECT — only CTLE, DFECDR, and DFE support Mode=2 (Adaptive)
txFFE = serdes.FFE;
txFFE.Mode = 1;            % Fixed, exported as AMI parameter
rxDFECDR = serdes.DFECDR;
rxDFECDR.Mode = 2;         % Adaptive — requires Dual model
% Note: CDR.Mode is deprecated and will be removed in a future release
```

## 5. Init-Only Model with Adaptive Blocks [LOGICAL ERROR]

```matlab
% WRONG — DFECDR.Mode=2 (adaptive) but Init-Only model cannot run GetWave
% DFE taps stay at initial values, CDR never converges

% CORRECT — when any block uses Mode=2, configure a Dual model:
% R2026a+: set via serdes.AMIExport
AMIExport = serdes.AMIExport("myModel");
AMIExport.ModelTypeRx = "Dual model";  % Init_Returns_Impulse=true AND GetWave_Exists=true
export(AMIExport);
% R2025b and earlier: open IbisAmiManager GUI, set Init_Returns_Impulse=true AND GetWave_Exists=true
```

## 6. Row Vectors in Signal Conversion Functions [HARD ERROR]

```matlab
% WRONG — row vector causes error
impulse = zeros(1, 128);
impulse(1) = 1;
pulse = impulse2pulse(impulse, 16, 6.25e-12);  % ERROR

% CORRECT — use column vectors
impulse = zeros(128, 1);
impulse(1) = 1;
pulse = impulse2pulse(impulse, 16, 6.25e-12);  % OK
```

## 7. JitterAndNoise Rj Units [LOGICAL ERROR]

```matlab
% WRONG — treating Rj as peak-to-peak
jn = JitterAndNoise;
jn.Tx_Rj = 10e-12;  % If this is peak-to-peak, value is ~5x too high

% CORRECT — Rj is standard deviation per IBIS 7.0
jn = JitterAndNoise;
jn.Tx_Rj = 1e-12;   % 1 ps RMS (standard deviation)
jn.Tx_Dj = 5e-12;   % Dj IS peak-to-peak
```

## 8. Non-Existent IBIS Read/Write Functions [HARD ERROR]

```matlab
% WRONG — these functions do not exist in SerDes Toolbox
ibisData = readIBIS("model.ibs");
exportAMI(sys, "output.ami");
generateAMI(sys);

% CORRECT — IBIS-AMI generation requires a Simulink model
% Option A (R2026a+): serdes.AMIExport — fully programmatic
%   1. exportToSimulink(sys)
%   2. ae = serdes.AMIExport("modelName"); ae.DLLFiles = true; export(ae);
% Option B: IbisAmiManager GUI
%   1. exportToSimulink(sys)
%   2. Open IbisAmiManager from the Configuration block
%   3. Configure and Generate from within the app
% Option C: slbuild (R2025b and earlier, requires Simulink Coder + Embedded Coder)
%   1. exportToSimulink(sys)
%   2. Configure AMI settings (IbisAmiManager or programmatic)
%   3. slbuild('modelName/Tx') and slbuild('modelName/Rx')
% For loading compiled DLLs/SOs, use serdes.AMI
```

## 9. WaveType Not Set in MATLAB [SILENT FAIL]

```matlab
% WRONG — WaveType defaults to "Sample", impulse processing gives wrong result
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = 100e-12;
ffe.SampleInterval = 6.25e-12;
y = ffe(impulseResponse);  % Processes as time-domain samples

% CORRECT — set WaveType to "Impulse" for impulse processing
ffe = serdes.FFE('TapWeights', [-0.1 0.8 -0.1]);
ffe.SymbolTime = 100e-12;
ffe.SampleInterval = 6.25e-12;
ffe.WaveType = "Impulse";
y = ffe(impulseResponse);  % Correct impulse-domain processing
```

## 10. String Property Names in Transmitter Constructor [HARD ERROR]

```matlab
% WRONG — Transmitter rejects string property names
tx = Transmitter("Blocks", {serdes.FFE});  % ERROR: ismember fails on string

% CORRECT — use char vectors (single quotes) for Transmitter
tx = Transmitter('Blocks', {serdes.FFE});  % OK
% Note: Receiver("Blocks", ...) accepts strings fine; only Transmitter fails
% serdes.* block constructors and SerdesSystem also accept strings fine
```

## 11. analysis() Returns Nx2 Matrices, Not Vectors [HARD ERROR]

```matlab
% WRONG — treating results.pulse as a column vector
results = analysis(sys);
metrics = optPulseMetric(results.pulse, 16, sys.dt, 1e-6);  % ERROR: not a vector

% CORRECT — column 1 = unequalized, column 2 = equalized
eqPulse = results.pulse(:, 2);    % equalized pulse (column vector)
metrics = optPulseMetric(eqPulse, 16, sys.dt, 1e-6);  % OK
% Same for results.impulse and results.wave
```

## 12. optPulseMetric Does Not Include Jitter [LOGICAL ERROR]

```matlab
% WRONG — expecting optPulseMetric to reflect JitterAndNoise settings
sys.JitterAndNoise.Tx_Rj = 2e-12;
results = analysis(sys);
metrics = optPulseMetric(results.pulse(:, 2), 16, sys.dt, 1e-6);
% metrics.maxEyeHeight is IDENTICAL with or without jitter — it's LTI only

% CORRECT — use sys.Metrics for jitter-aware statistical eye metrics
analysis(sys);
eyeHeight = sys.Metrics.summary.EH;  % eye height at BERtarget, includes jitter
```

## 13. plotStatEye Renders into Current Axes [MISCONCEPTION]

```matlab
% WRONG assumption — plotStatEye does NOT create a tiledlayout.
% It renders into the current axes, so both title() and sgtitle() work.

% OK — title() works directly on the axes
plotStatEye(sys);
title("My Custom Title");

% OK — subplot and tiledlayout both work
figure; subplot(1,2,1); plotStatEye(sysA); title("Config A");
        subplot(1,2,2); plotStatEye(sysB); title("Config B");

% OK — tiledlayout works too
figure; tiledlayout(1,2);
nexttile; plotStatEye(sysA); title("Config A");
nexttile; plotStatEye(sysB); title("Config B");
```

## 14. JitterAndNoise Properties Are SimpleJitter Objects [HARD ERROR]

```matlab
% WRONG — jitter properties are SimpleJitter objects, not doubles
jn = JitterAndNoise;
jn.Tx_Rj = 1e-12;
rjVal = jn.Tx_Rj * 1e12;  % ERROR: "Invalid data type"

% CORRECT — use .Value to read; direct assignment auto-sets Include=true
rjVal = jn.Tx_Rj.Value * 1e12;  % OK
% Note: jn.Tx_Rj.Value = 1e-12 alone leaves Include=false (jitter ignored)
```

## 15. Wrong InputString Root Name for serdes.AMI [HARD ERROR]

```matlab
% WRONG — root name does not match Simulink model name
ami.InputString = "(mySerDesModel_Tx)";  % ERROR: root name mismatch

% CORRECT — exported DLLs use serdes_tx / serdes_rx as default root names
ami.InputString = "(serdes_tx)";   % Tx DLL
ami.InputString = "(serdes_rx)";   % Rx DLL
% Or use generateDefaultInputString to extract from .ami file
```

## 16. ChannelData Impulse Requires Constructor [SILENT FAIL]

```matlab
% WRONG — post-hoc assignment silently ignored, loss model runs
sys.ChannelData.Impulse = spCh.ImpulseResponse;
sys.ChannelData.dt = spCh.SampleInterval;

% CORRECT — pass Impulse and dt as constructor name-value pairs
channel = ChannelData("Impulse", spCh.ImpulseResponse, "dt", spCh.SampleInterval);
sys = SerdesSystem("ChannelData", channel, ...);
```

## 17. SParameterChannel Requires FileName Name-Value [HARD ERROR]

```matlab
% WRONG — positional syntax does not work
spCh = SParameterChannel("channel.s4p");

% CORRECT — use "FileName" name-value pair
spCh = SParameterChannel("FileName", "channel.s4p");
```

## 18. PeakingFrequency Left at Default (5 GHz) [PERF BUG]

```matlab
% WRONG — default PeakingFrequency is 5 GHz, only correct for ~10 Gbps NRZ
ctle = serdes.CTLE('Specification', "DC Gain and AC Gain", ...
    'DCGain', 0, 'ACGain', 10);  % PeakingFrequency = 5 GHz (default)

% CORRECT — set PeakingFrequency to Nyquist = 1/(2*SymbolTime)
% 56 Gbps PAM4 → SymbolTime=35.71 ps → Nyquist=14 GHz
ctle = serdes.CTLE('Specification', "DC Gain and AC Gain", ...
    'DCGain', 0, 'ACGain', 10, ...
    'PeakingFrequency', 1 / (2 * 35.71e-12));  % 14 GHz
% Impact: ~3 dB COM improvement on a 15 dB loss PAM4 channel
```

## 19. Fabricated set_param AMI Parameter Names [HARD ERROR]

```matlab
% WRONG — these set_param parameter names do not exist
set_param('model/Tx', 'AMIVersion', '7.0');
set_param('model/Tx', 'ExportAMI', 'on');
set_param('model/Rx', 'Description', 'My Rx Model');

% CORRECT — AMI export uses *AMI suffix on block property names
get_param('model/Tx/FFE', 'ModeAMI')          % 'on' or 'off'
get_param('model/Tx/FFE', 'TapWeightsAMI')    % 'on' or 'off'
get_param('model/Rx/CTLE', 'ConfigSelectAMI')  % 'on' or 'off'
set_param('model/Tx/FFE', 'ModeAMI', 'off');   % disable from AMI export
% AMI version, model type, IBIS metadata are set via IbisAmiManager or serdes.AMIExport
% NOT via set_param on the top-level model
```

## 20. Reading Adapted DFE Taps from Block Object [SILENT FAIL]

```matlab
% WRONG — block object retains INITIAL values, not adapted values
results = analysis(sys);
dfeTaps = sys.RxModel.Blocks{2}.TapWeights;  % Still zeros!

% CORRECT — adapted parameters are in results.outparams
% outparams is a cell array: one entry per datapath block (Tx first, then Rx)
results = analysis(sys);
for p = 1:numel(results.outparams)
    if isstruct(results.outparams{p}) && isfield(results.outparams{p}, 'DFECDR')
        dfeTaps = results.outparams{p}.DFECDR.TapWeights;  % Solver's adapted values
        phase = results.outparams{p}.DFECDR.Phase;          % Recovered clock phase
    end
end
% With FFE + CTLE + DFECDR: outparams{1}=FFE, outparams{2}=CTLE, outparams{3}=DFECDR
```

This is the most common source of "the DFE isn't working" confusion. The statistical
solver **does** optimize Mode=2 DFE taps, but writes results only to `outparams`.

## 21. Missing AnalogModel and JitterAndNoise [PERF BUG]

```matlab
% WRONG — bare Transmitter/Receiver omit analog termination and clock model
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE(...)}), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE(...), serdes.DFECDR(...)}), ...
    'SymbolTime', 35.71e-12, 'SamplesPerSymbol', 16, 'Modulation', 4);

% CORRECT — include AnalogModel and JitterAndNoise for realistic results
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {serdes.FFE(...)}, ...
        'AnalogModel', AnalogModel('R', 50, 'C', 1e-13), ...
        'RiseTime', 1e-11, 'VoltageSwingIdeal', 1), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE(...), serdes.DFECDR(...)}, ...
        'AnalogModel', AnalogModel('R', 50, 'C', 2e-13)), ...
    'JitterAndNoise', JitterAndNoise('RxClockMode', 'clocked'), ...
    'SymbolTime', 35.71e-12, 'SamplesPerSymbol', 16, ...
    'Modulation', 4, 'Signaling', 'Differential', 'BERtarget', 1e-6);
```

Without `AnalogModel`, the Tx/Rx termination is idealized (no parasitic capacitance).
Without `JitterAndNoise`, the clock model defaults may not match the intended analysis.
COM results differ by 1-2 dB between bare and fully-specified systems.

## 22. GPZ ConfigSelect ignored without Mode=1 [SILENT FAIL]

```matlab
% WRONG — ConfigSelect has no effect with default Mode=0
ctle = serdes.CTLE('Specification', "GPZ Matrix", ...
    'GPZ', gpzMatrix, 'ConfigSelect', 3);
% Always uses row 0 regardless of ConfigSelect value
```

```matlab
% CORRECT — Mode=1 enables ConfigSelect switching
ctle = serdes.CTLE('Specification', "GPZ Matrix", ...
    'GPZ', gpzMatrix, 'ConfigSelect', 3, 'Mode', 1);
```

With `Mode=0` (default), the CTLE uses only GPZ row 0 regardless of the
`ConfigSelect` value. Setting `Mode=1` (impulse processing / active filtering)
enables `ConfigSelect` to switch between GPZ rows. No warning is issued —
all rows appear to produce identical results.

## 23. SimpleJitter Include Defaults to False [SILENT FAIL]

```matlab
% WRONG — Include defaults to false, jitter value stored but excluded from analysis
sj = SimpleJitter;
sj.Value = 3e-12;
sj.Type = "Float";
jn.Tx_DCD = sj;      % Value is 3 ps but Include=false → analysis ignores it

% Also wrong — .Value assignment alone leaves Include=false
sj = jn.Tx_DCD;
sj.Value = 3e-12;    % Include is still false from default
jn.Tx_DCD = sj;      % no effect on analysis results
```

```matlab
% CORRECT — use direct scalar assignment (auto-sets Include=true)
jn.Tx_DCD = 3e-12;   % sets Value=3e-12, Include=true, Type="Float"

% Or construct SimpleJitter with Include=true explicitly
sj = SimpleJitter('Value', 3e-12, 'Include', true, 'Type', 'Float');
jn.Tx_DCD = sj;

% UI type also works — Value is in unit intervals, converted internally
sj = SimpleJitter('Value', 0.084, 'Include', true, 'Type', 'UI');
jn.Tx_DCD = sj;      % 0.084 UI → analysis converts using SymbolTime
```

When constructing `SimpleJitter` manually, `Include` defaults to `false`. The
value is stored on the object but excluded from `analysis()` — no warning, no
error. Direct scalar assignment (`jn.Tx_DCD = 3e-12`) is the safest approach
because it auto-sets `Include = true`. Both `Type = "Float"` (seconds) and
`Type = "UI"` (unit intervals) work correctly when `Include = true`.

## 24. Rx jitter (Rx_Rj/Dj/DCD/Sj) requires RxClockMode="clocked" [SILENT FAIL]

```matlab
% WRONG — Rx jitter has NO effect with ideal clock
jn = JitterAndNoise('RxClockMode', 'ideal');
jn.Rx_Rj = 2e-12;   % silently ignored
```

```matlab
% CORRECT — Rx jitter only affects analysis with clocked mode
jn = JitterAndNoise('RxClockMode', 'clocked');
jn.Rx_Rj = 2e-12;   % now degrades the eye
```

All Rx jitter parameters (`Rx_Rj`, `Rx_Dj`, `Rx_DCD`, `Rx_Sj`) are modeled as
clock jitter and only take effect when `RxClockMode = "clocked"`. In `"ideal"`
mode, these parameters are silently ignored. Note: Rx jitter and Rx Clock Recovery
jitter of the same type (e.g., `Rx_Rj` vs `Rx_Clock_Recovery_Rj`) produce
identical degradation — they both jitter the sampling clock.

## 25. Channel Impulse Not Scaled by dt in filter() [SILENT FAIL]

```matlab
% WRONG — impulse from analysis() is in V/s, amplitudes blow up by ~10^11
chImpulse = results.impulse(:, 1);
w = filter(chImpulse, 1, stimWave);  % output range: ±86 billion V

% CORRECT — multiply by dt to convert V/s → unitless FIR coefficients
w = filter(chImpulse * dt, 1, stimWave);  % output range: ±0.19 V
```

The channel impulse response from `analysis()` (and from `serdes.ChannelLoss.impulse`)
is in V/s (continuous-time units). When using it as FIR filter coefficients in
`filter()`, you must multiply by `dt` (the sample interval) to get the correct
discrete-time scaling. Without this, the convolution output is ~10^11× too large.
Verify: `sum(chImpulse * dt)` should be close to 1.0 (DC gain).

## 26. DFECDR Modulation Not Set for PAM-N in System Objects Chain [SILENT FAIL]

```matlab
% WRONG — DFECDR defaults to NRZ, PAM4 adaptation fails silently
dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
dfecdr.SymbolTime = symbolTime;
dfecdr.SampleInterval = dt;
dfecdr.WaveType = "Sample";
% Adapts as NRZ → eye stays closed for PAM4 input

% CORRECT — set Modulation explicitly for PAM-N
dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
dfecdr.SymbolTime = symbolTime;
dfecdr.SampleInterval = dt;
dfecdr.WaveType = "Sample";
dfecdr.Modulation = 4;  % PAM4 — required for correct adaptation
```

In Simulink, the DFECDR block inherits `Modulation` from the model workspace
automatically. In a MATLAB system objects chain, `Modulation` defaults to 2 (NRZ).
For PAM4 or higher, you must set it explicitly or the DFE decision thresholds
and CDR adaptation will be wrong, producing a closed or degraded eye.

## 27. pulse2wave Output Depends on Input Pattern — Not NRZ-Only [CORRECTED]

```matlab
% pulse2wave operates on whatever stimulus is provided
% Output modulation depends on the input pattern (NRZ or PAM-N)
prbsSeq = prbs(10, 1023 * samplesPerSymbol);
wave = pulse2wave(eqPulse, prbsSeq, samplesPerSymbol);

% For PAM-N eye analysis, use eyeDiagramSI with correct Modulation setting
eyeObj = eyeDiagramSI;
eyeObj.Modulation = modulation;
eyeObj.SampleInterval = dt;
eyeObj.SymbolTime = symbolTime;
eyeObj(wave);
```

`pulse2wave` convolves the pulse response with the stimulus pattern. The output
waveform has whatever modulation the input pattern encodes. For LTI pulse-based
metrics, use `optPulseMetric` which handles PAM-N natively.

## 28. DFECDR Mode=0 Is Passthrough in Sample Mode [SILENT FAIL]

```matlab
% WRONG — Mode=0 does NOT apply DFE correction in Sample mode
dfecdr = serdes.DFECDR('TapWeights', [-0.05 0.11 0.07 0.04 0.02], 'Mode', 0);
dfecdr.WaveType = "Sample";
y = zeros(size(w)); for k = 1:numel(w), y(k) = dfecdr(w(k)); end
% y ≈ w — DFE taps are ignored, signal passes through unchanged
```

```matlab
% CORRECT — use Mode=1 (fixed) or Mode=2 (adaptive) for DFE to function
dfecdr = serdes.DFECDR('TapWeights', [-0.05 0.11 0.07 0.04 0.02], 'Mode', 1);
dfecdr.WaveType = "Sample";
y = zeros(size(w)); for k = 1:numel(w), y(k) = dfecdr(w(k)); end
% y has DFE correction applied — eye opens
```

In Sample mode: Mode=0 is a complete passthrough (no DFE, no CDR). Mode=1 applies
the fixed tap weights + CDR. Mode=2 applies taps + CDR + adaptation. If you pre-load
adapted taps from `analysis()`, use Mode=1 or Mode=2 — Mode=0 silently ignores them.

## 29. DFECDR Adapted Taps Returned as Output, Not on Property [SILENT FAIL]

```matlab
% WRONG — TapWeights property always shows INITIAL values
dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
dfecdr.WaveType = "Sample";
for k = 1:numel(w), y(k) = dfecdr(w(k)); end
fprintf("Taps: %s\n", mat2str(dfecdr.TapWeights));  % always [0 0 0 0 0]
```

```matlab
% CORRECT — capture adapted taps from the SECOND output
dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
dfecdr.WaveType = "Sample";
for k = 1:numel(w), [y(k), adaptedTaps, phase] = dfecdr(w(k)); end
fprintf("Taps: %s\n", mat2str(adaptedTaps));  % shows actual adapted values
```

The DFECDR step function returns `[y, TapWeights, Phase, clkAMI, interior]`. The
adapted tap weights are the second output — the `TapWeights` property on the object
always retains its initial value. To monitor adaptation, capture the second output.

## 30. DFECDR Default EqualizationGain Too Slow for Short Waveforms [PERF BUG]

```matlab
% WRONG — default gain needs 80K+ symbols to converge
dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
% EqualizationGain = 9.6e-05 (default)
% After 20K symbols: taps reach only ~25% of target
```

```matlab
% CORRECT — increase gain for faster convergence in MATLAB chains
dfecdr = serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2);
dfecdr.EqualizationGain = 9.6e-04;  % 10x default
% After 20K symbols: taps reach ~100% of target
%
% Or: pre-load adapted taps from analysis() for instant convergence
adaptedTaps = results.outparams{end}.DFECDR.TapWeights;
dfecdr = serdes.DFECDR('TapWeights', adaptedTaps, 'Mode', 1);
```

The default `EqualizationGain` (9.6e-05) is tuned for Simulink's long continuous
simulations. In a MATLAB system objects chain with limited symbols, taps adapt too
slowly to converge. Either increase `EqualizationGain` by 10x or pre-load adapted
taps from `results.outparams` (fastest approach — no adaptation needed).

## 31. AMI GetWave Crashes MATLAB When Stimulus > Impulse Length [HARD ERROR]

```matlab
% WRONG — stimulus longer than impulse causes MATLAB process crash (segfault)
chImpulse = results.impulse(:, 1);   % e.g. 16253 samples
prbsWave = repelem(levels, sps);     % e.g. 16368 samples (longer!)
txAmi.RowSize = numel(prbsWave);
[out, ~] = txAmi(prbsWave, chImpulse, -1);  % CRASHES MATLAB — no error, process terminates
```

```matlab
% CORRECT — zero-pad impulse to match stimulus length
chImpulse = results.impulse(:, 1);
if numel(prbsWave) > numel(chImpulse)
    chImpulse = [chImpulse; zeros(numel(prbsWave) - numel(chImpulse), 1)];
end
txAmi.RowSize = numel(prbsWave);
[out, ~] = txAmi(prbsWave, chImpulse, -1);  % OK
```

The `serdes.AMI` system object in GetWave mode (`InitOnly = false`) crashes the
MATLAB process when the input waveform has more samples than the impulse response.
The boundary is exact: `impulseLen + 1` triggers the crash. There is no error
message — MATLAB terminates silently. Always zero-pad the impulse to at least
match the waveform length. This affects Init mode as well when RowSize exceeds
the impulse length.

## 32. Vendor AMI DLLs: serdes.AMI vs Simulink AMI Block [LOGICAL ERROR]

```matlab
% WRONG — serdes.AMI is for standalone validation, not Simulink integration
ami = serdes.AMI;
ami.LibraryName = "vendor_tx";
ami.LibraryPath = "C:/vendor/dlls";
% This works for quick Init/GetWave checks but does NOT integrate into
% a Simulink time-domain simulation

% CORRECT — for Simulink integration, use the AMI block in the testbench
% 1. Create testbench: exportToSimulink(sys)
% 2. Open Configuration block -> IbisAmiManager
% 3. Import vendor .ami/.ibs/.dll files for Tx and/or Rx
% 4. Run: out = sim(mdl)
%
% Use serdes.AMI only for standalone validation outside Simulink
% (e.g., comparing Init impulse response against behavioral reference)
```

---

## 33. Setting SamplesPerSymbol on serdes.DFECDR [HARD ERROR]

```matlab
% WRONG — SamplesPerSymbol is read-only (hidden, protected) on DFECDR
dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
    "SymbolTime", symbolTime, "SamplesPerSymbol", 16, "Modulation", 4);
% Error: Unable to set the 'SamplesPerSymbol' property ... because it is read-only

% CORRECT — omit SamplesPerSymbol; SerdesSystem sets it automatically
dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
    "SymbolTime", symbolTime, "Modulation", 4);

% For standalone use, set SampleInterval instead
dfecdr.SampleInterval = symbolTime / 16;
```

`SamplesPerSymbol` on `serdes.DFECDR` is a hidden, protected property — it exists but
cannot be set from the constructor or by assignment. When used inside `SerdesSystem`,
the system propagates `SampleInterval` automatically. For standalone datapath chains,
set `SampleInterval` explicitly instead.

---

## 34. serdes.Stimulus is a Streaming System Object [HARD ERROR]

```matlab
% WRONG — Stimulus has no SamplesPerSymbol property, and only 1 output
stim = serdes.Stimulus("SamplesPerSymbol", 16, "SymbolTime", symbolTime, ...
    "Modulation", 2, "PRBS", 13);
[wave, t, symbols] = stim();  % ERROR: not accessible / too many outputs
```

```matlab
% CORRECT — use SampleInterval, set Specification/Order, call in a loop
stim = serdes.Stimulus("SampleInterval", dt, "SymbolTime", symbolTime, ...
    "Modulation", 2);
stim.Specification = "PRBS";
stim.Order = 13;

numSamples = (2^13 - 1) * round(symbolTime / dt);
wave = zeros(numSamples, 1);
for k = 1:numSamples
    wave(k) = stim();
end
```

`serdes.Stimulus` produces **one sample per call** (streaming System object). There
is no vectorized mode. Key differences from what agents hallucinate:
- Property is `SampleInterval` (NOT `SamplesPerSymbol`)
- Set `Specification = "PRBS"` and `Order = N` (NOT `"PRBS"` as constructor arg)
- Only 1 output (NOT `[wave, time, symbols]`)
- Jitter units (`RjUnit`, `DjUnit`) default to `"UI"` — override with `"Seconds"`

---

## 35. Pre-loaded Taps Fail for PAM4 Time-Domain [SILENT FAIL]

```matlab
% WRONG — stat-analysis adapted taps assume different signal normalization
adaptedTaps = results.outparams{2}.DFECDR.TapWeights;
dfecdr = serdes.DFECDR("TapWeights", adaptedTaps, "Mode", 1, "Modulation", 4);
% Eye stays closed — taps from stat path don't transfer to PAM4 time-domain
```

```matlab
% CORRECT — use adaptive DFE with high gain for PAM4 waveform processing
dfecdr = serdes.DFECDR("TapWeights", zeros(1, 10), "Mode", 2, ...
    "EqualizationGain", 5e-3, "Modulation", 4);
% Measure converged portion only (skip first ~2000 symbols)
eyeObj(eqWave(convergedStart:end));
```

Pre-loaded taps from `analysis()` work well for **NRZ** time-domain but produce
closed eyes for **PAM4**. The statistical path uses normalized pulse-response math
that doesn't map to the actual voltage levels in sample-by-sample processing. For
PAM4 waveforms, always use adaptive Mode=2 with `EqualizationGain >= 5e-3`.

Additionally, at low loss (<=15 dB), CTLE over-boosts PAM4 in time-domain. Use
DFE-only (no CTLE) for better COM — this is the time-domain analog of gotcha #6.

---

## 36. Features That Do Not Exist in SerDes Toolbox [MISCONCEPTION]

These features are commonly hallucinated by agents but do not exist:

- **ADC receiver model**: No built-in ADC quantization block. Use a custom datapath block
  (`serdes.SerdesAbstractSystemObject`) to add quantization in `stepImpl`
- **Dual summing node DFE**: `serdes.DFECDR` has one summing node. For speculative DFE
  or loop-unrolled architectures, implement as a custom block
- **Half-rate CDR**: The CDR operates at full symbol rate. Half-rate timing requires
  custom implementation
- **CDR internal state access from statistical API**: `analysis()` returns adapted
  `Phase` in `outparams`, but CDR loop bandwidth, lock detector state, and jitter
  tracking metrics are only available in time-domain (Simulink or system objects chain)
- **Built-in compliance masks for IEEE/OIF standards**: `eyeMask` provides configurable
  mask geometry but does not include pre-defined IEEE 802.3 or OIF-CEI mask templates.
  Define mask parameters manually from the standard
- **`readIBIS`/`exportAMI`/`generateAMI` functions**: IBIS-AMI generation requires
  a Simulink model — see `serdes.AMIExport` or `IbisAmiManager`
- **Automatic FFE tap optimization in `analysis()`**: The statistical solver optimizes
  DFE taps (when Mode=2) but FFE taps are used as-is. For FFE optimization, use GA
  or manual sweep

## 37. JitterAndNoise Goes on SerdesSystem, Not Transmitter/Receiver [HARD ERROR]

```matlab
% WRONG — JitterAndNoise is not a Transmitter or Receiver property
sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {ffe}, 'JitterAndNoise', jn), ...  % ERROR
    ...);

% ALSO WRONG — cannot set post-hoc on Transmitter
sys.TxModel.JitterAndNoise = jn;  % ERROR: Unrecognized property
```

```matlab
% CORRECT — JitterAndNoise is a SerdesSystem property
jn = JitterAndNoise;
jn.Tx_Rj = 2e-12;

sys = SerdesSystem(...
    'TxModel', Transmitter('Blocks', {ffe}), ...
    'RxModel', Receiver('Blocks', {ctle, dfecdr}), ...
    'JitterAndNoise', jn, ...        % on SerdesSystem, not Tx/Rx
    'SymbolTime', symbolTime, ...
    'SamplesPerSymbol', 16);
```

`JitterAndNoise` contains BOTH Tx and Rx jitter parameters in a single object.
It is a property of `SerdesSystem`, not of `Transmitter` or `Receiver`.
Similarly, `AnalogModel` goes on `Transmitter`/`Receiver` (as `'AnalogModel'`
name-value pair), but `JitterAndNoise` goes on `SerdesSystem`.

---

## Summary

| Type | Count | Anti-Patterns |
|------|-------|---------------|
| HARD ERROR | 14 | #1, #4, #6, #8, #10, #11, #14, #15, #17, #19, #31, #33, #34, #37 |
| SILENT FAIL | 14 | #2, #2b, #3, #9, #16, #20, #22, #23, #24, #25, #26, #28, #29, #35 |
| LOGICAL ERROR | 5 | #5, #7, #12, #27, #32 |
| MISCONCEPTION | 2 | #13, #36 |
| PERF BUG | 3 | #18, #21, #30 |

Silent failures and logical errors are the most dangerous — no exception is thrown,
but the model produces incorrect results or violates IBIS-AMI semantics.

----

Copyright 2026 The MathWorks, Inc.
----
