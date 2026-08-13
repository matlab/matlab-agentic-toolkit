# Custom OCR Model Training Guide

## When to Train a Custom Model

**Train only when ALL of these conditions are true:**

1. Default `ocr()` with preprocessing gives consistently poor results
2. Tuning `LayoutAnalysis`, `CharacterSet`, and preprocessing does not resolve issues
3. The font/character set is not covered by any built-in model (64 languages + seven-segment)
4. You have or can create labeled ground truth data (50+ images minimum)
5. The use case is repeated/high-volume enough to justify the effort

**Common scenarios requiring custom training:**
- Industrial seven-segment variants not covered by built-in model
- LED/LCD display fonts with unique styling
- Custom symbology (warehouse codes, proprietary markings)
- Degraded historical document fonts
- Domain-specific character sets (circuit labels, chemical formulas)

**Do NOT train when:**
- A different language model would work — try `Model="japanese"` etc. first
- Preprocessing would fix it — most failures are preprocessing problems
- The character set is standard but images are noisy — preprocess instead
- You only have a few images — insufficient data for training

## Training Workflow

### Step 1: Create Ground Truth Labels

Use the Image Labeler app to label text regions:

```matlab
% Launch Image Labeler
imageLabeler

% In the app:
% 1. Import images
% 2. Create a Rectangle ROI label named "TextROI"
% 3. Add a String attribute named "Text" to the label
% 4. Draw bounding boxes around each text region
% 5. Type the text content into the "Text" attribute
% 6. Export to workspace as 'gTruth'
```

**Labeling tips:**
- Label at word level (one box per word) for best results
- Include variety: different sizes, orientations, backgrounds
- Minimum 50 labeled images; 200+ recommended for robustness
- Include hard cases that the default model fails on

### Step 2: Extract Training Data

```matlab
% Extract datastores from ground truth
[imds, boxds, txtds] = ocrTrainingData(gTruth, "TextROI", "Text");

% Combine into single training datastore
trainingData = combine(imds, boxds, txtds);

% Optional: split for validation (80/20)
numImages = numel(imds.Files);
idx = randperm(numImages);
trainIdx = idx(1:round(0.8*numImages));
valIdx = idx(round(0.8*numImages)+1:end);
```

### Step 3: Configure Training Options

```matlab
options = ocrTrainingOptions( ...
    MaxEpochs=10, ...
    InitialLearnRate=0.001, ...
    Verbose=true, ...
    VerboseFrequency=50, ...
    CheckpointPath=tempdir, ...
    CheckpointFrequency=1);

% With validation for early stopping
options = ocrTrainingOptions( ...
    MaxEpochs=20, ...
    InitialLearnRate=0.001, ...
    ValidationData=validationData, ...
    ValidationFrequency=50, ...
    ValidationPatience=5, ...
    OutputNetwork="best-validation-loss");
```

### Step 4: Train

```matlab
% Fine-tune from English base model (transfer learning)
modelFile = trainOCR(trainingData, "myCustomModel", "english", options);

% Or fine-tune from another language base
modelFile = trainOCR(trainingData, "myCustomModel", "japanese", options);

% Resume from checkpoint if interrupted
modelFile = trainOCR(trainingData, "myCustomModel", checkpointPath, options);
```

### Step 5: Evaluate

```matlab
% Test on held-out images
results = ocr(testImage, Model=modelFile);
disp(results.Text)

% Formal evaluation with metrics
metrics = evaluateOCR(results, groundTruthDatastore);
disp(metrics.DataSetMetrics)  % Overall CER and WER
disp(metrics.ImageMetrics)    % Per-image breakdown
```

**Metrics explained:**
- **CER (Character Error Rate):** Edit distance between predicted and ground-truth characters / ground-truth length. Target: < 0.05
- **WER (Word Error Rate):** Edit distance between predicted and ground-truth words / ground-truth count. Target: < 0.10

### Step 6: Quantize for Speed (Optional)

```matlab
% Quantize for ~40% faster inference (small accuracy tradeoff)
fastModelFile = quantizeOCR(modelFile, "myCustomModel-fast");

% Use quantized model
results = ocr(I, Model=fastModelFile);
```

## Training Functions Reference

| Function | Purpose |
|----------|---------|
| `ocrTrainingData` | Extract training datastores from groundTruth object |
| `ocrTrainingOptions` | Configure hyperparameters (epochs, LR, solver, validation) |
| `trainOCR` | Train or fine-tune an OCR model |
| `evaluateOCR` | Compute CER/WER against ground truth |
| `ocrMetrics` | Object holding dataset and per-image error metrics |
| `quantizeOCR` | Reduce model to lower precision for speed |

## Key Training Parameters

| Parameter | Default | Guidance |
|-----------|---------|----------|
| `MaxEpochs` | 5 | Start with 10-20; use validation patience for early stopping |
| `InitialLearnRate` | 0.001 | Lower (0.0001) for fine-tuning, higher (0.01) for new domains |
| `SolverName` | `"adam"` | Adam works well; try `"sgdm"` if Adam oscillates |
| `CharacterSetSource` | `"auto"` | Use `"ground-truth-data"` for custom character sets |
| `ValidationPatience` | Inf | Set to 5-10 to enable early stopping |
| `OutputNetwork` | `"auto"` | Use `"best-validation-loss"` when validation data provided |

## Troubleshooting Training

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Training loss not decreasing | Learning rate too low or data issue | Increase LR or check label quality |
| Validation loss increasing | Overfitting | Reduce epochs, add more data, or lower LR |
| Model worse than baseline | Insufficient or mismatched training data | Need more diverse examples |
| Training very slow | Large images | Crop to text regions before training |
| Out of memory | Images too large or batch too big | Resize images or reduce batch size |


----
Copyright 2026 The MathWorks, Inc.
----
