# Building a Scenario from OpenSCENARIO (.xosc)

Detailed procedure for the "From OpenSCENARIO" workflow in `SKILL.md`. Interpret an
OpenSCENARIO 1.x (.xosc) file, produce a Scenario Description for user review, then
build it with the main authoring workflow. Consult `references/openscenario-mapping.md`
for XOSC → RoadRunner type, state, rule, and property mapping.

## Critical Rules

1. **Never fabricate actions or conditions not present in the source XOSC.**
   If a construct cannot be mapped, skip it and warn the user.

2. **Never propose workarounds.** Do not replace an unsupported condition (for
   example TimeToCollisionCondition) with DurationCondition, do not substitute
   SimulationTimeCondition for unsupported triggers, do not add any construct
   not in the source.

3. **Never simplify or duplicate trajectory vertices.** Extract exactly the
   polyline vertices present in the source XOSC — no fewer, no more. Do not
   reduce 90 vertices to 5. Do not duplicate start/end points during extraction.
   The only vertices to drop are true duplicates (see 1c, item 4).

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

---

## Step 1: Analyze the .xosc and Produce a Scenario Description

Parse the .xosc and its referenced .xodr following this strict logical order.

### 1a. Validate the input

Read the .xosc XML. If the file is invalid XML, missing required elements, or
fails basic structural checks, **stop and report the error**. Do not guess or
assume missing data. If data is ambiguous, state the assumption explicitly.

### 1b. Resolve parameters, expressions, and catalogs

Before interpreting any values, resolve all references:

- **ParameterDeclarations / VariableDeclarations**: Evaluate `${...}` expressions
  to concrete numeric values. Process in declaration order (later params may
  reference earlier ones).
- **CatalogReferences**: Read the referenced catalog XML file (from
  `<CatalogLocations>`), find the entry by `catalogName` + `entryName`, extract
  the vehicle/pedestrian definition (model3d path, category, bounding box).
- **Catalog properties with no API equivalent:** `mass` and `Performance`
  (`maxSpeed`, `maxAcceleration`, `maxDeceleration`), including
  `ParameterAssignments` that only change them. `VehicleAsset` holds geometry
  only. Resolve the values and list them under Unsupported Constructs.

```matlab
% Parameter expression resolution example
params.HostSpeed_kph = 80;
params.LeadTime_s = 6;
params.hostSpeed_ms = params.HostSpeed_kph / 3.6;        % 22.2222
params.leadSpeed_ms = params.hostSpeed_ms * 0.5;         % 11.1111
params.initSeparation = (params.hostSpeed_ms + params.leadSpeed_ms) * params.LeadTime_s; % 200
```

### 1c. Describe the Init phase

For each actor's Private actions in `<Init>`:

1. **TeleportAction** — convert position to world [x, y, z]:
   - WorldPosition: use directly
   - LanePosition: translate using .xodr (see `scripts/xoscPositionToWorld.p`)
   - RoadPosition: translate using .xodr (see `scripts/xoscPositionToWorld.p`)
   - **CRITICAL: pass the position values to `xoscPositionToWorld` as numbers.**
     XML attributes are always text — convert each one with `str2double()` before calling:
     ```matlab
     pos = xoscPositionToWorld(xodrPath, 'LanePosition', ...
         'roadId', str2double(roadId), 'laneId', str2double(laneId), ...
         's', str2double(s), 'offset', str2double(offset));
     ```
     `roadId` also works as text, but `laneId`, `s`, `t` and `offset` must be
     numbers: as text they either error or silently return a wrong position
     (measured on RoadNetwork1: `laneId` 1.7 m off, `offset` 27.8 m, `t` 91 m).
   - RelativeObjectPosition: rotate dx/dy by entity heading, add to base position
   - RelativeRoadPosition: inverse-lookup base entity road coords, offset s/t
   - RelativeLanePosition: inverse-lookup base lane, compute target lane + s
     (skip center lane when dLane crosses from negative to positive IDs)
   - Process entities in dependency order: resolve reference entities first

