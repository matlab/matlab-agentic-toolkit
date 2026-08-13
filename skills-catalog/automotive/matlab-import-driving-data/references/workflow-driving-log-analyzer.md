---
name: workflow-driving-log-analyzer
description: Opt-in workflow for using the drivingLogAnalyzer (DLA) app to interactively inspect recorded multi-sensor data. Loaded ONLY when the user explicitly asks for DLA / "open in DLA" / "inspect / visualize / explore / replay / analyze the recording", or when the user reports a sensor-data problem DLA is built to debug (sync drift, timestamp mismatch, overlay misalignment, missing frames, shifted timeline). NEVER use this workflow as a default verification step after wrapping data.
---

# Inspect Multi-Sensor Data with `drivingLogAnalyzer` (opt-in)

> **Parent skill:** [`SKILL.md`](../SKILL.md) (matlab-import-driving-data). **HARD RULE: this workflow is opt-in only — see Rule 0 in `SKILL.md`.** DLA is launched **only** when the user explicitly asks for it (says `DLA` / `drivingLogAnalyzer` / "open in DLA" / "inspect / visualize / explore / replay / analyze the recording") **or** reports a sensor-data problem DLA is built to debug (sync drift, timestamp mismatch, overlay misalignment, missing frames, shifted timeline).
>
> Do NOT invoke this workflow as part of a "virtualize / build scenario" handoff. For those requests, wrap with [`sensor-import-api.md`](sensor-import-api.md), save to `sandbox/<dataset>_wrapped.mat`, and hand off straight to `matlab-use-scenario-builder`. Auto-launching DLA after wrapping stalls the user (UI-app context switch) and signals a lack of confidence in the import — both are first-attempt-success failures.

DLA gives the user synchronized scrubbing, a map view, video playback, lidar 3D viewer, and actor-track overlays — all automatically driven by the `Timestamps` properties on the wrappers. Manual `VideoWriter` dashboards re-implement what DLA already does, so when DLA *is* invoked, prefer it over a custom dashboard.

## When to choose DLA over a custom video

| User intent | Choose |
|-------------|--------|
| "Visualize / inspect / explore / analyze this dataset" | DLA (this workflow) |
| "Build a single shareable mp4 of camera + radar + …" | Custom dashboard (only after the user asks for a static artifact) |
| "Validate sensor data before RoadRunner export" | Hand off to **matlab-use-scenario-builder** Rule 2 (track-overlay / BEV+Camera / raw save-video) |
| "Overlay per-frame 3D detections on the camera" | **Convert to `ActorTrackData` and use DLA's native Actors overlay** — see [`per-frame-detections-to-actortrackdata.md`](../../matlab-use-scenario-builder/references/per-frame-detections-to-actortrackdata.md) (in matlab-use-scenario-builder). Do NOT build a manual `world2img` + VideoWriter cuboid overlay. |

DLA's camera pane has a built-in **Actors** overlay (Camera tab → Overlay group → Actors) that projects `ActorTrackData` cuboids onto the image as long as the `CameraData` has Intrinsics + Mounting Location/Angles + Ego Origin Height attached. Per-frame detections without persistent IDs (CubeRCNN-style `corners3D`) should be wrapped into `ActorTrackData` with placeholder IDs (`"det_<frameIdx>_<i>"`) and added to the same DLA cell array — no separate overlay video is needed.

## End-to-end recipe (6 steps)

### Step 1 — Wrap each sensor into `scenariobuilder.*`

Use [`sensor-import-api.md`](sensor-import-api.md) for the constructor and per-schema field-mapping tables. The minimal set:

```matlab
gpsData    = scenariobuilder.GPSData(gpsTs, lat, lon, alt, Name="GPS");
cameraData = scenariobuilder.CameraData(camTs, imgList, Name="ExternalRGB");
osLidar    = scenariobuilder.LidarData(osTs, pcdList, Name="OSLidar");
% trackData (only when the dataset has track-IDed actor lists):
trackData  = scenariobuilder.ActorTrackData(trkTs, trackIDs, positions, ...
    Category=cats, Dimension=dims, Orientation=orients, Name="Tracks");
```

Sensors without a wrapper (radar, IMU) are **not** passed to DLA — keep them as raw structs and visualize separately. **Per-frame 3D detections** (no persistent IDs) DO go to DLA — convert them to `ActorTrackData` first via [`per-frame-detections-to-actortrackdata.md`](../../matlab-use-scenario-builder/references/per-frame-detections-to-actortrackdata.md) (in matlab-use-scenario-builder) and append to the cell array.

### Step 2 — Convert raw timestamps to seconds

