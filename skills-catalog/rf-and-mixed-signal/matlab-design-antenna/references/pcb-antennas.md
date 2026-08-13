# PCB Antenna Design (pcbStack)

## Layer Stack Construction

The `Layers` property is a cell array specified **top-to-bottom**, alternating metal shapes and dielectric objects.

### Critical Rules

1. **Set `BoardThickness` BEFORE `Layers`** — Setting Layers always overwrites dielectric thickness with current BoardThickness. Setting BoardThickness afterwards does NOT fix it.
2. **Layer indices are cell array positions** — In `{metal, diel, metal}`, metals are at indices 1 and 3.
3. **First and last entries are typically metal** — but dielectric layers can appear first/last (e.g., radome above top patch).
4. **`BoardThickness` = total dielectric below top metal** — For multi-substrate stacks, sum all dielectric thicknesses.

### 3-Layer Stack (Most Common)

```matlab
subHeight = 1.6e-3;
sub = dielectric("FR4");

p = pcbStack;
p.BoardShape = antenna.Rectangle(Length=60e-3, Width=60e-3);
p.BoardThickness = subHeight;       % MUST be set BEFORE Layers
p.Layers = {patch, sub, ground};    % {metal(1), diel(2), metal(3)}
p.FeedLocations = [x, y, 1, 3];    % sig=1(top), gnd=3(bottom)
```

### 2-Layer Stack (Air Dielectric)

```matlab
p.Layers = {radiator, ground};      % air dielectric assumed
p.FeedLocations = [x, y, 1, 2];
```

### 5-Layer Stack (Aperture-Coupled)

```matlab
p.BoardThickness = upperSubHeight + lowerSubHeight;
p.Layers = {radiator, upperSub, slottedGround, lowerSub, feedLine};
p.FeedLocations = [x, y, 5, 3];    % sig=5(feedLine), gnd=3(ground)
```

### Substrate Materials

| Material | EpsilonR | LossTangent | Use Case |
|----------|----------|-------------|----------|
| `"FR4"` | 4.8 | 0.026 | Prototyping |
| Custom `"RO4003C"` | 3.55 | 0.0027 | High-frequency |
| `"Teflon"` | 2.1 | 0.0002 | Very low loss |

```matlab
sub = dielectric(Name="RO4003C", EpsilonR=3.55, LossTangent=0.0027, Thickness=h);
```

## Shape Operations (antenna.* Namespace)

### Available Shapes

| Shape | Key Properties |
|-------|---------------|
| `antenna.Rectangle` | `Length`, `Width`, `Center`, `NumPoints` |
| `antenna.Circle` | `Radius`, `Center`, `NumPoints` |
| `antenna.Ellipse` | `MajorAxis`, `MinorAxis`, `Center` |
| `antenna.Polygon` | `Vertices` (N-by-3) |
| `antenna.Triangle` | `InputType`, `Side`, `Angle` |

### Boolean Operations

```matlab
patchWithFeed = patch + feedLine;        % union
gndWithSlot = ground - slot;             % subtraction
eNotch = patch - notch1 - notch2;
```

### Common Patterns

```matlab
% Slot in ground
slot = antenna.Rectangle(Length=30e-3, Width=2e-3);
slottedGround = gnd - slot;

% Ring patch
ring = antenna.Circle(Radius=15e-3) - antenna.Circle(Radius=10e-3);

% Corner-truncated patch for CP
tri1 = antenna.Polygon(Vertices=[Lp/2, Lp/2, 0; Lp/2-tc, Lp/2, 0; Lp/2, Lp/2-tc, 0]);
tri2 = antenna.Polygon(Vertices=[-Lp/2, -Lp/2, 0; -Lp/2+tc, -Lp/2, 0; -Lp/2, -Lp/2+tc, 0]);
cpPatch = patch - tri1 - tri2;
```

### Geometric Transforms

```matlab
shifted = translate(shape, [dx, dy, 0]);
rotated = rotateZ(shape, angleDeg);
mirrored = mirrorX(copy(shape));
shapeCopy = copy(shape);
bigger = scale(shape, factor);
```

## Feed Configuration

### Delta-Gap Feed Model

Feed offset from patch center controls impedance:
- **Center**: ~0 ohm (current antinode)
- **Edge**: ~200+ ohm (current node)
- **~1/4 to 1/3 from center**: ~50 ohm

### Unbalanced Feed (Most Common)

Format: `[x, y, sigLayer, gndLayer]` — 4 columns.

