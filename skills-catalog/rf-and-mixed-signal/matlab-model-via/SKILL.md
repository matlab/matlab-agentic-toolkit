---
name: matlab-model-via
description: "Via modeling: pads, antipads, ground return vias, GRV placement, and signal integrity for high-speed layer transitions. TRIGGER: user asks to model a via, design a via transition, place ground return vias, analyze via performance, or check signal integrity through layer transitions. Invoke BEFORE writing code — only viaSingleEnded exists (no viaDifferential), and the location format is non-obvious. SKIP: general signal integrity without vias (use matlab-analyze-em), transmission line design (use matlab-design-pcb-txline), PDN analysis (use matlab-analyze-pcb-pdn), material/stackup setup only (use matlab-manage-pcb-material)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Modeling Vias

## When to Use

- Modeling signal vias through multi-layer PCB stackups (viaSingleEnded)
- Configuring pad and antipad geometry per layer
- Placing ground return vias for signal integrity
- Analyzing via S-parameters and identifying barrel resonances
- Evaluating GRV placement with criticalwavelength and gapratedistance

## When NOT to Use

- Designing transmission lines or impedance control — use `matlab-design-pcb-txline`
- Building custom PCB structures from shapes — use `matlab-assemble-pcb-layout`
- Setting up substrate or conductor materials — use `matlab-manage-pcb-material`
- Running full-wave EM analysis on non-via structures — use `matlab-analyze-em`
- PDN analysis on imported boards — use `matlab-analyze-pcb-pdn`

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — set up substrate and conductor for the stackup
2. **This skill:** Model the via, place GRVs, check signal integrity
3. **After:** `matlab-integrate-pcb-circuit` — cascade via model with trace/connector models → `matlab-optimize-pcb-design` — optimize GRV placement or pad geometry

## Quick Reference

| Task | Code |
|------|------|
| Create via | `via = viaSingleEnded` |
| Set signal layers | `via.SignalLayer = [1 5]` |
| Set ground layers | `via.GroundLayer = [3 7 9]` |
| Set substrate | `via.Substrate = dielectric(...)` |
| Place signal via | `via.SignalViaLocations = [x y startLayer stopLayer]` |
| Place ground return vias | `via.GroundReturnViaLocations = [x y start stop; ...]` |
| Define ports | `via.SignalTable = {viaNum layer traceWidth direction; ...}` |
| View pads | `padsTable(via)` |
| View antipads | `antipadsTable(via)` |
| Customize pads | `pads = getpads(via); pads{k}.Radius = r; via.SignalViaPad = pads` |
| Customize antipads | `ap = getantipads(via); ap{k}.Radius = r; via.SignalViaAntipad = ap` |
| Visualize | `show(via)` |
| S-parameters | `sp = sparameters(via, freq)` |
| Resonance risk check | `cw = criticalwavelength(via, freq)` |
| Max GRV distance | `gapratedistance(via, freq)` |

## viaSingleEnded Object

The `viaSingleEnded` object models signal vias through multi-layer PCB stackups with configurable pads, antipads, and ground return vias.

### Basic Setup

```matlab
via = viaSingleEnded;
via.SignalLayer = [1 5];
via.GroundLayer = [3 7 9];
via.Substrate = dielectric("Name","FR4","EpsilonR",4.8,...
    "LossTangent",0.026,"Thickness",1.27e-4,"Frequency",1e8);
via.Conductor = metal("Copper");
show(via);
```

### Key Properties

| Property | Format | Description |
|----------|--------|-------------|
| `SignalLayer` | Vector | Layer indices where signal traces connect (odd numbers) |
| `GroundLayer` | Vector | Layer indices for ground/return planes |
| `Substrate` | dielectric | Dielectric between layers |
| `Conductor` | metal | Via barrel and pad conductor |
| `SignalViaLocations` | N×4 matrix | `[x, y, startLayer, stopLayer]` per via |
| `SignalViaDiameter` | Scalar (m) | Via barrel diameter |
| `SignalViaFinishedDiameter` | Scalar (m) | Finished hole diameter (after plating) |
| `SignalViaPad` | Shape or cell | Pad shape(s) on signal via |
| `SignalViaAntipad` | Shape or cell | Antipad (clearance) shape(s) |
| `RemoveUnusedPads` | Logical | Remove pads on non-signal layers (default: true) |
| `GroundReturnViaLocations` | M×4 matrix | `[x, y, startLayer, stopLayer]` per GRV |
| `GroundReturnViaDiameter` | Scalar or vector | GRV barrel diameter |
| `GroundReturnViaFinishedDiameter` | Scalar or vector | GRV finished hole diameter |
| `SignalTable` | Cell array | Port definitions: `{viaNum, layer, traceWidth, direction}` |

