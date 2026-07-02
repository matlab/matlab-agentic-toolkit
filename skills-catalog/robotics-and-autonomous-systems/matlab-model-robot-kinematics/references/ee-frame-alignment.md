# End-Effector Frame Alignment for Gripper Attachment

## The Problem

Grippers expect their parent body's Z-axis to be the approach direction (outward from the arm). Most `loadrobot` models have `tool0` Z already aligned with the arm's outward direction — but some do not. Attaching a gripper without checking causes it to point sideways.

## Quick Reference: Which Robots Need Correction?

| Robot | Has `tool0`? | EE Z = Outward? | Action |
|-------|-------------|-----------------|--------|
| All Universal Robots (UR3/5/10/16e) | Yes | Yes | Attach directly to `tool0` |
| ABB IRB120 / IRB120T / IRB1600 | Yes | Yes | Attach directly to `tool0` |
| Techman TM5-700/900, TM12, TM14 | Yes | Yes | Attach directly to `tool0` |
| FANUC LRMate200ib / M16ib | Yes | Yes | Attach directly to `tool0` |
| Kinova Gen3 | Yes | Yes | Attach directly to `tool0` |
| Yaskawa Motoman MH5 | Yes | Yes | Attach directly to `tool0` |
| Meca500 R3 | No (`meca_axis_6_link`) | Yes | Attach directly to last body |
| Robotis OpenManipulator | No (`gripper_link_sub`) | Yes | Attach directly to last body |
| Rethink Sawyer | No (`right_hand`) | Yes | Attach directly to `right_hand` |
| Quanser QArm | No (`END-EFFECTOR`) | Yes | Attach directly to last body |
| Omron Ecobra 600 | No (`link4`) | Yes | Attach directly to last body |
| Puma 560 | No (`link7`) | Yes | Attach directly to last body |
| **KUKA iiwa 7** | **No** (`iiwa_link_ee`) | **No — Z is perpendicular** | **Add `tool0` with Ry(90deg)** |
| **KUKA iiwa 14** | **No** (`iiwa_link_ee`) | **No — Z is perpendicular** | **Add `tool0` with Ry(90deg)** |

## Correction Pattern for KUKA iiwa Models

The KUKA iiwa `iiwa_link_ee` frame has Z pointing perpendicular to the arm (along world -X at home). The arm's geometric outward direction aligns with `iiwa_link_ee` X-axis. Apply a Ry(90deg) correction to create a `tool0` with Z = outward:

```matlab
robot = loadrobot("kukaIiwa7", DataFormat="row");

tool0 = rigidBody("tool0");
tool0Joint = rigidBodyJoint("tool0_joint", "fixed");
R_correction = [0 0 1; 0 1 0; -1 0 0]; % Ry(90deg)
setFixedTransform(tool0Joint, rotm2tform(R_correction));
tool0.Joint = tool0Joint;
addBody(robot, tool0, "iiwa_link_ee");
```

After this, gripper attachment and contact frame placement follow the standard pattern.

## Diagnostic: Verify Any Robot Before Attaching

If a robot is not in the table above (e.g., imported from URDF), verify alignment before attaching a gripper:

```matlab
q = homeConfiguration(robot);
eeBody = "tool0"; % or whatever the EE body is named
tform = getTransform(robot, q, eeBody);

% Get geometric outward: direction from second-to-last link to EE
parentBody = robot.getBody(eeBody).Parent.Name;
tformParent = getTransform(robot, q, parentBody);
outward = tform(1:3,4) - tformParent(1:3,4);

if norm(outward) < 1e-6
    % Zero-length offset — go one link further back
    grandparent = robot.getBody(parentBody).Parent.Name;
    tformGP = getTransform(robot, q, grandparent);
    outward = tform(1:3,4) - tformGP(1:3,4);
end
outward = outward / norm(outward);

% Check if EE Z aligns with outward
eeZ = tform(1:3,3);
alignment = abs(dot(eeZ, outward));
if alignment < 0.99
    warning("EE Z does not align with arm outward (dot=%.3f). Correction needed.", alignment);
end
```

## Why This Matters

- Grippers use their parent's local Z as the approach direction
- If Z points sideways, the gripper sticks out perpendicular to the arm
- IK solutions will be geometrically wrong — the gripper reaches the target but from the wrong direction
- Contact frame offsets (`trvec2tform([0, 0, offset])`) go in the wrong direction

----

Copyright 2026 The MathWorks, Inc.

----
