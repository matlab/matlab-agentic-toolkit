---
name: workflow-04-roadrunner-export-detail
description: Detailed RoadRunner export workflow — connecting to RoadRunner, obtaining a scene (OSM/file/HERE/OpenDRIVE), exporting ego + actor trajectories, running the simulation, exporting and comparing simulation video. Loaded when user needs full RR export detail beyond the inline minimal pattern.
---

# Workflow 4 — Export Trajectories to RoadRunner (Detailed)

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Workflow 4 inline section has the minimal happy-path pattern. This file has the complete workflow including all four scene-source options, simulation control, and side-by-side comparison video composition.
>
> **Related references:** [`workflow-08-lane-localization.md`](workflow-08-lane-localization.md) when intrinsics + lane detection are available. [`workflow-09-static-objects.md`](workflow-09-static-objects.md) when adding static objects to the HD map.

## Step 1: Connect to RoadRunner
```matlab
% Use paths provided by the user (see Rule 8) — single-instance guard
rrAppPath = "<user-provided installation path>";
rrProjectPath = "<user-provided project path>";
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end
```

**RoadRunner crash recovery (use at chunk boundaries or after timeout):**
If RoadRunner has crashed or become unresponsive mid-pipeline, the handle is stale. Always wrap RR calls after a pause/chunk boundary in a try-catch:
```matlab
try
    worldSettings(rrApp);  % lightweight probe — errors if RR died
catch
    clear rrApp;
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end
```

**Stale cosimulation connection fix:** If you get the error `"MATLAB is already connected to RoadRunner Scenario cosimulation server"`, close and relaunch RoadRunner to clear it:
```matlab
% Close and relaunch RoadRunner to clear stale cosim connection
close(rrApp); clear rrApp; pause(2);
rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
```
If that alone doesn't work (connection persists), also clear the Simulink client (requires Simulink):
```matlab
try
    rrSim = Simulink.ScenarioSimulation.getSimulationClient('localhost:60731');
    delete(rrSim); clear rrSim;
catch
end
```

## Step 2: Obtain a RoadRunner Scene
A scene provides the road network for the scenario. Use one of the following options:

### Option A: Download from OpenStreetMap (most common)
**Important:** Always zero altitude for OSM (no elevation data). Use `getRoadRunnerHDMap` (not OpenDRIVE export) to avoid lateral misalignment.

**IMPORTANT — Actor-aware OSM download:** Do NOT use only ego GPS for the bounding box. Actors may be on parallel roads outside the ego's GPS spread. Use a single-pass approach:
1. Scan raw actor track positions for max lateral offset (ego-relative Y coordinate)
2. Add 50m margin (for road width) and pass as `Extent` to `getMapROI`
3. `Extent` is in **meters**

This avoids a double-pass (no need to build trajectories first) and ensures roads are downloaded for all actors.

```matlab
% Step 1: Estimate buffer from raw track positions (instant — no trajectory needed)
maxLateral = 0;
for i = 1:numel(trackPositions)
    pos = trackPositions{i};
    if ~isempty(pos)
        maxLateral = max(maxLateral, max(abs(pos(:,2))));
    end
end
buffer = maxLateral + 50;  % 50m margin for road width

% Step 2: Download OSM with actor-aware buffer (skip-if-exists + timeout), convert to RoadRunner HD Map
mapROI = getMapROI(gpsData.Latitude, gpsData.Longitude, Extent=buffer);
osmFile = fullfile(tempdir, "drive_map.osm");
if ~isfile(osmFile)
    websave(osmFile, mapROI.osmUrl, weboptions(ContentType="xml", Timeout=30));
end
ds =  drivingScenario;
roadNetwork(ds,OpenStreetMap=osmFile)
rrMap = getRoadRunnerHDMap(ds);
rrhdFile = fullfile(tempdir, "roads.rrhd");
write(rrMap, rrhdFile);

% Step 3: Build ego trajectory with OSM local origin
localOrigin = rrMap.GeoReference;
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);
smooth(egoTrajectory);

% Step 4: Export to drivingScenario with OSM roads
scenario = exportToDrivingScenario(egoTrajectory, ...
    RoadNetworkSource="OpenStreetMap", FileName=osmFile, Name="Ego");

% Step 5: Import HD Map — overlap groups MUST BE DISABLED by default.
% This is a hard rule, not an optimization: importing with the default
% (IsEnabled=true) produces false-positive overlap groups at junctions/overpasses
% on OSM-derived maps, which makes the scene look wrong even when geometry is fine.
% Always pass these three options together. Only re-enable later if the user
% reports junction/overpass artifacts AFTER reviewing the scene (see below).
copyfile(rrhdFile, fullfile(rrProjectPath, "Assets", "RoadFromOSM.rrhd"));
changeWorldSettings(rrApp, WorldOrigin=localOrigin(1:2));
oOpts = enableOverlapGroupsOptions(IsEnabled=false);              % MANDATORY default
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, "RoadFromOSM.rrhd", "RoadRunner HD Map", ImportOptions=iOpts);
tempSceneFile = fullfile(tempdir, "osm_roads_temp.rrscene");
saveScene(rrApp, tempSceneFile);

% Step 6: Export ego with scene (ensures coordinate alignment)
newScene(rrApp);
exportToRoadRunner(egoTrajectory, rrApp, ...
    RoadRunnerScene=tempSceneFile, Name="Ego", SetupSimulation=true);
```

