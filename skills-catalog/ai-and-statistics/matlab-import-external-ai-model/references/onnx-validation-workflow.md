# Validation Workflow

Mandatory verification that an imported ONNX model produces numerically correct
outputs. Every import must pass this check before declaring success.

## Prerequisites

- Imported `dlnetwork` object in MATLAB
- Python available in MATLAB (`pyenv` returns a valid environment)
- `onnxruntime` already installed in the user's Python environment

**Important:** Only run this workflow if `onnxruntime` is already present. Do not ask the user to install it or suggest installation commands.

## Full Procedure

### 1. Generate Deterministic Test Input

Use a fixed random seed so results are reproducible:

```matlab
rng(42);
```

Determine the input shape and format by inspecting the network's input layer.
The layer class tells you which format to use:

| Input Layer Class | `InputSize` | dlarray Format | Example |
|---|---|---|---|
| `ImageInputLayer` | `[H W C]` | `"SSCB"` | `randn([H W C 1], "single")` |
| `SequenceInputLayer` | `numFeatures` (scalar) | `"CBT"` | `randn([C T 1], "single")` where T is an arbitrary sequence length |
| `FeatureInputLayer` | `numFeatures` (scalar) | `"CB"` | `randn([C 1], "single")` |

```matlab
inputLayer = net.Layers(1);
inputSize = inputLayer.InputSize;

if isa(inputLayer, "nnet.cnn.layer.ImageInputLayer")
    inputData = randn([inputSize 1], "single");
    X = dlarray(inputData, "SSCB");
elseif isa(inputLayer, "nnet.cnn.layer.SequenceInputLayer")
    seqLen = 10;  % Arbitrary sequence length for testing
    inputData = randn([inputSize seqLen 1], "single");
    X = dlarray(inputData, "CBT");
elseif isa(inputLayer, "nnet.cnn.layer.FeatureInputLayer")
    inputData = randn([inputSize 1], "single");
    X = dlarray(inputData, "CB");
end
```

For **uninitialized networks** (input layer is `CustomInputLayerMultiOutput`),
read the `InputInformation` property which prints the expected ONNX shape and
required format. Use `NumDims` to determine rank. You will need to initialize
the network with `InputDataFormats` before running inference.

### 2. Run MATLAB Inference

```matlab
Y = predict(net, X);
matlabOutput = extractdata(Y);
```

### 3. Run ONNX Runtime Inference

```matlab
ort = py.importlib.import_module("onnxruntime");
np = py.importlib.import_module("numpy");

sess = ort.InferenceSession("model.onnx");
inputs = sess.get_inputs();
inputInfo = inputs{1};
inputName = char(inputInfo.name);
```

### 4. Permute MATLAB Data to ONNX Dimension Order

MATLAB and ONNX use reversed dimension ordering. MATLAB's dlarray stores data
in DLT order (reverse of ONNX convention). You **must** permute the input data
before passing it to ONNX Runtime, and permute ORT outputs back for comparison.

**Why permutation is required:** MATLAB uses column-major storage with dimensions
ordered as spatial→channel→batch (SSCB), while ONNX uses row-major convention
with batch→channel→spatial (NCHW). Without permutation, the comparison is
meaningless — you'd be comparing different data arrangements.

#### Input permutation (MATLAB → ONNX):

The general rule is to reverse the MATLAB dimension order. Use permutation
vectors based on the dlarray format:

```matlab
% Image SSCB (H,W,C,B) → ONNX NCHW (B,C,H,W): reverse 4D
inputForOnnx = permute(inputData, [4, 3, 1, 2]);

% Sequence CBT (C,B,T) → ONNX (B,T,C): swap to batch-first
inputForOnnx = permute(inputData, [2, 3, 1]);

% Feature CB (C,B) → ONNX BC (B,C): transpose
inputForOnnx = permute(inputData, [2, 1]);
```

#### Output permutation (ONNX → MATLAB):

ORT returns outputs in ONNX dimension order. Permute back to MATLAB order
before comparing:

```matlab
% Image output: ORT NCHW (B,C,H,W) → MATLAB SSCB (H,W,C,B)
ortOutputPermuted = permute(ortOutput, [3, 4, 2, 1]);

% Sequence output: ORT (B,T,C) → MATLAB CBT (C,B,T)
ortOutputPermuted = permute(ortOutput, [3, 1, 2]);

% Feature/classification output: ORT BC (B,C) → MATLAB CB (C,B)
ortOutputPermuted = permute(ortOutput, [2, 1]);
```

**Tip:** If the ORT output is 1D or 2D with a batch size of 1, you can often
skip output permutation and compare with `matlabOutput(:)` vs `ortOutput(:)`
since flattening makes order irrelevant for scalar or vector outputs.

#### Handling numpy shape issues

When passing MATLAB arrays to numpy, small arrays (1D or 2D with a singleton
dimension) may lose dimensions. Use `numpy.reshape` to enforce the expected
shape from the ONNX session metadata:

```matlab
% If numpy flattens the input, reshape to match expected ONNX shape:
onnxShape = inputInfo.shape;
pyInput = np.array(inputForOnnx(:)', pyargs("dtype", np.float32));
expectedShape = int32(cell2mat(cell(onnxShape)));
pyInput = pyInput.reshape(expectedShape);
```

### 5. Execute and Compare

```matlab
pyInput = np.array(inputForOnnx, pyargs("dtype", np.float32));
inputDict = py.dict(pyargs(inputName, pyInput));
result = sess.run(py.list(), inputDict);
ortOutput = single(result{1});

% Permute ORT output back to MATLAB order if needed (see Step 4)
% For scalar/vector outputs, direct comparison usually works:
maxDiff = max(abs(matlabOutput(:) - ortOutput(:)));
meanDiff = mean(abs(matlabOutput(:) - ortOutput(:)));
fprintf("Max absolute difference:  %e\n", maxDiff);
fprintf("Mean absolute difference: %e\n", meanDiff);
```

### 6. Assert Tolerance

```matlab
assert(maxDiff < 1e-4, ...
    "FAIL: Max difference %e exceeds float32 tolerance 1e-4", maxDiff);
fprintf("PASS: MATLAB output matches ONNX Runtime (max diff: %e)\n", maxDiff);
```

**Tolerance guidelines:**
- float32 models: `< 1e-4` (typical accumulation error)
- float16 models: `< 1e-2`
- If difference is `> 1e-3` for float32, investigate which layer diverges

## When ONNX Runtime Is Not Installed

If `onnxruntime` is not available, skip numeric verification. Do not:
- Ask the user to install `onnxruntime`
- Suggest `pip install` commands
- Use alternative verification methods (e.g., `onnx.reference.ReferenceEvaluator`)

Simply inform the user that numeric verification was skipped because ONNX Runtime
is not present in their environment.

## Multi-Output Models

For models with multiple outputs, compare each output separately:

```matlab
outputs = sess.get_outputs();
for i = 1:int32(py.len(outputs))
    outputName = char(outputs{i}.name);
    ortOut = single(result{i});
    % Get corresponding MATLAB output
    matlabOut = extractdata(predict(net, X, Outputs=outputName));
    maxDiff = max(abs(matlabOut(:) - ortOut(:)));
    fprintf("Output '%s': max diff = %e\n", outputName, maxDiff);
end
```

----

Copyright 2026 The MathWorks, Inc.

----
