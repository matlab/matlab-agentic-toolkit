---
name: matlab-plan-robot-motion
description: >
  Plan manipulator motion and generate trajectories in MATLAB. Use when the task
  involves moving a robot arm between configurations or poses — whether the user
  says "trajectory," "motion," "path," "move from A to B," or "plan." This skill
  applies regardless of whether the user explicitly mentions collisions or
  obstacles; if geometry exists in the workspace, collision safety is implicit.
  Triggers on: manipulatorRRT, manipulatorCHOMP, dlCHOMP, contopptraj,
  trapveltraj, collision-free path, motion planner, RRT, CHOMP, TOPPRA, path
  shortening, obstacle avoidance for manipulators, time-optimal trajectory,
  velocity limits, acceleration limits, occupancyMap3D, meshtsdf, collision
  objects as environment, trajectory between waypoints, joint interpolation,
  move between poses, constant velocity, trapezoidal profile, feed rate.
  Also triggers when a user has IK solutions or waypoints and needs to connect
  them — whether for time-optimal motion, constant-speed welding/cutting, or
  any other trajectory parameterization.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Manipulator Motion Planning

Plan collision-free paths for manipulators and convert them to time-optimal trajectories that respect velocity and acceleration limits.

## When to Use

- Moving a robot arm between joint configurations or Cartesian poses — regardless of whether the user says "trajectory," "motion," "path," or "plan"
- Generating any trajectory between waypoints (time-optimal, constant-velocity, trapezoidal, minimum-jerk)
- Planning a collision-free path between configurations
- Modeling obstacles as collision environments for planning
- Choosing between motion planners (RRT, CHOMP, dlCHOMP)
- Verifying a trajectory is collision-free
- Any task where the robot moves through space and geometry exists in the workspace — collision safety is implicit even if the user doesn't mention it

## When NOT to Use

- Building, loading, or importing the robot model — use `/matlab-model-robot-kinematics`
- Solving IK/FK or validating solutions — use `/matlab-model-robot-kinematics`
- Attaching grippers or configuring end-effectors — use `/matlab-model-robot-kinematics`
- Mobile robot navigation (wheeled platforms, ground vehicles)
- Dynamics simulation (`inverseDynamics`, `forwardDynamics`)
- Code generation / MEX deployment of planners

## Pre-conditions

Before planning, verify these are satisfied:

0. **MANDATORY: Invoke `/matlab-model-robot-kinematics` first** — Do NOT proceed with any step below until the robot model exists in the MATLAB workspace AND was set up by that skill. Never call `loadrobot`, `importrobot`, or build a `rigidBodyTree` inline in a motion-planning workflow — even if it seems trivial. No exceptions. The modeling skill handles collision mesh validation, gripper selection, EE frame alignment, and known pitfalls (e.g., articulated grippers causing self-collisions with planners). Skipping it leads to wasted iterations.

1. **Robot has collision meshes** — A robot without collision geometry causes planners to report "collision-free" for paths that actually collide. Confirm with:

```matlab
bodies = robot.Bodies;
hasCollision = any(cellfun(@(b) ~isempty(b.Collisions), bodies));
assert(hasCollision, "Robot has no collision meshes — planning results will be invalid.");
```

2. **`DataFormat="row"`** — All planning functions expect row-vector configurations. Verify:

```matlab
assert(strcmp(robot.DataFormat, "row"), "Set DataFormat to 'row' before planning.");
```

## Workflow

### Step 0: Assess Collision Risk

Before choosing a trajectory tool, determine whether the workspace has geometry that the robot could collide with. **Default assumption: if any objects exist near the robot (tables, workpieces, fixtures, tools), collision checking is mandatory** — even if the user only asked for a "trajectory" or "interpolation."

