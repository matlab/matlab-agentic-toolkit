# Import RRHD or OpenDRIVE into a RoadRunner Scene

Import map files into a RoadRunner scene for visualization, verification, and building.



## Key Rules

- **Always write to .m files** when executing code. Never put multi-line MATLAB code directly in `evaluate_matlab_code`. Write to a `.m` file, run with `run_matlab_file`, edit on error. Exception: if the user asks to "show the pattern" or says "do not execute", show code inline without writing files.
- **Requires `rrApp` from `roadrunner-manage-project`.** Do not launch or connect to RoadRunner in this workflow. If `rrApp` does not exist, invoke `roadrunner-manage-project` first.
- **Always copy file to project folder.** Use `status(rrApp).Project.Filename` and `copyfile()` explicitly in every import workflow — never omit or hide behind a variable.
- **Always set `bridgeOpts.IsEnabled = true` explicitly.** Never rely on constructor defaults for bridge auto-detection.
- **Run enforcement gates before `importScene`.** File location, extension, and build-option checks are mandatory.
- **Load before Build by default.** Use `ImportStep="Load"` unless user explicitly requests a full build.
- **NEVER hardcode `DetectAsphaltSurfaces = true` for converted maps.** Always inspect the RRHD for closed-loop topology first. Closed-loop networks (most Lanelet2 conversions) MUST use `DetectAsphaltSurfaces = false` — asphalt detection fills the interior of loops.
- **ALWAYS preserve junctions when they exist.** If `tempMap.Junctions` is non-empty, you MUST set `overlapOpts.IsEnabled = true`, `overlapOpts.PreserveJunctionLanes = true`, and `overlapOpts.PreserveJunctionShape = true`. Never rely on RoadRunner's auto-detection to re-infer junctions — it discards authored geometry.

## Prerequisites

- A valid `rrApp` handle must exist (produced by `roadrunner-manage-project` skill)
- A RoadRunner project must be open
- If `rrApp` does not exist, invoke `roadrunner-manage-project` first to launch and connect

**Connection, launching, and project lifecycle are owned by `roadrunner-manage-project`.** This workflow assumes `rrApp` is already available.

## Import Workflow

### Step 1: Create a Fresh Scene

Always create a new scene before importing to avoid stale data. If the current scene may have unsaved changes, use the `NEW_SCENE` pattern from `roadrunner-manage-project` — it detects unsaved changes and asks before discarding them. Otherwise:

```matlab
newScene(rrApp);
```

### Step 2: Copy File to Project (MANDATORY — always show explicitly)

RoadRunner requires imported files to be inside the project folder. You MUST always include this exact pattern in your generated code — never assume the file is already there or hide it behind a variable:

```matlab
st = status(rrApp);
projectFolder = st.Project.Filename;
[~, fileName, ext] = fileparts(sourceFile);
destFile = fullfile(projectFolder, fileName + ext);
copyfile(sourceFile, destFile);
```

**NEVER** omit the `copyfile()` call or the `status(rrApp).Project.Filename` lookup. Even if you define a `destFile` variable elsewhere, you MUST show both the project path retrieval and the copy operation explicitly in every import workflow.

### Step 3: Import the Map

#### RoadRunner HD Map (.rrhd)

**Load only (inspect RRHD view before build):**
```matlab
importOpts = roadrunnerHDMapImportOptions;
importOpts.ImportStep = "Load";
importScene(rrApp, destFile, "RoadRunner HD Map", importOpts);
```

**Full import with build (use conditional logic — NEVER hardcode asphalt/junction settings):**

Do NOT copy a fixed template. Always use the "Conditional Build Options" section below to determine the correct settings based on RRHD content. The enforcement gate will reject hardcoded `DetectAsphaltSurfaces = true` for RRHD files.

**IMPORTANT:** When enabling bridge auto-detection, you MUST always write `bridgeOpts.IsEnabled = true` explicitly. Do NOT rely on the constructor default — the line must appear in the generated code.

### Conditional Build Options (MANDATORY — apply based on map content)

Inspect the RRHD content before choosing build options. The following rules determine when to enable/disable specific settings:

| Condition | Action | Reason |
|-----------|--------|--------|
| No `Junctions` in RRHD (empty or zero) | Set `overlapOpts.IsEnabled = false` | Without explicit junction definitions, overlap detection uses only geometry and produces incorrect groupings |
| Closed-loop network — `detectClosedLoop(tempMap)` true (track-style ring or roundabout; street grids are not loops) | Set `buildOpts.DetectAsphaltSurfaces = false` | Asphalt detection fills interior of closed loops, creating unwanted surface polygons |
| Explicit `Junctions` present in RRHD | Set `overlapOpts.PreserveJunctionLanes = true` and `overlapOpts.PreserveJunctionShape = true` | Preserves authored junction geometry and lane connectivity instead of re-inferring from geometry |

