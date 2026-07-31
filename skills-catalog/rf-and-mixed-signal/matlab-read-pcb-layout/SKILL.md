---
name: matlab-read-pcb-layout
description: "Import Gerber, ODB++, Allegro .brd, .mcm files for PCB boards and IC packages. Inspect nets, layers, shapes, and stackups. TRIGGER: user asks to import, read, or open a PCB layout file. Gerber files use gerberRead or PCBReader; ODB++, Allegro .brd, .mcm, and native formats use pcbFileRead. Also when inspecting nets, layers, components, or stackups from an imported board. Invoke BEFORE writing import code — the query API (cadnet, cadnetList, componentList) is specialized. SKIP: EM analysis or S-parameter extraction (use matlab-analyze-em), PDN/IR-drop analysis (use matlab-analyze-pcb-pdn), building custom geometry (use matlab-assemble-pcb-layout), material/stackup definition only (use matlab-manage-pcb-material)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Reading PCB and Package Layouts

**Scope:** `pcbFileRead` handles both PCB boards and IC/SiP packages. ODB++ and Allegro files may contain package-level designs (BGA substrates, interposers, embedded passives). The workflow is identical — the format determines what's inside, not the function name.

## When to Use

- Importing Gerber files (`.gtl`, `.gbl`, `.gbr`, etc.) into MATLAB for visualization or EM analysis
- Reading ODB++ archives (zipped or unzipped) to inspect board or package layouts
- Importing Cadence Allegro `.brd` files
- Inspecting cadnets, components, layers, pins, or shapes from imported layouts
- Extracting metal layer polygons from Gerber files for use in custom designs
- Building a `pcbComponent` from externally designed layouts for S-parameter analysis

## When NOT to Use

- Exporting designs to Gerber files — use `matlab-write-pcb-layout`
- Building PCB structures from scratch with shape primitives — use `matlab-assemble-pcb-layout`
- Running EM analysis after import — use `matlab-analyze-em`
- Defining substrates or stackup materials — use `matlab-manage-pcb-material`

## Typical Workflow

1. **This skill:** Import the PCB layout from Gerber, ODB++, or Allegro
2. **After:** `matlab-analyze-pcb-pdn` — PDN DC analysis on imported board; or `matlab-analyze-em` — S-parameter extraction from imported geometry; or `matlab-model-via` — via analysis on imported stackup

## Quick Reference

| Task | Code |
|------|------|
| Import Gerber file | `P = gerberRead('file.gtl')` |
| Extract shapes | `shp = shapes(P)` |
| Define stackup | `S = stackUp` |
| Multi-layer import | `p = PCBReader('StackUp', S)` |
| Convert to pcbComponent | `pcb = pcbComponent(p)` |
| Import ODB++ | `pfile = pcbFileRead('design.zip')` |
| Import Allegro .brd | `pfile = pcbFileRead('design.brd')` |
| List cadnets | `tbl = cadnetList(pfile)` |
| Open a cadnet | `cnet = cadnet(pfile, "NET_NAME")` |
| Query layer stackup | `su = stackUp(pfile)` |
| List components | `tbl = componentList(pfile)` |
| List padstacks | `tbl = padStackList(pfile)` |

## gerberRead — Simple Import

The `gerberRead` function imports Gerber files and returns a `PCBReader` object. Use `shapes()` to extract the metal layers as polygon shapes.

### Basic Usage

```matlab
P = gerberRead('interdigital_Capacitor.gtl');
shp = shapes(P);      % Extract metal layer shapes
show(shp(1));          % Show top layer polygon
```

### Centering Imported Geometry

Imported shapes often have non-zero offsets from CAD origin. Extract shapes, then center:

```matlab
P = gerberRead('myDesign.gtl');
shp = shapes(P);
layer1 = shp(1);

% Get bounding box to compute center offset
verts = layer1.Vertices;
cx = (max(verts(:,1)) + min(verts(:,1))) / 2;
cy = (max(verts(:,2)) + min(verts(:,2))) / 2;

% Center using translate
layer1 = translate(layer1, [-cx -cy 0]);
show(layer1);
```

