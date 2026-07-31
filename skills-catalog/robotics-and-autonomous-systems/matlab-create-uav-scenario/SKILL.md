---
name: matlab-create-uav-scenario
description: >
  Create and simulate UAV scenarios with terrain, buildings, platforms, and sensors
  using uavScenario. Use when building a UAV simulation, UAV simulator, or UAV scenario
  in MATLAB. Covers addMesh for terrain/building import, uavPlatform with updateMesh,
  uavSensor adaptor pattern for GPS/IMU, and the setup/advance simulation loop.
  Triggers on: uavScenario, UAV simulation, UAV simulator, multirotor simulation,
  quadrotor scenario, terrain import, building import, GPS sensor simulation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Create UAV Scenario

Build and simulate UAV scenarios with terrain, buildings, sensor-equipped platforms, and 3D visualization using the UAV Toolbox `uavScenario` framework.

## When to Use

- Creating a UAV simulation environment with real-world terrain or buildings
- Adding sensor-equipped UAV platforms (GPS, IMU, lidar) to a scenario
- Running a time-stepping simulation loop with sensor readings
- Visualizing UAV flight in 3D with `show3D`

## When NOT to Use

- Generating flight trajectories (waypoint design, min-snap) — use trajectory skill instead
- Simulink-based UAV simulation (UAV Toolbox Simulink blocks)
- Path planning and obstacle avoidance algorithms
- Coordinate conversion only (`ned2lla`, `lla2ned`) — use these directly

## Workflow

1. **Create scenario** — `uavScenario` with `ReferenceLocation` and `UpdateRate`
2. **Add terrain** — `addMesh(scene,"terrain",...)` with GMTED2010 or custom DTED
3. **Add buildings** — `addMesh(scene,"buildings",...)` from OSM file
4. **Add platform** — `uavPlatform` with trajectory, then `updateMesh`
5. **Attach sensors** — `uavSensor` adaptor binding sensor to platform
6. **Run simulation** — `setup` → `advance` → `updateSensors` → `read` loop
7. **Visualize** — `show3D` with `FastUpdate` for animation

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `uavScenario` | Create simulation scenario | UAV Toolbox |
| `addMesh` | Add terrain, buildings, or custom meshes | UAV Toolbox |
| `uavPlatform` | Add UAV platform to scenario | UAV Toolbox |
| `updateMesh` | Set platform body mesh | UAV Toolbox |
| `uavSensor` | Attach sensor to platform | UAV Toolbox |
| `setup` | Initialize scenario for simulation | UAV Toolbox |
| `advance` | Step simulation forward one time step | UAV Toolbox |
| `updateSensors` | Update all sensors at current time | UAV Toolbox |
| `show3D` | 3D visualization | UAV Toolbox |
| `waypointTrajectory` | Define flight path from waypoints | Navigation Toolbox |
| `gpsSensor` | GPS noise model | Navigation Toolbox |
| `insSensor` | INS/IMU noise model | Navigation Toolbox |

## Patterns

### Create Scenario with Reference Location

```matlab
scene = uavScenario( ...
    "UpdateRate", 10, ...
    "StopTime", 60, ...
    "ReferenceLocation", [42.355 -71.066 0]);
```

`ReferenceLocation` is `[lat lon alt]` in degrees and meters. All local coordinates are relative to this origin. Set this before adding any meshes or platforms.

### Add Terrain (GMTED2010)

Use geographic coordinates with `UseLatLon=true`:

```matlab
latLim = [42.350 42.360];
lonLim = [-71.072 -71.060];
addMesh(scene, "terrain", {"gmted2010", latLim, lonLim}, [0.3 0.6 0.2], ...
    UseLatLon=true);
```

Or use local ENU coordinates (meters) without `UseLatLon`:

```matlab
xLim = [-500 500];
yLim = [-500 500];
addMesh(scene, "terrain", {"gmted2010", xLim, yLim}, [0.3 0.6 0.2]);
```

The geometry cell for terrain is **3 elements:** `{"gmted2010", xOrLatLim, yOrLonLim}`.

The `color` argument is **required** — it is not optional.

If user used addCustomTerrain to import DTED file with a terrain name, this terrain can be used in addition to gmted2010.

