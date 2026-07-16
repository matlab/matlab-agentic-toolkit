---
name: workflow-08-lane-localization
description: Snap ego trajectory onto correct lane center using lane boundary detections — simplified path with monoCamera detect, advanced manual pixel-filtering path, GPS-vs-localized verification in RoadRunner, and final scenario generation in the same session. Loaded when user has camera intrinsics and needs lane-level positioning.
---

# Workflow 8 — Localize Ego Trajectory on Map Using Lane Detections

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when GPS accuracy is insufficient for lane-level positioning AND camera intrinsics are available.
>
> **Related references:** [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) for the upstream OSM/HD-map setup. The localization step replaces direct GPS export.
>
> **Official MathWorks docs:**
> - Lane extraction: <https://www.mathworks.com/help/driving/ug/extract-lane-information-from-recorded-camera-data-for-scene-generation.html>
> - `localizeEgoUsingLanes` reference: <https://www.mathworks.com/help/driving/ref/localizeegousinglanes.html>

When GPS accuracy is insufficient for lane-level positioning, use `localizeEgoUsingLanes` to snap the ego trajectory onto the correct lane center using lane boundary detections.

## IMPORTANT — Localization is OPTIONAL (ask before running)

**Do NOT auto-run this workflow.** Before starting lane detection, ask the user:
> "Do you want to apply lane localization (snaps the trajectory to the lane center using camera detections), or use the GPS trajectory directly?"

**Skip the question and localize by default only when:**
- User explicitly says "localize", "snap to lane", "lane-level accuracy"
- User says "build scenario" with no pre-built scene (OSM-only — GPS typically needs help)

**Always ask when:**
- Dataset has a pre-built scene (HERE HD, vendor `.rrscene`) — GPS may already be accurate enough
- User chose "Corrected GPS" — implies they trust the correction
- Dataset explicitly has RTK or post-processed GNSS

**Why:** Choosing Corrected GPS implies the user trusts it. Running localization on top without asking is wasted time and can even degrade the trajectory if the map's lane geometry doesn't perfectly match.

## Canonical signature (R2026a)
```matlab
% Four positional arguments — order matters
[localizedTrajectory, info] = localizeEgoUsingLanes( ...
    trajectory, rrMap, lanedata, startLaneIndex);

% Optional: ApproxLaneWidth (default 3.5 m)
[localizedTrajectory, info] = localizeEgoUsingLanes( ...
    trajectory, rrMap, lanedata, startLaneIndex, ApproxLaneWidth=3.5);
```
- `trajectory` — `scenariobuilder.Trajectory` (ego from GPS)
- `rrMap` — `roadrunnerHDMap` object (preferred) **or** `rrApp` (`roadrunner` object)
- `lanedata` — `laneData` object built **from tracked** lane boundaries (see Step 3 below)
- `startLaneIndex` — positive integer (left-to-right, excluding shoulders). Must be scalar. **Always ask the user** — `egoLaneIndex` is detection-only and routinely undercounts on multi-lane roads.

## DO NOT use `egoToWorldLaneBoundarySegments` for localization
`egoToWorldLaneBoundarySegments` converts tracked boundaries to world-coordinate segments for **static lane-geometry reconstruction** (feeds into `laneBoundaryGroup` for HD-map building). It is **not** part of the ego-localization path. Pass the `laneData` object directly into `localizeEgoUsingLanes` — never go through `egoToWorldLaneBoundarySegments` first.

## Prerequisites
- A `scenariobuilder.Trajectory` object (from GPS)
- A `roadrunnerHDMap` object or connected `rrApp` with a loaded scene
- A `laneData` object with tracked lane boundaries (from lane detection + `laneBoundaryTracker`)
- The starting lane index of the ego vehicle (left-to-right numbering, excluding shoulders)
- **Scene must have been imported with `enableOverlapGroupsOptions(IsEnabled=false)`** — the upstream `importScene(rrApp, ..., "RoadRunner HD Map", ImportOptions=iOpts)` in workflow-04 MUST pass this option block. If you launch this workflow with a freshly built scene, build it with overlap groups disabled. The default `IsEnabled=true` produces false-positive overlap groups at junctions/overpasses on OSM-derived maps — flip to `true` only if the user inspects the imported scene and reports junction/overpass artifacts.
- **Variable-lane roads are handled automatically** — `localizeEgoUsingLanes` interpolates through frames where the map has fewer lanes than `startLaneIdx`. No pre-emptive crop/split logic needed.

## Map lane-count gate (silent — run BEFORE `localizeEgoUsingLanes`)

`localizeEgoUsingLanes` needs `startLaneIdx ≤ availableLanes` at every frame along the route. **This gate is silent by default** — do not generate plots, tables, or printed summaries for the user. It runs internally and only surfaces a question if the map actually has a coverage problem or the user's chosen `startLaneIdx` exceeds the map's minimum lane count. Generating a `lane_count_vs_frame.png` and a `LaneCount/Frames/PercentOfRoute` summary up-front clutters the chat and biases the user's answer to the next gate (which lane is the ego in?).

**Note:** `roadrunnerHDMap` does not expose `findLanes`. Use a proximity loop on `rrMap.Lanes(li).Geometry` instead.

