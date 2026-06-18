# Trajectory Configuration

## When to Use Which

| Trajectory | Use When | Scenario Constraint |
|------------|----------|---------------------|
| `kinematicTrajectory` | Stationary platforms, constant-velocity movers, or state-driven motion | `IsEarthCentered = false` |
| `waypointTrajectory` | Planned flight paths with waypoints and timing | `IsEarthCentered = false` |
| `geoTrajectory` | Geodetic paths (lat/lon/alt), long-range, earth curvature matters | `IsEarthCentered = true` |

## Stationary Platforms

| Trajectory | How to Make Stationary | Scenario Constraint |
|------------|----------------------|---------------------|
| `kinematicTrajectory` | `platform(scene, 'Position', [x y z])` or explicit `Velocity=[0 0 0]` | `IsEarthCentered = false` |
| `waypointTrajectory` | Duplicate endpoint: same position at `[0; StopTime]` | `IsEarthCentered = false` |
| `geoTrajectory` | Single waypoint: `geoTrajectory([lat, lon, alt])` | `IsEarthCentered = true` |

```matlab
% kinematicTrajectory (simplest, recommended for stationary)
radarPlat = platform(scene, 'Position', [0 0 0]);

% waypointTrajectory (must have 2 waypoints — duplicate position)
radarPlat = platform(scene, 'Trajectory', waypointTrajectory( ...
    'Waypoints', [0 0 0; 0 0 0], 'TimeOfArrival', [0; stopTime]));

% geoTrajectory (earth-centered) — single waypoint is stationary
radarPlat = platform(scene, 'Trajectory', geoTrajectory([42.36, -71.06, 30]));
```

**Gotcha:** `waypointTrajectory` requires at least 2 waypoints — cannot use single waypoint for stationary. Duplicate positions are allowed with `TimeOfArrival` form but NOT with `GroundSpeed` form (errors: "unique values"). `geoTrajectory` allows single waypoint (warning about `TimeOfArrival` ignored is harmless).

## Orientation and Body Frame — Critical Difference

The trajectory type determines whether the platform's body frame rotates with velocity:

| Trajectory | Orientation (Stationary) | Orientation (Moving) | Sensor Boresight Behavior |
|------------|-------------------------|---------------------|--------------------------|
| `kinematicTrajectory` | [0,0,0] = body +X = North | **[0,0,0] always** — body frame FIXED to scenario frame | Sensor always points same direction regardless of platform velocity |
| `waypointTrajectory` | [0,0,0] = body +X = North | **Rotates** — body +X follows velocity (yaw = heading) | Sensor "looks forward" — beam direction follows platform heading |
| `geoTrajectory` | [0,0,0] = body +X = local North | **Rotates** — body +X follows velocity (yaw = heading) | Same as waypointTrajectory |

**`platform.Orientation` is [yaw, pitch, roll] in degrees.** Yaw=0 means body +X points North (NED). Yaw=90 means body +X points East.

**Critical implication for sensors:** If you put a radar with `MountingAngles=[0,0,0]` on a platform moving East:
- **kinematicTrajectory:** radar looks **North** (body frame is fixed)
- **waypointTrajectory/geoTrajectory:** radar looks **East** (body frame follows heading)

This causes **silent beam-pointing errors** when agents use `kinematicTrajectory` for moving platforms with forward-looking sensors. The radar "appears" to work but looks sideways.

**`AutoPitch` and `AutoBank`** (waypointTrajectory only):
- `AutoPitch=false` (default): pitch stays 0 even during climb/descent. Body stays level.
- `AutoPitch=true`: pitch aligns with velocity direction. Climbing at 45° gives pitch=+45° (positive = nose up in NED).
- `AutoBank=true`: roll counteracts centripetal force in turns.

**Recommendation:** For moving platforms with sensors (aircraft, ships):
- Use `waypointTrajectory` or `geoTrajectory` so the body frame (and thus sensor boresight) naturally follows the platform heading.
- Use `kinematicTrajectory` only for stationary platforms or when you explicitly want a fixed body frame (e.g., a target that moves but has no meaningful orientation).

**Note:** This is the `radar/waypointTrajectory` from Radar Toolbox (shared with Sensor Fusion). It is NOT the same as the trajectory system in `drivingScenario` — those use actor waypoints with a different API. Do not mix documentation between the two.

