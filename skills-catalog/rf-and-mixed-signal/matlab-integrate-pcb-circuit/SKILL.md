---
name: matlab-integrate-pcb-circuit
description: "Cascade PCB components, add lumped elements, export Touchstone, and bridge to eye diagram or antenna array workflows. TRIGGER: user asks to cascade or connect multiple RF PCB components, add lumped R/L/C, export S-parameters to Touchstone, or combine PCB elements into a circuit. Invoke BEFORE writing pcbcascade or circuit code — cascade rules and port matching are non-obvious. SKIP: designing individual components (use the specific matlab-design-pcb-* skill), EM analysis of a single component (use matlab-analyze-em), material/stackup setup only (use matlab-manage-pcb-material), optimization (use matlab-optimize-pcb-design)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Cascading and Integrating RF PCB Components

## When to Use

- Cascading two or more PCB components end-to-end with `pcbcascade`
- Wrapping PCB components as circuit elements with `pcbElement` for RF Toolbox
- Loading internal ports with lumped elements (varactors, terminators)
- Exporting S-parameters to Touchstone files via `rfwrite`
- Integrating RF PCB feed networks with antenna arrays
- Bridging to Signal Integrity Toolbox for eye diagram analysis

## When NOT to Use

- Designing individual filters, couplers, or transmission lines — use the respective designing skill
- Building custom PCB geometry from scratch — use `matlab-assemble-pcb-layout`
- Running EM analysis on a single component — use `matlab-analyze-em`
- Setting up materials — use `matlab-manage-pcb-material`

## Typical Workflow

1. **Before:** Design skills (`matlab-design-pcb-filter`, `matlab-design-pcb-coupler`, etc.) or `matlab-analyze-em` — create and validate individual components
2. **This skill:** Cascade components, add lumped elements, export Touchstone, bridge to eye diagram analysis
3. **After:** `matlab-write-pcb-layout` — export final design to Gerber; or feed S-parameters into Signal Integrity Toolbox workflows

## Quick Reference

| Task | Code |
|------|------|
| Cascade two components | `out = pcbcascade(comp1, comp2)` |
| Cascade with rectangular board | `out = pcbcascade(comp1, comp2, 'RectangularBoard', true)` |
| Interactive cascade | `pcbcascade(comp1, comp2, 'Interactive', true)` |
| Create circuit element | `elem = pcbElement(comp)` |
| Set analysis ports | `elem.AnalysisPorts = {1, 2}` |
| Attach lumped elements | `elem.PortNumber = {3, 4}; elem.PortValue = {capacitor(2.2e-12), resistor(50)}` |
| Add to RF circuit | `add(ckt, [1 2 0 0], elem)` |
| Export to Touchstone | `rfwrite(sp, 'comp.s2p')` |
| Export with options | `rfwrite(sp, 'comp.s2p', FrequencyUnit='GHz', Format='DB')` |

## pcbcascade — Connecting Components End-to-End

The `pcbcascade` function joins two RF PCB components port-to-port, producing a single `pcbComponent` for full-wave analysis.

### Basic Cascade

```matlab
HPF = filterStub;
HPF.StubShort = [1 1 1 1 1];
HPF.Height = 0.508e-3;
% ... set HPF properties ...

LPF = filterStepImpedanceLowPass;
LPF.Height = 0.508e-3;
LPF = design(LPF, 7e9);

BPF = pcbcascade(LPF, HPF, "RectangularBoard", true);
show(BPF);
```

### Analyzing the Cascade

```matlab
freq = linspace(1e6, 12e9, 51);
sp = sparameters(BPF, freq, 'SweepOption', 'interp');
rfplot(sp);
```

### RectangularBoard Option

| Value | Behavior |
|-------|----------|
| `true` | Creates a rectangular dielectric board around the cascaded layout |
| `false` (default) | Uses the natural board shape from the component geometries |

### Interactive Cascade Mode

For visual port alignment:

```matlab
pcbcascade(comp1, comp2, 'Interactive', true);
```

This launches a GUI that lets you visually connect ports and adjust spacing.

### Multi-Stage Cascade

