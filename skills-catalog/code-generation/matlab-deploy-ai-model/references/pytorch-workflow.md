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

**Rule:** If the goal is to keep the model's source of truth in PyTorch and
generate code from it, use the MATLAB Coder Support Package for PyTorch and
LiteRT Models path (`loadPyTorchExportedProgram` + `invoke`). Do not use
`importNetworkFromPyTorch`, `coder.loadDeepLearningNetwork`, or `dlarray` on
this path — that path converts the PyTorch model to a `dlnetwork` first.

**If the user needs quantization (`dlquantizer`), projection, pruning, or
`exportNetworkToSimulink`** and is OK with translating the model to a
`dlnetwork` using the Deep Learning Toolbox, then route to the
`matlab-deploy-embedded-ai` skill (Pattern 1), which covers
`dlnetwork`-based workflows.

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

## Code Generation (MEX, Library, Executable)

For the full codegen workflow (MEX generation, verification, library/executable
targets, `coder.Constant` usage, and `coder.DeepLearningConfig` notes), see
`codegen-workflow.md`.

Quick reference — CPU MEX:

```matlab
cfg = coder.config("mex");
input = ones(1, 3, 224, 224, "single");  % NCHW — match inputSpecifications
codegen -config cfg -args {coder.Constant("model.pt2"), input} mInvoke
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `importNetworkFromPyTorch("model.pt2")` on this skill's codegen path | Returns a `dlnetwork` (DLT path) — cannot use `invoke`, and codegen from a `dlnetwork` follows a different pipeline than the one this skill documents | Use `loadPyTorchExportedProgram("model.pt2")` for `.pt2` codegen. If a `dlnetwork` is required for quantization/projection/pruning/`exportNetworkToSimulink`, route to `matlab-deploy-embedded-ai` |
| `coder.loadDeepLearningNetwork(...)` | DLT codegen API, not compatible with PyTorchExportedProgram | Use `loadPyTorchExportedProgram` in the entry-point directly |
| `predict(net, dlarray(x, 'BCSS'))` | DLT inference API with dlarray wrapping | `invoke(model, x)` — no dlarray needed |
| `coder.DeepLearningConfig('mkldnn')` | Ignored by the MATLAB Coder Support Package for PyTorch and LiteRT Models path | Optional — has no effect on PyTorchExportedProgram codegen |
| Input shape `[224, 224, 3]` (HWC) from `imread` | PyTorchExportedProgram preserves NCHW | Permute to `[1, 3, 224, 224]` (check `inputSpecifications`) |
| Saving to `.mat` before codegen | Unnecessary intermediate step | Pass .pt2 path via `coder.Constant` directly |
| Omitting `coder.Constant` for model path | Codegen needs model path at compile time | Always wrap model path: `coder.Constant("model.pt2")` |
| Using `classify()` on the model | `classify` is for `dlnetwork`/`SeriesNetwork`, not `PyTorchExportedProgram` | Use `invoke(model, input)` |

## Conventions

- Always use `loadPyTorchExportedProgram` for `.pt2` code generation workflows
- PyTorch models use NCHW layout — do not feed HWC data without permuting
- Do NOT use `importNetworkFromPyTorch`, `coder.loadDeepLearningNetwork`, `dlarray`, `predict`, or `classify` on this skill's `.pt2` codegen path. If the user needs a `dlnetwork` for quantization/projection/pruning or `exportNetworkToSimulink` prior to codegen, route to the `matlab-deploy-embedded-ai` skill
- For shared conventions (MEX-first, `coder.Constant`, verify before lib), see `codegen-workflow.md`

## Detailed References

- `codegen-workflow.md` — Shared codegen steps: MEX generation, verification,
  library/executable targets, `coder.Constant`, `coder.DeepLearningConfig`.
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
