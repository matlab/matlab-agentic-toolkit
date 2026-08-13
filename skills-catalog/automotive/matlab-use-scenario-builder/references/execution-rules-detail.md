---
name: execution-rules-detail
description: Detailed code blocks, tables, and templates supporting the Execution Rules in SKILL.md (Rules 1, 5, 6, 7, 11). Loaded when the agent needs the full progress-table example, timestamp-conversion code, data-format mapping table, script header template, actor-aware OSM buffer, collision fail-condition snippet, or preferred-pipeline migration code.
---

# Execution Rules — Detailed Reference

> **Parent skill:** [`SKILL.md`](../SKILL.md). The mandates of each rule are inline in `SKILL.md`. Heavy code blocks, tables, and templates live here.

## Rule 1 — Progress Table Example

The standard progress-table format used by `Rule 1` in `SKILL.md`:

```
| # | Step                              | Status | Info                             |
|---|-----------------------------------|--------|----------------------------------|
| 1 | Load data & create sensor objects | ✅     | GPS(80), Tracks(80), Camera(80)  |
| 2 | Preprocess & synchronize          | ✅     | 80 samples, 7.90s duration       |
| 3 | Download roads (OSM = OpenStreetMap) | ✅  | Buffer=58.9m, origin=[37.37, -122.06] |
| 4 | Build ego trajectory              | ✅     | 80 waypoints, smoothed           |
| 5 | Localize ego (lane detection)     | ✅     | RVLD, 4 boundaries, lane 2, Δ=0.97m |
| 6 | Verify localization in RoadRunner | ✅     | green=localized, red=raw — ASK USER |
| 7 | Generate scenario (delete red, add actors) | ⬜ |                              |
| 8 | Visualize camera (track overlay)  | ⬜     |                                  |
| 9 | Simulate & export video           | ⬜     |                                  |
```

- ✅ for completed, ⬜ for pending. Mark each step ✅ immediately after completion.
- Re-print the FULL table after EVERY step completes. Never skip a re-print between steps.
- Steps MUST be checked in sequential order — never mark a later step ✅ before earlier steps are done.
- Adapt the step list to the task; combine closely related operations into one row (~8 rows max).
- Always say "OSM (OpenStreetMap)" or "OSM = OpenStreetMap" at least once when referencing OpenStreetMap.

**Output paths:**
- Save all videos in the dataset folder (the folder containing `sensorData.mat`), NOT in `pwd` or a temp dir. Use a `dataDir` variable.
- After saving any video file, print the full path in the Claude session AND in MATLAB via `fprintf`.

## Rule 5 — Timestamp Scale Detection & Synchronization Code

```matlab
%% Detect timestamp scale and convert to seconds BEFORE creating objects
%
% Two checks — the first matches POSIX-anchored timestamps; the second
% catches relative timestamps that start near 0. HERE HD / OpenDRIVE
% datasets often store timestamps in microseconds-since-trip-start, so
% the first sample is small but the *span* (end - start) is huge.
% Without the span check, you build a 23-million-second trajectory.
sampleTs = rawTimestamps(1);
spanTs   = rawTimestamps(end) - rawTimestamps(1);
if sampleTs > 1e15 || spanTs > 1e9
    rawTimestamps = rawTimestamps / 1e6;  % microseconds → seconds
elseif sampleTs > 1e12 || spanTs > 1e6
    rawTimestamps = rawTimestamps / 1e3;  % milliseconds → seconds
end
% Apply the SAME conversion to every sensor's raw timestamps before
% constructing scenariobuilder.* objects — mismatched units cause silent
% sync failures (durations of millions of seconds, empty crops, etc.).

%% After creating sensor objects — normalize and synchronize
convertTimestamps(gpsData, "numeric");
convertTimestamps(trackData, "numeric");
timeRef = normalizeTimestamps(gpsData);
try
    normalizeTimestamps(trackData, timeRef);
catch
    normalizeTimestamps(trackData);  % normalize independently if shared ref fails
end
synchronize(trackData, gpsData);
assert(isnumeric(gpsData.Timestamps), "GPS timestamps must be numeric seconds");
fprintf("All sensors synchronized: %d samples, duration %.2f s\n", ...
    gpsData.NumSamples, gpsData.Duration);
```

**`normalizeTimestamps` pitfall:** `convertTimestamps(obj, "numeric")` may internally normalize timestamps to start at 0 for some sensors but not others. After calling `convertTimestamps`, check if timestamps already start near 0 before calling `normalizeTimestamps` with a shared reference. If one sensor is already normalized but another still has POSIX values, normalize each independently first, then synchronize.