Chain more than two components by cascading sequentially:

```matlab
stage1 = design(filterStepImpedanceLowPass, 5e9);
stage2 = design(microstripLine, 5e9);
stage3 = design(filterStepImpedanceLowPass, 5e9);

% Match substrates — design() defaults differ across object types
stage2.Substrate = stage1.Substrate;
stage2.Height = stage1.Height;
stage2.Conductor = stage1.Conductor;
stage3.Substrate = stage1.Substrate;
stage3.Height = stage1.Height;
stage3.Conductor = stage1.Conductor;

% Cascade stage1 + stage2, then result + stage3
intermediate = pcbcascade(stage1, stage2, 'RectangularBoard', true);
final = pcbcascade(intermediate, stage3, 'RectangularBoard', true);
show(final);
```

### Cascade Requirements

- Both components must share the same substrate (`Height`, `Substrate`)
- Port line widths should match at the connection interface
- Components connect at their port edges (port 2 of comp1 to port 1 of comp2)

## pcbElement — RF Toolbox Circuit Integration

`pcbElement` wraps an RF PCB component as a circuit element usable in the RF Toolbox `circuit` framework. This enables hybrid distributed+lumped modeling.

### Basic Usage

```matlab
comp = design(couplerBranchline, 5e9);
elem = pcbElement(pcbComponent(comp));
S = sparameters(elem, linspace(3e9, 7e9, 51), 'SweepOption', 'interp');
rfplot(S);
```

### Behavioral vs Full-Wave

```matlab
% Behavioral model (fast, uses analytic approximation)
elem = pcbElement(comp, 'Behavioral', true);

% Full-wave solve (accurate, uses MoM)
elem = pcbElement(comp, 'Behavioral', false);
```

Not all components support behavioral mode. If unsupported, a warning is issued and full-wave is used automatically.

### Adding pcbElement to a Circuit

```matlab
ckt = circuit;
c1 = interdigitalCapacitor;
c2 = interdigitalCapacitor('NumFingers', 3);
p = pcbElement(c2, 'Behavioral', false);
add(ckt, [1 2 0 0], c1);    % Default pcbElement created automatically
add(ckt, [2 3 0 0], p);
setports(ckt, [1 0], [3 0]);
S = sparameters(ckt, 8e9);
```

## Hybrid Distributed+Lumped Modeling with Internal Ports

The most powerful use of `pcbElement` is connecting lumped components (capacitors, resistors, inductors) to internal ports on an EM structure. This models tunable filters with varactors, loaded resonators, and bias-T networks.

### Concept

1. Define extra `FeedLocations` on the PCB as internal port pairs
2. Wrap with `pcbElement`
3. Assign `AnalysisPorts` (external I/O ports for S-parameter extraction)
4. Assign `PortNumber` (internal port indices to load)
5. Assign `PortValue` (lumped elements connected at those ports)

### Pattern: Loaded Coupler with Terminations

```matlab
% Start with a 4-port coupler
comp = design(couplerRatrace, 5e9);
pcb = pcbComponent(comp);

% Create pcbElement
elem = pcbElement(pcb);

% Ports 1,2 are external I/O (for S-parameter extraction)
elem.AnalysisPorts = {1, 2};

% Ports 3,4 are loaded with lumped elements
elem.PortNumber = {3, 4};
elem.PortValue = {resistor(50), resistor(50)};

% Analyze the 2-port network with internal loads
S = sparameters(elem, linspace(3e9, 7e9, 51), 'SweepOption', 'interp');
rfplot(S);
```

### Pattern: Tunable Filter with Varactors

