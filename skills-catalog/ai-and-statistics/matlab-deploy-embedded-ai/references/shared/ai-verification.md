# AI Verification

Verify AI model behavior before system integration. This phase applies to all
Pattern 1 workflows (both native and import paths) after training or import.

## Prerequisites

Check for AI Verification Library (support package, NOT toolbox):

```matlab
pkgs = matlabshared.supportpkg.getInstalled;
hasAIVerif = false;
if ~isempty(pkgs)
    hasAIVerif = any(contains({pkgs.Name}, "AI Verification"));
end
```

If missing, direct user to Add-On Explorer. Do NOT install on their behalf.

## Converting Stats/ML Models for Verification

If the model was trained with `fitcnet` or `fitrnet`, convert for verification:

```matlab
dlNet = dlnetwork(mdl);  % Convert fitcnet/fitrnet to dlnetwork
```

## Out-of-Distribution (OOD) Detection -- ALWAYS RECOMMEND

**CRITICAL:** Use the official `networkDistributionDiscriminator` function.
Do NOT implement custom OOD detection.

### Create OOD Discriminator

```matlab
% For tabular / image data
discriminator = networkDistributionDiscriminator(net, XTrain, [], "hbos");

% With tuning
discriminator = networkDistributionDiscriminator(net, XTrain, [], "hbos", ...
    TruePositiveGoal=0.95, ...
    FalsePositiveGoal=0.05);

% For sequence models: convert cell array to dlarray first
dlXTrain = dlarray(cat(3, XTrain{:}), "TCB");
discriminator = networkDistributionDiscriminator(net, dlXTrain, [], "hbos");
```

### OOD Detection Methods

| Method | Name-Value | Best For |
|--------|-----------|----------|
| Baseline | `"baseline"` | Simple softmax-based |
| ODIN | `"odin"` | Temperature-scaled softmax |
| Energy | `"energy"` | General purpose, robust |
| **HBOS** | `"hbos"` | **Recommended default** -- histogram-based, works for classification and regression |

### Evaluate OOD

**CRITICAL:** Do NOT use `predict(discriminator, ...)`. Use dedicated functions:

```matlab
% Check if samples are in-distribution
tf = isInNetworkDistribution(discriminator, XTest);

% Get confidence scores
scores = distributionScores(discriminator, XTest);

% Summarize
numOOD = sum(~tf);
fprintf("OOD samples: %d / %d (%.1f%%)\n", numOOD, numel(tf), 100*numOOD/numel(tf));
```

### Deploy OOD to Simulink / Embedded

```matlab
% Save discriminator for deployment
save("oodDiscriminator.mat", "discriminator");

% In Simulink MATLAB Function block or codegen entry-point:
function [prediction, isOOD] = predictWithOOD(inputData)
    persistent net disc
    if isempty(net)
        net = coder.loadDeepLearningNetwork("trainedNet.mat");
        disc = coder.loadNetworkDistributionDiscriminator("oodDiscriminator.mat");
    end
    prediction = predict(net, inputData);
    tf = isInNetworkDistribution(disc, inputData);
    isOOD = ~tf;
end
```

## Formal Verification (if AI Verification Library Available)

```matlab
% Robustness verification to Linf perturbations
epsilon = 0.01;
results = verifyNetworkRobustness(net, XTest(1:100,:), YTest(1:100), ...
    PerturbationRadius=epsilon);

% Analyze results: "verified", "counterexample", or "unknown"
numVerified = sum(results.VerificationStatus == "verified");
fprintf("Verified: %d / %d\n", numVerified, height(results));
```

Notes:
- Computationally expensive; may not scale to large networks
- Check documentation for supported layer types
- Results depend on network architecture and perturbation radius

## Empirical Verification (No Additional Toolbox Required)

### Adversarial Robustness Testing

Apply small perturbations (FGSM-style) and check prediction stability:

```matlab
epsilon = 0.01;
numChanged = 0;
for i = 1:size(XTest, 1)
    x = dlarray(single(XTest(i,:)), 'CB');
    [y, grad] = dlfeval(@(x) predict(net, x), x);
    xPerturbed = x + epsilon * sign(grad);
    yPerturbed = predict(net, xPerturbed);
    if argmax(extractdata(y)) ~= argmax(extractdata(yPerturbed))
        numChanged = numChanged + 1;
    end
end
fprintf("Predictions changed under perturbation: %d / %d\n", numChanged, size(XTest,1));
```

### Distribution Shift Analysis

Compare training vs. test feature distributions using histograms or
statistical tests to identify potential deployment-time distribution drift.

## Re-Verify After Compression

**CRITICAL:** After any compression (Phase 5 — Model Compression), re-run OOD detection on the
compressed model to ensure the discriminator still works correctly. Compression
can shift internal activations, affecting OOD boundaries.


Copyright 2026 The MathWorks, Inc.
