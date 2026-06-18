# RF Budget Cascade Analysis

Compute cascaded performance metrics (gain, noise figure, IP3, SNR, output power) through an RF signal chain using `rfbudget`.

## Creating an RF Budget

```matlab
lna = amplifier('Gain', 15, 'NF', 2, 'OIP3', 35, 'Name', 'LNA');
bpf = rfelement('Gain', -3, 'NF', 3, 'Name', 'BPF');
mix = modulator('Gain', -6, 'NF', 10, 'OIP3', 20, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');
ifAmp = amplifier('Gain', 20, 'NF', 4, 'OIP3', 30, 'Name', 'IFAmp');

b = rfbudget([lna bpf mix ifAmp], 2.4e9, -30, 10e6);
```

Constructor: `rfbudget(elements, inputFreq, availInputPower_dBm, signalBW)`

Name-value form (equivalent):
```matlab
b = rfbudget('Elements', [lna bpf mix ifAmp], ...
    'InputFrequency', 2.4e9, ...
    'AvailableInputPower', -30, ...
    'SignalBandwidth', 10e6);
```

## Key Properties (Read-Only Results)

All result properties return a vector with one value per stage (cumulative through the chain):

| Property | Description | Units |
|----------|-------------|-------|
| `TransducerGain` | Cumulative gain at each stage | dB |
| `NF` | Cumulative noise figure | dB |
| `OIP3` | Cumulative output third-order intercept | dBm |
| `IIP3` | Cumulative input third-order intercept | dBm |
| `OIP2` | Cumulative output second-order intercept | dBm |
| `IIP2` | Cumulative input second-order intercept | dBm |
| `OutputPower` | Output power at each stage | dBm |
| `OutputFrequency` | Frequency at each stage output | Hz |
| `SNR` | Signal-to-noise ratio at each stage | dB |
| `EIRP` | Effective isotropic radiated power (with rfantenna) | dBm |
| `Directivity` | Antenna directivity (with rfantenna) | dB |

System-level results are the last element of each vector:
```matlab
systemGain = b.TransducerGain(end);    % Total chain gain in dB
systemNF = b.NF(end);                  % System noise figure in dB
systemOIP3 = b.OIP3(end);             % System OIP3 in dBm
systemSNR = b.SNR(end);               % Output SNR in dB
```

### Input Properties (Read-Write)

| Property | Description |
|----------|-------------|
| `Elements` | Array of RF element objects |
| `InputFrequency` | Input signal frequency (Hz) |
| `AvailableInputPower` | Available input power (dBm) |
| `SignalBandwidth` | Signal bandwidth (Hz) |
| `Solver` | `'Friis'` (default) or `'HarmonicBalance'` |
| `AutoUpdate` | `true` (default) -- recompute on property change |

## Visualization

### Tabular View

```matlab
show(b);               % Opens interactive GUI table -- no command-window output
```

**Gotcha:** `show(b)` opens a GUI table widget but produces no text in the command window. For programmatic access, use `b.TransducerGain`, `b.NF`, `b.OIP3`, `b.OutputPower`, etc.

### RF Budget Analyzer App

```matlab
rfBudgetAnalyzer(b);   % Launch interactive RF Budget Analyzer app with pre-loaded budget
rfBudgetAnalyzer;      % Launch empty app for manual entry
```

### Plotting

```matlab
rfplot(b, 'Pout');     % Output power per stage
rfplot(b, 'GainT');    % Transducer gain per stage
rfplot(b, 'NF');       % Noise figure per stage
rfplot(b, 'OIP3');     % OIP3 per stage
rfplot(b, 'IIP3');     % IIP3 per stage
rfplot(b, 'SNR');      % SNR per stage
```

Valid `rfplot` parameter strings: `'Pout'`, `'GainT'`, `'NF'`, `'OIP3'`, `'IIP3'`, `'SNR'`, `'Sparameters'`, `'OneTone'`, `'TwoTone'`.

**Note:** `rfplot(b)` with no parameter string plots S-parameters (like `rfplot(sparametersObj)`). To plot budget metrics, specify a parameter string: `rfplot(b, 'Pout')`, `rfplot(b, 'GainT')`, etc.

**Note:** `'OneTone'` and `'TwoTone'` require `Solver='HarmonicBalance'` -- they error with "Harmonic balance solutions must be computed" if the Friis solver is active.

### Polar and Smith Chart Visualization

Plot S-parameters of each cascade stage vs. frequency:

```matlab
polar(b, 2, 2);        % S22 of each stage on a polar plot
smithplot(b, 1, 1);    % S11 reflection coefficient on Smith chart
```

## Solvers

| Solver | Use Case |
|--------|----------|
| `'Friis'` (default) | Linear cascade analysis -- fast, sufficient for most system budgets |
| `'HarmonicBalance'` | Nonlinear analysis -- more accurate than Friis, matches RF Blockset Circuit Envelope simulation |

