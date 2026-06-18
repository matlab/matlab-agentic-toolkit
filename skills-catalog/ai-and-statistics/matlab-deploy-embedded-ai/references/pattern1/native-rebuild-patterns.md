# Native dlnetwork Rebuild Patterns

Patterns for rebuilding imported networks as native `dlnetwork` objects, organized by
architecture type. The imported network is used only as a weight source.

## MLP (Feedforward Networks)

The simplest rebuild. Construct FC + activation stacks and transfer weights directly.

```matlab
%% Import for weight extraction
netImport = importNetworkFromPyTorch('model.pt2');

%% Build native network
layers = [
    featureInputLayer(inputSize, 'Name', 'input')
];
for k = 1:numHiddenLayers
    layers = [layers
        fullyConnectedLayer(hiddenSize, 'Name', sprintf('fc%d', k))
        reluLayer('Name', sprintf('relu%d', k))
    ];
end
layers = [layers
    fullyConnectedLayer(outputSize, 'Name', 'fc_out')
];
netNative = dlnetwork(layers);

%% Transfer weights
importLearn = netImport.Learnables;
for i = 1:height(netNative.Learnables)
    lyr = netNative.Learnables.Layer{i};
    prm = netNative.Learnables.Parameter{i};
    idx = find(contains(importLearn.Layer, lyr) & strcmp(importLearn.Parameter, prm));
    if ~isempty(idx)
        netNative.Learnables.Value{i} = importLearn.Value{idx(1)};
    end
end

%% Entry-point for codegen (network passed as argument)
% function out = predictDLNet(net, x)
%     arguments
%         net     dlnetwork
%         x       (1,:) single
%     end
%     dlX = dlarray(x, "CB");
%     dlY = predict(net, dlX);
%     out = extractdata(dlY);
% end
```

**dlarray format:** `'CB'` -- Channel (features) x Batch.

**Input types for codegen:**
```matlab
netType = coder.loadDeepLearningNetwork("trainedNet.mat");
inputType = coder.typeof(single(0), [1 inputSize]);
codegen -config cfg predictDLNet -args {netType, inputType} -report
```

### MLP Weight Transpose Note

When importing from ONNX, FC weights may need transposing:
```matlab
% ONNX MatMul stores [input, output]; MATLAB FC expects [output, input]
matlabW = onnxW';
```

Always verify by comparing `predict()` outputs after transfer.

---

## LSTM Networks

### Key Trick: OutputMode='last'

PyTorch LSTMs return `(output, (h_n, c_n))`. Selecting `h_n[-1]` generates a custom
`select` layer that blocks codegen. Avoid this entirely:

```matlab
% Use OutputMode='last' on the final LSTM layer
% This outputs only the last timestep -- no select layer needed
layers = [
    sequenceInputLayer(numFeatures, 'Name', 'input')
    lstmLayer(hiddenSize, 'OutputMode', 'sequence', 'Name', 'lstm1')  % full sequence
    lstmLayer(hiddenSize, 'OutputMode', 'last', 'Name', 'lstm2')     % last timestep only
    fullyConnectedLayer(headSize, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(outputSize, 'Name', 'fc2')
];
netNative = dlnetwork(layers);
```

For single-layer LSTMs that need only the final output:
```matlab
layers = [
    sequenceInputLayer(numFeatures, 'Name', 'input')
    lstmLayer(hiddenSize, 'OutputMode', 'last', 'Name', 'lstm')
    fullyConnectedLayer(outputSize, 'Name', 'fc')
];
```

### LSTM Weight Transfer

LSTM weights transfer directly -- both PyTorch and MATLAB use the same concatenated gate
layout (`[4*hiddenSize, inputSize]` for InputWeights):

```matlab
% Find parameter indices in import and native networks
srcIdx = findParam(netImport, 'lstm', 'InputWeights');
dstIdx = find(netNative.Learnables.Layer == "lstm1" & netNative.Learnables.Parameter == "InputWeights");
netNative.Learnables.Value{dstIdx} = netImport.Learnables.Value{srcIdx};

srcIdx = findParam(netImport, 'lstm', 'RecurrentWeights');
dstIdx = find(netNative.Learnables.Layer == "lstm1" & netNative.Learnables.Parameter == "RecurrentWeights");
netNative.Learnables.Value{dstIdx} = netImport.Learnables.Value{srcIdx};

srcIdx = findParam(netImport, 'lstm', 'Bias');
dstIdx = find(netNative.Learnables.Layer == "lstm1" & netNative.Learnables.Parameter == "Bias");
netNative.Learnables.Value{dstIdx} = netImport.Learnables.Value{srcIdx};
```

Helper function:
```matlab
function idx = findParam(net, layerSubstr, paramName)
    idx = find(contains(net.Learnables.Layer, layerSubstr) & ...
               strcmp(net.Learnables.Parameter, paramName), 1);
end
```

### LSTM Entry-Point and Formats

```matlab
function out = predictSeqDLNet(net, x)
    %predictSeqDLNet Run stateful sequence inference with a dlnetwork
    %
    % Input x is one time step: (1, numFeatures) single.

    arguments
        net     dlnetwork
        x       (1,:) single
    end

    dlX = dlarray(x, "TC");  % Time x Channels for sequence models
    dlY = predict(net, dlX);
    out = extractdata(dlY);
end
```

**dlarray format:** `'TC'` -- Time x Channel (features).