#### Re-enabling overlap groups (when default disabled doesn't look right)
Default behaviour above imports with `EnableOverlapGroups=false`. **If, after scenario generation, the user reports that roads/scene look wrong at junctions or overpasses** (e.g., crossing roads that should be connected aren't, or overpasses look flat), re-import the same `.rrhd` with overlap groups **enabled**, then ask the user whether the result looks better:
```matlab
% Conditional fix — only when user flags scene problems at junctions/overpasses
oOpts = enableOverlapGroupsOptions(IsEnabled=true);
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, "RoadFromOSM.rrhd", "RoadRunner HD Map", ImportOptions=iOpts);

% Then ask the user if this version looks better
choice = questdlg("Re-imported scene with overlap groups enabled. Does this look better at junctions/overpasses?", ...
    "Overlap groups", "Yes — keep this", "No — revert to disabled", "Yes — keep this");
```
Re-importing the scene only — keep the actor list and simulation settings untouched (Rule 12: minimum-change reruns).

### Option B: Import a pre-existing scene file
**IMPORTANT:** The `.rrscene` file must be inside the RoadRunner project's `Scenes/` folder. If the user's scene file is located elsewhere, **copy it into the project first**:
```matlab
% Copy scene file into the RoadRunner project if it's external
scenesDir = fullfile(rrProjectPath, "Scenes");
if ~isfolder(scenesDir)
    mkdir(scenesDir);
end
[~, sceneName, sceneExt] = fileparts(userSceneFile);
destScene = fullfile(scenesDir, sceneName + sceneExt);
if ~isfile(destScene)
    copyfile(userSceneFile, destScene);
end

% Now export using the scene inside the project
exportToRoadRunner(egoTrajectory, rrApp, ...
    RoadRunnerScene=destScene, Name="Ego", SetupSimulation=true);
```

#### Option B.1: Pre-built scene + GPS (HERE HD, OpenDRIVE, or any externally-built `.rrscene`)
When the user supplies a `.rrscene` that was *not* built from their GPS (e.g. a HERE HD export, a vendor OpenDRIVE scene, a manually-authored RoadRunner scene), you cannot get `localOrigin` from `roadprops` and **`getRoadRunnerHDMap(rrApp)` does not exist**. Use this pattern instead:

```matlab
%% (1) Open the scene in RoadRunner (after copying into project Scenes/)
openScene(rrApp, sceneName + sceneExt);

%% (2) Read the scene's geo-anchor — this is the LocalOrigin for trajectories.
%   - worldSettings(rrApp).WorldOrigin gives [lat lon] (reduced precision, ~5 dp)
%   - For full precision, parse latitude_of_origin / central_meridian from the
%     Projection WKT string. Always do this for HERE HD / OpenDRIVE scenes —
%     the 5-dp WorldOrigin can be off by several meters at the equator.
ws   = worldSettings(rrApp);
proj = ws.Projection;
latStr = regexp(proj, 'latitude_of_origin",([\-\d\.]+)', "tokens", "once");
lonStr = regexp(proj, 'central_meridian",([\-\d\.]+)',   "tokens", "once");
localOrigin = [str2double(latStr{1}), str2double(lonStr{1}), 0];

%% (3) Build trajectory using the scene's anchor
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);
smooth(egoTrajectory);

%% (4) HEREHD/OpenDRIVE scenes have terrain — apply height correction.
%   Even when GPS altitude is non-zero, surveyed altitude (geoid) and the
%   scene's terrain (often EGM96 or a local datum) can disagree by several
%   meters. Run adjustHeight unconditionally for terrain-aware scenes — it is
%   a no-op when alignment is already good. See workflow-07-height-correction.md.
rrhdOut = fullfile(tempdir, "scene_export.rrhd");
exportScene(rrApp, rrhdOut, "RoadRunner HD Map");
rrMap = roadrunnerHDMap;
read(rrMap, rrhdOut);                 % NOTE: positional ctor errors — must use read()
adjustHeight(egoTrajectory, rrMap);

%% (5) Export ego with the in-project scene file
exportToRoadRunner(egoTrajectory, rrApp, ...
    RoadRunnerScene=destScene, Name="Ego", SetupSimulation=true);
```

**Why these calls are different from Option A:**
- `getRoadRunnerHDMap(rrApp)` — **does NOT exist.** `getRoadRunnerHDMap` only takes a `drivingScenario`. To get a `roadrunnerHDMap` from a scene already loaded in `rrApp`, export the HD map to a `.rrhd` first, then `read()` it into a fresh `roadrunnerHDMap`.
- `roadrunnerHDMap(file)` — **does NOT accept a positional file path.** Must construct empty (`rrMap = roadrunnerHDMap`) then call `read(rrMap, file)`.
- The exported `.rrhd`'s `GeoReference` property is `[0 0]` (does not carry the scene's anchor). Always pull `LocalOrigin` from `worldSettings(rrApp)`, not from `rrMap.GeoReference`.

