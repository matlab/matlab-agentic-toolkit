---
name: workflow-09-static-objects
description: Place static objects (buildings, trees, traffic cones, signs, electric poles, street lights) into a RoadRunner HD Map using roadrunnerStaticObjectInfo. Covers source-of-truth options (lidar segmentation, camera 3D detection, manual, synthetic), M×9 cuboid format, default dimensions per category, asset-path mapping, and combining with scenario pipelines.
---

# Workflow 9 — Add Static Objects to RoadRunner HD Map

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when user asks to add buildings, trees, traffic cones, signs, electric poles, street lights, or any static prop to a RoadRunner scene.
>
> **Related references:** [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) for the upstream `getRoadRunnerHDMap` step. Static objects attach to the same `rrMap` before `write(rrMap, ...)`.

Use `roadrunnerStaticObjectInfo` to place static objects (buildings, trees, traffic cones, signs, street lights, etc.) into a RoadRunner HD Map.

## Source of Static Object Data
| Source | Description |
|--------|-------------|
| **Lidar segmentation (RandLA-Net)** | Run semantic segmentation on aerial/vehicle lidar to extract labeled 3D bounding boxes for buildings, trees, poles, etc. |
| **Camera 3D detection** | Use 3D object detectors on camera imagery to get cuboid positions |
| **Manual annotation / labels** | User-provided label data (e.g., from a labeling tool) |
| **Green region / ROI placement** | Place trees/bushes programmatically within a specific region of interest (e.g., a green area on the map) |
| **Synthetic placement along geometry** | Place objects along road boundaries (trees), medians (street lights), or at regular intervals — no sensor data needed |

## Input Format
Each object category is an M×9 matrix: `[xctr yctr zctr xlen ylen zlen xrot yrot zrot]`
- `xctr, yctr, zctr` — center position (meters, local coordinates matching the HD map)
- `xlen, ylen, zlen` — dimensions along each axis (meters)
- `xrot, yrot, zrot` — rotation angles (degrees)

## Default Cuboid Dimensions
When programmatically placing static objects (not from sensor detections), use these standard dimensions:

| Category | Default Dimensions [xlen ylen zlen] | Typical Asset |
|----------|-------------------------------------|---------------|
| `trees` | [4.0, 4.0, 8.0] | `Props/Trees/Ash01.fbx_rrx` |
| `bushes` | [2.0, 2.0, 1.5] | `Props/Trees/Bush_Med01.fbx_rrx` |
| `electricPoles` | [0.4, 0.4, 10.0] | `Props/ElectricPoles/Arrester_Lg01.fbx_rrx` |
| `barricades` | [1.5, 0.3, 1.0] | `Props/TrafficControl/Barricade01.fbx_rrx` |
| `cones` | [0.3, 0.3, 0.7] | `Props/TrafficControl/Drum01.fbx_rrx` |
| `buildings` | [15.0, 15.0, 12.0] | `Buildings/Downtown_15mX15m_01_5storey.fbx_rrx` |
| `signs.stop` | [0.05, 0.6, 0.6] | `Signs/US/Regulatory Signs/Sign_R1-1.svg` |
| `signs.yield` | [0.05, 0.6, 0.6] | `Signs/US/Regulatory Signs/Sign_R1-2.svg` |
| `signs.speedLimit` | [0.05, 0.6, 0.75] | `Signs/US/Regulatory Signs/Sign_SpeedLimit.svg_rrx` |
| `signPosts` | [0.1, 0.1, 3.0] | (auto-generated with signs) |
| `miscellaneousObjects` | [1.0, 1.0, 1.0] | (generic cuboid) |

