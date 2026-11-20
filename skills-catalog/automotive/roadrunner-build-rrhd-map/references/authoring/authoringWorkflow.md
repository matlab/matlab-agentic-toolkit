# Author RRHD Maps from Scratch — Workflow, Gotchas, Enforcement Gate

## Key Rules

- **Always write to .m files** when executing code. Never put multi-line MATLAB code directly in `evaluate_matlab_code`. Write to a `.m` file, run with `run_matlab_file`, edit on error. Exception: if the user asks to "show the pattern" or says "do not execute", show code inline without writing files.
- **Read only the specific reference needed for the task** — do not read all references upfront. Use apiReference.md for property lookups, other references only when directly relevant.
- **Only build what the user asked for.** Do not add extra lanes, junctions, or objects unless explicitly requested.
- **`rrMap = roadrunnerHDMap;` must come first** — loads the namespace before any `roadrunner.hdmap.*` usage.
- **Never pass positional constructor arguments** — use create-then-assign or Name=Value (`roadrunner.hdmap.Lane(ID="L1")`).
- **Empty typed arrays** — use `ClassName.empty` not `[]`.
- **All geometry must be Nx3** — always include Z column (default 0 if flat).
- **Run enforcement gate before `write()`** — alignment, spatial, and geometry checks are mandatory.
- **Track maps (closed-loop ovals/circuits): OMIT topology (no Predecessors/Successors), OMIT marking attributes (no ParametricAttribution), OMIT Z bumps.** Use natural elevation only. See [references/orthogonalSplit.md](orthogonalSplit.md).

## Critical API Rules

**You MUST create a `roadrunnerHDMap` object before using any `roadrunner.hdmap.*` classes** (lazy namespace loading):
```matlab
rrMap = roadrunnerHDMap;  % REQUIRED — loads the namespace
```

**Constructors** — positional arguments always error. Create-then-assign works in every release:
```matlab
ref = roadrunner.hdmap.Reference;
ref.ID = "myID";  % assign after creation
```

**Name=Value constructors** — every `roadrunner.hdmap.*` class accepts Name=Value (verified R2026b: Reference, Lane, LaneBoundary, Junction, Polygon, Sign, CurveMarking, GeoOrientedBoundingBox, ...):
```matlab
rap = roadrunner.hdmap.RelativeAssetPath(AssetPath="Assets/Markings/StopLine.rrlms");
ar = roadrunner.hdmap.AlignedReference(Reference=ref, Alignment="Forward");
% WRONG: positional args error with "A name is expected"
```

**Empty typed arrays** — never use `[]` for typed properties:
```matlab
lane.Predecessors = roadrunner.hdmap.AlignedReference.empty;  % CORRECT
lane.Predecessors = [];  % WRONG: "Value must be of type AlignedReference"
```

## Verified Property Names (R2025a+)

See [references/apiReference.md](apiReference.md) for the complete verified class/property table. Key gotchas:

| Common Mistake | Correct |
|---|---|
| `LeftBoundary` | `LeftLaneBoundary` |
| `RightBoundary` | `RightLaneBoundary` |
| `Speed` | `Value` (int32) |
| `Unit = "KPH"` | `VelocityUnit = "Kph"` |
| `ParametricAttrib` | `ParametricAttribution` |
| `pa.Value = mr` | `pa.MarkingReference = mr` |
| `pa.StartFraction/EndFraction` | `pa.Span = [0 1]` (double array) |
| `JunctionPhase` / `Phase` (direct) | `Configurations` (JunctionConfiguration array with nested `.Phases`) |
| `roadrunnerHDMap("file.rrhd")` | `rrMap = roadrunnerHDMap; read(rrMap, "file.rrhd")` |
| Nx2 geometry | Nx3 geometry (always include Z column) |
| `cm.CurveMarkingTypeID` | `cm.MarkingTypeReference` |
| `b.BarrierTypeID` | `b.BarrierTypeReference` |
| `s.SignTypeID` | `s.SignTypeReference` |
| `s.BoundingBox` | `s.Geometry` (takes GeoOrientedBoundingBox) |
| `bb.Position` | `bb.Center` (1x3 double) |
| `bb.Orientation` | `bb.GeoOrientation` (`[roll pitch heading]`, radians) |
| `pg.OuterRing` | `pg.ExteriorRing` (Nx3 double) |
| `bt.AssetPath` | `bt.ExtrusionPath` (for BarrierType only) |
| `roadrunner.hdmap.GeoOrientation` | NOT a class — use a `[roll pitch heading]` double array (radians) |
| `Lane.Predecessors = []` | `Lane.Predecessors = roadrunner.hdmap.AlignedReference.empty` |
| `lb.ParametricAttributes = []` | `lb.ParametricAttributes = roadrunner.hdmap.ParametricAttribution.empty` |
| `RelativeAssetPath("path")` | `RelativeAssetPath(AssetPath="path")` — Name=Value required |
| `AlignedReference(ref, "Fwd")` | `AlignedReference(Reference=ref, Alignment="Forward")` |
| `Junction.Geometry = polygon` | `Junction.Geometry = multiPolygon` (wrap in MultiPolygon) |
| `MarkingReference.MarkingID = 5` | `MarkingReference.MarkingID = ref` (Reference object, NOT numeric) |
| `SpeedLimit.Velocity` | `SpeedLimit.Value` (int32) + `.VelocityUnit = "Kph"` |

