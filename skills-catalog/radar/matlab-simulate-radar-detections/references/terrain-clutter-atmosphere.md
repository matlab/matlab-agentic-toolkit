# Terrain, Clutter & Atmosphere

## Terrain and Surface Configuration

All surfaces are created as methods on `radarScenario`, not standalone constructors:

```matlab
srf = landSurface(scenario, Name, Value, ...);
srf = seaSurface(scenario, Name, Value, ...);
srf = customSurface(scenario, Name, Value, ...);
```

### Surface Types

| Method | Purpose | Key Properties |
|--------|---------|----------------|
| `landSurface` | Static terrain: height matrix or DTED file | `Terrain`, `Boundary`, `RadarReflectivity`, `ReferenceHeight`, `ReflectionCoefficient` |
| `seaSurface` | Dynamic ocean surface (spectral models) | `SpectralModel`, `Boundary`, `WindSpeed`, `WindDirection`, `Fetch`, `RadarReflectivity` |
| `customSurface` | Polarization scattering matrices | `Shh`, `Svv`, `Shv`, `Svh`, `Boundary`, `CrossPolarization`, `Frequency` |

### landSurface

```matlab
% Flat-earth with height matrix
srf = landSurface(scene, ...
    'Terrain', heightMatrix, ...       % M×N matrix of heights (meters)
    'Boundary', [-50e3 50e3; -50e3 50e3], ...  % [MinX MaxX; MinY MaxY]
    'RadarReflectivity', surfaceReflectivityLand('Model', 'Barton', 'LandType', 'Flatland'));

% Earth-centered with DTED file
scene = radarScenario('IsEarthCentered', true);
srf = landSurface(scene, ...
    'Terrain', 'dted_file.dt2', ...    % DTED filename
    'Boundary', [40 45; -75 -70]);     % [MinLat MaxLat; MinLon MaxLon]
```

| Property | Purpose | Notes |
|----------|---------|-------|
| `Terrain` | Height data | Numeric matrix (meters) or DTED filename (requires `IsEarthCentered=true`) |
| `Boundary` | Spatial extent | `[MinX MaxX; MinY MaxY]` or `[MinLat MaxLat; MinLon MaxLon]` |
| `RadarReflectivity` | Surface clutter model | `surfaceReflectivityLand` (default) or `surfaceReflectivityCustom` |
| `ReflectionCoefficient` | Multipath coefficient | Scalar or `SurfaceReflectionCoefficient` object |
| `ReferenceHeight` | Height datum offset | Default 0; WGS84-relative when earth-centered |

### seaSurface

```matlab
srf = seaSurface(scene, ...
    'WindSpeed', 15, ...        % m/s at 10m height
    'WindDirection', 45, ...    % degrees (from North when flat-earth, from +x when earth-centered)
    'Boundary', [-20e3 20e3; -20e3 20e3]);
```

| Property | Purpose | Notes |
|----------|---------|-------|
| `SpectralModel` | Sea state spectrum | `seaSpectrum` object for wave dynamics |
| `WindSpeed` | Wind at 10m height (m/s) | Default 10; drives reflectivity and wave model |
| `WindDirection` | Wind direction (deg) | Convention differs by `IsEarthCentered` |
| `Fetch` | Unobstructed wind distance (m) | Default `Inf` |
| `RadarReflectivity` | Sea clutter model | `surfaceReflectivitySea` (default) |

### Surface Reflectivity Models

```matlab
% Land reflectivity
refl = surfaceReflectivityLand('Model', 'Barton', 'LandType', 'Flatland');

% Sea reflectivity  
refl = surfaceReflectivitySea('Model', 'GIT', 'SeaState', 3);
```

**Land models — selection by grazing angle and frequency:**

