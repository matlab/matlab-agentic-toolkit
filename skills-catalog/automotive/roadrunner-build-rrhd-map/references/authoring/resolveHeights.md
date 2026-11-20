# Resolve Height Conflicts

Raise one side of each at-grade crossing between unconnected lanes so RoadRunner does not render grass where roads cross. Use [scripts/resolveHeightConflicts.m](../../scripts/resolveHeightConflicts.m) — do not reimplement it inline.

```matlab
[lanes, laneBoundaries, info] = resolveHeightConflicts(lanes, laneBoundaries);            % zStep 0.15 m, MinSeparation 2 m
[lanes, laneBoundaries, info] = resolveHeightConflicts(lanes, laneBoundaries, 0.15, MinSeparation=3);
[lanes, laneBoundaries, info] = resolveHeightConflicts(lanes, laneBoundaries, JunctionLaneIDs=jInfo.junctionLaneIDs);  % after detectJunctions
fprintf('%d components, %d at-grade conflicts, %d Z levels, %d lanes raised\n', ...
    info.nComponents, info.nConflicts, info.nZLevels, info.lanesAdjusted);
```

## Algorithm

1. **Connected components** — union-find over predecessor/successor links. Connected lanes are the same road and never conflict with each other.
2. **Lane bounding-box pre-filter** — only lane pairs from different components whose 2D boxes overlap are tested.
3. **Vectorized segment intersection** — center-line segments of the two lanes are intersected in 2D; at each hit the elevation of both lanes is interpolated.
4. **Junction crossings are skipped** — two lanes of junctions cross at grade by design (`JunctionLaneIDs`).
5. **At-grade test** — a crossing is a conflict only if the two elevations differ by less than `MinSeparation` (default 2.0 m). Bridges and overpasses already separated in the source data are left alone.
6. **Graph coloring** — greedy, highest-degree first; crossing components get different colors.
7. **Additive offset** — each lane gets `color * zStep` **added** to its existing Z; each boundary is offset once by the largest level of the lanes that reference it.

## Rules

- **Preserve source elevation.** Never flatten Z to 0 before resolving — Lanelet2 and survey maps carry real elevation (`ele`), and flattening destroys bridges, ramps, and grades.
- **zStep** — default 0.15 m, the minimum separation RoadRunner needs to render overlapping roads without grass bleeding through.
- **Track maps (closed-loop ovals)** — skip this step entirely; use natural elevation.
- **Order** — run after endpoint snapping and before boundary deduplication.
- **Large maps** — the script prints progress every 1000 lanes; expect seconds, not minutes, for ~5k lanes.

----

Copyright 2026 The MathWorks, Inc.

----
