---
name: matlab-design-pcb-coupler
description: "Wilkinson, branchline, ratrace, directional couplers, corporate dividers, Rotman lenses for power splitting and beam-forming. TRIGGER: user asks to design, create, or analyze any coupler, splitter, power divider, combiner, or Rotman lens. Invoke BEFORE writing code — class names and design() availability vary per coupler type. SKIP: EM simulation/S-parameter extraction of an existing component (use matlab-analyze-em), building custom non-catalog geometry (use matlab-assemble-pcb-layout), material/stackup setup only (use matlab-manage-pcb-material), cascading multiple components (use matlab-integrate-pcb-circuit)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Designing Couplers and Splitters

## When to Use

- Designing Wilkinson splitters (equal, unequal, wideband) for power division
- Creating branchline or ratrace couplers for quadrature or sum/difference networks
- Building corporate power dividers for array feed networks
- Designing directional couplers for signal sampling
- Creating SIW splitters or Rotman lenses for beam-forming

## When NOT to Use

- Designing transmission lines — use `matlab-design-pcb-transmission-line`
- Designing filters — use `matlab-design-pcb-filter`
- Designing passive components (inductors, capacitors, baluns) — use `matlab-design-pcb-passive`
- Cascading couplers with other components — use `matlab-integrate-pcb-circuit`
- Optimizing coupler performance — use `matlab-optimize-pcb-design`

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — set up substrate and conductor
2. **This skill:** Design the coupler or splitter
3. **Check mesh/memory:** `memoryEstimate(obj, fc, 'RetainMesh', true)` — inspect auto-mesh density before committing to a full solve
4. **After:** `matlab-analyze-em` — validate S-parameters → `matlab-optimize-pcb-design` — tune dimensions → `matlab-integrate-pcb-circuit` — cascade into larger network

## Quick Reference — Component Selection

| Object | Type | Ports | Best For |
|--------|------|-------|----------|
| `wilkinsonSplitter` | Equal power divider | 3 | Standard 2-way equal split |
| `wilkinsonSplitterUnequal` | Unequal power divider | 3 | Asymmetric power distribution |
| `wilkinsonSplitterWideband` | Wideband equal divider | 3 | Multi-octave equal split |
| `couplerBranchline` | 90° hybrid | 4 | Quadrature combining/splitting |
| `couplerBranchlineWideband` | Wideband 90° hybrid | 4 | Multi-section wideband quadrature |
| `couplerRatrace` | 180° hybrid | 4 | Sum/difference networks |
| `couplerDirectional` | Directional coupler | 4 | Sampling, multi-section symmetric |
| `splitterTee` | T-junction | 3 | Simple reactive split |
| `powerDividerCorporate` | N-way corporate | N+1 | Array feed networks |
| `SIWSplitter` | SIW power divider | 3 | High-freq waveguide split |
| `rotmanLens` | Beam-forming network | N beam + N array | True-time-delay phased arrays |

## Wilkinson Splitters

### Equal Split

