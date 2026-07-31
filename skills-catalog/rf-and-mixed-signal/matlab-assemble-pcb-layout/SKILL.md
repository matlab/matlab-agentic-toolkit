---
name: matlab-assemble-pcb-layout
description: "Build custom PCB structures with pcbComponent, shapes, Boolean ops, feeds, and multi-layer stackups for non-catalog geometries. TRIGGER: user asks to build, modify, or customize a pcbComponent — add/remove shapes, edit polygons, place feeds, add metal layers, cut slots, or create non-catalog RF structures. Also when modifying geometry of an existing catalog-designed component (e.g., adding pads, removing elements, editing vertices). Invoke BEFORE writing pcbComponent code — layer/shape/feed API is non-obvious. SKIP: designing catalog components like filters/couplers/txlines (use the specific matlab-design-pcb-* skill), material/stackup definition only (use matlab-manage-pcb-material), EM analysis (use matlab-analyze-em), importing PCB files (use matlab-read-pcb-layout)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Assembling Custom PCB Components

## When to Use

- Building custom PCB structures that aren't covered by catalog objects (microstripLine, coupledMicrostripLine, etc.)
- Constructing multi-layer stackups with custom metal shapes on each layer
- Combining shape primitives with Boolean operations (union, subtract, intersect)
- Creating defected ground structures (DGS) by etching patterns into ground planes
- Placing feed ports, vias, or using advanced FeedDefinitions (coaxial, edge, delta-gap)
- Assembling stripline or shielded enclosure structures

## When NOT to Use

- Designing standard transmission lines — use `matlab-design-pcb-txline`
- Importing layouts from Gerber, ODB++, or Allegro — use `matlab-read-pcb-layout`
- Defining dielectric or metal materials — use `matlab-manage-pcb-material`
- Running EM analysis after assembly — use `matlab-analyze-em`
- Cascading or connecting multiple pcbComponents — use `matlab-integrate-pcb-circuit`

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — set up substrate and conductor
2. **This skill:** Build the custom PCB structure using pcbComponent, shapes, and feeds
3. **After:** `matlab-analyze-em` — validate S-parameters → `matlab-optimize-pcb-design` — tune dimensions → `matlab-write-pcb-layout` — export Gerber

## Quick Reference

| Task | Code |
|------|------|
| Create pcbComponent | `pcb = pcbComponent` |
| Assign layers | `pcb.Layers = {signal, substrate, ground}` |
| Set board shape | `pcb.BoardShape = ground` |
| Set thickness | `pcb.BoardThickness = 1.6e-3` |
| Place feeds | `pcb.FeedLocations = [x1 y1 1 3; x2 y2 1 3]` |
| Feed diameter | `pcb.FeedDiameter = W/2` |
| Set conductor | `pcb.Conductor = metal("Copper")` |
| Add vias | `pcb.ViaLocations = [x y topLayer botLayer]` |
| Visualize | `show(pcb)` |
| Layout view | `layout(pcb)` |
| Boolean union | `shape = s1 + s2` |
| Boolean subtract | `shape = s1 - s2` |
| Boolean intersect | `shape = s1 & s2` |

## pcbComponent Anatomy

`pcbComponent` is the universal container for custom RF PCB structures.

### Minimal 2-Layer Microstrip

```matlab
pcb = pcbComponent;
substrate = dielectric("FR4");
substrate.Thickness = 1.6e-3;

signal = traceRectangular(Length=20e-3, Width=3e-3);
ground = traceRectangular(Length=30e-3, Width=20e-3);

pcb.Layers = {signal, substrate, ground};
pcb.BoardShape = ground;
pcb.BoardThickness = substrate.Thickness;
pcb.Conductor = metal("Copper");
pcb.FeedDiameter = 1.5e-3;
pcb.FeedLocations = [-10e-3 0 1 3; 10e-3 0 1 3];
show(pcb);
```

### 5-Layer Stripline Structure

