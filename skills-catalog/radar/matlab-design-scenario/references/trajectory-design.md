# Design Trajectories

## Ground Trajectories

A ground trajectory follows the terrain surface.

```matlab
waypoints = pointtable([40.7080; 40.7090; 40.7100], [-74.0100; -74.0090; -74.0080]);
traj = groundTrajectory(waypoints, GroundSpeed=12);
c = car(scnro, traj, Name="Patrol Car");

traj = groundTrajectory(waypoints, GroundSpeed=12, Height=2, PathType="linear");
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `GroundSpeed` | `13` (default) \| nonnegative scalar \| vector, one per waypoint | Meters per second; at least one value must be positive |
| `TimeOfArrival` | vector, one per waypoint | Seconds, as nondecreasing values starting at `0` (number or `duration`) (see Rules) |
| `PathType` | `"clothoid"` (default) \| `"linear"` | Smooth curve or straight segments through the waypoints |
| `Course` | vector, one per waypoint | Direction at each waypoint, degrees clockwise from north; requires `PathType="clothoid"` |
| `Height` | `0` (default) \| nonnegative scalar | Offset above the ground, meters |

Waypoints must be a 2D `pointtable(lat, lon)` with the default `"terrain"` reference.
Heights or `HeightReference="surface"` are not supported. Raise the path with `Height`.

## Air Trajectories

An air trajectory flies through 3D waypoints.

```matlab
waypoints = pointtable([40.7100; 40.7150; 40.7200], [-74.0050; -74.0020; -74.0050], ...
    [200; 200; 200], HeightReference="ellipsoid");
traj = airTrajectory(waypoints, GroundSpeed=30);
a = aircraft(scnro, traj, Name="Survey Drone");
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `GroundSpeed` | `250` (default) \| nonnegative scalar \| vector, one per waypoint | Meters per second; at least one value must be positive |
| `TimeOfArrival` | vector, one per waypoint | Seconds, as nondecreasing values starting at `0` (number or `duration`) (see Rules) |
| `Course` | vector, one per waypoint | Direction at each waypoint, degrees clockwise from north |
| `ClimbRate` | scalar \| vector, one per waypoint | Meters per second |

Waypoints must have heights referenced to the WGS84 ellipsoid
(`HeightReference="ellipsoid"`). Convert mean-sea-level heights with
`hEllipsoid = hMSL + egm96geoid(lat, lon)`.

## Speed Guidance

Always specify `GroundSpeed`. The defaults rarely fit the scenario.

| Scenario | GroundSpeed (m/s) |
|---|---|
| Car in city | 8–15 |
| Car on highway | 25–35 |
| Drone or small UAV | 10–30 |
| Helicopter | 40–70 |
| Commercial jet (cruise) | 220–260 |
| Fighter jet | 250–400 |

## Rules

- Provide at least 2 waypoints, including the start point.
- Specify either `GroundSpeed` or `TimeOfArrival`, not both.
- To delay a start or hold at a point, repeat the waypoint with a later time. For example, waypoints
  `[A; A; B]` with `TimeOfArrival=[0 30 60]` waits 30 s at A.
- `Course` (clockwise from north) differs from actor yaw in the scene's ENU frame
  (counterclockwise from east; see `pose-and-refframes.md`, Actor Poses).

## Replace a Trajectory

An actor with a trajectory can't be moved with `position`, `translate`, `rotate`, or `pose`.
Replace its trajectory instead:

```matlab
c.Behavior.Trajectory = groundTrajectory(pointtable([40.7080; 40.7095], [-74.0100; -74.0070]), ...
    GroundSpeed=15);
```

## Time Step

The `TimeStep` property of the behavior stored in each moving actor (default `seconds(0.1)`)
sets how often the actor updates (see `simulation-execution.md`, Advance Loop):

```matlab
c.Behavior.TimeStep = seconds(0.5);
```

## Trajectory Visual

The path line and waypoint markers are a `WaypointTrajectoryVisual`. `Behavior.Visual` is
empty until a viewer is attached; call `viewer(scnro)` first:

```matlab
vis = c.Behavior.Visual;      % or getvisual(v, c.Behavior)
vis.ShowWaypoints = "off";    % path only
vis.Color = [1 0.5 0];
vis.LineWidth = 3;
vis.WaypointSize = 10;
vis.Visible = "off";          % hide entirely
```

`WaypointTrajectoryVisual` properties: `Color`, `LineWidth`, `WaypointSize`, `ShowPath`,
`ShowWaypoints`, `Visible`.

## Waypoints from a GPX File

