
# Deploying Visual Inspection Models

Take trained anomaly detectors, YOLOX object detectors, and shape models from
the MATLAB desktop to production: standalone executables, embedded C/C++,
GPU-accelerated inference, or interoperable ONNX for specialized hardware.

## When to Use

- Packaging inspection algorithms as standalone applications
- Generating C/C++ code for embedded or edge deployment
- Targeting NVIDIA GPUs with TensorRT optimization
- Exporting models to ONNX for NPUs, AI accelerators, or smart camera SDKs
- Deploying to Beckhoff industrial PCs/PLCs via TwinCAT
- Deploying monitoring dashboards built with MATLAB UI tools
- Running inference in production loops without a MATLAB license

## When NOT to Use

- Still training or tuning the model — finish training first
- Need to choose a detection/anomaly approach — see `references/detect-objects.md` or `references/detect-anomaly.md`
- Interactive visualization or labeling — keep in MATLAB desktop

## Deployment Targets

| Target | Toolchain | Best For |
|--------|-----------|----------|
| Standalone app / shared library / dashboard | MATLAB Compiler | Easiest path; full MATLAB runtime bundled |
| C/C++ on CPU (x86, ARM) | MATLAB Coder | Embedded/edge, x86 or ARM smart cameras |
| NVIDIA GPU (Jetson, Orin, dGPU) | GPU Coder + TensorRT | Maximum throughput, Jetson/Orin smart cameras |
| NPUs, AI accelerators, smart camera SDKs | ONNX export | Hardware with ONNX runtime or vendor SDK |
| Beckhoff industrial PCs/PLCs | MATLAB Coder + TwinCAT | PLC-integrated inspection on Beckhoff hardware |

## Choosing a Deployment Path

| Question | Recommendation |
|----------|---------------|
| Need simplest deployment, runtime size not critical? | MATLAB Compiler |
| Deploying a monitoring dashboard or UI app? | MATLAB Compiler — preferred for UI deployment |
| Targeting NVIDIA Jetson/Orin or dGPU? | GPU Coder + TensorRT |
| Targeting x86 or ARM smart camera (Open standard)? | MATLAB Coder |
| Targeting NPU or AI accelerator hardware? | ONNX export |
| Smart camera with vendor SDK (non-NVIDIA)? | ONNX — often easiest integration path |
| Need pre/post-processing bundled as one executable? | Codegen (MATLAB Coder or GPU Coder) |
| Deploying to Beckhoff TwinCAT environment? | MATLAB Coder → TwinCAT integration |

## Patterns

### MATLAB Compiler: Standalone Application

Package the inspection pipeline as a standalone executable that includes the
MATLAB Runtime. No code generation step; full MATLAB language support.

```matlab
function results = inspectParts(imageFolder, modelPath)
    detector = load(modelPath).detector;
    imds = imageDatastore(imageFolder);
    results = table(Size=[0 3], ...
        VariableTypes=["string", "logical", "double"], ...
        VariableNames=["File", "Pass", "Score"]);
    while hasdata(imds)
        [img, info] = read(imds);
        [tf, score] = classify(detector, img);
        results = [results; {info.Filename, ~tf, score}];
    end
end
```

Compile with:
```matlab
mcc -m inspectParts.m -a modelFile.mat
```

### MATLAB Compiler: Monitoring Dashboards

MATLAB Compiler is the preferred way to deploy dashboards for monitoring
deployed visual inspection systems. Apps built with MATLAB UI tools (App
Designer, `uifigure`) deploy directly via Compiler with full graphics support:

```matlab
mcc -m inspectionDashboard.m -a modelFile.mat -a uiAssets/
```

This preserves all UI functionality — live image display, charts, status
indicators — without requiring MATLAB licenses on the monitoring workstation.

For maximum rectification throughput in Compiler-deployed apps, use
`images.geotrans.Warper` (see `references/blob-analysis.md` for the pattern).

### Code Generation Entry Point: Anomaly Detector

```matlab
function [tf, score, map] = anomalyInference(I, matFilePath) %#codegen
persistent detector
if isempty(detector)
    detector = coder.loadDeepLearningNetwork(matFilePath);
end
[tf, score, map] = classify(detector, I);
end
```

Generate code:
```matlab
cfg = coder.config("mex");
cfg.TargetLang = "C++";
cfg.DeepLearningConfig = coder.DeepLearningConfig(TargetLibrary="mkldnn");
inputArgs = {ones(256, 256, 3, "uint8"), coder.Constant("model.mat")};
codegen -config cfg anomalyInference -args inputArgs
```

### Code Generation Entry Point: YOLOX Detector

```matlab
function [bboxes, scores, labels] = yoloxInference(I, matFilePath) %#codegen
persistent detector
if isempty(detector)
    detector = coder.loadDeepLearningNetwork(matFilePath);
end
[bboxes, scores, labels] = detect(detector, I, Threshold=0.5);
end
```

### GPU Coder + TensorRT (NVIDIA GPU)

For maximum throughput on NVIDIA hardware (desktop GPUs, Jetson, Orin):

```matlab
cfg = coder.gpuConfig("mex");
cfg.TargetLang = "C++";
cfg.DeepLearningConfig = coder.DeepLearningConfig(TargetLibrary="tensorrt");
inputArgs = {ones(256, 256, 3, "uint8"), coder.Constant("model.mat")};
codegen -config cfg anomalyInference -args inputArgs
```

TensorRT performs layer fusion and FP16/INT8 optimization automatically.

### ONNX Export

