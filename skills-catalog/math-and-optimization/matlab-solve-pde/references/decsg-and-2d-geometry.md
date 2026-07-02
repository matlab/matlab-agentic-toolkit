# decsg and 2-D Geometry

## Shape Column Format

Each shape is a column in the geometry description matrix `gd`. All columns must have the same number of rows (pad shorter ones with zeros).

### Rectangle (type 3)

```
[3; 4; x1; x2; x3; x4; y1; y2; y3; y4]
```

Corners listed counterclockwise. Axis-aligned shortcut (BL, BR, TR, TL):

```matlab
R = [3; 4; 0; W; W; 0; 0; 0; H; H];
```

### Circle (type 1)

```
[1; xc; yc; r; 0; 0; 0; 0; 0; 0]
```

### Ellipse (type 4)

```
[4; xc; yc; a; b; angle; 0; 0; 0; 0]
```

### Polygon (type 2)

```
[2; N; x1; x2; ...; xN; y1; y2; ...; yN]
```

Total rows: 2 + 2N. Vertices listed counterclockwise.

```matlab
% Trapezoid (4 vertices)
P1 = [2; 4; x1; x2; x3; x4; y1; y2; y3; y4];
dl = decsg(P1, 'P1', char('P1')');
gm2D = fegeometry(dl);
gm3D = extrude(gm2D, depth);
```

## Namespace Matrix

Each **column** of `ns` is one name:

```matlab
ns = char('R1', 'C1', 'R2')';  % Transpose! columns are names
```

## Set Formula

| Operation | Syntax |
|-----------|--------|
| Union | `'R1+R2'` |
| Subtraction | `'R1-C1'` |
| Intersection | `'R1*C1'` |
| Grouping | `'(R1+R2)-C1'` |

## Complete Example

```matlab
R1 = [3; 4; 0; 2; 2; 0; 0; 0; 1; 1];
C1 = [1; 0.2; 0.5; 0.1; 0; 0; 0; 0; 0; 0];
gd = [R1, C1]; sf = 'R1-C1'; ns = char('R1', 'C1')';
gm = fegeometry(decsg(gd, sf, ns));
```

## Polar-Coordinate Polygons

For symmetric shapes (stars, gears), define vertices by (angle, radius) sweeping CCW:

```matlab
nArms = 6; rValley = 0.02; rTip = 0.08; halfAngle = deg2rad(4);
angles = []; radii = [];
for k = 0:nArms-1
    centerAngle = k * 2*pi/nArms;
    angles = [angles, centerAngle - halfAngle, centerAngle + halfAngle];
    radii = [radii, rValley, rValley];
end
xVerts = radii .* cos(angles);
yVerts = radii .* sin(angles);
P1 = [2; numel(xVerts); xVerts(:); yVerts(:)];
```

## Extrude (2-D to 3-D)

```matlab
gm3d = extrude(gm2d, depth);
```

2-D (x,y) preserved. Z is extrusion direction (0 to depth).

## Tips

- All shapes in `gd` must have same row count — pad with zeros
- `char('name1', 'name2')'` handles padding automatically
- Use `+` (union) of adjacent rectangles to create interior vertices for load application
- After `decsg`, always wrap: `gm = fegeometry(dl)`
- `fegeometry` does NOT accept `polyshape` directly

----
Copyright 2026 The MathWorks, Inc.
----