## Rule 6 — Data Format / Mapping Table

Present this table to the user before importing. Fill the "Your Data" and "Raw Magnitude / Scale" columns with what you actually detect from the workspace; flag mismatches.

**HARD RULE — Raw timestamp magnitudes are mandatory, not optional.** For every sensor with a `timestamps` row, you must run `max(rawTs)` (and `rawTs(end) - rawTs(1)` if `rawTs(1)` is small) before constructing the `scenariobuilder.*` object, then write the magnitude AND the Rule 5 scale factor (`/1`, `/1e3`, `/1e6`, `/1e9`) into the table. A blank or hand-waved magnitude entry is not acceptable — the table is the proof that Rule 5 was applied. Construction with the wrong scale silently builds million-second trajectories that only fail downstream at simulate-time (e.g., RoadRunner: *"Simulation step size 49999.1 is out of range"*) — by which point you have wasted a full pipeline run.

| Sensor | Required Fields | Expected Format | Your Data | Raw Magnitude / Scale |
|--------|----------------|-----------------|-----------|-----------------------|
| **GPS** | `timestamps` | N×1 numeric (seconds), datetime, or duration | *<detected>* | *<max(rawTs) → /1, /1e3, /1e6, /1e9>* |
| | `latitude` | N×1 numeric column vector (degrees) | *<detected>* | — |
| | `longitude` | N×1 numeric column vector (degrees) | *<detected>* | — |
| | `altitude` | N×1 numeric column vector (meters) | *<detected>* | — |
| **Actor Tracks** | `timestamps` | N×1 numeric column vector (seconds) | *<detected>* | *<max(rawTs) → scale>* |
| | `trackID` | N×1 cell array; each cell is M×1 string array | *<detected>* | — |
| | `position` | N×1 cell array; each cell is M×3 numeric `[x y z]` (meters, ego-relative) | *<detected>* | — |
| | `dimension` (optional) | N×1 cell array; each cell is M×3 `[length width height]` (meters) | *<detected>* | — |
| | `orientation` (optional) | N×1 cell array; each cell is M×3 `[yaw pitch roll]` (degrees) | *<detected>* | — |
| **Camera** | `timestamps` | N×1 numeric (seconds) | *<detected>* | *<max(rawTs) → scale>* |
| | `imageFileNames` | N×1 cell array of file paths | *<detected>* | — |

**Known-dataset quick reference (extend as new datasets are validated):**

| Dataset | Raw timestamp unit | Magnitude | Scale to apply |
|---------|---------------------|-----------|----------------|
| Pandaset | POSIX seconds | ~1.5e9 | `/1` (none) |
| Polysync | microseconds since epoch | ~1.46e15 | `/1e6` |
| nuScenes | microseconds since epoch | ~1.5e15 | `/1e6` |
| KITTI raw | POSIX seconds | ~1.3e9 | `/1` |
| HERE HD recordings | microseconds-since-trip-start (small first sample, large span) | sample ~0, span ~1e7 | `/1e6` (span check) |
| OEM CAN (AH_ACC) | POSIX seconds (GPS) / relative seconds (CAN) | ~1.5e9 (GPS), variable (CAN) | `/1` — but check Y-axis flip |

**Field name case sensitivity:** MATLAB table variable names are case-sensitive. Datasets vary in naming (e.g., `timestamp` vs `timeStamp`, `filename` vs `fileName`, `TrackID` vs `trackID`). Always inspect `.Properties.VariableNames` before accessing any field:
```matlab
disp(data.GPSData_Raw.Properties.VariableNames');
disp(data.CameraData.Properties.VariableNames');
```

## Rule 7 — MCP Chunking & Skip-If-Done

### MCP Timeout Prevention

When executing via MCP (each `evaluate_matlab_code` call has a ~90s timeout), never combine multiple expensive operations in one call. Split into chunks:

| Chunk | Operations | Typical time |
|-------|-----------|--------------|
| 1 | Load CAN/MAT data + reshape + build objects + actorprops | 30–40s |
| 2 | Export ego + N actors to RoadRunner | 5–10s per actor |
| 3 | simulateScenario (capped duration) | ≤30s for validation |
| 4 | exportVideo | 10–20s |
| 5 | Comparison video composition | 15–20s |
| 6 | (If long data) Full-duration simulate + export | runs in RR, agent polls |

**Never combine** simulate + exportVideo in one MCP call. Never combine data-load + full export pipeline. Each chunk must complete within 90s.

