# MATLAB-Native Training

Detailed training patterns for Embedded AI Pattern 1 (lean hardware, <500KB models).

## Critical Rules

- **NEVER** use `trainNetwork`, `trainnetwork`, or `train` for deep learning
- **NEVER** produce `DAGNetwork`, `SeriesNetwork`, or `network` objects
- **ALWAYS** use `trainnet` for deep learning (produces `dlnetwork`)
- **ALWAYS** use `fitcnet` / `fitrnet` for MLPs (Stats/ML Toolbox)
- **ALWAYS** create `.m` scripts for training steps; execute via `run_matlab_file`
- **ALWAYS** load the trained model in Deep Network Designer after training completes:
  ```matlab
  deepNetworkDesigner(net)
  ```
  Announce: "The trained model is now open in Deep Network Designer for inspection.
  Let me know when you're ready to proceed."

## Stats/ML Toolbox: fitcnet (Classification MLP)

Requires: Statistics and Machine Learning Toolbox

```matlab
% Basic classification MLP
mdl = fitcnet(XTrain, YTrain, ...
    "LayerSizes", [64 32], ...
    "Activations", "relu");

% With validation and early stopping
mdl = fitcnet(XTrain, YTrain, ...
    "LayerSizes", [128 64 32], ...
    "Activations", "relu", ...
    "ValidationData", {XVal, YVal}, ...
    "ValidationPatience", 5, ...
    "Standardize", true, ...
    "Lambda", 1e-4);

% Evaluate
YPred = predict(mdl, XTest);
accuracy = mean(YPred == YTest);
confMat = confusionmat(YTest, YPred);
```

### Key Parameters for fitcnet

| Parameter           | Description                              | Typical Values        |
|---------------------|------------------------------------------|-----------------------|
| LayerSizes          | Hidden layer widths                      | [32], [64 32], [128 64 32] |
| Activations         | Activation function                      | "relu", "tanh", "sigmoid" |
| Lambda              | L2 regularization                        | 1e-4 to 1e-2         |
| Standardize         | Auto-normalize inputs                    | true (recommended)    |
| ValidationData      | Validation set for early stopping        | {XVal, YVal}          |
| ValidationPatience  | Epochs without improvement before stop   | 5 to 10              |
| IterationLimit      | Max training iterations                  | 1000 (default)        |

## Stats/ML Toolbox: fitrnet (Regression MLP)

Requires: Statistics and Machine Learning Toolbox

```matlab
% Basic regression MLP
mdl = fitrnet(XTrain, YTrain, ...
    "LayerSizes", [64 32], ...
    "Activations", "relu");

% With validation
mdl = fitrnet(XTrain, YTrain, ...
    "LayerSizes", [128 64 32], ...
    "Activations", "relu", ...
    "ValidationData", {XVal, YVal}, ...
    "ValidationPatience", 5, ...
    "Standardize", true);

% Evaluate
YPred = predict(mdl, XTest);
rmseVal = rmse(YPred, YTest);
maeVal  = mean(abs(YPred - YTest));
r2Val   = 1 - sum((YTest - YPred).^2) / sum((YTest - mean(YTest)).^2);
```

## Deep Learning Toolbox: trainnet (DNN / LSTM / CNN)

Requires: Deep Learning Toolbox

### Fully Connected Network (Tabular Data)

```matlab
layers = [
    featureInputLayer(numFeatures)
    fullyConnectedLayer(64)
    reluLayer
    dropoutLayer(0.2)
    fullyConnectedLayer(32)
    reluLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer
];

net = dlnetwork(layers);

options = trainingOptions("adam", ...
    MaxEpochs=100, ...
    MiniBatchSize=32, ...
    InitialLearnRate=1e-3, ...
    ValidationData={XVal, YVal}, ...
    ValidationFrequency=30, ...
    ValidationPatience=5, ...
    Plots="training-progress", ...
    Verbose=false);

% Classification
net = trainnet(XTrain, YTrain, net, "crossentropy", options);

% Regression (change loss and remove softmax)
net = trainnet(XTrain, YTrain, net, "mse", options);
```

### Sequence Data Format for trainnet

> **CRITICAL:** trainnet expects sequence data as **[T x C]** matrices (time-steps x channels), **NOT [C x T]**. For variable-length sequences, use an N-by-1 cell array where each cell contains a [T x C] single matrix.

