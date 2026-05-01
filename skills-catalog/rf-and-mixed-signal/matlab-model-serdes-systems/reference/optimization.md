# Parameter Optimization

## Overview

Use `ga()` (Genetic Algorithm) from the Global Optimization Toolbox to optimize any
SerDes parameter — equalization, analog, or channel. GA handles quantized and
staircase fitness landscapes that defeat gradient-based optimizers like `fmincon`.

## Why GA, Not fmincon

SerDes parameter spaces are quantized (e.g., FFE taps at 0.02 resolution). Quantization
creates a staircase fitness function with zero gradient between steps. `fmincon` relies
on gradients, so it:

- Evaluates only ~3 points per parameter (initial + 2 finite-difference probes)
- Gets stuck at the initial guess because the gradient is zero
- Returns +0.00 dB improvement regardless of starting point

GA handles this natively because it uses population-based search, not gradients.

**If you must use fmincon:** Remove quantization from the inner fitness function and
apply it only to the final result. But this changes the optimization landscape and
may find solutions that degrade when re-quantized.

## Equalization Parameter Optimization

### FFE Tap Optimization (2-Variable Formulation)

Optimize `[pre, post]` with `main = 1 - |pre| - |post|` derived from normalization.

```matlab
% Fitness function: negative COM (GA minimizes)
fitnessFcn = @(x) -evalStatCOM(x, channelLoss, symbolTime);

% Bounds: pre in [-0.3, 0], post in [-0.5, 0]
lb = [-0.3, -0.5];
ub = [ 0.0,  0.0];

% Linear constraint: main >= 0.4 → |pre| + |post| <= 0.6
% Since pre <= 0 and post <= 0: -pre + (-post) <= 0.6 → [-1, -1]*x <= 0.6
A = [-1, -1];
b = 0.6;

% GA options
opts = optimoptions("ga", ...
    "PopulationSize", 50, ...
    "MaxGenerations", 30, ...
    "FunctionTolerance", 1e-3, ...
    "Display", "iter");

[xOpt, fOpt] = ga(fitnessFcn, 2, A, b, [], [], lb, ub, [], opts);
optCOM = -fOpt;
optTaps = [xOpt(1), 1 - abs(xOpt(1)) - abs(xOpt(2)), xOpt(2)];
```

### Fitness Function Template

```matlab
function comDB = evalStatCOM(x, channelLoss, symbolTime)
    pre = x(1);  post = x(2);
    main = 1 - abs(pre) - abs(post);

    % Quantize to hardware resolution
    tapRes = 0.02;
    taps = round([pre, main, post] / tapRes) * tapRes;

    ffe = serdes.FFE("TapWeights", taps);
    ctle = serdes.CTLE("Specification", "DC Gain and AC Gain", ...
        "DCGain", 0, "ACGain", 12, "PeakingFrequency", 1/(2*symbolTime));
    dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
        "SymbolTime", symbolTime, "Modulation", 4);

    channel = ChannelData();
    channel.ChannelLossdB = channelLoss;
    channel.ChannelLossFreq = 1 / (2 * symbolTime);

    sys = SerdesSystem("ChannelData", channel, ...
        'TxModel', Transmitter('Blocks', {ffe}, ...
            'AnalogModel', AnalogModel("R", 50, "C", 1e-13), ...
            'RiseTime', 12e-12, 'VoltageSwingIdeal', 1), ...
        'RxModel', Receiver('Blocks', {ctle, dfecdr}, ...
            'AnalogModel', AnalogModel("R", 50, "C", 2e-13)), ...
        'SymbolTime', symbolTime, 'SamplesPerSymbol', 16, 'Modulation', 4);

    analysis(sys);
    comDB = sys.Metrics.summary.COMestimate;
end
```

### Joint Multi-Parameter Optimization

Optimize FFE taps AND CTLE AC gain simultaneously:

```matlab
% 3 variables: [pre, post, acGain]
fitnessFcn = @(x) -evalJointCOM(x, channelLoss, symbolTime);

lb = [-0.3, -0.5, 0];    % pre, post, acGain
ub = [ 0.0,  0.0, 20];

% Main cursor constraint still applies to first 2 variables
A = [-1, -1, 0];
b = 0.6;

[xOpt, fOpt] = ga(fitnessFcn, 3, A, b, [], [], lb, ub, [], opts);
```

Joint optimization finds better solutions than sequential sweeps because it explores
the interaction between FFE pre-emphasis and CTLE boost.

### COM vs Eye Height as Fitness Metric

| Metric | Optimizes For | Best When |
|--------|--------------|-----------|
| COM | Noise margin, compliance | Targeting a spec (e.g., COM >= 3 dB) |
| Eye Height | Voltage margin | Maximizing signal quality |

COM and EH agree at low loss (< 15 dB) and high loss (> 30 dB) but diverge at
mid-loss (20-25 dB). At 20 dB loss, COM-optimal and EH-optimal FFE taps can differ
by 0.05-0.10 per tap.

For Eye Height fitness, use `min(EH)` for PAM4 (worst eye of the three):

