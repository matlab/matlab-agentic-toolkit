# Impedance Matching Network Design

Design, evaluate, and optimize **1-port** impedance matching networks. The `matchingnetwork` object and `matchingNetworkDesigner` app match a source impedance to a load impedance — they do not yet design 2-port (e.g., filter-style) matching. The object generates candidate topologies, ranks them by performance, and exports as circuit objects.

## Creating a Matching Network

```matlab
mn = matchingnetwork( ...
    'SourceImpedance', 50, ...
    'LoadImpedance', 75 + 20i, ...
    'CenterFrequency', 2.4e9, ...
    'Bandwidth', 200e6, ...
    'Components', 2);
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `SourceImpedance` | 50 | Source impedance (see formats below) |
| `LoadImpedance` | 50 | Load impedance (see formats below) |
| `CenterFrequency` | 1e9 | Design frequency (Hz) |
| `Bandwidth` | 100e6 | Target bandwidth (Hz) |
| `LoadedQ` | 10 | Loaded Q factor |
| `Components` | 2 | Topology: `2`, `3`, `'L'`, `'Pi'`, `'Tee'` |
| `Circuit` | (auto) | Read-only array of generated circuits |

### Bandwidth and LoadedQ Are Coupled

`LoadedQ = CenterFrequency / Bandwidth`. Setting one updates the other. If both are specified, `Bandwidth` takes precedence.

### Components / Topology Options

| Value | Circuits Generated |
|-------|-------------------|
| `2` or `'L'` | 2 L-section designs (series-L/shunt-C and series-C/shunt-L) |
| `3` | 8 three-element designs (all permutations) |
| `'Pi'` | 4 shunt-series-shunt designs |
| `'Tee'` | 4 series-shunt-series designs |

**Gotcha:** Maximum is 3 components. `Components = 1` or `Components = 4` error.

## Impedance Source Formats

Both `SourceImpedance` and `LoadImpedance` accept:

```matlab
% Scalar (constant impedance)
mn.LoadImpedance = 75 + 20i;

% S-parameter object (frequency-dependent, 1-port)
sAnt = sparameters('antenna.s1p');
mn.LoadImpedance = sAnt;

% Z-parameter or Y-parameter object
mn.LoadImpedance = zparameters(sAnt);

% Touchstone file path
mn.LoadImpedance = 'antenna.s1p';

% 1-port circuit object (must have setports called)
ckt = circuit('Load');
add(ckt, [1 0], resistor(75, 'RL'));
add(ckt, [1 0], capacitor(1e-12, 'CL'));
setports(ckt, [1 0]);
mn.LoadImpedance = ckt;

% Function handle (frequency in Hz)
mn.LoadImpedance = @(f) 50 + 30i*(f/1e9);
```

## Inspecting Candidate Designs

```matlab
[topology, performance] = circuitDescriptions(mn);
disp(topology);       % Component types and values for each design
disp(performance);    % Pass/fail, tests failed, performance score
```

The **topology table** columns: `circuitName`, `component1Type`, `component1Value`, `component2Type`, `component2Value`, etc. Component types are `"Series L"`, `"Series C"`, `"Shunt L"`, `"Shunt C"`.

The **performance table** columns: `circuitName`, `evaluationPassed` (`"Yes"`/`"No"`), `testsFailed`, `performanceScore`. Designs are ranked by score (descending). The `performanceScore` is a weighted composite — higher is better, but the scale depends on your evaluation parameters (it is not a fixed 0–100 range). Use it for relative ranking between candidates, not as an absolute quality metric.

Use `component1Type`/`component2Type` columns in the topology table to identify which topology each auto-generated design represents (e.g., `"Series L"` + `"Shunt C"` vs `"Series C"` + `"Shunt L"`).

## Evaluation Parameters

Add performance goals to rank and filter designs. Only two parameter types: `'gammain'` (input reflection) and `'Gt'` (transducer gain).

```matlab
% Require return loss below -15 dB in-band
addEvaluationParameter(mn, 'gammain', '<', -15, [2.3e9 2.5e9], 2);