```matlab
addCustomTerrain("myterrain", "myterrain.dt1");
xLim = [-500 500];
yLim = [-500 500];
addMesh(scene, "terrain", {"myterrain", xLim, yLim}, [0.3 0.6 0.2]);
```

### Add Buildings (OSM File)

```matlab
osmFile = "boston_common.osm";
latLim = [42.350 42.360];
lonLim = [-71.072 -71.060];

addMesh(scene, "buildings", {osmFile, latLim, lonLim, 'auto'}, ...
    [0.6 0.6 0.6], UseLatLon=true);
```

Or use local ENU coordinates (meters) without `UseLatLon`:

```matlab
xLim = [-500 500];
yLim = [-500 500];
addMesh(scene, "buildings", {osmFile, xLim, yLim, 'auto'}, [0.3 0.6 0.2]);
```

The geometry cell for buildings is **4 elements:** `{osmFile, latOrXLim, lonOrYLim, height}`. `height` can either be 'auto' or a numerical scalar. Auto will snap buildings to terrain height if available.

The `color` argument is **required** — it is not optional.

### Add Platform with Mesh

```matlab
traj = waypointTrajectory( ...
    "Waypoints", [0 0 -50; 200 0 -50; 200 200 -50; 0 0 -50], ...
    "TimeOfArrival", [0 20 40 60], ...
    "ReferenceFrame", "NED");

plat = uavPlatform("UAV1", scene, "Trajectory", traj);
updateMesh(plat, "quadrotor", {1}, [0 0.4 0.8], [0 0 0], [0 1 0 0]);
```

`updateMesh` requires **all arguments**: `(platform, type, geometries, color, position, orientation)`.
- `geometries` — 1-element cell: `{scaleFactor}` for `"quadrotor"`/`"fixedwing"`, `{[L W H]}` for `"cuboid"`
- `color` — RGB triplet (required, not optional)
- `position` — `[x y z]` offset, use `[0 0 0]` for default
- `orientation` — quaternion `[w x y z]`, use `[0 1 0 0]` for NED scenarios (180-degree roll to flip z-down body frame upright)

Valid mesh types: `"fixedwing"`, `"quadrotor"`, `"cuboid"`, `"custom"`.

There is NO `"multirotor"` type — use `"quadrotor"` for any multirotor UAV.

### Attach Sensors (uavSensor Adaptor Pattern)

**Always use `uavSensor` to bind sensors to platforms.** Do not feed sensor models manually.

```matlab
% Create sensor model
gps = gpsSensor("SampleRate", 10, "ReferenceFrame", "NED");

% Bind to platform via uavSensor adaptor
gpsSensorObj = uavSensor("GPS", plat, gps, "UpdateRate", 10);
```

For INS:

```matlab
ins = insSensor;
insSensorObj = uavSensor("INS", plat, ins, "UpdateRate", 10);
```

Sensor `UpdateRate` must divide evenly into the scenario `UpdateRate`. For example, a 10 Hz scenario supports sensor rates of 1, 2, 5, or 10 Hz — not 100 Hz.

### Simulation Loop

```matlab
setup(scene);

while advance(scene)
    updateSensors(scene);

    % Read sensor data (3 outputs: isUpdated, timestamp, readings)
    [isUpdated, t, position, velocity, groundspeed, course] = read(gpsSensorObj);
    if isUpdated
        % position is 1x3 [lat lon alt] for gpsSensor
        gpsLLA = position;
    end

    % Read platform state directly
    [motion, lla] = read(plat);
    % motion: 1x16 vector [pos(3) orient(4) vel(3) acc(3) angvel(3)]
    % lla: [lat lon alt]
end
```

`read(sensor)` returns **variable number outputs:**
- `isUpdated` — logical, true when sensor has new data at this time step
- `t` — timestamp in seconds
- `sensorReadings1` to `sensorReadingsN` — sensor-specific output (`position, velocity, groundspeed, course` for `gpsSensor`)

`read(plat)` returns **exactly 2 outputs:**
- `motion` — 16-element vector: position(1:3), orientation quaternion(4:7), velocity(8:10), acceleration(11:13), angular velocity(14:16)
- `lla` — 3-element vector: [latitude, longitude, altitude]

### Visualize with show3D