### Supported Gerber File Extensions

| Extension | Layer Type |
|-----------|-----------|
| `.gtl` | Top copper |
| `.gbl` | Bottom copper |
| `.gts` | Top solder mask |
| `.gbs` | Bottom solder mask |
| `.gto` | Top silkscreen |
| `.gbo` | Bottom silkscreen |
| `.drl` | Drill file |
| `.gbr` | Generic Gerber |

## stackUp — Multi-Layer Definition

The `stackUp` object defines the full PCB layer structure for importing multi-layer boards.

### Default stackUp

```matlab
S = stackUp;
```

A default stackup has numbered layers. Odd layers are conductors (metal or Gerber files), even layers are dielectrics.

### Assigning Gerber Files to Layers

```matlab
S = stackUp;
S.Layer1.Thickness = 0.1e-3;           % Air layer above board
S.Layer2 = 'interdigital_Capacitor.gtl'; % Top copper from Gerber
```

### Multi-Layer Stackup

```matlab
S = stackUp;
S.Layer1.Thickness = 0.1e-3;       % Air
S.Layer2 = 'top_copper.gtl';       % Top copper
S.Layer3.Thickness = 0.2e-3;       % Dielectric
S.Layer3.EpsilonR = 4.4;
S.Layer4 = 'inner_layer.g2';       % Inner copper
S.Layer5.Thickness = 1.0e-3;       % Core dielectric
S.Layer5.EpsilonR = 4.4;
S.Layer6 = 'bottom_copper.gbl';    % Bottom copper
```

## PCBReader — Full Board Import

`PCBReader` wraps the stackup with Gerber files into a reader object that can be converted to `pcbComponent`.

### Basic Workflow

```matlab
S = stackUp;
S.Layer1.Thickness = 0.1e-3;
S.Layer2 = 'interdigital_Capacitor.gtl';

p = PCBReader('StackUp', S);
pcb = pcbComponent(p);
pcb.FeedDiameter = 0.001;
show(pcb);
```

### Adding Feeds After Import

After converting to `pcbComponent`, add feed locations for EM analysis:

```matlab
pcb = pcbComponent(p);
pcb.FeedDiameter = 1e-3;
pcb.FeedLocations = [-5e-3 0 1 3;    % Port 1
                      5e-3 0 1 3];    % Port 2
sp = sparameters(pcb, linspace(1e9, 10e9, 51), 'SweepOption', 'interp');
rfplot(sp);
```

### Determining Feed Locations from Imported Geometry

Feed locations must fall on metal traces. After converting a Gerber import to `pcbComponent`, inspect the geometry to find valid feed points:

```matlab
pcb = pcbComponent(p);
show(pcb);                      % Visual inspection — identify trace endpoints
layout(pcb);                    % Top-down layout view with dimensions
```

For programmatic placement, extract the imported layer's mesh vertices and compute edge midpoints:

```matlab
m = mesh(pcb);                  % Get mesh structure for coordinate reference
```

When feed locations are uncertain, place feeds at the visual endpoints of the main transmission line trace, inset by at least `FeedDiameter/2` from the trace edge.

### FeedLocations Column Semantics

`FeedLocations = [x, y, col3, col4]` — Column 3 is the **signal layer** (where the feed probe/sphere appears). Column 4 is the **ground reference layer**. The probe connects from col3 to col4. If you swap them, the feed sphere renders on the wrong layer.

### Edge Feeds (Strip Model)

For structures fed at the board edge (e.g., microstrip lines terminating at the PCB boundary), use the strip feed model:

```matlab
pcb.FeedViaModel = 'strip';
pcb.FeedDiameter = traceWidth / 2;  % Must be half the trace width for edge feeds
```

The `'strip'` model creates a planar feed at the board edge rather than a vertical via probe. Place feeds at the exact edge of the BoardShape where the trace terminates.

