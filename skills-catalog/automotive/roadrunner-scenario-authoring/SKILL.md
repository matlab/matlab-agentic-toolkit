---
name: roadrunner-scenario-authoring
description: >
  Programmatically author RoadRunner scenarios from MATLAB using roadrunnerAPI.
  Use when adding actors, creating routes, building scenario logic (phases,
  conditions, actions), placing vehicles/pedestrians, defining cut-in/crossing/
  follow scenarios, or any programmatic scenario creation in RoadRunner.
  Triggers on: roadrunnerAPI, scenario authoring, add actor, create route,
  phase logic, cut-in scenario, pedestrian crossing, scenario from MATLAB.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# RoadRunner Scenario Authoring

Programmatically create RoadRunner scenarios from MATLAB: actors, routes, phase logic, and validation — all via `roadrunnerAPI`.

## When to Use

- Adding actors (vehicles, pedestrians, objects) to a RoadRunner scenario
- Creating routes and waypoints for actors
- Building scenario logic: phases, conditions, actions
- Authoring common patterns: cut-in, pedestrian crossing, lead-follow, emergency brake
- Placing actors on roads using anchor-based or HD Map positioning
- Validating scenario structure before simulation

## When NOT to Use

- Connecting to or launching RoadRunner → use `roadrunner-core`
- Building scenarios from recorded sensor data → use `matlab-scenario-builder`
- Authoring road geometry (lanes, junctions) → use `roadrunner-rrhd-authoring`
- Importing maps or scenes → use `roadrunner-import-scene`
- Simulating or exporting scenarios → use `roadrunner-scenario-simulating`

## Workflow

### 1. Ensure Session

Verify `rrApp` exists. If not, ensure RoadRunner is connected first (e.g., via `roadrunner-core` or manually).

```matlab
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    error("No active RoadRunner session. Use the roadrunner-core skill.");
end
```

**Path setup:** Before calling helper functions, ensure the scripts directory is on the MATLAB path:
```matlab
addpath('<path-to-skill>/scripts');
```

### 2. Initialize Scenario

```matlab
openScene(rrApp, sceneName);
newScenario(rrApp);
rrApi = roadrunnerAPI(rrApp);
rrs = rrApi.Scenario;
phaseLogic = rrs.PhaseLogic;
rrprj = rrApi.Project;
```

### 3. Scene Awareness

Before placing actors, survey the scene to find valid lane positions. Use the `helperSceneAwareness` script for automated analysis, or query manually via HD Map export:

```matlab
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in");
```

See `references/scene-awareness.md` for manual HD Map query patterns when the helper is unavailable.

### 4. Add Actors

**Option A — Batch placement** (recommended for 2+ actors):
```matlab
actorSpecs(1) = struct(Name="Ego", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=1, Fraction=0.1, Speed=15);
[actors, report] = helperPlaceActors(rrs, rrprj, phaseLogic, sceneInfo.HDMap, actorSpecs);
ego = actors{1};  % cell array — use curly braces
```

**Option B — Manual placement:**
```matlab
vehicleAsset = getAsset(rrprj, "Vehicles/Sedan.fbx", "VehicleAsset");
actor = addActor(rrs, vehicleAsset, position);
actor.Name = "Ego";
autoAnchor(actor.InitialPoint);  % Snaps to nearest road
```

**Post-placement check:** Verify `actor.InitialPoint.WorldPosition` is NOT `[0 0 0]`.

See `references/asset-catalog.md` for available vehicle/character paths.

### 5. Position Actors (Anchoring)

**Option A — Scene anchors available:**
```matlab
anchors = getAnchors(rrApp);
% Use remapAnchor for cross-scene portability (not findSceneAnchor)
anchorPt = findSceneAnchor(rrs, anchors(1).Name);
anchorToPoint(actor.InitialPoint, anchorPt);
actor.InitialPoint.ForwardOffset = 20;
actor.InitialPoint.LaneOffset = 1;
```

**Option B — No scene anchors (use autoAnchor):**
```matlab
actor = addActor(rrs, asset, approximatePosition);
autoAnchor(actor.InitialPoint);  % Must be within 5m of road
```

**Option C — Relative to another actor:**
```matlab
anchorToPoint(target.InitialPoint, ego.InitialPoint);
target.InitialPoint.ForwardOffset = 30;
target.InitialPoint.LaneOffset = 1;
```

### 6. Create Routes (When Needed)

Routes put actors in **path-following mode**. Actors without routes drive in **lane-following mode** along their anchored lane.

