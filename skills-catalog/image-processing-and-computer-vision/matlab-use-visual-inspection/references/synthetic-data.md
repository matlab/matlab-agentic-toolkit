
# Synthetic Data Generation and Auto-Labeling

Generate synthetic training images by pasting labeled defect instances into
clean background images. Labels (bounding boxes, class names, instance masks)
are produced automatically — no manual annotation needed for the synthetic set.

## When to Use

- Small labeled dataset, need more training images
- Have pixel-labeled defect examples and unlabeled good images
- Want to pre-train YOLOX before fine-tuning on real data
- Need instance segmentation training data from limited examples
- Copy-paste augmentation for industrial defect detection

## When NOT to Use

- No segmented defect examples available — label some first
- Need photorealistic 3D rendering from CAD — different workflow
- Standard augmentation (flips, rotations, color jitter) is sufficient — use `imageDataAugmenter`

## Key Functions

| Function | Purpose |
|----------|---------|
| `objectInsertionDatastore` | Generate a full synthetic labeled dataset as a datastore |
| `insertObjectInImage` | Insert one object into one image (low-level, single-image use) |

## Concepts

**Copy-paste augmentation** — Cut a labeled object from one image using its
pixel mask and paste it into a clean background at a random location with
blending. The inserted object's bounding box and mask are known exactly,
providing free labels.

**Source datastore** — Provides defect instances. Each read returns a 4-element
cell: `{Image, BoundingBoxes, Labels, Masks}` where `Masks` is
`logical(H,W,P)` with P planes for P objects.

**Destination datastore** — Provides clean background images. Can optionally
return `{Image, RegionConstraintMask}` to restrict where objects may be placed.

## Overall Workflow

1. **Prepare source data** — segment defects, store with boxes/labels/masks
2. **Prepare destinations** — collect clean/good images
3. **Configure** — set insertion count, overlap, blending, geometric augmentation
4. **Generate** — `objectInsertionDatastore` produces labeled synthetic images
5. **Train** — feed datastore directly to `trainYOLOXObjectDetector`, or write to disk first
6. **Fine-tune** — fine-tune the synthetically pre-trained model on real labeled data

## Online vs. On-Disk Synthetic Data

| Approach | Pros | Cons |
|----------|------|------|
| Online (datastore → trainer directly) | Simplest code; infinite variety each epoch | Slower training — blending/insertion recomputed every image every epoch |
| On-disk (`writeall` then train from files) | Faster training (read-only I/O); fixed dataset for reproducibility, visualization, QA | Requires disk space; less variety (fixed set) |

Choose on-disk when training speed matters or you want experiment management
with a fixed dataset. Choose online when you want maximum variety and simpler
code.

## Patterns

### Source Datastore Format

The source datastore must return a 4-element cell per read:

```matlab
dsObject = fileDatastore(annotatedImagePaths, ...
    ReadFcn=@(imgPath) readObjectData(imgPath, annotationPath));
```

Where the read function returns:

```matlab
function data = readObjectData(imagePath, annotationPath)
    img = imread(imagePath);
    [~, baseName] = fileparts(imagePath);
    annotation = load(fullfile(annotationPath, baseName + ".mat"));
    boxes = annotation.boxes;
    labels = categorical(annotation.labels);
    masks = annotation.masks;
    data = {img, boxes, labels, masks};
end
```

- `boxes` is `[P x 4]` in `[x, y, width, height]` format
- `labels` is `P x 1` categorical vector (all reads must share the same categories)
- `masks` is `logical(H, W, P)` where each plane corresponds to one object

### Destination Datastore

Simple (any location valid):

```matlab
dsDest = imageDatastore(cleanImagePaths);
```

With region constraint (restrict placement to specific area):

```matlab
dsDest = fileDatastore(cleanImagePaths, ReadFcn=@readDestWithMask);

function data = readDestWithMask(imagePath)
    img = imread(imagePath);
    mask = imread(strrep(imagePath, ".png", "_mask.png")) > 0;
    data = {img, mask};
end
```

### objectInsertionDatastore: Full Configuration

