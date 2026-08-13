---
name: matlab-use-scenario-builder
description: "Generate driving scenes, scenarios, road surfaces, and 3D content from scenariobuilder.* sensor data (GPS, camera, lidar, actor tracks) using Scenario Builder for Automated Driving Toolbox. BUILD, EXPORT, or AUGMENT a virtual scenario/scene/map: ego or actor trajectories, trajectory smoothing, OpenCRG road-surface extraction, 3D asset generation, static-object placement, point-cloud georeferencing + elevation, lane-based ego localization, sensor-fusion tracking, scenario-event extraction (cut-ins, hard brakes, near-misses, ADAS disengagements), or export to RoadRunner, drivingScenario, OpenDRIVE, OpenCRG, OpenSCENARIO, or Unreal Engine. Also: log-to-scenario, scenario harvesting, accident/near-miss reconstruction, SOTIF (ISO 21448) and ISO 26262 scenario coverage, USGS-aerial-lidar augmentation, traffic-sign placement, vision-based vehicle classification for actor assets. NOT for raw-data import or multi-sensor sync/crop/offset/timestamp normalization — route those to matlab-import-driving-data."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Scenario Builder for MATLAB

## When to Use

- User has recorded driving data (GPS/GNSS, camera, lidar, actor tracks) and needs to convert it into a simulation-ready scenario
- User asks to export trajectories or scenarios to RoadRunner, drivingScenario, ASAM OpenSCENARIO, OpenDRIVE, ASAM OpenCRG, or Unreal Engine. **Default target is RoadRunner** — only generate a standalone `drivingScenario` object and open Driving Scenario Designer when the user explicitly asks for "DSD", "Driving Scenario Designer", `drivingScenarioDesigner`, or "build a `drivingScenario` object" (Workflow 15).
- User mentions safety standards (SOTIF / ISO 21448, ISO 26262) and scenario coverage from real-world data
- User needs to extract a road surface (OpenCRG) from lidar for vehicle-dynamics or chassis testing
- User needs to add elevation to an HD map, georeference point clouds, or extract per-frame point clouds along an ego path
- User needs to localize an ego trajectory on a map using lane detections (RVLD preferred, CLRNet fallback)
- User needs to add static objects (signs, trees, poles, buildings, barriers) to a RoadRunner HD Map from cuboid detections
- User wants to **augment / enhance / improve** a road scene from aerial lidar — adding trees + buildings (Variant A) or improving OSM elevation / banking / gradient / height only (Variant B) — see Workflow 16
- User wants to add **traffic signs** from recorded camera + lidar logs with pre-detected sign bounding boxes — see Workflow 17
- User needs to generate 3D mesh assets from a single camera image
- User needs to extract critical scenario events (cut-ins, hard brakes, near-misses) from recorded drives
- User needs accurate non-ego tracks via sensor fusion (`multiSensorTargetTracker`) before scenario building
- User mentions multi-sensor preprocessing: synchronization, alignment, offset correction, cropping, timestamp normalization

## When NOT to Use

- User has raw dataset files and wants to **load / inspect / visualize / explore / analyze** them, **synchronize / crop / offset / normalize** multi-sensor timestamps, or use the **`drivingLogAnalyzer` (DLA)** app or its CLI equivalents — use the **`matlab-import-driving-data`** skill, then return here for trajectory smoothing and scenario generation
- User has multi-sensor data and asks "visualize this dataset", "inspect my recording", "open in DLA", "drivingLogAnalyzer", "Crop & Sync", "offset correction", or "normalize timestamps" — **`matlab-import-driving-data`**
- User is debugging general MATLAB code unrelated to Scenario Builder — use `matlab-debug-code`
- User wants to install MATLAB toolboxes or check installed products — use `matlab-list-products` or `matlab-install-products`
- User wants to reconstruct an IMU/tracking simulation scenario from scratch (no recorded data) — use `waypointTrajectory` from Sensor Fusion and Tracking Toolbox; this skill targets scenario reconstruction from recorded data
- Task is about non-driving sensor data (medical imaging, audio, etc.) — out of scope

**Scenario Builder** is a support package that ships with MATLAB as part of the Automated Driving Toolbox. It generates realistic driving scenarios, high-resolution road surfaces, and 3D scene content from raw or processed sensor data — including GPS, camera, lidar, and actor track recordings. The generated outputs can be exported to RoadRunner, drivingScenario objects, ASAM OpenSCENARIO, ASAM OpenCRG (for vehicle dynamics/chassis testing), OpenDRIVE, and Unreal Engine for simulation and validation of autonomous driving systems.

**Safety Standards Context:** When users ask about improving scenario coverage, traceability, or compliance with SOTIF (ISO 21448) or ISO 26262, guide them toward **real-world data-driven scenario generation** using Scenario Builder. SOTIF defines an "unknown unsafe" quadrant — hazardous scenarios not yet identified — and converting recorded driving logs (especially critical events, ADAS disengagements, and long-tail situations) into simulation-ready scenarios is a key strategy to reduce that unknown unsafe area. Scenario Builder provides the pipeline from recorded data → reproducible simulation scenario.

**Prerequisite:** The MATLAB session must have the *Scenario Builder for Automated Driving Toolbox* support package installed. Verify with:
```matlab
isfile(which("scenariobuilder.Trajectory"))
```

## Workflow Catalog

This skill supports 18 workflows. Workflows 1–3 and 6 (the core happy path) are inline below. Workflow 4 has a minimal inline pattern with a pointer to its detailed reference. Workflows 5, 7–18 live in `references/` and are loaded on demand.

