---
name: osm-flat-scene-gotchas
description: Common pitfalls and fixes when building scenarios on flat OSM-derived scenes — Z handling, importScene options, simulation cleanup, image-frame datasets. Loaded when troubleshooting flat-scene export issues.
---

# OSM Flat-Scene Gotchas

> **Parent skill:** [`SKILL.md`](../SKILL.md) Rule 4 Step 4 (Download roads).
>
> **Related references:**
> - [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) — Option A (OSM download + import)
> - [`workflow-07-height-correction.md`](workflow-07-height-correction.md) — terrain-aware height (NOT applicable to flat scenes)

## When This Applies

A scene is "flat" when it was derived from OpenStreetMap. OSM roads carry no elevation data — all geometry Z is effectively 0. Symptoms of getting this wrong: actors floating above road, ego in air, vehicles invisible below ground plane.

**Detection:** After `importScene`, read the `.rrhd` geometry Z range. On OSM maps `range(Z) < 2 m` (noise). On terrain-aware maps it spans tens to hundreds of meters. Compare with `range(gpsData.Altitude)`.

## Gotcha 1: Flatten Z to 0 for ALL trajectories (ego AND actors)

On flat scenes, **every** trajectory's Z must be zeroed — ego AND actors. GPS altitude puts ego at ~30–50 m; actor Z is dominated by sensor mount offset (~1–1.5 m). Without flattening, vehicles float above the road.

```matlab
% Flat scene — zero Z for ALL actors
wp(:,3) = 0;
```

**Do NOT add +0.75 m on flat scenes** — that's only for terrain-aware scenes (HERE HD, Zenrin).

**Ego Z MUST also be flattened.** `trajectory(gpsData, ...)` preserves GPS altitude in `Position(:,3)` (typically 30–50 m). On flat OSM scenes, this puts the ego 30–50 m above the road. When rebuilding with Z=0, always preserve `Orientation` from localization:

```matlab
% CORRECT — flatten ego Z + preserve localized heading
locWp = localizedTrajectory.Position;
locWp(:,3) = 0;
egoFlat = scenariobuilder.Trajectory(localizedTrajectory.Timestamps, locWp, ...
    Name="Ego", LocalOrigin=localizedTrajectory.LocalOrigin, ...
    Orientation=localizedTrajectory.Orientation);

% WRONG — drops lane-aligned orientation, heading re-derived from waypoints
egoFlat = scenariobuilder.Trajectory(localizedTrajectory.Timestamps, locWp, ...
    Name="Ego", LocalOrigin=localizedTrajectory.LocalOrigin);
```

## Gotcha 2: Ego trajectory LocalOrigin MUST be set at construction time

```matlab
% CORRECT — LocalOrigin set in constructor
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);

% WRONG — modifying after construction does NOT recompute positions
egoTrajectory = trajectory(gpsData);
egoTrajectory.LocalOrigin = localOrigin;  % positions remain wrong
```

The `localOrigin` comes from `roadprops(OpenStreetMap=osmFile)` (second output).

## Gotcha 3: importScene options — exact API signatures

All three of these have been observed to fail with wrong signatures:

```matlab
% CORRECT
oOpts = enableOverlapGroupsOptions(IsEnabled=false);
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, rrhd, "RoadRunner HD Map", ImportOptions=iOpts);

% WRONG — these all error:
% enableOverlapGroupsOptions(EnableOverlapGroups=false)  ← wrong param name
% roadrunnerHDMapImportOptions(RoadRunnerHDMapBuildOptions=bOpts)  ← wrong param name
% importScene(rrApp, rrhd, ImportOptions=iOpts)  ← missing format string
```

## Gotcha 4: Acquiring the rrMap for localizeEgoUsingLanes

After importing OSM roads via `importScene`, two paths are valid for feeding the map to `localizeEgoUsingLanes`:

```matlab
% Path A — construct + read the .rrhd directly
rrMap = roadrunnerHDMap();
read(rrMap, rrhdFile);
localized = localizeEgoUsingLanes(egoTrajectory, rrMap, laneData, startLaneIdx);

% Path B — pass the rrApp object as the second argument
localized = localizeEgoUsingLanes(egoTrajectory, rrApp, laneData, startLaneIdx);
```

Both signatures are documented in `help localizeEgoUsingLanes` (R2025a+).

**HARD RULE — `getRoadRunnerHDMap(rrApp)` does NOT exist on the `roadrunner` app class.** It is a method of `drivingScenario` only. Calling it on an `rrApp` object errors with: *"Undefined function 'getRoadRunnerHDMap' for input arguments of type 'roadrunner'"*.

