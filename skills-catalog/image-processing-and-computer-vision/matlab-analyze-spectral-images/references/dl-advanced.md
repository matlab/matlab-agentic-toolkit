# Advanced Deep Learning Workflows

Spectral unmixing autoencoder, transfer learning, and semantic segmentation (DeepLabV3+) for multispectral satellite imagery.

## Workflow 4: Spectral Unmixing with Autoencoder

```matlab
%% Prepare data
hcube = imhypercube("scene.hdr");
dataCube = gather(hcube);
[M, N, C] = size(dataCube);
pixels = reshape(double(dataCube), [], C);

% Normalize to [0, 1]
pixelMax = max(pixels, [], "all");
pixelsNorm = pixels / pixelMax;

%% Define autoencoder for unmixing
numEndmembers = 5;

% Encoder: learns abundance fractions (sum-to-one via softmax)
% Decoder: learns endmember signatures (weights = endmember spectra)
layers = [
    featureInputLayer(C, Name="input")
    fullyConnectedLayer(128, Name="enc1")
    reluLayer(Name="enc_relu")
    fullyConnectedLayer(numEndmembers, Name="abundances")
    softmaxLayer(Name="abundance_softmax")
    fullyConnectedLayer(C, Name="decoder")
];
net = dlnetwork(layers);

%% Train (self-supervised: input = target)
options = trainingOptions("adam", ...
    MaxEpochs=100, ...
    MiniBatchSize=512, ...
    InitialLearnRate=1e-3, ...
    Plots="training-progress");

net = trainnet(pixelsNorm, pixelsNorm, net, "mse", options);

%% Extract endmembers from decoder weights
decoderIdx = net.Learnables.Layer == "decoder" & net.Learnables.Parameter == "Weights";
decoderWeights = net.Learnables.Value{decoderIdx};  % C-by-numEndmembers
endmembers = extractdata(decoderWeights)' * pixelMax;

%% Predict abundance maps
abundances = minibatchpredict(net, pixelsNorm, Outputs="abundance_softmax");
abundanceMaps = reshape(double(abundances), M, N, numEndmembers);
```

## Workflow 5: Transfer Learning with Pretrained Network

```matlab
%% Load data and reduce to 3 channels for pretrained network
hcube = imhypercube("scene.hdr");
dataCube = gather(hcube);
[M, N, C] = size(dataCube);

% PCA to 3 bands (compatible with pretrained RGB networks)
[pcaCube, ~, ~] = hyperpca(dataCube, 3);

%% Create patches and labels (use ground truth)
patchSize = 224;  % match pretrained network input size
% ... extract patches from pcaCube with labels ...

%% Load pretrained network and modify
net = imagePretrainedNetwork("resnet18");

% Replace classification head
numClasses = 4;
net = replaceLayer(net, "fc1000", fullyConnectedLayer(numClasses, Name="fc_new"));
net = replaceLayer(net, "prob", softmaxLayer(Name="prob_new"));

%% Train with lower learning rate for fine-tuning
options = trainingOptions("sgdm", ...
    MaxEpochs=20, ...
    MiniBatchSize=32, ...
    InitialLearnRate=1e-4, ...
    Plots="training-progress");

net = trainnet(XTrain, YTrain, net, "crossentropy", options);
```

## Workflow 6: Semantic Segmentation of Multispectral Satellite Imagery (DeepLabV3+)

