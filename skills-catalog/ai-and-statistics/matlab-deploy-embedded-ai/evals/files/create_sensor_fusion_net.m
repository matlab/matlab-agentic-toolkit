% Create a simple sensor fusion dlnetwork (4 inputs, 2 outputs)
% for use in the simulink-integration-dlnetwork eval.
% Copyright 2026 The MathWorks, Inc.

layers = [
    featureInputLayer(4, Name="input")
    fullyConnectedLayer(16, Name="fc1")
    reluLayer(Name="relu1")
    fullyConnectedLayer(2, Name="fc2")
];

net = dlnetwork(layers);