2. **Heading** — record the source heading `h` (radians) in degrees,
   `rad2deg(h)`. It is the actor's world heading (`ActorWorldHeadingDegrees`).
   - Anchored (lane-following) actors take the lane direction from autoAnchor;
     do not set their heading.
   - Unanchored actors (MiscObjects and path-following actors) keep RoadRunner's
     default 90° unless you set it, so apply the source heading (Step 2b).
   - The `h` is also needed for RelativeObjectPosition translation (to rotate
     dx/dy in the entity's local frame).

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
   - **Duplicate vertices:** a consecutive vertex is a duplicate only if it has
     the same position as the previous one AND either the trajectory is untimed,
     or it is timed and the `time` is also the same. Keep one point for each
     duplicate. In a timed trajectory, the same position at a different time is
     a stop (the actor is at 0 speed between the two times): keep BOTH as
     separate timed points; do not merge them into one point with `WaitTime`.
     Example: StoryTrajectory.xosc White has vertices at t = 4.11 and t = 4.61 at
     the same [x, y] → keep both (49 vertices → 49 route points).
     Note: RoadRunner's `importScenario` merges such a stop into one point with
     `WaitTime` (48 points). That is not the reference for this skill; the
     source vertices are.
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
   in the Actors section so it is placed via `addActor`.
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

### 1d. Describe the Story phase

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

### 1e. Produce the Scenario Description

Fill in the template in `assets/scenario-description-template.md`. It uses RoadRunner
authoring terminology, so Step 2 can build directly from it.

### 1f. Present for review

Show the Scenario Description to the user. Ask:
*"Here is the scenario description I extracted. Review the actors, positions,
phase logic, and relative references. Should I adjust anything before generating
the MATLAB script?"*

**Wait for user approval before proceeding to Step 2.**

---

## Step 2: Build the Scenario

After the user approves the Scenario Description, build it. Do not write MATLAB
code during Step 1 — Step 1 produces only the description.

### 2a. Import the scene

Import into a new scene and create a new scenario:
1. Do the unsaved-work check from `SKILL.md` Workflow step 2 first: `newScene`
   also discards an unsaved scenario without asking.
2. Call `newScene(rrApp)` to get a clean scene (no leftover roads)
3. Import with `ProjectionMode = "noprojection"` to preserve the .xodr's native
   coordinate system:
   ```matlab
   importOpts = openDriveImportOptions;
   importOpts.ProjectionMode = "noprojection";
   importScene(rrApp, xodrPath, "OpenDRIVE", importOpts);
   ```
4. Call `newScenario(rrApp)` to create a fresh scenario on the imported scene
5. Create the handles from `SKILL.md` Workflow step 2 (`rrApi`, `rrs`, `phaseLogic`,
   `rrprj`), but not its `openScene`/`newScenario`: they would replace the imported road

### 2b. Build the scenario

Follow `SKILL.md` Workflow steps 3–8 using the approved Scenario Description as the
spec. The scene is already imported and a new scenario has been created, and the
approved description satisfies the plan-confirmation requirement of `SKILL.md`
Workflow step 0 (Plan the Scenario) — do not re-ask for the same parameters.

Apply these mapping details while building:

**Anchoring rules:**
- **Lane-following actors (no route/trajectory):** MUST autoAnchor — the actor
  needs to be anchored to the road to follow lanes correctly. This includes
  actors on junction connector roads. After anchoring, compare
  `InitialPoint.WorldPosition` with the translated position; if it moved more
  than 0.5 m, report the shift to the user (the anchor cannot be undone —
  `AnchorPoint` and `WorldPosition` are read-only):
  ```matlab
  p0 = actor.InitialPoint.WorldPosition;
  autoAnchor(actor.InitialPoint);
  shift = norm(actor.InitialPoint.WorldPosition - p0);
  if shift > 0.5
      fprintf("WARNING: %s moved %.2f m when anchored\n", actor.Name, shift);
  end
  ```
- **Path-following actors (have route):** do NOT autoAnchor actor or route
  waypoints — positions are precise world coordinates and autoAnchor would shift
  them from their intended positions, misaligning trajectories.
- **MiscObjects** (props, including a `TrafficCone01` stand-in): do NOT
  autoAnchor. Place them at the translated position and leave them. They never
  follow a lane, and anchoring snaps them onto the nearest lane, discarding the
  source's lateral offset. Example: a rock prop at a `LanePosition` with offset
  −7.43 m (on the shoulder) moved 1.89 m when anchored;
  unanchored it stays at the exact source position and the scenario still
  validates (verified in R2026b Update 3).

**Heading of unanchored actors:** an unanchored actor (MiscObject or
path-following) keeps the default 90° heading. Set the source heading after
`addActor` (and after the route is assigned). `setActorWorldAnglesDegrees` needs
RoadRunner R2026b Update 1 or later:
```matlab
setActorWorldAnglesDegrees(actor.InitialPoint, rad2deg(h), 0, 0);
```
`h` is the heading of the actor's TeleportAction position, or of the first
trajectory vertex if there is no TeleportAction. Verified in R2026b Update 3:
that rock prop goes from 90° to the source 6.48°, and
AddEntityAction.xosc CompactCar from 8.27° (route direction) to the source 9.315°.
Both keep their positions and the scenarios validate.

**CollisionCondition patterns (include in end conditions):**

| XOSC Pattern | What to Specify |
|---|---|
| `<EntityRef entityRef="ActorB"/>` (specific pair) | "Collision between [Actor] and [ActorB]" |
| `<ByType type="vehicle"/>` (any vehicle) | `CollisionCondition` has no type filter (only `FirstActor`, `SecondActor`). Exact only when every other actor is of that type: `FirstActor` = [Actor], `SecondActor` = []. Otherwise list it under Unsupported Constructs; don't use `SecondActor = []`, which also triggers on pedestrians and props. |

**Multiple `<ConditionGroup>` elements** (OR logic in StopTrigger): RootPhase
holds one end condition and one fail condition, and there is no OR condition
(`AnyCondition`, `OrCondition` and `ConditionGroup` are not registered). Keep
the condition that matches the source's intent and list the others under
Unsupported Constructs.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Skipping autoAnchor on lane-following actors without routes | Actor won't follow lane properly without being anchored to road | Lane-following actors (no route/trajectory) MUST be autoAnchored, including on junction connector roads |
| Skipping autoAnchor because the actor is on a junction connector road | Leaves a lane-following actor unanchored; anchoring at junction positions does not shift the actor | autoAnchor it, then check the `WorldPosition` shift and report it if > 0.5 m |
| Using autoAnchor on path-following actors with routes | Shifts positions, misaligns trajectories | Path-following actors and their route waypoints should NOT be autoAnchored — positions are already precise world coordinates |
| Using autoAnchor on a MiscObject (prop) | Snaps it onto the nearest lane and discards the source's lateral offset (a shoulder prop: 1.89 m off) | Do not anchor MiscObjects; keep the translated position |
| Leaving the heading of an unanchored actor unset | It keeps the default 90°, whatever the source orientation (a prop: 90° instead of 6.48°) | `setActorWorldAnglesDegrees(actor.InitialPoint, rad2deg(h), 0, 0)` for MiscObjects and path-following actors (R2026b Update 1 or later) |
| Passing string parameters to `xoscPositionToWorld` | Function silently gives wrong coordinates (up to 12m error) | Always use `str2double()` on XML attribute values before calling: `'roadId', str2double(id), 'laneId', str2double(lane), 's', str2double(s), 'offset', str2double(off)` |
| Adding a pass-through init phase before WaitAction for AddEntityAction actors | Adds an unnecessary phase; actor should do nothing until spawn time | WaitAction IS the first phase — only two phases: WaitAction → behavior |
| Including Initial Speed in Actors section for AddEntityAction actors | Actor has no initialization before the wait | Speed is set in Phase Logic after WaitAction, not in Actors section |
| Using ActorActionPhase for WaitAction | WaitAction is not an actor action | WaitAction must be in a SystemActionPhase |

----

Copyright 2026 The MathWorks, Inc.

----