## Synthetic Scene Construction

### Lane Width and Geometry

Standard lane width: **3.7m** (US highway). Compute boundary positions by offsetting perpendicular to the lane center line direction.

### Shared Boundaries Between Adjacent Lanes

**Adjacent lanes MUST share boundary geometry.** The right boundary of lane N is the same object as the left boundary of lane N+1. For N lanes, create N+1 boundaries.

```
  LB_0 (left edge)
  ───────────────────
  │    Lane_1        │  left=LB_0(Fwd), right=LB_1(Fwd)
  ───────────────────
  LB_1 (shared)
  ───────────────────
  │    Lane_2        │  left=LB_1(Fwd), right=LB_2(Fwd)
  ───────────────────
  LB_2 (right edge)
```

### Alignment Rules

See [references/alignmentRules.md](alignmentRules.md) for complete rules, diagrams, and green-surface debugging.

Alignment specifies how boundary geometry direction relates to lane geometry direction:
- **Same direction → `"Forward"`**
- **Opposite direction → `"Backward"`**

**Which algorithm to use:**
- **Map conversion** (left/right known from source, e.g., Lanelet2 roles) → dp-based approach below
- **Synthetic scenes** (left/right must be determined from geometry) → Multi-sample spatial verification in [references/alignmentRules.md](alignmentRules.md)

**Dp-based algorithm (for conversion — left/right already known):**

```matlab
lDir = leftPts(end,:) - leftPts(1,:);
rDir = rightPts(end,:) - rightPts(1,:);
dp = dot(lDir(1:2)/(norm(lDir(1:2))+1e-10), rDir(1:2)/(norm(rDir(1:2))+1e-10));

if dp >= -0.3
    % Normal: both boundaries go same direction
    leftAlign = "Forward"; rightAlign = "Forward";
else
    % Opposing boundaries: use proximity to determine which is backward
    d_ls_re = norm(leftPts(1,1:2) - rightPts(end,1:2));
    d_ls_rs = norm(leftPts(1,1:2) - rightPts(1,1:2));
    if d_ls_re < d_ls_rs
        leftAlign = "Forward"; rightAlign = "Backward";
    else
        leftAlign = "Backward"; rightAlign = "Forward";
    end
end
```

The -0.3 threshold (not 0) handles lanes with slight boundary curvature that produce small negative dot products but are NOT truly opposing.

**Left/Right spatial verification** (for synthetic scenes where left/right must be verified):
```matlab
nSamples = min(5, size(centerGeom,1)-1);
sampleIdx = round(linspace(2, size(centerGeom,1)-1, nSamples));
leftOnLeft = 0;
for si = 1:numel(sampleIdx)
    idx = sampleIdx(si);
    localTan = centerGeom(min(idx+1,end),1:2) - centerGeom(max(idx-1,1),1:2);
    localTan = localTan / norm(localTan);
    localLeftN = [-localTan(2), localTan(1)];
    distsL = vecnorm(leftBndGeom(:,1:2) - centerGeom(idx,1:2), 2, 2);
    [~, closestL] = min(distsL);
    toBndL = leftBndGeom(closestL,1:2) - centerGeom(idx,1:2);
    if dot(toBndL, localLeftN) > 0, leftOnLeft = leftOnLeft + 1; end
end
assert(leftOnLeft >= numel(sampleIdx)/2, ...
    'Left boundary is spatially on the RIGHT — swap boundaries or fix assignment');
```

