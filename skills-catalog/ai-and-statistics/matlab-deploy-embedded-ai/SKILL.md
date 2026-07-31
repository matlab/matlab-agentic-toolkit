---
name: matlab-deploy-embedded-ai
description: >
  Deploy AI models to embedded hardware using MathWorks tools (MATLAB, Simulink,
  Embedded Coder). Covers two workflow patterns: (1) MathWorks-native or imported
  models rebuilt as dlnetwork for lean hardware, (2) direct C/C++ code generation
  from PyTorch and LiteRT models. Both patterns support all targets (Cortex-M/A/R,
  x86, GPU).
  Trigger when: user wants to deploy AI to embedded targets; generate C/CUDA from
  neural networks; compress AI models for MCU; integrate AI in Simulink for
  system-level simulation; import PyTorch/ONNX/TensorFlow models for embedded
  deployment; optimize AI for resource-constrained hardware; or use
  loadPyTorchExportedProgram, loadLiteRTModel, importNetworkFromPyTorch,
  importNetworkFromONNX, importNetworkFromTensorFlow, importNetworkFromKeras,
  dlquantizer, exportNetworkToSimulink, or Embedded Coder with AI models.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.1"
---

# Embedded AI for Engineered Systems

Deploy AI models to embedded hardware using MATLAB&reg; and Simulink&reg;. This skill is
written specifically for **MATLAB R2026a** and uses APIs, functions, and workflows
introduced in that release. It covers the complete lifecycle: model creation or
import, verification, compression, system-level simulation, and code generation
for resource-constrained targets.

Requires MATLAB R2026a or newer. Core toolboxes: Deep Learning Toolbox, Statistics
and Machine Learning Toolbox, MATLAB Coder, Embedded Coder, Simulink, and
Fixed-Point Designer. Workflow-specific support packages are checked during
Environment Discovery. The MATLAB and Simulink Agentic Toolkits must be available
so the agent can drive a live MATLAB and Simulink session through MCP tools.

## When to Use

- Deploying a trained neural network (MATLAB-native or imported) to embedded hardware
- Generating C or CUDA code from a deep learning model for ARM Cortex-M/A/R, x86, or GPU targets
- Deploying imported PyTorch, ONNX, TensorFlow, or LiteRT models to embedded targets (import step handled by `/matlab-import-external-ai-model`)
- Compressing AI models (quantization, pruning, projection) to fit resource-constrained hardware
- Integrating AI inference into a Simulink system model for closed-loop simulation before code generation
- Using `loadPyTorchExportedProgram`, `importNetworkFromPyTorch`, `importNetworkFromONNX`, `importNetworkFromTensorFlow`, `dlquantizer`, `exportNetworkToSimulink`, or Embedded Coder with AI models
- Choosing between MathWorks-native code generation and direct PyTorch/LiteRT code generation

## When NOT to Use

- Training a model purely for research with no deployment target — use Deep Learning Toolbox documentation directly
- Deploying to cloud/server endpoints (no embedded target) — use MATLAB Production Server or MATLAB Compiler SDK
- Working with classical ML models (decision trees, SVMs, ensembles) that aren't neural networks — use Statistics and Machine Learning Toolbox codegen workflows directly. Note: `fitcnet`/`fitrnet` neural network models ARE covered by this skill
- Generating code for non-AI Simulink models — use standard Embedded Coder workflows
- Converting between model formats without an embedded deployment goal (e.g., ONNX to MATLAB for desktop inference only)

## Workflow Pattern Selection

This skill uses two deployment patterns:

- **Pattern 1 — MATLAB Network Codegen:** Import or build a `dlnetwork`, optionally
  compress it, then generate C/C++ via MATLAB Coder or export to Simulink.
  See [`references/pattern1/workflow.md`](references/pattern1/workflow.md).
- **Pattern 2 — PyTorch/LiteRT Direct Codegen:** Load a PyTorch (.pt2) or LiteRT
  (.tflite) model directly and generate C/C++ without converting to a dlnetwork.
  See [`references/pattern2/workflow.md`](references/pattern2/workflow.md).

### Decision Tree

Primary discriminator for external models: **deployment capabilities + hardware class**.

