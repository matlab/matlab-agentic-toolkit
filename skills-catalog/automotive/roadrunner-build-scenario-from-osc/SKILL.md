---
name: roadrunner-build-scenario-from-osc
description: >
  Build a RoadRunner Scenario programmatically from an OpenSCENARIO 1.x (.xosc)
  file using the `roadrunner-scenario-authoring` skill. Use when the user wants
  to recreate a scenario from a .xosc file, interpret an OpenSCENARIO file and
  build it programmatically, reconstruct a .xosc as a RoadRunner scenario,
  generate a MATLAB script from a .xosc file, or convert an OpenSCENARIO file
  to MATLAB code. Do NOT use when the user says "import" a .xosc file — that
  means they want RoadRunner's built-in importScenario API, not programmatic
  reconstruction. Handles position translation (LanePosition and RoadPosition
  to world coordinates), construct mapping, relative references, trajectory/route
  handling, parameter expressions, catalog references, and phase logic topology.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Build RoadRunner Scenario from OpenSCENARIO

Interpret an OpenSCENARIO 1.x (.xosc) file and recreate the scenario in
RoadRunner using the `roadrunner-scenario-authoring` skill. Translates positions,
maps constructs, preserves relative references, and builds correct phase logic.

## When to Use

- User has a .xosc file and wants to recreate it in RoadRunner
- User wants to programmatically build a scenario from OpenSCENARIO
- User says "build this .xosc in RoadRunner" or "recreate this scenario"
- User has an OpenSCENARIO file from a partner or standards body (e.g., Euro NCAP, ALKS)
- User wants to generate a MATLAB script from a .xosc file
- User says "convert this xosc to matlab" or "recreate with a matlab script"

## When NOT to Use

- User says "import" a .xosc file — they want `importScenario(rrApp, xoscPath)`, not this skill. Simply call the API directly.
- User wants to use RoadRunner's built-in `importScenario` (let them — it works for simple cases)
- User wants to create a scenario from scratch **without** a .xosc file (use `roadrunner-scenario-authoring`)
- User wants to export a scenario TO OpenSCENARIO (use `roadrunner-export-scenario`)

## Critical Rules

1. **Never fabricate actions or conditions not present in the source XOSC.**
   If a construct cannot be mapped, skip it and warn the user.

2. **Never propose workarounds.** Do not replace DistanceToPointCondition with
   DurationCondition, do not substitute SimulationTimeCondition for unsupported
   triggers, do not add any construct not in the source.

3. **Never simplify or duplicate trajectory vertices.** Extract exactly the
   polyline vertices present in the source XOSC — no fewer, no more. Do not
   reduce 90 vertices to 5. Do not duplicate start/end points during extraction.

4. **Never guess scenes.** Only report the .xodr filename from `<LogicFile>`.
   Import it — do not search for a scene with a similar name.

5. **Never convert relative references to absolute.** If the source uses
   `RelativeTargetSpeed delta=-8`, preserve it as `SpeedReference="actor"` with
   `Direction="slower"`, `Speed=8`. Do not compute and hardcode `7 m/s`.

6. **Never omit unsupported features silently.** Always flag them explicitly in
   the Scenario Description under "Unsupported Constructs."

7. **Describe intent, not XOSC structure.** Collapse placeholder Acts
   (MW_WaitAction) into end conditions. Do not create phases for scaffolding
   elements that have no meaningful actor actions.

## Workflow

This skill operates in two steps. Complete Step 1 first, present the description
to the user for review, then proceed to Step 2 only after approval.

---

### Step 1: Analyze the .xosc and Produce a Scenario Description

Parse the .xosc and its referenced .xodr following this strict logical order.

#### 1a. Validate the input

Read the .xosc XML. If the file is invalid XML, missing required elements, or
fails basic structural checks, **stop and report the error**. Do not guess or
assume missing data. If data is ambiguous, state the assumption explicitly.

#### 1b. Resolve parameters, expressions, and catalogs

Before interpreting any values, resolve all references:

- **ParameterDeclarations / VariableDeclarations**: Evaluate `${...}` expressions
  to concrete numeric values. Process in declaration order (later params may
  reference earlier ones).
- **CatalogReferences**: Read the referenced catalog XML file (from
  `<CatalogLocations>`), find the entry by `catalogName` + `entryName`, extract
  the vehicle/pedestrian definition (model3d path, category, bounding box).

```matlab
% Parameter expression resolution example
params.HostSpeed_kph = 80;
params.LeadTime_s = 6;
params.hostSpeed_ms = params.HostSpeed_kph / 3.6;        % 22.2222
params.leadSpeed_ms = params.hostSpeed_ms * 0.5;         % 11.1111
params.initSeparation = (params.hostSpeed_ms + params.leadSpeed_ms) * params.LeadTime_s; % 200
```

