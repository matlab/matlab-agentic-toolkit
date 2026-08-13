# Deep Learning Classification Workflows

Pixel classification using 3-D spatial-spectral CNN, 1-D spectral CNN, and ground truth to training data pipeline.

## Workflow 1: Pixel Classification with 3-D Spectral-Spatial CNN (CSCNN)

```matlab
%% Load and preprocess
hcube = imhypercube("indian_pines.dat");
gtLabel = load("indian_pines_gt.mat").indian_pines_gt;
numClasses = max(gtLabel(:));

% Dimensionality reduction via PCA
numPCBands = 30;
imageData = hyperpca(hcube, numPCBands);

% Normalize by per-band standard deviation
sd = std(imageData, [], 3);
imageData = imageData ./ sd;

%% Create spatial patches
windowSize = 25;
inputSize = [windowSize windowSize numPCBands];
[allPatches, allLabels] = createImagePatchesFromHypercube(imageData, gtLabel, windowSize);

% Filter labeled patches only
patchesLabeled = allPatches(allLabels > 0, :, :, :);
patchLabels = categorical(allLabels(allLabels > 0));

% Split: 30% train, 70% test
[trainIdx, ~, testIdx] = dividerand(size(patchesLabeled, 1), 0.3, 0, 0.7);
XTrain = permute(patchesLabeled(trainIdx, :, :, :), [2 3 4 1]);
YTrain = patchLabels(trainIdx);
XTest = permute(patchesLabeled(testIdx, :, :, :), [2 3 4 1]);
YTest = patchLabels(testIdx);

% Create datastores
dsTrain = augmentedImageDatastore(inputSize, XTrain, YTrain);
dsTest = augmentedImageDatastore(inputSize, XTest, YTest);

%% Define 3-D CNN (Custom Spectral CNN architecture)
layers = [
    image3dInputLayer(inputSize, Name="Input", Normalization="none")
    convolution3dLayer([3 3 7], 8, Name="conv3d_1")
    reluLayer(Name="relu_1")
    convolution3dLayer([3 3 5], 16, Name="conv3d_2")
    reluLayer(Name="relu_2")
    convolution3dLayer([3 3 3], 32, Name="conv3d_3")
    reluLayer(Name="relu_3")
    convolution3dLayer([3 3 1], 8, Name="conv3d_4")
    reluLayer(Name="relu_4")
    fullyConnectedLayer(256, Name="fc1")
    reluLayer(Name="relu_5")
    dropoutLayer(0.4, Name="drop_1")
    fullyConnectedLayer(128, Name="fc2")
    dropoutLayer(0.4, Name="drop_2")
    fullyConnectedLayer(numClasses, Name="fc3")
    softmaxLayer(Name="softmax")
];
net = dlnetwork(layers);

%% Train
options = trainingOptions("adam", ...
    InitialLearnRate=0.001, ...
    LearnRateSchedule="piecewise", ...
    LearnRateDropPeriod=30, ...
    LearnRateDropFactor=0.01, ...
    MaxEpochs=100, ...
    MiniBatchSize=256, ...
    GradientThresholdMethod="l2norm", ...
    GradientThreshold=0.01, ...
    ValidationData=dsTest, ...
    ValidationFrequency=100, ...
    Plots="training-progress");

net = trainnet(dsTrain, net, "crossentropy", options);

%% Predict and evaluate
dsAll = augmentedImageDatastore(inputSize, permute(allPatches, [2 3 4 1]), allLabels);
scores = minibatchpredict(net, dsAll);
prediction = scores2label(scores, categories(YTrain));

% Mask unlabeled pixels
prediction(allLabels == 0) = "<undefined>";
[M, N, ~] = size(imageData);
classMap = reshape(prediction, [N M])';
```

## Workflow 2: 1-D Spectral CNN for Pixel Classification

```matlab
%% Load data
hcube = imhypercube("scene.hdr");
dataCube = gather(hcube);
[M, N, C] = size(dataCube);

%% Load ground truth and extract labeled pixels
load("gTruth.mat", "gTruth");
labelMap = createLabelMapFromGTruth(gTruth, [M N]);  % user-defined helper

pixels = reshape(dataCube, [], C);
labels = reshape(labelMap, [], 1);
validIdx = ~isundefined(labels);
trainPixels = pixels(validIdx, :);
trainLabels = labels(validIdx);

% Reshape for 1-D CNN: C-by-1-by-1-by-numSamples
numSamples = sum(validIdx);
XTrain = reshape(trainPixels', [C 1 1 numSamples]);

%% Define 1-D spectral CNN
numClasses = numel(categories(trainLabels));
layers = [
    image3dInputLayer([C 1 1], Normalization="none")
    convolution3dLayer([7 1 1], 32, Padding="same")
    batchNormalizationLayer
    reluLayer
    convolution3dLayer([5 1 1], 64, Padding="same")
    batchNormalizationLayer
    reluLayer
    convolution3dLayer([3 1 1], 128, Padding="same")
    batchNormalizationLayer
    reluLayer
    globalAveragePooling3dLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer
];
net = dlnetwork(layers);

%% Train
options = trainingOptions("adam", ...
    MaxEpochs=50, ...
    MiniBatchSize=256, ...
    InitialLearnRate=1e-3, ...
    Shuffle="every-epoch", ...
    Plots="training-progress");

net = trainnet(XTrain, trainLabels, net, "crossentropy", options);

%% Predict full image
XAll = reshape(pixels', [C 1 1 M*N]);
scores = minibatchpredict(net, XAll);
predLabels = scores2label(scores, categories(trainLabels));
classMap = reshape(predLabels, [M N]);
```