```
Q1: Where does the AI model come from?
 |
 +-- Trained in MATLAB, or requires training in MATLAB -------> Pattern 1
 |
 +-- External framework (PyTorch, TF, ONNX, Keras) --> Q2
      |
      Q2: Does the deployment need any of these?
       |  - Quantization (INT8 via dlquantizer)
       |  - Pruning or projection
       |  - Weight inspection / modification
       |  - exportNetworkToSimulink integration
       |
       +-- YES --> Pattern 1 (import as dlnetwork)
       |
       +-- NO ---> Q3
            |
            Q3: What is the deployment target?
             |
             +-- Cortex-M: Pattern 1
             |     (compression and Simulink verification typically needed)
             |
             +-- x86 / GPU:
             |     +-- PyTorch (.pt2) or LiteRT (.tflite) --> Pattern 2
             |     +-- ONNX, TF, Keras --> Pattern 1 (convert to ONNX recommended)
             |
             +-- Cortex-A/R:
                   +-- Small model --> Pattern 1
                   |     (import as dlnetwork, then codegen)
                   +-- Large model:
                        +-- PyTorch (.pt2) or LiteRT (.tflite) --> Pattern 2
                        +-- ONNX, TF, Keras --> Pattern 1 (convert to ONNX recommended)
```

### Pattern Summary

| Pattern | When to Use | Primary Toolchain |
|---------|-------------|-------------------|
| **1 — MATLAB Network Codegen** | Model trained in MATLAB, OR external model needing compression/quantization/Simulink export/weight inspection, OR Cortex-M targets | MATLAB Coder&trade; / Embedded Coder&trade; |
| **2 — PyTorch/LiteRT Direct Codegen** | External PyTorch (.pt2) or LiteRT (.tflite) model on x86/GPU/Cortex-A targets; shorter path to C code without compression | MATLAB Coder&trade; + PyTorch & LiteRT SPKG |

Pattern 2's generated C is portable to any target, but Cortex-M deployments typically require Pattern 1 capabilities (compression, Simulink verification).

**Import step (Pattern 1):** For PyTorch/ONNX/Keras/TensorFlow model import, use `/matlab-import-external-ai-model`. This skill takes over after import for the compression, Simulink integration, and code generation phases.

### Pattern 1 vs Pattern 2 Capability Comparison

| Capability | Pattern 1 (dlnetwork) | Pattern 2 (PyTorch/LiteRT direct) |
|-----------|----------------------|----------------------|
| C code generation | Yes | Yes |
| Target: Cortex-M, Cortex-A/R, x86, GPU | Yes | Yes |
| Weight inspection / modification | **Yes** | No |
| dlquantizer (INT8) | **Yes** | No |
| Projection (compressNetworkUsingProjection) | **Yes** | No |
| Pruning | **Yes** | No |
| Simulink integration | **Yes** (exportNetworkToSimulink) | **Yes** (PyTorch SPKG Simulink blocks) |
| Combined compression | **Yes** | No |
| Speed to first C code | Slower | **Faster** |

**Rule of thumb:** Choose Pattern 1 when you need to compress, quantize, inspect
weights, or use `exportNetworkToSimulink` — or when the model is already a
`dlnetwork`, or when targeting Cortex-M. Choose Pattern 2 when the model is already
in PyTorch (.pt2) or LiteRT (.tflite) format and you want the shorter path to C code
without compression.

**Stats/ML models (fitrnet/fitcnet):** These follow Pattern 1 but have their own
Simulink integration path. Use the **RegressionNeuralNetwork Predict** block (for
`fitrnet`) or **ClassificationNeuralNetwork Predict** block (for `fitcnet`) from
the Statistics and Machine Learning Toolbox library — do NOT use
`exportNetworkToSimulink` (which is for `dlnetwork` only). Configure simulation
programmatically with `Simulink.SimulationInput`.

## Common Start: Prerequisites

Regardless of pattern, **always** begin with these two prerequisite steps before
entering the pattern-specific phases (which start at Phase 1):

1. **Environment Discovery** (silent): Load [`references/shared/environment-setup.md`](references/shared/environment-setup.md)
2. **Project Discovery** (interactive): Load [`references/shared/project-discovery.md`](references/shared/project-discovery.md)

Project Discovery determines the workflow pattern via the decision tree above.

## Do Not Use (Legacy Functions)

