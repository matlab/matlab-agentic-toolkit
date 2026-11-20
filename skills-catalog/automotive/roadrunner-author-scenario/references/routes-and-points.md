# Routes and Points Reference

## Point Properties

All properties of a `Point` object (accessed via `actor.InitialPoint` or route waypoints):

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | string | `""` | Point identifier |
| `Position` | [x y z] | — | Coordinates in local space |
| `WorldPosition` | [x y z] | — | Coordinates in world space (read-only) |
| `VerticalOffset` | numeric | 0.0 | Height offset from anchor (meters) |
| `Route` | Route | — | Parent route (read-only) |
| `RouteDistance` | numeric | — | Distance along route (read-only) |
| `AnchorPoint` | Point | — | Reference anchor (read-only) |
| `OffsetFrom` | string | `"leftmost"` | Lane offset reference side |
| `LaneOffset` | integer | 0 | Lane index [0, 50] from reference side |
| `LateralOffset` | numeric | 0 | Signed lateral distance from anchor (meters) |
| `ForwardOffset` | numeric | 0 | Signed longitudinal distance to anchor (meters) |
| `ReferenceLine` | string | `"origin"` | Where ForwardOffset is measured on the actor |
| `AnchorReferenceLine` | string | `"origin"` | Where ForwardOffset is measured on anchor actor |
| `TravelDirection` | string | `"forward"` | Direction of travel when anchored |
| `HasTime` | logical | false | Whether point has time data |
| `Time` | numeric | — | Time value for time-based trajectory |
| `HasSpeed` | logical | false | Whether point has speed data |
| `Speed` | numeric | — | Speed at this point (m/s) |
| `WaitTime` | numeric | 0 | Duration actor stops at this point (seconds) |

> **IMPORTANT:** `LaneOffset` is an absolute lane index [0, 50]. It is NOT a relative offset.

---

## Point Enumerations

### OffsetFrom (`LaneOffsetReference`)

| Value | Meaning |
|-------|---------|
| `"leftmost"` | LaneOffset 0 = leftmost lane, 1 = next right, etc. |
| `"rightmost"` | LaneOffset 0 = rightmost lane, 1 = next left, etc. |

### ReferenceLine / AnchorReferenceLine (`PointReferenceLine`)

| Value | Meaning |
|-------|---------|
| `"front"` | ForwardOffset measured from front of actor |
| `"origin"` | ForwardOffset measured from actor origin (default) |
| `"back"` | ForwardOffset measured from back of actor |

### TravelDirection

| Value | Meaning |
|-------|---------|
| `"forward"` | Actor faces forward along road direction |
| `"backward"` | Actor faces opposite to road direction |
| `"bidirectional"` | Either direction accepted |
| `"undirected"` | No direction constraint |

