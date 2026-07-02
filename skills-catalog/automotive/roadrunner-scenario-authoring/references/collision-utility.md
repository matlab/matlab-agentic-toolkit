# Collision Utility Reference

Configures collision analysis between two specific actors. Access via `scnro.CollisionUtility`.

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `Actor1` | Vehicle | First actor (typically ego) |
| `Actor2` | Vehicle | Second actor (target) |
| `Actor1CoordinateSystem` | string | Collision point mode for actor 1 |
| `Actor2CoordinateSystem` | string | Collision point mode for actor 2 |
| `Actor1CollisionPoint` | numeric | Normalized bounding box location [0, 4) |
| `Actor2CollisionPoint` | numeric | Normalized bounding box location [0, 4) |
| `Actor1CollisionPointOffset` | [x, y] | Origin-relative offset for actor 1 |
| `Actor2CollisionPointOffset` | [x, y] | Origin-relative offset for actor 2 |
| `Result` | struct | Collision time, wait actor, wait duration, step size (read-only) |
| `ComputedActor1CollisionPointWorldCoord` | [x y z] | Actor 1 collision point after simulation (read-only) |
| `ComputedActor2CollisionPointWorldCoord` | [x y z] | Actor 2 collision point after simulation (read-only) |
| `ComputedCollisionPointDistance` | numeric | Distance between collision points after simulation (read-only) |

## CollisionPointCoordinateSystem Enum

| Value | Description |
|-------|-------------|
| `"normalizedCollisionPoint"` | Normalized coordinates [0-4) around bounding box perimeter |
| `"vehicleOriginOffset"` | x, y offset from vehicle origin |

### Normalized Collision Point Reference

The bounding box perimeter is parameterized from 0 to 4:
- `0.0` — rear center
- `1.0` — right center
- `2.0` — front center
- `3.0` — left center
- Values between represent interpolated positions along edges

## Usage Pattern

```matlab
% Configure collision analysis for a cut-in scenario
cu = scnro.CollisionUtility;
cu.Actor1 = ego;
cu.Actor2 = target;

% Monitor front-center of ego vs rear-center of target
cu.Actor1CoordinateSystem = "normalizedCollisionPoint";
cu.Actor1CollisionPoint = 2.0;   % Front-center of ego
cu.Actor2CoordinateSystem = "normalizedCollisionPoint";
cu.Actor2CollisionPoint = 0.0;   % Rear-center of target

% After simulation, read results:
% cu.Result contains collision timing information
% cu.ComputedCollisionPointDistance gives final distance
```

## When to Use CollisionUtility

- **Pre-simulation analysis** — determine if/when actors will collide given their paths
- **Specific impact point monitoring** — track exact collision locations on vehicles
- **Safety margin verification** — check distances between specific points on actors

**Note:** This is separate from `CollisionCondition` (which is a phase trigger). CollisionUtility provides analytical data; CollisionCondition triggers scenario failure.

## Relationship to CollisionCondition

| Feature | CollisionCondition | CollisionUtility |
|---------|-------------------|-----------------|
| Purpose | Trigger phase end/scenario fail | Analyze collision details |
| When used | During scenario authoring (phase logic) | For detailed analysis configuration |
| Output | Boolean (collision happened) | Timing, positions, distances |
| Set via | `setEndCondition` / `setFailCondition` | Direct property assignment |

----

Copyright 2026 The MathWorks, Inc.

----