| Legacy | Modern Replacement |
|--------|-------------------|
| `trainNetwork` / `train` (for DL) | `trainnet` |
| `DAGNetwork` / `SeriesNetwork` / `network` | `dlnetwork` |
| `taylorPrunableNetwork` / `updateScore` / `updatePrunables` | `compressNetworkUsingTaylorPruning` (when trainable with `trainnet`); use `taylorPrunableNetwork` for custom training loops |
| `csvread` / `xlsread` | `readmatrix` / `readtable` |
| `datenum` | `datetime` |

For legacy import functions (`importONNXNetwork`, `importKerasNetwork`, etc.), see
`/matlab-import-external-ai-model` which handles all model import workflows.

## Global Rules

### Advisory vs Execution Mode

Distinguish between two modes based on the user's intent:

- **Advisory** ("How should I approach this?", "What workflow?", "Which pattern?"): Answer
  the routing question directly — state the recommended Pattern, explain why, and outline
  the high-level steps. Do NOT enter Environment Discovery or start asking prerequisite
  questions. After giving the recommendation, ask if the user wants to begin execution.
- **Execution** ("Deploy my model", "Walk me through", "Write the script"): Enter the full
  prerequisite flow (Environment Discovery → Project Discovery → step-by-step phases).

### ALWAYS

- Check **toolboxes** via `detect_matlab_toolboxes` and **support packages** via `matlabshared.supportpkg.getInstalled` before any workflow step
- If a support package is missing, ask the user to download from Add-On Explorer -- **never** install on their behalf
- Guide the user step-by-step -- one phase at a time
- Use consistent data partitioning (e.g., fixed indices or a stored partition object) for reproducibility
- Verify numerical equivalence at each transformation step
- Generate MEX for desktop validation before generating C code for target
- Use `single` precision for all inference inputs
- **Script-based execution:** For each workflow step done in MATLAB, create a `.m` script file and execute it with `run_matlab_file` or `evaluate_matlab_code`. Do NOT run ad-hoc MATLAB commands without first writing the script file. If a script needs changes, edit the script file and re-run it. This gives users full visibility into what code is being executed and enables reproducibility. **IMPORTANT:** `run_matlab_file` sets the working directory to the script's folder. Always use **absolute paths** (via `fullfile`) for model files, data, and saved outputs — never rely on `pwd` or relative paths.
- **Pause after each workflow step:** After every workflow step completes, pause and explicitly ask the user for permission to proceed to the next step. The goal is to let the user read/inspect the MATLAB scripts you created, review results, and ask questions before moving on.
- **Deep Network Designer:** When a model is trained in MATLAB, imported, or rebuilt as a native dlnetwork, load it in Deep Network Designer (`deepNetworkDesigner(net)`) so the user can visually inspect the architecture. Announce this action and wait for user acknowledgment before proceeding.
- **Numerical equivalency tests (import workflows):** For any import from PyTorch or ONNX:
  1. Run inference on the **original model** (via bundled Python for PyTorch, or ONNX runtime) to collect ground-truth reference data. Do NOT use the imported MATLAB model as reference — for PyTorch imports in R2026a, custom autogenerated layers may not support code generation and the model may need to be rebuilt natively. (ONNX autogenerated layers have supported code generation since R2025a and may not require a rebuild.)
  2. Run the same inputs through the **rebuilt native** MATLAB model and compare against ground truth
  3. After compression, report the accuracy delta vs. the uncompressed baseline (MAE, max error, % accuracy drop). Compute these from variables in the current run — never hardcode numeric values into `fprintf`/`disp` strings, because re-running the script with different inputs or a different model will then print stale numbers.
  4. Run tests to validate numerical equivalence between: compressed model in MATLAB, compressed model in Simulink, and final generated code
- **Test count proposal:** Before running numerical equivalency tests, propose how many tests you plan to run and explain why (considering model complexity, output range, class count, etc.). Wait for user agreement or correction before proceeding.
- **Code generation report:** Do NOT open the code generation report automatically — it opens a GUI that is not useful in an agentic workflow. Only open if the user explicitly requests it.
- **Look up function signatures from MATLAB's help or the online reference page, not from this skill.** Argument lists, name-value pair (NVP) defaults, and supported-layer enumerations live in MATLAB's `help <function>` output and on the function's reference page. Use those as the source of truth instead of any inline parameter table in this skill — inline tables go stale across releases and burn context. This skill only flags name-value arguments that materially change the recipe (e.g., `ValidationThreshold` for accuracy-budgeted pruning). Lookup procedure:
  1. **First** try `help <function>` in the live MATLAB session. Fast and reflects the actually-installed release of the toolbox or support package.
  2. If `help` returns only a stub like "Run doc <function> for more information." — common for support-package functions whose help redirects to the browser doc — **fall back to the agent's web browsing of the online reference page** at `https://www.mathworks.com/help/<product>/ref/<funcname>.html` (lower-case function name). Extract every name-value argument with its default value, formatted as a markdown table, quoting defaults verbatim.
  3. If the function is not found at all (`which <func>` returns "not found") on a system that has the relevant support package installed, the support package is likely on a stale build. Ask the user to update via Add-On Explorer rather than working around the missing function.
