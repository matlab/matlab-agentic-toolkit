# scenariobuilder.Trajectory — Detailed API

Creates a trajectory using timestamps and waypoints.
**Requires:** Scenario Builder for Automated Driving Toolbox support package.

## Constructor Syntax

```matlab
trajectory = scenariobuilder.Trajectory(timestamps, x, y, z)
trajectory = scenariobuilder.Trajectory(timestamps, waypoints)
trajectory = scenariobuilder.Trajectory(___, Name=Value)
```

## Input Arguments

| Argument | Description | Data Types |
|----------|-------------|------------|
| `timestamps` | Timestamps of waypoint data. If numeric, units are seconds. | `double`, `datetime`, `duration` — N-element vector |
| `x`, `y`, `z` | Coordinates in ENU world frame. Units: meters. | `single`, `double` — N-element vectors |
| `waypoints` | N-by-3 matrix `[x, y, z]`. Units: meters. | `single`, `double` |

## Name-Value Arguments (Constructor)

| Argument | Description | Default |
|----------|-------------|---------|
| `Name` | Name of the trajectory object. | `''` |
| `Orientation` | N-by-3 matrix of **`[Yaw, Pitch, Roll]`** at each waypoint. Units: **radians** (intrinsic ZYX Euler). **NOT [Roll, Pitch, Yaw].** Only pass for ego (fused CAN heading); actors auto-derive from waypoints. | Computed from `Position` |
| `LocalOrigin` | Anchor point. `[lat, lon, alt]` for GPS or `[x, y, z]` for Cartesian. | `[0 0 0]` |
| `TimeOrigin` | Reference time subtracted from all timestamps. | `0` |
| `Attributes` | Cell array of additional recorded attributes (same length as timestamps). | `[]` |

### HARD RULES — non-ego actors built from `actorprops`

1. **Do NOT pass `Orientation=`.** The `Yaw` column from `actorprops` is in
   compass convention (0° = North, ~340° for a northbound actor). Passing
   it as `Orientation=[yaw pitch roll]` rotates actors to the wrong heading
   in RoadRunner's ENU world frame. Omit the argument and let RR derive
   heading from waypoint deltas — this matches recorded motion.
2. **`Speed=` is not a valid N-V argument** to the constructor. It exists
   on `vehicle()` in `drivingScenario`, not on `scenariobuilder.Trajectory`.
   Speed is read-only on the object (`GroundSpeed` property), derived from
   waypoint timestamps. Passing `Speed=` errors with *"Unrecognized name-
   value pair argument"*.

These rules apply only to NON-EGO actors. The ego trajectory is built from
GPS via the `trajectory()` function (lowercase) and follows different
conventions — see [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md).

### Ego Orientation — GPS heading is unreliable

`trajectory(gpsData)` derives heading from position deltas. **At low speed
or early GPS lock, the heading can be 180° wrong** — the ego faces
backwards at the start of the simulation. CAN ego yaw rate or GPS compass
heading are accurate alternatives.

**When CAN ego signals exist (speed, yaw rate, compass heading):** use the
GPS+CAN heading fusion pattern to build a fused ego trajectory with
`Orientation=[canHeading, 0, 0]`.

**When only GPS is available:** accept the limitation. The heading corrects
itself once the vehicle reaches sufficient speed (>5 m/s). For short
low-speed segments at the start, `smooth(egoTrajectory)` can help but
won't fully fix a 180° flip.

### Known Product Bugs (workarounds until fixed)

**P9 — `actorprops` Yaw gives ego heading to ALL actors.** `actorprops`
returns the ego's yaw for every actor regardless of their actual direction
of travel. Oncoming vehicles show ~273° instead of ~93°. **Workaround:**
Never pass `actorprops` Yaw to `Trajectory`. Omit `Orientation=` entirely
— the `Trajectory` object auto-derives correct heading from waypoint
deltas.