% Require insertion loss above -1 dB
addEvaluationParameter(mn, 'Gt', '>', -1, [2.3e9 2.5e9], 1);

% View current evaluations
params = getEvaluationParameters(mn);
disp(params);

% Remove an evaluation by row index
clearEvaluationParameter(mn, 1);
```

Arguments: `(mn, parameter, comparison, targetdB, [fLow fHigh], weight)` — all 6 are **positional and required** (weight is not optional).

A **default automatic evaluation** (`Gt > -3 dB` over `[CenterFrequency - Bandwidth/2, CenterFrequency + Bandwidth/2]`) is always present. Clear it with `clearEvaluationParameter(mn, 1)` if the automatic entry is at row 1.

**Gotcha:** Only `'gammain'` and `'Gt'` are supported — no S11, S21, VSWR, or other parameters.

## Exporting Circuits

```matlab
ckt = exportCircuits(mn);            % Best-ranked circuit only
ckts = exportCircuits(mn, [1 3]);    % Specific designs by index
```

Returns `circuit` objects containing `inductor` and `capacitor` elements. These can be used directly with `sparameters(ckt, freq)`, embedded in larger circuits via `add()`, or cascaded.

## Visualization

### Frequency Response

```matlab
rfplot(mn);                          % All designs, auto frequency range
rfplot(mn, freq);                    % Custom frequencies
rfplot(mn, freq, [1 3]);             % Specific designs
```

Plots two panels: input reflection coefficient (gammain) and transducer gain (Gt) in dB. Overlays evaluation goal lines.

### Smith Chart

```matlab
smithplot(mn);                                        % Best design
smithplot(mn, 'CircuitIndex', 2, 'Z0', 50);          % Specific design
```

Shows the impedance transformation path from source to load, tracing through each matching element in sequence (one arc per L/C component). This is the standard way to visualize each element's individual contribution to the match — no need to build intermediate circuits manually.

**Gotcha:** `smithplot(mn)` works directly on the `matchingnetwork` object. To plot an exported circuit's S-parameters on a Smith chart, use the S-parameter object form:

```matlab
ckt = exportCircuits(mn);
s = sparameters(ckt, linspace(1e9, 3e9, 201));
smithplot(s, 1, 1);                                   % Plot S11
```

Do not pass the circuit object directly to `smithplot` — it only accepts `matchingnetwork`, `sparameters`, or numeric data.

### S-Parameters

```matlab
s = sparameters(mn);                       % Best design, auto frequency
s = sparameters(mn, freq);                 % Custom frequencies
s = sparameters(mn, freq, Z0);             % Custom reference impedance
sArr = sparameters(mn, freq, Z0, [1 3]);   % Multiple designs -> array
```

The 4-argument form `sparameters(mn, freq, Z0, circuitIndex)` extracts S-parameters directly without needing `exportCircuits` first. Use `gammain(s)` or `powergain(s, 50, 50, 'Gt')` on the result for analysis.

## Richards Transformation (Lumped -> Stubs)

Convert lumped L/C matching elements to transmission line stubs. See `reference/lumped-to-distributed.md` for full Kuroda identity and realization details.

```matlab
txCkt = richards(mn, 2.4e9);              % Best design at 2.4 GHz
txCkts = richards(mn, 2.4e9, [1 2]);      % Specific designs
```

Returns `circuit` objects with `txlineElectricalLength` stub elements. Each stub has:
- `Z0` — characteristic impedance (from original element)
- `LineLength` — electrical length in radians (pi/4 for quarter-wave)
- `ReferenceFrequency` — the operating frequency argument
- `Termination` — `'Short'` for inductors, `'Open'` for capacitors
- `StubMode` — `'Series'` or `'Shunt'` matching the original topology

Stub element names get a `_tx` suffix: `C` becomes `C_tx`, `L` becomes `L_tx`.

## Tolerance Analysis

Evaluate matching network sensitivity to component value variations:

```matlab
% Default 5% tolerance on all components
toleranceAnalysis(mn);

