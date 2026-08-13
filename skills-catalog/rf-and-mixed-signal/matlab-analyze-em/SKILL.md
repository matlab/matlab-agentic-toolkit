---
name: matlab-analyze-em
description: "S-parameters, insertion loss, fields, currents, mesh control, and solver selection for RF PCB performance validation. TRIGGER: user asks to compute S-parameters, analyze insertion/return loss, extract fields or currents, compare MoM vs FEM, or control mesh for any RF PCB component. Invoke BEFORE writing sparameters() or solver code — API is non-obvious. SKIP: designing or creating components (use the specific matlab-design-pcb-* skill), material/stackup setup only (use matlab-manage-pcb-material), optimization sweeps (use matlab-optimize-pcb-design), PDN/IR-drop analysis (use matlab-analyze-pcb-pdn)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Analyzing EM Performance of RF PCB Components

## When to Use

- Extracting S-parameters from any RF PCB component (catalog or custom pcbComponent)
- Comparing MoM vs FEM solvers or selecting the right solver for a structure
- Using interpolating sweeps or frequencySweep objects for faster multi-frequency analysis
- Controlling mesh density for accuracy vs speed tradeoffs
- Visualizing E/H fields, surface currents, or charge distributions
- Using behavioral (analytic) S-parameter models for fast estimates or optimization

## When NOT to Use

- Building or assembling custom PCB structures — use `matlab-assemble-pcb-layout`
- Designing standard transmission lines or catalog objects — use `matlab-design-pcb-transmission-line`
- Defining dielectric or metal materials — use `matlab-manage-pcb-material`
- Cascading or connecting multiple components into circuits — use `matlab-integrate-pcb-circuit`
- Importing PCB layouts from Gerber, ODB++, or Allegro — use `matlab-read-pcb-layout`

## Typical Workflow

1. **Before:** `matlab-manage-pcb-material` — substrate/conductor setup; then a design skill or `matlab-assemble-pcb-layout` — create the component
2. **This skill:** Extract S-parameters, visualize fields and currents, verify performance
3. **After:** `matlab-optimize-pcb-design` — tune dimensions if specs not met → `matlab-integrate-pcb-circuit` — cascade into larger network → `matlab-write-pcb-layout` — export Gerber

## Quick Reference

| Task | Code |
|------|------|
| S-parameters (MoM) | `sp = sparameters(obj, freq, 'SweepOption', 'interp')` |
| S-params with port Z0 | `sp = sparameters(obj, freq, 50, 'SweepOption', 'interp')` |
| Interpolating sweep | `sp = sparameters(obj, freq, 50, 'SweepOption', 'interp')` |
| Interp with gradient | `sp = sparameters(obj, freq, 50, 'SweepOption', 'interpWithGrad')` |
| Plot S-params | `rfplot(sp)` or `rfplot(sp, [2 1], 1)` |
| Current distribution | `current(obj, fc)` |
| Charge distribution | `charge(obj, fc)` |
| Feed current | `feedCurrent(obj, freq)` |
| E/H fields | `[e, h] = EHfields(obj, fc, points)` |
| Set mesh | `mesh(obj, 'MaxEdgeLength', val)` |
| Memory estimate | `memoryEstimate(obj, fc)` |
| Switch to FEM solver | `pcb.SolverType = 'FEM'` |
| FEM boundary condition | `s = solver(pcb); s.BoundaryCondition = 'absorbing'` |
| Frequency sweep object | `fsweep = frequencySweep; sp = sparameters(obj, freq, 'SweepOption', fsweep)` |
| Rational model from sweep | `rmodel = getRationalModel(fsweep)` |
| Discover methods | `methods(obj)` |

## S-Parameter Extraction

The `sparameters` function is the primary analysis method for all RF PCB components.

### Basic Usage

```matlab
obj = design(couplerBranchline, 5e9);
freq = linspace(1e9, 10e9, 101);
sp = sparameters(obj, freq, 'SweepOption', 'interp');
figure;
rfplot(sp);
```

### Specifying Port Impedance

```matlab
sp = sparameters(obj, freq, 50, 'SweepOption', 'interp');   % 50-ohm reference
sp = sparameters(obj, freq, 75, 'SweepOption', 'interp');   % 75-ohm reference
```

