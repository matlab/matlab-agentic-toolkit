---
name: matlab-import-driving-data
description: "Import recorded driving sensor data (GPS, camera, lidar, actor tracks, lanes) into scenariobuilder.* objects (GPSData, CameraData, LidarData, ActorTrackData, Trajectory, laneData) and run preprocessing — synchronize, offset correction, crop, normalizeTimestamps, convertTimestamps. Also: compute actor tracks from lidar when no annotations exist, attach camera/lidar mounting + intrinsics, export to MAT/workspace/timetable/script. Use for raw driving dataset files (KITTI, nuScenes, Waymo, Pandaset, ROS/ROS2 bags, .mat, .csv, .mp4) or driving/vehicle/sensor logs that need wrapping. drivingLogAnalyzer (DLA) is OPT-IN ONLY — invoke only on explicit user request ('DLA', 'open in DLA', 'inspect/explore/analyze the recording') or reported sensor problem (sync drift, timestamp mismatch, overlay misalignment). NEVER auto-launch DLA after wrapping (Rule 0). For 'build scenario / export to RoadRunner / drivingScenario / OpenSCENARIO / Unreal / simulate', hand off to matlab-use-scenario-builder."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Driving Data Importer

This skill loads raw driving sensor data into `scenariobuilder.*` objects (`GPSData`, `CameraData`, `LidarData`, `ActorTrackData`, `Trajectory`, `laneData`) and provides the CLI for every preprocessing step DLA exposes (sync, crop, offset, normalize, convert timestamps). It also covers the `drivingLogAnalyzer` (DLA) app **as an opt-in inspection tool** — see *Rule 0* below; DLA is never a default step.

After wrapping is done, the canonical next move is `matlab-use-scenario-builder` (trajectory smoothing, scene/scenario generation, lane localization, RoadRunner / drivingScenario / OpenSCENARIO / OpenDRIVE / OpenCRG / Unreal export).

## Rule 0 — DLA is opt-in only (HARD RULE, READ FIRST)

**Never call `drivingLogAnalyzer` unless the user explicitly asks for it or has reported a sensor-data problem DLA is built to debug.** Auto-launching DLA after wrapping data is a first-attempt-success failure: it stalls the user (a UI app forces context-switch, scrub, click, confirm) and signals that the agent is not confident the import worked.

**When DLA IS allowed — only these two cases:**

1. **Explicit user request** — user types `DLA`, `drivingLogAnalyzer`, "open in DLA", "inspect / visualize / explore / replay / analyze the recording", "open the driving log analyzer".
2. **Reported sensor-data problem** that DLA is the right tool for:
   - "the sensors look out of sync"
   - "camera and lidar timestamps don't match"
   - "actor cuboids float above the cars" (overlay alignment)
   - "I see missing frames / a gap in the timeline"
   - "the offset looks wrong / the timeline is shifted"

**When DLA is NOT allowed (defaults — go straight to `matlab-use-scenario-builder`):**

- "Virtualize this data", "build a scenario from this data", "generate a scene", "export to RoadRunner / drivingScenario / OpenSCENARIO / OpenDRIVE / OpenCRG / Unreal", "simulate this drive", "I have data, do something with it".
- *Anything that has a downstream simulation or scenario target.*

If you ever feel an urge to add a "let me open DLA so you can verify" step after wrapping — **stop.** Save the wrapped objects to `sandbox/<dataset>_wrapped.mat`, print a short summary, and hand off.

## When to Use

