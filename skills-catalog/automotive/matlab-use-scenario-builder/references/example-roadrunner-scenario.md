# Example: Generate RoadRunner Scenario from Recorded Sensor Data

This is the complete end-to-end example for exporting to RoadRunner directly.

```matlab
%% Generate RoadRunner Scenario from Recorded Sensor Data
% This example shows how to generate a RoadRunner scenario from recorded
% GPS, actor track, and camera data using Scenario Builder.

%% Step 1: Load Sensor Data
dataFolder = tempdir;
dataFilename = "PandasetSeq90_94.zip";
url = "https://ssd.mathworks.com/supportfiles/driving/data/" + dataFilename;
filePath = fullfile(dataFolder,dataFilename);
if ~isfile(filePath)
    websave(filePath,url);
end
unzip(filePath,dataFolder)
dataset = fullfile(dataFolder,"PandasetSeq90_94");
data = load(fullfile(dataset,"sensorData.mat"));

%% Step 2: Create GPS Data Object
gpsTimestamps = data.GPS.timeStamp;
latitude = data.GPS.latitude;
longitude = data.GPS.longitude;
% Set altitude to 0 as the scene does not contain height information.
altitude = zeros(size(data.GPS.altitude));

gpsData = recordedSensorData("gps",gpsTimestamps,latitude,longitude,altitude)

%% Step 3: Create Actor Track Data Object
actorTimes = data.ActorTracks.timeStamp;
trackIDs = data.ActorTracks.TrackIDs;
actorPos = data.ActorTracks.Positions;
actorDims = data.ActorTracks.Dimension;
actorOrient = data.ActorTracks.Orientation;
trackData = recordedSensorData("actorTrack",actorTimes,trackIDs,actorPos, ...
    Dimension=actorDims,Orientation=actorOrient)

%% Step 4: Create Camera Data Object
imageFileNames = strcat(fullfile(dataset,"Camera"),filesep,data.Camera.fileName);

focalLength = [data.Intrinsics.fx,data.Intrinsics.fy];
principlePoint = [data.Intrinsics.cx,data.Intrinsics.cy];
imageSize = size(imread(imageFileNames{1}),1:2);
intrinsics = cameraIntrinsics(focalLength,principlePoint,imageSize);

camTimestamps = data.Camera.timeStamp;
cameraParams = monoCamera(intrinsics,data.CameraHeight);

cameraData = recordedSensorData("camera",camTimestamps,imageFileNames, ...
    Name="FrontCamera",SensorParameters=cameraParams)

%% Step 5: Preprocess — Synchronize and Normalize Timestamps
synchronize(gpsData,trackData)
synchronize(cameraData,trackData)

refTime = normalizeTimestamps(trackData);
normalizeTimestamps(gpsData,refTime);
normalizeTimestamps(cameraData,refTime);

%% Step 6: Create Ego Trajectory from GPS
egoTrajectory = trajectory(gpsData)

% Smooth the trajectory to remove GPS noise
smooth(egoTrajectory);

%% Step 7: Visualize GPS Data and Ego Trajectory Side by Side
f = figure(Position=[500 500 1000 500]);
gpsPanel = uipanel(Parent=f,Position=[0 0 0.5 1],Title="GPS");
plot(gpsData,Parent=gpsPanel,Basemap="satellite")
trajPanel = uipanel(Parent=f,Position=[0.5 0 0.5 1],Title="Ego Trajectory");
plot(egoTrajectory,ShowHeading=true,Parent=trajPanel)

%% Step 8: Save camera playback as video + popup
% Pick the right mode (track-overlay / BEV+Camera / raw) per the priority
% order in SKILL.md Rule 2, and use the matching save-block from
% references/visualization-patterns.md. ONE UI event per video — do not
% combine interactive play(cameraData) with the save block.

%% Step 9: Extract Non-Ego Actor Trajectories
% Extract actor properties — transforms vehicle-relative to world coords
nonEgoActorInfo = actorprops(trackData,egoTrajectory,SaveAs="none");

% Display first 5 actors
nonEgoActorInfo(1:5,:)

%% Step 10: Export to RoadRunner
% Per SKILL Rule: ALWAYS ask the user for these paths — auto-discovery is
% unreliable and platform-specific (Windows: C:\Program Files\..., macOS:
% /Applications/RoadRunner R*.app, Linux: /usr/local/MATLAB/RoadRunner_R*).
rrAppPath     = "<RoadRunner installation folder containing AppRoadRunner>";
rrProjectPath = "<RoadRunner project folder>";

if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath,InstallationFolder=rrAppPath);
end

% Export ego trajectory with scene
filename = fullfile(pwd,"pandasetScene.rrscene");
exportToRoadRunner(egoTrajectory,rrApp,RoadRunnerScene=filename,Name="Ego")

% Export non-ego actor trajectories
for i = 1:height(nonEgoActorInfo)
    actorTraj = scenariobuilder.Trajectory( ...
        nonEgoActorInfo.Time{i}, nonEgoActorInfo.Waypoints{i}, ...
        Name=nonEgoActorInfo.TrackID(i));
    exportToRoadRunner(actorTraj,rrApp, ...
        Name=nonEgoActorInfo.TrackID(i),SetupSimulation=false);
end
```


----

Copyright 2026 The MathWorks, Inc.

----
