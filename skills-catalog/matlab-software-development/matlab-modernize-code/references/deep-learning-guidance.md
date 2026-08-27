# Deep Learning Toolbox Modernization

## Quick Reference: Function Mappings

| Topic | Recommendation | Since | Status |
|---|---|---|---|
| `trainNetwork` | `trainnet` | R2024a | Not Recommended |
| `LayerGraph` / `SeriesNetwork` / `DAGNetwork` | `dlnetwork` | R2024a | Not Recommended |
| `classify` | `minibatchpredict` + `scores2label` | R2024a | Not Recommended |
| `activations` | `minibatchpredict` (`Outputs=`) | R2024a | Not Recommended |

---

## trainNetwork → trainnet

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
layers = [
    imageInputLayer([28 28 1])
    convolution2dLayer(3,8,'Padding','same')
    reluLayer
    fullyConnectedLayer(10)
    softmaxLayer
    classificationLayer];

net = trainNetwork(XTrain, YTrain, layers, options);
```

**Modern Pattern (Use This):**
```matlab
layers = [
    imageInputLayer([28 28 1])
    convolution2dLayer(3, 8, Padding="same")
    reluLayer
    fullyConnectedLayer(10)
    softmaxLayer];

net = trainnet(XTrain, YTrain, layers, "crossentropy", options);
```

**Why Modern is Better:**
- `trainnet` supports `dlnetwork` objects with broader architecture support
- Enables easier loss function specification (built-in or custom)
- Returns unified `dlnetwork` data type
- Typically faster than `trainNetwork`
- Supports networks imported from external platforms (PyTorch, TensorFlow)

**Key Difference:** Specify loss function explicitly instead of using output layers like `classificationLayer`.

---

## LayerGraph, SeriesNetwork, DAGNetwork → dlnetwork

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
lgraph = layerGraph(layers);
lgraph = addLayers(lgraph, newLayers);
lgraph = connectLayers(lgraph, 'layer1', 'layer2');
net = trainNetwork(data, lgraph, options);
```

**Modern Pattern (Use This):**
```matlab
net = dlnetwork(layers);
% Or for complex architectures:
net = dlnetwork;
net = addLayers(net, layers1);
net = addLayers(net, layers2);
net = connectLayers(net, 'layer1', 'layer2');
net = initialize(net);

% Train with trainnet
net = trainnet(XTrain, YTrain, net, "crossentropy", options);
```

**Migration from existing networks:**
```matlab
% Convert DAGNetwork or SeriesNetwork to dlnetwork
dlnet = dag2dlnetwork(trainedNet);
```

**Why Modern is Better:**
- Unified data type for building, prediction, training, visualization, compression, and verification
- Supports custom training loops
- Better interoperability with external frameworks
- Required for modern training functions

---

## classify → minibatchpredict + scores2label

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
YPred = classify(net, XTest);
```

**Modern Pattern (Use This):**
```matlab
scores = minibatchpredict(net, XTest);
YPred = scores2label(scores, classNames);
```

**For probability scores:**
```matlab
scores = minibatchpredict(net, XTest);
[YPred, probs] = scores2label(scores, classNames);
```

---

## activations → minibatchpredict with Outputs

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
act = activations(net, X, 'conv1');
```

**Modern Pattern (Use This):**
```matlab
act = minibatchpredict(net, X, Outputs='conv1');
```

**Multiple layer outputs:**
```matlab
[act1, act2] = minibatchpredict(net, X, Outputs={'conv1', 'fc1'});
```

----

Copyright 2026 The MathWorks, Inc.

----
