# Supported Models and Limitations

## Supported Model Types

`loadPyTorchExportedProgram` supports models exported with `torch.export.export()`
to the `.pt2` format. This includes:

- Convolutional networks (ResNet, VGG, MobileNet, EfficientNet)
- Recurrent networks (LSTM, GRU)
- Transformer models (encoder/decoder architectures)
- Custom models using supported operators
- Sequence-to-sequence models
- Classification, detection, segmentation models

## PyTorch Version Requirement

The required PyTorch version depends on the MATLAB release:

| MATLAB Release | PyTorch Version | Notes |
|---------------|----------------|-------|
| R2026a | 2.7.0 – 2.8.0 (stable releases only) | Any stable release in this range |

The export uses `torch.export.export()` which produces the ExportedProgram
format (.pt2).

## Execution Modes

| Mode | Description | Trade-off |
|------|-------------|-----------|
| `"JIT"` (default) | Just-in-time compilation | Faster load time, but no OpenMP parallelization — lower inference performance |
| `"MEX"` | MEX-based execution | Slower initial compilation, but leverages OpenMP for better inference performance, requires C compiler |

```matlab
% Faster to load, slower inference (no parallelization)
model = loadPyTorchExportedProgram("model.pt2", ExecutionMode="JIT");

% Slower initial compile, faster inference (OpenMP parallelization)
model = loadPyTorchExportedProgram("model.pt2", ExecutionMode="MEX");
```

Choose `"MEX"` when inference performance matters. Choose `"JIT"` for quick
prototyping where load time is more important than execution speed.

## Known Limitations

| Limitation | Description |
|-----------|-------------|
| No MAT-file saved models | Cannot save `PyTorchExportedProgram` to a MAT-file and reload |
| No quantized models | INT8/quantized PyTorch models are not supported |
| No complex dtypes | Complex-valued tensors are not supported |
| No CUDA-exported tensors | Models must be exported on CPU (`model.cpu()` before export) |
| No custom output classes | Model output must be standard tensors, not custom Python objects |
| Single-device only | Multi-GPU or distributed models must be consolidated to single device |

## Unsupported Operations

When code generation encounters an unsupported operator:

1. **Named operator in error message** (e.g., "operator X is not supported"):
   - The only workaround is to restructure the PyTorch model to avoid that operator
   - This may not always be feasible depending on the model architecture
   - Check if an equivalent supported operator exists

2. **Unnamed/unclear error** (e.g., internal assertion, cryptic error):
   - This is likely a bug in the support package
   - Report to MathWorks Technical Support
   - Provide the .pt2 file and the full error message

## Code Generation Support

| Target | Supported |
|--------|-----------|
| MEX (desktop) | Yes |
| Static library (lib) | Yes |
| Dynamic library (dll) | Yes |
| Executable (exe) | Yes |
| Embedded Coder (ERT) | Yes |
| GPU Coder (CUDA) | Yes |

## Required Add-On

**MATLAB Coder Support Package for PyTorch and LiteRT Models**

Install via Add-On Explorer or:

```matlab
matlab.addons.install("MATLAB Coder Support Package for PyTorch and LiteRT Models")
```

Verify installation:

```matlab
ver('coder')  % MATLAB Coder must be installed
% Support package presence confirmed if loadPyTorchExportedProgram resolves
which loadPyTorchExportedProgram
```

----

Copyright 2026 The MathWorks, Inc.

----
