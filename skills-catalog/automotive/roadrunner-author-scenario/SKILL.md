---
name: roadrunner-author-scenario
description: >
  Create and edit RoadRunner scenarios in MATLAB with roadrunnerAPI: add actors,
  routes and phase logic, validate and repair a scenario, or recreate an
  OpenSCENARIO 1.x (.xosc) file as an editable scenario. Use when building a
  RoadRunner scenario from a description (cut-in, pedestrian crossing,
  lead-follow and similar), fixing one that fails validation, or rebuilding,
  recreating or converting a .xosc file in MATLAB. Do NOT use when the user says
  "import" a .xosc file — call importScenario instead. Not for exporting to
  OpenSCENARIO, simulation (use roadrunner-simulate-scenario), recorded sensor
  data (use matlab-use-scenario-builder), Euro NCAP protocol tests (use
  matlab-use-ncap-protocol), drivingScenario/Driving Scenario Designer
  scenarios, or OpenSCENARIO 2.x (.osc) files.
  Triggers on: roadrunnerAPI, RoadRunner scenario authoring, add actor, create
  route, phase logic, cut-in scenario, pedestrian crossing, scenario from
  MATLAB, OpenSCENARIO, xosc to MATLAB, recreate xosc.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# RoadRunner Scenario Authoring

Programmatically create RoadRunner scenarios from MATLAB: actors, routes, phase logic, and validation — all via `roadrunnerAPI`. Build from a user description, or recreate an OpenSCENARIO 1.x (.xosc) file.

## When to Use

