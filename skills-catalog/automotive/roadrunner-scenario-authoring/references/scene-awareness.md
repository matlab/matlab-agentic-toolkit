# Scene Awareness

## Scene Catalog

### Base Scenes (with ScenarioStart anchor)

| Scene | Forward Lanes | Best For |
|-------|--------------|----------|
| `ScenarioBasic.rrscene` | 310 | Default — straight multi-lane road |
| `Bridge.rrscene` | 255 | Bridge scenarios |
| `SanAntonio.rrscene` | 625 | Urban, complex network |
| `ParkingGarage.rrscene` | 212 | Parking scenarios |

### Intersection Scenes (no scene anchors)

| Scene | Forward Lanes | Best For |
|-------|--------------|----------|
| `FourWaySignal.rrscene` | 139 | Signalized intersection |
| `FourWayStop.rrscene` | 50 | Stop-sign intersection |
| `T_Intersection.rrscene` | 29 | T-junction |
| `LargeFourWayIntersection.rrscene` | 451 | Large intersection |

### Specialty Scenes

| Scene | Forward Lanes | Best For |
|-------|--------------|----------|
| `SimpleFreewayRamps.rrscene` | 76 | Merging/diverging |
| `SimpleRoundabout.rrscene` | 101 | Roundabout navigation |
| `DoubleRoundabout.rrscene` | 1171 | Complex roundabout |
| `SimpleCurve.rrscene` | 9 | Curved road |
| `SimpleBankedRoad.rrscene` | 31 | Banked curves |
| `USCityBlockBidirectional.rrscene` | 1406 | Urban grid |

### Scene Selection Guide

| Scenario Type | Recommended Scene |
|---------------|-------------------|
| Free-drive, cut-in, follow | `ScenarioBasic` |
| Pedestrian crossing | `FourWaySignal` or `FourWayStop` |
| Intersection collision | `FourWaySignal`, `T_Intersection` |
| Highway merge | `SimpleFreewayRamps` |
| Roundabout | `SimpleRoundabout` |
| Urban | `SanAntonio`, `USCityBlockBidirectional` |

### MinLength Guidance

The `MinLength` parameter in `helperGetPositionFromHDMap` and `helperSurveyLanes` filters out lanes shorter than the specified value. Over-filtering leaves fewer lanes than expected and causes "Lane index N out of range" errors.

| Scenario Type | Recommended MinLength | Rationale |
|--------------|----------------------|-----------|
| Following/braking | 60–80 | Need stopping distance + approach |
| Cut-in/lane-change | 50–60 | Need parallel lanes of moderate length |
| Intersection approach | 20–30 | Approach lanes are short |
| Pedestrian crossing | 10–20 | Only need width of road |

**Formula:** `MinLength = max_speed × scenario_duration + 20m`

**Never use `MinLength > 80`** on intersection scenes (`FourWaySignal`, `T_Intersection`) — approach lanes are typically 30–60m. Using 80+ will return 0 matching lanes.

---

## HD Map Export for Lane Queries

When `helperSceneAwareness` is not available, query scene geometry manually:

```matlab
% Export scene to HD Map format
hdMapFile = fullfile(tempdir, "sceneHDMap.rrhd");
exportScene(rrApp, hdMapFile, "RoadRunner HD Map");

% Read the HD Map
rrMap = roadrunnerHDMap;
read(rrMap, hdMapFile);

% Get all lanes
lanes = rrMap.Lanes;
fprintf("Total lanes: %d\n", numel(lanes));

% Filter to driving lanes in forward direction
drivingLanes = [];
for i = 1:numel(lanes)
    if lanes(i).LaneType == "Driving" && lanes(i).TravelDirection == "Forward"
        drivingLanes = [drivingLanes; lanes(i)];
    end
end
fprintf("Forward driving lanes: %d\n", numel(drivingLanes));
```

## Getting Positions from HD Map

```matlab
% Get position at fraction along a lane (0=start, 1=end)
lane = drivingLanes(1);  % Longest lane (sorted by length desc)
geometry = lane.Geometry;
fraction = 0.3;  % 30% along the lane
idx = max(1, round(fraction * size(geometry, 1)));
position = geometry(idx, :);
```

## Checking for Scene Anchors

```matlab
anchors = getAnchors(rrApp);
if isempty(anchors)
    % No named anchors — use autoAnchor or HD Map positioning
    disp("No scene anchors. Using autoAnchor for placement.");
else
    % List available anchors
    for i = 1:numel(anchors)
        fprintf("  Anchor: %s\n", anchors(i).Name);
    end
end
```

## autoAnchor Constraints

- Point must be within **5 meters** of a road surface
- Works only when waypoints are on the **same lane** as previous point
- For cross-lane waypoints: use `anchorToPoint` + `ForwardOffset`
- Returns `ScenarioAnchorPoint` on success
- Error "Unable to locate a nearby anchoring road" means point is too far from road

**Pose preservation option:**
```matlab
autoAnchor(point);                      % Default: resets pose to road alignment
autoAnchor(point, "preserve-pose");     % Keeps current position/orientation
anchorToPoint(pt, anchor, "preserve-pose");  % Same option for anchorToPoint
```

## Creating Custom Assets

Create new vehicle, character, or behavior assets programmatically:

```matlab
% Create a new vehicle asset
newVehicle = createAsset(rrprj, "Vehicles/CustomCar.rrvehicle", "VehicleAsset");

% Create a new character asset
newChar = createAsset(rrprj, "Characters/CustomPed.rrchar", "CharacterAsset");

% Create a behavior asset and assign a platform
newBehavior = createAsset(rrprj, "Behaviors/Custom.rrbehavior", "BehaviorAsset");
platform = setPlatform(newBehavior, "SimulinkPlatform");
platform.FileName = "myController.slx";
```

Supported asset types for `createAsset`: `"VehicleAsset"`, `"CharacterAsset"`, `"BehaviorAsset"`, `"LaneMarkingStyle"`

----

Copyright 2026 The MathWorks, Inc.

----