## Signal Via Configuration

### Placing a Signal Via

```matlab
via = viaSingleEnded;
via.SignalLayer = [1 5];
via.GroundLayer = [3 7 9];

X = 0; Y = 0;
startLayer = 1;
stopLayer = 7;
via.SignalViaLocations = [X Y startLayer stopLayer];
```

The via barrel spans from `startLayer` to `stopLayer`. Signal connections occur on layers listed in `SignalLayer` that fall within this range.

### Via Diameter

```matlab
via.SignalViaDiameter = 0.25e-3;          % Drill diameter
via.SignalViaFinishedDiameter = 0.20e-3;  % After copper plating
```

### Unit Conversion Helper

The object provides a built-in mils-to-meters conversion:

```matlab
via.SignalViaDiameter = 10 * via.mils2meters;   % 10 mils
```

## Port Definition (SignalTable)

The `SignalTable` property defines which layers become ports for S-parameter extraction.

### Format

Each row: `{signalViaNumber, layerIndex, traceWidth, direction}`

- `signalViaNumber`: Which signal via (1-based index into `SignalViaLocations`)
- `layerIndex`: The layer where the port is placed
- `traceWidth`: Width of the connecting trace (meters)
- `direction`: Angle in degrees (0 = +x direction, 90 = +y, etc.)

### Example: Two-Port Via

```matlab
via.SignalTable = {1, 1, 3e-4, 45;   % Port 1: via 1, layer 1, 0.3mm trace, 45 deg
                   1, 5, 3e-4, 0};    % Port 2: via 1, layer 5, 0.3mm trace, 0 deg
```

### Using Table Syntax for Clarity

```matlab
vPorts = table('Size', [2 4], ...
    'VariableTypes', ["cell","cell","cell","cell"], ...
    'VariableNames', ["Signal Via Num","Layer","Trace Width","Direction"]);
vPorts(1,:) = {{1} {1} {3e-4} {45}};
vPorts(2,:) = {{1} {5} {3e-4} {0}};
via.SignalTable = vPorts.Variables;
```

## Ground Return Vias

Ground return vias provide a low-impedance return path near the signal via, critical for signal integrity.

### Placement

```matlab
via.GroundReturnViaLocations = [
    1.0015  2.001  1  9;
    1.0015  1.999  1  9;
    0.999   1.999  1  9;
    1.000   2.0015 1  9;
    0.999   2.001  1  9;
    1.0001  1.9987 1  9];
```

Each row: `[x, y, startLayer, stopLayer]`. Ground return vias typically span from the topmost to the bottommost ground layer.

### GRV Diameter

```matlab
via.GroundReturnViaDiameter = 0.25e-3;
via.GroundReturnViaFinishedDiameter = 0.20e-3;
```

These can be scalars (same for all GRVs) or vectors (one per GRV).

## Pad and Antipad Customization

### Viewing Pad/Antipad Tables

```matlab
padsTable(via)       % Rows = signal vias, Columns = conductive layers; cells are pad shape objects (e.g. antenna.Circle) or []. Scalar SignalViaPad is expanded across all positions.
antipadsTable(via)            % Signal via antipads: rows = signal vias, columns = connected layers
antipadsTable(via, "ground")  % Ground return via antipads: rows = GRVs, columns = power planes
```

### Default Pad Shape

By default, `SignalViaPad` is a circle:

```matlab
via.SignalViaPad.Radius = 3e-4;    % Set pad radius
```

### Per-Layer Pad Customization

Use `getpads` to get a cell array of pad shapes (one per layer), modify individual entries, then reassign:

