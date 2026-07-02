---
name: matlab-model-robot-kinematics
description: >
  Use whenever a MATLAB robot model (rigidBodyTree) is needed — whether for
  simulation, visualization, IK, motion planning, pick-and-place, or trajectory
  generation. Triggers on: any mention of a manipulator by name (UR3, UR5, UR5e,
  UR10, UR10e, UR16e, UR20, KUKA iiwa, Fanuc, ABB, Panda, Kinova, Sawyer,
  Baxter), robot modeling verbs (load, create, build, import, simulate, model),
  tasks implying a robot model (pick, place, lift, reach, move, grasp, plan
  motion for, animate), kinematics keywords (IK, FK, inverse kinematics, forward
  kinematics, joint configuration, end-effector pose, gripper), or working with
  rigidBodyTree, loadrobot, importrobot, URDF, DH parameters, addVisual,
  addCollision.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Robot Modeling & Kinematics

Build manipulator models correctly and validate every kinematic solution.

## When to Use

- Any task that requires a robot model in MATLAB (even if the goal is downstream: animation, pick-and-place, trajectory, motion planning)
- User mentions a specific manipulator by name (UR5e, KUKA iiwa14, Panda, Kinova Gen3, etc.)
- Loading, building, or importing a robot model
- Simulating, animating, or visualizing a manipulator
- Tasks involving lifting, reaching, picking, placing, or grasping
- Adding visual meshes or collision geometry
- Attaching a gripper to a manipulator
- Choosing between `inverseKinematics` vs `generalizedInverseKinematics`
- Validating IK/GIK solutions (exit flags, position error, joint continuity)

## When NOT to Use

- Collision-free motion planning (RRT, CHOMP, path planning) — use a motion planning skill
- Trajectory generation (`contopptraj`, `cubicpolytraj`, `trapveltraj`) — use a trajectory skill
- Closed-loop parallel mechanisms (delta, Stewart) — see `references/parallel-robot-guidance.md`
- Mobile robot navigation or wheeled platforms — not covered here
- Dynamics simulation (`inverseDynamics`, `forwardDynamics`) — separate domain

## Workflow

### Step 1: Determine Model Source

Choose the highest-fidelity source available:

| Priority | Source | When to Use | Why |
|----------|--------|-------------|-----|
| 1 | `loadrobot` | Robot exists in the library | Includes collision meshes, inertias, visuals |
| 2 | `importrobot` | User has URDF/Xacro/SDF file | Preserves mesh references |
| 3 | Build from DH | Only DH parameters available | No collision meshes unless added manually |

**Critical:** A robot without collision meshes will cause downstream motion planning to silently report "collision-free" paths that actually collide. Always prefer sources that include meshes.

If the user says "build a robot" but names a known robot (UR5e, KUKA iiwa, Panda, etc.), suggest `loadrobot` first.

**After importing from URDF, Simscape, or CAD:** Check if collision meshes are present. Simscape Multibody models and many URDFs/CAD exports only provide visual geometry — no collision meshes. If collision meshes are missing, read `references/import-mesh-handling.md` for the decision tree on generating them from visuals.

### Step 2: Load or Build the Model

Always set `DataFormat="row"` — this is required for planning and dynamics workflows.

**Option A — loadrobot:**

```matlab
robot = loadrobot("universalUR5e", DataFormat="row");
```

**Option B — importrobot (URDF/Xacro/SDF):**

```matlab
robot = importrobot("myRobot.urdf", DataFormat="row");
```

If the URDF has only visual geometry (no `<collision>` tags), add VHACD collision decomposition at import time:

```matlab
opts = vhacdOptions("RigidBodyTree");
opts.SourceMesh = "VisualGeometry";
robot = importrobot("myRobot.urdf", DataFormat="row", ...
    MeshPath="path/to/meshes", CollisionDecomposition=opts);
```

**Option C — Build from DH parameters:**