### Option C: Download from HERE HD Live Map (requires HERE HD credentials)
```matlab
% Requires valid HERE HD Live Map credentials configured in MATLAB
% User must have a HERE account and provide credentials
scenario = exportToDrivingScenario(egoTrajectory, ...
    RoadNetworkSource="HEREHDLiveMap", ...
    GeoCoordinates=[minLat minLon maxLat maxLon], Name="Ego");
```
> **Note:** Ask the user for their HERE HD credentials before attempting this option. They must be configured via `hereHDLMCredentials` in MATLAB.

### Option D: Import from OpenDRIVE file
```matlab
scenario = exportToDrivingScenario(egoTrajectory, ...
    RoadNetworkSource="OpenDRIVE", FileName="road_network.xodr", Name="Ego");
```

## Step 2.5: Multi-GPS / multi-GNSS — pick one with a comparison video gate

When the dataset contains more than one ego position series — common variants include `GPSData_Raw`/`GPSData_Corrected`, `GPS`/`GNSS`, or two GNSS receivers with different fix qualities — **do not silently pick one**. Field names are not always trustworthy ("Corrected" can mean smoothed, RTK-corrected, lever-arm-compensated, dead-reckoned, etc.) and "best" depends on what the scene needs.

**Hard rule — show the user a comparison video before asking which to use.** This mirrors the lane-localization compare-then-ask gate (workflow-08 Step 4): the user must see all candidates simulated against the same scene before they can make a sensible call. Do **not** pick by smaller offset, smaller residual, or any quantitative heuristic — visual judgement against the actual road wins every time.

