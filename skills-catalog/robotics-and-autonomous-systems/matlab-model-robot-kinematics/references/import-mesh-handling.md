# Handling Meshes After Import

## The Problem

Not all model sources provide collision geometry. After `importrobot`, the model may have visual meshes but no collision meshes — meaning `checkCollision` and motion planners have nothing to work with.

## Which Sources Provide What

| Source | Visual Meshes | Collision Meshes |
|--------|:---:|:---:|
| URDF with both `<visual>` and `<collision>` tags | Yes | Yes |
| URDF with only `<visual>` tags | Yes | No |
| Simscape Multibody (`.slx`) | Yes | No |
| CAD exports (OnShape, SolidWorks URDF) | Yes | No |
| `loadrobot` library models | Yes | Yes |

Simscape Multibody has no concept of collision geometry — solids define inertia and visualization only. This makes "visual present, collision missing" the **most common** import scenario, not an edge case.

## Decision Tree

```
After import, check collision state:
│
├─ Both visual AND collision present?
│  └─ Use as-is. No action needed.
│
├─ Visual present, collision MISSING?
│  │
│  ├─ Fresh import (calling importrobot now)?
│  │  └─ PREFERRED: Use importrobot's CollisionDecomposition option.
│  │     One line — handles decomposition and attachment internally.
│  │
│  └─ Model already loaded (from loadrobot or prior import)?
│     └─ Manual loop: stlread → collisionVHACD → addCollision per body.
│
└─ Neither present (no STL files available)?
   └─ ONLY THEN fall back to primitive shapes (cylinder, box, sphere).
       This is a last resort — primitives create a false sense of
       safety in simulation that could break on real hardware.
```

**Critical: Always prefer VHACD decomposition over primitives or raw convex hulls.** Primitive shapes (cylinders, boxes) do not match the actual link geometry. And `addCollision(body, "Mesh", file)` produces a single convex hull that fills in concavities — an L-shaped link becomes a solid block. Use VHACD decomposition to get accurate convex pieces that preserve the link's actual shape.

**Direction is one-way:** visual → collision is the standard workflow. Collision → visual does not work — collision meshes are intentionally simplified/shrunk and produce unacceptable visual results.

## Generating Collision Meshes from Visual Geometry

### Preferred: Import-Time Decomposition (Fresh URDF/Xacro/SDF Import)

When importing a URDF that has only visual geometry, use `importrobot`'s `CollisionDecomposition` option with `SourceMesh="VisualGeometry"`. This handles VHACD decomposition and attachment in one step:

```matlab
opts = vhacdOptions("RigidBodyTree");
opts.SourceMesh = "VisualGeometry";
robot = importrobot("myRobot.urdf", DataFormat="row", ...
    MeshPath="path/to/meshes", CollisionDecomposition=opts);
```

**Why `SourceMesh="VisualGeometry"`:** The default is `"CollisionGeometry"`, which decomposes existing collision meshes. For visual-only URDFs (no `<collision>` tags), you MUST set this to `"VisualGeometry"` — otherwise there is nothing to decompose.

**Optional tuning via vhacdOptions properties:**
- `MaxNumConvexHulls` — default 32; reduce for faster planning, increase for fidelity
- `VoxelResolution` — default 128000; higher = more accurate decomposition
- `MaxNumVerticesPerHull` — default 128; lower = simpler collision shapes

### Manual Loop: For Already-Loaded Models

When the model is already in memory (e.g., from `loadrobot` or a previous `importrobot` call without collision decomposition), use the manual per-body approach:

```matlab
for i = 1:robot.NumBodies
    body = robot.Bodies{i};
    stlFile = fullfile(visualDir, stlFiles(i));
    if isfile(stlFile)
        tri = stlread(stlFile);
        convexParts = collisionVHACD(tri);
        for k = 1:numel(convexParts)
            addCollision(body, convexParts{k});
        end
    end
end
```

**Why `collisionVHACD`:** It decomposes the concave mesh into multiple convex pieces (typically 10–40 per link) that closely approximate the original shape. Gaps, holes, and concavities are preserved. A motion plan validated against this geometry will behave predictably on real hardware.

