---
name: roadrunner-convert-lanelet2-to-rrhd
description: >
  Convert Lanelet2 maps (.osm) to RoadRunner HD Map (.rrhd) format using MATLAB. Use when
  converting Lanelet2 maps into RoadRunner Scene Builder, building driving scenes from
  open-source map data, or transforming road network definitions for simulation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Lanelet2 to RRHD Converter

Converts Lanelet2 `.osm` files to RoadRunner HD Map `.rrhd` format.

## When to Use

- Converting a Lanelet2 `.osm` file to RoadRunner HD Map `.rrhd` format
- Importing Lanelet2 maps into RoadRunner via MATLAB
- Building RRHD from `.osm` sources that contain `type=lanelet` relations
- Need full pipeline: parse, geometry, topology, semantics, junctions, barriers, signs, markings

## When NOT to Use

- Input is a standard OpenStreetMap file (highway=* ways without `type=lanelet` relations)
- Input is OpenDRIVE `.xodr` — import directly via `roadrunner-import-scene`
- Building RRHD from scratch without a source file — use `roadrunner-rrhd-authoring`
- Only need asset path lookups — use `roadrunner-asset-mapping`

## Key Rules

- **Always write to .m files** when executing code. Never put multi-line MATLAB code directly in `evaluate_matlab_code`. Write to a `.m` file, run with `run_matlab_file`, edit on error. Exception: if the user asks to "show the pattern" or says "do not execute", show code inline without writing files.
- **ALL pipeline steps are mandatory.** Do NOT stop after writing lanes/boundaries — junctions, curve markings, barriers, signs, and speed limits must all be built.
- **Boundary geometry is IMMUTABLE.** Never flip, resample, project, or modify boundary points.
- **One boundary object per way.** Deduplicate via `wayToBndID` map.
- **Detect alignment for EVERY lane.** Never hardcode `"Forward"` for all boundaries.
- **Center line density: 1 point per meter minimum.** Use `max(10, round(avgLen), nLeft, nRight)`.
- **Run enforcement gate before `write()`.** Alignment, spatial, extension, and completeness checks are mandatory.
- **No nested function definitions.** Code runs in script context — all logic inline or anonymous functions.

## Behavior

Generate MATLAB code that performs the conversion pipeline described below. Run it via `mcp__matlab__evaluate_matlab_code`. No pre-built scripts or `addpath` calls are needed — Claude generates all code at runtime from these instructions.

**MANDATORY: ALL steps must be executed.** Do NOT stop after writing lanes/boundaries. The pipeline is incomplete without: junctions, curve markings (stop lines + crosswalks), barriers, signs, and speed limits. Every element found in the OSM MUST appear in the output RRHD.

**MANDATORY: Steps 3b and 3c (discovery) must execute IN THE SAME code block as Step 3a.** These are not optional post-processing — they are part of parsing. The discovery loop code is inlined below in Step 3. If you skip 3b/3c, the completeness gate in Step 9 will fail with assertion errors.

**Scope:** This skill supports **Lanelet2 OSM only**. If the input is a standard OpenStreetMap file (highway=* ways without `type=lanelet` relations), do NOT attempt conversion. Instead inform the user: "This file appears to be a standard OpenStreetMap road network, not a Lanelet2 map. This skill only supports Lanelet2 OSM → RRHD conversion."

**Companion skills (invoke automatically during conversion):**

| Skill | When to invoke | Purpose |
|-------|----------------|---------|
| `roadrunner-rrhd-authoring` | Step 9 (Build RRHD Objects) | Provides `roadrunner.hdmap.*` class/property reference and construction patterns |
| `roadrunner-asset-mapping` | Step 8 (Extract Semantics) | Resolves marking subtypes, sign codes, and barrier types to RoadRunner asset paths |

These skills are loaded on demand — read their references when generating RRHD construction code or resolving asset paths.

**Skill boundary:** This skill owns everything Lanelet2-specific (OSM parsing, node-ref topology, turn_direction clustering, opposing-boundary detection). For RRHD object construction patterns (alignment algorithm, center line synthesis, junction polygon, API reference), defer to `roadrunner-rrhd-authoring`.