```matlab
ws = design(wilkinsonSplitter, 3e9);
show(ws);
memoryEstimate(ws, 3e9, 'RetainMesh', true);  % Check mesh before solving
sp = sparameters(ws, linspace(1e9, 5e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

Key properties: `SplitLineLength`, `SplitLineWidth`, `Resistance`, `PortLineLength`, `PortLineWidth`, `GroundPlaneWidth`.

### Unequal Split

```matlab
ws = wilkinsonSplitterUnequal;
ws = design(ws, 3e9);
show(ws);
```

The power division ratio is controlled by the impedance transformation arms.

**Property reference (2-element vector properties):**

| Property | Description | Default |
|---|---|---|
| `SplitLineLength` | Length of split lines (m) | `0.0279` |
| `SplitLineWidth` | Width of split lines (m) | `[0.0014 0.0049]` (2-element vector: one per arm) |
| `MatchLineLength` | Length of output matching lines (m) | `0.0277` |
| `MatchLineWidth` | Width of output matching lines (m) | `[0.0039 0.0066]` (2-element vector: one per arm) |
| `Resistance` | Isolation resistor (ohms) | `106` |

### Wideband Wilkinson

Multi-section for extended bandwidth:

```matlab
ws = wilkinsonSplitterWideband;
ws = design(ws, 5e9);
show(ws);
sp = sparameters(ws, linspace(2e9, 8e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

**Property reference (vector properties scale with `NumSections`):**

| Property | Description | Default (3 sections) |
|---|---|---|
| `NumSections` | Number of cascaded sections | `3` |
| `Shape` | Shape of sections | `"Rectangular"` (`"Circular"`) |
| `SplitLineWidth` | Width of quarter-wave transformers (m) | `[8.55e-04 0.0014 0.0021]` (vector, one per section) |
| `Resistance` | Isolation resistor values (ohms) | `[100 183.40 141.42]` (vector, one per section) |

### Multi-Layer Wilkinson

```matlab
ws = design(wilkinsonSplitter, 5e9);
sub = dielectric("FR4", "Teflon");
sub.Thickness = [1e-3 0.5e-3];         % Set Thickness BEFORE assigning to component
ws.Substrate = sub;
ws.Height = 1.5e-3;
show(ws);
```

## Branchline Couplers

### Standard (Single-Section)

```matlab
bl = design(couplerBranchline, 5e9);
show(bl);

freq = linspace(3e9, 7e9, 51);
sp = sparameters(bl, freq, 'SweepOption', 'interp');
rfplot(sp);
```

Key properties: `SeriesArmLength`, `SeriesArmWidth`, `ShuntArmLength`, `ShuntArmWidth`, `PortLineLength`, `PortLineWidth`.

### Wideband (Multi-Section)

```matlab
blw = couplerBranchlineWideband;
blw.NumSections = 3;
blw = design(blw, 5e9);
show(blw);
```

**Property reference (vector properties scale with `NumSections`):**

| Property | Description | Default (2 sections) |
|---|---|---|
| `NumSections` | Number of branchline sections | `2` |
| `SeriesArmWidth` | Width of series arms (m) | `0.0051` (scalar or vector) |
| `ShuntArmWidth` | Width of shunt arms (m) | `[0.00096 0.0029 0.00096]` (vector, NumSections+1 elements) |
| `IsShielded` | Add metal shielding | `false` |

### Branchline with DGS

Adding DGS improves directivity and isolation:

```matlab
bl = design(couplerBranchline, 5e9);
dgsShape = dumbbell;
dgsShape.SideLength = 3e-3;       % Head size (default Type='Square')
dgsShape.ArmLength = 5e-3;
dgsShape.ArmWidth = 0.3e-3;
bl = dgs(bl, {dgsShape});         % Must capture return value
show(bl);
```

### Analysis Methods for Couplers

```matlab
freq = linspace(3e9, 7e9, 51);

% Coupling factor (S31 for branchline)
coupling(bl, freq);

% Directivity
directivity(bl, freq);

% Isolation (S41 for branchline)
isolation(bl, freq);
```

## Ratrace Coupler

180° hybrid (sum/difference port):

```matlab
rr = design(couplerRatrace, 5e9);
show(rr);

freq = linspace(3e9, 7e9, 51);
sp = sparameters(rr, freq, 'SweepOption', 'interp');
rfplot(sp);

% Analysis
coupling(rr, freq);
directivity(rr, freq);
isolation(rr, freq);
```

Key properties: `RingRadius`, `RingWidth`, `PortLineWidth`, `PortLineLength`.

### Charge and Current on Ratrace

```matlab
figure; current(rr, 5e9);
figure; charge(rr, 5e9);
```

## Directional Coupler

Multi-section symmetric directional coupler. **Note:** `couplerDirectional` does not have a `design` function — set properties manually:

```matlab
dc = couplerDirectional;
dc.NumSections = 3;
dc.Width = [2.8e-3 2.8e-3 2.8e-3];       % One value per section
dc.Spacing = [1.3e-3 1.3e-3 1.3e-3];     % One value per section
dc.GroundPlaneLength = 0.15;               % Must accommodate total length
show(dc);

freq = linspace(3e9, 7e9, 51);
coupling(dc, freq);
directivity(dc, freq);
```

Key properties: `NumSections`, `Length` (scalar), `Width` (vector, one per section), `Spacing` (vector, one per section), `PortLineWidth`, `GroundPlaneLength`.

## Tee Junction and Corporate Dividers

### Splitter Tee

Simple reactive T-junction. The `Shape` property controls the junction geometry:

| Shape Value | Description |
|---|---|
| `'RectangularMitered'` | Rectangular with mitered bends (default) |
| `'RectangularCurved'` | Rectangular with curved bends |
| `'Circular'` | Circular junction |

```matlab
st = splitterTee;
st = design(splitterTee, 5e9);
show(st);
sp = sparameters(st, linspace(3e9, 7e9, 51), 'SweepOption', 'interp');
rfplot(sp);

% Circular shape variant
st2 = splitterTee(Shape='Circular');
st2 = design(st2, 5e9);
show(st2);
```

### Corporate Power Divider (N-way)

For array feed networks:

```matlab
cpd = powerDividerCorporate;
cpd.NumOutputPorts = 4;       % 1:4 divider
cpd = design(cpd, 5e9);
show(cpd);
sp = sparameters(cpd, linspace(3e9, 7e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

### 8-Way Corporate Divider

```matlab
cpd = powerDividerCorporate;
cpd.NumOutputPorts = 8;
cpd = design(cpd, 2.4e9);
show(cpd);
```

## SIW Splitter

```matlab
siw_s = SIWSplitter;
siw_s = design(siw_s, 10e9);
show(siw_s);
```

The `FeedLine` property is a `traceTapered` object controlling the microstrip-to-SIW transition:

```matlab
siw_s.FeedLine.InputWidth = 1e-3;
siw_s.FeedLine.OutputWidth = 3e-3;
show(siw_s);
```

## Design Workflow

1. **Select topology** based on requirements (equal/unequal split, bandwidth, isolation)
2. **Design at center frequency**: `obj = design(ObjectType, fc)`
3. **Visualize**: `show(obj)`
4. **Analyze S-parameters**: `sparameters(obj, freq, 'SweepOption', 'interp')`
5. **Check metrics**: `coupling`, `directivity`, `isolation`
6. **Customize**: Adjust properties for specific impedance, substrate, dimensions
7. **Optimize** if needed (see `matlab-optimize-pcb-design`)

## Coupler-Specific Analysis Functions

These functions are available on 4-port coupler objects: `couplerBranchline`, `couplerBranchlineWideband`, `couplerRatrace`, `couplerDirectional`.

| Function | What It Measures | Signature |
|---|---|---|
| `coupling(obj, freq)` | Coupling factor (dB) — power transferred to coupled port | Plots by default; `cVal = coupling(obj, freq)` returns values |
| `directivity(obj, freq)` | Directivity (dB) — separation of forward vs. backward coupled power | Plots by default; `dVal = directivity(obj, freq)` returns values |
| `isolation(obj, freq)` | Isolation (dB) — power leakage to the isolated port | Plots by default; `iVal = isolation(obj, freq)` returns values |

```matlab
c = design(couplerBranchline, 2.4e9);
freq = linspace(2e9, 3e9, 101);

coupling(c, freq);              % plots coupling factor
cVal = coupling(c, freq);       % returns numeric values (dB)

directivity(c, freq);           % plots directivity
dVal = directivity(c, freq);    % returns numeric values (dB)

isolation(c, freq);             % plots isolation
iVal = isolation(c, freq);      % returns numeric values (dB)
```

## Port Numbering Convention

### 3-Port (Splitters)

| Port | Function |
|------|----------|
| 1 | Input |
| 2 | Output (through) |
| 3 | Output (split) |

### 4-Port (Couplers)

| Port | Branchline | Ratrace |
|------|-----------|---------|
| 1 | Input | Input |
| 2 | Through (-3dB, 0°) | Sum |
| 3 | Coupled (-3dB, -90°) | Difference |
| 4 | Isolated | Through |

## Rotman Lens (Beam-Forming Network)

`rotmanLens` is an N-beam, N-array true-time-delay beam-forming network.

```matlab
lens = rotmanLens;
lens.NumBeamPorts  = 4;
lens.NumArrayPorts = 4;
lens.NumDummyPorts = 4;       % Absorb reflected energy at lens edges
lens.BeamPortAngle = 40;      % Angular spread of beam ports (degrees)
lens.MaxScanAngle  = 30;      % Maximum scan angle (degrees)
lens.Height        = 5.08e-4;
lens.Conductor     = metal("Copper");
show(lens);
layout(lens);
```

Key properties: `OnaxisFocalLength`, `OffaxisFocalLength` (auto-computed from scan angle). `BeamTaper` and `ArrayTaper` control the tapered feed line shapes (`traceTapered` objects).

## SIW Power Divider

`SIWSplitter` is a substrate integrated waveguide 1:2 power divider.

```matlab
s = SIWSplitter;
s.InputLineLength = 0.0155;
s.SplitLineLength = 0.0145;
s.Width           = 0.0125;
s.ViaSpacing      = [0.0017, 0.011];    % [wall via spacing, split via spacing]
s.ViaDiameter     = 5e-4;
s.PostDiameter    = 2.54e-4;
s.PostOffsetX     = 5.5e-3;
s.Height          = 8e-4;
show(s);
```

Custom feed lines via `FeedLine` property:

```matlab
s.FeedLine = traceRectangular(Length=3e-3, Width=2e-3);
```

## Pitfalls

1. **Use interpolating sweep for S-parameters**: Always use `sparameters(obj, freq, 'SweepOption', 'interp')` for MoM solves. Direct sweeps solve at every frequency point individually and are significantly slower.

2. **Check mesh density before solving**: Catalog couplers generate dense auto-meshes that dominate runtime. Always run `memoryEstimate(obj, fc, 'RetainMesh', true)` before `sparameters()`. If memory is excessive, coarsen: `mesh(obj, 'MaxEdgeLength', lambda/6)`. See `matlab-analyze-em` for full mesh inspection workflow.

3. **Resistance in Wilkinson**: The isolation resistor value defaults to 100 ohm (2×Z0). For non-50-ohm systems, adjust `Resistance` property accordingly.

4. **Port numbering varies**: Different coupler types number ports differently. Always check with `show(obj)` which port is which before interpreting S-parameters.

5. **Wideband coupler sections**: More sections = wider bandwidth but larger size. Each section adds approximately a quarter-wavelength at center frequency.

6. **Corporate divider symmetry**: `powerDividerCorporate` requires `NumOutputPorts` to be a power of 2 (2, 4, 8, 16...).

7. **Corporate divider substrate**: `powerDividerCorporate.Substrate` is read-only. Set the substrate on `corp.SplitterElement.Substrate` instead — the corporate divider builds from its unit `SplitterElement` (a `wilkinsonSplitter`). Note: `design()` may override the substrate thickness.

8. **Corporate dividers have large mesh**: Multi-way corporate dividers are physically large structures. Memory requirements can exceed hundreds of GB at high frequencies. Use behavioral S-parameters (`'Behavioral', true`) for fast amplitude/phase balance verification when full-wave is infeasible.

9. **Set substrate BEFORE design()**: `design(obj, fc)` auto-sizes dimensions based on the current substrate. Setting substrate after `design()` changes the material but does NOT re-compute dimensions — causing incorrect impedance. Always: set `Substrate` first, then call `design()`.

10. **DGS coupling**: Adding DGS to couplers can improve directivity by 10-15 dB but slightly shifts center frequency. Re-tune after adding DGS.

11. **SplitterTee is reactive**: Unlike Wilkinson, the T-junction is a reactive (lossless) split — output ports are not isolated from each other. Use Wilkinson when isolation matters.

12. **No design() for couplerDirectional**: `couplerDirectional` does not support `design()`. Set `Length`, `Width`, `Spacing`, and `NumSections` manually.

13. **couplerDirectional multi-section dimensions**: When `NumSections > 1`, `Width` and `Spacing` must be vectors with one element per section. `Length` remains scalar. Also increase `GroundPlaneLength` to accommodate the longer structure — the default only fits 1 section.

14. **Cascading couplers with stubs/resonators**: To physically attach a stub or resonator to a coupler port, use `pcbcascade(pcbComponent(coupler), pcbComponent(stub), portA, portB)`. Match `Height`, `Substrate`, and `Conductor` between the two objects. The connected ports disappear — verify surviving port count with `show(combined)`. See `matlab-integrate-pcb-circuit` for cascade details.

15. **Catalog couplers are MoM-only**: Objects like `couplerBranchline` only support MoM natively. To use FEM, wrap in `pcbComponent` and set `SolverType` after construction (not during):
    ```matlab
    bl = design(couplerBranchline, 5e9);
    pcb = pcbComponent(bl);
    pcb.SolverType = 'FEM';
    s = solver(pcb);
    s.BoundaryCondition = 'perfectly-matched-layer';
    ```
    Do NOT pass `SolverType` as a name-value to `pcbComponent()`. FEM requires the IDMF solver engine (WSL on Windows) — if `idmf_hub` is missing, use MoM instead. See `matlab-analyze-em` for FEM prerequisites and troubleshooting.

## Related Skills

- `matlab-manage-pcb-material` — Substrate configuration
- `matlab-analyze-em` — S-parameter and field analysis
- `matlab-optimize-pcb-design` — Optimizing coupler/splitter performance
- `matlab-integrate-pcb-circuit` — Combining splitters with other components

----

Copyright 2026 The MathWorks, Inc.