## Step 1: Organize cuboid detections
```matlab
%% Organize static object cuboids by category
% Each row: [xctr yctr zctr xlen ylen zlen xrot yrot zrot]
staticObjectCuboids = struct();

% Trees along the roadside
staticObjectCuboids.trees = [
    25.0  8.0  4.0   4.0 4.0 8.0   0 0 0;   % Tree at (25, 8)
    45.0  9.0  4.0   4.0 4.0 8.0   0 0 0;   % Tree at (45, 9)
    65.0  8.5  4.0   4.0 4.0 8.0   0 0 0;   % Tree at (65, 8.5)
];

% Electric poles
staticObjectCuboids.electricPoles = [
    30.0  7.0  5.0   0.4 0.4 10.0   0 0 0;
    60.0  7.0  5.0   0.4 0.4 10.0   0 0 0;
];

% Stop sign (nested under signs)
staticObjectCuboids.signs.stop = [
    10.0  5.5  1.5   0.05 0.6 0.6   0 0 0;
];
```

## Step 2: Configure asset paths (optional but recommended)
```matlab
%% Map categories to RoadRunner assets
params = struct();
params.trees.AssetPath = fullfile("Assets", "Props", "Trees", "Ash01.fbx_rrx");
params.electricPoles.AssetPath = fullfile("Assets", "Props", "ElectricPoles", "Arrester_Lg01.fbx_rrx");

% For multiple objects with different assets, use cell array:
% params.trees.AssetPath = {"Props/Trees/Ash01.fbx_rrx", "Props/Trees/Birch01.fbx_rrx", "Props/Trees/Ash01.fbx_rrx"};

% Merge overlapping cuboids from lidar (requires Lidar Toolbox)
% params.trees.OverlapThreshold = 0.7;
```

## Step 3: Generate HD Map info and assign to map
```matlab
%% Convert cuboids to RoadRunner HD Map format
objectsInfo = roadrunnerStaticObjectInfo(staticObjectCuboids, Params=params);

%% Add to existing RoadRunner HD Map (e.g., from getRoadRunnerHDMap)
% If building from scratch:
rrMap = roadrunnerHDMap;

% If adding to an existing map (from OSM/scenario):
% rrMap = getRoadRunnerHDMap(scenario);

% Assign static objects
rrMap.StaticObjectTypes = objectsInfo.staticObjectTypes;
rrMap.StaticObjects = objectsInfo.staticObjects;

% Assign signs (if any)
if isfield(objectsInfo, 'signTypes')
    rrMap.SignTypes = objectsInfo.signTypes;
    rrMap.Signs = objectsInfo.signs;
end

%% Write and import
rrhdFile = fullfile(tempdir, "scene_with_objects.rrhd");
write(rrMap, rrhdFile);
```

## Step 4: Import to RoadRunner
```matlab
%% Import the augmented HD map
copyfile(rrhdFile, fullfile(rrProjectPath, "Assets", "SceneWithObjects.rrhd"));
importScene(rrApp, "SceneWithObjects.rrhd", "RoadRunner HD Map");
```

## Synthetic Placement Examples

### Trees along road boundaries
```matlab
%% Place trees every 15m along road boundaries
[roadProperties, localOrigin] = roadprops(OpenStreetMap=osmFile);
treeCuboids = [];
spacing = 15;  % meters between trees
dims = [4.0 4.0 8.0];  % default tree dimensions

for i = 1:height(roadProperties)
    leftBdy = roadProperties.LeftBoundary{i};
    if size(leftBdy, 1) < 2, continue; end
    % Sample points along boundary at regular intervals
    cumDist = [0; cumsum(vecnorm(diff(leftBdy), 2, 2))];
    sampleDists = (0:spacing:cumDist(end))';
    pts = interp1(cumDist, leftBdy, sampleDists);
    % Offset 3m outward from boundary
    pts(:,2) = pts(:,2) + 3;
    nPts = size(pts, 1);
    treeCuboids = [treeCuboids; pts(:,1) pts(:,2) repmat(dims(3)/2, nPts, 1) ...
        repmat(dims, nPts, 1) zeros(nPts, 3)]; %#ok<AGROW>
end
staticObjectCuboids.trees = treeCuboids;
```

