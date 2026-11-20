# Actions and Conditions Catalog

## Actions (addAction)

**Only these actions can be authored from MATLAB (R2026b):** `ChangeSpeedAction`, `ChangeLaneAction`, `ChangeLateralOffsetAction`, `ChangeLongitudinalDistanceAction`, `SynchronizeAction`, `RemoveActorAction` (actor phases) and `WaitAction` (system phases). Other RoadRunner actions, such as Change Parameter and user-defined actions, are not registered: `addAction(phase, "ChangeParameterAction")` errors with "Object type 'ChangeParameterAction' is not registered." If a request needs one, tell the user it has to be added in the RoadRunner Scenario editor.

**Only these conditions can be authored from MATLAB (R2026b Update 2):** `ActorSpeedCondition`, `CollisionCondition`, `DistanceToActorCondition`, `DistanceToPointCondition`, `DurationCondition`, `LongitudinalDistanceToActorCondition`, `PhaseStateCondition`, `SimulationTimeCondition` and `StandStillCondition`.

**API limitations (verified R2026b Update 2: `roadrunner.api` has no classes for these).** When a request needs one of these, say so, offer the fallback, and state what the fallback does not do. Never substitute a different condition silently (for example a `DurationCondition` for a time-to-collision trigger):

| Not available from MATLAB | Fallback |
|---|---|
| Traffic signals: no signal-state condition and no signal action; the scene's lights run their own cycle, and the HD map has no stop-line objects | Scripted stop-and-go: `DistanceToPointCondition` to the approach lane's junction edge, then a wait (`StandStillCondition` or `DurationCondition`). Tell the user it is not linked to the real signal state |
| Other conditions: Time To Actor (time-to-collision), Lateral Distance to Actor, Global Parameter, user-defined events | Tell the user; add them in the RoadRunner Scenario editor |
| Other actions: Change Parameter, Change Global Parameter, user-defined actions | Add them in the RoadRunner Scenario editor |
| Scenario (global) parameters and environment settings (weather, time of day) | Set them in RoadRunner |
| Actor-type filters and OR conditions: `CollisionCondition` has only `FirstActor`/`SecondActor`; RootPhase holds one end and one fail condition | A specific actor pair; see `openscenario-analysis.md` for .xosc sources |
| Vehicle mass and performance (`VehicleAsset` holds geometry only) | Report the value as not representable |
| Real 3D vehicle models; behavior parameters such as `FollowGround` | A sized placeholder (`asset-catalog.md`); set the parameter in RoadRunner (`behaviors-and-parameters.md`) |

### ChangeSpeedAction

| Property | Type | Default | Values |
|----------|------|---------|--------|
| Speed | numeric | 17.88 | m/s |
| SpeedReference | string | "absolute" | "absolute", "actor", "route-time-data" |
| ReferenceActor | object | [] | Vehicle/Character/MovableObject |
| Direction | string | "faster" | "faster", "slower", "same" |
| SamplingMode | string | "action-start" | "action-start", "continuous" |
| DynamicsDimension | string | "rate" | "rate", "time", "distance" |
| DynamicsShape | string | "cubic" | "cubic", "linear", "step" |
| DynamicsValue | numeric | — | positive scalar |

**Gotcha:** Initial phase auto-creates one ChangeSpeedAction. Modify `phase.Actions(1)` — do not add a second.

**Launch / "0 to v in t seconds":** initial phase speed 0 with an end condition (how long it stands still), then a `ChangeSpeedAction` with `Speed = v`, `DynamicsDimension = "time"`, `DynamicsValue = t` and **`DynamicsShape = "linear"`** (equivalently `"rate"` with `DynamicsValue = v/t`). Verified in R2026b: 0 → 26.8 m/s in 1.9 s reached 26.5 m/s after 1.85 s at a steady 14.1 m/s². The built-in behavior applies **no acceleration cap**, so it will follow unrealistic values: sanity-check them and tell the user. With the default `"cubic"` shape the same launch peaks at 21.1 m/s² (1.5× the average), so use `"linear"` when a constant acceleration is intended.

```matlab
standPhase = initialPhaseForActor(phaseLogic, car); standPhase.Actions(1).Speed = 0;
c = setEndCondition(standPhase, "DurationCondition"); c.Duration = 1;     % stand for 1 s
launchPhase = addPhaseInSerial(phaseLogic, standPhase, "ActorActionPhase"); launchPhase.Actor = car;
launch = addAction(launchPhase, "ChangeSpeedAction"); launch.Speed = 26.8;
launch.DynamicsDimension = "time"; launch.DynamicsValue = 1.9; launch.DynamicsShape = "linear";
```