## Coordinate System

Lanelet2 OSM nodes may use either:
- **`local_x`/`local_y` tags** — already in local meters, use directly as geometry X/Y
- **`lat`/`lon` attributes only** — geographic coordinates that MUST be projected to local meters

### Step 1: Check for `map_projector_info.yaml`

Lanelet2 datasets typically include a `map_projector_info.yaml` file in the same directory as the `.osm` file. This file specifies the projection and map origin:

```yaml
ProjectorType: TransverseMercator
VerticalDatum: WGS84
MapOrigin:
  Latitude: 42.300945
  Longitude: -83.698205
  Altitude: 0
```

**Always look for this file first.** Parse it to get `ProjectorType` and `MapOrigin`:

```matlab
projFile = fullfile(fileparts(osmFile), "map_projector_info.yaml");
if isfile(projFile)
    txt = fileread(projFile);
    latMatch = regexp(txt, 'Latitude:\s*([-\d.]+)', 'tokens');
    lonMatch = regexp(txt, 'Longitude:\s*([-\d.]+)', 'tokens');
    if ~isempty(latMatch) && ~isempty(lonMatch)
        originLat = str2double(latMatch{1}{1});
        originLon = str2double(lonMatch{1}{1});
    end
end
```

If `MapOrigin` is `[0, 0]`, the origin is implicit — use the centroid of all nodes instead.

### Step 2: Determine coordinate mode

1. **Nodes have `local_x`/`local_y`** → use directly, set `geoRef` from `map_projector_info.yaml` MapOrigin (or from node lat/lon if yaml missing)
2. **Nodes have only `lat`/`lon`** → project to local ENU meters using the origin from yaml (or node centroid as fallback)

### Step 3: Project lat/lon to local meters (when needed)

```matlab
% Origin from map_projector_info.yaml or centroid fallback
geoRef = [originLat, originLon];

% For each node, convert to local meters:
dLat = node.lat - originLat;
dLon = node.lon - originLon;
metersPerDegLat = 111132.92;
metersPerDegLon = 111132.92 * cosd(originLat);
x = dLon * metersPerDegLon;   % East
y = dLat * metersPerDegLat;   % North
z = node.ele;                  % Up (elevation)
```

Set `rrMap.GeoReference = [originLat, originLon]` so RoadRunner knows the map's geographic position.

**IMPORTANT:** This projection happens ONCE during node parsing. All downstream geometry (boundaries, center lines, barriers, signs) uses the projected local coordinates. The "boundary geometry is immutable" rule (below) refers to the projected coordinates — do not re-project or modify them after initial parsing.

## Geometry Invariants (MUST enforce — violations produce broken RRHD)

These rules are NON-NEGOTIABLE. Every conversion MUST follow them:

1. **Boundary geometry is IMMUTABLE.** Store way node coordinates (local or projected) exactly as computed during parsing. NEVER flip, resample, or modify boundary points after initial coordinate assignment. Shared boundaries between opposing lanes will corrupt if touched. Use `Alignment="Backward"` instead.

2. **One boundary object per way.** Deduplicate via `wayToBndID` map. Multiple lanes reference the same boundary with different alignments.

3. **Alignment via left/right dot product + proximity test.** Compute `dp = dot(leftDir, rightDir)` (normalized overall direction — this is correct for the threshold check). If `dp >= -0.3`: both boundaries are Forward. If `dp < -0.3`: boundaries are opposing — use proximity (`d_ls_re = norm(leftStart - rightEnd)` vs `d_ls_rs = norm(leftStart - rightStart)`) to determine which is Backward. If `d_ls_re < d_ls_rs`, right is Backward, left is Forward. (Note: the "NEVER use overall direction" warning in Step 9 applies to the multi-sample spatial *verification* step, not this dp threshold check.)

4. **Center line density: 1 point per meter minimum.** Use `nPts = max(10, round(avgBoundaryLength), nLeftPts, nRightPts)`. Too few points causes pchip interpolation deviation from true midpoint.

5. **Center line orthogonal endpoints only.** Enforce perpendicular start/end on CENTER LINE via tangent blending. Do NOT project boundary endpoints.

