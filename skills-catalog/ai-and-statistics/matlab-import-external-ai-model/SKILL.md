---
name: matlab-import-external-ai-model
description: >
  Import PyTorch, ONNX, or Keras 3 / TensorFlow 2.16+ deep learning models into
  MATLAB as dlnetwork objects. Use when importing .pt2 exported programs, traced
  .pt files, .onnx models, or Keras 3 models via matlabsaver. Covers
  importNetworkFromPyTorch, importNetworkFromONNX, importNetworkFromKeras,
  importNetworkFromTensorFlow, torch.export.export, PyTorchInputSizes,
  InputDataFormats, matlabsaver, tf_keras downgrade, numeric validation against
  PyTorch or ONNX Runtime, and placeholder/custom layer implementation. Applies
  when user mentions any of these functions, file formats, or encounters import
  errors, unsupported operator warnings, 0 learnables, or uninitialized networks.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Import Deep Learning Models into MATLAB

Import trained PyTorch, ONNX, or Keras 3 models into MATLAB as `dlnetwork`
objects and verify numerical correctness.

## When to Use

- User wants to import a deep learning model from PyTorch, ONNX, or Keras/TensorFlow
- User has `.pt2`, `.pt`, `.onnx`, or `.keras` files to bring into MATLAB
- User mentions `importNetworkFromPyTorch`, `importNetworkFromONNX`, `importNetworkFromKeras`, or `importNetworkFromTensorFlow`
- User mentions `torch.export.export`, `torch.jit.trace`, `PyTorchInputSizes`, `InputDataFormats`, or `matlabsaver`
- User encounters import errors, unsupported operator warnings, uninitialized networks, or 0 learnables after import
- User wants to validate that an imported model matches the source framework's outputs

## When NOT to Use

- Exporting MATLAB networks to ONNX/PyTorch (use `exportONNXNetwork` / `exportNetworkToPyTorch`)
- Training or fine-tuning after import — use `/matlab-train-network`
- Deploying to embedded hardware — use `/matlab-deploy-embedded-ai`
- Simulink integration after import (agent handles this well without guidance)

## Router: Which Framework?

```
Q: What format is the source model?
 |
 +-- .pt2 (PyTorch exported program) ──────────> PYTORCH IMPORT below
 +-- .pt (PyTorch traced model) ───────────────> PYTORCH IMPORT below
 +-- .onnx ────────────────────────────────────> ONNX IMPORT below
 +-- .keras / TensorFlow 2.16+ / matlabsaver ──> KERAS IMPORT below
 +-- Unknown ("import my model") ──────────────> Ask: framework? file extension?
```

---

## PyTorch Import

Full pipeline: export from PyTorch → import into MATLAB → validate numerics.

### Determine Starting Point

| User has | Action |
|----------|--------|
| PyTorch model (code or saved) | Export as .pt2 first → see `references/pytorch-export-guidance.md` |
| `.pt2` file (exported program) | Import directly (below) |
| `.pt` file (traced model) | Import with input sizes (below) |

**Always prefer .pt2 over .pt.** If user has a traced model, recommend re-exporting
with `torch.export.export` first. Only use traced path if re-export is not feasible.

### Import .pt2 (Exported Program)

```matlab
net = importNetworkFromPyTorch("model.pt2");
```

No input size argument needed — shape info is embedded in the .pt2 file.

### Import .pt (Traced Model)

```matlab
net = importNetworkFromPyTorch("model.pt", ...
    PyTorchInputSizes=[1 3 224 224]);
```

`PyTorchInputSizes` is **mandatory** for traced models. Specify sizes in PyTorch
dimension ordering. For multiple inputs use a cell array: `{[1 3 256 256], [1 10]}`.

### Name-Value Arguments

| Argument | When to use |
|----------|-------------|
| `PyTorchInputSizes` | **Required** for traced models (.pt). Not needed for .pt2 |
| `Namespace` | Control where auto-generated custom layer files are stored |
| `PreferredNestingType` | Choose `"networklayer"` (default) or `"customlayer"` |

