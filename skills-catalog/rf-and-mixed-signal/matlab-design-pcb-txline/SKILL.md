---
name: matlab-design-pcb-txline
description: "Microstrip, stripline, CPW, differential pairs, and crosstalk analysis for impedance-controlled PCB interconnects. TRIGGER: user asks to design or analyze a transmission line (microstrip, stripline, CPW, coplanar, differential pair), extract RLGC or per-unit-length parameters, compute trace impedance, analyze a PCB trace cross-section, or perform crosstalk/coupling analysis. Invoke BEFORE writing code — preferred over RF Toolbox analytical functions (txlineMicrostrip, txlineStripline, txlineCPW). SKIP: EM simulation/S-parameter extraction of an existing component (use matlab-analyze-em), material/stackup definition only (use matlab-manage-pcb-material), building custom non-catalog geometry (use matlab-assemble-pcb-layout), optimization sweeps (use matlab-optimize-pcb-design)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Designing Transmission Lines

## When to Use

- Designing microstrip, stripline, or CPW transmission lines for impedance control
- Modeling differential pairs with or without aggressor traces for NEXT/FEXT crosstalk
- Analyzing 2D cross-sections for fast per-unit-length RLGC extraction
- Creating SIW (substrate integrated waveguide) lines
- Using `design()` to auto-size lines for target impedance at a given frequency

## When NOT to Use

- Building custom PCB structures from shapes — use `matlab-assemble-pcb-layout`
- Setting up substrate or conductor materials — use `matlab-manage-pcb-material`
- Running S-parameter or field analysis after design — use `matlab-analyze-em`
- Cascading transmission lines with other components — use `matlab-integrate-pcb-circuit`

## Tool Selection Priority

1. **RF PCB Toolbox** (default): `microstripLine`, `pcb2D`, `stripLine`, `coplanarWaveguide`, etc.
   - 2D field solver — accurate for loss, coupling, and arbitrary stackups
   - Use for any RLGC, impedance, cross-section, or transmission line design task

2. **RF Toolbox** (fallback only): `txlineMicrostrip`, `txlineStripline`, `txlineCPW`
   - Analytical closed-form approximations, less accurate
   - Use ONLY when: the user explicitly names these functions, or states RF PCB Toolbox is unavailable

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — set up substrate and conductor
2. **This skill:** Design and analyze the transmission line
3. **Check mesh/memory:** `memoryEstimate(obj, fc, 'RetainMesh', true)` — inspect auto-mesh before solving
4. **After:** `matlab-analyze-em` — validate S-parameters → `matlab-optimize-pcb-design` — tune → `matlab-integrate-pcb-circuit` — cascade

## Quick Reference

| Object | Topology | Key Properties |
|--------|----------|---------------|
| `microstripLine` | Single microstrip on ground | Length, Width, Height, GroundPlaneWidth |
| `stripLine` | Signal embedded in dielectric | Length, Width, Height, GroundPlaneWidth |
| `coplanarWaveguide` | CPW on substrate | Length, Width, Height, SlotWidth, GroundPlaneWidth |
| `coupledMicrostripLine` | Edge-coupled microstrip pair | Length, Width, Spacing, Height |
| `coupledStripLine` | Edge-coupled stripline pair | Length, Width, Spacing, Height |
| `microstripLineCustom` | Custom coupled/differential microstrip | TraceType, TraceWidth, TraceSpacing, aggressor traces |
| `stripLineCustom` | Custom coupled/differential stripline | TraceType, TraceWidth, TraceSpacing |
| `pcbBendCustom` | Custom bend discontinuity (R2025a) | BendShape, Height, GroundPlaneWidth |
| `pcb2D` | 2D cross-section analysis | BoardWidth, BoardCenter, Layers |
| `SIWLine` | Substrate integrated waveguide | Length, Width, ViaSpacing, ViaDiameter |

## Microstrip Line

### Basic Creation and Design

```matlab
ms = microstripLine;
show(ms);

% Design for target impedance at frequency
ms = design(microstripLine, 3e9);
Z0 = getZ0(ms);
```

### Properties

```matlab
ms = microstripLine;
ms.Length = 20e-3;
ms.Width = 5e-3;
ms.Height = 1.6e-3;            % Substrate height
ms.GroundPlaneWidth = 30e-3;
ms.Substrate = dielectric("FR4");
ms.Conductor = metal("Copper");
```