- User has raw driving dataset files (KITTI, nuScenes, Waymo, custom logs, ROS/ROS2 bags, .mat, .csv, .xls, video) and needs them loaded into `scenariobuilder.*` objects
- User says **"open in DLA"**, **"drivingLogAnalyzer"**, **"inspect / visualize / explore / replay / analyze this dataset"** *(triggers DLA — Rule 0 case 1)*
- User wants to map raw structs/tables/rosbag topics to `GPSData`, `CameraData`, `LidarData`, `ActorTrackData`, `Trajectory`, or `laneData`
- User wants to attach camera/lidar **Mounting Location / Mounting Angles / Intrinsics / Ego Origin Height**
- User asks for **multi-sensor synchronization** of any kind: "sync", "align sensors", "match sample rates", "resample to a common timeline", "sensor-to-sensor alignment"
- User asks for **offset correction** ("drag-to-align", "time offset", "shift this sensor by X seconds")
- User asks to **crop / trim / extract a segment** of a recording across sensors
- User asks to **normalize timestamps** ("common t=0", "time origin", "POSIX to seconds", "datetime to numeric")
- User wants to **export sensor data** to MAT, workspace, timetable, or a reproducible script
- User needs to inspect dataset structure, identify available sensor modalities, validate calibration transforms, or check for pre-computed annotations
- User needs to compute actor tracks from lidar when no annotations exist (clustering / detector / camera-based pipeline)
- User reports a **sensor-data problem** (Rule 0 case 2) — wrap, then offer DLA as the debugging path

## When NOT to Use

- **Do NOT auto-launch DLA after wrapping.** If the user asked to virtualize / build a scenario / export to a sim format, finish wrapping and hand off to `matlab-use-scenario-builder` directly. (Rule 0.)
- User wants to **build / generate / export a scenario** (RoadRunner, drivingScenario, OpenSCENARIO, OpenDRIVE, OpenCRG, Unreal) — wrap here, then hand off to **`matlab-use-scenario-builder`**.
- User wants to **smooth a trajectory**, **localize ego on a lane**, **correct height on a terrain scene**, **place static objects** (signs/trees/poles), **extract a road surface (OpenCRG)** from lidar, **generate 3D assets** from images, **add elevation** to a map, or **georeference point clouds** — all `matlab-use-scenario-builder`
- User wants to **run sensor-fusion tracking** (`multiSensorTargetTracker`, JPDA + smoother) to get cleaner tracks — `matlab-use-scenario-builder` Workflow 14
- User is debugging general MATLAB code unrelated to dataset import — use `matlab-debug-code`
- User wants to install a toolbox or check MATLAB products — use `matlab-list-products` / `matlab-install-products`
- Task is about non-driving sensor data (medical imaging, audio, etc.) — out of scope

**Boundary heuristic:** wrapping into `scenariobuilder.*` and any sync/crop/offset/normalize CLI work belongs here. The moment the user says *scenario / scene / RoadRunner / simulate / drive in a virtual world / export to OpenSCENARIO / virtualize* — wrap, save, hand off. DLA stays parked unless invoked by name or summoned by a reported problem.

## IMPORTANT — Execution Rules

### Rule 1: Inspect Before Importing
**Always inspect the dataset structure first.** Before writing any import code:
1. List the top-level directory structure
2. Identify what sensor modalities are available (GPS, lidar, camera, annotations)
3. Determine if pre-computed annotations/labels exist (3D bounding boxes, tracks)
4. Check calibration files for coordinate frame definitions

### Rule 2: Check for Existing Annotations Before Computing Tracks
**Never run a lidar tracker if the dataset already provides actor tracks or 3D bounding box annotations.** Always check first:
- Look for annotation files (`object_detection.json`, `labels/`, `annotations/`, `tracking/`)
- Check if annotations are per-frame (temporal tracks) or single-keyframe only
- If annotations exist, map them directly to `ActorTrackData`
- If only keyframe annotations exist (no temporal tracking), inform the user and discuss options

### Rule 3: Understand Dataset Structure Types
Driving datasets commonly have two types of recordings:

| Type | Duration | Annotations | Use Case |
|------|----------|-------------|----------|
| **Drives/Logs** | Long (1-10 min) | Often none | Ego trajectory + road network |
| **Sequences/Clips** | Short (10-30s) | Usually yes (keyframe or full) | Actor tracks + ego |