**`SpeedReference = "route-time-data"`** follows the times on the actor's route points, so the route needs `HasTime = true` and `Time` on its points. Without them `validate()` fails with "Change Speed Action: uses waypoint time data, but <name> Route has no assigned time data." (verified R2026b). See `routes-and-points.md` §Time-Based Trajectory.

### ChangeLaneAction

| Property | Type | Default | Values |
|----------|------|---------|--------|
| LaneChangeReference | string | "lane" | "lane", "actor" |
| Direction | string | "left" | "left", "right", "same-lane" |
| NumLanesOffset | int | 1 | positive integer |
| ReferenceActor | object | [] | Vehicle/Character/MovableObject |
| DynamicsDimension | string | "distance" | "rate", "time", "distance" |
| DynamicsShape | string | "cubic" | "cubic", "linear", "step" |
| DynamicsValue | numeric | — | positive scalar |

**Constraint:** Actor must be in lane-following mode. Does not work with path/trajectory following.

### ChangeLateralOffsetAction

| Property | Type | Default | Values |
|----------|------|---------|--------|
| Direction | string | "left" | "left", "right", "center" |
| LateralOffset | numeric | — | positive scalar (meters) |
| DynamicsDimension | string | "time" | "time", "rate" |
| DynamicsShape | string | "cubic" | "cubic", "linear", "step" |
| DynamicsValue | numeric | — | positive scalar |

### ChangeLongitudinalDistanceAction (Gap-Keeping)

| Property | Type | Default | Values |
|----------|------|---------|--------|
| ReferenceActor | object | [] | Vehicle/Character/MovableObject (REQUIRED) |
| RelativePosition | string | "behind" | "behind", "ahead", "either" |
| DistanceType | string | "space" | "space", "time" |
| DistanceOffset | numeric | 0 | meters (when "space") or seconds (when "time") |
| DistanceReference | string | "bounding-box" | "bounding-box", "origin" |
| SamplingMode | string | "action-start" | "action-start", "continuous" |
| ConstraintType | string | "asset" | "asset", "custom", "none" |
| MaxSpeed | numeric | — | m/s (only when ConstraintType="custom") |
| MaxAcceleration | numeric | — | m/s^2 (only when ConstraintType="custom") |
| MaxDeceleration | numeric | — | m/s^2 (only when ConstraintType="custom") |

**`DistanceType` usage:**
- `"space"` — maintain a spatial gap in meters (default)
- `"time"` — maintain a time-gap in seconds (e.g., 2s headway). Useful for synchronization and adaptive following.

**`ConstraintType` usage:**
- `"asset"` — use kinematic limits from the actor's asset (default, most realistic)
- `"custom"` — set explicit `MaxSpeed`, `MaxAcceleration`, `MaxDeceleration` limits
- `"none"` — no kinematic constraints (instant response, unrealistic but useful for testing)

**Time-gap following pattern:**
```matlab
gapAction = addAction(followPhase, "ChangeLongitudinalDistanceAction");
gapAction.ReferenceActor = leader;
gapAction.DistanceType = "time";       % time-gap mode
gapAction.DistanceOffset = 2.0;        % 2-second headway
gapAction.SamplingMode = "continuous";  % dynamic adjustment
gapAction.ConstraintType = "custom";   % explicit kinematic limits
gapAction.MaxAcceleration = 3.0;       % m/s^2
gapAction.MaxDeceleration = 5.0;       % m/s^2
```

### WaitAction

| Property | Type | Default |
|----------|------|---------|
| Name | string | "" |

Used in SystemActionPhase only. Actor holds current state.

### RemoveActorAction (R2026a)

Removes the phase's actor from the scenario during simulation. No properties to set: put it alone in an `ActorActionPhase` with `.Actor` set, after the phase it should follow. It only works for actors with the built-in RoadRunner behavior; Simulink, external and FMU behaviors raise a simulation error.

**R2026a or later only** (also `SynchronizeAction` and `setupCollision`). On R2025b or earlier the class does not exist and `addAction` errors. If the script must also run on an older release, guard it and tell the user the actor stays in the scenario there:

```matlab
rrRelease = extractBefore(string(rrApp.Version) + " ", " ");   % e.g. "R2026b"; the API comes from RoadRunner
if exist("roadrunner.api.RemoveActorAction", "class") == 8     % feature check; same result as rrRelease >= "R2026a"
    removePhase = addPhaseInSerial(phaseLogic, holdPhase, "ActorActionPhase");
    removePhase.Actor = lead;
    addAction(removePhase, "RemoveActorAction");
else
    warning("RemoveActorAction needs RoadRunner R2026a or later; %s keeps the actor in the scenario.", rrRelease);
end
```