| Model | Grazing Angle | Frequency | Best For |
|-------|--------------|-----------|----------|
| `"Barton"` (default) | 20–60° | 1–10 GHz | General medium-angle; constant-gamma math model |
| `"APL"` | 0–90° | 1–100 GHz | Low-fidelity, includes specular scattering |
| `"Billingsley"` | -0.75–2° (depression) | VHF–X band | Low depression angle (ground-based surveillance) |
| `"GIT"` | 20–65° | 3–15 GHz | Medium angle, accounts for terrain roughness |
| `"Morchin"` | 70–90° | UHF–C band | High grazing (nadir-looking, airborne) |
| `"Nathanson"` | 0–60° | L–Ka band | Wide frequency range, low-to-medium angle |
| `"UlabyDobson"` | 0–60° | L–Ku band | Polarization-dependent; semi-empirical |
| `"ConstantGamma"` | All | All | User-specified gamma value (default -20 dB) |

**Land types** vary by model: Barton has 11 (RuggedMountains→Smooth), Billingsley has 11 (LowReliefRural→LowReliefUrban), GIT has 5 (Soil/Grass/TallGrass/Trees/Urban), etc. Do not use models outside their valid frequency/angle range.

**Sea models:** NRL, APL, GIT, Hybrid, Masuko, Nathanson, RRE, Sittrop, TSC. All are polarization-dependent and account for radar look angle relative to wind direction.

### Importing Terrain Data (Flat-Earth)

For `IsEarthCentered = false`, terrain data must be supplied as a height matrix in your chosen coordinate convention:

```matlab
% 1. Get elevation data (e.g., WMS, DTED, or other source)
% 2. Convert geodetic to local frame
[east, north, Zenu] = geodetic2enu(latGrid, lonGrid, Z_lla, latRef, lonRef, 0, wgs84Ellipsoid);

% 3. Orient for your convention
if strcmp(coordMode, 'ENU')
    Z_terrain = Zenu;                    % Z positive = up
    boundary = [min(east(:)) max(east(:)); min(north(:)) max(north(:))];
else  % NED
    Z_terrain = -Zenu.';                 % Transpose AND negate (Z positive = down)
    boundary = [min(north(:)) max(north(:)); min(east(:)) max(east(:))];
end

% 4. Create surface
srf = landSurface(scene, 'Terrain', Z_terrain, 'Boundary', boundary);
```

**Key points:**
- `landSurface` is frame-agnostic — you supply data in your convention
- For NED: transpose the matrix (swap E/N axes) AND negate heights (up→down)
- Geoid correction (`egm96geoid`) is good practice when comparing to GPS coordinates
- `Boundary` is `[MinX MaxX; MinY MaxY]` — first row is first spatial dimension of terrain matrix

### Surface Methods

| Method | Purpose | Signature |
|--------|---------|-----------|
| `height(srf, pos)` | Terrain height at point | `pos` = [x,y] or [lat,lon]. Returns height in meters. |
| `occlusion(srf, P1, P2)` | LOS check between two 3D points | Returns `true` if terrain blocks LOS. **Uses z-positive-up convention.** |
| `plotReflectivityMap(srf)` | Visualize reflectivity | Opens figure |

### Terrain Occlusion — Critical Behavior

**`IsEarthCentered = true`:** Terrain occlusion IS applied during `detect()`. Targets behind terrain are not detected.

**`IsEarthCentered = false`:** Terrain occlusion is NOT applied during `detect()`. The `occlusion()` method works but `radarDataGenerator` does not query it for target LOS. All targets in range are detected regardless of intervening terrain.

**This is a major gotcha.** If the user needs terrain masking of targets, they MUST use `IsEarthCentered = true` with `geoTrajectory`.

**`radarDataGenerator.HasOcclusion`** is for target-to-target occlusion (extended objects blocking each other), NOT terrain-to-target occlusion.

**`SurfaceManager.UseOcclusion`** controls whether surfaces participate in occlusion checks. Default is `true`. Access via `scene.SurfaceManager.UseOcclusion`.

### Multipath Ghost Targets (HasGhosts)

`radarDataGenerator.HasGhosts` models ghost returns from multipath propagation paths (up to 3 reflections between Tx and Rx). Requirements:

- `HasGhosts = true` on the radar sensor
- `SurfaceManager.EnableMultipath = true` on the scenario
- A surface (land/sea/custom) with `ReflectionCoefficient` defined
- `DetectionMode = 'Monostatic'` (only mode that supports ghosts)

