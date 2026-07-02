# Boolean Operations and Cell Modification

## Boolean Operations

```matlab
gmCombined = union(gm1, gm2);                          % Merge into 1 cell
gmCombined = union(gm1, gm2, KeepBoundaries=true);     % Preserve cells
gmCombined = union(gm1, [gm2, gm3, gm4]);              % Vector of geometries
gmResult = subtract(gm1, gm2);                         % Remove gm2 from gm1
gmResult = subtract(gm1, [gm2, gm3]);                  % Remove multiple
gmOverlap = intersect(gm1, gm2);                       % Keep overlap only
```

**Rules:**
- `KeepBoundaries=true` when shapes get different materials
- Union first, subtract last
- The function is `subtract` — NOT `subtractgeom`
- Never assemble pre-hollowed pieces — voids don't merge reliably

## Strategy A: Sculpt + Carve (multi-body assemblies with voids)

1. Union all solid material (walls, caps, external bodies)
2. One `subtract` at the end for the entire interior cavity

```matlab
outerCapsule = union(union(outerCyl, outerSphBot), outerSphTop);
outerAssembly = union(outerCapsule, pedestals, KeepBoundaries=true);
gm = subtract(outerAssembly, innerCapsule);  % one subtract hollows everything
```

## Strategy B: Void Flags (simplest when primitives suffice)

```matlab
gm = fegeometry(multicylinder([0.5, 0.55], 1, Void=[true, false]));
```

Void cells survive `union` — no subtract needed.

## Avoiding Degenerate Intersections

Never place cutting planes on tangent/equator/shared boundary → produces 0 cells.

- **Wrong:** cut sphere at equator
- **Right:** offset cutting block well past surface

Prefer full-sphere-union approach over cutting with `intersect`/`subtract`.

## Array Pattern (fin arrays, bolt holes)

```matlab
gmUnit = fegeometry(multicylinder(0.002, 0.01));
parts = fegeometry.empty;
for ix = -1:1
    parts(end+1) = translate(gmUnit, [ix*spacing, 0, 0]);
end
gmArray = union(parts(1), parts(2:end));
```

## Cell Modification Functions

| Function | Purpose |
|----------|---------|
| `addCell(gm, gmInner)` | Add geometry as new cell inside existing cell |
| `addVoid(gm, gmInner)` | Create empty cavity (no mesh, no material) |
| `addFace(gm, edgeIDs)` | Split cell using closed edge contour |
| `addVertex(gm, Coordinates=[x,y])` | Add vertex on boundary (2-D) |
| `deleteCell(gm, cellIDs)` | Remove unwanted cells |
| `findCell(model.Geometry, [x,y,z])` | Query which cell contains point (NaN = void). **`fegeometry` only** — use `model.Geometry`, not the raw `DiscreteGeometry` from `multicuboid`/`multicylinder` |
| `mergeCells(gm)` | Merge ALL cells into one |
| `mergeCells(gm, cellIDs)` | Merge specified cells (must be connected) |

**`addCell` vs `union(KeepBoundaries=true)`:** Use `addCell` when inner shape is fully contained. Use `union(KeepBoundaries=true)` when shapes overlap or are adjacent.

**`mergeCells` precondition:** Only call on multi-cell geometries (from `KeepBoundaries=true` or `addCell`). Plain `union` without `KeepBoundaries` already produces a single cell — calling `mergeCells` on it errors.

## Face Imprinting via Sphere + deleteCell

Split a boundary face into sub-faces (inscribe a circle):

```matlab
center = (faceDist + offset) * faceNormal;
gmSph = fegeometry(multisphere(rSphere));
gmSph = translate(gmSph, center);
gm = union(gm, gmSph, KeepBoundaries=true);
testPt = (faceDist + offset + rSphere*0.5) * faceNormal;
idOuter = findCell(gm, testPt);
gm = deleteCell(gm, idOuter);
gm = mergeCells(gm);  % ONCE at end, after all imprint operations
```

**Critical:** Call `mergeCells` only ONCE at the end. Calling between operations destroys intended topology.

## Hollow Geometry Recipes

### Recipe A: Void + Hemisphere Cut

```matlab
gmCyl = fegeometry(multicylinder([Ri, Ro], L, Void=[true, false]));
gmSph = fegeometry(multisphere([Ri, Ro], Void=[true, false]));
cutBlock = fegeometry(multicuboid(3, 3, 3));
cutBlock = translate(cutBlock, [0, 0, -2]);
gmHemiUpper = subtract(gmSph, cutBlock);
gmCapTop = translate(gmHemiUpper, [0, 0, L]);
gmCapBot = scale(gmHemiUpper, [1, 1, -1]);
gmVessel = union(union(gmCyl, gmCapTop), gmCapBot);
```

### Recipe B: Full Sphere Union + Final Subtract

```matlab
outerCyl = fegeometry(multicylinder(Ro, L));
outerSphBot = fegeometry(multisphere(Ro));
outerSphTop = translate(fegeometry(multisphere(Ro)), [0, 0, L]);
outerCapsule = union(union(outerCyl, outerSphBot), outerSphTop);
innerCapsule = union(union(innerCyl, innerSphBot), innerSphTop);
assembly = union(outerCapsule, pedestals, KeepBoundaries=true);
gm = subtract(assembly, innerCapsule);
```

No degenerate cuts, no deleteCell needed.

----
Copyright 2026 The MathWorks, Inc.
----