```matlab
pad_temp = getpads(via);
pad_temp{3}.Radius = 4.5e-4;   % Customize pad on the 3rd layer
via.SignalViaPad = pad_temp;
```

### Antipad Customization

```matlab
via.SignalViaAntipad.Radius = 5e-4;   % Clearance radius on ground layers

% Per-layer antipad customization (cell array: SignalViaLocations × GroundLayer)
antipad_temp = getantipads(via);
antipad_temp{1,2}.Radius = 6e-4;   % Customize antipad on 2nd ground layer
via.SignalViaAntipad = antipad_temp;
```

### RemoveUnusedPads

When `RemoveUnusedPads = true` (default), pads are only placed on layers in `SignalLayer`. Set to `false` to place pads on all layers the via passes through:

```matlab
via.RemoveUnusedPads = false;
padsTable(via)   % Now shows pads on all layers
```

## Via Arrays

For modeling multiple signal vias (e.g., BGA breakout or bus routing):

### Grid-Based Via Array

```matlab
obj = viaSingleEnded;
obj.SignalLayer = [1 3];
obj.GroundLayer = [1 3];   % Mixed signal/ground layers
obj.Conductor = metal('Name','Copper','Thickness',3*obj.mils2meters,'Conductivity',10e9);
obj.Substrate = dielectric('EpsilonR',3.7,'LossTangent',0.03,'Thickness',12*obj.mils2meters);
obj.SignalViaDiameter = 10 * obj.mils2meters;
obj.SignalViaPad.Radius = 1.00001 * obj.SignalViaDiameter/2;
obj.SignalViaAntipad.Radius = 15 * obj.mils2meters;

% Create grid of all via positions
[X,Y] = meshgrid(1:8, 1:8);
allXYs = [X(:) Y(:)];

% Signal via subset
[X,Y] = meshgrid([1 3 5 8], [1 2 4 6 8]);
SVXYs = [X(:) Y(:)];

% Ground via locations = everything else
GRVXYs = setdiff(allXYs, SVXYs, 'rows');
```

### Assigning Multiple Signal Vias

```matlab
startLayer = 1; stopLayer = 3;
obj.SignalViaLocations = [SVXYs, repmat([startLayer stopLayer], size(SVXYs,1), 1)];
obj.GroundReturnViaLocations = [GRVXYs, repmat([startLayer stopLayer], size(GRVXYs,1), 1)];
```

### Open Signal Vias (No Ports)

To model signal vias without assigning ports (open-circuited), leave `SignalTable` empty or assign ports only to specific vias:

```matlab
% Only port via #1 on layers 1 and 3
obj.SignalTable = {1, 1, 5*obj.mils2meters, 0;
                   1, 3, 5*obj.mils2meters, 0};
```

All other signal vias remain as open (unported) stubs — useful for studying coupling in dense via fields.

## Multi-Layer Stackup

### Layer Numbering Convention

Layers alternate metal and dielectric, numbered sequentially:

```
Layer 1:  Metal (signal or ground)
Layer 2:  Dielectric
Layer 3:  Metal (signal or ground)
Layer 4:  Dielectric
Layer 5:  Metal (signal or ground)
...
```

Only odd-numbered layers are metal. `SignalLayer` and `GroundLayer` use these odd indices.

### Example: 10-Layer Board

```matlab
via = viaSingleEnded;
via.SignalLayer = [1 7];         % Signal on layers 1 and 7
via.GroundLayer = [3 5 9];      % Ground on layers 3, 5, and 9
via.Substrate = dielectric("Name","FR4","EpsilonR",4.4,...
    "LossTangent",0.02,"Thickness",0.1e-3);
```

The substrate `Thickness` is the thickness of each dielectric layer (uniform). For non-uniform stackups, use a multi-element dielectric.

## Analysis

### S-Parameters

```matlab
freq = linspace(1e9, 20e9, 51);
sp = sparameters(via, freq, 'Behavioral', true);
rfplot(sp);

% Verify insertion loss meets threshold across band
S21_dB = 20*log10(abs(squeeze(sp.Parameters(2,1,:))));
idx = find(S21_dB <= -1, 1);
if isempty(idx), fprintf('PASS: IL < 1 dB across band\n');
else, fprintf('FAIL: IL exceeds 1 dB at %.1f GHz\n', sp.Frequencies(idx)/1e9); end
```