Export models to ONNX for deployment on NPUs, AI accelerators, or smart camera
SDKs where ONNX runtime is available:

```matlab
detector = load("trainedDetector.mat").detector;
exportONNXNetwork(detector, "detector.onnx");
```

Visual Inspection Toolbox detector objects (e.g. `studentTeacherAnomalyDetector`,
`yoloxObjectDetector`) have their own `exportONNXNetwork` overload. This is
always preferable to extracting any underlying `dlnetwork` (via `.Network`,
`.Backbone`, or `dlnetwork(detector)`) because the object-level export includes
preprocessing and post-processing logic and provides export options not present
in the generic `dlnetwork` method.

ONNX is the preferred path when targeting specialized AI-accelerator hardware
(NPUs, VPUs) or when integrating with smart camera vendor SDKs that provide
ONNX runtime support. The trade-off is that pre/post-processing must be
implemented separately in the target environment's native language.

### Beckhoff TwinCAT Deployment

For industrial PCs and PLCs running Beckhoff TwinCAT, use MATLAB Coder to
generate C/C++ code, then integrate via the TwinCAT Machine Learning Server
(TE1401). The generated code runs as a TwinCAT module with deterministic
real-time execution.

```matlab
cfg = coder.config("lib");
cfg.TargetLang = "C++";
cfg.DeepLearningConfig = coder.DeepLearningConfig(TargetLibrary="mkldnn");
inputArgs = {ones(256, 256, 3, "uint8"), coder.Constant("model.mat")};
codegen -config cfg anomalyInference -args inputArgs
```

### Shape Model Deployment (Non-DL)

Shape models used for fixturing or counting do not require deep learning
code generation. They are lightweight and deploy directly via MATLAB Compiler
or standard code generation:

```matlab
function [locations, scores] = matchInFrame(I, matFilePath) %#codegen
persistent model
if isempty(model)
    modelData = coder.load(matFilePath);
    model = modelData.model;
end
matches = matchshape(model, I, ScoreThreshold=0.7);
locations = matches.Location;
scores = matches.Score;
end
```

## Entry-Point Conventions for Code Generation

| Convention | Reason |
|------------|--------|
| `persistent` variable for model | Load once, infer many times |
| `coder.loadDeepLearningNetwork(path)` | Loads DL networks for codegen |
| `coder.Constant(path)` for MAT file | Path is compile-time constant |
| `coder.load(path)` for non-DL data | Loads structs/shape models for codegen |
| `%#codegen` pragma | Enables code generation checks |
| Fixed input size in `-args` | Codegen requires known dimensions |

## Decision Framework

| Scenario | Path |
|----------|------|
| Prototype deployment, keep full MATLAB features | MATLAB Compiler |
| Monitoring dashboard or UI app | MATLAB Compiler |
| Embedded CPU target, no GPU | MATLAB Coder (mkl-dnn) |
| NVIDIA Jetson/Orin smart camera | GPU Coder + TensorRT |
| x86 or ARM smart camera (open standard) | MATLAB Coder |
| NPU or dedicated AI accelerator | ONNX export |
| Smart camera with vendor SDK | ONNX — often easiest integration |
| Beckhoff industrial PLC | MATLAB Coder → TwinCAT (TE1401) |
| Need bundled pre/post-processing in one binary | Codegen (MATLAB Coder or GPU Coder) |
| Model only, separate pre/post-processing OK | ONNX export |
| Shape model (non-DL, fixturing/counting) | `coder.load` + standard codegen |

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Not using `persistent` in entry point | Reloads model every frame | `persistent` + `isempty` guard |
| Passing MAT path as runtime variable | Codegen needs compile-time path | `coder.Constant("path.mat")` |
| Using `coder.load` for DL networks | Wrong loader for deep learning | `coder.loadDeepLearningNetwork` |
| Exporting to ONNX when pre/post-processing must be bundled | ONNX only exports the network | Use codegen to bundle full pipeline |
| Using ONNX for NVIDIA Jetson/Orin | Misses TensorRT optimization | GPU Coder + TensorRT for NVIDIA hardware |
| Extracting `.Network` or `.Backbone` before ONNX export | Loses detector-specific pre/post-processing layers | Pass the detector object directly: `exportONNXNetwork(detector, ...)` |
| Recomputing rectification per frame in production | Slow | Precompute `imageToWorldPlaneMapping`, reuse |
| Using codegen for UI/dashboard deployment | Codegen doesn't support UI | MATLAB Compiler for apps with UI |

## Conventions

- **Always:** use `persistent` + `isempty` for model loading in codegen entry points
- **Always:** use `coder.loadDeepLearningNetwork` for deep learning models
- **Always:** use `coder.Constant` for the MAT file path argument
- **Always:** specify fixed input dimensions in codegen `-args`
- **Never:** mix `coder.load` (structs) with `coder.loadDeepLearningNetwork` (DL)
- **Never:** extract `.Network` or `.Backbone` before calling `exportONNXNetwork` — pass the detector object directly
- **Prefer:** MATLAB Compiler for dashboards and UI-based monitoring apps
- **Prefer:** GPU Coder + TensorRT for NVIDIA targets (Jetson, Orin, dGPU)
- **Prefer:** MATLAB Coder for x86/ARM smart cameras and Beckhoff TwinCAT
- **Prefer:** ONNX when targeting NPUs, AI accelerators, or vendor camera SDKs
- **Prefer:** codegen when pre/post-processing must be bundled as one executable


----

Copyright 2026 The MathWorks, Inc.

----
