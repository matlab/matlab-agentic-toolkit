# BC and Load Property Reference

## Boundary Dimension Rule

BCs and loads apply on the **boundary** of the domain (lower dimension than the region):
- **3-D:** boundary = faces, edges, vertices; region = cell
- **2-D:** boundary = edges, vertices; region = face

## faceBC / edgeBC (Prescribed Values — Dirichlet)

| Property | Domain | Description |
|----------|--------|-------------|
| `Temperature` | Thermal | Fixed temperature value or function |
| `Constraint` | Structural | `"fixed"`, `"roller"`, `"symmetric"` |
| `XDisplacement` | Structural | Prescribed x-displacement |
| `YDisplacement` | Structural | Prescribed y-displacement |
| `ZDisplacement` | Structural | Prescribed z-displacement |
| `Voltage` | EM | Fixed electric potential |
| `MagneticPotential` | EM | Fixed magnetic potential (3-D: vector `[Ax;Ay;Az]`, 2-D: scalar) |
| `ElectricField` | EM | Prescribed E-field (harmonic) |
| `MagneticField` | EM | Prescribed H-field (harmonic) |
| `FarField` | EM | `farFieldBC(Thickness=t)` — absorbing BC |

## vertexBC (Structural only)

| Property | Domain | Description |
|----------|--------|-------------|
| `Constraint` | Structural | `"fixed"` — locks all displacement components |
| `XDisplacement` | Structural | Prescribed x-displacement (scalar or function) |
| `YDisplacement` | Structural | Prescribed y-displacement (scalar or function) |
| `ZDisplacement` | Structural | Prescribed z-displacement (3-D only) |

No thermal or EM vertex BCs are supported.

## faceLoad / edgeLoad (Natural BCs and Sources)

| Property | Domain | Description |
|----------|--------|-------------|
| `Heat` | Thermal | Heat flux (W/m² on face, W/m on edge) |
| `ConvectionCoefficient` | Thermal | Convection h (MUST pair with `AmbientTemperature`) |
| `AmbientTemperature` | Thermal | Ambient T for convection or radiation |
| `Emissivity` | Thermal | Surface emissivity for radiation |
| `Pressure` | Structural | Normal pressure on face/edge |
| `SurfaceTraction` | Structural | Traction vector [Tx; Ty; Tz] |
| `TranslationalStiffness` | Structural | Elastic foundation stiffness |
| `SurfaceCurrentDensity` | EM | Surface current |
| `ChargeDensity` | EM | Surface charge |
| `CurrentDensity` | EM | Current density |
| `Magnetization` | EM | Magnetization vector |

## vertexLoad (Concentrated Loads)

| Property | Domain | Description |
|----------|--------|-------------|
| `Force` | Structural | Force vector: `[Fx; Fy]` (2-D) or `[Fx; Fy; Fz]` (3-D) |

NO component-wise properties (`XForce`, `YForce` don't exist). Always use `Force` vector.

## cellLoad (Body/Volume Loads — 3-D only)

| Property | Domain | Description |
|----------|--------|-------------|
| `Heat` | Thermal | Volumetric heat generation (W/m³) |
| `Gravity` | Structural | Gravitational acceleration `[gx; gy; gz]` — applied globally |
| `AngularVelocity` | Structural | Centrifugal load `[wx; wy; wz]` (rad/s) |
| `Temperature` | Structural | Temperature field for thermal stress (scalar or thermal results object). Requires `model.ReferenceTemperature` |
| `ChargeDensity` | EM | Volume charge density |
| `CurrentDensity` | EM | Volume current density vector (3-D magnetostatic: `[Jx; Jy; Jz]`) |
| `Magnetization` | EM | Volume magnetization vector |

**2-D equivalent:** No `cellLoad` in 2-D — use `faceLoad` on the 2-D face region for body loads (Heat, Gravity, AngularVelocity, CurrentDensity, Magnetization, ChargeDensity).

**Axisymmetric:** `AngularVelocity` (centrifugal) is on `faceLoad`, not `cellLoad`.

## Radiation Requirements

When using `Emissivity` on `faceLoad`/`edgeLoad`:
1. Set `model.StefanBoltzmannConstant = 5.670374419e-8`
2. Use Kelvin for ALL temperatures (BCs, ICs, ambient)

## Entity Dimension Rules

| Geometry | BCs applied to | Loads applied to | ICs applied to |
|----------|----------------|------------------|----------------|
| 3-D | Face, Edge, Vertex | Face, Cell, Vertex | Cell, Face, Edge, Vertex |
| 2-D | Edge, Vertex | Edge, Face, Vertex | Face, Edge, Vertex |

**IC precedence** (highest → lowest): `VertexIC` > `EdgeIC` > `FaceIC` > `CellIC`. When ICs overlap, the more specific entity wins regardless of assignment order.

## Assignment Patterns

```matlab
% 3-D thermal
model.FaceBC(faceID) = faceBC(Temperature=100);
model.FaceLoad(faceID) = faceLoad(ConvectionCoefficient=30, AmbientTemperature=25);
model.CellLoad(cellID) = cellLoad(Heat=1e6);

% 3-D structural
model.FaceBC(faceID) = faceBC(Constraint="fixed");
model.VertexLoad(vertexID) = vertexLoad(Force=[0; 0; -1000]);

% 2-D: Edge for boundaries, Face for area
model.EdgeBC(edgeID) = edgeBC(Temperature=100);
model.EdgeLoad(edgeID) = edgeLoad(ConvectionCoefficient=30, AmbientTemperature=25);
model.VertexLoad(vertexID) = vertexLoad(Force=[0; -1000]);

% Multi-material per-cell
model.MaterialProperties(1) = materialProperties(ThermalConductivity=400);
model.MaterialProperties(2) = materialProperties(ThermalConductivity=50);
```

----
Copyright 2026 The MathWorks, Inc.
----