### Analysis

```matlab
ms.Conductor = metal("Copper");       % Required for rlgc (finite conductivity)
Z0 = getZ0(ms);                       % Characteristic impedance (no frequency argument)
td = propagationDelay(ms, 3e9);       % Propagation delay (scalar frequency)
params = rlgc(ms, 3e9);              % RLGC per unit length (scalar frequency)

freq = linspace(1e9, 6e9, 51);
sp = sparameters(ms, freq, 'SweepOption', 'interp');  % S-parameters (frequency vector OK)
rfplot(sp);
```

### Inverted / Suspended Microstrip

Model inverted or suspended configurations with multi-layer substrates (air gaps):

```matlab
% Inverted: air below trace, substrate above ground
ms = microstripLine;
ms.Substrate = dielectric(Name={"Air","FR4"}, EpsilonR=[1 4.4], ...
    LossTangent=[0 0.02], Thickness=[0.5e-3 1.6e-3]);
ms.Height = 0.5e-3 + 1.6e-3;

% Suspended: air / substrate / air
ms.Substrate = dielectric(Name={"Air","FR4","Air"}, EpsilonR=[1 4.4 1], ...
    LossTangent=[0 0.02 0], Thickness=[0.3e-3 0.8e-3 0.3e-3]);
ms.Height = sum([0.3e-3 0.8e-3 0.3e-3]);
```

## Stripline

Stripline has the signal trace embedded between two ground planes.

### Symmetric Stripline

```matlab
sl = stripLine;
sl.Length = 20e-3;
sl.Width = 3e-3;
sl.Height = 3.2e-3;            % Total dielectric height (top + bottom)
sl.GroundPlaneWidth = 30e-3;
sl.Substrate = dielectric("Teflon");
sl.Conductor = metal("Copper");
show(sl);
```

### Asymmetric Stripline

Use multi-layer dielectric with different thicknesses above and below. `Height` = cumulative thickness of layers **below** the signal (a layer boundary, not the total):

```matlab
sl = stripLine;
sl.Substrate = dielectric(Name={"FR4","FR4"}, EpsilonR=[4.4 4.4], ...
    LossTangent=[0.02 0.02], Thickness=[0.8e-3 1.6e-3]);
sl.Height = 0.8e-3;    % Signal at the boundary between the two layers
```

### Suspended Stripline

```matlab
sl = stripLine;
sl.Substrate = dielectric(Name={"Air","FR4","Air"}, ...
    EpsilonR=[1 4.4 1], LossTangent=[0 0.02 0], ...
    Thickness=[0.5e-3 0.8e-3 0.5e-3]);
sl.Height = 0.5e-3;    % Signal at Air/FR4 boundary (0.5mm from ground)
sl = design(stripLine, 3e9);  % Or design for 50-ohm at target freq
```

## Coplanar Waveguide

### Basic CPW

```matlab
cpw = coplanarWaveguide;
cpw.Length = 20e-3;
cpw.Width = 2e-3;          % Center conductor width
cpw.SlotWidth = 0.5e-3;    % Gap between center and ground
cpw.Height = 1.6e-3;
cpw.GroundPlaneWidth = 10e-3;
show(cpw);
```

### Design and Analyze

