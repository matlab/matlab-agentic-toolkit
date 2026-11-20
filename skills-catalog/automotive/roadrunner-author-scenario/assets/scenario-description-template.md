# Scenario Description Template

Fill this in during Step 1e of `references/openscenario-analysis.md` (recreating a `.xosc`), then show it to the user for review before Step 2 builds the scenario. It uses RoadRunner authoring terminology, so Step 2 can build directly from it.

```
## Scene
- OpenDRIVE file: <filename from LogicFile>
- Import required: yes, the OpenDRIVE road only (the .xodr from LogicFile, never the .xosc).
  Import it in Build Step 2 with:
    importOpts = openDriveImportOptions;
    importOpts.ProjectionMode = "noprojection";
    importScene(rrApp, xodrPath, "OpenDRIVE", importOpts);

## Parameters (if any)
- <name> = <resolved value> (original expression: <expr>)

## Actors
For each actor:
- Name: <XOSC entity name>
- Type: Vehicle / Pedestrian
- Asset: <model3d path> (AssetType: "VehicleAsset" or "CharacterAsset")
  - If that asset is not in the project, use `Vehicles/Sedan.fbx` for vehicles, `Characters/Citizen_Male.rrchar` for pedestrians, or `Props/TrafficControl/TrafficCone01.fbx` for props/misc objects, and state the substitution here (see `references/asset-catalog.md`). Do not stop the build for a missing asset.
- Initial Position: [x, y, z] (translated from <original position type>)
- Initial Heading: <rad2deg(h)> deg (unanchored actors only; anchored actors follow the lane)
- Anchoring:
  - Lane-following (no route): autoAnchor (actor must be anchored to road for lane following),
    including actors whose translated position is on a junction connector road
  - Path-following (has route): do NOT autoAnchor (positions are precise world coordinates)
  - MiscObject (prop): do NOT autoAnchor — it never follows a lane, and anchoring
    snaps it onto the nearest lane, discarding any lateral offset in the source
- Movement Mode: path-following (has route) or lane-following (no route)
- **Anchoring and Movement Mode are REQUIRED fields.** Every actor description
  must explicitly state the anchoring decision (autoAnchor or NOT autoAnchor)
  and movement mode. Do not omit these even when the choice seems obvious from
  context — Step 2 needs them stated explicitly.
- Initial Speed: <value> m/s (absolute)
  OR: <delta> m/s <direction> relative to <reference actor>
- Route (if path-following):
  - Waypoints: [x, y, z] per row (ALL vertices — never simplify; drop only true duplicates — same position in an untimed trajectory, or same position AND same time in a timed one. A timed stop (same position, different time) stays as separate timed points)
  - Timestamps: [t0, t1, t2, ...] (if timed trajectory — sets Point.Time)
  - Speed Reference: "route-time-data" (timed) or absolute value (untimed)
  - Freeform: vehicles `false` (as in SKILL.md §6 — the driven path still passes through every waypoint, verified in R2026b); pedestrians `true` (they must cross roads)
  - Do NOT autoAnchor route waypoints

## Phase Logic
Use RoadRunner action/condition type names (see `references/openscenario-mapping.md`):
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

----

Copyright 2026 The MathWorks, Inc.

----