```matlab
%% Silent lane-count probe — used internally, NOT shown to the user up-front
ego2D  = egoTrajectory.Position(:,1:2);
radius = 5;
laneXY = arrayfun(@(L) L.Geometry(:,1:2), rrMap.Lanes, UniformOutput=false);
laneCount = zeros(size(ego2D,1),1);
for k = 1:size(ego2D,1)
    p = ego2D(k,:);
    cnt = 0;
    for li = 1:numel(laneXY)
        d = vecnorm(laneXY{li} - p, 2, 2);
        if any(d < radius), cnt = cnt + 1; end
    end
    laneCount(k) = cnt;
end
maxValidStartLaneIdx = min(laneCount);   % keep — used after the user answers
```

**No variable-lane gate question.** After the user provides `startLaneIdx`, just call `localizeEgoUsingLanes` — it interpolates through frames where the map has fewer lanes. Do NOT pre-emptively ask "the map narrows to K lanes, want to crop or split?" The user already chose their lane from the dashcam; the localizer handles it.

**Only surface a problem if:**
- `min(laneCount) < 1` → the map has zero lane coverage for some frames. Tell the user: *"OpenStreetMap doesn't have road geometry for some frames — localization may not work. Want to fall back to raw GPS?"*
- `localizeEgoUsingLanes` **actually throws an error** — then report the error, include lane-count diagnostics, and offer the user: (a) crop/split, (b) try a different `startLaneIdx`, or (c) skip localization and use GPS directly.

**NEVER silently skip localization.** If it fails, always tell the user what happened and ask how to proceed. Proceeding with raw GPS without informing the user is a failure mode.

The crop recipe below is kept for reference in case the localizer does error on a specific dataset:

### Crop recipe — `Trajectory` + `laneData` to a frame window

`scenariobuilder.Trajectory` has a `crop(traj, tStart, tEnd)` method, but **`laneData` does not**. Rebuild it.

```matlab
% Inputs from the gate above:
%   cropStartFrame, cropEndFrame  — frame indices into trackedLanes
tStart = trackedLanes.TimeStamp(cropStartFrame);     % singular .TimeStamp
tEnd   = trackedLanes.TimeStamp(cropEndFrame);

% Crop ego (Trajectory has crop)
egoTrajectory = crop(egoTrajectory, tStart, tEnd);

% Rebuild laneData on the cropped window (laneData has NO crop method)
trackedLanes = laneData( ...
    trackedLanes.TimeStamp(cropStartFrame:cropEndFrame), ...
    trackedLanes.LaneBoundaryData(cropStartFrame:cropEndFrame), ...
    TrackIDs=trackedLanes.TrackIDs(cropStartFrame:cropEndFrame));

% Re-zero both timelines so they share t=0 again
normalizeTimestamps(egoTrajectory); egoTrajectory.TimeOrigin = 0;
trackedLanes.updateTime(trackedLanes.TimeStamp - tStart);

% Crop the camera arrays the same way before composing the compare video.
```

**Why this gate matters:** without it, the agent runs detect → track → laneData → localize, the localizer crashes, the user has no diagnostic, and you waste a 5-15 min lane-detection pass per retry. The probe takes <1 s.

## Recommended path (mirrors the official MathWorks example)
Follow the same five stages as the doc *"Extract Lane Information from Recorded Camera Data for Scene Generation"*: **build `monoCamera`** sensor → **detect** in image coords → **`imageToVehicle`** to get vehicle-coord points → **`findParabolicLaneBoundaries`** to fit parabolas → **`laneBoundaryTracker`** to track over time, then build `laneData` and call `localizeEgoUsingLanes`.

> **HARD RULE — `imageToVehicle` REQUIRES a `monoCamera` object, NOT a bare `cameraIntrinsics`.** Passing `cameraIntrinsics` (the object you build from `fx, fy, cx, cy, imageSize`) directly into `imageToVehicle` is the most common failure mode in this workflow. `imageToVehicle` needs the camera-to-vehicle geometry (mounting Height + Pitch + Yaw + Roll) that lives on `monoCamera`, not on the bare intrinsics. Build `cameraParams = monoCamera(intrinsics, height, Pitch=..., Yaw=..., Roll=...)` BEFORE Step 1 and reuse it everywhere `imageToVehicle` is called. Same `monoCamera` is what you assemble into the 4-field `cameraData.SensorParameters` struct (`MountingLocation` / `MountingAngles` / `Intrinsics` / `EgoOriginHeight`) for DLA-style overlays — see [`sensor-import-api`](../../matlab-driving-data-importer/references/sensor-import-api.md). Skipping `imageToVehicle` + `findParabolicLaneBoundaries` and trying to feed pixel coordinates straight into `laneBoundaryTracker` ALSO fails — the tracker expects `parabolicLaneBoundary` rows in vehicle coordinates.

