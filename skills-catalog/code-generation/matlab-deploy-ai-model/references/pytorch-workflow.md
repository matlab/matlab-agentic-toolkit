# Generate C/C++/CUDA Code from a PyTorch Model

Complete workflow for generating C/C++ or CUDA code from a PyTorch ExportedProgram
(.pt2) using the MATLAB Coder Support Package for PyTorch and LiteRT Models (R2026a+).

## Critical: API Routing

Two completely different pipelines exist. Choose based on the goal:

| | Deep Learning Toolbox path (editable dlnetwork) | MATLAB Coder Support Package for PyTorch and LiteRT Models (code generation) |
|---|---|---|
| Load | `importNetworkFromPyTorch` | `loadPyTorchExportedProgram` |
| Object | `dlnetwork` | `PyTorchExportedProgram` |
| Inference | `predict(net, dlarray(...))` | `invoke(model, input)` |
| Codegen | `coder.loadDeepLearningNetwork` + `DeepLearningConfig` | Direct `codegen` with entry-point |
| Data layout (2-D images) | HWCN (MATLAB convention) | NCHW (PyTorch convention preserved) |
| Since | R2022b | R2026a |
| Use for | Quantization, compression, transfer learning (DLT tools) | C/C++/CUDA code generation |

**Rule:** If generating code is the primary goal, use the MATLAB Coder Support
Package for PyTorch and LiteRT Models path. Do not use `importNetworkFromPyTorch`,
`coder.loadDeepLearningNetwork`, or `dlarray` for such workflows unless explicitly
requested.

## Export PyTorch Model (if user doesn't have .pt2 yet)

If the user has a PyTorch model but hasn't exported it to `.pt2` format, use
the `export-pytorch-models` reference for the full `torch.export` workflow
(covers HuggingFace, torchvision, timm, torchbench sources and known serialization issues).

## Load and Inspect

```matlab
model = loadPyTorchExportedProgram("model.pt2");
summary(model)
inSpecs = model.inputSpecifications;
outSpecs = model.outputSpecifications;
```

Use `inputSpecifications` to determine the expected input shape and type.
The model preserves PyTorch's NCHW layout — see `pytorch-data-layout.md`.

## Entry-Point Pattern

The standard entry-point for PyTorch model codegen:

```matlab
function out = mInvoke(networkPath, input) %#codegen
    net = loadPyTorchExportedProgram(networkPath);
    out = invoke(net, input);
end
```

**Why `coder.Constant` in the codegen call:** The model file path must be known at
compile time so the code generator can resolve the model at build time.

**Note on `coder.DeepLearningConfig`:** The MATLAB Coder Support Package for
PyTorch and LiteRT Models path ignores this setting. It generates code directly
from the PyTorchExportedProgram without requiring an external deep learning library.
Setting it won't cause errors but has no effect.

## Generate MEX

**CPU MEX:**

```matlab
cfg = coder.config("mex");
input = ones(1, 3, 224, 224, "single");  % match model's inputSpecifications
codegen -config cfg -args {coder.Constant("model.pt2"), input} mInvoke
```

**CUDA MEX (GPU acceleration):**

```matlab
cfg = coder.gpuConfig("mex");
input = ones(1, 3, 224, 224, "single");  % match model's inputSpecifications
codegen -config cfg -args {coder.Constant("model.pt2"), input} mInvoke
```

Key points:
- `coder.Constant` makes the model filename a compile-time constant
- Input shape must match `inputSpecifications` exactly (NCHW, not HWC)

## Verify MEX Output

```matlab
refOut = mInvoke("model.pt2", input);
mexOut = mInvoke_mex("model.pt2", input);
testCase = matlab.unittest.TestCase.forInteractiveUse;
testCase.verifyThat(mexOut, matlab.unittest.constraints.IsEqualTo(refOut, ...
    'Within', matlab.unittest.constraints.AbsoluteTolerance(single(1e-5))));
```

## Generate Library/Executable

Once MEX is verified, generate production code:

```matlab
cfgLib = coder.config("lib");
codegen -config cfgLib -args {coder.Constant("model.pt2"), input} mInvoke
```

For DLL: `coder.config("dll")`. For executable: `coder.config("exe")`.

**CUDA library/executable:**

```matlab
cfgLib = coder.gpuConfig("lib");
codegen -config cfgLib -args {coder.Constant("model.pt2"), input} mInvoke
```

For CUDA DLL: `coder.gpuConfig("dll")`. For CUDA executable: `coder.gpuConfig("exe")`.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `importNetworkFromPyTorch("model.pt2")` | Returns `dlnetwork` (DLT path), cannot use `invoke` or codegen may fail | `loadPyTorchExportedProgram("model.pt2")` |
| `coder.loadDeepLearningNetwork(...)` | DLT codegen API, not compatible with PyTorchExportedProgram | Use `loadPyTorchExportedProgram` in the entry-point directly |
| `predict(net, dlarray(x, 'BCSS'))` | DLT inference API with dlarray wrapping | `invoke(model, x)` — no dlarray needed |
| `coder.DeepLearningConfig('mkldnn')` | Ignored by the MATLAB Coder Support Package for PyTorch and LiteRT Models path | Optional — has no effect on PyTorchExportedProgram codegen |
| Input shape `[224, 224, 3]` (HWC) from `imread` | PyTorchExportedProgram preserves NCHW | Permute to `[1, 3, 224, 224]` (check `inputSpecifications`) |
| Saving to `.mat` before codegen | Unnecessary intermediate step | Pass .pt2 path via `coder.Constant` directly |
| Omitting `coder.Constant` for model path | Codegen needs model path at compile time | Always wrap model path: `coder.Constant("model.pt2")` |
| Using `classify()` on the model | `classify` is for `dlnetwork`/`SeriesNetwork`, not `PyTorchExportedProgram` | Use `invoke(model, input)` |

## Conventions

- Always use `loadPyTorchExportedProgram` for code generation workflows
- Always check `inputSpecifications` for correct input shape and type
- Always generate MEX first, verify, then proceed to lib/exe
- Always use `coder.Constant` for the model file path argument
- Input data is single-precision by default (check `inputSpecifications` to confirm)
- Do NOT use `importNetworkFromPyTorch`, `coder.loadDeepLearningNetwork`, `dlarray`, `predict`, or `classify` in code generation workflows

## Detailed References

- `pytorch-api-reference.md` — Full API signatures and properties for
  `loadPyTorchExportedProgram` and `PyTorchExportedProgram`.
- `pytorch-numeric-verification.md` — MATLAB Engine for Python pattern for
  comparing PyTorch vs MATLAB outputs.
- `pytorch-data-layout.md` — NCHW vs HWC layout explanation and permutation
  patterns for PyTorch models.
- `pytorch-supported-models.md` — Model constraints, PyTorch version requirements,
  execution modes, and troubleshooting.

----

Copyright 2026 The MathWorks, Inc.

----
