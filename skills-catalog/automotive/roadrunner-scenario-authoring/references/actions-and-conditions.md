# Actions and Conditions Catalog

## Actions (addAction)

### ChangeSpeedAction

| Property | Type | Default | Values |
|----------|------|---------|--------|
| Speed | numeric | 17.88 | m/s |
| SpeedReference | string | "absolute" | "absolute", "actor", "route-time-data" |
| ReferenceActor | object | [] | Vehicle/Character/MovableObject |
| Direction | string | "faster" | "faster", "slower", "same" |
| SamplingMode | string | "action-start" | "action-start", "continuous" |
| DynamicsDimension | string | "rate" | "rate", "time", "distance" |
| DynamicsShape | string | "cubic" | "cubic", "linear", "step", "sinusoidal" |
| DynamicsValue | numeric | — | positive scalar |

**Gotcha:** Initial phase auto-creates one ChangeSpeedAction. Modify `phase.Actions(1)` — do not add a second.

### ChangeLaneAction

| Property | Type | Default | Values |
|----------|------|---------|--------|
| LaneChangeReference | string | "lane" | "lane", "actor" |
| Direction | string | "left" | "left", "right", "same-lane" |
| NumLanesOffset | int | 1 | positive integer |
| ReferenceActor | object | [] | Vehicle/Character/MovableObject |
| DynamicsDimension | string | "distance" | "rate", "time", "distance" |
| DynamicsShape | string | "cubic" | "cubic", "linear", "step", "sinusoidal" |
| DynamicsValue | numeric | — | positive scalar |

**Constraint:** Actor must be in lane-following mode. Does not work with path/trajectory following.

### ChangeLateralOffsetAction

| Property | Type | Default | Values |
|----------|------|---------|--------|
| Direction | string | "left" | "left", "right", "center" |
| LateralOffset | numeric | — | positive scalar (meters) |
| DynamicsDimension | string | "time" | "time", "rate" |
| DynamicsShape | string | "cubic" | "cubic", "linear", "step", "sinusoidal" |
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

Removes actor from scenario during simulation.

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

**Note:** R2026a only. Not available in R2025b or earlier.

**Gotcha — Speed limits:** SynchronizeAction computes speed dynamically to reach the target point simultaneously with the reference actor. Without `HasTargetSpeed=true` and a reasonable `TargetSpeed`, the actor may accelerate to extreme speeds (50+ m/s). Always set `HasTargetSpeed=true` with a realistic speed limit.

**Gotcha — TargetPoint is initially a double, not a Point object.** You cannot use `anchorToPoint` on it until a valid Point is assigned. Also: assigning `actor.InitialPoint` directly creates a **shared reference** — modifying `ForwardOffset` on the TargetPoint will move the actor itself. Use independent Point objects (route waypoints) instead.

**Correct SynchronizeAction pattern:**
```matlab
% Actors MUST have routes (path-following mode) to provide independent Points
egoRoute = ego.InitialPoint.Route;
wp1 = addPoint(egoRoute, ego.InitialPoint.WorldPosition + [50 0 0]);
autoAnchor(wp1);
egoRoute.Segments(end).Freeform = false;

targetRoute = target.InitialPoint.Route;
wp2 = addPoint(targetRoute, target.InitialPoint.WorldPosition + [30 0 0]);
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

---

## Phase Types

| Type | Use for | Created with |
|------|---------|-------------|
| ActorActionPhase | Actor-specific behavior | `addPhaseInSerial/Parallel` |
| SystemActionPhase | System-level actions (WaitAction) | `addPhaseInSerial/Parallel` |
| ParallelPhase | Concurrent execution group | `addPhaseInParallel` |
| SerialPhase | Sequential group (auto-created) | Created when adding serial phases |

**ActorActionPhase limit:** Supports exactly ONE action (added via `addAction`). Only the auto-created initial phase (from `initialPhaseForActor`) can hold the default `ChangeSpeedAction` without an explicit `addAction` call. For multiple concurrent actions on the same actor, use a `ParallelPhase` parent with one `ActorActionPhase` child per action.

**Nesting rule:** SerialPhase CANNOT nest inside another SerialPhase. Use ParallelPhase as intermediate.

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

**CRITICAL — Never chain property assignment on `setEndCondition()`:**
```matlab
% WRONG — fails on ActorActionPhase (works only on InitialPhase):
setEndCondition(phase, "DurationCondition").Duration = 5;

% CORRECT — always use two lines (works on ALL phase types):
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
| "sinusoidal" | Sine-wave profile |

----

Copyright 2026 The MathWorks, Inc.

----
