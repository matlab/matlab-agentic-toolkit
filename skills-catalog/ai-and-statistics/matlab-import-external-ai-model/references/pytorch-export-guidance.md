# Export a PyTorch Model for MATLAB Import

## Required Steps

Every export script must include these steps in order:

```python
import torch

# 1. Load or define the model
model = YourModel()
# If loading from state_dict:
model.load_state_dict(torch.load("weights.pt", weights_only=True))

# 2. Move to CPU (MANDATORY)
model.to("cpu")

# 3. Set eval mode (MANDATORY)
model.eval()

# 4. Verify PyTorch version (MANDATORY)
assert torch.__version__.startswith("2.8"), (
    f"importNetworkFromPyTorch requires models exported with PyTorch 2.8. "
    f"Current version: {torch.__version__}"
)

# 5. Create example input with CORRECT shape (ask user, don't guess)
example_input = torch.randn(1, 3, 224, 224)  # Replace with actual shape

# 6. Export
exported_program = torch.export.export(model, (example_input,))

# 7. Save as .pt2
torch.export.save(exported_program, "model.pt2")
```

## Why Each Step Matters

### model.to("cpu")

MATLAB's `importNetworkFromPyTorch` expects CPU tensors. If the model is on GPU,
the saved .pt2 file will contain CUDA tensors that MATLAB cannot read. The export
may succeed, but the import will fail with a device mismatch error.

### PyTorch version 2.8

The exported program format evolves across PyTorch versions. MATLAB's converter is
built against PyTorch 2.8's format specifically. Older .pt2 files trigger a
deprecation warning; newer ones (2.9+, 2.12+) fail with an incompatible format
error.

If the user has a newer PyTorch version, they must create a separate environment
with PyTorch 2.8:

```bash
python -m venv pytorch28_env
source pytorch28_env/bin/activate  # or Scripts/activate on Windows
pip install torch==2.8.0 --index-url https://download.pytorch.org/whl/cpu
```

### Input size

The export traces the model with the example input to build the computation graph.
Wrong input size means wrong graph topology (e.g., wrong flatten dimensions,
wrong linear layer sizes). The export will succeed but the model will be wrong.

**Never guess.** If you don't know the input size:
- Ask the user
- Check the model's documentation
- Inspect the first layer: `model.features[0].in_channels` tells you channel count

## Loading Models from Different Formats

### Full model pickle (torch.save(model))

```python
# CAUTION: requires the class definition in scope
import sys
sys.path.insert(0, "/path/to/model/definition")
model = torch.load("model.pt", weights_only=False)
```

The class must be importable. If not available, ask the user for the model class.

### State dict

```python
model = YourModel()  # Must have class definition
model.load_state_dict(torch.load("weights.pt", weights_only=True))
```

### TorchVision pretrained

```python
import torchvision.models as models
model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
```

### HuggingFace

```python
from transformers import AutoModel
model = AutoModel.from_pretrained("bert-base-uncased")
```

For HuggingFace models, export with kwargs for optional inputs:

```python
input_ids = torch.randint(0, 30522, (1, 128), dtype=torch.long)
attention_mask = torch.ones(1, 128, dtype=torch.long)

exported = torch.export.export(
    model,
    (input_ids,),
    kwargs={"attention_mask": attention_mask},
)
```

## Common Export Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `torch._dynamo.exc.Unsupported` | Dynamic control flow | Use `strict=False` or refactor with `torch.cond` |
| `GuardOnDataDependentSymNode` | Data-dependent shapes | Specify dynamic shapes explicitly |
| `RuntimeError: Expected all tensors on same device` | Model on GPU | Call `model.to("cpu")` |

----

Copyright 2026 The MathWorks, Inc.

----
