---
name: matlab-design-scenario
description: >
  Design, simulate, and analyze 3D scenarios with terrain, buildings, actors,
  trajectories, and analyses. Use when evaluating visibility or geometric paths
  between moving actors, planning sensor or antenna placement in urban
  environments, simulating vehicle or aircraft routes, or analyzing line-of-sight
  and geometric ray trace propagation over terrain and buildings. Also use when the user
  mentions 3D Scenarios or scenario(). Not for radarScenario, drivingScenario,
  uavScenario, trackingScenario, satelliteScenario, RoadRunner Scenario or Scenario
  Builder driving scenarios, or txsite and siteviewer coverage maps.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Design 3D Scenarios

## When to Use

- Creating 3D geographic scenarios with terrain and buildings
- Placing actors (cars, aircraft, generic point actors) and defining trajectories
- Running line-of-sight or ray trace analyses between actors, for example, evaluating geometric
  visibility for sensor or antenna placement
- Simulating actor motion and querying analysis results
- Viewing scenarios in interactive 3D globe viewers
- Querying actor poses in reference frames
- The user names 3D Scenarios or `scenario()`, or shares a script that uses it

## When NOT to Use

- UAV simulations with `uavScenario`. Use `matlab-create-uav-scenario` instead.
- Radar detections or radar coverage with `radarScenario`. Use `matlab-simulate-radar-detections`
  instead.
- Authoring or simulating scenarios in RoadRunner Scenario. Use `roadrunner-author-scenario`
  or `roadrunner-simulate-scenario` instead.
- Driving scenarios reconstructed from recorded data. Use `matlab-use-scenario-builder` instead.
- Driving, tracking, or satellite scenarios. Use `drivingScenario`, `trackingScenario`, or
  `satelliteScenario` instead.
- Terrain-only visibility. Use `los2` or `viewshed` instead.
- RF coverage, signal strength, or link budgets. Use `txsite` and `siteviewer` with
  `matlab-integrate-antenna` instead.

## Dependencies

3D Scenarios functions require Mapping Toolbox and the 3D Scenarios add-on. Use these Mapping
Toolbox functions for geospatial operations: `readgeotable` (read GPX, OpenStreetMap, GeoJSON,
KML, or shapefile data), `geocode` (get the shape of a placename as a geospatial table; for an
area, use `bounds` on the shape), `addCustomTerrain` (register terrain data),
`addCustomBuildings` (register buildings data), and geographic coordinate utilities.

## Workflow

1. **Register data:** Register buildings with `addCustomBuildings` and custom terrain with
   `addCustomTerrain`. Built-in terrain doesn't need registering.
2. **Create scenario:** `scenario()` with options: `Terrain`, `Buildings`, `StopTime`.
3. **Visualize (optional):** `viewer(scnro)` attaches a standalone 3D viewer. It updates
   automatically during `advance()`.
4. **Define trajectories:** `groundTrajectory()` or `airTrajectory()` with waypoints. Specify
   `GroundSpeed` or `TimeOfArrival`.
5. **Add actors:** `actor()`, `car()`, `aircraft()` with a `pointtable` position
   (`pointtable(lat,lon,ht)`; add `HeightReference="surface"` or `"ellipsoid"` for a
   non-default reference) or a `pose`. Pass a trajectory as the position for moving actors.
6. **Add analyses:** `losAnalysis(src, dest)` or `rayTraceAnalysis(src, dest)`. `dest` can
   be an array.
7. **Simulate:** `while advance(scnro)` loop. Query results inside, for example, `hasLOS(losA)`.

### Quick Example