```matlab
numSyntheticImages = 1000;
dsSynthetic = objectInsertionDatastore(dsDest, dsObject, numSyntheticImages, ...
    NumObjectsToInsert=[1 3], ...
    ObjectsInSceneMaxOverlap=0.3, ...
    BlendMethod="guidedfilter", ...
    GeometricAugmentation=@() randomAffine2d(Scale=[0.8 1.2], ...
        XReflection=true, YReflection=true, Rotation=[-180 180]), ...
    OutputFormat="ObjectDetection");
```

### Online Training (Direct Datastore to Trainer)

```matlab
detector = yoloxObjectDetector("small-coco", className, InputSize=[512 512 3]);
options = trainingOptions("sgdm", MaxEpochs=20, MiniBatchSize=32);
netSynthetic = trainYOLOXObjectDetector(dsSynthetic, detector, options);
```

### On-Disk Training (Write First, Then Train from Files)

```matlab
dsSynthetic.writeall(outputFolder, FilenamePrefix="synth_");

dsOnDisk = fileDatastore(outputFolder, ReadFcn=@(f) load(f).labeledImageData);
netSynthetic = trainYOLOXObjectDetector(dsOnDisk, detector, options);
```

Writing to disk avoids recomputing blending/insertion each epoch — faster
training at the cost of disk space and a fixed (non-varying) dataset.

### Synthetic Pre-training + Real Fine-tuning

Pre-train on synthetic data, then fine-tune on real labeled data. This is the
documented best practice and yields significantly higher AP than real-only:

```matlab
netSynthetic = trainYOLOXObjectDetector(dsSynthetic, detector, options);
netFinal = trainYOLOXObjectDetector(dsTrainReal, netSynthetic, options);
```

Documented result: AP@0.5 = 0.846 (synthetic + fine-tune) vs 0.760 (real only).

### Instance Segmentation Output

For instance segmentation training, use `OutputFormat="InstanceSegmentation"`:

```matlab
dsSynthetic = objectInsertionDatastore(dsDest, dsObject, numSyntheticImages, ...
    NumObjectsToInsert=[1 3], ...
    ObjectsInSceneMaxOverlap=0.3, ...
    BlendMethod="guidedfilter", ...
    GeometricAugmentation=@() randomAffine2d(Scale=[0.8 1.2], ...
        XReflection=true, YReflection=true, Rotation=[-180 180]), ...
    OutputFormat="InstanceSegmentation");
```

Each read returns `{Image, Boxes, Labels, Masks}`.

### Visualizing Synthetic Output

```matlab
sampleData = preview(dsSynthetic);
sampleImg = sampleData{1};
sampleBoxes = sampleData{2};
sampleLabels = sampleData{3};
figure
imshow(sampleImg)
hold on
showShape("rectangle", sampleBoxes, Label=string(sampleLabels), Color="green")
hold off
```

### Single Image Insertion (Low-Level)

For one-off insertion or custom pipelines, use `insertObjectInImage` directly:

```matlab
[augImg, box, mask] = insertObjectInImage(destImg, sourceImg, sourceMask, ...
    BlendMethod="guidedfilter", ...
    BoundaryConstraintMode="inbounds-bbox", ...
    ObjectsInSceneMaxOverlap=0.3);
```

Returns the augmented image, the bounding box of the inserted object, and a
logical mask of where content was pasted.

## Parameters

### objectInsertionDatastore

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `NumObjectsToInsert` | 1 | Scalar or `[min max]` range of objects per image |
| `OutputFormat` | "InstanceSegmentation" | "ObjectDetection", "InstanceSegmentation", or "SceneClassification" |
| `BoundaryConstraintMode` | "inbounds-bbox" | How objects are constrained at image boundary |
| `ObjectsInSceneMaxOverlap` | 1.0 | Max overlap ratio with previously inserted objects (0–1) |
| `MaxInsertionAttempts` | 10 | Attempts to find valid placement before skipping |
| `BlendMethod` | "guidedfilter" | "guidedfilter", "poisson", "none", or custom `@(dest,src,mask)` |
| `GeometricAugmentation` | identity | Function handle returning `affinetform2d` |