### SynchronizeAction (R2026a)

| Property | Type | Default | Values |
|----------|------|---------|--------|
| TargetPoint | object | [] | Point |
| TargetThreshold | numeric | 0 | meters |
| HasTargetSpeed | logical | false | |
| TargetSpeed | numeric | 0 | m/s |
| SpeedReference | string | "absolute" | "absolute", "actor" |
| ReferenceActor | object | [] | Vehicle/Character/MovableObject |
| ReferenceActorTargetPoint | object | [] | Point |
| ReferenceActorTargetThreshold | numeric | 0 | meters |

**Note:** R2026a or later. Not available in R2025b or earlier — use the release check under RemoveActorAction.

**Gotcha — Speed limits:** SynchronizeAction computes speed dynamically to reach the target point simultaneously with the reference actor. Without `HasTargetSpeed=true` and a reasonable `TargetSpeed`, the actor may accelerate to extreme speeds (50+ m/s). Always set `HasTargetSpeed=true` with a realistic speed limit.

**Gotcha — TargetPoint is initially a double, not a Point object.** You cannot use `anchorToPoint` on it until a valid Point is assigned. Also: assigning `actor.InitialPoint` directly creates a **shared reference** — modifying `ForwardOffset` on the TargetPoint will move the actor itself. Use independent Point objects (route waypoints) instead.

**Correct SynchronizeAction pattern:**
```matlab
% Actors MUST have routes (path-following mode) to provide independent Points.
% Target points come from each actor's own lane in the HD map (egoLane/targetLane = the
% laneIdx used to place them), never from world-space offsets such as WorldPosition + [50 0 0].
egoRoute = ego.InitialPoint.Route;
wp1 = addPoint(egoRoute, helperGetPositionFromHDMap(sceneInfo.HDMap, egoLane, 0.7));
autoAnchor(wp1);
egoRoute.Segments(end).Freeform = false;

targetRoute = target.InitialPoint.Route;
wp2 = addPoint(targetRoute, helperGetPositionFromHDMap(sceneInfo.HDMap, targetLane, 0.6));
autoAnchor(wp2);
targetRoute.Segments(end).Freeform = false;

% Use route waypoints as TargetPoint (independent from actor position)
syncAction = addAction(syncPhase, "SynchronizeAction");
syncAction.TargetPoint = wp1;              % Independent point, NOT ego.InitialPoint
syncAction.ReferenceActor = target;
syncAction.ReferenceActorTargetPoint = wp2; % Independent point, NOT target.InitialPoint
syncAction.HasTargetSpeed = true;
syncAction.TargetSpeed = 15;               % Realistic speed limit
```

---

## Conditions (setEndCondition / setFailCondition)

### DurationCondition

| Property | Type | Values |
|----------|------|--------|
| Duration | numeric | seconds (from phase start) |

### SimulationTimeCondition

| Property | Type | Values |
|----------|------|--------|
| Time | numeric | absolute seconds from scenario start |

### LongitudinalDistanceToActorCondition

| Property | Type | Values |
|----------|------|--------|
| Actor | object | REQUIRED — the actor being monitored |
| ReferenceActor | object | the other actor |
| RelativePosition | string | "either", "ahead", "behind" |
| DistanceReference | string | "bounding-box", "origin" |
| MeasureDistance | string | "lane", "actor" |
| Distance | numeric | meters |
| Rule | string | **ONLY "le" or "ge"** |

**`MeasureDistance` usage:**
- `"lane"` — measures along the road curvature (lane s-coordinate)
- `"actor"` — measures along the actor's local forward direction

**Critical:** Trigger only fires if actors have different speeds. Equal speeds = constant gap = never triggers.

### DistanceToActorCondition

| Property | Type | Values |
|----------|------|--------|
| Actor | object | REQUIRED |
| ReferenceActor | object | REQUIRED |
| Distance | numeric | meters (Euclidean) |
| Rule | string | **ONLY "le" or "ge"** |

### DistanceToPointCondition

| Property | Type | Values |
|----------|------|--------|
| Actor | object | REQUIRED |
| Point | object | Point object |
| Distance | numeric | meters |
| PointHeight | numeric | Height above ground (default: 0.5 m) |
| Rule | string | **ONLY "le" or "ge"** |

### ActorSpeedCondition

