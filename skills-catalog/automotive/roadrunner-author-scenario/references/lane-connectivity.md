# Lane Connectivity and Road Feature Classification

## Lane Network (from `helperAnalyzeHDMapLanes`)

The lane network provides topology-aware information about all lanes in the scene:

```matlab
% Build lane network (called automatically by helperSceneAwareness)
laneNetwork = helperAnalyzeHDMapLanes(rrHDMap);
```

**Output fields:**

| Field | Content |
|-------|---------|
| `.Lanes` | Table: ID, GlobalIndex, LaneType, TravelDirection, Length, LaneGroupID |
| `.LateralAdj` | Table: LaneID_A, LaneID_B, SharedBoundaryID, Relation |
| `.LongitudinalAdj` | Table: FromLaneID, ToLaneID, Relation ("successor"/"predecessor") |
| `.LaneGroups` | Table: GroupID, LaneIDs (cell), NumDrivingLanes |
| `.JunctionLaneIDs` | Cell array of lane IDs inside junctions |

## Road Feature Classification (from `helperClassifyRoadFeatures`)

Classifies lanes into semantic road features using elevation clustering:

```matlab
% Called automatically by helperSceneAwareness
roadFeatures = helperClassifyRoadFeatures(laneNetwork, rrHDMap);
```

**Algorithm:**
1. Compute mean Z per lane and per LaneGroup
2. Detect natural elevation breaks (largest gap in sorted Z values)
3. Assign labels based on relative elevation and spatial overlap:
   - `"ground"` — lowest elevation tier
   - `"bridge"` — elevated tier with ground-level lanes spatially below
   - `"overpass"` — elevated with no road below
   - `"ramp"` — lanes connecting across elevation tiers

**Output:**
- `roadFeatures.Features` — table with Label, MeanZ, ZRange, LaneIDs, TotalLength, NumLanes, ConnectedPathLength
- `roadFeatures.LaneToFeature` — Map: laneID -> feature label
- `roadFeatures.Summary` — human-readable feature list

## Usage Patterns

### Feature-filtered scene awareness
```matlab
% Get only bridge lanes
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="following", ...
    RoadFeature="bridge");

% sceneInfo.FilteredLaneIDs contains only bridge lane IDs
% sceneInfo.LaneTable is filtered to bridge lanes
% Recommendations use LaneIndex relative to bridge lanes only
```

### Passing filter to helperPlaceActors
```matlab
% Use FilterLaneIDs so LaneIndex is relative to the feature
actorSpecs(1).Name = "Leader";
actorSpecs(1).AssetPath = "Vehicles/Sedan.fbx";
actorSpecs(1).AssetType = "VehicleAsset";
actorSpecs(1).LaneIndex = 1;  % Longest bridge lane
actorSpecs(1).Fraction = 0.3;
actorSpecs(1).Speed = 15;
actorSpecs(1).FilterLaneIDs = sceneInfo.FilteredLaneIDs;
```

### Querying lane connectivity directly
```matlab
% Find successor lanes for a specific lane
laneNetwork = sceneInfo.LaneNetwork;
longAdj = laneNetwork.LongitudinalAdj;
myLaneID = "some-lane-id";
successors = longAdj.ToLaneID(longAdj.FromLaneID == myLaneID & longAdj.Relation == "successor");

% Find lateral neighbors (adjacent parallel lanes)
latAdj = laneNetwork.LateralAdj;
neighbors = latAdj.LaneID_B(latAdj.LaneID_A == myLaneID);
```

### Understanding connected path length
```matlab
% The ConnectedPathLength in roadFeatures.Features shows total
% forward-reachable path length through successor links within the same feature.
% This represents how far a vehicle in lane-following mode can travel
% without leaving the road feature.
%
% Example: Bridge scene
%   Individual bridge lanes: 70m, 122m
%   Connected path: 192m (vehicle traverses both via successor link)
```

## When Feature Classification Returns "ground" Only

If the scene has no significant elevation variation (< 2m range), all lanes are classified as "ground" and the feature system behaves identically to the original (no filter applied). This is the expected behavior for flat scenes like `ScenarioBasic` or `FourWaySignal`.