### BoundaryConstraintMode

| Mode | Behavior | Use When |
|------|----------|----------|
| `"inbounds-bbox"` | Bounding box must fit entirely within destination | Default; works well for blob-like defects |
| `"inbounds-exact"` | Exact mask shape must fit (FFT-based erosion) | Elongated/irregular shapes, or object nearly fills constraint region |
| `"center"` | Only object center must be in bounds; clipping allowed | Objects at edges are realistic (e.g., partially visible parts) |

Use `"inbounds-exact"` when the object (including after geometric augmentation
with rotation/scale) is large relative to the `RegionConstraintMask` area —
the bounding-box approximation is more likely to fail to find valid placements.

### BlendMethod

| Method | Effect | Use When |
|--------|--------|----------|
| `"guidedfilter"` | Edge-aware blending via guided filter | Default — good general-purpose boundary blending |
| `"poisson"` | Seamless cloning that adapts object color to destination | Object color doesn't naturally match the destination region |
| `"none"` | Direct pixel paste, no blending | Source already matches destination appearance |
| `@(dest,src,mask)` | Custom blend function | Special blending needs |

## Decision Framework

| Situation | Approach |
|-----------|----------|
| Need synthetic dataset for YOLOX training | `objectInsertionDatastore` → `trainYOLOXObjectDetector` |
| Best accuracy from limited labels | Synthetic pre-train → real fine-tune |
| Training speed matters | `writeall` to disk, train from files |
| Maximum variety per epoch | Online datastore (direct to trainer) |
| Need reproducible experiments or visual QA | `writeall` to disk |
| Custom insertion logic or single image | `insertObjectInImage` directly |
| Objects can be partially visible at edges | `BoundaryConstraintMode="center"` |
| Large objects in small constraint region | `BoundaryConstraintMode="inbounds-exact"` |
| Defects vary in scale/rotation in real data | `GeometricAugmentation` with `randomAffine2d` |
| Inserted object color doesn't match background | `BlendMethod="poisson"` |
| Need instance masks for training | `OutputFormat="InstanceSegmentation"` |

## Conventions

- **Always:** provide source data as `{Image, Boxes, Labels, Masks}` (4-element cell)
- **Always:** use `categorical` for labels; all reads must share the same categories
- **Always:** use `GeometricAugmentation` to add scale/rotation variation
- **Never:** write intermediate COCO JSON — the datastore integrates directly with MATLAB trainers
- **Never:** build DIY copy-paste pipelines from low-level primitives when these functions exist
- **Prefer:** `"guidedfilter"` blending for most industrial defect insertion
- **Prefer:** `"poisson"` when object color doesn't naturally blend into destination
- **Prefer:** synthetic pre-train + real fine-tune over synthetic-only training
- **Prefer:** `OutputFormat="ObjectDetection"` for YOLOX training
- **Prefer:** on-disk generation when training speed is a priority

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Writing to files then converting to COCO JSON | Unnecessary complexity | `writeall` produces `.mat` files directly usable as training input |
| Source data missing masks (3 elements) | Datastore requires 4-element cell | Always include masks: `{Image, Boxes, Labels, Masks}` |
| Building DIY alpha blending pipeline | Reinvents existing functionality | `insertObjectInImage` with `BlendMethod` |
| No geometric augmentation | All synthetic objects same scale/orientation | `GeometricAugmentation=@() randomAffine2d(...)` |
| `ObjectsInSceneMaxOverlap=1` with many objects | Objects pile on top of each other | Set to 0.2–0.3 for realistic placement |
| Training only on synthetic data | Domain gap limits accuracy | Pre-train synthetic, fine-tune on real |
| `"inbounds-bbox"` with large irregular objects | Fails to find valid placements | Switch to `"inbounds-exact"` |
| Labels not categorical or categories mismatch | Training fails on inconsistent labels | Ensure all reads return same `categorical` categories |


----

Copyright 2026 The MathWorks, Inc.

----
