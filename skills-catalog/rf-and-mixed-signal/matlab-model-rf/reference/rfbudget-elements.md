# rfbudget Element Objects

Create and configure all rfbudget-compatible elements -- active components (amplifier, modulator, attenuator, phaseshift) and passive networks (seriesRLC, shuntRLC, lcladder, rffilter, nport, transmission lines). These are the building blocks for `rfbudget` cascade analysis and `circuit` composition.

## Element Hierarchy

### Active Elements

| Object | Represents | Key Properties |
|--------|-----------|----------------|
| `amplifier` | Active gain stage (LNA, PA) | Gain, NF, OIP3, Model ('poly'/'cubic'/'ampm'/'sparam') |
| `modulator` | Frequency converter (mixer) | Gain, NF, OIP3, LO, ConverterType ('Down'/'Up') |
| `rfelement` | Generic 2-port (cable, coupler) | Gain, NF, OIP3 |
| `attenuator` | Matched attenuator pad | Attenuation, Zin, Zout |
| `phaseshift` | Lossless phase shifter | PhaseShift (degrees) |

### Passive / Data-Driven Elements

| Object | Represents | Key Properties |
|--------|-----------|----------------|
| `nport` | Component from S-parameter data | Touchstone file or sparameters object |
| `rffilter` | Synthesized LC filter | ResponseType, FilterType, FilterOrder |
| `rfantenna` | Antenna in link budget | Type, Gain, TxEIRP, PathLoss |
| `seriesRLC` | Series R+L+C in signal path | R, L, C |
| `shuntRLC` | Shunt R+L+C to ground | R, L, C |
| `lcladder` | LC ladder filter | Topology, L, C values |

### Transmission Lines

All are rfbudget-compatible 2-port: `txlineDelayLossless`, `txlineDelayLossy`, `txlineMicrostrip`, `txlineCoaxial`, `txlineCPW`, `txlineStripline`, `txlineRLCGLine`, `txlineWRLGC`, `txlineWtable`, `txlineParallelPlate`, `txlineTwoWire`.

**Not rfbudget-compatible:** `resistor`, `capacitor`, `inductor`, `circuit` -- primitive elements for circuit composition only.

## amplifier