Wrong alignment or swapped left/right causes **green grass instead of road surface**.

### Standard Marking Assets

| Marking ID | Asset Path |
|---|---|
| `SolidSingleWhite` | `Assets/Markings/SolidSingleWhite.rrlms` |
| `DashedSingleWhite` | `Assets/Markings/DashedSingleWhite.rrlms` |
| `SolidDoubleYellow` | `Assets/Markings/SolidDoubleYellow.rrlms` |
| `DashedSolidYellow` | `Assets/Markings/DashedSolidYellow.rrlms` |
| `DashedSolidYellow` (flipped) | `Assets/Markings/DashedSolidYellow.rrlms` with `FlipLaterally=true` |

### Multi-Lane Road Recipe

1. Compute N lane center lines (evenly spaced at `laneWidth` intervals)
2. Compute N+1 boundary lines (edges + between each lane pair)
3. Assign shared boundaries — same-direction: lane i uses `left=LB_(i-1)`, `right=LB_i`. **Opposing-traffic lanes: swap left/right** (driver's left is toward the road edge, not the center)
4. Detect alignment via dot product (boundaries going same direction as lane → Forward, opposite → Backward)
5. Apply markings (edges: `SolidSingleWhite`, divider: `SolidDoubleYellow`, separators: `DashedSingleWhite`)
6. Wire topology (if multiple segments, connect with pred/succ)
7. Assemble map and write

**Additional steps for converted maps only** (skip for synthetic scenes):
- Left-gap topology filter — see [references/leftGapFilter.md](leftGapFilter.md)
- Snap connected endpoints — see [scripts/snapConnectedEndpoints.m](../../scripts/snapConnectedEndpoints.m)
- Resolve height conflicts — see [scripts/resolveHeightConflicts.m](../../scripts/resolveHeightConflicts.m)
- Deduplicate boundaries — see [references/deduplicateBoundaries.md](deduplicateBoundaries.md)

### Complete 2-Lane Road Example

```matlab
rrMap = roadrunnerHDMap;
w = 3.7;

% Lane Markings
lm1 = roadrunner.hdmap.LaneMarking; lm1.ID = "SolidWhite";
rap1 = roadrunner.hdmap.RelativeAssetPath; rap1.AssetPath = "Assets/Markings/SolidSingleWhite.rrlms";
lm1.AssetPath = rap1;
lm2 = roadrunner.hdmap.LaneMarking; lm2.ID = "DashedWhite";
rap2 = roadrunner.hdmap.RelativeAssetPath; rap2.AssetPath = "Assets/Markings/DashedSingleWhite.rrlms";
lm2.AssetPath = rap2;

% Boundaries (3 for 2 lanes)
lb = roadrunner.hdmap.LaneBoundary;
lb(2) = roadrunner.hdmap.LaneBoundary;
lb(3) = roadrunner.hdmap.LaneBoundary;
lb(1).ID = "LB_0"; lb(1).Geometry = [0 w 0; 100 w 0];
lb(2).ID = "LB_1"; lb(2).Geometry = [0 0 0; 100 0 0];
lb(3).ID = "LB_2"; lb(3).Geometry = [0 -w 0; 100 -w 0];

% Markings on boundaries
for i = [1 3]  % solid on edges
    pa = roadrunner.hdmap.ParametricAttribution; pa.Span = [0 1];
    ref = roadrunner.hdmap.Reference; ref.ID = "SolidWhite";
    mr = roadrunner.hdmap.MarkingReference; mr.MarkingID = ref; mr.FlipLaterally = false;
    pa.MarkingReference = mr;
    lb(i).ParametricAttributes = pa;
end
pa = roadrunner.hdmap.ParametricAttribution; pa.Span = [0 1];
ref = roadrunner.hdmap.Reference; ref.ID = "DashedWhite";
mr = roadrunner.hdmap.MarkingReference; mr.MarkingID = ref; mr.FlipLaterally = false;
pa.MarkingReference = mr;
lb(2).ParametricAttributes = pa;

% Lanes
ln = roadrunner.hdmap.Lane;
ln(2) = roadrunner.hdmap.Lane;
ln(1).ID = "Lane_1"; ln(1).Geometry = [0 w/2 0; 100 w/2 0];
ln(1).TravelDirection = "Forward"; ln(1).LaneType = "Driving";
ln(2).ID = "Lane_2"; ln(2).Geometry = [0 -w/2 0; 100 -w/2 0];
ln(2).TravelDirection = "Forward"; ln(2).LaneType = "Driving";

% Assign boundaries with alignment
bndIDs = ["LB_0","LB_1","LB_2"];
for i = 1:2
    arL = roadrunner.hdmap.AlignedReference;
    refL = roadrunner.hdmap.Reference; refL.ID = bndIDs(i);
    arL.Reference = refL; arL.Alignment = "Forward";
    ln(i).LeftLaneBoundary = arL;

    arR = roadrunner.hdmap.AlignedReference;
    refR = roadrunner.hdmap.Reference; refR.ID = bndIDs(i+1);
    arR.Reference = refR; arR.Alignment = "Forward";
    ln(i).RightLaneBoundary = arR;
end

% Assemble and write
rrMap.Lanes = ln;
rrMap.LaneBoundaries = lb;
rrMap.LaneMarkings = [lm1 lm2];
write(rrMap, "two_lane_road.rrhd");
```

## Enforcement Gate (MANDATORY before `write()`)

Run this validation block before writing any multi-lane map. Do NOT skip. If any check FAILS, fix the issue (run the appropriate post-processing step) before proceeding to `write()`.

```matlab
%% --- ENFORCEMENT: Topology — no excessive connections (left-gap filter applied) ---
lanes = rrMap.Lanes;
nExcessiveJunc = 0;
for i = 1:numel(lanes)
    nConn = numel(lanes(i).Predecessors) + numel(lanes(i).Successors);
    if nConn > 4  % junction lanes should have at most ~4 (multi-lane merge/diverge)
        nExcessiveJunc = nExcessiveJunc + 1;
    end
end
if nExcessiveJunc > 0
    warning('TOPOLOGY WARNING: %d lanes have >4 connections — run left-gap filter (references/leftGapFilter.md)', nExcessiveJunc);
end
fprintf('Topology check: %d lanes with >4 connections\n', nExcessiveJunc);

%% --- ENFORCEMENT: Alignment matches geometry (every lane, every side) ---
% Alignment = boundary direction relative to the LANE geometry. All-Forward is correct for one-way roads;
% what must hold is that each reference agrees with the geometry. Majority vote over 3 samples per lane,
% using LOCAL tangents (robust on curves and split half-ovals).
bnds = rrMap.LaneBoundaries;
bndMap = containers.Map;
for i = 1:numel(bnds), bndMap(char(bnds(i).ID)) = bnds(i).Geometry; end
nFwd = 0; nBwd = 0; badAlign = strings(0, 1);
for i = 1:numel(lanes)
    lGeom = lanes(i).Geometry;
    if size(lGeom, 1) < 2, continue; end
    sIdx = unique(round(linspace(1, size(lGeom, 1) - 1, 3)));
    for side = ["LeftLaneBoundary", "RightLaneBoundary"]
        ar = lanes(i).(side);
        if ~bndMap.isKey(char(ar.Reference.ID)), continue; end
        bGeom = bndMap(char(ar.Reference.ID));
        if ar.Alignment == "Forward", nFwd = nFwd + 1; else, nBwd = nBwd + 1; end
        votes = 0;
        for si = sIdx
            lt = lGeom(si + 1, 1:2) - lGeom(si, 1:2);
            [~, c] = min(vecnorm(bGeom(:, 1:2) - lGeom(si, 1:2), 2, 2));
            c = min(max(c, 1), size(bGeom, 1) - 1);
            bt = bGeom(c + 1, 1:2) - bGeom(c, 1:2);
            votes = votes + sign(dot(lt, bt));
        end
        expected = "Forward"; if votes < 0, expected = "Backward"; end
        if votes ~= 0 && ar.Alignment ~= expected
            badAlign(end + 1) = string(lanes(i).ID) + "." + extractBefore(side, "LaneBoundary"); %#ok<SAGROW>
        end
    end
end
fprintf('Alignment: %d Forward, %d Backward (all-Forward is valid for one-way roads)\n', nFwd, nBwd);
assert(isempty(badAlign), ...
    'ALIGNMENT ERROR: %d boundary references disagree with geometry (e.g. %s) — set Alignment from the boundary direction relative to the lane (references/alignmentRules.md).', ...
    numel(badAlign), strjoin(badAlign(1:min(3, end)), ", "));
fprintf('Alignment-vs-geometry check: PASS\n');

%% --- ENFORCEMENT: Left boundary spatially on left (multi-sample, local tangent) ---
nBadSide = 0;
for i = 1:numel(lanes)
    lGeom = lanes(i).Geometry;
    if size(lGeom, 1) < 3 || ~bndMap.isKey(char(lanes(i).LeftLaneBoundary.Reference.ID)), continue; end
    leftBndGeom = bndMap(char(lanes(i).LeftLaneBoundary.Reference.ID));
    sampleIdx = round(linspace(2, size(lGeom, 1) - 1, min(5, size(lGeom, 1) - 1)));
    badCount = 0;
    for idx = sampleIdx
        localTan = lGeom(idx + 1, 1:2) - lGeom(idx - 1, 1:2);
        if norm(localTan) < 1e-6, continue; end
        localLeftN = [-localTan(2), localTan(1)];
        [~, cl] = min(vecnorm(leftBndGeom(:, 1:2) - lGeom(idx, 1:2), 2, 2));
        if dot(leftBndGeom(cl, 1:2) - lGeom(idx, 1:2), localLeftN) < 0, badCount = badCount + 1; end
    end
    if badCount > numel(sampleIdx) / 2, nBadSide = nBadSide + 1; end
end
assert(nBadSide == 0, ...
    'SPATIAL ERROR: %d lanes have left boundary on wrong side — swap left/right for those lanes.', nBadSide);
fprintf('Spatial left-side check (multi-sample): PASS\n');

%% --- ENFORCEMENT: Geometry is Nx3 ---
bnds = rrMap.LaneBoundaries;
for i = 1:numel(bnds)
    assert(size(bnds(i).Geometry, 2) == 3, ...
        'Boundary %s geometry must be Nx3 (got Nx%d)', bnds(i).ID, size(bnds(i).Geometry,2));
end
fprintf('Geometry dimensions: PASS\n');

%% --- ENFORCEMENT: GeoReference set ---
assert(any(rrMap.GeoReference ~= 0), 'GeoReference is [0,0] — set lat/lon origin');
fprintf('GeoReference: PASS\n');

%% --- ENFORCEMENT: No duplicate boundaries (deduplication applied) ---
bnds = rrMap.LaneBoundaries;
nDupBnd = 0;
for i = 1:numel(bnds)
    for j = i+1:numel(bnds)
        g1 = bnds(i).Geometry; g2 = bnds(j).Geometry;
        if size(g1,1) ~= size(g2,1), continue; end
        if max(vecnorm(g1 - flipud(g2), 2, 2)) < 0.001
            nDupBnd = nDupBnd + 1; break;
        end
    end
    if nDupBnd > 5, break; end  % early exit for performance
end
if nDupBnd > 0
    warning('DEDUP WARNING: Found reversed-duplicate boundaries — run deduplicateBoundaries (references/deduplicateBoundaries.md)');
end
fprintf('Boundary deduplication check: %d duplicates found\n', nDupBnd);
```

## Post-Processing (MANDATORY — execute in order before `write()`)

### Left-Gap Topology Filter (MANDATORY for converted maps)

Removes false predecessor/successor connections caused by shared boundary endpoint nodes. For each lane with multiple successors (or predecessors), computes left boundary gap — if any connection has gap < 3m and others > 3m, removes the far ones. **Without this, junction lanes get 2-4x too many connections.** See [references/leftGapFilter.md](leftGapFilter.md).

### Endpoint Snapping

For connected lanes (pred/succ), snap successor start to predecessor end. See [scripts/snapConnectedEndpoints.m](../../scripts/snapConnectedEndpoints.m) and [references/snapEndpoints.md](snapEndpoints.md).

### Height Conflict Resolution

Overlapping unconnected lanes at the same Z cause grass artifacts. Use graph coloring to assign Z-levels. See [scripts/resolveHeightConflicts.m](../../scripts/resolveHeightConflicts.m) and [references/resolveHeights.md](resolveHeights.md).

### Boundary Deduplication (MANDATORY for converted maps)

When building from source formats that assign separate boundary objects to opposing lanes (Lanelet2, HERE, NDS, etc.), scan all boundary pairs for identical geometry (forward or reversed within 1mm tolerance). Merge duplicates and update lane references with flipped alignment. **Without this step, shared boundaries render doubled markings.** See [references/deduplicateBoundaries.md](deduplicateBoundaries.md).

## Additional Entity Types

For all entity classes (Signs, Signals, Barriers, Parking, CurveMarkings, StencilMarkings, StaticObjects, LaneGroups), see the class/property table in [references/apiReference.md](apiReference.md). Key references by task:

| Task | Reference |
|------|-----------|
| Junction polygon construction | [references/junctionPolygon.md](junctionPolygon.md) |
| Geometry algorithms (split, resample, center line) | [references/orthogonalSplit.md](orthogonalSplit.md), [references/splitClosedGeometry.md](splitClosedGeometry.md), [references/synthesizeCenterLine.md](synthesizeCenterLine.md) |
| Post-processing (dedup, filter, snap, heights) | [references/deduplicateBoundaries.md](deduplicateBoundaries.md), [references/leftGapFilter.md](leftGapFilter.md), [references/snapEndpoints.md](snapEndpoints.md), [references/resolveHeights.md](resolveHeights.md) |
| Validation before write() | [references/validateMap.md](validateMap.md) |

## Key Functions

| Function | Purpose |
|----------|---------|
| `roadrunnerHDMap` | Create HD Map object (loads namespace) |
| `read(rrMap, file)` | Read existing `.rrhd` file |
| `write(rrMap, file)` | Write HD Map to `.rrhd` file |
| `roadrunner.hdmap.Lane` | Lane entity (Geometry, TravelDirection, LaneType) |
| `roadrunner.hdmap.LaneBoundary` | Boundary entity (Geometry, ParametricAttributes) |
| `roadrunner.hdmap.LaneMarking` | Marking definition (ID, AssetPath) |
| `roadrunner.hdmap.Junction` | Junction area (Geometry as MultiPolygon) |
| `roadrunner.hdmap.AlignedReference` | Reference with alignment (Name=Value constructor) |
| `roadrunner.hdmap.RelativeAssetPath` | Asset path wrapper (Name=Value constructor) |
| `roadrunner.hdmap.ParametricAttribution` | Marking placement (Span, MarkingReference) |

## Known Limitations

- SignalTypes/Signals survive RRHD write/read in MATLAB, but RoadRunner **silently ignores** them on scene import — signals will not appear in the RoadRunner scene
- RoadRunner cannot render self-closing lanes — split using N-way orthogonal algorithm (see [references/orthogonalSplit.md](orthogonalSplit.md))
- Geometry must always be Nx3 (include Z=0 if flat)
- For track maps (closed-loop ovals): omit topology (Predecessors/Successors), Z bumps, and marking attributes (ParametricAttribution) — see orthogonalSplit.md Track-Specific Guidance

## Conventions

- Always use create-then-assign pattern for `roadrunner.hdmap.*` objects
- Use `RelativeAssetPath(AssetPath="...")` and `AlignedReference(Reference=ref, Alignment="...")` — Name=Value, never positional
- Use `ClassName.empty` for empty typed arrays, never `[]`
- All geometry is Nx3 with Z column (default 0 for flat terrain)
- Shared boundaries: one object per way, multiple lanes reference with different alignments

----

Copyright 2026 The MathWorks, Inc.

----
