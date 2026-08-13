# Numeric Verification: MATLAB vs Python LiteRT

Compare inference output between the original LiteRT model (in Python via
`ai_edge_litert.Interpreter`) and the MATLAB-loaded model to confirm correct
loading and numerical equivalence.

## Approach: pyrun from MATLAB

Use MATLAB's `pyrun` to call Python code inline from a MATLAB script. This
keeps everything in a single MATLAB script — no separate Python process, no
`matlab.engine` package needed.

**Python environment setup:** See `evals/README.md` for venv location and
authoring styles. Point MATLAB at the venv with `ai-edge-litert`:

```matlab
venvRoot = getenv("LITERT_VENV_ROOT_DIR");
pyenv(ExecutionMode="OutOfProcess", ...
    Version=fullfile(venvRoot, "bin", "python3"));
```

## Complete Verification Script

```matlab
%% Configure Python environment
venvRoot = getenv("LITERT_VENV_ROOT_DIR");
pyenv(ExecutionMode="OutOfProcess", ...
    Version=fullfile(venvRoot, "bin", "python3"));

%% MATLAB inference
modelPath = "/path/to/model.tflite";
model = loadLiteRTModel(modelPath);
specs = inputSpecifications(model);
input = randn(specs.Size{1}, specs.Type{1});

matlabOut = invoke(model, input);

%% Python LiteRT inference via pyrun
pyOut = pyrun( ...
    ["from ai_edge_litert.interpreter import Interpreter;" ...
     "import numpy as np;" ...
     "interp = Interpreter(model_path=mp);" ...
     "interp.allocate_tensors();" ...
     "inp_det = interp.get_input_details();" ...
     "out_det = interp.get_output_details();" ...
     "interp.set_tensor(inp_det[0]['index'], np.array(x, dtype='float32'));" ...
     "interp.invoke();" ...
     "result = interp.get_tensor(out_det[0]['index'])"], ...
    "result", mp=modelPath, x=input);
pyOut = single(pyOut);

%% Compare with tolerance
testCase = matlab.unittest.TestCase.forInteractiveUse;
testCase.verifyThat(matlabOut, matlab.unittest.constraints.IsEqualTo(pyOut, ...
    'Within', matlab.unittest.constraints.AbsoluteTolerance(single(1e-5))));
fprintf('VERIFICATION PASSED: MATLAB and Python outputs match within 1e-5.\n');
```

## Key Details

**Python package:** Use `ai-edge-litert` (current Google AI Edge package).
Import as `from ai_edge_litert.interpreter import Interpreter`. The legacy
`tflite_runtime` package is deprecated.

**Windows note:** `ai_edge_litert` requires the Visual C++ Redistributable to
be installed on Windows. Alternatively, use `tf.lite.Interpreter` from the
`tensorflow` package, which has the same API:

```python
import tensorflow as tf
interp = tf.lite.Interpreter(model_path=mp)
```

**ExecutionMode OutOfProcess:** Required to avoid library conflicts between
MATLAB and the Python runtime. Set this before any `pyrun` call.

**Data passing:** `pyrun` converts MATLAB arrays to numpy arrays automatically.
The returned numpy array converts back with `single(pyOut)`.

**Tolerance values:**
- Absolute tolerance: `1e-5` (standard for single-precision inference)
- Differences arise from floating-point operation ordering, not from incorrect loading

**Shape matching:** LiteRT models use NHWC layout in both Python and MATLAB,
so shapes align without permutation.

**Variable-size batch dimension:** If `inputSpecifications` shows `Inf` for the
batch dimension, replace it with a concrete size (e.g., 1) before creating the
test input:

```matlab
inputSize = specs.Size{1};
inputSize(isinf(inputSize)) = 1;
input = randn(inputSize, specs.Type{1});
```

## When to Use

- After loading a model with `loadLiteRTModel` for the first time
- Before proceeding to MEX generation (confirm the model loaded correctly)
- When debugging unexpected inference results
- When comparing MATLAB output against a known Python reference

## Prerequisites

- Python venv with `ai-edge-litert` installed (path in `LITERT_VENV_ROOT_DIR`)
- The `.tflite` file accessible from MATLAB

----

Copyright 2026 The MathWorks, Inc.

----