**Always clarify which type the user's data is** before proceeding. If data lacks annotations, inform the user that actor tracks must be computed (via lidar detection/tracking or camera detection) and set expectations about quality.

### Rule 4: Validate Coordinate Frames
Before using any transform, verify:
1. What coordinate frame convention the dataset uses (e.g., X-forward vs Y-forward)
2. Whether extrinsic transforms are sensor-to-ego, sensor-to-vehicle, or sensor-to-sensor
3. Validate by checking that transformed ground points have Z near 0 in ego frame

### Rule 5: Report Data Summary to User
After initial inspection, always present a summary:
```
Dataset: <name>
Recording: <ID/name>
Duration: <X seconds>
Available sensors:
  - GPS: <format, sample count, rate>
  - Lidar: <format, frame count, rate, sensor model>
  - Camera: <format, frame count, rate, resolution>
  - Annotations: <YES/NO — type if yes>
Calibration: <available transforms>
```

---

## Common Dataset Formats

### GPS / GNSS / IMU
| Format | How to Read |
|--------|-------------|
| JSON (lat/lon/alt arrays) | `jsondecode(fileread(file))` |
| HDF5 (fields in groups) | `h5read(file, '/group/field')` |
| CSV | `readtable(file)` |
| ROS bag | `scenariobuilder.GPSData("file.bag", "/topic")` |
| NMEA | Custom parser needed |

**Key fields needed:** timestamps, latitude, longitude, altitude

### Lidar Point Clouds
| Format | How to Read |
|--------|-------------|
| PCD | `pcread(file)` |
| PLY | `pcread(file)` |
| BIN (KITTI format) | `reshape(fread(fid,'single'),[4,Inf])'` — columns: x,y,z,intensity |
| NPY (custom struct) | Custom reader needed — parse header, read structured bytes |
| LAS/LAZ | `lasFileReader(file)` then `readPointCloud` |

**Important:** Always check the point cloud coordinate frame. Common conventions:
- **X-forward, Y-left, Z-up** (ROS/vehicle standard)
- **X-right, Y-forward, Z-up** (some lidars)
- **X-forward, Y-right, Z-up** (KITTI)

### Camera Images
| Format | How to Read |
|--------|-------------|
| Directory of images | `imageDatastore(dir)` |
| Video file | `VideoReader(file)` |
| ROS bag | `rosbag` then read image messages |

**Key info needed:** timestamps, file paths, intrinsics, distortion model, extrinsics (camera-to-ego)

### Calibration
Calibration files typically provide:
- **Intrinsics:** focal length, principal point, distortion coefficients
- **Extrinsics:** 4x4 homogeneous transforms between sensor frames
- **Distortion model:** pinhole, fisheye (Kannala), equidistant, etc.

**Common pitfall:** The naming of extrinsic transforms is inconsistent across datasets. A field named `lidar_extrinsics` could mean:
- lidar-to-ego (most common)
- lidar-to-camera
- ego-to-lidar (inverse)

**Always verify** by checking translation values against physical sensor mounting positions (e.g., lidar mounted ~1.7m high should have Z translation ~1.7 in lidar-to-ego).

### 3D Bounding Box Annotations
Common formats:
```
Per object:
  - class: "Car", "Truck", "Pedestrian", etc.
  - location_3d: [x, y, z] — center position in some reference frame
  - size: [length, width, height] in meters
  - orientation: quaternion or yaw angle
  - track_id: persistent ID across frames (if temporal tracking exists)
```

**Frame of reference:** Annotations may be in:
- Ego/vehicle frame (most common for driving datasets)
- World/global frame
- Sensor frame (lidar or camera)

Always check which frame and transform to ego if needed.

---

## Import Pipeline

### Step 1: GPS → GPSData