```matlab
route = actor.InitialPoint.Route;
fwdPt = addPoint(route, actor.InitialPoint.WorldPosition + [20 0 0]);
autoAnchor(fwdPt);
% For vehicles: disable freeform so route follows road surface
% (Do NOT do this for pedestrians — they need freeform to cross roads)
for i = 1:numel(route.Segments)
    route.Segments(i).Freeform = false;
end
```

**When to add routes:**
- Character/pedestrian actors — ALWAYS required (validation fails without them)
- Vehicles that follow a specific path (e.g., ego driving straight)
- Vehicles that do NOT need `ChangeLaneAction`

**When NOT to add routes:**
- Vehicles that need `ChangeLaneAction` — they MUST be in lane-following mode (no routes)
- Vehicles that need `ChangeLateralOffsetAction` — same requirement

**Route point rules:**
- Always use `autoAnchor` for route points — position must be within 5m of road
- Do NOT use `anchorToPoint` + `ForwardOffset` on route points — causes validation failure
- Keep route offset small (20m) to stay on the road
- For junction turns: use multiple waypoints (pre-junction, post-junction, exit) for smooth path
- After adding route points, set `seg.Freeform = false` on each segment to follow road geometry (freeform routes ignore road surface and may float above/below the road)

### 7. Build Phase Logic

See `references/actions-and-conditions.md` for the complete catalog.

```matlab
% Get actor's initial phase (auto-created with addActor)
initPhase = initialPhaseForActor(phaseLogic, actor);

% Modify default speed (initial phase already has ChangeSpeedAction)
initPhase.Actions(1).Speed = 20;

% Add sequential phase
nextPhase = addPhaseInSerial(phaseLogic, initPhase, "ActorActionPhase");
nextPhase.Actor = actor;  % REQUIRED — never omit

% Set trigger condition on initial phase
cond = setEndCondition(initPhase, "LongitudinalDistanceToActorCondition");
cond.Actor = actor;           % REQUIRED
cond.ReferenceActor = otherActor;
cond.Distance = 10;

% Add action to next phase
action = addAction(nextPhase, "ChangeLaneAction");
action.Direction = "left";
```

**Multi-actor phase logic:** Each actor's phase chain is independent. Any phase that has a subsequent phase MUST have an end condition — without one, the phase runs indefinitely and subsequent phases never execute. For multi-actor scenarios, ensure EVERY phase with a successor has an appropriate end condition set via `setEndCondition`.

### 8. Validate and Report

```matlab
validate(rrs);
```

After validation passes, present a summary of what was created — never simulate unless explicitly asked.

## Scenario Decomposition

**MANDATORY: Before writing ANY code, complete Steps 0–1 below and present your plan to the user for confirmation.** Do not skip this — scenarios built without pre-analysis frequently fail due to wrong timing, missed collisions, or impossible trigger conditions.

**Step 0 — Clarify intent:** If the user's prompt is ambiguous about ANY of the following, ASK before proceeding:
- Number and types of actors
- Desired outcome (collision, near-miss, safe completion?)
- Speeds, distances, or timing not specified
- Which actor is "ego" vs "target"
- Scene to use (if not stated)

**Step 1 — Physics-first design (REQUIRED for timed interactions):** For collisions, near-misses, cut-ins, pedestrian crossings, and any scenario where actors must arrive at the same point at a specific time — you MUST derive kinematic parameters before writing code. Follow the full 5-step process in `references/physics-first-design.md`:
1. Parse intent into timeline
2. Measure spatial parameters (query HD Map)
3. Build parameter derivation table (show your math)
4. Verify conditions will trigger
5. Write code with derived values

**Present your decomposition to the user** — show actors, placement, speeds, trigger timing, and expected outcome. Get confirmation before executing code.

1. **Actors** — How many, what types (vehicle/pedestrian/object), what roles (ego, target, background, stationary)
2. **Placement geometry** — Determines which `helperSceneAwareness` type to use:
   - **Same lane** (`ScenarioType="following"`) — leader/follower, overtake start, emergency brake
   - **Adjacent lanes** (`ScenarioType="cut-in"`) — lane changes, merges, parallel driving
   - **Crossing paths** — pedestrian crossing, intersection conflicts
3. **Interaction intent** — Determines speed/separation/trigger defaults:
   - **Conflict/near-miss:** Close proximity, speed differential, tests reaction (small gap, distance triggers)
   - **Cooperative:** Safe completion expected, no collision (large gap ≥ 30m, time or duration triggers)
   - **Independent:** Actors don't interact directly (background traffic, stationary objects)