```
Does the workspace contain any geometry (workpiece, table, fixture, tool)?
├── YES → Model it as collision objects (Step 1) and either:
│         ├── Use a planner (Steps 2–3) if configs are far apart or path is non-trivial
│         └── Interpolate directly (Step 4) BUT verify collision-free (Step 5) — if collisions
│             are found, go back and use a planner
└── NO (free space, no objects) → Skip to Step 4 (trajectory generation)
```

**Never assume a straight-line joint interpolation is safe.** Even nearby configurations can produce intermediate poses that dip into workpieces, especially for 6-DOF arms operating close to surfaces (welding, machining, assembly). The cost of checking is low; the cost of a collision is high.

### Step 1: Model the Environment

Choose a representation based on what you have and which planner you'll use:

| Representation | Create With | Works With | Best For |
|---------------|-------------|------------|----------|
| Cell array of collision objects | `collisionBox`, `collisionCylinder`, `collisionSphere`, `collisionMesh` | `manipulatorRRT` | Known geometric obstacles (tables, walls, bins) |
| `occupancyMap3D` | `occupancyMap3D` + `insertPointCloud` | `manipulatorRRT` (via `Map` property) | Point cloud or sensor data |
| `meshtsdf` | `meshtsdf` from `geom2struct` output | `manipulatorCHOMP` | Mesh-based environments needing smooth cost |
| `SphericalObstacles` | N×4 matrix `[x y z radius]` | `manipulatorCHOMP` | Simple sphere approximations |

**Collision objects pattern:**

```matlab
% Table top surface at z = -0.01 (center at z = -0.02 for a 0.02 m thick box)
table = collisionBox(1.2, 0.8, 0.02);
table.Pose = trvec2tform([0.5, 0, -0.02]);

pillar = collisionCylinder(0.05, 0.6);
pillar.Pose = trvec2tform([0.4, 0.0, 0.3]);

env = {table, pillar};
```

**occupancyMap3D pattern:**

```matlab
omap = occupancyMap3D(20);
sensorPose = [0 0 0 1 0 0 0];
insertPointCloud(omap, sensorPose, pointCloudData, 5.0);
```

**meshtsdf pattern (for CHOMP):**

```matlab
meshStructs = geom2struct(env);
mTSDF = meshtsdf(meshStructs, Resolution=20, TruncationDistance=0.2);
```

The `TruncationDistance` must be larger than the largest robot collision sphere radius — otherwise CHOMP cannot detect proximity correctly.

### Step 2: Select a Planner

**Primary decision — what is the environment?**

```
What is the environment representation?
├── Simple primitives (boxes, cylinders, spheres) → manipulatorRRT
├── Dense mesh / CAD STLs → manipulatorCHOMP (meshtsdf is its native input)
├── Point cloud / sensor data → manipulatorRRT (via occupancyMap3D)
└── Just a few spheres → manipulatorCHOMP (SphericalObstacles, lightweight)
```

**Secondary decision — path topology:**

```
Does the path require going "around" obstacles (large joint-space excursion)?
├── YES → Favor manipulatorRRT (global search won't get stuck in local minima)
└── NO (small adjustment to avoid nearby obstacle) → Either works; CHOMP may be faster
```

**Default: `manipulatorRRT`** — it handles all environment types, has robust collision checking, and its output feeds cleanly into `contopptraj`. Note that `shorten` reduces detours and `contopptraj` respects velocity/acceleration limits, but neither smooths out sharp direction changes in the path geometry. If smooth joint-space paths matter (e.g., for reduced jerk or mechanical wear), CHOMP is preferable — it jointly optimizes a smoothness cost and collision avoidance cost, producing inherently smoother trajectories.

See `references/planner-comparison.md` for detailed tuning parameters and performance characteristics.

### Step 3: Plan the Path

**Before planning with manipulatorRRT:** Resolve self-collision skip pairs up front to avoid wasted planning iterations:

1. `[isColl,sepDist,witPts] = checkCollision(robot, startConfig, {}, SkippedSelfCollisions="parent")` — if `isColl(1)==0`, use `"parent"`.
2. Otherwise, build the skip list empirically — see `references/self-collision-skip-procedure.md`.