GPX layers include `"waypoints"`, `"routes"`, `"tracks"`, and `"track_points"`; the layers
present depend on the file. `"track_points"` gives one point per recorded fix, with an
`Elevation` column.

```matlab
trackPts = readgeotable("route.gpx", Layer="track_points");
lat = trackPts.Shape.Latitude;
lon = trackPts.Shape.Longitude;

groundTraj = groundTrajectory(pointtable(lat, lon), GroundSpeed=12);

% GPX elevations are usually above mean sea level, so convert to ellipsoid heights
hEllipsoid = trackPts.Elevation + egm96geoid(lat, lon);
airTraj = airTrajectory(pointtable(lat, lon, hEllipsoid, HeightReference="ellipsoid"), GroundSpeed=30);
```

## Query Trajectory State

`interp` evaluates a trajectory without running the simulation; it returns `pose` objects:

```matlab
p5 = interp(traj, 5);                        % pose at t = 5 s
p = interp(traj, 0:0.5:10);                  % 21-by-1 pose
t0 = startTime(traj);                        % seconds
t1 = stopTime(traj);                         % when the trajectory finishes
```

- `interp` poses use a plain WGS84 `geoframe` (`Terrain="none"`), not the scene frame. See
  `pose-and-refframes.md`, Trajectory Poses vs Actor Poses.
- Times before `startTime` or after `stopTime` return `NaN` positions.

## Offset Trajectory from a Lead Actor

For formation, escort, or chase, sample the lead trajectory densely and offset each sample in
the lead's local ENU. Offsetting only the lead's waypoints holds the formation only at the
waypoints; between them the follower drifts (tens of meters or more in turns).

```matlab
scnro = scenario(Terrain="none");
leadWaypoints = pointtable([40.70; 40.72; 40.72], [-74.02; -74.02; -73.99], ...
    [500; 500; 600], HeightReference="ellipsoid");
leadTraj = airTrajectory(leadWaypoints, GroundSpeed=60);
lead = aircraft(scnro, leadTraj, Name="Lead");

offsetForward = -100;                  % meters along the lead's heading (negative = behind)
offsetRight = 60;                      % meters to the lead's right
t1 = stopTime(leadTraj);
t = unique([startTime(leadTraj):1:t1, t1]);           % 1 s samples, end included
p = interp(leadTraj, t);
leadPos = vertcat(p.Position);
fwd = vertcat(p.Forward);
heading = fwd(:, 1:2) ./ vecnorm(fwd(:, 1:2), 2, 2);  % horizontal [east north]
east = offsetForward*heading(:, 1) + offsetRight*heading(:, 2);
north = offsetForward*heading(:, 2) - offsetRight*heading(:, 1);
[lat, lon, h] = enu2geodetic(east, north, zeros(size(east)), ...
    leadPos(:, 1), leadPos(:, 2), leadPos(:, 3), wgs84Ellipsoid);
wingTraj = airTrajectory(pointtable(lat, lon, h, HeightReference="ellipsoid"), TimeOfArrival=t);
wing = aircraft(scnro, wingTraj, Name="Wingman");
```

- `TimeOfArrival` must equal the sample times so the follower stays synchronized.
- Air `interp` heights are ellipsoid heights, as `airTrajectory` requires. For a ground
  follower, pass only `lat, lon` to `groundTrajectory`. Ground `interp` heights are the
  `Height` offset, not ellipsoid heights.
- Check the offset *between* sample times (for example, `t + 0.5`). Simulation steps that land on
  sample times always show zero error.

## Orbits and Patrols

There is no orbit option. Repeat the waypoint loop once per lap and close it on the start point:

```matlab
loopLat = [40.70; 40.71; 40.71; 40.70];
loopLon = [-74.02; -74.02; -74.00; -74.00];
nLaps = 3;
lat = [repmat(loopLat, nLaps, 1); loopLat(1)];        % close the last lap
lon = [repmat(loopLon, nLaps, 1); loopLon(1)];
orbitWaypoints = pointtable(lat, lon, repmat(800, size(lat)), HeightReference="ellipsoid");
orbitTraj = airTrajectory(orbitWaypoints, GroundSpeed=60);
recon = aircraft(scnro, orbitTraj, Name="Recon");
lapTime = orbitTraj.TimeOfArrival(numel(loopLat) + 1);   % seconds per lap
```

- `stopTime` grows linearly with `nLaps`. Choose `nLaps = ceil(requiredDuration/lapTime)`.
- The run lasts as long as the longest trajectory, so extra laps lengthen the whole run. Set
  `scnro.StopTime` to cut it.

----

Copyright 2026 The MathWorks, Inc.

----
