# Projection (Layer Dimension Reduction)

Projection reduces the dimensionality of supported layers using principal component
analysis of neuron activations. For the up-to-date list of supported layers and any
release-specific limitations (such as restrictions on layers that share learnable
parameters via weight tying), see the
[`compressNetworkUsingProjection` reference page](https://www.mathworks.com/help/deeplearning/ref/compressnetworkusingprojection.html).

To inspect a specific network's compressibility visually, open it in **Deep Network
Designer** (`deepNetworkDesigner(net)`) and use the compression analysis pane — it
flags which layers are eligible for projection, pruning, and quantization without
requiring you to reason about the support list yourself.

```matlab
% Single-call projection: pass calibration data directly. Internally the
% function runs the PCA step and applies projection in one call.
% Always capture the second output (info struct) — it reports what
% actually happened, which is essential for verifying that the requested
% reduction was applied to the layers you expected.
[projectedNet, info] = compressNetworkUsingProjection(net, XTrain);
fprintf("Achieved learnables reduction: %.1f%%\n", info.LearnablesReduction * 100);
fprintf("Explained variance: %.3f\n", info.ExplainedVariance);
fprintf("Projected layers: %s\n", strjoin(info.LayerNames, ", "));

% When to call neuronPCA separately: only when you plan to reuse the PCA
% across multiple projection goals (e.g., a trade-off sweep), since the
% PCA step can be expensive. For a single goal, the one-call form above
% is the recommended path.

% With UnpackProjectedLayers=false (the default), every compressed layer in
% the result is wrapped in a ProjectedLayer object — regardless of whether
% the original was an FC, conv, LSTM, or GRU layer. The actual unpacked
% structure (multiple FC/conv layers for FC/conv inputs, or
% lstmProjectedLayer / gruProjectedLayer for recurrent inputs) only
% appears after unpacking — see "Preparing Projected Networks for Code
% Generation" below.

% Fine-tune after projection
options = trainingOptions("adam", ...
    MaxEpochs=20, ...
    MiniBatchSize=32, ...
    InitialLearnRate=1e-4, ...
    Verbose=false);

projectedNet = trainnet(XTrain, YTrain, projectedNet, "crossentropy", options);
```

**Layer types in the output network:**

| `UnpackProjectedLayers` | What `compressNetworkUsingProjection` returns |
|---|---|
| `false` (default) | Every compressed layer is a `ProjectedLayer`, regardless of the original layer type. The `ProjectedLayer` wraps the equivalent sub-network internally. |
| `true` | Each `ProjectedLayer` is replaced by its unpacked equivalent: two or three `fullyConnectedLayer` objects (from an FC original), two or three `convolution1dLayer`/`convolution2dLayer` objects (from conv originals), a single `lstmProjectedLayer` (from an LSTM), or a single `gruProjectedLayer` (from a GRU). |

The same unpacking can also be applied after the fact via
`unpackProjectedLayers(projectedNet)`. Use `analyzeNetwork(projectedNet, Plots='none')`
to inspect layer-wise compression ratios when the network contains `ProjectedLayer`
objects. Codegen support depends on the unpacked layer type:

- `lstmProjectedLayer` and `gruProjectedLayer` are supported for generic
  C/C++ code generation via `coder.loadDeepLearningNetwork` (no MKL-DNN /
  ARM Compute Library acceleration; in R2026a, `HasStateInputs` /
  `HasStateOutputs` modes are also supported on the generic path).
- A `ProjectedLayer` wrapper is supported for codegen when its contents
  are stateless — that is, conv/FC layers, or LSTM/GRU layers in
  stateful-I/O mode. A wrapped LSTM/GRU with stored state is not
  codegen-compatible until unpacked.

`exportNetworkToSimulink` accepts projected networks directly in R2026a.
For the direct MATLAB Coder path, when in doubt, calling
`unpackProjectedLayers` before `coder.loadDeepLearningNetwork` removes
the wrapper and produces the most codegen-friendly form (see "Preparing
Projected Networks for Code Generation" below).

## Projection for Sequence Models (LSTM/GRU)

Since R2026a, `compressNetworkUsingProjection` accepts the same input data
types as `trainnet` (including a **cell array of sequences**), and exposes
the sequence-batching name-value arguments — `MiniBatchSize`,
`SequenceLength`, `SequencePaddingDirection`, `SequencePaddingValue`,
`InputDataFormats` — directly. The older `minibatchqueue` wrapper is no
longer needed.

```matlab
% Calibration data: MUST be representative of training data (NOT random).
% Pass training or validation data directly. For large datasets (>200
% observations), subset to speed up the PCA step.
calibData = XTrain;

% Single-call projection. MiniBatchSize=1 avoids padding across sequences
% (padding is documented to hurt PCA quality); use SequenceLength="shortest"
% instead if larger mini-batches are required. Omit LearnablesReductionGoal
% to let the function use its default (ExplainedVarianceGoal=0.95).
[projNet, info] = compressNetworkUsingProjection(baseNet, calibData, ...
    MiniBatchSize=1);

fprintf('Actual reduction: %.1f%%\n', info.LearnablesReduction * 100);
fprintf('Compressed layers: %s\n', strjoin(info.LayerNames, ', '));
```

Projection requires the input data to have a batch (`"B"`) dimension. If the
network uses an `inputLayer` without `"B"` in its format, use a non-generic input
layer (e.g., `featureInputLayer`, `sequenceInputLayer`) or specify a format that
includes `"B"` during import. For the full list of name-value arguments see the
[`compressNetworkUsingProjection` reference page](https://www.mathworks.com/help/deeplearning/ref/compressnetworkusingprojection.html).

**Important:** Accuracy can degrade quickly with structural compression, even at
low compression levels. Retraining after projection is highly recommended when
possible.

## Projection Limitations

- **Choose `LearnablesReductionGoal` empirically, not by rule of thumb.** The
  achievable reduction without retraining is highly model- and
  data-dependent. If the user has no specific target, prefer the default
  behavior (driven by `ExplainedVarianceGoal=0.95`) or run a trade-off sweep
  across several goals and pick the one that meets the accuracy budget.
- **Data distribution matters.** The calibration set passed to
  `compressNetworkUsingProjection` must reflect the true deployment
  distribution; results inferred from unrepresentative data do not
  transfer.
- **No synthetic fine-tuning shortcuts.** If the real data distribution is narrow, generating
  synthetic N(0,1) data for fine-tuning does not help -- it introduces out-of-distribution noise.
- **Test on real data.** Projection accuracy must be validated on the actual expected input
  distribution, not random data.

## Preparing Projected Networks for Code Generation

Codegen support for projected networks depends on the layer:

- `lstmProjectedLayer` and `gruProjectedLayer` (the unpacked recurrent
  forms) are supported for generic C/C++ codegen via
  `coder.loadDeepLearningNetwork`. No third-party libraries (MKL-DNN, ARM
  Compute Library) are used on this path. R2026a adds support for
  `HasStateInputs` / `HasStateOutputs` modes.
- A `ProjectedLayer` wrapper is supported for codegen only when its
  contents are stateless — conv/FC, or LSTM/GRU configured with state
  inputs/outputs (`HasStateInputs=true`, `HasStateOutputs=true`) instead
  of stored state.
- A `ProjectedLayer` wrapping a stateful LSTM/GRU is **not**
  codegen-compatible. Unpack it first.

When in doubt, unpack before saving for `coder.loadDeepLearningNetwork`:

```matlab
% Unpack projected layers — produces lstmProjectedLayer / gruProjectedLayer
% directly (no ProjectedLayer wrapper) plus FC/conv expansions.
unpackedNet = unpackProjectedLayers(projectedNet);
save("deployableNet.mat", "unpackedNet");

% Alternative: set UnpackProjectedLayers=true during projection
[projectedNet, info] = compressNetworkUsingProjection(net, calibData, ...
    UnpackProjectedLayers=true);
```


Copyright 2026 The MathWorks, Inc.
