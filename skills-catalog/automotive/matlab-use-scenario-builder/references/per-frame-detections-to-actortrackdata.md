---
name: per-frame-detections-to-actortrackdata
description: Convert per-frame 3D detections (CubeRCNN / KITTI / nuScenes-style corners3D + labels + scores, no persistent IDs) into a scenariobuilder.ActorTrackData object so the Driving Log Analyzer app can overlay them natively on the camera pane. Skips fabrication of a custom VideoWriter cuboid overlay — DLA already does the projection when the CameraData has Intrinsics + Mounting Location/Angles + Ego Origin Height attached.
---

# Per-Frame 3D Detections → `ActorTrackData` (for DLA overlay)

> **Parent skill:** [`SKILL.md`](../SKILL.md). Load this when a dataset ships per-frame 3D detections (8×3 `corners3D` in camera optical frame, or center+dimension+yaw in vehicle frame) without persistent track IDs and you want them visualized on top of the camera in `drivingLogAnalyzer`. **Do NOT build a manual VideoWriter cuboid overlay.** DLA's camera pane has a built-in **Actors** overlay that projects `ActorTrackData` onto the image as long as the `CameraData` has `Intrinsics`, `MountingLocation`, `MountingAngles`, and `EgoOriginHeight` attached.

## Why this path (not a custom overlay)

The Driving Log Analyzer app supports five sensor object types: `GPSData`, `Trajectory`, `CameraData`, `LidarData`, `ActorTrackData`. The Camera toolstrip's **Actors** + **Lane** overlay is the native projection — feeding it `ActorTrackData` is strictly less code than `world2img` + `VideoWriter`, and the user gets synchronized scrubbing for free. CubeRCNN-style `corners3D` arrays cannot be passed to DLA directly; they must first be converted to `Position` / `Dimension` / `Orientation` per the `ActorTrackData` schema.

## Schema mapping

| `ActorTrackData` field | What to compute from per-frame detections |
|------------------------|-------------------------------------------|
| `timestamps` (N×1) | One entry per camera frame that has detections (use the camera timestamp). |
| `trackID` (N×1 cell of M×1 string) | Per-frame placeholder IDs since these are detections, not tracks. Use `"det_<frameIdx>_<i>"` so each cuboid is unique within the frame. |
| `position` (N×1 cell of M×3) | Center of the cuboid in **vehicle frame** (x forward, y left, z up). For CubeRCNN `corners3D` in camera optical frame, take `mean(corners3D, 1)` then transform camera→vehicle using the camera mount. |
| `Category` (N×1 cell of M×1 string) | The detection's `labels` field. |
| `Dimension` (N×1 cell of M×3) | `[length, width, height]` from the cuboid extents. For axis-aligned `corners3D`: `range(corners3D, 1)` after rotating to the cuboid's local frame. |
| `Orientation` (N×1 cell of M×3) | `[yaw, pitch, roll]` in **degrees**. Recover yaw from the cuboid's bottom-face edges (atan2 of edge 1→2) and transform to vehicle frame. |

## Camera→vehicle frame transform

CubeRCNN / KITTI / nuScenes typically emit `corners3D` in the **camera optical frame** (`x` right, `y` down, `z` forward). DLA needs **vehicle frame** (`x` forward, `y` left, `z` up). The standard rotation:

```matlab
% Camera optical -> vehicle (right-down-forward -> forward-left-up):
%   x_veh =  z_cam
%   y_veh = -x_cam
%   z_veh = -y_cam
R_cam2veh = [0 0 1; -1 0 0; 0 -1 0];

% Then translate by the camera mount position (from CameraParams.MountingLocation):
%   p_veh = R_cam2veh * p_cam + mountingLocation
```

If the camera also has roll/pitch/yaw mount angles (`CameraParams.MountingAngles`), pre-multiply by the mount rotation matrix as well. Most front-facing recordings have near-zero mount angles and only the position offset matters.

## Conversion loop

