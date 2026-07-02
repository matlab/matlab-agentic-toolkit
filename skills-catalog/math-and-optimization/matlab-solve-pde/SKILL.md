---
name: matlab-solve-pde
description: >
  End-to-end finite element analysis in MATLAB PDE Toolbox — geometry creation,
  model setup, solve, and post-processing in one skill. Use when building geometry
  from primitives or file import, setting up femodel with BCs/loads/materials,
  solving thermal/structural/EM problems, and extracting or visualizing results.
  Covers fegeometry, multicuboid, multicylinder, multisphere, decsg, boolean ops,
  mesh generation, femodel, all AnalysisTypes (thermalSteady, thermalTransient,
  structuralStatic, structuralTransient, structuralModal, structuralFrequency,
  electrostatic, magnetostatic, dcConduction, harmonic EM), materialProperties,
  faceBC, faceLoad, cellLoad, vertexLoad, solve, interpolation, von Mises stress,
  principal stress, reaction forces, heat flux, pdeplot3D visualization.
  Triggers on: PDE Toolbox, finite element, FEA, thermal analysis, structural
  analysis, electromagnetic analysis, femodel, mesh, boundary conditions, stress,
  displacement, heat transfer, post-processing.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# PDE Toolbox — Full FEA Workflow

End-to-end finite element analysis: geometry → model setup → solve → post-process. Uses the modern `femodel` workflow (R2025a+).

## When to Use

- Building geometry from primitives (`multicuboid`, `multicylinder`, `multisphere`), STL/STEP import, or 2-D `decsg`
- Setting up `femodel` with boundary conditions, loads, materials, and initial conditions
- Solving thermal, structural, or electromagnetic problems (steady, transient, modal, frequency, conduction)
- Post-processing FE results: interpolation, derived quantities, visualization

## When Not to Use

- General-equation PDE (`createpde(N)`) — that legacy workflow is not covered here
- System-level simulation (Simulink/Simscape) — use product-specific skills
- Mesh-only tasks with no PDE solve (e.g., surface meshing for visualization)

## Workflow Overview

1. **Geometry** — Create with primitives, `decsg`, file import, or boolean ops → wrap in `fegeometry`
2. **Model** — `femodel(AnalysisType=..., Geometry=gm)` → material, BCs, loads, ICs
3. **Mesh** — `generateMesh(model)` (default first, refine if needed)
4. **Solve** — `result = solve(model)` or `solve(model, tlist)`
5. **Post-process** — Extract fields, interpolate, compute derived quantities, visualize

## Phase 1: Geometry

### fegeometry — The Hub

```matlab
gm = fegeometry(multicuboid(1, 1, 1));       % From primitives
gm = fegeometry("model.stl");                % From STL/STEP file
gm = fegeometry(decsg(gd, sf, ns));          % From 2-D CSG
gm = fegeometry(nodes, elements);            % From mesh data
```

**`fegeometry` is for the `femodel` workflow only.** Do NOT use `fegeometry` with `createpde(N)` — that legacy workflow uses `geometryFromEdges` (2-D) or `importGeometry` (3-D) instead. This skill covers `femodel` exclusively.

Key properties: `NumCells`, `NumFaces`, `NumEdges`, `Vertices`

### 3-D Primitives

| Function | Origin | Arguments |
|----------|--------|-----------|
| `multicuboid(W, D, H)` | x-y centered, **base at z=0** | Width, Depth, Height |
| `multicylinder(R, H)` | x-y centered, **base at z=0** | Radius, Height |
| `multisphere(R)` | **Centered at origin** | Radius |

Nested cells (vectors), stacked layers (`ZOffset`), hollow (`Void=[true,false]`):

```matlab
gm = fegeometry(multicylinder([0.3, 0.5], 1, Void=[true, false]));  % hollow pipe
gm = fegeometry(multicuboid([1, 1], [1, 1], [0.3, 0.7], ZOffset=[0, 0.3]));  % stacked
```

See `references/primitives-and-import.md` for full options and file import details.

### Boolean Operations

```matlab
gmCombined = union(gm1, gm2);                         % Merge into 1 cell
gmCombined = union(gm1, gm2, KeepBoundaries=true);    % Preserve cells (multi-material)
gmCombined = union(gm1, gm2, KeepBoundaries=[true, false]);  % Selective per shape
gmResult = subtract(gm1, gm2);                        % Cut gm2 from gm1
gmResult = intersect(gm1, gm2);                       % Keep only overlapping region
```