**manipulatorRRT:**

```matlab
rrt = manipulatorRRT(robot, env, SkippedSelfCollisions=skippedSelfCollisions);
rrt.MaxConnectionDistance = 0.3;
rrt.ValidationDistance = 0.05;
rrt.MaxIterations = 5000;
rrt.EnableConnectHeuristic = true;

rng(0, "twister");
path = plan(rrt, startConfig, goalConfig);
shortenedPath = shorten(rrt, path, 20);
```

Always call `shorten` after `plan` — RRT paths are jagged by nature. The second argument is the number of shortening iterations (20 is a good default; increase for complex environments).

**manipulatorRRT with occupancyMap3D:**

```matlab
rrt = manipulatorRRT(robot, {}, Map=omap);
rrt.MaxConnectionDistance = 0.2;
rrt.ValidationDistance = 0.02;
```

Pass an empty cell `{}` for collision objects when using only the map.

**manipulatorCHOMP:**

```matlab
chomp = manipulatorCHOMP(robot, MeshTSDF=mTSDF, ...
    SkippedSelfCollisions="parent");
chomp.SmoothnessOptions.Weight = 100;
chomp.CollisionOptions.CollisionCostWeight = 10;
chomp.SolverOptions.MaxIterations = 200;

trajectory = optimize(chomp, startConfig, goalConfig);
```

`MeshTSDF` must be passed at construction — it is read-only after creation.

**Self-collision handling:** Pass `SkippedSelfCollisions` at construction time. Setting it after construction can cause type mismatches (especially in codegen contexts).

**NEVER use `clearCollision` to work around self-collision issues.** Removing collision meshes silently disables collision checking for those bodies — the planner will report "collision-free" for paths that actually collide.

**Strategy:** First try `SkippedSelfCollisions="parent"`. If the planner still reports self-collision at a valid configuration, build the skip list empirically using the procedure in `references/self-collision-skip-procedure.md`.

**Key facts about `checkCollision` (easily misunderstood):**

- `separationDist` body ordering: rows/cols 1:m are `robot.Bodies{1:m}` in order; index m+1 is `robot.BaseName`. **The base is LAST, not first.**
- `NaN` = pair is in collision. `Inf` = pair was successfully skipped.
- `isColliding` returns `true` if ANY `NaN` exists in the matrix. The skip list must eliminate all NaN entries — a pair that appears in your skip list but still shows NaN means the skip didn't take effect (check name spelling and char vs string types).
- `{" "," "}` (space characters in a 1×2 cell) is the dummy skip pair that suppresses the default parent-skip behavior without actually skipping any real pair.
- The always-NaN-across-samples approach catches parent-child overlaps (~100% collision rate), but parallel-linkage grippers (e.g., robotiq2F85) have additional pairs at ~70-90% that still need skipping. After the first pass, re-check home — if still colliding, add the remaining NaN pairs iteratively.

### Step 4: Generate Trajectory (Time-Parameterize the Path)

Choose based on application need:

| Need | Tool | Key Property |
|------|------|-------------|
| Minimum time respecting joint limits | `contopptraj` | TOPPRA algorithm — truly time-optimal |
| Constant velocity in working zone (welding, cutting, dispensing) | `trapveltraj` | Guaranteed zero-acceleration cruise phase |
| Smooth motion minimizing jerk (no obstacles) | `minjerkpolytraj` | Minimizes ∫jerk² cost |

**`contopptraj` (time-optimal):**

```matlab
velLimits = [-2*ones(numJoints,1), 2*ones(numJoints,1)];
accelLimits = [-5*ones(numJoints,1), 5*ones(numJoints,1)];
[q, qd, qdd, tSamples] = contopptraj(shortenedPath', velLimits, accelLimits);
```

**`trapveltraj` (constant-velocity cruise):**

