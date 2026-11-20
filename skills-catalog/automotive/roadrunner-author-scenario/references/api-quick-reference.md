# roadrunnerAPI Quick Reference

Full action and condition catalog: `actions-and-conditions.md`. Full wrong-name table and constraint list: `common-mistakes.md`.

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `roadrunnerAPI(rrApp)` | Create authoring API handle | R2025a |
| `addActor(rrs, asset, pos)` | Add actor to scenario | R2025a |
| `getAsset(proj, path, type)` | Load asset by path (`"VehicleAsset"`, `"CharacterAsset"`, …) | R2025a |
| `createAsset(proj, path, type)` | Create new asset (vehicle, character, behavior) | R2025a |
| `autoAnchor(point)` | Snap point to nearest road | R2025a |
| `anchorToPoint(pt, anchor)` | Anchor point to reference | R2025a |
| `addPoint(route, pos)` | Add waypoint to route | R2025a |
| `initialPhaseForActor(logic, actor)` | Get actor's init phase | R2025a |
| `addPhaseInSerial(logic, phase, type)` | Add sequential phase | R2025a |
| `addPhaseInParallel(logic, phase, type)` | Add concurrent phase | R2025a |
| `setEndCondition(phase, type)` | Set phase trigger | R2025a |
| `addAction(phase, type)` | Add behavior action | R2025a |
| `findActions(phase, type)` | Find actions of a type in a phase | R2025a |
| `validate(rrs)` | Check scenario validity — returns `true`, or throws with detailed diagnostics | R2025a |
| `validate(rrs, ObjectRoot=obj)` | Validate specific object (phase, actor, route) and its descendants | R2025a |
| `validate(rrs, ShowWarnings=true)` | Also emit non-blocking Warning/Info diagnostics as MATLAB warnings | R2026b Update 2 |
| `getAnchors(rrApp)` | List scene anchors | R2024a |
| `saveScenario(rrApp, name)` | Save to `<project>/Scenarios/name.rrscenario` (overwrites silently) | R2022a |
| `RemoveActorAction` | Remove actor during simulation | R2026a |
| `SynchronizeAction` | Coordinate arrival timing between two actors | R2026a |
| `createSimulation(rrApp)` | Create scenario simulation object | R2022a |
| `roadrunner.extensions.setupCollision(rrApp, rrApi, rrSim)` | Run collision analysis, auto-adjust timing | R2026a |

## Common Wrong Property Names (Most Frequent)

| Wrong (hallucinated) | Correct |
|---------------------|---------|
| `action.Rate` | `.DynamicsDimension = "rate"; .DynamicsValue = N;` |
| `setEndCondition(...).Prop = N` | `c = setEndCondition(...); c.Prop = N;` (two-line pattern) |
| `LateralOffsetAction` | `ChangeLateralOffsetAction` (full name required) |
| `DynamicsShape = "sinusoidal"` | `DynamicsShape = "cubic"` (closest S-curve; `"sinusoidal"` validates but breaks simulation) |
| `addPhaseInSerial(..., "ParallelPhase")` | `addPhaseInParallel(phaseLogic, firstPhase, "ActorActionPhase")` — wrapper auto-created |
| `actors(i)` from helperPlaceActors | `actors{i}` — cell array, use curly-brace indexing |
| `MinLength` (on helperSceneAwareness) | `MinLaneLength` — lower-level helpers use `MinLength` |

## Actor Movement Modes

| Mode | Trigger | Behavior | Compatible Actions |
|------|---------|----------|-------------------|
| **Lane-following** | No route waypoints | Follows anchored lane at set speed | `ChangeLaneAction`, `ChangeLateralOffsetAction` |
| **Path-following** | Has route waypoints | Follows waypoint path | `ChangeSpeedAction`, `ChangeLongitudinalDistanceAction` |

- Vehicles with speed set but NO routes drive along their lane automatically
- `ChangeLaneAction` ONLY works in lane-following mode (no routes)
- Character/pedestrian actors ALWAYS need routes (validation fails without them)

----

Copyright 2026 The MathWorks, Inc.

----
