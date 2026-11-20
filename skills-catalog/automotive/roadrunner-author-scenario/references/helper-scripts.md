# Helper Scripts

Put `scripts/` on the MATLAB path first (`addpath(fullfile(skillDir, "scripts"))`, SKILL.md Step 1). They depend on each other: `helperSceneAwareness` calls `helperSurveyLanes`, `helperGetPositionFromHDMap` and `helperAnalyzeHDMapLanes`.

| Script | Purpose | When to use |
|--------|---------|-------------|
| `scripts/helperSceneAwareness.m` | Export HD Map, survey lanes, classify road features, recommend placements | First step before placing actors — provides positions, lane context, and feature classification |
| `scripts/helperSurveyLanes.m` | Filter/sort lanes by type, direction, length | When you need lane geometry data without full scene analysis |
| `scripts/helperGetPositionFromHDMap.m` | Arc-length interpolation along lanes, nearest-point queries | When you need precise positions at specific fractions along a lane |
| `scripts/helperPlaceActors.m` | Batch place, anchor, set speed, verify multiple actors | When placing 2+ actors — automates the manual add/anchor/verify loop |
| `scripts/helperClassifyRoadFeatures.m` | Elevation-based road feature classification (bridge, ground, ramp) | Used internally by helperSceneAwareness; call directly for custom feature queries |
| `scripts/helperAnalyzeHDMapLanes.m` | Lane network: lateral/longitudinal adjacency, lane groups, junction paths | Used internally by helperSceneAwareness; see `lane-connectivity.md` |
| `scripts/helperCheckScenarioStructure.m` | Flags silent mistakes `validate()` misses: overlapping or unplaced actors, lane-changers with routes, characters without routes, phases without `.Actor`, continuous phases that never end, same-axis parallel actions | After building, before `validate` — run it and fix every issue it prints |
| `scripts/xoscPositionToWorld.p` | Translate OpenSCENARIO World/Lane/Road positions to world [x, y, z] using the .xodr | .xosc workflow only — pass numeric arguments (`str2double`) |

## Interfaces

Called without an output, each helper prints its summary and returns nothing (no `ans` display).

**`sceneInfo = helperSceneAwareness(rrApp, Name=Value)`**
- Options: `NumActors` (default 2), `ScenarioType` (`"cut-in"`, `"following"`, `"pedestrian"`, `"intersection"`, `"crossing"`, or `"free-drive"`, the default), `MinLaneLength` (default 30 m), `TravelDirection` (default `"Forward"`), `RoadFeature` (`"bridge"`, `"ground"`, `"ramp"`, `"overpass"`; default none).
- Output fields: `SceneName`, `HDMap`, `LaneTable`, `NumForwardLanes`, `MaxLaneLength`, `Recommendations` (struct array: `ActorRole`, `LaneIndex`, `Fraction`, `Position`, `Heading`, `ExitLaneID`, `ExitPosition`), `Summary`, `LaneNetwork`, `RoadFeatures`, `FilteredLaneIDs`.
- Errors with `helperSceneAwareness:NoScene` when no scene is open.

**`laneTable = helperSurveyLanes(rrHDMap, Name=Value)`**
- Options: `LaneType` (default `"Driving"`), `MinLength` (default 0), `TravelDirection` (default any), `LaneIDs` (restrict to these IDs).
- Output: table with `Index`, `LaneID`, `Length`, `Direction`, `LaneType`, `StartPos`, `EndPos`, longest first.

**`[position, heading, laneInfo] = helperGetPositionFromHDMap(rrHDMap, laneIdx, fraction, Name, Value)`** or **`(rrHDMap, queryPoint, Name, Value)`**
- Index form: the point at `fraction` (0 = start, 1 = end) along the `laneIdx`-th longest lane that matches the filters.
- Query form: the nearest lane to `queryPoint` (`[x y]` or `[x y z]`). It snaps to the nearest lane vertex, so `autoAnchor` the result.
- Options: `LaneType` (default `"Driving"`), `TravelDirection`, `Offset` (lateral, m), `MinLength`, `LaneIDs`.
- Outputs: `position` `[x y z]`, `heading` (unit vector), `laneInfo` (`ID`, `LaneType`, `TravelDirection`, `GlobalIndex`, `Geometry`).
- Errors: `helperGetPositionFromHDMap:InvalidLaneIndex`, `:InvalidInput`, `:NoLanes`.