```matlab
% Each cell: [T x numFeatures] single (time-steps by channels)
% XTrain{1} is e.g. [200 x 3] single — 200 time steps, 3 features
% YTrain{1} is e.g. [200 x 1] single — 200 time steps, 1 response (seq-to-seq)
% Or YTrain{1} is [1 x 1] categorical — single label (seq-to-one)

% Wrong: [C x T] will produce "Invalid size of channel dimension" error
```

### LSTM Network (Time-Series / Sequence)

```matlab
numFeatures = 3;    % Input features per time step
numHidden   = 64;   % LSTM hidden units
numClasses  = 5;    % Output classes

layers = [
    sequenceInputLayer(numFeatures)
    lstmLayer(numHidden, OutputMode="last")
    dropoutLayer(0.3)
    fullyConnectedLayer(numClasses)
    softmaxLayer
];

net = dlnetwork(layers);

options = trainingOptions("adam", ...
    MaxEpochs=50, ...
    MiniBatchSize=16, ...
    InitialLearnRate=1e-3, ...
    GradientThreshold=1, ...
    ValidationData={XVal, YVal}, ...
    ValidationFrequency=20, ...
    Shuffle="every-epoch", ...
    Plots="training-progress", ...
    Verbose=false);

% XTrain: cell array, each cell [T x numFeatures] single
% YTrain: cell array, each cell [T x numResponses] single (seq-to-seq) or categorical (seq-to-one)
net = trainnet(XTrain, YTrain, net, "crossentropy", options);
```

### GRU Network (Lighter Alternative to LSTM)

```matlab
layers = [
    sequenceInputLayer(numFeatures)
    gruLayer(numHidden, OutputMode="last")
    fullyConnectedLayer(numResponses)
];

net = dlnetwork(layers);

options = trainingOptions("adam", ...
    MaxEpochs=50, ...
    MiniBatchSize=32, ...
    InitialLearnRate=1e-3, ...
    GradientThreshold=1, ...
    Plots="training-progress", ...
    Verbose=false);

net = trainnet(XTrain, YTrain, net, "mse", options);
```

### 1D-CNN (Signal Classification)

```matlab
filterSize  = 5;
numFilters  = 16;
numClasses  = 4;

layers = [
    sequenceInputLayer(numFeatures)
    convolution1dLayer(filterSize, numFilters, Padding="same")
    batchNormalizationLayer
    reluLayer
    convolution1dLayer(filterSize, 2*numFilters, Padding="same")
    batchNormalizationLayer
    reluLayer
    globalAveragePooling1dLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer
];

net = dlnetwork(layers);

options = trainingOptions("adam", ...
    MaxEpochs=30, ...
    MiniBatchSize=32, ...
    Plots="training-progress", ...
    Verbose=false);

net = trainnet(XTrain, YTrain, net, "crossentropy", options);
```

### Autoencoder (Anomaly Detection)

```matlab
encoderLayers = [
    featureInputLayer(numFeatures)
    fullyConnectedLayer(32)
    reluLayer
    fullyConnectedLayer(8)    % Bottleneck
    reluLayer
];

decoderLayers = [
    fullyConnectedLayer(32)
    reluLayer
    fullyConnectedLayer(numFeatures)
];

layers = [encoderLayers; decoderLayers];
net = dlnetwork(layers);

% Train to reconstruct input (target = input)
options = trainingOptions("adam", ...
    MaxEpochs=100, ...
    MiniBatchSize=64, ...
    Plots="training-progress", ...
    Verbose=false);

net = trainnet(XTrain, XTrain, net, "mse", options);

% Anomaly detection: high reconstruction error = anomaly
XRecon = minibatchpredict(net, XTest);
reconError = mean((XTest - XRecon).^2, 2);
threshold = prctile(reconError, 95);
isAnomaly = reconError > threshold;
```

## Loss Functions for trainnet

| Loss Function    | Use Case                     |
|------------------|------------------------------|
| "crossentropy"   | Multi-class classification   |
| "binary-crossentropy" | Binary classification   |
| "mse"            | Regression                   |
| "mae"            | Regression (robust to outliers) |
| "huber"          | Regression (balanced)        |

