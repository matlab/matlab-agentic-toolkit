# Scene Awareness

## Scene Catalog

Lane counts are HD-map **driving lane pieces** (both directions), measured in RoadRunner R2026b. Roads are split into many short pieces, so few are long: check the "≥ 30 m" and "longest" columns before planning long routes or long gaps on one piece, and chain pieces (`LongitudinalAdj` from `helperSceneAwareness`) for longer stretches.

### Base Scenes (with ScenarioStart anchor)

| Scene | Driving lane pieces (fwd / bwd) | ≥ 30 m | Longest | Best For |
|-------|------|------|------|----------|
| `ScenarioBasic.rrscene` | 339 (199 / 140) | 35 | 238 m | Default — mixed network: multi-lane roads, a signalised junction and a roundabout (not a single straight road) |
| `Bridge.rrscene` | 268 (130 / 138) | 64 | 165 m | Bridge scenarios |
| `SanAntonio.rrscene` | 612 (383 / 229) | 99 | 160 m | Urban, complex network |
| `ParkingGarage.rrscene` | 217 (118 / 99) | 7 | 44 m | Parking scenarios |

### Intersection Scenes (no scene anchors)

| Scene | Driving lane pieces (fwd / bwd) | ≥ 30 m | Longest | Best For |
|-------|------|------|------|----------|
| `FourWaySignal.rrscene` | 139 (74 / 65) | 13 | 92 m | Signalized intersection |
| `FourWayStop.rrscene` | 50 (29 / 21) | 8 | 63 m | Stop-sign intersection |
| `T_Intersection.rrscene` | 29 (27 / 2) | 0 | 26 m | T-junction |
| `LargeFourWayIntersection.rrscene` | 451 (older count, not re-measured) | — | — | Large intersection |

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

% Forward driving lanes, longest first
drivingLanes = lanes([lanes.LaneType] == "Driving" & [lanes.TravelDirection] == "Forward");
laneLength = arrayfun(@(l) sum(vecnorm(diff(l.Geometry), 2, 2)), drivingLanes);
[~, order] = sort(laneLength, "descend");
drivingLanes = drivingLanes(order);
fprintf("Forward driving lanes: %d\n", numel(drivingLanes));
```

## Getting Positions from HD Map

```matlab
% Get position at fraction along a lane (0=start, 1=end)
lane = drivingLanes(1);  % longest forward driving lane
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

----

Copyright 2026 The MathWorks, Inc.

----