```matlab
% Design a filter with extra internal feed points for varactors
pcb = pcbComponent;
% ... build custom filter geometry with internal feed pads ...
% FeedLocations rows 1,2 = external I/O
% FeedLocations rows 3,4 and 5,6 = varactor pads (internal port pairs)

pcb.FeedLocations = [x1 y1 1 3;    % Port 1: input
                     x2 y2 1 3;    % Port 2: output
                     x3 y3 1 3;    % Port 3: varactor pad A+
                     x4 y4 1 3;    % Port 4: varactor pad A-
                     x5 y5 1 3;    % Port 5: varactor pad B+
                     x6 y6 1 3];   % Port 6: varactor pad B-

elem = pcbElement(pcb);
elem.AnalysisPorts = {1, 2};
elem.PortNumber = {{3,4}, {5,6}};
elem.PortValue = {capacitor(2.2e-12), capacitor(2.2e-12)};

S = sparameters(elem, linspace(1e9, 10e9, 51), 'SweepOption', 'interp');
rfplot(S);
```

### Supported PortValue Types

| Type | Example |
|------|---------|
| `resistor` | `resistor(50)` |
| `capacitor` | `capacitor(2.2e-12)` |
| `inductor` | `inductor(1e-9)` |
| S-parameter file | `'component.s2p'` |

### PortNumber Formats

```matlab
% Single-port loads (each port terminated individually)
elem.PortNumber = {3, 4};
elem.PortValue = {resistor(50), resistor(50)};

% Port-pair loads (2-port element connected across a pair)
elem.PortNumber = {{3,4}, {5,6}};
elem.PortValue = {capacitor(2.2e-12), nport('varactor.s2p')};
```

## Antenna Integration

Integrate RF PCB feed networks with Antenna Toolbox arrays.

### Corporate Divider + Patch Array

```matlab
% Design corporate power divider
pdc = powerDividerCorporate;
pdc = design(pdc, 5e9);
pdc.NumOutputPorts = 4;
pdc.PortSpacing = physconst('lightspeed') / 5e9;

% Design patch antenna
ant = patchMicrostripInsetfed;
ant.Substrate = dielectric('Teflon');
ant = design(ant, 5e9);

% Convert to pcbStack for shape extraction
pcbant = pcbStack(ant);
TopLayer = pcbant.Layers{1};

% Create linear array of patches
for i = 2:4
    a = copy(TopLayer);
    a = translate(a, [0, pdc.PortSpacing*(i-1), 0]);
    TopLayer = TopLayer + a;
end

% Merge divider and antenna array into single pcbStack
pcbcomp = pcbComponent(pdc);
pcbant1 = pcbStack;
pcbant1.BoardShape = pcbcomp.BoardShape;
pcbant1.BoardThickness = pcbcomp.BoardThickness;
pcbant1.Layers = pcbcomp.Layers;
pcbant1.FeedDiameter = pcbcomp.FeedDiameter;
pcbant1.FeedLocations = pcbcomp.FeedLocations(1,:);  % Keep only input port

% Combine top layers
pcbant1.Layers{1} = pcbant1.Layers{1} + TopLayer;
show(pcbant1);
```

## pcb2D Cross-Section and Crosstalk

For `pcb2D` cross-section analysis, `trace2D` setup, RLGC extraction, `slice()`, and crosstalk with coupled traces, see `matlab-design-pcb-transmission-line`.

## Exporting S-Parameters to Touchstone Files

Use `rfwrite` to save computed S-parameters as Touchstone files for reuse in other tools or simulations.

### Basic Export

```matlab
sp = sparameters(pcbComponent, freq, 'SweepOption', 'interp');
rfwrite(sp, 'component.s2p');
```

### rfwrite Options

| Option | Values | Description |
|--------|--------|-------------|
| `FrequencyUnit` | `'Hz'`, `'kHz'`, `'MHz'`, `'GHz'` | Unit for frequency column |
| `Parameter` | `'S'`, `'Y'`, `'Z'` | Network parameter type |
| `Format` | `'MA'`, `'DB'`, `'RI'` | Magnitude-Angle, dB-Angle, Real-Imaginary |
| `ReferenceResistance` | scalar (default 50) | Reference impedance in ohms |

```matlab
rfwrite(sp, 'filter_2p4GHz.s2p', FrequencyUnit='GHz', Format='DB');
```

### Load Touchstone as nport

```matlab
n = nport('component.s2p');
% Use in any RF Toolbox circuit
add(ckt, [1 2], n);
```

The file extension (`.s2p`, `.s4p`, etc.) is selected automatically by `rfwrite` based on port count.