**`KeepBoundaries`**: Use `true` when shapes get different materials (preserves internal faces as cell boundaries). Omit or use `false` to merge into a single cell.

**Cell modification** after boolean ops:

```matlab
gm = mergeCells(gm);              % Merge ALL cells into one
gm = mergeCells(gm, [2, 3]);      % Merge specific cells (must be connected)
gm = deleteCell(gm, cellIDs);     % Remove unwanted cells
```

**Rules:** Union first, subtract last. The function is `subtract` — NOT `subtractgeom`. Never assemble pre-hollowed pieces. Call `mergeCells` only ONCE at the end.

See `references/boolean-and-cell-ops.md` for full strategy (Sculpt+Carve, Void flags, addCell, addVoid, face imprinting).

### 2-D Geometry with decsg

Each shape is a column vector in the geometry matrix. First entry identifies the type:

| Type code | Shape | Column format |
|-----------|-------|---------------|
| `1` | Circle | `[1; xc; yc; r; 0; ...]` |
| `2` | Polygon | `[2; N; x1;...;xN; y1;...;yN]` |
| `3` | Rectangle | `[3; 4; x1;x2;x3;x4; y1;y2;y3;y4]` (CCW corners) |
| `4` | Ellipse | `[4; xc; yc; a; b; angle; 0; ...]` |

All columns must have the same row count — pad shorter ones with zeros. Set formula: `+` (union), `-` (subtract), `*` (intersect).

```matlab
R1 = [3; 4; 0; 1; 1; 0; 0; 0; 0.5; 0.5];
C1 = [1; 0.5; 0.25; 0.15; 0; 0; 0; 0; 0; 0];
gd = [R1, C1]; sf = '(R1-C1)'; ns = char('R1', 'C1')';
gm = fegeometry(decsg(gd, sf, ns));
```

See `references/decsg-and-2d-geometry.md` for polygon vertices, polar-coordinate shapes, extrude, namespace rules.

### Entity Identification

```matlab
topFace = nearestFace(gm, [0, 0, 1]);       % Single point: row vector
faceIDs = nearestFace(gm, [0 0 1; 0 0 0]);  % Multiple points: N×3 matrix
frontEdge = nearestEdge(gm, [0.5, 0, 0.5]);
cellID = findCell(model.Geometry, [x, y, z]); % fegeometry only (not DiscreteGeometry)
facesOfCell = cellFaces(gm, 1);              % All faces of cell 1
facesOfCell = cellFaces(gm, 1, "external");  % Only outer boundary faces
edgesOfCell = cellEdges(gm, 1);
edgeIDs = faceEdges(gm, faceID);
fIDs = facesAttachedToEdges(gm, edgeID);              % Faces sharing an edge
fIDs = facesAttachedToEdges(gm, edgeID, "internal");  % Only internal faces (3-D)
```

**Identify faces/edges BEFORE meshing.** `nearestVertex` does not exist — use `gm.Vertices` + distance calculation.

### Transforms

```matlab
gm = translate(gm, [dx, dy, dz]);
gm = rotate(gm, angle);                          % angle° about z through origin
gm = rotate(gm, angle, [cx cy cz]);              % about z through point [cx,cy,cz]
gm = rotate(gm, angle, [x1 y1 z1], [x2 y2 z2]); % about LINE from pt1 to pt2
gm = scale(gm, [1, 1, -1]);                      % reflect across z=0 (use -1 on axis to flip)
```

**`rotate` 4-arg:** Both args are **points defining the axis line**, not direction+origin. E.g., about y through origin: `rotate(gm, 90, [0 0 0], [0 1 0])`. The 3-arg form ONLY rotates about z.

### Extrude

```matlab
gm3d = extrude(gm2d, [0.1, 0.3, 0.1]);   % 2-D → 3-D stacked layers along z
gm = extrude(gm, faceID, 0.2);            % 3-D face extrusion along outward normal
```

### Mesh Generation

**Only mesh when needed.** Escalate: default → global → local.

