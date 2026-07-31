# Impedance Matching Networks

## matchingnetwork Object

`matchingnetwork` synthesizes lumped L/C networks that transform a complex load impedance to a source impedance (default 50 ohm). It generates multiple candidate topologies, ranks them by performance goals, and exports the best designs as RF Toolbox `circuit` objects.

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `SourceImpedance` | 50 | Source impedance (real scalar, ohms) |
| `LoadImpedance` | 100 | Load: scalar, antenna, sparameters, file, or function handle |
| `CenterFrequency` | 1e9 | Design center frequency (Hz) |
| `Bandwidth` | `CenterFrequency/20` | Design bandwidth (Hz) |
| `Components` | 2 | Topology: 2, 3, `"L"`, `"Pi"`, `"Tee"` |
| `LoadedQ` | Inf | Component quality factor (finite for realistic losses) |

## Critical Property Order

**Set `CenterFrequency` BEFORE `LoadImpedance`** when the load is a frequency-dependent object (antenna, sparameters, file). MATLAB silently evaluates the antenna at the current (default 1 GHz) center frequency, producing an incorrect matching network — no error is thrown.

```matlab
mn = matchingnetwork;
mn.CenterFrequency = freq;    % 1. Set frequency FIRST
mn.Bandwidth = bw;            % 2. Bandwidth (optional)
mn.LoadImpedance = load;      % 3. Load AFTER frequency
mn.Components = 2;            % 4. Topology (any time)
```

## Load Impedance Options

| Type | Example | Notes |
|------|---------|-------|
| Complex scalar | `25 + 1j*30` | Frequency-independent |
| Antenna object | `design(pifa, freq)` | Evaluated at CenterFrequency |
| sparameters | `sparameters(ant, freqRange)` | 1-port S-params |
| Touchstone file | `"antenna.s1p"` | .s1p or .s2p file path |
| Function handle | `@(f) 36 + 1j*21*(f/2.4e9-1)` | Z(f) in ohms |

**Prefer `sparameters(ant, freqRange)` over raw antenna as `LoadImpedance`** -- avoids repeated EM solves.

## Topology Selection

| Components | Topologies Generated | Use Case |
|------------|---------------------|----------|
| 2 | All 2-element L-sections | Narrowband (BW < 5% of fc) |
| 3 | All 3-element networks | Wider bandwidth (BW > 5% of fc) |
| `"L"` | L-section variants only | Equivalent to 2 |
| `"Pi"` | Pi (shunt-series-shunt) | Low-pass or band-pass |
| `"Tee"` | Tee (series-shunt-series) | High-impedance loads |

## Evaluation Parameters (Ranking & Filtering)

```matlab
% Goal: S11 < -15 dB in band (weight 2)
addEvaluationParameter(mn, 'gammain', '<', -15, [2.3e9 2.5e9], 2);

% Goal: Transducer gain > -1 dB (weight 1)
addEvaluationParameter(mn, 'Gt', '>', -1, [2.3e9 2.5e9], 1);

% View all active parameters
ep = getEvaluationParameters(mn);

% Remove a specific parameter (by index)
clearEvaluationParameter(mn, 2);
```

- `'gammain'`: Input reflection coefficient (dB). Use `'<'` with negative target.
- `'Gt'`: Transducer power gain (dB). Use `'>'` with target near 0 dB.
- `band`: Frequency range `[fLow fHigh]` in Hz.
- `weight`: Higher weight = more influence on ranking.

## Antenna Impedance Matching

```matlab
freq = 2.4e9;
ant = design(pifa, freq);

mn = matchingnetwork;
mn.CenterFrequency = freq;
mn.Bandwidth = 200e6;
mn.LoadImpedance = ant;
mn.Components = 2;

addEvaluationParameter(mn, 'gammain', '<', -15, [2.3e9 2.5e9], 1);

cd = circuitDescriptions(mn);
disp(cd)

figure; rfplot(mn);
figure; smithplot(mn);
```

## Topology Comparison

```matlab
freq = 5.8e9;
Zload = 15 + 1j*40;

topologies = {2, 3, "Pi", "Tee"};
for k = 1:numel(topologies)
    mn = matchingnetwork;
    mn.CenterFrequency = freq;
    mn.Bandwidth = 500e6;
    mn.LoadImpedance = Zload;
    mn.Components = topologies{k};
    addEvaluationParameter(mn, 'gammain', '<', -15, [5.5e9 6.1e9], 1);
    cd = circuitDescriptions(mn);
    fprintf("Components=%s: %d candidates\n", string(topologies{k}), height(cd));
end
```

## Export and Circuit Analysis

```matlab
% Export best circuit (index 1) as RF Toolbox circuit object
ckt = exportCircuits(mn, 1);

% S-parameters of the matching network (2-port)
freqRange = linspace(2e9, 3e9, 101);
sCkt = sparameters(ckt, freqRange);
figure; rfplot(sCkt);
```

## Richards Transformation (Lumped to Distributed)

Convert lumped L/C to transmission-line-based circuit for PCB/microstrip realization:

```matlab
% Convert best circuit to transmission lines
txCkt = richards(mn, freq);

% Convert specific circuits by index
txCkts = richards(mn, freq, [1 2 3]);

% Analyze distributed circuit
freqRange = linspace(1e9, 4e9, 201);
sTx = sparameters(txCkts(1), freqRange);
figure; rfplot(sTx);
```

Output uses `txlineElectricalLength` elements -- quarter-wave stubs replacing L/C.

## Custom Network Topology

```matlab
mn = matchingnetwork;
mn.CenterFrequency = 2.4e9;
mn.LoadImpedance = 25 + 1j*30;

% Build custom 2-port matching circuit
c1 = circuit("my_match");
add(c1, [1 2], inductor(2e-9));
add(c1, [2 0], capacitor(1e-12));
setports(c1, [1 0], [2 0]);

% Disable automatic generation, add only custom
disableAutomaticNetworks(mn);
addNetwork(mn, c1);
```

## Lossy Components (Finite Q)

```matlab
mn.LoadedQ = 50;  % typical SMD inductor Q at 2.4 GHz
```

Lower `LoadedQ` values model lossier components and reduce achievable bandwidth.

## Non-50-Ohm Source

```matlab
mn.SourceImpedance = 75;  % 75-ohm system
```

## Function Handle Load

```matlab
R = 30; L = 5e-9; C = 2e-12;
Zfunc = @(f) R + 1j*(2*pi*f*L - 1./(2*pi*f*C));
mn.LoadImpedance = Zfunc;
```

## Multi-Band Matching

```matlab
mn.CenterFrequency = 3.5e9;
mn.Bandwidth = 3e9;
mn.LoadImpedance = sparameters(ant, linspace(2e9, 6e9, 101));
mn.Components = 3;

% Band 1: 2.4 GHz (higher weight)
addEvaluationParameter(mn, 'gammain', '<', -10, [2.4e9 2.5e9], 2);
% Band 2: 5 GHz (lower weight)
addEvaluationParameter(mn, 'gammain', '<', -10, [5.15e9 5.85e9], 1);
```

Set `CenterFrequency` between bands with `Bandwidth` spanning both. Weight primary band higher.

## Off-Resonance Matching

When antenna design frequency differs from operating frequency:

```matlab
designFreq = 3e9;
operatingFreq = 2.4e9;
bw = 200e6;

ant = design(patchMicrostrip, designFreq);
sAntLoad = sparameters(ant, linspace(operatingFreq - bw, operatingFreq + bw, 51));

mn = matchingnetwork;
mn.CenterFrequency = operatingFreq;  % Match at OPERATING freq
mn.Bandwidth = bw;
mn.LoadImpedance = sAntLoad;
```

## Before/After Comparison

```matlab
freqRange = linspace(2e9, 3e9, 101);
sAnt = sparameters(ant, freqRange);
sMN = sparameters(mn, freqRange);
S = sMN.Parameters;
gammaL = squeeze(sAnt.Parameters(1,1,:));
gammain = squeeze(S(1,1,:)) + squeeze(S(1,2,:)).*squeeze(S(2,1,:)).*gammaL ./ ...
    (1 - squeeze(S(2,2,:)).*gammaL);

figure;
plot(freqRange/1e9, 20*log10(abs(gammaL)), ...
     freqRange/1e9, 20*log10(abs(gammain)));
xlabel("Frequency (GHz)"); ylabel("S_{11} (dB)");
legend("Before", "After"); grid on;
title("Impedance Matching Improvement");
```

## Key Functions

| Function | Purpose |
|----------|---------|
| `circuitDescriptions(mn)` | Table of all candidate circuits with values |
| `addEvaluationParameter(mn, ...)` | Add performance goal for ranking |
| `getEvaluationParameters(mn)` | View active parameters |
| `clearEvaluationParameter(mn, idx)` | Remove a parameter |
| `exportCircuits(mn, idx)` | Export as RF Toolbox circuit object |
| `richards(mn, freq)` | Convert to distributed elements |
| `rfplot(mn)` | Plot matched system performance |
| `smithplot(mn)` | Smith chart of impedance transformation |
| `sparameters(mn, freq)` | 2-port S-params of matching network |
| `disableAutomaticNetworks(mn)` | Disable auto-generated topologies |
| `addNetwork(mn, ckt)` | Add custom topology to candidates |
| `deleteNetwork(mn, idx)` | Remove a circuit from pool |

## Guidelines

- `addEvaluationParameter` requires all 5 args: parameter, comparison, targetdB, band, weight
- `disableAutomaticNetworks` and `addNetwork` mutate the object in place (handle class)
- `rfplot(mn)` shows matched system performance (gammain and Gt with load connected)
- `sparameters(mn, freq)` returns the matching circuit as a 2-port (without load)
- Default to `Components = 2` unless user needs wider bandwidth
- Property is `Bandwidth` not `BandWidth` -- case-sensitive

----

Copyright 2026 The MathWorks, Inc.