**Input types for codegen:**
```matlab
netType = coder.loadDeepLearningNetwork("lstm_net.mat");
inputType = coder.typeof(single(0), [1 numFeatures]);
codegen -config cfg predictSeqDLNet -args {netType, inputType} -report
```

---

## CNN Networks

CNNs typically generate custom layers for channel shuffle, channel split, and global mean
pooling operations. The rebuild replaces these with codegen-compatible equivalents.

### Rebuild Workflow

```matlab
%% Step 1: Import and expand
net = importNetworkFromPyTorch('model.pt2', PyTorchInputSizes=[1 3 224 224]);
net = expandLayers(net);

%% Step 2: Identify custom layers
layerNames = {net.Layers.Name};
viewLayers  = layerNames(contains(layerNames, 'view_view'));   % -> ChannelShuffle
chunkLayers = layerNames(contains(layerNames, 'chunk'));       % -> ChannelSplit
meanLayers  = layerNames(contains(layerNames, 'mean'));        % -> GAP + Flatten

%% Step 3: Replace on layerGraph
lgraph = layerGraph(net);
for i = 1:numel(viewLayers)
    lgraph = replaceLayer(lgraph, viewLayers{i}, ...
        ChannelShuffleLayer(2, viewLayers{i}));
end
for i = 1:numel(chunkLayers)
    lgraph = replaceLayer(lgraph, chunkLayers{i}, ...
        ChannelSplitLayer(chunkLayers{i}));
end

%% Step 4: Replace mean -> GAP + flatten (graph surgery)
for i = 1:numel(meanLayers)
    mn = meanLayers{i};
    % Find the downstream FC connection
    conns = lgraph.Connections;
    destIdx = find(strcmp(conns.Source, [mn '/out1']) | strcmp(conns.Source, mn));
    fcDest = conns.Destination{destIdx(1)};

    gapLayer = globalAveragePooling2dLayer('Name', mn);
    lgraph = replaceLayer(lgraph, mn, gapLayer);

    flatLayer = flattenLayer('Name', [mn '_flatten']);
    lgraph = addLayers(lgraph, flatLayer);
    lgraph = disconnectLayers(lgraph, mn, fcDest);
    lgraph = connectLayers(lgraph, mn, [mn '_flatten']);
    lgraph = connectLayers(lgraph, [mn '_flatten'], fcDest);
end

%% Step 5: Fix FC OperationDimension after GAP+flatten replacement
% The imported FC has OperationDimension set for PyTorch convention.
% After replacing mean with GAP+flatten, reset to MATLAB convention:
fcOld = lgraph.Layers(findLayerByName(lgraph, 'fc'));
fcNew = fullyConnectedLayer(fcOld.OutputSize, 'Name', fcOld.Name, ...
    'Weights', fcOld.Weights, 'Bias', fcOld.Bias);
lgraph = replaceLayer(lgraph, fcOld.Name, fcNew);

%% Step 6: Rebuild dlnetwork
netNative = dlnetwork(lgraph);
```

See `custom-layers-codegen.md` for `ChannelShuffleLayer` and `ChannelSplitLayer` implementations.

**dlarray format:** `'SSCB'` -- Spatial x Spatial x Channel x Batch.

**Input type:**
```matlab
inputType = coder.typeof(single(zeros(224, 224, 3, 1)), [224 224 3 1], false(1,4));
```

---

## Vision Transformer (ViT) Networks

ViTs generate 30+ custom layers and require the most complex rebuild.

### Architecture to Reconstruct

```
imageInputLayer [224x224x3]
  -> Conv2D (patch embedding: 16x16 stride 16, 3->embedDim)
  -> PatchFlattenLayer (custom, SSCB->CTB)
  -> AddPositionEmbeddingLayer (custom, learnable)
  -> 12x Transformer Block:
      -> layerNormalizationLayer
      -> selfAttentionLayer (numHeads heads)
      -> additionLayer (residual)
      -> layerNormalizationLayer
      -> FC (embedDim -> mlpDim)
      -> geluLayer
      -> FC (mlpDim -> embedDim)
      -> additionLayer (residual)
  -> layerNormalizationLayer (final)
  -> FC (embedDim -> numClasses)
```

### Weight Transfer for Transformers

**Patch embedding conv:** PyTorch [O,I,H,W] -> MATLAB [H,W,I,O]:
```matlab
convW = permute(pytorchConvW, [3, 4, 2, 1]);
```

**Attention QKV from ONNX:** Combined [inputDim, 3*embedDim] -> split:
```matlab
qW = combinedW(:, 1:embedDim);
kW = combinedW(:, embedDim+1:2*embedDim);
vW = combinedW(:, 2*embedDim+1:3*embedDim);
```

**Position embedding:** Typically [numTokens, embedDim] in PyTorch -> transpose to
[embedDim, numTokens] for MATLAB broadcast addition.

See `custom-layers-codegen.md` for `PatchFlattenLayer` and `AddPositionEmbeddingLayer`.

---

## dlarray Format Strings Summary

| Architecture | Format | Meaning |
|-------------|--------|---------|
| MLP | `'CB'` | Channel (features) x Batch |
| LSTM | `'CT'` | Channel (features) x Time (timesteps) |
| CNN | `'SSCB'` | Spatial x Spatial x Channel x Batch |


Copyright 2026 The MathWorks, Inc.
