# Export Patterns by Model Source

Six patterns covering the model-loading entry points encountered in
practice. Pick the one matching your source. Each pattern has a stable ID
(shown in its heading) — cross-references elsewhere in the skill use these
IDs rather than positional numbers.

## FULL_MODEL_PTH — Full model .pth (simplest case)

```python
import torch

model = torch.load('model.pth', map_location='cpu', weights_only=False)
model = model.cpu()
model.eval()
inputs = (torch.randn(1, 3, 224, 224, device='cpu'),)
exported = torch.export.export(model, inputs, strict=False)
torch.export.save(exported, 'model.pt2')
```

## HF_AUTOMODEL — HuggingFace models (most reliable)

Use `from_pretrained` — avoids pickle issues with SDPA attention and ensures correct architecture instantiation.

```python
import torch
from transformers import AutoModel

model = AutoModel.from_pretrained("bert-base-uncased", attn_implementation="eager")
model = model.cpu()
model.eval()
inputs = (torch.randint(0, 30522, (1, 128)),)
exported = torch.export.export(model, inputs, strict=False)
torch.export.save(exported, 'bert.pt2')
```

Key: `attn_implementation="eager"` prevents SDPA class which can't be exported.

## TORCHVISION — torchvision models

```python
import torch
import torchvision.models as models

model = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.DEFAULT)
model = model.cpu()
model.eval()
inputs = (torch.randn(1, 3, 224, 224, device='cpu'),)
exported = torch.export.export(model, inputs, strict=False)
torch.export.save(exported, 'mobilenet_v2.pt2')
```

## TIMM — timm models

```python
import torch
import timm

model = timm.create_model('tiny_vit_5m_224', pretrained=True)
model = model.cpu()
model.eval()
inputs = (torch.randn(1, 3, 224, 224, device='cpu'),)
exported = torch.export.export(model, inputs, strict=False)
torch.export.save(exported, 'tinyvit.pt2')
```

## STATE_DICT — State_dict-only .pth (requires knowing architecture)

If `torch.load()` returns a dict (not a Module), instantiate the architecture first:

```python
import torch
from torchvision.models import resnet18

model = resnet18()
state_dict = torch.load('resnet18.pth', map_location='cpu', weights_only=True)
model.load_state_dict(state_dict)
model = model.cpu()
model.eval()
inputs = (torch.randn(1, 3, 224, 224, device='cpu'),)
exported = torch.export.export(model, inputs, strict=False)
torch.export.save(exported, 'resnet18.pt2')
```

## TENSOR_WRAPPER — Models with dict inputs or dataclass outputs (`TensorOutputWrapper`)

Some models (especially HuggingFace transformers) have two torch.export
constraints that must be handled before `torch.export.export`:

1. **HF dataclass outputs don't round-trip** through `torch.export.save` /
   `torch.export.load` even when `transformers` is imported in the loader
   (`CausalLMOutputWithPast`, `Seq2SeqLMOutput`, etc.).
2. **`loadPyTorchExportedProgram` and other consumers only feed positional args** to
   the loaded exported program. If `example_inputs` is a dict (most HF
   models — `{input_ids: ...}`), exporting it as `kwargs=...` yields a
   keyword-only signature and the consumer fails with
   *"Ran into a kwarg keyword mismatch: Got the following keywords [] but
   expected ['input_ids']"*.

Wrap once to fix both:

```python
import torch
import torch.nn as nn

class TensorOutputWrapper(nn.Module):
    def __init__(self, model: nn.Module, kwarg_names: list[str] | None = None):
        super().__init__()
        self.model = model
        self.kwarg_names = kwarg_names  # set when example_inputs is a dict

    def forward(self, *args, **kwargs):
        if self.kwarg_names is not None and not kwargs:
            kwargs = dict(zip(self.kwarg_names, args))
            args = ()
        out = self.model(*args, **kwargs)
        # Flatten HF dataclass / dict / namedtuple to plain tensor(s)
        if isinstance(out, torch.Tensor):
            return out
        if hasattr(out, "to_tuple"):
            flat = tuple(t for t in out.to_tuple() if isinstance(t, torch.Tensor))
            return flat[0] if len(flat) == 1 else flat
        if isinstance(out, dict):
            flat = tuple(v for v in out.values() if isinstance(v, torch.Tensor))
            return flat[0] if len(flat) == 1 else flat
        if isinstance(out, (tuple, list)):
            flat = tuple(t for t in out if isinstance(t, torch.Tensor))
            return flat[0] if len(flat) == 1 else flat
        return out

from transformers import BertModel
module = BertModel.from_pretrained("bert-base-uncased", attn_implementation="eager")
module = module.cpu()
example_inputs = {"input_ids": torch.randint(0, 30522, (1, 128), device='cpu'),
                  "attention_mask": torch.ones(1, 128, dtype=torch.long, device='cpu')}
module.eval()

if isinstance(example_inputs, dict):
    kwarg_names = list(example_inputs.keys())
    args_tuple  = tuple(example_inputs.values())
elif isinstance(example_inputs, (tuple, list)):
    kwarg_names, args_tuple = None, tuple(example_inputs)
else:
    kwarg_names, args_tuple = None, (example_inputs,)

module = TensorOutputWrapper(module, kwarg_names=kwarg_names).eval()
with torch.no_grad():
    ep = torch.export.export(module, args_tuple, kwargs={}, strict=False)
torch.export.save(ep, "bert_wrapped.pt2")
```

----

Copyright 2026 The MathWorks, Inc.

----