`HarmonicBalance` accounts for compression, intermodulation, and mixer spurs that Friis ignores. Use it when accuracy matters -- the results match the highly accurate Circuit Envelope simulation in RF Blockset.

```matlab
b = rfbudget(elements, 2.4e9, -30, 10e6, ...
    'Solver', 'HarmonicBalance', 'WaitBar', false);
```

For HarmonicBalance, control harmonic content:
```matlab
b = rfbudget(elements, 2.4e9, -30, 10e6, ...
    'Solver', 'HarmonicBalance', ...
    'HarmonicOrder', 3, 'WaitBar', false);
```

**Tip:** Set `'WaitBar', false` when scripting or running programmatically -- suppresses the progress bar GUI that otherwise appears during HarmonicBalance computation.

## AM/PM Compression Table

Compute the system's AM/AM and AM/PM characteristic:

```matlab
ampmTable = computeAMPMTable(b);
% ampmTable: M-3 matrix [Pin_dBm, Pout_dBm, PhaseShift_deg]

% With custom input power range
pinRange = -40:0.5:10;
ampmTable = computeAMPMTable(b, pinRange);
```

## Computing System P1dB

Extract the 1-dB compression point from the AM/PM table:

```matlab
b = rfbudget(elements, 2.4e9, -30, 10e6, ...
    'Solver', 'HarmonicBalance', 'WaitBar', false);

ampm = computeAMPMTable(b, -50:0.5:10);
% ampm columns: [Pin_dBm, Pout_dBm, PhaseShift_deg]

gain = ampm(:,2) - ampm(:,1);          % Realized gain vs input power
linearGain = gain(1);                   % Small-signal gain (first point)
idx = find(gain <= linearGain - 1, 1);  % First point where gain drops 1 dB
inputP1dB = ampm(idx, 1);              % System input P1dB (dBm)
outputP1dB = ampm(idx, 2);            % System output P1dB (dBm)
```

This is the correct way to find system P1dB -- it accounts for cascaded compression across all stages. Do not manually refer individual element P1dB values to the output; `computeAMPMTable` handles the full nonlinear cascade.

## Mismatch Loss

```matlab
ml = mismatchLoss(b, 1);     % Mismatch loss at stage 1 input boundary (per frequency)
ml = mismatchLoss(b, 2);     % Mismatch loss at stage 2 input boundary (per frequency)
```

Arguments: `(rfbudgetObj, stageNum)` -- `stageNum` is required (1 to number of elements). Returns a **vector** of linear loss factors (one per frequency point, 0 to 1, where 1 = perfect match).

## AutoUpdate and Manual Computation

By default, `rfbudget` recomputes whenever a property changes. For batch modifications, disable auto-update:

```matlab
b = rfbudget(elements, 2.4e9, -30, 10e6, 'AutoUpdate', false);
b.InputFrequency = 5.8e9;
b.AvailableInputPower = -20;
computeBudget(b);     % Explicitly trigger computation
```

## Export

```matlab
exportScript(b);              % Opens generated MATLAB script in the editor
exportRFBlockset(b);          % Opens Simulink model with RF Blockset blocks
exportReceiver(b);            % Opens receiver configuration script in the editor
exportTransmitter(b);         % Opens transmitter configuration script in the editor
c = circuit(b);               % Convert to circuit for S-parameter extraction
s = sparameters(c, freq);
```

## Gotchas

1. **Elements cannot appear twice** -- The same element object cannot be used more than once, whether in the same chain (e.g., `rfbudget([lna filt lna], ...)`) or across separate budgets. Use `clone(element)` to create an independent copy: `rfbudget([lna filt clone(lna)], ...)`.
2. **Name must be valid MATLAB identifier** -- Element `Name` property cannot contain spaces or special characters. Use `'IFAmp'` not `'IF Amp'`.
3. **Per-stage results are cumulative** -- `TransducerGain`, `NF`, `OIP3` etc. are cumulative through the chain, not per-element deltas. The system result is always the last element.
4. **rfplot default is S-parameters** -- `rfplot(b)` with no parameter string plots S-parameters. Specify a string for budget metrics: `rfplot(b, 'Pout')`, `rfplot(b, 'GainT')`, etc.
5. **Frequency changes at mixers** -- `OutputFrequency` changes after a `modulator` element (down/up conversion). Subsequent stages operate at the new frequency.
6. **`show(b)` opens GUI, no text output** -- Use properties for programmatic access.

## Conventions

- Use `tiledlayout`/`nexttile` for multi-panel budget comparison plots
- Always label plots with units (dBm, dB, GHz)
- Use `show(b)` for quick inspection before plotting
- Name elements descriptively for readable `show` output

----

Copyright 2026 The MathWorks, Inc.

----
