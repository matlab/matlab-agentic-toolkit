# Multi-Output Training

End-to-end recipe for training and evaluating a multi-output `dlnetwork` with
`trainnet`. Three things must align: `net.OutputNames` order, loss function
argument order, and combined datastore column order.

## Step-by-Step Recipe

### 1. Build the dlnetwork

```matlab
numChannels = 6;
numClasses = 4;
net = dlnetwork;

layers = [
    sequenceInputLayer(numChannels)
    lstmLayer(128,OutputMode="last",Name="lstm")];
net = addLayers(net,layers);

head1 = [
    fullyConnectedLayer(numClasses,Name="fc1")
    softmaxLayer(Name="softmax")];
net = addLayers(net,head1);
net = connectLayers(net,"lstm","fc1");

head2 = fullyConnectedLayer(1,Name="fc2");
net = addLayers(net,head2);
net = connectLayers(net,"lstm","fc2");
```

### 2. Check net.OutputNames — this is the source of truth

```matlab
net.OutputNames
% ans = {'softmax', 'fc2'}
```

The order here determines everything below.

### 3. Build the combined datastore with targets in OutputNames order

```matlab
dsX = arrayDatastore(XTrain,IterationDimension=3,OutputType="cell");
dsT1 = arrayDatastore(T1Train);
dsT2 = arrayDatastore(T2Train);

% Columns: input, target1, target2 — matching OutputNames order
dsTrain = combine(dsX,dsT1,dsT2);
```

### 4. Write the loss function to match OutputNames order

The loss function receives: outputs first (in `OutputNames` order), then
targets (in the same order).

```matlab
% OutputNames = {'softmax', 'fc2'}
% So: lossFcn(Y1,Y2,T1,T2)
lossFcn = @(Y1,Y2,T1,T2) ...
    crossentropy(Y1,T1) + 0.01*mse(Y2,T2);
```

### 5. Train

```matlab
% Metrics must be a cell array, not a matrix — use { } not [ ]
metrics = {
    accuracyMetric(NetworkOutput="softmax")
    rmseMetric(NetworkOutput="fc2")};

options = trainingOptions("adam", ...
    MaxEpochs=15, ...
    MiniBatchSize=128, ...
    Shuffle="every-epoch", ...
    Metrics=metrics, ...
    Plots="training-progress");

net = trainnet(dsTrain,net,lossFcn,options);
```
The `NetworkOutput` values in metric objects must match `net.OutputNames`
exactly.

### 6. Evaluate with testnet — same datastore structure

`testnet` for multi-output networks requires a datastore that provides all
targets (one per output). You cannot pass `XTest, TTest` when there are
multiple outputs.

```matlab
dsX = arrayDatastore(XTest,IterationDimension=3,OutputType="cell");
dsT1 = arrayDatastore(T1Test);
dsT2 = arrayDatastore(T2Test);
dsTest = combine(dsX,dsT1,dsT2);

results = testnet(net,dsTest,metrics);
% results = [accuracy, rmse] — one value per metric, in order
```

## Common Pitfalls

| Symptom | Issue | Fix |
|---------|-------|-----|
| Dimension mismatch during training | Datastore columns are in wrong order | Reorder to match `net.OutputNames` |
| Training runs but accuracy is poor | Loss function argument positions are swapped | Reorder to match `net.OutputNames` |
| `testnet` errors on multi-output | Passing `XTest, TTest` arrays | Use a combined datastore |

----

Copyright 2026 The MathWorks, Inc.

----
