---
name: visualization-patterns
description: Full code patterns for the three camera-playback modes (track-overlay via plotActorCircles, BEV+Camera side-by-side, raw playback) including video saving, MATLAB popups, video-vs-image-sequence detection. Loaded when implementing camera visualization in scenario builder workflows.
---

# Visualization Patterns

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Rule 2 inline keeps the **decision logic** (which mode to use based on intrinsics availability) and short snippets. This file has the **full** code for video saving, popups, and frame iteration.

## When to load this reference
- You've decided which playback mode to use (per Rule 2 priority order)
- You need the full save-video-to-disk + MATLAB-popup pattern
- The user wants to keep a video of the playback (not just see it once in MATLAB)

## Property-name reminders (don't guess)
- `cameraData.Frames` — N-by-1 string array of file paths. **NOT** `Filenames`, `Files`, or `ImageFileNames`.
- `localizedTrajectory.Position` (and `egoTrajectory.Position`) — N-by-3 `[x y z]`. **NOT** `Waypoints`. (`Waypoints` is the column name in the `actorprops` *result table* — different object.)
- See [[trajectory-api]] and the `CameraData` section of [[actortrackdata-api]] before using any other property.

## HARD RULE — Validate CameraData frames after construction

```matlab
% Run immediately after constructing or rebuilding CameraData
assert(numel(unique(cameraData.Frames)) > 1, ...
    "All CameraData.Frames point to the same file — check image file list");
```

If `CameraData.Frames` is read-only and you must rebuild the object (e.g., to fix paths), **always pass `SensorParameters=`** to preserve intrinsics. Without it, Mode 1 silently degrades to Mode 3. See [[osm-flat-scene-gotchas]] Gotcha 9.

## Mode Selection — Executable Decision Tree

Copy this logic exactly when choosing which mode to use. Do NOT skip Mode 2 just because intrinsics are missing.

```matlab
% Rule 2 — visualization mode selection (copy this logic)
hasIntrinsics = ~isempty(cameraData.SensorParameters) ...
    && isstruct(cameraData.SensorParameters) ...
    && isfield(cameraData.SensorParameters, 'Intrinsics');
hasTracks = exist('trackData','var') && ~isempty(trackData.UniqueTrackIDs);
sameSampleCount = hasTracks && (cameraData.NumSamples == trackData.NumSamples);

if hasIntrinsics && hasTracks
    % MODE 1: track-overlay (plotActorCircles) — PRIMARY when intrinsics exist
elseif hasTracks && sameSampleCount
    % MODE 2: BEV + Camera (plotBEVAndCamera) — fallback when no intrinsics
else
    % MODE 3: raw camera playback — last resort
end
```

> **WRONG:** "No intrinsics → skip to raw playback."
> **RIGHT:** "No intrinsics → check if BEV+Camera is possible (tracks + matching sample counts). Only raw playback if tracks are also missing."

---

## Double-Compression Blur — Comparison Video

**NEVER** compose the final comparison video by reading the pre-saved `trackOverlay_video.mp4` through `VideoReader`. This causes double H.264 compression:
1. Original frames → encode as `trackOverlay_video.mp4` (first compression, quality loss)
2. Decode → `imresize` → re-encode as `compare.mp4` (second compression, visible blur)

**CORRECT:** Compose the overlay on-the-fly from original frames in the comparison loop:
```matlab
% Left panel: overlay from originals (single-encode, no blur)
img = imread(cameraData.Frames(frameIdx));
imgL = plotActorCircles(img, frameIdx, cameraData, trackData, intrinsics);
imgL = imresize(imgL, [targetH targetW]);
```

The standalone `trackOverlay_video.mp4` is still saved separately (for the questdlg popup / user inspection), but the comparison video must NOT read from it.

---

## MCP Timeout Note

When running video composition through MCP eval (each call ~90s timeout), reduce frame targets:
- **Single-camera video** (track-overlay, BEV+Camera, raw): `maxFrames = 150` (default below)
- **Side-by-side composition** (input vs sim, GPS compare, localization compare): `maxFrames = 100` — these do 2× the I/O per frame (two VideoReaders + resize + insertText × 2)
- **Standalone script** (user runs locally): up to 300 is fine

If a composition loop times out, reduce `maxFrames` to 50 and retry — a 50-frame video at correct FrameRate still covers the full drive duration.

---

## Mode 1: Track-overlay video (intrinsics available)

> **One UI event per video.** Do NOT call interactive `play(cameraData, PlotFcn=...)` *and* the save-video block below — the user would have to dismiss the Camera Player window AND the `questdlg` popup for the same content. Pick one: **save + popup** is the default for a non-interactive scripted run; interactive `play()` is only for ad-hoc inspection in the MATLAB desktop.

