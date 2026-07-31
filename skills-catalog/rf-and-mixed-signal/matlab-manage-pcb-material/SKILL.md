---
name: matlab-manage-pcb-material
description: "Dielectric substrates, metal conductors, multi-layer stackups, and loss models (FR4, Rogers, Teflon) for RF PCB simulation. TRIGGER: user asks to set up a substrate, define dielectric properties, create a stackup, select a PCB material (FR4, Rogers, Teflon, etc.), or configure metal conductors. Invoke BEFORE writing dielectric() or metal() code — the API for named vs custom materials differs significantly. SKIP: PCB layout assembly (use matlab-assemble-pcb-layout), transmission line design (use matlab-design-pcb-txline), EM analysis (use matlab-analyze-em), importing a PCB file (use matlab-read-pcb-layout)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Managing Materials for RF PCB Toolbox

## When to Use

- Creating dielectric substrates for transmission lines, filters, couplers, or custom pcbComponent designs
- Selecting metals (Copper, Gold, etc.) for realistic conductor loss modeling
- Building multi-layer dielectric stacks for stripline or embedded designs
- Choosing frequency-dependent dispersion models (DjordjevicSarkar) for wideband accuracy
- Looking up catalog material properties or adding custom materials

## When NOT to Use

- Building the PCB layer structure itself — use `matlab-assemble-pcb-layout`
- Running EM analysis after materials are defined — use `matlab-analyze-em`
- Designing transmission lines that happen to need substrates — use `matlab-design-pcb-txline` (it references this skill for material details)
- Importing material properties from an existing board file — use `matlab-read-pcb-layout`

## Typical Workflow

1. **This skill:** Define substrate, conductor, and stackup — typically the first step in any RF PCB design
2. **After:** Any design skill (`matlab-design-pcb-filter`, `matlab-design-pcb-txline`, `matlab-assemble-pcb-layout`, `matlab-model-via`) — pass materials to the component

## Quick Reference

| Task | Code |
|------|------|
| Catalog dielectric | `sub = dielectric("FR4")` |
| Custom dielectric | `sub = dielectric(Name="MyMat", EpsilonR=4.4, LossTangent=0.02, Thickness=1.6e-3)` |
| Multi-layer dielectric | `sub = dielectric("FR4","Teflon"); sub.Thickness = [0.8e-3 0.4e-3]` |
| Catalog metal | `cond = metal("Copper")` |
| Custom metal | `cond = metal(Name="MyMetal", Conductivity=5.8e7, Thickness=35e-6)` |
| Browse dielectrics | `DielectricCatalog` |
| Browse metals | `MetalCatalog` |
| Frequency-dependent | `sub = dielectric(..., Frequency=1e9)` |
| Get properties at freq | `[epsr, tand, f] = getMaterialProperties(sub, freqVector)` |

## Creating Dielectrics

The `dielectric` object defines substrate properties. Create from the built-in catalog or specify custom parameters.

### From Catalog

```matlab
sub = dielectric("FR4");
sub = dielectric("Teflon");
sub = dielectric("RO4730JXR");
sub = dielectric("TMM10");
```

To see every name in the catalog:

```matlab
dc = DielectricCatalog;
disp(dc.Materials)
```

Available catalog names (R2026a): Air, FR4, Teflon, Foam, Polystyrene, Plexiglas, Fused quartz, E glass, RO4725JXR, RO4730JXR, TMM3, TMM4, TMM6, TMM10, TMM10i, Taconic RF-35. Add custom materials with `add(dc, ...)` if your material is not listed.

### Custom Properties

```matlab
sub = dielectric(Name="Rogers4350B", EpsilonR=3.66, LossTangent=0.0037, Thickness=0.508e-3);
```

### Key Properties

| Property | Description | Units |
|----------|-------------|-------|
| `Name` | Material identifier | string |
| `EpsilonR` | Relative permittivity | dimensionless |
| `LossTangent` | Dielectric loss tangent (tan δ) | dimensionless |
| `Thickness` | Layer thickness | meters |
| `Frequency` | Reference frequency for loss tangent | Hz |
| `FrequencyModel` | `'Constant'`, `'DjordjevicSarkar'`, `'MeanDjordjevicSarkar'`, or `'TableDriven'` | — |

### Browsing the Catalog

```matlab
dc = DielectricCatalog;
open(dc)               % Opens interactive catalog viewer
disp(dc.Materials)     % List all materials as a table
s = find(dc, "FR4");   % Returns struct with Name, Relative_Permittivity, Loss_Tangent, Frequency, Comments
```

## Creating Metals

The `metal` object defines conductor properties.

### From Catalog