```matlab
function ehV = evalStatEH(x, channelLoss, symbolTime)
    pre = x(1);  post = x(2);
    main = 1 - abs(pre) - abs(post);
    tapRes = 0.02;
    taps = round([pre, main, post] / tapRes) * tapRes;

    ffe = serdes.FFE("TapWeights", taps);
    ctle = serdes.CTLE("Specification", "DC Gain and AC Gain", ...
        "DCGain", 0, "ACGain", 12, "PeakingFrequency", 1/(2*symbolTime));
    dfecdr = serdes.DFECDR("Mode", 2, "TapWeights", zeros(1, 5), ...
        "SymbolTime", symbolTime, "Modulation", 4);

    channel = ChannelData();
    channel.ChannelLossdB = channelLoss;
    channel.ChannelLossFreq = 1 / (2 * symbolTime);

    sys = SerdesSystem("ChannelData", channel, ...
        'TxModel', Transmitter('Blocks', {ffe}, ...
            'AnalogModel', AnalogModel("R", 50, "C", 1e-13), ...
            'RiseTime', 12e-12, 'VoltageSwingIdeal', 1), ...
        'RxModel', Receiver('Blocks', {ctle, dfecdr}, ...
            'AnalogModel', AnalogModel("R", 50, "C", 2e-13)), ...
        'SymbolTime', symbolTime, 'SamplesPerSymbol', 16, 'Modulation', 4);

    analysis(sys);
    ehV = min(sys.Metrics.summary.EH);  % worst eye for PAM4
end
```

## Analog Parameter Optimization

Optimize rise time and parasitic capacitance for a given channel:

```matlab
% 2 variables: [riseTime_ps, txCp_fF]
fitnessFcn = @(x) -evalAnalogCOM(x, channelLoss, symbolTime);

lb = [5, 50];      % 5 ps rise time, 50 fF Tx capacitance
ub = [30, 500];    % 30 ps, 500 fF

[xOpt, fOpt] = ga(fitnessFcn, 2, [], [], [], [], lb, ub, [], opts);
```

This is useful for package/board design tradeoffs — finding the maximum tolerable
parasitic capacitance that still meets COM targets.

## Channel Parameter Optimization

### Maximum Tolerable Loss

Find the highest channel loss where COM stays above a threshold:

```matlab
% Single variable: channel loss in dB
fitnessFcn = @(loss) -loss;  % maximize loss (GA minimizes, so negate)

% Nonlinear constraint: COM >= 3 dB
nonlcon = @(loss) deal(3.0 - evalStatCOM_fixedEQ(loss, symbolTime), []);

lb = 5;
ub = 40;

[maxLoss, ~] = ga(fitnessFcn, 1, [], [], [], [], lb, ub, nonlcon, opts);
```

### Parameterized S-Parameter Channels

If you have a parameterized channel model (e.g., trace length, via stub depth),
optimize those physical parameters:

```matlab
% 2 variables: [traceLength_inches, viaStubDepth_mils]
fitnessFcn = @(x) -evalParameterizedChannel(x, eqConfig, symbolTime);

lb = [2, 5];     % 2 inches, 5 mils
ub = [20, 50];   % 20 inches, 50 mils

[xOpt, fOpt] = ga(fitnessFcn, 2, [], [], [], [], lb, ub, [], opts);
```

The fitness function generates an S-parameter model for each parameter combination
(e.g., using `rfckt.txline` or an external channel model), converts to impulse
response, and evaluates COM.

## Empirical Results

### FFE GA Optimization (56 Gbps PAM4, 3-tap FFE)

Sweep across 5:5:35 dB loss, 50 population, 30 generations:

| Loss (dB) | Baseline COM | GA-Optimized COM | Uplift |
|-----------|-------------|-----------------|--------|
| 5 | 13.85 | 14.19 | +0.34 |
| 10 | 9.67 | 10.22 | +0.55 |
| 15 | 6.94 | 8.85 | +1.91 |
| 20 | 3.39 | 7.40 | +4.01 |
| 25 | 0.88 | 5.07 | +4.19 |
| 30 | -2.93 | -0.37 | +2.56 |
| 35 | -11.85 | -1.47 | +10.38 |

Average uplift: **+3.42 dB** (statistical COM, GA vs fixed [-0.1, 0.7, -0.2])

### fmincon Comparison

fmincon on the same quantized landscape: **+0.00 dB** across all loss points. Only
3 evaluations per loss point (vs 1512 for GA). The staircase fitness function has
zero gradient, so fmincon cannot make progress.

### Speed

- Statistical COM evaluation: ~0.8 s/eval
- Time-domain COM evaluation: ~1.4 s/eval
- Full GA sweep (7 loss points x 50 pop x 30 gen): ~20-25 min (statistical)

Statistical path is preferred for optimization speed. Use time-domain for final
validation of the optimized parameters.

## Pattern: Design Space Sweep

```matlab
% Sweep CTLE AC gain to find optimal equalization for a 15 dB loss channel
acGainValues = 0:2:14;
results = cell(numel(acGainValues), 1);
comValues = zeros(numel(acGainValues), 1);

for k = 1:numel(acGainValues)
    sys = SerdesSystem(...
        'TxModel', Transmitter('Blocks', ...
            {serdes.FFE('TapWeights', [-0.1 0.7 -0.2])}), ...
        'RxModel', Receiver('Blocks', ...
            {serdes.CTLE('Specification', "DC Gain and AC Gain", ...
                          'DCGain', 0, 'ACGain', acGainValues(k), ...
                          'PeakingFrequency', 14e9), ...
             serdes.DFECDR('TapWeights', zeros(1, 5))}), ...
        'SymbolTime', 35.71e-12, 'SamplesPerSymbol', 16, ...
        'Modulation', 4, 'BERtarget', 1e-6);
    sys.ChannelData.ChannelLossdB = 15;
    sys.ChannelData.ChannelLossFreq = 14e9;
    results{k} = analysis(sys);
    comValues(k) = sys.Metrics.summary.COMestimate;
end

% Find optimal and plot
[bestCOM, bestIdx] = max(comValues);
fprintf("Best: AC Gain = %d dB → COM = %.2f dB\n", acGainValues(bestIdx), bestCOM);
figure; plot(acGainValues, comValues, '-o'); xlabel("CTLE AC Gain (dB)"); ylabel("COM (dB)");
```

----

Copyright 2026 The MathWorks, Inc.
----
