# GIK Constraint Objects

Use with `generalizedInverseKinematics`. Each constraint is passed as a `ConstraintInputs` type string and instantiated as an object.

## Available Constraints

| Constraint Object | Type String | Purpose | Available From |
|-------------------|-------------|---------|----------------|
| `constraintPositionTarget` | `"position"` | End-effector must reach a target XYZ position | R2017a |
| `constraintOrientationTarget` | `"orientation"` | End-effector must match a target orientation (quaternion) | R2017a |
| `constraintPoseTarget` | `"pose"` | Combined position + orientation in one constraint | R2019a |
| `constraintAiming` | `"aiming"` | End-effector z-axis must point at a target point | R2017a |
| `constraintJointBounds` | `"joint"` | Joint positions must stay within specified limits | R2017a |
| `constraintCartesianBounds` | `"cartesian"` | End-effector position within a bounding box | R2018b |
| `constraintDistanceBounds` | `"distance"` | Distance between two bodies within bounds | R2021b |
| `constraintFixedJoint` | `"fixed"` | Lock relative pose between two bodies | R2022a |
| `constraintRevoluteJoint` | `"revolute"` | Constrain relative motion to revolute | R2022a |
| `constraintPrismaticJoint` | `"prismatic"` | Constrain relative motion to prismatic | R2022a |

## Setup Pattern

```matlab
gik = generalizedInverseKinematics(RigidBodyTree=robot, ...
    ConstraintInputs={"position", "aiming", "joint"});

posCon = constraintPositionTarget("endEffectorBody");
posCon.TargetPosition = [x, y, z];
posCon.PositionTolerance = 0.001;

aimCon = constraintAiming("endEffectorBody");
aimCon.TargetPoint = [tx, ty, tz];

jntCon = constraintJointBounds(robot);

[qSol, solInfo] = gik(q0, posCon, aimCon, jntCon);
```

## Common Combinations

| Task | Constraints |
|------|-------------|
| Reach a point while looking at a target | `position` + `aiming` + `joint` |
| Reach a full 6-DOF pose with joint limits | `pose` + `joint` |
| Keep tool level while reaching a position | `position` + `orientation` + `joint` |
| Stay within a workspace box | `cartesian` + `joint` |
| Excavator bucket at angle | `position` + `orientation` |

## Key Properties

**constraintPositionTarget:**
- `EndEffector` — body name to constrain
- `ReferenceBody` — relative to which body (default: base)
- `TargetPosition` — `[x y z]` target
- `PositionTolerance` — allowable error (meters)
- `Weights` — solver priority

**constraintOrientationTarget:**
- `EndEffector` — body name
- `TargetOrientation` — quaternion `[w x y z]`
- `OrientationTolerance` — allowable angular error (radians)

**constraintAiming:**
- `EndEffector` — body whose z-axis must aim
- `TargetPoint` — `[x y z]` point to aim at
- `AngularTolerance` — allowable aiming error (radians)

**constraintJointBounds:**
- Created from robot: `constraintJointBounds(robot)`
- `Bounds` — Nx2 matrix of [min max] per joint (defaults to robot limits)

----

Copyright 2026 The MathWorks, Inc.

----