## Finding Crossing Paths for Collision Scenarios

When two actors must traverse a junction on conflicting paths (e.g., T-bone collision at an intersection), use the pre-computed `JunctionPaths` from `helperAnalyzeHDMapLanes`:

```matlab
laneNetwork = helperAnalyzeHDMapLanes(rrHDMap);
junctionPaths = laneNetwork.JunctionPaths;  % approach → junction → exit chains

% Find two paths with ~90° relative angle (best for T-bone collision)
bestPair = [];
bestAngle = 0;
for i = 1:numel(junctionPaths)
    for j = (i+1):numel(junctionPaths)
        relAngle = acosd(abs(dot(junctionPaths(i).ApproachHeading, ...
            junctionPaths(j).ApproachHeading)));
        if relAngle > bestAngle && relAngle > 45
            bestAngle = relAngle;
            bestPair = [i, j];
        end
    end
end

% Use the pair for actor placement
path1 = junctionPaths(bestPair(1));  % Ego's path
path2 = junctionPaths(bestPair(2));  % Target's path
```

### Route creation from junction paths

Place actors on approach lanes and add route waypoints on exit lanes. RoadRunner automatically routes through junction connectors when start and end are connected via LongitudinalAdj:

```matlab
% Place ego on approach lane
[egoPos, ~] = helperGetPositionFromHDMap(rrHDMap, approachLaneIdx, 0.5, ...
    "TravelDirection", "Forward", "MinLength", 30);
ego = addActor(rrs, vehicleAsset, egoPos);
autoAnchor(ego.InitialPoint);

% Add route WP on exit lane — RoadRunner routes through junction automatically
[exitPos, ~] = helperGetPositionFromHDMap(rrHDMap, exitLaneIdx, 0.3, ...
    "TravelDirection", "Forward", "MinLength", 20);
egoRoute = ego.InitialPoint.Route;
wp = addPoint(egoRoute, exitPos);
autoAnchor(wp, PosePreservation="reset-pose");
for i = 1:numel(egoRoute.Segments)
    egoRoute.Segments(i).Freeform = false;
end
```

**Key constraint:** Approach and exit lanes MUST be connected through LongitudinalAdj (approach → junction connector → exit). Use `laneNetwork.JunctionPaths` to identify valid approach/exit pairs rather than manually tracing successor chains.

### Using helperSceneAwareness for crossing scenarios

The simplest approach for collision scenarios at intersections:

```matlab
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="crossing");
% Returns recommendations with:
%   .LaneIndex — approach lane index for placement
%   .ExitLaneID — exit lane ID for route waypoint
%   .Heading — approach heading (use to verify relative angle)
```

## When to Target a Road Feature

Pass `RoadFeature` to `helperSceneAwareness` when:
- User mentions "on the bridge", "under the bridge", "on the ramp", "on the overpass"
- Scene has multiple elevation levels (Bridge, highway interchanges)
- Default placement picks the wrong road level (actor at unexpected elevation)

**Available feature labels:** `"bridge"`, `"ground"`, `"ramp"`, `"overpass"`

With `RoadFeature` set, `LaneIndex=1` refers to the longest lane of that feature, not the longest overall lane.

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

## RoadRunner Example Helpers vs. HD-Map Placement

RoadRunner ships example helpers at `<RoadRunner-Install>/Tools/MATLAB/api/scenario/common` (e.g., `helperAddCutInAndSlowCar`, `helperAddPedestrian`). These use `anchorToPoint` + `LaneOffset` for actor placement.

**When built-in helpers are suitable:** Simple scenes with clearly separated lanes (straight roads, known layouts).

**When to prefer HD-map placement instead:** Scenes with junctions, complex layouts, or unknown geometry — `LaneOffset` can land actors on junction connectors that don't support lane changes. HD Map positions + `autoAnchor` works reliably on any scene.

**Key pattern from built-in helpers:** `ChangeLaneAction` supports `LaneChangeReference="actor"` with `Direction="same-lane"` — the actor moves to the reference actor's lane automatically, eliminating cross-product direction computation. See `assets/scenario-templates.md` Cut-In section for usage.

----

Copyright 2026 The MathWorks, Inc.

----
