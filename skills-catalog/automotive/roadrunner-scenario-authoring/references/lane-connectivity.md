# Lane Connectivity and Road Feature Classification

## Overview

Scenes with multiple elevation levels (bridges, overpasses, underpasses) require feature-aware placement. The `helperSceneAwareness` function integrates lane connectivity analysis and elevation-based classification to identify which lanes belong to specific road structures.

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

## Shipped RoadRunner Helpers

These helpers from `<RoadRunner-Install>/Tools/MATLAB/api/Scenario/common/` are used internally:

| Helper | Purpose |
|--------|---------|
| `helperAnalyzeHDMapLanes` | Build full lane network with connectivity |
| `helperFindPathFromLane` | DFS for connected lane sequences of target length |
| `helperFindAdjacentLanes` | Get lateral neighbors of a lane |
| `helperFindLanesOnSameRoad` | Get all lanes in the same LaneGroup |
| `helperBuildLaneGraph` | Build directed graph for A* routing |

These are added to the MATLAB path automatically by `helperSceneAwareness`.

----

Copyright 2026 The MathWorks, Inc.

----