| Property | Type | Values |
|----------|------|--------|
| Actor | object | REQUIRED |
| Speed | numeric | m/s |
| SpeedReference | string | "absolute", "actor" |
| ReferenceActor | object | Reference actor (when SpeedReference="actor") |
| Direction | string | "faster", "slower", "same" (relative direction) |
| SamplingMode | string | "action-start", "continuous" |
| Rule | string | "eq", "gt", "lt", "ge", "le", "ne" (full set) |

### CollisionCondition

| Property | Type | Values |
|----------|------|--------|
| FirstActor | object | [] or specific actor |
| SecondActor | object | [] or specific actor |

When both are [], any collision triggers. Set specific actors to monitor a pair.

### PhaseStateCondition

| Property | Type | Values |
|----------|------|--------|
| Phase | object | phase to monitor |
| PhaseState | string | "idle", "start", "run", "end" |

**`PhaseState` values:**
- `"idle"` — phase has not started yet
- `"start"` — phase's start conditions are being evaluated
- `"run"` — phase is actively running
- `"end"` — phase execution has ended or was skipped

### StandStillCondition

| Property | Type | Values |
|----------|------|--------|
| Actor | object | actor that must be stopped |
| Duration | numeric | seconds the actor has been stationary |

True once `Actor` has been at standstill for `Duration` seconds. Use it to end a "stop and wait" phase (for example a stop at a junction); `.Actor` is required, as for the other actor conditions.

---

## Phase Types

| Type | Use for | Created with |
|------|---------|-------------|
| ActorActionPhase | Actor-specific behavior | `addPhaseInSerial/Parallel` |
| SystemActionPhase | System-level actions (WaitAction) | `addPhaseInSerial/Parallel` |
| ParallelPhase | Concurrent execution group (auto-created wrapper) | Prefer the auto-created wrapper; fill one you create with `addPhase` — see note below |
| SerialPhase | Sequential group (auto-created) | Created when adding serial phases |

**ActorActionPhase limit:** Supports exactly ONE action (added via `addAction`). Only the auto-created initial phase (from `initialPhaseForActor`) can hold the default `ChangeSpeedAction` without an explicit `addAction` call. For multiple concurrent actions on the same actor, add the first `ActorActionPhase` in serial after the preceding phase, then add each additional concurrent `ActorActionPhase` in parallel *with the first* — the API auto-creates a `ParallelPhase` wrapper around them.

**Never fill an explicit `"ParallelPhase"` with `addPhaseInParallel`.** `addPhaseInSerial(phaseLogic, prevPhase, "ParallelPhase")` creates an empty container, and `addPhaseInParallel` on it adds siblings *next to* it inside a new wrapper. The wrapper ends up with 3 children instead of 2, one of them the empty container, which can't be removed (`delete` only clears the MATLAB handle). A container you create is filled with its own `addPhase(container, phaseType)`, which adds the phase as its last child (verified in R2026b). The simplest route is the auto-created wrapper:

```matlab
% WRONG — the container stays empty; the new phases land next to it in a new wrapper
wrongContainer = addPhaseInSerial(phaseLogic, initPhase, "ParallelPhase");
wrongPhase1 = addPhaseInParallel(phaseLogic, wrongContainer, "ActorActionPhase");
wrongPhase2 = addPhaseInParallel(phaseLogic, wrongContainer, "ActorActionPhase");
% Result: wrapper ParallelPhase with [<empty ParallelPhase>, wrongPhase1, wrongPhase2]

% ALSO CORRECT — fill the container you created with addPhase
parallelPhase = addPhaseInSerial(phaseLogic, initPhase, "ParallelPhase");
child1 = addPhase(parallelPhase, "ActorActionPhase");
child2 = addPhase(parallelPhase, "ActorActionPhase");
% Result: ParallelPhase with [child1, child2]

% CORRECT — no empty child; API wraps the two phases automatically
phase1 = addPhaseInSerial(phaseLogic, initPhase, "ActorActionPhase");
phase1.Actor = actor;
action1 = addAction(phase1, "ChangeLaneAction");
% ... set action1 properties

phase2 = addPhaseInParallel(phaseLogic, phase1, "ActorActionPhase");
phase2.Actor = actor;
action2 = addAction(phase2, "ChangeSpeedAction");
% ... set action2 properties
% Result: ParallelPhase with [phase1, phase2]
```

**Concurrent actions must control different axes.** Each actor has one longitudinal channel (`ChangeSpeedAction`, `ChangeLongitudinalDistanceAction`, `SynchronizeAction`) and one lateral channel (`ChangeLaneAction`, `ChangeLateralOffsetAction`). Two actions on the same channel for the same actor at the same time do not combine: the engine interrupts or skips one of them, so it is silently dropped. `validate()` still returns true. A lane change in parallel with a speed change is fine (verified).

