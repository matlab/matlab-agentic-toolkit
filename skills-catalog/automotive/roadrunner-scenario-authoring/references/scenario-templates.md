# Scenario Templates

Tested, validated patterns for common scenario types. All actors using `ChangeLaneAction` or `ChangeLateralOffsetAction` must be in **lane-following mode** (no routes).

## Cut-In

Target cuts into ego's lane from an adjacent lane. Both actors in lane-following mode.

**Key setup:**
- Place actors on verified parallel lanes using HD Map positions + `autoAnchor`
- Do NOT use `LaneOffset` — it may place actors on junction connectors that don't support lane changes
- Ego faster than target so gap closes (triggers distance condition)
- Neither actor has routes (lane-following mode required for `ChangeLaneAction`)
- `helperSceneAwareness` with `ScenarioType="cut-in"` automatically finds adjacent parallel lanes

**Verifying parallel lanes manually** (when not using the helper):
```matlab
% Check two lanes are suitable for cut-in: aligned headings + close proximity
[posI, hdgI] = helperGetPositionFromHDMap(rrHDMap, laneI, 0.5, "TravelDirection", "Forward", "MinLength", 50);
[posJ, hdgJ] = helperGetPositionFromHDMap(rrHDMap, laneJ, 0.5, "TravelDirection", "Forward", "MinLength", 50);
alignment = abs(dot(hdgI(1:2)/norm(hdgI(1:2)), hdgJ(1:2)/norm(hdgJ(1:2))));
lateralDist = norm(posI(1:2) - posJ(1:2));
assert(alignment > 0.95, "Lanes are not parallel (alignment=%.3f)", alignment);
assert(lateralDist < 10, "Lanes are too far apart (%.1fm)", lateralDist);
```

```matlab
% Step 1: Find two parallel lanes using helperSurveyLanes
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in");

% Step 2: Get positions on adjacent lanes (use lanes with similar headings)
[egoPos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, egoLaneIdx, 0.1, ...
    "TravelDirection", "Forward", "MinLength", 50);
[targetPos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, targetLaneIdx, 0.3, ...
    "TravelDirection", "Forward", "MinLength", 50);

% Step 3: Place actors — no routes (lane-following mode)
ego = addActor(rrs, vehicleAsset, egoPos);
ego.Name = "Ego";
autoAnchor(ego.InitialPoint);

target = addActor(rrs, vehicleAsset, targetPos);
target.Name = "TargetVehicle";
autoAnchor(target.InitialPoint);

% Step 4: Speeds — ego faster so it catches up
egoInit = initialPhaseForActor(phaseLogic, ego);
egoInit.Actions(1).Speed = 20;
targetInit = initialPhaseForActor(phaseLogic, target);
targetInit.Actions(1).Speed = 15;

% Step 5: Cut-in phase logic
cutPhase = addPhaseInSerial(phaseLogic, targetInit, "ActorActionPhase");
cutPhase.Actor = target;

cond = setEndCondition(targetInit, "LongitudinalDistanceToActorCondition");
cond.Actor = target;
cond.ReferenceActor = ego;
cond.Distance = 8;
cond.Rule = "le";

% Direction depends on lane layout: if target is at higher Y, use "right"
laneChange = addAction(cutPhase, "ChangeLaneAction");
laneChange.Direction = "right";  % Verify: target must move toward ego's lane
laneChange.DynamicsDimension = "distance";
laneChange.DynamicsValue = 20;
```

**How to determine lane change direction:** "Left"/"right" is relative to the actor's travel direction, not absolute coordinates. Two approaches:

**Option A — "same-lane" reference (preferred, simplest):**
```matlab
% Target automatically moves to the reference actor's lane — no direction computation needed
laneChange = addAction(cutPhase, "ChangeLaneAction");
laneChange.LaneChangeReference = "actor";
laneChange.Direction = "same-lane";
laneChange.ReferenceActor = ego;
laneChange.DynamicsDimension = "distance";
laneChange.DynamicsValue = 20;
```

**Option B — Explicit direction via cross product** (use when targeting a lane that has no actor):
```matlab
% Vector from target to ego (desired movement direction)
targetToEgo = ego.InitialPoint.WorldPosition(1:2) - target.InitialPoint.WorldPosition(1:2);
targetToEgo = targetToEgo / norm(targetToEgo);

% Target's travel heading
[~, targetHdg] = helperGetPositionFromHDMap(rrHDMap, targetLaneIdx, fraction, ...
    "TravelDirection", "Forward", "MinLength", 50);
hdg2D = targetHdg(1:2) / norm(targetHdg(1:2));

% Cross product Z-component: positive = ego is to the LEFT
crossZ = hdg2D(1) * targetToEgo(2) - hdg2D(2) * targetToEgo(1);
if crossZ > 0
    direction = "left";
else
    direction = "right";
end
```

