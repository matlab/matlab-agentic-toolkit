# Junction Polygon Construction

Computes a junction polygon by tracing the outer boundary geometry of junction lanes. Reusable for both Lanelet2 conversion and from-scratch RRHD authoring.

## When to Use

- Building junction polygons from a set of junction lane boundaries
- Converting Lanelet2 maps with `turn_direction` tags
- Authoring RRHD from scratch where junction areas need explicit polygons

## Algorithm: Trace Outer Boundary Geometry

The junction polygon must **follow the actual boundary polylines** — straight where boundaries are straight, curved where boundaries curve naturally. It must NOT use point-cloud hulls (`boundary()`, `convhull`) or spline smoothing.

### Step 1: Identify Outer Boundaries

Count how many times each boundary is referenced within the junction cluster. **Outer boundaries** are referenced exactly ONCE. Internal shared boundaries (referenced by 2+ junction lanes) are lane dividers inside the junction and must be excluded.

```matlab
bndWayCount = containers.Map('KeyType','char','ValueType','double');
for j = 1:numel(junctionLaneIndices)
    leftBndID = getLeftBoundaryID(junctionLaneIndices(j));
    rightBndID = getRightBoundaryID(junctionLaneIndices(j));
    if bndWayCount.isKey(leftBndID), bndWayCount(leftBndID) = bndWayCount(leftBndID)+1;
    else, bndWayCount(leftBndID) = 1; end
    if bndWayCount.isKey(rightBndID), bndWayCount(rightBndID) = bndWayCount(rightBndID)+1;
    else, bndWayCount(rightBndID) = 1; end
end

% Collect outer boundary polylines (count == 1)
outerSegs = {};
bndKeys = bndWayCount.keys;
for b = 1:numel(bndKeys)
    if bndWayCount(bndKeys{b}) == 1
        outerSegs{end+1} = getBoundaryGeometry(bndKeys{b});  % Nx2 polyline
    end
end
```

### Step 2: Chain Segments into Connected Perimeter

Order outer boundary segments by greedy nearest-endpoint chaining. Flip segments when the end point is closer than the start point. This produces a single closed polyline that traces the junction perimeter exactly.

```matlab
nSegs = numel(outerSegs);
used = false(1, nSegs);
used(1) = true;
orderedPts = outerSegs{1};

for iter = 1:nSegs-1
    currentEnd = orderedPts(end,:);
    bestDist = inf; bestIdx = 0; bestFlip = false;

    for s = 1:nSegs
        if used(s), continue; end
        seg = outerSegs{s};
        dStart = norm(currentEnd - seg(1,:));
        dEnd = norm(currentEnd - seg(end,:));
        if dStart < bestDist
            bestDist = dStart; bestIdx = s; bestFlip = false;
        end
        if dEnd < bestDist
            bestDist = dEnd; bestIdx = s; bestFlip = true;
        end
    end

    if bestIdx == 0, break; end
    used(bestIdx) = true;
    seg = outerSegs{bestIdx};
    if bestFlip, seg = flipud(seg); end

    % Append (skip first point if close to current end to avoid duplicate)
    if norm(seg(1,:) - currentEnd) < 0.2
        orderedPts = [orderedPts; seg(2:end,:)];
    else
        orderedPts = [orderedPts; seg];
    end
end

% Close the polygon
if norm(orderedPts(1,:) - orderedPts(end,:)) > 0.1
    orderedPts = [orderedPts; orderedPts(1,:)];
end

meanZ = computeMeanZFromLanes();
polygonPts3D = [orderedPts, ones(size(orderedPts,1),1)*meanZ];
```

### Step 3: Assign to Junction Object

```matlab
jObj = roadrunner.hdmap.Junction;
jObj.ID = junctionID;
pg = roadrunner.hdmap.Polygon;
pg.ExteriorRing = polygonPts3D;  % Nx3
mp = roadrunner.hdmap.MultiPolygon;
mp.Polygons = pg;
jObj.Geometry = mp;
```

## Critical Rules

| Rule | Rationale |
|------|-----------|
| Use ONLY outer boundaries (count == 1) | Internal shared boundaries cause polygon to shrink at straight-through lanes |
| Trace actual polyline geometry | Preserves straight edges as straight, curves as natural curves |
| Greedy nearest-endpoint chaining | Orders segments into a connected perimeter without distortion |
| Prefer outer boundary chaining over `boundary()`/`convhull` | Point-cloud hulls produce artificial shapes that don't follow actual road geometry |
| Do NOT use spline smoothing | Adds artificial curves where edges should be straight |
| Endpoint chaining tolerance = 0.2m | Skip duplicate junction points when connecting adjacent segments |

## Alternative: `boundary()` with Shrink Factor (Lanelet2 Conversion)

For **Lanelet2 conversion** where junctions are inferred from `turn_direction` clustering, `boundary(pts(:,1), pts(:,2), 0.7)` is an acceptable alternative when outer boundary chaining is impractical (e.g., short junction lanes where boundaries don't form a clean perimeter). This produces good curved polygons for most intersections.

**When to use convhull instead:** If `boundary(0.7)` creates concave indentations that visually exclude junction lanes (common for small 2-3 lane junctions with non-turn-direction lanes added), use `convhull` for those specific junctions while keeping `boundary(0.7)` for the rest.

```matlab
% Default: boundary(0.7) for curved polygons
k = boundary(allJuncPts(:,1), allJuncPts(:,2), 0.7);
chain = allJuncPts(k,:);

% Specific junctions needing full coverage: convhull
k = convhull(allJuncPts(:,1), allJuncPts(:,2));
chain = allJuncPts(k,:);
```

## Common Failures

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Polygon pinches at straight lanes | Used `boundary()` with high shrink | Reduce shrink or use convhull for that junction |
| Straight edges cutting across curves | Used `convhull` globally | Use `boundary(0.7)` for most, convhull selectively |
| Artificial curves at straight edges | Applied spline smoothing | Use raw boundary geometry — no smoothing |
| Polygon inside/smaller than lanes | Included internal shared boundaries | Use only outer boundaries (count == 1) |
| Giant polygon spanning 200m+ | Cluster threshold too large (30m) | Reduce to 8m for BFS clustering |
| Disconnected polygon | Chaining tolerance too tight | Use 0.2m tolerance for endpoint matching |
| Junction doesn't cover all lanes | Only used turn_direction lanes for polygon | Include non-turn lanes at junction nodes |

## Why Outer-Only Boundaries?

Internal boundaries (shared between two junction lanes) are lane dividers INSIDE the junction. Including them in polygon construction causes:
- Polygon shrinkage where straight-through lanes extend beyond turning lanes
- The polygon cuts inward to follow internal dividers instead of the junction perimeter

By using only boundaries referenced once (the exterior perimeter), the polygon naturally encompasses all junction lanes from the outside.

## Typical Results

| Intersection Type | Lanes | Outer Segments | Polygon Points |
|-------------------|-------|----------------|----------------|
| Small T-intersection | 5-6 | 6 | ~76-87 |
| Standard 4-way | 12 | 12-24 | ~150-285 |
| Oversized (BAD) | 22+ | — | Reduce cluster threshold |

----

Copyright 2026 The MathWorks, Inc.
