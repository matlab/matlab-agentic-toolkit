# Simulink Integration and Simulation

Export trained AI models to Simulink for closed-loop simulation, hardware-in-the-loop
testing, and Embedded Coder C generation. This reference covers integration paths for
dlnetwork, fitcnet, and fitrnet models, along with simulation patterns and pre-deployment
verification.

## Integration Paths by Model Type

| Model Type                          | Integration Method                           |
|--------------------------------------|----------------------------------------------|
| `dlnetwork` (Deep Learning Toolbox)  | `exportNetworkToSimulink`                    |
| `fitcnet` (Stats/ML Toolbox)         | ClassificationNeuralNetwork Predict block    |
| `fitrnet` (Stats/ML Toolbox)         | RegressionNeuralNetwork Predict block        |

---

## dlnetwork Integration: exportNetworkToSimulink

### Clean Environment Before Export

Stale Simulink artifacts can cause export failures. Always clean before exporting:

```matlab
modelName = 'my_dl_model';

% Clean stale files
if exist([modelName '.slx'], 'file'), delete([modelName '.slx']); end
if exist([modelName '.slxc'], 'file'), delete([modelName '.slxc']); end
if bdIsLoaded(modelName), close_system(modelName, 0); end

% Now export
exportNetworkToSimulink(net, 'ModelName', modelName);
```

### Basic Export

```matlab
% Export trained dlnetwork to Simulink (use name-value pairs, not positional model name)
mdlInfo = exportNetworkToSimulink(net, ModelName="myModel");
```

This creates a Simulink model with the network expanded into individual layer blocks
(FC, LSTM, ReLU, etc.), connected with signal lines matching the dlnetwork graph.
Each layer becomes its own Simulink block, giving full visibility into the inference
pipeline and enabling per-layer inspection during simulation.

### exportNetworkToSimulink Options

| Parameter                   | Values                    | Default           |
|-----------------------------|---------------------------|--------------------|
| `ModelName`                 | string                    | `"my_model"`      |
| `Stateful`                  | `true` / `false`          | auto (based on net)|
| `SampleTime`                | **string** (e.g. `"1"`, `"-1"`) | `"-1"`        |
| `InputDataType`             | `"uint8"`, `"single"`, `"Inherit: auto"` | `"Inherit: auto"` |
| `SaveModelToFile`           | `true` / `false`          | `true`            |
| `OpenSystem`                | `true` / `false`          | `true`            |
| `SaveNetworkInModelWorkspace` | `true` / `false`        | `false`           |

### Exporting Quantized Networks (Recommended for Fixed-Point Deployment)

Pass the quantized network (output of `quantize()`) directly to
`exportNetworkToSimulink`. This creates a Simulink model with fixed-point data
types pre-configured in block parameters — weights, biases, and accumulators all
use `embedded.fi` types. Embedded Coder then generates integer C code directly.

Reference: https://www.mathworks.com/help/deeplearning/ug/export-quantized-network-to-simulink.html

```matlab
% Quantize the network
quantObj = dlquantizer(net, ExecutionEnvironment="MATLAB");
calibrate(quantObj, calibDs);
qNet = quantize(quantObj);

% Export quantized network -- creates fixed-point Simulink blocks
exportNetworkToSimulink(qNet, ModelName="model_quantized", ...
    Stateful=true, InputDataType="single", SampleTime="1");

% Generate fixed-point C code
set_param('model_quantized', 'SystemTargetFile', 'ert.tlc');

% CMSIS-NN optimization: if targeting ARM Cortex-M, set the Code Replacement
% Library to use CMSIS-NN INT8 kernels for Conv2D and FC blocks ONLY (~2.8-3x).
% LSTM/GRU/BiLSTM blocks in the quantized model have no CMSIS-NN INT8 kernel
% in R2026a — they generate as plain fixed-point C. See codegen-embedded.md.
% Requires: Embedded Coder Support Package for ARM Cortex-M Processors.
set_param('model_quantized', 'ProdHWDeviceType', 'ARM Compatible->ARM Cortex-M');
set_param('model_quantized', 'CodeReplacementLibrary', 'ARM Cortex-M');

slbuild('model_quantized');
```

### Exporting Projected Networks (R2026a)

In R2026a, `exportNetworkToSimulink` accepts networks that contain `ProjectedLayer`,
`lstmProjectedLayer`, or `gruProjectedLayer` directly. Calling `unpackProjectedLayers`
before export is no longer required for the Simulink path.

