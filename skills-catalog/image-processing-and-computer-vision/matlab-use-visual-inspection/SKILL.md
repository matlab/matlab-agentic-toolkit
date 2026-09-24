---
name: matlab-use-visual-inspection
description: >
  Build machine vision inspection systems with MATLAB Visual Inspection Toolbox.
  Covers the full arc from problem selection through deployment: anomaly detection
  (Student-Teacher, PatchCore, FastFlow, FCDD), object detection (YOLOX), counting
  (CounTR, shape matching), gauging and measurement (caliper, fitcircle, fitangle),
  blob analysis (regionprops, calibrated measurement), shape matching for fixturing
  and localization, synthetic data generation for training augmentation, and
  deployment to standalone apps, embedded C/C++, NVIDIA GPUs (TensorRT), NPUs (ONNX),
  and Beckhoff PLCs. Routes to rule-based tools when problems are geometric and
  deterministic, AI-based tools when defect appearance varies, and hybrid pipelines
  combining both.
license: "https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md"
metadata:
  author: MathWorks
  version: "1.0"
---

# Visual Inspection with MATLAB

Build machine vision inspection systems using Visual Inspection Toolbox. Select the
right approach — rule-based, AI-based, or hybrid — based on problem characteristics,
then implement, train, and deploy.

## When to Use

**Defect detection and classification**
- Detecting anomalies on manufactured parts (scratches, dents, contamination)
- Training anomaly detectors with good-part images only (one-class learning)
- Detecting and localizing defects with bounding boxes (YOLOX)
- Classifying defect types or severity levels

**Measurement and gauging**
- Measuring widths, gaps, angles, diameters on parts
- Calibrated measurement in physical units (mm, degrees)
- Vision fixturing — locating parts and repositioning measurement tools
- Blob analysis — area, perimeter, shape metrics of segmented regions

**Counting and localization**
- Counting identical rigid parts via shape matching
- Few-shot counting with intra-class variation (CounTR)
- Locating parts by edge geometry for downstream inspection

**Training data augmentation**
- Generating synthetic labeled data via copy-paste augmentation
- Expanding small defect datasets for YOLOX training

**Deployment**
- Packaging inspection as standalone executables (MATLAB Compiler)
- Generating C/C++ for embedded/edge targets (MATLAB Coder)
- GPU-accelerated inference with TensorRT (GPU Coder)
- ONNX export for NPUs, AI accelerators, smart camera SDKs
- Deploying to Beckhoff TwinCAT industrial PLCs

## When NOT to Use

- Camera acquisition, frame grabber configuration — use Image Acquisition Toolbox
- PLC communication, OPC UA, MQTT protocols — use Industrial Communication Toolbox
- General image processing unrelated to inspection (artistic filters, medical imaging)

## Must-Follow Rules

### Approach Selection
- **Rule-based for geometric, deterministic problems** — when defects are dimensional deviations or parts have known geometry, use caliper/fitcircle/matchshape. No training data needed
- **AI-based for variable appearance** — when defect appearance can't be enumerated, use anomaly detection or YOLOX. Requires training data
- **Hybrid when parts move** — use `matchshape` to fixture (locate + normalize pose), then AI on the cropped/warped region. Anomaly detectors are NOT rotation/scale invariant

### Anomaly Detection
- **Anomaly detectors require consistent pose** — CNN backbones are not rotation/scale invariant. Fixture with `matchshape` + `imwarp` to canonical orientation before training and inference
- **Choose detector by data availability** — >100 good images: `studentTeacherAnomalyDetector`; <100 images: `patchCoreAnomalyDetector`; have anomaly labels: `fcddAnomalyDetector`
- **Use `classify` for inference** — returns `[tf, score, map]` for anomaly map visualization

### Object Detection (YOLOX)
- **Use `AutoResize=false` for full-resolution inference** — prevents downscaling that loses small defects. Pair with tiled training when objects are small relative to image
- **Synthetic data benefits YOLOX most** — copy-paste augmentation via `objectInsertionDatastore` is proven for detection tasks