**Canonical GPSData construction is THREE lines, always together** — bare `scenariobuilder.GPSData(...)` is incomplete. The post-construction `convertTimestamps` + `normalizeTimestamps` calls are part of the canonical construction, not optional cleanup. Downstream APIs (`synchronize`, `trajectory`, `actorprops`, `localizeEgoUsingLanes`, RoadRunner export) expect numeric timestamps starting at t=0.

```matlab
% Load timestamps, lat, lon, alt from dataset
gpsData = scenariobuilder.GPSData(timestamps, latitude, longitude, altitude);

% Canonical post-construction pair (always run both)
convertTimestamps(gpsData, "numeric");
timeRef = normalizeTimestamps(gpsData);
```

If you skip these two lines, the object will silently fail later (sample-rate mismatches in `synchronize`, scenario time bounds wrong, RoadRunner export errors). Run them every time, even when you "just" construct a `GPSData` for inspection — and even when the prompt only says "construct the GPSData object."

**Altitude handling:**
- If using OpenStreetMap roads: **zero the altitude** (`altitude = zeros(...)`) — OSM has no elevation
- If using a scene with terrain elevation: keep real altitude
- If altitude is missing: use zeros

### Step 2: Annotations → ActorTrackData
When per-frame 3D annotations with track IDs exist:
```matlab
% For each timestamp, collect track IDs and positions
timestamps = <Nx1 numeric>;
trackIDs = cell(N, 1);    % each cell: Mx1 string array
positions = cell(N, 1);   % each cell: Mx3 [x y z] in ego frame

for i = 1:N
    % Get annotations for frame i
    frameAnnots = <filter annotations for this frame>;
    trackIDs{i} = string({frameAnnots.track_id}');
    positions{i} = [frameAnnots.x, frameAnnots.y, frameAnnots.z];
end

trackData = scenariobuilder.ActorTrackData(timestamps, trackIDs, positions);
```

**If annotations are in world frame** (not ego frame):
```matlab
% Transform world positions to ego-relative positions
% ActorTrackData expects positions relative to ego at each timestamp
for i = 1:N
    worldPos = positions_world{i};
    egoPos = egoPositionAtTime(i);  % from GPS/odometry
    egoYaw = egoYawAtTime(i);
    R = [cos(egoYaw) sin(egoYaw) 0; -sin(egoYaw) cos(egoYaw) 0; 0 0 1];
    positions{i} = (worldPos - egoPos) * R';
end
```

### Step 3: Camera → CameraData
```matlab
% Match camera image files to timestamps
imageFiles = dir(fullfile(camDir, '*.jpg'));
camTimestamps = <parse timestamps from filenames or metadata>;

cameraData = scenariobuilder.CameraData(camTimestamps, ...
    fullfile(camDir, {imageFiles.name}'), Name="FrontCamera");
```

### Step 4: Lidar → LidarData

**Always wrap lidar via `scenariobuilder.LidarData`** — this is the only wrapper DLA accepts and the only one downstream Scenario Builder APIs (Workflow 10 OpenCRG extraction, Workflow 11 georeferencing) consume. Do not hand DLA raw `pointCloud` arrays or paths.

```matlab
% Match lidar files (.pcd, .ply, .las/.laz) to timestamps
lidarFiles = dir(fullfile(lidarDir, '*.pcd'));
lidarTimestamps = <parse timestamps from filenames or metadata>;

lidarData = scenariobuilder.LidarData(lidarTimestamps, ...
    fullfile(lidarDir, {lidarFiles.name}'), Name="OSLidar");
```

For multi-lidar setups, build one `scenariobuilder.LidarData` per sensor with a distinct `Name` (e.g., `"OSLidar"`, `"VLP32"`, `"OuterLeft"`). DLA will render each in its own pane.

### Step 5: Synchronize All Sensors
```matlab
convertTimestamps(gpsData, "numeric");
convertTimestamps(trackData, "numeric");

timeRef = normalizeTimestamps(gpsData);
normalizeTimestamps(trackData, timeRef);
synchronize(trackData, gpsData);
```