```matlab
% Project, then export directly — no unpack needed for the Simulink path
projectedNet = compressNetworkUsingProjection(net, calibData);
exportNetworkToSimulink(projectedNet, ModelName="model_projected", ...
    Stateful=true, InputDataType="single", SampleTime="1");
```

For the **direct MATLAB Coder path**, `lstmProjectedLayer` and
`gruProjectedLayer` are supported by `coder.loadDeepLearningNetwork` for
generic C/C++ codegen. A `ProjectedLayer` wrapper is supported only when
its contents are stateless (conv/FC, or LSTM/GRU in stateful-I/O mode); a
wrapped stateful LSTM/GRU is not. When in doubt, call
`unpackProjectedLayers` first to produce the most codegen-friendly form.

### Exporting Non-Quantized Compressed Networks

For the float32 path (projected or pruned networks):

```matlab
exportNetworkToSimulink(compressedNet, ModelName="model_float32", ...
    Stateful=true, InputDataType="single", SampleTime="1");
```

### Handling Placeholder Layers from exportNetworkToSimulink

When `exportNetworkToSimulink` encounters layers it cannot map to native Simulink layer
blocks (e.g., `selfAttentionLayer`, custom reshape/permute layers), it creates
**placeholder subsystems** -- empty stubs containing `Inport -> Assertion -> Outport`
with unspecified output dimensions. These block both simulation and code generation.

If placeholder layers appear after export, load `placeholder-blocks.md` for the complete
workflow: identifying placeholders, cleaning stub contents, choosing between Simulink
primitives vs MATLAB Function blocks, storing weights in model workspace, and wiring
replacements.

**Path 1: Use the Predict block (simpler)**

The Predict block from the Deep Learning Toolbox handles inference internally
without exposing individual network layers. This avoids placeholder layer issues.

```matlab
% Instead of exportNetworkToSimulink, use the Predict block:
% 1. Open your Simulink model
% 2. From the Library Browser: Deep Learning Toolbox > Predict
% 3. Drag the Predict block into your model
% 4. Double-click and set the network to your workspace variable (e.g., 'net')
% 5. Configure input dimensions to match your signal
```

This is the recommended path when the primary goal is system-level simulation
and the user does not need layer-by-layer visibility in Simulink.

**Path 2: Implement placeholder layers with codegen-compatible primitives**

If the user needs the full network exposed as individual Simulink blocks (e.g.,
for layer-by-layer inspection, modification, or mixed-precision analysis):

1. **Identify each placeholder layer** and its mathematical operation:
   ```matlab
   % List placeholder layers in the exported model
   % Check the original dlnetwork to understand what each layer does
   analyzeNetwork(net)
   ```

2. **Replace each placeholder** with one of:
   - **MATLAB Function block** -- Write the operation in MATLAB code that is
     compatible with code generation (no dynamic allocation, use `single` types)
   - **Simulink math blocks** -- Use Sum, Product, Gain, Math Function, etc.
     to implement the same operation with primitive blocks

3. **Validation:** After replacing all placeholder layers, verify:
   ```matlab
   % Run simulation and compare outputs
   % Original: run inference in MATLAB
   YMatlab = minibatchpredict(net, XTest);

   % Simulink: run the model and collect logged output
   simOut = sim("myModel");
   YSimulink = simOut.logsout.get("AI_Output").Values.Data;

   % Compare
   maxDiff = max(abs(YMatlab - YSimulink), [], "all");
   fprintf("Max difference: %.6e\n", maxDiff);
   ```

4. **Ensure all replacement blocks are code-generation compatible** -- avoid
   `eval`, dynamic memory allocation, or variable-size arrays in MATLAB
   Function blocks.

### Configuring the Predict Block

After export, configure the block:

1. **Input format:** Set to match your signal dimensions
2. **Data type:** Ensure input signals use `single` precision for compatibility
3. **Sample time:** Match the sample time of your system

```matlab
% Set block parameters programmatically
set_param("myModel/Predict", "SampleTime", "0.01");
```

### Handling Sequence/Time-Series Models (LSTM/GRU)

For any sequence model, set both `Stateful=true` and `FrameBased=true`:

```matlab
mdlInfo = exportNetworkToSimulink(net, ...
    ModelName="mySeqModel", ...
    Stateful=true, ...
    FrameBased=true, ...
    InputDataType="single", ...
    SampleTime="0.01");
```

- `Stateful=true` makes the exported block maintain hidden state between time steps,
  processing one time step per simulation step.
- `FrameBased=true` configures the block to operate on frame-based signals, which is
  the recommended setting for any sequence model exported with
  `exportNetworkToSimulink`.

---

## Stats/ML Toolbox Integration

