# Deep Learning for Image Processing

Decision guidance for combining deep learning with image processing: data preparation, semantic segmentation, pretrained networks, and inference pipelines. Requires Deep Learning Toolbox; some features require Computer Vision Toolbox.

> **Often loaded with:** `image-io.md` (datastores and batch loading), `analysis-measurement.md` (post-processing segmentation output).

## Using Pretrained PyTorch Vision Models

For tasks where a pretrained PyTorch model is the best starting point (e.g., depth estimation, style transfer, foundation models not available natively in MATLAB), use the **`matlab-integrate-pytorch-vision`** skill to interface with Python model repositories from MATLAB.

## Toolbox Requirements

| Task | Required toolboxes |
|------|-------------------|
| Training/inference | Deep Learning Toolbox |
| Semantic segmentation architectures | Computer Vision Toolbox |
| Object detection architectures | Computer Vision Toolbox |
| Image data augmentation | Deep Learning Toolbox |
| Pretrained feature extraction | Deep Learning Toolbox |

**Check availability before generating code:**
```matlab
hasDeepLearning = ~isempty(ver("nnet"));
hasComputerVision = ~isempty(ver("vision"));
```

## 1. Data Preprocessing

### Image Datastores

#### Classification (folder-per-class)

```matlab
imds = imageDatastore("data/images/", ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");  % Labels from folder names (e.g., cat/, dog/)
```

#### Semantic Segmentation (image + pixel label pairs)

```matlab
imds = imageDatastore("data/images/");

classNames = ["background", "tumor", "healthy"];
labelIDs = [0 1 2];
pxds = pixelLabelDatastore("data/labels/", classNames, labelIDs);

ds = combine(imds, pxds);
```

#### Image Regression (image + continuous target)

```matlab
imds = imageDatastore("data/images/");

% Targets from a table or file (e.g., depth maps, angles, coordinates)
targets = readtable("data/targets.csv");  % columns: filename, value1, value2, ...
targetDs = arrayDatastore(targets{:, 2:end});

ds = combine(imds, targetDs);
```

For image-to-image regression (e.g., denoising, super-resolution, depth estimation):

```matlab
inputImds = imageDatastore("data/noisy/");
targetImds = imageDatastore("data/clean/");
ds = combine(inputImds, targetImds);
```

### Resizing for Network Input

Networks require fixed input size. Resize images to match:

```matlab
targetSize = [256 256];  % [rows cols] — NOT [width height]

% For datastores — use transform
dsResized = transform(ds, @(data) resizeForNetwork(data, targetSize));

function out = resizeForNetwork(data, targetSize)
    out{1} = imresize(data{1}, targetSize);
    out{2} = imresize(data{2}, targetSize, "nearest");  % Labels: nearest!
end
```

**Gotcha:** Always use `"nearest"` interpolation when resizing label maps or masks. Default bicubic creates invalid fractional labels.

#### Aspect-Ratio-Preserving Resize

When aspect ratio distortion hurts accuracy (e.g., object detection), pad to the target size instead of stretching:

```matlab
function out = letterboxResize(img, targetSize)
    [h, w, ~] = size(img);
    scale = min(targetSize(1)/h, targetSize(2)/w);
    newSize = round([h w] * scale);
    resized = imresize(img, newSize);

    padValue = 114;  % common gray fill for detection networks
    out = ones(targetSize(1), targetSize(2), size(img,3), class(img)) * padValue;
    offset = floor((targetSize - newSize) / 2) + 1;
    out(offset(1):offset(1)+newSize(1)-1, offset(2):offset(2)+newSize(2)-1, :) = resized;
end
```

For semantic segmentation, wrap as a paired `transform` that also pads labels with an ignore value (e.g., 255) so padded pixels do not contribute to loss.

### Input Normalization — Critical

Networks expect specific input ranges. Common patterns:

| Network type | Expected input | Prepare with |
|-------------|---------------|--------------|
| Pretrained (ImageNet) | Per-channel zero-mean, unit-variance | Subtract ImageNet channel means, divide by stds |
| Pretrained (COCO) | Per-channel zero-mean, unit-variance | Subtract COCO channel means, divide by stds |
| Custom (trained on [0,1]) | [0, 1] single | `im2single(img)` or `rescale(img, 0, 1)` for arbitrary-range data |
| Custom (trained on [-1,1]) | [-1, 1] | `rescale(img, -1, 1)` |
| Arbitrary range (medical HU, float sensors) | Dataset-specific z-score | Compute dataset mean/std, normalize |

**Gotcha:** If your training data was uint8 [0,255] but inference images are double [0,1], the network will produce garbage. Always match inference preprocessing to training preprocessing.

#### Pretrained Networks (ImageNet / COCO)

Most pretrained backbones use fixed per-channel statistics:

```matlab
% ImageNet (ResNet, VGG, EfficientNet, etc.)
channelMeans = single([0.485, 0.456, 0.406]);
channelStds  = single([0.229, 0.224, 0.225]);

% COCO (detection/segmentation models pretrained on COCO)
channelMeans = single([0.471, 0.448, 0.408]);
channelStds  = single([0.234, 0.239, 0.242]);

% Apply: input must be single [0,1] first
img = im2single(img);  % uint8 [0,255] → single [0,1]
img = (img - reshape(channelMeans, 1, 1, 3)) ./ reshape(channelStds, 1, 1, 3);
```

#### Custom Networks (Compute-Then-Apply)

Compute mean/std from your training set, save, then apply via `transform`:

```matlab
% Step 1: Compute channel-wise statistics
imds = imageDatastore("train/", IncludeSubfolders=true);
pixelSum = single([0 0 0]);
pixelSqSum = single([0 0 0]);
nPixels = 0;

while hasdata(imds)
    img = single(read(imds));
    nPx = size(img, 1) * size(img, 2);
    pixelSum = pixelSum + sum(img, [1 2]);
    pixelSqSum = pixelSqSum + sum(img.^2, [1 2]);
    nPixels = nPixels + nPx;
end
reset(imds);

channelMeans = pixelSum / nPixels;
channelStds = sqrt(pixelSqSum / nPixels - channelMeans.^2);
save("normalization_params.mat", "channelMeans", "channelStds");

% Step 2: Apply in training pipeline
params = load("normalization_params.mat");
dsTrain = transform(dsTrain, @(data) normalizeForTraining(data, params));

function out = normalizeForTraining(data, params)
    img = single(data{1});
    img = (img - reshape(params.channelMeans, 1, 1, [])) ./ ...
          reshape(params.channelStds, 1, 1, []);
    out = {img, data{2}};  % {normalized image, label}
end
```

### Data Augmentation

```matlab
augmenter = imageDataAugmenter( ...
    RandXReflection=true, ...
    RandRotation=[-10 10], ...
    RandScale=[0.9 1.1]);

augDs = augmentedImageDatastore(targetSize, imds, ...
    DataAugmentation=augmenter);
```

For segmentation (paired image + label augmentation), use `transform` with custom function:

```matlab
ds = combine(imds, pxds);
dsAug = transform(ds, @augmentPair);

function out = augmentPair(data)
    img = data{1};
    lbl = data{2};
    % Apply same geometric transform to both
    if rand > 0.5
        img = fliplr(img);
        lbl = fliplr(lbl);
    end
    tform = randomAffine2d(Rotation=[-15 15], Scale=[0.8 1.2]);
    rout = affineOutputView(size(img), tform);
    img = imwarp(img, tform, OutputView=rout);
    lbl = imwarp(lbl, tform, OutputView=rout, Interpolation="nearest");
    out = {img, lbl};
end
```

### Channel Count Mismatches

| Scenario | Solution |
|----------|----------|
| Grayscale image → network expects RGB (3-ch) | `repmat(grayImg, 1, 1, 3)` |
| RGB image → network expects grayscale (1-ch) | `im2gray(rgbImg)` |
| Medical volume → network expects 2-D slices | Process slice-by-slice |
| Multi-channel (>3) → standard network | Custom input layer or channel reduction |


## 2. Modeling

### Building from Scratch (Layer-by-Layer)

Define custom architectures using Deep Learning Toolbox layers:

```matlab
layers = [
    imageInputLayer([256 256 3], Normalization="none")
    convolution2dLayer(3, 32, Padding="same")
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2, Stride=2)
    convolution2dLayer(3, 64, Padding="same")
    batchNormalizationLayer
    reluLayer
    globalAveragePooling2dLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer
];
net = dlnetwork(layers);
```

Use `addLayers` and `connectLayers` for branching or multi-input architectures:

```matlab
net = dlnetwork;
net = addLayers(net, [imageInputLayer([256 256 3]) convolution2dLayer(3, 32)]);
net = addLayers(net, [reluLayer concatenationLayer(3, 2)]);
net = connectLayers(net, "conv", "relu");
```

Use **Deep Network Designer** app (`deepNetworkDesigner`) to visually inspect, edit, and validate network architectures.

### Classification with Pretrained Encoders

Use `pretrainedEncoderNetwork` to create a feature extractor from a pretrained backbone, then add classification layers:

```matlab
[encoder, outputNames] = pretrainedEncoderNetwork("resnet18", 4);
```

### Semantic Segmentation Architectures

| Architecture | Function | Best for |
|-------------|----------|----------|
| U-Net | `unet` | Medical imaging, small datasets |
| 3-D U-Net | `unet3d` | Volumetric data (CT, MRI) |
| DeepLab v3+ | `deeplabv3plus` | General segmentation, large images |
| BISENet | `bisenetv2` | Real-time segmentation |

