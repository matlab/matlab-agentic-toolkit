# Detect Junctions from Overlapping Lane Footprints

Build junctions **after** lanes, boundaries, and topology exist (Step 9, after the left-gap filter) with [scripts/detectJunctions.m](../../scripts/detectJunctions.m). It works for every Lanelet2 dialect — `turn_direction`, `turning_dir`, or no turn tags at all.

```matlab
[junctions, jInfo] = detectJunctions(lanes, laneBoundaries);
fprintf('Junctions: %d (lanes per junction %s) | dropped: %d < 15 m^2\n', jInfo.nJunctions, ...
    mat2str(jInfo.laneCounts'), jInfo.nDroppedSmall);

% Strip markings from boundaries used only by junction lanes
isJ = ismember(arrayfun(@(l) string(l.ID), lanes(:)), jInfo.junctionLaneIDs);
useAll = strings(0, 1); useJ = strings(0, 1);
for i = 1:numel(lanes)
    b = [string(lanes(i).LeftLaneBoundary.Reference.ID), string(lanes(i).RightLaneBoundary.Reference.ID)];
    useAll = [useAll, b]; if isJ(i), useJ = [useJ, b]; end %#ok<AGROW>
end
onlyJ = setdiff(unique(useJ), unique(useAll(~ismember(useAll, useJ))));
for k = 1:numel(laneBoundaries)
    if ismember(string(laneBoundaries(k).ID), onlyJ)
        laneBoundaries(k).ParametricAttributes = roadrunner.hdmap.ParametricAttribution.empty;
    end
end
```

## How it works

| Rule | Why |
|---|---|
| Footprint = left boundary + reversed right boundary (respecting alignment) | Real lane area, not a point cloud |
| Two lanes link when their footprints overlap by > 0.01 m² | Turn and through lanes inside an intersection overlap; plain road does not. Small overlaps left unlinked become RoadRunner sliver junctions |
| Predecessor/successor pairs never link; boundary-sharing neighbours need ≥ 25% overlap | End-to-end and side-by-side contact is not a conflict — lane-add/drop tapers stay out |
| Junction = connected group of linked lanes, **including through-lanes** | Covers the whole conflict area (avoids RoadRunner sliver junctions) |
| Polygon = union of member footprints (largest region, holes removed) | Follows the actual road edges |
| Merge groups chained end to end (a member of one is the predecessor/successor of a member of the other) whose footprints are within 1 m (`MergeGap`) | Sources cut one diverge/merge/crossing into many short lanelets (a real urban map: 0.9–7.5 m segments over a 15 m split) — without this each segment pair becomes its own junction and RoadRunner fills the gaps with slivers |
| Merge groups lying side by side across the road: footprints run alongside each other (within 1 m) for ≥ 4 m (`SideBySideLength`), tested on the chain-merged groups | One intersection whose two carriageways overlap separately (real urban map, T-junction east of a roundabout: 154 + 95 m² halves → one 249 m² junction, ODR 339 m²) |
| No proximity merging otherwise | Separate intersections stay separate; roundabout entries touch only at corners and stay apart |
| Keep diverges/merges whose lanes overlap (`DropDivergeMerge=false`) | Dropping them makes RoadRunner build its own, larger junction there |
| Drop groups < 15 m² | Numerical slivers |
| Roundabouts | Only the entries/exits overlap the ring, so each becomes its own small junction; the ring stays normal road |

## Validation (real urban map vs RoadRunner's build of its OpenDRIVE, 16 junctions)

Authored = junctions written to the RRHD; built = junctions in the RoadRunner scene after Build (exported back with `exportScene`).

| Method | Authored | Built | Slivers < 5 m² in build | ODR junctions present in build | Roundabout |
|---|---|---|---|---|---|
| `turn_direction`/`turning_dir` BFS clustering (8 m) | 11 | — | — | — | 48-, 32-, 31-lane clumps; 12 of 19 ring lanes inside junctions |
| `detectJunctions`, strict (0.3 m², drop diverge/merge) | 24 | 41 | 15 | 16 / 16 | 7 entry/exit junctions, 38–59 m² (ODR 41–65 m²) |
| `detectJunctions` 0.01 m², keep diverge/merge, no chain merge | 28 | 36 | 10 | 16 / 16 | same |
| `detectJunctions` + chain merge (1 m) | 21 | 30 | 7 | 16 / 16 | same; split zone east of the roundabout is one 66 m² junction (was 20 + 40 m² plus 2 slivers) |
| `detectJunctions` defaults (+ side-by-side merge, 4 m) | 19 | not built yet | — | 14 / 16 authored within 15 m | same; T-junction east of the roundabout is one junction |

RoadRunner still adds junctions of its own during Build (30 built vs 21 authored with chain merge only). A likely contributor is the very short source lanelets (median 3.3 m); merging 1:1 lanelet chains before building is the next thing to try.

`turn_direction` tags are still useful as a diagnostic: a turn lane that ends up outside every junction usually means a missing or mis-aligned boundary.

## Explicit junctions

If the source carries explicit junction areas (`type=multipolygon`, `subtype=junction`), use their polygons and member lanes directly instead of `detectJunctions`.

## Traffic-light regulatory elements

RoadRunner ignores RRHD signals on import, so `regulatory_element/traffic_light` relations are reported, not built. Phase timing needs `custom:phase_*` tags (standard Lanelet2 has no signal phases).

----

Copyright 2026 The MathWorks, Inc.

----
