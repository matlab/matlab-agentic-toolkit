# Numeric Verification: MATLAB vs PyTorch

Compare inference output between the original PyTorch model (in Python) and the
MATLAB-loaded model to confirm correct loading and numerical equivalence.

## Primary Approach: pyrun (from within MATLAB)

Use `pyrun` to call PyTorch inference directly from MATLAB. This keeps
everything in one session — no external scripts, no file exchange.

**Ask the user for a Python venv path** with `torch` installed (and any other
packages the model needs to run, e.g., `transformers`, `timm`, model-specific
repos). Do not guess a path or install packages without confirmation.

**Critical:** Set `ExecutionMode` to `'OutOfProcess'` before importing torch.
PyTorch's C extensions conflict with MATLAB's bundled libraries in-process and
crash with an `undefined symbol` error. This must be set before Python is
first loaded (i.e., before the first `pyrun` call in the session).

```matlab
% Set ONCE at the start of the session, before any pyrun call
pyenv('Version', '/path/to/venv/bin/python3', 'ExecutionMode', 'OutOfProcess');

% Fixed input — same seed used for both MATLAB and PyTorch
rng(42);
inp = randn(1, 3, 224, 224, 'single');

% MATLAB inference
model = loadPyTorchExportedProgram("model.pt2");
matlabOut = invoke(model, inp);

% PyTorch inference via pyrun
pyrun("import torch; ep = torch.export.load('model.pt2')");
ptOut = pyrun( ...
    ["import numpy as np;" ...
     "t = torch.from_numpy(np.array(x, dtype='float32'));" ...
     "with torch.no_grad():" ...
     "    out = ep.module()(t);" ...
     "out = out[0] if isinstance(out, (tuple,list)) else out;" ...
     "result = out.numpy()"], ...
    "result", x=inp);
ptOut = single(ptOut);

% Compare
testCase = matlab.unittest.TestCase.forInteractiveUse;
testCase.verifyThat(matlabOut, matlab.unittest.constraints.IsEqualTo(ptOut, ...
    'Within', matlab.unittest.constraints.AbsoluteTolerance(single(1e-4))));
```

**Input shape and type must match what the model expects.** Construct the test
input with the correct dimensions (e.g., NCHW for vision models) and dtype
(`single` for float32). Mismatched inputs produce silent wrong results or
runtime errors.

**Note on multi-output models:** If the PyTorch model returns a tuple, the
`pyrun` snippet above extracts `out[0]`. Adjust indexing if your model returns
multiple tensors.

## Tolerance Values

- Absolute tolerance: `1e-4` (single-precision inference, CPU vs CPU)

## When to Use

- After loading a model with `loadPyTorchExportedProgram` for the first time
- Before proceeding to MEX generation (confirm the model loaded correctly)
- When debugging unexpected inference results

----

Copyright 2026 The MathWorks, Inc.

----