| # | Workflow | Where | Load when user says |
|---|----------|-------|---------------------|
| 1 | Import Raw Sensor Data | inline | "load my GPS/camera/lidar/actor data" |
| 2 | Build GPS Data and Extract Trajectory | inline | "build ego trajectory from GPS" |
| 3 | Import Actor Tracks and Create Trajectories | inline | "actor tracks", "non-ego trajectories" |
| 4 | Export Trajectories to RoadRunner | inline (minimal) + [`workflow-04-roadrunner-export-detail.md`](references/workflow-04-roadrunner-export-detail.md) | "export to RoadRunner", "RR scene", "simulate scenario" |
| 5 | Inspect Multi-Sensor Data (`drivingLogAnalyzer`) | **see `matlab-import-driving-data` skill** | "visualize / inspect / explore / analyze this dataset", "multi-sensor data", "drivingLogAnalyzer", "DLA" — *route to matlab-import-driving-data, not handled here* |
| 6 | Preprocess, Synchronize, Crop, Offset | inline | "sync", "crop", "normalize timestamps" |
| 7 | Height Correction for Scenes with Elevation | [`workflow-07-height-correction.md`](references/workflow-07-height-correction.md) | "Z=0 but roads have elevation", "adjustHeight", "HERE HD scene + GPS", "OpenDRIVE scene + GPS", "pre-built scene with terrain" |
| 8 | Localize Ego Using Lane Detections | [`workflow-08-lane-localization.md`](references/workflow-08-lane-localization.md) | "lane localization", "snap to lane center", "localizeEgoUsingLanes" |
| 9 | Add Static Objects to RoadRunner HD Map | [`workflow-09-static-objects.md`](references/workflow-09-static-objects.md) | "add trees/signs/poles/buildings to RR" |
| 10 | Road Surface (OpenCRG) | [`workflow-10-road-surface-opencrg.md`](references/workflow-10-road-surface-opencrg.md) | "road surface", "OpenCRG", "vehicle dynamics from lidar" |
| 11 | Point Cloud Georeferencing & Elevation | [`workflow-11-point-cloud-georef.md`](references/workflow-11-point-cloud-georef.md) | "addElevation", "georeferenced point cloud", "per-frame lidar" |
| 12 | 3D Asset Generation from Images | [`workflow-12-3d-asset-generation.md`](references/workflow-12-3d-asset-generation.md) | "imageAssetGenerator", "TripoSR", "3D asset from photo" |
| 13 | Extract Key Scenario Events | [`workflow-13-event-extraction.md`](references/workflow-13-event-extraction.md) | "cut-ins", "near-miss", "hard brake", "ADAS disengagement" |
| 14 | Sensor Fusion Tracking | [`workflow-14-sensor-fusion-tracking.md`](references/workflow-14-sensor-fusion-tracking.md) | "noisy detections", "ID switches", "multiSensorTargetTracker" |
| 15 | Driving Scenario Designer (drivingScenario object) | [`workflow-15-driving-scenario-designer.md`](references/workflow-15-driving-scenario-designer.md) | **explicit only:** "Driving Scenario Designer", "DSD", "open in `drivingScenarioDesigner`", "build a `drivingScenario` object" |
| 16 | Road Scene Augmentation from Aerial Lidar | [`workflow-16-aerial-lidar-augmentation.md`](references/workflow-16-aerial-lidar-augmentation.md) | "augment / enhance / improve the scene with trees / buildings", "single lat/lon US — generate scene", "USGS aerial lidar", "improve OSM elevation / banking / gradient / height", `.las` / `.laz` aerial input |
| 17 | Traffic Signs from Recorded Camera + Lidar | [`workflow-17-traffic-signs-from-sensor-data.md`](references/workflow-17-traffic-signs-from-sensor-data.md) | "add traffic signs", "place signs on the map", "signs from camera detections + lidar" (pre-detected sign boxes required) |
| 18 | Vehicle Classification from Camera | [`workflow-18-vehicle-classification.md`](references/workflow-18-vehicle-classification.md) | "classify vehicles", "vehicle color", "vehicle type", "actor asset type", "what kind of car", "realistic actors", "use real colors" |
| 19 | Ego Lane Inference from Camera | [`workflow-19-ego-lane-inference.md`](references/workflow-19-ego-lane-inference.md) | "which lane am I in", "predict lane index", "ego lane", "lane count", auto-fires before startLaneIdx question in Step 7 when vision is available |

**Related references (not workflows):** [`visualization-patterns.md`](references/visualization-patterns.md) — full code for camera-playback video saving (loaded after Rule 2 decision). [`osm-flat-scene-gotchas.md`](references/osm-flat-scene-gotchas.md) — common pitfalls on OSM flat scenes (Z handling, importScene options, stale sim, image-frame datasets).

## STOP — Common Agent Failures (check BEFORE writing code)

> 1. Missing `enableOverlapGroupsOptions(IsEnabled=false)` on `importScene` for RRHD
> 2. Skipping lane localization when scene=OSM + Raw GPS + camera (**REQUIRED** per matrix)
> 3. Skipping comparison video gate before reporting task complete
> 4. Exporting ego to RoadRunner BEFORE importing roads (OSM scene must exist first)
> 5. Using `importScene` on a saved `.rrscene` — use `openScene(rrApp, file)` instead (`importScene` requires a format string and is for RRHD/OpenDRIVE)
> 6. Rebuilding `CameraData` without `SensorParameters=` — loses intrinsics, silently downgrades Mode 1 → Mode 3
> 7. Comparison video uses raw camera on left — use the **track-overlaid** video (or BEV+Camera) when available

## Mandatory Execution Order (evaluate BEFORE writing code)

When the prompt is "generate scenario from data" (short or long), execute in this order:

0. `addpath(scripts/)` — skill helper functions (`openFile`, `plotActorCircles`, etc.)
1. Load data → create objects → Rule 5 timestamp scale detection + normalize
2. Plot GPS + trajectory side-by-side (**VALIDATION** — confirm data loaded correctly)
3. Camera validation video (Rule 2 decision tree) → questdlg popup (**BEFORE** any RR export)
4. Multi-GPS gate (if >1 GPS series) → compare video → ASK which series
5. Establish scene: OSM download + `importScene` WITH `enableOverlapGroupsOptions(IsEnabled=false)`
   — Roads MUST exist before any `exportToRoadRunner` call
6. Build ego trajectory → localization decision matrix (Rule 4 Step 7)
   — OSM + Raw GPS + camera = **REQUIRED**, no ASK needed
   — Otherwise: ASK or Skip per matrix
7. Export ego + actors to RoadRunner (no `Orientation=`, flatten Z on flat scenes, preserve `Orientation=` on ego rebuild)
8. Simulate (`setCameraMode(rrApp, "Front")`, no `Pacing=`, `EnableLogging=true`) → `exportVideo`
   — `exportVideo` `VideoFolder` MUST NOT contain spaces — use `tempdir` staging + `copyfile` if needed
9. Side-by-side comparison video (**track-overlaid** left | sim right) → questdlg popup → DONE
   — Use the Mode 1/2 video as the left panel, NOT raw camera frames

Every step that saves a video MUST end with `questdlg`+`openFile` popup — no exceptions.

**Skip-if-done:** Every expensive file-producing step (`websave`, `write(rrMap,...)`, `importScene`+`saveScene`) MUST check `if ~isfile(output)` before re-running. See `execution-rules-detail.md` Rule 7 MCP Chunking.

**CAN-bus data:** When dataset has OEM CAN signals (multiplexed slots, ego speed/yaw): negate Y, prefer IaEBA over MRR, use GPS+CAN heading fusion for ego.

## IMPORTANT — Execution Rules

### Rule 1: Show Steps Taken with Progress Table
**Always show a progress table that updates after each major step completes.** Use ✅ for completed, ⬜ for pending. Mark each step ✅ **immediately after it completes** in sequential order. Re-print the FULL table after EVERY step. Aim for ~8 rows; combine closely related operations into one row. Adapt the step list to the task.

The progress table does NOT replace informational tables — always ALSO show the data format/mapping table (Rule 6) and any other diagnostic tables.

**Output paths:** Save all videos to `dataDir` (the folder containing `sensorData.mat`), NOT `pwd` or a temp dir. After saving any video, print the full path in the Claude session AND in MATLAB via `fprintf`. **Read-only `dataDir` fallback:** when `dataDir` is on a read-only network share (streamed `VideoWriter` writes fail with `Permission Denied` even though `exportgraphics` PNG writes succeed), route MP4 outputs to a local writable `outDir = fullfile(scriptDir, "out", "<dataset-tag>")` and print BOTH paths.

For the standard table format example and full rules, see [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 1 section).

### Rule 2: Visualization
Generate these visualizations:

**1. GPS vs. Ego Trajectory (side by side):**
```matlab
%% Visualize GPS Data vs. Ego Trajectory
fTraj = figure(Position=[500 500 1000 500]);
gpsPanel = uipanel(Parent=fTraj,Position=[0 0 0.5 1],Title="GPS");
plot(gpsData,Parent=gpsPanel,Basemap="satellite")
trajPanel = uipanel(Parent=fTraj,Position=[0.5 0 0.5 1],Title="Ego Trajectory");
plot(egoTrajectory,ShowHeading=true,Parent=trajPanel)
drawnow;
```