## MATLAB Script Constraints

Code runs in `mcp__matlab__evaluate_matlab_code` which is a **script context** (NOT a function file):
- **NO nested function definitions** — all logic must be inline or use anonymous functions
- **NO `function ... end` blocks** — these error with "Function definitions are not supported in this context"
- **Empty typed arrays** — use `ClassName.empty` not `[]` (e.g., `roadrunner.hdmap.AlignedReference.empty`)
- **Name=Value constructors** — `RelativeAssetPath`, `AlignedReference` require Name=Value syntax:
  ```matlab
  % CORRECT:
  rap = roadrunner.hdmap.RelativeAssetPath(AssetPath="Assets/Markings/StopLine.rrlms");
  ar = roadrunner.hdmap.AlignedReference(Reference=ref, Alignment="Forward");

  % WRONG (will error with "A name is expected"):
  rap = roadrunner.hdmap.RelativeAssetPath("Assets/Markings/StopLine.rrlms");
  ar = roadrunner.hdmap.AlignedReference(bndID, "Forward");
  ```
- **containers.Map empty assignment** — never do `map(key) = []`. Use `map(key) = zeros(1,0)` or only assign non-empty values
- **No chaining `()()`** — `geomMap(key)(:,1)` errors with "Using parentheses directly after parentheses is disallowed". Assign to a temp variable first:
  ```matlab
  % WRONG: min(geomMap(k)(:,1))
  % CORRECT:
  pts = geomMap(k);
  minX = min(pts(:,1));
  ```
- **`unique()` on cell arrays** — `unique(cellArray)` requires cellstr (cell of char vectors). For string arrays use `unique(stringArray)` directly. For mixed cells: `unique(string(cellArray))`.
- **`containers.Map` values need explicit type cast** — values retrieved from `containers.Map` may lose their numeric type. Always cast before math: `double(geoRef(1))` before passing to `cosd()`, `sind()`, etc.
- **Cell array struct field assignment** — never do `cellArray{end+1} = x; cellArray{end}.field = val;` (errors with "dot indexing not supported for double"). Instead, build the struct first then append:
  ```matlab
  % WRONG:
  stopLineWays{end+1} = w; stopLineWays{end}.wayID = wid;
  % CORRECT:
  w.wayID = wid; stopLineWays{end+1} = w;
  % OR: store IDs in a separate parallel cell array
  ```

## Pipeline (execute in order)

### Step 1: Parse OSM

See [references/readOSM.md](references/readOSM.md) and [scripts/parseOSM.m](scripts/parseOSM.m).

```matlab
doc = xmlread(osmFile);
% Parse nodes: id, lat, lon, ele, local_x, local_y (from tags)
% Parse ways: id, nodeRefs[], tags (containers.Map)
% Parse relations: id, members[], tags (containers.Map)
```

### Step 2: Validate Format

Check that at least one relation has `type=lanelet`. If none found, error with clear message identifying the file as non-Lanelet2.

```matlab
hasLanelet = false;
relKeys = relations.keys;
for i = 1:numel(relKeys)
    rel = relations(relKeys{i});
    if rel.tags.isKey('type') && strcmp(rel.tags('type'), 'lanelet')
        hasLanelet = true; break;
    end
end
if ~hasLanelet
    error('UNSUPPORTED FORMAT: This converter supports Lanelet2 OSM files only.');
end
```

### Step 3: Extract Lanelets + Discover ALL Non-Lane Elements

**This step has THREE mandatory sub-steps. ALL must execute.**

#### Step 3a: Extract Lanelets

Filter relations with `type=lanelet`. See [references/extractLanelets.md](references/extractLanelets.md).

```matlab
% For each relation with type=lanelet:
%   leftWayID  = member with role="left"
%   rightWayID = member with role="right"
%   subtype, one_way, speed_limit, turn_direction from tags
```

#### Step 3b: Discover ALL Way Types (MANDATORY — run immediately after 3a)

See [scripts/discoverWayTypes.m](scripts/discoverWayTypes.m) for the reference implementation.

**DO NOT use a whitelist.** Scan every way, categorize by `type` tag using `strsplit(wType, '/')` for compound types:

```matlab
stopLineWays = {}; pedestrianMarkingWays = {}; zebraMarkingWays = {};
bikeMarkingWays = {}; zigzagWays = {};
fenceWays = {}; guardRailWays = {}; jerseyBarrierWays = {};
wallWays = {}; curbstoneWays = {};
trafficSignWays = {}; trafficLightWays = {};
unmappedWays = containers.Map;

wayKeys = ways.keys;
for i = 1:numel(wayKeys)
    w = ways(wayKeys{i});
    if ~w.tags.isKey('type'), continue; end
    wType = w.tags('type');
    typeParts = strsplit(wType, '/');
    baseType = typeParts{1};
    switch baseType
        case 'stop_line', stopLineWays{end+1} = w;
        case 'pedestrian_marking', pedestrianMarkingWays{end+1} = w;
        case 'zebra_marking', zebraMarkingWays{end+1} = w;
        case 'bike_marking', bikeMarkingWays{end+1} = w;
        case {'zig-zag','zig_zag'}, zigzagWays{end+1} = w;
        case 'fence', fenceWays{end+1} = w;
        case 'guard_rail', guardRailWays{end+1} = w;
        case 'jersey_barrier', jerseyBarrierWays{end+1} = w;
        case 'wall', wallWays{end+1} = w;
        case 'curbstone', curbstoneWays{end+1} = w;
        case 'traffic_sign', trafficSignWays{end+1} = w;
        case 'traffic_light', trafficLightWays{end+1} = w;
        case {'line_thin','line_thick','virtual','road_border','rail','keepout','symbol'}
            % Lane boundary types — handled via lanelet extraction
        otherwise
            if unmappedWays.isKey(wType), unmappedWays(wType) = unmappedWays(wType)+1;
            else, unmappedWays(wType) = 1; end
    end
end
```

#### Step 3c: Discover ALL Relation Types (MANDATORY — run immediately after 3b)

See [references/discoverRelations.md](references/discoverRelations.md) for the full categorization loop. Sorts all non-lanelet relations into: `trafficSignRels`, `speedLimitRels`, `rightOfWayRels`, `trafficLightRels`, `multipolygonRels` (struct with `.building`, `.parking`, `.vegetation`, `.traffic_island`, `.walkway`, `.exit`, `.keepout`), and `unmappedRels` (containers.Map with counts).

**Print discovery summary and unmapped elements.** Never silently drop anything.

### Step 4: Build Geometry

Resolve way geometry from nodes. See [references/extractGeometry.md](references/extractGeometry.md) for **mandatory** implementation patterns.

**GeoReference auto-detection:** If no `local_x`/`local_y` tags exist, compute centroid of all node lat/lon. Never use `[0 0]`. See [references/detectGeoReference.md](references/detectGeoReference.md).

**Priority:** Use `local_x`/`local_y` node tags if available. Fall back to lat/lon → ENU (see [references/latlon2enu.md](references/latlon2enu.md)):
```matlab
east  = (lon - geoRef(2)) * 111320 * cosd(geoRef(1));
north = (lat - geoRef(1)) * 110540;
```

**MANDATORY: Handle closed-loop boundaries BEFORE direction detection.** If both boundaries are closed loops (start≈end gap < 1.0m), the overall direction vector is near-zero and `dot(leftOverall, rightOverall)` is unreliable (~0). This causes incorrect flips that produce center lines cutting across the track interior (e.g., 136m "width" instead of 6.5m). See `roadrunner-rrhd-authoring` skill's [references/splitClosedGeometry.md](../roadrunner-rrhd-authoring/references/splitClosedGeometry.md) for the full closed-loop boundary handling algorithm (local direction detection + start-point alignment).

**MANDATORY center line synthesis pipeline** — see `roadrunner-rrhd-authoring` skill's [references/synthesizeCenterLine.md](../roadrunner-rrhd-authoring/references/synthesizeCenterLine.md) for the full algorithm with code. Summary:
1. **Detect opposing boundaries:** Use closed-loop-aware detection (see `splitClosedGeometry.md` above)
2. **Resample to density-based point count** using arc-length `pchip` — `max(10, round(avgLen), nLeft, nRight)`
3. **Average** resampled boundaries for center line
4. **Enforce orthogonal endpoints** with 50% tangent blending (skip for closed-loop lanes)
5. **Do NOT modify boundary geometry** — use `Alignment` property instead