## waypointTrajectory

```matlab
tgt = platform(scene, 'Trajectory', waypointTrajectory( ...
    'Waypoints', [10000 0 -500; 5000 5000 -1000; 0 10000 -500], ...
    'TimeOfArrival', [0; 30; 60], ...
    'ReferenceFrame', 'NED', ...
    'AutoPitch', true, ...
    'AutoBank', true));
```

| Property | Purpose | Notes |
|----------|---------|-------|
| `Waypoints` | N×3 positions [x,y,z] or [N,E,D] | Minimum 2 required; must be unique positions |
| `TimeOfArrival` | N×1 arrival times (s) | Mutually exclusive with `WaitTime` and `JerkLimit` |
| `Velocities` | N×3 velocities at waypoints | Auto-derived via cubic Hermite if omitted — causes smooth curves with possible overshoot at turns |
| `GroundSpeed` | N×1 scalar speed at each waypoint | Alternative to `TimeOfArrival` |
| `Course` | N×1 heading angle from North (deg) | Use with `GroundSpeed` |
| `ClimbRate` | N×1 vertical rate (m/s) | Use with `GroundSpeed` |
| `WaitTime` | N×1 loiter time at each waypoint (s) | Requires `GroundSpeed=0` at that waypoint; cannot combine with `TimeOfArrival` |
| `JerkLimit` | Scalar (m/s³) | Smooths transitions; cannot combine with `TimeOfArrival` |
| `ReferenceFrame` | `'NED'` or `'ENU'` | Sets coordinate convention |
| `AutoPitch` | `true`/`false` | Align pitch with velocity direction |
| `AutoBank` | `true`/`false` | Align roll to counteract centripetal force |
| `SampleRate` | Hz (default 100) | Irrelevant for radarScenario — scenario queries position at its own UpdateRate |

**Mutual exclusions (will error):**
- `TimeOfArrival` + `WaitTime`
- `TimeOfArrival` + `JerkLimit`
- `WaitTime` at a waypoint where `GroundSpeed > 0`

**Interpolation:** `waypointTrajectory` uses **piecewise cubic Hermite** interpolation between waypoints. With 2 collinear waypoints this is linear, but with turns the path will overshoot and curve smoothly through corners. Auto-derived velocities at intermediate waypoints create this smoothing. For strictly linear segments, use only 2 waypoints per straight leg (adding a waypoint at the corner creates overshoot).

## Scenario Duration — Critical Rule

**The scenario ends at `min(StopTime, max(all waypointTrajectory endpoints))`.**

- `StopTime` only **truncates** — it cannot extend the scenario past the last waypoint endpoint
- `kinematicTrajectory` (including stationary platforms via `'Position'`) does **NOT** extend scenario duration
- After a trajectory ends, `platform.Position` becomes `NaN` and the radar silently stops detecting it (no error)

This creates a **silent failure mode in multi-platform scenarios**: if one platform's trajectory is shorter than others, it "disappears" mid-simulation with no warning.

**Correct pattern for multi-platform scenarios:**

```matlab
% BAD: tgt1 disappears at t=10, scenario stops at t=10 even though StopTime=30
scene = radarScenario('UpdateRate', 1, 'StopTime', 30);
radarPlat = platform(scene, 'Position', [0 0 0]);  % kinematic — does NOT extend
tgt1 = platform(scene, 'Trajectory', waypointTrajectory( ...
    'Waypoints', [10000 0 -1000; 20000 0 -1000], ...
    'TimeOfArrival', [0; 10]));  % scenario ends at t=10!

% GOOD: extend trajectory to match StopTime
scene = radarScenario('UpdateRate', 1, 'StopTime', 30);
radarPlat = platform(scene, 'Position', [0 0 0]);
tgt1 = platform(scene, 'Trajectory', waypointTrajectory( ...
    'Waypoints', [10000 0 -1000; 20000 0 -1000; 20000 0 -1000], ...
    'TimeOfArrival', [0; 10; 30]));  % holds last position until t=30

% ALSO GOOD: use kinematicTrajectory for constant-velocity targets
tgt2 = platform(scene, 'Trajectory', kinematicTrajectory( ...
    'Position', [5000 0 -2000], 'Velocity', [500 0 0]));  % runs forever
```