```matlab
%% Build one scenariobuilder.Trajectory per GPS series (same LocalOrigin)
egoA = trajectory(gpsA, "LocalOrigin", localOrigin); smooth(egoA);
egoB = trajectory(gpsB, "LocalOrigin", localOrigin); smooth(egoB);
% (height correction if scene has terrain — see Option B.1 step 4)

%% Stage them side-by-side in a fresh scenario — red and green only when 2 series.
% For 3+ series, use distinct named colors (red/green/blue/yellow) and
% always burn the legend onto the right-side panel.
%
% HARD RULE — export-order matters. RoadRunner assigns ActorID in
% exportToRoadRunner call order (1st → ID=1). setCameraMode(..., "follow",
% FocusActorID=1) tracks whichever actor was exported first. Pick the
% series whose perspective matters MOST (usually the "Corrected" or
% RTK-quality one) and export it FIRST so the follow-cam locks onto it.
% Inverting silently produces a video that follows the wrong GPS series.
newScenario(rrApp);
exportToRoadRunner(egoA, rrApp, ...
    RoadRunnerScene=destScene, Name="Ego_A", Color="red",   SetupSimulation=true);
exportToRoadRunner(egoB, rrApp, ...
    Name="Ego_B", Color="green", SetupSimulation=false);

%% Disable collision fail and simulate (follow camera on Ego_A so both stay in frame)
% SetupSimulation=true creates a sim object — delete it before simulateScenario
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
rootPhase = roadrunnerAPI(rrApp).Scenario.PhaseLogic.RootPhase;
rootPhase.setFailCondition("DurationCondition").Duration = egoA.Duration + 10;
setCameraMode(rrApp, "follow", FocusActorID=1);
simulateScenario(rrApp, EnableLogging=true);

%% Export the follow-cam video; build raw-camera-on-left / RR-on-right composite
%  with red/green legend burnt in (same composition as workflow-08 Step 4).
%  Save to dataDir, popup ONLY for opening the video.
gpsCompareOut = fullfile(dataDir, "ego_gps_compare_labeled.mp4");
% ... (use the same composer used in workflow-08 Step 4) ...

ans1 = questdlg(sprintf("GPS-source compare video saved to:\n%s\n\nOpen it now?", gpsCompareOut), ...
    "Open GPS-source compare video", "Yes", "No", "Yes");
if strcmp(ans1, "Yes"), openFile(gpsCompareOut); end  % cross-platform; scripts/openFile.m

%% AFTER the popup: ask the user in the chat channel which GPS series to use.
%  Only after they pick do you proceed to lane localization (workflow-08) or
%  scenario generation. Never pick automatically.
```

**When NOT to apply this gate:**
- Only one GPS/GNSS series exists in the dataset — pick it without ceremony.
- The user explicitly told you which series to use up-front (stated as a default for *this* dataset, not as a permanent preference).

**When to apply 3-way:**
- If the dataset has two GPS series **and** lane localization will run, the simplest sequencing is: (1) GPS compare-and-pick (this gate), (2) lane-localization compare-and-pick (workflow-08 Step 4). Two separate gates, two separate questions. Don't try to combine into one 3-way video — users can't compare three trajectories at a glance.

## Step 3: Export ego trajectory
```matlab
% Export with a scene file — sets World Origin from LocalOrigin, creates simulation
exportToRoadRunner(egoTrajectory, rrApp, ...
    RoadRunnerScene="myScene.rrscene", Name="Ego", SetupSimulation=true);
```

## Step 4: Export non-ego actor trajectories
**Always smooth actor trajectories** before exporting — raw track data is often noisy/jittery.

**Vehicle classification (Workflow 18 — automatic).** Before the export loop, run the vehicle classification pipeline from [`workflow-18-vehicle-classification.md`](workflow-18-vehicle-classification.md). When camera intrinsics + `CameraHeight` + actor tracks are all present, the agent:
1. Calls `buildBestCropGrid` (in `scripts/`) to project tracks → image crops → composite grid
2. Views the grid and classifies each track by color + type
3. Maps type → `AssetPath` (e.g. `"Vehicles/SUV.fbx"`) and color → RR named color

If prerequisites are missing (no intrinsics, no camera, text-only agent), the classification step is skipped and actors export with the default `AssetPath="Vehicles/Sedan.fbx"`, `Color="auto"`.

**Use classified Color/AssetPath when available; otherwise `Color="auto"`.** Reserve named colors (`"red"`, `"green"`, `"blue"`) for ego comparison scenarios (raw vs localized, GPS_A vs GPS_B) where colour carries meaning.

**Flatten waypoint Z to 0 on flat scenes (OSM, OpenDRIVE without elevation, Pandaset).** `actorInfo.Waypoints` carries each actor's Z in **world frame**, but for scenes that lack terrain elevation the per-track Z is dominated by the **sensor mount offset** (camera height ≈ 1–1.5 m), not the road surface. Without flattening, every actor floats ~1 m above the road. Flatten only on flat scenes — on terrain-aware scenes (HERE HD, Zenrin, OpenDRIVE+CRG, point-cloud-derived rrhd) keep Z and apply the terrain offset described below.

**Terrain-aware actor Z offset (HERE HD, Zenrin, point-cloud scenes).** On terrain-aware scenes, **do NOT flatten Z to 0** and **do NOT use raw Z as-is**. The ego actor (`SetupSimulation=true`) is snapped to the terrain surface by RoadRunner's simulation engine, but non-ego actors (`SetupSimulation=false`) render at their exact CSV Z value — which is typically 0.5–1.0 m below the rendered terrain mesh. This causes actors to clip into or disappear below the road surface.