4. **Maneuver sequence** — Identify each distinct behavior change as a phase: drive → lane change → brake → resume. Each transition needs a trigger condition.
5. **Trigger selection:**
   - Distance-based (`LongitudinalDistanceToActorCondition`) — requires speed differential between actors
   - Time-based (`DurationCondition`) — works regardless of speeds, simpler
   - Simulation time (`SimulationTimeCondition`) — absolute time, good for choreographed sequences
6. **Safety validation** — Before executing, verify lane-change scenarios won't collide: `required_gap = lane_change_distance + closing_rate × (lane_change_distance / actor_speed) + 5m`

## Scenario Defaults (auto-created by RoadRunner)

When `newScenario()` is called, RoadRunner automatically creates:
- A **CollisionCondition** as the root phase's fail condition (any actor-to-actor collision fails the scenario)
- A **SimulationTimeCondition** (60s) as the root phase's end condition

Do NOT duplicate these. To modify the default collision condition:
```matlab
rootPhase = phaseLogic.RootPhase;
% The fail condition already exists — access it directly
% To change the end time:
rootEndCond = setEndCondition(rootPhase, "SimulationTimeCondition");
rootEndCond.Time = 30;  % Override default 60s
```

## Hard Constraints

1. **Always set `.Actor`** on ActorActionPhase and condition objects — never omit
2. **Never add duplicate action types** to a single phase — modify `phase.Actions(1)` instead
3. **Character actors require routes** — without them validation fails
4. **`autoAnchor` requires proximity** — point must be within 5m of road surface
5. **Distance condition rules** — ONLY `"le"` and `"ge"` are valid (not `"lt"`, `"gt"`)
6. **Speed condition rules** — full set: `"eq"`, `"gt"`, `"lt"`, `"ge"`, `"le"`, `"ne"`
7. **SerialPhase cannot nest in SerialPhase** — use ParallelPhase as intermediate
8. **Distance triggers need speed difference** — if actors travel at same speed, gap never changes
9. **Never simulate unless user explicitly asks** — authoring and simulation are separate workflows. Never claim scenario outcomes (collision, near-miss) based on math alone — only simulation produces ground truth
10. **Never assume — always clarify ambiguous prompts** — if user doesn't specify speeds, distances, timing, actor count, desired outcome (collision vs near-miss vs safe), or scene, ASK before writing code. Present your scenario decomposition and physics analysis to the user for confirmation before executing. Guessing leads to scenarios that validate but produce wrong outcomes.
11. **`setEndCondition` not `addEndCondition`** — only one end condition per phase
12. **`ChangeLaneAction` requires lane-following mode** — do NOT add routes to actors that need lane changes
13. **Do NOT use `anchorToPoint` + `ForwardOffset` on route points** — causes validation failure; use `autoAnchor` only
14. **`LaneOffset` can land on junction connectors** — for lane-change scenarios, place actors on verified parallel lanes using HD Map positions + `autoAnchor` instead of `LaneOffset`
15. **Never guess lane change direction** — use `LaneChangeReference="actor"` + `Direction="same-lane"` when targeting another actor's lane, or compute direction via cross product (see `references/scenario-templates.md`)
16. **Parallel group end condition** goes on `.ParentPhase`, not on child phases
17. **Verify WorldPosition after placement** — `[0 0 0]` means anchoring failed silently
18. **No actor removal API** — `removeActor` does not exist; `WorldPosition` is read-only after anchoring. Placement mistakes require `newScenario()` and rebuilding. Plan placement carefully before executing.
19. **`autoAnchor` unreliable at lane boundaries** — Use fraction ≥ 0.2 and ≤ 0.8 when querying HD Map positions. At lane start/end points, multiple lanes converge and `autoAnchor` may snap to the wrong lane.
20. **Lane-change safety margin** — For lane changes, ensure longitudinal separation exceeds: `lane_change_distance + (closing_rate × maneuver_time) + vehicle_length`. A 20m lane change at 5 m/s closing rate needs ≥ 30m initial gap.
21. **Vehicle route segments default to freeform** — after adding waypoints for vehicles, set `seg.Freeform = false` on each segment so the route follows road geometry. Do NOT disable freeform on pedestrian routes — pedestrians cross roads and need freeform paths.
22. **Path-following actors have no collision physics** — vehicles in path-following mode (with routes) pass through each other. RoadRunner detects collision when bumpers reach ≤50mm proximity, then terminates the scenario. Design collision timing using bumper-to-bumper distance, not center-to-center.
23. **Collision gap formula** — use bumper gap, not center gap: `bumper_gap = center_distance - (vehicle1_length/2 + vehicle2_length/2)`. Timing: `t_collision = bumper_gap / closing_rate`. Account for ~1s acceleration ramp from rest (vehicles don't reach target speed instantly).
24. **Head-on collisions not supported** — `LaneOffset` must be positive; you cannot place two vehicles facing each other on the same road segment via the programmatic API. Use rear-end or crossing-path collision designs instead.
25. **Initial separation must exceed trigger distance** — if actors start closer than the trigger condition's distance threshold, the condition fires immediately and phases advance before intended.
26. **Never chain property assignment on `setEndCondition`** — `setEndCondition(phase,"Type").Property = N` fails on `ActorActionPhase` (works only on `InitialPhase`). Always store the result first: `c = setEndCondition(phase, "Type"); c.Property = N;`. This two-line pattern works on ALL phase types.
27. **One action per `ActorActionPhase`** — call `addAction` only once per phase. The auto-created initial phase (from `initialPhaseForActor`) is the only exception. For concurrent actions, use a `ParallelPhase` with one `ActorActionPhase` child per action.
28. **Never use world-space offsets for actor placement** — `egoPos + [X, Y, 0]` only works on world-axis-aligned roads. For pedestrians and crossing actors, always use `helperGetPositionFromHDMap` to get position and heading, then compute the perpendicular crossing direction: `hdg2D = hdg(1:2)/norm(hdg(1:2)); perpDir = [-hdg2D(2), hdg2D(1), 0];`
29. **Junction scenes: do NOT route across intersection arms** — on `FourWaySignal`, `FourWayStop`, and `T_Intersection`, approach lanes do not connect to opposing exit lanes via the routing API. Use single-arm routes (approach → connected exit lane in the same corridor) or lane-following mode only. Cross-arm routes fail `validate`.
30. **Do not over-filter lane length** — for `helperSceneAwareness` the parameter is `MinLaneLength` (default 30); for `helperSurveyLanes`/`helperGetPositionFromHDMap` use `MinLength`. On intersection scenes use 30 since approach lanes are short. Compute needed length: `max_speed × scenario_duration + 20m`. Using 80+ on small scenes leaves fewer lanes than expected.

## Common Wrong Property Names

| Wrong (hallucinated) | Correct |
|---------------------|---------|
| `RelativeLaneOffset` | `NumLanesOffset` |
| `SimulationTime` | `SimulationTimeCondition` |
| `addEndCondition` | `setEndCondition` |
| `listAssets` / `getAssets` | `getAsset(proj, path, type)` |
| `getActors` / `listActors` | `rrs.Actors` |
| `actor.Speed` | `initPhase.Actions(1).Speed` |
| `route.addWaypoint` | `addPoint(route, position)` |
| `removeActor` / `deleteActor` | Does not exist — use `newScenario()` |
| `actor.WorldPosition = ...` | Read-only — reposition via `newScenario()` + re-place |
| `cond.Comparison` | Does not exist on `SimulationTimeCondition` (just set `.Time`) |
| `rrApp.ProjectFolder` | Not a public property — use `status(rrApp)` |
| `DistanceType = "gap"` | Use `"space"` (spatial) or `"time"` (time-gap) |
| `ConstraintType = "acceleration"` | Use `"asset"`, `"custom"`, or `"none"` |
| `PhaseState = "completed"` | Use `"end"` (valid: `"idle"`, `"start"`, `"run"`, `"end"`) |
| `MeasureDistance = "euclidean"` | Use `"lane"` or `"actor"` |
| `"MovableObjects/..."` | Use `"Props/TrafficControl/..."` with `"MovableObjectAsset"` type |
| `syncAction.TargetPoint = actor.InitialPoint` | Shared reference trap — use route waypoints as independent Points |
| `LateralOffsetAction` | `ChangeLateralOffsetAction` (full name required) |
| `.Offset` (on ChangeLateralOffsetAction) | `.LateralOffset` |
| `laneTable.LaneIndex` | `laneTable.Index` (column name from `helperSurveyLanes`) |
| `action.Rate` | Use `.DynamicsDimension = "rate"; .DynamicsValue = N;` |
| `setEndCondition(...).Property = N` | `c = setEndCondition(...); c.Property = N;` (two-line pattern) |
| `MinLength` (on helperSceneAwareness) | `MinLaneLength` — only lower-level helpers use `MinLength` |
| `"text" + status(rrApp)` | `status(rrApp)` returns a struct — use `s = status(rrApp); s.Scene.Filename` |
| `actors(i)` from helperPlaceActors | `actors{i}` — returns a cell array, use curly-brace indexing |

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `roadrunnerAPI(rrApp)` | Create authoring API handle | R2025a |
| `addActor(rrs, asset, pos)` | Add actor to scenario | R2025a |
| `getAsset(proj, path, type)` | Load asset by path | R2025a |
| `autoAnchor(point)` | Snap point to nearest road | R2025a |
| `anchorToPoint(pt, anchor)` | Anchor point to reference | R2025a |
| `addPoint(route, pos)` | Add waypoint to route | R2025a |
| `initialPhaseForActor(logic, actor)` | Get actor's init phase | R2025a |
| `addPhaseInSerial(logic, phase, type)` | Add sequential phase | R2025a |
| `addPhaseInParallel(logic, phase, type)` | Add concurrent phase | R2025a |
| `setEndCondition(phase, type)` | Set phase trigger | R2025a |
| `addAction(phase, type)` | Add behavior action | R2025a |
| `validate(rrs)` | Check scenario validity | R2025a |
| `validate(rrs, ObjectRoot=obj)` | Validate specific object (phase, actor, route) | R2025a |
| `findActions(phase, type)` | Find actions of a type in a phase | R2025a |
| `createAsset(proj, path, type)` | Create new asset (vehicle, character, behavior) | R2025a |
| `getAnchors(rrApp)` | List scene anchors | R2024a |
| `getAsset` with `"CharacterAsset"` | Load pedestrian asset | R2025a |

## Actor Movement Modes

| Mode | Trigger | Behavior | Compatible Actions |
|------|---------|----------|-------------------|
| **Lane-following** | No route waypoints | Follows anchored lane at set speed | `ChangeLaneAction`, `ChangeLateralOffsetAction` |
| **Path-following** | Has route waypoints | Follows waypoint path | `ChangeSpeedAction`, `ChangeLongitudinalDistanceAction` |

- Vehicles with speed set but NO routes drive along their lane automatically
- `ChangeLaneAction` ONLY works in lane-following mode (no routes)
- Character/pedestrian actors ALWAYS need routes (validation fails without them)

## Conventions

- **Coordinate system:** Z-up, world-space positions as `[X Y Z]`
- **Asset paths:** Use exact relative path from project Assets folder (e.g., `"Vehicles/Sedan.fbx"`)
- **File suffixes:** Disk shows `.fbx_rrx`, API uses `.fbx`; disk shows `.rrchar_rrx`, API uses `.rrchar`
- **Speed units:** Always meters per second (m/s)
- **Actor naming:** Use descriptive names (`"Ego"`, `"TargetVehicle"`, `"Pedestrian1"`)
- **Default scene:** `ScenarioBasic.rrscene` (310 forward lanes, ScenarioStart anchor)
- **Intersection scenes:** `FourWaySignal`, `FourWayStop`, `T_Intersection`
- **User clarification (MANDATORY):** Before writing code, present your scenario plan (actors, placement, speeds, timing, expected outcome) and get user confirmation. If ANY parameter is ambiguous, ask — never guess. This is the single most important convention for avoiding rework.

## Scripts

Deploy these helpers into the user's MATLAB path for automated scene analysis and batch placement. They depend on each other: `helperSceneAwareness` calls `helperSurveyLanes` and `helperGetPositionFromHDMap`.

| Script | Purpose | When to use |
|--------|---------|-------------|
| `scripts/helperSceneAwareness.m` | Export HD Map, survey lanes, classify road features, recommend placements | First step before placing actors — provides positions, lane context, and feature classification |
| `scripts/helperSurveyLanes.m` | Filter/sort lanes by type, direction, length | When you need lane geometry data without full scene analysis |
| `scripts/helperGetPositionFromHDMap.m` | Arc-length interpolation along lanes, nearest-point queries | When you need precise positions at specific fractions along a lane |
| `scripts/helperPlaceActors.m` | Batch place, anchor, set speed, verify multiple actors | When placing 2+ actors — automates the manual add/anchor/verify loop |
| `scripts/helperClassifyRoadFeatures.m` | Elevation-based road feature classification (bridge, ground, ramp) | Used internally by helperSceneAwareness; call directly for custom feature queries |

**Usage pattern:**
```matlab
% 1. Run scene awareness to get lane data and recommended positions
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in");

% 2. Define actor specs (do NOT pre-initialize with actorSpecs=[])
actorSpecs(1) = struct(Name="Ego", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=1, Fraction=0.1, Speed=15);
actorSpecs(2) = struct(Name="Target", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=2, Fraction=0.2, Speed=20);

% 3. Batch place and verify (actors is a cell array)
[actors, report] = helperPlaceActors(rrs, rrprj, phaseLogic, sceneInfo.HDMap, actorSpecs);
assert(report.AllValid, "Placement failed: " + report.Summary);
ego = actors{1}; target = actors{2};  % curly braces required
```

### Scene Feature Awareness

For scenes with multiple elevation levels (bridges, overpasses, underpasses), use the `RoadFeature` parameter to target a specific road structure:

```matlab
% Place actors specifically on the bridge deck
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="following", ...
    RoadFeature="bridge");

% LaneIndex=1 now refers to the longest BRIDGE lane, not the longest overall lane
actorSpecs(1) = struct(Name="Leader", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=1, Fraction=0.3, Speed=15, ...
    FilterLaneIDs=sceneInfo.FilteredLaneIDs);
```

**Available feature labels:** `"bridge"`, `"ground"`, `"ramp"`, `"overpass"`

**When to use `RoadFeature`:**
- User mentions "on the bridge", "under the bridge", "on the ramp", "on the overpass"
- Scene has multiple elevation levels (Bridge, highway interchanges)
- Default placement picks the wrong road level (actor at unexpected elevation)

**When `RoadFeature=""` (default):** The summary shows all detected features so you can ask the user which one they mean:
```
Road features detected:
  bridge: 10 lanes, total 700m, connected path 192m, elevation 7.9-8.6m
  ground: 3 lanes, total 490m, connected path 165m, elevation 2.4-2.8m
```

**Output fields for feature-aware placement:**
- `sceneInfo.RoadFeatures` — full feature classification struct
- `sceneInfo.FilteredLaneIDs` — lane IDs matching the requested feature (pass to `actorSpecs.FilterLaneIDs`)
- `sceneInfo.LaneNetwork` — full lane connectivity from `helperAnalyzeHDMapLanes`

## Built-in RoadRunner Helpers

RoadRunner ships example helpers at `<RoadRunner-Install>/Tools/MATLAB/api/scenario/common` (e.g., `helperAddCutInAndSlowCar`, `helperAddPedestrian`). These use `anchorToPoint` + `LaneOffset` for actor placement.

**When built-in helpers are suitable:** Simple scenes with clearly separated lanes (straight roads, known layouts).

**When to prefer this skill's approach instead:** Scenes with junctions, complex layouts, or unknown geometry — `LaneOffset` can land actors on junction connectors that don't support lane changes. HD Map positions + `autoAnchor` works reliably on any scene.

**Key pattern from built-in helpers:** `ChangeLaneAction` supports `LaneChangeReference="actor"` with `Direction="same-lane"` — the actor moves to the reference actor's lane automatically, eliminating cross-product direction computation. See `references/scenario-templates.md` Cut-In section for usage.

## References

- `references/actions-and-conditions.md` — Complete catalog of all action types, condition types, their properties and valid values. Consult when building phase logic.
- `references/routes-and-points.md` — Full Point properties, RouteSegment configuration, time-based trajectories, and route read-only properties. Consult for precise positioning, trajectory timing, or curve configuration.
- `references/collision-utility.md` — CollisionUtility configuration for collision analysis between specific actor pairs. Consult when setting up collision monitoring.
- `references/asset-catalog.md` — Available vehicle and character asset paths with naming conventions. Consult when adding actors.
- `references/scene-awareness.md` — HD Map export pattern for querying lane geometry when helperSceneAwareness is unavailable. Consult when placing actors on unknown scenes.
- `references/lane-connectivity.md` — Lane network topology, road feature classification, and connected path queries. Consult when placing actors on specific road features (bridge, ramp) or when you need lane connectivity information.
- `references/scenario-templates.md` — Tested code patterns for cut-in, pedestrian crossing, lead-follow, emergency brake. Consult when building specific scenario types.
- `references/physics-first-design.md` — Pre-authoring kinematic analysis: derive speeds, gaps, and timing before writing code. Consult for collision/near-miss/timed-interaction scenarios.

----

Copyright 2026 The MathWorks, Inc.

----