### TDR (Time Domain Reflectometry)

Use the `tdr` function from the Signal Integrity Toolbox. Thumb rules for parameters: `RiseTime = 1/fmax`, `SampleTime = 1/(100*fmax)`, `EndTime = 0.1e-9`, where `fmax` is the maximum frequency of the S-parameter sweep:

```matlab
fmax = 20e9;
tdrObj = tdr(sp, RiseTime=1/fmax, SampleTime=1/(100*fmax), EndTime=0.1e-9);
plot(tdrObj)
```

### SI Analysis Functions

Two functions help evaluate whether ground return vias are close enough to the signal via at a target frequency:

| Function | Syntax | Returns |
|----------|--------|---------|
| `criticalwavelength` | `cw = criticalwavelength(via, freq)` | Number of wavelengths between the signal via and its nearest ground return via at `freq`. Values approaching 0.25 or 0.5 indicate resonance risk. |
| `gapratedistance` | `gapratedistance(via, freq)` | Maximum allowable center-to-center distance between signal via and nearest ground return via for a default critical-wavelength threshold of 0.25. |

```matlab
% Check resonance risk at 28 GHz
cw = criticalwavelength(via, 28e9);

% Plot max allowable GRV distance vs frequency
freq = linspace(1e9, 56e9, 200);
gapratedistance(via, freq);

% Stricter threshold (0.125 instead of default 0.25)
gapratedistance(via, freq, 0.125);
```

Use `criticalwavelength` to spot-check a specific frequency of concern. Use `gapratedistance` to generate a curve showing how tight GRV placement must be across a frequency range. Both require at least one ground return via to be defined.

> **Gotcha:** `criticalwavelength(via)` requires a frequency argument. Omitting it will error.

### Identifying Via Resonances

Via barrel resonances appear as sharp dips in S21 (insertion loss) during a wideband sweep. To find them:

1. Sweep well beyond the signaling bandwidth (at least 2-3x the Nyquist frequency).
2. Use fine frequency resolution (300-500 points) so narrow dips are not missed.
3. Plot S21 and look for notches; their frequencies correspond to resonant modes of the via barrel bounded by the ground planes.

```matlab
% Wideband sweep to identify resonances
via = viaSingleEnded;
freq = linspace(1e9, 50e9, 500);
s = sparameters(via, freq);

% Insertion loss — dips indicate barrel resonances
figure;
rfplot(s, 2, 1);
title('Via Insertion Loss — Check for Resonance Dips');

% Return loss — peaks correspond to the same resonances
figure;
rfplot(s, 1, 1);
title('Via Return Loss');
```

Moving ground return vias closer to the signal via pushes resonances to higher frequencies. Use `criticalwavelength` at the dip frequency to confirm the mechanism, and `gapratedistance` to determine how close GRVs must be to keep resonances above the band of interest.

### Visualization

```matlab
show(via);          % 3-D view with pads, antipads, and vias
layout(via);        % Top-down layout view
```

**Note:** `viaSingleEnded` uses a behavioral (circuit) model, not a full-wave MoM mesh. Functions like `mesh`, `memoryEstimate`, and `getZ0` are not available on this object. To extract characteristic impedance, compute it from S-parameters or ABCD parameters post-solve.

## High-Speed Via Design (40+ Gbps)

For high-speed signaling, ground return via (GRV) placement is critical to managing return path inductance and crosstalk.

### GRV Placement Strategy

Sweep GRV configurations to find the minimum number of ground vias that meet insertion loss targets:

```matlab
via = viaSingleEnded;
via.Substrate = dielectric('Name', {'FR4','FR4','FR4','FR4'}, ...
    'EpsilonR', [4.4, 4.4, 4.4, 4.4], ...
    'LossTangent', [0.02, 0.02, 0.02, 0.02], ...
    'Thickness', [0.5e-3, 0.5e-3, 0.5e-3, 0.5e-3], ...
    'Frequency', [1e9, 1e9, 1e9, 1e9], ...
    'FrequencyModel', {'DjordjevicSarkar','DjordjevicSarkar','DjordjevicSarkar','DjordjevicSarkar'});

% Parametric GRV placement — compare 1, 2, 4, 8 ground vias
for nGRV = [1, 2, 4, 8]
    via.GroundReturnViaLocations = generateGRVPositions(nGRV, pitch);
    S = sparameters(via, freq, 50);
    rfplot(S);
    hold on;
end
```

