% trainModelRelativePaths.m — Script with relative paths that need resolution
% Located at: /projects/mywork/trainModelRelativePaths.m

data = load('data/train.mat');
XTrain = data.XTrain;
YTrain = data.YTrain;

valData = load('../shared/validation.mat');
XVal = valData.XVal;
YVal = valData.YVal;

net = [
    featureInputLayer(size(XTrain, 2))
    fullyConnectedLayer(64)
    reluLayer
    fullyConnectedLayer(10)
    softmaxLayer];

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 0.01, ...
    'MaxEpochs', 20, ...
    'MiniBatchSize', 64, ...
    'ValidationData', {XVal, YVal}, ...
    'ValidationFrequency', 50);

trainedNet = trainnet(XTrain, YTrain, net, "crossentropy", options);

% Copyright 2026 The MathWorks, Inc.