**Never guess direction from coordinates alone** — road orientation varies between scenes.

## Lane Change (Non-Conflict)

Actor changes into another actor's lane with safe separation — no collision expected. Use this pattern when the intent is a safe merge, overtake entry, or any lane change that should complete without collision.

**When to use this instead of Cut-In:**
- User describes a "merge", "lane change", "move over" (not "cut in front of")
- No collision or near-miss is expected
- Speeds are matched or actor is already ahead/behind

**Key setup differences from Cut-In:**
- Larger initial separation (≥ 30m)
- Matched or similar speeds (no aggressive closing)
- `DurationCondition` trigger (simpler, no speed differential needed)
- Actor is already ahead of or behind the other vehicle

```matlab
% Both actors on adjacent parallel lanes, actor ahead of reference
sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in");

% Place merger AHEAD on adjacent lane (fraction 0.4 vs ego at 0.2 = ~30m gap)
[mergerPos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, ...
    sceneInfo.Recommendations(2).LaneIndex, 0.4, ...
    "TravelDirection", "Forward", "MinLength", 50);
[egoPos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, ...
    sceneInfo.Recommendations(1).LaneIndex, 0.2, ...
    "TravelDirection", "Forward", "MinLength", 50);

ego = addActor(rrs, vehicleAsset, egoPos);
ego.Name = "Ego";
autoAnchor(ego.InitialPoint);

merger = addActor(rrs, vehicleAsset, mergerPos);
merger.Name = "MergingVehicle";
autoAnchor(merger.InitialPoint);

% Matched speeds — no closing
egoInit = initialPhaseForActor(phaseLogic, ego);
egoInit.Actions(1).Speed = 15;
mergerInit = initialPhaseForActor(phaseLogic, merger);
mergerInit.Actions(1).Speed = 15;

% Time-based trigger — merge after 2 seconds (no speed differential needed)
cond = setEndCondition(mergerInit, "DurationCondition");
cond.Duration = 2;

% Lane change using "same-lane" (simplest, no direction computation)
mergePhase = addPhaseInSerial(phaseLogic, mergerInit, "ActorActionPhase");
mergePhase.Actor = merger;
laneChange = addAction(mergePhase, "ChangeLaneAction");
laneChange.LaneChangeReference = "actor";
laneChange.Direction = "same-lane";
laneChange.ReferenceActor = ego;
laneChange.DynamicsDimension = "distance";
laneChange.DynamicsValue = 20;
```

**Safety margin formula:** For cooperative lane changes, ensure:
`initial_gap ≥ lane_change_distance + (closing_rate × maneuver_time) + 5m`

Example: 20m lane change at 15 m/s with 0 m/s closing rate → need ≥ 25m gap. With 5 m/s closing: maneuver_time ≈ 20/15 ≈ 1.3s, so need ≥ 20 + 5×1.3 + 5 = 31.5m.

## Same-Lane Placement (Leader/Follower)

Place multiple actors on the same lane at different positions. Used for overtake, follow, and emergency brake scenarios.

```matlab
% Query single lane at two different fractions
laneIdx = sceneInfo.Recommendations(1).LaneIndex;

% Leader further along the lane (higher fraction)
[leaderPos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, laneIdx, 0.4, ...
    "TravelDirection", "Forward", "MinLength", 50);
% Follower behind (lower fraction)
[followerPos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, laneIdx, 0.2, ...
    "TravelDirection", "Forward", "MinLength", 50);

leader = addActor(rrs, vehicleAsset, leaderPos);
leader.Name = "LeadVehicle";
autoAnchor(leader.InitialPoint);

follower = addActor(rrs, vehicleAsset, followerPos);
follower.Name = "FollowerVehicle";
autoAnchor(follower.InitialPoint);

% Verify separation
sep = norm(leader.InitialPoint.WorldPosition(1:2) - follower.InitialPoint.WorldPosition(1:2));
assert(sep > 10, "Actors too close (%.1fm) — increase fraction difference", sep);
```

**Fraction guidelines for same-lane placement:**
- Use fractions ≥ 0.2 and ≤ 0.8 (avoid lane boundaries where `autoAnchor` is unreliable)
- Minimum fraction difference of 0.1 for ~10-20m separation on typical lanes
- Always verify actual separation after placement (`norm` of positions)

## Pedestrian Crossing

Pedestrian crosses the road in front of ego. Pedestrian MUST have a route (required for character actors).

**CRITICAL:** Never use world-space offsets like `pos + [0 -15 0]` for pedestrian crossing routes — this only works on world-axis-aligned roads. Always compute the crossing direction from the road heading at the pedestrian's position.