`scenariobuilder.*` accepts numeric / `datetime` / `duration` timestamps but downstream code (`synchronize`, `trajectory`, `actorprops`) expects seconds. Convert before construction (preferred) or call `convertTimestamps(obj, "numeric")` after.

```matlab
% Example: POSIX seconds with magnitude ~1e9 — already in seconds, no conversion needed.
% Microseconds-since-epoch (~1e15) → divide by 1e6
% Nanoseconds-since-epoch (~1e18) → divide by 1e9
```

### Step 3 — Normalize to a common t=0

Pick the longest-duration sensor as the reference and align every other sensor to it.

```matlab
timeRef = normalizeTimestamps(cameraData);     % camera is usually densest
normalizeTimestamps(gpsData,    timeRef);
normalizeTimestamps(osLidar,    timeRef);
normalizeTimestamps(trackData,  timeRef);      % skip if no trackData
```

### Step 4 — Optional: crop to a common window

Skip when the user wants to scrub the full recording. Apply when one sensor starts/ends outside the others' coverage.

```matlab
[t0, t1] = deal(0, min([cameraData.Duration, gpsData.Duration, osLidar.Duration]));
crop(cameraData, t0, t1);
crop(gpsData,    t0, t1);
crop(osLidar,    t0, t1);
crop(trackData,  t0, t1);                       % skip if no trackData
```

DLA can scrub mismatched durations — cropping is a convenience, not a requirement.

### Step 5 — Optional: attach camera SensorParameters (4-field struct)

When intrinsics and mounting geometry are available in the dataset, build the full 4-field struct and attach so DLA can render actor/lane overlays. A bare `cameraIntrinsics` object is silently accepted by the property setter but DLA's overlay will refuse it at runtime. See [`sensor-import-api.md`](sensor-import-api.md) for the full struct specification.

```matlab
intrinsics = cameraIntrinsics([fx fy], [cx cy], [imgH imgW]);
cameraData.SensorParameters = struct( ...
    "MountingLocation", [1.5, 0, camHeight], ...
    "MountingAngles",   [0, 0, 0], ...
    "Intrinsics",       intrinsics, ...
    "EgoOriginHeight",  0.001);
```

### Step 6 — Launch DLA, then import wrapped sensors via the GUI

`drivingLogAnalyzer` takes no programmatic sensor inputs — it always opens an empty app, and the user (or the agent, on the user's behalf) imports the wrapped objects via the GUI (`Import → From Workspace`). The whole point of Steps 1–5 is to make sure those objects are sitting in the base workspace before the app opens.

```matlab
% Make sure the wrapped objects exist in the base workspace, then launch:
drivingLogAnalyzer;   % user clicks Import → From Workspace and selects gpsData, cameraData, osLidar, trackData
```

Once imported, the user can scrub all panes synchronously, toggle map basemaps, and inspect per-frame data.

## Launch variant

```matlab
% Empty app (the only supported form) — user imports wrapped sensors from the
% workspace, or opens files from disk via the GUI.
drivingLogAnalyzer;
```

## Default variable names when DLA imports back into the workspace

If the user uses DLA's GUI Import to bring data into the base workspace, objects are named after their `Name` property. If `Name` is empty, the defaults below are used.

| Object Type | Default Variable Name |
|---|---|
| `scenariobuilder.GPSData` | `gpsData` |
| `scenariobuilder.CameraData` | `cameraData` |
| `scenariobuilder.LidarData` | `lidarData` |
| `scenariobuilder.Trajectory` | `trajectory` |
| `scenariobuilder.ActorTrackData` | `actorTrackData` |

Always set `Name=...` at construction time so the user gets meaningful workspace variables (`extRGB`, `osLidar`) instead of generic `cameraData_1`, `cameraData_2`.

## Common pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Calling `drivingLogAnalyzer(sensors, Plot=true)` or any programmatic-input form | error: too many inputs / unsupported signature | DLA takes no programmatic args. Launch bare: `drivingLogAnalyzer;` then import via the GUI. |
| Importing radar / IMU into DLA | "Unsupported input type" in the import dialog | They have no `scenariobuilder.*` wrapper. Visualize separately. |
| Mismatched timestamp scales (camera in seconds, lidar in microseconds) | sensors play back at wildly different speeds in DLA | Convert all to seconds before construction (Step 2 above). |
| Wrapped objects not in base workspace at launch time | `Import → From Workspace` shows nothing | Run wrapping in the base workspace (or `assignin("base", ...)` if wrapping happens inside a function), then launch DLA. |
| Forgot to attach `SensorParameters` to camera | DLA shows raw image, no overlays | Build the 4-field `SensorParameters` struct and assign to `cameraData.SensorParameters`. |

----

Copyright 2026 The MathWorks, Inc.

----
