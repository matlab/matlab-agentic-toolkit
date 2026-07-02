% trainImageClassifier.m — Train a CNN for image classification
% Located at: /projects/imgclass/trainImageClassifier.m

dataDir = fullfile('/', 'projects', 'imgclass', 'data', 'flowers');
imds = imageDatastore(dataDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');
[trainData, valData] = splitEachLabel(imds, 0.8, 'randomized');

inputSize = [224 224 3];
numClasses = numel(categories(trainData.Labels));

net = [
    imageInputLayer(inputSize)
    convolution2dLayer(3, 16, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2, 'Stride', 2)
    fullyConnectedLayer(numClasses)
    softmaxLayer];

options = trainingOptions('adam', ...
    'InitialLearnRate', 0.001, ...
    'MiniBatchSize', 32, ...
    'MaxEpochs', 10, ...
    'ValidationData', valData, ...
    'Plots', 'training-progress');

trainedNet = trainnet(trainData, net, "crossentropy", options);

% Copyright 2026 The MathWorks, Inc.