### fitcnet -- ClassificationNeuralNetwork Predict Block

1. Open the Simulink Library Browser
2. Navigate to: **Statistics and Machine Learning Toolbox** > **Predict**
3. Drag the **ClassificationNeuralNetwork Predict** block into your model
4. Double-click to configure:
   - Set the trained model workspace variable name (e.g., `mdl`)
   - Configure input port dimensions to match your feature vector

```matlab
% Ensure the trained model is in the base workspace
mdl = fitcnet(XTrain, YTrain, "LayerSizes", [64 32]);

% Or load from file
load("trainedClassifier.mat", "mdl");
```

### fitrnet -- RegressionNeuralNetwork Predict Block

1. Open the Simulink Library Browser
2. Navigate to: **Statistics and Machine Learning Toolbox** > **Predict**
3. Drag the **RegressionNeuralNetwork Predict** block into your model
4. Configure with the trained model variable

---

## Configuring the Simulink Model

```matlab
% Open the generated model
open_system(modelName);

% Set solver for embedded deployment
set_param(modelName, ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '1');          % 1 sample per step (adapt to your app)

% Set stop time for simulation
numSamples = 100;
set_param(modelName, 'StopTime', num2str(numSamples - 1));
```

---

## Open-Loop Evaluation (No Simulink Model)

When the user does not have a Simulink model, perform open-loop evaluation in MATLAB:

### For dlnetwork

```matlab
% Run inference on test data
YPred = minibatchpredict(net, XTest);

% For classification
[~, YPredLabels] = max(YPred, [], 2);

% Compare with ground truth
accuracy = mean(YPredLabels == YTest);
confMat = confusionmat(YTest, YPredLabels);

figure;
confusionchart(confMat);
title("Confusion Matrix -- Open-Loop Evaluation");
```

### For fitcnet

```matlab
% Predict classes
YPred = predict(mdl, XTest);
accuracy = mean(YPred == YTest);

% Get scores for ROC analysis
[YPred, scores] = predict(mdl, XTest);

% Confusion matrix
figure;
confusionchart(YTest, YPred);
```

### For fitrnet

```matlab
% Predict values
YPred = predict(mdl, XTest);

% Regression metrics
rmseVal = rmse(YPred, YTest);
maeVal  = mean(abs(YPred - YTest));
r2Val   = 1 - sum((YTest - YPred).^2) / sum((YTest - mean(YTest)).^2);

% Scatter plot
figure;
scatter(YTest, YPred, 20, "filled", MarkerFaceAlpha=0.5);
hold on;
plot(xlim, xlim, "r--", LineWidth=1.5);
xlabel("Actual");
ylabel("Predicted");
title(sprintf("Regression Results -- RMSE: %.4f, R^2: %.4f", rmseVal, r2Val));
```

---

## System-Level Simulation Patterns

### Connecting AI Block to Control Logic

```matlab
% Typical connection pattern:
% Sensor Signal -> Preprocessing -> AI Predict Block -> Post-processing -> Controller

% Example: Virtual sensor replacing a physical measurement
% Input: available sensor readings (temperature, pressure, speed)
% Output: estimated quantity (e.g., mass flow rate)
```

### Running Simulation and Collecting Results

Use `Simulink.SimulationInput` to configure simulations programmatically without
modifying the saved model file. This is the recommended pattern for reproducible,
scriptable simulation runs.

```matlab
% Create simulation input object
simIn = Simulink.SimulationInput("myModel");

% Configure simulation parameters
simIn = setModelParameter(simIn, "StopTime", "10");
simIn = setModelParameter(simIn, "SolverType", "Fixed-step");
simIn = setModelParameter(simIn, "FixedStep", "0.001");

% Configure individual block parameters
simIn = setBlockParameter(simIn, "myModel/AI_Predict", ...
    "NetworkVariable", "net");

% Pass workspace variables (e.g., the trained network) to the model
simIn = setVariable(simIn, "net", net, Workspace="myModel");

% Run simulation -- returns Simulink.SimulationOutput
simOut = sim(simIn);

% Extract AI block outputs from logged signals
aiOutput = simOut.logsout.get("AI_Output").Values;

% Plot
figure;
plot(aiOutput.Time, aiOutput.Data);
xlabel("Time (s)");
ylabel("AI Output");
title("AI Model Output During System Simulation");
```

**Key `Simulink.SimulationInput` methods:**

| Method              | Purpose                                        |
|---------------------|------------------------------------------------|
| `setModelParameter` | Solver, stop time, and model-level settings    |
| `setBlockParameter` | Configure individual block parameters          |
| `setVariable`       | Pass workspace variables to the model          |

