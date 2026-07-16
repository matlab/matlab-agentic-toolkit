# torch.export Gotchas, Workarounds, and Known Limitations

## Critical rules (apply to every export)

- **Move model and tensors to CPU before export** — the MATLAB Coder codegen pipeline requires the exported program to be on CPU. Call `model.cpu()` and ensure input tensors are created on or moved to CPU before calling `torch.export.export()`:
  ```python
  model = model.cpu()
  inputs = (torch.randn(1, 3, 224, 224, device='cpu'),)
  ep = torch.export.export(model, inputs, strict=False)
  ```
- **`strict=False` is the default since torch 2.8** — you do not need to pass it explicitly on modern PyTorch. On older versions (< 2.8), pass `strict=False` when models have control flow (if/else on tensor shapes, data-dependent ops).
- **Always use `model.eval()`** — export in inference mode, not training mode.
- **HF dataclass outputs must be flattened to tensors before export** —
  see the `TENSOR_WRAPPER` pattern's `TensorOutputWrapper`. Without this, `.pt2` files
  serialize fine but fail on `torch.export.load` with
  *"We ran into an error when deserializing the saved file"*.
- **Dict-input models need `TensorOutputWrapper`** — `loadPyTorchExportedProgram` feeds positional args to the loaded program. If `example_inputs` is a dict, wrap with `TensorOutputWrapper(model, kwarg_names=...)` to convert to a positional signature. See the `TENSOR_WRAPPER` pattern in `pytorch-export-patterns.md`.

## Always validate after export

Example (sizes are model-dependent):

```python
loaded = torch.export.load('model.pt2')
out = loaded.module()(torch.randn(1, 3, 224, 224))
```

Bulk check:

```python
import torch, os
export_dir = '/path/to/exported/'
for f in sorted(os.listdir(export_dir)):
    if f.endswith('.pt2'):
        try:
            ep = torch.export.load(os.path.join(export_dir, f))
            print(f"OK: {f}")
        except Exception as e:
            print(f"FAIL: {f} — {e}")
```

## HuggingFace pickle: version-mismatched attention classes

`.pth` files pickled from a HuggingFace model reference the exact attention
class names that existed in `transformers` when the pickle was saved. If the
class has since been renamed or removed, `torch.load` fails with:

```
AttributeError: Can't get attribute '<ClassName>' on
<module 'transformers.models.<arch>.modeling_<arch>' ...>
```

Wrapping the loader (e.g. redefining a placeholder class) does not fix this
— the pickle still binds to the original module path and the class body is
not restored.

**Fix:** install the `transformers` version that first shipped the missing
class, then re-run the export in that environment.

**Known cases:**

| Missing class | Model family | Introduced in `transformers` |
|---------------|--------------|------------------------------|
| `Dinov2SdpaAttention`, `Dinov2SdpaSelfAttention` | DINOv2 / Depth Anything | 4.45.0 |

For DINOv2-based `.pth` files (e.g. Depth Anything) that pickled
`Dinov2SdpaAttention`:

```bash
pip install "transformers==4.45.0"
```

To find the right version for a class not listed above, scan the transformers
changelog or `git log --oneline transformers/models/<arch>/modeling_<arch>.py`
for the class name — the first commit introducing it identifies the minimum
compatible version.

Prefer re-exporting from `from_pretrained` (see `HF_AUTOMODEL` in
`pytorch-export-patterns.md`) when possible — it avoids the pickle path
entirely and sidesteps this class of failure.

## Known torch.export 2.11 limitations

### `lazy_load_decompositions` dead-node SerializeError

torch 2.11 predispatch inserts `torch._functorch.predispatch.lazy_load_decompositions`
calls with **zero users** that the serializer rejects. Fix: call
`ep.graph.eliminate_dead_code()` before `torch.export.save()`:

```python
ep = torch.export.export(module, args, strict=False)
ep.graph.eliminate_dead_code()   # prune dead predispatch nodes
torch.export.save(ep, "model.pt2")
```

### `_add_batch_dim` / `_remove_batch_dim` SerializeError (vmap predispatch)

Models using `vmap`/`functorch` internally insert live
`torch._functorch.predispatch._add_batch_dim` / `_remove_batch_dim`
nodes that the serializer cannot handle. Symptom: `SerializeError:
Serializing <function _add_batch_dim> is not supported`.

Fix: call `ep = ep.run_decompositions({})` **if and only if**
`torch.export.save()` raises `SerializeError` or `torch.export.load()`
fails on the saved file. It is safe to add unconditionally once the
issue is seen (no-op for unaffected models). Apply after
`eliminate_dead_code()`:

```python
ep = torch.export.export(module, args, strict=False)
ep.graph.eliminate_dead_code()
ep = ep.run_decompositions({})   # only if SerializeError or load fails
torch.export.save(ep, "model.pt2")
```

This affects any model whose graph contains `vmap`/`functorch` batch-dim
nodes.

----

Copyright 2026 The MathWorks, Inc.

----

