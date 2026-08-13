---
name: workflow-18-vehicle-classification
description: Classify tracked vehicles by color and type using the agent's built-in vision capability, then map results to RoadRunner asset paths and named colors for realistic scenario export. Runs automatically inside Workflow 4 Step 4 when camera intrinsics + actor tracks are available.
---

# Workflow 18 — Vehicle Classification from Camera (Vision-Based)

> **Parent skill:** [`SKILL.md`](../SKILL.md). This workflow runs as part of Workflow 4 Step 4 (non-ego export). It requires actor tracks (Workflow 3) and camera data with intrinsics.
>
> **Related references:**
> - [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) — Step 4 consumes the classification map.
> - [`visualization-patterns.md`](visualization-patterns.md) — camera frame convention (Xc = -y_ego, Yc = -(z-camH), Zc = x_ego).
> - [`actortrackdata-api.md`](actortrackdata-api.md) — ActorTrackData properties.

## When to Run

This workflow fires **automatically** inside Workflow 4 Step 4 (non-ego actor export) when ALL of these are true:

1. `ActorTrackData` exists with 3D ego-frame positions
2. `CameraData` exists with accessible frames (`.Frames` returns valid paths)
3. Camera intrinsics (`fx, fy, cx, cy`) AND `CameraHeight` are explicitly present
4. The agent can view images (multimodal — self-gating, see below)

**Skip conditions (any one → skip, export with default `"Sedan"`):**
- No camera intrinsics or no `CameraHeight`
- No actor tracks
- Agent cannot view images (text-only model)

## Self-Gating Pattern

No programmatic check for vision capability is needed. The workflow instruction self-gates:

> "View the composite grid image. If you can identify vehicles in the image, classify each by color (one word) and vehicle type. If you cannot process images, skip classification and export actors with default asset types."

A text-only agent reading that instruction will skip. A multimodal agent will classify.

## Pipeline

### Step 1: Build best-crop grid

Use the helper `scripts/buildBestCropGrid.m`:

```matlab
addpath(fullfile(fileparts(mfilename("fullpath")), "scripts"));

% intrinsics = struct with fx, fy, cx, cy from CameraData.SensorParameters
% camHeight = CameraData.SensorParameters.CameraHeight (or dataset's CameraHeight)
classifyDir = fullfile(dataDir, "classification");
[gridPath, cropManifest] = buildBestCropGrid(trackData, cameraData, ...
    intrinsics, camHeight, classifyDir);
fprintf("Classification grid saved: %s (%d tracks)\n", gridPath, height(cropManifest));
```

The function:
1. Projects each actor's 3D bounding box (default 4.5×1.9×1.6 m) to 2D using `K * [Xc Yc Zc]'`
2. Picks the frame with maximum projected bbox area per track (best visibility)
3. Crops that region from the frame
4. Stitches all crops into a single labeled grid (4 columns, track IDs visible)

### Step 2: Agent views the grid and classifies

View the composite grid image at `gridPath`. For each labeled track ID, determine:
- **Color** — one word (e.g., white, black, silver, red, blue, gray, dark, green)
- **Type** — sedan, SUV, truck, van, pickup, hatchback, motorcycle, bus, coupe, minivan
- **Confidence** — high / medium / low

Build the classification result as a MATLAB `containers.Map` keyed by TrackID:

```matlab
% Example classification map built from agent's vision pass
classificationMap = containers.Map();
classificationMap("3")  = struct(Color="white", Type="sedan",  RRCategory="Sedan",    Confidence="high");
classificationMap("4")  = struct(Color="gray",  Type="SUV",    RRCategory="SUV",      Confidence="high");
classificationMap("5")  = struct(Color="silver",Type="minivan",RRCategory="Van",      Confidence="high");
% ... one entry per classified track
```

### Step 3: Map type → RoadRunner category → AssetPath

Priority-ordered — first keyword match wins:

| Keyword in type | RoadRunner Category | Default AssetPath |
|----------------|---------------------|-------------------|
| police | Sedan | `"Vehicles/Sedan.fbx"` |
| ambulance | Van | `"Vehicles/Van.fbx"` |
| fire / garbage / tow / trailer | Truck | `"Vehicles/BoxTruck.fbx"` |
| minivan | Van | `"Vehicles/Van.fbx"` |
| minibus / school bus / bus | Bus | `"Vehicles/Bus.fbx"` |
| pickup | Pickup | `"Vehicles/SmallPickupTruck.fbx"` |
| limousine / convertible / coupe / sedan | Sedan | `"Vehicles/Sedan.fbx"` |
| suv / crossover / jeep | SUV | `"Vehicles/SUV.fbx"` |
| wagon / hatchback | Hatchback | `"Vehicles/Hatchback.fbx"` |
| scooter / moped / motorcycle | Motorcycle | `"Vehicles/Motorcycle.fbx"` |
| bicycle | Bicycle | `"Vehicles/Bicycle.fbx"` |
| truck | Truck | `"Vehicles/BoxTruck.fbx"` |
| van | Van | `"Vehicles/Van.fbx"` |
| taxi / cab / car / vehicle (generic) | Sedan | `"Vehicles/Sedan.fbx"` |

**Default (unclassified or low confidence):** `"Vehicles/Sedan.fbx"`

**AssetPath discovery is MANDATORY.** Filename casing in the table above is
illustrative — the actual on-disk stems vary by RR version (e.g., `Suv.fbx`
vs `SUV.fbx`, `Box_Truck.fbx` vs `BoxTruck.fbx`). RR's `<PROJECT>/Assets/...`
path resolution is **case-sensitive even on Windows**, so a wrong-cased path
silently produces a white placeholder box. Always discover the real names
first and match exactly:

```matlab
assetDir = fullfile(rrProjectPath, "Assets", "Vehicles");
availableAssets = string({dir(fullfile(assetDir, "*.fbx*")).name})';
fprintf("Available vehicle assets:\n");
disp(availableAssets);