**Why NOT `addCollision(body, "Mesh", file)`:** Despite appearances, `addCollision` with `"Mesh"` produces a single convex hull — all concavities are filled in. For links with holes, L-shapes, or dumbbell geometry (like a UR forearm), the convex hull is a poor approximation that creates phantom collisions where none exist on the real hardware.

**Trade-off:** Adjacent links may report self-collision because the geometry is tight-fitting — mitigate with skip pairs (see below), not by switching to primitives. VHACD decomposition adds a few seconds per link at import time, but this is a one-time cost.

### Fallback: Primitive Shape Approximation

Use primitives when visual STL files are not available (e.g., the URDF had no mesh files, or the model was built from DH parameters), or when the user explicitly prioritizes planning speed over geometric fidelity:

```matlab
addCollision(body, "Cylinder", [radius, length], tformOffset);
addCollision(body, "Box", [xLen, yLen, zLen], tformOffset);
addCollision(body, "Sphere", [radius], tformOffset);
```

If the user requests primitives for speed, inform them of the tradeoff: primitives may approximate link geometry poorly in some cases — a cylinder around an L-shaped link leaves gaps where collisions go undetected. Plans validated against primitives may not transfer cleanly to real hardware where the actual geometry collides. Let the user make that decision consciously.

## Dealing with Self-Collision from Tight-Fitting Meshes

When visual meshes are used directly as collision, adjacent (non-parent-child) links often report self-collision because the visual geometry has zero clearance at joints. This manifests as `checkCollision` returning `true` even in obviously valid configurations like home.

**Diagnosis:**

```matlab
[isColliding, sepDist] = checkCollision(robot, homeConfiguration(robot), ...
    SkippedSelfCollisions="parent");
if any(isColliding)
    warning("Self-collision at home — likely tight-fitting visual meshes.");
end
```

**Mitigation options:**

1. **Add skip pairs** for links known to be geometrically close (joints 2-apart):
   ```matlab
   skipPairs = ["iiwa_link_0","iiwa_link_2"; "iiwa_link_1","iiwa_link_3"];
   checkCollision(robot, q, SkippedSelfCollisions=skipPairs);
   ```

2. **Scale down collision meshes** — re-import the visual STL, apply a scale factor < 1 to the vertices, write out a shrunk version, then use that for collision.

3. **Switch to primitive shapes** for the problematic links while keeping mesh collision on the rest.

## Applying to an Imported Model (Pattern)

**Preferred — import-time decomposition (fresh import):**

```matlab
opts = vhacdOptions("RigidBodyTree");
opts.SourceMesh = "VisualGeometry";
robot = importrobot("myRobot.urdf", DataFormat="row", ...
    MeshPath="/path/to/visual/meshes", CollisionDecomposition=opts);
```

**Alternative — manual loop (model already loaded without collision):**

```matlab
robot = importrobot("myRobot.urdf", DataFormat="row");

% Check which bodies lack collision
for i = 1:robot.NumBodies
    body = robot.Bodies{i};
    if isempty(body.Collisions)
        fprintf("No collision: %s\n", body.Name);
    end
end

% Decompose visual STLs with VHACD
visualDir = "/path/to/visual/meshes";
for i = 1:numel(linkNames)
    body = robot.getBody(linkNames(i));
    stlFile = fullfile(visualDir, linkStlFiles(i));
    tri = stlread(stlFile);
    convexParts = collisionVHACD(tri);
    for k = 1:numel(convexParts)
        addCollision(body, convexParts{k});
    end
end
```

## Summary

| Scenario | Action | Tradeoff |
|----------|--------|----------|
| Both present | Use as-is | None |
| Visual only (Simscape, URDF, CAD) | Add collision from visuals | Tight fit → possible self-collision |
| Neither | Add primitives manually | Crude but functional |
| Need better planning performance | Use primitives or scale down meshes | Less geometric fidelity |

----

Copyright 2026 The MathWorks, Inc.

----