```matlab
robot = rigidBodyTree(DataFormat="row");

body = rigidBody("link1");
jnt = rigidBodyJoint("joint1", "revolute");
setFixedTransform(jnt, [a alpha d 0], "dh");
jnt.PositionLimits = [-pi, pi];
body.Joint = jnt;

addVisual(body, "Cylinder", [0.04, 0.3]);
addCollision(body, "Cylinder", [0.05, 0.3]);

addBody(robot, body, "base");
```

### Step 3: Ensure `tool0` Exists with Z = Outward

Before attaching a gripper, the robot MUST have a `tool0` body whose local Z-axis points along the arm's outward direction (away from the wrist). Most `loadrobot` models satisfy this already — **but KUKA iiwa models do not.**

**Check `references/ee-frame-alignment.md`** for the full compatibility table and diagnostic procedure.

**If the robot already has `tool0` with Z = outward** (all UR, ABB, Techman, FANUC, Kinova, Yaskawa): proceed directly to gripper attachment.

**If the robot lacks `tool0` or EE Z is misaligned** (KUKA iiwa 7/14): add a corrective `tool0` frame:

```matlab
% KUKA iiwa: iiwa_link_ee Z is perpendicular to arm — fix with Ry(90°)
tool0 = rigidBody("tool0");
tool0Joint = rigidBodyJoint("tool0_joint", "fixed");
R_correction = [0 0 1; 0 1 0; -1 0 0]; % Ry(90°)
setFixedTransform(tool0Joint, rotm2tform(R_correction));
tool0.Joint = tool0Joint;
addBody(robot, tool0, "iiwa_link_ee");
```

**For unknown robots (URDF imports):** Run the diagnostic check from `references/ee-frame-alignment.md` to verify alignment before attaching anything.

### Step 4: Configure the Model

**Visuals vs collisions — both are needed, for different purposes:**

| Function | Purpose | Used By |
|----------|---------|---------|
| `addVisual(body, shape, dims)` | Display appearance | `show` for visualization |
| `addCollision(body, shape, dims)` | Planning geometry | `checkCollision`, motion planners |

To color a visual: `addVisual(body, "Mesh", stlFile, tform, FaceColor=[1 0.8 0])`

Robots from `loadrobot` already have both. When building from scratch, add both explicitly.

**Attach a gripper (MANDATORY for manipulation tasks):**

If the task involves object interaction (picking, placing, lifting, grasping, manipulating), a gripper is required — do not skip this step. Only omit for pure visualization or reachability studies with no object contact.

**Before building ANY custom gripper, you MUST read `references/gripper-models.md`.** Available models include both parallel-jaw (`robotiq2F85`, 85mm opening) AND vacuum grippers (`robotiqEPick` variants for large/flat objects). Do NOT assume `robotiq2F85` is the only option.

1. Read `references/gripper-models.md`
2. Follow the decision tree in that file (check compatibility → check object size → select grip strategy)
3. Only build custom if no provided model fits (incompatible manipulator AND object unsuitable for vacuum)

```matlab
gripper = loadrobot("robotiq2F85", DataFormat="row");
addSubtree(robot, "tool0", gripper, ReplaceBase=false);
```

**Critical: Always use `ReplaceBase=false`.** The default (`true`) merges the gripper's base link into the parent body, silently discarding the base visual mesh (the gripper housing/coupling). All provided grippers have a base visual that is lost without this flag.

After attaching a gripper, add a contact frame at the gripper's contact point (fixed joint, zero DOF added), then solve IK to that frame. This avoids confusing tip frame orientations and manual offset math. See `references/gripper-models.md` for per-gripper offsets and the full pattern.

```matlab
contactFrame = rigidBody("contact_point");
contactJoint = rigidBodyJoint("contact_joint", "fixed");
setFixedTransform(contactJoint, trvec2tform([0, 0, gripperOffset]));
contactFrame.Joint = contactJoint;
addBody(robot, contactFrame, "tool0");
```

**Add a custom end-effector frame** (when no gripper is attached or you need a specific offset):