### Skip-If-Done Pattern (mandatory for all expensive operations)

Every expensive step MUST check if its output already exists before re-running. This prevents wasted time on re-runs after a failure at step N:

```matlab
if ~isfile(osmFile)
    websave(osmFile, mapROI.osmUrl, weboptions(ContentType="xml", Timeout=30));
end
if ~isfile(rrhdFile)
    write(rrMap, rrhdFile);
end
if ~isfile(tempSceneFile)
    importScene(rrApp, ...);
    saveScene(rrApp, tempSceneFile);
end
```

Apply this pattern to: OSM download, RRHD write, scene import/save, video export. Do NOT apply to `exportToRoadRunner` (actor state changes between runs) or `simulateScenario` (must always re-run after actor changes).

## Rule 7 — Standard Script Header Template

```matlab
%% Scenario Generation Script
% Purpose: <describe what this script does>
% Inputs:  <list input data files or variables>
% Outputs: <list outputs — trajectories, exported scenarios, etc.>

%% Cleanup
close all
if exist('rrApp','var'), close(rrApp); clear rrApp; end

%% Set dataDir — all video outputs go here (the dataset folder with sensorData.mat)
dataDir = "<path-to-dataset-folder>";
```

## Rule 8 — Multi-Script Pipeline Pitfall (Preventing Multiple RoadRunner Windows)

If you split a long pipeline across multiple scripts to checkpoint between user-gated pauses (e.g., `partN_state.mat` files for `startLaneIdx`, raw-vs-localized choice, etc.), do **not** start each part with `clear; clc;` followed by an unconditional `rrApp = roadrunner(...)`. `clear` wipes the MATLAB-side handle but does NOT close the RoadRunner desktop process — so each new `roadrunner(...)` call spawns another GUI window. The Rule 8 single-instance guard cannot help across `clear` boundaries because the `exist('rrApp','var')` check always fails.

**Pick one of these patterns:**

**A — Preferred: single script with inline pauses.** Keep one script and use `uiwait(msgbox(...))` / `questdlg(...)` / `inputdlg(...)` to gate user input between RoadRunner stages. The guard fires once, RoadRunner launches once.

```matlab
%% Stage 1: build trajectory, run lane detection, show compare video
% ... build egoTrajectory, localizedTrajectory, save compare video ...
openFile(compareVideoPath);

%% Pause for user input — do NOT split into a separate script
choice = questdlg("Use raw or localized trajectory?", ...
    "Trajectory choice", "Raw", "Localized", "Localized");
chosenTrajectory = (choice == "Localized") * localizedTrajectory ...
                 + (choice == "Raw")       * egoTrajectory;

%% Stage 2: final scenario — same rrApp instance, no relaunch
newScenario(rrApp);
exportToRoadRunner(chosenTrajectory, rrApp, ...);
```

**B — Multi-script split (only if checkpointing is essential).** At the **end** of part N, close RoadRunner cleanly:
```matlab
% End of partN.m
close(rrApp); clear rrApp;
save("partN_state.mat", "egoTrajectory", "localizedTrajectory", ...);
```
At the **top** of part N+1, do NOT `clear` outright (only clear specific workspace variables you need to reset). The Rule 8 guard then works:
```matlab
% Top of partNplus1.m
S = load("partN_state.mat");
% (optional, targeted) clear figureHandle videoWriter
if ~exist('rrApp','var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end
```
If you must `clear` outright, also kill any stray RoadRunner process before re-launch (`!taskkill /im RoadRunner.exe /f` on Windows, `system('pkill RoadRunner')` on Linux/macOS) to avoid stacking windows.

**Default shape in this skill is single-script.** Every reference template (`workflow-04-roadrunner-export-detail.md`, `example-scenario-from-gps-and-tracks.md`, `example-roadrunner-scenario.md`, `workflow-16-aerial-lidar-augmentation.md`, `workflow-17-traffic-signs-from-sensor-data.md`) opens RoadRunner once and keeps it alive through export. Only deviate from that shape if a specific checkpointing need justifies the complexity.

## Rule 11 — Code Snippets (Actor-Aware Buffer, Collision Fail-Condition, Preferred Pipelines)

**Actor-aware OSM buffer (computed before `getMapROI`):**
```matlab
maxLateral = 0;
for i = 1:numel(trackPositions)
    pos = trackPositions{i};
    if ~isempty(pos)
        maxLateral = max(maxLateral, max(abs(pos(:,2))));
    end
end
buffer = maxLateral + 50;  % 50m margin for road width
```