```matlab
%% Step 0 — Build the monoCamera sensor (MUST come before Step 2 imageToVehicle)
% Use the dataset's calibration: intrinsics from K (and D if available),
% mounting Height from CameraHeight (m, ground → camera optical center),
% mounting angles from the calibration's R/Euler. Do NOT fabricate.
intrinsics  = cameraIntrinsics([fx fy], [cx cy], [imgH imgW]);  % from dataset
camHeight   = CameraHeight;                                      % m, from dataset
cameraParams = monoCamera(intrinsics, camHeight, ...
    Pitch=pitchDeg, Yaw=yawDeg, Roll=rollDeg);                  % from dataset, deg
% If only Height is in the dataset, default Pitch/Yaw/Roll to 0 and tell
% the user — same disclosure rule as in sensor-import-api.md.

%% Step 1 — Detect lane boundary points in image coordinates
% RVLD first (preferred). Two fallback conditions trigger CLRNet:
%   (a) RVLD constructor throws — model not installed.
%   (b) After tracking, all LaneBoundary lateral offsets share one sign —
%       i.e., RVLD only saw boundaries on ONE side of the ego. CLRNet
%       typically returns boundaries on both sides on the same data.
%       (Detected post-tracking — see Step 4 sanity check below.)
try
    detector = laneBoundaryDetector(Model="RVLD");
catch ME
    warning("RVLD not installed (%s). Falling back to CLRNet.", ME.identifier);
    detector = laneBoundaryDetector();   % CLRNet default
end
laneBoundaryPoints = detect(detector, cameraData, ...
    DetectionThreshold=0.3, OverlapThreshold=0.1, ShowProgress=true);
% laneBoundaryPoints: cell-of-cell — outer = frames, inner = Nx2 pixel coords per boundary

%% Step 2 — Convert image → vehicle coordinates (imageToVehicle)
% MANDATORY: filter out-of-bounds pixels first. RVLD/CLRNet sometimes
% produce points at or above the horizon (y <= cy) and outside [1..W, 1..H].
% imageToVehicle errors with "Locations specified in imagePoints must be
% inside image bounds" if you pass these through unfiltered.
imageSize = cameraParams.Intrinsics.ImageSize;   % [H W]
H = imageSize(1); W = imageSize(2);
cy = cameraParams.Intrinsics.PrincipalPoint(2);
laneBoundaryPointsVehicle = cell(numel(laneBoundaryPoints), 1);
for i = 1:numel(laneBoundaryPoints)
    cellIn  = laneBoundaryPoints{i};
    cellOut = cell(1, numel(cellIn));
    for j = 1:numel(cellIn)
        pts = cellIn{j};
        if isempty(pts), cellOut{j} = []; continue; end
        validMask = pts(:,2) > (cy + 1) & ...
                    pts(:,1) >= 1 & pts(:,1) <= W & ...
                    pts(:,2) >= 1 & pts(:,2) <= H;
        validPts = pts(validMask, :);
        if size(validPts, 1) < 5
            cellOut{j} = [];
        else
            cellOut{j} = imageToVehicle(cameraParams, validPts);
        end
    end
    laneBoundaryPointsVehicle{i, 1} = cellOut;
end

%% Step 3 — Fit parabolic boundaries (findParabolicLaneBoundaries)
% Do NOT pass ValidateBoundaryFcn=@(b) length(b.Strength)>5 && b.Strength>0.1 —
% the validate fcn is called by RANSAC on raw model parameters (a numeric
% vector), so referencing `b.Strength` errors with "Dot indexing is not
% supported for variables of type double". Defaults are sufficient.
numFrames = numel(laneBoundaryPointsVehicle);
laneBoundaries = cell(numFrames, 1);
for i = 1:numFrames
    pts = laneBoundaryPointsVehicle{i};
    pts = pts(~cellfun(@isempty, pts));
    if isempty(pts), laneBoundaries{i,1} = []; continue; end
    boundaries = cellfun(@(x) findParabolicLaneBoundaries(x, 0.3, MaxNumBoundaries=1), ...
        pts, UniformOutput=false);
    idices = cellfun(@(x) ~isempty(x), boundaries);
    boundaries = cellfun(@(x) x(1), boundaries(idices));
    laneBoundaries{i, 1} = boundaries;
end

%% Step 4 — Track lane boundaries (laneBoundaryTracker)
% UseSmoother=true gives better results but can fail with
% "Expected StateCovariance to be positive-semidefinite" on long sequences
% or sparse detections. Fall back to UseSmoother=false if it errors.
lbTracker = laneBoundaryTracker( ...
    LaneBoundaryModel="Parabolic", ...
    DetectionProbability=0.8);
try
    trackedLanesRaw = lbTracker(laneBoundaries, cameraData.Timestamps, ...
        ShowProgress=true, UseSmoother=true);
catch ME
    if contains(ME.message, "positive-semidefinite") || contains(ME.message, "StateCovariance")
        warning("Smoother failed (%s). Retrying without smoother.", ME.message);
        lbTracker = laneBoundaryTracker(LaneBoundaryModel="Parabolic", DetectionProbability=0.8);
        trackedLanesRaw = lbTracker(laneBoundaries, cameraData.Timestamps, ...
            ShowProgress=true, UseSmoother=false);
    else
        rethrow(ME);
    end
end
% trackedLanesRaw is a cell-of-cell: outer = frames, inner = tracks. Convert
% to a laneData object (sorted left-to-right by lateral offset) before localizing.
nF = numel(cameraData.Timestamps);
lbDataSorted = cell(nF, 1);
trackIDsStr  = cell(nF, 1);
for i = 1:nF
    frameTracks = trackedLanesRaw{i};
    bounds = []; ids = [];
    for j = 1:numel(frameTracks)
        bounds = [bounds; frameTracks{j}.LaneBoundary]; %#ok<AGROW>
        ids    = [ids;    frameTracks{j}.TrackID];      %#ok<AGROW>
    end
    if ~isempty(bounds)
        offsets = arrayfun(@(b) b.Parameters(3), bounds);
        [~, sortIdx] = sort(offsets, 'descend');  % left -> right
        lbDataSorted{i} = bounds(sortIdx)';
        trackIDsStr{i}  = string(ids(sortIdx))';
    else
        lbDataSorted{i} = bounds';
        trackIDsStr{i}  = string([])';
    end
end
trackedLanes = laneData(cameraData.Timestamps, lbDataSorted, TrackIDs=trackIDsStr);

%% Step 4b — Single-side sanity check (RVLD → CLRNet fallback)
% localizeEgoUsingLanes needs the ego BRACKETED — boundaries on both sides.
% RVLD on some datasets returns same-sign offsets only (typically all
% positive). The localizer would then error with "ego lane detections
% missing for the frame N" on every frame. CLRNet usually catches the
% other side; re-run detection with CLRNet if RVLD output is single-sided.
allOffsets = [];
for i = 1:numel(lbDataSorted)
    if ~isempty(lbDataSorted{i})
        allOffsets = [allOffsets; arrayfun(@(b) b.Parameters(3), lbDataSorted{i}(:))]; %#ok<AGROW>
    end
end
if ~isempty(allOffsets) && (all(allOffsets >= 0) || all(allOffsets <= 0)) ...
        && detector.Model == "RVLD"
    warning("RVLD detected boundaries on a single side of ego only. " + ...
            "Re-running with CLRNet.");
    detector = laneBoundaryDetector();   % CLRNet default
    laneBoundaryPoints = detect(detector, cameraData, ...
        DetectionThreshold=0.3, OverlapThreshold=0.1, ShowProgress=true);
    % Re-run Steps 2–4 on the new detections (omitted here — see canonical script).
end

%% Step 5 — Get start lane index from the user (DO NOT auto-pick)
% mode(egoLaneIndex(trackedLanes)) is detection-only — it counts the
% boundaries the tracker actually held onto, not the lanes on the road.
% On any road wider than 2 lanes (or where outer boundaries are weakly
% detected), it systematically undercounts and the localizer snaps the
% ego into a parallel lane. Always ask the user.
laneIdxPerFrame = egoLaneIndex(trackedLanes);
validIdx = laneIdxPerFrame(~isnan(laneIdxPerFrame));
if isempty(validIdx)
    hintIdx = NaN; hintNum = NaN;
else
    [~, numLanesPerFrame] = egoLaneIndex(trackedLanes);
    hintIdx = mode(validIdx);
    hintNum = max(numLanesPerFrame, [], "omitnan");
    fprintf(['Detection-based hint: ego in lane %d of %d tracked boundaries.\n' ...
             'NOTE: this counts only what the camera tracked, not the actual\n' ...
             'road. Outer boundaries are often missed on >2-lane roads.\n'], ...
            hintIdx, hintNum);
end
% startLaneIdx must come from the user — they know how many lanes the
% road actually has and which one the ego is in. The agent must ASK in chat
% (use AskUserQuestion or the equivalent), not infer.
startLaneIdx = <ASK USER — leftmost lane = 1, excluding shoulders>;

%% Step 6 — Localize. Pass laneData directly — NOT egoToWorldLaneBoundarySegments output.
[localizedTrajectory, locInfo] = localizeEgoUsingLanes( ...
    egoTrajectory, rrMap, trackedLanes, startLaneIdx);
```