**P10 — `actorprops` Yaw is in degrees but `Trajectory(Orientation=...)`
expects radians.** No validation or warning is thrown — 273 degrees is
silently interpreted as 273 radians, causing vehicles to spin wildly.
**Workaround:** Even if you had correct per-actor yaw, you would need
`deg2rad()` before passing. But since P9 makes the values wrong anyway,
the correct fix is to never pass Orientation for actors.

**P11 — `Trajectory.Orientation` column order is undocumented in help.**
The help text says "N-by-3 matrix" but does not specify column order.
Actual order: **`[Yaw, Pitch, Roll]`** in **radians**. Most robotics
conventions use `[Roll, Pitch, Yaw]` — agents get this wrong on first
attempt every time. **Workaround:** Always use `[Yaw, Pitch, Roll]`.
Only relevant for ego trajectory (fused CAN heading) — actors should not
have Orientation passed at all (see P9).

**Summary — correct actor export pattern:**
```matlab
% NO Orientation, NO Speed — auto-derived heading from waypoints is correct
actorTraj = scenariobuilder.Trajectory( ...
    actorInfo.Time{i}, wp, ...
    Name=actorInfo.TrackID(i), LocalOrigin=egoLocalOrigin);
```

## Properties

| Property | Access | Description |
|----------|--------|-------------|
| `Name` | Read/Write | Name of the trajectory. |
| `NumSamples` | Read-only | Number of waypoints. |
| `Duration` | Read-only | Total time duration (seconds). |
| `SampleRate` | Read-only | Mean sample rate (Hz). |
| `SampleTime` | Read-only | Mean time interval between samples (seconds). |
| `Timestamps` | Read-only | Timestamps of waypoint data. |
| `Position` | Read-only | N-by-3 matrix of waypoint coordinates `[x y z]` (m). **Note:** the property is `Position` — NOT `Waypoints`. `Waypoints` is the column name in the `actorprops` result table, not a property of `scenariobuilder.Trajectory`. |
| `Orientation` | Read-only | N-by-3 matrix of Euler angles `[yaw pitch roll]` (rad). |
| `Velocity` | Read-only | Velocity at each waypoint (m/s). |
| `Course` | Read-only | Horizontal direction of travel (deg). |
| `GroundSpeed` | Read-only | Speed over ground at each waypoint (m/s). |
| `Acceleration` | Read-only | Acceleration at each waypoint (m/s²). |
| `AngularVelocity` | Read-only | Angular velocity at each waypoint (rad/s²). |
| `LocalOrigin` | Read/Write | Reference origin for coordinates. |
| `TimeOrigin` | Read/Write | Reference starting time. |
| `Attributes` | Read/Write | Custom trajectory attributes. |

## Object Functions

### Data Manipulation
| Method | Description |
|--------|-------------|
| `add` | Add data samples to the trajectory. |
| `remove` | Remove data samples from the trajectory. |
| `read` | Read data from the trajectory. |
| `crop` | Crop trajectory to a time range. |
| `copy` | Create a copy of the trajectory object. |
| `synchronize` | Synchronize trajectory with another sensor data object or timestamps. |
| `normalizeTimestamps` | Normalize timestamps to a reference time. |
| `convertTimestamps` | Convert timestamps to a different format. |
| `distance` | Calculate total distance traveled through waypoints (meters). |

### Smoothing
| Method | Description |
|--------|-------------|
| `smooth` | Smooth noisy trajectory data. |
| `adjustHeight` | Adjust trajectory z-coordinates to match road height. |

### Visualization
| Method | Description |
|--------|-------------|
| `plot` | Plot trajectory on a figure. |
| `writeCSV` | Write trajectory as a CSV file. |

### Export
| Method | Description |
|--------|-------------|
| `exportToRoadRunner` | Export trajectory to RoadRunner. |
| `exportToDrivingScenario` | Export trajectory to a drivingScenario object. |

---

## smooth

