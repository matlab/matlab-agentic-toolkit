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

---

## Time-Based Trajectory

Use point time/speed data for precise trajectory control (path-following actors with routes):

```matlab
route = actor.InitialPoint.Route;
wp1 = addPoint(route, pos1);
autoAnchor(wp1);
wp1.HasTime = true;
wp1.Time = 3.0;          % Arrive at 3 seconds
wp1.WaitTime = 2.0;      % Stop for 2 seconds at this point

wp2 = addPoint(route, pos2);
autoAnchor(wp2);
wp2.HasSpeed = true;
wp2.Speed = 5.0;          % 5 m/s at this point
```

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
| `Freeform` | logical | true | If true, road geometry does not influence route shape. Set to `false` for vehicle routes so they follow road surface. Leave `true` for pedestrian routes (they cross roads). |
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

## Point Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `anchorToPoint` | `anchorToPoint(pt, anchor)` or `anchorToPoint(pt, anchor, "preserve-pose")` | Anchor point to a reference point |
| `autoAnchor` | `autoAnchor(pt)` or `autoAnchor(pt, "preserve-pose")` | Snap point to nearest road |

**Pose preservation** (`PointPosePreservation`):
| Value | Meaning |
|-------|---------|
| `"reset-pose"` | Reset position/orientation to road alignment (default) |
| `"preserve-pose"` | Keep current position/orientation |

----

Copyright 2026 The MathWorks, Inc.

----