Ghost detections appear as additional reports with the same `TargetIndex` as the real target but at incorrect (multipath-extended) ranges. Without surfaces configured for multipath, `HasGhosts=true` has no effect.

### SurfaceManager

```matlab
scene.SurfaceManager.UseOcclusion = true;   % default — surfaces can occlude
scene.SurfaceManager.EnableMultipath = true; % enable multipath reflections (default false)
```

## Atmosphere Options

Default propagation is **FreeSpace** (no atmosphere, no refraction).

**Requires `IsEarthCentered = true`.** The `atmosphere()` function errors on flat-earth scenarios: *"The IsEarthCentered property must be true to modify the atmosphere model."* Flat-earth scenarios are always free-space — no refraction modeling is available.

Opt-in (earth-centered only): `atmosphere(scenario, model)`

| Model | Effect | Requires |
|-------|--------|----------|
| `'FreeSpace'` | No refraction (default) | `IsEarthCentered = true` |
| `'EffectiveEarth'` | 4/3 Earth radius approximation | `IsEarthCentered = true` |
| `'RefractivityGradient'` | Gradient-based refraction | `IsEarthCentered = true` |
| `'CRPL'` | CRPL exponential reference atmosphere | `IsEarthCentered = true` |

These model **refraction only**, not weather/precipitation. Rain/fog available only at I/Q level.

**Implication for skill flow:** If the user's scenario requires atmospheric refraction (e.g., long-range surface radar, ducting effects, over-the-horizon), the scenario **must** use `IsEarthCentered = true` with `geoTrajectory`. Flag this requirement in Step 2 when the user mentions atmosphere, propagation, or refraction.

## Clutter Generation (clutterGenerator)

`clutterGenerator` adds surface clutter to a `radarScenario`. Clutter patches are injected into `detect()` alongside real targets — both produce the same detection struct format.

### Setup

```matlab
scene = radarScenario('UpdateRate', 1);
landSurface(scene, 'RadarReflectivity', ...
    surfaceReflectivityLand('Model', 'Barton', 'LandType', 'WoodedHills'));

plat = platform(scene, 'Position', [0 0 -50]);
radar = radarDataGenerator(1, 'ScanMode', 'No scanning', ...
    'FieldOfView', [30 30], 'RangeLimits', [0 10e3], ...
    'CenterFrequency', 10e9, 'ReferenceRange', 5000, 'ReferenceRCS', 1);
plat.Sensors = radar;

cg = clutterGenerator(scene, radar, ...
    'Resolution', 100, ...    % patch spacing (meters) — Uniform mode only
    'RangeLimit', 5000);      % max clutter range (clipped by radar.RangeLimits)
```

### Properties

| Property | Default | Notes |
|----------|---------|-------|
| `ScattererDistribution` | `'Uniform'` | `'RangeDopplerCells'` requires `radarTransceiver` (errors with radarDataGenerator) |
| `Resolution` | 40 | Patch spacing in meters. **Irrelevant** in `'RangeDopplerCells'` mode (warning issued) |
| `RangeLimit` | 10e3 | Max range for patch generation. Radar `RangeLimits` still clips detections |
| `UseBeam` | `true` | If `false`, no clutter generated unless explicit `ringClutterRegion` defined |
| `UseShadowing` | `true` | Surface self-occlusion (requires terrain with elevation data) |
| `SeedSource` | `'Auto'` | Set to `'Property'` + `Seed` for reproducible patch layout |
| `Radar` | — | The radar sensor (read-only after creation) |
| `Regions` | empty | Populated by `ringClutterRegion` calls |

### Critical Behaviors

**1:1 mapping to radar sensor.** Each `clutterGenerator` serves exactly one radar. Multiple radars need separate clutter generators:

```matlab
cg1 = clutterGenerator(scene, radar1, 'Resolution', 100, 'RangeLimit', 5000);
cg2 = clutterGenerator(scene, radar2, 'Resolution', 100, 'RangeLimit', 5000);
```

**Requires a surface.** Without `landSurface`, `seaSurface`, or `customSurface`, clutter generator produces 0 detections (no error, no warning).

**Radar RangeLimits clips clutter.** Even if `cg.RangeLimit = 10000`, detections beyond `radar.RangeLimits(2)` are suppressed.

