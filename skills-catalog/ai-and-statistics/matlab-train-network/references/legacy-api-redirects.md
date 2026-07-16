# Legacy and Discouraged API Redirects — Code Examples

When a user asks for legacy or discouraged functionality, use the recommended
replacements instead. See the mapping table in SKILL.md for which APIs map to
which replacements. The examples below show before/after code for the most common
migrations: transfer learning, shallow neural networks (`patternnet`/`fitnet`),
and NARX time series.

## Common Legacy and Discouraged Patterns

### Transfer learning with discouraged layerGraph surgery

```matlab
% DON'T — discouraged pattern
net = squeezenet;
lgraph = layerGraph(net);
lgraph = replaceLayer(lgraph,"conv10",newConvLayer);
lgraph = replaceLayer(lgraph,"ClassificationLayer_predictions",newClassLayer);
trainedNet = trainNetwork(imdsTrain,lgraph,options);
[label,scores] = classify(trainedNet,imdsTest);

% DO — modern pattern
net = imagePretrainedNetwork("squeezenet",NumClasses=5);
net = trainnet(imdsTrain,net,"crossentropy",options);
classNames = categories(imdsTrain.Labels);
scores = minibatchpredict(net,imdsTest);
label = scores2label(scores,classNames);
```

### Legacy shallow nets classification

```matlab
% DON'T — legacy pattern
net = patternnet(20);
net = train(net,X,T);
Y = net(X);
classes = vec2ind(Y);

% DO — preferred (Statistics and Machine Learning Toolbox)
mdl = fitcnet(X,T,LayerSizes=20);
labels = predict(mdl,X);

% OR — Deep Learning Toolbox alternative
layers = [
    featureInputLayer(numFeatures)
    fullyConnectedLayer(20)
    reluLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer];
net = trainnet(X,T,layers,"crossentropy",options);
scores = minibatchpredict(net,X);
labels = scores2label(scores,classNames);
```

### Legacy NARX time series

```matlab
% DON'T — legacy pattern
net = narxnet(1:2,1:2,10);
[Xs,Xi,Ai,Ts] = preparets(net,X,{},T);
net = train(net,Xs,Ts,Xi,Ai);
net = closeloop(net);

% DO — preferred (System Identification Toolbox)
data = iddata(YTrain,XTrain,Ts);
sys = nlarx(data,[na nb nk],idSigmoidNetwork(hiddenSize));
futureInput = iddata([],XTest,Ts);
yF = forecast(sys,data,numSteps,futureInput);
Y = yF.OutputData';

% OR — Deep Learning Toolbox alternative (two-branch NARX with 1-D convolution)
% Uses maglev_dataset: current (exogenous input) → position (output)
[current,position] = maglev_dataset;
current = [current{:}]';
position = [position{:}]';

numSequenceDelays = 2;
numExogenousDelays = 2;
numFilters = 15;
numDelays = max(numSequenceDelays,numExogenousDelays);

% Inputs end at t-1, target ends at t (one-step-ahead). Each branch's left
% edge is trimmed by its own delay so conv1d outputs and target share length.
positionTrain = position(1+numDelays-numSequenceDelays:numTrain-1);
currentTrain = current(1+numDelays-numExogenousDelays:numTrain-1);
TTrain = position(1+numDelays:numTrain);

sequenceLayers = [
    sequenceInputLayer(1,Name="sequenceInput",MinLength=numSequenceDelays)
    convolution1dLayer(numSequenceDelays,numFilters,Name="conv1")];

exogenousLayers = [
    sequenceInputLayer(1,Name="exogenousInput",MinLength=numExogenousDelays)
    convolution1dLayer(numExogenousDelays,numFilters)
    concatenationLayer(1,2,Name="cat")
    tanhLayer
    fullyConnectedLayer(1)];

net = dlnetwork;
net = addLayers(net,sequenceLayers);
net = addLayers(net,exogenousLayers);
net = connectLayers(net,"conv1","cat/in2");

% Multi-input network requires a combined datastore.
% Each column vector is one full sequence; IterationDimension=2 treats it
% as a single observation.
ds = combine( ...
    arrayDatastore(positionTrain,IterationDimension=2), ...
    arrayDatastore(currentTrain,IterationDimension=2), ...
    arrayDatastore(TTrain,IterationDimension=2));

options = trainingOptions("lm",MaxIterations=500);
net = trainnet(ds,net,"mse",options);

% Closed-loop prediction: feed predictions back iteratively
Y = positionTest(1:numSequenceDelays,:);
for idx = 1:numSteps
    Y(end+1,:) = predict(net, ...
        Y(end-numSequenceDelays+1:end,:), ...
        currentTest(idx:idx+numExogenousDelays-1,:));
end
Y = Y(numSequenceDelays+1:end,:);
```


----

Copyright 2026 The MathWorks, Inc.

----
