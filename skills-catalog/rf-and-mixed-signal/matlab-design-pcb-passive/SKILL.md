---
name: matlab-design-pcb-passive
description: "Spiral inductors, interdigital capacitors, baluns, resonators, phase shifters for impedance matching, DC blocking, and bias tees. TRIGGER: user asks to design or create a spiral inductor, interdigital capacitor, balun, resonator, phase shifter, or other passive RF component. Invoke BEFORE writing code — class names and property patterns are non-obvious. SKIP: filter design (use matlab-design-pcb-filter), coupler/splitter design (use matlab-design-pcb-coupler), transmission line design (use matlab-design-pcb-txline), EM analysis (use matlab-analyze-em), material setup only (use matlab-manage-pcb-material)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Designing Passive Components

## When to Use

- Designing spiral inductors or interdigital capacitors for RF circuits
- Extracting inductance, capacitance, or self-resonant frequency from passive components
- Creating ring or split-ring resonators for filtering or metamaterial applications
- Designing coupled-line or Marchand baluns for balanced-to-unbalanced conversion
- Building Schiffman phase shifters or radial stubs

## When NOT to Use

- Designing transmission lines (microstrip, stripline, CPW) — use `matlab-design-pcb-txline`
- Designing filters (bandpass, lowpass, bandstop) — use `matlab-design-pcb-filter`
- Designing couplers or splitters — use `matlab-design-pcb-coupler`
- Setting up substrate materials — use `matlab-manage-pcb-material`
- Running EM analysis after design — use `matlab-analyze-em`

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — set up substrate and conductor
2. **This skill:** Design the passive component (inductor, capacitor, balun, resonator)
3. **Check mesh/memory:** `memoryEstimate(obj, fc, 'RetainMesh', true)` — inspect auto-mesh density before committing to a full solve
4. **After:** `matlab-analyze-em` — validate S-parameters → `matlab-optimize-pcb-design` — tune dimensions → `matlab-integrate-pcb-circuit` — cascade into circuit

## Quick Reference

| Task | Code |
|------|------|
| Spiral inductor | `ind = spiralInductor` |
| Interdigital capacitor | `cap = interdigitalCapacitor` |
| Extract inductance | `L = inductance(ind, freq)` |
| Extract capacitance | `C = capacitance(cap, freq, DeEmbed=true)` |
| Behavioral S-params | `S = sparameters(obj, freq, Behavioral=true)` |
| Ring resonator | `r = design(resonatorRing, freq)` |
| Split-ring (custom) | `r = resonatorSplitRingCustom` |
| Split-ring (square) | `r = resonatorSplitRingSquare` |
| Coupled-line balun | `b = balunCoupledLine` |
| Marchand balun | `b = balunMarchand` |
| Phase shifter | `ps = design(phaseShifter, freq, PhaseShift=90)` |
| Radial stub | `stub = stubRadialShunt` |
| Optimize | `optimize(obj, freq, ...)` |

## Spiral Inductors

### Creating and Configuring

```matlab
ind = spiralInductor;
ind.SpiralShape    = 'Square';      % 'Square' | 'Circle' | 'Hexagon' | 'Octagon'
ind.InnerDiameter  = 5e-4;
ind.Width          = 2.5e-4;
ind.Spacing        = 2.5e-4;
ind.NumTurns       = 4;
ind.Height         = 1.016e-3;      % Must be a cumulative substrate layer boundary
ind.GroundPlaneLength = 5.6e-3;
ind.GroundPlaneWidth  = 5.6e-3;
```

### RFIC Substrates (Silicon/SiO2)

```matlab
ind = spiralInductor;
ind.Substrate = dielectric('Name', {'Silicon','SiO2'}, ...
    'EpsilonR', [11.9, 4.1], 'LossTangent', [0.005, 0], ...
    'Thickness', [300e-6, 3e-6]);
ind.Height = 303e-6;              % Signal trace at top of stack
```

