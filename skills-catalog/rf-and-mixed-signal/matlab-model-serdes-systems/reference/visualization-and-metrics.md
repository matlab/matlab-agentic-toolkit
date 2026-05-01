# Visualization and Metrics

Plot methods, metrics extraction, eye diagram analysis, and jitter decomposition
for SerDes systems. Covers both statistical (`analysis()` path) and time-domain
(`eyeDiagramSI` path) workflows.

## SerdesSystem Plot Methods

All plot methods render into the **current axes**. They work with `subplot`,
`tiledlayout`/`nexttile`, or standalone `figure`. All auto-call `analysis()` if
needed — no prerequisite.

| Method | What It Shows | X-Axis | Traces |
|--------|--------------|--------|--------|
| `plotStatEye(sys)` | Statistical eye heatmap + contours | ps | Image + N-1 eye contour pairs (PAM-N) |
| `plotImpulse(sys)` | Impulse response | ns | Unequalized + Equalized (+ FEXT/NEXT with crosstalk) |
| `plotPulse(sys)` | Pulse response | ns | Unequalized + Equalized |
| `plotAlignedPulse(sys)` | Pulse aligned to cursor | UI | Unequalized + Equalized |
| `plotWavePattern(sys)` | PRBS waveform | ns | Unequalized + Equalized |
| `analysisReport(sys)` | Text summary to command window | — | Not a figure — prints EH/EW/COM/VEC + adapted params |

### Multi-Panel Layouts

```matlab
% tiledlayout — preferred for multi-panel
figure; tiledlayout(1, 2);
nexttile; plotStatEye(sysA); title("Config A");
nexttile; plotStatEye(sysB); title("Config B");
sgtitle("Side-by-Side Comparison");

% subplot works too
figure;
subplot(1, 2, 1); plotStatEye(sysA); title("Config A");
subplot(1, 2, 2); plotStatEye(sysB); title("Config B");

% All plot methods work the same way
figure; tiledlayout(2, 2);
nexttile; plotImpulse(sys);      title("Impulse");
nexttile; plotPulse(sys);        title("Pulse");
nexttile; plotAlignedPulse(sys); title("Aligned Pulse (UI)");
nexttile; plotWavePattern(sys);  title("PRBS Waveform");
```

### Crosstalk Traces

With crosstalk enabled (ICN or multi-port S-parameters), `plotImpulse` adds
FEXT and NEXT traces automatically — 6 traces total:

- Unequalized primary, Equalized primary
- Unequalized FEXT, Equalized FEXT
- Unequalized NEXT, Equalized NEXT

Other plot methods show only primary (victim) traces.

## Metrics from analysis()

After `analysis(sys)`, metrics are on `sys.Metrics.summary`:

| Field | Unit | Notes |
|-------|------|-------|
| `COMestimate` | dB | Channel Operating Margin |
| `EH` | volts | Eye Height — multiply by 1e3 for mV |
| `EW` | picoseconds | Eye Width — already scaled, do NOT multiply by 1e12 |
| `VEC` | percent | Vertical Eye Closure |
| `eyeLinearity` | ratio | 1.0 = ideal (PAM4+) |

**PAM-N returns N-1 values** per metric (e.g., PAM4 returns 3 EH values, one per
eye). Index with `EH(2)` for the center (worst) eye.

```matlab
results = analysis(sys);
m = sys.Metrics.summary;
fprintf("COM: %.2f dB, EH: %.1f mV, EW: %.1f ps\n", ...
    m.COMestimate, m.EH(2)*1e3, m.EW(2));
```

### analysisReport Output

`analysisReport(sys)` prints a formatted text summary to the command window:
- Eye Height/Width/Area per eye (Upper, Center, Lower for PAM4)
- COM, VEC, eyeLinearity
- Adapted parameter values (CTLE ConfigSelect, DFE TapWeights, CDR Phase)
- Interior DFE state (thresholds, counters, frequency estimates)

### optPulseMetric (LTI Only)

Computes metrics from the equalized pulse response — no jitter, no noise.
Use for quick LTI design exploration; use `sys.Metrics.summary` for
jitter-aware metrics.

