
# Object Detection with YOLOX

Train YOLOX object detectors on labeled industrial images and detect defects
with bounding boxes. YOLOX is anchor-free with built-in FPN for multi-scale
feature fusion — the recommended detector for industrial defect detection.

## When to Use

- Defect detection requiring bounding box localization
- Multi-class defect detection (scratches, cracks, missing components, etc.)
- Small object detection in high-resolution industrial images
- Deploying object detectors to hardware via MATLAB Coder / GPU Coder

## When NOT to Use

- Anomaly detection without defect labels — see `references/detect-anomaly.md`
- Template matching / part localization — see `references/match-shape.md`
- Pixel-level segmentation — use semantic segmentation
- Only need binary good/bad without localization — use anomaly detection

## Model Selection

| Variant | Speed | Accuracy | Use When |
|---------|-------|----------|----------|
| `"small-coco"` | Moderate | Higher | Default choice — best P/R vs. latency tradeoff |
| `"tiny-coco"` | Fast | Lower | Constrained hardware, real-time needs |

Larger models give better precision/recall at the cost of higher latency and
compute. `"tiny-coco"` is the smallest non-depthwise architecture — nano
variants use depthwise convolutions that may not be faster on actual hardware
despite smaller parameter counts.

**Default recommendation:** Use `"small-coco"` for training unless deployment
hardware requires the lower latency of `"tiny-coco"`.

## Resolution Strategy

| Strategy | When | Key Setting |
|----------|------|-------------|
| **Standard** (default) | Defects visible at training InputSize, GPU fits full batch | `InputSize=[H W 3]` — auto-resizes images |
| **Tiled training + full-res inference** | Small defects lost by resize, full image fits in memory | Train on tiles, `detect(..., AutoResize=false)` |
| **Tiled training + tiled inference** | Full image does not fit in CPU/GPU memory at inference | Tile at inference, stitch results with NMS |

The preferred inference approach is `AutoResize=false` — a single forward pass on
the full-resolution image. This leverages the fully convolutional architecture,
is faster, and is easier to deploy via code generation. Use tiled inference with
stitching only when the full image exceeds available memory.

Use tiled training when defects are small relative to image size and GPU memory limits training at full resolution.

## Workflow

1. **Organize data** — images + annotation tables with bounding boxes and labels
2. **Create datastores** — `imageDatastore` + `boxLabelDatastore` → `combine`
3. **Split data** — `subset` with shuffled indices into train/val/test
4. **Augment** — `transform` with geometric augmentations (flip, scale, translate)
5. **Create detector** — `yoloxObjectDetector(variant, classNames, InputSize=sz)`
6. **Train** — `trainYOLOXObjectDetector` with `trainingOptions`
7. **Evaluate** — `evaluateObjectDetection` → `summarize`, `precisionRecall`
8. **Select threshold** — choose operating point from PR curve
9. **Deploy** — `detect` at chosen threshold; optionally generate code

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `yoloxObjectDetector` | Create/configure YOLOX detector | Visual Inspection Toolbox |
| `trainYOLOXObjectDetector` | Train detector on labeled data | Visual Inspection Toolbox |
| `detect` | Run inference — returns `[bboxes, scores, labels]` | Visual Inspection Toolbox |
| `evaluateObjectDetection` | Compute AP, precision-recall per class | Computer Vision Toolbox |
| `mAPObjectDetectionMetric` | Training metric for validation monitoring | Computer Vision Toolbox |
| `boxLabelDatastore` | Datastore for bounding box + label data | Computer Vision Toolbox |
| `blockLocationsWithROI` | Select tile locations containing objects (tiled workflow) | Computer Vision Toolbox |
| `balanceBoxLabels` | Balance tile sampling across classes | Computer Vision Toolbox |
| `blockedImage` | Represent large images as tiled blocks | Image Processing Toolbox |
| `insertObjectAnnotation` | Draw bounding boxes on images for display | Computer Vision Toolbox |

