# Example: Generate Scenario from Actor Track Data and GPS Data

This example downloads a road network from OpenStreetMap, builds a scenario with
ego + actor trajectories, and exports to RoadRunner using the HD Map pipeline.

```matlab
%% Generate Scenario from Actor Track Data and GPS Data
% This example shows how to use GPS and actor track data along with
% OpenStreetMap road data to generate a driving scenario in RoadRunner.
% Uses getRoadRunnerHDMap (not OpenDRIVE export) for correct road alignment.

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
altitude = zeros(size(data.GPS.altitude));  % Zero elevation for OSM

gpsData = recordedSensorData("gps",gpsTimestamps,latitude,longitude,altitude)

%% Step 3: Download Road Network from OpenStreetMap
% Compute actor lateral extent so the map covers all actors
buffer = max(cellfun(@(p) max(vecnorm(p(:,1:2),2,2)), actorPos)) + 50;

% Get the map region of interest from GPS coordinates
mapStruct = getMapROI(gpsData.Latitude,gpsData.Longitude,Extent=buffer);

% Download the OSM file
osmFile = fullfile(tempdir,"drive_map.osm");
websave(osmFile,mapStruct.osmUrl,weboptions(ContentType="xml"));

% Extract local origin from the road network
[~,localOrigin] = roadprops("OpenStreetMap",osmFile);

%% Step 4: Create Actor Track Data Object
actorTimes = data.ActorTracks.timeStamp;
trackIDs = data.ActorTracks.TrackIDs;
actorPos = data.ActorTracks.Positions;
actorDims = data.ActorTracks.Dimension;
actorOrient = data.ActorTracks.Orientation;
trackData = recordedSensorData("actorTrack",actorTimes,trackIDs,actorPos, ...
    Dimension=actorDims,Orientation=actorOrient)

%% Step 5: Create Camera Data Object
imageFileNames = strcat(fullfile(dataset,"Camera"),filesep,data.Camera.fileName);

focalLength = [data.Intrinsics.fx,data.Intrinsics.fy];
principlePoint = [data.Intrinsics.cx,data.Intrinsics.cy];
imageSize = size(imread(imageFileNames{1}),1:2);
intrinsics = cameraIntrinsics(focalLength,principlePoint,imageSize);

camTimestamps = data.Camera.timeStamp;
cameraParams = monoCamera(intrinsics,data.CameraHeight);

cameraData = recordedSensorData("camera",camTimestamps,imageFileNames, ...
    Name="FrontCamera",SensorParameters=cameraParams)
% Validate frame paths — catch single-file replication bug early
assert(numel(unique(cameraData.Frames)) > 1, ...
    "All CameraData.Frames point to the same file — check imageFileNames construction");

%% Step 6: Preprocess — Synchronize and Normalize Timestamps
synchronize(gpsData,trackData)
synchronize(cameraData,trackData)

refTime = normalizeTimestamps(trackData);
normalizeTimestamps(gpsData,refTime);
normalizeTimestamps(cameraData,refTime);

%% Step 7: Create Ego Trajectory from GPS with Local Origin
% Using localOrigin from OSM so trajectory aligns with the road network
egoTrajectory = trajectory(gpsData,"LocalOrigin",localOrigin)

% Smooth the trajectory to remove GPS noise
smooth(egoTrajectory);

%% Step 8: Visualize GPS Data and Ego Trajectory Side by Side
f = figure(Position=[500 500 1000 500]);
gpsPanel = uipanel(Parent=f,Position=[0 0 0.5 1],Title="GPS");
plot(gpsData,Parent=gpsPanel,Basemap="satellite")
trajPanel = uipanel(Parent=f,Position=[0.5 0 0.5 1],Title="Ego Trajectory");
plot(egoTrajectory,ShowHeading=true,Parent=trajPanel)

%% Step 9: Save camera playback as video + popup
% Pick the right mode (track-overlay / BEV+Camera / raw) per the priority
% order in SKILL.md Rule 2, and use the matching save-block from
% references/visualization-patterns.md. ONE UI event per video — do not
% combine interactive play(cameraData) with the save block.

%% Step 10: Extract Non-Ego Actor Trajectories
% Extract actor properties — transforms vehicle-relative to world coords
nonEgoActorInfo = actorprops(trackData,egoTrajectory,SaveAs="none");

% Display first 5 actors
nonEgoActorInfo(1:5,:)

%% Step 11: Build OSM roads via drivingScenario → RoadRunner HD Map
scenario = exportToDrivingScenario(egoTrajectory, ...
    RoadNetworkSource="OpenStreetMap",FileName=osmFile,Name="Ego");
rrMap = getRoadRunnerHDMap(scenario);
rrhdFile = fullfile(tempdir,"osm_roads.rrhd");
write(rrMap, rrhdFile);

%% Step 12: Connect to RoadRunner, import HD Map, save temp scene
% Per SKILL Rule: ALWAYS ask the user for these paths — auto-discovery is
% unreliable and platform-specific (Windows: C:\Program Files\..., macOS:
% /Applications/RoadRunner R*.app, Linux: /usr/local/MATLAB/RoadRunner_R*).
rrAppPath     = "<RoadRunner installation folder containing AppRoadRunner>";
rrProjectPath = "<RoadRunner project folder>";

if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath,InstallationFolder=rrAppPath);
end

oOpts = enableOverlapGroupsOptions(IsEnabled=false);
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, rrhdFile, "RoadRunner HD Map", ImportOptions=iOpts);
tempSceneFile = fullfile(tempdir,"osm_roads_temp.rrscene");
saveScene(rrApp, tempSceneFile);

%% Step 13: Open saved scene, create new scenario, export ego
% IMPORTANT: Use openScene for .rrscene files (NOT importScene — that's for RRHD/OpenDRIVE)
newScenario(rrApp);
openScene(rrApp, tempSceneFile);
exportToRoadRunner(egoTrajectory, rrApp, ...
    Name="Ego", SetupSimulation=true);

%% Step 13b: Localization gate
% If OSM + Raw GPS + camera with intrinsics → localization is REQUIRED.
% See SKILL.md Rule 4 Step 7 decision matrix. Run Workflow 8 before actor
% export. If Corrected GPS or pre-built scene → ASK user first.

%% Step 14: Export non-ego actor trajectories
% HARD RULES:
%   - Do NOT pass Orientation= (actorprops yaw is compass, incompatible with RR)
%   - Do NOT pass Speed= (not a valid Trajectory N-V arg)
%   - Flatten Z to 0 on flat OSM scenes (sensor-mount offset, not road height)
egoLocalOrigin = egoTrajectory.LocalOrigin;
for i = 1:height(nonEgoActorInfo)
    wp = nonEgoActorInfo.Waypoints{i};
    wp(:,3) = 0;  % flat OSM scene — zero Z
    actorTraj = scenariobuilder.Trajectory( ...
        nonEgoActorInfo.Time{i}, wp, ...
        Name=nonEgoActorInfo.TrackID(i), ...
        LocalOrigin=egoLocalOrigin);
    smooth(actorTraj);
    exportToRoadRunner(actorTraj, rrApp, ...
        Name=nonEgoActorInfo.TrackID(i), Color="auto", SetupSimulation=false);
end

%% Step 15: Simulate (Front camera) + export video
setCameraMode(rrApp, "Front");
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
rootPhase = roadrunnerAPI(rrApp).Scenario.PhaseLogic.RootPhase;
failCond = rootPhase.setFailCondition("DurationCondition");
failCond.Duration = egoTrajectory.Duration + 10;
simulateScenario(rrApp, EnableLogging=true);

% exportVideo VideoFolder must not contain spaces — stage via tempdir if needed
simVideoFolder = dataDir;
if contains(simVideoFolder, " ")
    simVideoFolder = fullfile(tempdir, "rr_video_export");
    if ~isfolder(simVideoFolder); mkdir(simVideoFolder); end
end
exportVideo(rrApp, VideoFolder=simVideoFolder, FileName="sim_frontCamera");
simVideoPath = fullfile(simVideoFolder, "sim_frontCamera.mp4");
if ~strcmp(simVideoFolder, dataDir)
    copyfile(simVideoPath, fullfile(dataDir, "sim_frontCamera.mp4"));
    simVideoPath = fullfile(dataDir, "sim_frontCamera.mp4");
end

%% Step 16: Side-by-side comparison (on-the-fly overlay left | sim right)
% PREFERRED: compose overlay from original frames to avoid double-compression blur.
% Do NOT read the pre-saved trackOverlay_video.mp4 — that causes generation loss.
simReader = VideoReader(simVideoPath);
targetH = 540; targetW = 960;
maxFrames = 100;
step = max(1, ceil(cameraData.NumSamples / maxFrames));
frameIndices = 1:step:cameraData.NumSamples;
effectiveFPS = numel(frameIndices) / cameraData.Duration;

hasIntrinsics = ~isempty(cameraData.SensorParameters) ...
    && isstruct(cameraData.SensorParameters) ...
    && isfield(cameraData.SensorParameters, 'Intrinsics');
hasTracks = exist('trackData','var') && ~isempty(trackData.UniqueTrackIDs);

compVideoFile = fullfile(dataDir, "comparison_input_vs_sim.mp4");
vw = VideoWriter(compVideoFile, "MPEG-4");
vw.FrameRate = round(effectiveFPS);
open(vw);
for frameIdx = frameIndices
    img = imread(cameraData.Frames(frameIdx));
    if hasIntrinsics && hasTracks
        imgL = plotActorCircles(img, frameIdx, cameraData, trackData, intrinsics);
    else
        imgL = img;
    end
    imgL = imresize(imgL, [targetH targetW]);
    t = cameraData.Timestamps(frameIdx);
    imgL = insertText(imgL, [10 10], sprintf("Input+Tracks (t=%.1fs)", t), ...
        FontSize=20, BoxColor="black", TextColor="white", BoxOpacity=0.6);
    simReader.CurrentTime = min(t, simReader.Duration - 0.01);
    imgR = imresize(readFrame(simReader), [targetH targetW]);
    imgR = insertText(imgR, [10 10], sprintf("RR Sim Front (t=%.1fs)", t), ...
        FontSize=20, BoxColor="black", TextColor="white", BoxOpacity=0.6);
    writeVideo(vw, [imgL, imgR]);
end
close(vw);
answer = questdlg(sprintf("Comparison video saved to:\n%s\n\nOpen it?", ...
    compVideoFile), "Comparison Video", "Yes", "No", "Yes");
if strcmp(answer, "Yes"), openFile(compVideoFile); end

%% Step 17: Save scene and scenario
saveScene(rrApp, fullfile(rrProjectPath,"Scenes","myScene.rrscene"));
saveScenario(rrApp, fullfile(rrProjectPath,"Scenarios","myScenario.rrscenario"));
```


----

Copyright 2026 The MathWorks, Inc.

----