### Differential Via Pairs

There is no `viaDifferential` class — model differential via pairs using `viaSingleEnded` with two entries in `SignalViaLocations`. For 40 Gbps differential pairs, manage crosstalk by controlling via-to-via spacing and GRV fence placement:

```matlab
via = viaSingleEnded;
via.SignalViaLocations = [0, -pitch/2; 0, pitch/2];   % Differential pair
via.GroundReturnViaLocations = [                        % GRV fence
    -pitch, -pitch; -pitch, 0; -pitch, pitch;
     pitch, -pitch;  pitch, 0;  pitch, pitch];
```

## Frequency Range Guidelines for Interface Standards

When analyzing vias for a specific interface, sweep S-parameters to at least the Nyquist frequency. For resonance checks, sweep to 2-3x Nyquist.

| Interface Standard | Data Rate | Nyquist Frequency | Recommended Sweep Range |
|--------------------|-----------|-------------------|------------------------|
| PCIe Gen3 | 8 GT/s | 4 GHz | 1-12 GHz |
| PCIe Gen4 | 16 GT/s | 8 GHz | 1-24 GHz |
| PCIe Gen5 | 32 GT/s | 16 GHz | 1-48 GHz |
| PCIe Gen6 | 64 GT/s (PAM4) | 16 GHz | 1-48 GHz |
| USB 3.2 Gen1 | 5 GT/s | 2.5 GHz | 1-8 GHz |
| USB 3.2 Gen2 | 10 GT/s | 5 GHz | 1-15 GHz |
| USB4 / Thunderbolt 3 | 20 GT/s | 10 GHz | 1-30 GHz |
| DDR4-3200 | 3.2 GT/s | 1.6 GHz | 1-5 GHz |
| DDR5-4800 | 4.8 GT/s | 2.4 GHz | 1-8 GHz |
| DDR5-6400 | 6.4 GT/s | 3.2 GHz | 1-10 GHz |
| 100GBASE-KR4 | 25.78 GT/s | 12.89 GHz | 1-40 GHz |
| 400GBASE-KR4 (PAM4) | 53.125 GT/s | 26.56 GHz | 1-56 GHz |

Use these ranges when setting up `sparameters(via, freq)` sweeps. For resonance identification, extend the upper limit by 2-3x beyond the Nyquist frequency shown above.

## Pitfalls

1. **Layer numbering alternates metal and dielectric**: With the default `viaSingleEnded` constructor (no arguments), metal layers are odd (1, 3, 5, ...) and dielectric layers are even. With `viaSingleEnded(N)`, soldermask layers are added and metal layers use even numbering (2, 4, 6, ...). Always check the object's `SignalLayer` and `GroundLayer` properties to confirm which indices are metal.

2. **SignalViaLocations and GroundReturnViaLocations require 4 columns**: Each row must be `[x y startLayer stopLayer]`. Do NOT use 2-column `[x y]` — it will error or produce invalid geometry. Example: `via.SignalViaLocations = [0 0 1 9]` (not `[0 0]`).

3. **SignalTable viaNum must match SignalViaLocations**: The first column of `SignalTable` indexes into `SignalViaLocations` rows. If you have 3 signal vias, valid via numbers are 1, 2, 3.

4. **Pad radius must exceed via radius**: `SignalViaPad.Radius` must be larger than `SignalViaDiameter/2`. If they're equal or pad is smaller, the geometry is invalid.

5. **Antipad vs pad clearance**: The antipad is the clearance hole in ground planes. It must be larger than the pad to provide insulation. Typical rule: antipad radius >= pad radius + 0.1mm.

6. **GRV span**: Ground return vias should span at least from the signal entry layer to the signal exit layer. Shorter GRVs degrade return path quality at higher frequencies. Currently, ground return vias must always be PTH (full span of the stackup) and cannot be back-drilled.

