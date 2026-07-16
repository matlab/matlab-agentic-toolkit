# Numeric Validation After Import

## Overview

After importing a PyTorch model, validate that the MATLAB dlnetwork produces
the same outputs as the original PyTorch model for identical inputs.

## Step 1: Generate Reference Data (Python side)

```python
import torch
import numpy as np

model.eval()
model.to("cpu")

# Use deterministic input
torch.manual_seed(42)
x = torch.randn(1, 3, 224, 224)  # Replace with actual input shape

with torch.no_grad():
    y = model(x)

# Save as .npy for MATLAB consumption
np.save("reference_input.npy", x.numpy())
np.save("reference_output.npy", y.numpy())
```

## Step 2: Load Reference Data in MATLAB

Use a .npy reader or `readmatrix` if saved as CSV. For .npy files:

```matlab
refInput = readNPY("reference_input.npy");
refOutput = readNPY("reference_output.npy");
```

## Step 3: Convert Dimensions

PyTorch and MATLAB use different dimension orderings. The conversion depends
on the input rank:

### 4D Image Data

| Framework | Format | Dimension order |
|-----------|--------|----------------|
| PyTorch | BCSS | batch, channels, spatial, spatial |
| MATLAB dlarray | SSCB | spatial, spatial, channels, batch |

```matlab
% PyTorch BCSS [1, 3, 224, 224] → MATLAB SSCB [224, 224, 3, 1]
inputMATLAB = permute(refInput, [3, 4, 2, 1]);
dlIn = dlarray(single(inputMATLAB), 'SSCB');
```

### 2D Feature Data

| Framework | Format | Dimension order |
|-----------|--------|----------------|
| PyTorch | BC | batch, channels |
| MATLAB dlarray | CB | channels, batch |

```matlab
% PyTorch BC [1, 128] → MATLAB CB [128, 1]
inputMATLAB = refInput';
dlIn = dlarray(single(inputMATLAB), 'CB');
```

### General Rule

For data without a recognized labeled format (unlabeled / `U` dimensions), the
converter stores tensors in PyTorch dimension order. No permutation is needed —
pass reference data directly with `"U"` format labels:

```matlab
% For a 3D tensor, use 'UUU'; for 4D use 'UUUU'; etc.
dlIn = dlarray(single(refInput), repmat('U', 1, ndims(refInput)));
```

### Recognized dlarray Format Labels

The converter uses these labeled formats (MATLAB → PyTorch permutation):

| MATLAB format | Dimensions | PyTorch equivalent |
|---------------|------------|--------------------|
| `SSCB` | H, W, C, N | BCSS (4D images) |
| `SSC` | H, W, C | CSS (3D unbatched images) |
| `SSSCB` | H, W, D, C, N | BCSSS (5D volumetric) |
| `CB` | C, N | BC (2D features) |
| `SCBT` | S, C, B, T | BCTS (4D sequences) |
| `BT` | B, T | BT (2D temporal) |

If your imported network uses labeled dlarrays, permute reference data to match
the MATLAB format. If unlabeled (`U`), the data is already in PyTorch order —
no permutation needed.

## Step 4: Run MATLAB Inference

```matlab
dlOut = predict(net, dlIn);
matlabOutput = extractdata(dlOut);
```

## Step 5: Compare Outputs

Convert MATLAB output back to PyTorch ordering for comparison:

```matlab
% For 2D output [classes, batch] → [batch, classes]
matlabOutput = double(matlabOutput');

% Compare
absDiff = abs(matlabOutput - double(refOutput));
maxAbsDiff = max(absDiff(:));
meanAbsDiff = mean(absDiff(:));

fprintf("Max absolute difference:  %.2e\n", maxAbsDiff);
fprintf("Mean absolute difference: %.2e\n", meanAbsDiff);
```

## Tolerances

| Precision | Recommended tolerance | Notes |
|-----------|---------------------|-------|
| float32 | 1e-5 to 1e-4 | Typical for most models |
| float16 | 1e-3 | Half-precision has larger rounding |
| Complex models (transformers) | 1e-4 | Accumulated precision differences |

```matlab
tolerance = 1e-5;
if maxAbsDiff < tolerance
    fprintf("[PASS] Numeric validation passed.\n");
else
    fprintf("[FAIL] Max difference %.2e exceeds tolerance %.2e\n", ...
        maxAbsDiff, tolerance);
end
```

## Troubleshooting Numeric Mismatches

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Completely wrong output | Dimension conversion error | Check permutation matches input format |
| Small differences (1e-6 to 1e-4) | Float32 precision | Expected — loosen tolerance |
| Large differences (>1e-2) | Model not in eval mode during export | Re-export with `model.eval()` |
| Some samples match, others don't | Batch normalization | Ensure eval mode (disables running stats) |
| Output shape mismatch | Wrong input size used for export | Re-export with correct example input |

----

Copyright 2026 The MathWorks, Inc.

----