## Advanced Integration Patterns

### Nolen Matrix Beam-Forming

A Nolen matrix uses cascaded branchline couplers and phase shifters to create an N×N beam-forming network. Build by cascading individual RF PCB components:

```matlab
coupler = design(couplerBranchline, fc);
ps = design(phaseShifter, fc, PhaseShift=90);
% Extract S-parameters for each, then cascade via circuit()
ckt = circuit;
add(ckt, [1 2 3 4], nport(sparameters(coupler, freq, 'SweepOption', 'interp')));
add(ckt, [3 5], nport(sparameters(ps, freq, 'SweepOption', 'interp')));
% ... build full N×N matrix
```

### Monopulse Comparator

An X-band monopulse comparator uses four ratrace couplers to generate sum and difference beams:

```matlab
rr = design(couplerRatrace, fc);
S_rr = sparameters(rr, freq, 'SweepOption', 'interp');
% Build 4-coupler comparator network using circuit()
```

### Amplifier Matching Networks

Use microstrip tee junctions and stubs to create input/output matching networks, then cascade with amplifier S-parameters:

```matlab
% Build matching network as pcbComponent
tee = traceTee(Length=[L1, L2], Width=[W1, W2]);
pcb = pcbComponent(tee);
pcb.Substrate = dielectric("FR4");
S_match = sparameters(pcb, freq, 'SweepOption', 'interp');

% Load amplifier S-parameters and cascade
amp = nport('amplifier.s2p');
ckt = circuit;
add(ckt, [1 2 0 0], nport(S_match));     % Input match
add(ckt, [2 3 0 0], amp);                 % Amplifier
add(ckt, [3 4 0 0], nport(S_match));     % Output match
setports(ckt, [1 0], [4 0]);
S_total = sparameters(ckt, freq);
```

### FEXT/NEXT with Parallel Link Designer

Full-wave EM results from `pcb2D` can be exported to Signal Integrity Toolbox for system-level analysis:

```matlab
cs = pcb2D;
% ... configure traces, substrate
[r, l, g, c] = rlgc(cs, freq);
% Export to Parallel Link Designer for eye diagram analysis
```

## Optimization via S-Parameter Connection Formula

When searching for the optimal lumped element to bridge a gap or load an internal port, re-solving EM for every candidate value is prohibitively slow. Instead, extract the N-port S-matrix once and sweep element values analytically using S-parameter network math.

### Pattern: Extract Once, Sweep Analytically

```matlab
% 1. Build 4-port structure (2 external + 2 internal ports at the gap)
pcb = pcbComponent;
% ... set up geometry with 4 feeds ...
freq = linspace(9e9, 11e9, 101);
S4 = sparameters(pcb, freq, 50, 'SweepOption', 'interp');  % Solve once

% 2. Partition the 4-port S-matrix into external (1,2) and internal (3,4)
S = S4.Parameters;
S11 = S(1:2, 1:2, :);  S12 = S(1:2, 3:4, :);
S21 = S(3:4, 1:2, :);  S22 = S(3:4, 3:4, :);

% 3. Sweep element impedance analytically (no EM re-solve)
Z0 = 50;
Zvals = linspace(1, 500, 1000);  % Candidate impedances
bestS11 = 0;  bestZ = NaN;

for k = 1:numel(Zvals)
    Gamma_L = (Zvals(k) - Z0) / (Zvals(k) + Z0);
    GammaM = Gamma_L * eye(2);
    % S-parameter connection: S_ext = S11 + S12*GammaM*inv(I - S22*GammaM)*S21
    for fi = 1:size(S,3)
        Sext = S11(:,:,fi) + S12(:,:,fi) * GammaM / ...
            (eye(2) - S22(:,:,fi) * GammaM) * S21(:,:,fi);
        s11_dB = 20*log10(abs(Sext(1,1)));
        if s11_dB < bestS11
            bestS11 = s11_dB;  bestZ = Zvals(k);
        end
    end
end
```

### When to Use

