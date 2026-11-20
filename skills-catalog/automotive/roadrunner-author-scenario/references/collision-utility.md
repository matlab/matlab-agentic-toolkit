# Collision Utility Reference

Programmatic representation of the Collision Authoring Tool from RoadRunner Scenario. Use `CollisionUtility` to specify collision point locations between two vehicle actors, then run collision analysis to automatically adjust scenario timing so the collision occurs at the specified points during simulation.

Access via `rrs.CollisionUtility`.

**Required products:** Automated Driving Toolbox R2026a + Automated Driving Toolbox Test Suite for Euro NCAP Protocols support package.

**Check both before calling `setupCollision`**, in this order: (1) the geometry pre-check below — rear-end and head-on are not supported; (2) the support package. Without the package, `setupCollision` does not error cleanly: it opens a support-package installer window for the user (observed in R2026b). Filling in `CollisionUtility` properties is harmless either way.

```matlab
pkgs = matlabshared.supportpkg.getInstalled;
hasNcapSuite = ~isempty(pkgs) && any(contains(string({pkgs.Name}), "Euro NCAP"));
if ~hasNcapSuite
    % Do not call setupCollision: tell the user the support package is needed, and time the collision by hand
end
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `Actor1` | Vehicle | Ego actor for collision |
| `Actor2` | Vehicle | Target actor for collision |
| `Actor1CoordinateSystem` | string | Collision point coordinate system for ego actor |
| `Actor2CoordinateSystem` | string | Collision point coordinate system for target actor |
| `Actor1CollisionPoint` | numeric scalar | Normalized bounding box location [0, 4) for ego |
| `Actor2CollisionPoint` | numeric scalar | Normalized bounding box location [0, 4) for target |
| `Actor1CollisionPointOffset` | [x, y] | Collision point offset from ego actor origin |
| `Actor2CollisionPointOffset` | [x, y] | Collision point offset from target actor origin |
| `Result` | string scalar | Collision analysis result (read-only, populated after `setupCollision`) |
| `SimulatedActor1CollisionPoint` | [x y z] | World coordinate of ego collision point after simulation (read-only) |
| `SimulatedActor2CollisionPoint` | [x y z] | World coordinate of target collision point after simulation (read-only) |
| `SimulatedCollisionPointDistance` | numeric | Distance in meters between collision points after simulation (read-only) |

## CollisionPointCoordinateSystem Enum

| Value | Description |
|-------|-------------|
| `"normalizedcollisionpoint"` | Normalized 2D coordinates [0-4) relative to actor bounding box (default). Uses `ActorNCollisionPoint`, ignores `ActorNCollisionPointOffset`. |
| `"vehicleoriginoffset"` | 2D offset vector [x, y] from actor local origin. Uses `ActorNCollisionPointOffset`, ignores `ActorNCollisionPoint`. |

## Normalized Collision Point Reference

The bounding box perimeter is parameterized from 0 to 4. A value of **0 corresponds to the front-right corner**, and values increase **counterclockwise** relative to the forward direction of the actor (viewing from above):

```
         Front
   1.0 ─────────── 0.0
    |   ←─────────  |
    |               |     → Actor forward direction
    |   ─────────→  |
   2.0 ─────────── 3.0
         Rear
```

| Value | Location |
|-------|----------|
| `0.0` | Front-right corner |
| `0.5` | Front center |
| `1.0` | Front-left corner |
| `1.5` | Left center |
| `2.0` | Rear-left corner |
| `2.5` | Rear center |
| `3.0` | Rear-right corner |
| `3.5` | Right center |

Values between represent interpolated positions along edges.

## Pre-Check: Is CollisionUtility Compatible?

**MANDATORY — run this check BEFORE configuring CollisionUtility.** If geometry is incompatible, `setupCollision` will error with: *"The combination of given trajectories and the collision point does not coincide."*

| Scenario Geometry | Relative Heading | Compatible? | Alternative |
|-------------------|-----------------|-------------|-------------|
| **Crossing / T-bone** | 10°–170° | YES | — |
| **Rear-end** (same direction) | < 10° | NO | Same-lane + speed differential, use `physics-first-design.md` |
| **Head-on** (opposing) | > 170° | NO | Not supported by API (constraint #24) |
| **Same-lane following** | 0° | NO | Lane-following mode + distance triggers |

**Decision rule:** If both actors travel in the same direction on the same road corridor (rear-end, follow, overtake), CollisionUtility CANNOT work. Use manual collision timing: `t_collision = bumper_gap / closing_rate`.

**Relative heading check:**
```matlab
relAngle = acosd(abs(dot(hdg1(1:2)/norm(hdg1(1:2)), hdg2(1:2)/norm(hdg2(1:2)))));
% relAngle < 10° → same direction (incompatible)
% relAngle > 80° → good crossing angle
```

**For intersection collision scenarios:** Use `helperSceneAwareness(rrApp, NumActors=2, ScenarioType="crossing")` to automatically find two approach lanes on different arms with crossing routes through the junction. Place actors on approach lanes, add route waypoints on exit lanes — RoadRunner routes through junction connectors automatically.

## Collision Scenario Workflow

### Step 1 — Add vehicle actors with intersecting routes

Both actors must have defined paths (routes) that intersect at least one point. Lane-following mode is NOT supported.

```matlab
mySedan = getAsset(rrprj, "Vehicles/Sedan.fbx", "VehicleAsset");
car1 = addActor(rrs, mySedan, [0.4 -2 0]);
car2 = addActor(rrs, mySedan, [11.5 17 0]);

