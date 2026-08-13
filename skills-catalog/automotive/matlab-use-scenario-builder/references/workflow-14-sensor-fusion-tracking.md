---
name: workflow-14-sensor-fusion-tracking
description: Produce high-quality non-ego objectTrack outputs from raw multi-sensor detections (radar + lidar + camera) using multiSensorTargetTracker, then import into ActorTrackData for the scenario pipeline. Covers target/sensor specs, JIPDA tuning, frame-by-frame execution, importFromObjectTrack (index-based and function-handle methods), and an extensive tuning guide. Loaded when user mentions sensor fusion, noisy raw detections, ID switches, or multiSensorTargetTracker.
---

# Workflow 14 — Accurate Non-Ego Tracks via Sensor Fusion (multiSensorTargetTracker)

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when raw single-sensor detections are noisy or ID-inconsistent and the user wants fused tracks before scenario building.

When raw detections from a single sensor are noisy or IDs are inconsistent, use multi-sensor fusion from the **Sensor Fusion and Tracking Toolbox** to produce high-quality `objectTrack` outputs, then import into Scenario Builder.

## Pipeline: Sensor Fusion → Scenario Builder
```
Raw detections (radar + lidar + camera)
  → multiSensorTargetTracker (JIPDA/GNN)
    → objectTrack array (confirmed, smoothed tracks)
      → importFromObjectTrack → ActorTrackData
        → actorprops(trackData, egoTrajectory) → world-coord trajectories
          → RoadRunner scene / drivingScenario
```

## Step 1: Define targets and sensors
```matlab
%% Target specifications (what you expect to track)
carSpec = trackerTargetSpec("automotive", "car", "highway-driving");
truckSpec = trackerTargetSpec("automotive", "truck", "highway-driving");

%% Sensor specifications (what sensors are mounted on ego)
radarSpec = trackerSensorSpec("automotive", "radar", "clustered-points");
radarSpec.MountingLocation = [3.7 0 0.8];       % front bumper
radarSpec.MountingAngles = [0 0 0];
radarSpec.MaxRange = 120;
radarSpec.DetectionProbability = 0.9;
radarSpec.NumFalsePositivesPerScan = 6;

lidarSpec = trackerSensorSpec("automotive", "lidar", "bounding-boxes");
lidarSpec.MountingLocation = [0 0 1.8];          % roof
lidarSpec.MaxRange = 150;
lidarSpec.DetectionProbability = 0.9;
lidarSpec.NumFalsePositivesPerScan = 2;

cameraSpec = trackerSensorSpec("automotive", "camera", "bounding-boxes");
cameraSpec.MountingLocation = [1.5 0 1.4];       % windshield
cameraSpec.MaxRange = 120;
cameraSpec.DetectionProbability = 0.95;
```

## Step 2: Create and configure tracker
```matlab
%% JIPDA tracker (detection-level fusion)
tracker = multiSensorTargetTracker({carSpec, truckSpec}, ...
    {radarSpec, lidarSpec, cameraSpec}, "jipda");

% Key tuning parameters
tracker.MaxMahalanobisDistance = 7;                  % assignment gate
tracker.ConfirmationExistenceProbability = 0.9;      % track confirmation
tracker.DeletionExistenceProbability = 0.1;          % track deletion
```

## Step 3: Run tracker on preprocessed detections
```matlab
%% Process frame by frame — two struct inputs: sensorData + egoData
objectTrackCellArray = cell(numFrames, 1);
for t = 1:numFrames
    % Sensor data struct (format depends on sensor type)
    % Camera: struct(Time=time, BoundingBox=double(bboxes'))  ← 4×N double
    % Radar:  struct(Time=time, Measurement=detections')
    sensorData = getSensorData(t);  % IMPORTANT: bounding boxes must be DOUBLE, not single

    % Ego motion struct (body frame: forward/left/up)
    egoData = struct('Time', timestamps(t), ...
        'EgoPositionalDisplacement', [dForward dLeft 0], ...   % body frame
        'EgoRotationalDisplacement', [dYaw 0 0]);              % radians

    confirmedTracks = tracker(sensorData, egoData);
    objectTrackCellArray{t} = confirmedTracks;
end
```