#### 1c. Describe the Init phase

For each actor's Private actions in `<Init>`:

1. **TeleportAction** — convert position to world [x, y, z]:
   - WorldPosition: use directly
   - LanePosition: translate using .xodr (see `scripts/xoscPositionToWorld.p`)
   - RoadPosition: translate using .xodr (see `scripts/xoscPositionToWorld.p`)
   - **CRITICAL: All parameters to `xoscPositionToWorld` MUST be numeric.**
     XML attributes are always strings — convert with `str2double()` before calling:
     ```matlab
     pos = xoscPositionToWorld(xodrPath, 'LanePosition', ...
         'roadId', str2double(roadId), 'laneId', str2double(laneId), ...
         's', str2double(s), 'offset', str2double(offset));
     ```
     Passing strings silently produces wrong coordinates (up to 12m error).
   - RelativeObjectPosition: rotate dx/dy by entity heading, add to base position
   - RelativeRoadPosition: inverse-lookup base entity road coords, offset s/t
   - RelativeLanePosition: inverse-lookup base lane, compute target lane + s
     (skip center lane when dLane crosses from negative to positive IDs)
   - Process entities in dependency order: resolve reference entities first

2. **Heading** — The RoadRunner API does not support setting actor orientation.
   Actors always align with road direction at their anchor point. Do NOT include
   heading in the scenario description — it cannot be applied.
   Note: The `h` attribute from XOSC is still needed for RelativeObjectPosition
   translation (to rotate dx/dy in the entity's local frame), but it is not set
   on the placed actor.

3. **SpeedAction** — record the speed value and whether it is absolute or relative.
   For relative: describe as `<abs(delta)> m/s <direction> relative to <ref actor>`
   where direction is "slower" (delta < 0), "faster" (delta > 0), or "same" (0).

4. **FollowTrajectoryAction** — supported only if effectively starts at t=0.
   This means either: (a) in Init, or (b) in Story where the trigger chain
   resolves to t=0. Resolve by tracing: if Event StartTrigger is
   `StoryboardElementStateCondition(Act, runningState)` → check Act's
   StartTrigger; if that references Story's runningState → check Story's
   StartTrigger. If the chain terminates at `SimulationTimeCondition >= 0`,
   treat as t=0. If any link in the chain uses a non-zero time, duration,
   distance, or other condition → not supported. Skip and warn.

   When supported, extract exactly the polyline vertices as route waypoints
   (never reduce, never duplicate start/end points). Determine speed reference:
   - Has `<Timing>` in TimeReference → Speed Reference: "route-time-data".
     Include the `time` attribute from each vertex in the description.
     Ignore SpeedAction — timing overrides speed.
   - Has `<None/>` in TimeReference → Speed Reference: absolute (use SpeedAction value)
   Translate any non-WorldPosition vertices using `scripts/xoscPositionToWorld.p`.

5. **AssignRouteAction** — same t=0 rule as FollowTrajectoryAction (resolve
   trigger chain). When supported, extract all waypoints (LanePosition or
   WorldPosition). Always use absolute speed from SpeedAction. If trigger
   chain does not resolve to t=0 → not supported. Skip and warn.

6. **AddEntityAction** — Typically paired with SpeedAction (sets position +
   initial speed, same as TeleportAction + SpeedAction). May also combine
   with FollowTrajectoryAction or AssignRouteAction — in those cases the
   existing rules (items 4 and 5) apply. Extract position from the nested
   `<Position>` element and convert to world [x, y, z]. Describe the actor
   in the Actors section so the authoring skill places it via `addActor`.
   **Do not include Initial Speed in the Actors section** — the actor has no
   initialization. Speed is defined in the Phase Logic after the WaitAction.
   Since `addActor` places all actors at scenario start (no mid-scenario
   spawn), replicate the delayed appearance using phase logic:
   - Look at the StartTrigger condition of the AddEntityAction event/act
   - Describe a **WaitAction** phase (SystemActionPhase) as the actor's
     FIRST phase — inserted before the actor's auto-created init phase
   - Set the wait phase's end condition = the XOSC start condition
   - The actor's auto-created init phase comes AFTER the WaitAction — this
     is where speed/behavior is configured (e.g., ChangeSpeedAction)
   - Do NOT add a pass-through phase before the WaitAction — the WaitAction
     IS the first phase. Only two phases per actor: WaitAction → behavior
   - **Speed placement for AddEntityAction actors:** The WaitAction phase carries
     NO speed — it only waits for the spawn condition. Speed (e.g.,
     ChangeSpeedAction at 17.88 m/s) must be placed on the auto-created init
     phase that comes AFTER the WaitAction. Never assign speed on or before
     the WaitAction.

7. **Movement mode constraint** — If an actor has `ChangeLaneAction` or
   `ChangeLateralOffsetAction` in Story, it must be in lane-following mode
   (no route). Do NOT include route waypoints for such actors.

Ignore global init actions (e.g., EnvironmentAction) that do not affect actors.

#### 1d. Describe the Story phase

The goal is to describe **intent** — what each actor does, what triggers it,
and what ends it. Do NOT preserve the XOSC structural hierarchy (Acts, Events,
ManeuverGroups). Collapse scaffolding into simple action descriptions.

**Handling MW_WaitAction (placeholder Acts):**

- **Act with real action + MW_WaitAction:** Describe as the main action with
  the Act's StopTrigger as its end condition. Ignore the MW_WaitAction.
- **Act with ONLY MW_WaitAction (no real action):** This Act's StopTrigger is
  the end condition for whatever phase PRECEDES it in the serial chain. Set the
  condition directly on that preceding phase — do NOT create a separate
  WaitAction phase. **Exception:** If there is no preceding phase, or the
  preceding phase already has an end condition, create a WaitAction phase with
  the Act's StopTrigger as the end condition.

**Determining execution order:**

Look at StartTriggers to determine serial/parallel relationships:
- `StoryboardElementStateCondition(X, completeState)` → runs after X ends
- `StoryboardElementStateCondition(X, runningState)` → runs parallel with X
- `SimulationTimeCondition >= 0` → starts immediately

**Parallel groups and serial successors:**

When an Act contains multiple Events that run in parallel, they form a
ParallelPhase. If a subsequent action triggers on that Act's `completeState`,
it is serial after the **ParallelPhase** (the container), not after any
individual child phase. An Act completes when ALL its events finish — so the
successor must wait for the entire parallel group.

**What to capture for each action:**
- Actor, action type, action properties
- Phase name: use the `name` attribute from the XOSC `<Action>` tag
- What triggers it (start condition)
- What ends it (end condition — from Act StopTrigger or MW_WaitAction Act)
- Serial/parallel relationship to other actions

#### 1e. Produce the Scenario Description

Write a structured description using `roadrunner-scenario-authoring` terminology
so the authoring skill can execute it directly:

```
## Scene
- OpenDRIVE file: <filename from LogicFile>
- Import required: yes (use `roadrunner-import-scene` with format "OpenDRIVE")

## Parameters (if any)
- <name> = <resolved value> (original expression: <expr>)

## Actors
For each actor:
- Name: <XOSC entity name>
- Type: Vehicle / Pedestrian
- Asset: <model3d path> (AssetType: "VehicleAsset" or "CharacterAsset")
- Initial Position: [x, y, z] (translated from <original position type>)
- Anchoring:
  - Lane-following (no route): autoAnchor (actor must be anchored to road for lane following)
    - **Exception:** If the actor's translated position is on a junction connector road,
      do NOT autoAnchor — anchoring on junctions shifts the position to an
      unpredictable anchor point. Place the actor at the exact world coordinates instead.
  - Path-following (has route): do NOT autoAnchor (positions are precise world coordinates)
- Movement Mode: path-following (has route) or lane-following (no route)
- **Anchoring and Movement Mode are REQUIRED fields.** Every actor description
  must explicitly state the anchoring decision (autoAnchor or NOT autoAnchor)
  and movement mode. Do not omit these even when the choice seems obvious from
  context — the downstream authoring skill needs them stated explicitly.
- Initial Speed: <value> m/s (absolute)
  OR: <delta> m/s <direction> relative to <reference actor>
- Route (if path-following):
  - Waypoints: [x, y, z] per row (ALL vertices — never simplify)
  - Timestamps: [t0, t1, t2, ...] (if timed trajectory — sets Point.Time)
  - Speed Reference: "route-time-data" (timed) or absolute value (untimed)
  - Freeform: true (route follows exact waypoint positions, not road geometry)
  - Do NOT autoAnchor route waypoints

## Phase Logic
Use RoadRunner action/condition type names (see references/openscenario-mapping.md):
For each meaningful action (skip MW_WaitAction placeholders):
- Actor: <who>
- Phase Name: <from XOSC Action name attribute>
- Action: <RoadRunner action type> (e.g., ChangeSpeedAction, ChangeLaneAction)
  - Properties: Speed=X, DynamicsShape="step", Direction="left", etc.
- Trigger: <RoadRunner condition type> (e.g., SimulationTimeCondition, DurationCondition)
  - Properties: Time=X, Duration=X, Distance=X, Rule="ge", etc.
- End Condition: <RoadRunner condition type> with properties
- Topology: serial after <previous> / parallel with <sibling>

## Scenario End Conditions
- End: <condition type> on RootPhase (e.g., SimulationTimeCondition, Time=60)
- Fail: <condition type> on RootPhase (e.g., CollisionCondition)

## Unsupported Constructs
- <construct>: <why it cannot be mapped>
```

#### 1f. Present for review

Show the Scenario Description to the user. Ask:
*"Here is the scenario description I extracted. Review the actors, positions,
phase logic, and relative references. Should I adjust anything before generating
the MATLAB script?"*

**Wait for user approval before proceeding to Step 2.**

---

### Step 2: Build the Scenario via Dependent Skills

After the user approves the scenario description, delegate execution to the
dependent skills. **This skill does NOT generate MATLAB code.** It only
interprets the .xosc and produces the description.

#### 2a. Import the scene

Import into a new scene and create a new scenario:
1. Call `newScene(rrApp)` to get a clean scene (no leftover roads)
2. Import with `ProjectionMode = "noprojection"` to preserve the .xodr's native
   coordinate system:
   ```matlab
   importOpts = openDriveImportOptions;
   importOpts.ProjectionMode = "noprojection";
   importScene(rrApp, xodrPath, "OpenDRIVE", importOpts);
   ```
3. Call `newScenario(rrApp)` to create a fresh scenario on the imported scene

#### 2b. Build the scenario

**CRITICAL: You MUST invoke `/roadrunner-scenario-authoring` to build the
scenario. Do NOT write MATLAB code directly. Do NOT call MCP MATLAB tools
(`mcp__matlab__evaluate_matlab_code`, `mcp__matlab__run_matlab_file`) yourself.
The authoring skill handles all code generation and execution.**

Invoke `/roadrunner-scenario-authoring` with the full approved scenario
description as the argument. Prefix it with:

> Build the following scenario in RoadRunner. The scene is already
> imported and a new scenario has been created.

Then paste the complete scenario description (Actors, Phase Logic, End
Conditions, etc.) so the authoring skill can execute it directly.

Include the following mapping details in the instruction so the authoring
skill applies them correctly:

**Anchoring rules:**
- **Lane-following actors (no route/trajectory):** MUST autoAnchor — the actor
  needs to be anchored to the road to follow lanes correctly.
- **Path-following actors (have route):** do NOT autoAnchor actor or route
  waypoints — positions are precise world coordinates and autoAnchor would shift
  them from their intended positions, misaligning trajectories.

**CollisionCondition patterns (include in end conditions):**

| XOSC Pattern | What to Specify |
|---|---|
| `<EntityRef entityRef="ActorB"/>` (specific pair) | "Collision between [Actor] and [ActorB]" |
| `<ByType type="vehicle"/>` (any vehicle) | "Collision between [Actor] and any vehicle" |

**Multiple `<ConditionGroup>` elements** (OR logic in StopTrigger): describe
each as a separate end/fail condition on RootPhase.

---

## References

Consult these during Step 1 to map XOSC constructs to RoadRunner terminology:

- `references/openscenario-mapping.md` — XOSC action/condition types → RoadRunner API type names, state mapping, rule mapping, property mapping
- `scripts/xoscPositionToWorld.p` — MATLAB function: call to translate any XOSC position type to world [x, y, z] using the .xodr file

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Skipping autoAnchor on lane-following actors without routes | Actor won't follow lane properly without being anchored to road | Lane-following actors (no route/trajectory) MUST be autoAnchored — EXCEPT on junction connector roads where anchoring shifts position |
| Using autoAnchor on junction connector roads | Anchoring on junctions shifts the actor to an unpredictable anchor point, misaligning the position | If the translated position is on a junction, place at exact world coordinates without autoAnchor |
| Using autoAnchor on path-following actors with routes | Shifts positions, misaligns trajectories | Path-following actors and their route waypoints should NOT be autoAnchored — positions are already precise world coordinates |
| Passing string parameters to `xoscPositionToWorld` | Function silently gives wrong coordinates (up to 12m error) | Always use `str2double()` on XML attribute values before calling: `'roadId', str2double(id), 'laneId', str2double(lane), 's', str2double(s), 'offset', str2double(off)` |
| Adding a pass-through init phase before WaitAction for AddEntityAction actors | Adds an unnecessary phase; actor should do nothing until spawn time | WaitAction IS the first phase — only two phases: WaitAction → behavior |
| Including Initial Speed in Actors section for AddEntityAction actors | Actor has no initialization before the wait | Speed is set in Phase Logic after WaitAction, not in Actors section |
| Using ActorActionPhase for WaitAction | WaitAction is not an actor action | WaitAction must be in a SystemActionPhase |

## Conventions

- This skill produces **only** the scenario description — never MATLAB code
- Delegate to `roadrunner-import-scene` for scene import, `roadrunner-scenario-authoring` for building
- Always resolve parameters/expressions to concrete values before translating positions
- Always resolve CatalogReferences to asset paths before describing actors
- Asset paths use project extensions: `.fbx` for vehicles, `.rrchar` for characters

----

Copyright 2026 The MathWorks, Inc.

----