rrRoute1 = car1.InitialPoint.Route;
rrRoute2 = car2.InitialPoint.Route;
rrPoint1 = addPoint(rrRoute1, [31 -5 0]);
rrPoint2 = addPoint(rrRoute2, [9 -21 0]);
```

### Step 2 — Configure CollisionUtility

Specify which actors collide and where on each vehicle the impact occurs.

```matlab
collisionUtil = rrs.CollisionUtility;
collisionUtil.Actor1 = car1;
collisionUtil.Actor2 = car2;

collisionUtil.Actor1CoordinateSystem = "normalizedcollisionpoint";
collisionUtil.Actor2CoordinateSystem = "normalizedcollisionpoint";
collisionUtil.Actor1CollisionPoint = 1;    % Front-left corner of ego
collisionUtil.Actor2CollisionPoint = 0;    % Front-right corner of target
```

### Step 3 — Run collision analysis

The analysis computes timing adjustments (Wait actions) so actors arrive at the collision point simultaneously.

```matlab
rrSim = createSimulation(rrApp);
collisionResults = roadrunner.extensions.setupCollision(rrApp, rrApi, rrSim);
```

### Step 4 — Read results

```matlab
collisionResults = collisionUtil.Result;
```

### Step 5 — Simulate

```matlab
set(rrSim, "SimulationCommand", "Start");
```

After simulation, read:
- `collisionUtil.SimulatedActor1CollisionPoint` — world position of ego impact point
- `collisionUtil.SimulatedActor2CollisionPoint` — world position of target impact point
- `collisionUtil.SimulatedCollisionPointDistance` — distance between points (0 = contact)

## Result Property Contents

After running `setupCollision`, `collisionUtil.Result` contains:

**Collision Analysis Results:**

| Field | Description |
|-------|-------------|
| Collision Point | Location on the actor where the collision occurs |
| Collision Time | Simulation time (seconds) when collision occurs |
| Waiting Actor ID | ID of the actor that must wait to achieve accurate timing |
| Wait Time | Duration (seconds) the waiting actor should wait |
| Recommended StepSize | Suggested simulation step size for accurate timing |

**Per-actor fields (at point of collision):**

| Field | Description |
|-------|-------------|
| Actor ID | Unique ID for the actor |
| Travelled Distance | Distance traveled until reaching collision point |
| Position | Position of actor in scene at collision |
| Speed | Speed of actor at time of collision |
| Heading | Heading of actor at point of collision |

## Limitations

1. Supports only **two actors** at a time
2. Supports only **Wait action + Duration condition** preceding the Initialize Speed action (very restricted phase logic)
3. Both actors **must have routes that intersect** — lane-following mode NOT supported
4. Both actors must have **speed > 0** — static actors not supported
5. **No elevation differences** — z-axis values of actors and waypoints must match
6. **Banked/superelevated roads** may cause inaccurate results
7. Supports at most **two logic phases** per actor
8. **No head-on collisions** — actors with heading at 0 or 180 degrees relative to each other are not supported
9. **Fixed-step solver** — reduce Step Size to the Recommended StepSize from results for accuracy
10. **No attachments** — actors with trailers not supported
11. **Re-run after changes** — modifying the scenario after analysis invalidates results; must run `setupCollision` again

## When to Use CollisionUtility

**Use CollisionUtility + `setupCollision` when:**
- You need precise, automatic collision timing between two actors
- The scenario is simple (two actors, routes that intersect, minimal phase logic)
- You want RoadRunner to compute Wait actions and timing adjustments automatically

**Use manual speed/gap design instead when:**
- The scenario has complex phase logic (>2 phases per actor)
- Actors use lane-following mode (no routes)
- More than two actors are involved in the collision sequence
- You need head-on collision geometry
- Actors are at different elevations

For manual collision scenarios, derive timing using `references/physics-first-design.md` and design phase logic to achieve the collision through speed differentials and trigger conditions.

## Relationship to CollisionCondition

| Feature | CollisionCondition | CollisionUtility |
|---------|-------------------|-----------------|
| Purpose | Trigger phase end/scenario fail | Configure and analyze precise collision timing |
| When used | Phase logic (any scenario) | Dedicated collision scenarios with `setupCollision` |
| Output | Boolean (collision happened) | Timing, positions, distances, wait durations |
| Set via | `setEndCondition` / `setFailCondition` | Direct property assignment + `setupCollision` |
| Actor limit | Any number | Exactly two |
| Mode requirement | Any | Path-following (routes) only |

----

Copyright 2026 The MathWorks, Inc.

----