### Spiral Shape and Q-Factor Tradeoffs

| Shape | Q-Factor | Notes |
|-------|----------|-------|
| `'Circle'` | Highest | Best electrical performance |
| `'Octagon'` | High | Close to circular; easier to fabricate |
| `'Hexagon'` | Moderate | Compromise |
| `'Square'` | Lowest | Easiest to manufacture; current crowding at corners |

### Ground Plane Proximity Effect

Smaller `Height` increases capacitive coupling to ground, reducing inductance, Q-factor, and self-resonant frequency. Account for this when the PCB stackup constrains Height.

### Inductance Extraction

```matlab
L = inductance(ind, 600e6);                        % Scalar frequency → scalar (H)
L = inductance(ind, linspace(100e6, 1e9, 30));     % Vector → vector
```

### Self-Resonant Frequency (SRF)

At SRF, parasitic capacitance resonates with inductance — impedance peaks, then the inductor behaves as a capacitor. Design so the operating band stays below SRF/3 to SRF/2.

```matlab
freq = linspace(100e6, 10e9, 201);
L = inductance(ind, freq);
% Sign change: L > 0 (inductive) → L < 0 (capacitive) at SRF
```

### Visualization

```matlab
show(ind)
current(ind, 600e6)
charge(ind, 600e6)
[E, H] = EHfields(ind, 4e9, [0; 0; 1]);
```

## Interdigital Capacitors

### Creating and Configuring

```matlab
cap = interdigitalCapacitor;
cap.NumFingers         = 4;
cap.FingerLength       = 0.0137;
cap.FingerWidth        = 3.16e-4;
cap.FingerSpacing      = 3e-4;
cap.FingerEdgeGap      = 3.41e-4;
cap.TerminalStripWidth = 5e-4;
cap.PortLineWidth      = 1.9e-3;
cap.PortLineLength     = 3e-3;
cap.Height             = 7.87e-4;
```

### Capacitance Extraction

```matlab
C = capacitance(cap, 5e9);                                          % Raw
C = capacitance(cap, 5e9, DeEmbed=true);                            % De-embedded
C = capacitance(cap, 5e9, DeEmbed=true, IncludeParasitics=true);    % With parasitics
```

- **DeEmbed** removes feed line effects to isolate the capacitor.
- **IncludeParasitics** adds parasitic inductance/resistance from the finger structure.

## Behavioral S-Parameters

Both `spiralInductor` and `interdigitalCapacitor` support fast behavioral models:

```matlab
S = sparameters(ind, freq, Behavioral=true);     % ~instant
S = sparameters(cap, freq, Behavioral=true);
```

Use for initial exploration; switch to full-wave (`Behavioral=false`, the default) for validation. Before a full-wave solve, always check mesh density:

```matlab
memoryEstimate(ind, fc, 'RetainMesh', true);  % Check auto-mesh before full-wave
sp = sparameters(ind, freq, 'SweepOption', 'interp');
```

## Ring Resonators

`resonatorRing` is a microstrip ring resonator coupled to two feed lines via a gap.

```matlab
r = resonatorRing;
r.RingRadiusOuter = 0.01;
r.RingWidth       = 4e-3;
r.CouplingGap     = 1e-3;
r.PortLineLength  = 0.01;
r.PortLineWidth   = 5e-3;
r.Height          = 1.6e-3;
r.GroundPlaneWidth = 0.04;
```

### Frequency-Based Design

```matlab
r = design(resonatorRing, 1.8e9);                  % 50 Ω default
r = design(resonatorRing, 2.5e9, Z0=75);            % 75 Ω
```

## Split-Ring Resonators

Two object types: `resonatorSplitRingCustom` (pluggable shape) and `resonatorSplitRingSquare` (pre-configured square).

### Custom Split-Ring Resonator