```matlab
inputSize = [256 256 1];  % [H W C]
numClasses = 3;

% U-Net
net = unet(inputSize, numClasses, EncoderDepth=4);

% 3-D U-Net (volumetric)
net = unet3d([64 64 64 1], numClasses, EncoderDepth=3);

% DeepLab v3+ with pretrained backbone
net = deeplabv3plus([256 256 3], numClasses, "resnet18");

% BISENet v2 (lightweight, real-time)
net = bisenetv2(inputSize, numClasses);
```

To adapt segmentation architectures for **image-to-image regression** (e.g., depth estimation, denoising), replace the final classification layer with a regression output (1 or N channels, no softmax):

```matlab
net = unet([256 256 3], 2, EncoderDepth=4);  % Start with 2-class U-Net
% Replace final conv + softmax for single-channel regression output
net = replaceLayer(net, "encoderDecoderFinalConvLayer", ...
    convolution2dLayer(1, 1, Name="encoderDecoderFinalConvLayer"));
net = removeLayers(net, "FinalNetworkSoftmax-Layer");
```

### Custom Encoder-Decoder

For more control over skip connections and decoder structure, use `encoderDecoderNetwork` with a pretrained encoder:

```matlab
[encoder, outputNames] = pretrainedEncoderNetwork("resnet18", 4);
net = encoderDecoderNetwork([256 256 3], encoder, outputNames, ...
    NumClasses=numClasses);
```

## 3. Training

```matlab
options = trainingOptions("adam", ...
    InitialLearnRate=1e-3, ...
    MaxEpochs=50, ...
    MiniBatchSize=8, ...
    Shuffle="every-epoch", ...
    ValidationData=valDs, ...
    ValidationFrequency=50, ...
    Plots="training-progress");

net = trainnet(dsTrain, net, "crossentropy", options);
```

**Modern API:** Use `trainnet`, not the legacy `trainNetwork`. `trainnet` returns a `dlnetwork` directly.

## 4. Evaluation

### Inference

```matlab
% Single image
result = semanticseg(testImage, net);  % Returns categorical label map

% Batch via datastore
pxdsResults = semanticseg(testImds, net, WriteLocation="results/");
```

#### Inference — Reuse Training Normalization

Always load and apply the same normalization at inference:

```matlab
params = load("normalization_params.mat");
testImg = im2single(imread("test.png"));
testImg = (testImg - reshape(params.channelMeans, 1, 1, [])) ./ ...
          reshape(params.channelStds, 1, 1, []);
result = semanticseg(testImg, net);
```

#### Patch-Based Inference (Large Images/Volumes)

For images larger than GPU memory:

```matlab
bim = blockedImage(largeImage);

patchSize = [256 256];
overlap = [32 32];
result = apply(bim, @(block) semanticseg(block.Data, net), ...
    BlockSize=patchSize, ...
    BorderSize=overlap, ...
    PadPartialBlocks=true);
```

### Classification Metrics

```matlab
scores = minibatchpredict(net, dsTest);
YPred = scores2label(scores, classNames);

% ROC curve and AUC
rocObj = rocmetrics(YTest, scores, classNames);
plot(rocObj);

% Confusion matrix
confusionchart(YTest, YPred);
```

### Segmentation Quality Metrics

```matlab
% Confusion matrix metrics
metrics = evaluateSemanticSegmentation(pxdsResults, pxdsGT);
disp(metrics.ClassMetrics);    % Per-class IoU, accuracy
disp(metrics.DataSetMetrics);  % Mean IoU, mean accuracy, weighted IoU
```

### Post-Processing Segmentation Output

Raw network output often needs cleanup:

```matlab
% Convert categorical to numeric labels
labelMap = uint8(result);

% Remove small regions (per-class)
for c = 1:numClasses
    classMask = labelMap == c;
    classMask = bwareaopen(classMask, minPixels);
    labelMap(labelMap == c & ~classMask) = 0;
end

% Fill holes in segmentation
for c = 1:numClasses
    classMask = labelMap == c;
    classMask = imfill(classMask, "holes");
    labelMap(classMask) = c;
end
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| `trainNetwork` (legacy) | Deprecated, returns `SeriesNetwork`/`DAGNetwork` | Use `trainnet`, returns `dlnetwork` |
| Resizing labels with default interpolation | Bicubic creates invalid fractional labels | Always `imresize(lbl, sz, "nearest")` |
| Mismatched input range at inference | Network trained on [0,255] but given [0,1] | Match preprocessing exactly to training |
| Grayscale into 3-channel network | Dimension mismatch error | `repmat(gray, 1, 1, 3)` |
| Training segmentation without class weighting | Rare classes never learned | Use class weights or `"focal"` loss |
| Processing large image at full resolution | Out of memory | Patch-based with `blockedImage` or `randomPatchExtractionDatastore` |
| `augmentedImageDatastore` for segmentation | Only augments images, not labels | Use `transform` with paired augmentation function |
| Forgetting `"nearest"` for warping labels | `imwarp` default is linear → fractional labels | `imwarp(lbl, tform, Interpolation="nearest")` |

----

Copyright 2026 The MathWorks, Inc.

----
