
# Visual Anomaly Detection

Train anomaly detectors on images of normal/good parts and detect defects without
needing examples of every defect type. All four detectors share the same inference
interface: `classify`, `predict`, `anomalyMap`.

## When to Use

- Manufacturing inspection where defect appearance cannot be fully enumerated
- One-class or few-shot anomaly detection (mostly good data available)
- Need localization maps showing where anomalies are
- Choosing between four anomaly detection architectures
- Setting anomaly thresholds for production deployment
- Full-resolution inference on high-res industrial images

## When NOT to Use

- Object detection with bounding boxes — use YOLOX skill
- Binary classification with balanced classes — use standard deep learning
- Template matching / part localization — see `references/match-shape.md`
- Pixel-level segmentation with class labels — use semantic segmentation

## Model Selection

| Detector | Best When | Training | Inference Speed |
|----------|-----------|----------|-----------------|
| `studentTeacherAnomalyDetector` | Sufficient data (>100 images), need low latency + good metrics | `trainingOptions`-based, iterative | Fast (small network) |
| `patchCoreAnomalyDetector` | Limited data (<100 images), no hyperparameter tuning desired | Memory bank (no gradient training) | Moderate |
| `fcddAnomalyDetector` | Need tunable backbone size, semi-supervised with some anomaly labels | `trainingOptions`-based, iterative | Tunable (backbone-dependent) |
| `fastFlowAnomalyDetector` | Normalizing-flow approach, moderate data | `trainingOptions`-based, iterative | Moderate |

**Default recommendation:** Use `studentTeacherAnomalyDetector` with `Network="small"` when you have >100 normal images. Use `patchCoreAnomalyDetector` when you have limited normal data or want zero hyperparameter tuning.

**PatchCore warning:** Coreset subsampling is slow with large datasets (>500 images). Either subsample training data or use `SubsamplingStrategy="random"` for speed at slight accuracy cost.

## Workflow

1. **Organize data** — images in folders by label (good/bad or categorical defect types)
2. **Create datastores** — `imageDatastore` with `LabelSource="foldernames"`
3. **Split data** — `splitAnomalyData` or `splitEachLabel` into train/calibration/test
4. **Transform** — resize via `transform(ds, @(x) imresize(x, targetSize))`
5. **Create detector** — choose architecture from model selection table
6. **Train** — detector-specific training function
7. **Calibrate threshold** — `anomalyThreshold` on calibration set
8. **Evaluate** — `evaluateAnomalyDetection` with categorical labels
9. **Visualize** — `anomalyMap`, `anomalyMapOverlay`, `percentileNormalizer`

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `splitAnomalyData` | Split data into train/val/test respecting anomaly-free training | Visual Inspection Toolbox |
| `trainStudentTeacherAnomalyDetector` | Train student-teacher detector | Visual Inspection Toolbox |
| `trainPatchCoreAnomalyDetector` | Train PatchCore detector | Visual Inspection Toolbox |
| `trainFCDDAnomalyDetector` | Train FCDD detector | Visual Inspection Toolbox |
| `trainFastFlowAnomalyDetector` | Train FastFlow detector | Visual Inspection Toolbox |
| `anomalyThreshold` | Compute optimal threshold from calibration scores | Visual Inspection Toolbox |
| `evaluateAnomalyDetection` | Compute detection metrics (per-class if categorical) | Visual Inspection Toolbox |
| `percentileNormalizer` | Normalize anomaly maps to standard range using normal-image statistics | Visual Inspection Toolbox |
| `anomalyMapOverlay` | Overlay heatmap visualization on image | Visual Inspection Toolbox |
| `viewAnomalyDetectionResults` | Interactive results viewer | Visual Inspection Toolbox |
| `classify` | Returns `[tf, score, map]` — label, score, and anomaly map in one call | Visual Inspection Toolbox |

## Patterns

### Data Splitting with splitAnomalyData

```matlab
imds = imageDatastore(dataDir, IncludeSubfolders=true, LabelSource="foldernames");
[dsTrain, dsVal, dsTest] = splitAnomalyData(imds, "bad");
```

The function automatically excludes anomaly labels from training (`KeepAnomalyLabelsInTrainingDatastore=false` by default) and routes unused anomaly images to validation/test sets.

### Datastore Transform for Resizing

With default `ReadSize=1`, `imageDatastore` read returns a numeric image directly. The transform function receives the numeric image:

```matlab
targetSize = [256 256];
dsTrain = transform(dsTrain, @(x) imresize(x, targetSize));
```

Do NOT write `@(x) imresize(x{1}, targetSize)` — with the default `ReadSize=1`, `x` is already numeric. The `x{1}` pattern only applies when `ReadSize > 1` (which returns a cell array of images).

### Training Student-Teacher

```matlab
detector = studentTeacherAnomalyDetector(Network="small");
options = trainingOptions("adam", ...
    InitialLearnRate=4e-4, ...
    MaxEpochs=100, ...
    MiniBatchSize=4, ...
    Shuffle="every-epoch", ...
    ValidationData=dsVal, ...
    Metrics=aucMetric(Name="auc"), ...
    ObjectiveMetricName="auc", ...
    ResetInputNormalization=false);
detector = trainStudentTeacherAnomalyDetector(dsTrain, detector, options);
```