**`[actors, report] = helperPlaceActors(rrs, rrprj, phaseLogic, rrHDMap, actorSpecs, MinSeparation=6)`**
- `actorSpecs` struct array: `Name`, `AssetPath`, `AssetType` (`"VehicleAsset"` or `"CharacterAsset"`), `LaneIndex`, `Fraction`, `Speed`; optional `TravelDirection`, `LateralOffset`, `FilterLaneIDs`.
- Outputs: `actors` (cell array), `report` (`AllValid`, `Details`, `Summary`). Overlaps closer than `MinSeparation` set `AllValid` to false.

**`roadFeatures = helperClassifyRoadFeatures(laneNetwork, rrHDMap, ElevationThreshold=-1, MinFeatureLength=20)`**
- Output: `Features` (table: `Label`, `MeanZ`, `ZRange`, `LaneIDs`, `TotalLength`, `NumLanes`, `ConnectedPathLength`), `LaneToFeature` (lane ID to label), `FeatureConnections`, `Summary`.

**`laneNetwork = helperAnalyzeHDMapLanes(rrHDMap)`**
- Output: `Lanes`, `LateralAdj`, `LongitudinalAdj`, `LaneGroups` (tables), `JunctionLaneIDs`, `JunctionPaths` (struct array: `ApproachLaneID`, `JunctionLaneIDs`, `ExitLaneID`, `ApproachHeading`, `TotalLength`, `TravelDirection`).

**`report = helperCheckScenarioStructure(rrs, MinSeparation=4)`**
- Output: `AllValid`, `Issues` (one string per problem), `Actors` (table: `Name`, `AssetType`, `Position`, `RouteWaypoints`).

**`[worldPos, heading] = xoscPositionToWorld(xodrPath, posType, Name, Value)`** (p-coded)
- `posType` and its arguments:
  - `"WorldPosition"`: `x`, `y`, `z`
  - `"LanePosition"`: `roadId`, `laneId`, `s`, `offset` (default 0)
  - `"RoadPosition"`: `roadId`, `s`, `t`
  - `"RelativeObjectPosition"`: `basePos`, `baseHdg` (rad), `dx`, `dy`, `dz`
  - `"RelativeLanePosition"`: `basePos`, `baseHdg`, `dLane`, `ds`, `offset`; optional `baseRoadId`, `baseLaneId`, `baseS`
  - `"RelativeRoadPosition"`: `basePos`, `baseHdg`, `ds`, `dt`; optional `baseRoadId`, `baseS`, `baseT`
- Outputs: `worldPos` `[x y z]`, `heading` (road heading in rad, `NaN` when not applicable).
- Example: `pos = xoscPositionToWorld("RoadNetwork1.xodr", "RoadPosition", "roadId", "266", "s", 22.1893, "t", -5.28479);`

## Usage Pattern

```matlab
% 1. Run scene awareness to get lane data and recommended positions
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in");

% 2. Define actor specs (do NOT pre-initialize with actorSpecs=[]); keep fractions within 0.2-0.8
actorSpecs(1) = struct(Name="Ego", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=1, Fraction=0.2, Speed=15);
actorSpecs(2) = struct(Name="Target", AssetPath="Vehicles/Sedan.fbx", ...
    AssetType="VehicleAsset", LaneIndex=2, Fraction=0.3, Speed=20);

% 3. Batch place and verify (actors is a cell array)
[actors, report] = helperPlaceActors(rrs, rrprj, phaseLogic, sceneInfo.HDMap, actorSpecs);
assert(report.AllValid, "Placement failed: " + report.Summary);
ego = actors{1}; target = actors{2};  % curly braces required

% 4. After building the phase logic, check for silent mistakes, then validate
report = helperCheckScenarioStructure(rrs);
```

**Multi-level scenes (bridges, overpasses, ramps):** pass `RoadFeature="bridge"` (or `"ground"`, `"ramp"`, `"overpass"`) to `helperSceneAwareness` and `FilterLaneIDs=sceneInfo.FilteredLaneIDs` in `actorSpecs`. See `lane-connectivity.md` for when to use it, output fields, and when to prefer RoadRunner's shipped example helpers.

----

Copyright 2026 The MathWorks, Inc.

----