**Fix:** Add `+0.75` m (half the standard sedan height) to non-ego actor Z before export. This compensates for the terrain mesh sitting above the HD map geometry:

```matlab
wp(:,3) = wp(:,3) + 0.75;  % terrain compensation — actors render ON road surface
```

This offset was empirically validated: Z+0 → actors invisible below terrain; Z+0.75 → actors sit naturally on road; Z+3/+5 → actors float above road.

```matlab
%% Vehicle classification — Workflow 18 (self-gating)
% Run buildBestCropGrid → agent views grid → classifies → builds map.
% Full pipeline: references/workflow-18-vehicle-classification.md
classificationMap = containers.Map();  % populated below by agent vision pass
hasIntrinsics = exist('intrinsics','var') && isfield(intrinsics,'fx') && exist('camHeight','var');
if hasIntrinsics && trackData.NumSamples > 0 && cameraData.NumSamples > 0
    addpath(fullfile(fileparts(mfilename("fullpath")), "scripts"));
    classifyDir = fullfile(dataDir, "classification");
    [gridPath, cropManifest] = buildBestCropGrid(trackData, cameraData, ...
        intrinsics, camHeight, classifyDir);
    fprintf("Classification grid: %s (%d tracks)\n", gridPath, height(cropManifest));
    % >>> AGENT: View gridPath. Classify each labeled track by color + type.
    % >>> Build classificationMap entries per workflow-18 Step 2–4.
end

%% Export non-ego actors with classified assets
% SetupSimulation=false for non-ego actors to avoid overwriting simulation params
egoLocalOrigin = egoTrajectory.LocalOrigin;
isTerrainScene = true;  % Set false for flat OSM scenes — see "How to tell" note below
for i = 1:height(actorInfo)
    wp = actorInfo.Waypoints{i};
    if isTerrainScene
        wp(:,3) = wp(:,3) + 0.75;  % terrain compensation for non-ego actors
    else
        wp(:,3) = 0;               % flat scene — zero Z
    end
    % HARD RULE — do NOT pass Orientation= for non-ego actors. actorprops yaw
    % uses a compass convention (~340° for northbound) incompatible with RR's
    % world frame; RR auto-derives heading from waypoint deltas correctly.
    % Also do NOT pass Speed= — it is not a valid Trajectory N-V argument.
    actorTraj = scenariobuilder.Trajectory( ...
        actorInfo.Time{i}, wp, ...
        Name=actorInfo.TrackID(i), LocalOrigin=egoLocalOrigin);
    smooth(actorTraj);  % Remove noise from actor tracks

    tid = char(actorInfo.TrackID(i));
    if isKey(classificationMap, tid)
        cls = classificationMap(tid);
        exportToRoadRunner(actorTraj, rrApp, ...
            Name=actorInfo.TrackID(i), AssetPath=cls.AssetPath, ...
            Color=cls.Color, SetupSimulation=false);
    else
        exportToRoadRunner(actorTraj, rrApp, ...
            Name=actorInfo.TrackID(i), Color="auto", SetupSimulation=false);
    end
end
```

**How to tell if the scene is "flat":** read the rrhd's geometry Z range. On OSM-derived rrhd, `range(geometryZ) < ~2 m` (essentially noise from `getRoadRunnerHDMap`). On terrain-aware rrhd it spans tens to hundreds of metres along the route. Compare against `range(gpsData.Altitude)` — if both are near zero, flatten; if the rrhd has real elevation, run `adjustHeight` on ego instead.

**Ego Z on flat scenes:** The ego trajectory also needs Z=0 on flat OSM scenes — GPS altitude puts ego 30–50 m above the road. When rebuilding the ego `Trajectory` with Z=0 after localization, MUST preserve `Orientation=localizedTrajectory.Orientation` — without it, heading is re-derived from waypoints and loses the lane-aligned orientation from `localizeEgoUsingLanes`. Full pattern in [`osm-flat-scene-gotchas.md`](osm-flat-scene-gotchas.md) Gotcha 1.