```matlab
% Load character asset (verify path exists — see asset-catalog.md for project-specific paths)
charAsset = getAsset(rrprj, "Characters/Citizen_Male.rrchar", "CharacterAsset");

% Place pedestrian using HD Map position (not world-space guesses)
[pedPos, pedHdg] = helperGetPositionFromHDMap(sceneInfo.HDMap, pedLaneIdx, pedFraction, ...
    "TravelDirection", "Forward", "MinLength", 20);
ped = addActor(rrs, charAsset, pedPos);
ped.Name = "Pedestrian";
autoAnchor(ped.InitialPoint);

% REQUIRED: pedestrian route defines crossing path using road-relative direction
pedRoute = ped.InitialPoint.Route;
hdg2D = pedHdg(1:2) / norm(pedHdg(1:2));
perpDir = [-hdg2D(2), hdg2D(1), 0];  % perpendicular to road heading
crossingDistance = 15;  % meters — adjust based on road width
crossTarget = pedPos + perpDir * crossingDistance;
crossPt = addPoint(pedRoute, crossTarget);
autoAnchor(crossPt);
% Note: pedestrian routes remain freeform (default) — they cross roads, not follow them

pedInit = initialPhaseForActor(phaseLogic, ped);
pedInit.Actions(1).Speed = 1.4;  % Walking speed ~5 km/h
```

**Perpendicular direction selection:** The sign of `perpDir` determines which side the pedestrian crosses toward. Always verify by comparing the landing position against the target lane:
```matlab
% Check which perpendicular direction points toward egoLane
[ePos, ~] = helperGetPositionFromHDMap(sceneInfo.HDMap, egoLaneIdx, pedFraction, ...
    "TravelDirection", "Forward", "MinLength", 20);
perpL = [-hdg2D(2), hdg2D(1), 0];
perpR = [ hdg2D(2),-hdg2D(1), 0];
% Pick the direction that lands closer to egoLane
if norm(pedPos + perpL*5 - ePos) < norm(pedPos + perpR*5 - ePos)
    perpDir = perpL;
else
    perpDir = perpR;
end
```

## Lead-Follow (Gap-Keeping)

Follower maintains a fixed gap behind a leader using `ChangeLongitudinalDistanceAction`. Both in lane-following mode (no routes).

**Two gap-keeping modes:**
- `DistanceType="space"` — maintain spatial gap in meters (simpler, default)
- `DistanceType="time"` — maintain time-gap in seconds (adaptive to speed changes)

```matlab
% Both actors on same lane, leader ahead
leaderInit = initialPhaseForActor(phaseLogic, leader);
leaderInit.Actions(1).Speed = 15;
followerInit = initialPhaseForActor(phaseLogic, follower);
followerInit.Actions(1).Speed = 20;  % Start faster to close initial gap

% Gap-keeping phase
followPhase = addPhaseInSerial(phaseLogic, followerInit, "ActorActionPhase");
followPhase.Actor = follower;

gapAction = addAction(followPhase, "ChangeLongitudinalDistanceAction");
gapAction.ReferenceActor = leader;
gapAction.RelativePosition = "behind";
gapAction.DistanceType = "space";    % "space" for meters, "time" for seconds
gapAction.DistanceOffset = 15;       % 15 meters (or 2.0 seconds if "time")
gapAction.SamplingMode = "continuous";
gapAction.ConstraintType = "asset";  % Use actor's kinematic limits

% Trigger: start gap-keeping immediately after a short duration
cond = setEndCondition(followerInit, "DurationCondition");
cond.Duration = 1;
```

**With custom kinematic constraints** (for tighter control over acceleration):
```matlab
gapAction.ConstraintType = "custom";
gapAction.MaxSpeed = 25;           % m/s
gapAction.MaxAcceleration = 3.0;   % m/s^2
gapAction.MaxDeceleration = 5.0;   % m/s^2
```

## Emergency Brake

Lead vehicle brakes suddenly; test ego's response.

```matlab
% Leader ahead in same lane, both lane-following
leaderInit = initialPhaseForActor(phaseLogic, leader);
leaderInit.Actions(1).Speed = 20;

% Brake phase: leader decelerates to 0
brakePhase = addPhaseInSerial(phaseLogic, leaderInit, "ActorActionPhase");
brakePhase.Actor = leader;

brakeAction = addAction(brakePhase, "ChangeSpeedAction");
brakeAction.Speed = 0;
brakeAction.DynamicsDimension = "rate";
brakeAction.DynamicsValue = 8;  % 8 m/s^2 deceleration

% Trigger: after 3 seconds
cond = setEndCondition(leaderInit, "DurationCondition");
cond.Duration = 3;
```