### Street lights along road median
```matlab
%% Place street lights every 30m along road centers
lightCuboids = [];
spacing = 30;
dims = [0.3 0.3 6.0];  % pole dimensions

for i = 1:height(roadProperties)
    centers = roadProperties.RoadCenters{i};
    if size(centers, 1) < 2, continue; end
    cumDist = [0; cumsum(vecnorm(diff(centers), 2, 2))];
    sampleDists = (0:spacing:cumDist(end))';
    pts = interp1(cumDist, centers, sampleDists);
    nPts = size(pts, 1);
    lightCuboids = [lightCuboids; pts(:,1) pts(:,2) repmat(dims(3)/2, nPts, 1) ...
        repmat(dims, nPts, 1) zeros(nPts, 3)]; %#ok<AGROW>
end
staticObjectCuboids.electricPoles = lightCuboids;
```

### Objects in a green region / ROI
```matlab
%% Scatter trees/bushes within a polygon ROI (e.g., park or green area)
roiPolygon = [10 20; 10 50; 40 50; 40 20; 10 20];  % [x y] polygon vertices
nTrees = 20;

% Random placement within bounding box, filtered by polygon
xRange = [min(roiPolygon(:,1)), max(roiPolygon(:,1))];
yRange = [min(roiPolygon(:,2)), max(roiPolygon(:,2))];
xCand = xRange(1) + diff(xRange) * rand(nTrees * 3, 1);
yCand = yRange(1) + diff(yRange) * rand(nTrees * 3, 1);
inROI = inpolygon(xCand, yCand, roiPolygon(:,1), roiPolygon(:,2));
xCand = xCand(inROI); yCand = yCand(inROI);
xCand = xCand(1:min(nTrees, numel(xCand)));
yCand = yCand(1:min(nTrees, numel(yCand)));

dims = [4.0 4.0 8.0];
nPts = numel(xCand);
staticObjectCuboids.trees = [xCand yCand repmat(dims(3)/2, nPts, 1) ...
    repmat(dims, nPts, 1) zeros(nPts, 3)];
```

### From aerial top-down lidar — see Workflow 16
For aerial lidar (USGS 3DEP for US lat/lon, or user-provided LAS/LAZ + CRS for non-US), use [`workflow-16-aerial-lidar-augmentation.md`](workflow-16-aerial-lidar-augmentation.md). The documented pipeline is `segmentGroundSMRF` + RandLA-Net (`"dales"` model) via `helperRandLANetSegmentObjects` + cluster-based `helperExtractCuboidsFromLidar` — NOT `semanticseg` + `pcfitcuboid`. Workflow 16 also handles the CRS handshake (`readCRS` + EPSG code), `addElevation` on cuboids, and combining with OSM roads at the same georeference.

## Combining with Scenario Builder Workflows
When using `roadrunnerStaticObjectInfo` alongside the scenario generation pipeline (Workflows 4/8):
1. First build the ego/actor scenario as normal → get `rrMap = getRoadRunnerHDMap(scenario)`
2. Then add static objects to the **same** `rrMap` before writing
3. This produces a single `.rrhd` file with roads + lanes + static objects + signs

```matlab
%% Full pipeline: scenario + static objects in one HD map
scenario = exportToDrivingScenario(egoTrajectory, ...
    RoadNetworkSource="OpenStreetMap", FileName=osmFile, Name="Ego");
rrMap = getRoadRunnerHDMap(scenario);

% Add detected/placed static objects
objectsInfo = roadrunnerStaticObjectInfo(staticObjectCuboids, Params=params);
rrMap.StaticObjectTypes = objectsInfo.staticObjectTypes;
rrMap.StaticObjects = objectsInfo.staticObjects;
if isfield(objectsInfo, 'signTypes')
    rrMap.SignTypes = objectsInfo.signTypes;
    rrMap.Signs = objectsInfo.signs;
end

write(rrMap, rrhdFile);
```

----

Copyright 2026 The MathWorks, Inc.

----