Changes made via `Simulink.SimulationInput` override model values at runtime
without dirtying the saved `.slx` file -- ideal for parameter sweeps and
automated testing.

### Per-Sample Simulation (Sequence Models)

For LSTM or sequence models, run one simulation per test sample using timeseries input:

**IMPORTANT:** Stateful LSTM/GRU models output one value per simulation step. The output
`Data` field is 3-D: `[1 × 1 × seqLen]` (not `[seqLen × 1]`). Use `squeeze()` before
indexing, or index with `(end)` not `(end, :)`.

```matlab
numTests = 100;
simResults = zeros(numTests, 1);

% Configure model for external input
set_param(modelName, 'LoadExternalInput', 'on');
set_param(modelName, 'SaveOutput', 'on');
set_param(modelName, 'OutputSaveName', 'yout');

for i = 1:numTests
    % Create input timeseries for this sample
    inputSeq = single(testInputs{i});  % [seqLen x features]
    time = (0:size(inputSeq, 1) - 1)';
    inputTs = timeseries(inputSeq, time);

    % Configure and run
    set_param(modelName, 'StopTime', num2str(size(inputSeq, 1) - 1));
    set_param(modelName, 'ExternalInput', 'inputTs');
    simOut = sim(modelName);

    % Extract output — use squeeze for stateful LSTM (output is 3-D)
    outData = simOut.yout{1}.Values.Data;
    simResults(i) = outData(end);  % Last time step = final SoC estimate
end

% Compare against reference
errors = abs(simResults - referenceOutputs(:));
mae = mean(errors);
fprintf('Simulink MAE vs reference: %.4e\n', mae);
```

### Batch Simulation (Feedforward Models)

For MLP/CNN models that process independent samples:

```matlab
% Stack all inputs as timeseries
inputBatch = single(cat(1, testInputs{:}));  % [N x features]
time = (0:size(inputBatch, 1) - 1)';
ts = timeseries(inputBatch, time);

set_param(modelName, 'StopTime', num2str(size(inputBatch, 1) - 1));

simOut = sim(modelName);
simResults = simOut.yout{1}.Values.Data;
```

### Comparing AI vs. Reference Behavior

```matlab
% Compare AI output against reference (e.g., physical sensor, ground truth)
reference = simOut.logsout.get("Reference_Signal").Values;
aiOutput  = simOut.logsout.get("AI_Output").Values;

% Compute error
error = aiOutput.Data - reference.Data;
rmseVal = sqrt(mean(error.^2));
maxError = max(abs(error));

fprintf("RMSE: %.4f\n", rmseVal);
fprintf("Max absolute error: %.4f\n", maxError);

figure;
tiledlayout(2,1);
nexttile;
plot(reference.Time, reference.Data, "b", aiOutput.Time, aiOutput.Data, "r--");
legend("Reference", "AI Output");
title("AI vs. Reference Signal");

nexttile;
plot(aiOutput.Time, error);
ylabel("Error");
xlabel("Time (s)");
title(sprintf("Prediction Error (RMSE: %.4f)", rmseVal));
```

---

## Expected Simulink vs MATLAB Tolerances

Simulink introduces small additional numerical error due to block execution ordering
and fixed-step solver discretization.

| Network Type | Float32 MAE | INT8 MAE | Fixed-Point MAE |
|-------------|------------|---------|----------------|
| MLP | < 1e-6 | < 2e-3 | < 5e-3 |
| LSTM | < 1e-5 | < 2e-3 | < 5e-3 |
| CNN | < 1e-5 | < 3e-3 | < 5e-3 |

---

## Embedded Coder C Generation from Simulink

### Configure for Code Generation

```matlab
% Set ERT target
set_param(modelName, ...
    'SystemTargetFile', 'ert.tlc', ...
    'TargetLang', 'C');

% ARM Cortex-M hardware (bit-per-type params are read-only; auto-set by device type)
cs = getActiveConfigSet(modelName);
set_param(cs, 'ProdHWDeviceType', 'ARM Compatible->ARM Cortex-M');

% Portable word sizes for cross-compilation
set_param(cs, 'PortableWordSizes', 'on');
```

### Generate Code

```matlab
slbuild(modelName);
```

Generated code location: `<modelName>_ert_rtw/`

Key files:
- `<modelName>.c` -- Model step function
- `<modelName>.h` -- Model interface
- `<modelName>_data.c` -- Model parameters and weights
- `<modelName>_types.h` -- Type definitions
- `rtwtypes.h` -- Common data types
- `rt_OneStep()` -- Real-time entry point

