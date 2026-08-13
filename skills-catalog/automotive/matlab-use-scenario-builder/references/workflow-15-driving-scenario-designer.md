---
name: workflow-15-driving-scenario-designer
description: Generate a `drivingScenario` object from recorded GPS + actor tracks and open it in the Driving Scenario Designer (DSD) app. Use ONLY when the user explicitly asks for the DSD / `drivingScenario` / `drivingScenarioDesigner` target. The default Scenario Builder target is RoadRunner; do not invoke this workflow for generic "build a scenario" requests.
---

# Workflow 15 — Driving Scenario Designer (drivingScenario object)

> **Parent skill:** [`SKILL.md`](../SKILL.md). This workflow is **off by default**. The default Scenario Builder target is RoadRunner (Workflow 4). Use this workflow ONLY when the user explicitly mentions:
> - "Driving Scenario Designer", "DSD"
> - "open in `drivingScenarioDesigner`", "build a `drivingScenario` object"
> - "drivingScenario" (the MATLAB class), as the export target — NOT as an intermediate step toward RoadRunner

If the user just says "build a scenario", "generate a scenario", "scenario from this data" without any of the above keywords, use Workflow 4 (RoadRunner). Do NOT default to DSD because it is faster to launch — RoadRunner is the canonical target.

## Difference vs `exportToDrivingScenario` in Workflow 4

`exportToDrivingScenario` is also called inside Workflow 4 (Step 2) — but only to obtain the road network as an intermediate before `getRoadRunnerHDMap`. **That call does not constitute a DSD workflow** and the resulting `scenario` object is consumed and discarded. Workflow 15 is end-to-end: `drivingScenario` is the final artifact and `drivingScenarioDesigner(ds)` is the hand-off.

## High-level pipeline

1. Build sensor objects (Workflows 1–3).
2. Sync + normalize timestamps (Rule 5 / Workflow 6).
3. Build `egoTrajectory` from GPS with `LocalOrigin` from OSM `roadprops`.
4. Run camera-playback Mode (Rule 2). The validation video is exactly the same as for Workflow 4 — there's no DSD-specific replacement.
5. `actorprops(trackData, egoTrajectory, SaveAs="none")` to get the non-ego table.
6. `ds = exportToDrivingScenario(egoTrajectory, RoadNetworkSource="OpenStreetMap", FileName=osmFile, Name="Ego")` — this is your starting `ds` with road + ego.
7. Add non-ego actors to `ds` via the loop in the next section. **R2026a-specific care required.**
8. `save("…_ds.mat", "ds")` and `drivingScenarioDesigner(ds)`.

Do NOT call `getRoadRunnerHDMap`, `importScene`, or any RoadRunner API in this workflow.

## Adding non-ego actors — R2026a gotchas

`drivingScenario` actor trajectories are stricter than `scenariobuilder.Trajectory` exports to RoadRunner. The recorded actor table from `actorprops` will fail multiple validation paths if added naively. Apply all four safeguards in the loop:

```matlab
%% Add non-ego actors from actorprops table to drivingScenario `ds`.
% R2026a: trajectory(actor, wp, speeds) requires:
%   - 2D-flattened waypoints   (z column == 0)
%   - no two consecutive (x,y) identical
%   - non-empty per-waypoint speed vector  ([] is rejected)
%   - no exact-zero segment speed
nMoving = 0; nStatic = 0; nFailed = 0;
for i = 1:height(actorInfo)
    wp  = actorInfo.Waypoints{i};
    wp(:,3) = 0;                      % flatten Z (sensor offset, not road height)
    t   = actorInfo.Time{i};
    yaw = actorInfo.Yaw{i};

    % 1) dedup consecutive identical (x,y)
    keep = [true; any(diff(wp(:,1:2),1,1) ~= 0, 2)];
    wpu  = wp(keep,:);
    tu   = t(keep);
    yawu = yaw(keep);

    veh = vehicle(ds, ClassID=1, Name="Actor_" + string(actorInfo.TrackID(i)));

    if size(wpu,1) >= 2
        % 2) per-waypoint speed from finite differences
        dxy  = vecnorm(diff(wpu(:,1:2),1,1), 2, 2);
        dt   = max(diff(tu), 1e-3);    % guard against zero dt
        spdu = [dxy./dt; dxy(end)/dt(end)];
        % 3) clamp to a small positive floor — exact 0 is rejected
        spdu = max(spdu, 0.1);
        try
            % 4) trajectory(), NOT smoothTrajectory:
            % smoothTrajectory's accumulateDistance is brittle on sparse,
            % near-stationary, or slightly-noisy paths and throws
            % "Unable to create smooth trajectory."
            trajectory(veh, wpu, spdu);
            nMoving = nMoving + 1;
        catch ME
            fprintf("  trajectory() failed for ID %s (%s) — placing static.\n", ...
                string(actorInfo.TrackID(i)), ME.message);
            veh.Position = wpu(1,:);
            veh.Yaw      = yawu(1);
            nFailed = nFailed + 1;
        end
    elseif size(wpu,1) == 1
        % Whole track was at one location after dedup — actually stationary
        veh.Position = wpu(1,:);
        veh.Yaw      = yawu(1);
        nStatic = nStatic + 1;
    end
end
fprintf("drivingScenario: ego + %d moving, %d stationary, %d trajectory-failed (placed static).\n", ...
    nMoving, nStatic, nFailed);
```