```matlab
% manhattan.osm is on the MATLAB path
buildings = readgeotable("manhattan.osm", Layer="buildings");
addCustomBuildings("manhattan", buildings, NameExistsRule="preserve");
scnro = scenario(Buildings="manhattan", StopTime=30);
v = viewer(scnro);

% Positions are geospatial tables created using pointtable; "surface" puts the tower 5 m above the rooftop
towerPos = pointtable(40.7092, -74.0137, 5, HeightReference="surface");
actr = actor(scnro, towerPos, Name="Tower");

% Ground waypoints are 2D (no heights)
waypoints = pointtable([40.708; 40.710], [-74.010; -74.008]);
traj = groundTrajectory(waypoints, GroundSpeed=12);
c = car(scnro, traj, Name="Patrol");
losA = losAnalysis(actr, c);

% Advance the simulation one time step at a time and display LOS at each step
while advance(scnro)
    t = seconds(scnro.SimulationTime);
    isVisible = hasLOS(losA);
    fprintf("T=%.1fs: LOS=%d\n", t, isVisible);
end
```

### Frame the Scenario in the Viewer

After setting up actors and analyses, frame the scenario in the viewer so the user can see the
setup before simulation. Reuse the existing viewer rather than creating another:

```matlab
zoomto(v, "all")      % frame all scenario entities, terrain, and buildings
zoomto(v, actr)       % frame an actor
zoomto(v, losA)       % frame an analysis
```

### Key Functions

| Function | Purpose |
|----------|---------|
| `scenario()` | Create a scenario |
| `actor(scnro, p, Name=name)` | Add a generic point actor |
| `car(scnro, p, Name=name)` | Add a car |
| `aircraft(scnro, p, Name=name)` | Add an aircraft |
| `groundTrajectory(waypoints, Name=Value)` | Create a ground trajectory |
| `airTrajectory(waypoints, Name=Value)` | Create an air trajectory |
| `losAnalysis(source, destination, Name=Value)` | Create LOS analysis |
| `rayTraceAnalysis(source, destination, Name=Value)` | Create ray trace analysis |
| `advance(scnro)` | Advance simulation one step |
| `restart(scnro)` | Reset simulation to t=0 |
| `hasLOS(analysis)` | Query LOS visibility (logical) |
| `findpaths(rt)` | Get ray trace paths. `aoa` and `aod` azimuth is relative to the actor's forward axis; get the actor's yaw with `euler(pose(actor))` |
| `viewer(scnro)` | Attach a standalone viewer |
| `pickpoints(v, numpoints)` | Pick points interactively in the viewer (see Placing Actors) |
| `gcv(scnro)` | Get current viewer |
| `viewers(scnro)` | Get all viewers attached to a scenario |
| `getvisual(v, entity)` | Get the visual for an actor, trajectory, or analysis in a viewer |
| `interp(traj, t)` | Query trajectory pose at specified times |
| `pose([lat lon ht], [yaw pitch roll])` | Construct a pose (position with orientation). Pass it as an actor position to place a rotated actor. Read orientation back with `euler` on `pose(actor)` |
| `pointtable(lat, lon, ht)` | Create positions and waypoints. Pass `scnro.Scene` as the fourth argument to get the ellipsoid height of the terrain (add `HeightReference="surface"` to include buildings) |

## Placing Actors

When the user gives placenames rather than coordinates or data:

- Derive positions with `geocode`, or from OpenStreetMap roads and buildings by using
  `readgeotable`.
- In the final answer, name each actor or route whose position came from a placename,
  geocoding, or map data, and say that it is approximate. A geocoded point, a building
  centroid, or a street centerline is not an exact spot.
- Offer `[lat, lon, ht] = pickpoints(v, numpoints)` so the user can click exact positions in the
  viewer.
  - `pickpoints` blocks MATLAB until the user clicks, so prompt the user in text output before
    calling it.
  - The viewer opens in its own window even when MATLAB runs without the desktop, so
    `pickpoints` works there too. Ask whether the user can see the viewer.

Pick one plausible location from the data and run it. Don't search many placements (for
example, building scenarios in a loop) unless the user asks to optimize placement.

## Troubleshooting