## Junction Turn (Right/Left Turn + Stop)

Vehicle approaches junction, turns, and stops on the exit road. Uses path-following mode (routes with multiple waypoints for smooth turn).

**CRITICAL LIMITATION:** On intersection scenes, routes can ONLY follow connected lane segments. Do NOT route from one approach arm to a non-adjacent exit arm (e.g., North approach → South approach). These are separate unconnected arms. Valid routing: approach lane → connected exit lane in the same corridor (e.g., North approach → East exit for a right turn). Cross-arm routes fail `validate`.

**Key setup:**
- Use an intersection scene (`FourWaySignal`, `FourWayStop`, `T_Intersection`)
- Identify approach lane and exit lane from HD Map survey — lanes must be connected
- Add multiple route waypoints: pre-junction → post-junction → exit point
- More waypoints = smoother turn path
- For vehicles that just need to approach and stop at the junction, use lane-following mode (no routes) instead

```matlab
% Survey lanes to identify approach and exit lanes
laneTable = helperSurveyLanes(sceneInfo.HDMap, TravelDirection="Forward", MinLength=30);

% Place vehicle on approach lane
[startPos, ~] = helperGetPositionFromHDMap(rrHDMap, approachLaneIdx, 0.2, ...
    "TravelDirection", "Forward", "MinLength", 30);
vehicle = addActor(rrs, vehicleAsset, startPos);
vehicle.Name = "EgoVehicle";
autoAnchor(vehicle.InitialPoint);

% Multi-waypoint route for smooth turn
route = vehicle.InitialPoint.Route;

% WP1: End of approach lane (pre-junction)
[preJunctionPos, ~] = helperGetPositionFromHDMap(rrHDMap, approachLaneIdx, 0.9, ...
    "TravelDirection", "Forward", "MinLength", 30);
wp1 = addPoint(route, preJunctionPos);
autoAnchor(wp1);

% WP2: Start of exit lane (post-junction — defines the turn)
[postJunctionPos, ~] = helperGetPositionFromHDMap(rrHDMap, exitLaneIdx, 0.1, ...
    "TravelDirection", "Forward", "MinLength", 30);
wp2 = addPoint(route, postJunctionPos);
autoAnchor(wp2);

% WP3: Further along exit lane (stop area)
[exitPos, ~] = helperGetPositionFromHDMap(rrHDMap, exitLaneIdx, 0.6, ...
    "TravelDirection", "Forward", "MinLength", 30);
wp3 = addPoint(route, exitPos);
autoAnchor(wp3);

% Phase logic: drive then stop
initPhase = initialPhaseForActor(phaseLogic, vehicle);
initPhase.Actions(1).Speed = 10;

stopPhase = addPhaseInSerial(phaseLogic, initPhase, "ActorActionPhase");
stopPhase.Actor = vehicle;
stopAction = addAction(stopPhase, "ChangeSpeedAction");
stopAction.Speed = 0;
stopAction.DynamicsDimension = "rate";
stopAction.DynamicsValue = 3;

% Trigger: time-based (estimate from distance/speed)
cond = setEndCondition(initPhase, "SimulationTimeCondition");
cond.Time = 9;  % Adjust based on approach distance and speed
```

**How to identify approach/exit lanes:** Survey all forward lanes. Lanes ending near the intersection center are approach lanes. Lanes starting near the center are exit lanes. Compare start/end positions to determine direction (N/S/E/W).

## How to Use These Templates

These templates are **building blocks**, not recipes. Most real scenarios combine elements from multiple templates. The agent should:

1. Classify the user's intent into placement geometry (same-lane or adjacent-lane) and interaction type (conflict or non-conflict)
2. Pick the relevant placement pattern (Same-Lane or Cut-In/Lane Change)
3. Compose phase logic by chaining actions from any template that fits the maneuver
4. Validate safety margins before executing

## Key Rules for All Templates

1. **Lane-following vs path-following:** Actors needing `ChangeLaneAction` must NOT have routes
2. **Speed differential for triggers:** `LongitudinalDistanceToActorCondition` only fires if actors have different speeds
3. **Character actors always need routes:** Validation fails without them
4. **Always set `.Actor`:** On every `ActorActionPhase` and condition object
5. **Fraction boundaries:** Use fractions ≥ 0.2 and ≤ 0.8 for `helperGetPositionFromHDMap` — lane start/end points cause unreliable `autoAnchor` snapping
6. **No undo:** `removeActor` does not exist. Plan placement before executing. Mistakes require `newScenario()` and rebuilding.

----

Copyright 2026 The MathWorks, Inc.

----