```matlab
gm = generateMesh(gm);                            % Default (try first)
gm = generateMesh(gm, Hmax=0.1, Hmin=0.01);      % Global control
gm = generateMesh(gm, HFace={[3,5], 0.02});       % Local face refinement (cell array!)
gm = generateMesh(gm, HEdge={edgeIDs, 0.005}, Hmax=0.2, Hgrad=1.5);
gm = generateMesh(gm, HVertex={vtxID, 0.005}, Hgrad=1.5);  % Stress concentrations
```

**`GeometricOrder`**: Default `"quadratic"`. Use `"linear"` for faster solves. **Important:** 3-D `magnetostatic`/`magneticHarmonic`/`electricHarmonic` require linear mesh (Nedelec elements) — `generateMesh` handles this automatically.

**Mesh properties:** `mesh.Nodes` (3×N), `mesh.Elements` (connectivity), `meshQuality(mesh)` (0–1), `area(mesh)`, `volume(mesh)`.

## Phase 2: Model Setup

**Units:** PDE Toolbox is unit-less. All inputs are pure numbers — the user must keep dimensions, properties, loads, and constants in a self-consistent unit system. Do not assume SI.

### Create Model

```matlab
model = femodel(AnalysisType="thermalSteady", Geometry=gm);
```

### AnalysisType Reference

| AnalysisType | Use For |
|---|---|
| `"thermalSteady"` / `"thermalTransient"` / `"thermalModal"` | Heat transfer |
| `"structuralStatic"` / `"structuralTransient"` / `"structuralModal"` / `"structuralFrequency"` | Stress/displacement |
| `"electrostatic"` / `"magnetostatic"` / `"dcConduction"` | Static EM |
| `"electricHarmonic"` / `"magneticHarmonic"` | AC EM |

Pattern is `<physics><Type>`. NEVER `"transientStructural"` or `"steadyStateThermal"`.

### Material Properties

```matlab
model.MaterialProperties = materialProperties(Material="steel");           % Catalog (preferred)
model.MaterialProperties = materialProperties(YoungsModulus=70e9, PoissonsRatio=0.33);  % Explicit
model.MaterialProperties(cellID) = materialProperties(Material="copper");  % Per-cell
```

Catalog names: `"copper"`, `"Invar"`, `"steel"`, `"aluminum"`, `"brass"`, `"tungsten"`, `"iron"`, `"gold"`, `"silver"`, `"lead"`, `"zinc"`, `"glass"`, `"concrete"`, `"wood"`.

**Orthotropic** (structural): All three as 3-element vectors — `ShearModulus` has no scalar form:
```matlab
model.MaterialProperties = materialProperties(YoungsModulus=[Ex Ey Ez], ...
    PoissonsRatio=[nu_xy nu_yz nu_xz], ShearModulus=[Gxy Gyz Gxz], MassDensity=rho);
```

**Note:** Structural analysis is linear-elastic only — no plasticity or hyperelastic models.

### Structural Damping

Three forms: **Hysteretic** (`HystereticDamping=η` on materialProperties, frequency response only), **Rayleigh** (`model.DampingAlpha`, `model.DampingBeta`, transient/frequency), **Modal** (`DampingZeta=ζ` at solve time with `ModalResults`).

```matlab
% Hysteretic — frequency response
model.MaterialProperties = materialProperties(..., HystereticDamping=0.05);
% Rayleigh — transient/frequency (C = alpha*M + beta*K)
model.DampingAlpha = 10; model.DampingBeta = 0.002;
% Modal — with modal superposition
R = solve(model, tlist, ModalResults=Rm, DampingZeta=0.02);
```

See `references/damping-reference.md` for frequency-dependent damping and when to use each form.

### Nonconstant (Function) Parameters

Any material property, BC, or load can be a function handle. Signatures: `@(location, state)` for BCs/loads/materials, `@(location)` for ICs only.

`location`: `.x`, `.y`, `.z` (always), `.nx`, `.ny`, `.nz` (boundary only).
`state`: `.time`, `.frequency`, `.u`, `.ux`/`.uy`/`.uz`, `.NormFluxDensity` (analysis-dependent).

**NaN convention (critical):** Solver probes with NaN in state fields. Function MUST return NaN of correct size when state fields are NaN. Pure arithmetic propagates NaN automatically; only conditional logic needs an explicit check:

```matlab
pressure = @(location, state) ...
    ifelse(isnan(state.time), NaN(1,numel(location.x)), ...
    1e5*sin(2*pi*100*state.time)*ones(1,numel(location.x)));
```

**Vectorization:** Output as 1×Np row (scalars) or 3×Np matrix (vectors). See `references/nonconstant-parameters.md` for state fields and output size rules. See `references/time-dependent-loads.md` for full NaN patterns with conditionals.

### Boundary Conditions vs Loads

**Rule:** Prescribed values (Dirichlet) → BC. Everything else → Load.

**Boundary dimension rule:**
- **3-D:** boundary = faces, edges, vertices (region = cell); body load = `cellLoad`
- **2-D:** boundary = edges, vertices (region = face); body load = `faceLoad`

| BC (Dirichlet) | Load (Neumann/Robin) |
|---|---|
| `faceBC`, `edgeBC`, `vertexBC` | `faceLoad`, `edgeLoad`, `cellLoad`, `vertexLoad` |
| `Temperature`, `Constraint`, `XDisplacement` | `Heat`, `ConvectionCoefficient`+`AmbientTemperature` |
| `Voltage`, `MagneticPotential` | `Pressure`, `SurfaceTraction`, `Force` |

```matlab
model.FaceBC(topFace) = faceBC(Temperature=100);          % 3-D thermal
model.EdgeBC(edgeID) = edgeBC(Temperature=100);            % 2-D thermal
model.VertexBC(vtxID) = vertexBC(Constraint="fixed");      % Structural pin
model.FaceLoad(sideFace) = faceLoad(ConvectionCoefficient=30, AmbientTemperature=25);
model.VertexLoad(tipVtx) = vertexLoad(Force=[0; -1000; 0]);  % Full vector, no YForce
model.CellLoad(1) = cellLoad(Heat=1e6);                    % Body load (3-D)
model.CellLoad(1) = cellLoad(Gravity=[0; 0; -9.81]);       % Self-weight (structural 3-D)
model.CellLoad(1) = cellLoad(Temperature=thermalResults);  % Thermal stress coupling (3-D)
model.FaceLoad(1) = faceLoad(Gravity=[0; -9.81]);          % Body loads in 2-D use faceLoad
```

`vertexBC` is structural-only: `Constraint="fixed"`, `XDisplacement`, `YDisplacement`, `ZDisplacement`.

