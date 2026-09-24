
# Shape Matching for Industrial Object Detection

Locate, count, and classify objects using edge-geometry matching — the industrial
standard for textureless parts under variable lighting.

## When to Use

- Detecting or localizing textureless parts (metal, plastic, molded)
- Counting identical objects in a scene
- Locating a reference feature to reposition downstream measurements
- Multi-class part detection (multiple templates, single search pass)
- Matching objects at arbitrary rotation and/or scale
- Building synthetic templates from known geometry to match real parts

## When NOT to Use

- Texture-rich matching where intensity correlation works — use `normxcorr2`
- Object detection requiring training data — use `yoloxObjectDetector`
- Feature-based matching for natural scenes — use `matchFeatures`
- Anomaly/defect detection — use anomaly detection skills
- Measurement or gauging after localization — use gauging/measurement skill

## Workflow

1. **Create template** — acquire or draw a template image of the target shape
2. **Build model** — `model = shapemodel(template, ...)` with appropriate rotation/scale ranges
3. **Match** — `matches = matchshape(model, searchImage, ...)` to find instances
4. **Use results** — access `Score`, `ModelOriginTransformation`, `RotatedBoundingBox`, `ClassName`
5. **Visualize** — `showmatches(model, matches, searchImage)`

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `shapemodel` | Build edge-geometry model from template | Visual Inspection Toolbox |
| `matchshape` | Find model instances in a search image | Visual Inspection Toolbox |
| `showmatches` | Visualize match results with oriented boxes | Visual Inspection Toolbox |
| `transformPointsForward` | Map points from model frame to image frame | Image Processing Toolbox |

## Patterns

### Core Matching

```matlab
template = imread("myTemplate.png");
model = shapemodel(template, RotationRange=[-180 180]);
searchImage = imread("scene.png");
matches = matchshape(model, searchImage, MaxMatches=20, ScoreThreshold=0.6);
showmatches(model, matches, searchImage);
```

### Counting Objects

Set `MaxMatches=Inf` and count the results. The count equals `numel(matches)`.

```matlab
model = shapemodel(template, RotationRange=[-180 180]);
matches = matchshape(model, searchImage, MaxMatches=Inf, ScoreThreshold=0.7);
numParts = numel(matches);
fprintf("Found %d parts\n", numParts);
```

### Repositioning (Coordinate Transformation)

Each match carries a `ModelOriginTransformation` — a `simtform2d` encoding
translation, rotation, and scale. Use `transformPointsForward` to map points
defined in the template coordinate frame into the search image.

```matlab
matches = matchshape(model, searchImage, MaxMatches=1, ScoreThreshold=0.7);
tform = matches.ModelOriginTransformation;

modelPoints = [50 30; 120 30];
imagePoints = transformPointsForward(tform, modelPoints);
```

This is the correct way to reposition measurements, annotations, or ROIs
relative to a located reference. Do not build manual rotation matrices.

### Multi-Class Detection

Pass an array of `shapemodel` objects to `matchshape`. Use `ClassName` to
distinguish results.

```matlab
modelA = shapemodel(templateA, RotationRange=[-45 45], ClassName="Connector");
modelB = shapemodel(templateB, RotationRange=[-10 10], ClassName="Bracket");

matches = matchshape([modelA; modelB], searchImage, MaxMatches=10, ScoreThreshold=0.6);

for i = 1:numel(matches)
    fprintf("Class: %s, Score: %.3f\n", matches(i).ClassName, matches(i).Score);
end
```

### Synthetic Templates

When a real template image is unavailable, draw the expected geometry
programmatically and use it as the `shapemodel` input. This enables
synthetic-to-real matching — the model uses edge geometry, so drawn shapes
match real parts with the same contours.

```matlab
canvas = zeros(200, 200, "uint8");
canvas = insertShape(canvas, "FilledCircle", [100 100 40], Color="white", Opacity=1);
syntheticTemplate = im2gray(canvas);

model = shapemodel(syntheticTemplate, RotationRange=[0 0], ScaleRange=[0.5 2.0]);
matches = matchshape(model, realImage, MaxMatches=Inf, ScoreThreshold=0.6);
```

Use `insertShape` to draw circles, rectangles, polygons, or lines. Combine
multiple shapes for complex geometry. Set `ScaleRange` broader when the
physical size of real parts varies relative to your drawn template.

## Speed vs. Sensitivity

Tune these parameters when detection is too slow or partially occluded parts are missed.

Key principles:

- **Narrower `RotationRange`/`ScaleRange`** = faster (fewer poses to test)
- **Larger `RotationStep`** = faster (coarser angular sampling)
- **More `NumPyramidLevels`** = faster (coarse global search) but too many risks missing fine shape detail
- **Higher `ScoreThreshold`** = faster (prunes candidates at each pyramid level)
- **Lower `ScoreThreshold`** = catches occluded parts (max achievable score ≈ fraction of visible edges)

The tension: speed wants high `ScoreThreshold`; occlusion recovery wants low
`ScoreThreshold`. Resolve by constraining `RotationRange`/`ScaleRange` for speed
while keeping `ScoreThreshold` low for robustness.

## Conventions

- **Always:** use `shapemodel`/`matchshape` for textureless industrial parts — not `normxcorr2`
- **Always:** use `showmatches` for visualization — do not build manual plotting code
- **Always:** access `ModelOriginTransformation` for coordinate transforms — do not compute rotation matrices manually
- **Never:** use `normxcorr2` with manual rotation loops when `shapemodel` is available
- **Prefer:** `UsePolarity=false` for shiny/specular metal parts where edge polarity flips with lighting

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `normxcorr2` + `imrotate` loop | Hundreds of lines, no sub-pixel pose, no built-in pyramid | `shapemodel` + `matchshape` (3 lines, sub-pixel, pyramid search) |
| Building manual rotation matrix from match results | Error-prone coordinate bookkeeping | `transformPointsForward(matches.ModelOriginTransformation, pts)` |
| Running `matchshape` separately per class | Redundant computation, no cross-class NMS | Pass array `[modelA; modelB]` to single `matchshape` call |
| Setting `MaxMatches=1` when counting | Only returns the best match | `MaxMatches=Inf` with appropriate `ScoreThreshold` |
| Lowering `ScoreThreshold` to speed up | Opposite effect — more candidates to refine | Narrow `RotationRange`/`ScaleRange` or increase `NumPyramidLevels` |
| Using `shapeModel` / `matchShape` (wrong case) | Functions are all-lowercase | `shapemodel`, `matchshape`, `showmatches` |

## Match Result Properties

Each element of the `matches` array is a `Match` object with:

| Property | Type | Description |
|----------|------|-------------|
| `Score` | scalar | Similarity score (0 to 1) |
| `ClassName` | string | Class label from `shapemodel(..., ClassName=...)` |
| `ModelIndex` | scalar | Index into the model array (for multi-class) |
| `ModelOriginTransformation` | `simtform2d` | Pose: translation + rotation + scale |
| `RotatedBoundingBox` | 1×5 vector | `[cx cy width height angle]` |


----

Copyright 2026 The MathWorks, Inc.

----