```matlab
results = analysis(sys);
eqPulse = results.pulse(:, 2);  % column 2 = equalized
metrics = optPulseMetric(eqPulse, samplesPerSymbol, sampleInterval, targetBER);
fprintf("COM: %.1f dB, EH: %.1f mV, EW: %.1f ps\n", ...
    metrics.maxCOM, metrics.maxEyeHeight * 1e3, metrics.eyeWidth * 1e12);
```

## eyeDiagramSI (R2024a+)

System object that builds a 2-D eye histogram from time-domain waveform data.
Provides measurement methods for eye metrics, bathtub curves, and compliance
testing.

### Setup and Usage

```matlab
eyeObj = eyeDiagramSI;
eyeObj.SampleInterval = dt;       % sample interval (seconds)
eyeObj.SymbolTime = symbolTime;   % symbol period (seconds)
eyeObj.Modulation = modulation;   % 2 = NRZ, 4 = PAM4, etc.
eyeObj(waveform);                 % step — NO output capture
```

**Critical:** Do NOT name the variable `eye` — it shadows MATLAB's built-in
`eye()` matrix function. Use `eyeObj` instead.

The step call has **no output argument**. It updates internal state (histogram).
Capturing the output errors:

```matlab
% WRONG — stepImpl has no output
result = eyeObj(waveform);  % ERROR: Too many output arguments

% CORRECT — call without output, then read metrics
eyeObj(waveform);
eh = eyeHeight(eyeObj);
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `SampleInterval` | 1 | Time between samples (seconds) |
| `SymbolTime` | 8 | Symbol period (seconds) |
| `Modulation` | 2 | Number of symbol levels |
| `ClockMode` | `"Auto"` | Clock recovery: `"Auto"`, `"Clocked"`, `"Ideal"`, `"Convolved"` |
| `PhaseDetector` | `"BangBang"` | CDR algorithm: `"BangBang"`, `"BaudRateTypeA"`, `"None"` |
| `SymbolsPerDiagram` | 2 | Eye width in symbol periods |
| `TimeBins` | 255 | Histogram time resolution |
| `AmplitudeBins` | 255 | Histogram voltage resolution |
| `AmplitudeLimits` | [] | Voltage range `[min max]` — auto if empty |
| `SymbolThresholds` | [] | Decision thresholds — auto for PAM4 |

### Measurement Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `eyeHeight(eye)` | scalar or vector | Vertical eye opening (V). PAM-N returns N-1 values |
| `eyeWidth(eye)` | scalar or vector | Horizontal eye opening (seconds) |
| `eyeArea(eye)` | scalar or vector | Area of eye opening (V*s) |
| `com(eye)` | scalar | Channel operating margin (dB) |
| `vec(eye)` | scalar | Vertical eye closure (dB) — `20*log10(amplitude/eyeHeight)`. Note: different unit than `Metrics.summary.VEC` (percent) |
| `eyeLinearity(eye)` | scalar | PAM4 eye linearity (1.0 = ideal) |
| `risetime(eye)` | scalar | Rise time from eye diagram |
| `falltime(eye)` | scalar | Fall time from eye diagram |
| `eyeCenter(eye)` | struct | Center point coordinates |
| `eyeCrossing(eye)` | struct | Crossing point coordinates |
| `eyeAmplitude(eye)` | scalar | Peak-to-peak eye amplitude |
| `eyeLevels(eye)` | struct | Symbol level statistics |
| `margin(eye, mask)` | struct | Compliance margin against `eyeMask` |
| `bathtub(eye)` | — | Plot bathtub curves |
| `slice(eye, ...)` | vector | Extract histogram slice |

### Plotting

```matlab
figure;
plot(eyeObj);                  % 2-D eye diagram with colormap
title("Eye Diagram Title");   % title() works on the axes
```

### eyeDiagramSI vs pulse2stateye

| Feature | `eyeDiagramSI` | `pulse2stateye` |
|---------|---------------|-----------------|
| Input | Time-domain waveform | Pulse response (column vector) |
| Method | Histogram accumulation | Statistical convolution |
| Jitter | Captured from waveform | Not included (LTI only) |
| Clock recovery | Built-in CDR | None |
| Streaming | Can call step() multiple times | Single call |
| Metrics | Rich method set (COM, VEC, margins) | Use `optPulseMetric` separately |
| Compliance | `margin()` with `eyeMask` | Manual |
| Best for | Post-equalization waveform analysis | Quick LTI design exploration |

## Custom Statistical Eye Rendering

Use `pulse2stateye` to build a statistical eye matrix for custom visualization:

```matlab
results = analysis(sys);
eqPulse = results.pulse(:, 2);
[statEye, vAxis, tAxis] = pulse2stateye(eqPulse, samplesPerSymbol, modulation);