```matlab
cond = metal("Copper");       % Conductivity=5.96e7, Thickness=35.56e-6 (1 oz)
cond = metal("Aluminium");    % Conductivity=3.77e7, Thickness=762e-6
cond = metal("Gold");         % Conductivity=4.11e7, Thickness=0.2e-6
```

Available catalog metals (R2026a): PEC, Copper, Aluminium, Gold, Silver, Zinc, Tungsten, Lead, Iron, Steel, Brass.

### Custom Properties

```matlab
cond = metal(Name="ThickCopper", Conductivity=5.8e7, Thickness=70e-6);
```

### Browsing the Catalog

```matlab
mc = MetalCatalog;
open(mc)                    % Opens interactive catalog viewer
disp(mc.Materials)          % List all metals as a table
s = find(mc, "Aluminium");  % Returns struct with Name, Conductivity, Thickness, Units, Comments
```

### Assigning to Components

```matlab
mline = microstripLine;
mline.Conductor = metal("Copper");
```

## Multi-Layer Substrates

Many RF PCB components support multi-layer dielectric stacks. Pass multiple material names or use vector properties.

### Shorthand Syntax (catalog names)

```matlab
sub = dielectric("FR4", "Teflon");
sub.Thickness = [0.0016 0.0008];
```

### Explicit Multi-Layer

```matlab
sub = dielectric(Name={"FR4","Foam","FR4"}, ...
    EpsilonR=[4.4 1.05 4.4], ...
    LossTangent=[0.02 0.001 0.02], ...
    Thickness=[0.4e-3 0.8e-3 0.4e-3]);
```

**Important**: Use a cell array `{...}` for `Name`, not a string array `[...]`. String array concatenation (`["FR4","Foam"]`) produces a single string `"FR4Foam"`, not a multi-element array.

### Assigning to Components

```matlab
balun = balunMarchand;
balun.Height = 0.0016;
balun.Substrate = sub;
show(balun);
```

Multi-layer substrates are supported by all catalog components that have a `Substrate` or `Height` property (transmission lines, filters, couplers, splitters, etc.).

## Dielectrics in pcbComponent

When building custom structures with `pcbComponent`, dielectrics appear as layers in the `Layers` cell array:

```matlab
pcb = pcbComponent;
substrate = dielectric("RO4730JXR");
substrate.Thickness = 1.52e-3;
ground = traceRectangular(Length=20e-3, Width=10e-3);

pcb.BoardThickness = substrate.Thickness;
pcb.Layers = {signalTrace, substrate, ground};
```

For multi-dielectric pcbComponent stacks (5-layer):

```matlab
sub1 = dielectric(Name="FR4", EpsilonR=4.4, LossTangent=0.02, Thickness=0.8e-3);
sub2 = dielectric(Name="FR4", EpsilonR=4.4, LossTangent=0.02, Thickness=0.8e-3);

pcb.BoardThickness = sub1.Thickness + sub2.Thickness;
pcb.Layers = {topTrace, sub1, groundPlane, sub2, bottomTrace};
```

## Frequency-Dependent Loss Models

For accurate wideband modeling, specify a reference frequency for the loss tangent:

```matlab
sub = dielectric(Name="FR4", EpsilonR=4.4, LossTangent=0.02, ...
    Thickness=1.6e-3, Frequency=1e9);
```

When `Frequency` is specified, the `FrequencyModel` property automatically becomes `'DjordjevicSarkar'`. This causal model extrapolates permittivity and loss tangent across the analysis bandwidth, ensuring physically consistent results. Without `Frequency`, the model uses `'Constant'` (frequency-independent).

Available dispersion models:
- `"Constant"` -- (default) frequency-independent permittivity and loss tangent
- `"DjordjevicSarkar"` -- wideband causal model, best for PCB substrates
- `"MeanDjordjevicSarkar"` -- averaged version of DjordjevicSarkar
- `"TableDriven"` -- user-supplied frequency-dependent data from vendor datasheets

### Frequency Model Selection Guide

| Frequency Range | Recommended Model | Use Case |
|-----------------|-------------------|----------|
| DC -- 1 GHz | `Constant` (default) | Low-frequency, quick estimates |
| 1 -- 40 GHz | `DjordjevicSarkar` | Most RF PCB designs, FR4/Rogers |
| Broadband with vendor data | `TableDriven` | Import manufacturer permittivity vs. frequency curves |
| Wideband model fitting | `MeanDjordjevicSarkar` | Averaged causal model for broadband sweeps |

### Querying Dispersion-Aware Properties

Use `getMaterialProperties()` to calculate permittivity and loss tangent at specific frequencies, accounting for the active dispersion model:

```matlab
sub = dielectric("FR4");
sub.FrequencyModel = "DjordjevicSarkar";
sub.Frequency = 1e9;

% Get properties across a frequency sweep
freq = linspace(1e8, 10e9, 100);
[epsr, tand, f] = getMaterialProperties(sub, freq);

% Plot frequency-dependent permittivity
plot(f/1e9, epsr);
xlabel("Frequency (GHz)"); ylabel("\epsilon_r");
title("FR4 Permittivity (DjordjevicSarkar)");
```

## Common Material Parameters

### Dielectric Catalog Values (R2026a)

| Material | EpsilonR | LossTangent | Freq (Hz) | Notes |
|----------|----------|-------------|-----------|-------|
| FR4 | 4.8 | 0.026 | 1e8 | Standard PCB |
| Teflon | 2.1 | 0.0002 | 1e8 | Low-loss PTFE |
| Foam | 1.03 | 0.00015 | 5e7 | Air-like spacer |
| RO4725JXR | 2.55 | 0.0022 | 2.5e9 | Rogers, halogen-free |
| RO4730JXR | 3.0 | 0.0023 | 2.5e9 | Rogers, halogen-free |
| TMM10 | 9.8 | 0.0022 | 1e10 | Ceramic-filled PTFE |
| Taconic RF-35 | 3.5 | 0.0018 | 1.9e9 | Low-loss RF |

Materials **not in catalog** that must be created manually:

```matlab
sub = dielectric(Name="RO4003C", EpsilonR=3.38, LossTangent=0.0027, Thickness=0.508e-3);
sub = dielectric(Name="RO4350B", EpsilonR=3.66, LossTangent=0.0037, Thickness=0.508e-3);
```

### Metal Catalog Values (R2026a)

| Metal | Conductivity (S/m) | Catalog Thickness | Notes |
|-------|-------------------|-------------------|-------|
| PEC | Inf | 0 | Perfect conductor (default) |
| Copper | 5.96e7 | 35.56 μm (1.4 mil, 1 oz) | Most common |
| Aluminium | 3.77e7 | 762 μm (30 mil) | |
| Gold | 4.11e7 | 0.2 μm | Plating |
| Silver | 6.3e7 | 0.2 μm | Highest conductivity |

## Pitfalls

1. **Set BoardThickness before Layers**: `pcbComponent.BoardThickness` must equal the sum of all dielectric thicknesses. Always assign `BoardThickness` **before** `Layers` — reversing the order triggers a warning and silently overwrites dielectric thicknesses.

2. **Default conductor is PEC**: If you don't assign a `Conductor`, components use perfect electric conductor (lossless). Always assign `metal("Copper")` for realistic loss modeling.

3. **Most Rogers materials not in catalog**: Only RO4725JXR and RO4730JXR are in `DielectricCatalog`. Common substrates like RO4003C, RO4350B, and RO3003 must be created manually from datasheet values. Calling `dielectric("RO4003C")` will error.

4. **Multi-layer Thickness must match element count**: When using vector `Thickness`, the number of elements must equal the number of names/EpsilonR values. Mismatched lengths throw an error.

5. **Units are always SI**: Thickness in meters (not mm or mils). A 1.6 mm board is `1.6e-3`, not `1.6`.

6. **FrequencyModel can be set post-design.** After `design()` creates a component with a default constant dielectric, you can switch to DjordjevicSarkar: `obj.Substrate.FrequencyModel = 'DjordjevicSarkar'; obj.Substrate.Frequency = 1e9;`. This is useful when the design step doesn't accept frequency-dependent substrates.

7. **Named catalog dielectrics are single-layer**: `dielectric("FR4")` creates a 1-layer object with fixed catalog properties. For multi-layer pcbComponent stacks, create separate unnamed `dielectric` objects with explicit `EpsilonR`, `LossTangent`, and scalar `Thickness` for each layer. Do NOT use a named catalog entry when you need to control per-layer thickness in a `Layers` cell array.

8. **Dielectric layer count for `viaSingleEnded`**: When building a multi-layer substrate for `viaSingleEnded`, the number of dielectric layers must equal N-1 where N is the number of conductive layers in the stackup (e.g., Signal=[1 5], Ground=[3 7] → 4 metal layers → 3 dielectric layers). When using the `viaSingleEnded(N)` constructor, soldermask layers are added automatically — see `matlab-model-via` Pitfall #17 for exact requirements. All dielectric property arrays (`Name`, `EpsilonR`, `LossTangent`, `Thickness`, `Frequency`) must match in size.

## Related Skills

- `matlab-assemble-pcb-layout` — Using materials in custom pcbComponent structures
- `matlab-analyze-em` — How material properties affect solver accuracy
- `matlab-design-pcb-txline` — Substrate selection for impedance control

----

Copyright 2026 The MathWorks, Inc.