```matlab
ee = rigidBody("tool_tip");
eeJoint = rigidBodyJoint("tool_tip_joint", "fixed");
setFixedTransform(eeJoint, trvec2tform([0.1, 0, 0]));
ee.Joint = eeJoint;
addBody(robot, ee, "tool0");
```

### Step 5: Verify the Model with Kinematics

Use FK and IK to confirm the model is built correctly — correct link lengths, joint axes, limits, and end-effector frame placement.

**Verify with FK:** Move to a known configuration and check the end-effector reaches the expected position.

```matlab
q = homeConfiguration(robot);
tform = getTransform(robot, q, "tool0");
fprintf("Home position: [%.3f, %.3f, %.3f] m\n", tform(1:3,4));
```

Visually confirm the pose makes sense:

```matlab
figure;
show(robot, q, Frames="off");
axis auto;
title("Home configuration");
```

**Verify with IK:** Pick a target you know is reachable and confirm the solver converges.

**Decision — IK vs GIK:**

| Use | When |
|-----|------|
| `inverseKinematics` | Single target pose, no extra constraints |
| `generalizedInverseKinematics` | Multiple constraints (position + aiming, joint bounds, orientation, etc.) |

See `references/gik-constraints.md` for all available GIK constraint types.

```matlab
ik = inverseKinematics(RigidBodyTree=robot);
weights = [0.25 0.25 0.25 1 1 1];
targetPose = trvec2tform([0.4, 0.1, 0.3]) * eul2tform([0 pi 0], "ZYX");
[qSol, solnInfo] = ik("tool0", targetPose, weights, homeConfiguration(robot));
```

### Step 6: Validate Every IK/GIK Solution (MANDATORY)

**Never skip this step.** Agents consistently skip validation and deliver solutions that silently failed.

**After `inverseKinematics`:**

```matlab
if solnInfo.ExitFlag <= 0
    warning("IK did not converge. ExitFlag: %d, Status: %s", ...
        solnInfo.ExitFlag, solnInfo.Status);
end

tformActual = getTransform(robot, qSol, "tool0");
posError = norm(tformActual(1:3,4)' - targetPose(1:3,4)');
if posError > 1e-3
    warning("IK position error %.4f m exceeds threshold.", posError);
end
```

**After `generalizedInverseKinematics`:**

```matlab
if solInfo.ExitFlag <= 0
    warning("GIK did not converge. ExitFlag: %d, Status: %s", ...
        solInfo.ExitFlag, solInfo.Status);
end

for i = 1:numel(solInfo.ConstraintViolations)
    cv = solInfo.ConstraintViolations(i);
    if cv.Violation > 1e-3
        warning("Constraint %d (%s) violated: %.4f", i, cv.Type, cv.Violation);
    end
end
```

**For sequential waypoints — check joint continuity:**

```matlab
for i = 2:size(qAll, 1)
    maxJump = max(abs(qAll(i,:) - qAll(i-1,:)));
    if maxJump > deg2rad(30)
        warning("Joint jump of %.1f deg between waypoints %d and %d.", ...
            rad2deg(maxJump), i-1, i);
    end
end
```

## Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `loadrobot` | Load built-in robot with meshes | Robotics System Toolbox | R2019b |
| `importrobot` | Import from URDF/Xacro/SDF/Simscape | Robotics System Toolbox | R2017a |
| `rigidBodyTree` | Create empty robot model | Robotics System Toolbox | R2016b |
| `setFixedTransform` | Set joint transform (DH or homogeneous) | Robotics System Toolbox | R2016b |
| `addVisual` | Add visual geometry for display | Robotics System Toolbox | R2019a |
| `addCollision` | Add collision geometry for planning | Robotics System Toolbox | R2019b |
| `addSubtree` | Attach subtree (gripper) to body | Robotics System Toolbox | R2016b |
| `getTransform` | Compute FK for a configuration | Robotics System Toolbox | R2016b |
| `inverseKinematics` | Solve IK for single target pose | Robotics System Toolbox | R2016b |
| `generalizedInverseKinematics` | Solve IK with multiple constraints | Robotics System Toolbox | R2017a |
| `show` | Visualize robot configuration | Robotics System Toolbox | R2016b |

