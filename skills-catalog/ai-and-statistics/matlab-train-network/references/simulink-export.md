# Simulink Export

Export a trained network to Simulink. Replaces the legacy `gensim` function.

## Export Methods

### 1. ClassificationNeuralNetwork / RegressionNeuralNetwork Predict Blocks

For `ClassificationNeuralNetwork` and `RegressionNeuralNetwork` objects (from
`fitcnet`/`fitrnet`), use the dedicated predict blocks from the Statistics and
Machine Learning Toolbox library (`statsLibrary`).

```matlab
% Classification
mdl = fitcnet(tbl,responseName,LayerSizes=[20 10]);
add_block("statsLibrary/Classification/ClassificationNeuralNetwork Predict", ...
    "myModel/ClassifierPredict", ...
    TrainedLearner="mdl");

% Regression
mdl = fitrnet(tbl,responseName,LayerSizes=[20 10]);
add_block("statsLibrary/Regression/RegressionNeuralNetwork Predict", ...
    "myModel/RegressionPredict", ...
    TrainedLearner="mdl");
```

### 2. exportNetworkToSimulink (preferred for `dlnetwork`)

Use when the network is small and all layers are supported for export.
Generates a Simulink subsystem with individual layer blocks.

```matlab
exportNetworkToSimulink(net)
```

### 3. Predict Block

Use for larger networks or when the network contains layers not supported by
`exportNetworkToSimulink`. Add a **Predict** block from the `deeplib` library
and configure it to load the saved `dlnetwork`.

```matlab
save("myNet.mat","net");
add_block("deeplib/Predict","myModel/Predict", ...
    Network="Network from MAT-file", ...
    NetworkFilePath="myNet.mat");
```

## Legacy Pattern (DO NOT USE)

```matlab
% DON'T — legacy pattern
net = feedforwardnet(10);
net = train(net,X,T);
gensim(net)

% DO — modern pattern
layers = [...];
net = trainnet(X,T,layers,"mse",options);
exportNetworkToSimulink(net)
```

----

Copyright 2026 The MathWorks, Inc.

----
