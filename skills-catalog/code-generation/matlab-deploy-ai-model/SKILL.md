---
name: matlab-deploy-ai-model
description: >
  Generate C/C++ or CUDA code from an AI model (PyTorch, LiteRT) using
  MATLAB Coder or GPU Coder. Use when the user wants to integrate an AI model
  into an application with code generation as the end goal — generating MEX,
  CUDA MEX, static library, dynamic library, or executable — or using the model
  in Simulink for simulation and code generation. This skill currently documents
  the PyTorch ExportedProgram (.pt2) workflow via loadPyTorchExportedProgram;
  LiteRT is already supported by the product (loadLiteRTModel, R2026a+) but
  detailed guidance has not yet been added to this skill.
  Keywords: PyTorch, torch, .pt2, ExportedProgram, loadPyTorchExportedProgram,
  invoke, codegen, MEX, CUDA, GPU, C, C++, deploy, AI model, deep learning model,
  LiteRT, TFLite, TensorFlow Lite, Simulink, slbuild, PyTorch ExportedProgram block,
  MATLAB Function block, dlosslib.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Generate C/C++/CUDA Code from an AI Model

Generate deployable C/C++ or CUDA code from an AI model using MATLAB Coder or
GPU Coder. The workflow follows a common pattern regardless of model framework:
load, inspect, write entry-point, generate MEX, verify, then generate production code.

## When to Use

- User wants to generate C/C++/CUDA code from an AI model (PyTorch, LiteRT)
- User has a model file (.pt2, .tflite) and wants to load it into MATLAB
- User wants MEX acceleration for an AI model
- User wants to generate CUDA code or GPU-accelerated MEX from an AI model
- User wants to deploy an AI model to hardware
- User wants to use a PyTorch or LiteRT model in Simulink (simulation or code generation)
- User wants to verify AI model numerics between the source framework and MATLAB

## When NOT to Use

- **General MATLAB Coder usage** (codegen syntax, config tuning, writing codegen-ready code)
- **Editable dlnetwork for Deep Learning Toolbox workflows** (quantization, compression, transfer learning) — use `importNetworkFromPyTorch` which returns a `dlnetwork` for PyTorch models. For deployment of an editable `dlnetwork` with model compression (INT8 quantization via `dlquantizer`, pruning, projection) or `exportNetworkToSimulink` workflows — use `matlab-deploy-embedded-ai` (Pattern 1).
- **Training or fine-tuning** — this skill is for inference code generation only

## Supported Frameworks

| Framework | Model format | Load function | Status |
|-----------|-------------|---------------|--------|
| PyTorch | `.pt2` | `loadPyTorchExportedProgram` | Supported (R2026a+) |
| LiteRT / TFLite | `.tflite` | `loadLiteRTModel` | Supported (R2026a+) |

For PyTorch-specific details (API routing, entry-point pattern, export workflow,
data layout, common mistakes): see `references/pytorch-workflow.md`.

## Generic Workflow

The code generation workflow follows the same steps for any framework:

### 1. Load and Inspect

Load the model and check its input/output specifications to determine expected
shapes and types.

### 2. Write Entry-Point Function

Create a codegen-compatible entry-point function that:
- Loads the model from a file path
- Runs inference on an input
- Returns the output

The model file path must be wrapped with `coder.Constant` so it's known at
compile time.

### 3. Verify Numerics

Compare MATLAB inference output against the source framework to confirm correct
loading. Use the same input data in both environments and compare with tolerance.

### 4. Generate MEX (First!)

Always generate MEX before lib/exe to verify on the host machine:

**CPU MEX:**
```matlab
cfg = coder.config("mex");
codegen -config cfg -args {coder.Constant("model_file"), input} entryPoint
```

**CUDA MEX (GPU acceleration):**
```matlab
cfg = coder.gpuConfig("mex");
codegen -config cfg -args {coder.Constant("model_file"), input} entryPoint
```

For CPU MEX SIMD acceleration (`SIMDAcceleration = 'Full'` for AVX2 on
Intel/AMD), see `references/codegen-performance-options.md`. For the DNN-
inference-specific MEX AVX2 ceiling, see `references/dnn-codegen-options.md`.

### 5. Verify MEX Output

Compare MEX output against MATLAB reference using `matlab.unittest` with
tolerance:

```matlab
refOut = entryPoint("model_file", input);
mexOut = entryPoint_mex("model_file", input);
testCase = matlab.unittest.TestCase.forInteractiveUse;
testCase.verifyThat(mexOut, matlab.unittest.constraints.IsEqualTo(refOut, ...
    'Within', matlab.unittest.constraints.AbsoluteTolerance(single(1e-5))));
```

### 6. Generate Library/Executable

Once MEX is verified, generate production code:

```matlab
cfgLib = coder.config("lib");
cfgLib.TargetLang = "C++";  % set to "C++" for C++ output; default is "C"
codegen -config cfgLib -args {coder.Constant("model_file"), input} entryPoint
```