figure;
imagesc(tAxis * 1e12, vAxis * 1e3, statEye);
colormap(serdes.utilities.SignalIntegrityColorMap);
colorbar;
axis xy;
xlabel("Time (ps)"); ylabel("Voltage (mV)");
title("Statistical Eye");
```

**Colormap convention:** Use `serdes.utilities.SignalIntegrityColorMap` (not
`hot` or `parula`) for statistical eye plots. Always add `colorbar`.

## jitter (R2024b+)

Function that decomposes jitter from time-domain waveforms into standard
IBIS/JEDEC jitter components.

### Basic Usage

```matlab
% With SampleInterval and SymbolTime (suppress plots for scripting)
J = jitter(waveform, SampleInterval=dt, SymbolTime=symbolTime, Plot=false);

% With explicit time vector
J = jitter(timeVec, waveform, SymbolTime=symbolTime, Plot=false);

% With reference waveform (for ISI separation) — plots enabled
J = jitter(timeVec, waveform, timeRef, waveRef, Plot="on");
```

### Built-In Jitter Plots

When `Plot=true` (default) or `Plot="on"`, `jitter()` creates a 7-panel figure
showing PDF histograms for each jitter component: TJ, RJ, DJ, SJ, DDJ, DCD, ISI.
Each panel shows timing error on the x-axis and PDF estimate on the y-axis.

Set `Plot=false` in scripts to suppress automatic histogram figures. When running
in automated pipelines or MCP evaluation, always use `Plot=false` to avoid
unwanted figure windows.

### Output Structure Fields

| Field | Unit | Description |
|-------|------|-------------|
| `TJrms` | seconds | Total jitter (RMS) |
| `TJpkpk` | seconds | Total jitter (peak-to-peak) |
| `RJrms` | seconds | Random jitter (RMS) |
| `DJrms` | seconds | Deterministic jitter (RMS) |
| `DJpkpk` | seconds | Deterministic jitter (peak-to-peak) |
| `DDJrms` | seconds | Data-dependent jitter (RMS) |
| `DDJpkpk` | seconds | Data-dependent jitter (peak-to-peak) |
| `DCDrms` | seconds | Duty cycle distortion (RMS) |
| `DCDpkpk` | seconds | Duty cycle distortion (peak-to-peak) |
| `ISIrms` | seconds | Inter-symbol interference jitter (RMS) |
| `ISIpkpk` | seconds | Inter-symbol interference jitter (peak-to-peak) |
| `SJa` | seconds | Sinusoidal jitter amplitude |
| `SJf` | Hz | Sinusoidal jitter frequency |
| `SJp` | radians | Sinusoidal jitter phase |

**Critical:** Field names use `rms`/`pkpk` suffixes — not plain `TJ`, `RJ`, etc.

### Name-Value Options

| Name | Default | Description |
|------|---------|-------------|
| `SampleInterval` | — | Sample period for uniformly sampled data |
| `SymbolTime` | — | Symbol period |
| `SymbolThresholds` | auto | Decision thresholds for edge detection |
| `Plot` | `true` | Display jitter histogram plots |
| `Frequencies` | 1 | Max sinusoidal jitter frequencies to detect |
| `PastSymbols` | 31 | Symbols before edge for DDJ correlation |
| `FutureSymbols` | auto | Symbols after edge for DDJ correlation |
| `DCDMethod` | `"oddeven"` | DCD measurement: `"oddeven"` or `"risefall"` |

### Sinusoidal Jitter Detection Limitation

The `jitter()` function's sinusoidal jitter (SJ) detection works best with a single
dominant SJ frequency. When multiple SJ frequencies are present, set `Frequencies`
to the expected count. With no sinusoidal jitter present, the detected `SJa` may
be nonzero but small — treat values below 0.01 UI as noise floor artifacts.

## PRBS Waveform Generation

When generating time-domain waveforms via `pulse2wave`, the PRBS order and symbol
count are user-configurable. Default to PRBS-10 (1023 symbols) if unspecified, but
always offer the choice. Longer sequences improve jitter statistics but increase
computation time.

```matlab
prbsOrder = 10;
nSymbols = 2^prbsOrder - 1;  % 1023 symbols
prbsSeq = prbs(prbsOrder, nSymbols * samplesPerSymbol);
wave = pulse2wave(eqPulse, prbsSeq, samplesPerSymbol);
```

When comparing across multiple analysis paths (statistical, Simulink `sim()`,
system objects chain, AMI DLL chain), use the **same PRBS sequence and length**
so results are directly comparable.

## Compliance Testing

Use `eyeMask` with `eyeDiagramSI.margin()` for standards-based pass/fail testing:

```matlab
% Create eye mask for compliance testing
mask = eyeMask;
mask.MaskType = "Hexagonal";                  % or "Rectangular"
mask.EyeHeightThreshold = 15e-3;              % 15 mV minimum eye opening
mask.EyeWidthThreshold = 0.3;                 % 0.3 UI minimum width
mask.SymbolTime = symbolTime;

