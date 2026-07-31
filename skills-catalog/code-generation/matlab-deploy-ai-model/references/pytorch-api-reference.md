# PyTorchExportedProgram API Reference

## loadPyTorchExportedProgram

Loads a PyTorch ExportedProgram (.pt2) file into MATLAB.

```matlab
model = loadPyTorchExportedProgram(modelFileName)
model = loadPyTorchExportedProgram(modelFileName, ExecutionMode=mode)
```

**Arguments:**

| Argument | Type | Description |
|----------|------|-------------|
| `modelFileName` | char vector or string | Path to the `.pt2` file |
| `ExecutionMode` (name-value) | `"JIT"` or `"MEX"` | Simulation behavior. `"JIT"`: faster load, no OpenMP. `"MEX"`: slower initial compile, requires a host C compiler, OpenMP parallelization for better performance. Default: `"JIT"` |

**Returns:** `PyTorchExportedProgram` object

**Introduced:** R2026a

## PyTorchExportedProgram Object

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `ModelPath` | char vector | Absolute path to the loaded .pt2 file |
| `FcnNames` | cell array of char vectors | Function names defined in the model |

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `invoke` | `out = invoke(model, input)` | Run forward inference |
| `inputSpecifications` | `specs = model.inputSpecifications` | Return input specs struct (Name, Size, Type) |
| `outputSpecifications` | `specs = model.outputSpecifications` | Return output specs struct (Name, Size, Type) |
| `summary` | `summary(model)` | Display input/output specifications to command window |

### invoke

Performs forward inference on the model.

```matlab
output = invoke(model, input);
```

- Input must match the shape and type reported by `inputSpecifications`
- Data layout is preserved from PyTorch — see `pytorch-data-layout.md` for details
- Output shape and type match `outputSpecifications`
- Supports C/C++ code generation (MATLAB Coder) and GPU code generation (GPU Coder)

### inputSpecifications / outputSpecifications

Returns a struct with fields:

| Field | Type | Description |
|-------|------|-------------|
| Name | cell array of char vectors | Tensor names from the PyTorch model |
| Size | cell array of numeric arrays | Dimensions of each tensor |
| Type | cell array of char vectors | MATLAB data type (e.g., `'single'`) |

Example:

```matlab
model = loadPyTorchExportedProgram("resnet18.pt2");
inSpecs = model.inputSpecifications;
% inSpecs.Size{1} might be [1 3 224 224]
% inSpecs.Type{1} might be 'single'
```

## Requirements

- MATLAB Coder Support Package for PyTorch and LiteRT Models (add-on)
- PyTorch 2.7.0–2.8.0 for R2026a
- The `.pt2` file must be accessible at the path specified during codegen

----

Copyright 2026 The MathWorks, Inc.

----
