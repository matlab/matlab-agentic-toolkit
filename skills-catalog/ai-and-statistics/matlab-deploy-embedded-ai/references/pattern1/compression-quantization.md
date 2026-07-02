# Quantization (Float32 to Int8)

## Why Quantize?

Quantization reduces model size (4x for float32 → int8). On ARM Cortex-M targets with
the Embedded Coder Support Package for ARM Cortex-M Processors, INT8 quantized models
can use CMSIS-NN kernels for **`convolution2dLayer` and `fullyConnectedLayer` only**
(~2.8–3x speedup). LSTM, GRU, and BiLSTM layers in R2026a have **no INT8 CMSIS-NN
kernel** — they generate as plain fixed-point C when quantized, which can be slower
than the float32 + CMSIS-DSP `mw_arm_mat_mult_f32` path for recurrent layers. Choose
quantization based on the goal collected via [`compression-decision.md`](compression-decision.md).

**Two consumers of quantization data (do not confuse):**

| | Simulink path | MATLAB Coder CMSIS-NN path |
|---|---|---|
| Calls `quantize()`? | **Yes** — produces quantized dlnetwork for `exportNetworkToSimulink` | **No** — only `calibrate()`, calibration data passed to code generator |
| Requires Simulink? | Yes | No |
| Code gen mechanism | `slbuild` with CRL "ARM Cortex-M" | `codegen` with `coder.DeepLearningConfig('cmsis-nn')` |

See `codegen-embedded.md` for full CMSIS-NN deployment details.

## Checking dlquantizer Layer Support

Do not maintain a layer-by-layer support list in code or in this skill — it goes
stale across releases. Two ways to check whether a specific layer is supported by
`dlquantizer` in the user's installed release:

1. **Doc:** [Supported Layers for Quantization](https://www.mathworks.com/help/deeplearning/ug/supported-layers-for-quantization.html) — authoritative, release-versioned.
2. **Visual tool:** open the network in **Deep Network Designer**
   (`deepNetworkDesigner(net)`) and use the compression analysis pane. It flags
   each layer's eligibility for quantization, projection, and pruning directly
   on the architecture diagram, which is faster than cross-referencing a table.

**LSTM/GRU implication for Cortex-M deployment:** Although `dlquantizer` quantizes
LSTM/GRU layers in the MATLAB execution environment and `exportNetworkToSimulink`
preserves them as fixed-point blocks, **the ARM Cortex-M code replacement library
in R2026a does not provide INT8 CMSIS kernels for recurrent layers** (Conv2D and FC
have CMSIS-NN INT8 wrappers; LSTM/GRU/BiLSTM only have float32 CMSIS-DSP
matrix-multiply replacement). Quantizing an LSTM saves flash but does NOT speed up
inference on Cortex-M. If latency is the priority, keep recurrent layers in float32
and rely on CMSIS-DSP. See [`codegen-embedded.md`](codegen-embedded.md) for the
CMSIS support tables.

## INT8 Suitability Check

Before quantizing, verify that INT8 precision is adequate for the model's output
range. INT8 provides 256 discrete levels; the quantization step size determines
how much precision is lost.

**Rule:** If `(max_output - min_output) / 256 > acceptable_error`, INT8 is inadequate.

| Output Range | INT8 Suitability | Step Size | Alternative |
|-------------|-----------------|-----------|-------------|
| 0 to 1 | Excellent | ~0.004 | — |
| 0 to 5 | Good | ~0.02 | — |
| -10 to 10 | Acceptable | ~0.08 | Consider INT16 if error budget is tight |
| 100 to 500 | **Poor** (~50%+ error) | ~1.6 | Use INT16 (step ~0.006) or FP32 |

**Precision options when INT8 is insufficient:**

- **INT16:** `dlquantizer` does not produce INT16 directly. Use Fixed-Point Designer
  with `DefaultWordLength=16` via the `codegen -float2fixed` workflow for INT16
  deployment. Provides 65536 levels (~0.006 step for range 0–400).
- **FP32 (no quantization):** If precision requirements cannot be met with any
  fixed-point format, deploy in float32. On Cortex-M4F and above, the hardware FPU
  handles float32 natively.
- **Mixed precision:** Some layers (output regression) can remain FP32 while
  internal layers use INT8. This requires manual layer exclusion during calibration
  — consult the `quantizationDetails` output to identify high-error layers, then
  exclude them from quantization using the `ExcludedLayers` option.

**Note on INT32 fallback:** The code generator may automatically widen accumulator
arithmetic to INT32 even when weights/activations are INT8. This is expected behavior
for multiply-accumulate operations and does not affect the deployed weight storage
(still INT8). It only affects intermediate computation registers.

## Step 1: Prepare Calibration Data

```matlab
% Create calibration dataset of representative inputs
numCalibSamples = 100;

% For sequence models (LSTM/GRU): cell array of [features × time] sequences.
% Pass this directly to calibrate() — see Step 2d. If you prefer a
% datastore form, wrap with arrayDatastore.
calibData = cell(numCalibSamples, 1);
for i = 1:numCalibSamples
    calibData{i} = single(randn(numFeatures, seqLen));
end

% For image models (CNN): 4D array [H x W x C x N]
calibImages = single(randn(224, 224, 3, numCalibSamples));
ds = arrayDatastore(calibImages, 'IterationDimension', 4);

% For feature models (MLP): 2D array [features x N]
calibFeatures = single(randn(numFeatures, numCalibSamples));
ds = arrayDatastore(calibFeatures, 'IterationDimension', 2);
```

## Step 2: Quantize

```matlab
% Step 2a: Create the quantizer object
qOpts = dlquantizationOptions(MetricFcn={@(x) myMetric(x)});  % Optional
quantObj = dlquantizer(net, ExecutionEnvironment="MATLAB");

% Step 2b: Prepare the quantizer's network for quantization
% In R2026a, prepareNetwork takes the dlquantizer object (not a dlnetwork)
% and mutates it in place. It accepts projected networks: any
% ProjectedLayer / lstmProjectedLayer / gruProjectedLayer in the wrapped
% network is unpacked into its underlying built-in layers (e.g., a
% ProjectedLayer becomes two fullyConnectedLayer objects named
% "<orig>_proj_in" and "<orig>_proj_out") before calibration.
prepareNetwork(quantObj);

% Step 2d: Calibrate with representative data
% calData must be defined from YOUR calibration inputs (e.g., XCal from
% your dataset). Create a datastore from the calibration array:
calData = arrayDatastore(calibFeatures, IterationDimension=1);
calibrate(quantObj, calData);
% For sequence models, pad variable-length sequences with padsequences,
% then wrap as a formatted dlarray. For [C × T] inputs padded along dim 2,
% padsequences returns [C × T_pad × N] — format as "CBT" (channel × batch
% × time). Do NOT use cat(3, X{:}); it requires equal-length sequences and
% gives the wrong axis order.
% XPad   = padsequences(calibData, 2);     % [C × T_pad × N]
% dlXCal = dlarray(XPad, "CBT");
% calibrate(quantObj, dlXCal);

% Step 2e: Quantize the network
quantizedNet = quantize(quantObj);
save('quantized_net.mat', 'quantizedNet', '-v7.3');
```

**Code generation from quantized networks — two paths:**

1. **Simulink path (SUPPORTED):** Pass the quantized network to
   `exportNetworkToSimulink(qNet)`. This creates a Simulink model with
   fixed-point data types (embedded.fi) pre-configured in block parameters.
   Embedded Coder then generates integer C code (int8/int16/int32) via `slbuild`.
   This is the recommended path for fixed-point embedded deployment.
   See: https://www.mathworks.com/help/deeplearning/ug/export-quantized-network-to-simulink.html

   For Cortex-M targets: configure the ARM Cortex-M CRL before `slbuild` to enable
   CMSIS-NN INT8 block replacement for **Conv2D and FC layers only**. LSTM/GRU/BiLSTM
   in the quantized model generate as plain fixed-point C — there is no CMSIS-NN
   recurrent-layer kernel in R2026a. See [`codegen-embedded.md`](codegen-embedded.md).

2. **Direct MATLAB Coder path (NOT SUPPORTED):** `coder.loadDeepLearningNetwork`
   does NOT accept the output of `quantize()`. For the direct codegen path
   (without Simulink), use the uncompressed, pruned, or unpacked projected
   network instead.

## Step 3: Validate

```matlab
% Validate using dlquantizer's built-in validation
valData = arrayDatastore(XVal, IterationDimension=1);
valResults = validate(quantObj, valData);
disp(valResults);

% Manual error comparison
errors = zeros(numTests, 1);
for i = 1:numTests
    x = dlarray(single(testInputs{i}), formatString);
    yBase = predict(baseNet, x);
    yQuant = predict(quantizedNet, x);
    errors(i) = max(abs(extractdata(yBase(:)) - extractdata(yQuant(:))));
end

mae = mean(errors);
fprintf('INT8 quantization: MAE=%.4e, MaxErr=%.4e\n', mae, max(errors));
assert(mae < 1e-3, 'Quantization error exceeds budget');
```

## Understanding Quantization Results

After calibration and validation:
- Compare accuracy/error before and after quantization
- Check per-layer quantization parameters (scale, zero-point)
- Identify layers with high quantization error

```matlab
% Get detailed quantization information from the quantized network (not quantObj)
qDetails = quantizationDetails(quantizedNet);
% qDetails struct fields:
%   IsQuantized          - logical
%   TargetLibrary        - string ("none" for MATLAB execution)
%   QuantizedLayerNames  - string array of quantized layer names
%   QuantizedLearnables  - table (Layer, Parameter, Value as embedded.fi)
fprintf('Quantized: %d, Layers: %s\n', qDetails.IsQuantized, ...
    strjoin(qDetails.QuantizedLayerNames, ', '));

% Estimate inference metrics for the quantized network
metrics = estimateNetworkMetrics(quantObj);
disp(metrics);
```

## Alternative: Projection for Parameter Reduction

When `dlquantizer` does not apply (e.g., networks with custom layers that lack
calibration support), use `compressNetworkUsingProjection` to reduce model size.
Projection decomposes weight matrices into lower-rank approximations, directly
reducing parameter count and flash footprint while preserving float32 inference.

See the projection section in this file and
[`compression-decision.md`](compression-decision.md) for when to apply projection
vs. quantization.

## Combined Pipeline (Projection + Quantization)

Use the combined pipeline only when the user's goal is flash reduction AND retraining
is acceptable. Confirm via [`compression-decision.md`](compression-decision.md) before
applying it. The pipeline applies projection first (modest parameter reduction), then
INT8 quantization (aggressive bit-width reduction). Together they achieve significant
flash savings.

### Full Combined Workflow: Prune -> Project -> Quantize

This pseudo-code mirrors the structure of the
[Compress Sequence Classification Network for Road Damage Detection](https://www.mathworks.com/help/deeplearning/ug/compress-sequence-classification-network-for-road-damage-detection.html)
example. All steps reuse the same in-memory cell arrays
(`XTrain`/`TTrain`, `XValidation`/`TValidation`, `XTest`/`TTest`) and the
same trained network and training options — no minibatchqueue, no
datastore wrappers.

```matlab
% Inputs assumed in workspace:
%   netTrained                              — trained dlnetwork
%   XTrain, TTrain, XValidation, TValidation, XTest, TTest  — cell arrays
%   options  — trainingOptions used for the original training
%   lossFcn  — loss function name or handle (e.g., "crossentropy")

%% Step 1: Prune (optional; only effective when conv/FC layers are present)
optionsFineTuning          = options;
optionsFineTuning.MaxEpochs = 10;
[netPruned, infoPruned] = compressNetworkUsingTaylorPruning(netTrained, ...
    XTrain, TTrain, lossFcn, optionsFineTuning, ...
    LearnablesReductionGoal = 0.3, ...
    LearnablesReductionIncrement = 0.02);

% Retrain pruned network on the same data
netPruned = trainnet(XTrain, TTrain, netPruned, lossFcn, options);

%% Step 2: Projection
% Pass training data directly. No separate neuronPCA call is needed for a
% single goal — compressNetworkUsingProjection runs PCA internally. Omit
% LearnablesReductionGoal to let the function use its default driven by ExplainedVarianceGoal.
[netProjected, infoProjection] = compressNetworkUsingProjection(netPruned, ...
    XTrain, LearnablesReductionGoal = 0.10);

% Fine-tune the projected network
netProjected = trainnet(XTrain, TTrain, netProjected, lossFcn, options);

%% Step 3: INT8 quantization
% prepareNetwork(quantObj) performs batch-normalization fusion, parameter
% equalization, and unpacks projected layers as part of preparing the
% network inside the dlquantizer object for calibration.
quantObj = dlquantizer(netProjected, ExecutionEnvironment = "MATLAB");
prepareNetwork(quantObj);
calibrate(quantObj, XTrain);
netQuantized = quantize(quantObj, ExponentScheme = "histogram");
save("combined_compressed.mat", "netQuantized", "-v7.3");

% Deployment via Simulink (R2026a):
%   exportNetworkToSimulink(netQuantized, ...) → slbuild with ARM Cortex-M CRL
% Deployment via direct MATLAB Coder:
%   not supported — coder.loadDeepLearningNetwork does not accept quantize() output.
%   For that path, use the unpacked projected float32 network instead.

%% Verify combined accuracy on the held-out test set (same in-memory cell array)
YTest        = minibatchpredict(netQuantized, XTest);
YBaseline    = minibatchpredict(netTrained,   XTest);
maeCombined  = mean(abs(YTest(:) - YBaseline(:)));
fprintf("Combined: MAE vs baseline = %.4e\n", maeCombined);

%% Calculate flash savings
% Use estimateNetworkMetrics — the Learnables of a quantized dlnetwork are
% NOT stored as int8, so summing numel(v)*sizeof(class(v)) over .Learnables
% misreports the deployed flash footprint. estimateNetworkMetrics accepts
% a quantized network and reports the int8 parameter memory in its
% "ParameterMemory (MB)" column.
[metricsFloat, metricsQuantized] = estimateNetworkMetrics(netTrained, netQuantized);
flashFloatMB     = sum(metricsFloat.("ParameterMemory (MB)"));
flashQuantizedMB = sum(metricsQuantized.("ParameterMemory (MB)"));
fprintf("Flash: %.2f MB -> %.2f MB (%.1f%% savings)\n", ...
    flashFloatMB, flashQuantizedMB, ...
    (1 - flashQuantizedMB/flashFloatMB) * 100);
```


Copyright 2026 The MathWorks, Inc.