```matlab
%% Load Sentinel-2 data and prepare multispectral cube
mcube = geomulticube("sentinel2.safe");
resampledMcube = resampleBands(mcube, mcube.BandResolution(2));  % 10m resolution
imgCube = gather(resampledMcube);  % M-by-N-by-12 (12 Sentinel-2 bands)

%% Create patches for training (balanced sampling)
patchSize = [256 256];
numChannels = size(imgCube, 3);
labelMask = imread("label_mask.tif");  % binary or multi-class mask

% Extract balanced patches (positive and negative)
[patches, patchLabels] = extractBalancedPatches(imgCube, labelMask, patchSize, 2000);

%% Create datastores
imds = imageDatastore("patches_images/", FileExtensions={".tif"});
pxds = pixelLabelDatastore("patches_labels/", classNames, labelIDs, ...
    FileExtensions={".tif"});

% Partition: 60% train, 20% val, 20% test
numFiles = numel(imds.Files);
idx = randperm(numFiles);
nTrain = round(0.6*numFiles);
nVal = round(0.2*numFiles);
imdsTrain = subset(imds, idx(1:nTrain));
pxdsTrain = subset(pxds, idx(1:nTrain));
imdsVal = subset(imds, idx(nTrain+1:nTrain+nVal));
pxdsVal = subset(pxds, idx(nTrain+1:nTrain+nVal));
imdsTest = subset(imds, idx(nTrain+nVal+1:end));
pxdsTest = subset(pxds, idx(nTrain+nVal+1:end));

% Combine and augment training data
dsTrain = combine(imdsTrain, pxdsTrain);
dsTrain = transform(dsTrain, @augmentImageAndPixelLabels);
dsVal = combine(imdsVal, pxdsVal);

%% Create DeepLabV3+ network adapted for multispectral input
numClasses = numel(classNames);
net = deeplabv3plus(patchSize, numClasses, "resnet50");

% Replace input layer for multi-channel (12 bands instead of 3)
layer = imageInputLayer([patchSize numChannels], Name="input_2", ...
    Normalization="none");
net = replaceLayer(net, "input_1", layer);

% Replace first conv layer (original expects 3-channel RGB)
layer = convolution2dLayer([7 7], 64, Name="conv1", ...
    Padding=[3 3 3 3], Stride=[2 2]);
net = replaceLayer(net, "conv1", layer);

%% Training options
options = trainingOptions("adam", ...
    InitialLearnRate=1e-4, ...
    L2Regularization=5e-4, ...
    MaxEpochs=15, ...
    MiniBatchSize=8, ...
    LearnRateSchedule="piecewise", ...
    LearnRateDropPeriod=10, ...
    LearnRateDropFactor=0.5, ...
    Shuffle="every-epoch", ...
    ValidationData=dsVal, ...
    ValidationFrequency=50, ...
    OutputNetwork="best-validation-loss", ...
    Plots="training-progress");

%% Train with custom focal loss for class imbalance
net = trainnet(dsTrain, net, @modelLoss, options);

%% Predict on test set
pxdsResults = semanticseg(imdsTest, net, ...
    MiniBatchSize=4, ...
    WriteLocation="predictions/", ...
    Classes=classNames);

%% Evaluate metrics
metrics = evaluateSemanticSegmentation(pxdsResults, pxdsTest, ...
    Metrics=["global-accuracy", "accuracy", "weighted-iou"]);
disp(metrics.DataSetMetrics);
disp(metrics.ClassMetrics);

%% Predict full tile (sliding window)
function predMask = predictFullTile(imgCube, net, patchSize)
    [H, W, ~] = size(imgCube);
    predMask = zeros(H, W, 'uint8');
    pH = patchSize(1); pW = patchSize(2);
    for r = 1:pH:H
        rEnd = min(r+pH-1, H);
        for c = 1:pW:W
            cEnd = min(c+pW-1, W);
            patch = imgCube(r:rEnd, c:cEnd, :);
            patchPred = semanticseg(patch, net, ...
                MiniBatchSize=1, OutputType="uint8");
            predMask(r:r+size(patchPred,1)-1, c:c+size(patchPred,2)-1) = patchPred;
        end
    end
end

%% Custom focal loss function
function loss = modelLoss(Y, targets)
    targets(isnan(targets)) = 0;
    loss = focalCrossEntropy(Y, targets, Gamma=3);
end

%% Data augmentation for image + pixel labels
function dataOut = augmentImageAndPixelLabels(dataIn)
    img = dataIn{1};
    pixLab = dataIn{2};
    tform = randomAffine2d(Rotation=[-45 45], XReflection=true, ...
        YReflection=true, Scale=[0.8 1.2]);
    outview = affineOutputView(size(img), tform);
    dataOut{1} = imwarp(img, tform, OutputView=outview);
    dataOut{2} = imwarp(pixLab, tform, OutputView=outview);
end
```

**Key differences from pixel-classification workflows:**
- Uses **2-D semantic segmentation** (DeepLabV3+) instead of 3-D patch-based CNN
- Requires **`replaceLayer`** to adapt pretrained backbone for >3 channel input
- Uses **`pixelLabelDatastore`** for per-pixel ground truth (not categorical arrays)
- Uses **`semanticseg`** for inference (returns label images directly)
- Uses **`evaluateSemanticSegmentation`** for IoU/accuracy metrics
- **`focalCrossEntropy`** handles severe class imbalance in satellite imagery
- Processes large tiles via **sliding window prediction**

**Required toolboxes:** Image Processing Toolbox, Deep Learning Toolbox, Computer Vision Toolbox

----

Copyright 2026 The MathWorks, Inc.