## `exportToRoadRunner` Name-Value Arguments
| Argument | Description | Default |
|----------|-------------|---------|
| `Name` | Vehicle name in RoadRunner | `"auto"` |
| `Color` | Actor color | `"auto"` |
| `AssetPath` | Actor asset path (relative to Assets/ or absolute) | `"auto"` |
| `SetupSimulation` | Create simulation with time/step from trajectory | `true` |
| `RoadRunnerScene` | `.rrscene` or `.rrhd` file to import | `[]` |

## Vehicle Assets
Vehicle assets are located at `<rrProjectPath>/Assets/Vehicles/`. To use a specific vehicle asset:
```matlab
% List available vehicle assets
assetDir = fullfile(rrProjectPath,"Assets","Vehicles");
dir(assetDir)

% Use a specific asset when exporting
exportToRoadRunner(egoTrajectory, rrApp, ...
    AssetPath="Vehicles/Sedan.fbx", Name="Ego");
```

**Asset filename casing matters.** RR ships filenames with TitleCase stems
(`Sedan.fbx`, `Suv.fbx`, `Hatchback.fbx`, `Box_Truck.fbx`). Lowercase forms
(`sedan.fbx`) silently resolve to white placeholder boxes on Windows because
`<PROJECT>/Assets/...` resolution is case-sensitive even on case-insensitive
filesystems. Confirm spelling with `dir(fullfile(rrProjectPath,"Assets","Vehicles"))`
before composing `AssetPath`.

### Post-Export Asset Replacement via API
When modifying actor assets **after** `exportToRoadRunner` (e.g., applying classification results iteratively), use `<PROJECT>/` relative paths — **never** absolute paths:
```matlab
rrAPI = roadrunnerAPI(rrApp);
allActors = rrAPI.Scenario.Actors;  % index 1 = ego
allActors(k).ActorAsset = "<PROJECT>/Assets/Vehicles/Suv.fbx_rrx";
allActors(k).Color = [0.15 0.15 0.15 1];  % [R G B A] normalized
```
**CRITICAL:** Absolute paths silently break the asset reference — actors render as white placeholder boxes. The `<PROJECT>/` prefix is required for RoadRunner to resolve the asset correctly.

## Running the Scenario Simulation
After exporting ego + actors, run the simulation in RoadRunner.

### Duration-Aware Simulation & Actor Count Caps

Long datasets (>30s) and dense actor lists (>15 actors) cause MCP timeouts. Use these caps:

```matlab
simDuration = egoTrajectory.Duration;
if simDuration <= 30
    nExportActors = height(actorInfo);       % all actors
else
    nExportActors = min(15, height(actorInfo)); % top 15 by Age for validation
    % Sort by track age (longest-lived actors are most important)
    [~, ageOrder] = sort(actorInfo.Age, "descend");
    actorInfo = actorInfo(ageOrder(1:nExportActors), :);
end
```

For datasets >30s: validate at 30s first (confirm Y-axis, roads, actors look correct), then trigger the full-duration simulation. If the full sim times out via MCP, the simulation continues in RoadRunner — export the video in the next MCP call:
```matlab
% After timeout: sim is still running in RR — wait for it
pause(2);  % RR finishes async
exportVideo(rrApp, VideoFolder=simVideoFolder, FileName="sim_frontCamera", VideoResolution="HD");
```

**MANDATORY PRE-FLIGHT CHECKLIST — verify ALL before proceeding:**
- [ ] Actor-aware OSM buffer used (`getMapROI(..., Extent=buffer)`)
- [ ] GPS vs Trajectory plot shown to user
- [ ] BEV+Camera or track-overlay video saved to disk
- [ ] Collision fail condition disabled (`setFailCondition("DurationCondition")`)
- [ ] `simulateScenario(rrApp, EnableLogging=true)` — NOT without EnableLogging
- [ ] `exportVideo` called after simulation
- [ ] Side-by-side comparison video (input vs sim) created and saved

**CRITICAL — Always disable collision fail condition:** RoadRunner's default fail condition stops the simulation when vehicles collide. Since recorded data often has close passes that trigger this, you MUST always replace it with a duration-based condition. **Never skip this step.**