Verified in R2026b simulation (lane change 3 s + 1 m lateral offset 3 s, in parallel on one car): the car followed the action in the phase added by `addPhaseInParallel` and ignored the one in the first phase, in either order. For "change lane and also shift toward the edge", run them **in serial**: put the lateral offset in a phase after the lane change, with no end condition on the lane-change phase so the offset starts when the lane change completes (verified: the full 1 m offset was applied in the new lane).

```matlab
lcPhase = addPhaseInSerial(phaseLogic, prevPhase, "ActorActionPhase"); lcPhase.Actor = actor;
lc = addAction(lcPhase, "ChangeLaneAction"); lc.Direction = "left";
lc.DynamicsDimension = "time"; lc.DynamicsValue = 3;
% No end condition on lcPhase: it ends when the lane change completes
offPhase = addPhaseInSerial(phaseLogic, lcPhase, "ActorActionPhase"); offPhase.Actor = actor;
off = addAction(offPhase, "ChangeLateralOffsetAction"); off.Direction = "left"; off.LateralOffset = 1;
off.DynamicsDimension = "time"; off.DynamicsValue = 2;
```

**Nesting rule:** SerialPhase CANNOT nest inside another SerialPhase (`addPhaseInSerial(..., "SerialPhase")` errors: "Serial phase cannot be a child of a serial phase"). To run a sequence alongside other phases, use a ParallelPhase as the intermediate and build inside it with `addPhase`: `seq = addPhase(parallelPhase, "SerialPhase"); step1 = addPhase(seq, "ActorActionPhase");` (builds and validates in R2026b).

**Phase insertion options:**
```matlab
% Insert BEFORE an existing phase (not just after)
prePhase = addPhaseInSerial(phaseLogic, existingPhase, "ActorActionPhase", Insertion="before");
prePhase.Actor = actor;
```

**Finding existing actions in a phase:**
```matlab
% Find all ChangeSpeedActions in a phase
speedActions = findActions(phase, "ChangeSpeedAction");
% Modify existing rather than adding duplicate
speedActions(1).Speed = 10;
```

---

## Condition Management

**Removing a condition:**
```matlab
cond = phase.EndCondition;
remove(cond);  % Phase now has no end condition
```

**Replacing a condition** (`setEndCondition` always overwrites any existing):
```matlab
newCond = setEndCondition(phase, "DurationCondition");
newCond.Duration = 5;
```

**CRITICAL — Never chain property assignment on the function form `setEndCondition(...)`:**
```matlab
% WRONG — MATLAB error on every phase type (initial, later and root phases; verified in R2026b):
% "Unable to use a value of type roadrunner.api.ActorActionPhase as an index."
setEndCondition(phase, "DurationCondition").Duration = 5;

% CORRECT — two lines (the dot form phase.setEndCondition("DurationCondition").Duration = 5 also works):
cond = setEndCondition(phase, "DurationCondition");
cond.Duration = 5;
```

---

## Actor Properties

| Property | Type | Description |
|----------|------|-------------|
| `actor.ActorID` | numeric | Unique actor identifier |
| `actor.Color` | [R G B] | Actor color (settable) |
| `actor.BehaviorAsset` | BehaviorAsset | Actor's behavior configuration |
| `actor.ActorAsset` | Asset object | The actor's source asset (read-only) |

For Point, Route, and RouteSegment properties, see `references/routes-and-points.md`.
For CollisionUtility, see `references/collision-utility.md`.

---

## Dynamics Configuration

Controls how actions transition (acceleration profile):

| DynamicsDimension | Unit | Meaning |
|-------------------|------|---------|
| "rate" | m/s^2 | Acceleration/deceleration rate |
| "time" | seconds | Duration of transition |
| "distance" | meters | Distance over which transition occurs |

| DynamicsShape | Profile |
|---------------|---------|
| "cubic" | Smooth S-curve (default) |
| "linear" | Constant rate |
| "step" | Instantaneous |

**`"sinusoidal"` is NOT supported.** Use only `"cubic"`, `"linear"`, or `"step"`. In R2026b, setting `"sinusoidal"` does not throw and `validate()` still returns true, but simulation then fails to start ("Scenario contains critical issues"; verified on `ChangeLateralOffsetAction`). `ChangeSpeedAction` silently stores it as `"linear"`. If a source scenario (e.g., an ALKS or Euro NCAP `.xosc`) specifies sinusoidal dynamics, use `"cubic"` as the closest S-curve approximation and note the substitution in the output.

----

Copyright 2026 The MathWorks, Inc.

----