% Build the AssetPath using the discovered stem, not a hardcoded one
% e.g. assetPath = "Vehicles/" + availableAssets(idxMatchingCategory);
```

If a category's asset is missing from the user's project, fall back to
`"Vehicles/Sedan.fbx"` (always present in default RR projects). The fallback
must use whichever case matches what `dir` returned.

### Step 4: Map classified color → RR named color

Reduce the free-form color word to the closest RR-supported named color:

| Classified color | RR Color value |
|-----------------|----------------|
| white | `"white"` |
| black / dark | `"black"` |
| red | `"red"` |
| blue | `"blue"` |
| green / dark green | `"green"` |
| yellow / gold | `"yellow"` |
| gray / grey / silver | `"gray"` |
| orange / brown | `"orange"` |
| unknown / unclassified | `"auto"` |

When confidence is "low", always use `Color="auto"` regardless of the classified word.

### Step 5: Export with classification (replaces default Step 4 loop)

```matlab
% This replaces the plain Color="auto" loop in workflow-04 Step 4.
% isTerrainScene: true for HERE HD, Zenrin, etc.; false for OSM/Pandaset flat scenes
for i = 1:height(actorInfo)
    wp = actorInfo.Waypoints{i};
    if isTerrainScene
        wp(:,3) = wp(:,3) + 0.75;  % terrain compensation for non-ego actors
    else
        wp(:,3) = 0;  % flat scene — see workflow-04 "Flatten waypoint Z"
    end
    % Do NOT pass Orientation= or Speed= here — see trajectory-api.md HARD RULES.
    actorTraj = scenariobuilder.Trajectory( ...
        actorInfo.Time{i}, wp, ...
        Name=actorInfo.TrackID(i), LocalOrigin=egoLocalOrigin);
    smooth(actorTraj);

    tid = char(actorInfo.TrackID(i));
    if isKey(classificationMap, tid)
        cls = classificationMap(tid);
        if cls.Confidence ~= "low"
            assetPath = mapCategoryToAssetPath(cls.RRCategory, rrProjectPath);
            rrColor   = mapColorToRRColor(cls.Color);
        else
            assetPath = "Vehicles/Sedan.fbx";
            rrColor   = "auto";
        end
    else
        assetPath = "Vehicles/Sedan.fbx";
        rrColor   = "auto";
    end

    exportToRoadRunner(actorTraj, rrApp, ...
        Name=actorInfo.TrackID(i), AssetPath=assetPath, ...
        Color=rrColor, SetupSimulation=false);
end
```

## Post-Export Asset Replacement (Alternative to AssetPath in exportToRoadRunner)

When replacing assets **after** export (e.g., iterating on classification results without re-exporting trajectories), use the `<PROJECT>/` relative path format — **never** absolute paths:

```matlab
% Get actor handles from the scenario API
rrAPI = roadrunnerAPI(rrApp);
allActors = rrAPI.Scenario.Actors;

% Apply classification — use <PROJECT>/Assets/... paths (CRITICAL)
for k = 2:numel(allActors)  % skip ego (k=1)
    tid = allActors(k).Name;
    if isKey(assetMap, tid)
        allActors(k).ActorAsset = assetMap(tid);  % e.g. "<PROJECT>/Assets/Vehicles/Suv.fbx_rrx"
        allActors(k).Color = colorMap(tid);       % [R G B A] normalized, e.g. [1 1 1 1]
    end