## Workflow 3: Ground Truth to Training Data Pipeline

```matlab
%% Load exported ground truth from Spectral Image Labeler
load("labelerSession.mat", "gTruth");

%% Load spectral data from the ground truth source
hcube = imhypercube(gTruth.DataSource.Filename);
dataCube = gather(hcube);
[M, N, C] = size(dataCube);

%% Convert polyshape ROIs to pixel label mask
labelNames = gTruth.LabelDefinitions.LabelName;
labelMask = zeros(M, N);

for j = 1:numel(labelNames)
    for row = 1:height(gTruth.LabelData)
        roiData = gTruth.LabelData.(labelNames(j)){row};
        if ~isempty(roiData)
            vertices = roiData.ROI.Vertices;
            mask = poly2mask(vertices(:,1), vertices(:,2), M, N);
            labelMask(mask) = j;
        end
    end
end

%% Create training arrays
pixels = reshape(dataCube, [], C);
pixelLabels = reshape(labelMask, [], 1);
validIdx = pixelLabels > 0;
XTrain = pixels(validIdx, :);
YTrain = categorical(pixelLabels(validIdx), 1:numel(labelNames), labelNames);

%% Or create patches for spatial-spectral CNN
patchSize = 25;
halfPatch = floor(patchSize/2);
[rows, cols] = find(labelMask > 0);

patches = zeros(patchSize, patchSize, C, numel(rows), 'single');
patchLabels = categorical.empty;
count = 0;

for i = 1:numel(rows)
    r = rows(i); c = cols(i);
    if r > halfPatch && r <= M-halfPatch && c > halfPatch && c <= N-halfPatch
        count = count + 1;
        patches(:,:,:,count) = dataCube(r-halfPatch:r+halfPatch, c-halfPatch:c+halfPatch, :);
        patchLabels(count,1) = categorical(labelMask(r,c), 1:numel(labelNames), labelNames);
    end
end
patches = patches(:,:,:,1:count);
patchLabels = patchLabels(1:count);
```

## Common Patterns

### Creating Datastores for Large Datasets

```matlab
% Array datastores for patches
patchDS = arrayDatastore(patches, IterationDimension=4);
labelDS = arrayDatastore(patchLabels);
trainDS = combine(patchDS, labelDS);

% Use with trainnet
net = trainnet(trainDS, net, "crossentropy", options);
```

### Evaluating Classification Results

```matlab
% Predict and convert scores to labels
scores = minibatchpredict(net, dsTest);
YPred = scores2label(scores, categories(YTest));

% Confusion matrix
figure;
confusionchart(YTest, YPred);

% Overall and per-class accuracy
accuracy = mean(YPred == YTest);
cm = confusionmat(YTest, YPred);
perClassAcc = diag(cm) ./ sum(cm, 2);
fprintf("Overall Accuracy: %.2f%%\n", accuracy * 100);
```

### Visualizing Classification Map

```matlab
[M, N, ~] = size(imageData);
classMap = reshape(classIdx, [M N]);

figure;
imagesc(classMap);
colormap(jet(numClasses));
colorbar(TickLabels=categories(YTrain), Ticks=1:numClasses);
title("Classification Map");
```

### Helper: Patch Extraction from Hypercube

```matlab
function [patches, labels] = createImagePatchesFromHypercube(imageData, gtLabel, windowSize)
    [M, N, C] = size(imageData);
    halfWin = floor(windowSize / 2);
    padded = padarray(imageData, [halfWin halfWin 0], 0, "both");

    numPixels = M * N;
    patches = zeros(numPixels, windowSize, windowSize, C, 'single');
    labels = reshape(gtLabel, [], 1);

    idx = 0;
    for r = 1:M
        for c = 1:N
            idx = idx + 1;
            patches(idx, :, :, :) = padded(r:r+windowSize-1, c:c+windowSize-1, :);
        end
    end
end
```

----

Copyright 2026 The MathWorks, Inc.
