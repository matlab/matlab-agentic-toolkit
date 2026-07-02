# Physics-First Scenario Design

Derive all numerical parameters from scenario intent using kinematics BEFORE writing code. This prevents scenarios that validate but are functionally wrong (actors miss each other, phases end early, conditions never trigger).

## When to Apply

| Scenario type | Apply physics-first? |
|---|---|
| Collision / near-miss (pedestrian, vehicle) | **Always** |
| Timed cut-in or cut-out | **Always** |
| Pedestrian crossing with ego interaction | **Always** |
| Lead-follow, stop-and-go | Recommended (verify gap dynamics) |
| Swerving / lateral offset | Not needed (offset is lane-relative) |
| Junction approach (no crossing conflict) | Not needed |

---

## Universal Kinematic Equations

Every scenario parameter derives from these relationships:

| Equation | Use when you know | To find |
|---|---|---|
| `d = v * t` | speed and time | distance covered |
| `t = d / v` | distance and speed | time to cover it |
| `a = Dv / t` | speed change and time | acceleration rate |
| `d_stop = v^2 / (2*a)` | speed and decel rate | stopping distance |
| `d_relative = Dv * t` | speed difference and time | how gap opens/closes |
| `t_collision = bumper_gap / closing_rate` | gap and speed difference | time to collision |

**Relative motion rule:** Gap changes at `Dv = v_rear - v_front` m/s. Positive = closing.

---

## The 5-Step Pre-Authoring Process

### Step 1 — Parse Intent into Timeline

Extract desired events from the prompt:
```
t = ?   Ego reaches crossing point
t = ?   Other actor starts action
t = ?   Critical event (collision, near-miss, merge)
```

### Step 2 — Measure Spatial Parameters

Run geometry query BEFORE writing scenario code:
```matlab
% Get actual positions and heading at key fractions
[egoPos, egoHdg] = helperGetPositionFromHDMap(hdMap, egoLane, egoFrac, ...
    "TravelDirection", "Forward", "MinLength", 60);
[actorPos, actorHdg] = helperGetPositionFromHDMap(hdMap, actorLane, actorFrac, ...
    "TravelDirection", "Forward", "MinLength", 60);
d_between = norm(egoPos - actorPos);

% For crossing scenarios: confirm perpendicular direction
hdg2D = actorHdg(1:2) / norm(actorHdg(1:2));
perpL = [-hdg2D(2), hdg2D(1), 0];
perpR = [ hdg2D(2),-hdg2D(1), 0];
% Pick direction that lands closer to egoLane
```

### Step 3 — Build Parameter Derivation Table

| Parameter | Given | Formula | Value |
|---|---|---|---|
| Distance ego to event | positions | `norm(egoPos - eventPos)` | ? m |
| Ego travel time | distance, speed | `d / v_ego` | ? s |
| Actor action duration | Dv or distance, dynamics | `Dv/rate` or `d/speed` | ? s |
| **Trigger time** | arrival - action_duration | `t_ego_arrive - t_action` | ? s |
| Phase duration | action_duration + margin | `>= DynamicsValue` | ? s |
| MinLength needed | speed, total time | `v * t_total + 20` | ? m |

### Step 4 — Verify Conditions Will Trigger

For every condition, confirm it fires:
- `SimulationTimeCondition`: Is event still possible at that time?
- `DurationCondition`: Is `Duration >= DynamicsValue` of the action?
- `LongitudinalDistanceToActorCondition`: Does `d(t) = d_initial - Dv*t` cross threshold?
- `SpeedCondition`: Does speed ramp reach threshold before phase ends?

**If trigger time <= 0:** Reposition actors or adjust speeds — the event is impossible.

### Step 5 — Write Code with Derived Values

```matlab
% Use computed values — no magic numbers
c = setEndCondition(initPhase, "SimulationTimeCondition");
c.Time = t_trigger;             % from Step 3

sa = addAction(phase, "ChangeSpeedAction");
sa.Speed = v_target;
sa.DynamicsDimension = "time";
sa.DynamicsValue = t_budget;    % from Step 3

c2 = setEndCondition(phase, "DurationCondition");
c2.Duration = phase_dur;        % from Step 3, >= DynamicsValue
```

---

## Per-Category Quick Rules

### Following / Braking
- Gap changes at `Dv` m/s. Equal speeds = gap never changes = distance trigger never fires.
- Stopping distance: `d = v^2 / (2*a)`. Verify `d < remaining_lane_length`.
- `DurationCondition` on brake phase = `v / a` (time to stop).

### Cut-In / Lane Change
- Closing rate: `v_ego - v_target`. Lane change must start before ego arrives.
- Trigger time: `t = gap / closing_rate - lane_change_duration`.
- Safety: `initial_gap >= lane_change_dist + closing_rate * maneuver_time + vehicle_length`.

### Pedestrian Crossing
- Crossing time: `t_cross = road_width / ped_speed + ramp_time` (ramp ~0.3s).
- Pedestrian start time: `t_start = t_ego_arrive - t_cross`. Must be > 0.
- Always use perpendicular direction from heading query — never world-space offsets.
- Route overshoot: `crossDist = lane_sep + half_lane_width + 1.0m`.

### Stop / Stop-Line
- Trigger: start braking when `d_to_stop - d_stop_distance` remains.
- `d_stop = v^2 / (2*a)`. At 3 m/s^2 and 14 m/s: d = 32.7m.
- Phase duration for decel: `t = v / a`.

### Swerving / Lateral Offset
- `DurationCondition.Duration >= DynamicsValue` (phase must last at least as long as action).
- For oscillation: spacing between swerves >= 1.5 * DynamicsValue.
- MinLength: `v * num_swerves * swerve_period + 20m`.

### Junction
- Single-arm routing only (approach -> connected exit).
- `MinLength=30` for intersection approach lanes.
- Lane-following mode preferred for simple approach-and-stop.

### Multi-Actor Sequences
- Sequential triggers: `t_trigger[k] = t_trigger[k-1] + phase_duration[k-1]`.
- MinLength for N actors at spacing S: `N * S + v * total_time`.
- Every phase with a successor MUST have an end condition.

---

## Pre-Authoring Checklist

```
SPATIAL
  [ ] Queried actual world positions — no guessed fractions
  [ ] Measured distances between interacting actors
  [ ] For lateral interactions: confirmed perpendicular direction via query

TEMPORAL
  [ ] Computed ego travel time to event point (d/v)
  [ ] Computed each actor's action duration
  [ ] Computed trigger time (t_arrive - t_action). All > 0?

DYNAMIC
  [ ] DynamicsValue consistent with desired change and time budget
  [ ] DurationCondition.Duration >= DynamicsValue for each phase
  [ ] MinLength >= v * total_scenario_time + 20m

CONDITIONS
  [ ] Each condition verified to trigger (not just plausible — computed)
  [ ] No actor runs out of lane before scenario ends

OUTCOME
  [ ] Intended event confirmed by computing actor states at critical time
```

----

Copyright 2026 The MathWorks, Inc.

----
