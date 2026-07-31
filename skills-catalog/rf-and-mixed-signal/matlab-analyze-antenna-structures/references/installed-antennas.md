# Installed Antenna Analysis

## Platform Creation

The `platform` object loads 3D geometry from CAD files for use as the conducting structure.

### Supported File Formats

| Format | Extensions | Units |
|--------|-----------|-------|
| STL | `.stl` | User-configurable via `Units` (default: `"mm"`) |
| STEP | `.step`, `.stp` | Read-only (embedded in file) |
| IGES | `.igs`, `.iges` | Read-only (embedded in file) |

### Platform Units

**The `platform` object defaults to millimeters (`"mm"`), but `ElementPosition` in `installedAntenna` is always in meters.** Always set `Units` explicitly:

```matlab
plat = platform(FileName="vehicle.stl", Units="m");

% Built-in plate geometry
plat = platform(FileName="plate.stl", Units="m");
```

**`platform` requires a `FileName`** -- calling `platform()` with no file produces an error.

### Generating Platform STL Programmatically

When no CAD file exists, generate geometry using `triangulation` + `stlwrite`:

```matlab
% Open-ended metal tube
radius = 0.05; height = 0.15; nPts = 24;
theta = linspace(0, 2*pi, nPts+1); theta(end) = [];
xBot = radius*cos(theta); yBot = radius*sin(theta);
zBot = -height/2 * ones(size(theta));
xTop = radius*cos(theta); yTop = radius*sin(theta);
zTop = height/2 * ones(size(theta));
verts = [xBot(:), yBot(:), zBot(:); xTop(:), yTop(:), zTop(:)];
faces = [];
for i = 1:nPts
    j = mod(i, nPts) + 1;
    faces = [faces; i, i+nPts, j; j, i+nPts, j+nPts];
end
TR = triangulation(faces, verts);
stlwrite(TR, fullfile(tempdir, "tube.stl"));
plat = platform(FileName=fullfile(tempdir, "tube.stl"), Units="m");
```

### Flat Rectangular Plate

```matlab
Lx = 0.5; Ly = 0.3;
verts = [-Lx/2, -Ly/2, 0; Lx/2, -Ly/2, 0; Lx/2, Ly/2, 0; -Lx/2, Ly/2, 0];
faces = [1 2 3; 1 3 4];
TR = triangulation(faces, verts);
stlwrite(TR, fullfile(tempdir, "plate.stl"));
plat = platform(FileName=fullfile(tempdir, "plate.stl"), Units="m");
```

### Box (Closed Enclosure)

```matlab
Lx = 0.3; Ly = 0.2; Lz = 0.1;
x = Lx/2; y = Ly/2; z = Lz/2;
verts = [-x,-y,-z; x,-y,-z; x,y,-z; -x,y,-z; -x,-y,z; x,-y,z; x,y,z; -x,y,z];
faces = [1 3 2; 1 4 3; 5 6 7; 5 7 8; 1 2 6; 1 6 5; 2 3 7; 2 7 6; 3 4 8; 3 8 7; 4 1 5; 4 5 8];
TR = triangulation(faces, verts);
stlwrite(TR, fullfile(tempdir, "box.stl"));
plat = platform(FileName=fullfile(tempdir, "box.stl"), Units="m");
```

### Tips for Clean STL Meshes

- Avoid duplicate vertices at seams -- use `theta(end) = []`
- Open structures work reliably with FMM/EFIE
- Closed bodies require watertight mesh for CFIE/MFIE
- Use `stlFileChecker` if `platform` reports "Bad features in STL file"
- Keep triangle count reasonable (`nPts=24` for cylinders is sufficient)

### UseFileAsMesh

Skip remeshing when the STL comes from a dedicated mesh generator:

```matlab
plat = platform(FileName="premeshed_body.stl", Units="m");
plat.UseFileAsMesh = true;
```

## Element Installation

### installedAntenna Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Platform` | `platform` object | rectangular plate | Conducting structure |
| `Element` | antenna, array, or cell array | `dipole` | Antenna element(s) |
| `ElementPosition` | N-by-3 matrix (meters) | `[0 0 0.075]` | [x, y, z] per element |
| `Reference` | `"feed"` or `"origin"` | `"feed"` | Position reference point |
| `FeedVoltage` | scalar or vector (V) | 1 | Excitation amplitude |
| `FeedPhase` | scalar or vector (deg) | 0 | Excitation phase |
| `Tilt` | scalar or vector (deg) | 0 | Element rotation angle |
| `TiltAxis` | vector, matrix, or string | `[1 0 0]` | Rotation axis |
| `SolverType` | string | `"MoM-PO"` | `"MoM-PO"`, `"MoM"`, or `"FMM"` |

### Substrate Limitation

