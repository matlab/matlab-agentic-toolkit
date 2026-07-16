# Data Layout: NCHW vs HWC

## Core Rule

`PyTorchExportedProgram` preserves PyTorch's native data layout. It does NOT
convert to MATLAB's traditional image convention.

| Framework | Layout | Example (224x224 RGB image) |
|-----------|--------|----------------------------|
| PyTorch | NCHW | `[1, 3, 224, 224]` |
| MATLAB images (`imread`) | HWC | `[224, 224, 3]` |
| `PyTorchExportedProgram` | NCHW (preserved) | `[1, 3, 224, 224]` |

## Determining the Expected Layout

Always check `inputSpecifications` — it reports the exact shape expected:

```matlab
model = loadPyTorchExportedProgram("resnet18.pt2");
inSpecs = model.inputSpecifications;
disp(inSpecs.Size{1})  % e.g., [1 3 224 224] for ResNet
```

## Common Layout Patterns by Model Type

| Model Type | PyTorch Layout | Dimensions |
|-----------|---------------|------------|
| Vision (CNN) | NCHW | `[batch, channels, height, width]` |
| Sequence (RNN/LSTM) | NCL | `[batch, features, sequence_length]` |
| Transformer (NLP) | NLC | `[batch, sequence_length, features]` |
| Audio | NCL | `[batch, channels, samples]` |

## When Permutation Is Needed

If the user's source data is in MATLAB image format (HWC), permute before passing
to `invoke`:

```matlab
img = single(imread("test.png"));  % [224, 224, 3] single HWC
input = permute(img, [4 3 1 2]);   % HWC -> 1CHW (add batch dim)
% Result: [1, 3, 224, 224] single
output = invoke(model, input);
```

**Note:** Model-specific preprocessing (normalization, resizing, mean subtraction,
etc.) is still required before calling `invoke`. The preprocessing depends on how
the PyTorch model was trained — consult the model's documentation for the expected
input range and transformations.

### Example: ResNet from torchvision

torchvision ImageNet models expect input normalized with ImageNet statistics:
- Mean: `[0.485, 0.456, 0.406]` (RGB)
- Std: `[0.229, 0.224, 0.225]` (RGB)
- Input range: `[0, 1]` before normalization
- Crop size: 224x224

```matlab
img = single(imread("test.png"));       % [H, W, 3] uint8 -> single
img = imresize(img, [224 224]);         % resize to expected crop size
img = img / 255.0;                      % scale to [0, 1]

% ImageNet normalization (per-channel)
mean = reshape(single([0.485, 0.456, 0.406]), [1 1 3]);
stddev = reshape(single([0.229, 0.224, 0.225]), [1 1 3]);
img = (img - mean) ./ stddev;

input = permute(img, [4 3 1 2]);        % HWC -> 1CHW
output = invoke(model, input);
```

For other models, find the expected preprocessing in the model's documentation.
torchvision models document their transforms at:
https://docs.pytorch.org/vision/stable/models.html

## When Permutation Is NOT Needed

- Data already in NCHW format (e.g., from another PyTorch preprocessing step)
- Random test inputs created directly in the correct shape:
  ```matlab
  input = randn(1, 3, 224, 224, "single");
  ```
- Sequence data already in NCL format

## Output Layout

Outputs also preserve PyTorch layout. For a classification model:
- PyTorch output: `[1, 1000]` (batch, classes)
- `invoke` output: `[1, 1000]` (same)

No permutation needed for 1D outputs (classification scores, embeddings).
For spatial outputs (segmentation masks, depth maps), the output will be NCHW —
permute back to HWC for display in MATLAB:

```matlab
output = invoke(model, input);          % [1, numClasses, H, W] NCHW
mask = permute(output, [3 4 2 1]);      % NCHW -> HWC (drop batch)
imshow(mask(:,:,1));                    % display first class channel
```

## Common Mistake

Assuming a fixed layout instead of checking `inputSpecifications`:

```matlab
% WRONG — assumes NCHW without checking
input = ones(224, 224, 3, "single");
output = invoke(model, input);  % likely shape mismatch

% CORRECT — always check inputSpecifications first
inSpecs = model.inputSpecifications;
disp(inSpecs.Size{1})  % reveals actual expected shape
input = ones(1, 3, 224, 224, "single");  % match what the model expects
output = invoke(model, input);
```

Most standard vision models (ResNet, EfficientNet, etc.) use NCHW, but custom
models may use any layout. Always consult `inputSpecifications`.

----

Copyright 2026 The MathWorks, Inc.

----