| Problem | Fix |
|---|---|
| `groundTrajectory` errors on waypoints with heights | Pass a 2D `pointtable(lat,lon)`. To raise the actor, set an offset for all waypoints with the `Height` name-value argument |
| `airTrajectory` errors on waypoints without ellipsoid heights | Use `pointtable(lat,lon,ht,HeightReference="ellipsoid")` |
| `rayTraceAnalysis` errors that the reference point is inside the 3D model | Pass `SourceReferencePoint` and `DestinationReferencePoint`, for example, `"roof"`, for car and aircraft actors |
| `scenario(Buildings=file)` errors that the name is not a valid variable name | Register the data with `addCustomBuildings` (for terrain, `addCustomTerrain`), then pass the registered name |
| `scenario` errors that the registered buildings are invalid (for example, after their data was moved or deleted) | Re-register with `addCustomBuildings(name, data, NameExistsRule="overwrite")`, or call `removeCustomBuildings(name)` and add them again. `NameExistsRule="preserve"` keeps the invalid registration |
| `advance(scnro,dt)` errors with too many inputs | `advance` takes no step size. Set the `TimeStep` property of the behavior stored in the actor (`actr.Behavior.TimeStep`, default 0.1 s) |
| Viewer stays open after `close all` | Call `close(v)` on the viewer |
| The user can't see the viewer window | Call `figure(v.Parent)` to bring it to the front (for a viewer in a panel, call `figure` on the window that holds the panel). Don't move or resize the viewer's window from code. If the viewer is blank, call `close(v)`, then `v = viewer(scnro)` and `zoomto(v, "all")` |
| Changing actors, poses, or analyses errors after the simulation starts | Call `restart(scnro)` before changing actors, poses, or analyses |
| A multi-row `pointtable` passed to `aircraft`, `car`, or `actor` creates one static actor per row | Build a trajectory (`airTrajectory` or `groundTrajectory`) from the rows and pass it to a single actor |

## Conventions

- This skill and its reference files are the source of truth for the 3D Scenarios API. Use
  the signatures and patterns documented here. If a function isn't covered in SKILL.md, load
  the matching reference file before writing code.
- Name-value argument tables in the references list the commonly used arguments, not all of
  them. An unknown argument name errors with the list of valid names.
- On and off options accept `"on"` or `"off"`, or `true` or `false`. Examples use `"on"` and
  `"off"`.
- Times are in seconds. `TimeOfArrival`, `interp` times, `StopTime`, and `TimeStep` accept a
  number or a `duration`. `startTime`, `stopTime`, and `TimeOfArrival` return doubles.
  `SimulationTime`, `StopTime`, and `TimeStep` return durations (convert with `seconds`).
- Do not hard-code coordinates for placenames from memory. Resolve them with `geocode`
  or map data (`readgeotable`). Positions derived this way are approximate; say so in the answer.
- When input data states heights above ground, verify them against terrain before building
  trajectories: `pointtable(lat, lon, 0, scnro.Scene)` returns the terrain's ellipsoid height.
- Do not report received power from ray trace analysis. Ray paths contain only geometry
  (angles and distance). For power, use RF Propagation (`txsite`, `propagationModel`) or a
  model the user supplies.

## Reference

Paths are relative to this skill's folder, not the project's working directory.

| File | Topic |
|---|---|
| `references/scenario-configuration.md` | Scenario creation, terrain and buildings names, data registration, OpenStreetMap layers |
| `references/actor-placement.md` | Actor types, positions from `pointtable`, height references, placement on buildings, actor changes |
| `references/trajectory-design.md` | Ground and air trajectories, speed guidance, trajectory replacement, trajectory visuals, GPX waypoints, formations, orbits |
| `references/visibility-analysis.md` | LOS and ray trace analysis creation, reference points, result queries, LOS visuals, materials |
| `references/ray-path-analysis.md` | Ray trace results: `RayPathSet`, `RayPath` methods (`aoa`, `aod`, `propdist`), path plots, ray trace visuals |
| `references/pose-and-refframes.md` | Pose construction, orientation extraction, actor poses, reference frames, transforms |
| `references/simulation-execution.md` | Advance loop, restart and locking, per-step results, simulation properties |
| `references/camera-and-viewing.md` | Viewer options, basemaps, actor visuals, camera position, actor following, zoom and fly-to, point picking, line and point plots |

----

Copyright 2026 The MathWorks, Inc.

----