- Adding actors (vehicles, pedestrians, objects) to a RoadRunner scenario
- Creating routes and waypoints for actors
- Building scenario logic: phases, conditions, actions
- Authoring common patterns: cut-in, pedestrian crossing, lead-follow, emergency brake
- Placing actors on roads using anchor-based or HD Map positioning
- Validating scenario structure before simulation
- Recreating a .xosc file programmatically ("build this .xosc", "convert this xosc to MATLAB") → see [From OpenSCENARIO](#from-openscenario-xosc)

## When NOT to Use

- Connecting to or launching RoadRunner, or only opening, saving or listing projects, scenes or scenarios → use `roadrunner-manage-project`
- Building or reconstructing scenarios from recorded sensor data (GPS, camera, lidar, actor tracks, drive logs), or extracting cut-in/near-miss events from recordings → use `matlab-use-scenario-builder`
- Generating protocol-defined Euro NCAP test scenarios or variants (CCRs, CCRm, CCRb, CPNA, CPFA, …) or NCAP scoring → use `matlab-use-ncap-protocol`
- Authoring road geometry (lanes, junctions) → use `roadrunner-build-rrhd-map`
- Importing a map or scene on its own (.rrhd, .xodr, HERE, TomTom) → use `roadrunner-build-rrhd-map` (the .xodr a .xosc references is imported by this skill, with `noprojection`)
- Simulating scenarios → use `roadrunner-simulate-scenario`
- User says "import" a .xosc file → call `importScenario(rrApp, xoscPath, "OpenSCENARIO XML")` directly; do not rebuild it
- Exporting a scenario TO OpenSCENARIO (.xosc) → call `exportScenario(rrApp, "scenario.xosc", "OpenSCENARIO XML")` directly
- `drivingScenario` objects or Driving Scenario Designer sessions (Automated Driving Toolbox, not RoadRunner)
- OpenSCENARIO 2.x (.osc) files: this skill reads OpenSCENARIO 1.x (.xosc) only

## Workflow

### 0. Plan the Scenario (before any code)

**Clarify, then proceed (the one rule on confirmation):** complete this step before writing code — scenarios built without pre-analysis fail on timing, missed collisions or triggers that never fire. If the request is fully specified (actors, scene, speeds, distances or timing, intended outcome) or the user says not to wait, state the plan in two or three lines and proceed, reporting your judgment calls. If something outcome-defining is missing or contradictory, ask only about that and wait for the answer.

**Check intent:** actors and roles (ego/target), desired outcome (collision, near-miss, safe completion), speeds, distances or timing, scene.

**Physics first (required for timed interactions):** follow `references/physics-first-design.md`: timeline → measure the scene (HD map) → derivation table → verify every trigger can fire → code.
- **Placement:** same lane (`ScenarioType="following"`), adjacent lanes (`"cut-in"`), crossing paths (`"crossing"`).
- **Triggers:** distance triggers need a speed difference (#8) and a starting separation beyond the trigger distance, or they fire at t = 0; duration and simulation-time triggers work at any speed.
- **Safety:** keep actors apart unless a collision is intended: `required_gap = maneuver_distance + closing_rate × maneuver_time + 5 m` (about one car length).

### 1. Ensure Session (BLOCKING — do NOT proceed without rrApp)

If `rrApp` does not exist or is invalid, you MUST invoke the `roadrunner-manage-project` skill (it runs `rrAppInitialize`). Never call `roadrunner`, `roadrunner(ProjectFolder=...)` or `roadrunner.connect()` yourself — that creates duplicate RoadRunner instances. Set `skillDir` to the folder that contains this SKILL.md.

```matlab
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    error("roadrunnerAuthorScenario:NoSession", ...
        "STOP: rrApp is missing. Invoke the roadrunner-manage-project skill now.");
end
addpath(fullfile(skillDir, "scripts"));   % helper functions (references/helper-scripts.md)
```

**Release check:** `RemoveActorAction`, `SynchronizeAction` and `setupCollision` need RoadRunner R2026a or later, and `setActorWorldAnglesDegrees` (source headings in .xosc recreations) R2026b Update 1; the API comes from the connected RoadRunner (`rrApp.Version`). If the user's release, or one the script must also run on, is older, guard them with `exist("roadrunner.api.RemoveActorAction", "class") == 8` or use an alternative, and tell the user (`references/actions-and-conditions.md` §RemoveActorAction).

### 2. Initialize Scenario

`openScene` and `newScenario` discard an unsaved scenario without asking (verified in R2026b). Once, before your first call in the task, check `s = status(rrApp)`: if `isstruct(s.Scenario) && s.Scenario.UnsavedChanges`, the user has unsaved work, so ask whether to save it (`saveScenario`) or discard it, and wait for the answer. Never decide yourself, even if the changes look like leftovers from earlier work. Your own build script can re-run freely.

```matlab
openScene(rrApp, sceneName);
newScenario(rrApp);
rrApi = roadrunnerAPI(rrApp);
rrs = rrApi.Scenario;
phaseLogic = rrs.PhaseLogic;
rrprj = rrApi.Project;
```

### 3. Scene Awareness

Survey the scene for valid lane positions before placing actors (manual HD Map queries: `references/scene-awareness.md`):

```matlab
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in");
```

### 4. Add Actors

```matlab
% 2+ actors: batch place, anchor, set speed and verify
actorSpecs(1) = struct(Name="Ego", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=1, Fraction=0.2, Speed=15);
[actors, report] = helperPlaceActors(rrs, rrprj, phaseLogic, sceneInfo.HDMap, actorSpecs);
ego = actors{1};  % cell array — use curly braces

% Single actor
actor = addActor(rrs, getAsset(rrprj, "Vehicles/Sedan.fbx", "VehicleAsset"), position);
actor.Name = "Ego";
autoAnchor(actor.InitialPoint);  % snaps to the lane centre
shift = norm(actor.InitialPoint.WorldPosition(1:2) - position(1:2));   % > 0.5 m = jumped lanes (#19)
```

Asset paths, props, and vehicles not in the catalog: `references/asset-catalog.md`.

### 5. Position Actors (Anchoring)

```matlab
% Scene anchor: findSceneAnchor returns the point (remapAnchor instead moves an existing scenario anchor)
anchors = getAnchors(rrApp);
anchorPt = findSceneAnchor(rrs, anchors(1).Name);
anchorToPoint(actor.InitialPoint, anchorPt);
actor.InitialPoint.ForwardOffset = 20;
actor.InitialPoint.LaneOffset = 1;

% Relative to another actor
anchorToPoint(target.InitialPoint, ego.InitialPoint);
target.InitialPoint.ForwardOffset = 30;
```

Without scene anchors, `autoAnchor` an HD-map position (within 5 m of the road).

### 6. Create Routes (When Needed)

Routes put actors in **path-following mode**; actors without routes drive in **lane-following mode** along their lane.

```matlab
route = actor.InitialPoint.Route;
% Waypoint further along the actor's own lane (same laneIdx as placement; fraction 0.2-0.8)
fwdPt = addPoint(route, helperGetPositionFromHDMap(sceneInfo.HDMap, laneIdx, 0.6));
autoAnchor(fwdPt, PosePreservation="reset-pose");
for i = 1:numel(route.Segments)
    route.Segments(i).Freeform = false;   % road-following vehicles follow the road surface
end
```

- **Routes required:** characters/pedestrians (always), vehicles that follow a specific path.
- **No routes:** actors that need `ChangeLaneAction` or `ChangeLateralOffsetAction` (lane-following only).
- **Route points:** `autoAnchor` on HD-map positions, never `anchorToPoint` + `ForwardOffset` (it discards the computed position). Junction turns: several waypoints along one connected arm.
- **`Freeform = true`** only for pedestrians, off-road or airborne segments, and an oncoming car driving against its lane (`references/routes-and-points.md`).
- **Arrival at a set time:** `HasTime`/`Time` on waypoints (`references/routes-and-points.md` §Time-Based Trajectory).

### 7. Build Phase Logic

Full action and condition catalog, and what cannot be authored from MATLAB (traffic signals, time-to-collision and parameter conditions, environment) with the fallback to offer: `references/actions-and-conditions.md`.

```matlab
initPhase = initialPhaseForActor(phaseLogic, actor);   % auto-created; already has a ChangeSpeedAction
initPhase.Actions(1).Speed = 20;

nextPhase = addPhaseInSerial(phaseLogic, initPhase, "ActorActionPhase");
nextPhase.Actor = actor;  % REQUIRED — never omit

cond = setEndCondition(initPhase, "LongitudinalDistanceToActorCondition");   % trigger
cond.Actor = actor;           % REQUIRED
cond.ReferenceActor = otherActor;
cond.Distance = 10;

action = addAction(nextPhase, "ChangeLaneAction");
action.Direction = "left";
```

**When does a phase end?** Each actor's phase chain is independent. With an end condition, a phase ends when the condition becomes true. Without one, it ends when its action completes (verified in R2026b simulation):
- **Initial phase:** ends almost immediately (~0.2 s). Give it an end condition if the next phase should wait.
- **Finishing action** (absolute speed change, lane change, lateral offset, `SamplingMode="action-start"`): ends at the goal. For "A, then B once A is done", leave A's end condition empty.
- **Continuous action** (speed or longitudinal distance with `SamplingMode="continuous"`): never ends, so the next phase never starts unless it has an end condition. `validate()` does not flag this.

### 8. Validate and Report

Run `helperCheckScenarioStructure(rrs)` first: it flags mistakes `validate()` misses. `validate` returns `true` or **throws**; in R2026b Update 2 the per-object diagnostics are attached as `ME.cause`, not in `ME.message` (earlier releases throw `datamodelapi:datamodeltreeservice:callMethodError` with no causes). Never call it bare:

```matlab
try
    isValid = validate(rrs);
catch ME
    if ~ismember(ME.identifier, ["roadrunner:scenario:ValidationFailed" "datamodelapi:datamodeltreeservice:callMethodError"])
        rethrow(ME);   % genuine API/runtime error
    end
    if isempty(ME.cause)
        fprintf("  %s\n", ME.message);   % before R2026b Update 2: only the summary
    end
    for i = 1:numel(ME.cause)
        fprintf("  %s\n", ME.cause{i}.message);   % one diagnostic per cause
    end
end
```

Fix each cause and re-validate until it returns `true`; when a fix isn't safe (e.g. a missing asset), ask the user. In a .xosc recreation, use the stand-in asset for a missing one instead and state the substitution (`references/asset-catalog.md`). Messages and fixes: `references/validation-diagnostics.md`. `validate(rrs, ShowWarnings=true)` also surfaces non-blocking diagnostics.

Write the final build code to a `.m` script in the working folder and run it from there, so the user can rerun and review it. Then summarize what was built — **never simulate unless explicitly asked** — and label every timing, gap or collision outcome you state as **calculated, not simulated** (only a simulation confirms it). **Save** only when asked or given a name: `saveScenario(rrApp, "Name")` writes `<project>/Scenarios/Name.rrscenario` and silently overwrites, so check `isfile` first and report the path from `status(rrApp).Scenario.Filename`. A scene created with `newScene` or a road import has no file yet, and `saveScenario` fails ("Scene has no file path") until you save it with `saveScene(rrApp, "Name")`; check `isfile` for the scene too.

### 9. Next Steps (Post-Authoring)

| User asks to... | Invoke | Entry point |
|-----------------|--------|-------------|
| "Simulate" / "Run it" / "Log trajectories" | `roadrunner-simulate-scenario` skill | `createSimulation(rrApp)` |
| "Export to OpenSCENARIO" | API directly | `exportScenario(rrApp, "scenario.xosc", "OpenSCENARIO XML")` |

Do NOT call simulation or log APIs yourself — invoke `roadrunner-simulate-scenario`.

## From OpenSCENARIO (.xosc)

Recreate a .xosc file as a RoadRunner scenario built with this skill. Follow `references/openscenario-analysis.md` for the full procedure; `references/openscenario-mapping.md` maps XOSC types to RoadRunner types.

**Critical rules (full text in the reference):**
1. Never fabricate actions or conditions not in the source — skip and warn.
2. Never propose workarounds (e.g., DurationCondition for an unsupported TimeToCollisionCondition).
3. Never simplify or duplicate trajectory vertices — extract exactly what is in the source. A vertex is a duplicate only if it repeats the previous position in an untimed trajectory, or repeats both position and time in a timed one; a timed stop (same position, different time) keeps both points.
4. Never guess scenes — import the .xodr named in `<LogicFile>`.
5. Never convert relative references to absolute (`RelativeTargetSpeed delta=-8` → `SpeedReference="actor"`, `Direction="slower"`, `Speed=8`).
6. Never omit unsupported features silently — list them under "Unsupported Constructs."
7. Describe intent, not XOSC structure — collapse MW_WaitAction placeholder Acts into end conditions.

**Step 1 — Analyze (no MATLAB code yet):** validate the XML; resolve parameters, expressions, and CatalogReferences; translate Init positions to world [x, y, z] with `scripts/xoscPositionToWorld.p` (**pass position values as numbers** — wrap each XML attribute in `str2double()`; `roadId` also works as text, but `laneId`, `s`, `t` or `offset` as text error or silently give a position tens of metres off); describe Story intent and serial/parallel topology. Fill in the Scenario Description (`assets/scenario-description-template.md`) and **wait for user approval**.

**Step 2 — Build:** do Workflow step 2's unsaved-work check first (`newScene` also discards an unsaved scenario); then `newScene(rrApp)`, import the .xodr with `openDriveImportOptions` `ProjectionMode="noprojection"`, `newScenario(rrApp)`, and create the handles from Workflow step 2 (`rrApi`, `rrs`, `phaseLogic`, `rrprj`) without its `openScene`/`newScenario`, which would replace the imported road. Then run Workflow steps 3–8 using the approved description as the plan. Anchoring: lane-following actors autoAnchor, including on junction connector roads; path-following actors and their route waypoints are NOT autoAnchored; MiscObjects (props) are NOT autoAnchored — anchoring discards the source's lateral offset. To keep a source lane offset on a lane-following actor, `autoAnchor` it first, then set `actor.InitialPoint.LateralOffset = -offset` (source +0.5 → −0.5); set before `autoAnchor`, it is lost and can move the actor.

**Key mappings:** anchored actors align with the lane; unanchored actors (MiscObjects, path-following actors) keep the default 90° heading unless you set the source heading with `setActorWorldAnglesDegrees(actor.InitialPoint, rad2deg(h), 0, 0)`; `FollowTrajectoryAction`/`AssignRouteAction` are supported only when their trigger chain resolves to t=0; `AddEntityAction` actors get a `WaitAction` in a `SystemActionPhase` as their first phase, with speed set on the following phase; actors with `ChangeLaneAction` or `ChangeLateralOffsetAction` must be lane-following (no route).

## Scenario Defaults (auto-created by RoadRunner)

`newScenario()` creates a root fail condition (`CollisionCondition`: any actor-to-actor collision fails) and a root end condition (`SimulationTimeCondition`, 60 s). Edit them in place; never add duplicates:

```matlab
rootPhase = phaseLogic.RootPhase;
failCond = rootPhase.FailCondition;   % setFailCondition would replace it and drop any actor pair
failCond.FirstActor = ego;            % fail only on this pair (verified in R2026b simulation)
failCond.SecondActor = truck;
rootEndCond = setEndCondition(rootPhase, "SimulationTimeCondition");
rootEndCond.Time = 30;
```

**Collision analysis** (`rrs.CollisionUtility` + `roadrunner.extensions.setupCollision(rrApp, rrApi, rrSim)`) inserts Wait actions so actors meet at chosen collision points; it needs intersecting routes (no lane-following) and at most 2 phases per actor. **Before ever calling `setupCollision`:** run the geometry pre-check in `references/collision-utility.md` — rear-end and head-on are not supported, so time those with the bumper-gap calculation and tell the user — and check that `matlabshared.supportpkg.getInstalled` lists the Euro NCAP Test Suite (without it the call opens an installer).

## Hard Constraints

1. **Always set `.Actor`** on ActorActionPhase and condition objects.
2. **Never add a duplicate action type** to a phase — modify `phase.Actions(1)` instead.
3. **Character actors require routes.**
4. **`autoAnchor` requires proximity** — within 5 m of the road surface.
5. **Distance-condition `Rule`** is `"le"` or `"ge"` only.
8. **Distance triggers need a speed difference** — equal speeds never close the gap.
9. **Never simulate unless the user explicitly asks**, and never claim outcomes (collision, near-miss) from math alone.
10. **Never guess outcome-defining parameters** (Workflow step 0).
11. **`setEndCondition`, not `addEndCondition`** — one end condition per phase.
12. **`ChangeLaneAction` and `ChangeLateralOffsetAction` need lane-following mode** — no routes on those actors.
14. **`LaneOffset` can land on junction connectors** — put lane-change actors on HD-map parallel lanes with `autoAnchor`.
18. **No actor removal API** — `WorldPosition` is read-only after anchoring; rebuild with `newScenario()`.
19. **`autoAnchor` jumps lanes at lane-piece ends** — use fractions 0.2–0.8 of a piece (also along chained pieces), check each shift (> 0.5 m = wrong lane) and that no two actors overlap; `validate()` does not catch overlaps. **Never probe positions by moving an anchored point and re-calling `autoAnchor` in a loop** — it freezes RoadRunner R2026b within a few calls; query the HD map instead.
26. **Never chain the function form `setEndCondition(phase, "Type").Prop = N`** — MATLAB errors on every phase type (it can't assign into a function result). Use `c = setEndCondition(phase, "Type"); c.Prop = N;` (the dot form `phase.setEndCondition("Type").Prop = N` also works).
27. **One action per `ActorActionPhase`.** Concurrent actions: first phase in serial, the others via `addPhaseInParallel(phaseLogic, firstPhase, "ActorActionPhase")`. They must control **different axes**: two lateral or two longitudinal actions at once silently drop one — run those in serial.
37. **Never call `addPhaseInParallel` on a `"ParallelPhase"` you created** — it adds siblings next to it, leaving it empty, and it can't be removed. Prefer #27 (the API adds the wrapper); fill a container you created with its own `addPhase(container, "ActorActionPhase")`.
38. **`DynamicsShape = "sinusoidal"`** validates but breaks simulation — use `"cubic"` (closest S-curve) and tell the user.

Full list (#6–7, #13, #15–17, #20–25, #28–36), violation outcomes and recovery: `references/common-mistakes.md`. Key functions, frequent wrong property names and movement modes: `references/api-quick-reference.md`.

## Conventions

- **Units and axes:** m/s; Z-up world positions `[X Y Z]`.
- **Asset paths:** relative to the project Assets folder; the API uses `.fbx`/`.rrchar` where disk shows `.fbx_rrx`/`.rrchar_rrx`.
- **Scenes:** use the scene the user names. If they name none, use the scene already open in RoadRunner (`status(rrApp).Scene.Filename`); if none is open, use `ScenarioBasic.rrscene` (339 short HD-map driving lane pieces, only 35 ≥ 30 m; ScenarioStart anchor). Say which scene you used. Intersections: `FourWaySignal`, `FourWayStop`, `T_Intersection` (`references/scene-awareness.md`).
- **Names:** descriptive (`"Ego"`, `"TargetVehicle"`, `"Pedestrian1"`).

## Scripts

Helpers in `scripts/` (on the path from Step 1); table and usage example in `references/helper-scripts.md`:
- `helperSceneAwareness` — HD map, lane survey, road features and placement recommendations. Multi-level scenes: `RoadFeature="bridge"` (or `"ground"`, `"ramp"`, `"overpass"`), then `FilterLaneIDs=sceneInfo.FilteredLaneIDs` in `actorSpecs`.
- `helperPlaceActors` — batch place, anchor, set speed and verify (returns a cell array).
- `helperGetPositionFromHDMap`, `helperSurveyLanes` — positions along lanes; lane filtering.
- `helperCheckScenarioStructure` — flags silent structural mistakes; run before `validate`.
- `xoscPositionToWorld.p` — .xosc positions to world coordinates (position values as numbers; `roadId` may be text).

## References

- `references/actions-and-conditions.md` — all actions and conditions, properties, valid values
- `references/routes-and-points.md` — points, route segments, time-based and airborne paths
- `references/physics-first-design.md` — derive speeds, gaps and timing before coding
- `references/validation-diagnostics.md` — `validate()` contract, messages and fixes
- `references/common-mistakes.md` — full constraint list, wrong names, recovery patterns
- `references/api-quick-reference.md` — key functions, frequent wrong names, movement modes
- `references/helper-scripts.md` — helper table and usage pattern
- `references/scene-awareness.md` — scene catalog and manual HD Map queries
- `references/lane-connectivity.md` — lane network, road features, connected paths
- `references/asset-catalog.md` — vehicle, character and prop paths; stand-in vehicles
- `references/collision-utility.md` — collision analysis setup and limits
- `references/behaviors-and-parameters.md` — behavior assets, and what the API cannot do
- `assets/scenario-templates.md` — tested cut-in, crossing, lead-follow, emergency-brake patterns
- `assets/scenario-description-template.md` — fillable Scenario Description for .xosc recreations
- `references/openscenario-analysis.md`, `references/openscenario-mapping.md` — .xosc procedure and type mapping

----

Copyright 2026 The MathWorks, Inc.

----