### Why each safeguard exists

| Safeguard | Symptom if missing | Root cause |
|-----------|-------------------|------------|
| Dedup consecutive (x,y) | `setProperties` errors: *"A waypoint was repeated consecutively with different corresponding speeds values."* | Recordings of stationary or slow actors duplicate samples |
| Finite-difference speed vector | `trajectory()` errors: *"The value of 'Speed' is invalid. Expected speed to be a vector."* | R2026a `trajectory()` rejects `[]` / scalar speeds |
| Clamp to 0.1 m/s floor | `trajectory()` accepts but DSD playback stalls; some R2026a builds error | Exact zero is treated as an invalid segment |
| Use `trajectory()`, not `smoothTrajectory()` | `accumulateDistance` errors: *"Unable to create smooth trajectory. Try adjusting waypoints, speed, or jerk."* | `smoothTrajectory` requires monotonic forward-progress paths; recorded tracks frequently violate this |

### What NOT to do

- Do not call `smoothTrajectory(veh, wpu, spdu, Yaw=yawu)` — fragile on recorded data.
- Do not pass `[]` for speeds — R2026a rejects.
- Do not skip the dedup — pre-dedup paths trigger the duplicate-waypoint error.
- Do not flag stationary actors as failures — three "static" actors out of eight is normal for short Pandaset/VSI clips.

## Save and launch

```matlab
dsFile = fullfile(dataDir, "<sequence>_ds.mat");
save(dsFile, "ds");
fprintf("Scenario saved: %s\n", dsFile);
drivingScenarioDesigner(ds);
```

`drivingScenarioDesigner(ds)` opens DSD with the scenario already loaded — the user can hit Play immediately. They can also reopen it later via:

```matlab
load("<sequence>_ds.mat", "ds");
drivingScenarioDesigner(ds);
```

## What to skip (vs Workflow 4)

| Workflow 4 step | DSD workflow |
|-----------------|--------------|
| Connect to RoadRunner (`roadrunner(rrProjectPath, ...)`) | Skip |
| Ask user for RR install + project paths (Rule 8) | Skip |
| `getRoadRunnerHDMap` + `importScene` + `enableOverlapGroupsOptions` | Skip |
| Lane localization (`localizeEgoUsingLanes`) gate (Rule 4 step 7) | Skip — DSD does not consume `localizedTrajectory` the same way; raw GPS path goes directly into `exportToDrivingScenario`. If the user explicitly asks for localized ego in DSD, run Workflow 8 first and feed the localized trajectory into step 6 above |
| Final-scenario simulation + `exportVideo` (Rule 4 step 9) | Skip — DSD has its own Play / Record buttons; let the user drive playback |
| Side-by-side comparison video composition | Skip |

## Combined RoadRunner + DSD requests

If the user asks for both ("export to RoadRunner AND open in DSD"), run Workflow 4 to completion, then run this workflow's actor-add loop on a fresh `ds = exportToDrivingScenario(...)`. Do not try to share state between the two — RoadRunner has actor handles tied to the RR session that don't translate to `drivingScenario`.

----

Copyright 2026 The MathWorks, Inc.

----