**Save the overlaid video and show a MATLAB popup to open it:**
```matlab
%% Save overlaid video (subsampled if many frames for speed)
addpath("<skill-scripts-path>");  % path to scripts/plotActorCircles.m
intrinsics = struct( ...
    fx=CameraIntrinsics.fx, fy=CameraIntrinsics.fy, ...
    cx=CameraIntrinsics.cx, cy=CameraIntrinsics.cy, ...
    camHeight=CameraHeight);

overlaidVideoFile = fullfile(dataDir, "trackOverlay_video.mp4");
maxFrames = 150;  % ~150 target: covers full drive (no truncation), fast in MCP eval
step = max(1, ceil(cameraData.NumSamples / maxFrames));
frameIndices = 1:step:cameraData.NumSamples;
effectiveFPS = numel(frameIndices) / cameraData.Duration;

vidWriter = VideoWriter(overlaidVideoFile, "MPEG-4");
vidWriter.FrameRate = round(effectiveFPS);
open(vidWriter);

% Detect video-based vs image-sequence camera
isVideoCam = contains(cameraData.Frames(1), "/frame_") || contains(cameraData.Frames(1), "\frame_");
if isVideoCam
    parts = split(cameraData.Frames(1), "/frame_");
    if isscalar(parts), parts = split(cameraData.Frames(1), "\frame_"); end
    vidReaderSrc = VideoReader(parts(1));
end

for frameIdx = frameIndices
    if isVideoCam
        vidReaderSrc.CurrentTime = cameraData.Timestamps(frameIdx) * cameraData.SampleTime;
        img = readFrame(vidReaderSrc);
    else
        img = imread(cameraData.Frames(frameIdx));
    end
    imgOut = plotActorCircles(img, frameIdx, cameraData, trackData, intrinsics);
    writeVideo(vidWriter, imgOut);
end
close(vidWriter);

%% MATLAB popup — ask user to open the video (guard: only if file has content)
if isfile(overlaidVideoFile) && dir(overlaidVideoFile).bytes > 0
    answer = questdlg(sprintf("Track-overlaid video saved to:\n%s\n\nWould you like to open it?", ...
        overlaidVideoFile), "Overlaid Video Saved", "Yes", "No", "Yes");
    if strcmp(answer, "Yes")
        openFile(overlaidVideoFile);  % cross-platform; requires scripts/openFile.m on path
    end
end
```

## Mode 2: BEV + Camera side-by-side (no intrinsics, but tracks exist)

`plotBEVAndCamera` requires camera and track data to have the **same number of samples** (i.e., fully synchronized). If the sample counts differ after `synchronize()`, inform the user:
> "The camera and actor track data have different sample rates (camera: N samples, tracks: M samples). Please use the **Crop & Sync** tab in the **Driving Log Analyzer** app to apply offset correction and resample to matching rates, then re-import the data."

> **One UI event per video.** Do NOT call interactive `plotBEVAndCamera(trackData, cameraData)` *and* the save-video block below. Use interactive `plotBEVAndCamera(...)` only for ad-hoc desktop inspection; for a scripted run use the save block below (which produces the same composition).