```matlab
% MANDATORY: Delete stale sim object from SetupSimulation=true, then set fail condition
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
rootPhase = roadrunnerAPI(rrApp).Scenario.PhaseLogic.RootPhase;
failCond = rootPhase.setFailCondition("DurationCondition");
failCond.Duration = egoTrajectory.Duration + 10;  % ensure it won't trigger

% Set camera to front (dashcam) view — shows ego perspective with all actors visible ahead.
% Available modes: "default", "front", "follow", "orbit"
%   "front"  — dashcam view from ego looking forward (recommended for driving-log-like replay)
%   "follow" — third-person chase camera behind ego (FollowHeight, FollowDistance adjustable)
%   "orbit"  — free-rotating overview of entire scene
setCameraMode(rrApp, "front", FocusActorID=1);

% HARD RULE — do NOT pass Pacing= here. Pacing throttles real-time playback
% but truncates/desyncs the EnableLogging capture for long clips. For full-
% length recording, omit Pacing entirely and let the simulation run as fast
% as the host allows.
% EnableLogging=true is REQUIRED for exportVideo to work after simulation
simulateScenario(rrApp, EnableLogging=true);
```

## Export Simulation Video and Create Comparison
After simulation completes, export the simulation video and create a side-by-side comparison with the input camera video.

**Step 1: Export simulation video** (uses `exportVideo` — available in R2026a+):
```matlab
%% Export simulation video from RoadRunner
% exportVideo takes ONLY name-value pairs (rrApp is positional). Passing the
% output path positionally — `exportVideo(rrApp, fullPath)` — errors with
% "Name-value pair arguments require a name followed by a value."
% FileName must be a STEM (no extension) — exportVideo appends .mp4 / .avi.
%
% HARD RULE — VideoFolder must be a path WITHOUT SPACES. RR's video exporter
% silently fails (or returns "permission denied") when the target path
% contains spaces — common on Windows OneDrive paths like
% "C:\Users\<user>\OneDrive - <Organization>\...". If dataDir contains a space,
% redirect VideoFolder to a no-space staging folder (e.g. tempdir or C:\rr_out)
% and copyfile the result back to dataDir afterwards.
simVideoFolder = dataDir;  % Always save in dataset folder
if contains(simVideoFolder, " ")
    simVideoFolder = fullfile(tempdir, "rr_video_export");
    if ~isfolder(simVideoFolder); mkdir(simVideoFolder); end
end
exportVideo(rrApp, VideoFolder=simVideoFolder, FileName="sim_frontCamera", VideoResolution="HD");

% exportVideo may save as .avi depending on codecs — always convert to .mp4
simVideoPath = fullfile(simVideoFolder, "sim_frontCamera.mp4");
aviPath = fullfile(simVideoFolder, "sim_frontCamera.avi");
if ~isfile(simVideoPath) && isfile(aviPath)
    aviReader = VideoReader(aviPath);
    mp4Writer = VideoWriter(simVideoPath, "MPEG-4");
    mp4Writer.FrameRate = aviReader.FrameRate;
    open(mp4Writer);
    while hasFrame(aviReader)
        writeVideo(mp4Writer, readFrame(aviReader));
    end
    close(mp4Writer);
    delete(aviPath);
end
```

**Step 2: Create side-by-side comparison (Input Camera | Simulation).** Three requirements are MANDATORY and have failed in past evals when omitted — none of them are optional:

1. **`insertText` timestamp burn on BOTH halves** — every frame of the comparison video must have a black-box label like `Input Camera (t=X.Xs)` on the left half and `RoadRunner Sim (t=X.Xs)` on the right half. The user uses these to spot drift between the recorded drive and the simulation; without them the video is much harder to interpret. Skipping `insertText` (just concatenating raw frames) FAILS the comparison-video assertion, even when the rest of the composition is correct.
2. **`questdlg` + `openFile` popup AFTER `close(vw)`** — the comparison video is NOT exempt from the saved-video popup HARD RULE. Every script that writes a comparison MP4 must immediately follow `close(vw)` with the `questdlg("...saved to...\n\nOpen it now?", "Yes", "No")` block whose Yes branch calls `openFile(compVideoFile)`. `fprintf("Saved: %s", ...)` alone is not acceptable.
3. **Defensive field-name inspect on the input recording's struct/MAT** — datasets vary in case (`Timestamp` vs `timestamp`, `ImagePath` vs `imagePath`, `TrackID` vs `trackID`). Before referencing fields off the loaded `S = load(...)` struct or any table, print `disp(fieldnames(S))` (or `disp(S.<Sensor>.Properties.VariableNames')` for a table) and use the discovered name. Hard-coding a guess produces a silent `Reference to non-existent field` mid-script and the comparison video never gets built.

```matlab
%% Side-by-side comparison video: Input (track-overlaid) vs Simulation
% PREFERRED: compose overlay on-the-fly from original frames to avoid
% double-compression blur (encode trackOverlay.mp4 → decode → resize → re-encode).
% Reading the pre-saved overlay video introduces generation loss.
simReader = VideoReader(simVideoPath);

