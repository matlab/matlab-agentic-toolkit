---
name: matlab-write-pcb-layout
description: "Export pcbComponent designs to Gerber files with RF connectors and fab service formatting for PCB manufacturing. TRIGGER: user asks to export a PCB design to Gerber, generate manufacturing files, or write out a pcbComponent for fabrication. Invoke BEFORE writing export code — gerberWrite signature (pcbComponent, connectors, filename) is non-obvious. SKIP: importing/reading PCB files (use matlab-read-pcb-layout), building PCB geometry (use matlab-assemble-pcb-layout), EM analysis (use matlab-analyze-em), material/stackup setup (use matlab-manage-pcb-material)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Writing PCB Layouts to Manufacturing Files

## When to Use

- Exporting a pcbComponent or pcbStack design to Gerber manufacturing files
- Selecting and configuring RF connectors (SMA, SMB, MMCX, etc.) for PCB export
- Formatting output for specific fabrication services (OSH Park, Seeed, Advanced Circuits)
- Attaching RFConnector objects to catalog components for shielded analysis
- Generating a complete manufacturing package from a MATLAB RF design

## When NOT to Use

- Importing Gerber files into MATLAB — use `matlab-read-pcb-layout`
- Building the PCB design itself — use `matlab-assemble-pcb-layout` or the designing skills
- Running EM analysis — use `matlab-analyze-em`

## Typical Workflow

1. **Before:** A design skill or `matlab-assemble-pcb-layout` — create the pcbComponent; `matlab-analyze-em` — validate performance; `matlab-optimize-pcb-design` — tune if needed
2. **This skill:** Export to Gerber with connectors and fab formatting

## Quick Reference

| Task | Code |
|------|------|
| Export Gerber files | `[A,g] = gerberWrite(pcb, W, {C1,C2})` |
| SMA connector | `C = PCBConnectors.SMA_Cinch` |
| Edge-launch SMA | `C = PCBConnectors.SMAEdge_Samtec` |
| PCB service writer | `W = PCBServices.OSHParkWriter` |
| Customize writer | `W.Filename = 'name'; W.CoordUnits = 'mm'` |
| RF connector object | `rc = RFConnector` |
| Design connector for PCB | `rc = design(RFConnector, pcb)` |

## gerberWrite — Export to Manufacturing

The `gerberWrite` function generates manufacturing files from a `pcbComponent`.

### Basic Export

```matlab
p = pcbComponent;   % Your designed component
W = PCBServices.OSHParkWriter;
W.Filename = 'my_design';          % Controls output zip/folder name (default: 'untitled')
C1 = PCBConnectors.SMA_Cinch;
C2 = PCBConnectors.SMA_Cinch;

[A, outputPath] = gerberWrite(p, W, {C1, C2});
```

### Output

`gerberWrite` produces a folder of Gerber and drill files:
- Top/bottom copper layers
- Solder mask layers
- Silkscreen layers
- Drill files
- Board outline

The `A` output is a `PCBWriter` object with export metadata. `outputPath` is the path to the generated files.

## PCBWriter Object

The `PCBWriter` object controls export settings.

### Properties

| Property | Description |
|----------|-------------|
| `Design` | Struct containing the PCB design data |
| `Writer` | The PCB service writer (output format) |
| `Connector` | Cell array of connector objects |
| `UseDefaultConnector` | Use default connector if none specified |
| `ComponentBoundaryLineWidth` | Outline line width |
| `PCBMargin` | Extra board margin around component (m) |
| `Soldermask` | `'both'`, `'top'`, `'bottom'`, or `'none'` |
| `Solderpaste` | Logical — generate solderpaste layer |
| `Font` | Font for text on silkscreen |

## PCBConnectors — Connector Catalog

Attach standard RF connectors to your exported board.

### Available Connectors (25 Built-in Types)

| Category | Connectors |
|----------|-----------|
| **SMA 5-Pad** | `SMA`, `SMA_Cinch`, `SMA_Multicomp` |
| **SMA Edge-Launch** | `SMAEdge`, `SMAEdge_Cinch`, `SMAEdge_Samtec`, `SMAEdge_Amphenol`, `SMAEdge_Linx` |
| **SMB/SMC** | `SMB_Johnson`, `SMB_Pasternack`, `SMC_Pasternack`, `SMCEdge_Pasternack` |
| **MMCX** | `MMCX_Cinch`, `MMCX_Samtec` |
| **IPX/U.FL** | `IPX_Jack_Lighthorse`, `IPX_Plug_Lighthorse`, `UFL_Hirose` |
| **Coaxial Cable** | `Coax_RG11`, `Coax_RG58`, `Coax_RG59`, `Coax_RG174` |
| **Semi-Rigid** | `Semi_020`, `Semi_034`, `Semi_047`, `Semi_118` |

Access via `PCBConnectors.<type>`. All connectors have common properties: `Type`, `Mfg`, `Part`, `Annotation`, `Impedance` (default: 50 ohm), `Datasheet`, `Purchase`.

5-pad properties: `TotalSize`, `GroundPadSize`, `SignalPadDiameter`, `PinHoleDiameter`, `IsolationRing`, `VerticalGroundStrips`

Edge-launch properties: `GroundPadSize`, `GroundSeparation`, `GroundPadIsolation`, `SignalPadSize`, `SignalGap`, `SignalLineWidth`, `EdgeLocation` (`'north'|'south'|'east'|'west'`), `ExtendBoardProfile`, `FillGroundSide`

Coax properties: `PinDiameter`, `DielectricDiameter`, `ShieldDiameter`, `AddThermals`, `ThermalsDiameter`, `ThermalsBridgeWidth`