### PCBReader Layer Structure

After `pcbComponent(PCBReader)`, the `Layers` cell array follows the standard alternating pattern: `{metal, dielectric, metal, ...}`. The metal layers contain the imported Gerber shapes. Layer indices for `FeedLocations` follow the same odd-numbered convention (1, 3, 5, ...) as manually assembled `pcbComponent` objects.

### Converting PCBReader to pcbComponent

The `pcbComponent` constructor accepts a `PCBReader` object directly.

## Cadence Allegro .brd Import

**When the user references a `.brd` file for import or analysis, always ask for their Cadence `extracta.exe` path before attempting the import.** The `extracta` utility is required and must be configured first. Do not assume it is already set up.

```matlab
% Step 1: Check if extracta is already configured
extractaSetup()                % Displays current path, or [] if not set

% Step 2: If [], ask user for path and configure (persists across sessions)
extractaSetup('C:/Cadence/SPB_17.4/tools/bin/extracta.exe')

% Step 3: Import
pcb = pcbFileRead('design.brd');
```

`extractaSetup(path)` accepts the full path to the Cadence `extracta.exe` executable. The path persists across MATLAB sessions — it only needs to be run once. Without this, `.brd` imports fail with an `extracta` error.

Calling `extractaSetup()` with no arguments displays the currently configured path (or `[]` if not yet set). Use this to check whether setup has already been done.

## ODB++ Import

```matlab
pcb = pcbFileRead('design.zip');       % Zipped ODB++
pcb = pcbFileRead('odb_directory');    % Unzipped ODB++
```

## Board and Package Inspection

`pcbFileRead` opens ODB++, Allegro, or native PCB files for hierarchical inspection — layers, cadnets, components, parts, pins, and shapes. This works identically for PCB boards and IC/SiP packages.

### Opening a File

```matlab
pfile = pcbFileRead('ExampleBoard.odb');
```

The returned object exposes: `NumLayers`, `NumCadnets`, `NumPadStacks`, `NumComponents`, `NumParts`, `LayerHeight`.

### Querying Layer Stackup

`stackUp(pfile)` returns a **table** of material details for every layer in the imported board:

```matlab
su = stackUp(pfile);                   % Full stackup table
su = stackUp(pfile, [2 3 4]);         % Specific layers only
```

The table has columns: `LayerNumber`, `LayerName`, `LayerType`, `Material`, `Thickness(inch)`, `EpsilonR`, `LossTangent`, `Conductivity(S/m)`.

**Note:** This is an object function on `pcbFileRead` that returns a table — it is unrelated to the `stackUp` constructor used with Gerber import (see the Pitfalls section).

### Navigating the Hierarchy

```matlab
% List cadnets (electrical nets)
tbl = cadnetList(pfile);               % Returns table with net names

% Open a specific cadnet and get its shapes
cnet = cadnet(pfile, "VDD_CORE");
data = cadnetData(cnet);               % Struct with .Surfaces, .Pins, .Vias, .Traces
s = shapes(cnet);                      % Same struct as cadnetData (equivalent call)

% List and inspect components
tbl = componentList(pfile);
comp = component(pfile, "U1");
pins = componentPinData(comp);         % Returns pinsData array (see below)

% List and inspect parts (component types)
tbl = partList(pfile);
p = part(pfile, "IC6ANT");
cdata = componentData(p);             % Components that use this part type

% List padstacks
tbl = padStackList(pfile);

% Layer-level inspection (metal layers only — use pfile.MetalLayer for valid indices)
lyr = layer(pfile, pfile.MetalLayer(1));
ldata = layerData(lyr);

% Search for components in a cadnet
results = findComponents(cnet);
results = findComponents(cnet, 'ComponentType', 'IC');
```

### Shape Data Structure

`shapes(cnet)` and `cadnetData(cnet)` are equivalent — both return a **struct** with fields:

| Field | Type | Content |
|-------|------|---------|
| `.Surfaces` | antenna.Polygon array | Copper pours and fills |
| `.Pins` | antenna.Polygon array | Pad shapes |
| `.Vias` | antenna.Polygon array | Via barrel shapes |
| `.Traces` | antenna.Polygon array | Routed trace segments |

```matlab
s = shapes(cnet);
s.Traces(1).Vertices   % Vertices of first trace segment
numel(s.Surfaces)      % Number of copper pours
```

`layerData(lyr)` returns the same struct format. Each antenna.Polygon has a `.Vertices` property (Nx3 double).

### componentPinData — Pin Positions and Properties

`componentPinData(comp)` returns a `pinsData` array. Each element has:

| Property | Type | Description |
|----------|------|-------------|
| `Center` | 1x2 double | XY position of pin center (board units) |
| `PinNumber` | char/string | Pin number/name |
| `CadnetName` | char/string | Net the pin connects to |
| `PinShape` | char | Shape type (e.g., 'Rect', 'Circle') |
| `StartLayer` | double | First layer the pin spans |
| `StopLayer` | double | Last layer the pin spans |
| `Length` | double | Pad length |
| `Width` | double | Pad width |
| `Diameter` | double | Pad diameter (for circular pads) |
| `Vertices` | Nx3 double | Full pad outline vertices |

```matlab
comp = component(pfile, "U1");
pins = componentPinData(comp);
pins(1).Center       % [x, y] in board units (inches for ODB++)
pins(1).CadnetName   % Which net this pin connects to
pins(1).PinNumber    % Pin identifier
```

**Coordinate units:** For ODB++ imports, pin positions (`.Center`) and shape vertices are in the board's native units — typically **inches**. Convert to meters for use in `pcbComponent`: multiply by `25.4e-3`.

### Tracing a Circuit Path Across Nets

Use `findComponents` + `componentPinData` to hop across nets via shared components:

```matlab
pwr_net = cadnet(pfile, "+PWR");
pwr_comps = findComponents(pwr_net);   % Table: ComponentIndex, Refdes, PinList, ComponentType, Part

% Open a component and discover its other nets
q4 = component(pfile, string(pwr_comps.Refdes(9)));
q4_pins = componentPinData(q4);
for i = 1:numel(q4_pins)
    fprintf('%s.%s -> %s at [%.3f, %.3f]\n', "Q4", ...
        string(q4_pins(i).PinNumber), string(q4_pins(i).CadnetName), ...
        q4_pins(i).Center(1), q4_pins(i).Center(2));
end

% Follow Q4's output net to find the next component
next_net = cadnet(pfile, string(q4_pins(1).CadnetName));
next_comps = findComponents(next_net);
```

## Using Imported Shapes in Custom Designs

Import Gerber geometry and combine with other shapes using Boolean operations:

```matlab
% Import a CSRR pattern from Gerber
reader = gerberRead('csrr_pattern.gbr');
shp = shapes(reader);
csrr = shp(1);
verts = csrr.Vertices;
cx = (max(verts(:,1)) + min(verts(:,1))) / 2;
cy = (max(verts(:,2)) + min(verts(:,2))) / 2;
csrr = translate(csrr, [-cx -cy 0]);

% Use as DGS or combine with other geometry
ground = traceRectangular(Length=30e-3, Width=20e-3);
groundWithSlots = ground - csrr;

pcb = pcbComponent;
signal = traceRectangular(Length=25e-3, Width=3e-3);
sub = dielectric("FR4");
sub.Thickness = 1.6e-3;
pcb.Layers = {signal, sub, groundWithSlots};
pcb.BoardShape = ground;
pcb.BoardThickness = sub.Thickness;
show(pcb);
```

## Import-to-Analysis Workflow

