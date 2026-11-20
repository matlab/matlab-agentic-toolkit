# Lanelet2 to RRHD Conversion Pipeline

Convert a Lanelet2 `.osm` file to a RoadRunner HD Map `.rrhd`. Execute every step in order.

## Key Rules

- **Write generated code to `.m` files** and run with `run_matlab_file`; edit on error. Exception: the user asks to "show the pattern" or "do not execute".
- **Call the skill's `scripts/` functions** (`parseOSM`, `discoverWayTypes`, `detectAlignment`, `resolveSignAsset`, `snapConnectedEndpoints`, `resolveHeightConflicts`, `validateRRHD`) — generated scripts run in their own folder, so start with `addpath(<skill>/scripts)` and end with `rmpath(...)`. Do not define local functions in generated scripts — keep other logic inline or in anonymous functions.
- **ALL steps are mandatory.** The map is incomplete without junctions, curve markings, barriers, signs, and speed limits. Every discovered element is either built or reported as unmapped.
- **Boundary geometry is immutable** — see Invariant 1.
- **One boundary object per way** (`wayToBndID`); **detect alignment for every lane** — never hardcode `"Forward"`.
- **Center line density ≥ 1 point per meter** — `max(10, round(avgLen), nLeft, nRight)`.
- **Run the enforcement gate before `write()`.**

## Scope

| Input | Action |
|---|---|
| Lanelet2 OSM (`type=lanelet` relations) | Convert |
| Standard OpenStreetMap (`highway=*` ways, no `type=lanelet` relations) | Stop: "This file appears to be a standard OpenStreetMap road network, not a Lanelet2 map. Only Lanelet2 OSM → RRHD conversion is supported." |
| Lanelet2 routing graph (`*.rg.osm`: no relations, ways tagged `routing_cost`/`relation`) | Stop: "This is a Lanelet2 routing-graph export (lanelets as nodes, routing edges as ways). It contains no lane geometry — convert the source `lanelet2_map.osm` instead." |

Related references (load on demand): [authoring/](../authoring/apiReference.md) for `roadrunner.hdmap.*` construction (Step 9) and [assets/](../assets/assetCatalog.md) for asset paths (Steps 8–9). This pipeline owns everything Lanelet2-specific; format-agnostic construction lives in the authoring references.

## Geometry Invariants

1. **Boundary geometry is immutable.** Store way geometry exactly as computed in Step 4. Never flip, resample, or project boundary points — use `Alignment="Backward"`. The only sanctioned edit is endpoint snapping of connected lanes (gap < 1 m) in Step 10.
2. **One boundary object per way.** Multiple lanes reference the same boundary with independent alignments.
3. **Alignment per lane** — dot product, proximity, and an inverted-lanelet check:
   ```matlab
   lDir = lPts(end,1:2) - lPts(1,1:2);  lDir = lDir / (norm(lDir) + 1e-10);
   rDir = rPts(end,1:2) - rPts(1,1:2);  rDir = rDir / (norm(rDir) + 1e-10);
   dp = dot(lDir, rDir);
   if dp >= -0.3
       % Same digitization direction. Lanelet2 requires the left way on the LEFT of travel;
       % if it is geometrically on the right, the lanelet is driven AGAINST its ways.
       travel = lDir + rDir;
       leftSide = dot(mean(lPts(:,1:2),1) - mean(rPts(:,1:2),1), [-travel(2), travel(1)]);
       if leftSide >= 0
           leftAlign = "Forward";  rightAlign = "Forward";
       else
           leftAlign = "Backward"; rightAlign = "Backward";   % inverted lanelet
       end
   elseif norm(lPts(1,1:2) - rPts(end,1:2)) < norm(lPts(1,1:2) - rPts(1,1:2))
       leftAlign = "Forward";  rightAlign = "Backward";       % opposing, right reversed
   else
       leftAlign = "Backward"; rightAlign = "Forward";        % opposing, left reversed
   end
   ```
   Orient copies of the boundaries by these alignments before synthesizing the center line, so the lane runs in the travel direction. Then confirm with `detectAlignment(center, lPts, rPts)`; report (do not silently accept) any lane where the two disagree.
4. **Center line density ≥ 1 point per meter.**
5. **Orthogonal endpoints on the center line only** — never on boundaries.
6. **Closed loop** = boundary whose start and end are within 1.0 m **and** whose length is > 10 m. Short lanelets (< 10 m, often sub-meter connectors) are not loops.
   ```matlab
   isClosed = @(g) norm(g(1,:) - g(end,:)) < 1.0 && sum(vecnorm(diff(g), 2, 2)) > 10;
   ```

## MATLAB Script Constraints