Connectors are placed at feed locations during Gerber export. They define pad footprints and drill patterns.

## PCBServices — Fabrication Service Writers

Writers configure output for specific fabrication services.

### Available Services (5 Built-in Writers)

| Service | Description |
|---------|-------------|
| `PCBServices.GerbLookWriter` | GerbLook online viewer |
| `PCBServices.ZofZWriter` | ZofZ 3-D Gerber viewer |
| `PCBServices.AdvancedCircuitsWriter` | Advanced Circuits manufacturing |
| `PCBServices.SeeedWriter` | Seeed Studio manufacturing |
| `PCBServices.OSHParkWriter` | OSH Park manufacturing |

Each writer formats Gerber files according to the fab house's naming and layer conventions.

**Key PCBServices properties:** `Filename`, `CoordUnits` (`'in'`/`'mm'`), `CoordPrecision`, `CreateArchiveFile`, `DefaultViaDiameter`, `UseExcellon`, `BoardProfileFile`, `SameExtensionForGerberFiles`, `PostWriteFcn`, `Files`

```matlab
% Customize a service writer
w = PCBServices.AdvancedCircuitsWriter;
w.Filename = 'my_antenna';
w.CoordUnits = 'mm';
w.CoordPrecision = [3 4];
```

## RF Connectors

`RFConnector` models coaxial connectors (SMA, SMB, etc.) that attach to PCB structures.

```matlab
rc = RFConnector;
rc.InnerRadius  = 5e-4;      % Center pin radius
rc.OuterRadius  = 1.5e-3;    % Outer conductor radius
rc.PinLength    = 3e-3;      % Pin insertion depth
rc.PinFootprint = 'Taper';   % 'Taper' or 'Circular'
rc.EpsilonR     = 1.7341;    % Dielectric fill permittivity
rc.Impedance    = 50;        % Characteristic impedance
```

### Attaching to a Catalog Object

Attaching a `Connector` to a catalog object (e.g., `microstripLine`) requires `IsShielded = true`:

```matlab
m = microstripLine;
m.IsShielded = true;          % Required before setting Connector
m.Connector = RFConnector;
show(m);
```

### Design for a pcbComponent

`design()` auto-tunes connector dimensions to match a PCB object. This requires an FEM-based `pcbComponent` — catalog objects like `microstripLine` do not support FEM:

```matlab
pcb = pcbComponent;           % Must be pcbComponent with SolverType='FEM'
pcb.SolverType = 'FEM';
rc = design(RFConnector, pcb);
```

## Complete Design-to-Manufacturing Workflow

```matlab
%% Design a filter
f = design(filterCoupledLine, 3e9);

%% Analyze
freq = linspace(1e9, 5e9, 101);
sp = sparameters(f, freq, 'SweepOption', 'interp');
rfplot(sp);

%% Export for manufacturing (convert to pcbComponent first)
pcb = pcbComponent(f);
W = PCBServices.OSHParkWriter;
C1 = PCBConnectors.SMA_Cinch;
C2 = PCBConnectors.SMA_Cinch;
[A, gPath] = gerberWrite(pcb, W, {C1, C2});
```

## Pitfalls

1. **Connector compatibility**: Not all connectors work with all board thicknesses. SMA edge-launch connectors assume standard substrate heights. Check connector footprint dimensions match your board.

2. **Gerber aperture limitations**: Complex curved geometries may be approximated with polygons in Gerber format. Very fine features may lose resolution during export — check minimum feature size for your target fab service.

3. **Multiple connectors need cell array**: When passing multiple connectors to `gerberWrite`, wrap them in a cell array: `gerberWrite(pcb, W, {C1, C2})`. An object array `[C1, C2]` will error.

4. **gerberWrite requires pcbComponent or pcbStack**: `gerberWrite` does not work on catalog objects (e.g., `microstripLine`, `filterHairpin`). Convert to `pcbComponent` first if needed.

5. **Connector requires IsShielded on catalog objects.** Setting `obj.Connector = RFConnector` on a catalog object (microstripLine, etc.) will error with "SolverType property must be set to 'FEM'" unless `obj.IsShielded = true` is set first. Catalog objects do not support FEM directly — use `IsShielded = true` for MoM shielded mode. `design(RFConnector, obj)` only works with `pcbComponent` objects that have `SolverType='FEM'`.

6. **IsShielded + finite conductivity conflict.** Setting `IsShielded = true` activates an internal FEM-like solver path. If you also set `Conductor = metal("Copper")` (finite conductivity), you will get "FEM solver does not support finite conductivity. Set conductivity of conductor to Inf." Leave `Conductor` at the default (PEC) when using `IsShielded = true` or `Connector`.

7. **gerberWrite on pcbcascade results.** `pcbcascade` returns a `pcbComponent`. This can be passed directly to `gerberWrite`. However, verify the port count and connector count match — pcbcascade merges ports and removes connected ports, so the surviving port count may differ from the input components.

8. **IsShielded switches solver to FEM — affects sweep options.** Setting `IsShielded = true` changes the internal solver to FEM. The `'SweepOption', 'interp'` interpolated sweep is designed for MoM and may not be available or behave differently with FEM. Run S-parameter analysis before adding `IsShielded` for export, or use a discrete frequency sweep with FEM.

## Related Skills

- `matlab-read-pcb-layout` — Import layouts from Gerber, ODB++, and Allegro
- `matlab-assemble-pcb-layout` — Building custom PCB structures from shapes
- `matlab-analyze-em` — Running EM analysis before export

----

Copyright 2026 The MathWorks, Inc.