```matlab
%% Import
S = stackUp;
S.Layer1.Thickness = 0.1e-3;
S.Layer2 = 'myFilter.gtl';

p = PCBReader('StackUp', S);
pcb = pcbComponent(p);

%% Configure for analysis
pcb.FeedDiameter = 0.5e-3;
pcb.FeedLocations = [-10e-3 0 1 3; 10e-3 0 1 3];
pcb.Conductor = metal("Copper");
show(pcb);

%% Analyze
freq = linspace(1e9, 10e9, 51);
sp = sparameters(pcb, freq, 'SweepOption', 'interp');
rfplot(sp);
```

## Common Error Diagnostics

| Error | Cause | Fix |
|-------|-------|-----|
| "File not found" | Wrong path or unsupported format | Verify path; use `fullfile()` for cross-platform paths |
| "Unrecognized file format" | File extension doesn't match content | Pass format explicitly: `pcbFileRead(file, 'FileType', 'ODB++')` |
| Stack-up mismatch after import | Layer count/materials differ from design | For `pcbFileRead` imports: call `stackUp(pfile)` to inspect the imported layer table. For Gerber imports: verify your `stackUp` constructor matches the source design |
| `extracta` error on `.brd` import | Cadence Allegro extracta not configured | Run `extractaSetup()` first, then retry |
| Empty `cadnetList` results | Board has no routed nets or wrong format version | Open board in native EDA tool to verify routing exists |

## Pitfalls

1. **Coordinate alignment**: Gerber files from different CAD tools may use different origins. Always check and translate to center before combining layers or adding feeds.

2. **Units mismatch**: Gerber files can be in mils or mm. RF PCB Toolbox uses meters internally. If imported geometry looks too large or too small, check the source file's unit setting.

3. **gerberRead returns PCBReader, not shapes**: `gerberRead` returns a `PCBReader` object. Call `shapes(P)` to extract the metal layer polygons. Don't try to use `P.Vertices` or `show(P)` directly on the reader.

4. **Layer ordering in stackUp constructor**: Layer numbering in the `stackUp` constructor starts from the top. `Layer1` is typically air above the board, `Layer2` is the top copper. Odd-numbered physical metal layers map to even `stackUp` layers (since Layer1 is air).

5. **`layer()` only accepts metal layer indices.** `layer(pfile, idx)` requires `idx` to be a metal layer number. Use `pfile.MetalLayer` to get valid indices. Passing a dielectric layer index (e.g., `layer(pfile, 1)` when layer 1 is dielectric) errors with "Value must be a member of this set: ..."

6. **`componentData` is on `part`, not `component`.** To get the list of components that use a part type, call `componentData(p)` where `p = part(pfile, partName)`. The `component` object has `componentPinData` and `shapes`, but not `componentData`.

7. **`stackUp` name collision.** `S = stackUp` (no arguments) creates a constructor object for defining Gerber import layer structures. `su = stackUp(pfile)` is an object function on `pcbFileRead` that returns a **table** of material details. These are completely different types with different purposes. Do not confuse them.

8. **Large imported geometries**: Full-board Gerber imports can be very large. For EM analysis, extract only the region of interest rather than analyzing the entire board.

9. **Always ask for extracta path before .brd import.** When the user points to a `.brd` file, first run `extractaSetup()` (no args) to check if it's already configured. If it returns `[]`, ask the user for the path to their Cadence `extracta.exe` and run `extractaSetup(path)`. Typical path: `C:/Cadence/SPB_<version>/tools/bin/extracta.exe`. Without this, `.brd` imports fail.

10. **Package vs board — same workflow.** ODB++ and Allegro files may contain IC packages, not just PCBs. `pcbFileRead` handles both identically. The format determines the content, not the function name.

## Related Skills

- `matlab-write-pcb-layout` — Export designs to Gerber manufacturing files
- `matlab-assemble-pcb-layout` — Building custom PCB structures from shapes
- `matlab-analyze-em` — Running EM analysis on imported boards
- `matlab-manage-pcb-material` — Substrate setup for imported stackups
- `matlab-analyze-pcb-pdn` — PDN analysis on imported boards

----

Copyright 2026 The MathWorks, Inc.