| Scenario | Approach |
|----------|----------|
| Swept R/L/C value search | Extract N-port once, sweep analytically |
| Few discrete element options | `pcbElement` with PortValue (re-solves each time) |
| Final validation of optimal value | `pcbElement` with the chosen value for full-wave confirmation |

This technique is orders of magnitude faster than re-solving EM per iteration — Task 8 swept 1000 impedance values in seconds vs. hours of EM solves.

## Pitfalls

1. **pcbcascade substrate match**: Both components must have identical `Substrate`, `Height`, and `Conductor`. `design()` uses different defaults for different object types (e.g. `filterStepImpedanceLowPass` defaults to a custom dielectric while `microstripLine` defaults to Teflon). Always copy substrate properties from one component to the other before calling `pcbcascade`.

2. **Port width matching**: When cascading, the port line width of comp1's output port should match comp2's input port width. Mismatched widths cause impedance discontinuities that aren't physical.

3. **pcbElement port ordering**: `AnalysisPorts` indices must be a subset of the feed indices defined in `FeedLocations`. Port 1 in `AnalysisPorts` corresponds to the first row of `FeedLocations`.

4. **PortNumber vs AnalysisPorts**: Ports listed in `PortNumber` are loaded with lumped elements and NOT available as external analysis ports. Don't include the same port index in both `AnalysisPorts` and `PortNumber`.

5. **Behavioral mode availability**: Not all catalog objects support `Behavioral=true`. The behavioral model is a fast approximation — use `Behavioral=false` for final design validation.

6. **Corporate divider + antenna assembly**: When combining shapes with `+`, ensure they physically overlap or touch. Disjoint shapes create disconnected geometry that won't simulate correctly.

7. **No design() for filterStub**: `filterStub` does not support `design()`. Set stub dimensions manually.

8. **pcbElement Behavioral default is true**: When wrapping a catalog object, `Behavioral` defaults to `true` (fast analytic). Set `Behavioral=false` explicitly for full-wave accuracy.

9. **Port renumbering after cascade**: `pcbcascade(comp1, comp2, portA, portB)` connects `comp1:portA` to `comp2:portB` — those two ports disappear. Surviving ports are renumbered: comp1's remaining ports first (in original order, skipping portA), then comp2's remaining ports (skipping portB). Example: comp1 has ports [1,2], comp2 has ports [1,2,3]. `pcbcascade(comp1, comp2, 2, 1)` produces combined ports: [comp1:1, comp2:2, comp2:3]. Always verify with `show(combined)`.

10. **Ground plane continuity in antenna cascades**: By default, `pcbcascade` does not merge ground planes. Use `'GroundFloodFill', true` for a continuous ground plane, which is essential for microstrip-fed antennas: `pcbcascade(feed, ant, 2, 1, 'GroundFloodFill', true)`.

11. **SI frequency sampling**: Use at least 400 frequency points for wideband SI channels. Too few points cause artifacts in time-domain conversion (eye diagrams).

12. **pcbcascade does not accept lumped elements**: `pcbcascade` only connects `pcbComponent` objects. To combine a PCB component with lumped `resistor`/`capacitor`/`inductor` elements, use the `circuit()` object: wrap the PCB component with `pcbElement`, then `add()` both the pcbElement and lumped elements to a `circuit` with node connections and `setports()`. Example:

```matlab
pe = pcbElement(comp); pe.Name = 'txline';
C = capacitor(100e-12); C.Name = 'Cblock';
R = resistor(50); R.Name = 'Rterm';
ckt = circuit('modified');
add(ckt, [1 2], C);        % Series DC block
add(ckt, [2 3], pe);       % PCB element
add(ckt, [3 0], R);        % Shunt termination
setports(ckt, [1 0], [3 0]);
S = sparameters(ckt, freq);
```

## Related Skills

- `matlab-design-pcb-filter` — Filter objects for cascade
- `matlab-design-pcb-coupler` — Coupler/splitter objects for cascade
- `matlab-assemble-pcb-layout` — Custom geometry with pcbComponent
- `matlab-analyze-em` — S-parameter extraction and field analysis

----

Copyright 2026 The MathWorks, Inc.