- **Empty typed arrays** — `ClassName.empty`, never `[]`.
- **Constructors** — never positional (`RelativeAssetPath("path")` errors with "A name is expected"); use Name=Value (`RelativeAssetPath(AssetPath=...)`, `AlignedReference(Reference=..., Alignment=...)`) or create-then-assign.
- **`containers.Map`** — never assign `map(key) = []`; cast numeric values with `double(...)` before trigonometry.
- **No chained indexing** — `geomMap(k)(:,1)` is invalid; assign to a temporary first.
- **`unique()` on cells** — use cellstr or convert with `string(...)`.
- **Struct fields before appending** — set `w.wayID = wid;` then `list{end+1} = w;`.
- **A `for` loop over an empty 0×1 array runs once** — iterate with `for j = reshape(v, 1, [])`.

## Pipeline

### Step 1: Parse OSM

```matlab
ll2 = parseOSM(osmFile);                          % scripts/parseOSM.m
nodes = ll2.nodes; ways = ll2.ways; relations = ll2.relations;
```
Node structs: `lat`, `lon`, `ele`, `local_x`, `local_y`. Way structs: `nodeRefs` (string array), `tags`. Relation structs: `members` (`type`, `ref`, `role`), `tags`. See [readOSM.md](readOSM.md).

### Step 2: Validate Format

```matlab
relKeys = relations.keys;
isLaneletRel = cellfun(@(k) relations(k).tags.isKey('type') && strcmp(relations(k).tags('type'), 'lanelet'), relKeys);
if ~any(isLaneletRel)
    wk = ways.keys;
    if relations.Count == 0 && ~isempty(wk) && ways(wk{1}).tags.isKey('routing_cost')
        fprintf(1, 'UNSUPPORTED FORMAT: Lanelet2 routing-graph export (no lane geometry). Convert the source lanelet2_map.osm instead.
');
    else
        fprintf(1, 'UNSUPPORTED FORMAT: no type=lanelet relations — not a Lanelet2 map (standard OpenStreetMap is not supported).
');
    end
    return   % stop the pipeline cleanly — report the reason to the user; write nothing
end
```

Stop at this check and tell the user why. Do not write an `.rrhd` or continue with a partial conversion.

### Step 3: Extract Lanelets and Discover Everything Else

Run 3a–3c in the same script.

**3a — Lanelets** ([extractLanelets.md](extractLanelets.md)): for each `type=lanelet` relation take `role=left` / `role=right` way IDs and the tags `subtype`, `one_way`, `speed_limit`, `turn_direction` (some maps use `turning_dir`), `location`.

**3b — Ways** (no whitelist):
```matlab
disc = discoverWayTypes(ways);                    % scripts/discoverWayTypes.m — each way has .wayID
stopLineWays = disc.stopLineWays; pedestrianMarkingWays = disc.pedestrianMarkingWays;
zebraMarkingWays = disc.zebraMarkingWays; bikeMarkingWays = disc.bikeMarkingWays; zigzagWays = disc.zigzagWays;
fenceWays = disc.fenceWays; guardRailWays = disc.guardRailWays; jerseyBarrierWays = disc.jerseyBarrierWays;
wallWays = disc.wallWays; curbstoneWays = disc.curbstoneWays;
trafficSignWays = disc.trafficSignWays; trafficLightWays = disc.trafficLightWays;
uk = disc.unmapped.keys;
for k = 1:numel(uk), fprintf('UNMAPPED way type %s: %d\n', uk{k}, disc.unmapped(uk{k})); end
```

**3c — Relations**: categorize every non-lanelet relation with [discoverRelations.md](discoverRelations.md) (`trafficSignRels`, `speedLimitRels`, `rightOfWayRels`, `trafficLightRels`, `multipolygonRels`, `unmappedRels`). Print the discovery summary — never silently drop anything.

### Step 4: Coordinates and Geometry

1. Resolve the origin, project nodes once, and build `geomMap` (wayID → Nx3) with [coordinates.md](coordinates.md). Keep source elevation.
2. Handle closed-loop boundaries (Invariant 6) **before** direction detection — see [splitClosedGeometry.md](../authoring/splitClosedGeometry.md).
3. Compute alignment per lanelet (Invariant 3), then synthesize the center line with [synthesizeCenterLine.md](../authoring/synthesizeCenterLine.md) and [extractGeometry.md](extractGeometry.md): arc-length `pchip` resampling, averaging, orthogonal endpoints (skip for closed loops).

### Step 5: Split Closed Roads

RoadRunner cannot render self-closing geometry. Split closed loops (Invariant 6) at perpendicular cross-sections — [splitClosedRoads.md](splitClosedRoads.md), [orthogonalSplit.md](../authoring/orthogonalSplit.md).

### Step 6: Topology