**No built-in target/clutter distinction.** Both produce `ObjectClassID = 0`. Clutter patches get `TargetIndex` values above the number of explicit platforms. To distinguish: clutter indices start at `numPlatforms + 1`.

**UseBeam=false requires explicit regions.** Setting `UseBeam=false` disables automatic beam-footprint clutter — you must define where clutter goes with `ringClutterRegion`:

```matlab
cg = clutterGenerator(scene, radar, 'UseBeam', false, 'RangeLimit', 5000);
ringClutterRegion(cg, 100, 5000, 360, 0);  % full 360-degree ring
```

**Multiple surfaces with clutter: unsupported.** Combining `landSurface` + `seaSurface` in the same scenario with `clutterGenerator` causes internal errors in R2026a. Use a single surface type per scenario when clutter is needed.

### ringClutterRegion

Defines explicit clutter regions (required when `UseBeam=false`, optional otherwise):

```matlab
region = ringClutterRegion(cg, minRadius, maxRadius, azimuthSpan, azimuthCenter);
```

| Parameter | Units | Description |
|-----------|-------|-------------|
| `minRadius` | meters | Inner ring boundary |
| `maxRadius` | meters | Outer ring boundary |
| `azimuthSpan` | degrees | Angular width of region |
| `azimuthCenter` | degrees | Center azimuth of region |

Multiple regions can be added to one clutter generator:

```matlab
ringClutterRegion(cg, 100, 2000, 90, 0);    % close-in, 90-deg sector North
ringClutterRegion(cg, 2000, 5000, 45, 90);  % far, 45-deg sector East
```

### Surface Reflectivity Coupling

The surface's `RadarReflectivity` model directly controls clutter SNR:

| Configuration | Effect |
|---------------|--------|
| `landSurface(scene)` (default) | Uses default `surfaceReflectivityLand` |
| `landSurface(scene, 'RadarReflectivity', surfaceReflectivityLand('Model','Barton','LandType','WoodedHills'))` | Higher sigma-zero → stronger clutter |
| `landSurface(scene, 'RadarReflectivity', surfaceReflectivityLand('Model','ConstantGamma','Gamma',-20))` | Fixed -20 dB sigma-zero → weaker clutter |
| `seaSurface(scene)` | Uses default `surfaceReflectivitySea` |

### customSurface with Clutter

`customSurface` provides full polarization scattering matrix control. Key constraint: set `clutterGenerator.Resolution` to match the custom surface patch resolution to prevent resampling:

```matlab
boundary = [-5000 5000; -5000 5000];  % 10km x 10km
numPatches = 100;  % 100x100 grid
res = 10000/numPatches;  % 100m resolution

cs = customSurface(scene, 'Boundary', boundary, ...
    'Shh', ones(numPatches, numPatches, 2), ...
    'Svv', ones(numPatches, numPatches, 2));
cg = clutterGenerator(scene, radar, 'Resolution', res, 'RangeLimit', 5000);
```

### Retrieving a Clutter Generator

```matlab
cg = getClutterGenerator(scene, radar);  % retrieve existing cg for a specific radar
```

### Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| No surface added | 0 clutter detections, no error | Add `landSurface(scene)` or `seaSurface(scene)` |
| `UseBeam=false` without regions | 0 clutter detections | Add `ringClutterRegion(cg, ...)` |
| `ScattererDistribution='RangeDopplerCells'` with radarDataGenerator | Error at `detect()` | Use `'Uniform'` (default) or switch to `radarTransceiver` |
| `Resolution` set in RangeDopplerCells mode | Warning: "not relevant" | Remove `Resolution` or switch to Uniform |
| `cg.RangeLimit` > `radar.RangeLimits(2)` | Wasted computation, no extra detections | Set `cg.RangeLimit` ≤ `radar.RangeLimits(2)` |
| Multiple surface types + clutter | Internal error in `detect()` | Use one surface type per scenario |
| Expecting ObjectClassID to distinguish clutter | Both are 0 | Use TargetIndex > numPlatforms to identify clutter |

----

Copyright 2026 The MathWorks, Inc.

----