**Why ask instead of auto-pick:** `egoLaneIndex` counts tracked boundaries in the camera frame and adds 1 — it has no view of the rrMap or how many lanes the road actually has. When the tracker only holds the two boundaries immediately bracketing the ego (typical on 3+ lane roads with weak outer markings), `egoLaneIndex` returns 1 every frame and `mode(...)` cheerfully agrees, even though the ego may be in lane 3 of a 4-lane road. The localizer then snaps the trajectory two lanes to the left and the user sees a multi-lane offset in the compare video. The fastest, most reliable fix is just to ask — the user already knows the answer from the dashcam.

**IMPORTANT — Common pitfalls:**
- **`imageToVehicle` REQUIRES a `monoCamera` object, NOT a bare `cameraIntrinsics`.** This is the most common failure mode. Build `cameraParams = monoCamera(intrinsics, camHeight, Pitch=..., Yaw=..., Roll=...)` and pass `cameraParams` to `imageToVehicle`. Passing the bare `cameraIntrinsics` errors with `Invalid argument at position 1` because `imageToVehicle` needs the camera→vehicle geometry (mounting Height + angles) that only `monoCamera` carries.
- **Do NOT skip `imageToVehicle` + `findParabolicLaneBoundaries`** — pass detection pixel coords through BOTH before tracking. The tracker expects `parabolicLaneBoundary` rows in vehicle coordinates. Skipping either step (e.g., feeding raw pixel cells directly into `laneBoundaryTracker`) errors out at the first frame.
- **Do filter out-of-bounds pixels** before `imageToVehicle` (mask shown in Step 2). RVLD/CLRNet near-horizon points routinely fall above `cy` and outside `[1..W,1..H]`; the function errors on those.
- **Do NOT pass a custom `ValidateBoundaryFcn` that touches `b.Strength`** — RANSAC calls it with raw model parameters (a numeric vector), not a struct. Defaults work.
- **Do NOT call `egoToWorldLaneBoundarySegments`** — that function is for *static lane-geometry reconstruction* (feeds `laneBoundaryGroup`), not ego localization. Localization takes the `laneData` object directly.
- **RVLD first, CLRNet as fallback (two trigger conditions):** Always try `laneBoundaryDetector(Model="RVLD")` first — RVLD is the preferred model for this workflow. Fall back to `laneBoundaryDetector()` (CLRNet default) when **either** (a) the RVLD constructor throws (not installed) **or** (b) after tracking, all `LaneBoundary` lateral offsets share the same sign — meaning RVLD only saw boundaries on ONE side of ego, and `localizeEgoUsingLanes` would error with *"ego lane detections missing"* on every frame. CLRNet typically returns boundaries on both sides on the same data. Do NOT default to CLRNet for performance reasons; only swap on (a) or (b).
- **RVLD availability — WRONG way to check:** Do NOT use `which("rvldLaneDetector")` or `exist("rvldLaneDetector")` — no such standalone function exists. RVLD is a **model option** on `laneBoundaryDetector`, not a separate class. The ONLY correct check is the try-catch on `laneBoundaryDetector(Model="RVLD")`. If you grep for function names and find nothing, that does NOT mean RVLD is unavailable.
- **Flat OSM scene — flatten ego Z + preserve Orientation after localization:** `localizedTrajectory.Position(:,3)` carries GPS altitude (~40m+). On flat OSM scenes (Z=0 roads), you MUST zero the ego Z before export — otherwise ego floats above the road. When rebuilding the trajectory with `Z=0`, always pass `Orientation=localizedTrajectory.Orientation` to preserve the lane-aligned heading from localization. Without it, heading is re-derived from waypoint deltas (less accurate at low speed/curves).
- **Python-SPKG install errors (RVLD is Python-backed):** if the RVLD constructor or first run fails with a `proxyError`, `SSL: CERTIFICATE_VERIFY_FAILED`, `SSLConnectionError`, or `ReadTimeoutError: HTTPSConnectionPool(host='download.pytorch.org', ...)`, this is a known customer-network issue, not a MATLAB bug. Load [`python-spkg-install-troubleshooting.md`](python-spkg-install-troubleshooting.md) for the symptom→fix matrix (proxy / SSL → set `http_proxy`+`https_proxy`; PyTorch read timeout → reinstall the SPKG).
- **Always ASK the user for `startLaneIdx`** (1 = leftmost lane, excluding shoulders). Never auto-pick. `egoLaneIndex` is detection-only and undercounts on 3+ lane roads, so `mode(egoLaneIndex(...))` is unreliable as a startLaneIdx source. Compute it as a hint to show the user, but the value passed to `localizeEgoUsingLanes` MUST come from the user.
- **`localizeEgoUsingLanes` accepts `roadrunnerHDMap` or `roadrunner` app** — NOT an OSM file path. **Do NOT call `getRoadRunnerHDMap(rrApp)`** — that function does not exist on the `roadrunner` class (it's a `drivingScenario` method only) and errors with *"Undefined function for input arguments of type 'roadrunner'"*. Use one of: (a) `rrMap = roadrunnerHDMap(); read(rrMap, rrhdFile);` then pass `rrMap`, or (b) pass `rrApp` directly as the second argument to `localizeEgoUsingLanes`. Both paths are documented in `help localizeEgoUsingLanes`. For a pre-built `.rrscene` already opened in `rrApp`, use `exportScene(rrApp, file, "RoadRunner HD Map")` to extract the rrhd, then path (a) — see [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) Option B.1.
- **Warnings about missing frames are normal** — the function interpolates through gaps.
- **HD Map import option is mandatory** — every `importScene(rrApp, ..., "RoadRunner HD Map", ...)` call in this workflow's upstream MUST pass `ImportOptions=iOpts` built with `enableOverlapGroupsOptions(IsEnabled=false)`. Forgetting this is a recurring miss; treat it as a hard default.
- **`laneBoundaryTracker` returns cell-of-structs, NOT a struct array.** Each element is a cell: `tracked = trackerObj(boundaries, ts)` → `tracked{k}` is a struct with `.TrackID`, `.UpdateTime`, `.LaneBoundary`. Extract with curly braces: `tracked{k}.LaneBoundary`. Using parentheses `tracked(k).LaneBoundary` errors because `tracked` is a cell, not a struct array.
- **Empty frames need typed empty, not `[]`.** Passing `[]` (class double) to `laneBoundaryTracker` errors with *"Expected input to be one of these types: cell, parabolicLaneBoundary"*. Use `parabolicLaneBoundary.empty(1,0)` for frames with no detections:
  ```matlab
  if isempty(allBoundaries{i})
      tracked = trackerObj(parabolicLaneBoundary.empty(1,0), ts(i));
  else
      tracked = trackerObj(allBoundaries{i}, ts(i));
  end
  ```
- **Do NOT name your boundary cell array `laneData`** — this shadows the `laneData` class. `localizeEgoUsingLanes` requires a `laneData` *object* (constructed via `laneData(timestamps, lbCell)`), not a raw cell. If you shadow the class, `clear laneData` is needed before you can construct the object. Use `lbCell` or `laneBoundsPerFrame` for the intermediate cell array.
- **`localizeEgoUsingLanes` passes Z through unchanged** — it localizes XY (snaps to lane center) but copies `Position(:,3)` from the input trajectory verbatim. On flat OSM scenes, GPS altitude (~30–50 m) survives into the localized output. Always zero Z after localization for flat scenes (and preserve `Orientation` — see gotcha above).

## Advanced Path (Manual pixel filtering — use when simplified path fails)
### Step 1: Run RVLD lane detector on camera data
```matlab
detector = laneBoundaryDetector(Model="RVLD");
roi = round(cameraIntrinsics.cy) + 50;  % Below horizon

[lanePoints, ~] = detect(detector, cameraData, ...
    ROI=roi, DetectionThreshold=0.3, OverlapThreshold=0.1, ...
    MaxBoundaries=6, ShowProgress=true, ExecutionEnvironment="cpu");

% Convert to vehicle coords (filter out-of-bounds points)
numFrames = numel(lanePoints);
laneBoundaries = cell(numFrames, 1);
for i = 1:numFrames
    frameBounds = [];
    for j = 1:numel(lanePoints{i})
        pts = lanePoints{i}{j};
        if isempty(pts), continue; end
        validMask = pts(:,2) > (cameraIntrinsics.cy + 1) & ...
                    pts(:,1) >= 1 & pts(:,1) <= imageSize(2) & ...
                    pts(:,2) >= 1 & pts(:,2) <= imageSize(1);
        validPts = pts(validMask, :);
        if size(validPts, 1) < 5, continue; end
        vehPts = imageToVehicle(cameraParams, validPts);   % monoCamera, NOT cameraIntrinsics
        bounds = findParabolicLaneBoundaries(vehPts, 0.3, MaxNumBoundaries=1);
        if ~isempty(bounds)
            frameBounds = [frameBounds; bounds];
        end
    end
    laneBoundaries{i} = frameBounds;
end
```

### Step 2: Track lane boundaries
```matlab
tracker = laneBoundaryTracker(LaneBoundaryModel="Parabolic");
trackedLanes = tracker(laneBoundaries, timestamps, ShowProgress=true, UseSmoother=true);

% Convert to laneData (sorted left-to-right by lateral offset)
lbDataSorted = cell(numFrames, 1);
trackIDsStr = cell(numFrames, 1);
for i = 1:numFrames
    frameTracks = trackedLanes{i};
    bounds = []; ids = [];
    for j = 1:numel(frameTracks)
        bounds = [bounds; frameTracks{j}.LaneBoundary];
        ids = [ids; frameTracks{j}.TrackID];
    end
    if ~isempty(bounds)
        offsets = arrayfun(@(b) b.Parameters(3), bounds);
        [~, sortIdx] = sort(offsets, 'descend');  % Left-to-right
        lbDataSorted{i} = bounds(sortIdx)';
        trackIDsStr{i} = string(ids(sortIdx))';
    else
        lbDataSorted{i} = bounds';
        trackIDsStr{i} = string([])';
    end
end
laneDetections = laneData(timestamps, lbDataSorted, TrackIDs=trackIDsStr);
```

### Step 3: Localize ego trajectory
```matlab
% Using roadrunnerHDMap object (preferred — no rrApp dependency)
[localizedTrajectory, info] = localizeEgoUsingLanes(egoTrajectory, rrMap, ...
    laneDetections, startLaneIndex, ApproxLaneWidth=detectedLaneWidth);

% OR using rrApp (requires scene loaded with at least one actor)
[localizedTrajectory, info] = localizeEgoUsingLanes(egoTrajectory, rrApp, ...
    laneDetections, startLaneIndex, ApproxLaneWidth=detectedLaneWidth);
```

### Step 4: Visualize comparison (GPS vs Localized) — MANDATORY user gate
**This is a hard pause.** Immediately after `localizeEgoUsingLanes` returns:
1. Print the offset metrics
2. Export both trajectories to RoadRunner (red=raw GPS, green=localized) and simulate
3. Export the simulation video, then **burn a legend onto the video itself** so the user can tell red vs green without external context
4. Show a `questdlg` popup with the **video file path** and an "Open video" button — this popup is **only** for opening the video, NOT for choosing a trajectory
5. After the user has reviewed the video, **ask in the agent text channel** which trajectory to use (raw GPS or localized) — do not pick automatically

> **HARD RULE — Export `Ego_Localized` FIRST.** RoadRunner assigns `ActorID` in
> the order `exportToRoadRunner` is called (1st call → ID=1). `setCameraMode(...,
> "follow", FocusActorID=1)` therefore tracks whichever actor was exported first.
> Inverting the order silently produces a follow-cam locked on the **red raw**
> trajectory instead of the green localized one — the symptom looks like a
> camera-mode bug but the root cause is the export sequence. Same rule applies
> in workflow-04's multi-GPS compare and SKILL.md Rule 4 final scenario.

```matlab
% Export both trajectories — Ego_Localized FIRST so it gets ActorID=1.
% (Order matters — follow-cam tracks ID=1.)
newScene(rrApp);
exportToRoadRunner(localizedTrajectory, rrApp, ...
    RoadRunnerScene=tempSceneFile, Name="Ego_Localized", ...
    Color="green", SetupSimulation=true);
exportToRoadRunner(egoTrajectory, rrApp, ...
    Name="Ego_GPS_Raw", Color="red", SetupSimulation=false);

% MANDATORY: Delete stale sim object from SetupSimulation=true, then set fail condition
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
rootPhase = roadrunnerAPI(rrApp).Scenario.PhaseLogic.RootPhase;
failCond = rootPhase.setFailCondition("DurationCondition");
failCond.Duration = localizedTrajectory.Duration + 10;

% FOLLOW view focused on the green (localized) ego — keeps both ego cars in
% frame and shows the perspective the user actually drove. NEVER use orbit
% for the localization comparison: it loses the on-road context the user needs.
setCameraMode(rrApp, "follow", FocusActorID=1);  % FocusActorID=1 → Ego_Localized
simulateScenario(rrApp, EnableLogging=true);

% Export simulation video (FileName WITHOUT extension)
locVideoBase = "ego_localization_compare";
exportVideo(rrApp, VideoFolder=videoDir, FileName=locVideoBase, VideoResolution="HD");
locVideoSrc = fullfile(videoDir, locVideoBase + ".mp4");
if ~isfile(locVideoSrc)
    locVideoSrc = fullfile(videoDir, locVideoBase + ".avi");
end

% MANDATORY: side-by-side composite — RAW CAMERA on the LEFT, RR follow view on the RIGHT.
% The raw camera anchors the user to where the ego was in the original recording so
% they can judge whether the green trajectory matches reality.
locVideoOut = fullfile(videoDir, "ego_localization_compare_labeled.mp4");

% Build the raw-camera-as-video on the fly (cameraData is the scenariobuilder.CameraData)
rawVideoTmp = fullfile(tempdir, "raw_camera_for_localization.mp4");
camPaths = cameraData.Frames;                % string array of full paths — NOT `.Filenames`
ts = cameraData.Timestamps;
camWriter = VideoWriter(rawVideoTmp, "MPEG-4");
camWriter.FrameRate = numel(ts) / (ts(end) - ts(1));
open(camWriter);
for k = 1:numel(camPaths)
    img = imread(camPaths(k));
    writeVideo(camWriter, img);
end
close(camWriter);

% Now compose: raw camera (left) | RR follow view with legend (right)
rawReader = VideoReader(rawVideoTmp);
simReader = VideoReader(locVideoSrc);
targetH = 480;
maxFrames = 100;  % side-by-side = heavier I/O per frame; matches visualization-patterns.md
totalDur = min(rawReader.Duration, simReader.Duration);
timeSteps = linspace(0, totalDur - 0.01, maxFrames);

vw = VideoWriter(locVideoOut, "MPEG-4");
vw.FrameRate = round(maxFrames / totalDur);
open(vw);
for k = 1:maxFrames
    t = timeSteps(k);
    rawReader.CurrentTime = t;
    simReader.CurrentTime = t;
    imgRaw = readFrame(rawReader);
    imgSim = readFrame(simReader);

    imgRawR = imresize(imgRaw, targetH / size(imgRaw, 1));
    imgSimR = imresize(imgSim, targetH / size(imgSim, 1));

    imgRawR = insertText(imgRawR, [10 10], ...
        sprintf("Raw camera (t=%.1fs) — original recording", t), ...
        FontSize=18, BoxColor="black", TextColor="white", BoxOpacity=0.7);
    imgSimR = insertText(imgSimR, [10 10], "Red = Raw GPS", ...
        FontSize=18, BoxColor="red", TextColor="white", BoxOpacity=0.75);
    imgSimR = insertText(imgSimR, [10 45], "Green = Localized", ...
        FontSize=18, BoxColor="green", TextColor="white", BoxOpacity=0.75);

    writeVideo(vw, [imgRawR, imgSimR]);
end
close(vw);

% MATLAB popup: ONLY for opening the video — NOT for choosing the trajectory
ans1 = questdlg(sprintf("Lane-localization comparison video saved to:\n%s\n\nOpen it now?", locVideoOut), ...
    "Open localization video", "Yes", "No", "Yes");
if strcmp(ans1, "Yes")
    openFile(locVideoOut);
end
```

After the popup, **the agent must ask the user in the chat channel** which trajectory to use (raw GPS or localized) before exporting non-ego actors or running the final simulation. Do not derive the choice from `medLoc < medRaw` — the smaller-offset trajectory is not always the user's preferred one (e.g., when localization snaps to the wrong lane).

### Step 5: Generate final scenario (same RoadRunner session)
After user confirms localization looks good, **reuse the same RoadRunner instance**. The cleanest path is:
1. `newScenario(rrApp)` — clears the red+green compare scenario (the per-actor `actor.delete()` API is unreliable)
2. Re-export **only** the localized ego with `Color="auto"` (no red/green leftover)
3. Normalize timestamps so ego trajectory and tracklist share the same time origin
4. Call `actorprops` with the **`scenariobuilder.Trajectory`** directly — it accepts that type
5. Export each non-ego actor with `Color="auto"` and `deg2rad` orientations
6. Disable collision fail-condition, set **front camera** on the ego, simulate
7. Save scene and scenario

```matlab
% (1) Fresh scenario — wipes the red/green compare actors cleanly
newScenario(rrApp);

% (2) Re-export only the localized ego
exportToRoadRunner(localizedTrajectory, rrApp, ...
    RoadRunnerScene=tempSceneFile, Name="Ego", ...
    Color="auto", SetupSimulation=true);

% (3) MANDATORY: normalize timestamps — actorprops compares ego and track
% absolute times. Localized trajectory keeps `TimeOrigin=0` after
% localizeEgoUsingLanes; track data has the original epoch start. They MUST
% share an origin. Easiest: zero both sides.
trackObjNorm = copy(trackData);
normalizeTimestamps(trackObjNorm);          % sets track time origin to 0
localizedTrajectory.TimeOrigin = 0;          % already 0 in practice; keep explicit

% (4) Extract non-ego actors — scenariobuilder.Trajectory works directly
nonEgoActorInfo = actorprops(trackObjNorm, localizedTrajectory, SaveAs="none");

% (5) Export each non-ego actor.
% HARD RULE — do NOT pass Orientation= here. actorprops Yaw uses compass
% convention (~340° for northbound) which is incompatible with RR's ENU frame.
% RR auto-derives heading from waypoint deltas — that matches recorded motion.
% On flat scenes (OSM), flatten waypoint Z to 0 — per-track Z is sensor-mount
% offset, not road height. See workflow-04 "Flatten waypoint Z" note.
egoLocalOrigin = localizedTrajectory.LocalOrigin;
for i = 1:height(nonEgoActorInfo)
    wp = nonEgoActorInfo.Waypoints{i};
    wp(:,3) = 0;   % flat scene only
    actorTraj = scenariobuilder.Trajectory( ...
        nonEgoActorInfo.Time{i}, wp, ...
        Name=nonEgoActorInfo.TrackID(i), ...
        LocalOrigin=egoLocalOrigin);
    smooth(actorTraj);
    exportToRoadRunner(actorTraj, rrApp, ...
        Name=nonEgoActorInfo.TrackID(i), Color="auto", SetupSimulation=false);
end

% (6) MANDATORY: Delete stale sim object, then disable collision fail condition
rrSim = createSimulation(rrApp); delete(rrSim); clear rrSim;
rootPhase = roadrunnerAPI(rrApp).Scenario.PhaseLogic.RootPhase;
failCond = rootPhase.setFailCondition("DurationCondition");
failCond.Duration = localizedTrajectory.Duration + 10;

% Final-scenario camera: ALWAYS "front" on ego (NOT follow). Follow view is
% reserved for the localization compare in Step 4. Front view shows what the
% driver sees and what the recorded camera shows — directly comparable.
setCameraMode(rrApp, "front", FocusActorID=1);
simulateScenario(rrApp, EnableLogging=true);

% (7) Save
saveScene(rrApp, fullfile(rrProjectPath, "Scenes", "MyScenario.rrscene"));
saveScenario(rrApp, fullfile(rrProjectPath, "Scenarios", "MyScenario.rrscenario"));
```

**Camera-mode rule (do NOT mix up):**
| Stage | Camera | FocusActor | Why |
|-------|--------|------------|-----|
| Step 4 — localization compare | `"follow"` | localized ego | Both ego copies (red/green) need to stay in frame side-by-side with the road |
| Step 5 — final scenario | `"front"` | ego | Mirror what driver/dashcam saw — directly comparable to raw camera input |

**`actorprops` gotchas (R2026a):**
- Accepts `scenariobuilder.Trajectory` directly — do NOT convert to `waypointTrajectory` first
- The internal timestamp-overlap check uses **absolute** timestamps. If the ego trajectory has `TimeOrigin=0` but track timestamps are still on the recording's epoch (e.g. `1.55e9`), the check fails for every actor. Always `normalizeTimestamps(trackObj)` and set `localizedTrajectory.TimeOrigin = 0` before calling
- The error surface looks like: *"Actor tracklist start timestamp must be greater than or equal to the ego start timestamp..."* followed by an internal `actorParams` assignment failure — both are the same root cause

## Determining the starting lane index — ASK the user
Do NOT try to derive `startLaneIdx` from the detections. The ego camera typically only tracks the two boundaries immediately bracketing the vehicle, so a frame-1 inspection (or `mode(egoLaneIndex(...))`) systematically returns 1 even on a 3-lane or 4-lane road. The dashcam recording is what disambiguates — the user has already seen it; just ask.

Pattern:
1. Run Steps 1–4 (detect → imageToVehicle → fit → track → `laneData`).
2. Print the detection-only hint: `mode(egoLaneIndex(trackedLanes))` and `max(numLanesPerFrame)`.
3. Save state, **stop the script**, and ASK the user in chat for `startLaneIdx` (1 = leftmost driving lane, excluding shoulders).
4. Resume with the user's value into `localizeEgoUsingLanes`.

Splitting the script at this gate (e.g., `part2a_lane_detect.m` → user answers → `part2b_localize_compare.m`) is the cleanest way to enforce the pause without a blocking `input()` prompt that hides in MATLAB's command window.

**Staged-script pattern.** When a pipeline has more than one human-in-the-loop gate (e.g. Multi-GPS pick + lane-index ASK + raw-vs-localized pick), do not stuff them into one monolithic script. Split into numbered parts that save state to a `.mat` between gates (`part1_state.mat`, `part2a_state.mat`, ...). Each part reloads the state, does one section's work, prints a hint, saves new state, and exits. This makes reruns cheap (no re-detecting lanes to fix a downstream bug) and matches the agent's "one tool call ↔ one user answer" loop.

## Benign warnings to ignore
These are expected and do not indicate a problem:
- `Warning: Duplicate data points have been detected and removed - corresponding values have been averaged.` — emitted by `adjustHeight` on dense GPS where two raw samples land on the same point.
- `Warning: Ego lane detections are missing for the frame N.` — emitted by `localizeEgoUsingLanes` when the tracker dropped a frame; it interpolates through. Common at frame 1 before the tracker has converged.
- `Warning: The video's width and height has been padded to be a multiple of two as required by the H.264 codec.` — emitted by `VideoWriter` MPEG-4 on odd-pixel canvases. Cosmetic.

----

Copyright 2026 The MathWorks, Inc.

----