## Patterns

### Standard Training Pipeline

```matlab
imds = imageDatastore(imageDir, IncludeSubfolders=true);
blds = boxLabelDatastore(annotationTable);
ds = combine(imds, blds);

numImages = ds.numpartitions;
shuffledIdx = randperm(numImages);
numTrain = floor(0.7 * numImages);
numVal = floor(0.15 * numImages);
dsTrain = subset(ds, shuffledIdx(1:numTrain));
dsVal = subset(ds, shuffledIdx(numTrain+1:numTrain+numVal));
dsTest = subset(ds, shuffledIdx(numTrain+numVal+1:end));

dsTrain = transform(dsTrain, @augmentData);

detector = yoloxObjectDetector("small-coco", classNames, InputSize=[800 800 3]);
options = trainingOptions("sgdm", ...
    InitialLearnRate=5e-4, ...
    LearnRateSchedule="piecewise", ...
    LearnRateDropFactor=0.99, ...
    LearnRateDropPeriod=1, ...
    MaxEpochs=100, ...
    MiniBatchSize=20, ...
    Shuffle="every-epoch", ...
    ValidationData=dsVal, ...
    ValidationFrequency=100, ...
    ResetInputNormalization=false, ...
    OutputNetwork="best-validation-loss", ...
    Metrics=mAPObjectDetectionMetric(Name="mAP50"), ...
    ObjectiveMetricName="mAP50", ...
    L2Regularization=5e-4);

[detector, info] = trainYOLOXObjectDetector(dsTrain, detector, options);
```

Images are automatically resized to `InputSize` during training and inference by
default. Choose `InputSize` large enough that your smallest defects occupy at
least a few pixels after resizing.

### ResetInputNormalization

- `false` — use for standard uint8 [0,255] images (the common case with COCO
  pretrained backbones). Skips recomputation of normalization statistics, which
  speeds up training startup.
- `true` — use when input data is outside the [0,255] range expected by the
  COCO pretrained backbone (e.g., normalized floats, 16-bit images, non-standard
  intensity ranges). Recomputes mean/std from your training data.

### Data Augmentation

Use geometric augmentations that preserve bounding box validity:

```matlab
function data = augmentData(A)
data = cell(size(A));
for ii = 1:size(A, 1)
    I = A{ii, 1};
    bboxes = A{ii, 2};
    labels = A{ii, 3};
    sz = size(I);
    tform = randomAffine2d(XReflection=true, Scale=[1 1.1]);
    rout = affineOutputView(sz, tform, BoundsStyle="centerOutput");
    I = imwarp(I, tform, OutputView=rout);
    [bboxes, indices] = bboxwarp(bboxes, tform, rout, OverlapThreshold=0.25);
    labels = labels(indices);
    if isempty(indices)
        data(ii, :) = A(ii, :);
    else
        data(ii, :) = {I, bboxes, labels};
    end
end
end
```

### Detection and Visualization

```matlab
[bboxes, scores, labels] = detect(detector, img, Threshold=0.5);
annotatedImg = insertObjectAnnotation(img, "rectangle", bboxes, labels);
imshow(annotatedImg)
```

### Full-Resolution Inference

After tiled training, infer on the full image without resizing:

```matlab
[bboxes, scores, labels] = detect(detector, fullResImg, AutoResize=false, Threshold=0.5);
```

This is faster and easier to deploy than tiled inference. It works as long as the
full image fits in CPU/GPU memory. Use `MiniBatchSize=1` when running on a
datastore to limit memory usage.

### Evaluation with Precision-Recall

Run detection at a low threshold to capture the full score range, then analyze:

```matlab
detResults = detect(detector, dsTest, Threshold=0.01);
metrics = evaluateObjectDetection(detResults, dsTest);
[summaryDataset, summaryClass] = summarize(metrics);
```

Extract precision-recall curve for threshold selection:

```matlab
[precision, recall, scores] = precisionRecall(metrics, ClassNames="defect");
```

### Threshold Selection Strategies

Choose the operating point based on application requirements:

```matlab
[precision, recall, scores] = precisionRecall(metrics, ClassNames="defect");
P = precision{1};
R = recall{1};
S = scores{1};

f1 = 2 * (P .* R) ./ (P + R);
[~, idxF1] = max(f1);
threshMaxF1 = S(idxF1);

targetRecall = 0.95;
idxRecall = find(R >= targetRecall, 1, "last");
threshFixRecall = S(idxRecall);

targetPrecision = 0.95;
idxPrecision = find(P >= targetPrecision, 1, "last");
threshFixPrecision = S(idxPrecision);
```

| Strategy | When | Tradeoff |
|----------|------|----------|
| Max F1 | General-purpose balanced | Equal weight to P and R |
| Fix recall (e.g., 0.95) | Safety-critical — cannot miss defects | Tolerates more false alarms |
| Fix precision (e.g., 0.95) | High-throughput — false alarms are costly | May miss some defects |

### Size-Based Performance Analysis

Evaluate detection performance stratified by object size:

```matlab
metrics = evaluateObjectDetection(detResults, dsTest);
boxPrctileBoundaries = prctile(boxArea, [33 66]);
areaMetrics = metricsByArea(metrics, [0, boxPrctileBoundaries, Inf]);
```

This reveals whether small defects need the tiled training workflow.

### Class Imbalance Handling

Use `ClassWeights` when defect classes are imbalanced:

```matlab
[detector, info] = trainYOLOXObjectDetector(dsTrain, detector, options, ...
    ClassWeights=[1 2 3 1 5 2]);
```

Higher weights increase the classification loss contribution for rare classes.

### Transfer Learning with Frozen Backbone

For small datasets, freeze the pretrained backbone initially:

```matlab
[detector, info] = trainYOLOXObjectDetector(dsTrain, detector, options, ...
    FreezeSubNetwork="backbone");
```

Then unfreeze and fine-tune with a lower learning rate for best results.

## Decision Framework: InputSize

| Image Resolution | Defect Size | Recommended Approach |
|-----------------|-------------|---------------------|
| ≤1024×1024 | >20×20 px at input | Standard with `InputSize` matching image |
| >1024×1024 | Still visible after resize | Standard with `InputSize=[800 800 3]` or similar |
| >1024×1024 | <20×20 px after resize | Tiled training + full-res inference |

If defects are too small after resizing to `InputSize`, switch to tiled
training: train on crops, infer on the full image with `AutoResize=false`.

## Conventions

- **Always:** use `combine(imds, blds)` to create training datastores — not manual cell construction
- **Always:** use `evaluateObjectDetection` + `precisionRecall` for threshold selection — not ad-hoc score sweeps
- **Always:** use `mAPObjectDetectionMetric` as the validation metric during training
- **Prefer:** `AutoResize=false` single-pass inference — faster, deployable via code generation
- **Prefer:** `"small-coco"` over `"tiny-coco"` unless hardware-constrained
- **Prefer:** geometric augmentations (flip, scale, translate) that preserve box validity via `bboxwarp`
- **Fall back to:** tiled inference with NMS stitching only when full image exceeds available memory

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Defaulting to tiled inference with stitching | Unnecessary when image fits memory; harder to deploy | `detect(detector, img, AutoResize=false)` for full-res |
| Evaluating at default Threshold=0.25 | Misses the full PR curve | `detect(..., Threshold=0.01)` then analyze PR |
| Not specifying `InputSize` | Network uses default size, may lose small defects | Explicit `InputSize` based on defect visibility |
| Ad-hoc threshold selection | No principled tradeoff | Use PR curve: Max F1, fix recall, or fix precision |
| Ignoring class imbalance | Rare defects get low AP | `ClassWeights` proportional to inverse frequency |


----

Copyright 2026 The MathWorks, Inc.

----
