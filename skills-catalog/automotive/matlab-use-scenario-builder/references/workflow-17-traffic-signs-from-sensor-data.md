---
name: workflow-17-traffic-signs-from-sensor-data
description: Add traffic signs (and their posts) to a RoadRunner HD Map using recorded camera images, lidar point clouds, and pre-detected sign bounding boxes. Camera supplies sign labels and 2D pixel boxes; lidar supplies depth/dimensions; the camera-to-lidar pose plus intrinsics let helperEstimateSignCuboids project image boxes onto point clouds to produce 9-DOF sign cuboids; signposts are inferred from the sign cuboids; everything is attached as roadrunner.hdmap.Sign + roadrunner.hdmap.StaticObject via roadrunnerStaticObjectInfo.
---

# Workflow 17 — Traffic Signs from Recorded Camera + Lidar Logs

> **Parent skill:** [`SKILL.md`](../SKILL.md). Load this when the user wants to **place traffic signs** (and their posts) onto a road scene using **recorded** camera + lidar data with **pre-detected sign bounding boxes** — not from aerial lidar, and not by manually placing assets.
>
> **Related references:**
> - [`workflow-09-static-objects.md`](workflow-09-static-objects.md) — `roadrunnerStaticObjectInfo` contract (M×9 cuboids, asset paths, default dimensions). Sign placement is a special case of static-object placement.
> - [`workflow-16-aerial-lidar-augmentation.md`](workflow-16-aerial-lidar-augmentation.md) — for trees and buildings instead of signs.
> - [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) — `importScene` + overlap-groups rule used at the end.

## When to use

The user has **all three** of:
1. Time-synchronized **camera images** (frame sequence) and **lidar PCDs**
2. **Pre-detected** traffic-sign 2D bounding boxes in **pixel coordinates** with class labels (from a labeling app or an existing detector)
3. Camera **intrinsics** (focal length, principal point, image size) and **camera-to-lidar pose**, plus per-frame lidar **world poses** and synchronized **GPS** for the geo-reference

If any of these are missing — e.g., no pre-existing sign labels, only sign labels in 3D not in pixels, no camera-to-lidar pose — STOP and ASK the user to obtain them. Do not try to detect signs from scratch in this skill.

## Required input data layout

| Variable | Type | Required columns / fields |
|----------|------|---------------------------|
| `lidarData` | table | `timestamp`, `filename` (path to PCD), `position` (1×3 world XYZ), `orientation` (1×4 quaternion) |
| `cameraDetections` | table | `timestamp`, `filename` (image path), `boxes` (M×4 pixel `[x y w h]`), `labels` (M×1 categorical / string of sign class) |
| `cameraParameters` | struct | `.focalLength` (1×2), `.principalPoint` (1×2), `.imageSize` (1×2) |
| `cameraToLidarPose` | `rigidtform3d` | extrinsic from camera frame → lidar frame |
| `gpsData` | table / struct | `latitude`, `longitude` per timestamp (used to set `rrMap.GeoReference`) |

The MathWorks reference example uses a 80-frame PandaSet subset; load it via `helperLoadPandasetTrafficSignsData(dataset)`.

## Prerequisites

- Scenario Builder for Automated Driving Toolbox (support package)
- Automated Driving Toolbox
- Computer Vision Toolbox
- Lidar Toolbox
- Sensor Fusion and Tracking Toolbox
- Mapping Toolbox
- RoadRunner with **Scene Builder** license (for `importScene`)

## Pipeline overview

```
recorded   pre-detected         camera         lidar
camera   + 2D sign boxes  +  intrinsics +  cam→lidar pose
   │           │                  │              │
   ▼           ▼                  ▼              ▼
        helperEstimateSignCuboids  ───►  9-DOF sign cuboids (per frame)
                       │
                       ▼
        helperRemoveDuplicateSigns  +  helperGroupStackedSigns
                       │
                       ▼
        helperEstimateSignPostCuboids (with lidar)
                       │
                       ▼
        helperArrangeCuboids  ───►  trafficSignCuboids table
                       │
                       ▼
        helperMapLabelsToRoadRunnerSignTypes
                       │
                       ▼
        roadrunnerStaticObjectInfo
                       │
                       ▼
        rrMap.SignTypes / Signs / StaticObjectTypes / StaticObjects
                       │
                       ▼
        write(rrMap, "*.rrhd")  +  importScene(rrApp, ...)
```

## Step 1 — Load sensor data and build datastores

