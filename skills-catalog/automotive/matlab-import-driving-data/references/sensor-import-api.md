---
name: sensor-import-api
description: How to wrap recorded sensor data into scenariobuilder.* objects (GPSData, ActorTrackData, CameraData, LidarData, Trajectory) using direct constructors or the recordedSensorData factory. Includes field-mapping tables for the two common dataset schemas (consolidated sensorData.mat vs per-sensor-folder + timestamps/*.mat) and a list of sensor types that have NO scenariobuilder wrapper.
---

# Sensor Import API — Wrapping Recorded Data into `scenariobuilder.*`

> **Parent skill:** [`SKILL.md`](../SKILL.md) (driving-data-importer). Load this when a user gives you a dataset in any layout and you need to convert raw structs/cells/files into `scenariobuilder.*` objects ready for `drivingLogAnalyzer` inspection ([`workflow-driving-log-analyzer.md`](workflow-driving-log-analyzer.md)). After cleaning + wrapping, hand the resulting objects to the **scenario-builder** skill for `trajectory(...)`, `actorprops`, lane localization, or RoadRunner / drivingScenario / OpenSCENARIO / OpenDRIVE / OpenCRG export.

## Coverage table — what has a wrapper, what does not

| Sensor type | Wrapper class | Notes |
|-------------|---------------|-------|
| GPS / GNSS | `scenariobuilder.GPSData` | timestamps + lat/lon/alt |
| Local-frame ego waypoints | `scenariobuilder.Trajectory` | usually built from `trajectory(gpsData,...)`, but can be constructed directly |
| Camera (image sequence or video) | `scenariobuilder.CameraData` | accepts file lists, image arrays, video files, or rosbag topics |
| Lidar (point clouds) | `scenariobuilder.LidarData` | accepts `pointCloud` arrays, file lists, or rosbag topics |
| Actor / object tracks (with track IDs) | `scenariobuilder.ActorTrackData` | requires per-frame track-ID lists |
| **Radar** | **none** | no `scenariobuilder.RadarData`. Keep raw struct, do NOT fabricate a wrapper. |
| **IMU** | **none** | no `scenariobuilder.IMUData`. Keep raw struct, do NOT fabricate a wrapper. |
| **Per-frame 3D detections without track IDs** (e.g., CubeRCNN `corners3D` only) | `scenariobuilder.ActorTrackData` with placeholder per-frame IDs | DLA's camera **Actors** overlay projects them natively when `CameraData` has Intrinsics + Mounting Location/Angles + Ego Origin Height. Use IDs `"det_<frameIdx>_<i>"` so each cuboid is unique within the frame. Full conversion in [`per-frame-detections-to-actortrackdata.md`](../../matlab-use-scenario-builder/references/per-frame-detections-to-actortrackdata.md) (in the matlab-use-scenario-builder skill). |

**Rule of thumb:** if `help scenariobuilder.<X>Data` does not return a help page, the wrapper does not exist — do not invent a constructor. Plot/visualize raw radar/IMU/per-frame detections with regular MATLAB plotting.

## Two ways to construct: direct vs factory

Both forms are equivalent. Pick the factory when constructing a mix of sensors in one loop; pick direct constructors when you want explicit type names in code review.

```matlab
%% Direct constructors
gpsData    = scenariobuilder.GPSData(timestamps, lat, lon, alt);
cameraData = scenariobuilder.CameraData(camTimestamps, imageFiles);
lidarData  = scenariobuilder.LidarData(lidarTimestamps, pcdFiles);
trackData  = scenariobuilder.ActorTrackData(trkTimestamps, trackIDs, positions);
egoTraj    = scenariobuilder.Trajectory(timestamps, waypoints);

%% recordedSensorData factory — type-string dispatch
gpsData    = recordedSensorData("gps",        timestamps, lat, lon, alt);
cameraData = recordedSensorData("camera",     camTimestamps, imageFiles);
lidarData  = recordedSensorData("lidar",      lidarTimestamps, pcdFiles);
trackData  = recordedSensorData("actorTrack", trkTimestamps, trackIDs, positions);
egoTraj    = recordedSensorData("trajectory", timestamps, waypoints);   % Nx3
```

Both forms accept the same name-value arguments as their direct constructors (`Name`, `Attributes`, `SensorParameters` for camera/lidar, `Category`/`Dimension`/`Orientation`/`Velocity`/`Speed`/`Age` for actor tracks).

## Schema A — consolidated `sensorData.mat`

A single `.mat` file at the dataset root containing all sensors as fields/tables. Common in many MathWorks examples (Pandaset, VSI quick exports).

```matlab
S = load(fullfile(dataDir, "sensorData.mat"));
gpsData    = scenariobuilder.GPSData(S.GPS.Timestamp, S.GPS.Latitude, S.GPS.Longitude, S.GPS.Altitude);
cameraData = scenariobuilder.CameraData(S.Camera.Timestamp, S.Camera.ImagePath);
trackData  = scenariobuilder.ActorTrackData(S.Tracks.Timestamp, S.Tracks.TrackID, S.Tracks.Position, ...
    Category=S.Tracks.Category, Dimension=S.Tracks.Dimension, Orientation=S.Tracks.Orientation);
```

**Field-name case sensitivity:** `Timestamp` vs `Timestamps` vs `timestamp` varies between datasets. Always `disp(fieldnames(S.<Sensor>))` (or `disp(S.<Sensor>.Properties.VariableNames')` for tables) before accessing.

## Schema B — per-sensor folders + separate `timestamps/*.mat`

Common in larger recordings (VSI-Labs PostProcessed, polysync exports, ros2bag-derived dumps). Each sensor lives in its own folder with binary frames (`.jpeg`, `.pcd`, `.png`), and a sibling `timestamps/<Sensor>.mat` carries the time vector. There may also be a `configs/<Sensor>_CameraParameters.mat` per camera.

```
<dataDir>/
├── ExternalRGBCamera/*.jpeg
├── OSLidar/*.pcd
├── GPS/GPSData.mat        (cell array of per-sample structs)
├── Radar/RadarData.mat    (cell array of per-sample structs — no wrapper)
├── timestamps/
│   ├── ExternalRGBCamera.mat
│   ├── OSLidar.mat
│   ├── GPS.mat
│   └── Radar.mat
└── configs/
    └── ExternalRGBCamera_CameraParameters.mat
```

Build each sensor with the matching timestamp file:

```matlab
%% Camera — image-file list + separate timestamps
extDir   = fullfile(dataDir, "ExternalRGBCamera");
extFiles = dir(fullfile(extDir, "*.jpeg"));
[~, o]   = sort({extFiles.name}); extFiles = extFiles(o);
imgList  = fullfile(extDir, {extFiles.name}');                      % N-by-1 cell of full paths
camTs    = load(fullfile(dataDir, "timestamps", "ExternalRGBCamera.mat")).timestamps;

cameraData = scenariobuilder.CameraData(camTs, imgList, Name="ExternalRGB");

%% Lidar — pcd-file list + separate timestamps
osDir    = fullfile(dataDir, "OSLidar");
osFiles  = dir(fullfile(osDir, "*.pcd"));
[~, o]   = sort({osFiles.name}); osFiles = osFiles(o);
pcdList  = fullfile(osDir, {osFiles.name}');                         % N-by-1 cell of full paths
osTs     = load(fullfile(dataDir, "timestamps", "OSLidar.mat")).timestamps;

osLidar  = scenariobuilder.LidarData(osTs, pcdList, Name="OSLidar");

%% GPS — cell array of per-sample structs needs flattening into column vectors
gpsRaw = load(fullfile(dataDir, "GPS", "GPSData.mat")).GPSData;       % N-by-1 cell
nGPS   = numel(gpsRaw);
lat = zeros(nGPS,1); lon = zeros(nGPS,1); alt = zeros(nGPS,1);
for k = 1:nGPS
    lat(k) = gpsRaw{k}.Latitude;
    lon(k) = gpsRaw{k}.Longitude;
    alt(k) = gpsRaw{k}.Altitude;
end
gpsTs   = load(fullfile(dataDir, "timestamps", "GPS.mat")).timestamps;

gpsData = scenariobuilder.GPSData(gpsTs, lat, lon, alt, Name="GPS");
```

## Attach camera parameters via `SensorParameters` (required for DLA actor/lane overlay)

DLA's actor/lane overlay path requires `cameraData.SensorParameters` to be a **struct with all four fields**:

| Field | Type | Constraint |
|---|---|---|
| `MountingLocation` | 1×3 double `[x y z]` (m, vehicle frame) | finite |
| `MountingAngles`   | 1×3 double `[yaw pitch roll]` (deg) | finite |
| `Intrinsics`       | `cameraIntrinsics` object | required |
| `EgoOriginHeight`  | scalar double (m) | **must be > 0** (DLA rejects 0 with *"must be a positive and finite scalar"*) |

A bare `cameraIntrinsics` *will* be accepted by the property setter but DLA's overlay will refuse it. Always build the full struct.

```matlab
% From ROS-style K (row-major 9x1) + D (5x1 plumb_bob [k1 k2 p1 p2 k3])
camCfg = load(fullfile(dataDir, "configs", "ExternalRGBCamera_CameraParameters.mat")).CameraParams;
K = reshape(camCfg.K, 3, 3).';
intr = cameraIntrinsics([K(1,1) K(2,2)], [K(1,3) K(2,3)], [imgH imgW], ...
    RadialDistortion=[camCfg.D(1) camCfg.D(2) camCfg.D(5)], ...
    TangentialDistortion=[camCfg.D(3) camCfg.D(4)]);

cameraData.SensorParameters = struct( ...
    "MountingLocation", [1.5, 0, camHeight], ...   % see "Mounting geometry" below
    "MountingAngles",   [0, 0, 0], ...
    "Intrinsics",       intr, ...
    "EgoOriginHeight",  0.001);
```

### Mounting geometry — agent guidance

Actor `Position(:,3)` from typical ground-truth or detector pipelines is **already in ego frame with z ≈ 0** (vehicles sit at ground level). The agent never invents calibration — it uses what the dataset provides and explicitly tells the user what the defaults are.

Recommended workflow when the dataset ships only intrinsics + `CameraHeight`:

1. **Auto-fill** with the defaults below and *print them clearly* to the user.
2. Direct the user to the DLA camera-overlay pane and say: *"verify boxes sit on the ground; if pitch is off or boxes float, give me the real `MountingAngles` / `MountingLocation` from your calibration."*
3. Update only the field the user corrects — do not silently retune all four.

| Field | Default | Why |
|---|---|---|
| `MountingLocation(1)` (forward) | `1.5` m | Typical ADAS rig; rarely off by enough to ruin overlay. |
| `MountingLocation(2)` (lateral) | `0` | Centered. |
| `MountingLocation(3)` (height)  | `CameraHeight` from source, else `1.5` m | Largest geometric impact after intrinsics. |
| `MountingAngles` `[yaw pitch roll]` | `[0 0 0]` deg | Pitch is the second-most-impactful param after intrinsics — even 2–3° tilts cuboids vertically. Surface this to the user. |
| `EgoOriginHeight` | `0.001` m | Just needs to be positive to clear DLA's validator. Do NOT put `CameraHeight` here — that lifts every actor by `camHeight` and they project at the horizon (the "boxes in the air" failure mode). |

### When the dataset has no intrinsics

Leave `cameraData.SensorParameters` empty and tell the user:

> "No camera intrinsics found in the source. DLA actor/lane overlay will be disabled until you provide `fx, fy, cx, cy` (and optionally `imageSize`, `RadialDistortion`, `TangentialDistortion`) from the camera calibration file."

Do **not** fabricate a pinhole guess from image size — a plausible-but-wrong overlay is worse than a disabled one (it produces silently misaligned cuboids that a user may not notice).

## After wrapping — what happens next

The default next step is **NOT** to launch DLA. After the sensors are wrapped:

1. **Save** the wrapped objects (`save sandbox/<dataset>_wrapped.mat gpsData cameraData lidarData trackData`).
2. **Print a one-screen summary** (sensor counts, durations, sample rates).
3. **Hand off to `matlab-use-scenario-builder`** if the user asked to virtualize / build a scenario / generate a scene / export to RoadRunner / drivingScenario / OpenSCENARIO / OpenDRIVE / OpenCRG / Unreal / simulate.

`drivingLogAnalyzer` is **opt-in only** (Rule 0 in `SKILL.md`). Launch it **only** when the user explicitly asks (`DLA`, `drivingLogAnalyzer`, "open in DLA", "inspect / visualize / explore / replay / analyze the recording") **or** reports a sensor-data problem DLA is built to debug (sync drift, timestamp mismatch, overlay misalignment, missing frames, shifted timeline).

When DLA *is* invoked:

```matlab
% drivingLogAnalyzer takes no programmatic arguments — it imports from the
% MATLAB workspace via its UI. Just ensure the wrapped objects are in scope:
drivingLogAnalyzer;   % then user clicks Import → From Workspace
```

DLA handles synchronization, scrubbing, and per-pane visualization automatically; do **not** build a manual VideoWriter dashboard for inspection. See [`workflow-driving-log-analyzer.md`](workflow-driving-log-analyzer.md) for the full opt-in recipe.

## Sensors without a wrapper — radar, IMU

These do NOT have a `scenariobuilder.*` class. Keep them as their loaded form (cell array of structs, struct of arrays, or table) and visualize with regular MATLAB:

- **Radar BEV:** `scatter(x, y, 36, radial_speed, "filled")` on Cartesian axes — see the radar pane in any of the example scripts.
- **IMU:** `plot(t, [linAccel angVel])` — diagnostics only; not consumed by `actorprops` / RR export.

## Per-frame 3D detections — wrap into `ActorTrackData` for DLA

CubeRCNN / KITTI / nuScenes-style detections (per-frame `corners3D` + `labels` + `scores`, no persistent IDs) **DO** belong in `ActorTrackData` — DLA's camera pane has a built-in **Actors** overlay that projects the cuboids onto the image as long as the `CameraData` has Intrinsics + Mounting Location/Angles + Ego Origin Height attached. Assign placeholder per-frame IDs (`"det_<frameIdx>_<i>"`) so each cuboid is unique within its frame. Full conversion (camera→vehicle rotation, center/dimension/yaw mapping, the `ActorTrackData` constructor, and the DLA hand-off) is in [`per-frame-detections-to-actortrackdata.md`](../../matlab-use-scenario-builder/references/per-frame-detections-to-actortrackdata.md) (in the matlab-use-scenario-builder skill).

If detections need to participate in the *scenario* (RR export, `actorprops`, etc., where persistent track IDs are required), run a tracker first (`matlab-use-scenario-builder` Workflow 14, sensor-fusion tracking) to assign IDs, then rebuild `ActorTrackData` from the tracker output.

----

Copyright 2026 The MathWorks, Inc.

----
