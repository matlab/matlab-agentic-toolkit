# Custom Antenna Design (customAntenna + shape.*)

## shape.* vs antenna.* — Two Different Namespaces

| Namespace | Used With | Examples |
|-----------|----------|---------|
| `shape.*` | `customAntenna` | `shape.Rectangle`, `shape.Box`, `shape.Cylinder` |
| `antenna.*` | `pcbStack` | `antenna.Rectangle`, `antenna.Circle`, `antenna.Polygon` |

They are **not interchangeable**. This is the #1 source of confusion.

## 2D Shape Primitives

All 2D shapes live in the XY plane (z = 0).

| Shape | Key Properties |
|-------|---------------|
| `shape.Rectangle` | `Length`, `Width`, `Center`, `NumPoints`, `Metal` |
| `shape.Circle` | `Radius`, `Center`, `NumPoints`, `Metal` |
| `shape.Ellipse` | `MajorAxis`, `MinorAxis`, `Center`, `Metal` |
| `shape.Polygon` | `Vertices` (N-by-3, z must be 0), `Metal` |

Default `Metal="PEC"`. Available: `PEC`, `Copper`, `Aluminium`, `Gold`, `Silver`, `Zinc`, `Tungsten`, `Lead`, `Iron`, `Steel`, `Brass`.

## 3D Shape Primitives

| Shape | Key Properties | Notes |
|-------|---------------|-------|
| `shape.Box` | `Length`, `Width`, `Height`, `Center` | Closed box (6 faces) |
| `shape.OpenBox` | `Length`, `Width`, `Height`, `Center` | One face removed |
| `shape.Cylinder` | `Radius`, `Height`, `Center`, `Cap` | `Cap=[1 1]` = both ends |
| `shape.OpenCylinder` | `Radius`, `Height`, `Center` | Open-ended |
| `shape.Sphere` | `Radius`, `Center` | Full sphere |
| `shape.Custom3D` | `Vertices` (from triangulation) | Arbitrary 3D mesh |

3D shapes have both `Metal` and `Dielectric` properties.

## Boolean Operations

```matlab
combined = shape1 + shape2;        % union
slotted = ground - slot;           % subtraction
overlap = shape1 & shape2;         % intersection
```

Use `RetainShape=true` in `add`/`subtract` to preserve internal boundaries.

### createHole (For 2D Slots)

Preferred over subtraction for cutting holes in 2D shapes:

```matlab
ground = shape.Rectangle(Length=0.1, Width=0.1);
slot = shape.Rectangle(Length=0.05, Width=0.003);
slottedGround = createHole(ground, slot);

% Overlapping holes: union first, then cut once
hSlot = shape.Rectangle(Length=0.05, Width=0.003);
vSlot = shape.Rectangle(Length=0.003, Width=0.05);
crossSlot = hSlot + vSlot;
slottedGround = createHole(ground, crossSlot);
```

### Alternative: Direct Polygon Definition

When boolean operations fail, define the final shape directly:

```matlab
halfL = patchL/2;
cornerClip = 0.008;
verts = [
    -halfL, -halfL, 0;
     halfL-cornerClip, -halfL, 0;
     halfL, -halfL+cornerClip, 0;
     halfL, halfL, 0;
    -halfL+cornerClip, halfL, 0;
    -halfL, halfL-cornerClip, 0];
truncatedPatch = shape.Polygon(Vertices=verts);
```

## Transforms

```matlab
translate(shape, [dx, dy, dz]);
rotate(shape, angleDeg, [x1 y1 z1], [x2 y2 z2]);
rotateX(shape, angleDeg);  rotateY(shape, angleDeg);  rotateZ(shape, angleDeg);
scale(shape, factor);
```

**Shapes are handle objects** — transforms modify the original. Use `copy(shape)` to preserve.

**Vertical rectangles:** Always rotate at origin first, then translate:

```matlab
wall = shape.Rectangle(Length=wallHeight, Width=wallSpan);
rotate(wall, 90, [0, 0, 0], [0, 1, 0]);
translate(wall, [x, y, wallHeight/2]);
```

## Extrusion: 2D to 3D

### extrudeLinear

2D shape **must be in XY plane**. Extrude first, then rotate.

```matlab
rect = shape.Rectangle(Length=0.023, Width=0.010);
box = extrudeLinear(rect, 0.030);

% Tapered extrusion (horn flare)
horn = extrudeLinear(rect, 0.050, Scale=[2.5 2.0], NumSegments=1, Caps=false);
```

| Argument | Default | Description |
|----------|---------|-------------|
| `height` | — | Extrusion height along z |
| `Scale` | `1` | `[sx sy]` at far end (taper) |
| `NumSegments` | `1` | Mesh segments along extrusion |
| `Caps` | `false` | Close both ends |
| `Direction` | `[0 0 1]` | Extrusion direction |
| `Twist` | `0` | Twist angle (degrees) |

### extrudeRotate

Revolves a 2D shape around the z-axis:

```matlab
profile = shape.Polygon(Vertices=[0.005 0 0; 0.01 0 0; 0.02 0.05 0; 0.015 0.05 0]);
hornRev = extrudeRotate(profile, 360, NumSegments=16);
```

| Argument | Default | Description |
|----------|---------|-------------|
| `angle` | — | Revolution angle (360 = full) |
| `NumSegments` | `3` | Segments around revolution |
| `Caps` | `false` | Close ends |
| `Pitch` | `0` | Z-advance per revolution (helical) |

## Modifying 3D Structures

### removeFaces

Opens a face on a closed shape. **Never hardcode face indices** — run `removeFaces(sh)` interactively first to identify the correct face:

```matlab
removeFaces(sh, faceIdx);
```

### imprintShape

Cuts a 2D outline into a 3D surface for clean feed contact:

```matlab
imprintCirc = shape.Circle(Radius=0.005);
translate(imprintCirc, [feedX 0 0]);
wgWithImprint = imprintShape(wg, imprintCirc);
```

## Feed Configuration

### Delta-Gap Feed Model

Feed edge must be at a **geometric discontinuity** (gap, slot edge, shape junction, probe contact).

A feed in the middle of continuous flat plate gives ~0 ohm impedance.

### createFeed Syntax

`FeedLocation` is read-only. Always use `createFeed()`:

```matlab
ant = customAntenna(Shape=antShape);
createFeed(ant, [x y z], numEdges);
createFeed(ant, [x y z], numEdges, FeedShape=probeShape);
```

| Argument | Description |
|----------|-------------|
| `[x y z]` | Feed point (N-by-3 for multi-feed). Must be on metal surface. |
| `numEdges` | Edges per feed. Must be `1` or `>= 3`. |
| `FeedShape` | Optional 2D `shape.*` defining physical probe. |

### Feed Approach Selection

| Antenna Type | Approach |
|---|---|
| 2D planar (slot, dipole) | `createFeed(ant, loc, 1)` |
| Probe-fed patch on substrate | `FeedShape=probeRect` (no manual imprint) |
| 3D extruded (waveguide, horn, cavity) | `createFeed(ant, loc, 1)` delta-gap |
| Body of revolution | `createFeed(ant, loc, N)` with large `NumEdges` |

**For 3D extruded structures, use delta-gap `createFeed(ant, loc, 1)`** — avoid `FeedShape` which requires precise surface alignment on complex boolean geometries. `FeedShape` is reliable only on flat/planar structures where the feed rectangle position is unambiguous.

### Waveguide Feed (FeedShape)

```matlab
% Assumes waveguide extruded along Z: extrudeLinear(rect, wgLength)
probeH = narrowWall * 0.65;
probeW = 5.2e-5;
feedrect = shape.Rectangle(Length=probeW, Width=probeH);
feedZ = lambda/4;               % λ/4 from shorted back wall (extrusion axis)
wallY = -narrowWall/2;          % bottom broad wall
translate(feedrect, [0, wallY + probeH/2, feedZ]);
createFeed(ant, [0, wallY, feedZ], 1, FeedShape=feedrect);
```

### Probe-Fed Patch (Complete Pattern)

```matlab
ground = shape.Rectangle(Length=gndL, Width=gndW);
patch = shape.Rectangle(Length=patchL, Width=patchW);
translate(patch, [0, 0, subH]);
metalShape = ground + patch;

substrate = shape.Box(Length=gndL, Width=gndW, Height=subH, ...
    Center=[0, 0, subH/2], Dielectric="FR4");
bbox = shape.Box(Length=0.2, Width=0.2, Height=0.1, ...
    Center=[0, 0, 0.05], Dielectric="Air", Transparency=0.1);
antShape = addSubstrate(metalShape, substrate + bbox);
ant = customAntenna(Shape=antShape);

feedWidth = 1.3e-3;
feedProbe = shape.Rectangle(Length=feedWidth, Width=subH);
translate(feedProbe, [feedOffset, 0, subH/2]);
rotate(feedProbe, 90, [feedOffset, 0, subH/2], [feedOffset+1, 0, subH/2]);
createFeed(ant, [feedOffset, 0, 0], 1, FeedShape=feedProbe);
```

**Do not manually `imprintShape` the ground at the feed point when using `FeedShape`** — `createFeed` handles the imprint internally. A double imprint causes dimension errors.

### Multi-Feed Excitation (R2026a+)

```matlab
createFeed(ant, [x1 y1 z1; x2 y2 z2], [1, 1]);
ant.FeedVoltage = [1, 1];
ant.FeedPhase = [0, 90];
```

## Dielectric Support (addSubstrate)

**Precondition:** `metalShape` must be a 3D composite shape (Custom3D) built via boolean union of shapes at different Z-positions (e.g., `ground + patch` where patch is translated in Z). A plain 2D `shape.Rectangle` will error.

```matlab
substrate = shape.Box(Length=0.06, Width=0.06, Height=subH, ...
    Center=[0 0 subH/2], Dielectric="FR4");
bbox = shape.Box(Length=0.2, Width=0.2, Height=0.1, ...
    Center=[0 0 0.05], Dielectric="Air", Transparency=0.1);
antShape = addSubstrate(metalShape, substrate + bbox);
```

**The air bounding box is required.** Several wavelengths larger than the antenna. Extend slightly below ground plane.

## Meshing

```matlab
c = physconst("LightSpeed");
lambda = c / freq;
mesh(ant, MaxEdgeLength=lambda/6, MinEdgeLength=lambda/20);
mem = memoryEstimate(ant, freq);
```

## STL/CAD Import

```matlab
ant = customAntennaStl;
ant.FileName = "horn.stl";
ant.Units = "mm";
createFeed(ant, [0 0 0], 1);
mesh(ant, MaxEdgeLength=lambda/6);
```

Supported: `.stl`, `.step`, `.iges`. Set `UseFileAsMesh = true` if STL mesh is fine enough.

## Feed Coupling Diagnostic

If impedance seems unrealistically low:
```matlab
figure; current(ant, freq, Scale="log");
```
Log-scale current reveals whether current flows into the structure even when impedance is unreliable.

----

Copyright 2026 The MathWorks, Inc.