### C Integration Patterns

```c
#include "my_dl_model.h"

// Initialize once at startup
my_dl_model_initialize();

// Call at each control loop iteration
void sensor_callback(float* sensor_data) {
    // Set model inputs
    my_dl_model_U.input[0] = sensor_data[0];
    my_dl_model_U.input[1] = sensor_data[1];
    // ... etc

    // Execute one step
    my_dl_model_step();

    // Read prediction
    float prediction = my_dl_model_Y.output;
    apply_control_action(prediction);
}
```

### Fixed-Point Code Generation

For maximum flash reduction on MCU targets, generate fixed-point code from the
Simulink model:

```matlab
% Configure for fixed-point
cfg = getActiveConfigSet(modelName);
set_param(cfg, 'PortableWordSizes', 'on');

% The quantized network's int8/int16 types are preserved through codegen
% Fixed-Point Designer handles the scaling automatically
slbuild(modelName);
```

Fixed-point C code is typically 60-70% smaller than float32 generated C.

---

## Two-Path Comparison: Direct MATLAB Coder vs Simulink Embedded Coder

You can generate C from the same network via two paths and compare:

### Path 1: Direct MATLAB Coder

```matlab
% Save network
save('net.mat', 'netNative');

% Write entry-point
% function out = predict_fn(Xin)
% %#codegen
%   persistent net;
%   if isempty(net), net = coder.loadDeepLearningNetwork('net.mat','n'); end
%   out = extractdata(predict(net, dlarray(single(Xin), 'CT')));
% end

cfg = coder.config('lib', 'ecoder', true);
cfg.TargetLang = 'C';
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');
codegen -config cfg predict_fn -args {inputType} -report
```

### Path 2: Simulink Embedded Coder

```matlab
exportNetworkToSimulink(netNative, 'ModelName', 'model_sim');
set_param('model_sim', 'SystemTargetFile', 'ert.tlc');
slbuild('model_sim');
```

**Comparison notes:**
- Simulink adds step/init/terminate harness code (slightly larger)
- Fixed-point through Simulink can produce smaller MAC cost
- Direct codegen is simpler for standalone inference
- Simulink codegen is better for closed-loop systems with other blocks

---

## Numerical Equivalency: MATLAB Compressed Model vs. Simulink

After integrating the compressed model into Simulink, **always** validate numerical
equivalency between the MATLAB compressed model and the Simulink simulation output.
This ensures no numerical drift was introduced during the export and Simulink block
execution.

### Test Protocol

1. **Propose test count** to the user: typically 100 inputs for feedforward models,
   50 sequences for LSTM/GRU models. Explain rationale and wait for agreement.

2. **Run comparison tests:**

```matlab
%% Numerical Equivalency: MATLAB vs Simulink
numTests = 100;  % As agreed with user
errors = zeros(numTests, 1);

for i = 1:numTests
    % MATLAB compressed model inference
    xTest = single(testInputs{i});
    yMatlab = predict(compressedNet, dlarray(xTest, formatString));
    yMatlab = extractdata(yMatlab);

    % Simulink inference (via sim)
    simIn = Simulink.SimulationInput(modelName);
    simIn = setVariable(simIn, 'inputData', timeseries(xTest, 0:size(xTest,1)-1));
    simOut = sim(simIn);
    ySimulink = simOut.yout{1}.Values.Data(end, :);

    errors(i) = max(abs(yMatlab(:) - ySimulink(:)));
end

fprintf('MATLAB vs Simulink Numerical Equivalency\n');
fprintf('=========================================\n');
fprintf('Tests run:  %d\n', numTests);
fprintf('MAE:        %.4e\n', mean(errors));
fprintf('Max Error:  %.4e\n', max(errors));
fprintf('Pass/Fail:  %s\n', iif(max(errors) < 1e-4, 'PASS', 'INVESTIGATE'));
```

3. **Report results** with explicit pass/fail and comparison to expected tolerances
   (see tolerance table above).

---

## Pre-Deployment Simulation Checklist

Before proceeding to compression and code generation:

- [ ] AI model produces expected outputs in simulation
- [ ] Input/output data types are consistent (preferably `single`)
- [ ] Sample time is correctly configured
- [ ] No algebraic loops introduced by the AI block
- [ ] System behavior is acceptable with AI in the loop
- [ ] Edge cases and boundary conditions tested
- [ ] **Numerical equivalency validated** between MATLAB compressed model and Simulink output


Copyright 2026 The MathWorks, Inc.