```matlab
cpw = design(coplanarWaveguide, 5e9);
Z0 = getZ0(cpw);
sp = sparameters(cpw, linspace(1e9, 10e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

## Coupled Transmission Lines

### Edge-Coupled Microstrip

```matlab
cms = coupledMicrostripLine;
cms.Length = 20e-3;
cms.Width = 2e-3;
cms.Spacing = 0.5e-3;      % Gap between traces
cms.Height = 1.6e-3;
cms.Substrate = dielectric("FR4");
show(cms);
```

### Even/Odd Mode Impedance

```matlab
freq = 3e9;
Zeven = getZEven(cms, freq);   % Even-mode impedance
Zodd = getZOdd(cms, freq);     % Odd-mode impedance
Zdiff = 2 * Zodd;             % Differential impedance
```

### Edge-Coupled Stripline

```matlab
csl = coupledStripLine;
csl.Length = 20e-3;
csl.Width = 2e-3;
csl.Spacing = 0.3e-3;
csl.Height = 3.2e-3;
csl.Substrate = dielectric("Teflon");
```

### Multi-Layer Coupled Lines

```matlab
cms = coupledMicrostripLine;
sub = dielectric("FR4", "Teflon");
sub.Thickness = [1.0e-3 0.5e-3];       % Set Thickness BEFORE assigning to component
cms.Substrate = sub;
cms.Height = 1.5e-3;
```

## Custom Transmission Lines and Crosstalk Analysis

`microstripLineCustom` and `stripLineCustom` model differential pairs with optional aggressor traces for NEXT/FEXT crosstalk analysis.

### Properties (`microstripLineCustom`; `stripLineCustom` has same interface, Teflon default, embedded between ground planes)

| Property | Default | Description |
|----------|---------|-------------|
| `TraceType` | `'Single'` | `'Single'` or `'Differential'` (NOT `'Single-ended'`) |
| `TraceLength` | `0.05` | Trace length (m) |
| `TraceWidth` | `0.002` | Signal trace width (m) |
| `TraceSpacing` | `0.002` | Spacing between differential pair traces (m) |
| `Height` | `0.0016` | Substrate height (m) |
| `GroundPlaneWidth` | (read-only) | Ground plane width — auto-computed, cannot be set |
| `LeftCoupledTraceGap` | `0` | Gap to left aggressor trace (m); 0 = no left aggressor |
| `RightCoupledTraceGap` | `0` | Gap to right aggressor trace (m); 0 = no right aggressor |
| `Substrate` | FR4 | Dielectric object |
| `Conductor` | PEC | Metal object |

### Differential Microstrip

```matlab
ms_diff = microstripLineCustom(TraceType='Differential', ...
    TraceWidth=0.002, TraceSpacing=0.0005);
show(ms_diff);
```

### Differential with Aggressor Traces

```matlab
ms_diff = microstripLineCustom(TraceType='Differential', ...
    TraceWidth=0.002, TraceSpacing=0.0005, ...
    RightCoupledTraceGap=[0.003, 0.003], ...
    LeftCoupledTraceGap=0);
show(ms_diff);
```

### NEXT/FEXT Extraction

With aggressor traces, the S-parameter matrix is 6-port. Port mapping:

| Port | Trace |
|------|-------|
| 1, 2 | Differential pair (near end, far end) |
| 3, 4 | Left aggressor (near end = NEXT, far end = FEXT) |
| 5, 6 | Right aggressor (near end = NEXT, far end = FEXT) |

```matlab
ms = microstripLineCustom(TraceType='Differential', ...
    TraceWidth=0.002, TraceSpacing=0.0005, ...
    LeftCoupledTraceGap=0.003, RightCoupledTraceGap=0.003);
ms.Conductor = metal("Copper");

freq = linspace(0.1e9, 10e9, 101);
sp = sparameters(ms, freq, 'SweepOption', 'interp');

% Extract crosstalk from S-parameters
S31_dB = 20*log10(abs(squeeze(sp.Parameters(3,1,:))));  % Left NEXT
S41_dB = 20*log10(abs(squeeze(sp.Parameters(4,1,:))));  % Left FEXT
S51_dB = 20*log10(abs(squeeze(sp.Parameters(5,1,:))));  % Right NEXT
S61_dB = 20*log10(abs(squeeze(sp.Parameters(6,1,:))));  % Right FEXT
```

### RLGC Coupling Matrices

For coupled/differential lines, `rlgc` returns N×N matrices (off-diagonal = mutual L/C):

```matlab
ms = microstripLineCustom(TraceType='Differential', ...
    TraceWidth=0.002, TraceSpacing=0.0005, RightCoupledTraceGap=0.003);
ms.Conductor = metal("Copper");
params = rlgc(ms, 5e9);
```

## Custom Bends and Traces (R2025a)

`pcbBendCustom` and `pcbTraceCustom` model bend discontinuities and step-impedance transitions. See [references/custom-bends-and-traces.md](references/custom-bends-and-traces.md) for properties and examples.

## SIW Transmission Line

Substrate Integrated Waveguide uses via fences to create a waveguide in PCB.

```matlab
siw = SIWLine;
siw.Length = 15.3e-3;
siw.Width = 7.4e-3;
siw.ViaSpacing = [1.2e-3 5e-3];   % [along-length, across-width]
siw.ViaDiameter = 0.51e-3;
siw.Height = 0.254e-3;
siw.Substrate = dielectric(Name="RO4003C", EpsilonR=3.38, LossTangent=0.0027, Thickness=0.254e-3);
siw.Conductor = metal("Copper");
show(siw);