```matlab
pcb = pcbComponent;
sub = dielectric(Name="FR4", EpsilonR=4.4, LossTangent=0.02, Thickness=0.8e-3);

topGnd = traceRectangular(Length=40e-3, Width=20e-3);
signal = traceRectangular(Length=30e-3, Width=2e-3);
botGnd = traceRectangular(Length=40e-3, Width=20e-3);

pcb.BoardThickness = 2 * sub.Thickness;          % Set BEFORE Layers
pcb.Layers = {topGnd, sub, signal, sub, botGnd};
pcb.BoardShape = topGnd;
pcb.Conductor = metal("Copper");
pcb.FeedLocations = [-15e-3 0 3 1; 15e-3 0 3 5];
pcb.FeedDiameter = 1e-3;
show(pcb);
```

### Key Properties

| Property | Format | Description |
|----------|--------|-------------|
| `Layers` | Cell array | Alternating: metal shape, dielectric, metal shape, ... |
| `BoardShape` | Shape object | Outer boundary of the PCB |
| `BoardThickness` | Scalar (m) | Must equal sum of dielectric thicknesses |
| `FeedLocations` | N×4 matrix | `[x, y, signalLayer, groundLayer]` per port |
| `FeedDiameter` | Scalar (m) | Diameter of feed via/probe |
| `ViaLocations` | M×4 matrix | `[x, y, topLayer, bottomLayer]` per via |
| `ViaDiameter` | Scalar (m) | Via barrel diameter |
| `FeedViaModel` | String | `'strip'`, `'square'`, `'octagon'`, `'hexagon'` |
| `Conductor` | metal object | Conductor for all metal layers |
| `SolverType` | String | `'MoM'` or `'FEM'` |

## Shape Primitives

### Rectangular Traces

```matlab
rect = traceRectangular(Length=20e-3, Width=5e-3, Center=[0 0]);
```

### Line Traces (multi-segment with bends)

```matlab
tl = traceLine;
tl.Length = [10 5*sqrt(2) 10]*1e-3;
tl.Angle = [0 45 0];
tl.Width = 3e-3;
tl.Corner = 1;          % 1 = Miter, 2 = Smooth (default: Sharp)
show(tl);
```

### Point-Defined Traces

```matlab
tp = tracePoint;
tp.TracePoints = [0 0; 10e-3 0; 15e-3 5e-3; 25e-3 5e-3];
tp.Width = 2e-3;
tp.Corner = 2;          % 2 = Smooth
```

### Spiral Traces

```matlab
sp = traceSpiral;
sp.NumTurns = 3;
sp.InnerDiameter = 4e-3;
sp.Spacing = 0.5e-3;
sp.TraceWidth = 0.5e-3;
show(sp);
```

### Tapered Traces

```matlab
tt = traceTapered;
tt.Length = 10e-3;
tt.InputWidth = 1e-3;
tt.OutputWidth = 3e-3;
```

### Bends

Bend `Width` is a 2-element vector `[w1 w2]` for the two arms:

```matlab
bc = bendCurved;
bc.Width = [2e-3 2e-3];
bc.CurveRadius = 5e-3;

bm = bendMitered;
bm.Width = [2e-3 2e-3];

br = bendRightAngle;
br.Width = [2e-3 2e-3];
```

### U-Bends

U-bend `Width` is a 3-element vector `[arm1 bottom arm2]`:

```matlab
uc = ubendCurved;
uc.Width = [2e-3 2e-3 2e-3];
uc.CurveRadius = 3e-3;

um = ubendMitered;
um.Width = [2e-3 2e-3 2e-3];
```

### Other Shapes

```matlab
d = delta;
d.OuterRadius = 5e-3;                           % Triangle/delta

db = dumbbell;
db.SideLength = 6e-3;                           % Head size (square Type, default)
db.ArmLength = 10e-3;
db.ArmWidth = 0.5e-3;                           % Dumbbell (for DGS)
% Note: Type='Square' uses SideLength; Type='Circle' uses Diameter

rt = racetrack;
rt.Length = 15e-3;
rt.Width = 5e-3;                                % Racetrack

rd = radial;
rd.OuterRadius = 5e-3;
rd.Angle = 60;                                  % Radial sector

ar = ringAnnular;
ar.InnerRadius = 1e-3;
ar.Width = 4e-3;                                % Annular ring (InnerRadius must be > 0)

sr = splitRing;
sr.RingDiameter = 10e-3;
sr.TraceWidth = 0.5e-3;
sr.SplitGap = 0.5e-3;                           % Split ring resonator
```