### Plotting Specific S-Parameters

```matlab
rfplot(sp, [2 1], 1);              % Plot S21 only
rfplot(sp, [1 1], 1);              % Plot S11 only
rfplot(sp, 2:4, 1);               % Plot S21, S31, S41 vs port 1
```

### Extracting Numeric Data

```matlab
sp = sparameters(obj, freq, 'SweepOption', 'interp');
S21_dB = 20*log10(abs(squeeze(sp.Parameters(2,1,:))));
S11_dB = 20*log10(abs(squeeze(sp.Parameters(1,1,:))));
```

## Solver Selection

RF PCB Toolbox supports two electromagnetic solvers:

| Solver | Property Value | Best For |
|--------|---------------|----------|
| Method of Moments (MoM) | `'MoM'` (default) | Planar structures, open radiators |
| Finite Element Method (FEM) | `'FEM'` | Shielded catalog elements; also available on pcbComponent via SolverType |

### Switching to FEM

FEM is available via `pcbComponent`:

```matlab
pcb = pcbComponent(couplerBranchline);
pcb.SolverType = 'FEM';
sp_fem = sparameters(pcb, freq);
```

### FEM Boundary Condition Configuration

After setting `SolverType` to `'FEM'`, retrieve the solver object via `solver()` to configure boundary conditions:

```matlab
pcb = pcbComponent(catalogObj);
pcb.SolverType = 'FEM';

s = solver(pcb);                          % Returns em.solvers.fem.FEM object
s.BoundaryCondition = 'absorbing';        % or 'perfectly-matched-layer' (default)
```

| Boundary Condition | Value | Use Case |
|--------------------|-------|----------|
| Perfectly Matched Layer (PML) | `'perfectly-matched-layer'` (default) | Open radiating structures, antennas |
| Absorbing | `'absorbing'` | Shielded enclosures, waveguide ports |

**Gotcha:** `solver(comp, 'SolverType', 'FEM')` errors with "Too many input arguments." `SolverType` is a property of `pcbComponent`, not an argument to `solver()`. `BoundaryCondition` is a property of the returned FEM solver object, not of the component.

### FEM Prerequisites

The FEM solver (introduced R2025a) requires two dependencies:

1. **Integro-Differential Modeling Framework for MATLAB (IDMF)** — Install via Home > Add-Ons > search "Integro-Differential Modeling Framework for MATLAB". Verify with `matlab.addons.installedAddons`.
2. **Windows Subsystem for Linux (WSL)** — Required on Windows. Install via `wsl --install` from an elevated PowerShell prompt. Verify with `wsl --status`.

If WSL is available, the FEM solver can be used when designing custom structures via pcbComponent. For shielded catalog elements, FEM is used automatically.

**Firewall note:** Windows Defender may block the PostgreSQL server used by IDMF (`<matlabroot>\sys\postgresql\win64\PostgreSQL\bin\postgres.exe`). If FEM solves hang on first use, inform the user of this potential cause and defer to them on what action to take per their IT/security policies. Do not modify firewall settings autonomously.

### WSL Memory Tuning

WSL is allocated only **50% of system RAM** by default. Large FEM problems may fail with out-of-memory errors. If the user hits OOM during an FEM solve, inform them that WSL memory can be increased by editing `C:/Users/%UserProfile%/.wslconfig`:

```ini
[wsl2]
memory=48GB
swap=8GB
```

Followed by `wsl --shutdown` and `restart-service LxssManager` (elevated PowerShell). Values should be adjusted based on system specs. This may require IT involvement — ask the user to make this change manually and resume when ready. Do not create or modify `.wslconfig` autonomously.

### FEM-Only Properties

When `SolverType='FEM'`, additional properties become available on `pcbComponent`:

| Property | Purpose |
|----------|---------|
| `Connector` | Attach an `RFConnector` object for coaxial feed modeling (default: 50-ohm, InnerRadius=0.5mm, OuterRadius=1.5mm) |
| `IsShielded` | Add metal shielding box around the structure (dimensions match ground plane) |

### FEM Constraints