### PyTorch Critical Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Using `InputShape` NV argument | Does not exist — use `PyTorchInputSizes` for .pt, nothing for .pt2 |
| Using `PackageName` NV argument | Deprecated — use `Namespace` |
| Not calling `model.to("cpu")` before export | Always `model.to("cpu")` before export |
| Not checking PyTorch version before export | Assert `torch.__version__` starts with "2.8" |
| Passing `PyTorchInputSizes` for .pt2 | Unnecessary — .pt2 embeds shape info, omit it |
| Guessing input size for unknown models | Always ask the user for exact input dimensions |
| Assuming `net.InputNames` matches `forward()` order | Importer may reorder — always check `net.InputNames` |

### PyTorch Conventions

- Always `model.to("cpu")` and `model.eval()` before export
- Always verify PyTorch version is 2.8 before exporting as .pt2
- Never guess input sizes — ask the user or inspect the model
- Use `Namespace` not `PackageName` for custom layer storage
- Prefer .pt2 over .pt — recommend `torch.export.export` over `torch.jit.trace`

### PyTorch References

- `references/pytorch-export-guidance.md` — Full Python-side export procedure
- `references/pytorch-import-guidance.md` — Detailed MATLAB import for both formats
- `references/pytorch-numeric-validation.md` — Dimension conversion and tolerance comparison
- `references/pytorch-placeholder-guidance.md` — Implementing unsupported ops in custom layers
- `scripts/validateImportedNetwork.m` — Helper function for numeric validation against .npy reference data

---

## ONNX Import

Import ONNX models using `importNetworkFromONNX`, diagnose issues, verify numerics.

### Workflow

```
1. IMPORT  → importNetworkFromONNX with appropriate NVPs
2. DIAGNOSE → Check initialization, custom layers, warnings
3. RESOLVE  → Fix issues (InputDataFormats, placeholder functions)
4. VERIFY   → Compare outputs against ONNX Runtime (if installed)
```

**CRITICAL: Do NOT re-import after step 3.** Re-importing regenerates `+ops/` and overwrites all custom implementations.

### Import

```matlab
net = importNetworkFromONNX("model.onnx");
```

If you know the input format:

```matlab
net = importNetworkFromONNX("model.onnx", InputDataFormats="BCSS");
```

### Diagnose and Resolve

If `net.Initialized` is false, read the input shape and re-import with `InputDataFormats`:

```matlab
net = importNetworkFromONNX("model.onnx");
if ~net.Initialized
    inputLayer = net.Layers(1);
    fprintf("NumDims: %d\n", inputLayer.NumDims);
end
```

### InputDataFormats Reference

Characters: `B` (batch), `C` (channel), `S` (spatial), `T` (time), `U` (unspecified).

| ONNX Input Shape | InputDataFormats |
|-----------------|------------------|
| [N, C, H, W] | `"BCSS"` |
| [N, C] | `"BC"` |
| [N, T, C] | `"BTC"` |
| [N, C, T] | `"BCT"` |

### Verify Against ONNX Runtime

If `onnxruntime` is installed in the user's Python environment, compare outputs. If not installed, skip — do not ask the user to install it.

```matlab
try
    ort = py.importlib.import_module("onnxruntime");
    ortAvailable = true;
catch
    ortAvailable = false;
end
```

See `references/onnx-validation-workflow.md` for the full comparison procedure.

### ONNX Critical Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Use `importONNXNetwork` or `importONNXLayers` | Legacy — always use `importNetworkFromONNX` |
| Re-import after implementing placeholders | Import once, then modify. Never re-import. |
| Guess InputDataFormats randomly | Read input shape from uninitialized network first |
| Skip numeric verification when ORT is available | Compare against ONNX Runtime if installed |

### ONNX Conventions