## Boolean Operations

Combine shapes using operators to build complex geometries.

### Union (+)

```matlab
left = traceRectangular(Length=10e-3, Width=5e-3, Center=[-5e-3 0]);
right = traceRectangular(Length=10e-3, Width=5e-3, Center=[5e-3 0]);
combined = left + right;
show(combined);
```

### Subtraction (-)

Create slots, gaps, or etched patterns:

```matlab
base = traceRectangular(Length=20e-3, Width=10e-3);
slot = traceRectangular(Length=15e-3, Width=1e-3);
slotted = base - slot;
show(slotted);
```

### Intersection (&)

```matlab
ring = ringAnnular;
ring.InnerRadius = 1e-3;
ring.Width = 9e-3;
rect = traceRectangular(Length=15e-3, Width=15e-3);
clipped = ring & rect;
```

### Complex Example: U-CSRR Filter

```matlab
% Create feeding microstrip
ZA = traceRectangular(Length=4e-3, Width=4e-3, Center=[-7e-3 0]);
Cell = traceRectangular(Length=5e-3, Width=5e-3, Center=[-2.5e-3 0]);
LeftSection = ZA + Cell;

% Create slots using traceLine
s1 = traceLine(StartPoint=[-2.5e-3-0.1e-3, -1.9e-3], ...
    Angle=[-180 -270 0], Length=[1.75e-3 3.8e-3 1.75e-3], Width=0.2e-3);
s2 = traceLine(StartPoint=[-2.5e-3+0.1e-3, -1.9e-3], ...
    Angle=[0 90 180], Length=[1.75e-3 3.8e-3 1.75e-3], Width=0.2e-3);

% Subtract slots from base
LeftSection = LeftSection - s1 - s2;

% Mirror for right section
RightSection = copy(LeftSection);
RightSection = mirrorY(RightSection);

% Complete filter
filter = LeftSection + RightSection;
show(filter);
```

## Feed Placement

### FeedLocations Format

Each row: `[x, y, signalLayerIndex, groundLayerIndex]`

- Layer indices are odd numbers (1, 3, 5, ...) for metal layers in the `Layers` cell array
- Layer 1 = first metal (top), Layer 3 = second metal, etc.

```matlab
% 2-port microstrip (signal on layer 1, ground on layer 3)
pcb.FeedLocations = [-10e-3 0 1 3;    % Port 1: left edge
                      10e-3 0 1 3];    % Port 2: right edge
```

### 4-Port Coupled Trace

```matlab
pcb.FeedLocations = [0 0 1 3;         % Port 1
                     40e-3 0 1 3;      % Port 2
                     40e-3 -5e-3 1 3;  % Port 3
                     0 -5e-3 1 3];     % Port 4
```

### Feed Diameter

```matlab
pcb.FeedDiameter = traceWidth / 2;  % Must fit within the trace
```

### Internal Ports (for lumped elements)

Define extra feed locations for internal connections to lumped components (see `matlab-integrate-pcb-circuit` skill for pcbElement with PortNumber/PortValue).

## DGS — Defected Ground Structures

Etch patterns into the ground plane using the `dgs` method:

```matlab
ms = microstripLine;
ms.Length = 20e-3;
ms.Width = 3e-3;

% Create a dumbbell DGS under the trace
dgsShape = dumbbell;
dgsShape.SideLength = 4e-3;       % Head size (default Type='Square')
dgsShape.ArmLength = 8e-3;
dgsShape.ArmWidth = 0.5e-3;
ms = dgs(ms, {dgsShape});   % Must capture return value — does not modify in place
show(ms);
memoryEstimate(ms, 10e9, 'RetainMesh', true);  % Check mesh before solving
sp = sparameters(ms, linspace(1e9, 10e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

DGS adds bandstop characteristics and can improve coupler directivity or filter rejection.
## Shielded Enclosures

Add a conductive lid for shielded analysis:

```matlab
pcb = pcbComponent;
% ... set up layers ...
pcb.IsShielded = true;   % Adds PEC enclosure walls and lid
show(pcb);
```

For filter-in-enclosure problems, shielding affects resonant frequencies and coupling.

## Shape Manipulation

```matlab
shape = translate(shape, [dx, dy, 0]);  % Translate
shape = rotateZ(shape, angle);          % Rotate about z-axis (degrees)
shape = rotateX(shape, angle);          % Rotate about x-axis
shape = mirrorX(shape);                 % Mirror about x-axis
shape = mirrorY(shape);                 % Mirror about y-axis
shapeCopy = copy(shape);                % Deep copy
shape = scale(shape, factor);           % Uniform scaling
a = area(shape);                        % Shape area (m²)
```

For catalog objects, extract shapes by layer with `shapes()`:

```matlab
s = shapes(obj);              % Struct of shapes by layer name
boardArea = area(s.GroundPlane);
```

For pcbComponent, shapes are in `Layers` and `BoardShape`:

```matlab
boardArea = area(pcb.BoardShape);
```

## Discovering Available Methods

Use `methods(obj)` to list all available operations on any object:

```matlab
methods(pcb)                  % List all pcbComponent methods
methods(traceRectangular)     % List all shape methods
```

## Visualization

```matlab
show(pcb);          % 3-D structure view
layout(pcb);        % Top-down layout with feeds and vias
mesh(pcb);          % Mesh visualization
info(pcb);          % Print structure summary
```

## Advanced Feed Setup (FeedDefinitions API)

By default, `pcbComponent` uses `FeedLocations` (XY coordinates + layer) for simple probe feeds. For advanced feed types — coaxial, edge, delta-gap, finite-gap — switch to the `FeedDefinitions` API:

```matlab
pcb = pcbComponent;
pcb.FeedFormat = 'FeedDefinitions';     % Enable FeedDefinitions mode
```

### Feed Types

| Feed Type | Use When | Key Properties |
|-----------|----------|----------------|
| `ProbeFeed` | Vertical via probe (patch antennas) | `SignalLocations`, `SignalLayers`, `GroundLayers`, `ViaDiameter`, `ViaModel` |
| `CoaxialFeed` | Probe with explicit pad/antipad geometry | `PadShape`, `AntipadShape`, `SignalLayers`, `GroundLayers` |
| `EdgeFeed` | Stripline-style edge excitation | `SignalLocations`, `SignalLayers`, `GroundLayers`, `SignalWidths` |
| `DeltaGapFeed` | Internal port with current direction | `SignalLocations`, `SignalLayers`, `SignalWidths`, `CurrentDirection` |
| `FiniteGapFeed` | Internal gap port (signal + ground) | `SignalLocations`, `GroundLocations`, `SignalLayers`, `SignalWidths` |
| `ArbitraryFiniteGapFeed` | Coplanar port with full control | `SignalLocations`, `GroundLocations`, `SignalWidths`, `GroundWidths`, `SignalLayers`, `GroundLayers` |

### ProbeFeed (Most Common)

```matlab
f = ProbeFeed('SignalLocations', [-0.0187, 0], ...
    'SignalLayers', 1, 'GroundLayers', 3, ...
    'ViaDiameter', 1e-3, 'ViaModel', 'square');
pcb.FeedDefinitions = f;
```

### EdgeFeed (Stripline Structures)

For 5-layer stripline structures with signal on layer 3 and ground on layers 1 and 5:

```matlab
f1 = EdgeFeed('SignalLocations', feed1_xy, 'SignalLayers', 3, ...
    'GroundLayers', [1; 5], 'SignalWidths', trace_width);
f2 = EdgeFeed('SignalLocations', feed2_xy, 'SignalLayers', 3, ...
    'GroundLayers', [1; 5], 'SignalWidths', trace_width);
pcb.FeedDefinitions = [f1, f2];
```

### CoaxialFeed (Custom Pad/Antipad Geometry)

```matlab
pad = antenna.Circle('Radius', 0.5e-3);
antipad = antenna.Circle('Radius', 1e-3);
f = CoaxialFeed('PadShape', pad, 'AntipadShape', antipad, ...
    'SignalLayers', 1, 'GroundLayers', 3);