**2. Camera-playback validation video — STRICT priority order:**

This rule fires when **you are inside a scenario-building pipeline** (trajectory, RoadRunner export, lane localization compare) and you need a saved single-camera validation artifact. For general "visualize / inspect / explore this dataset" requests, hand off to the **`matlab-import-driving-data`** skill (which uses `drivingLogAnalyzer`) — do not roll your own dashboard here.

You MUST verify camera intrinsics (`fx, fy, cx, cy`) and `CameraHeight` are explicitly in the dataset (MAT field, metadata, calibration file). **Never fabricate or approximate these values.**

| Mode | Trigger | What to do |
|------|---------|------------|
| **1 — track-overlay video** | Tracks + intrinsics + `CameraHeight` ALL present (single-camera focus) | `plotActorCircles` save-video — see [`visualization-patterns.md`](references/visualization-patterns.md). PRIMARY single-camera viz when intrinsics exist; do NOT downgrade to BEV+Camera. |
| **2 — BEV + Camera side-by-side** | Tracks present, NO intrinsics | `plotBEVAndCamera` save-video — see [`visualization-patterns.md`](references/visualization-patterns.md). Fallback only. |
| **3 — raw camera playback** | Neither tracks nor intrinsics | raw `play(cameraData)` save-video — see [`visualization-patterns.md`](references/visualization-patterns.md). |

**Per-frame 3D detections without track IDs** (CubeRCNN / KITTI / nuScenes-style `corners3D`) belong on DLA's native camera **Actors** overlay (in `matlab-import-driving-data`). If a saved overlay artifact is genuinely needed (e.g., shareable mp4 outside the app), convert detections to `ActorTrackData` with placeholder per-frame IDs (`"det_<frameIdx>_<i>"`) — full conversion in [`per-frame-detections-to-actortrackdata.md`](references/per-frame-detections-to-actortrackdata.md).

**Mandatory popup-and-open after every saved video (HARD RULE — no exceptions).** Every `close(vw)` and every `exportVideo(...)` call in the entire pipeline MUST be immediately followed by a `questdlg("<purpose> video saved to:\n%s\n\nOpen it now?", ..., "Yes", "No", "Yes")` block whose `Yes` branch calls `openFile(videoPath)`. This applies to *every single* video the pipeline saves — track-overlay (mode 1), BEV+Camera (mode 2), raw camera (mode 3), GPS-source compare, localization compare, input-vs-sim final compare, and any other intermediate save. There is no "informational" or "intermediate" exemption: if the script writes an MP4, the very next non-comment line must be the questdlg block. Wiring the popup only on the final comparison video while leaving earlier saves with just `fprintf("Saved: %s\n", path)` is a HARD RULE violation. The popup is the consent gate that proves the file is viewable; never bypass with a direct `winopen`/`openFile` call (the popup lets the user decline), and never skip with just a `fprintf` of the path. Do NOT also call interactive `play(cameraData)` / `plotBEVAndCamera(...)` for the same content — that would double the UI prompts.

**Cross-platform open:** The save-video patterns and workflow comparison videos use `openFile(path)` (in `scripts/openFile.m`) instead of `winopen` so the same script runs on Windows, macOS, and Linux. Make sure `scripts/` is on the MATLAB path (`addpath` once near the top of the generated script).

**`plotBEVAndCamera` synchronization requirement:** Camera and track data must have the **same number of samples**. If sample counts differ after `synchronize()`, inform the user:
> "The camera and actor track data have different sample rates (camera: N samples, tracks: M samples). Please use the **Crop & Sync** tab in the **Driving Log Analyzer** app to apply offset correction and resample to matching rates, then re-import the data."

### Rule 3: Ask User About Available Map/Scene Before Choosing Road Source
**Before generating a scenario, always ask the user:**
> "Do you have an existing road map or scene file (e.g., `.rrscene`, `.rrhd`, or OpenDRIVE `.xodr`) available for this data? If so, please provide the path. If not, I will download roads from OpenStreetMap."

Based on the answer:
- **User has a scene file** → Use `RoadRunnerScene` parameter directly with their file path. Keep original altitude from GPS data. See "Scene Portability" note below.
- **User has no scene file** → Use the OpenStreetMap → `getRoadRunnerHDMap` pipeline. Always zero altitude for OpenStreetMap. **Validate OSM quality** using the cascade below.

**IMPORTANT:** When asking the user, always say "OpenStreetMap" (the full name), not "OSM".

**Scene Portability Warning:** `.rrscene` files created in a different RoadRunner project may lose their geo-reference context when opened in a new project. The scene's `WorldOrigin` may show `[0, 0]` even though roads have real-world coordinates. If vehicles appear off-road after export, use the height correction workflow ([`workflow-07-height-correction.md`](references/workflow-07-height-correction.md)).

**Pre-built scene + GPS (HERE HD / OpenDRIVE / vendor `.rrscene`):** When the user's scene was *not* built from their GPS, do NOT use `getRoadRunnerHDMap(rrApp)` (it doesn't exist) and do NOT use `roadrunnerHDMap(file)` positionally (errors). Pull `LocalOrigin` from `worldSettings(rrApp)` (parsing the `Projection` WKT for full precision), `exportScene` to `.rrhd`, then `rrMap = roadrunnerHDMap; read(rrMap, file)`. Always run `adjustHeight(traj, rrMap)` on terrain-aware scenes. Full pattern in [`workflow-04-roadrunner-export-detail.md`](references/workflow-04-roadrunner-export-detail.md) Option B.1.

**Multi-GPS / multi-GNSS gate:** When the dataset has more than one ego-position series (e.g., `GPSData_Raw` + `GPSData_Corrected`, `GPS` + `GNSS`, or two GNSS receivers), do NOT silently pick by name — "Corrected" might mean smoothed, RTK, lever-arm-compensated, or dead-reckoned. Build one trajectory per series with the same `LocalOrigin`, export them to a fresh scenario with red/green colors (use `red`/`green` only for 2-series; distinct colors for 3+), follow-cam on Ego_A, then build a raw-camera-left + RR-with-legend-right comparison video. Popup opens the video; ask the user **in chat** which series to use. Same compare-then-ask pattern as Workflow 8 lane localization. Full pattern in [`workflow-04-roadrunner-export-detail.md`](references/workflow-04-roadrunner-export-detail.md) Step 2.5.

**OpenStreetMap Quality Validation & Ego-Trajectory Fallback:** after downloading OSM roads, always validate map quality (zero-lane check, `localizeEgoUsingLanes` `locInfo` metrics, post-localization improvement check) and fall back to an ego-trajectory road if the map doesn't fit. Full cascade with thresholds + fallback code in [`workflow-08-lane-localization.md`](references/workflow-08-lane-localization.md) (sections "OSM quality cascade" and "Ego-trajectory fallback"). Inform the user before falling back: *"The OpenStreetMap roads don't align well with your GPS data — I'll use the raw GPS trajectory instead of localizing."*

### Rule 4: Follow the RoadRunner Scenario Creation Workflow