## Patterns

### Visualization

```matlab
figure;
show(robot, q, Frames="off");
axis auto;
view(45, 30);
title("Robot at configuration q");
```

For multiple configurations, use `tiledlayout`/`nexttile`:

```matlab
figure;
tiledlayout(1, 3);
for i = 1:3
    nexttile;
    show(robot, qAll(i,:), Frames="off", PreservePlot=false);
    axis auto;
    title(sprintf("Waypoint %d", i));
end
```

### Using Initial Guess to Improve IK Convergence

When solving IK for sequential waypoints, use the previous solution as the initial guess:

```matlab
qPrev = homeConfiguration(robot);
for i = 1:numWaypoints
    [qSol, solnInfo] = ik("tool0", targetPoses(:,:,i), weights, qPrev);
    % ... validate ...
    qPrev = qSol;
end
```

## Conventions

- Always set `DataFormat="row"` on creation or import
- Joint limits in radians (use `deg2rad` when specifying in degrees)
- Use `Frames="off"` and `axis auto` for clean visualization
- Use `tiledlayout`/`nexttile` instead of `subplot`
- Name end-effector frames descriptively (e.g., `"tool_tip"`, `"bucket_tip"`)
- Weights for `inverseKinematics`: `[orientation(3) position(3)]` — set position weights higher for position-priority tasks

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Building from DH when `loadrobot` has the robot | No collision meshes → planning silently fails | Check `loadrobot` library first |
| Using `addCollision` for visual appearance | Collision geometry is simplified, not rendered by `show` | Use `addVisual` for display, `addCollision` for planning |
| Skipping IK validation | Solution may not converge; `ExitFlag <= 0` means failure | Always check `ExitFlag` and verify position error via FK |
| Using `DataFormat="column"` or `"struct"` | Incompatible with planning/trajectory functions that expect row vectors | Always use `DataFormat="row"` |
| Skipping gripper for manipulation tasks | Object interaction (pick, lift, grasp) requires a gripper on the model | Always attach a gripper when the task involves object contact |
| Solving IK to `"tool0"` or tip body without a contact frame | `"tool0"` is the flange (offset from contact point); tip body frames have confusing 90° rotations | Add a fixed `"contact_point"` frame at the gripper offset, solve IK to that |
| Building a custom gripper from scratch | Provided models have accurate geometry and are ready to attach | Check `references/gripper-models.md` for available grippers |
| Using `robotiq2F85` for objects > 85 mm | Jaw cannot open wide enough to grasp the object | Compare object dimensions to gripper max opening; use vacuum for large objects |
| Using IK when multiple constraints are needed | `inverseKinematics` only handles a single pose target | Use `generalizedInverseKinematics` with constraint objects |
| Not checking joint continuity for waypoint sequences | Large jumps between solutions cause unsafe trajectories | Compare consecutive solutions, flag jumps > 30 deg |
| Using `addSubtree` without `ReplaceBase=false` | Gripper base visual mesh is silently discarded; housing disappears from visualization | Always pass `ReplaceBase=false` when attaching grippers |
| Attaching gripper to KUKA iiwa without frame correction | `iiwa_link_ee` Z is perpendicular to arm; gripper points sideways | Add `tool0` with Ry(90°) correction before attaching — see `references/ee-frame-alignment.md` |
| Assuming all `loadrobot` models have `tool0` with Z = outward | Some robots (KUKA iiwa) lack `tool0` or have misaligned EE frames | Check `references/ee-frame-alignment.md` table or run diagnostic before gripper attachment |
| Using `rigidBodyTree` for closed-loop parallel robots | Cannot represent closed kinematic chains | See `references/parallel-robot-guidance.md` |

----

Copyright 2026 The MathWorks, Inc.

----