```matlab
r = resonatorSplitRingCustom;
sr = splitRing(Type="Hexagon", NumRings=3);
sr.SplitSide = [2 3 5];
r.Resonator = sr;
r.FeedType  = 'Tapped';         % 'Tapped' (default) or 'Coupled'
r.PortLineLength = 0.01;
r.PortLineWidth  = 7.5e-4;
r.Height = 8.13e-4;
```

### Square Split-Ring Resonator

```matlab
r = resonatorSplitRingSquare;
r.RingLengthInner   = 3.6e-3;
r.RingWidth          = 5e-4;
r.RingSpacing        = 3e-4;
r.SplitGap           = 5e-4;
r.CouplingGap        = 2.5e-4;
r.NumResonator       = 5;
r.ResonatorSpacing   = 4e-3;
```

For the full `splitRing` shape property table, CSRR ground-plane etching, and SIW integration patterns, see [references/resonators-detail.md](references/resonators-detail.md).

## Coupled-Line Baluns

`balunCoupledLine` is a 3-section coupled-line balun (balanced-to-unbalanced converter).

```matlab
b = balunCoupledLine;
b.NumCoupledLineSection = 3;
b.CoupledLineLength     = 0.0153;
b.CoupledLineWidth      = 4e-4;
b.CoupledLineSpacing    = 1.4e-4;
b.OutputLineLength      = 0.0124;
b.OutputLineWidth       = 1.53e-4;
b.OutputLineSpacing     = 0.011;
b.Height                = 1.3e-3;
```

`balunCoupledLine` has no `design()` method. Use `designCoupledLine`, `designOutputLine`, `designUncoupledLine` for section-by-section sizing from impedance targets. See [references/resonators-detail.md](references/resonators-detail.md) for the full API.

## Marchand Baluns

`balunMarchand` is a broadband balun using λ/4 coupled-line sections.

```matlab
bm = balunMarchand;
bm.CoupledLineLength  = 0.0178;
bm.CoupledLineWidth   = 3e-3;
bm.CoupledLineSpacing = 1.5e-4;
bm.OutputLineLength   = 0.016;
bm.OutputLineWidth    = 2.9e-4;
bm.Height             = 1.6e-3;
```

No `design()` method. Set dimensions manually or use `optimize()`.

## Phase Shifters

`phaseShifter` is a Schiffman-type phase shifter using coupled-line sections.

```matlab
ps = design(phaseShifter, 1.8e9);                    % Default phase shift
ps = design(phaseShifter, 1.8e9, PhaseShift=90);      % 90° phase shift
```

### Properties

```matlab
ps.NumSections  = 1;
ps.PortLineLength = 0.01;
ps.PortLineWidth  = 5e-3;
ps.Height         = 1.6e-3;
ps.SectionShape   = ubendRightAngle;     % Default U-bend shape
```

## Radial Stubs

`stubRadialShunt` creates a single- or double-radial stub shunt. Radial stubs provide wideband short-circuit behavior compared to rectangular stubs.

```matlab
stub = stubRadialShunt;
stub.StubType       = "Single";     % "Single" (default) or "Double"
stub.OuterRadius    = 8.5e-3;
stub.InnerRadius    = 1.2e-3;
stub.Angle          = 90;           % Range [5, 175] degrees
stub.PortLineWidth  = 2.5e-3;
stub.PortLineLength = 0.0137;
stub.Height         = 1.6e-3;
```

For double-stub vector property configuration, see [references/resonators-detail.md](references/resonators-detail.md).

## Circuit Integration

Wrap passive components in `pcbElement` for RF Toolbox circuit assembly:

```matlab
ckt = circuit;
c1 = interdigitalCapacitor;
c2 = interdigitalCapacitor(NumFingers=3);
p = pcbElement(c2, 'Behavioral', false);
add(ckt, [1 2 0 0], c1);
add(ckt, [2 3 0 0], p);
setports(ckt, [1 0], [3 0]);
S = sparameters(ckt, 8e9);
```

## Optimization

All objects in this skill support `optimize()`:

```matlab
ind = spiralInductor(NumTurns=3);
optimize(ind, linspace(1e9, 3e9, 11), ...
    'Properties', {'Width', 'Spacing', 'InnerDiameter'}, ...
    'LowerBound', [1e-4, 1e-4, 3e-4], ...
    'UpperBound', [5e-4, 5e-4, 1e-3], ...
    'Objective', 'maximizeBandwidth');
```

## Multilayer Dielectric Pattern

All objects follow the same pattern — set `Thickness` before assigning to the component:

```matlab
sub = dielectric('FR4', 'Teflon');
sub.Thickness = [1.6e-3, 0.8e-3];
obj.Substrate = sub;
obj.Height = 0.8e-3;    % Must match a cumulative layer boundary
```

## Pitfalls

1. **Use interpolating sweep for S-parameters**: Always use `sparameters(obj, freq, 'SweepOption', 'interp')` for MoM solves. Direct sweeps solve at every frequency point individually and are significantly slower.

2. **Check mesh density before solving**: Spiral inductors and interdigital capacitors generate dense auto-meshes. Always run `memoryEstimate(obj, fc, 'RetainMesh', true)` before `sparameters()`. If memory is excessive, coarsen: `mesh(obj, 'MaxEdgeLength', lambda/6)`. See `matlab-analyze-em` for full mesh inspection workflow.

3. **No `design()` for inductors/capacitors.** `spiralInductor` and `interdigitalCapacitor` have no `design()` method. Set dimensions manually or use `optimize()`.

4. **Inductance/capacitance are frequency-dependent.** Both require a frequency argument — no DC extraction. Parasitic effects shift the value at high frequencies.

5. **DeEmbed matters for capacitance.** Without `DeEmbed=true`, extracted capacitance includes feed line contributions.

6. **SpiralShape is case-sensitive.** Use `'Square'`, `'Circle'`, `'Hexagon'`, `'Octagon'`.

7. **Behavioral vs full-wave accuracy.** Behavioral S-parameters diverge near SRF (inductors) or finger resonances (capacitors).

8. **Height must be a cumulative substrate boundary.** For Thickness=[t1, t2], valid Heights are t1, t1+t2. Applies to all objects in this skill.

9. **spiralInductor requires multi-layer substrate.** The underpass feed routing needs ≥ 2 dielectric layers. A single layer errors with "More than one substrate is required."

10. **GroundPlane dimensions.** Keep ground plane ≥ 2× the component footprint to avoid truncating fringing fields.

11. **No `design()` for baluns.** `balunCoupledLine` and `balunMarchand` have no `design()` method. Use section-design functions or `optimize()`.

12. **No `design()` for split-ring resonators.** Only `resonatorRing` supports `design()`.

13. **`splitRing` is a shape, not a component.** Cannot be analyzed directly — attach to `resonatorSplitRingCustom` or embed in a `pcbComponent`.

14. **PhaseShift units are degrees.** The `PhaseShift` parameter in `design(phaseShifter, ...)` is degrees, not radians.

15. **`stubRadialShunt` has no `design()` method.** Set dimensions manually or use `optimize()`.

14. **Polygonal SplitSide defaults may be invalid.** Hexagons require `SplitSide` from {2, 3, 5, 6}. Always set explicitly for polygonal types with multiple rings.

## Related Skills

- `matlab-manage-pcb-material` — Substrate and conductor setup
- `matlab-analyze-em` — S-parameters, fields, mesh control
- `matlab-optimize-pcb-design` — optimize() syntax, objectives, solvers
- `matlab-integrate-pcb-circuit` — pcbElement circuit integration
- `matlab-design-pcb-filter` — SIW filters can embed split-ring resonators
- `matlab-assemble-pcb-layout` — Custom CSRR structures via pcbComponent + Boolean ops
- `matlab-design-pcb-coupler` — Related coupled-line structures

----

Copyright 2026 The MathWorks, Inc.