% Custom tolerances per component
toleranceAnalysis(mn, [0.05 0.02 0.10]);    % 5%, 2%, 10% for each component

% Custom frequency range and specific circuit
toleranceAnalysis(mn, 0.05, linspace(0.5e9, 2.5e9, 500), 1);
```

Arguments: `(mn, tolerances, freqList, circuitIndices)` — all optional after `mn`. Plots the nominal and perturbed responses showing the spread due to component variations.

## Custom Matching Networks

Import user-designed circuits for comparison alongside auto-generated designs:

```matlab
% Build a custom matching circuit
custom = circuit('MyMatch');
add(custom, [1 2], inductor(3.3e-9, 'Ls'));
add(custom, [2 0], capacitor(0.8e-12, 'Cp'));
setports(custom, [1 0], [2 0]);

% Add to matchingnetwork for evaluation
addNetwork(mn, custom);    % Appears as "user_1" in circuitDescriptions

% Remove a custom network by name
deleteNetwork(mn, 'user_1');

% Suppress auto-generated designs to evaluate only custom circuits
disableAutomaticNetworks(mn);

% Re-enable auto-generated designs
enableAutomaticNetworks(mn);
```

Custom networks appear as `"user_1"`, `"user_2"`, etc. in `circuitDescriptions`.

**Gotcha:** Custom circuits must be 2-port with `setports` called, and contain only R/L/C elements. Other element types produce `-Inf` performance scores.

## Matching Network Designer App (R2021a+)

Interactive GUI for designing and comparing matching networks:

```matlab
matchingNetworkDesigner              % Launch empty
matchingNetworkDesigner(mn)          % Pre-loaded with existing design
```

The app provides visual comparison of topologies, interactive evaluation parameter setup, and Smith chart visualization. Configure programmatically with `matchingnetwork`, then open in the designer for interactive exploration.

## Handle Class Behavior

`matchingnetwork` is a **handle class**. These methods mutate in-place (no output argument):
- `addNetwork`, `deleteNetwork`
- `disableAutomaticNetworks`, `enableAutomaticNetworks`

Use `copy(mn)` for independent deep copies.

## Gotchas

1. **Property is `Bandwidth` (lowercase 'w')** — not `BandWidth` as some help text suggests.
2. **Components range is 2–3 only** — `Components = 1` or `Components = 4` error.
3. **Only `'gammain'` and `'Gt'` evaluation parameters** — no S11, S21, VSWR. All 6 positional arguments are required: `(mn, parameter, comparison, targetdB, [fLow fHigh], weight)`.
4. **Handle class** — `addNetwork`/`deleteNetwork` mutate in-place. Assigning their output errors ("too many output arguments").
5. **Custom circuits must be 2-port RLC only** — other element types produce warnings and `-Inf` scores.
6. **Default automatic evaluation always present** — `Gt > -3 dB` over bandwidth. Clear explicitly if unwanted.
7. **`Bandwidth` takes precedence** over `LoadedQ` when both are specified.
8. **`smithplot` only accepts `matchingnetwork` or `sparameters` objects** — do not pass a `circuit` object directly. For exported circuits, call `sparameters(ckt, freq)` first, then `smithplot(s, 1, 1)`.
9. **`performanceScore` is relative, not absolute** — use it to rank candidates against each other, not as a fixed quality metric. The scale depends on your evaluation parameters and weights.

## Conventions

- Use `tiledlayout`/`nexttile` for multi-panel matching analysis plots
- Show `smithplot` alongside `rfplot` for matching network analysis
- Always inspect `circuitDescriptions` to compare candidates before selecting
- Label axes with units (GHz, dB) and include figure titles

----

Copyright 2026 The MathWorks, Inc.

----