**Common mistakes:** Convection on `faceBC` → error (it's a load). `faceBC` in 2-D → error (use `edgeBC`). `cellLoad` in 2-D → error (use `faceLoad`).

See `references/bc-load-reference.md` for complete property tables.

### Radiation

When using `Emissivity` on `faceLoad`/`edgeLoad`: set `model.StefanBoltzmannConstant = 5.670374419e-8` and use **all temperatures in Kelvin**.

### Thermal Stress

Temperature load generates strain only when `ReferenceTemperature` is set:
```matlab
model.ReferenceTemperature = 20;  % Strain = CTE × (T - Tref)
```

### Initial Conditions

**Required for all transient analyses.** Structural transient needs BOTH Displacement and Velocity.

```matlab
model.CellIC = cellIC(Temperature=25);                                    % Thermal 3-D
model.FaceIC = faceIC(Temperature=25);                                    % Thermal 2-D
model.CellIC = cellIC(Displacement=[0;0;0], Velocity=[0;0;0]);           % Structural 3-D
model.FaceIC = faceIC(Displacement=[0;0], Velocity=[0;0]);               % Structural 2-D
model.CellIC = cellIC(MagneticVectorPotential=Rlin);                     % Nonlinear mag 3-D
```

### PlanarType (2-D)

Set AFTER construction: `model.PlanarType = "planeStress";` (or `"planeStrain"`, `"axisymmetric"`)

### Model Reusability — ALWAYS Reuse

When a task requires multiple analysis types on the same geometry, **change `AnalysisType` on the existing model** — NEVER create a second `femodel`:

```matlab
model = femodel(AnalysisType="structuralStatic", Geometry=gm);
model.MaterialProperties = materialProperties(Material="brass");
model.FaceBC(bottomFace) = faceBC(Constraint="fixed");
model = generateMesh(model);
staticResult = solve(model);
model.AnalysisType = "structuralModal";  % Reuse — geometry, material, mesh carry over
modalResult = solve(model, FrequencyRange=[-Inf, 5000]);
model.AnalysisType = "structuralTransient";  % Modal transient
transientResult = solve(model, tlist, ModalResults=modalResult, DampingZeta=0.02);
```

**Multi-physics coupling sequences:**

| Sequence | Pattern | Caveat |
|----------|---------|--------|
| static → modal → transient | Change AnalysisType, mesh reused | None |
| dcConduction → magnetostatic | `cellLoad(CurrentDensity=conductionResults)` | **Must re-mesh**: magnetostatic uses Nedelec (linear) elements; dcConduction defaults to quadratic |
| electrostatic → electricHarmonic | Change AnalysisType, add frequency | Add `VacuumPermeability` (harmonic needs both constants) |
| magnetostatic → magneticHarmonic | Change AnalysisType, add frequency | None if already linear mesh |
| thermalSteady → structuralStatic | `cellLoad(Temperature=thermalResults)` | Set `ReferenceTemperature` on structural model |

**Mesh regeneration rule:** When switching TO `magnetostatic`, `magneticHarmonic`, or `electricHarmonic` (Nedelec elements), the mesh must be linear. If the prior analysis used quadratic (default), call `generateMesh(model)` again — the solver will auto-select linear order for these types.

### Electromagnetic Setup

EM types require vacuum constants:
```matlab
model.VacuumPermittivity = 8.854187817e-12;   % Required for electrostatic, harmonic
model.VacuumPermeability = 4*pi*1e-7;         % Required for magnetostatic, harmonic
```

**Nonlinear permeability** (magnetostatic): Express μr as `@(~,s) muRfcn(s.NormFluxDensity)`. Two-step: solve linear first with constant μr, then use result as initial guess via `cellIC(MagneticVectorPotential=Rlin)`.

See `references/electromagnetic-setup.md` for CurrentDensity format (scalar in 2-D, vector in 3-D), nonlinear B-H workflow, harmonic EM, far-field BCs.

## Phase 3: Solve

| Analysis type | Syntax | Notes |
|--------------|--------|-------|
| Steady/static | `R = solve(model)` | thermalSteady, structuralStatic, electrostatic, magnetostatic, dcConduction |
| Transient | `R = solve(model, tlist)` | tlist = monotonically increasing vector (seconds) |
| Modal (structural) | `R = solve(model, FrequencyRange=[ω1, ω2])` | Bounds in **rad/s**. Use `-Inf` lower bound |
| Modal (thermal) | `R = solve(model, DecayRange=[-Inf, λmax])` | Decay rates in s⁻¹. Use `-Inf` lower bound |
| Frequency response | `R = solve(model, flist)` | flist in **rad/s** (multiply Hz by 2π) |
| Modal superposition | `R = solve(model, tlist, ModalResults=Rm)` | Transient or frequency via prior modal solve |
| POD (thermal) | `R = solve(model, tlist, Snapshots=Tmatrix)` | Tmatrix = Temperature from coarse solve |
| Harmonic EM | `R = solve(model, omega)` | omega in **rad/s** |

**Units convention (critical):** `FrequencyRange`, `flist`, and `omega` are all in **rad/s**, not Hz. Convert: `omega = 2*pi*freqHz`.

```matlab
R = solve(model);                                          % Steady/static
R = solve(model, linspace(0, 2, 100));                     % Transient
R = solve(model, FrequencyRange=[-Inf, 2*pi*500]);         % Modal
R = solve(model, 2*pi*linspace(10, 1000, 200));            % Frequency response
Rm = solve(model, FrequencyRange=[-Inf, 2*pi*500]);        % Modal superposition...
R = solve(model, tlist, ModalResults=Rm, DampingZeta=0.02);
coarseR = solve(model, linspace(0, 40, 10));               % POD thermal...
R = solve(model, linspace(0, 40, 200), Snapshots=coarseR.Temperature);
```

**SolverOptions:** `model.SolverOptions.RelativeTolerance`, `model.SolverOptions.AbsoluteTolerance`.

**Incremental range strategy (modal/decay):** Never guess a large upper bound. Start small, check mode count, widen only if needed. Same for `DecayRange`. See `references/modal-and-reduced-order.md` for full details and modal transient workflow.

## Phase 4: Post-Processing

### Result Objects

| Analysis | Key Properties | Key Methods |
|---|---|---|
| `thermalSteady` | `Temperature` | `evaluateHeatFlux`, `evaluateHeatRate`, `interpolateTemperature` |
| `thermalTransient` | `Temperature` (N×T), `SolutionTimes` | Same + `filterByIndex` |
| `structuralStatic` | `Displacement`, `VonMisesStress`, `Stress`, `Strain` | `evaluatePrincipalStress`, `evaluateReaction`, `interpolateDisplacement` |
| `structuralTransient` | `Displacement` (N×T), `SolutionTimes` | `evaluateVonMisesStress`, `evaluateStress`, `filterByIndex` |
| `structuralFrequency` | `Displacement` (N×F), `SolutionFrequencies` | `evaluateVonMisesStress`, `evaluateStress` (no `filterByIndex`) |
| `structuralModal` | `NaturalFrequencies`, `ModeShapes` | Pass to `solve(..., ModalResults=R)` |
| `electrostatic` | `ElectricPotential`, `ElectricField` | `interpolateElectricPotential`, `interpolateElectricField`, `interpolateElectricFlux` |
| `magnetostatic` | `MagneticFluxDensity`, `MagneticField` | `interpolateMagneticFlux`, `interpolateMagneticField` |
| `conduction` | `ElectricPotential`, `CurrentDensity` | `interpolateCurrentDensity` |

### Critical Rules

1. **`Stress.Magnitude` is EMPTY** — use `result.VonMisesStress` (static) or `evaluateVonMisesStress(result)` (transient)
2. **`evaluateHeatFlux` requires 3 outputs:** `[qx, qy, qz] = evaluateHeatFlux(result)`
3. **Transient stress/strain are methods, not properties:** `evaluateVonMisesStress(result)`, `evaluateStress(result)`
4. **FEStruct field names — ALWAYS use domain-specific names:**

| Analysis | Fields | NEVER |
|----------|--------|-------|
| Displacement | `.ux`, `.uy`, `.uz` | `.x`, `.y`, `.z` |
| Stress | `.sxx`, `.syy`, `.szz`, `.syz`, `.sxz`, `.sxy` | `.xx`, `.yy` |
| Strain | `.exx`, `.eyy`, `.ezz`, `.eyz`, `.exz`, `.exy` | `.xx`, `.yy` |
| Electric field | `.Ex`, `.Ey`, `.Ez` | `.x`, `.y`, `.z` |
| Magnetic flux density | `.Bx`, `.By`, `.Bz` | `.x`, `.y`, `.z` |
| Current density | `.Jx`, `.Jy`, `.Jz` | `.x`, `.y`, `.z` |

### Interpolation

Query points are **3×N matrices** (each column = one point):

```matlab
Tq = interpolateTemperature(result, queryPts);        % Steady: no iT needed
Tq = interpolateTemperature(result, queryPts, iT);    % Transient: iT REQUIRED
d = interpolateDisplacement(result, queryPts);        % Returns all times (no iT accepted)
```

**iT asymmetry:** `interpolateTemperature` (transient) REQUIRES time index iT. `interpolateDisplacement` does NOT accept iT — returns all times. For intermediate times, use `interp1` over `SolutionTimes`.

### filterByIndex — Extract Time Steps

Required for transient visualization (pdeplot3D needs N×1, not N×T):

```matlab
resultF = filterByIndex(result, numel(result.SolutionTimes));
vm = evaluateVonMisesStress(resultF);
pdeplot3D(resultF.Mesh, ColorMapData=vm, Deformation=resultF.Displacement, DeformationScaleFactor=100);
```

**Not available** on `FrequencyStructuralResults` — index columns directly:

```matlab
iFreq = 10;
vm = evaluateVonMisesStress(result);  % N×F
pdeplot3D(result.Mesh, ColorMapData=vm(:,iFreq), ...
    Deformation=struct("ux", result.Displacement.ux(:,iFreq), ...
                       "uy", result.Displacement.uy(:,iFreq), ...
                       "uz", result.Displacement.uz(:,iFreq)), ...
    DeformationScaleFactor=500);
```

### Visualization

```matlab
pdeplot3D(result.Mesh, ColorMapData=result.Temperature, Mesh="on");
colorbar; title("Temperature");
pdeplot3D(result.Mesh, ColorMapData=result.VonMisesStress, ...
    Deformation=result.Displacement, DeformationScaleFactor=100);
[qx, qy, qz] = evaluateHeatFlux(result);
pdeplot3D(result.Mesh, FlowData=[qx qy qz]);
% Partial mesh — hide regions (e.g., air in EM)
elemIDs = findElements(result.Mesh, "region", Cell=[1 3]);
pdeplot3D(result.Mesh.Nodes, result.Mesh.Elements(:,elemIDs), ColorMapData=data);
```

See `references/visualization-reference.md` for pdeplot (2-D), pdeviz, FlowData, cross-sections, streamlines.
See `references/em-postprocessing.md` for EM post-processing (Maxwell stress tensor, energy methods, all interpolation methods).

## Common Mistakes

| Mistake | Correct |
|---------|---------|
| `nearestFace(gm, [0; 0; 1])` (column) | `nearestFace(gm, [0, 0, 1])` — row vector |
| `subtractgeom` / `unite` | `subtract(gm1, gm2)` / `union(gm1, gm2)` |
| `union(gm1, gm2)` for multi-material | `union(gm1, gm2, KeepBoundaries=true)` |
| `HFace=[faceID, size]` | `HFace={faceID, size}` — cell array |
| `rotate(gm, 90, [0 1 0], center)` (dir+pt) | 4-arg takes two POINTS defining axis line: `rotate(gm, 90, [0 0 0], [0 1 0])` |
| `AnalysisType="transientStructural"` | `"structuralTransient"` — physics first |
| `faceBC(ConvectionCoefficient=...)` | `faceLoad(ConvectionCoefficient=..., AmbientTemperature=...)` |
| `vertexLoad(YForce=-1000)` | `vertexLoad(Force=[0; -1000; 0])` — full vector |
| `femodel(..., PlanarType="planeStress")` | Set after: `model.PlanarType = "planeStress"` |
| No `isnan(t)` in conditional load | Add `if isnan(t), F=NaN; return; end` |
| No `VacuumPermittivity` for electrostatic | `model.VacuumPermittivity = 8.854187817e-12` |
| `result.Stress.Magnitude` | `result.VonMisesStress` or `evaluateVonMisesStress(result)` |
| `hf = evaluateHeatFlux(result)` (1 output) | `[qx, qy, qz] = evaluateHeatFlux(result)` |
| `interpolateTemperature(result, pts)` transient | Add iT: `interpolateTemperature(result, pts, iT)` |
| `interpolateDisplacement(result, pts, iT)` | No iT: `interpolateDisplacement(result, pts)` |
| `interpolateMagneticFluxDensity(...)` / `interpolateElectricFluxDensity(...)` / `interpolateCurrentFlux(...)` | `interpolateMagneticFlux` / `interpolateElectricFlux` / `interpolateCurrentDensity` |
| `pdeplot3D(Deformation=...)` on transient | `filterByIndex` first, then plot |
| `filterByIndex(result, iFreq)` on frequency | Index columns directly; build struct for Deformation |
| `materialProperties(Material="steel")` missing | Use catalog name; provides E, ν, ρ, CTE automatically |
| Second `femodel()` for modal after static | `model.AnalysisType = "structuralModal"` on same model |
| No damping in frequency response | `HystereticDamping=0.05` or Rayleigh/Modal damping |
| `RelativePermeability=500` for saturating iron | `@(~,s) muRfcn(s.NormFluxDensity)` — nonlinear |
| No initial guess for nonlinear magnetostatic | `cellIC(MagneticVectorPotential=Rlin)` from linear solve |
| `result.CurrentDensity.x` | `result.CurrentDensity.Jx` — domain-specific names |
| Celsius with radiation (`Emissivity`) | All temps in Kelvin + `model.StefanBoltzmannConstant` |
| Temperature load without `ReferenceTemperature` | `model.ReferenceTemperature = 20` |
| `solve(model, Frequency=1e6)` for harmonic | `solve(model, 1e6)` — positional, not name-value |
| `createpde` for thermal/structural/EM | Use `femodel` — `createpde` is equation-based PDE only |

----
Copyright 2026 The MathWorks, Inc.
----