```matlab
smooth(traj)
smooth(traj, Method=method)
smooth(traj, SmoothingFactor=factor)
smooth(traj, Method="sgolay", Degree=d)
smooth(traj, Method="custom", SmoothingFcn=@fcn)
smoothedTraj = smooth(traj, ...)   % returns copy, does not modify original
```

| Name-Value | Description | Default |
|------------|-------------|---------|
| `Method` | `"sgolay"`, `"movmean"`, `"movmedian"`, `"gaussian"`, `"lowess"`, `"loess"`, `"rlowess"`, `"rloess"`, `"custom"` | `"sgolay"` |
| `SmoothingFactor` | 0 (less smoothing) to 1 (more smoothing). | `0.25` |
| `Degree` | Polynomial degree for sgolay filter. | `2` |
| `SmoothingFcn` | Function handle for custom smoothing (required when Method="custom"). | `[]` |

---

## plot

```matlab
plot(traj)
f = plot(traj)
plot(traj, Name=Value)
```

| Name-Value | Description | Default |
|------------|-------------|---------|
| `Parent` | Handle to parent figure. | New figure |
| `ShowZ` | Show Z values. | `false` |
| `ShowSpeed` | Show speed. | `false` |
| `ShowHeading` | Show heading. | `false` |
| `ShowOrientation` | Show orientation. | `false` |
| `ShowVelocity` | Show velocity. | `false` |
| `ShowAcceleration` | Show acceleration. | `false` |
| `ShowAngularVelocity` | Show angular velocity. | `false` |
| `LineSpec` | Line style, marker, color. | `"-o"` |
| `Color` | Line color. | `[]` |
| `LineWidth` | Line width. | `1` |
| `MarkerSize` | Marker size. | `5` |
| `MarkerFaceColor` | Marker fill color. | `'none'` |
| `HeadingStep` | Points to skip between heading markers. | `round(NumSamples * 0.1)` |
| `OrientationUnit` | `"radians"` or `"degrees"`. | `"radians"` |

---

## writeCSV

```matlab
writeCSV(traj)
writeCSV(traj, FileName="path/to/file.csv")
writeCSV(traj, IncludeOrientation=true)
```

| Name-Value | Description | Default |
|------------|-------------|---------|
| `FileName` | Output CSV file path. | `fullfile(pwd, "Vehicle.csv")` |
| `IncludeOrientation` | Include yaw, pitch, roll columns. | `false` |

Output CSV columns: `time, x, y, z` (and optionally `yaw, pitch, roll`).

---

## exportToRoadRunner

```matlab
exportToRoadRunner(traj)
exportToRoadRunner(traj, rrApp)
exportToRoadRunner(traj, rrApp, Name=Value)
rrApp = exportToRoadRunner(traj, ...)
```

| Argument | Description |
|----------|-------------|
| `traj` | `scenariobuilder.Trajectory` object. |
| `rrApp` | `roadrunner` application object. If omitted, a dialog opens to select the RoadRunner project. |

| Name-Value | Description | Default |
|------------|-------------|---------|
| `Name` | Name of the vehicle in RoadRunner. | `"auto"` |
| `Color` | Color of the actor in the scenario. | `"auto"` |
| `AssetPath` | Actor asset path (string). Can be relative to Assets/ or Vehicles/ dir, or absolute path. | `"auto"` |
| `SetupSimulation` | If `true`, creates a RoadRunner simulation and sets start time, end time, and step size from the trajectory. | `true` |
| `RoadRunnerScene` | Path to a `.rrscene` or `.rrhd` file to import as the scene. | `[]` |

**Behavior:**
- Sets the scene's World Origin using `traj.LocalOrigin`.
- Writes trajectory to a temporary CSV, then calls `importScenario` with `"CSV Trajectory"` format.
- If `SetupSimulation=true`, creates a new scenario in RoadRunner and configures `MaxSimulationTime` and `StepSize`.

---

## exportToDrivingScenario

