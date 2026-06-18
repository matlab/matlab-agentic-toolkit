# Pattern 2: Direct C/C++ Code Generation from PyTorch and LiteRT Models

Generate embedded C/C++ directly from PyTorch and LiteRT models using MATLAB Coder
with the PyTorch and LiteRT support package. No Deep Learning Toolbox layer system
required. Proven across 8+ real-world models (LSTM, MLP, CNN, Vision Transformer)
spanning 1K to 5.7M parameters, deployed to ARM Cortex-M7, Cortex-A53, and generic
embedded targets.

## When to Use

- User has a trained PyTorch model and wants C code quickly
- User does NOT need compression (quantization, projection, pruning)
- User does NOT need Simulink integration
- User does NOT need weight inspection or modification
- User targets Cortex-M, Cortex-A, x86, or GPU platforms

## When NOT to Use

- User needs compression, Simulink, or weight inspection → Pattern 1 (import path)
- User wants to train from scratch in MATLAB → Pattern 1 (native training)
- User targets FPGA or NPU (not covered by this skill)

## How It Works

```
PyTorch model (.pt2) --> MLIR --> TOSA primitives --> MATLAB Coder --> C/C++
```

The PyTorch Support Package takes a `.pt2` exported model and lowers it through
TOSA (Tensor Operator Set Architecture) primitive ops (`tosa.matmul`, `tosa.sigmoid`,
`tosa.relu`, etc.) before MATLAB Coder sees it. This path **never uses MATLAB's
Deep Learning Toolbox layer system**. The loaded object is NOT a `dlnetwork`.

## Prerequisites

- MATLAB R2026+ with **MATLAB Coder Support Package for PyTorch and LiteRT Models**
- MATLAB Coder (+ Embedded Coder for ARM targets)
- Python environment with `torch >= 2.0` configured in MATLAB via `pyenv('Version', '<path to python executable>')`
- PyTorch model exported as `.pt2` via `torch.export`

## Quick-Start Workflow

### Step 1: Export from PyTorch

```python
import torch
model.eval()
example_input = torch.randn(1, 10, 5)  # Must match model's expected shape exactly
ep = torch.export.export(model, (example_input,))
torch.export.save(ep, 'model.pt2')
```

See [`pytorch-export.md`](pytorch-export.md) for detailed export guidance,
common failures, and test vector generation.

### Step 2: Write the Entry-Point Function

```matlab
function pred = predict_model(Xin)
%#codegen

persistent net;
if isempty(net)
    net = loadPyTorchExportedProgram('/absolute/path/to/model.pt2');
end

out = net.invoke(single(Xin));
pred = single(out);
end
```

**Key:** Use `net.invoke()` -- the loaded `PyTorchExportedProgram` object is NOT a
standard `dlnetwork`. Do not try to inspect `.Layers` or call `predict()` on it.

### Step 3: Configure and Run Codegen

```matlab
cfg = coder.config('lib', 'ecoder', true);
cfg.TargetLang = 'C';
cfg.GenerateReport = true;

% CRITICAL: Pure C without external library dependencies
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');

inputType = coder.typeof(single(zeros(1, 10, 5)), [1 10 5], [false false false]);
codegen -config cfg predict_model -args {inputType} -report
```

See [`coder-configuration.md`](coder-configuration.md) for full production settings
including SIMD, OpenMP, and target-specific configurations.

### Step 4: Verify Generated C

Compare C output against PyTorch reference on 100+ diverse inputs. See
[`verification-testing.md`](verification-testing.md).

## Reference Documents (Progressive Loading)

Load only the references relevant to your current task:

| Reference | When to Load |
|-----------|-------------|
| [`pytorch-export.md`](pytorch-export.md) | Exporting PyTorch models to .pt2, generating test vectors |
| [`coder-configuration.md`](coder-configuration.md) | MATLAB Coder settings for embedded targets (ARM, MCU) |
| [`architecture-patterns.md`](architecture-patterns.md) | LSTM, MLP, CNN, ViT-specific input formats and gotchas |
| [`verification-testing.md`](verification-testing.md) | Numerical validation of generated code |
| [`troubleshooting.md`](troubleshooting.md) | Common errors and fixes |

## Key Lessons

1. **Always set `DeepLearningConfig('none')`** for pure C without MathWorks runtime dependencies
2. **Use `net.invoke()`**, not `predict()` -- the loaded object is a `PyTorchExportedProgram`, not a dlnetwork
3. **Use absolute paths** for the .pt2 file in the entry-point function
4. **Input shape must match exactly** what was used during `torch.export` -- no dynamic dimensions
5. **Column-major layout in generated C** -- test harnesses must transpose from PyTorch's row-major

## Workflow Phases

4 sequential phases. Prerequisites (Environment Discovery + Project Discovery)
are already completed before this file is loaded.

### Phase 1: Export
Export PyTorch model to .pt2 (load `pytorch-export.md`)
- Create `.m` scripts for each step; execute via `run_matlab_file`
- **Pause** and ask user permission before proceeding to next step

### Phase 2: Configure
Set up MATLAB Coder for target (load `coder-configuration.md`)
- **Pause** after configuration for user review

### Phase 3: Generate
Run `codegen` to produce C/C++
- **Open the code generation report** when complete
- **Pause** for user to review report

### Phase 4: Verify
Three-stage validation: PyTorch → MATLAB → MEX → C (load `verification-testing.md`)
- **Propose test count** and rationale; wait for user agreement
- Run numerical equivalency at each stage
- **Explicitly state accuracy** at each transformation point
- Report MAE, max error, pass/fail for each stage

At each step, load the relevant reference file. Create `.m` scripts for all MATLAB
execution (never run ad-hoc commands in the MCP server). If errors occur, load
`troubleshooting.md`.


Copyright 2026 The MathWorks, Inc.