### Step 6: Launch DLA — only when explicitly requested (Rule 0)

**`drivingLogAnalyzer` does NOT accept programmatic sensor inputs.** It opens the app; the user then imports sensors via the GUI (`Import → From Workspace`). Make sure the wrapped objects are in the base workspace, then launch the app bare:

```matlab
% Wrapped objects must already exist in the base workspace
% (gpsData, cameraData, lidarData, trackData)
drivingLogAnalyzer;   % user clicks Import → From Workspace
```

Do NOT call forms like `drivingLogAnalyzer(sensors, Plot=true)` or `drivingLogAnalyzer(gpsData, Plot=true)` — those signatures are not supported and will error. Remember Rule 0: launch DLA only when the user explicitly asks for it or reports a sensor-data problem DLA is built to debug. (See [`workflow-driving-log-analyzer.md`](references/workflow-driving-log-analyzer.md) for the full opt-in recipe.)

---

## When No Annotations Exist — Computing Actor Tracks from Lidar

If the dataset has NO pre-computed 3D bounding boxes or temporal tracks, actor tracks must be computed. **Always inform the user** about:
1. This requires significant processing and tuning
2. Results depend heavily on scene complexity (open highway = good, dense urban = poor)
3. Deep learning detectors (PointPillars, CenterPoint) give much better results than clustering

### Option A: Deep Learning Detector (Preferred)
```matlab
% Requires a trained model (e.g., PointPillars)
detector = pointPillarsObjectDetector(net, pcRange, classNames, anchorBoxes);
bboxes = detect(detector, ptCloud);
```

### Option B: Classical Pipeline (Clustering + Tracking)
```matlab
% Per frame:
% 1. Transform lidar to ego frame
% 2. Remove ground plane
% 3. Filter ROI
% 4. Euclidean clustering
% 5. Size filtering
% 6. Feed detections to tracker (JPDA or GNN)
```

**Known limitations of clustering approach:**
- Dense urban scenes: parked cars, buildings, and road infrastructure form continuous surfaces that cannot be segmented into individual objects
- Mega-clusters: thousands of points merging into single clusters spanning 20+ meters
- False positives: poles, signs, trees, walls pass size filters
- Works best on: highways, open roads with isolated vehicles

### Option C: Camera-Based Detection
```matlab
% Use pretrained camera detector
detector = vehicleDetectorYOLOv2();  % or vehicleDetectorFasterRCNN()
[bboxes, scores] = detect(detector, img);
```
**Limitation:** Gives 2D boxes only. Requires depth estimation or lidar fusion for 3D positions.

---

## Projection: Lidar Points → Camera Image

To verify detection alignment or overlay lidar on camera:
```matlab
% Transform lidar to camera frame
T_lidar2cam = inv(T_cam2ego) * T_lidar2ego;  % compose transforms
pts_cam = (T_lidar2cam * [pts_lidar, ones(N,1)]')';

% Project to pixels (pinhole model)
inFront = pts_cam(:,3) > 0;
u = fx * pts_cam(inFront,1) ./ pts_cam(inFront,3) + cx;
v = fy * pts_cam(inFront,2) ./ pts_cam(inFront,3) + cy;

% Display
imshow(img); hold on;
scatter(u, v, 1, depth, 'filled');
```

**For fisheye cameras:** Standard pinhole projection will have errors at image edges. Use the camera's distortion model for accurate projection.

---

## Checklist Before Starting Import

- [ ] What sensors does the dataset provide?
- [ ] Are there pre-computed annotations/3D bounding boxes?
- [ ] Are annotations per-frame (temporal) or keyframe-only?
- [ ] What coordinate frame are positions in?
- [ ] What is the calibration transform naming convention?
- [ ] Does altitude data exist? Will OSM or scene-based roads be used?
- [ ] What is the recording duration? Need to crop?

----

Copyright 2026 The MathWorks, Inc.

----