> **Critical:** YOLO `detect()` returns bounding boxes as `single`. Cast to `double` before passing to the tracker — otherwise tracks silently fail to confirm.

## Step 4: Import into Scenario Builder
```matlab
%% Convert objectTrack → ActorTrackData directly
atd = ActorTrackData;

% State vector for multiSensorTargetTracker with HighwayCar target:
% [x, vx, y, vy, z, vz, yaw, L, W, H] (10 elements)
% x=forward(range), y=lateral, z=height
posIdx = [1 3 5];        % [x y z] in state
velIdx = [2 4 6];        % [vx vy vz] in state
dimIdx = [8 9 10];       % [L W H] in state
orientIdx = [7 0 0];     % [yaw pitch roll] — only yaw in state

% Method 1: Index-based (when state vector layout is known)
importFromObjectTrack(atd, objectTrackCellArray, posIdx, velIdx, dimIdx, orientIdx);

% Method 2: Function handle (most flexible — extracts from ObjectAttributes)
importFromObjectTrack(atd, objectTrackCellArray, @extractActorParams);

function [pos, vel, dim, orient] = extractActorParams(tracks)
    nTracks = numel(tracks);
    pos = zeros(nTracks, 3);
    vel = zeros(nTracks, 3);
    dim = zeros(nTracks, 3);
    orient = zeros(nTracks, 3);
    for i = 1:nTracks
        st = tracks(i).State;
        pos(i,:) = [st(1) st(3) st(5)];
        vel(i,:) = [st(2) st(4) st(6)];
        dim(i,:) = [st(8) st(9) st(10)];   % L, W, H from state
        orient(i,:) = [st(7) 0 0];         % yaw from state
    end
end

%% Generate world-frame trajectories via actorprops
actorInfo = actorprops(atd, egoTrajectory, SaveAs="none");

%% Build scenario from actorprops output
% Option A: Import to RoadRunner (preferred for OpenSCENARIO/OpenDRIVE export)
% Option B: Build drivingScenario programmatically
scenario = drivingScenario;
for k = 1:height(actorInfo)
    actor = vehicle(scenario, Length=actorInfo.Dimension(k,1), ...
        Width=actorInfo.Dimension(k,2), Height=actorInfo.Dimension(k,3));
    trajectory(actor, actorInfo.Waypoints{k}, actorInfo.Speed{k});
end
```

## Tuning Guide — Track Quality Issues
| Problem | Parameter to Tune | Direction |
|---------|-------------------|-----------|
| Tracks not confirming (too few) | `ConfirmationExistenceProbability` | Lower (try 0.7) |
| Too many false tracks | `ConfirmationExistenceProbability` | Raise (try 0.95) |
| Tracks dropped too early | `DeletionExistenceProbability` | Lower (try 0.05) |
| Tracks persist after object leaves | `DeletionExistenceProbability` | Raise (try 0.2) |
| Missed associations (ID switches) | `MaxMahalanobisDistance` | Increase (try 10–15) |
| Wrong associations (merged tracks) | `MaxMahalanobisDistance` | Decrease (try 4–5) |
| Sensor has high clutter | `NumFalsePositivesPerScan` | Increase to match actual |
| Sensor misses objects often | `DetectionProbability` | Lower to match actual |

## Alternative: Use trackerJPDA directly (without task-oriented API)
```matlab
%% Lower-level tracker for full control
tracker = trackerJPDA( ...
    TrackLogic="Integrated", ...
    AssignmentThreshold=[30 100], ...
    ConfirmationThreshold=0.9, ...
    DeletionThreshold=1e-2, ...
    DetectionProbability=0.9, ...
    ClutterDensity=1e-5);

% For offline smoothing (retroactive correction):
smoother = smootherJIPDA(tracker);
smoother.TrackAssignmentThreshold = 100;
smoothedTracks = smooth(smoother, allDetections);
```

----

Copyright 2026 The MathWorks, Inc.

----