```matlab
%% Inputs:
%   detRaw     : N-by-1 cell, detRaw{k} is a struct array per frame with
%                fields .corners3D (8x3 cam-optical), .labels (string),
%                .scores (double), and optionally .yaw / .dimension.
%   T.extCam   : N-by-1 timestamps for the camera frames (seconds).
%   camParams  : struct from <Camera>_CameraParameters.mat with
%                MountingLocation [x y z] in vehicle frame.
%
% Outputs:
%   detTracks  : scenariobuilder.ActorTrackData ready for DLA.

R_cam2veh = [0 0 1; -1 0 0; 0 -1 0];
mountXYZ  = camParams.MountingLocation(:).';            % 1x3
scoreThr  = 0.30;

ts = []; ids = {}; pos = {}; cat = {}; dim = {}; ori = {};
for k = 1:numel(detRaw)
    if isempty(detRaw{k}), continue; end
    d = detRaw{k};
    keep = [d.scores] >= scoreThr;
    d = d(keep);
    if isempty(d), continue; end

    nm = numel(d);
    pK   = zeros(nm, 3);
    dimK = zeros(nm, 3);
    oriK = zeros(nm, 3);
    catK = strings(nm, 1);
    idK  = strings(nm, 1);

    for i = 1:nm
        c3 = d(i).corners3D;                                   % 8x3 cam-optical
        if ~isequal(size(c3), [8 3]), continue; end

        center_cam = mean(c3, 1);                              % 1x3
        pK(i,:) = (R_cam2veh * center_cam.').' + mountXYZ;

        % Dimension from the cuboid extents along its own bottom edges
        ed1 = c3(2,:) - c3(1,:);                               % length
        ed2 = c3(4,:) - c3(1,:);                               % width
        ed3 = c3(5,:) - c3(1,:);                               % height
        dimK(i,:) = [norm(ed1) norm(ed2) norm(ed3)];

        % Yaw from bottom-edge in camera optical, then to vehicle
        edge_veh = (R_cam2veh * ed1.').';
        yawDeg   = atan2d(edge_veh(2), edge_veh(1));
        oriK(i,:) = [yawDeg 0 0];                              % [yaw pitch roll]

        catK(i) = string(d(i).labels);
        idK(i)  = sprintf("det_%d_%d", k, i);
    end

    ts(end+1,1) = T.extCam(k); %#ok<SAGROW>
    ids{end+1,1} = idK;
    pos{end+1,1} = pK;
    cat{end+1,1} = catK;
    dim{end+1,1} = dimK;
    ori{end+1,1} = oriK;
end

detTracks = scenariobuilder.ActorTrackData(ts, ids, pos, ...
    Category=cat, Dimension=dim, Orientation=ori, Name="CubeRCNNDetections");
```

## Hand off to DLA

Build `cameraData` with the full mounting + intrinsics attached (DLA needs all four to project), then pass both objects in the cell array:

```matlab
cameraData = scenariobuilder.CameraData(T.extCam, imgList, ...
    Name="ExternalRGB", SensorParameters=intrinsics);
% Attach mounting via Attributes / Properties depending on your dataset's helper —
% in DLA's GUI this maps to Mounting Location / Mounting Angles / Ego Origin Height.

drivingLogAnalyzer({gpsData, cameraData, lidarData, detTracks}, Plot=true);
```

In the DLA window: open the **Camera** tab → **Overlay** group → **Actors** → pick `CubeRCNNDetections`. The cuboids render natively, scrubbing stays synchronized with GPS / lidar / camera.

## When you still need a custom overlay video

Only when:
- The user explicitly asks for a saved `.mp4` artifact (shareable, asynchronous review).
- DLA's projection looks wrong because mounting angles aren't quite right and you need to debug intrinsics.

In those cases, the `world2img` + 12-edge cuboid loop is appropriate — but it is a **secondary artifact**, not a replacement for the DLA hand-off.

## Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Forgot the camera→vehicle rotation | Actors hover above the road or appear behind the ego | Apply `R_cam2veh` to `corners3D` centers before storing in `Position`. |
| `Position` left in camera optical frame | DLA renders cuboids but they fly off-screen on every camera turn | Same fix — DLA expects vehicle frame. |
| Mounting Location not attached to `CameraData` | DLA shows actors floating ~1 m above the road | Attach `MountingLocation` (and angles, height) when building `CameraData` per dataset's calibration. |
| Empty per-frame detections crash on `[d.scores]` | `Reference to non-existent field "scores"` | Guard with `if isempty(detRaw{k}), continue; end` before any field access. |
| Track IDs collide across frames | DLA "merges" unrelated detections under one ID | Use `sprintf("det_%d_%d", frameIdx, i)` so every cuboid has a unique ID. |

----

Copyright 2026 The MathWorks, Inc.

----