```matlab
[q, qd, qdd, tSamples] = trapveltraj(shortenedPath', 500, AccelTime=0.4);
```

`AccelTime` sets the ramp duration — everything between ramps is constant velocity. Use `PeakVelocity` to set an explicit cruise speed.

**`minjerkpolytraj` (smooth interpolation):**

```matlab
tPoints = linspace(0, 3, size(shortenedPath', 2));
[q, qd, qdd, ~, tSamples] = minjerkpolytraj(shortenedPath', tPoints, 500);
```

**Critical notes:**
- All three expect numJoints×numWaypoints — **transpose** RRT output (`shortenedPath'`)
- All return numJoints×numSamples
- Never use manual trapezoidal code or `interp1` + `gradient` — these tools replace them
- `contopptraj` does NOT guarantee constant velocity; `trapveltraj` does NOT minimize time — pick the right one

### Step 5: Verify Collision-Free Trajectory

The planner verified waypoints, but `contopptraj` interpolates between them. Verify the full trajectory:

```matlab
% q from contopptraj is numJoints×numSamples — transpose for checkCollision (expects row vectors)
qRows = q';
inCollision = false;
for i = 1:size(qRows, 1)
    result = checkCollision(robot, qRows(i,:), env, SkippedSelfCollisions="parent");
    % result is 1×2: [selfCollision, worldCollision] — check BOTH
    if any(result)
        warning("Collision at trajectory sample %d (t=%.3f s), self=%d world=%d", ...
            i, tSamples(i), result(1), result(2));
        inCollision = true;
        break;
    end
end
if ~inCollision
    fprintf("Trajectory is collision-free (%d samples verified).\n", size(qRows,1));
end
```

If collisions are found in the interpolated trajectory, increase the planner's `ValidationDistance` (smaller = finer checking during planning) and re-plan.

### Step 6: Visualize

```matlab
figure;
show(robot, q(1,:), Frames="off");
hold on;
for k = 1:numel(env)
    show(env{k});
end
title("Motion Plan — Start Configuration");
axis auto;
view(45, 30);
```

Animate the trajectory:

```matlab
figure;
ax = show(robot, q(1,:), Frames="off");
hold on;
for k = 1:numel(env)
    show(env{k});
end
axis auto;
view(45, 30);
title("Motion Plan Animation");

for i = 1:10:size(q,1)
    show(robot, q(i,:), Frames="off", PreservePlot=false, Parent=ax);
    drawnow;
end
```

## Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `manipulatorRRT` | Sampling-based collision-free planner | Robotics System Toolbox | R2021b |
| `manipulatorCHOMP` | Optimization-based smooth planner | Robotics System Toolbox | R2023a |
| `contopptraj` | Time-optimal trajectory (TOPPRA) | Robotics System Toolbox | R2023b |
| `trapveltraj` | Trapezoidal velocity profile (constant-velocity cruise) | Robotics System Toolbox | R2019a |
| `minjerkpolytraj` | Minimum-jerk polynomial trajectory | Robotics System Toolbox | R2022a |
| `checkCollision` | Check robot-environment collision | Robotics System Toolbox | R2020b |
| `collisionBox` | Box collision primitive | Robotics System Toolbox | R2019b |
| `collisionCylinder` | Cylinder collision primitive | Robotics System Toolbox | R2019b |
| `collisionSphere` | Sphere collision primitive | Robotics System Toolbox | R2019b |
| `collisionMesh` | Mesh collision primitive | Robotics System Toolbox | R2019b |
| `occupancyMap3D` | 3D voxel map from point clouds | Navigation Toolbox | R2019b |
| `meshtsdf` | Truncated signed distance field from meshes | Robotics System Toolbox | R2023a |
| `geom2struct` | Convert collision geometries to mesh structs | Robotics System Toolbox | R2023a |
| `manipulatorStateSpace` | Custom state space for planners | Robotics System Toolbox | R2021b |
| `plannerBiRRT` | Bidirectional RRT (with state space) | Navigation Toolbox | R2020b |

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `trapveltraj` when time-optimality is needed | Trapezoidal profiles are NOT time-optimal — they over-allocate time | Use `contopptraj` (TOPPRA). `trapveltraj` is correct when constant velocity is the goal. |
| Using `contopptraj` when constant velocity is needed | TOPPRA varies velocity continuously to minimize time — no steady cruise phase | Use `trapveltraj` with `AccelTime` for welding/cutting/dispensing applications |
| Building manual trapezoidal time computation | Reinvents a solved problem incorrectly; 20+ lines replaced by one call | `contopptraj` or `trapveltraj` depending on need |
| Using `interp1` + `gradient` for trajectory | Numerical differentiation is noisy and doesn't respect limits | Use the appropriate trajectory function — all return q, qd, qdd analytically |
| Skipping collision checks for "simple" interpolation | Even nearby configurations produce intermediate poses that can collide with workpieces, especially near surfaces | Always verify with `checkCollision` across all trajectory samples (Step 5) |
| Using `clearCollision` to fix self-collision errors | Removes collision checking for those bodies entirely — planner silently ignores real collisions | Discover the correct skip pairs empirically (see Self-collision handling above) |
| Planning without collision meshes on robot | Planner reports "collision-free" for paths that actually collide | Verify `robot.Bodies` have collision geometry before planning |
| Setting `SkippedSelfCollisions` after construction | Can cause type mismatches; fragile in codegen | Pass as name-value at planner construction |
| Setting `MeshTSDF` after CHOMP construction | Property is read-only after creation | Pass `MeshTSDF=mTSDF` at construction |
| Not calling `shorten` after RRT `plan` | RRT paths are jagged with unnecessary detours | Always call `shorten(rrt, path, 20)` |
| Verifying collisions only at planner waypoints | Interpolated trajectory points between waypoints can still collide | Check `checkCollision` across all `contopptraj` output samples |
| Passing RRT path directly to `contopptraj` without transposing | `manipulatorRRT/plan` returns N×numJoints (rows=waypoints) but `contopptraj` expects numJoints×N (columns=waypoints) | Transpose: `contopptraj(path', velLimits, accelLimits)` |
| Using `contopptraj` output `q` directly with `checkCollision` | `contopptraj` returns numJoints×numSamples but `checkCollision` expects row vectors | Transpose: `checkCollision(robot, q(:,i)', env, ...)` or work with `q'` |
| Using `DataFormat="column"` with planners | `manipulatorRRT`/`plan` expect row vectors | Set `DataFormat="row"` on the robot before planning |
| Treating `checkCollision` output as a scalar | With world objects, `checkCollision` returns 1×2: `[selfCollision, worldCollision]`. Using it as `if checkCollision(...)` only tests `selfCollision` (element 1) — world collisions are silently ignored | Always capture the result: `result = checkCollision(...)` then check `any(result)` or inspect `result(2)` for world collision specifically |
| `TruncationDistance` too small for `meshtsdf` | CHOMP cannot detect proximity if truncation < robot sphere radius | Set `TruncationDistance` > max collision sphere radius (typically 0.2+) |
| Placing a ground/floor collision object with its top surface at z=0 | Robot base collision meshes extend up to 5 mm below z=0 (worst case: `universalUR5` at 5 mm; most others ~1 mm). Additionally, many `loadrobot` home configurations extend the arm horizontally, causing distal links to dip below z=0. Both cause immediate world-collision before planning begins. | Place the ground surface top at z ≤ −0.01 (clears all `loadrobot` base meshes). Only include a ground plane if the task requires one. Always verify start/goal configs are collision-free with `checkCollision` before calling `plan` — if they collide, adjust IK initial guesses or raise target positions rather than lowering the floor. |

----

Copyright 2026 The MathWorks, Inc.

----