% Run margin check against the mask
result = margin(eyeObj, mask);
fprintf("Margin: %.2f dB, Pass: %s\n", result.Margin, string(result.Pass));
```

`eyeMask` defines the compliance region. `margin()` returns the distance (in dB) to
the mask boundary. Positive margin = pass; negative = fail.

For CDR jitter tolerance (JTOL) compliance testing, see the Simulink-based
`simulinkJTOLController` workflow (requires Simulink + Parallel Computing Toolbox).

## Bathtub Curves

Bathtub curves show BER vs timing offset — the horizontal eye margin at each BER level.

```matlab
% Generate bathtub curve from eyeDiagramSI
figure;
bathtub(eyeObj);
title("Bathtub Curve");
```

`bathtub(eyeObj)` plots the bathtub curve directly. The curve shows BER on a log
scale (y-axis) vs timing offset in UI (x-axis), with the characteristic bathtub
shape where the minimum BER corresponds to the optimal sampling point.

## COM Waterfall (Per-Stage Contribution)

To understand how each equalization stage contributes to COM, run analysis with
progressively more EQ stages enabled:

```matlab
% Build configurations with increasing equalization
configs = {
    "Channel only",    {serdes.PassThrough},                  {};
    "FFE only",        {ffe},                                {};
    "FFE+CTLE",        {ffe},                                {ctle};
    "FFE+CTLE+DFE",    {ffe},                                {ctle, dfecdr};
};
comValues = zeros(size(configs, 1), 1);

for k = 1:size(configs, 1)
    sys = SerdesSystem(...
        'TxModel', Transmitter('Blocks', configs{k, 2}), ...
        'RxModel', Receiver('Blocks', configs{k, 3}), ...
        'ChannelData', channel, ...
        'SymbolTime', symbolTime, 'SamplesPerSymbol', 16, ...
        'Modulation', modulation, 'BERtarget', 1e-6);
    sys.ChannelData.ChannelLossFreq = 1 / (2 * symbolTime);
    analysis(sys);
    comValues(k) = sys.Metrics.summary.COMestimate;
end