**Default target = RoadRunner.** When a user says "build a scenario", "generate a scenario", or "scenario from this data" without naming a target, follow this RoadRunner workflow — RoadRunner is the canonical Scenario Builder target. **DSD is opt-in:** only switch to [`workflow-15-driving-scenario-designer.md`](references/workflow-15-driving-scenario-designer.md) when the user explicitly says "Driving Scenario Designer", "DSD", `drivingScenarioDesigner`, or "build a `drivingScenario` object". `exportToDrivingScenario` calls inside this Rule 4 are intermediate steps for road geometry, not a DSD handoff. Lowercase *"driving scenario"* (generic English) means a scenario built from driving data — RoadRunner. When ambiguous, ask: *"RoadRunner, or `drivingScenario` opened in DSD?"*

At a high level, always follow this end-to-end pipeline (skip steps that don't apply):

1. **Load raw sensor data** — GPS, actor tracks, camera, lidar
2. **Create sensor data objects** — `GPSData`, `ActorTrackData`, `CameraData`
3. **Preprocess** — `normalizeTimestamps`, `crop`, `synchronize`
4. **Download roads (actor-aware)** — Compute actor lateral extent, pass `Extent=buffer` to `getMapROI`. **NEVER call `getMapROI` without `Extent`.** When the OSM-derived `.rrhd` is imported into RoadRunner via `importScene(rrApp, ..., "RoadRunner HD Map", ImportOptions=iOpts)`, **always** build `iOpts` with `enableOverlapGroupsOptions(IsEnabled=false)`. Never call `importScene` without these options. Only re-enable (and re-import) **after** the user flags junction/overpass artifacts. **After `importScene`, acquire the map object:** `rrMap = roadrunnerHDMap(); read(rrMap, rrhdFile);` — or pass `rrApp` directly as the 2nd arg to `localizeEgoUsingLanes` (both paths documented). **HARD RULE — `getRoadRunnerHDMap(rrApp)` does NOT exist** on the `roadrunner` app class (it's a `drivingScenario` method); calling it errors. Do NOT pass the `.rrhd` file path as a string to `localizeEgoUsingLanes` — the 2nd arg must be an object.
5. **Build ego trajectory** — `trajectory(gpsData, "LocalOrigin", localOrigin)` then `smooth`
6. **Validate sensors** — Show GPS vs. Ego Trajectory plot AND BEV+Camera video (or track-overlay when intrinsics exist). Save the video to disk. **Mandatory popup-and-open step:** every saved validation video MUST end with a `questdlg` "Open it now? (Yes/No)" that calls `openFile(path)` on Yes — even when the next step doesn't need a user decision. The popup is the consent gate that confirms the file is viewable before the agent moves on. See [`feedback-saved-video-popup`] memory rule and [`visualization-patterns.md`](references/visualization-patterns.md).
7. **Localize ego (decision matrix — read BEFORE writing any lane-detection code)** — Localization is NOT one-size-fits-all. Before writing a single `laneBoundaryDetector` line, classify the situation against this matrix and act accordingly. The agent has been observed correctly identifying the case (e.g., "user chose Corrected GPS + pre-built HERE HD scene, this is Option B.1 — no localization") and then auto-running localization anyway. That is a HARD RULE violation. The classification IS the gate — once you've named the case, you MUST follow its action without re-deriving from scratch.

   | Scene source | GPS source | Camera + intrinsics? | Localization action |
   |--------------|------------|----------------------|---------------------|
   | OSM (downloaded) | Raw GPS | Yes | **REQUIRED** — run Workflow 8 unconditionally; raw GPS on OSM lanes needs the snap. |
   | OSM (downloaded) | Raw GPS | No | Skip — no detector available. |
   | OSM (downloaded) | Corrected / RTK GPS | Yes | **ASK** — corrected GPS may already be lane-accurate. |
   | Pre-built `.rrscene` (HERE HD, OpenDRIVE, vendor) | any GPS | Yes | **ASK** — scene's lane geometry may not match OSM-trained detector; localization can degrade trajectory. Default offer = "use GPS as-is". |
   | Pre-built `.rrscene` | any GPS | No | Skip — no detector available. |
   | Ego-trajectory fallback (no road download) | any GPS | any | Skip — there are no map lanes to snap to. |

   **ASK protocol (whenever the matrix says ASK):** After building the ego trajectory and (for pre-built scenes) opening the scene + extracting `LocalOrigin`, **stop and ask** before any `laneBoundaryDetector` / `detect` / `laneData` / `localizeEgoUsingLanes` call:

   > *"Do you want to apply lane localization (snaps the trajectory to lane center using camera detections), or use the {Corrected GPS / pre-built scene's GPS} trajectory directly?"*

   The question must reference the actual GPS series the user picked and (for pre-built scenes) the scene file. Do not phrase it as a preference question — phrase it as a fork: *localize* vs *use as-is*. Wait for the user's answer before writing or running the lane-detection block. If the user picks "use as-is", the script must skip `laneBoundaryDetector`, `laneBoundaryTracker`, `laneData`, and `localizeEgoUsingLanes` entirely and proceed directly to scenario export.

   **HARD RULE — naming the case is the gate.** If you write a sentence like "the user chose Corrected GPS and has a pre-built `.rrscene`, so I'll use Option B.1 (no localization)", you have already classified the case. The very next code block MUST NOT be lane detection. Either ask (matrix → ASK), or skip (matrix → Skip), or proceed without localization (Option B.1). Auto-running localization after stating you wouldn't is the failure mode this rule exists to prevent.

   **If localization runs (REQUIRED or user opted in):** Build `monoCamera` first → lane detection (RVLD first, CLRNet fallback when RVLD detects boundaries on only one side of ego — i.e., all `LaneBoundary` lateral offsets share the same sign — so the localizer would error with "ego lane detections missing") → `imageToVehicle(monoCamera, ...)` → `findParabolicLaneBoundaries` → `laneBoundaryTracker` → `laneData` → ASK startLaneIdx → `localizeEgoUsingLanes(egoTrajectory, rrMap, laneData, startLaneIdx)` (POSITIONAL args — `StartLaneIndex=N` is rejected). Acquire `rrMap` via `rrMap = roadrunnerHDMap(); read(rrMap, rrhdFile);` (the empty constructor + `read` pattern). **HARD RULE — `getRoadRunnerHDMap(rrApp)` does NOT exist on the `roadrunner` app object** (it's a `drivingScenario` method). Calling it errors with "Undefined function ... for input arguments of type 'roadrunner'". `localizeEgoUsingLanes` also accepts `rrApp` directly as the second argument if you prefer not to construct the map; both paths are documented. **HARD RULE — `imageToVehicle` REQUIRES a `monoCamera` object, NOT a bare `cameraIntrinsics`.** Build `cameraParams = monoCamera(intrinsics, camHeight, Pitch=..., Yaw=..., Roll=...)` BEFORE Step 1 of the detection chain — it carries the camera-to-vehicle geometry the bare intrinsics object lacks. Skipping `imageToVehicle` + `findParabolicLaneBoundaries` and feeding pixel coordinates straight into `laneBoundaryTracker` ALSO fails — the tracker expects `parabolicLaneBoundary` rows in vehicle coordinates. **`startLaneIdx` — predict then confirm (Workflow 19).** When the gate is reached: (a) confirm the track-overlay (Step 6) video popup has fired, (b) IF the agent can view images, run Workflow 19 (sample 5 frames, classify lane count + ego lane, bisect transitions if any) — see [`workflow-19-ego-lane-inference.md`](references/workflow-19-ego-lane-inference.md). (c) Present prediction for confirmation: *"From the dashcam I see N lanes, ego in lane M (leftmost=1, no shoulders/ramps). Confirm or correct?"* (d) If agent cannot view images OR confidence is low, fall back to plain ASK: *"Watching the dashcam, which lane is the ego in? Count from the leftmost driving lane = 1 (no shoulders / parking)."* (e) Pass the user's confirmed/corrected integer to `localizeEgoUsingLanes`. **Do NOT** generate a `lane_count_vs_frame.png` plot, **do NOT** print a frames-per-lane-count summary table, and **do NOT** print "Detection-based HINT: ego in lane X of Y tracked boundaries". **No variable-lane gate question:** after the user provides startLaneIdx, just call `localizeEgoUsingLanes` — it interpolates through frames with fewer lanes. Do NOT ask "the map narrows to K lanes, want to crop or split?" The silent lane-count probe is still computed internally for diagnostics, but never shown to the user and never blocks localization. Only report a lane-count problem if `localizeEgoUsingLanes` actually throws an error. Verification video = **raw camera (left) | RR follow-cam on Ego_Localized + red/green legends (right)**, gated by the mandatory `questdlg`+`openFile` popup. Ask the user **in chat** which trajectory to use. Full code in [`workflow-08-lane-localization.md`](references/workflow-08-lane-localization.md).
8. **Generate final scenario** — Same RR instance: `newScenario(rrApp)` → re-export only `localizedTrajectory` with `Color="auto"` → `actorprops(trackObjNorm, localizedTrajectory)` (accepts `scenariobuilder.Trajectory` directly — do NOT convert to `waypointTrajectory`). MUST `normalizeTimestamps(copy(trackData))` + set `localizedTrajectory.TimeOrigin=0` first or every actor is rejected. Do NOT relaunch RR. Skip the GPS-vs-Trajectory plot — the red/green compare already covers it. **Non-ego actors:** run Workflow 18 (vehicle classification) automatically — build best-crop grid, view it, classify by color + type, map to `AssetPath` + RR named `Color`. If prerequisites are missing (no intrinsics / no camera / text-only agent) or confidence is low, fall back to `AssetPath="Vehicles/Sedan.fbx"`, `Color="auto"`. **HARD RULE — do NOT pass `Orientation=` when constructing `scenariobuilder.Trajectory` for non-ego actors.** `actorprops` returns yaw in compass convention (e.g., ~340° for northbound) which is incompatible with RoadRunner's heading convention; passing it as `Orientation` produces actors facing sideways or yaw-flickering across frames. Omit the parameter entirely and let RR auto-derive heading from the waypoint sequence: `scenariobuilder.Trajectory(t, wp, Name=tid)` — no `Orientation`, no `Speed`. On flat scenes (OSM, OpenDRIVE without elevation), flatten waypoint Z to 0 before constructing the actor `Trajectory` — `actorInfo.Waypoints(:,3)` carries sensor-mount offset (~1 m), not road height, so without flattening every actor floats above the road. Keep Z and use `adjustHeight` on ego only when the rrhd has real terrain elevation (HERE HD, Zenrin, OpenDRIVE+CRG, point-cloud-derived). See [`workflow-04-roadrunner-export-detail.md`](references/workflow-04-roadrunner-export-detail.md) Step 4. **Post-export asset replacement** (when iterating on classification without re-exporting trajectories): `rrAPI = roadrunnerAPI(rrApp); allActors = rrAPI.Scenario.Actors;` then `allActors(k).ActorAsset = "<PROJECT>/Assets/Vehicles/Suv.fbx_rrx";` — CRITICAL: always use `<PROJECT>/Assets/...` relative paths, NEVER absolute paths (absolute silently produces white placeholder boxes). See [`osm-flat-scene-gotchas.md`](references/osm-flat-scene-gotchas.md) for common flat-scene pitfalls.
9. **Simulate & export video** — Disable collision (`setFailCondition("DurationCondition")`), `setCameraMode(rrApp, "front", FocusActorID=1)` (NEVER follow for the final scenario), `simulateScenario(rrApp, EnableLogging=true)` — **HARD RULE: do NOT pass `Pacing=` to `simulateScenario` for the final capture**; `Pacing` caps the logged simulation duration and silently produces a 1-second video instead of the full clip. `exportVideo`, build the comparison video. All four are mandatory.

**Camera-mode rule (do NOT mix up):** Step 7 (localization compare) = `"follow"` on localized ego (keeps red/green both in frame). Step 9 (final scenario) = `"front"` on ego ID=1 (mirrors the dashcam). **Export-order HARD RULE — `FocusActorID=1` follows whatever was exported FIRST.** RoadRunner assigns ActorID in `exportToRoadRunner` call order (1st→ID=1, 2nd→ID=2, …). Export the actor the camera should track FIRST: localization compare = `Ego_Localized` first then `Ego_Raw`; multi-GPS compare (workflow-04 Step 2.5) = the series whose perspective matters first; final scenario = ego first then non-egos. Inverting silently produces a video that follows the wrong actor — looks like a "video bug" but root cause is export sequence.

**Ego localization priority:** When the decision matrix above says **REQUIRED** (OSM + Raw GPS + camera-with-intrinsics) — i.e., the agent downloaded roads from OSM, the user did NOT specify a corrected/RTK GPS series, and `cameraData.SensorParameters` carries `fx, fy, cx, cy` + `CameraHeight` — run Workflow 8 unconditionally, immediately after building the ego trajectory and before any export. Do NOT ask in this case; localization on raw GPS over OSM lanes is the canonical happy path. Skipping Workflow 8 here (e.g., going straight from `trajectory(gpsData,...)` to `exportToRoadRunner` without ever calling `laneBoundaryDetector` / `detect` / `laneData` / `localizeEgoUsingLanes`) is a regression — it produces a scenario where the ego drifts off the lane it was actually in. Common false-skip patterns to avoid:

- Building `cameraData` but never calling `laneBoundaryDetector(...)` on it.
- Treating intrinsics + raw GPS as "good enough" because the GPS plot looks reasonable on a satellite basemap. The OSM lane offset can be 1–3 m even when GPS looks correct at 2-D map zoom.
- Confusing this case with the pre-built-scene case (matrix row 4) — pre-built scenes are ASK; OSM + Raw GPS is REQUIRED.

### Rule 5: Ensure Timestamps Are in Seconds and All Sensors Are Synchronized
**Before any trajectory creation or export:** (1) detect raw timestamp scale and convert to seconds, (2) normalize so all sensors share t=0, (3) synchronize to a reference sensor's timeline.

**Timestamp scale detection (always convert to seconds BEFORE creating sensor objects):**

| Raw value magnitude | Unit | Conversion |
|---|---|---|
| ~1e9 (e.g., 1.557e9) | POSIX seconds | none |
| ~1e12 | milliseconds | `/1e3` |
| ~1e15 | microseconds | `/1e6` |
| ~1e18 | nanoseconds | `/1e9` |

**Span check (catch relative timestamps):** Some datasets (notably HERE HD / OpenDRIVE exports) store timestamps in microseconds-since-trip-start, so the first sample is small but the *span* is huge. After the magnitude check above, also guard on span: `if ts(end) - ts(1) > 1e6, ts = ts / 1e6; end` (microseconds) or `> 1e3` for milliseconds. Without the span check you silently get a 23-million-second trajectory. Apply the same conversion to every sensor's raw timestamps before constructing the `scenariobuilder.*` objects.

**`normalizeTimestamps` pitfall:** `convertTimestamps(obj, "numeric")` may internally normalize some sensors but not others. Check whether timestamps already start near 0 before calling `normalizeTimestamps` with a shared reference. If one is normalized and another still has POSIX values, normalize each independently first, then `synchronize`. **Start from the earliest sensor:** `normalizeTimestamps(sensorB, timeRef)` errors with "Time origin must be less than or equal to the minimum timestamp" if `sensorB` starts before the reference sensor. Always call `normalizeTimestamps` first on the sensor with the smallest `Timestamps(1)`, capture its `timeRef`, then pass that to all others.

For the full conversion + sync code block, see [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 5 section).

### Rule 6: Explain Expected Data Format Before Importing
**Before importing any sensor data, always tell the user the exact format/structure their data must be in.** Inspect the user's data first (load it, check variable names, sizes, types), then present a sensor-format mapping table: **Sensor | Required Fields | Expected Format | Your Data | Raw Magnitude / Scale**. Fill in what you detect and flag mismatches or required transformations (e.g., "timestamps are POSIX — will convert", "positions are 2D — will add z=0").

**HARD RULE — Raw Magnitude column is mandatory.** Run `max(rawTs)` (and span `rawTs(end)-rawTs(1)` if the first sample is small) BEFORE constructing any `scenariobuilder.*` object; write the magnitude AND Rule 5 scale factor (`/1`, `/1e3`, `/1e6`, `/1e9`) into the table. A blank magnitude cell is not acceptable — Polysync (~1.46e15 µs) silently builds million-second trajectories that only fail at `simulateScenario`. Full table template + known-dataset quick reference (Pandaset, Polysync, nuScenes, KITTI, HERE HD) in [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 6 section).

**Field name case sensitivity:** MATLAB table variable names are case-sensitive. Datasets vary (`timestamp` vs `timeStamp`, `TrackID` vs `trackID`). Always `disp(data.X.Properties.VariableNames')` before accessing any field.

**Y-axis convention (CAN/OEM data — HARD RULE):** OEM radar (`MRR_*`) and camera AEB (`IaEBA_*`) signals use **+Y = right**. MATLAB/SAE/ISO use **+Y = left**. **ALWAYS negate Y** from CAN object sources: `posY = -rawLatDist`. Without negation actors on the left appear on the right — silent, no error. Add a "Coordinate flip needed?" column to the format table when CAN data is detected.

### Rule 7: Generate and Run a MATLAB Script
**Always generate a well-documented `.m` script and run it** (via `run_matlab_file` or `evaluate_matlab_code`) — do not execute snippets piecemeal. Include `%%` section headers, comments, and a header block stating purpose, inputs, and outputs. Always set a `dataDir` variable for video outputs and clean up `rrApp` before re-launching. For the standard header template, see [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 7 section).

### Rule 8: Ask User for RoadRunner Paths
**Always ask the user for the RoadRunner installation folder (containing `AppRoadRunner.exe`) and project folder.** Auto-discovery is unreliable. If you already have the paths from earlier in this conversation, reuse without re-asking. **Single-instance guard:** never call `roadrunner(...)` unconditionally — always check first:
```matlab
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end
```
This prevents opening multiple RoadRunner windows when the script is re-run or when Part 2 follows Part 1 in the same MATLAB session.

**Multi-script pipeline pitfall:** the default pipeline shape is **single-script** — every reference template opens RoadRunner once and keeps it alive through export. If you split a pipeline across scripts to checkpoint between user-gated pauses, do NOT start each part with `clear; clc;` then `roadrunner(...)` — `clear` wipes the handle but not the GUI process, so each part spawns a new RoadRunner window. Either keep one script with inline `uiwait`/`questdlg` pauses, or `close(rrApp); clear rrApp` at the end of each part and skip the outright `clear` at the top of the next. Full patterns in [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 8 — Multi-Script Pipeline Pitfall).

**Clean-slate before export:** After the guard, always call `newScenario(rrApp)` before exporting trajectories — this ensures a previous run's actors/scenario don't accumulate. When loading a pre-built scene (`openScene`), call `newScenario(rrApp)` *after* the scene is loaded (scene stays, scenario clears). When importing an HD map (`importScene`), the import itself opens a new scene so no explicit `newScenario` is needed before import — but call it after import and before `exportToRoadRunner`.

### Rule 9: Create Your Own Helper Functions When Needed
**Do not rely on pre-existing helper functions** (e.g., `helperSmoothWaypoints`, `helperPlotActors`). Write helpers as local functions or separate `.m` files alongside the script.

### Rule 10: Always Use scenariobuilder.* APIs for Timestamped Sensor Data
**Read the matching reference file in `references/` BEFORE the first call.** The `references/*-api.md` and `workflow-*.md` files have the exact constructor signatures. Do NOT guess from memory — `scenariobuilder.ActorTrackData(timestamps, trackID, position)` has 3 positional args (no ClassID), and similar pitfalls exist for the other constructors. Open the reference once at the top of the session, then proceed.

**Whenever the user's data has timestamps + a sensor type, use the corresponding `scenariobuilder.*` object:**

| User has | Use |
|----------|-----|
| Timestamps + lat/lon/GPS/GNSS | `scenariobuilder.GPSData` |
| Timestamps + camera images/video | `scenariobuilder.CameraData` |
| Timestamps + lidar point clouds | `scenariobuilder.LidarData` |
| Timestamps + actor/object tracks | `scenariobuilder.ActorTrackData` |
| Timestamps + waypoints (local XY) | `scenariobuilder.Trajectory` |

**Whenever the user mentions these operations, use the built-in methods:**

| User says | Use |
|-----------|-----|
| Synchronize, sync, align sensors, multi-sensor alignment | `synchronize(sensorObj, referenceSensor)` |
| Crop, trim, cut, extract segment | `crop(sensorObj, startTime, endTime)` |
| Offset correction, time offset, shift timestamps | `normalizeTimestamps(sensorObj)` or `normalizeTimestamps(sensorObj, timeRef)` |
| Normalize, common time base, t=0 reference | `normalizeTimestamps(sensorObj)` |
| Convert timestamps, datetime to numeric | `convertTimestamps(sensorObj, "numeric")` |
| Visualize, plot, play, replay | `plot(sensorObj)` or `play(sensorObj)` |

**Do NOT implement these manually** (e.g., `interp1` for sync, manual indexing for crop). The `scenariobuilder.*` objects handle edge cases that manual code often gets wrong. **OpenStreetMap roads:** always use `getMapROI` for the bounding box, URL, and georeference — never manually construct OSM API URLs. Standard OSM import pattern in [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 11).

### Rule 11: Preferred APIs — Use / Don't Use

**NEVER use these functions:**

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| `roadrunnerLaneInfo` | `laneBoundarySegment` → `laneBoundaryGroup` → `getLanesInRoadRunnerHDMap` | Struct-heavy I/O, error-prone |
| `actorTracklist` | `scenariobuilder.ActorTrackData` | Legacy — no sync/crop/normalize/viz support |

**`waypointTrajectory` vs `scenariobuilder.Trajectory`:** For scenario building, always use `scenariobuilder.Trajectory`. `waypointTrajectory` is a Sensor Fusion System object for IMU simulation — NOT for scenario reconstruction.

**Preferred pipelines** (full code in [`references/execution-rules-detail.md`](references/execution-rules-detail.md)):
- **Programmatic roads:** `laneBoundarySegment` → `laneBoundaryGroup` → (optional `smoothBoundaries`) → `getLanesInRoadRunnerHDMap` → `write(rrMap, filePath)`.
- **Static objects:** Always `roadrunnerStaticObjectInfo`. Never manually build `roadrunner.hdmap.StaticObject`/`Sign` structs. See [`workflow-09-static-objects.md`](references/workflow-09-static-objects.md).
- **GPS/GNSS data:** `GPSData` → `trajectory(...)` → `smooth(...)` → `exportToDrivingScenario` or `exportToRoadRunner`. Never combine `latlon2local` + `vehicle()` + `trajectory()` on a `drivingScenario`.
- **Legacy migration:** Convert `actorTracklist`/`objectTrack` via `importFromObjectTrack()` on an `ActorTrackData`.

### Rule 12: Minimum-Change Reruns
**When fixing a defect, change ONLY what the defect requires.** Do not rebuild the scene/scenario/actors when only a color, orientation, camera mode, or a scene-flag changed. Each unnecessary rerun wastes 30-60s and risks file-lock issues. Before re-running anything, write a one-line plan: "the defect is X; the minimum change is Y." For the matrix of defect → minimum change, see [`references/execution-rules-detail.md`](references/execution-rules-detail.md) (Rule 12 section).

## Quick Reference — Key APIs

| API | Purpose |
|-----|---------|
| **Sensor Data Objects** | |
| `scenariobuilder.GPSData` | Store GPS coordinates with timestamps |
| `scenariobuilder.ActorTrackData` | Store actor track detections with timestamps |
| `scenariobuilder.CameraData` | Store camera image data with timestamps |
| `scenariobuilder.LidarData` | Store lidar point cloud data with timestamps |
| `scenariobuilder.Trajectory` | Create trajectory from timestamps + waypoints |
| `recordedSensorData` | Convenience factory to create any sensor data object |
| `drivingLogAnalyzer` | Launch the interactive app for sensor data analysis |
| **Trajectory & Actor Processing** | |
| `actorprops` | Extract actor properties and trajectories from track data |
| `importFromObjectTrack` | Import `objectTrack` array (sensor fusion) into `ActorTrackData` |
| `writeCSV` | Export trajectory to CSV (world-coord waypoints + optional orientation) |
| `selectActorRoads` | Filter roads in an actor's path from `roadprops` output |
| **Road Network & Map** | |
| `getMapROI` | Compute geographic bounding box from GPS for OSM download |
| `roadprops` | Extract road properties and geo-reference from OSM/OpenDRIVE file |
| `updateLaneSpec` | Update lane widths/markings using lane detections |
| **Lane Detection & Localization** | |
| `laneBoundaryDetector` | Detect lane boundaries. **Constructor:** `laneBoundaryDetector(Model="RVLD")` — RVLD is preferred. Fall back to `laneBoundaryDetector()` (CLRNet default) only if the RVLD constructor errors. **WRONG:** checking `which("rvldLaneDetector")` or `exist("rvldLaneDetector")` — no such function exists. RVLD is a model option on `laneBoundaryDetector`, not a separate class. Also fall back to CLRNet if tracker output has boundaries on only one side of ego (all same-sign lateral offsets). |
| `laneBoundaryTracker` | Track lane boundaries across frames |
| `laneData` | Store recorded lane boundary data with timestamps |
| `egoToWorldLaneBoundarySegments` | Convert tracked ego-frame lane boundaries → world-frame `laneBoundarySegment` |
| `laneBoundarySegment` | Store lane boundary info for a road segment (world coords) |
| `laneBoundaryGroup` | Connect multiple lane boundary segments |
| `getLanesInRoadRunnerHDMap` | Create RoadRunner HD Map from lane boundary objects |
| `localizeEgoUsingLanes` | Snap ego trajectory to lane center using lane detections |
| **Static Objects & 3D Assets** | |
| `roadrunnerStaticObjectInfo` | Convert cuboid detections to RR HD Map static objects/signs |
| `imageAssetGenerator` | Generate 3D mesh assets from a single camera image (TripoSR) |
| **Point Cloud & Elevation** | |
| `egoPointCloudExtractor` | Extract local point clouds along ego trajectory |
| `addElevation` | Add elevation to `roadrunnerHDMap`, 2D lane points, or cuboids |
| `roadSurface` | Extract high-res road surface from lidar → OpenCRG, elevation, mesh, boundaries |
| **Export** | |
| `exportToDrivingScenario` | Export trajectory + road network → `drivingScenario` |
| `exportToRoadRunner` | Export trajectory + scene directly to RoadRunner |
| `exportScenario(rrApp,file,"OpenSCENARIO XML")` | Export RR scenario to ASAM OpenSCENARIO XML |
| `exportScene(rrApp,file,"OpenDRIVE")` | Export RR scene to ASAM OpenDRIVE |
| `openScenarioExportOptions` | Configure OpenSCENARIO export (version, OpenDRIVE pairing, catalogs) |
| `openDriveExportOptions` | Configure OpenDRIVE export (version, signals, objects, CRG) |
| `exportToASAMOpenCRG` | Export `roadSurface` to ASAM OpenCRG `.crg` file |
| `enableOverlapGroupsOptions` | **Hard default `IsEnabled=false`** for every `importScene(rrApp, ..., "RoadRunner HD Map", ...)` call. Flip to `true` and re-import (asking the user) ONLY if junctions/overpasses look wrong. |

---

## Workflow 1 — Import Raw Sensor Data

Use `recordedSensorData` (factory) or construct directly: `scenariobuilder.GPSData(timestamps, lat, lon, alt)`, `scenariobuilder.ActorTrackData(timestamps, trackID, position, ...)`, `scenariobuilder.CameraData(camTimestamps, imageFileNames, ...)`, `scenariobuilder.LidarData(lidarTimestamps, pcdFiles, ...)`. For per-schema field-mapping see the **`matlab-import-driving-data`** skill. **No wrapper exists for radar or IMU** — do NOT fabricate `scenariobuilder.RadarData` / `scenariobuilder.IMUData`.

---

## Workflow 2 — Build GPS Data and Extract Trajectory

```matlab
altitude = zeros(size(latitude));  % OSM has no elevation — zero it
gpsData = scenariobuilder.GPSData(timestamps, latitude, longitude, altitude);
[roadProperties, localOrigin] = roadprops(OpenStreetMap="drive_map.osm");
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);
smooth(egoTrajectory);   % remove GPS noise
```

---

## Workflow 3 — Import Actor Track Data and Create Trajectories

```matlab
%% Step 1: Create ActorTrackData
trackData = scenariobuilder.ActorTrackData(timestamps, trackID, position, ...
    Category=category, Dimension=dimension, Orientation=orientation);

%% Step 2: Create ego trajectory (needed as reference)
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);
smooth(egoTrajectory);

%% Step 3: Extract actor properties using actorprops
actorInfo = actorprops(trackData, egoTrajectory);                  % basic
actorInfo = actorprops(trackData, egoTrajectory, AgeThreshold=20); % filter short tracks
actorInfo = actorprops(trackData, egoTrajectory, SaveAs="none");   % in-memory only
```

`actorprops` returns a table with `Age, TrackID, ClassID, EntryTime, ExitTime, Mesh, Time, Waypoints, Speed, Roll, Pitch, Yaw, IsStationary`.

### Lightweight off-ramp: world-coordinate trajectories as CSV
If the user just wants trajectories in world coords (no RoadRunner, no drivingScenario), use `actorprops` → `Trajectory` → `writeCSV(traj, FileName="ego_trajectory.csv", IncludeOrientation=true)`.

### Step 4: Ask User About Actor Track Smoothness
After generating actor trajectories, **always ask:**
> "Are the actor trajectories smooth and consistent? If tracks appear jittery or IDs are not persistent, I can run a JPDA smoother (`smootherJIPDA`) on the raw detections for better track quality."

If the user reports jittery/noisy tracks, apply offline smoothing using `trackerJPDA` + `smootherJIPDA`, then `importFromObjectTrack` into a fresh `ActorTrackData`. Full pattern in [`workflow-14-sensor-fusion-tracking.md`](references/workflow-14-sensor-fusion-tracking.md).

---

## Workflow 4 — Export Trajectories to RoadRunner (minimal inline)

This is the minimal happy-path pattern. For the full workflow (4 scene-source options including OpenStreetMap with actor-aware buffer, HERE HD Live Map, OpenDRIVE; stale-cosim-fix; advanced simulation control; side-by-side comparison video composition; OpenSCENARIO/OpenDRIVE export), load **[`workflow-04-roadrunner-export-detail.md`](references/workflow-04-roadrunner-export-detail.md)**.

```matlab
%% Step 1: Connect to RoadRunner (single-instance guard — Rule 8)
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end

%% Step 2: Get scene from OSM (most common path) — full version in reference
mapROI = getMapROI(gpsData.Latitude, gpsData.Longitude, Extent=buffer);
osmFile = fullfile(tempdir, "drive_map.osm");
websave(osmFile, mapROI.osmUrl, weboptions(ContentType="xml"));
[roadProperties, localOrigin] = roadprops(OpenStreetMap=osmFile);
egoTrajectory = trajectory(gpsData, "LocalOrigin", localOrigin);
smooth(egoTrajectory);

scenario = exportToDrivingScenario(egoTrajectory, ...
    RoadNetworkSource="OpenStreetMap", FileName=osmFile, Name="Ego");
rrMap = getRoadRunnerHDMap(scenario);

%% Step 3: Import HD Map into RoadRunner — overlap groups DISABLED by default
% (user can re-enable later if junctions/overpasses look wrong — see workflow-04)
rrhdFile = fullfile(tempdir, "roads.rrhd");
write(rrMap, rrhdFile);
copyfile(rrhdFile, fullfile(rrProjectPath, "Assets", "RoadFromOSM.rrhd"));
oOpts = enableOverlapGroupsOptions(IsEnabled=false);
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, "RoadFromOSM.rrhd", "RoadRunner HD Map", ImportOptions=iOpts);
tempSceneFile = fullfile(tempdir, "osm_roads_temp.rrscene");
saveScene(rrApp, tempSceneFile);

%% Step 4: Clean slate + export ego (with the saved scene)
newScenario(rrApp);
exportToRoadRunner(egoTrajectory, rrApp, ...
    RoadRunnerScene=tempSceneFile, Name="Ego", SetupSimulation=true);

%% Step 5: Classify vehicles (Workflow 18 — automatic when intrinsics exist)
% Builds best-crop grid, agent views + classifies, maps to AssetPath + Color.
% See references/workflow-18-vehicle-classification.md for full pipeline.
% Self-gating: skipped if no intrinsics/CameraHeight or agent can't view images.
classificationMap = containers.Map();  % populated by agent vision pass

%% Step 6: Export non-ego actors with classified asset types
for i = 1:height(actorInfo)
    actorTraj = scenariobuilder.Trajectory( ...
        actorInfo.Time{i}, actorInfo.Waypoints{i}, Name=actorInfo.TrackID(i));
    smooth(actorTraj);
    tid = char(actorInfo.TrackID(i));
    if isKey(classificationMap, tid)
        cls = classificationMap(tid);
        assetPath = cls.AssetPath;  rrColor = cls.Color;
    else
        assetPath = "Vehicles/Sedan.fbx"; rrColor = "auto";
    end
    exportToRoadRunner(actorTraj, rrApp, ...
        Name=actorInfo.TrackID(i), AssetPath=assetPath, ...
        Color=rrColor, SetupSimulation=false);
end

%% Step 6: Disable collision fail condition + simulate (see Rule 11 snippet)
%% Step 7: exportVideo + side-by-side comparison — see workflow-04 reference
```

`exportToRoadRunner` name-value args (full list in reference): `Name`, `Color`, `AssetPath`, `SetupSimulation`, `RoadRunnerScene`.

**Comparison video requirements:** `insertText` timestamp burn on BOTH halves, `questdlg` popup after `close(vw)`, defensive field-name inspect on input struct. Full pattern in [`workflow-04-roadrunner-export-detail.md`](references/workflow-04-roadrunner-export-detail.md).

---

## Workflow 5 — handled in `matlab-import-driving-data`

DLA (`drivingLogAnalyzer`) routing for "visualize / inspect / explore / analyze this dataset" → **`matlab-import-driving-data`**.

## Workflow 6 — Preprocess, Synchronize, Crop, and Correct Offset

Use `normalizeTimestamps`, `crop`, `synchronize`, `convertTimestamps` on the scenariobuilder data objects. Route complex preprocessing to `matlab-import-driving-data`.

## Workflows 7–17, Object APIs, End-to-End Examples

Workflows 7–18 are reference-only — see the **Workflow Catalog** above for triggers and `references/workflow-NN-<slug>.md`. Workflow 15 (DSD) is opt-in. Workflows 16–17 cover scene augmentation. Workflow 18 (vehicle classification) runs automatically inside Workflow 4 Step 4 when the prerequisites are met.

**Workflow 15 (DSD) actor safeguards — NEVER use `smoothTrajectory` on recorded actor waypoints.** Use `trajectory(veh, wpu, spdu)` instead. `smoothTrajectory`'s `accumulateDistance` is brittle on sparse, near-stationary, or noisy paths and throws "Unable to create smooth trajectory." Also: dedup consecutive identical (x,y) waypoints, compute per-waypoint speed via finite differences, clamp speed to `max(spdu, 0.1)` (zero stalls DSD), and flatten actor Z to 0 on OSM scenes. Full pattern in [`workflow-15-driving-scenario-designer.md`](references/workflow-15-driving-scenario-designer.md).

Object APIs (load on demand): [`trajectory-api.md`](references/trajectory-api.md), [`actortrackdata-api.md`](references/actortrackdata-api.md), [`gpsdata-api.md`](references/gpsdata-api.md). For raw-dataset wrapping → `matlab-import-driving-data`.

End-to-end examples (read one before writing scripts): [`example-roadrunner-scenario.md`](references/example-roadrunner-scenario.md) (direct RR export, Pandaset) · [`example-scenario-from-gps-and-tracks.md`](references/example-scenario-from-gps-and-tracks.md) (OSM roads + `getMapROI` + `roadprops`).

----
Copyright 2026 The MathWorks, Inc.
----