```matlab
lna = amplifier('Gain', 15, 'NF', 2, 'OIP3', 35, 'Name', 'LNA');
ampFromFile = amplifier('FileName', 'default.s2p', 'Name', 'LNAMeasured');
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `Gain` | 0 | Small-signal gain (dB) |
| `NF` | 0 | Noise figure (dB) |
| `OIP3` / `IIP3` | Inf | Third-order intercept (dBm) -- OIP3 = IIP3 + Gain |
| `OIP2` | Inf | Output second-order intercept (dBm) |
| `OP1dB` / `IP1dB` | Inf | 1-dB compression (dBm) -- OP1dB = IP1dB + Gain - 1 |
| `OPsat` / `IPsat` | Inf | Saturation power (dBm) -- independent of each other |
| `Model` | `'poly'` | `'poly'`, `'cubic'`, `'ampm'`, `'sparam'` |
| `Zin` / `Zout` | 50 | Impedance (Ohm) |
| `Name` | `''` | Element name (must be valid MATLAB identifier) |

**Conventions:** Amplifiers use output-referred (OIP3, OP1dB, OPsat). Mixers/modulators use input-referred (IIP3, IP1dB, IPsat).

**`'poly'` vs `'cubic'`:** `'poly'` (default) uses ALL set compression params to fit a higher-order polynomial. `'cubic'` uses only ONE param selected by `Nonlinearity`. Prefer `'poly'`. See `reference/amplifier-models.md` for detailed compression parameter conventions.

## modulator

```matlab
downMixer = modulator('Gain', -6, 'NF', 10, 'OIP3', 20, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');

upMixer = modulator('Gain', -8, 'NF', 12, 'OIP3', 18, ...
    'LO', 1.5e9, 'ConverterType', 'Up', 'Name', 'UpConv');
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `LO` | 0 | Local oscillator frequency (Hz) |
| `ConverterType` | `'Down'` | `'Down'` or `'Up'` conversion |
| `Gain` | 0 | Conversion gain/loss (dB) |
| `NF` | 0 | Noise figure (dB) |
| `OIP3` | Inf | Output IP3 (dBm) |
| `ImageReject` | true | Reject image frequency |
| `ChannelSelect` | true | Select desired channel |

### Frequency Behavior

After a `modulator`, the signal frequency changes. In an `rfbudget`, subsequent stages operate at the converted frequency. For a down-converter: `fOut = fIn - LO` (or `LO - fIn` depending on sideband). For an up-converter: `fOut = fIn + LO`. Read `b.OutputFrequency` to see the frequency at each stage output.

## rfelement

Use for cables, couplers, or any passive/active component defined by scalar specs:

```matlab
atten = rfelement('Gain', -10, 'NF', 10, 'Name', 'Atten');
cable = rfelement('Gain', -1.5, 'NF', 1.5, 'Name', 'Cable');
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `Gain` | 0 | Gain (dB) -- negative for loss |
| `NF` | 0 | Noise figure (dB) |
| `OIP3` | Inf | Output IP3 (dBm) |
| `OIP2` | Inf | Output IP2 (dBm) |
| `Zin` | 50 | Input impedance (Ohm) |
| `Zout` | 50 | Output impedance (Ohm) |
| `Name` | `''` | Element name |

**Gotcha:** For passive, NF must equal `abs(Gain)`. A -3 dB attenuator has NF = 3 dB. Setting inconsistent values (e.g., Gain=-3, NF=0) produces incorrect budget results. Prefer `attenuator` which handles this automatically.

## rfantenna

Models a transmit or receive antenna in an `rfbudget` chain, computing EIRP and received power from `TxEIRP`, `PathLoss`, and antenna `Gain`.

```matlab
tx = rfantenna('Type', 'Transmitter', 'Gain', 6, 'Name', 'TxAnt');
rx = rfantenna('Type', 'Receiver', 'Gain', 3, 'TxEIRP', 30, ...
    'PathLoss', 60, 'Name', 'RxAnt');
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `Type` | `'Transmitter'` | `'Transmitter'`, `'Receiver'`, or `'TransmitReceive'` |
| `Gain` | 0 | Antenna gain (dB) -- scalar for Tx/Rx, 1x2 `[TxGain RxGain]` for TransmitReceive |
| `Z` | 50 | Impedance (Ohm) -- scalar or 1x2 for TransmitReceive |
| `TxEIRP` | -30 | Transmitter EIRP (dBm) -- used by Receiver to compute input power |
| `PathLoss` | 0 | Path loss between Tx and Rx (dB) |

### Behavior in rfbudget

- **Transmitter:** Placed at end of chain. Adds antenna `Gain` to `TransducerGain` and `OutputPower`. EIRP = OutputPower at the antenna stage.
- **Receiver:** Placed at start of chain. Computes received power as `TxEIRP - PathLoss + Gain`. Adds 0 dB to `TransducerGain`. The `AvailableInputPower` argument to `rfbudget` is **ignored** (warning issued). The received power property is `RxP`.
- **TransmitReceive:** Can go anywhere in the chain. `Gain` must be 1x2 vector `[TxGain RxGain]`.

```matlab
% Receiver link budget: Rx computes its own input power
rx = rfantenna('Type', 'Receiver', 'Gain', 3, 'TxEIRP', 30, ...
    'PathLoss', 60, 'Name', 'RxAnt');
lna = amplifier('Gain', 15, 'NF', 2, 'OIP3', 35, 'Name', 'LNA');
b = rfbudget([rx lna], 2.4e9, -30, 10e6);
% Input power = TxEIRP - PathLoss + Gain = 30 - 60 + 3 = -27 dBm
```

**Gotcha:** Only one `rfantenna` element is allowed per `rfbudget` chain.

**Gotcha:** `rfantenna` is a 1-port element (2 terminals: `p1+`, `p1-`). In a `circuit`, use `add(ckt, [1 0], ant)` with 2 nodes, not 4.

**Gotcha:** You cannot call `sparameters()` directly on an `rfbudget` object. To extract S-parameters from a budget, first convert to a circuit: `sp = sparameters(circuit(b), freq)`.

## attenuator

A dedicated attenuator element that automatically handles NF derivation and impedance matching.

```matlab
pad = attenuator('Attenuation', 6, 'Name', 'Pad6dB');
pad50to75 = attenuator('Attenuation', 10, 'Zin', 50, 'Zout', 75, 'Name', 'MatchPad');
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `Attenuation` | 3 | Attenuation in dB (positive value) |
| `Zin` | 50 | Input impedance (Ohm) |
| `Zout` | 50 | Output impedance (Ohm) |

In `rfbudget`, NF equals `Attenuation` automatically -- no manual NF setting needed.

**Gotcha:** When `Zin != Zout`, there is a **minimum attenuation** requirement. For example, `Zin=50, Zout=75` requires `Attenuation > 5.72 dB`. MATLAB reports the exact threshold in the error message. Matched impedances (`Zin == Zout`) have no minimum.

## phaseshift

Adds a frequency-independent phase shift with zero insertion loss.

```matlab
ps = phaseshift('PhaseShift', 90, 'Name', 'PS90');
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `PhaseShift` | 90 | Phase shift in degrees |

In `rfbudget`: Gain = 0 dB, NF = 0 dB (lossless). In S-parameters: `|S21| = 1`, `angle(S21) = PhaseShift`.

**Gotcha:** The `PhaseShift` value maps directly to the S21 phase angle (positive = phase lead, negative = phase lag). `PhaseShift=45` gives `angle(S21) = +45 deg`.

## nport

Use when you have measured or simulated S-parameter data. Accepts `.s1p` through any `.snp` Touchstone file:

```matlab
filter = nport('passive.s2p', 'BPFilter');   % Name is positional (2nd arg)

% Or from a sparameters object
s = sparameters(data, freq, 50);
comp = nport(s, 'CustomComp');
```

- Accepts `.s1p` through `.snp` (1-port works in circuit, not rfbudget)
- `.amp` files NOT supported
- For multi-port: set `Input` and `Output` properties for rfbudget port selection

### Multi-Port Selection

For components with more than 2 ports, specify which ports to use:

```matlab
n = nport('default.s4p');
n.Input = 1;          % Input port number
n.Output = 3;         % Output port number
n.Termination = 50;   % Terminate unused ports
```

### Creating nport from Synthetic Data

```matlab
% Build a 4-port sparameters object (e.g., through-path on ports 1->3)
data = zeros(4, 4, 10);
data(3,1,:) = 0.8; data(1,3,:) = 0.8;  % S31=S13 (reciprocal through)
data(4,2,:) = 0.8; data(2,4,:) = 0.8;  % S42=S24 (second pair)
s4 = sparameters(data, linspace(1e9, 3e9, 10), 50);
comp = nport(s4, 'MyComp');
comp.Input = 1;
comp.Output = 3;
```

## rffilter

```matlab
bpf = rffilter('ResponseType', 'Bandpass', 'FilterType', 'Butterworth', ...
    'FilterOrder', 5, 'PassbandFrequency', [2.3e9 2.5e9], 'Name', 'BPF');
```

Key properties: `ResponseType` (Lowpass/Highpass/Bandpass/Bandstop), `FilterType` (Butterworth/Chebyshev/InverseChebyshev), `FilterOrder`, `PassbandFrequency` (scalar for LP/HP, 2-vector for BP/BS). See `reference/rffilter-synthesis.md` for full design options.

**Gotcha:** `ResponseType` is shape (Lowpass/Bandpass/etc.), `FilterType` is algorithm (Butterworth/Chebyshev). Using `rffilter('FilterType', 'Bandpass')` errors.

## seriesRLC and shuntRLC

### Series Elements (In-Line with Signal Path)

```matlab
L1 = seriesRLC('L', 2.7e-9, 'Name', 'Lseries');          % Inductor only
C1 = seriesRLC('C', 1.2e-12, 'Name', 'DCBlock');          % DC blocking cap
R1 = seriesRLC('R', 50, 'Name', 'Rpad');                   % Resistor only
rlc = seriesRLC('R', 10, 'L', 1e-9, 'C', 0.5e-12, 'Name', 'RLC1');
```

### Shunt Elements (To Ground)

```matlab
Cbypass = shuntRLC('C', 100e-12, 'Name', 'Cbypass');       % Bypass cap
Lchoke = shuntRLC('L', 100e-9, 'Name', 'Lchoke');          % RF choke
Rterm = shuntRLC('R', 50, 'Name', 'Rterm');                 % Termination
```

Omitted values default to "absent": seriesRLC uses R=0, L=0, C=Inf (wire-through); shuntRLC uses R=Inf, L=Inf, C=0 (open-circuit).

### rfbudget vs circuit Topology Difference

In `rfbudget`, shuntRLC is modeled as a 2-port inline element (computing insertion loss from its shunt impedance to ground). In a `circuit` object, `add(ckt, [node 0], shuntRLC(...))` wires the element literally between a signal node and ground -- this is a different topology. For example, a bias-tee inductor (`shuntRLC('L', 100e-9)`) shows near-zero insertion loss in `rfbudget` at RF frequencies, but if wired as `add(ckt, [2 0], ...)` in a circuit it appears as a shunt path to ground and dominates the S21 response. Use `rfbudget` for cascade analysis of bias tees; use `circuit` only when modeling the full node-level topology.

### Common Building Blocks

| Block | Implementation |
|-------|---------------|
| DC block | `seriesRLC('C', 100e-12, 'Name', 'DCBlk')` |
| Bias tee inductor | `shuntRLC('L', 100e-9, 'Name', 'Lbias')` |
| Pad attenuator | `seriesRLC('R', Rseries)` + `shuntRLC('R', Rshunt)` |
| Termination | `shuntRLC('R', 50, 'Name', 'Term')` |

## lcladder

LC ladder filter networks. Created from a topology string, inductor values, and capacitor values.

```matlab
lc = lcladder('lowpasspi', [10e-9 10e-9], [1e-12 1e-12 1e-12], 'LPF');
lc = lcladder(rffilterObj, 'BPF');
```

### Topologies

| Topology String | Description |
|----------------|-------------|
| `'lowpasspi'` | Low-pass pi |
| `'lowpasstee'` | Low-pass tee |
| `'highpasspi'` | High-pass pi |
| `'highpasstee'` | High-pass tee |
| `'bandpasspi'` | Band-pass pi |
| `'bandpasstee'` | Band-pass tee |
| `'bandstoppi'` | Band-stop pi |
| `'bandstoptee'` | Band-stop tee |

**Gotcha:** `lcladder` constructor is positional -- `lcladder(topology, L, C, name)`, not name-value pairs.

**Gotcha:** Topology strings are **all lowercase** (`'lowpasspi'`, `'bandpasstee'`). Using mixed-case like `'LowpassPi'` or abbreviations like `'CLC'` errors with "not a valid LC Ladder topology."

## Transmission Lines

All transmission line objects are 2-port and rfbudget-compatible. Use `LineLength` for physical length (not `Length`). See `reference/transmission-lines.md` for all types and properties.

```matlab
tl = txlineDelayLossless('Z0', 50, 'TimeDelay', 33e-12, 'Name', 'TL1');
rlcg = txlineRLCGLine('R', 0.5, 'L', 250e-9, 'C', 100e-12, 'G', 0, 'LineLength', 0.05);
tw = txlineWRLGC('Lo', 350e-9, 'Co', 130e-12, 'Ro', 2, 'Rs', 5e-4, 'Gd', 1e-11, ...
    'LineLength', 0.1, 'Name', 'WLine');
```

- All use `LineLength` for physical length (not `Length`)
- All constructors are name-value only (no positional)
- `txlineWRLGC` properties are `Ro`, `Lo`, `Co`, `Go`, `Gd` -- short forms `R`, `L` are ambiguous and error

## Using in rfbudget

All elements plug directly into rfbudget's element array:

```matlab
lna = amplifier('Name', 'LNA', 'Gain', 15, 'NF', 1.5, 'OIP3', 20);
dcblk = seriesRLC('C', 100e-12, 'Name', 'DCBlock');
bpf = lcladder(rffilter('ResponseType', 'Bandpass', 'FilterOrder', 3, ...
    'PassbandFrequency', [2.3e9 2.5e9]), 'BPF');

% Positional form: rfbudget(elements, freq, inputPower, signalBW)
b = rfbudget([dcblk lna bpf], 2.4e9, -30, 10e6);

% Name-value form (equivalent):
% b = rfbudget('Elements', [dcblk lna bpf], 'InputFrequency', 2.4e9, ...
%     'AvailableInputPower', -30, 'SignalBandwidth', 10e6);

show(b);   % Opens GUI table; no command-window output
```

**Critical:** `SignalBandwidth` (4th positional arg) is required for NF, IP3, and SNR computation. Without it, those fields remain empty.

### Element Reuse Requires clone()

An element object cannot appear more than once in the same chain or across separate budgets. Use `clone()` every time you need a second instance:

```matlab
% ERROR: same object used twice
% b = rfbudget([lna filter lna], 2.4e9, -30, 10e6);

% CORRECT: clone for the second use
b = rfbudget([lna filter clone(lna)], 2.4e9, -30, 10e6);

% CORRECT: reuse across two budgets
b1 = rfbudget(lna, 2.4e9, -30, 10e6);
b2 = rfbudget(clone(lna), 5.8e9, -30, 10e6);
```

### circuit Objects Are NOT rfbudget-Compatible

A `circuit` object cannot be added to rfbudget directly. Workaround -- convert to nport via Touchstone:

```matlab
% Build circuit
ckt = circuit('MyNetwork');
add(ckt, [1 2], seriesRLC('L', 10e-9, 'Name', 'L1'));
add(ckt, [2 0], shuntRLC('C', 1e-12, 'Name', 'C1'));
setports(ckt, [1 0], [2 0]);

% Convert to nport for rfbudget
s = sparameters(ckt, linspace(1e9, 6e9, 500));
outFile = 'mynetwork.s2p';
rfwrite(s, outFile, 'ForceOverwrite', true);
np = nport(outFile, 'MyNetwork');
% np works in rfbudget
```

### Standalone S-Parameter Analysis

Any element can compute S-parameters directly without wrapping in a circuit:

```matlab
freq = linspace(1e9, 10e9, 500);
s = sparameters(mstrip, freq);

figure;
tiledlayout(1, 2);
nexttile; rfplot(s, 2, 1); title('S21 -- Insertion Loss');
nexttile; rfplot(s, 1, 1); title('S11 -- Return Loss');
```

## Gotchas

1. **Name must be valid MATLAB identifier** -- no spaces
2. **Elements are handle objects** -- modifying an element after adding it to a budget changes the budget; use `clone` for independent copies
3. **Passive NF equals loss** -- prefer `attenuator`
4. **nport uses ports 1 (input) and 2 (output) by default** -- for multi-port files, set `Input` and `Output` explicitly
5. **nport Name is positional** -- `nport('file.s2p', 'MyName')`, not NV syntax; `nport('file.s2p', 'Name', 'X')` sets Name to literal `'Name'`
6. **rffilter is ideal** -- no parasitic effects
7. **rfantenna is 1-port** -- one per chain; in circuit use `add(ckt, [1 0], ant)` with 2 nodes
8. **attenuator minimum for mismatched Z** -- `Zin=50, Zout=75` requires `Attenuation > 5.72 dB`; error message gives threshold
9. **`'poly'` vs `'cubic'`** -- `'poly'` uses all params, `'cubic'` uses one selected by Nonlinearity
10. **lcladder constructor is positional** -- `lcladder(topology, L, C, name)`, not name-value pairs
11. **lcladder topology strings all lowercase** -- `'lowpasspi'` not `'LowpassPi'`
12. **circuit objects don't work in rfbudget** -- convert via nport + Touchstone
13. **`rfwrite` blocks on existing files** -- Always `'ForceOverwrite', true`
14. **phaseshift sign convention** -- positive `PhaseShift` = positive S21 phase angle (phase lead)
15. **Cannot call sparameters() on rfbudget** -- convert to circuit first: `sparameters(circuit(b), freq)`

----

Copyright 2026 The MathWorks, Inc.

----
