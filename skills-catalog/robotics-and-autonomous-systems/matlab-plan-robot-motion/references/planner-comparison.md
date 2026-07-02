# Planner Comparison

Detailed properties and tuning guidance for each manipulator motion planner.

## manipulatorRRT

Sampling-based planner using Rapidly-exploring Random Trees with connect heuristic.

**Strengths:**
- Works with any environment representation (collision objects, occupancyMap3D)
- Probabilistically complete — will find a path if one exists (given enough iterations)
- Fast for open environments with few narrow passages
- Output feeds directly into `contopptraj`

**Limitations:**
- Paths are jagged — always requires `shorten` post-processing
- Non-deterministic — use `rng(seed, "twister")` for reproducibility
- Slow in cluttered environments with narrow passages

**Key Properties:**

| Property | Default | Guidance |
|----------|---------|----------|
| `MaxConnectionDistance` | 0.1 | Increase (0.2–0.5) for open spaces; decrease (0.05) for narrow passages |
| `ValidationDistance` | 0.01 | Smaller = safer but slower. Keep < MaxConnectionDistance/5 |
| `MaxIterations` | 1000 | Increase to 5000–10000 for cluttered environments |
| `EnableConnectHeuristic` | true | Keep true — significantly speeds up convergence |

**Construction patterns:**

With collision objects:

```matlab
rrt = manipulatorRRT(robot, env);
```

With occupancyMap3D:

```matlab
rrt = manipulatorRRT(robot, {}, Map=omap);
```

With explicit self-collision skip pairs:

```matlab
rrt = manipulatorRRT(robot, env, SkippedSelfCollisions=skipPairs);
```

---

## manipulatorCHOMP

Optimization-based planner (Covariant Hamiltonian Optimization for Motion Planning). Produces inherently smooth trajectories by minimizing a combined smoothness + collision cost.

**Strengths:**
- Output is already smooth — no post-processing needed
- Deterministic (same input → same output)
- Supports `meshtsdf` for continuous cost gradients
- Supports code generation (`%#codegen`)

**Limitations:**
- Can get stuck in local minima (not probabilistically complete)
- Requires mesh-based environment (`meshtsdf`) or `SphericalObstacles`
- Does NOT work with collision object cell arrays or occupancyMap3D
- `MeshTSDF` and many options are read-only after construction

**Key Properties:**

| Property | Default | Guidance |
|----------|---------|----------|
| `SmoothnessOptions.Weight` | 100 | Higher = smoother but may not avoid obstacles. Lower for tight environments |
| `CollisionOptions.CollisionCostWeight` | 10 | Higher = more collision avoidance but less smooth |
| `SolverOptions.MaxIterations` | 200 | Increase to 500 for complex environments |
| `SolverOptions.LearningRate` | 0.1 | Decrease (0.01) if solution oscillates |
| `SkippedSelfCollisions` | "parent" | Set at construction. Use "parent" or explicit pairs |

**Construction pattern:**

```matlab
meshStructs = geom2struct(env);
mTSDF = meshtsdf(meshStructs, Resolution=20, TruncationDistance=0.2);

chomp = manipulatorCHOMP(robot, MeshTSDF=mTSDF, ...
    SkippedSelfCollisions="parent");
trajectory = optimize(chomp, startConfig, goalConfig);
```

**With spherical obstacles (no mesh):**

```matlab
spheres = [0.5 0 0.3 0.1;
           0.3 0.2 0.5 0.08];
chomp = manipulatorCHOMP(robot, SphericalObstacles=spheres, ...
    SkippedSelfCollisions="parent");
```

---

## manipulatorStateSpace + plannerBiRRT

Low-level pipeline giving full control over state space, validator, and planner.

**When to use:** When `manipulatorRRT` defaults don't fit — custom state validation, non-standard sampling, or you need bidirectional RRT specifically.

**Most users should prefer `manipulatorRRT`** which wraps this pipeline with sensible defaults.

```matlab
ss = manipulatorStateSpace(robot);
sv = manipulatorCollisionBodyValidator(ss, env);
sv.ValidationDistance = 0.05;

planner = plannerBiRRT(ss, sv);
planner.MaxConnectionDistance = 0.3;
planner.MaxIterations = 5000;

path = plan(planner, startConfig, goalConfig);
```

---

## dlCHOMP

Deep-learning-accelerated CHOMP. Uses a neural network to predict a good initial trajectory, then refines with CHOMP optimization.

**When to use:** When you have a trained network for your robot/environment class and need fast planning in deployment.

**Most users should start with `manipulatorCHOMP`** and only move to `dlCHOMP` when planning speed is critical and training data is available.

---

## Summary Decision Matrix

| Criterion | manipulatorRRT | manipulatorCHOMP | StateSpace + BiRRT |
|-----------|---------------|------------------|-------------------|
| Guaranteed to find path | Yes (prob. complete) | No (local minima) | Yes (prob. complete) |
| Smooth output | No (needs shorten) | Yes | No (needs shorten) |
| Collision objects | Yes | No | Yes |
| occupancyMap3D | Yes | No | Yes |
| meshtsdf | No | Yes | No |
| Deterministic | No | Yes | No |
| Code generation | Yes | Yes | No |
| Setup complexity | Low | Medium | High |

----

Copyright 2026 The MathWorks, Inc.

----