7. **mils2meters units**: All geometric properties are in meters. Use `via.mils2meters` (= 2.54e-5) for conversion from mils: `10*via.mils2meters` = 0.254mm.

8. **Behavioral model only**: `viaSingleEnded` uses a behavioral (circuit) model — not MoM. `mesh(via)`, `memoryEstimate(via, freq)`, and `getZ0(via, freq)` are **not available**. Use `sparameters(via, freq, 'Behavioral', true)` to suppress the "Switching to behavioral model" warning.

9. **Direction in SignalTable**: The direction angle determines where the trace exits the pad. Ensure traces from adjacent ports don't overlap — check with `show(via)`.

10. **Default GRV span may exceed stackup**: The default `GroundReturnViaLocations` spans to layer 9 regardless of actual stackup size. Always set `GroundReturnViaLocations` explicitly to match your stackup's layer range.

11. **Set geometry before getpads()**: `getpads()` triggers `checkDimensions()` internally. All properties — including `GroundReturnViaLocations` — must be valid before calling it, or it will error.

12. **Mixed layers (Signal and Ground) only at top/bottom**: Only the top and bottom metal layers of the stackup can appear in both `SignalLayer` and `GroundLayer`. Middle layers cannot be mixed — MATLAB errors with "must be either assigned as a Ground Layer or a Signal Layer but not both." Mixed top/bottom layers enable vertical ports while providing ground references for the behavioral model.

13. **Back-drilled vias must terminate on a ground (connected) layer**: When modeling a back-drilled (non-PTH) signal via, the behavioral model requires the via's start/stop layer to be a ground (connected) layer or any bottom/top layer of the stackup. If the via ends on a signal-only layer, `sparameters` errors with "signal via must end on a connected layer."

14. **"Vertical" is a valid direction in SignalTable**: In addition to numeric angles (0, 90, 180, etc.), `"Vertical"` is an accepted value for the direction field in `SignalTable`. It creates a vertical port connection through the via barrel. Constraint: vertical ports are only valid on signal layers at the top or bottom of the full stackup.

15. **`show(via, "View", "metal")`**: Use the `"View","metal"` name-value pair to display only metal layers (pads, antipads, barrels) without dielectric fill.

16. **Dielectric arrays must all match in size**: When specifying a multi-layer substrate, `Name`, `EpsilonR`, `LossTangent`, `Thickness`, and `Frequency` must all have the same number of elements. If `Name` is a cell array with K entries, all other properties must also have K entries — otherwise MATLAB errors with "size of 'Thickness' (or 'Frequency') does not match number of layers specified in 'Name'." The default `FrequencyModel` is `'DjordjevicSarkar'` (not `'Constant'`).

17. **Dielectric layer count for `viaSingleEnded(N)`**: When using `viaSingleEnded(N)` (N = number of conductive layers), the substrate requires a minimum of N dielectric layers. N-1 layers errors with "Incorrect number of Substrate: Expected N." Extra layers beyond N are added as soldermask (top/bottom). The default constructor creates N+1 dielectric layers (N-1 core/prepreg + 2 thin soldermask). Metal layers use even numbering (2, 4, 6, ...) with this constructor.

18. **At least 2 ground planes required for S-parameter analysis**: The behavioral model requires at least 2 ground (connected) layers in `GroundLayer` for `sparameters` to work. With only 1 ground plane, MATLAB errors with "At least 2 connected layers must be present for analysis." Use mixed top/bottom layers (pitfall #12) to satisfy this requirement on boards with fewer dedicated ground layers. Additionally, if power planes are present, there must be at least one ground plane above and below each power plane.

## Related Skills

- `matlab-manage-pcb-material` — Substrate and conductor setup for via stackups
- `matlab-analyze-pcb-pdn` — Power distribution network analysis
- `matlab-analyze-em` — S-parameter extraction and mesh control
- `matlab-integrate-pcb-circuit` — serialLinkDesigner for eye diagram analysis
- `matlab-assemble-pcb-layout` — Using ViaLocations in pcbComponent

----

Copyright 2026 The MathWorks, Inc.