For DLL: `coder.config("dll")`. For executable: `coder.config("exe")`.

**CUDA variants:** Replace `coder.config` with `coder.gpuConfig`.

**Performance tuning:**
- Generic knobs (SIMD instruction sets, reduction-loop vectorization,
  multithreaded loops, MATLAB Coder ↔ Simulink Coder naming duality): see
  `references/codegen-performance-options.md`.
- DNN-inference-specific knobs (`DLTargetLibrary` / `DeepLearningConfig` to
  disable third-party DL libraries, `LargeConstantGeneration` to serialize
  weights to data files): see `references/dnn-codegen-options.md`.

### 7. Use in Simulink

For Simulink integration, use the dedicated `PyTorch ExportedProgram` block from
`dlosslib` — set `ModelFilePath` to the `.pt2` file and it auto-detects
input/output shapes. No entry-point function or `coder.Constant` needed.

Pre/post-processing can be done with Simulink blocks around the dedicated block.
If you need everything in a single block, use a MATLAB Function block with
`loadPyTorchExportedProgram` + `invoke` (same pattern as the entry-point, but
the model path is a string literal — no `coder.Constant`).

Both paths support `slbuild` code generation (requires fixed-step solver + ERT
or GRT target). See `references/simulink-workflow.md` for full details.

### 8. Deploy to Hardware (Optional — requires Embedded Coder)

For embedded deployment, use the same entry-point function with an Embedded Coder
configuration. See the `matlab-deploy-embedded-code` skill for ERT config,
hardware settings, PIL/SIL verification, and target-specific options.
Ask the user to install the skill if it is not installed

## Key Functions

| Function | Purpose | Package | Since |
|----------|---------|---------|-------|
| `coder.Constant` | Make argument a compile-time constant | MATLAB Coder | R2011a |
| `coder.gpuConfig` | Create GPU (CUDA) code generation config | GPU Coder | R2017b |
| `codegen` | Generate code | MATLAB Coder | R2011a |
| `loadPyTorchExportedProgram` | Load .pt2 into MATLAB | MATLAB Coder Support Package for PyTorch and LiteRT Models | R2026a |
| `loadLiteRTModel` | Load .tflite into MATLAB | MATLAB Coder Support Package for PyTorch and LiteRT Models | R2026a |

## Conventions

- Always check the model's input specifications for correct input shape and type
- Always generate MEX first, verify, then proceed to lib/exe
- Always use `coder.Constant` for the model file path argument
- Input data is typically single-precision (check model input specs to confirm)
- Do NOT use `importNetworkFromPyTorch` for code generation workflows — it returns `dlnetwork` for the DLT path

## References

- `references/pytorch-workflow.md` — Full PyTorch-specific workflow: API routing,
  entry-point pattern, export guidance, common mistakes, and conventions. Consult
  for any PyTorch/.pt2 model code generation task. Links to deeper PyTorch
  references (API signatures, data layout, numeric verification, supported models).
- `references/export-pytorch-models.md` — Exporting an eager-mode PyTorch model to
  `.pt2` with `torch.export` (upstream of loading). Consult when the user has a
  PyTorch model but no `.pt2` file yet, or hits `torch.export` `SerializeError` /
  kwarg-mismatch errors. Links to `pytorch-export-patterns.md` (per-source
  templates) and `pytorch-export-gotchas.md` (torch 2.11 serialization fixes).
- `references/simulink-workflow.md` — Simulink integration: dedicated PyTorch
  ExportedProgram block (Path A) vs MATLAB Function block (Path B), block mask
  parameters, code generation config, and key differences from command-line codegen.
- `references/codegen-performance-options.md` — GENERIC codegen tuning
  (not AI-specific). SIMD instruction sets (`InstructionSetExtensions` for
  lib/exe/slbuild, `SIMDAcceleration` for MEX), reduction-loop vectorization
  (`OptimizeReductions`), OpenMP multi-threading (`EnableOpenMP` MATLAB Coder
  / `MultiThreadedLoops` Simulink Coder), and the MATLAB Coder ↔ Simulink
  Coder property naming table.
- `references/dnn-codegen-options.md` — DNN-INFERENCE-SPECIFIC codegen
  options: `DLTargetLibrary` / `DeepLearningConfig('none')` for the plain-C
  DL path, `LargeConstantGeneration` for serializing large DNN weights to
  data files, and MEX SIMD ceiling in a DNN-inference context. Read this
  when the generic file's knobs need DNN-specific framing (e.g., "the MEX
  SIMD cap matters because inference is the target").

## See Also

- `matlab-deploy-embedded-code` — Embedded Coder configuration, PIL/SIL verification, hardware targets
- `matlab-deploy-embedded-ai` — `dlnetwork`-based codegen with model compression (quantization, pruning, projection) and `exportNetworkToSimulink` workflows (Pattern 1). Use it when the source is an editable `dlnetwork` in MATLAB rather than a `.pt2` / `.tflite` file.

----

Copyright 2026 The MathWorks, Inc.

----
