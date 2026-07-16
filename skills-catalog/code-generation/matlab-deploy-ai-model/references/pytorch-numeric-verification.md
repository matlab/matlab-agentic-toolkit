# Numeric Verification: MATLAB vs PyTorch

Compare inference output between the original PyTorch model (in Python) and the
MATLAB-loaded model to confirm correct loading and numerical equivalence.

## Approach: MATLAB Engine for Python

Use the MATLAB Engine for Python to call MATLAB from the same Python script that
runs PyTorch inference. This avoids file-based data exchange and ensures identical
inputs are used.

## MATLAB Entry-Point Function

Save as `mInvoke.m`:

```matlab
function out = mInvoke(networkPath, input)
    net = loadPyTorchExportedProgram(networkPath);
    out = invoke(net, input);
end
```

## Python Verification Script

```python
import torch
import numpy as np
import matlab.engine

eng = matlab.engine.start_matlab()
eng.addpath(r"/path/to/mfiles", nargout=0)

pt2_path = r"/path/to/model.pt2"

model = torch.export.load(pt2_path)

x_torch = torch.randn(1, 3, 224, 224, dtype=torch.float32)

with torch.no_grad():
    y_python = model.module()(x_torch).numpy()

x_mat_single = eng.single(x_torch.numpy())

y_matlab = eng.mInvoke(pt2_path, x_mat_single)
y_matlab_np = np.array(y_matlab).astype(np.float32)

max_abs_err = float(np.max(np.abs(y_python - y_matlab_np)))
max_rel_err = float(np.max(np.abs(y_python - y_matlab_np) / (np.abs(y_python) + 1e-12)))

print(f"Max absolute error: {max_abs_err:.2e}")
print(f"Max relative error: {max_rel_err:.2e}")

ATOL = 1e-5
RTOL = 1e-4
assert max_abs_err < ATOL, f"Absolute error {max_abs_err} exceeds {ATOL}"
assert max_rel_err < RTOL, f"Relative error {max_rel_err} exceeds {RTOL}"
print("PASS: Numerical equivalence confirmed")
```

## Key Details

**Input conversion:** Use `eng.single(numpy_array)` to pass data to MATLAB as
single precision. The MATLAB Engine handles the numpy-to-MATLAB conversion.

**Output conversion:** The returned MATLAB array converts to numpy via
`np.array(y_matlab).astype(np.float32)`.

**Tolerance values:**
- Absolute tolerance: `1e-5` (standard for single-precision inference)
- Relative tolerance: `1e-4` (allows for accumulated floating-point differences)
- Epsilon `1e-12` in denominator prevents division by zero

**Shape matching:** If output shapes don't match between Python and MATLAB,
reshape the MATLAB output to match. PyTorchExportedProgram preserves PyTorch's
dimension ordering, so shapes should align without permutation.

## When to Use

- After loading a model with `loadPyTorchExportedProgram` for the first time
- Before proceeding to MEX generation (confirm the model loaded correctly)
- When debugging unexpected inference results

## Prerequisites

- `matlabengine` Python package (installed from MATLAB: `cd /path/to/matlab/extern/engines/python && pip install .`)
- PyTorch installed in the same Python environment
- The `.pt2` file accessible from both Python and MATLAB

----

Copyright 2026 The MathWorks, Inc.

----