Note the **−90° z-rotation** that the toolchain applies to the lidar so it aligns with the Automated Driving Toolbox sensor convention. Do not skip this — sign cuboids will come out rotated otherwise.

```matlab
%% Step 1: Load sensors
sensorData = helperLoadPandasetTrafficSignsData(dataset);   % or your own loader

lidarData = sensorData.lidarData;
cdsLidar  = helperCreateCombinedDatastoreLidar(lidarData);

isWorldFrame = true;
rotationInLidarFrame = [0 0 -90];
cdsLidar = transform(cdsLidar, ...
    @(d) helperTransformPointCloudFcn(d, isWorldFrame, rotationInLidarFrame));

cameraDetections = sensorData.cameraDetections;
cdsCamera = helperCreateCombinedDatastoreCamera(cameraDetections);
```

`helperCreateCombinedDatastoreLidar` and `helperCreateCombinedDatastoreCamera` are example helpers — copy them as local functions per Rule 9 of SKILL.md. Body for reference (verbatim from the MathWorks doc):

```matlab
function cdsLidar = helperCreateCombinedDatastoreLidar(lidarData)
pcds = fileDatastore(lidarData.filename, "ReadFcn", @pcread);
lidarPoses = rigidtform3d.empty;
for i = 1:size(lidarData, 1)
    rot = quat2rotm(quaternion(lidarData.heading(i, :)));
    tran = lidarData.position(i, :);
    lidarPoses(i, 1) = rigidtform3d(rot, tran);
end
poses = arrayDatastore(lidarPoses);
cdsLidar = combine(pcds, poses);
end

function cdsCamera = helperCreateCombinedDatastoreCamera(cameraData)
imds = imageDatastore(cameraData.filename);
blds = boxLabelDatastore(cameraData(:, 3:end));
cdsCamera = combine(imds, blds);
end
```

## Step 2 — Camera intrinsics and camera-to-lidar pose

```matlab
%% Step 2: Build cameraIntrinsics and align cam→lidar with the same -90° z-rot
cameraParameters = sensorData.cameraParameters;
intrinsics = cameraIntrinsics( ...
    cameraParameters.focalLength, ...
    cameraParameters.principalPoint, ...
    cameraParameters.imageSize);

cameraToLidarPose = sensorData.cameraToLidarPose;
cameraToLidarPose = helperTransformCameraToLidarPose( ...
    cameraToLidarPose, rotationInLidarFrame);
```

## Step 3 — Estimate sign cuboids (camera + lidar fusion)

This is the core fusion step. Pixel boxes come from camera detections; depth and dimension come from the lidar; the cam→lidar pose stitches them together.

```matlab
%% Step 3: Project pixel boxes onto lidar to get 9-DOF cuboids
asprThreshold = [0.5 2];   % aspect-ratio (height/width) sanity gate
cuboidSigns = helperEstimateSignCuboids( ...
    cdsCamera, cdsLidar, intrinsics, cameraToLidarPose, asprThreshold);
```

`asprThreshold` rejects degenerate aspect ratios — adjust upward if the user has unusual sign types (e.g., wide variable-message signs).

## Step 4 — Deduplicate and group stacked signs

The same physical sign appears in many consecutive frames, producing many near-identical cuboids. Cluster within a distance threshold, then group signs that share a post (stacked stop+street-name, etc.):

```matlab
%% Step 4: Collapse repeats across frames; group co-mounted signs
distanceThreshold = 1.5;   % metres
cuboidSigns = helperRemoveDuplicateSigns(cuboidSigns, distanceThreshold);
cuboidSigns = helperGroupStackedSigns(cuboidSigns);
```

## Step 5 — Estimate signposts

Posts are inferred from the consolidated sign cuboids together with the lidar. Run this AFTER Step 4 so each post corresponds to a unique physical sign.

```matlab
%% Step 5: Infer post (pole) cuboids from signs + lidar
cuboidSignPosts = helperEstimateSignPostCuboids(cuboidSigns, cdsLidar);
```

## Step 6 — Arrange cuboids into the table format `roadrunnerStaticObjectInfo` expects

```matlab
%% Step 6: Unify into a label/cuboids table
trafficSignCuboids = helperArrangeCuboids(cuboidSigns, cuboidSignPosts);
```

Output table has columns:
- `label` — RoadRunner-recognized sign type (string)
- `cuboids` — M×9 `[xctr yctr zctr xlen ylen zlen xrot yrot zrot]` matrix

Same M×9 contract as [`workflow-09-static-objects.md`](workflow-09-static-objects.md).

