# Alignment Rules — Lanes, Boundaries, and Travel Direction

**Reference implementation:** `scripts/detectAlignment.m`

Defines the geometry alignment conventions that prevent **green surface (grass/terrain)** rendering bugs in RoadRunner.

## Core Concept: Digitization Direction

Every geometric object has a direction defined by point order:
- **First point** = START
- **Last point** = END

All alignment is relative to this direction.

## Alignment Enum

| Value | Meaning |
|-------|---------|
| `Forward` | Referenced object runs **same direction** as the referring object |
| `Backward` | Referenced object runs **opposite direction** |

## Lane Boundary Alignment

`LeftLaneBoundary.Alignment` and `RightLaneBoundary.Alignment` describe how boundary geometry relates to **lane** geometry:

```
Forward:  lane start──────►lane end
          bnd start───────►bnd end    (same direction)

Backward: lane start──────►lane end
          bnd end◄─────────bnd start  (opposite direction)
```

### Detection Algorithm (Proximity + Multi-Sample Spatial Verification)

A simple dot product or overall direction vector is NOT sufficient — it fails on highly curved lanes (split half-ovals, U-turns, tight curves) where the chord direction (start→end) doesn't represent travel direction.

**Use this two-step algorithm:**

#### Step 1: Proximity-Based Direction

Compare boundary start/end distance to the lane center start point:

```matlab
% For each boundary independently:
dStartToLaneStart = norm(bndGeom(1,1:2) - centerGeom(1,1:2));
dEndToLaneStart   = norm(bndGeom(end,1:2) - centerGeom(1,1:2));
if dStartToLaneStart <= dEndToLaneStart
    alignment = "Forward";
else
    alignment = "Backward";
end
```

#### Step 2: Multi-Sample Spatial Verification

Sample multiple points along the center line, use LOCAL tangent at each to verify which side boundaries are on:

```matlab
nSamples = min(5, size(centerGeom,1)-1);
sampleIdx = round(linspace(2, size(centerGeom,1)-1, nSamples));
leftOnLeft = 0;
for si = 1:numel(sampleIdx)
    idx = sampleIdx(si);
    % Local tangent (NOT overall direction)
    localTan = centerGeom(min(idx+1,end),1:2) - centerGeom(max(idx-1,1),1:2);
    localTan = localTan / norm(localTan);
    localLeftN = [-localTan(2), localTan(1)];  % 90 deg CCW = left normal
    % Find closest point on left boundary to this center point
    distsL = vecnorm(leftBndGeom(:,1:2) - centerGeom(idx,1:2), 2, 2);
    [~, closestL] = min(distsL);
    toBndL = leftBndGeom(closestL,1:2) - centerGeom(idx,1:2);
    if dot(toBndL, localLeftN) > 0
        leftOnLeft = leftOnLeft + 1;
    end
end
% If left boundary is NOT on the left at majority of samples → swap left/right
if leftOnLeft < numel(sampleIdx)/2
    % Swap boundary assignments and recompute proximity alignment
end
```

**Why multi-sample?** The overall direction vector `geom(end,:) - geom(1,:)` fails catastrophically on half-oval segments where the chord cuts across the curve interior. Local tangent at each sample point always correctly identifies the geometric left/right regardless of overall curvature.

#### Simplified Algorithm for Map Conversion (Lanelet2-proven)

For converting maps where left/right boundary assignment is already known (e.g., Lanelet2 lanelets define which way is left vs right), a simpler approach works reliably:

```matlab
lDir = leftPts(end,:) - leftPts(1,:);
rDir = rightPts(end,:) - rightPts(1,:);
dp = dot(lDir(1:2)/(norm(lDir(1:2))+1e-10), rDir(1:2)/(norm(rDir(1:2))+1e-10));

if dp >= -0.3
    % Normal: both boundaries go same direction
    rightAlign = "Forward";
    leftAlign = "Forward";
else
    % Opposing boundaries: use proximity to determine which is backward
    d_ls_re = norm(leftPts(1,1:2) - rightPts(end,1:2));  % left start to right end
    d_ls_rs = norm(leftPts(1,1:2) - rightPts(1,1:2));    % left start to right start
    if d_ls_re < d_ls_rs
        % left_start near right_end → right is Backward
        rightAlign = "Backward";
        leftAlign = "Forward";
    else
        rightAlign = "Forward";
        leftAlign = "Backward";
    end
end
```

**Key insight:** The -0.3 threshold (not 0) handles lanes with slight boundary curvature that produce small negative dot products but are NOT truly opposing. True opposing boundaries (shared center lines between lanes going opposite directions) typically have dp < -0.7.

This approach is simpler than multi-sample verification because the source data guarantees correct left/right assignment. It has been validated on 184-lane Japanese urban maps with 46 backward-right boundaries.

#### Legacy Algorithm (d_starts/d_cross)

The `d_starts` vs `d_cross` approach below works for straight/mildly curved lanes but **MUST NOT be used as the sole spatial verification for highly curved geometry**. It is acceptable as a quick first-pass for typical road networks, but always validate with the multi-sample check above:

```matlab
d_starts = norm(leftGeom(1,1:2) - rightGeom(1,1:2));
d_cross  = norm(leftGeom(1,1:2) - rightGeom(end,1:2));

if d_starts <= d_cross
    % Both boundaries go same direction
    laneDir = (leftGeom(end,1:2)+rightGeom(end,1:2))/2 ...
            - (leftGeom(1,1:2)+rightGeom(1,1:2))/2;
    laneDir = laneDir / norm(laneDir);
    leftNormal = [-laneDir(2), laneDir(1)];
    toLeft = mean(leftGeom(:,1:2)) - mean(rightGeom(:,1:2));
    if dot(toLeft, leftNormal) >= 0
        leftAlign = "Forward"; rightAlign = "Forward";
    else
        leftAlign = "Backward"; rightAlign = "Backward";
    end
else
    % Boundaries go opposite directions
    laneDirA = leftGeom(end,1:2) - leftGeom(1,1:2);
    laneDirA = laneDirA / norm(laneDirA);
    leftNormalA = [-laneDirA(2), laneDirA(1)];
    toLB = mean(leftGeom(:,1:2)) - mean(rightGeom(:,1:2));
    if dot(toLB, leftNormalA) >= 0
        leftAlign = "Forward"; rightAlign = "Backward";
    else
        leftAlign = "Backward"; rightAlign = "Forward";
    end
end
```

**Why proximity first?** The d_starts vs d_cross comparison tells you whether the two boundary geometries were digitized in the same direction or opposing directions. This determines whether their alignments should match or be opposite.

**Why spatial verification?** The leftNormal check ensures the boundary assigned as "left" is actually on the geometric left side when looking in the lane's travel direction. Without this, you can get alignment values that are technically consistent (dot product passes) but physically wrong (boundaries swapped).

**Critical:** Use **overall direction** `(end - start)`, NOT first-segment direction `(2,:) - (1,:)`. First-segment fails for wide turn lanes where initial tangent is nearly perpendicular to overall direction.

## Left vs Right Boundary Determination

Standing at lane START, facing lane END:
- **Left boundary** = on your left-hand side
- **Right boundary** = on your right-hand side

### Verification Algorithm

```matlab
laneDir2D = laneGeom(end,1:2) - laneGeom(1,1:2);
laneDir2D = laneDir2D / norm(laneDir2D);
leftNormal = [-laneDir2D(2), laneDir2D(1)];  % 90 deg CCW rotation

centerToBnd = mean(bndGeom(:,1:2)) - mean(laneGeom(:,1:2));
if dot(centerToBnd, leftNormal) > 0
    % Boundary IS on the left → assign as LeftLaneBoundary
else
    % Boundary is on the right → assign as RightLaneBoundary
end
```

## Green Surface Bug — Root Causes

RoadRunner constructs road mesh by walking left boundary then right boundary (respecting alignment) and filling between them.

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Green grass on road | Left/Right boundaries swapped | Verify with cross product; swap assignment |
| Green patches at curves | Alignment Forward/Backward incorrect | Recompute dot product using overall direction |
| Half-lane green | Shared boundary has wrong alignment for one lane | Each lane computes alignment independently |
| Green at intersections | First-segment direction used | Use `geom(end,:) - geom(1,:)` |

## Travel Direction

Describes traffic flow relative to lane digitization direction:

| Value | Traffic flows... | Use case |
|-------|-----------------|----------|
| `Forward` | START → END (same as digitization) | Standard one-way lanes |
| `Backward` | END → START (opposite) | Opposing lane sharing geometry |
| `Bidirectional` | Both directions | Two-way undivided roads |
| `Undirected` | No dominant direction | Sidewalks, curbs, parking |

**TravelDirection does NOT affect surface rendering.** It only affects:
- Routing/navigation logic
- Lane arrow visualization in scenario editing
- Which end is entry/exit for actors

## Predecessor/Successor Alignment

| Alignment | Connection |
|-----------|-----------|
| `Forward` | Connected lane flows same direction (predecessor END → current START) |
| `Backward` | Connected lane flows opposite (predecessor START → current START) |

```
Forward predecessor:   [pred]────►  ────►[current]
                         end      start

Backward predecessor:  ◄────[pred]  ────►[current]
                       start        start
```

## Lane Group Alignment

`LaneGroup.Lanes[i].Alignment`:
- `Forward`: lane geometry same direction as LaneGroup geometry
- `Backward`: lane geometry opposite (allows opposing lanes in one group)

## Shared Boundary Between Adjacent Lanes

Each lane computes alignment **independently** against the same boundary:

```
Lane A (W→E):          ────────────►
Shared boundary (W→E): ────────────►  (Right of A → Forward, Left of B → Forward)
Lane B (W→E):          ────────────►

Lane A (W→E):          ────────────►
Shared boundary (E→W): ◄────────────  (Right of A → Backward, Left of B → Backward)
Lane B (W→E):          ────────────►
```

----

Copyright 2026 The MathWorks, Inc.
