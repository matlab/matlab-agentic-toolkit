
# Vision Gauging and Metrology

Measure part dimensions in images and check them against tolerances — a
non-contact replacement for calipers, micrometers, and coordinate measuring
machines.

## Concepts

**Gauging** — Measuring dimensions of a part (lengths, diameters, angles, gap
widths, hole positions) and checking whether they fall within specified
tolerances. The output is a numerical value plus a pass/fail decision.

**Fixturing** (vision fixturing / software fixturing) — Locating the part in
the image using pattern matching or edge-finding on a reference feature, then
transforming the coordinate system so measurement tools are positioned relative
to where the part actually is. This lets parts arrive with variation in position
and rotation without needing precision mechanical fixtures.

**Metrology** — The science of measurement. Vision metrology requires careful
calibration (pixels → real-world units), controlled lighting, and often
telecentric lenses for high-precision cases.

## When to Use

- Measuring part dimensions: widths, diameters, angles, gap sizes
- Tolerance checking: pass/fail against dimensional specifications
- Vision fixturing: locating parts that arrive in varying positions/orientations
- Calibrated measurement in physical units (mm, µm)
- Replacing contact gauges with non-contact vision measurement
- Automated inspection where parts move on a conveyor

## When NOT to Use

- Counting objects — see `references/count-objects.md`
- Defect detection (anomaly or bounding box) — use anomaly/detection skills
- Template matching without measurement — see `references/match-shape.md`

## Measurement Tools

| Tool | Programmatic | Interactive | Measures |
|------|-------------|-------------|----------|
| Caliper | `caliper` | `uicaliper` | Edge distances along a profile line |
| Angle | `fitangle` | `uifitangle` | Angle between two edges |
| Circle | `fitcircle` | `uifitcircle` | Center, radius, area, circumference |
| T-Square | — | `uitsquare` | Perpendicular distance from point to edge |

All tools accept a `Transformation` parameter to report measurements in world
units when spatial referencing is available.

## When Is Camera Calibration Necessary?

Not all gauging applications require full camera calibration. The choice depends
on the precision required and the amount of distortion in the imaging setup:

| Situation | Approach |
|-----------|----------|
| Low-distortion lens, near-top-down view, moderate tolerance | Simple scale factor: measure a known object in pixels, compute mm/pixel |
| Tighter tolerances, noticeable lens distortion, or perspective | Full camera calibration (intrinsics + extrinsics) → `imageToWorldPlane` |

**Simple scale factor** — Machine vision cameras often have low-distortion lenses
and are mounted nearly perpendicular to the imaging plane. In these cases, a
single scale factor (derived from a known reference dimension divided by its
pixel count) passed as an `imref2d` to the `Transformation` parameter is often
sufficient.

**Full calibration** — As required precision tightens and/or lens distortion or
projective distortion becomes significant, you need calibrated intrinsics and
extrinsics. `imageToWorldPlane` corrects both lens distortion and perspective
in a single step, producing a rectified image where each pixel subtends a known
world distance.

## Overall Workflow

1. **Calibrate** — simple scale factor or full camera calibration
2. **Rectify** (if calibrated) — `imageToWorldPlane` or precomputed `imageToWorldPlaneMapping`
3. **Fixture** — locate part with `shapemodel`/`matchshape` to get pose
4. **Reposition** — transform measurement positions to detected part pose
5. **Gauge** — `caliper`/`fitangle`/`fitcircle` with `Transformation`
6. **Decide** — compare measurements against tolerances (pass/fail)

Steps 1–2 are needed only when measuring in physical units. Steps 3–4 are
needed only when part position varies between images.

## Patterns

### Caliper: Edge-Pair Distance (Gauging a Width)

```matlab
linePosition = [100 200; 300 200];
data = caliper(img, linePosition, MeasurementMode="edge-pair");
width = data.IntraEdgeDistance;
```

Output fields:
- `Distance` — distance from start to each detected edge
- `IntraEdgeDistance` — width of each edge pair (start to end)
- `InterEdgeDistance` — gap between consecutive edge pairs

### Caliper: Single-Edge Mode

```matlab
data = caliper(img, linePosition, MeasurementMode="single-edge", ...
    EdgeTransition="rising");
edgePositions = data.Distance;
```

### Caliper Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `Width` | 10 | Number of scan lines averaged for profile |
| `EdgeTransition` | "both" | "rising", "falling", or "both" |
| `GradientThreshold` | 0.1 | Minimum normalized gradient to count as edge |
| `Sigma` | 1.0 | Gaussian smoothing before gradient detection |
| `MeasurementMode` | "edge-pair" | "edge-pair" or "single-edge" |
| `Transformation` | — | `imref2d` or tform for world-unit output |

### Angle Measurement

```matlab
position = [50 100; 150 150; 250 100];
data = fitangle(img, position, Snap=true);
angle = data.Theta;
```

Position is [startPoint; vertex; endPoint]. With `Snap=true`, the tool snaps
to the nearest linear edges in the image.

### Circle Measurement

```matlab
position = [200 200 50];
data = fitcircle(img, position, Snap=true);
diameter = 2 * data.Radius;
```

Position is `[xCenter, yCenter, radius]`. With `Snap=true`, the circle snaps
to nearby image edges via RANSAC. Use `AngleRange` to fit an arc when the
circle is partially occluded.

### Simple Scale Factor (No Full Calibration)

When the lens has low distortion and the view is nearly top-down, derive a
scale factor from a known reference dimension:

```matlab
knownWidthMM = 25.0;
knownWidthPixels = 487;
mmPerPixel = knownWidthMM / knownWidthPixels;
Rout = imref2d(size(img), mmPerPixel, mmPerPixel);
data = caliper(img, linePosition, Transformation=Rout);
widthInMM = data.IntraEdgeDistance;
```

### Calibrated Measurement in World Units (Full Calibration)

When lens distortion or perspective is significant, rectify the image to a
top-down world-coordinate view:

```matlab
[rectified, Rout] = imageToWorldPlane(img, intrinsics, camExtrinsics);
data = caliper(rectified, linePosition, Transformation=Rout);
widthInMM = data.IntraEdgeDistance;
```

`Rout` is an `imref2d` mapping pixels to world units (e.g., mm). All
measurement outputs are then in the calibration unit system.

### Precomputing the Rectification Map (Production)

For repeated measurement on a fixed camera, compute the displacement field
once and reuse it per frame:

```matlab
D = imageToWorldPlaneMapping(intrinsics, camExtrinsics);
rectified = imwarp(img, D);
```

### Projecting Points Without Full Rectification

When you only need world coordinates for specific points:

```matlab
worldPts = imagePointsToWorldPlane(imagePoints, intrinsics, camExtrinsics);
```

### Interactive Measurement with World Units

```matlab
v = viewer2d(SpatialUnits="mm");
hIm = imageshow(rectified, Transformation=Rout, Parent=v);
hCal = uicaliper(hIm, Position=caliperPosition);
```

Set `SpatialUnits` on the `viewer2d` so tools display the unit label.
Interactive tools inherit the transformation from `imageshow`.

### Vision Fixturing with Shape Matching

When part position varies, locate a reference fixture (a stable visual
feature independent of the dimension being measured) and reposition all
measurement tools to the detected pose:

```matlab
model = shapemodel(fixtureTemplate, NumPyramidLevels=3);
matches = matchshape(model, rectified, ScoreThreshold=0.7);
tform = matches.ModelOriginTransformation;

[tform.Translation(1), tform.Translation(2)] = ...
    intrinsicToWorld(Rout, tform.Translation(1), tform.Translation(2));

caliperPosForMatch = transformPointsForward(tform, caliperRelativeToModel);
data = caliper(rectified, caliperPosForMatch, Transformation=Rout);
```

The workflow:
1. Define measurement positions relative to the fixture's model origin (in world coords)
2. Detect fixture with `matchshape` → get `ModelOriginTransformation`
3. Convert translation from intrinsic to world coordinates via `intrinsicToWorld`
4. Apply `transformPointsForward` to reposition measurement tools
5. Gauge at the new position

### Complete Gauging Function (Production Pattern)

```matlab
function [measurement, passFail] = gaugePartWidth(img, D, Rout, fixtureModel, refPosition, tolerance)
    rectified = imwarp(img, D);
    matches = matchshape(fixtureModel, rectified, ScoreThreshold=0.7);
    if isempty(matches)
        measurement = NaN;
        passFail = "no fixture found";
        return
    end
    tform = matches.ModelOriginTransformation;
    [tform.Translation(1), tform.Translation(2)] = ...
        intrinsicToWorld(Rout, tform.Translation(1), tform.Translation(2));
    caliperPos = transformPointsForward(tform, refPosition);
    data = caliper(rectified, caliperPos, Transformation=Rout);
    measurement = data.IntraEdgeDistance;
    passFail = abs(measurement - tolerance(1)) <= tolerance(2);
end
```

## Decision Framework

| Situation | Approach |
|-----------|----------|
| Fixed part position, pixel measurements sufficient | `caliper`/`fitangle`/`fitcircle` directly |
| Need physical units (mm) | Calibrate + `imageToWorldPlane` + `Transformation=Rout` |
| Part position varies image-to-image | Vision fixturing: `matchshape` → reposition tools |
| Production (many images, fixed camera) | Precompute `imageToWorldPlaneMapping`, reuse per frame |
| Only need world coords for specific points | `imagePointsToWorldPlane` (no full rectification) |

## Conventions

- **Always:** pass `Transformation=Rout` when measurements must be in world units
- **Always:** set `viewer2d(SpatialUnits="mm")` for interactive tools to display unit labels
- **Always:** precompute `imageToWorldPlaneMapping` for repeated measurement on fixed cameras
- **Always:** convert `ModelOriginTransformation.Translation` via `intrinsicToWorld` before repositioning
- **Never:** manually build projective transforms for rectification — use `imageToWorldPlane`
- **Prefer:** `fitangle`/`fitcircle` with `Snap=true` over manual edge detection + geometry
- **Prefer:** `caliper` over custom gradient-based edge finding for distance measurement

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Measuring in pixels and scaling manually | Ignores lens distortion, perspective | `imageToWorldPlane` + `Transformation=Rout` |
| Recomputing `imageToWorldPlane` per frame | Slow — recomputes displacement field | `imageToWorldPlaneMapping` once, `imwarp` per frame |
| Missing `SpatialUnits` on viewer | Interactive tools show no unit label | `viewer2d(SpatialUnits="mm")` |
| Repositioning without `intrinsicToWorld` | Translation in `ModelOriginTransformation` is in intrinsic coords | Convert before `transformPointsForward` |
| Building custom projective rectification | Error-prone, misses lens distortion correction | `imageToWorldPlane` handles both |
| Choosing a fixture feature that varies with the measured dimension | Fixture pose correlates with measurement error | Choose fixture independent of what you're measuring |


----

Copyright 2026 The MathWorks, Inc.

----