**Verified (R2026b, ScenarioBasic):** setting `"backward"` on an anchored vehicle re-anchors it onto the adjacent lane (it moved 3.50 m sideways) and flips its heading. It then drives as oncoming traffic: two cars set up "facing each other" passed 3.5 m apart without colliding. It cannot produce a same-lane head-on; for that, use an unanchored path-following car (constraint #24).

---

## Time-Based Trajectory

Use point time/speed data for precise trajectory control (path-following actors with routes).

**RoadRunner clamps time data silently (verified R2026b Update 2), so follow these rules:**
- `WaitTime` needs time data: on a route without `HasTime`, it stays 0.
- Each `Time` is clamped to the next point's current `Time`. Set times **last-to-first**; set first-to-last, [0 20 40 60] became [0 0.0017 0.003 60].
- `WaitTime` is clamped to the gap `Time(next) − Time(this)`, and a wait equal to the gap fails `validate()` ("ends at the same time that Point begins"). Keep each wait shorter than the gap, so the actor has time to drive.
- Drive the actor by the times: `SpeedReference = "route-time-data"` on its speed action.

```matlab
route = actor.InitialPoint.Route;           % points added and autoAnchored first
pts = route.Points;                          % pts(1) is the initial point
t = [0 8 16 24];                             % arrival time at each point (s)
for i = numel(pts):-1:1                      % last-to-first
    pts(i).HasTime = true;
    pts(i).Time = t(i);
end
pts(2).WaitTime = 2;                         % 2 s stop, shorter than the 8 s gap
startPhase = initialPhaseForActor(phaseLogic, actor);
startPhase.Actions(1).SpeedReference = "route-time-data";
assert(isequal([pts.Time], t))               % read back: clamping gives no error
```

Verified: this route validates. For a speed at a point instead of a time, set `HasSpeed = true` and `Speed` on that point.

**When to use time data vs phase logic:**
- **Time data** — precise trajectory timing for path-following actors (characters, scripted paths)
- **Phase logic** — reactive behavior triggered by conditions (lane changes, speed changes, gap-keeping)

---

## Route Properties

| Property | Type | Description |
|----------|------|-------------|
| `Name` | string | Route name |
| `Length` | numeric | Total route length in meters (read-only) |
| `Points` | Point[] | Control points / waypoints (read-only) |
| `Segments` | RouteSegment[] | Segments between points (read-only) |
| `HasTime` | logical | Whether any point has time data (read-only) |
| `PositionSamples` | N×3 matrix | Sampled positions along route (read-only) |
| `SpeedSamples` | N-vector | Speed at each sample (read-only) |
| `TimeSamples` | N-vector | Time at each sample (read-only) |
| `YawSamples` | N-vector | Heading in radians at each sample (read-only) |

**Methods:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `addPoint` | `addPoint(route, [x y z])` | Add waypoint to end of route |

---

## RouteSegment Properties

Segments connect successive points in a route. Access via `route.Segments`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Name` | string | `""` | Segment identifier |
| `CurveType` | string | `"cubic"` | Curve interpolation method |
| `Freeform` | logical | false | If true, road geometry does not influence route shape. New segments are `false` (road-following) in R2026b (verified: with or without anchored points); setting `false` explicitly for vehicle routes is harmless. **Set** `true` for pedestrian routes (they cross roads) and for segments that must leave the road (see §Off-Road and Airborne Paths). |
| `StartPoint` | Point | — | Start point (read-only) |
| `EndPoint` | Point | — | End point (read-only) |
| `PositionSamples` | N×3 matrix | — | Sampled positions along segment (read-only) |

### Clothoid-Turn Properties (only when `CurveType = "clothoid-turn"`)

| Property | Type | Description |
|----------|------|-------------|
| `ClothoidTurnPreferredRadius` | numeric | Preferred radius of circular arc |
| `ClothoidTurnProportion` | numeric | Clothoid percentage [0, 100] |
| `ClothoidTurnArcAngle` | numeric | Angle of the circular arc portion |
| `ClothoidTurnClothoidAngle` | numeric | Angle of the clothoid spline portion |

### CurveType Enum (`RouteSegmentCurveType`)

| Value | Use for |
|-------|---------|
| `"cubic"` | Default smooth curves (most scenarios) |
| `"clothoid"` | Road-realistic curves (highway ramps, transitions) |
| `"clothoid-turn"` | Junction turns with controlled radius/arc |

### Configuring Segment Curves

```matlab
% Configure a junction turn segment for smooth cornering
route = actor.InitialPoint.Route;
wp1 = addPoint(route, preJunctionPos);
autoAnchor(wp1);
wp2 = addPoint(route, postJunctionPos);
autoAnchor(wp2);

% Access the segment between wp1 and wp2
seg = route.Segments(end);
seg.CurveType = "clothoid-turn";
seg.ClothoidTurnPreferredRadius = 15;   % 15m turn radius
seg.ClothoidTurnProportion = 50;        % 50% clothoid blend
```

**When to use non-default curve types:**
- `"clothoid-turn"` — junction/intersection turns where you need controlled radius
- `"clothoid"` — highway on/off ramps, lane transitions with specific curvature
- `"cubic"` (default) — works well for most straight-road and gentle-curve scenarios

---

## Off-Road and Airborne Paths

The `Freeform = false` rule is for vehicles that drive on the road. For a path that must leave the road (a vehicle that lifts off and lands, a drone, a vehicle jumping a gap), keep the off-road segments `Freeform = true` and raise the points with `VerticalOffset`:

1. Anchor every route point to the road with `autoAnchor`, including the airborne ones (they must still be within 5 m of the road).
2. Raise each airborne point with `pt.VerticalOffset` (meters above the anchored road position).
3. Set `Freeform = false` on the on-road segments before lift-off and after landing, and `Freeform = true` on the climb, airborne and descent segments.

```matlab
% Positions along the lane come from the HD map (not world-space offsets)
route = car.InitialPoint.Route;
alongLane = [posRoad1; posLiftOff; posAir1; posAir2; posLand];   % N x 3, in driving order
height    = [0;        5;          5;       5;       0];         % meters above the road
for k = 1:size(alongLane, 1)
    pt = addPoint(route, alongLane(k, :));
    autoAnchor(pt, PosePreservation="reset-pose");
    if height(k) > 0
        pt.VerticalOffset = height(k);
    end
end
segs = route.Segments;           % segment k runs to alongLane(k); the first starts at the actor's initial point
for k = 1:numel(segs)
    endsRaised   = height(k) > 0;
    startsRaised = k > 1 && height(k-1) > 0;
    segs(k).Freeform = endsRaised || startsRaised;   % off-road segments stay freeform
end
```

**Verified (RoadRunner R2026b, ScenarioBasic):** route points at 40, 80, 120, 160 and 200 m along the lane, with 5 m `VerticalOffset` on 80–160 m. Height at the middle of each segment, from `seg.PositionSamples(:,3)`:

| Segments | Mid-segment height (start → climb → level → level → descent) | `validate()` |
|---|---|---|
| All `Freeform = false` | 0, 0.46, 0, 0, 0 m: the route drops back to the road between raised points | passes |
| Off-road segments `Freeform = true` | 0, 2.97, 5, 5, 2.5 m: smooth climb, level flight, descent | passes |

**A vehicle does not leave the ground from MATLAB alone (verified in R2026b simulation).** With the default built-in behavior, the car drove the route above at 20 m/s but stayed on the road: its height never rose above 0.00 m while the route peaked at 5 m. The built-in behavior keeps vehicles on the ground (`FollowGround` is on by default), and behavior parameters cannot be set through `roadrunnerAPI` in R2026b (`references/behaviors-and-parameters.md`). So you can author and validate the raised route from MATLAB, but tell the user the car only flies after `FollowGround` is turned off on its behavior asset in RoadRunner. Don't claim it flies.

**Limits of flight with the built-in behavior** (tell the user when they apply):
- **Kinematic, not physical.** The car follows the scripted path: no thrust, lift or gravity. Physics-based flight needs a custom behavior (MATLAB/Simulink, or an FMU).
- **No lane-based actions while airborne.** The car is path-following, so `ChangeLaneAction` and `ChangeLateralOffsetAction` don't apply (constraint #12).
- **Only actors are collision-checked, in 3D.** Flying over another actor is not a collision. Scene geometry (bridges, signs, buildings) is never checked, so the route itself must clear it.

---

## Point Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `anchorToPoint` | `anchorToPoint(pt, anchor)` or `anchorToPoint(pt, anchor, PosePreservation="preserve-pose")` | Anchor point to a reference point |
| `autoAnchor` | `autoAnchor(pt)` or `autoAnchor(pt, PosePreservation="preserve-pose")` | Snap point to nearest road |

**Pose preservation** (`PointPosePreservation`):
| Value | Meaning |
|-------|---------|
| `"reset-pose"` | Reset position/orientation to road alignment (default) |
| `"preserve-pose"` | Keep current position/orientation |

**Anchoring notes** (core rules: SKILL.md constraints #4 and #19):
- The error "Unable to locate a nearby anchoring road" means the point is more than about 5 m from a road.
- For a waypoint on another lane, take its position from the HD map for that lane and `autoAnchor` it. Never use `anchorToPoint` + `ForwardOffset` on route points (constraint #13).

----

Copyright 2026 The MathWorks, Inc.

----
