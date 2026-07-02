# Primitives and Geometry Import

## 3-D Primitive Options

### multicuboid

```matlab
gm = multicuboid(W, D, H)
gm = multicuboid(W, D, H, ZOffset=offsets)
gm = multicuboid(W, D, H, Void=flags)
```

| Argument | Type | Description |
|----------|------|-------------|
| `W` | scalar or vector | Width(s) along x |
| `D` | scalar or vector | Depth(s) along y |
| `H` | scalar or vector | Height(s) along z |
| `ZOffset` | vector | Z-position of each cuboid's base (default: all 0) |
| `Void` | logical vector | Mark cells as empty (hollow geometry) |

**Origin:** Centered in x and y. Base at z=0 (or z=ZOffset).

```matlab
gm = fegeometry(multicuboid(1, 0.5, 0.2));              % Single cuboid
gm = fegeometry(multicuboid([0.5, 1], [0.5, 1], [1, 1]));  % Nested (2 cells)
gm = fegeometry(multicuboid([1,1], [1,1], [0.3, 0.7], ZOffset=[0, 0.3]));  % Stacked
gm = fegeometry(multicuboid([0.4, 0.5], [0.4, 0.5], [1, 1], Void=[true, false]));  % Hollow
```

### multicylinder

```matlab
gm = multicylinder(R, H)
gm = multicylinder(R, H, ZOffset=offsets)
gm = multicylinder(R, H, Void=flags)
```

**Origin:** Axis aligned with z. Centered in x-y. Base at z=0.

```matlab
gm = fegeometry(multicylinder(0.5, 1));                    % Single cylinder
gm = fegeometry(multicylinder([0.3, 0.5], 1));             % Concentric (pipe)
gm = fegeometry(multicylinder([0.3, 0.5], 1, Void=[true, false]));  % Hollow pipe
```

### multisphere

```matlab
gm = multisphere(R)
gm = multisphere(R, Void=flags)
```

**Origin:** Centered at origin (all axes).

```matlab
gm = fegeometry(multisphere(0.1));                           % Single sphere
gm = fegeometry(multisphere([0.08, 0.1], Void=[true, false]));  % Hollow shell
```

### Origin Summary

| Primitive | x-y | z |
|-----------|-----|---|
| `multicuboid` | Centered | Base at z=0 |
| `multicylinder` | Centered (axis = z) | Base at z=0 |
| `multisphere` | Centered | Centered (z=0 is equator) |

### Capsule Pattern (cylinder + hemispherical ends)

Union full hollow spheres at cylinder ends — overlap absorbed by union:

```matlab
gmCyl = fegeometry(multicylinder([Ri, Ro], L, Void=[true, false]));
gmSph = fegeometry(multisphere([Ri, Ro], Void=[true, false]));
gmCapTop = translate(gmSph, [0, 0, L]);
gmCapsule = union(union(gmCyl, gmSph), gmCapTop);
```

## File Import (STL / STEP)

```matlab
gm = fegeometry("model.stl");
gm = fegeometry("assembly.step");
```

### Import Options

| Option | Default | Purpose |
|--------|---------|---------|
| `FeatureAngle` | 44 | Dihedral angle threshold (degrees) for edge detection. Lower = more faces. |
| `MaxRelativeDeviation` | 1 | Tessellation accuracy for STEP (0.1–10). Lower = finer. |
| `AllowSelfIntersections` | true | Permit self-intersecting geometry. |

```matlab
gm = fegeometry("part.step", FeatureAngle=30, MaxRelativeDeviation=0.5);
```

## Mesh Data Import

```matlab
gm = fegeometry(nodes, elements);                    % nodes N×3, elements M×4
gm = fegeometry(nodes, elements, elementIDToRegionID);  % Multidomain
gm = fegeometry(meshObj);                            % From FEMesh object
```

Supported element types: M×3 (triangles), M×6 (quadratic triangles), M×4 (tetrahedra), M×10 (quadratic tetrahedra).

## Custom Geometry from Computational Geometry Tools

`fegeometry` accepts triangulations (nodes + connectivity). Design shape with any tool, extract boundary:

| Tool | Extract Triangulation |
|------|----------------------|
| `convhull(pts)` | `K = convhull(pts); gm = fegeometry(pts, K);` |
| `alphaShape(pts, alpha)` | `[tri, pts] = boundaryFacets(shp); gm = fegeometry(pts, tri);` |
| `delaunayTriangulation(pts)` | `[tri, pts] = freeBoundary(dt); gm = fegeometry(pts, tri);` |
| `polyshape(x, y)` | `[F, V] = triangulation(pg); gm = fegeometry(V, F);` |
| `isosurface(V, isovalue)` | `fv = isosurface(X,Y,Z,V,val); gm = fegeometry(fv.vertices, fv.faces);` |
| `stlread(file)` | `TR = stlread("file.stl"); gm = fegeometry(TR.Points, TR.ConnectivityList);` |
| `boundary(pts, shrinkFactor)` | `K = boundary(pts, s); gm = fegeometry(pts, K);` |
| `surf2patch` / patch data | `gm = fegeometry(vertices, faces);` |

**Note:** `fegeometry` does NOT accept `polyshape` directly — extract triangulation first.

## Diagnostic Checklist (Before Meshing)

| Check | Expected | How |
|-------|----------|-----|
| Cell count | Matches design | `gm.NumCells` |
| Void exists | Interior is hollow | `findCell(model.Geometry, interiorPoint)` returns NaN |
| Materials assignable | Cells correspond to materials | `findCell(model.Geometry, pt)` at known material locations |
| No fragments | No unexpected extra cells | Compare `NumCells` to expected |

If `generateMesh` fails with "invalid boundary / gaps / self-intersections":
- Degenerate boolean condition (coincident surfaces)
- Gap between parts that weren't properly unioned
- Cutting plane exactly at tangent/equator

----
Copyright 2026 The MathWorks, Inc.
----