## Step 7 — Build the HD map

```matlab
%% Step 7: Load prebuilt road geometry; pin the geo-reference to the GPS
rrMap = roadrunnerHDMap;
read(rrMap, "mapWithRoads.rrhd");

gpsData = sensorData.gpsData;
rrMap.GeoReference = [gpsData.latitude(1) gpsData.longitude(1)];
```

If the user does NOT yet have `mapWithRoads.rrhd`, build it first via the standard OSM pipeline ([`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) Step 4 / SKILL.md Rule 4 step 4) and `write(rrMap, "mapWithRoads.rrhd")` before this step.

## Step 8 — Map labels and attach to map

```matlab
%% Step 8: Convert labels to RR sign types, then attach
staticObjects = helperMapLabelsToRoadRunnerSignTypes(trafficSignCuboids);
objectsInfo = roadrunnerStaticObjectInfo(staticObjects);

rrMap.SignTypes         = objectsInfo.signTypes;
rrMap.Signs             = objectsInfo.signs;
rrMap.StaticObjectTypes = objectsInfo.staticObjectTypes;
rrMap.StaticObjects     = objectsInfo.staticObjects;
```

Unmatched class labels (those `helperMapLabelsToRoadRunnerSignTypes` cannot map to a built-in RR sign) go into a `miscellaneousSign` field — `roadrunnerStaticObjectInfo` accepts a `Params` name-value to point at a custom asset:

```matlab
% Optional: custom asset for unmatched labels
params.miscellaneousSign.AssetPath = "Signs/MyCustomSign01.fbx_rrx";
objectsInfo = roadrunnerStaticObjectInfo(staticObjects, Params=params);
```

> `addElevation` is **NOT** part of this workflow as documented. Sign cuboid Z comes from the lidar, which already has real elevation. Only call `addElevation` if you observe signs floating or sunk after import — and then you usually want to fix the underlying lidar pose, not patch with `addElevation`.

## Step 9 — Write `.rrhd` and import into RoadRunner

The MathWorks doc derives the world origin from the map's CRS instead of the GPS first sample — that keeps the imported scene aligned with how the HD map was authored. Use this form:

```matlab
%% Step 9: Write and import (overlap groups disabled — Rule 4 of SKILL.md)
write(rrMap, "TrafficSignScene.rrhd");

% Single-instance guard (Rule 8)
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end

copyfile("TrafficSignScene.rrhd", fullfile(rrProjectPath, "Assets"));
rrhdFile = fullfile(rrProjectPath, "Assets", "TrafficSignScene.rrhd");

% Anchor RR's world origin to the HD map's CRS
geoRef = [rrMap.readCRS().ProjectionParameters.LatitudeOfNaturalOrigin ...
          rrMap.readCRS().ProjectionParameters.LongitudeOfNaturalOrigin];
changeWorldSettings(rrApp, WorldOrigin=geoRef);

% Per Rule 4: always disable overlap groups on import
oOpts = enableOverlapGroupsOptions(IsEnabled=false);
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, rrhdFile, "RoadRunner HD Map", ImportOptions=iOpts);
```

The MathWorks doc page omits the `ImportOptions` argument; SKILL.md Rule 4 makes overlap-groups-off mandatory for every `importScene` call, so we add it here.

## Output

- Binary HD Map: **`TrafficSignScene.rrhd`** with sign types, signs, static object types, and static objects all attached.
- After `importScene`, the RoadRunner scene shows signs mounted on posts at their measured positions.
- (Optional) Export the imported scene to ASAM OpenDRIVE via `exportScene(rrApp, file, "OpenDRIVE")` — preserves signs as OpenDRIVE objects.

## When this is the wrong workflow

| User's situation | Where to go instead |
|------------------|---------------------|
| Trees / buildings (not signs) | [`workflow-16-aerial-lidar-augmentation.md`](workflow-16-aerial-lidar-augmentation.md). |
| Generic static-object cuboids (cones, barriers, lights) from any source | [`workflow-09-static-objects.md`](workflow-09-static-objects.md). |
| No pre-existing sign detections — needs a detector trained from scratch | Out of scope. Direct the user to the Automated Driving Toolbox sign-detection examples; come back here once detections exist. |
| Aerial top-down lidar (no per-frame camera) | [`workflow-16-aerial-lidar-augmentation.md`](workflow-16-aerial-lidar-augmentation.md) — RandLA-Net does not currently include a `signs` class, so signs from aerial-only data are unreliable. |

----

Copyright 2026 The MathWorks, Inc.

----