Match **effective** boundary endpoint nodes (respecting each lane's alignment — for Backward boundaries the effective start is the last node), with 1.0 m center-line proximity as fallback. Then apply the opposing-direction filter (effective travel directions, dp < −0.3 rejected) and the left-gap filter. See [extractTopology.md](extractTopology.md) and [leftGapFilter.md](../authoring/leftGapFilter.md). Remove self-references.

### Step 7: Junction Lanes (deferred)

Junctions are detected geometrically from the built lanes in Step 9 — see [extractJunctions.md](extractJunctions.md). `turn_direction` / `turning_dir` tags are not required.

### Step 8: Semantics

Markings, lane types, speed limits: [extractSemantics.md](extractSemantics.md); asset paths: [laneMarkings.md](../assets/laneMarkings.md).

| Lanelet2 subtype | RRHD |
|---|---|
| `road`, `highway`, `bus_lane` | Lane, `Driving` |
| `bicycle_lane` | Lane, `Biking` |
| `emergency_lane`, `road_shoulder` | Lane, `Shoulder` |
| `parking` | Lane, `Parking` |
| any subtype with `participant:vehicle=no` + `participant:bicycle=yes` | Lane, `Biking` (participant tags win) |
| any subtype with `participant:vehicle=no` + `participant:pedestrian=yes` | Lane, `Sidewalk` |
| `crosswalk`, `walkway` | **CurveMarking** (`SimpleCrosswalk`), never a Lane |

**Travel direction** (relative to the synthesized center line, which runs in the travel direction):

| Condition | `TravelDirection` |
|---|---|
| `turn_direction` / `turning_dir` present | `"Forward"` |
| `one_way=no` | `"Bidirectional"` |
| `one_way=yes` **or tag absent** (Lanelet2 default for vehicle lanelets) | `"Forward"` |
| Sidewalk / curb lane types | `"Undirected"` |

**Speed limits** — values may carry units (`"100.000000 km/h"`, `"30 mph"`); never `str2double` the raw tag:
```matlab
parseSpeed = @(s) str2double(regexp(char(s), '^\s*([\d.]+)', 'tokens', 'once'));
isMph = @(s) contains(lower(string(s)), "mph");
% Lanelet tag speed_limit; regulatory element tags max_speed / speed_limit, else trailing number of sign_type ("de274-30")
```
Set `SpeedLimit.VelocityUnit = "Mph"` for mph values, `"Kph"` otherwise.

**Crosswalks / curve markings** — stop lines `.rrlms`, crosswalks `.rrcws`; see [assetCatalog.md](../assets/assetCatalog.md).

### Step 9: Build RRHD Objects

Construction patterns: [buildRRHD.md](buildRRHD.md); class/property table: [apiReference.md](../authoring/apiReference.md).

- `rrMap = roadrunnerHDMap;` first. On some systems it starts a background RoadRunner; do not launch another one — see [importScene.md](../import/importScene.md).
- Boundaries from `geomMap` exactly (Invariant 1); markings from the way subtype (junction-only boundaries are stripped after junction detection).
- Lanes with per-lane alignment (Invariant 3), travel direction and speed limits (Step 8), topology (Step 6); then the left-gap filter.
- **Junctions:** `detectJunctions(lanes, laneBoundaries)`, then strip markings from boundaries used only by junction lanes — [extractJunctions.md](extractJunctions.md).
- Non-lane elements — [extractNonLaneElements.md](extractNonLaneElements.md): **9a** curve markings (stop lines, pedestrian/zebra markings, crosswalk lanelets), **9b** barriers ([barriers.md](../assets/barriers.md)), **9c** signs — one per physical sign, resolved with `resolveSignAsset` ([signs.md](../assets/signs.md)), **9d** speed limits, **9e** placed objects ([placedObjects.md](placedObjects.md)).

### Step 10: Post-Processing

1. **Snap connected endpoints** (gap < 1 m) — [snapEndpoints.md](../authoring/snapEndpoints.md), `snapConnectedEndpoints`.
2. **Height conflicts** — `resolveHeightConflicts(lanes, laneBoundaries, JunctionLaneIDs=jInfo.junctionLaneIDs)` raises one side of each crossing of unconnected lanes **outside junctions** by 0.15 m **on top of the source elevation**; crossings already ≥ 2 m apart (bridges) and crossings between junction lanes (at grade by design) are left alone. Skip for closed-loop track maps. See [resolveHeights.md](../authoring/resolveHeights.md).
3. **Boundary deduplication** — reversed duplicate ways between opposing lanes: [deduplicateBoundaries.md](../authoring/deduplicateBoundaries.md).

### Step 11: Gate and Write

Run [enforcementGate.md](enforcementGate.md) verbatim, set `rrMap.GeoReference = geoRef` (1x2), then `write(rrMap, outputFile)`. If junction detection was skipped, leave `rrMap.Junctions` empty. Print counts of everything built and everything unmapped (traffic lights, right-of-way, buildings, vegetation — not importable). To view the result, continue with [importScene.md](../import/importScene.md) and [buildOptions.md](../import/buildOptions.md).

## Conventions

- Source geometry is projected once and never modified (except Step 10 snapping)
- `containers.Map` for indexed lookups; `geomMap` for all way geometry
- Nx3 geometry with source elevation
- Junctions from overlapping lane footprints (`detectJunctions`), never proximity or union-find merging
- Print a discovery summary; report every unmapped type with its count
- `tiledlayout`/`nexttile` for multi-panel figures

----

Copyright 2026 The MathWorks, Inc.

----
