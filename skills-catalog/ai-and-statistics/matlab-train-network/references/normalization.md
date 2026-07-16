# Normalization

Normalize inputs and targets per channel before training. Compute statistics
from training data only — never recompute on validation or test data.

## Classification Workflow

Set `Normalization` on the input layer. Statistics are computed per channel
from training data automatically.

```matlab
layers = [
    sequenceInputLayer(numChannels,Normalization="zscore")
    lstmLayer(100,OutputMode="last")
    fullyConnectedLayer(numClasses)
    softmaxLayer];

net = trainnet(XTrain,TTrain,layers,"crossentropy",options);
```

## Regression Workflow (since R2026a)

- **Inputs:** set the `Normalization` property on the input layer.
- **Targets:** append an `inverseNormalizationLayer` as the last layer, then
  set `NormalizeTargets=true` in `trainingOptions` so `trainnet` normalizes the
  targets during training and the `inverseNormalizationLayer` denormalizes
  predictions automatically at inference.

```matlab
layers = [
    sequenceInputLayer(numChannels,Normalization="zscore")
    lstmLayer(100,OutputMode="last")
    fullyConnectedLayer(numResponses)
    inverseNormalizationLayer];

options = trainingOptions("adam",MaxEpochs=50,NormalizeTargets=true);
net = trainnet(XTrain,TTrain,layers,"mse",options);
rmse = testnet(net,XTest,TTest,"rmse");
```

## Regression Workflow (before R2026a)

Normalize inputs and targets manually per channel. Denormalize predictions
at inference using training statistics.

```matlab
% Per-channel stats from training data only
muX = mean(XTrain,1);  sigmaX = std(XTrain,0,1);
muT = mean(TTrain,1);  sigmaT = std(TTrain,0,1);

XTrainNorm = (XTrain - muX) ./ sigmaX;
TTrainNorm = (TTrain - muT) ./ sigmaT;
XTestNorm = (XTest - muX) ./ sigmaX;

layers = [
    sequenceInputLayer(numChannels)
    lstmLayer(100,OutputMode="last")
    fullyConnectedLayer(numResponses)];

options = trainingOptions("adam",MaxEpochs=50);
net = trainnet(XTrainNorm,TTrainNorm,layers,"mse",options);

% Denormalize predictions
Y = minibatchpredict(net,XTestNorm) .* sigmaT + muT;
```

----

Copyright 2026 The MathWorks, Inc.

----