**CRITICAL: Do NOT apply orthogonal endpoint projection to boundary geometry.** Boundaries are shared between multiple lanes (including opposing-direction lanes). Modifying a shared boundary's endpoints to match one lane's center line direction will corrupt it for other lanes referencing the same boundary. The `Alignment` property handles the direction relationship.

**Boundary geometry rule:** Always store the ORIGINAL way geometry from OSM nodes. Compute alignment using the robust multi-sample algorithm (see `roadrunner-rrhd-authoring/references/alignmentRules.md`). Do NOT use a simple dot product of overall directions — this fails on curved geometry.

All geometry must be Nx3 (include Z from `ele` tag, default 0).

### Step 5: Split Closed Roads

RoadRunner cannot render self-closed geometry. See [references/splitClosedRoads.md](references/splitClosedRoads.md) and `roadrunner-rrhd-authoring` skill's [references/splitClosedGeometry.md](../roadrunner-rrhd-authoring/references/splitClosedGeometry.md) for the generic N-way orthogonal split algorithm.

Split using perpendicular cross-section projection at ALL joints (including closure). Use `roadrunner-rrhd-authoring/references/orthogonalSplit.md` for the full N-way algorithm.

### Step 6: Extract Topology

Use **boundary endpoint node matching** as primary method, with geometry proximity (1.0m threshold) as fallback. See [references/extractTopology.md](references/extractTopology.md).

**Critical rules:**
- Account for opposing boundary directions when matching nodes (use dp threshold of -0.3, proximity test for backward-right lanes)
- Apply **opposing-direction filter** using EFFECTIVE travel direction (reverse raw direction for backward-right lanes)
- Apply **left-gap filtering** to remove false successors where left boundary gap > 3m when a better alternative exists

### Step 7: Detect Junctions

See [references/extractJunctions.md](references/extractJunctions.md) for the full algorithm with code.

**Primary method:** Use `turn_direction` tag (`straight`, `left`, `right`) as the junction lane indicator.
**Fallback:** Lane is junction if (predecessor has >1 successors) OR (successor has >1 predecessors).