- **No mode impedance extraction**: `getZEven`/`getZOdd` are not available with the FEM solver. Use S-parameters only for shielded comparisons.
- **PEC required**: FEM requires `Conductivity=Inf` (PEC). Finite conductivity metals (e.g., Copper) will error. For shielded vs unshielded comparisons, use PEC for both.
- **Connector spacing**: The `RFConnector` outer radius (default 1.5 mm) must fit between adjacent ports. If port spacing is tight, increase `Spacing`/`GroundPlaneWidth` or reduce `OuterRadius` on the connector.

### Comparing Solvers

```matlab
obj = design(couplerBranchline, 5e9);
freq = linspace(1e9, 5e9, 21);

sp_mom = sparameters(obj, freq, 'SweepOption', 'interp');

pcb = pcbComponent(obj);
pcb.SolverType = 'FEM';
sp_fem = sparameters(pcb, freq);  % FEM: interp not applicable

figure;
rfplot(sp_mom); hold on;
rfplot(sp_fem, '--');
legend('MoM', 'FEM');
```

## Interpolating Sweep

For faster multi-frequency analysis, use interpolating sweep instead of discrete point-by-point solves. This is significantly faster, especially for large structures.

### Basic Interpolation

```matlab
freq = linspace(4.5e9, 5.5e9, 101);
sp = sparameters(obj, freq, 50, 'SweepOption', 'interp');
```

### Interpolation with Gradient

More accurate interpolation using gradient information:

```matlab
freq = [4.5e9, 5.5e9];  % Only need start/end — solver picks internal points
sp = sparameters(obj, freq, 50, 'SweepOption', 'interpWithGrad');
```

### When to Use Interpolation

| Scenario | Recommendation |
|----------|---------------|
| Narrowband (< 2:1 BW) | `'interpWithGrad'` — fastest, accurate |
| Wideband (> 2:1 BW) | `'interp'` — stable over wide range |
| Debugging / single freq | No sweep option (discrete) |
| Resonant structures | Discrete or fine `'interp'` grid |

### frequencySweep Object (R2025a)

For finer control over interpolation-based sweeps, use the `frequencySweep` object. It exposes error tolerance, iteration limits, and rational fitting — useful when the default `'SweepOption'` settings are not sufficient.

```matlab
fsweep = frequencySweep;
fsweep.SweepType = "interp";        % "interp" (default) | "interpWithGrad"
fsweep.ErrTol = -80;                % dB, default -80
fsweep.NumFreqs = 100;              % points to discretize frequency range, default 100
fsweep.NumIters = 25;               % max fitting iterations, default 25

freq = linspace(1e9, 10e9, 200);
sp = sparameters(comp, freq, 'SweepOption', fsweep);

% Extract rational fitting model after the sweep
rmodel = getRationalModel(fsweep);
```

| Property | Default | Description |
|----------|---------|-------------|
| `SweepType` | `"interp"` | Interpolation type; `"interpWithGrad"` uses gradient info |
| `ErrTol` | `-80` dB | Max error tolerance between fitting iterations |
| `NumFreqs` | `100` | Number of points to discretize frequency range |
| `NumIters` | `25` | Maximum number of fitting iterations |

## Mesh Control

Mesh density directly affects accuracy and computation time.

### Setting Maximum Edge Length

Rule of thumb: `MaxEdgeLength` ≤ λ/8 at the highest frequency.

```matlab
fc = 10e9;
lambda = 3e8 / fc;
mesh(obj, 'MaxEdgeLength', lambda/8);
```

### Viewing the Mesh

```matlab
figure;
mesh(obj);                              % Visualize default mesh
figure;
mesh(obj, 'MaxEdgeLength', 1e-3);       % Visualize refined mesh
```

### Mesh Configuration

Switch between automatic and manual meshing:

```matlab
meshconfig(obj, 'manual');
mesh(obj, 'MaxEdgeLength', 0.5e-3, 'MinEdgeLength', 0.1e-3);

meshconfig(obj, 'auto');   % Revert to automatic meshing
```

### Pre-Solve Checkpoint: Inspect Mesh and Memory

Catalog components generate dense auto-meshes that can dominate runtime even with interpolating sweep. Always inspect before committing to a full solve:

```matlab
fc = 10e9;
memoryEstimate(obj, fc, 'RetainMesh', true);  % Estimate RAM; retain mesh for inspection
mesh(obj);                                     % Visualize — check if overly dense

% If too dense or memory too high, coarsen
lambda = physconst('LightSpeed') / fc;
mesh(obj, 'MaxEdgeLength', lambda/6);          % Relax from default
memoryEstimate(obj, fc, 'RetainMesh', true);   % Re-check after coarsening
```

The `'RetainMesh', true` option keeps the generated mesh attached to the object so you can visualize it immediately. Without it, the mesh is discarded after estimation.

## Field Visualization

### EHfields — Electric and Magnetic Fields

#### At a Single Point

```matlab
ind = spiralInductor;
[e, h] = EHfields(ind, 4e9, [0; 0; 1]);  % Point at (0,0,1) meters
```

#### Near-Field on a Planar Grid

```matlab
fc = 5e9;
Nx = 80; Ny = 60;
xVec = linspace(-0.02, 0.02, Nx);
yVec = linspace(-0.015, 0.015, Ny);
[Xg, Yg] = meshgrid(xVec, yVec);
Zg = 2e-3 * ones(size(Xg));  % Observation plane at z = 2 mm
points = [Xg(:)'; Yg(:)'; Zg(:)'];

[eNear, hNear] = EHfields(obj, fc, points);
eMag2D = reshape(vecnorm(eNear), Ny, Nx);

figure;
imagesc(xVec*1e3, yVec*1e3, 20*log10(eMag2D));
xlabel('x (mm)'); ylabel('y (mm)');
title(sprintf('|E| at z=2mm, f=%.1f GHz', fc/1e9));
colorbar; axis equal tight;
```

#### Observation Plane Selection

| Structure Type | Recommended Slice | Rationale |
|---|---|---|
| Horizontal traces (microstrip, stub) | X-Y at z = h (signal layer) | Fields strongest at trace plane |
| Vertical structures (vias) | X-Z at y = 0 | See vertical field transition |
| T-junctions / stubs | X-Y biased toward stub | Capture fringing at open end |

### Far-Field (Default Sphere)

```matlab
EHfields(obj, fc, ViewField="E");   % Plot only, no output
```

## Current and Charge Distribution

### Surface Current

```matlab
figure;
current(obj, 5e9);                  % Linear scale
figure;
current(obj, 5e9, scale="log");     % Log scale for dynamic range
```

### Charge Distribution

```matlab
figure;
charge(obj, 5e9);                   % On metal surface
figure;
charge(obj, 5e9, 'dielectric');     % On dielectric surface
```

### Feed Current vs. Frequency

```matlab
freq = linspace(1e9, 10e9, 101);
feedCurrent(obj, freq);             % Plots feed current magnitude
```

## Transmission Line RLGC and Impedance

For pcb2D cross-section analysis, RLGC extraction, characteristic impedance (`getZ0`), and propagation delay, see `matlab-design-pcb-transmission-line`.

## Behavioral S-Parameters (Fast Analytic Models)

Behavioral models compute S-parameters using closed-form analytic approximations instead of full-wave EM. They are orders of magnitude faster — useful for initial exploration, circuit-level simulation, and optimization inner loops.

### Syntax

```matlab
S = sparameters(obj, freq, Behavioral=true);       % Named argument
S = sparameters(obj, freq, 'Behavioral', true);     % Name-value pair
```

### Supported Objects

Behavioral mode works on:

| Category | Objects |
|----------|---------|
| **Catalog components** | `coplanarWaveguide`, `microstripLine`, `stripLine`, `spiralInductor`, `interdigitalCapacitor`, and most catalog objects |
| **pcbComponent wrappers** | Any `pcbComponent` containing microstrip bend, cross, tee, or other discontinuity shapes |

### Common Patterns

**Transmission line discontinuities** — wrap a shape in `pcbComponent`, then compare behavioral vs full-wave:

```matlab
m = microstripLine(Length=0.04, Width=2.7e-3, Height=1.6e-3);
shape = bendMitered(Length=[m.Length/2, m.Length/2], ...
    Width=[m.Width, m.Width], MiterDiagonal=sqrt(2)*m.Width);
pcb = pcbComponent(shape);
pcb.BoardThickness = m.Substrate.Thickness;
pcb.Layers{2} = m.Substrate;

freq = (1:40)*100e6;
S_fast = sparameters(pcb, freq, Behavioral=true);     % ~instant
S_em   = sparameters(pcb, freq, 'SweepOption', 'interp');  % Full MoM solve
```