### Measurement
- **Vision fixturing pattern** — `matchshape` locates part → transform measurement positions to detected pose → measure at repositioned locations
- **Calibrated measurements require `imageToWorldPlane`** — converts pixel measurements to physical units using camera calibration
- **`images.geotrans.Warper` for production rectification** — precompute the mapping once, apply per frame for maximum throughput

### Deployment
- **Always use `persistent` + `isempty` guard** in codegen entry points — load model once, infer many times
- **`coder.loadDeepLearningNetwork` for DL models** — not `coder.load` (which is for structs/shape models)
- **`coder.Constant` for MAT file path** — codegen requires compile-time constant paths
- **Pass detector objects directly to `exportONNXNetwork`** — never extract `.Network` or `.Backbone` first. The object-level export includes pre/post-processing logic
- **ONNX for NPUs/AI accelerators; GPU Coder + TensorRT for NVIDIA** — don't use ONNX for Jetson/Orin

## Pipeline Construction

Machine vision inspections compose tools in sequence:

1. **Acquire** — Get the image (Image Acquisition Toolbox)
2. **Fixture** — Locate a stable reference feature (`matchshape`)
3. **Reposition** — Transform measurement positions to detected pose
4. **Inspect** — Apply measurement or classification at repositioned locations
5. **Decide** — Compare to tolerances → pass/fail
6. **Communicate** — Send results to PLC/SCADA (Industrial Communication Toolbox)

### Common Hybrid Patterns

| Pattern | Rule-Based Part | AI Part |
|---------|----------------|---------|
| Fixture + classify | `matchshape` locates part, crops ROI | Anomaly detector on cropped region |
| Fixture + detect | `matchshape` locates part | YOLOX finds defects relative to fixture |
| Pose normalize + anomaly | `matchshape` + `imwarp` to canonical pose | Anomaly detector on normalized image |
| Segment + measure | Thresholding / morphology | `regionprops` on segmented blobs |

## Primary Decision: Rule-Based vs. AI-Based

| Choose Rule-Based When | Choose AI-Based When |
|------------------------|---------------------|
| Defects have predictable, enumerable geometry | Defect appearance varies unpredictably |
| Lighting and positioning are tightly controlled | Background or part appearance varies |
| Need dimensional measurements (mm, degrees) | Need classification without precise measurement |
| Few or no labeled examples available | Have labeled training data (or can generate synthetic) |
| Require explainable, auditable decisions | Accuracy matters more than explainability |

## Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `shapemodel` | Build edge-geometry model from template | Visual Inspection Toolbox | R2026b |
| `matchshape` | Find model instances in search image | Visual Inspection Toolbox | R2026b |
| `caliper` | Measure edge distances along a profile | Visual Inspection Toolbox | R2026b |
| `fitangle` | Measure angle between edges | Visual Inspection Toolbox | R2026b |
| `fitcircle` | Measure circle center and radius | Visual Inspection Toolbox | R2026b |
| `studentTeacherAnomalyDetector` | One-class anomaly detection (>100 good images) | Visual Inspection Toolbox | R2026b |
| `patchCoreAnomalyDetector` | One-class anomaly detection (few-shot, <100 images) | Visual Inspection Toolbox | R2026b |
| `fastFlowAnomalyDetector` | Normalizing-flow anomaly detection | Visual Inspection Toolbox | R2026b |
| `fcddAnomalyDetector` | Semi-supervised anomaly detection | Visual Inspection Toolbox | R2026b |
| `yoloxObjectDetector` | Object/defect detection with bounding boxes | Visual Inspection Toolbox | R2026b |
| `counTRObjectCounter` | Counting with intra-class variation (few-shot) | Visual Inspection Toolbox | R2026b |
| `objectInsertionDatastore` | Synthetic labeled training data (copy-paste) | Visual Inspection Toolbox | R2026b |
| `regionprops` | Blob area, perimeter, shape features | Image Processing Toolbox | R2006a |
| `imageToWorldPlane` | Calibrated world-unit measurement | Computer Vision Toolbox | R2022b |

## Decision Trees

### "I need to detect defects"