**Rule:** Every `waypointTrajectory` in the scenario must have `TimeOfArrival(end) >= StopTime`. If a target "arrives" early, add a final hold waypoint: repeat the last position with `TimeOfArrival = StopTime`.

## kinematicTrajectory

```matlab
% Constant velocity (runs indefinitely)
tgt = platform(scene, 'Trajectory', kinematicTrajectory( ...
    'Position', [20000 0 -5000], ...
    'Velocity', [-250 0 0], ...
    'AccelerationSource', 'Property', ...
    'Acceleration', [0 0 0]));
```

| Property | Purpose | Notes |
|----------|---------|-------|
| `Position` | Initial [x,y,z] | Meters |
| `Velocity` | Initial velocity [vx,vy,vz] | m/s |
| `Acceleration` | Constant acceleration | Only when `AccelerationSource = 'Property'` |
| `AngularVelocity` | Rotation rate | Only when `AngularVelocitySource = 'Property'` |
| `AccelerationSource` | `'Input'` or `'Property'` | `'Input'` requires external driving; `'Property'` uses constant value |
| `AngularVelocitySource` | `'Input'` or `'Property'` | Same as above |

**Key difference from waypointTrajectory:** No predefined endpoint — runs indefinitely. Scenario continues until `StopTime` or explicit stop.

## geoTrajectory

```matlab
% Earth-centered scenario with geodetic waypoints
scene = radarScenario('IsEarthCentered', true);
tgt = platform(scene, 'Trajectory', geoTrajectory( ...
    'Waypoints', [42.36 -71.06 5000; 42.50 -70.80 5000], ...
    'TimeOfArrival', [0; 120], ...
    'AutoPitch', true));
```

| Property | Purpose | Notes |
|----------|---------|-------|
| `Waypoints` | N×3 [latitude, longitude, altitude] | deg, deg, meters |
| `TimeOfArrival` | N×1 arrival times (s) | `Inf` for single stationary waypoint |
| `Velocities` | N×3 in local NED/ENU | m/s |
| `Course` | N×1 heading from North (deg) | Alternative to `Velocities` |
| `GroundSpeed` | N×1 (m/s) | Alternative to `Velocities` |
| `ClimbRate` | N×1 (m/s) | Alternative to `Velocities` |
| `ReferenceFrame` | `'NED'` or `'ENU'` | For velocity/orientation interpretation |

**Outputs when called:** `[positionLLA, orientation, velocity, acceleration, angularVelocity, ecef2ref]`

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Single waypoint in `waypointTrajectory` | Error: "At least two waypoints must be specified" | Use `kinematicTrajectory` or `geoTrajectory` for stationary |
| `TimeOfArrival` + `WaitTime` | Error: "may not be specified together" | Use `GroundSpeed` instead of `TimeOfArrival` when using `WaitTime` |
| `TimeOfArrival` + `JerkLimit` | Error: "may not be specified together" | Use `GroundSpeed` instead of `TimeOfArrival` when using `JerkLimit` |
| `geoTrajectory` with `IsEarthCentered=false` | Error: "must be a geoTrajectory when IsEarthCentered is true" | Match trajectory type to scenario setting |
| `waypointTrajectory` with `IsEarthCentered=true` | Same error | Use `geoTrajectory` for earth-centered scenarios |
| Scenario stops unexpectedly | `advance()` returns `false` | `waypointTrajectory` ended — scenario stops at `min(StopTime, max(all waypointTrajectory endpoints))`. Fix: extend all trajectories to match desired duration, or use `kinematicTrajectory` for constant-velocity platforms |
| Platform disappears mid-simulation (NaN position) | No detections on a target after a certain time | Its `waypointTrajectory` ended before other platforms'. Add a hold waypoint: repeat final position with `TimeOfArrival = StopTime` |
| Duplicate waypoints error | "The first input must contain unique values" | Waypoint positions must differ (even slightly). For loiter/hold: offset by 0.01 m or use `WaitTime` with `GroundSpeed` form |
| `SampleRate` mismatch warnings | Trajectory SampleRate overridden | Don't set — scenario auto-sets `SampleRate` to its `UpdateRate` |
| Mixing `ReferenceFrame` across platforms | Silent position errors | Set all trajectories to same `ReferenceFrame` |

----

Copyright 2026 The MathWorks, Inc.

----