sp = sparameters(siw, linspace(20e9, 40e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

The SIW has a `FeedLine` property (a `traceTapered` object) for the microstrip-to-SIW transition.

## 2D Cross-Section Analysis

### pcb2D

Creates a 2D cross-section model for fast per-unit-length analysis. Much faster than full 3D `sparameters` for uniform transmission line characterization.

```matlab
p = pcb2D;
p = pcb2D(Name=Value);
```

**Key Properties:**
- `Name` — Descriptive name for the cross-section
- `BoardWidth` — Total board width (m)
- `BoardCenter` — Center position of the board cross-section
- `Layers` — Cell array of `trace2D` and `dielectric` objects defining the stackup

**Methods:** `show(p)`, `sparameters(p, freq)`, `rlgc(p, scalarFreq)`, `propagationDelay(p, scalarFreq)`

### trace2D

Represents a trace cross-section for use inside a `pcb2D` object's `Layers` cell array.

```matlab
t = trace2D;
t.Type = 'Signal';                                  % 'Signal' (default) or 'Ground'
t.Shape = shape.Rectangle(Length=0.3e-3, Width=35e-6);  % Length=trace width, Width=trace thickness
t.Conductor = metal("Copper");
```

**Key Properties:** `Type` (`'Signal'`/`'Ground'`), `Shape` (`shape.Rectangle` — `Length` = trace width, `Width` = metal thickness), `Conductor`, `TrapezoidalEtchAngle`

### Building a 2D Model — Single Trace

```matlab
sub = dielectric("FR4");
sub.Thickness = 0.2e-3;

sig = trace2D;
sig.Type = 'Signal';
sig.Shape = shape.Rectangle(Length=0.3e-3, Width=35e-6);
sig.Conductor = metal("Copper");

gnd = trace2D;
gnd.Type = 'Ground';
gnd.Shape = shape.Rectangle(Length=5e-3, Width=35e-6);

p = pcb2D(BoardWidth=5e-3, Layers={sig, sub, gnd});
show(p);
params = rlgc(p, 10e9);
fprintf('L = %.2f nH/m, C = %.2f pF/m\n', params.L*1e9, params.C*1e12);
```

### Building a 2D Model — Differential Pair (Coupled Traces)

Multiple traces on the **same metal layer** must be passed as a `trace2D` array `[sig1, sig2]`, not separate cells:

```matlab
sub = dielectric("FR4");
sub.Thickness = 0.2e-3;

sig1 = trace2D;
sig1.Type = 'Signal';
sig1.Shape = shape.Rectangle(Length=0.15e-3, Width=35e-6);
sig1.Shape.Center = [-0.2e-3 0];
sig1.Conductor = metal("Copper");

sig2 = trace2D;
sig2.Type = 'Signal';
sig2.Shape = shape.Rectangle(Length=0.15e-3, Width=35e-6);
sig2.Shape.Center = [0.2e-3 0];
sig2.Conductor = metal("Copper");

gnd = trace2D;
gnd.Type = 'Ground';
gnd.Shape = shape.Rectangle(Length=5e-3, Width=35e-6);

p = pcb2D(BoardWidth=5e-3, Layers={[sig1, sig2], sub, gnd});
show(p);
params = rlgc(p, 10e9);  % Returns 2x2 L and C matrices for coupled pair
```

### When to Use pcb2D vs 3D

| Scenario | Approach |
|---|---|
| Impedance/RLGC of uniform cross-section | `pcb2D` — milliseconds |
| Discontinuities (bends, steps, stubs) | 3D `sparameters` — minutes |
| Differential pair coupling | `pcb2D` with `[sig1, sig2]` array |

### Slicing a 3-D Component to 2-D

`slice` extracts a 2-D cross section from a `pcbComponent` (convert catalog objects first):

```matlab
cms = design(coupledMicrostripLine, 3e9);
cms.Conductor = metal("Copper");
pcb2d = slice(pcbComponent(cms));
params = rlgc(pcb2d, 3e9);
```

## design() for Impedance Targeting

The `design` function sizes a transmission line for a target frequency (and optionally impedance):

```matlab
ms = design(microstripLine, 3e9);           % Default 50-ohm at 3 GHz
sl = design(stripLine, 5e9);                % Default 50-ohm at 5 GHz
cpw = design(coplanarWaveguide, 10e9);      % Default 50-ohm at 10 GHz
```

After `design`, verify with `getZ0`:

```matlab
Z0 = getZ0(ms);   % Should be ~50 ohm
```

## transmissionLineDesigner App

Interactive app for designing and analyzing transmission lines:

```matlab
transmissionLineDesigner
```

Select line type, set dimensions/materials interactively, analyze impedance/S-parameters/RLGC, and export designs to workspace.

## Design Adjustments

| Problem | Adjust | Direction |
|---|---|---|
| Z0 too high | Width | Increase |
| Z0 too low | Width | Decrease |
| Too lossy | Conductor thickness | Increase |
| Wrong electrical length | Length | Adjust |

## Pitfalls
1. **Use interpolating sweep for S-parameters**: Always use `sparameters(obj, freq, 'SweepOption', 'interp')` — direct sweeps are significantly slower.
2. **Check mesh density before solving**: Run `memoryEstimate(obj, fc, 'RetainMesh', true)` before `sparameters()`. If too dense, coarsen: `mesh(obj, 'MaxEdgeLength', lambda/6)`. See `matlab-analyze-em`.
3. **Height meaning differs by topology**: For microstrip, `Height` = dielectric thickness. For stripline with multi-layer substrate, `Height` must equal a cumulative layer boundary — it defines where the signal sits in the stack.
4. **Width controls impedance**: Wider trace → lower impedance. Use `design()` to auto-size, then adjust manually if needed.
5. **Conductor defaults to PEC**: Without assigning `metal("Copper")`, loss will be zero. Always set `Conductor` for realistic insertion loss.

6. **Inverted/suspended microstrip Height rule**: For inverted microstrip, create multi-layer dielectric with `Name={"Substrate","Air"}` and set `Height` to air layer thickness. For suspended microstrip, `Height` = sum of air + substrate thickness.

7. **Multi-layer stripline Height is a layer boundary, not total**: `Height` must equal a cumulative layer boundary from `Thickness` vector. Setting Height to total causes "Expected Height must be among the substrate layers."

8. **SIW cutoff**: SIW has a cutoff frequency below which signals do not propagate. Size the width for operation well above cutoff.

9. **getZ0 takes no frequency**: `getZ0(obj)` returns characteristic impedance directly. Do not pass a frequency argument.

10. **rlgc requires finite conductivity**: Assign `metal("Copper")` before calling `rlgc`. Default PEC causes "Conductivity value must be finite with 2D field solver."

11. **Multi-layer Name must use cell array**: Use `Name={"Air","FR4"}` (cell array), not `Name=["Air","FR4"]` (string array).

12. **trace2D uses Shape, not Width/Thickness**: Set `t.Shape = shape.Rectangle(Length=traceWidth, Width=metalThickness)`. Note: `shape.Rectangle.Length` = trace width, `.Width` = metal thickness. A `pcb2D` requires at least one `'Ground'` type trace.

13. **pcb2D rlgc takes scalar frequency**: `rlgc(p, freq)` requires a scalar, not a vector. Loop or call once at the frequency of interest.

14. **pcb2D trace2D Center is x-position only**: `trace2D.Shape.Center` controls horizontal position. Vertical is from layer stacking order. Set `Center = [x_offset 0]`.

15. **Same-layer traces need array, not separate cells**: For coupled/differential traces on the same metal layer, use `Layers={[sig1, sig2], sub, gnd}`. Separate cells `{sig1, sig2, sub, gnd}` treats them as different metal layers and errors: "dielectric layer must be between metal layers."

16. **Crosstalk port count depends on aggressor configuration**: Both aggressors → 6-port; one → 4-port; none → 2-port. `RightCoupledTraceGap=Inf` removes that aggressor.

17. **TraceGap is edge-to-edge, not center-to-center**: Measures gap between nearest edges, not trace centers.

18. **Use `TraceWidth`, not `Width`**: `microstripLineCustom` and `stripLineCustom` use `TraceWidth`. Setting `Width` silently has no effect.

## Related Skills

- `matlab-manage-pcb-material` — Substrate and conductor setup
- `matlab-analyze-em` — S-parameter extraction and field analysis
- `matlab-integrate-pcb-circuit` — Touchstone export, circuit cascading
- `matlab-assemble-pcb-layout` — Custom trace geometries

----

Copyright 2026 The MathWorks, Inc.