```matlab
setup(scene);
ax = show3D(scene);

while advance(scene)
    updateSensors(scene);
    show3D(scene, "FastUpdate", true, "Parent", ax);
    drawnow limitrate
end
```

Use `"FastUpdate", true` after the first call for efficient animation.

### Trajectory Trail (Flight Path Line)

`show3D` only renders the UAV at its current position — it does NOT draw the flight path. To show the trajectory trail, create a line object once, then update its data each step:

```matlab
setup(scene);
[ax, plottedFrames] = show3D(scene);
hold(ax, "on");
% Draw trajectory in the platform's reference frame
trajLine = plot3(plottedFrames.(plat.ReferenceFrame), NaN, NaN, NaN, "r-", "LineWidth", 1.5);
hold(ax, "off");

% acceptable for short loops; pre-allocate for long simulations
xHist = []; yHist = []; zHist = [];
while advance(scene)
    show3D(scene, "FastUpdate", true, "Parent", ax);
    [motion, ~] = read(plat);
    xHist(end+1) = motion(1); 
    yHist(end+1) = motion(2);
    zHist(end+1) = motion(3);
    set(trajLine, "XData", xHist, "YData", yHist, "ZData", zHist);
    drawnow limitrate
end
```

Do NOT call `plot3` inside the loop — it creates a new graphics object each step and kills performance.

### Body-Frame Marker (Visibility in Large Scenes)

When scenes span 500m+, the platform mesh becomes invisible regardless of scale factor. Instead of inflating the scale (which distorts the mesh), parent a marker to the platform's body frame so it tracks at any zoom level:

```matlab
setup(scene);
[ax, plottedFrames] = show3D(scene);
hold(ax, "on");
bodyFrame = plottedFrames.UAV1.BodyFrame;
plot3(ax, 0, 0, 0, "r^", "MarkerSize", 15, "MarkerFaceColor", "r", ...
    "Parent", bodyFrame);
hold(ax, "off");

while advance(scene)
    show3D(scene, "FastUpdate", true, "Parent", ax);
    drawnow limitrate
end
```

Replace `UAV1` with the actual platform name. The marker moves with the UAV automatically via the parent transform.

## Gotchas

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| `addMesh(...,latLim,lonLim)` without `UseLatLon=true` | 0 buildings imported, terrain at wrong location | Add `UseLatLon=true` when passing geographic coordinates |
| `updateMesh(plat,"multirotor",...)` | Error — invalid mesh type | Use `"quadrotor"` |
| `updateMesh` with `[1 0 0 0]` (identity quaternion) in NED scenario | Inverted or invisible mesh — body frame is z-down | Use `[0 1 0 0]` (180-degree roll) to flip mesh upright |
| `[pos, orient, vel] = read(plat)` | Error — too many outputs | Use `[motion, lla] = read(plat)` (2 outputs) |
| `[isUpdated, data] = read(sensor)` | Gets timestamp instead of readings | Use `[isUpdated, t, sensorReadings] = read(sensor)` (3 outputs) |
| Feeding `gpsSensor` manually each step | Works but bypasses the scenario framework | Use `uavSensor` adaptor + `updateSensors(scene)` |
| Missing `color` argument in `addMesh` | Error — not enough input arguments | Always provide RGB triplet as 4th argument |
| `waypointTrajectory` in ENU with NED platform | Error — reference frame mismatch | Set `"ReferenceFrame","NED"` on trajectory |
| Forgetting `setup(scene)` before loop | Sensors not initialized, no readings | Always call `setup(scene)` before `advance` |
| Sensor `UpdateRate` > scenario `UpdateRate` | Error — rate must divide evenly | Sensor rate must be ≤ scenario rate and divide evenly into it |

## Conventions

- **NED frame** is the default for `uavPlatform`. Match all trajectories and sensors to NED.
- **`ReferenceLocation`** must be set at scenario creation — it is read-only after construction.
- **`UpdateRate`** on the scenario controls the simulation time step. Sensor `UpdateRate` can differ (sensors skip steps when not due).
- **OSM files** must be downloaded separately (e.g., via Overpass API or export from openstreetmap.org). `addMesh("buildings",...)` expects a file path, not a URL.
- **`addCustomTerrain`** for DTED files when GMTED2010 resolution is insufficient.

---

Copyright 2026 The MathWorks, Inc.