pcb.FeedDefinitions = f;
```

### DeltaGapFeed (Internal Ports)

```matlab
f = DeltaGapFeed('SignalLocations', [x, y], 'SignalLayers', 1, ...
    'SignalWidths', 0.5e-3, 'CurrentDirection', [0, 1]);
pcb.FeedDefinitions(end+1) = f;     % Append to existing feeds
```

### Multiple Feeds

Build feed arrays by concatenation or append:

```matlab
pcb.FeedDefinitions = [f1, f2];          % Row array at once
pcb.FeedDefinitions(end+1) = f3;         % Append incrementally
```

## Shape Primitives Reference

For the full catalog of all shape primitives (traces, bends, curves, rings, special shapes) with properties and common operations, see [references/shape-primitives.md](references/shape-primitives.md).

## Pitfalls

1. **Feed outside metal**: The feed circle (`FeedDiameter`) must fit entirely within the metal trace at the feed location. Inset at least `FeedDiameter/2` from any trace edge. Failing this causes solver errors.

2. **BoardThickness mismatch — set before Layers**: `BoardThickness` must exactly equal the sum of all dielectric layer thicknesses in `Layers`. The `Layers` setter validates against the current `BoardThickness`, so **set `BoardThickness` before `Layers`** when the total differs from the default (1.6 mm). Setting `Layers` first with a non-default total causes an error.

3. **Layer indexing**: Metal layers are odd-indexed (1, 3, 5, ...) in the `Layers` cell array. Dielectrics are even-indexed (2, 4, ...). `FeedLocations` references metal layer indices only.

4. **Boolean operation order**: Subtraction is order-dependent (`A - B ≠ B - A`). The first operand defines the base; the second is removed from it.

5. **Shape overlap for union**: Shapes must overlap or touch for `+` to produce a connected geometry. Disjoint shapes create multi-body structures which may confuse the solver.

6. **FeedViaModel for stripline**: For 5-layer (stripline) structures, set `FeedViaModel` to control the feed via shape connecting the internal signal layer to the external port reference.

7. **Corner property is integer-valued**: Set `Corner` using integers: 1 = Miter, 2 = Smooth (default is Sharp). String values like `"Miter"` cause errors.

8. **DGS: capture return value + use cell array**: `dgs` does not modify the object in place — you must capture the output: `ms = dgs(ms, {dgsShape})`. Also pass shapes in a cell array, not bare: `{dgsShape}`, not `dgsShape`.

9. **IsShielded auto-switches to FEM**: Setting `pcb.IsShielded = true` automatically changes `SolverType` to `'FEM'`. This is expected but makes the solve significantly slower.

10. **Use rotateZ, not rotate, for z-axis rotation**: `rotate(shape, angle)` requires 4 arguments (angle + two 3D points defining the axis). For simple z-rotation use `rotateZ(shape, angle)`. Similarly `rotateX` and `rotateY` for other axes.

11. **FeedFormat is exclusive.** Setting `FeedFormat = 'FeedDefinitions'` disables `FeedLocations`. You cannot mix both modes — choose one or the other.

12. **GroundLayers as column vector for multi-ground.** For stripline structures with ground on both sides, pass `GroundLayers` as a column vector: `[1; 5]`, not `[1, 5]`.

13. **Each dielectric in Layers must be a single-layer object**: Do NOT use a multi-layer `dielectric` (one with vector `Thickness`/`EpsilonR`) as a single entry in the `Layers` cell array. Each dielectric layer must be its own separate `dielectric` object with scalar properties. For a 5-layer stack: `pcb.Layers = {metal1, diel1, metal2, diel2, metal3}` where each `diel` has scalar `Thickness`.

## Related Skills

- `matlab-manage-pcb-material` — Defining dielectric and metal for layers
- `matlab-analyze-em` — Analyzing the assembled structure
- `matlab-design-pcb-filter` — Filters using custom pcbComponent geometry
- `matlab-integrate-pcb-circuit` — Connecting pcbComponents together

----

Copyright 2026 The MathWorks, Inc.
