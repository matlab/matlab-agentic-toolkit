# Common Mistakes and Extended Constraints

## Wrong Property Names (Full Table)

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
| `DynamicsShape = "sinusoidal"` | `DynamicsShape = "cubic"` — `"sinusoidal"` passes `validate()` but breaks simulation; cubic is the closest S-curve |
| `addPhaseInSerial(..., "ParallelPhase")` | `addPhaseInParallel(phaseLogic, firstPhase, "ActorActionPhase")` — or fill a ParallelPhase you created with its own `addPhase`; `addPhaseInParallel` on it leaves it as an empty extra child |
| `setEndCondition(...).Property = N` | `c = setEndCondition(...); c.Property = N;` (two-line pattern) |
| `MinLength` (on helperSceneAwareness) | `MinLaneLength` — only lower-level helpers use `MinLength` |
| `"text" + status(rrApp)` | `status(rrApp)` returns a struct — use `s = status(rrApp); s.Scene.Filename` |
| `actors(i)` from helperPlaceActors | `actors{i}` — returns a cell array, use curly-brace indexing |

## Extended Constraints

These constraints supplement the core set in SKILL.md. Consult when building complex scenarios.

6. **Speed condition rules** — full set: `"eq"`, `"gt"`, `"lt"`, `"ge"`, `"le"`, `"ne"`
7. **SerialPhase cannot nest in SerialPhase** — the API errors; use a ParallelPhase as the intermediate, built with `addPhase` (not `addPhaseInParallel`, #37)
13. **Do NOT use `anchorToPoint` + `ForwardOffset` on route points** — `anchorToPoint` moves the waypoint onto the anchor and throws away its computed position, and the offset then re-places it along the anchor's own lane (in R2026b this validates, so nothing flags it); use `autoAnchor` on an HD-map position only
15. **Never guess lane change direction** — use `LaneChangeReference="actor"` + `Direction="same-lane"` when targeting another actor's lane, or compute direction via cross product (see `assets/scenario-templates.md`)
16. **Parallel group end condition** goes on `.ParentPhase`, not on child phases
17. **Verify WorldPosition after placement** — see §Failure Recovery if placement lands far from requested position
20. **Lane-change safety margin** — For lane changes, ensure longitudinal separation exceeds: `lane_change_distance + (closing_rate × maneuver_time) + 5 m` (about one car length). A 20m lane change at 5 m/s closing rate needs ≥ 30m initial gap.
21. **Route segments are road-following by default** — new segments have `Freeform = false` in R2026b (verified), so vehicle routes follow road geometry; setting `false` explicitly is harmless. **Set `Freeform = true`** on pedestrian routes (pedestrians cross roads and need freeform paths) and on segments that must leave the road (off-road or airborne): with `false`, the route between raised points is pulled back to road level (see `routes-and-points.md` §Off-Road and Airborne Paths).
22. **Path-following actors have no collision physics** — vehicles in path-following mode (with routes) pass through each other. RoadRunner detects collision when bumpers reach ≤50mm proximity, then terminates the scenario. Design collision timing using bumper-to-bumper distance, not center-to-center.
23. **Collision gap formula** — use bumper gap, not center gap: `bumper_gap = center_distance - (vehicle1_length/2 + vehicle2_length/2)`. Timing: `t_collision = bumper_gap / closing_rate`. Actors start at their initial-phase speed at t = 0 with no ramp (verified in R2026b: a Speed=15 actor is at 15.0 m/s at t = 0.1 s), so do not add ramp time. Only a later `ChangeSpeedAction` changes speed gradually, per its `DynamicsDimension`/`DynamicsValue`.
24. **Same-lane head-on only as path-following** — in lane-following mode two vehicles cannot face each other in one lane (`LaneOffset` must be positive), and `InitialPoint.TravelDirection = "backward"` does not help: in R2026b it re-anchors the actor onto the adjacent lane (verified: moved 3.50 m sideways), so the cars pass 3.5 m apart as oncoming traffic. A same-lane head-on **is** possible with a path-following oncoming car: leave its `InitialPoint` unanchored, turn it with `setActorWorldAnglesDegrees(pt, laneHeading + 180, 0, 0)`, add unanchored route points back along the lane centre (HD-map positions in reverse order), and set its segments `Freeform = true` (observed in an R2026b eval run: validated, simulation reported "Collision occurred between Actor CarA and Actor CarB" at 3.2 s; not yet reproduced independently). `CollisionUtility`/`setupCollision` still does not support head-on geometry.
25. **Initial separation must exceed trigger distance** — if actors start closer than the trigger condition's distance threshold, the condition fires immediately and phases advance before intended.
28. **Never use world-space offsets for actor placement** — `egoPos + [X, Y, 0]` only works on world-axis-aligned roads. For pedestrians and crossing actors, always use `helperGetPositionFromHDMap` to get position and heading, then compute the perpendicular crossing direction: `hdg2D = hdg(1:2)/norm(hdg(1:2)); perpDir = [-hdg2D(2), hdg2D(1), 0];`
29. **Junction scenes: do NOT route across intersection arms** — on `FourWaySignal`, `FourWayStop`, and `T_Intersection`, approach lanes do not connect to opposing exit lanes via the routing API. Use single-arm routes (approach → connected exit lane in the same corridor) or lane-following mode only. Cross-arm routes fail `validate`.
30. **Parameter naming differs by helper:**
    - `helperSceneAwareness(rrApp, MinLaneLength=30)` — capital L, one parameter
    - `helperSurveyLanes(rrHDMap, MinLength=30)` — no "Lane" in name
    - `helperGetPositionFromHDMap(rrHDMap, idx, frac, "MinLength", 30)` — same as Survey
    On intersection scenes always use 30 (approach lanes are 30-60m). Formula: `max_speed * duration + 20m`.
31. **CollisionUtility requires path-following mode** — both actors must have routes with waypoints that intersect. Lane-following mode (no routes) is NOT supported by the Collision Authoring Tool. Use manual speed/gap design for lane-following collision scenarios.
32. **Collision analysis supports max 2 logic phases per actor** — `setupCollision` only works when each actor has at most a Wait+DurationCondition phase followed by an Initialize Speed phase. Complex phase logic (multiple speed changes, lane changes) is incompatible.
33. **No same-direction or head-on collisions via CollisionUtility** — actors with heading at 0° or 180° relative to each other are not supported by collision analysis. Use crossing-path (T-bone, ~90° angle) with CollisionUtility, or manual physics-first timing for rear-end/head-on geometries (no CollisionUtility). See `references/collision-utility.md` Pre-Check section.
34. **Collision actors must be at same elevation** — z-axis values of actors and path waypoints must match for accurate collision analysis. Banked or superelevated roads may produce inaccurate results.
35. **Normalized collision point starts at front-right** — `0 = front-right corner`, increasing counterclockwise: `0.5 = front center`, `1.0 = front-left`, `1.5 = left center`, `2.0 = rear-left`, `2.5 = rear center`, `3.0 = rear-right`, `3.5 = right center`. Do NOT confuse with a rear-start parameterization.
36. **`setupCollision` error "trajectories and collision point does not coincide"** — this means the scenario geometry is incompatible with CollisionUtility. Check: (a) relative heading must be 10°–170° (rear-end at 0° and head-on at 180° are unsupported), (b) routes must geometrically cross in world space (same-lane routes don't cross). For rear-end collisions, use same-lane placement + speed differential + `physics-first-design.md`.
37. **Inline MCP code runs like the command line: no `function` definitions** — `evaluate_matlab_code` errors with "Function definitions are not supported in this context". Use anonymous functions (`f = @(a, b) norm(a - b);`), or write the code to a `.m` file and run that.

## Constraint Violation Outcomes

| Constraint | What happens on violation |
|---|---|
| #1 (.Actor missing) | MATLAB runtime error: "Actor property is required" |
| #2 (duplicate actions) | Silent: second action may be ignored or overwrite first |
| #3 (character no route) | `validate(rrs)` throws with a Critical diagnostic naming the character actor |
| #4 (autoAnchor > 5m) | Silent: may snap to wrong lane — see §Failure Recovery |
| #5 (invalid comparison) | MATLAB runtime error: invalid enum value |
| #8 (same speed + distance trigger) | Silent: condition never fires, phases stall indefinitely |
| #11 (addEndCondition) | MATLAB error: "Unrecognized function" |
| #12 (ChangeLaneAction + route) | `validate(rrs)` throws with a Critical diagnostic for the routed lane-change actor |
| #13 (ForwardOffset on route pt) | Silent in R2026b: `validate(rrs)` returns true, but the waypoint is re-placed relative to the anchor, not at its computed position |
| #14 (LaneOffset on junction) | Silent: actor lands on junction connector, lane-change fails at runtime |
| #18 (removeActor) | MATLAB error: "Unrecognized function" |
| #19 (fraction at 0 or 1) | Silent: autoAnchor snaps to wrong lane, possibly onto another actor; `validate()` still returns true with overlapping actors |
| #26 (chained setEndCondition) | MATLAB error on any phase type (function form only; the dot form works): "Unable to use a value of type roadrunner.api.ActorActionPhase as an index." |
| #27 (multiple addAction) | MATLAB error on some phase types; silent override on others |
| #27 (two same-axis actions in parallel, e.g. lane change + lateral offset) | Silent: one action is dropped in simulation; `validate()` returns true |
| #29 (cross-arm junction route) | `validate(rrs)` throws with a Critical diagnostic naming the cross-arm route |
| #31 (CollisionUtility + lane-following) | `setupCollision` fails or produces no result |
| #32 (>2 phases + collision analysis) | `setupCollision` fails or produces inaccurate timing |
| #33 (head-on via CollisionUtility) | `setupCollision` fails or produces no result |
| #34 (elevation mismatch) | Silent: collision analysis returns inaccurate timing |
| #35 (wrong collision point values) | Silent: collision occurs at unexpected location on vehicle |
| #36 (same-direction + CollisionUtility) | `setupCollision` error: "trajectories and collision point does not coincide" |

## Failure Recovery Patterns

### RoadRunner stops responding after repeated autoAnchor calls
Moving an already-anchored point (`ip.Position = …`, which is then relative to its anchor) and calling `autoAnchor` on it again, several times in a row, freezes RoadRunner R2026b: in two reproductions it hung on the 5th call, with or without `PosePreservation`, after erratic jumps of up to 100 m. Every later API call then hangs until RoadRunner is restarted. To find a valid road position, query the HD map (`helperGetPositionFromHDMap`, or `nearest-point` queries on exported lane geometry), then add the actor once at that position and anchor it once. If RoadRunner has stopped responding, tell the user it must be restarted; do not keep retrying.

### autoAnchor snaps to wrong location (WorldPosition far from requested position)
1. Verify the requested position is within 5m of road: `[nearPos,~] = helperGetPositionFromHDMap(rrHDMap, position(1:2))`
2. If position is valid but snaps wrong: try fraction 0.5 (center of lane avoids boundary convergence where multiple lanes meet). This applies per HD-map lane piece: a point interpolated along a chain of pieces can still land exactly on a piece end.
3. If still failing: the scene may not have road surface at that location — check elevation and lane geometry
4. Detect it: `autoAnchor` moves a point to its lane centre, so a lane-centre position should shift by ~0 m. A shift > 0.5 m means a jump to another lane (one lane ≈ 3.5 m). `helperPlaceActors` flags a shift beyond the requested lateral offset + 1 m. `validate()` does not catch the resulting overlap.

### validate(rrs) fails (throws)
`validate` throws on Critical/Error. As of R2026b Update 2 the exception (identifier `roadrunner:scenario:ValidationFailed`) attaches the detailed per-object diagnostics as **causes** (`ME.cause{i}.message`), NOT in the generic `ME.message` — read the causes, don't guess.
1. Wrap in `try/catch` and iterate `ME.cause` — each `ME.cause{i}.message` names the offending object (actor, route, phase) and the issue
2. Common causes: character without route, orphaned phase without .Actor, duplicate ActorID, time-based action on a route without time data, route segment between unconnected lanes (cross-arm)
3. Use `validate(rrs, ObjectRoot=actor)` to isolate which actor's subtree is problematic
4. For route validation: ensure all waypoints are autoAnchored and `Freeform=false` for vehicles
5. Apply the targeted fix, then re-run `validate(rrs)`; repeat until it returns `true`. See `references/validation-diagnostics.md` for the closed-loop repair workflow and the diagnostic→fix mapping. If a diagnostic isn't safe to auto-fix (e.g. missing asset), ask the user.

### helperSceneAwareness returns 0 lanes
1. `MinLaneLength` is too aggressive for the scene — reduce to 10
2. The `TravelDirection` filter is too strict — try without it
3. `RoadFeature` name doesn't match — check `sceneInfo.RoadFeatures.Summary` for available labels

### helperPlaceActors reports OVERLAP
- Two actors within 6m of each other (sedan = 4.7m + 1.3m buffer)
- OVERLAP is a warning, not a fatal error — placement still completes
- Fix: increase fraction separation between actors (0.1 fraction ≈ 7-10m on most lanes)

----

Copyright 2026 The MathWorks, Inc.

----