| Situation | Approach |
|-----------|----------|
| Defect appearance unpredictable; good-part images only | Anomaly detection |
| Classify defect types with bounding boxes; have labeled data | YOLOX object detection |
| Defects are geometric deviations from known shape | Shape matching + gauging |
| Dimensional out-of-tolerance (too wide, too narrow) | Caliper / fitcircle / fitangle |

### "I need to measure parts"

| Situation | Approach |
|-----------|----------|
| Widths, gaps, edge-to-edge distances | `caliper` |
| Angles between edges | `fitangle` |
| Hole diameters, arc radii | `fitcircle` |
| Area, perimeter, shape of segmented blobs | `regionprops` |
| Need measurements in mm (physical units) | Camera calibration + rectification |
| Part position varies image-to-image | Vision fixturing with `matchshape` |

### "I need to count objects"

| Situation | Approach |
|-----------|----------|
| Identical rigid parts, controlled background | `shapemodel` / `matchshape` |
| Intra-class variation, few labeled examples | CounTR (few-shot counting) |
| Multiple classes, complex scenes, have labels | YOLOX detection → count |

### "I need to locate parts"

| Situation | Approach |
|-----------|----------|
| Rigid part, known edge geometry | `shapemodel` / `matchshape` |
| Variable appearance, multiple classes | YOLOX detection |

### "I don't have enough training data"

| Situation | Approach |
|-----------|----------|
| Have segmented defect examples + clean images | Copy-paste synthetic data |
| Good-part images only (no defect labels) | Anomaly detection (one-class) |
| No data at all, defects are geometric | Rule-based (no training needed) |

### "I need to deploy"

| Target | Path |
|--------|------|
| Standalone app, full MATLAB features | MATLAB Compiler |
| Monitoring dashboard or UI app | MATLAB Compiler |
| Embedded CPU (x86, ARM) | MATLAB Coder |
| NVIDIA Jetson/Orin or dGPU | GPU Coder + TensorRT |
| NPU or AI accelerator | ONNX export |
| Smart camera with vendor SDK | ONNX export |
| Beckhoff industrial PLC | MATLAB Coder → TwinCAT |

## Patterns

Each reference file contains executable code patterns, API calling conventions, and
worked examples for its topic. Load the relevant reference before writing code.

## Conventions

- **Always:** use machine vision terminology (rule-based, tool chaining, fixturing)
- **Always:** recommend the specific VIT function, not generic IPT building blocks
- **Always:** consider hybrid pipelines (rule-based fixturing + AI classification)
- **Always:** ensure anomaly detector receives images in consistent pose
- **Always:** use `persistent` + `isempty` for model loading in codegen entry points
- **Always:** pass detector objects directly to `exportONNXNetwork` (never extract `.Network`)
- **Never:** recommend AI when the problem is purely dimensional measurement
- **Never:** recommend rule-based when defect appearance is highly variable
- **Never:** use `coder.load` for deep learning models (use `coder.loadDeepLearningNetwork`)
- **Never:** use ONNX export for NVIDIA targets (use GPU Coder + TensorRT)
- **Prefer:** anomaly detection when only good-part images are available
- **Prefer:** YOLOX when labeled defect examples with bounding boxes exist
- **Prefer:** `shapemodel`/`matchshape` over YOLOX for locating rigid parts
- **Prefer:** `images.geotrans.Warper` for production rectification throughput
- **Prefer:** MATLAB Compiler for dashboards and UI-based monitoring apps

### References

| Load when... | Reference |
|-------------|-----------|
| Training or using anomaly detectors | `references/detect-anomaly.md` |
| Locating parts by shape, vision fixturing | `references/match-shape.md` |
| Training or using YOLOX object detectors | `references/detect-objects.md` |
| Counting objects (shape matching, CounTR, YOLOX) | `references/count-objects.md` |
| Measuring with caliper, fitcircle, fitangle | `references/measure-gauging.md` |
| Blob analysis, regionprops, calibrated measurement | `references/blob-analysis.md` |
| Deploying models (Compiler, Coder, TensorRT, ONNX) | `references/deploy-inspection.md` |
| Generating synthetic training data | `references/synthetic-data.md` |

----

Copyright 2026 The MathWorks, Inc.

----