### Training PatchCore

```matlab
patchcore = patchCoreAnomalyDetector(Backbone="resnet18");
detector = trainPatchCoreAnomalyDetector(dsTrain, patchcore, CompressionRatio=0.1);
```

No `trainingOptions` needed — PatchCore builds a memory bank, not gradient training.

### Threshold Calibration

```matlab
scores = predict(detector, dsCal);
labels = dsCal.UnderlyingDatastores{1}.Labels;
[thresh, roc] = anomalyThreshold(labels, scores, "bad", "MaxF1Score");
detector.Threshold = thresh;
```

Methods: `"YoudensIndexROC"` (default), `"MaxF1Score"`, `"NearestZeroOneROC"`, or rate-based: `MaxFalsePositiveRate=0.01`.

### Classify with All Outputs

Use `classify` to get label, score, and anomaly map in a single call:

```matlab
[tf, score, map] = classify(detector, img);
```

Do not separately call `predict` then `anomalyMap` — `classify` returns all three.

### Evaluation with Categorical Labels

Pass categorical ground truth labels and specify which are anomalies. This enables per-class accuracy breakdown:

```matlab
predictedLabels = classify(detector, dsTest);
trueLabels = dsTest.UnderlyingDatastores{1}.Labels;
metrics = evaluateAnomalyDetection(predictedLabels, trueLabels, "bad");
```

When ground truth has multiple anomaly categories (e.g., "scratch", "dent", "stain"), pass all as anomaly labels:

```matlab
metrics = evaluateAnomalyDetection(predictedLabels, trueLabels, ["scratch","dent","stain"]);
```

`metrics.ClassMetrics.AccuracyPerSubClass` then shows accuracy per defect type.

### Anomaly Map Normalization and Visualization

Use `percentileNormalizer` to establish a consistent normalization from normal-image anomaly map statistics. This is the preferred approach for visualization — it maps the normal background to a known low range so anomalies stand out consistently.

```matlab
normalizer = percentileNormalizer(dsNormal, detector);
map = anomalyMap(detector, img);
normalizedMap = normalize(normalizer, map);
overlay = anomalyMapOverlay(img, normalizedMap);
imshow(overlay)
```

For quick single-image visualization without a normalizer:

```matlab
map = anomalyMap(detector, img);
overlay = anomalyMapOverlay(img, map);
imshow(overlay)
```

## Decision Framework: Resolution Strategy

Use tiled training when images are too large for GPU memory during training but you
need full-resolution inference for small defect detection.

| Strategy | When | Detectors |
|----------|------|-----------|
| **Downsample** (default) | Defects are large relative to image, speed matters | All four |
| **Tiled training + full-res inference** | Small defects, need full spatial resolution, GPU memory limited during training | Student-Teacher, FCDD only (fully convolutional) |

The tiled approach trains on 256×256 crops but infers on the full image in a single
pass — no stitching needed. Use `MiniBatchSize=1` at full-res inference to avoid OOM.
Only works with fully convolutional architectures (Student-Teacher, FCDD).

## Conventions

- **Always:** use `splitAnomalyData` or `splitEachLabel` for data splitting — do not manually partition with `randperm`
- **Always:** use `classify` for inference when you need labels + scores + maps — it returns all three as `[tf, score, map]`
- **Always:** set `detector.Threshold` after calling `anomalyThreshold` — the detector stores the threshold
- **Always:** use `percentileNormalizer` for consistent anomaly map visualization across images
- **Never:** include anomaly images in training data (except FCDD which supports semi-supervised)
- **Never:** use `concatenate(dsA, dsB)` — it does not exist. Use `combine` with appropriate options
- **Prefer:** categorical labels with `evaluateAnomalyDetection` for per-class breakdown over binary true/false

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `transform(imds, @(x) imresize(x{1}, sz))` | imageDatastore with default ReadSize=1 returns numeric, not cell | `transform(imds, @(x) imresize(x, sz))` |
| Calling `predict` + `anomalyMap` separately | Redundant forward passes | `[tf, score, map] = classify(detector, img)` |
| `concatenate(dsA, dsB)` | Not a MATLAB function | `combine(dsA, dsB)` |
| PatchCore on 500+ images with default settings | Coreset subsampling is very slow on large datasets | Subsample training data or use `SubsamplingStrategy="random"` |
| Using binary true/false labels for evaluation | Loses per-defect-class breakdown | Use categorical labels + specify anomaly label names |
| Manual train/cal/test split with randperm | Error-prone, doesn't handle anomaly exclusion | `splitAnomalyData(imds, anomalyLabels)` |
| Training fully convolutional detectors on full-res images | OOM during training | Downsample or use tiled training (ST/FCDD only) |
| Manual min/max for anomaly map display range | Inconsistent across images, brittle | `percentileNormalizer(dsNormal, detector)` + `normalize` |


----

Copyright 2026 The MathWorks, Inc.

----
