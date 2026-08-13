---
name: workflow-07-height-correction
description: Correct trajectory Z values when an existing .rrscene has terrain elevation. Try adjustHeight first; fall back to manual road-geometry interpolation if it fails. Loaded when user uses scenes with 3D terrain (Zenrin, HERE HD, OpenDRIVE, or any elevation-aware map) — including the pre-built-scene + GPS case from workflow-04 Option B.1.
---

# Workflow 7 — Height Correction for Scenes with Elevation

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when user has a scene with terrain elevation and trajectories are at Z=0 but roads are at hundreds of meters.
>
> **Related references:** [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) for the upstream RR scene setup. Apply this height correction *before* the export step.

**Trigger — always run `adjustHeight` for terrain-aware scenes:** If the user supplies a pre-built `.rrscene` from HERE HD, Zenrin, OpenDRIVE, or any map with elevation data (i.e. the workflow-04 Option B.1 path), run `adjustHeight(traj, rrMap)` unconditionally on every trajectory before exporting — including when GPS altitude looks reasonable. Surveyed altitude (geoid) and the scene's terrain (often EGM96 or a local datum) commonly disagree by several meters; `adjustHeight` is a no-op when alignment is already good, so there is no downside to running it. The OSM path (workflow-04 Option A) is the one case where `adjustHeight` is **not** needed (OSM has no terrain — Z is forced to 0).

When using an existing `.rrscene` that has terrain elevation (e.g., from Zenrin, HERE, or any map with 3D data), trajectories created from GPS without altitude will be at Z=0 while roads may be at hundreds of meters elevation. Use this workflow to correct heights.

## Step 1: Try `adjustHeight` first
```matlab
% adjustHeight adjusts Z to match road surface
adjustHeight(egoTrajectory, rrApp, SmoothingFactor=0.1);
```

## Step 2: Check if Z actually changed
```matlab
% If Z is still 0 (or unchanged), adjustHeight failed silently
if max(abs(egoTrajectory.Position(:,3))) < 1
    fprintf("adjustHeight did not modify Z — falling back to manual interpolation.\n");
    % Proceed to Step 3
end
```

## Step 3: Manual Z interpolation from road geometry (fallback)
If `adjustHeight` fails (often with "Trajectory is not aligned with road direction" warning), manually query road surface Z:
```matlab
%% Get road geometry from the scenario map
rrSim = createSimulation(rrApp);
rrhdMap = get(rrSim, "Map");
lbs = rrhdMap.LaneBoundaries;

% Collect all road boundary points [X, Y, Z]
allRoadPts = [];
for i = 1:numel(lbs)
    allRoadPts = [allRoadPts; lbs(i).Geometry];
end

%% Interpolate road Z for each trajectory point
egoPos = egoTrajectory.Position;
roadZ = zeros(size(egoPos, 1), 1);
for k = 1:size(egoPos, 1)
    dists = (allRoadPts(:,1) - egoPos(k,1)).^2 + (allRoadPts(:,2) - egoPos(k,2)).^2;
    [~, minIdx] = min(dists);
    roadZ(k) = allRoadPts(minIdx, 3);
end

%% Rebuild trajectory with corrected Z
correctedPos = [egoPos(:,1:2), roadZ];
egoTrajectory = scenariobuilder.Trajectory(egoTrajectory.Timestamps, correctedPos, ...
    Name="Ego", LocalOrigin=egoTrajectory.LocalOrigin);
smooth(egoTrajectory, SmoothingFactor=0.1);
```

Apply the same Z correction to actor trajectories before exporting them.

----

Copyright 2026 The MathWorks, Inc.

----