- Always use `importNetworkFromONNX` — never legacy APIs
- Verify numerically against ONNX Runtime after import (if installed)
- Never re-import after modifying network or implementing placeholders
- Use `dlarray` with explicit format strings: `dlarray(data, "SSCB")`
- Report max absolute difference and assert tolerance < 1e-4 for float32

### ONNX Reference

- `references/onnx-validation-workflow.md` — Full ORT comparison including multi-output models

---

## Keras Import

Import Keras 3 / TensorFlow 2.16+ models with full layer structure and learnables.

### Decision Tree

```
Q1: What MATLAB release is available?
 +-- R2026a or newer ──> PATH 1 (matlabsaver + importNetworkFromKeras)
 +-- R2025b or older ──> Q2
      Q2: Does the model use Keras 3-specific features? (keras.ops, multi-backend)
       +-- No (standard layers) ──> PATH 2 (tf_keras downgrade)
       +-- Yes ────────────────────> PATH 3 (ONNX export fallback)
```

### Path 1: matlabsaver + importNetworkFromKeras (R2026a+)

**Python:**
```python
import matlabsaver
matlabsaver.save_for_matlab(model, "exportedModelFolder")
```

Apply the config.json patch for Keras 3.10+ compatibility (see `references/keras-matlabsaver-workflow.md`).

**MATLAB:**
```matlab
net = importNetworkFromKeras("exportedModelFolder");
assert(numel(net.Learnables.Value) > 0, "Import failed: 0 learnables")
```

### Path 2: tf_keras Downgrade (Pre-R2026a, Standard Layers Only)

**Python:**
```python
import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"  # MUST be before importing TensorFlow
import tf_keras as keras
model.save("savedModelFolder")
```

**MATLAB:**
```matlab
net = importNetworkFromTensorFlow("savedModelFolder");
```

### Path 3: ONNX Export (Fallback)

Requires `tf2onnx` in the Python environment: `pip install tf2onnx`

**Python:**
```python
model.export("exportedModel.onnx", format="onnx")
```

**MATLAB:**
```matlab
net = importNetworkFromONNX("exportedModel.onnx");
```

### Keras Critical Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| `importNetworkFromKeras` fails with "Brace indexing..." | Keras 3.10+ changed config.json — apply the patch (see reference) |
| `model.export("folder")` then `importNetworkFromTensorFlow` | No keras_metadata.pb → 0 learnables. Use matlabsaver instead |
| `TF_USE_LEGACY_KERAS=1` set after `import tensorflow` | Must be set before any TF import |
| Using deprecated `importKerasNetwork` | Use `importNetworkFromKeras` (R2026a+) or Path 2/3 |

### Keras Conventions

- Always verify imported network has non-zero learnables
- Always check MATLAB release before choosing import path
- Prefer Path 1 > Path 2 > Path 3 (ordered by fidelity)
- Report number of layers and learnables after import

### Keras References

- `references/keras-matlabsaver-workflow.md` — Full matlabsaver procedure for R2026a+
- `references/keras-tf-keras-downgrade.md` — tf_keras setup for pre-R2026a

---

## Key Functions

| Function | Framework | Purpose |
|----------|-----------|---------|
| `importNetworkFromPyTorch` | PyTorch | Import .pt2 or .pt as dlnetwork |
| `importNetworkFromONNX` | ONNX | Import .onnx as dlnetwork |
| `importNetworkFromKeras` | Keras | Import Keras 3 folder as dlnetwork (R2026a+) |
| `importNetworkFromTensorFlow` | TF/Keras | Import TF SavedModel as dlnetwork |
| `torch.export.export` | PyTorch | Export model as .pt2 (Python) |
| `matlabsaver.save_for_matlab` | Keras | Export Keras 3 for MATLAB (Python) |
| `predict` | All | Run inference on imported dlnetwork |
| `dlarray` | All | Labeled multi-dimensional array for deep learning |

----

Copyright 2026 The MathWorks, Inc.

----