**Collision fail-condition handling (Rule 4 step 9):**
```matlab
% SetupSimulation=true (in exportToRoadRunner) creates a sim object that
% blocks simulateScenario. Delete it first, then get a fresh rootPhase.
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
rootPhase = roadrunnerAPI(rrApp).Scenario.PhaseLogic.RootPhase;
failCond = rootPhase.setFailCondition("DurationCondition");
failCond.Duration = egoTrajectory.Duration + 10;
simulateScenario(rrApp, EnableLogging=true);  % EnableLogging required for exportVideo
```

**Standard OSM import pattern (use for ALL export targets):**
```matlab
mapROI = getMapROI(gpsData.Latitude, gpsData.Longitude, Extent=buffer);
osmFile = fullfile(tempdir, "drive_map.osm");
websave(osmFile, mapROI.osmUrl, weboptions(ContentType="xml"));
[roadProperties, localOrigin] = roadprops(OpenStreetMap=osmFile);
```

**Preferred pipeline for programmatic road generation:**
```
laneBoundarySegment(boundaryIDs, boundaryPoints)
  → laneBoundaryGroup(lbseg)
  → smoothBoundaries(lbGroup, ...)        % only if noisy detections
  → getLanesInRoadRunnerHDMap(lbGroup)
  → write(rrMap, filePath)
```

**Preferred pipeline when user has lat/lon/GPS/GNSS data:**
```
scenariobuilder.GPSData(timestamps, lat, lon, alt)
  → trajectory(gpsData)                          % or trajectory(gpsData, LocalOrigin=origin)
  → smooth(egoTrajectory)
  → exportToDrivingScenario(...)                 % or exportToRoadRunner(...)
```
Never manually combine `latlon2local` + `vehicle()` + `trajectory()` on a `drivingScenario`.

**Off-ramp: exporting preprocessed data (no scenario generation):**
| From | Method | Output |
|------|--------|--------|
| `CameraData` | `datastore(camData)` | `ImageDatastore` for DL/labeling |
| `LidarData` | `datastore(lidarData)` | Datastore for point cloud processing |
| Any sensor object | `read(obj, Format="table")` | MATLAB `table` |
| Any sensor object | `read(obj)` | `struct` |
| Any sensor object | `timetable(seconds(obj.Timestamps), ...)` | `timetable` |

**Migration from legacy objects:** If you encounter `actorTracklist` or `objectTrack` arrays, convert via `importFromObjectTrack()` on an `ActorTrackData` object before proceeding.

## Rule 12 — Minimum-Change Reruns

When the user flags a defect, identify the smallest blast radius and patch only that. Each unnecessary rerun on a real pipeline costs 30-60s plus risks file-lock issues on network shares.

**Defect → minimum change:**

| Defect | Minimum change | Do NOT |
|---|---|---|
| Wrong actor color | Re-export only the affected actor with new `Color=...` | Rebuild scene or re-run other actor exports |
| Wrong orientation (`yaw/pitch/roll`) | Re-export only the affected actor with corrected `Orientation` | Re-extract via `actorprops` |
| Wrong camera mode / focus actor | `setCameraMode(rrApp, ...)` then re-run `simulateScenario` + `exportVideo` only | Rebuild scenario or re-export actors |
| Wrong scene flag (e.g. `EnableOverlapGroups`) | Re-import the scene only | Re-run any actor or simulation work |
| Network-share write failure | Export to local `tempdir`, then `copyfile` to share | Re-run the simulation |
| Stale cosim / collision condition triggered | `setFailCondition("DurationCondition")` and re-simulate | Recreate `rrApp`, scene, or actors |

**Process rule:** Before re-running anything, write a one-line plan: *"the defect is X; the minimum change is Y."* If Y doesn't include "rebuild scenario", don't rebuild the scenario.

**Staged-script pattern for human-gated pipelines.** When the pipeline has multiple human-in-the-loop gates (e.g. multi-GPS pick → lane-index ASK → raw-vs-localized pick), split into numbered scripts that save state to a `.mat` between gates: `part1.m` (load+trajectory+gate1) → `part2a.m` (lane detect+track+gate2 hint) → `part2b.m` (localize+gate3) → `part3.m` (final scenario). Each part reloads state, does one section, prints what the user needs to see, saves new state, and exits. This means a defect at gate 3 only re-runs `part2b.m` — not lane detection. See [`workflow-08-lane-localization.md`](workflow-08-lane-localization.md) ("Staged-script pattern" note) for the canonical layout.

----

Copyright 2026 The MathWorks, Inc.

----