% Plot waterfall
figure;
bar(comValues);
set(gca, "XTickLabel", configs(:, 1));
ylabel("COM (dB)"); title("EQ Stage Contribution");
```

This reveals which stage provides the most margin improvement and whether
any stage is counterproductive (e.g., CTLE at low loss or with PAM8+).

## Advanced Visualization Patterns

### 3D Surface Plot (COM vs Two Parameters)

Visualize COM across a 2-D parameter sweep as a 3D surface:

```matlab
% Sweep FFE pre-cursor and CTLE AC gain
preRange = -0.20:0.02:0;
acRange = 0:2:20;
comSurf = zeros(numel(acRange), numel(preRange));

for i = 1:numel(acRange)
    for j = 1:numel(preRange)
        pre = preRange(j);
        main = 1 - abs(pre) - 0.15;  % post fixed at -0.15
        ffe = serdes.FFE("TapWeights", [pre main -0.15]);
        ctle = serdes.CTLE("Specification", "DC Gain and AC Gain", ...
            "DCGain", 0, "ACGain", acRange(i));
        sysT = SerdesSystem('ChannelData', channel, ...
            'TxModel', Transmitter('Blocks', {ffe}), ...
            'RxModel', Receiver('Blocks', {ctle, dfecdr}), ...
            'SymbolTime', symbolTime, 'SamplesPerSymbol', 16, ...
            'Modulation', modulation);
        sysT.ChannelData.ChannelLossFreq = 1 / (2 * symbolTime);
        analysis(sysT);
        comSurf(i, j) = sysT.Metrics.summary.COMestimate;
    end
end

figure;
surf(preRange, acRange, comSurf);
xlabel("FFE Pre-Cursor"); ylabel("CTLE AC Gain (dB)"); zlabel("COM (dB)");
title("COM Surface: FFE Pre vs CTLE AC Gain");
colormap(turbo); colorbar;
```

### BER Contour Overlay on Eye Diagram

Overlay BER contour lines on an eye diagram using `eyeDiagramSI`:

```matlab
% Build eye diagram
eyeObj = eyeDiagramSI;
eyeObj.SampleInterval = dt;
eyeObj.SymbolTime = symbolTime;
eyeObj.Modulation = modulation;
eyeObj(waveform);

% Plot with BER contours
figure;
plot(eyeObj);
hold on;

% Extract histogram and compute BER contours
hist2d = eyeObj.EyeHistogram;
totalHits = sum(hist2d(:));
berLevels = [1e-3, 1e-6, 1e-9, 1e-12];
contour(hist2d / totalHits, berLevels, "LineWidth", 1.5);
hold off;
title("Eye Diagram with BER Contours");
```

### DFE Tap Adaptation Trajectory

Track DFE tap convergence over time using the system objects chain:

```matlab
% Setup DFECDR in adaptive mode
dfecdrAdapt = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
    "SymbolTime", symbolTime, "SampleInterval", dt, ...
    "Modulation", modulation, "WaveType", "Sample", ...
    "EqualizationGain", 9.6e-4);  % 10x default for faster convergence

% Stream sample-by-sample and record taps
nSamples = numel(waveform);
tapHistory = zeros(nSamples, 5);
for k = 1:nSamples
    [~, taps] = dfecdrAdapt(waveform(k));
    tapHistory(k, :) = taps;
end

