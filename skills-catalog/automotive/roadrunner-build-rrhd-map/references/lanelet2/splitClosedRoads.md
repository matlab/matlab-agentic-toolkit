# Split Closed Roads

## Description
Detects closed-loop lanelets and splits each into two open segments (`_A` and `_B`). RoadRunner cannot render self-closed roads. This is a Lanelet2-specific wrapper around the closed-loop split in [splitClosedGeometry.md](../authoring/splitClosedGeometry.md).

## Inputs
| Parameter | Type | Description |
|-----------|------|-------------|
| `lanelets` | struct array | Extracted lanelet structs |
| `ll2` | struct | Parsed OSM struct from `readOSM` |
| `geom` | containers.Map | wayID -> Nx3 geometry |
| `topo` | struct array | Topology structs parallel to lanelets |

## Outputs
- `lanelets` — updated array with split lanelets replacing originals
- `geom` — updated map with `_A`/`_B` suffixed geometry keys
- `topo` — updated topology with circular `A -> B -> A` wiring

## Algorithm (3 passes)

### Pass 1: Identify closed lanelets
Check each lanelet's center way: if `splitClosedGeometry` detects it as closed, OR the OSM way has first==last node ref, mark it for splitting.

### Pass 2: Split each closed lanelet
For each closed lanelet:
1. Split all 3 ways (center, left, right) at midpoint using `splitAtMidpoint`
2. Store as `wayID_A` and `wayID_B` in geom map
3. Create two lanelets: `id_A` and `id_B` with same subtype/speed/participants
4. Wire topology: A's predecessor = B, A's successor = B (circular)
5. B ends at A's start point for proper alignment at loop closure

### Pass 3: Update dangling references
For non-split lanelets that reference split lanelets:
- predecessor X -> X_B (end of X feeds into start)
- successor X -> X_A (start of X receives from end)
- neighbor X -> X_A

### Splitting at cross-section (not index midpoint)
**Critical:** Split boundaries at the **perpendicular cross-section through the center split point**, NOT at each boundary's own 50% arc length. Inner/outer boundaries have different curvatures, so same arc fraction ≠ same physical cross-section. Wrong cross-sections cause RoadRunner longitudinal alignment warnings.

```matlab
% 1. Split center at 50% arc length → get splitPt and tangent
% 2. For each boundary, find where the perpendicular plane intersects:
tangent2D = centerTangent(1:2) / norm(centerTangent(1:2));
projections = (bndPts(:,1:2) - centerSplitPt(1:2)) * tangent2D';
% Find zero-crossing (sign change) near the boundary midpoint
segIdx = find(diff(sign(projections)) ~= 0 & idx >= midIdx, 1);
% Interpolate exact crossing point
t = -projections(segIdx) / (projections(segIdx+1) - projections(segIdx));
bndSplitPt = bndPts(segIdx,:) + t * (bndPts(segIdx+1,:) - bndPts(segIdx,:));
```

### Both junctions need alignment
Apply the same perpendicular projection at BOTH split joints:
- **Midpoint junction** (A→B): project center midpoint tangent onto boundaries
- **Closure junction** (B→A): project center start tangent onto boundaries

Without closure alignment, boundary start/end points have longitudinal offsets (validated: ±0.14m on TestTrack).

## Example
```matlab
% "Closed roads split: 2 lanelet(s) -> 4 segments"
```

----

Copyright 2026 The MathWorks, Inc.

----