**Save the BEV + Camera visualization as a video with MATLAB popup:**
```matlab
%% Save BEV + Camera video (subsampled if many frames for speed)
addpath("<skill-scripts-path>");  % path to scripts/plotBEVAndCamera.m
bevVideoFile = fullfile(dataDir, "bevCamera_video.mp4");
maxFrames = 150;  % ~150 target: covers full drive (no truncation), fast in MCP eval
step = max(1, ceil(cameraData.NumSamples / maxFrames));
frameIndices = 1:step:cameraData.NumSamples;
effectiveFPS = numel(frameIndices) / cameraData.Duration;

vidWriter = VideoWriter(bevVideoFile, "MPEG-4");
vidWriter.FrameRate = round(effectiveFPS);
open(vidWriter);
f = figure(Position=[100 100 1400 550], Visible="off");
tl = tiledlayout(f, 1, 2, TileSpacing="compact", Padding="compact");
camAx = nexttile(tl);
bevAx = nexttile(tl);
bep = birdsEyePlot(Parent=bevAx, XLimits=[0 80], YLimits=[-30 30]);
trPlotter = trackPlotter(bep, LabelOffset=[1 0], Marker='^', ...
    MarkerEdgeColor='blue', MarkerFaceColor='cyan', DisplayName='Non-Ego Actors');
olPlotter = outlinePlotter(bep);
caPlotter = coverageAreaPlotter(bep, FaceColor=[0.6350 0.0780 0.1840]);
tsText = text(bevAx, 75, 12, "t=0.00s", FontSize=12, Color='b');

% Detect video-based vs image-sequence camera
isVideoCam = contains(cameraData.Frames(1), "/frame_") || contains(cameraData.Frames(1), "\frame_");
if isVideoCam
    parts = split(cameraData.Frames(1), "/frame_");
    if isscalar(parts), parts = split(cameraData.Frames(1), "\frame_"); end
    vidReaderSrc = VideoReader(parts(1));
end

for j = frameIndices
    if isVideoCam
        vidReaderSrc.CurrentTime = cameraData.Timestamps(j);
        img = readFrame(vidReaderSrc);
    else
        img = imread(cameraData.Frames(j));
    end
    camTs = cameraData.Timestamps(j);
    image(img, Parent=camAx); axis(camAx, "off");
    title(camAx, sprintf("Camera — t=%.2fs  (Frame %d/%d)", camTs, j, cameraData.NumSamples));
    positions = trackData.Position{j};
    trackIDs = trackData.TrackID{j};
    clearData(trPlotter);
    plotOutline(olPlotter, [0 0], 0, 4.7, 1.8, OriginOffset=[-1.35 0], Color=[0 0.447 0.741]);
    plotCoverageArea(caPlotter, [1 0], 60, 0, 60);
    if ~isempty(positions)
        plotTrack(trPlotter, positions(:,1:2), string(trackIDs));
    end
    tsText.String = sprintf("t=%.2fs", camTs);
    drawnow;
    frame = getframe(f);
    writeVideo(vidWriter, frame.cdata);
end
close(vidWriter); close(f);

if isfile(bevVideoFile) && dir(bevVideoFile).bytes > 0
    answer = questdlg(sprintf("BEV + Camera video saved to:\n%s\n\nWould you like to open it?", ...
        bevVideoFile), "BEV Video Saved", "Yes", "No", "Yes");
    if strcmp(answer, "Yes")
        openFile(bevVideoFile);
    end
end
```

## Mode 3: Raw playback (no tracks, no intrinsics)

> **One UI event per video.** Do NOT call interactive `play(cameraData)` *and* the save block below. Use `play(cameraData)` only for ad-hoc desktop inspection; for a scripted run use the save block below.

**Save raw camera video with MATLAB popup:**
```matlab
%% Save raw camera video (subsampled if many frames for speed)
rawVideoFile = fullfile(dataDir, "rawCamera_video.mp4");
maxFrames = 150;  % ~150 target: covers full drive (no truncation), fast in MCP eval
step = max(1, ceil(cameraData.NumSamples / maxFrames));
frameIndices = 1:step:cameraData.NumSamples;
effectiveFPS = numel(frameIndices) / cameraData.Duration;

vidWriter = VideoWriter(rawVideoFile, "MPEG-4");
vidWriter.FrameRate = round(effectiveFPS);
open(vidWriter);

% Detect video-based vs image-sequence camera
isVideoCam = contains(cameraData.Frames(1), "/frame_") || contains(cameraData.Frames(1), "\frame_");
if isVideoCam
    parts = split(cameraData.Frames(1), "/frame_");
    if isscalar(parts), parts = split(cameraData.Frames(1), "\frame_"); end
    vidReaderSrc = VideoReader(parts(1));
end

for j = frameIndices
    if isVideoCam
        vidReaderSrc.CurrentTime = cameraData.Timestamps(j);
        img = readFrame(vidReaderSrc);
    else
        img = imread(cameraData.Frames(j));
    end
    writeVideo(vidWriter, img);
end
close(vidWriter);

if isfile(rawVideoFile) && dir(rawVideoFile).bytes > 0
    answer = questdlg(sprintf("Camera video saved to:\n%s\n\nWould you like to open it?", ...
        rawVideoFile), "Camera Video Saved", "Yes", "No", "Yes");
    if strcmp(answer, "Yes")
        openFile(rawVideoFile);
    end
end
```

## `plotActorCircles` signature
```matlab
img = plotActorCircles(img, frameIdx, camObj, trackData, intrinsics)
```
- `img` — H×W×3 uint8 image (overwritten with overlays in the return value)
- `frameIdx` — index into `camObj.Timestamps`
- `camObj` — CameraData object (uses `.Timestamps` to find matching track frame)
- `trackData` — ActorTrackData object
- `intrinsics` — struct with fields `fx`, `fy`, `cx`, `cy`, `camHeight` (camera mounting height in meters)

The function projects ego-relative actor positions through a pinhole camera model (ego→camera coordinate transform: X-fwd,Y-left,Z-up → X-right,Y-down,Z-forward) and draws colored circles with track ID labels.

----

Copyright 2026 The MathWorks, Inc.

----