```matlab
% For 3-layer stack {metal, diel, metal}: sig=1 (top), gnd=3 (bottom)
% For 2-layer stack {metal, metal}: use gnd=2 instead of 3
p.FeedLocations = [patchL/4, 0, 1, 3];
p.FeedDiameter = 1e-3;
```

### Edge Feed

```matlab
p.FeedLocations = [0, -30e-3, 1, 3];   % south edge of 60x60 board
```

### Multi-Feed (Dual Polarization / CP)

```matlab
p.FeedLocations = [7e-3, 0, 1, 3;
                   0, 9e-3, 1, 3];
p.FeedVoltage = [1, 1];
p.FeedPhase = [0, 90];
```

### Balanced Feed

Format: `[x, y, layer]` — 3 columns.

```matlab
p.FeedLocations = [0, 0, 1];
```

### FeedViaModel

| Model | Sides | When to Use |
|-------|-------|-------------|
| `"strip"` | 2 | Default, fast |
| `"square"` | 4 | Better probe modeling |
| `"hexagon"` | 6 | More accurate |
| `"octagon"` | 8 | Most accurate |

## Via Configuration

Format: `[x, y, sigLayer, gndLayer]`.

```matlab
p.ViaLocations = [25e-3, 25e-3, 1, 3;
                  25e-3, -25e-3, 1, 3;
                  -25e-3, 25e-3, 1, 3;
                  -25e-3, -25e-3, 1, 3];
p.ViaDiameter = 0.8e-3;
```

### Via Fencing

```matlab
nVias = 20;
theta = linspace(0, 2*pi, nVias+1); theta = theta(1:end-1);
viaRadius = 28e-3;
vx = viaRadius * cos(theta);
vy = viaRadius * sin(theta);
p.ViaLocations = [vx(:), vy(:), ones(nVias,1), 3*ones(nVias,1)];
p.ViaDiameter = 0.5e-3;
```

## Conductor Material

```matlab
p.Conductor = metal("Copper");
```

Available: `PEC`, `Copper`, `Aluminium`, `Gold`, `Silver`.

## Analysis

```matlab
freq = 2.4e9;
freqRange = linspace(2e9, 3e9, 21);

Z = impedance(p, freq);
try s = sparameters(p, freqRange, SweepOption="interp");
catch, s = sparameters(p, freqRange); end
figure; rfplot(s);
figure; pattern(p, freq);

% Pattern types
pattern(p, freq, Type="directivity");
pattern(p, freq, Type="gain");
pattern(p, freq, Type="realizedgain");
```

### Mesh Control

```matlab
mesh(p, MaxEdgeLength=lambda/15);
mem = memoryEstimate(p, freq);

% Fine features near large areas
mesh(p, MaxEdgeLength=0.01, MinEdgeLength=0.001, GrowthRate=0.7);
```

## Catalog Antenna Conversion

```matlab
ant = design(patchMicrostrip, 2.4e9);
pb = pcbStack(ant);
pb.Conductor = metal("Copper");
pb.FeedDiameter = 1.27e-3;
```

`design()` does not work directly on `pcbStack`. Design catalog antenna first, then convert.

## Gerber Export

### Basic Export

```matlab
[A, g] = gerberWrite(p);
```

Requires at least one dielectric layer in `Layers`.

### With Connector and Service

```matlab
W = PCBServices.OSHParkWriter;
W.Filename = 'my_antenna';        % MUST be char, not "string"

C = PCBConnectors.SMA_Cinch;
A = PCBWriter(p, W, C);
gerberWrite(A);
```

### Edge-Launch Connector

```matlab
C = PCBConnectors.SMAEdge_Samtec;
C.EdgeLocation = 'south';
C.ExtendBoardProfile = true;
p.FeedLocations = [0, -boardW/2, 1, 3];
```

### Available Connectors

| Type | Examples |
|------|---------|
| Through-hole SMA | `SMA_Cinch`, `SMA_Multicomp` |
| Edge-launch SMA | `SMAEdge_Samtec`, `SMAEdge_Amphenol` |
| Coaxial | `Coax_RG58`, `Coax_RG174` |
| U.FL / IPX | `UFL_Hirose`, `IPX_Jack_LightHorse` |
| MMCX | `MMCX_Cinch`, `MMCX_Samtec` |

### Available Services

`OSHParkWriter`, `PCBWayWriter`, `SeeedWriter`, `MayhewWriter`, `EuroCircuitsWriter`, `AdvancedCircuitsWriter`.

----

Copyright 2026 The MathWorks, Inc.