**Example: Import with junction-aware options:**
```matlab
importOpts = roadrunnerHDMapImportOptions;
buildOpts = roadrunnerHDMapBuildOptions;
buildOpts.ClearSceneOfExistingData = true;

% Read RRHD to inspect content before build
tempMap = roadrunnerHDMap;
read(tempMap, destFile);

% Conditional: asphalt surfaces (scripts/detectClosedLoop.m)
[hasClosedLoop, loopInfo] = detectClosedLoop(tempMap);
fprintf('%s\n', loopInfo.reason);
buildOpts.DetectAsphaltSurfaces = ~hasClosedLoop;

% Conditional: overlap groups / junctions
overlapOpts = enableOverlapGroupsOptions;
if isempty(tempMap.Junctions) || numel(tempMap.Junctions) == 0
    overlapOpts.IsEnabled = false;
else
    overlapOpts.IsEnabled = true;
    overlapOpts.PreserveJunctionLanes = true;
    overlapOpts.PreserveJunctionShape = true;
end
buildOpts.EnableOverlapGroupsOptions = overlapOpts;

bridgeOpts = autoDetectBridgesOptions;
bridgeOpts.IsEnabled = true;
buildOpts.AutoDetectBridgesOptions = bridgeOpts;

importOpts.BuildOptions = buildOpts;
importScene(rrApp, destFile, "RoadRunner HD Map", importOpts);
```

#### OpenDRIVE (.xodr)

```matlab
importOpts = openDriveImportOptions;
importOpts.ImportSignals = true;
importOpts.ImportObjects = true;
importScene(rrApp, destFile, "OpenDRIVE", importOpts);
```

When the `.xodr` is the road network of an OpenSCENARIO (`.xosc`) being rebuilt with `roadrunner-author-scenario`, also set `importOpts.ProjectionMode = "noprojection"` so the scene stays in the `.xodr` native frame; otherwise actor positions taken from the `.xosc` do not line up.

### Step 4: Save the Scene

```matlab
[~, sceneName] = fileparts(sourceFile);
saveScene(rrApp, sceneName);
```

## Import Options Reference

### roadrunnerHDMapImportOptions

| Property | Description |
|----------|-------------|
| `ImportStep` | `"Load"` (RRHD view only) or `"Unspecified"` (full load+build) |
| `LoadOptions` | `roadrunnerHDMapLoadOptions` — offset, projection |
| `BuildOptions` | `roadrunnerHDMapBuildOptions` — build configuration |

### roadrunnerHDMapBuildOptions

| Property | Description | Default |
|----------|-------------|---------|
| `ClearSceneOfExistingData` | Remove existing scene content | auto |
| `DetectAsphaltSurfaces` | Generate road surfaces | auto |
| `FitCrossSections` | Fit lane cross sections | auto |
| `CurvatureBlend` | Curvature blending factor | auto |
| `UseLaneGroups` | Group lanes for editing (R2024a+) | auto |
| `CombineTransitionLanes` | Merge transition lanes (R2025a+) | auto |
| `AutoDetectBridgesOptions` | `autoDetectBridgesOptions` object | auto |
| `EnableOverlapGroupsOptions` | `enableOverlapGroupsOptions` object (junctions) | auto |
| `FixUnrealisticRoadElevation` | Correct elevation jumps from HD sources | auto |
| `FixInconsistentLaneConnections` | Remove physically unrealistic lane links | auto |

### enableOverlapGroupsOptions

| Property | Description | Default |
|----------|-------------|---------|
| `IsEnabled` | Use junction location info (false = geometric overlaps) | auto |
| `PreserveJunctionLanes` | Keep original junction lanes from imported map | auto |
| `PreserveJunctionShape` | Keep junction polygon geometry from imported map | auto |
| `GroupName` | Name of the overlap group | auto |

### openDriveImportOptions

| Property | Description |
|----------|-------------|
| `ImportSignals` | Import traffic signals |
| `ImportObjects` | Import static objects |
| `LaneOptions` | Lane conversion settings |
| `Offset` | Scene position offset |
| `Projection` | Geospatial projection |
| `ProjectionMode` | `"noprojection"` keeps native `.xodr` coordinates (OpenSCENARIO rebuilds) |
| `ImportRegion` | Region filter (R2024a+) |

## Supported Formats

| Format Name | File Type | Since |
|-------------|-----------|-------|
| `"RoadRunner HD Map"` | .rrhd | R2022b |
| `"OpenDRIVE"` | .xodr | R2022a |
| `"HERE HD Map"` | (catalog) | R2024a |
| `"TomTom HD Map"` | (catalog) | R2024b |

