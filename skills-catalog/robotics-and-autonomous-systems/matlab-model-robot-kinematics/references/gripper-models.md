# Available Gripper Models

## Models

| Model Name | Grip Type | DOF | Use Case |
|------------|-----------|-----|----------|
| `robotiq2F85` | Two-finger mechanical (parallel jaw) | 6 (underactuated linkage) | General pick-and-place of rigid objects |
| `robotiqEPick4CupVacuumAssembly` | Vacuum (4 suction cups) | 0 | Flat/smooth surfaces, heavier objects |
| `robotiqEPick2CupVacuumAssembly` | Vacuum (2 suction cups) | 0 | Flat/smooth surfaces, smaller footprint |
| `robotiqEPickVacuumCup` | Vacuum (single cup) | 0 | Single suction point, lightweight objects |
| `robotiqEPickVacuumCup200mm` | Vacuum (single cup, 200mm extension) | 0 | Single suction with extended reach |

## Compatibility

The `robotiq2F85` gripper is only compatible with these manipulators:

- Universal Robots UR3
- Universal Robots UR3e
- Universal Robots UR5
- Universal Robots UR5e
- Universal Robots UR10
- Universal Robots UR10e
- Universal Robots UR16e
- KINOVA Gen3 (versions 1 and 2)

The `robotiqEPick` vacuum grippers can attach to any manipulator with a `"tool0"` body whose Z-axis points along the arm's outward direction. If the robot lacks `tool0` or has a misaligned EE frame (e.g., KUKA iiwa), you must add a corrective `tool0` frame first — see `references/ee-frame-alignment.md`.

## Attachment Pattern

All grippers attach the same way — use `addSubtree` with `ReplaceBase=false`:

```matlab
robot = loadrobot("universalUR5e", DataFormat="row");
gripper = loadrobot("robotiq2F85", DataFormat="row");
addSubtree(robot, "tool0", gripper, ReplaceBase=false);
```

**Critical: Always set `ReplaceBase=false`.** The default (`true`) merges the gripper's base link into the parent body, silently discarding the gripper's base visual mesh (housing/coupling). Every provided gripper has a base visual that is lost without this flag — the fingers render but the housing disappears.

The gripper's base frame aligns to the specified body's frame. For most manipulators loaded via `loadrobot`, the end-effector body is named `"tool0"`.

## Choosing a Gripper

**Step 1 — Check manipulator compatibility:**

If the manipulator is not in the compatibility list above, the `robotiq2F85` cannot be used. Proceed to vacuum grippers or build a custom gripper (Step 4).

**Step 2 — Check object size against gripper opening:**

| Gripper | Max Opening | Use Only When |
|---------|-------------|---------------|
| `robotiq2F85` | 85 mm | Object's graspable dimension < 85 mm |
| `robotiqEPick` variants | N/A (suction) | Object has a flat surface accessible from above |

The `robotiq2F85` cannot grasp objects wider than 85 mm. If the object's smallest graspable dimension exceeds the jaw opening, the parallel-jaw gripper is physically unusable — select a vacuum gripper instead.

**Step 3 — Select by grip strategy:**

- **Small rigid objects with parallel faces** (< 85 mm across the grasp axis) → `robotiq2F85`
- **Large rigid objects picked from above** (boxes, cartons, panels, any object > 85 mm) → `robotiqEPick` variants (vacuum)
- **Flat, smooth surfaces** (sheets, sealed packages) → `robotiqEPick` variants
- **Heavy or large footprint** → `robotiqEPick4CupVacuumAssembly` (4 cups, higher payload)
- **Smaller footprint or lighter objects** → `robotiqEPick2CupVacuumAssembly`

**Step 4 — Build a custom gripper (last resort):**

If none of the available grippers work (incompatible manipulator, object not suitable for vacuum, object exceeds jaw opening), build a custom gripper using `rigidBody` with appropriate visual and collision geometry. Use `addVisual` and `addCollision` to define the gripper shape, then attach via `addSubtree` or `addBody`.

## IK Target Frame and Approach Axis

After attaching a gripper, you must know which body to solve IK to and how to orient the target so the gripper approaches correctly.

| Gripper | Contact Frame Offset (from tool0 along +Z) | Convention |
|---------|---------------------------------------------|------------|
| `robotiq2F85` | 130 mm | Fingers close perpendicular to approach axis |
| `robotiqEPick4CupVacuumAssembly` | 190 mm | Cups face in tool0 +Z direction |
| `robotiqEPick2CupVacuumAssembly` | 190 mm | Cups face in tool0 +Z direction |
| `robotiqEPickVacuumCup` | 129.5 mm | Cup faces in tool0 +Z direction |
| `robotiqEPickVacuumCup200mm` | 319.5 mm | Cup faces in tool0 +Z direction |

**Key insight:** For ALL grippers, the physical contact direction follows `tool0` +Z. The built-in tip body frames have internal rotations that are confusing to reason about — do not solve IK to them directly.

**Recommended pattern: Add a contact frame, then solve IK to it.**

This adds zero DOF (fixed joint) and gives a frame at the actual contact point with Z = approach direction:

```matlab
contactFrame = rigidBody("contact_point");
contactJoint = rigidBodyJoint("contact_joint", "fixed");
setFixedTransform(contactJoint, trvec2tform([0, 0, gripperOffset]));
contactFrame.Joint = contactJoint;
addBody(robot, contactFrame, "tool0");
```

Where `gripperOffset` is from the table above (e.g., `0.190` for EPick 4-cup).

**Solve IK to the contact frame** — Z = approach direction, position = where you want contact:

```matlab
contactPoint = [0.4, 0, 0.05];
targetRotm = [1 0 0; 0 -1 0; 0 0 -1];
targetPose = trvec2tform(contactPoint) * rotm2tform(targetRotm);
[qSol, solnInfo] = ik("contact_point", targetPose, weights, q0);
```

No offset math needed — the frame is already at the contact surface.

Helper to build rotation matrix from approach direction:

```matlab
function R = rotm_from_approach(approachZ)
%rotm_from_approach Build rotation matrix from approach direction.
    arguments
        approachZ (1,3) double
    end
    approachZ = approachZ / norm(approachZ);
    if abs(dot(approachZ, [1 0 0])) < 0.9
        tempX = cross([1 0 0], approachZ);
    else
        tempX = cross([0 1 0], approachZ);
    end
    xAxis = tempX / norm(tempX);
    yAxis = cross(approachZ, xAxis);
    R = [xAxis', yAxis', approachZ'];
end
```

**For `robotiq2F85`:** The grasp center is between the finger pads, 130mm along tool0 +Z. Best practice is to add a fixed frame at the midpoint:

```matlab
graspFrame = rigidBody("grasp_center");
graspJoint = rigidBodyJoint("grasp_joint", "fixed");
setFixedTransform(graspJoint, trvec2tform([0, 0, 0.130]));
graspFrame.Joint = graspJoint;
addBody(robot, graspFrame, "tool0");
```

Then solve IK to `"grasp_center"` instead of `"tool0"`.

## Before Building a Custom Gripper

Exhaust the provided models first. Only build custom when:
1. The manipulator is not in the `robotiq2F85` compatibility list, AND
2. The object is not suitable for vacuum gripping (no flat surface, porous, irregular)

Discovery showed agents building grippers from scratch when provided models were available and ready to attach in one line.

----

Copyright 2026 The MathWorks, Inc.

----