targetH = 540; targetW = 960;
maxFrames = 100;  % side-by-side = heavier I/O per frame
step = max(1, ceil(cameraData.NumSamples / maxFrames));
frameIndices = 1:step:cameraData.NumSamples;
effectiveFPS = numel(frameIndices) / cameraData.Duration;

% Determine left-panel mode (same priority as Rule 2)
hasIntrinsics = ~isempty(cameraData.SensorParameters) ...
    && isstruct(cameraData.SensorParameters) ...
    && isfield(cameraData.SensorParameters, 'Intrinsics');
hasTracks = exist('trackData','var') && ~isempty(trackData.UniqueTrackIDs);

compVideoFile = fullfile(dataDir, "comparison_input_vs_sim.mp4");
vidWriter = VideoWriter(compVideoFile, "MPEG-4");
vidWriter.FrameRate = round(effectiveFPS);
open(vidWriter);

for frameIdx = frameIndices
    % Left panel: overlay from original frames (no double-compression)
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

    % Right panel: RR sim
    simReader.CurrentTime = min(t, simReader.Duration - 0.01);
    imgR = readFrame(simReader);
    imgR = imresize(imgR, [targetH targetW]);
    imgR = insertText(imgR, [10 10], sprintf("RR Sim Front (t=%.1fs)", t), ...
        FontSize=20, BoxColor="black", TextColor="white", BoxOpacity=0.6);

    writeVideo(vidWriter, [imgL, imgR]);
end
close(vidWriter);

%% MATLAB popup
answer = questdlg(sprintf("Comparison video (Input vs Simulation) saved to:\n%s\n\nWould you like to open it?", ...
    compVideoFile), "Comparison Video", "Yes", "No", "Yes");
if strcmp(answer, "Yes")
    openFile(compVideoFile);
end
```

## Alternative: Export to drivingScenario
```matlab
scenario = exportToDrivingScenario(egoTrajectory, ...
    Name="Ego", RoadNetworkSource="OpenStreetMap", FileName=osmFile);
```

## Alternative: Export to ASAM OpenSCENARIO & OpenDRIVE (via RoadRunner)
**Always export OpenSCENARIO and OpenDRIVE from RoadRunner** — it produces higher-accuracy geometry than the `drivingScenario` export path.
```matlab
% After building the scene in RoadRunner (exportToRoadRunner with SetupSimulation=true):
outDir = fullfile(tempdir, "exports");
if ~isfolder(outDir), mkdir(outDir); end

% Export OpenSCENARIO XML (automatically generates paired OpenDRIVE)
% NOTE: For "OpenSCENARIO XML", the options class is openScenarioXMLExportOptions.
% Using openScenarioExportOptions here is REJECTED by exportScenario with:
%   "Invalid export options object specified for 'OpenSCENARIO XML' format."
% Use openScenarioDSLExportOptions for "OpenSCENARIO DSL".
xoscFile = fullfile(outDir, "scenario.xosc");
xoscOpts = openScenarioXMLExportOptions( ...
    OpenScenarioVersion=1.1, ...
    OpenDriveOptions=openDriveExportOptions(ExportSignals=true, ExportObjects=true));
exportScenario(rrApp, xoscFile, "OpenSCENARIO XML", xoscOpts);

% Or export OpenDRIVE only (scene/road network without scenario logic)
xodrFile = fullfile(outDir, "road_network.xodr");
xodrOpts = openDriveExportOptions(ExportSignals=true, ExportObjects=true);
exportScene(rrApp, xodrFile, "OpenDRIVE", xodrOpts);
```
> **Note:** `exportScenario` generates both `.xosc` and a paired `.xodr` automatically. Use `openScenarioExportOptions` to control version (`OpenScenarioVersion`), OpenDRIVE file name, and catalog options. The RoadRunner path preserves full lane geometry, elevation, and signal placement that may be simplified in the `drivingScenario` export path.

For full API details of both export methods, read [`trajectory-api.md`](trajectory-api.md).

----

Copyright 2026 The MathWorks, Inc.

----