- **Compression decision flow:** At the start of Phase 5 (Pattern 1), load `references/pattern1/compression-decision.md` and walk the user through the question flow (hardware + Simulink availability, primary goal, retraining tolerance). Pick the compression and code generation path based on the answers. Compression is not mandatory and the optimal combination of pruning, projection, and quantization depends on the goal — for example, on Cortex-M with a latency-bound LSTM model, the float32 path with CMSIS-DSP outperforms the quantized path because CMSIS-NN provides no INT8 kernel for recurrent layers.

### ASK FIRST

- Before each phase transition: "Is this step relevant to your project?" (some phases may not apply)
- Before data splitting: "Do you have existing train/val/test splits, or should I partition?" (avoids overwriting user's partitioning)
- Before model selection: "What problem type (classification/regression/sequence) and any size constraints?" (determines architecture)
- Before Simulink: "Do you have an existing Simulink model to integrate into?" (determines export vs standalone)
- Before quantization: "Does your target support floating-point, or is integer-only required?" (determines quantization path)
- Before code generation: "What is the target hardware?" (determines Coder configuration and CRL)
- Before compression and code generation (Pattern 1): walk the user through the decision flow in `references/pattern1/compression-decision.md` — hardware target + Simulink availability, primary goal, retraining tolerance. The answers determine the compression techniques and the code-replacement library to use. **Even if the hardware target is already stated**, you MUST still ask about the primary deployment goal (flash, SRAM, latency, accuracy) and present the user with the recommended recipe for confirmation before executing any compression step.

### NEVER

- Present the entire workflow at once
- Skip Environment Discovery or Project Discovery
- Open, load, or inspect user data before Project Discovery is confirmed
- Use legacy functions listed in "Do Not Use" section
- Assume toolbox or support package availability without checking
- Install support packages on the user's behalf
- Promise hardware-agnostic performance or "deploy anywhere"
- Generate `DAGNetwork`, `SeriesNetwork`, or `network` objects
- Run MATLAB commands directly in the MCP server without creating a script file first
- Skip numerical equivalency testing when using imported external models
- Proceed to the next workflow step without explicit user permission
- Apply compression without first walking the user through the decision flow in `compression-decision.md`
- Use the imported model (with custom autogenerated layers) as numerical ground truth — always validate against the original model via bundled Python
- Pass a `[C × T]` array with format `"CBT"` to a sequence model — always reshape to `[C × 1 × T]` for single-sequence inference
- Pass a `dlnetwork` to `prepareNetwork` — in R2026a the function takes a `dlquantizer` object (`prepareNetwork(quantObj)`) and mutates it in place. The legacy `net = prepareNetwork(net)` form is no longer defined

---

## Related Workflows (Out of Scope)

This skill covers C/C++ code generation for CPU targets (Cortex-M, Cortex-A/R,
x86) via MATLAB Coder and Embedded Coder, and GPU targets (CUDA/TensorRT) via
Pattern 2's `DeepLearningConfig` options. The following deployment targets use
different toolchains and are NOT covered:

| Target | Toolchain | Notes |
|--------|-----------|-------|
| FPGA / SoC | HDL Coder + Deep Learning HDL Toolbox | Generates HDL (VHDL/Verilog) from dlnetwork |
| PLC | Simulink PLC Coder | Generates Structured Text for PLCs from Simulink models |

If the user's target falls into one of these categories, inform them that this skill
does not cover that workflow and suggest the relevant toolchain.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See [www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list of additional trademarks. Other product or brand names may be trademarks or registered trademarks of their respective holders.


Copyright 2026 The MathWorks, Inc.