end
```

**CRITICAL:** Absolute paths (e.g., `"C:/Users/.../Vehicles/Sedan.fbx"`) will silently break the asset reference — actors render as white placeholder boxes. Always use `<PROJECT>/Assets/Vehicles/<name>` format. The `.Color` property accepts a `[R G B A]` vector (values 0–1).

## Helper Functions (local to the generated script)

```matlab
function ap = mapCategoryToAssetPath(category, rrProjectPath)
    % Discover real on-disk filenames — RR path resolution is case-sensitive,
    % so we match against actual stems instead of hardcoding which case is
    % "right" (varies by RR version: Suv.fbx vs SUV.fbx, etc.).
    assetDir = fullfile(rrProjectPath, "Assets", "Vehicles");
    files = string({dir(fullfile(assetDir, "*.fbx*")).name})';
    % Strip extensions to get bare stems
    [~, stems, ~] = arrayfun(@(f) fileparts(f), files, UniformOutput=false);
    stems = string(stems);
    % Category → list of acceptable stem patterns (case-insensitive match,
    % then return whatever case the disk actually uses).
    % Wrap pattern values in cells — dictionary requires uniform value sizes,
    % so scalar/array mix forces cell-valued entries (read with `{key}`).
    patternMap = dictionary( ...
        "Sedan",      {"sedan"}, ...
        "SUV",        {"suv"}, ...
        "Hatchback",  {"hatchback"}, ...
        "Pickup",     {["pickup" "smallpickup"]}, ...
        "Truck",      {["box_truck" "boxtruck" "truck"]}, ...
        "Van",        {"van"}, ...
        "Bus",        {"bus"}, ...
        "Motorcycle", {"motorcycle"}, ...
        "Bicycle",    {"bicycle"});
    if isKey(patternMap, category)
        patterns = patternMap{category};
    else
        patterns = "sedan";
    end
    matchIdx = find(arrayfun(@(s) any(strcmpi(s, patterns)), stems), 1);
    if isempty(matchIdx)
        % Fall back to first sedan-like file, or first file at all
        sedanIdx = find(arrayfun(@(s) startsWith(lower(s), "sedan"), stems), 1);
        if ~isempty(sedanIdx)
            ap = "Vehicles/" + files(sedanIdx);
        else
            ap = "Vehicles/" + files(1);
        end
    else
        ap = "Vehicles/" + files(matchIdx);
    end
end

function c = mapColorToRRColor(classifiedColor)
    classifiedColor = lower(classifiedColor);
    if contains(classifiedColor, ["white"])
        c = "white";
    elseif contains(classifiedColor, ["black", "dark"])
        c = "black";
    elseif contains(classifiedColor, ["red"])
        c = "red";
    elseif contains(classifiedColor, ["blue"])
        c = "blue";
    elseif contains(classifiedColor, ["green"])
        c = "green";
    elseif contains(classifiedColor, ["yellow", "gold"])
        c = "yellow";
    elseif contains(classifiedColor, ["gray", "grey", "silver"])
        c = "gray";
    elseif contains(classifiedColor, ["orange", "brown"])
        c = "orange";
    else
        c = "auto";
    end
end
```

## Confidence Handling

| Confidence | Action |
|-----------|--------|
| **high** | Apply both AssetPath and Color from classification |
| **medium** | Apply AssetPath; apply Color (but note uncertainty in progress table) |
| **low** | Fall back to `AssetPath="Vehicles/Sedan.fbx"`, `Color="auto"` |

## Composite Grid Optimization

For datasets with many tracks (>5), the grid approach (one image, all crops labeled) is far more efficient than viewing individual crops. The `buildBestCropGrid` helper always produces a grid regardless of track count. For ≤5 tracks the agent may view crops individually if the grid is hard to read.

## Accuracy Expectations

| Condition | Expected high-confidence rate |
|-----------|-------------------------------|
| Daytime, close range, ≥1080p | ~85% |
| Daytime, highway, 640×480 | ~35% |
| Nighttime, any resolution | ~35% |

Low-confidence classifications default to Sedan — the scenario is still valid, just with less visual variety.

## Overlay Verification (Optional)

After classification, the agent may render a verification overlay video showing each track's bbox with its classification label. This uses the same projection pattern as `plotActorCircles` but with classification labels instead of bare IDs:

```matlab
% Label format: "ID <tid> | <color> <type> [RR:<category>] (<confidence>)"
label = sprintf("ID %s | %s [RR:%s] (%s)", tid, cls.Color + " " + cls.Type, ...
    cls.RRCategory, cls.Confidence);
```

This overlay is OPTIONAL — only generate when the user asks "show me the classifications" or "verify vehicle types". It is NOT part of the mandatory saved-video-popup chain.

---

Copyright 2026 The MathWorks, Inc.

---