% Plot adaptation trajectory
symbolIndices = (1:nSamples) / samplesPerSymbol;
figure;
plot(symbolIndices, tapHistory, "LineWidth", 1.2);
xlabel("Symbols"); ylabel("Tap Weight");
title("DFE Tap Adaptation Trajectory");
legend("Tap " + (1:5), "Location", "best");
```

## Statistical vs Time-Domain COM Discrepancy

Statistical COM (`sys.Metrics.summary.COMestimate`) and time-domain COM
(`com(eyeObj)`) measure the same concept but differ in methodology:

| Source | Method | Includes |
|--------|--------|----------|
| `sys.Metrics.summary.COMestimate` | Statistical convolution of pulse response | Optimal DFE taps, BER target, jitter model |
| `com(eyeObj)` | Histogram analysis of time-domain waveform | Actual CDR recovery, finite PRBS, waveform jitter |

Expect 1-3 dB difference. Statistical COM is typically higher because it uses
the optimal sampling phase and mathematically optimal DFE taps. Time-domain COM
reflects real CDR tracking and finite adaptation convergence.

Use statistical COM for design-space exploration (fast, repeatable). Use
time-domain COM for final validation (realistic, includes implementation effects).

## Pattern: Side-by-Side Eye Comparison

```matlab
% Compare two configurations side by side using tiledlayout
% plotStatEye renders into the current axes — works with subplot and tiledlayout
configs = {10, "10 dB"; 20, "20 dB"};  % {loss, label}
figure; tiledlayout(1, size(configs, 1));
for c = 1:size(configs, 1)
    sys = SerdesSystem(...
        'TxModel', Transmitter('Blocks', {serdes.FFE('TapWeights', [-0.1 0.7 -0.2])}, ...
            'AnalogModel', AnalogModel('R', 50, 'C', 1e-13), ...
            'RiseTime', 1e-11, 'VoltageSwingIdeal', 1), ...
        'RxModel', Receiver('Blocks', ...
            {serdes.CTLE('Specification', "DC Gain and AC Gain", ...
                          'DCGain', 0, 'ACGain', 12, 'PeakingFrequency', 14e9), ...
             serdes.DFECDR('TapWeights', zeros(1, 5), 'Mode', 2)}, ...
            'AnalogModel', AnalogModel('R', 50, 'C', 2e-13)), ...
        'ChannelData', ChannelData('ChannelLossdB', configs{c, 1}, ...
            'ChannelLossFreq', 14e9, 'ChannelDifferentialImpedance', 100), ...
        'JitterAndNoise', JitterAndNoise('RxClockMode', 'clocked'), ...
        'SymbolTime', 35.71e-12, 'SamplesPerSymbol', 16, ...
        'Modulation', 4, 'Signaling', 'Differential', 'BERtarget', 1e-6);
    results = analysis(sys);
    m = sys.Metrics.summary;
    nexttile; plotStatEye(sys);
    title(sprintf("%s — COM %.1f dB, EH %.1f mV", configs{c, 2}, m.COMestimate, m.EH(2)*1e3));
    for p = 1:numel(results.outparams)
        if isstruct(results.outparams{p}) && isfield(results.outparams{p}, 'DFECDR')
            fprintf("%s DFE taps: %s\n", configs{c, 2}, mat2str(results.outparams{p}.DFECDR.TapWeights, 3));
        end
    end
end
```

All `SerdesSystem` plot methods (`plotStatEye`, `plotImpulse`, `plotPulse`, `plotAlignedPulse`, `plotWavePattern`) render into the current axes. Use `tiledlayout`/`nexttile` or `subplot` for multi-panel layouts.

## Pattern: Waveform Eye Diagram and Jitter Analysis

```matlab
% Build eye diagram from time-domain waveform (R2024a+)
eyeObj = eyeDiagramSI;
eyeObj.SampleInterval = dt;
eyeObj.SymbolTime = symbolTime;
eyeObj.Modulation = modulation;
eyeObj(waveform);  % step — NO output capture

% Read metrics
eh = eyeHeight(eyeObj);    % PAM-N returns N-1 values (one per eye)
ew = eyeWidth(eyeObj);
comVal = com(eyeObj);
fprintf("Eye Height: %.1f mV, Eye Width: %.1f ps, COM: %.2f dB\n", ...
    eh(1) * 1e3, ew(1) * 1e12, comVal);

% Jitter decomposition (R2024b+)
% Requires a long waveform (>200 symbols) — use pulse2wave with PRBS-10+
prbsSeq = prbs(10, (2^10 - 1) * samplesPerSymbol);
wave = pulse2wave(eqPulse, prbsSeq, samplesPerSymbol);
J = jitter(wave, SampleInterval=dt, SymbolTime=symbolTime, Plot=false);
fprintf("TJ: %.2f ps (pk-pk), RJ: %.2f ps (RMS), DDJ: %.2f ps (pk-pk)\n", ...
    J.TJpkpk * 1e12, J.RJrms * 1e12, J.DDJpkpk * 1e12);
```

----

Copyright 2026 The MathWorks, Inc.
----