Do NOT:
- Call `getRoadRunnerHDMap(rrApp)` — it's a `drivingScenario` method, not an `roadrunner` (rrApp) method.
- Use `roadrunnerHDMap(file)` positionally — the constructor takes no positional file argument; use the empty constructor + `read()`.
- Pass the `.rrhd` file path directly to `localizeEgoUsingLanes` — the second arg must be a `roadrunnerHDMap` object or a `roadrunner` app object, not a string.

## Gotcha 5: Stale simulation object blocks new simulation

`exportToRoadRunner(..., SetupSimulation=true)` creates a simulation object. Attempting `simulateScenario` while this object exists errors with: *"A RoadRunner Scenario Simulation object already exists"*.

```matlab
% Always clean up before simulating
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
% HARD RULE — no Pacing= here. Pacing truncates/desyncs EnableLogging capture.
simulateScenario(rrApp, EnableLogging=true);
```

## Gotcha 6: OSM URL needs .xml endpoint

`getMapROI` returns a URL with `/api/0.6/map?` — some servers reject this without the `.xml` suffix:

```matlab
osmUrl = mapROI.osmUrl;
osmUrl = strrep(osmUrl, '/api/0.6/map?', '/api/0.6/map.xml?');
osmFile = websave(fullfile(tempdir, "map.osm"), osmUrl, weboptions(ContentType="xml"));
```

## Gotcha 7: Image-frame datasets (not video files)

Some datasets store camera data as individual image files (JPEG/PNG per frame), not a video file. Using `VideoReader` on these errors.

```matlab
% WRONG
vr = VideoReader(frames(1));  % errors — not a video file

% CORRECT
img = imread(frames(1));      % read individual frame images
```

When composing a video from image-frame datasets, use `VideoWriter` with profile `'MPEG-4'` (with hyphen):

```matlab
vw = VideoWriter(outputPath, 'MPEG-4');
vw.FrameRate = 10;
open(vw);
for k = 1:numel(frames)
    writeVideo(vw, imread(frames(k)));
end
close(vw);
```

## Gotcha 8: `openScene` vs `importScene` — different API for different file types

`importScene(rrApp, file, formatName, ...)` is for importing road data (RRHD, OpenDRIVE) into RoadRunner's scene editor. A saved `.rrscene` file is NOT a road data format — it is a complete scene snapshot.

```matlab
% CORRECT — open a previously saved .rrscene
openScene(rrApp, tempSceneFile);

% WRONG — importScene on .rrscene errors: "Not enough input arguments"
% because it expects a format string ("RoadRunner HD Map", "OpenDRIVE", etc.)
importScene(rrApp, tempSceneFile);  % ERRORS
importScene(rrApp, tempSceneFile, "RoadRunner Scene");  % also ERRORS — not a valid format
```

**When to use which:**
| File type | API | Example |
|-----------|-----|---------|
| `.rrscene` (saved scene) | `openScene(rrApp, file)` | Re-opening an OSM scene after `saveScene` |
| `.rrhd` (HD Map) | `importScene(rrApp, file, "RoadRunner HD Map", ImportOptions=...)` | First-time OSM road import |
| `.xodr` (OpenDRIVE) | `importScene(rrApp, file, "OpenDRIVE")` | External OpenDRIVE import |

## Gotcha 9: Rebuilding CameraData loses SensorParameters

`CameraData.Frames` is read-only — if frame paths are wrong, you must reconstruct the object. But `scenariobuilder.CameraData(timestamps, frames)` **drops all sensor parameters**. This silently downgrades the visualization mode (Mode 1 → Mode 3) because `hasIntrinsics` becomes false.

```matlab
% WRONG — loses intrinsics
cameraData = scenariobuilder.CameraData(camTimestamps, correctFrames);

% CORRECT — preserve SensorParameters on rebuild
sensorParams = struct( ...
    'Intrinsics', CameraIntrinsics, ...
    'MountingLocation', [0 0 CameraHeight], ...
    'MountingAngles', [0 0 0], ...
    'EgoOriginHeight', 0);
cameraData = scenariobuilder.CameraData(camTimestamps, correctFrames, ...
    SensorParameters=sensorParams);
```

**Frame-path validation (run immediately after construction):**
```matlab
assert(numel(unique(cameraData.Frames)) > 1, ...
    "All CameraData.Frames point to the same file — check image file list construction");
```

## Gotcha 10: scenariobuilder.Trajectory vs trajectory() function

For GPS data, use the `trajectory()` function (lowercase) — not the class constructor:

```matlab
% CORRECT — function call with GPS data object
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);

% WRONG — class constructor rejects CoordinateType="Geographic"
egoTrajectory = scenariobuilder.Trajectory(..., CoordinateType="Geographic");
```

`scenariobuilder.Trajectory(times, waypoints, ...)` is for actor tracks (local XYZ waypoints). `trajectory(gpsData, ...)` is for GPS-to-trajectory conversion.

---

Copyright 2026 The MathWorks, Inc.
