# PDE Toolbox Visualization Reference

Always prefer PDE Toolbox-specific plotting options over raw MATLAB graphics.

## Function Selection

| Task | 2-D | 3-D |
|------|-----|-----|
| Geometry with labels | `pdegplot` | `pdegplot` |
| Mesh only | `pdemesh` | `pdemesh` |
| Scalar field (color) | `pdeplot` (XYData) | `pdeplot3D` (ColorMapData) |
| Vector field (quiver) | `pdeplot` (FlowData) | `pdeplot3D` (FlowData) |
| Contour lines | `pdeplot` (Contour) | Not available — use `contourslice` |
| Deformed shape | `pdeplot` (Deformation) | `pdeplot3D` (Deformation) |
| Interactive | `pdeviz` | `pdeviz` |

**Critical:** `pdeplot` is 2-D only. Use `pdeplot3D` for 3-D meshes.

## pdegplot — Geometry

```matlab
pdegplot(gm, FaceLabels="on", FaceAlpha=0.3);  % Essential for identifying faces
pdegplot(gm, EdgeLabels="on", VertexLabels="on");  % 2-D
pdegplot(gm, CellLabels="on", FaceAlpha=0.2);  % Multi-cell
```

Options: `VertexLabels`, `EdgeLabels`, `FaceLabels`, `CellLabels`, `FaceAlpha`, `FaceColor`, `Lighting`.

## pdeplot3D — 3-D Results

```matlab
pdeplot3D(result.Mesh, ColorMapData=result.Temperature, Mesh="on");
colorbar; title("Temperature");

% Deformed shape (static)
pdeplot3D(result.Mesh, ColorMapData=result.VonMisesStress, ...
    Deformation=result.Displacement, DeformationScaleFactor=100);

% Deformed shape (transient — filterByIndex first!)
resultF = filterByIndex(result, numel(result.SolutionTimes));
vm = evaluateVonMisesStress(resultF);
pdeplot3D(resultF.Mesh, ColorMapData=vm, ...
    Deformation=resultF.Displacement, DeformationScaleFactor=100);

% Vector field (quiver)
[qx, qy, qz] = evaluateHeatFlux(result);
pdeplot3D(result.Mesh, FlowData=[qx qy qz]);

% Transparent
pdeplot3D(result.Mesh, ColorMapData=result.Temperature, FaceAlpha=0.5);
```

Options: `ColorMapData`, `FlowData`, `Mesh`, `Deformation`, `DeformationScaleFactor`, `FaceAlpha`, `NodeLabels`, `ElementLabels`.

**Not available on pdeplot3D** (use base MATLAB after):
- Colormap → `colormap("hot")`
- Colorbar → `colorbar`
- Color limits → `clim([lo hi])`
- Title → `title("...")`

## pdeplot — 2-D Results

```matlab
% Temperature with contours
pdeplot(result.Mesh, XYData=result.Temperature, Contour="on", Levels=15, Mesh="on");

% Heat flux quiver
[gx, gy, ~] = evaluateTemperatureGradient(result);
pdeplot(result.Mesh, XYData=result.Temperature, FlowData=[-gx -gy]);

% Deformed shape
pdeplot(result.Mesh, XYData=result.VonMisesStress, ...
    Deformation=result.Displacement, DeformationScaleFactor=50);
```

Options: `XYData`, `XYStyle`, `ZData`, `FlowData`, `Deformation`, `DeformationScaleFactor`, `Mesh`, `Contour`, `Levels`, `ColorMap`, `ColorBar`.

## pdeviz — Interactive (R2021a+)

```matlab
pdeviz(result.Mesh, result.Temperature, Title="Temperature");
pdeviz(result.Mesh, result.VonMisesStress, ...
    DeformationData=result.Displacement, DeformationScaleFactor=200);
```

Use for quick inspection. Use `pdeplot`/`pdeplot3D` for publication figures, quiver, multi-panel.

## FlowData Format

| Function | Shape | Content |
|----------|-------|---------|
| `pdeplot` | N×2 `[Fx Fy]` | 2-D vector field at nodes |
| `pdeplot3D` | N×3 `[Fx Fy Fz]` | 3-D vector field at nodes |

## Partial Mesh Plotting (Subset of Elements)

`pdeplot3D` accepts `(nodes, elements)` instead of a mesh object. Use `findElements` to select a subset — plot full solution on partial mesh to see interior regions (e.g., remove air volume in EM):

```matlab
% Find elements belonging to specific cells (e.g., iron core, skip air)
elemIDs = findElements(result.Mesh, "region", Face=[1 2]);  % 2-D
elemIDs = findElements(result.Mesh, "region", Cell=[1 3]);  % 3-D

% Plot full solution on subset of mesh — pass ALL node data, subset of elements
nodes = result.Mesh.Nodes;
elements = result.Mesh.Elements(:, elemIDs);
pdeplot3D(nodes, elements, ColorMapData=result.MagneticFluxDensity.Magnitude);
```

Solution data is at nodes (not elements) — pass the full solution vector. Only the selected elements are rendered; unreferenced nodes are simply not drawn. No interpolation needed. Ideal for:
- EM: hiding air volume to see flux density in core/magnets
- Multi-material: isolating one region for inspection
- Interior views without cutting planes

## Cross-Section Visualization (3-D → 2-D slice)

```matlab
[xq, yq] = meshgrid(linspace(xmin, xmax, 50), linspace(ymin, ymax, 50));
zq = 0.005 * ones(size(xq));
queryPts = [xq(:)'; yq(:)'; zq(:)'];
Tq = interpolateTemperature(result, queryPts);
Tgrid = reshape(Tq, size(xq));
contourf(xq, yq, Tgrid, 20); colorbar;
```

## Streamline Visualization (Vector Fields)

No PDE Toolbox streamline option — interpolate to a regular grid and use base MATLAB `streamline`:

```matlab
% Interpolate vector field to regular grid
[xq, yq, zq] = meshgrid(linspace(xmin,xmax,20), ...
                         linspace(ymin,ymax,20), ...
                         linspace(zmin,zmax,20));
queryPts = [xq(:)'; yq(:)'; zq(:)'];
Jq = interpolateCurrentDensity(result, queryPts);

Jxg = reshape(Jq.Jx, size(xq));
Jyg = reshape(Jq.Jy, size(yq));
Jzg = reshape(Jq.Jz, size(zq));

% Start points for streamlines
[sx, sy, sz] = meshgrid(xmin, linspace(ymin,ymax,5), linspace(zmin,zmax,5));
streamline(xq,yq,zq, Jxg,Jyg,Jzg, sx,sy,sz);
```

Works with any vector FEStruct result (heat flux, magnetic field, current density). Replace `interpolateCurrentDensity` with the appropriate interpolation function.

## Multi-Panel Layout

```matlab
figure; tiledlayout(1,2);
nexttile; pdeplot3D(result.Mesh, ColorMapData=result.Temperature);
colorbar; title("Temperature");
nexttile; pdeplot3D(result.Mesh, FlowData=[qx qy qz]);
title("Heat flux");
```

## Key Pitfalls

| Temptation | Use Instead |
|------------|-------------|
| `quiver(x,y,u,v)` for flux | `pdeplot(..., FlowData=[Fx Fy])` |
| `trisurf(tri,x,y,T)` | `pdeplot(mesh, XYData=T)` |
| `patch` for deformed shape | `pdeplot3D(..., Deformation=D)` |
| `scatter3(x,y,z,[],T)` | `pdeplot3D(mesh, ColorMapData=T)` |
| `subplot` | `tiledlayout`/`nexttile` |

----
Copyright 2026 The MathWorks, Inc.
----