**`installedAntenna` only supports pure metal antennas.** Dielectric substrates are not supported. Use metal-only types: dipole, monopole, dipoleFolded, invertedF, horn, hornConical, spiralArchimedean, helix, slot, vivaldi, loopCircular, bicone, discone, monocone, waveguide, and arrays of these.

### Alternative for Substrate Elements: conformalArray

When any element has a dielectric substrate, use `shape.Custom3D(Vertices=...)` for platform/chassis elements — `shape.Rectangle` and other 2D parametric shapes lack the `AnalysisFrequencies` property that `conformalArray` requires internally.

```matlab
freq = 2.4e9;
ant = design(patchMicrostrip, freq);

% Chassis must be Custom3D when any element has dielectric
Lx = 0.14; Ly = 0.07;
verts = [-Lx/2, -Ly/2, 0; Lx/2, -Ly/2, 0; Lx/2, Ly/2, 0; -Lx/2, Ly/2, 0];
chassis = customAntenna(Shape=shape.Custom3D(Vertices=verts));
createFeed(chassis, [0 0 0], 1);

arr = conformalArray;
arr.ElementPosition = [0 0 0.008; 0 0 0];
arr.Element = {ant, chassis};
arr.Reference = "origin";
figure; show(arr);
figure; pattern(arr, freq);
```

### Single Element

```matlab
freq = 1e9;
plat = platform(FileName=fullfile(tempdir, "plate.stl"), Units="m");  % requires plate generated above
ant = installedAntenna;
ant.Platform = plat;
ant.Element = design(dipole, freq);
ant.ElementPosition = [0 0 0.1];
```

### Multiple Elements

**Set `ElementPosition` before `Element`:**

```matlab
ant = installedAntenna;
ant.Platform = plat;
ant.ElementPosition = [0.1 0 0.5; -0.1 0 0.5];
ant.Element = {design(dipole, freq), design(monocone, freq)};
ant.FeedVoltage = [1 2];
ant.FeedPhase = [0 45];
```

## FMM Configuration

**FMM requires homogeneous element types in multi-port configurations.** Use MoM-PO for installations with mixed antenna types (e.g., dipole + monocone).

```matlab
ant.SolverType = "FMM";
s = solver(ant);
s.Iterations = 200;
s.RelativeResidual = 1e-4;
s.Precision = 2e-4;
```

### Convergence Verification

```matlab
Z = impedance(ant, freq);
s = solver(ant);
figure; convergence(s);
```

If not converged: increase `Iterations` or refine mesh.

### FMM Formulations

| Formulation | Geometry | Notes |
|-------------|----------|-------|
| EFIE | Open or closed | Default. Works on all geometries. Only user-settable formulation. |

**Note:** CFIE exists as an internal class but is not user-assignable — `SolverType` only accepts `"MoM"`, `"MoM-PO"`, `"FMM"`, `"PO"`. MFIE does not exist in R2026a.

## Multi-Antenna Pattern Visualization

**Requires `installedAntenna` with 2+ elements.** For single-element, use `pattern` instead.

```matlab
figure;
patternSystem(ant, [1e9, 2e9]);
figure;
patternSystem(ant, [1e9, 2e9], ElementNumber=[1, 2]);
opts = PatternPlotOptions(Transparency=0.6, MagnitudeScale=[1 10]);
figure;
patternSystem(ant, [1e9, 2e9], PatternOptions=opts);
```

## Infinite Ground Plane (Image Theory)

```matlab
% Monopole with infinite ground
m = monopole;
m.GroundPlaneLength = inf;
m.GroundPlaneWidth = inf;
m = design(m, freq);

% Balanced antenna with infinite ground
r = reflector;
r.Exciter = dipole;
r.GroundPlaneLength = inf;
r.GroundPlaneWidth = inf;
r = design(r, freq);
```

## Analysis Functions

All standard functions work on `installedAntenna`: `pattern`, `patternAzimuth`, `patternElevation`, `impedance`, `sparameters`, `current`, `charge`, `efficiency`, `EHfields`, `beamwidth`.

Note: `EHfields` expects a 3-by-M matrix (columns are points), not M-by-3.

### S-Parameter Plotting

```matlab
freqRange = linspace(1.9e9, 2.1e9, 21);
S = sparameters(ant, freqRange);

% Plot all S-parameters (default)
figure; rfplot(S);

% Plot specific S-parameter: rfplot(S, row, col)
figure; rfplot(S, 2, 1);   % plots S21 — NOTE: rfplot(S, [2 1]) does NOT work

% Manual extraction (alternative)
figure;
plot(S.Frequencies/1e9, 20*log10(abs(squeeze(S.Parameters(2,1,:)))), LineWidth=1.5);
xlabel("Frequency (GHz)"); ylabel("|S_{21}| (dB)");
title("Isolation"); grid on;
```

----

Copyright 2026 The MathWorks, Inc.
