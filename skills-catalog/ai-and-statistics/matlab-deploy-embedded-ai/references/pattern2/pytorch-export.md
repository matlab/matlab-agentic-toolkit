# PyTorch Model Export to .pt2

The MATLAB Coder Support Package for PyTorch requires a `.pt2` file created with `torch.export`.

## Export Workflow

```python
import torch

model = YourModel()
model.load_state_dict(torch.load('weights.pt', map_location='cpu'))
model.eval()   # CRITICAL: must be in eval mode

# Example input MUST match the exact shape the model will use at inference
# Batch dimension should be 1 for embedded deployment
example_input = torch.randn(1, 10, 5)  # e.g., [batch=1, seq_len=10, features=5]

# Export the full computation graph
ep = torch.export.export(model, (example_input,))
torch.export.save(ep, 'model.pt2')

# Verify the export loads and produces correct output
ep_loaded = torch.export.load('model.pt2')
with torch.no_grad():
    out = ep_loaded.module()(example_input)
    print(f"Output shape: {out.shape}")
```

## Critical Requirements

1. **`model.eval()` before export.** Training-mode artifacts (dropout masks, batch norm running
   stats updates) get baked into the graph otherwise.

2. **Static shapes only.** `torch.export` traces a static computation graph. The exported model
   will only work with the exact input shape used during export. For embedded deployment this is
   fine -- you know the input shape at compile time.

3. **No dynamic control flow.** `if/else` on tensor values, variable-length loops, and data-dependent
   branching are not supported. The entire model must be traceable as a straight-line computation.

4. **Batch dimension = 1.** For embedded targets, always export with batch size 1.

## Common Export Shapes by Architecture

| Architecture | Example Input Shape | Notes |
|-------------|-------------------|-------|
| LSTM | `torch.randn(1, seq_len, features)` | [batch, time, channels] |
| MLP | `torch.randn(1, num_features)` | [batch, features] |
| CNN | `torch.randn(1, 3, 224, 224)` | [batch, channels, height, width] |
| ViT | `torch.randn(1, 3, 224, 224)` | Same as CNN (patch embedding is internal) |

## Common Export Failures

| Failure | Cause | Fix |
|---------|-------|-----|
| `torch._dynamo.exc.Unsupported` | Dynamic control flow | Restructure to static ops or use `torch.cond()` |
| `ConstraintViolation` | Dynamic batch size | Fix batch dim: `torch.export.Dim.STATIC` |
| Graph break on custom op | Unsupported Python op | Replace with standard PyTorch op |
| `RuntimeError: could not export` | In-place mutation | Replace `x.add_(y)` with `x = x + y` |

## Generating Test Vectors

Always create reference test vectors alongside the export. These are essential for verifying
the generated C code (see [`verification-testing.md`](verification-testing.md)).

```python
import numpy as np
from scipy.io import savemat

np.random.seed(42)
N_TESTS = 100

# Generate diverse test inputs
test_inputs = np.random.randn(N_TESTS, *input_shape).astype(np.float32)

# Run PyTorch reference
model.eval()
test_outputs = []
with torch.no_grad():
    for i in range(N_TESTS):
        x = torch.from_numpy(test_inputs[i:i+1])
        y = model(x)
        test_outputs.append(y.numpy())
test_outputs = np.array(test_outputs)

# Save for MATLAB comparison
savemat('test_vectors.mat', {
    'test_inputs': test_inputs,
    'test_outputs_ref': test_outputs
})

# Also save as C header for C test harness
with open('test_vectors.h', 'w') as f:
    f.write(f'#define NUM_TESTS {N_TESTS}\n')
    f.write(f'static const float test_inputs[{N_TESTS}][{np.prod(input_shape)}] = {{\n')
    for i in range(N_TESTS):
        vals = ', '.join(f'{v:.8f}f' for v in test_inputs[i].flatten())
        f.write(f'  {{{vals}}},\n')
    f.write('};\n')
    # ... similar for test_outputs
```

## Boundary Case Generation

Don't rely only on random inputs. For classification models, generate inputs that trigger
each output class -- random inputs tend to produce the same dominant-class prediction, which
hides numerical bugs.

```python
boundary_inputs = []
for target_class in range(num_classes):
    found = 0
    for _ in range(10000):
        x = torch.randn(1, *input_shape)
        with torch.no_grad():
            pred = model(x).argmax(-1).item()
        if pred == target_class:
            boundary_inputs.append(x.numpy())
            found += 1
            if found >= 20:
                break
    print(f"Class {target_class}: found {found} boundary inputs")
```

## Pre-Export Checklist

- [ ] `model.eval()` called
- [ ] Example input shape matches actual inference shape
- [ ] Batch dimension is 1
- [ ] No dynamic control flow in the model
- [ ] Export verified: `torch.export.load('model.pt2').module()(example_input)` runs
- [ ] 100+ test vectors saved with PyTorch reference outputs
- [ ] Boundary cases included (non-dominant class predictions for classifiers)


Copyright 2026 The MathWorks, Inc.
