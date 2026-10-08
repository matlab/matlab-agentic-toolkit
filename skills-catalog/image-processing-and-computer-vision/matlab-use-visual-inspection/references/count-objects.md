
# Counting Objects in Images

Count objects using the right approach for your data and environment. Three
primary methods are available, each suited to different scenarios.

## When to Use

- Counting parts on a conveyor or tray
- Counting defects in an inspection image
- Inventory verification (are all N parts present?)
- Quality check (count matches expected quantity)

## Decision Tree

| Scenario | Data Available | Recommended Approach |
|----------|---------------|---------------------|
| Controlled environment, uniform objects, no labeled data | Single template image | `shapemodel`/`matchshape` with high `MaxMatches` |
| Intra-class variation, few examples (1–3 boxes), no full annotation | A few exemplar bounding boxes | `counTRObjectCounter` (low-shot counting) |
| Complex scenes, labeled bounding box data | Full annotation set | `yoloxObjectDetector` → count detections |

### How to Choose

1. **Are objects uniform in shape?** (same part, same orientation range)
   - Yes → shape matching. Count = number of matches. No training needed.
2. **Do objects vary in appearance?** (different sizes, orientations, partial views)
   - Yes, but you only have a few examples → CounTR (1–3 exemplar boxes)
   - Yes, and you have full bounding box annotations → YOLOX detection

Blob analysis (`bwconncomp` + `regionprops`) is also a standard approach but
requires careful parameter tuning to generalize well — particularly for touching
or overlapping objects. The approaches above are typically more robust for
industrial counting tasks.

## Approach 1: Shape Matching (Template-Based)

Best when objects are geometrically uniform and appear against a relatively
clean background. Requires zero training — just one template.

```matlab
model = shapemodel(template, RotationRange=[-30 30]);
results = matchshape(model, searchImage, MaxMatches=Inf, ScoreThreshold=0.7);
count = numel(results);
fprintf("Found %d objects\n", count)
```

Set `MaxMatches` at least as high as the maximum expected count in the scene.
Use `Inf` when the count is unknown; use a known upper bound (e.g., 50) when
you want to limit computation for speed.

See `references/match-shape.md` for full guidance on parameter tuning, synthetic
templates, and multi-class counting.

**Strengths:** No training, fast, deterministic, works with a single template.
**Limitations:** Struggles with high intra-class variation, heavy occlusion, or
cluttered backgrounds where edges overlap.

## Approach 2: CounTR (Low-Shot Counting)

Best when objects vary in appearance and you have only 1–3 exemplar bounding
boxes. CounTR is a transformer-based density estimation model — it predicts a
density map whose integral equals the count.

### Construction from Exemplar Boxes

Provide an image and bounding boxes around a few representative objects:

```matlab
exemplarImg = imread("scene.png");
exemplarBoxes = [120 80 45 45; 300 210 50 48; 55 310 42 44];
counter = counTRObjectCounter(exemplarImg, exemplarBoxes);
```

### Construction from Patches

Alternatively, provide pre-cropped patches directly:

```matlab
patches = {patch1; patch2; patch3};
counter = counTRObjectCounter(patches);
```

Patches are internally resized to 64×64×3.

### Counting Objects

```matlab
count = countObjects(counter, testImage);
```

For a datastore of images:

```matlab
counts = countObjects(counter, imds);
```

Returns an integer-valued count per image.

### Density Map Visualization

The density map shows where the model believes objects are located:

```matlab
dmap = densityMap(counter, testImage);
overlay = anomalyMapOverlay(testImage, dmap, "Blend", "equal");
imshow(overlay)
title(sprintf("Count = %d", countObjects(counter, testImage)))
```

### Key Considerations

- **Exemplar quality matters:** Choose exemplars representative of the variation
  in the scene (different sizes, orientations, lighting if present).
- **No localization:** CounTR provides a density map but not individual bounding
  boxes. If you need per-object localization, use YOLOX detection instead.
- **Support package required:** CounTR requires the CounTR support package for
  Visual Inspection Toolbox.

## Approach 3: YOLOX Detection

Best for complex scenes with full bounding box annotations. Count = number of
detected objects above threshold.

```matlab
[bboxes, scores, labels] = detect(detector, img, Threshold=0.5);
count = size(bboxes, 1);
```

See `references/detect-objects.md` for training, threshold selection, and
evaluation workflows.

**Strengths:** Precise localization, per-class counting, handles complex scenes.
**Limitations:** Requires labeled training data (bounding boxes for all objects).

## Evaluation

### Shape Matching

Count accuracy is deterministic given parameters. Tune `ScoreThreshold` and
verify against known counts:

```matlab
results = matchshape(model, img, MaxMatches=Inf, ScoreThreshold=0.7);
countError = numel(results) - groundTruthCount;
```

### CounTR

Evaluate counting accuracy across a test set:

```matlab
counts = countObjects(counter, dsTest);
groundTruth = [10; 12; 8; 15; 11];
mae = mean(abs(counts - groundTruth));
fprintf("Mean Absolute Error: %.2f\n", mae)
```

### YOLOX

Use `evaluateObjectDetection` for full AP/PR analysis. Count accuracy follows
from detection accuracy at the chosen threshold.

## Conventions

- **Always:** start with the decision tree — don't default to generic IPT approaches
- **Always:** set `MaxMatches` high enough to not limit the count (at least the max expected objects in the scene)
- **Never:** use CounTR when you need per-object bounding boxes — it only provides density maps
- **Prefer:** shape matching over CounTR when objects are geometrically uniform (simpler, no model needed)
- **Prefer:** CounTR over YOLOX when you lack full bounding box annotations but have a few exemplars

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Defaulting to YOLOX without labeled data | Can't train without bounding box annotations | CounTR (few exemplars) or shape matching (template) |
| `matchshape` with default `MaxMatches=1` | Only finds one object | Set `MaxMatches` ≥ max expected count |
| Using CounTR when objects are perfectly uniform | Overkill — shape matching is simpler and more precise | `shapemodel`/`matchshape` |
| Not choosing representative CounTR exemplars | Model won't generalize to variation in scene | Pick exemplars covering size/orientation range |


----

Copyright 2026 The MathWorks, Inc.

----