## Training Options Quick Reference

| Parameter            | Classification        | Regression            | Sequence              |
|----------------------|-----------------------|-----------------------|-----------------------|
| Solver               | "adam"                | "adam"                | "adam"                |
| MaxEpochs            | 50-200                | 50-200                | 30-100                |
| MiniBatchSize        | 32-128                | 32-128                | 16-64                 |
| InitialLearnRate     | 1e-3                  | 1e-3                  | 1e-3                  |
| GradientThreshold    | Inf                   | Inf                   | 1 (important for RNNs)|
| ValidationPatience   | 5-10                  | 5-10                  | 5-10                  |

## Solver Selection

Different solvers are available via `trainingOptions`. Choose based on your problem:

| Solver    | Name-Value   | Best For                        | Notes                              |
|-----------|--------------|---------------------------------|------------------------------------|
| Adam      | `"adam"`     | General purpose, embedded AI    | Recommended default for most cases |
| SGDM      | `"sgdm"`    | Large datasets, precise LR control | Requires learning rate scheduling |
| RMSProp   | `"rmsprop"` | Recurrent networks              | Good for non-stationary objectives |
| L-BFGS    | `"lbfgs"`   | Small datasets, full-batch      | Second-order method, no mini-batching |

For embedded AI workflows, **Adam is typically the preferred solver**. It converges
reliably across a wide range of architectures and requires minimal tuning. Use SGDM
when you need precise learning rate control. Use L-BFGS for small datasets where
full-batch training is feasible.

## Key Hyperparameters for Embedded AI

| Parameter                | Name-Value Example                          | Purpose                              | Typical Range            |
|--------------------------|---------------------------------------------|--------------------------------------|--------------------------|
| `LearnRateSchedule`     | `LearnRateSchedule="piecewise"`             | Learning rate decay policy           | `"none"` or `"piecewise"` |
| `LearnRateDropFactor`   | `LearnRateDropFactor=0.1`                   | Factor to multiply LR at drop epochs | 0.1 to 0.5              |
| `LearnRateDropPeriod`   | `LearnRateDropPeriod=10`                    | Epochs between LR drops              | 5 to 50                 |
| `L2Regularization`      | `L2Regularization=1e-4`                     | Weight decay                         | 1e-5 to 1e-2            |
| `ValidationFrequency`   | `ValidationFrequency=30`                    | Iterations between validation checks | 10 to 50                |
| `ValidationPatience`    | `ValidationPatience=5`                      | Stop after N checks without improvement | 3 to 10             |
| `OutputNetwork`         | `OutputNetwork="best-validation"`           | Which network state to return        | `"last-iteration"` or `"best-validation"` |
| `GradientThreshold`     | `GradientThreshold=1`                       | Clip gradients exceeding threshold   | 1 to 10 (critical for RNNs) |
| `GradientThresholdMethod` | `GradientThresholdMethod="l2norm"`        | How to clip gradients                | `"l2norm"`, `"global-l2norm"`, `"absolute-value"` |
| `MiniBatchSize`         | `MiniBatchSize=32`                          | Samples per gradient step            | 16 to 128               |
| `SequenceLength`        | `SequenceLength="longest"`                  | How to handle variable-length sequences | `"longest"` or `"shortest"` only -- pre-pad/truncate in data prep instead of using integers |

**Key recommendations for embedded AI:**
- Use `OutputNetwork="best-validation"` to return the model with best validation
  performance, not the last training iteration
- For LSTM/GRU networks, always set `GradientThreshold=1` to prevent exploding gradients
- Start with `MiniBatchSize=32` and adjust based on memory and convergence

## Model Size Awareness for Lean Hardware

For Pattern 1, target model size < 500 KB. After training, check:

```matlab
% Check model size
info = whos("net");
fprintf("Model size: %.1f KB\n", info.bytes / 1024);

% Or save and check file size
save("tempModel.mat", "net");
d = dir("tempModel.mat");
fprintf("Saved model size: %.1f KB\n", d.bytes / 1024);
delete("tempModel.mat");
```

If the model exceeds 500 KB, consider:
1. Reducing layer widths or number of layers
2. Using GRU instead of LSTM (fewer parameters)
3. Applying model compression (pruning / quantization)


Copyright 2026 The MathWorks, Inc.