**Direct on catalog objects:**

```matlab
cpw = design(coplanarWaveguide, 3e9, LineLength=0.5, Z0=75);
cpw.Conductor = metal("Gold");
S = sparameters(cpw, 3e9, Behavioral=true);
```

### When to Use Behavioral vs Full-Wave

| Scenario | Recommendation |
|----------|---------------|
| Quick impedance/loss estimate | Behavioral |
| Optimization inner loop | Behavioral |
| Circuit-level cascading via `pcbElement` | Behavioral (set `Behavioral=true` in `pcbElement`) |
| Final design validation | Full-wave (default) |
| Complex multi-layer structures | Full-wave |
| Near field/current/charge visualization | Full-wave only |

### Accuracy Limitations

Behavioral models assume ideal microstrip/stripline geometry and may diverge from full-wave at:
- High frequencies (above first higher-order mode)
- Very wide or narrow traces (outside quasi-TEM regime)
- Complex multi-layer substrates
- Structures with significant radiation or surface wave coupling

## Pitfalls

1. **Ask for frequency range first**: Do not assume the analysis frequency range. Always ask the user what frequency band they want before running `sparameters`. Wrong assumptions waste solve time and may miss the structure's operating band.

2. **Memory exhaustion from dense auto-meshes**: Catalog components often generate overly dense meshes. Always run `memoryEstimate(obj, fc, 'RetainMesh', true)` before committing to a full-band sweep, then `mesh(obj)` to visualize. If the mesh is too fine or memory too high, coarsen with `mesh(obj, 'MaxEdgeLength', lambda/6)` before solving. This applies even when using interpolating sweep — the mesh drives per-frequency cost.

2. **FEM only works via pcbComponent and requires WSL on Windows**: The `SolverType` property exists on both catalog objects and `pcbComponent`, but setting it to `'FEM'` on a catalog object errors (e.g., "FEM solver for couplerBranchline is not supported"). Convert catalog objects first: `pcb = pcbComponent(catalogObj); pcb.SolverType = 'FEM';`. Additionally, FEM requires Windows Subsystem for Linux (WSL) — if WSL is not installed, the solve will fail. Use MoM (default) when WSL is unavailable.

3. **Feed errors**: If `sparameters` fails with a feed-related error, verify that `FeedLocations` coordinates fall within the metal trace and that `FeedDiameter` fits inside the trace width. Inset feed at least `FeedDiameter/2` from any trace edge.

4. **Interpolating sweep frequency range**: For `'interpWithGrad'`, you can specify just `[fmin, fmax]` — the solver picks internal sample points. For `'interp'`, provide a full frequency vector; the solver interpolates between computed points.

5. **Close figures between large solves**: EHfields with many figures or large grids can consume session memory. Use `close all` between analysis sections when running interactively.

6. **Behavioral models don't support field/current/charge.** `current()`, `charge()`, and `EHfields()` always use the full-wave solver regardless of the `Behavioral` flag. Only `sparameters()` honors it.

7. **`solver()` takes no name-value arguments**: Do not pass `solver(comp, 'SolverType', 'FEM')` — it errors with "Too many input arguments." Set `comp.SolverType = 'FEM'` first, then call `s = solver(comp)` to get the FEM solver object. Boundary conditions are configured on that solver object (`s.BoundaryCondition`), not on the component.

8. **EHfields points must be 3×N, not N×3**: The `points` argument to `EHfields(obj, fc, points)` must be a 3-row matrix where each column is `[x; y; z]`. Do NOT pass N×3. Build with: `points = [Xg(:)'; Yg(:)'; Zg(:)']`.

## Related Skills

- `matlab-manage-pcb-material` — Material properties affect solver accuracy and loss modeling
- `matlab-assemble-pcb-layout` — Building custom structures to analyze
- `matlab-design-pcb-transmission-line` — Transmission line parameter extraction, pcb2D, RLGC, crosstalk
- `matlab-design-pcb-passive` — Behavioral S-parameters for inductors/capacitors

----

Copyright 2026 The MathWorks, Inc.