```matlab
exportToDrivingScenario(traj)
exportToDrivingScenario(traj, scenario)
exportToDrivingScenario(traj, scenario, Name=Value)
scenario = exportToDrivingScenario(traj, ...)
```

| Argument | Description |
|----------|-------------|
| `traj` | `scenariobuilder.Trajectory` object. |
| `scenario` | Existing `drivingScenario` object. If omitted, a new one is created. |

| Name-Value | Description | Default |
|------------|-------------|---------|
| `Name` | Name of the actor in the scenario. | `""` |
| `Color` | Color of the actor in the plot. | `"auto"` |
| `ClassID` | Integer to classify vehicle type (0 = unknown). | `1` |
| `Mesh` | `extendedObjectMesh` object for the actor. | `driving.scenario.carMesh` |
| `AssetType` | Asset type string: `"Cuboid"`, `"Sedan"`, `"MuscleCar"`, `"Hatchback"`, `"SportUtilityVehicle"`, `"SmallPickupTruck"`, `"BoxTruck"`, `"Bicyclist"`, `"MalePedestrian"`, `"FemalePedestrian"`. | `"Sedan"` |
| `RoadNetworkSource` | Import roads: `"OpenDRIVE"`, `"OpenStreetMap"`, `"HEREHDLiveMap"`, `"ZenrinJapanMap"`, or `""`. | `""` |
| `FileName` | Road network file path (for OpenDRIVE or OpenStreetMap). | `[]` |
| `GeoCoordinates` | `[lat lon]` or `[minLat minLon maxLat maxLon]` for HEREHDLiveMap/ZenrinJapanMap. | `[]` |
| `SetupSimulation` | If `true`, sets `scenario.SampleTime` and `scenario.StopTime` from the trajectory. Set to `false` for non-ego actors. | `true` |

**Behavior:**
- Creates a `vehicle` in the scenario with the specified properties.
- If the trajectory is non-stationary (position std > 2m), assigns waypoints and speed via `trajectory()`.
- If `RoadNetworkSource` is specified, imports road network into the scenario.

---

## adjustHeight

```matlab
adjustHeight(traj, map)        % roadrunnerHDMap
adjustHeight(traj, rrApp)      % roadrunner app
adjustHeight(traj, scenario)   % drivingScenario
adjustedTraj = adjustHeight(traj, ...)  % returns copy
adjustHeight(traj, rrApp, SmoothingFactor=0.1)
```

| Name-Value | Description | Default |
|------------|-------------|---------|
| `SmoothingFactor` | 0 (less smoothing) to 1 (more smoothing) for the adjusted height. | `0.25` |

Adjusts the trajectory's z-coordinates to match road surface height from an HD map, RoadRunner scene, or drivingScenario.

**Note:** `adjustHeight` may fail with warning "Trajectory is not aligned with road direction in Map" if the scene was imported from a different project or has projection mismatches. In that case, use the manual Z interpolation approach from Workflow 7 in SKILL.md.

---

## distance

```matlab
d = distance(traj)
```

Returns the total distance traveled (sum of piecewise Euclidean distances between consecutive XY waypoints) in meters.

---

## Example

```matlab
t = (0:0.1:1)';
x = (0:10:100)';
y = zeros(11,1);
z = zeros(11,1);
traj = scenariobuilder.Trajectory(t, x, y, z, Name="LinearPath");

% Smooth
smooth(traj);

% Plot with speed and orientation
plot(traj, ShowSpeed=true, ShowOrientation=true);

% Export to RoadRunner
rrApp = roadrunner("C:\RRProject", InstallationFolder="C:\RoadRunner");
exportToRoadRunner(traj, rrApp, Name="Ego", SetupSimulation=true);

% Export to drivingScenario with OpenStreetMap roads
scenario = exportToDrivingScenario(traj, ...
    RoadNetworkSource="OpenStreetMap", FileName="map.osm", Name="Ego");
```


----

Copyright 2026 The MathWorks, Inc.

----
