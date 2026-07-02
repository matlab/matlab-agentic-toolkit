# Parallel Robot Guidance

## The Limitation

`rigidBodyTree` models **open-chain serial mechanisms only**. It cannot represent closed kinematic chains (parallel robots).

Parallel robots include: delta robots, Stewart platforms, 5-bar linkages, and any mechanism where multiple actuated chains connect the base to a single end-effector platform.

## Decision Gate

Ask early: "Is this an open-chain or closed-loop mechanism?"

| Mechanism | Tool |
|-----------|------|
| Serial manipulator (UR, KUKA, Panda, etc.) | `rigidBodyTree` — use this skill |
| Closed-loop parallel robot (delta, Stewart, etc.) | Simscape Multibody + `KinematicsSolver` |

## What NOT to Do

- Do not build custom geometric IK/FK solvers from scratch
- Do not approximate a parallel robot as an open chain by "breaking" a loop
- Do not use `importrobot` with `BreakChains="remove-joints"` as a workaround for kinematics — this changes the mechanism's behavior

## Correct Approach for Parallel Robots

1. **Model in Simscape Multibody** — use rigid transform blocks, revolute/prismatic joints, and closed-loop topology
2. **Use `KinematicsSolver`** — solves the closed-loop kinematics for desired end-effector pose
3. **For simulation** — Simscape handles constraint forces and closed-loop dynamics natively

This is outside the scope of the robot modeling & kinematics skill. If the user needs a parallel robot, direct them to Simscape Multibody documentation.

----

Copyright 2026 The MathWorks, Inc.

----
