---
name: workflow-13-event-extraction
description: Detect critical driving events (lane changes, hard braking, cut-ins, turns) from recorded GPS + actor track data using a rule-based pipeline. Includes ROI filtering, segmentation, classifier parameters, an extensive tuning guide for under-/over-detection, and a custom-classifier example (TTC near-collision). Loaded when user mentions critical events, cut-ins, near-misses, ADAS disengagements, or event extraction.
---

# Workflow 13 — Extract Key Scenario Events from Recorded Data

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when user wants to surface critical events (cut-ins, hard brakes, lane changes, turns) from recorded drives.

Identify critical driving events (lane changes, hard braking, cut-ins, turns) from recorded sensor data. There is no single public function — use the helper-based pipeline from the [example](https://www.mathworks.com/help/driving/ug/extract-key-scenario-events-from-recorded-sensor-data.html).

## Pipeline Overview
1. Load GPS + actor track data (same as Workflow 1)
2. Filter tracks to region of interest (ROI)
3. Convert ego-frame tracks to world-frame trajectories via `actorprops`
4. Segment trajectories into fixed time windows
5. Apply rule-based classifiers to each segment
6. Return event timetable with labeled segments

## Detected Event Types
| Category | Events |
|----------|--------|
| **Ego** | `left-lane-change`, `right-lane-change`, `left-turn`, `right-turn`, `acceleration`, `deceleration` |
| **Interaction** | `cut-in` (non-ego actor enters ego path from adjacent lane) |

## Configurable Parameters (Defaults)
```matlab
%% ROI filtering — which actors to consider
maxLateralDistance = 5;       % meters from ego centerline
maxLongitudinalDistance = 20; % meters ahead/behind ego

%% Segmentation
TimeWindow = 1;  % seconds per segment

%% Ego event thresholds (egoSegmentClassifier)
params.AccelerationThreshold = 100;            % m/s² — total acceleration magnitude
params.YawThresholdForLaneChange = 2;          % degrees — cumulative yaw change
params.YawRateThresholdForLaneChange = 40;     % degrees/second — instantaneous yaw rate
params.YawRateThresholdForTurn = 60;           % degrees/second — distinguishes turns from lane changes

%% Cut-in thresholds (cutInClassifier)
params.LateralDistanceBefore = 1.5;  % meters — actor must start beyond this lateral offset
params.LateralDistanceAfter = 2;     % meters — actor crosses into this lateral zone
params.LongitudinalDistance = 15;    % meters — actor must be within this longitudinal range
```

## Tuning Guide — "Event X is Not Being Detected"

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Lane changes missed | Yaw thresholds too high for gentle lane changes | Lower `YawThresholdForLaneChange` (try 1.0°) and `YawRateThresholdForLaneChange` (try 20°/s) |
| Lane changes detected as turns | `YawRateThresholdForTurn` too low | Increase `YawRateThresholdForTurn` (try 80–100°/s) |
| Turns detected as lane changes | `YawRateThresholdForTurn` too high | Decrease `YawRateThresholdForTurn` (try 40°/s) |
| Hard braking/acceleration missed | `AccelerationThreshold` too high | Lower it (try 3–5 m/s² for real-world braking; 100 m/s² is likely a typo/placeholder — use physics-based values) |
| Cut-ins missed | Actor filtered out by ROI | Increase `maxLateralDistance` (try 8–10m) |
| Cut-ins missed (actor in ROI) | `LateralDistanceBefore` too high | Lower to 1.0m (actor was already close) |
| Cut-ins missed (slow merge) | `LongitudinalDistance` too short | Increase to 25–30m |
| False cut-in detections | `LateralDistanceAfter` too tight | Increase to 3.0m so only clear lane invasions trigger |
| Events fragmented (split across segments) | `TimeWindow` too short | Increase to 2–3 seconds |
| Events merged together | `TimeWindow` too long | Decrease to 0.5 seconds |
| Actors outside ROI not analyzed | `maxLateralDistance` or `maxLongitudinalDistance` too small | Increase to capture wider traffic (10m lateral, 40m longitudinal) |

## Adding Custom Event Types
To detect events not in the built-in classifiers (e.g., TTC-based near-collision, sudden swerve):
```matlab
%% Example: Near-collision detector based on Time-To-Collision (TTC)
function events = ttcClassifier(egoTraj, targetTraj, params)
    arguments
        egoTraj     (:,3) double
        targetTraj  (:,3) double
        params.TTCThreshold (1,1) double = 2.0  % seconds
        params.MinSpeed (1,1) double = 1.0      % m/s — ignore if stopped
    end

    relPos = targetTraj - egoTraj;
    relDist = vecnorm(relPos(:,1:2), 2, 2);

    % Approximate relative speed (backward difference)
    dt = 0.1;  % sample period
    relSpeed = [0; -diff(relDist) / dt];

    % TTC = distance / closing speed (only when closing)
    ttc = inf(size(relDist));
    closing = relSpeed > params.MinSpeed;
    ttc(closing) = relDist(closing) ./ relSpeed(closing);

    events = strings(size(ttc));
    events(ttc < params.TTCThreshold) = "near-collision";
end
```

> **Tip:** When a user says an event is not being detected, first ask them to describe the event (what happened physically). Then identify which parameter controls that detection logic, and suggest lowering/widening the threshold. Use the tuning table above.

----

Copyright 2026 The MathWorks, Inc.

----
