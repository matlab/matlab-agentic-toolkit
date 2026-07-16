# Exporting PyTorch Models to .pt2

Convert eager-mode PyTorch models to ExportedProgram format (`.pt2`) using
`torch.export`, so `loadPyTorchExportedProgram` can consume them for code
generation. This reference covers the common model sources and resolves the
export issues seen in practice.

Use this when the user has a PyTorch model but does not yet have a `.pt2`
file, or when they hit `torch.export` `SerializeError` / kwarg-mismatch errors
while exporting.

## When this applies

To generate C/C++/CUDA code from a PyTorch model with MATLAB Coder, the model
must first be converted to a PyTorch ExportedProgram (`.pt2`) — the standardized
intermediate representation the MATLAB Coder Support Package for PyTorch and
LiteRT Models consumes. This reference guides exporting the model correctly in
Python, handling source-specific quirks (HuggingFace attention, dict inputs,
torchbench wrappers), and resolving version-specific serialization issues so the
resulting `.pt2` is ready for loading into MATLAB.

Note that `importNetworkFromPyTorch` (the Deep Learning Toolbox import path,
which builds an editable `dlnetwork`) can also accept a `.pt2` exported program,
so the export step here applies to that workflow too — but consuming the `.pt2`
via `importNetworkFromPyTorch` is not covered in this reference, which targets
the MATLAB Coder codegen consumer (`loadPyTorchExportedProgram`). This reference
also does not cover LiteRT / ONNX models, which have their own import paths.

## Prerequisites

- **PyTorch 2.7.0 or later** — see the PyTorch version requirement in
  `pytorch-supported-models.md`
- **Python 3.10+** recommended
- Additional packages as needed: `timm`, `transformers`, `torchvision`

Before running any export script, ask the user for the path to their Python
virtual environment with the required packages (torch, and optionally
transformers/timm/torchvision depending on the model source). Activate it before
executing export code. Always ask the user for confirmation before running any
`pip install` commands.

## Pick a pattern

Per-source export templates live in `pytorch-export-patterns.md`:

| Source                                             | Pattern |
|----------------------------------------------------|---------|
| Whole-model file (e.g. `.pth` / `.pt`, loadable as `nn.Module`) | `FULL_MODEL_PTH` |
| HuggingFace `AutoModel` / `AutoModelForX`          | `HF_AUTOMODEL` (`attn_implementation="eager"`) |
| torchvision built-in models                        | `TORCHVISION` |
| timm                                               | `TIMM` |
| `.pth` containing only state_dict                  | `STATE_DICT` (instantiate arch first) |
| Models with dict inputs or dataclass outputs       | `TENSOR_WRAPPER` |

## Diagnostic triggers

- **Consumer fails with "kwarg keyword mismatch"**: dict-typed example inputs
  were exported as kwargs. Wrap with `TensorOutputWrapper(model, kwarg_names=...)`.
  → `TENSOR_WRAPPER` in `pytorch-export-patterns.md`.
- **`SerializeError: Serializing <function _add_batch_dim> is not supported`**:
  vmap/predispatch artifacts. Add `ep = ep.run_decompositions({})` after
  `eliminate_dead_code()`. → `pytorch-export-gotchas.md`.
- **`SerializeError` on dead `lazy_load_decompositions` node**: torch 2.11
  predispatch bug. Fix: `ep.graph.eliminate_dead_code()` before
  `torch.export.save()`. → `pytorch-export-gotchas.md`.
- **`torch.export.load` fails with "We ran into an error when deserializing"**:
  HF dataclass output not flattened to tensors. Wrap with `TensorOutputWrapper`.
  → `TENSOR_WRAPPER`.
- **`torch.load` on a `.pth` fails with `AttributeError: Can't get attribute
  '<Class>' on <module 'transformers.models...'>`**: the pickle references
  an attention class from an older `transformers` version that has since
  been renamed or removed (e.g. `Dinov2SdpaAttention` /
  `Dinov2SdpaSelfAttention` on `transformers` ≥ 5.x). Install the version
  that introduced the class (DINOv2 / Depth Anything:
  `pip install "transformers==4.45.0"`) and re-run the export. Prefer
  re-exporting from `from_pretrained` (`HF_AUTOMODEL`) when possible.
  → "HuggingFace pickle: version-mismatched attention classes" in
  `pytorch-export-gotchas.md`.
- **Bulk-validating exports**: see "Always validate after export" in
  `pytorch-export-gotchas.md`.

## References

- `pytorch-export-patterns.md` — Per-source export templates (HF, torchvision,
  timm, state_dict, dict-input/dataclass-output wrapper).
- `pytorch-export-gotchas.md` — Critical rules, post-export validation, and
  torch 2.11 known serialization limitations with fixes.

----

Copyright 2026 The MathWorks, Inc.

----