## Default Behavior

When the user asks to "import a map" or "load into RoadRunner":
1. Ensure `rrApp` exists (invoke `roadrunner-manage-project` if not)
2. Create a new scene (clean slate)
3. Copy the file into the project folder (`status(rrApp).Project.Filename`)
4. Import with **Load only** (`ImportStep="Load"`) so user can verify RRHD view
5. Save the scene with the filename as scene name

Only perform a full build (with `BuildOptions`) when the user explicitly asks to build or the RRHD view has been verified.

When building, **always inspect the RRHD content first** and apply the conditional build options from the "Conditional Build Options" section above. Never use fixed/hardcoded build options without checking map content.

## Key Functions

| Function | Purpose |
|----------|---------|
| `newScene(rrApp)` | Create fresh scene (clean slate) |
| `status(rrApp)` | Get project info (`.Project.Filename`) |
| `importScene(rrApp, file, format, opts)` | Import map file into scene |
| `saveScene(rrApp, name)` | Save current scene |
| `roadrunnerHDMapImportOptions` | Create import options (set `ImportStep`, `BuildOptions`) |
| `roadrunnerHDMapBuildOptions` | Create build options (asphalt, bridges, junctions) |
| `autoDetectBridgesOptions` | Bridge detection settings (`IsEnabled`) |
| `enableOverlapGroupsOptions` | Junction preservation (`PreserveJunctionLanes`, `PreserveJunctionShape`) |
| `openDriveImportOptions` | OpenDRIVE-specific import options |

## Enforcement Gate (MANDATORY — run before import)

You MUST execute these checks before calling `importScene`. Do NOT skip.

```matlab
%% --- ENFORCEMENT: RoadRunner is connected ---
try
    st = status(rrApp);
    assert(~isempty(st.Project.Filename), 'No project open');
    fprintf('RoadRunner connected, project: %s\n', st.Project.Filename);
catch
    error('RoadRunner:NotConnected', ...
        'No RoadRunner instance connected. Run the Connection Strategy block first.');
end

%% --- ENFORCEMENT: File is inside project folder and exists ---
projectFolder = st.Project.Filename;
normPath = @(p) lower(strrep(char(p), '\', '/'));
assert(startsWith(normPath(destFile), normPath(projectFolder)) && isfile(destFile), ...
    'Import file must be inside the project folder (%s). Copy it first.', projectFolder);
fprintf('File location check: PASS\n');

%% --- ENFORCEMENT: File extension matches format ---
[~, ~, ext] = fileparts(destFile);
if formatName == "RoadRunner HD Map"
    assert(ext == ".rrhd", 'Expected .rrhd file for RoadRunner HD Map format');
elseif formatName == "OpenDRIVE"
    assert(ext == ".xodr", 'Expected .xodr file for OpenDRIVE format');
end
fprintf('Format check: PASS\n');

%% --- ENFORCEMENT: Build options match RRHD content (MANDATORY when building a .rrhd) ---
% Load-only imports (ImportStep="Load") do not use build options; these checks run whenever buildOpts exists.
if ext == ".rrhd" && exist('buildOpts', 'var') == 1
    tempMap = roadrunnerHDMap;
    read(tempMap, destFile);

    % Junction preservation check
    if ~isempty(tempMap.Junctions) && numel(tempMap.Junctions) > 0
        assert(exist('overlapOpts','var') == 1 && overlapOpts.IsEnabled == true ...
            && overlapOpts.PreserveJunctionLanes == true ...
            && overlapOpts.PreserveJunctionShape == true, ...
            'RRHD has %d junctions — you MUST enable PreserveJunctionLanes and PreserveJunctionShape.', ...
            numel(tempMap.Junctions));
        fprintf('Junction preservation check: PASS (%d junctions preserved)\n', numel(tempMap.Junctions));
    end

    % Closed-loop / asphalt check (scripts/detectClosedLoop.m)
    [hasClosedLoop, loopInfo] = detectClosedLoop(tempMap);
    if hasClosedLoop
        assert(buildOpts.DetectAsphaltSurfaces == false, ...
            'DetectAsphaltSurfaces must be false for closed-loop maps (%s).', loopInfo.reason);
    end
    fprintf('Asphalt detection check: PASS — %s\n', loopInfo.reason);
end
```

## Conventions

- Always specify format name string exactly: `"RoadRunner HD Map"`, `"OpenDRIVE"`
- Show all file-staging code explicitly (`status`, `fileparts`, `fullfile`, `copyfile`)
- Use `tiledlayout`/`nexttile` for multi-panel figures (not `subplot`)
- Pin `destFile` to the project folder path — never use temp or relative paths for import

----

Copyright 2026 The MathWorks, Inc.

----