**Critical rules:**
- **BFS clustering with 8m threshold** — NOT union-find (causes transitive chaining across distant intersections). Post-filter: verify each member is within 12m of cluster centroid.
- **`boundary(pts,0.7)` for polygon shape** — produces good curved polygons. Use `convhull` selectively for junctions where `boundary()` concavity excludes lanes.
- **Min 2 lanes** per cluster (catches small T-intersections that 3-lane threshold misses)
- **Fallback: uncovered fan-in/fan-out nodes** — after primary clustering, detect nodes with >=2 lanes ending AND >=2 lanes starting but no junction coverage. Add junction from turn_direction lanes at those nodes.
- **Add non-turn lanes** to existing junctions when they pass through junction topology nodes (improves polygon coverage)
- **Strip markings** from all junction lane boundaries (don't assign ParametricAttributes)
- **Graceful fallback:** If detection is unreliable, skip junctions entirely — use `UseLaneGroups=true` in build options during import

### Step 8: Extract Semantics

See [references/extractSemantics.md](references/extractSemantics.md).

| Lanelet2 boundary subtype | RRHD Marking ID | Asset Path |
|---|---|---|
| `solid` | `SolidWhite` | `Assets/Markings/SolidSingleWhite.rrlms` |
| `dashed` | `DashedWhite` | `Assets/Markings/DashedSingleWhite.rrlms` |
| `solid_solid` | `SolidDoubleYellow` | `Assets/Markings/SolidDoubleYellow.rrlms` |
| `dashed_solid` | `DashedSolidYellow` | `Assets/Markings/DashedSolidYellow.rrlms` |
| `solid_dashed` | `DashedSolidYellow` | `Assets/Markings/DashedSolidYellow.rrlms` (+ `FlipLaterally=true`) |

| Lanelet2 subtype | RRHD LaneType |
|---|---|
| `road`, `highway`, `bus_lane` | `Driving` |
| `crosswalk`, `walkway` | **CurveMarking** (NOT a lane) |
| `bicycle_lane` | `Biking` |
| `emergency_lane` | `Shoulder` |
| `parking` | `Parking` |

**Travel direction:**
- `turn_direction` tag present → `"Forward"` (always unidirectional)
- `one_way=yes` → `"Forward"`
- Sidewalk/Curb → `"Undirected"`
- Otherwise → `"Bidirectional"`

### Step 8b: Filter Crosswalks/Walkways from Lane List

**BEFORE building RRHD lane objects**, separate lanelets by subtype:
- `subtype=crosswalk` or `subtype=walkway` → route to CurveMarkings (use center line as geometry, type = `SimpleCrosswalk`)
- All other subtypes → build as RRHD Lanes

**Never create a Lane object for crosswalk/walkway lanelets.** They become CurveMarking instances.

**CurveMarkingType extensions — do NOT confuse:**
- Stop lines → `.rrlms` (lane marking style): `Assets/Markings/StopLine.rrlms`
- Crosswalks → `.rrcws` (crosswalk style): `Assets/Markings/SimpleCrosswalk.rrcws`

Using `.rrcws` for stop lines causes "Asset file is missing" on import.

### Step 9: Build RRHD Objects

See [references/buildRRHD.md](references/buildRRHD.md) for complete construction patterns.

**Critical rules:**
- `rrMap = roadrunnerHDMap;` must come first (loads namespace). **WARNING:** On some systems, `roadrunnerHDMap` may launch a background RoadRunner instance. The import skill's connection logic handles this with retry — see `roadrunner-import-scene`. Do NOT call `roadrunner(InstallationFolder=...)` separately if `roadrunnerHDMap` already launched one.
- Create-then-assign pattern for all `roadrunner.hdmap.*` objects
- **Strip markings** from junction lane boundaries (simply don't assign ParametricAttributes)
- **NEVER modify boundary geometry** — store original OSM way node coordinates exactly as-is. Boundaries are shared between multiple lanes (including opposing-direction lanes). Any modification (flipping, endpoint projection, resampling) will corrupt the boundary for other lanes.
- **One boundary per way** — use `wayToBndID` map to deduplicate. First lanelet to reference a way creates the boundary; all others share it via alignment.
- **Detect boundary alignment FOR EVERY LANE** using the robust multi-sample algorithm in `roadrunner-rrhd-authoring` skill's [references/alignmentRules.md](../roadrunner-rrhd-authoring/references/alignmentRules.md). **NEVER hardcode `alignment = "Forward"` for all boundaries** — this is the #1 cause of bad scenes. **NEVER use overall direction (`geom(end,:)-geom(1,:)`) for spatial verification** — it fails on highly curved segments (e.g., split half-ovals where the chord direction doesn't represent travel direction). The algorithm has two steps: (1) proximity-based direction detection, (2) multi-sample local-tangent spatial verification with majority vote.

**Verified property names:** See `roadrunner-rrhd-authoring` skill's [references/apiReference.md](../roadrunner-rrhd-authoring/references/apiReference.md) for the complete class/property table. Key non-obvious mappings: `CurveMarking.MarkingTypeReference` (not CurveMarkingTypeID), `Barrier.BarrierTypeReference` (not BarrierTypeID), `Sign.Geometry` (GeoOrientedBoundingBox, not BoundingBox), `SpeedLimit.Value` + `.VelocityUnit="Kph"`, `ParametricAttribution.Span=[0 1]` (not StartFraction/EndFraction), `MarkingReference.MarkingID` takes a Reference object (not numeric).

**Critical:** Filter self-referencing topology (lane predecessor/successor pointing to itself) before writing — RoadRunner will error with "connectedLane.Object != this" on import.

### Step 10: Post-Processing (MANDATORY — do NOT skip)

**Snap connected endpoints** — successor start must match predecessor end (lane + boundaries). For each pred→succ pair with gap < 1.0m, snap succ start to pred end. See [references/snapEndpoints.md](references/snapEndpoints.md) and `roadrunner-rrhd-authoring` skill's [scripts/snapConnectedEndpoints.m](../roadrunner-rrhd-authoring/scripts/snapConnectedEndpoints.m).

**Height conflict resolution (MANDATORY):** Overlapping unconnected lanes at same Z cause grass artifacts. Bump narrower lane by +0.05m per Z-level using graph coloring. See `roadrunner-rrhd-authoring` skill's [scripts/resolveHeightConflicts.m](../roadrunner-rrhd-authoring/scripts/resolveHeightConflicts.m).

**Boundary deduplication (MANDATORY):** Opposing lanes in Lanelet2 reference different way IDs that may contain the same geometry reversed. The per-way `wayToBndID` deduplication only catches same-way reuse — geometry-based deduplication catches reversed duplicates. See `roadrunner-rrhd-authoring` skill's [references/deduplicateBoundaries.md](../roadrunner-rrhd-authoring/references/deduplicateBoundaries.md) for the algorithm.

### Step 11: Assemble & Write

Assign all arrays to `rrMap` (Lanes, LaneBoundaries, LaneMarkings, SpeedLimits, Junctions, CurveMarkingTypes, CurveMarkings, BarrierTypes, Barriers, SignTypes, Signs) and set `rrMap.GeoReference = geoRef` (1x2 `[lat, lon]`). Call `write(rrMap, outputFile)`. See [references/buildRRHD.md](references/buildRRHD.md).

**Junctions are optional:** If junction detection was skipped, omit `rrMap.Junctions` — defaults to empty. Use `UseLaneGroups=true` in build options during import.

## Step 9 Sub-Steps — Build ALL Non-Lane RRHD Objects

Step 9 MUST build ALL non-lane elements from Steps 3b/3c. See [references/extractNonLaneElements.md](references/extractNonLaneElements.md) for code patterns. Sub-steps: **9a** CurveMarkings (stop lines, crosswalks, bike markings), **9b** Barriers (fence, guard rail, jersey barrier, wall, curbstone), **9c** Signs (from ways AND relations — see [references/signCodeMapping.md](references/signCodeMapping.md) and [references/mapLanelet2SignCode.md](references/mapLanelet2SignCode.md) for sign type resolution), **9d** SpeedLimits, **9e** Placed Objects (see [references/placedObjects.md](references/placedObjects.md) for custom relation parsing).

### Enforcement Gate (MANDATORY — run before `write()`)

You MUST execute the validation block in [references/enforcementGate.md](references/enforcementGate.md). It catches the three most common conversion errors (alignment, spatial correctness, asset extensions, completeness). Do NOT skip or simplify it.

### After Write

Print unmapped element counts (buildings, vegetation, signals — not importable). Then use `roadrunner-import-scene` skill to import. See [references/importIntoRoadRunner.md](references/importIntoRoadRunner.md) for build options.

## Key Functions

| Function | Purpose |
|----------|---------|
| `xmlread(osmFile)` | Parse OSM XML into DOM document |
| `roadrunnerHDMap` | Create HD Map object (loads namespace) |
| `write(rrMap, file)` | Write HD Map to `.rrhd` file |
| `containers.Map` | Store parsed nodes, ways, relations |
| `pchip` / `interp1` | Arc-length resampling for center lines |
| `vecnorm` | Distance computations for clustering and proximity |
| `strsplit` | Parse compound type tags (`type/subtype`) |

## Conventions

- Store original OSM way node coordinates exactly as parsed — never modify boundary geometry
- Use `containers.Map` for all indexed lookups (nodes, ways, relations, geometry)
- All geometry is Nx3 with Z from `ele` tag (default 0)
- Use proximity-based BFS clustering for junctions (8m threshold + 12m centroid filter), never union-find
- Use `boundary(pts,0.7)` for junction polygons; `convhull` selectively for small junctions needing full coverage
- Print discovery summary after parsing — never silently drop unmapped elements
- Use `tiledlayout`/`nexttile` for multi-panel figures (not `subplot`)

----

Copyright 2026 The MathWorks, Inc.
