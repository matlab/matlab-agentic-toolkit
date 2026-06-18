---
name: matlab-deploy-embedded-ai
description: >
  Deploy AI models to embedded hardware using MathWorks tools (MATLAB, Simulink,
  Embedded Coder). Covers two workflow patterns: (1) MathWorks-native or 3P-imported
  models rebuilt as dlnetwork for lean hardware (Cortex-M, DSP), (2) direct C/C++
  code generation from PyTorch and LiteRT models for high-performance hardware
  (Cortex-A, x86, GPU).
  Trigger when: user wants to deploy AI to embedded targets; generate C/CUDA from
  neural networks; compress AI models for MCU/DSP; integrate AI in Simulink for
  system-level simulation; import PyTorch/ONNX/TensorFlow models for embedded
  deployment; optimize AI for resource-constrained hardware; or use
  loadPyTorchExportedProgram, importNetworkFromPyTorch, dlquantizer,
  exportNetworkToSimulink, or Embedded Coder with AI models.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
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
- Generating C or CUDA code from a deep learning model for ARM Cortex-M/A/R, DSP, x86, or GPU targets
- Importing PyTorch, ONNX, TensorFlow, or LiteRT models into MATLAB for embedded deployment
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

Determine the correct workflow pattern based on model origin and deployment target.

### Decision Tree

Primary discriminator for 3P models: **model size + hardware class**.

```
Q1: What is the deployment target?
 |
 +-- Cortex-M (M33, M4, M7) ---------------------> Q2
 +-- Cortex-A/R processor or DSP (C2000, etc.) ----> Q2
 +-- x86 processor or GPU (Jetson, CUDA) ----------> Q2
      |
      Q2: Where does the AI model come from?
       |
       +-- Train from scratch in MATLAB ------------> Pattern 1  (references/pattern1/workflow.md)
       +-- Pre-trained 3P model --------------------> Q3
            |
            Q3: Route by hardware class + model size
             |
             +-- Cortex-M: always Pattern 1 import
             |     (MathWorks compression, tight sim-codegen agreement)
             |
             +-- x86 / GPU: Pattern 2 if PyTorch or LiteRT
             |     Pattern 1 import if ONNX/TF (convert to Py/LiteRT recommended)
             |
             +-- Cortex-A/R or DSP:
                   +-- Small model (< 500 KB) ---------> Pattern 1 with import path
                   +-- Large model (> 1 MB):
                        +-- PyTorch / LiteRT -----------> Pattern 2
                        +-- ONNX / TensorFlow ----------> Pattern 1 import *
```

\* Convert to PyTorch&reg; (.pt2) or LiteRT (.tflite) to use Pattern 2 instead.

### Pattern Summary

| Pattern | Model Origin | Target Hardware | Primary Toolchain |
|---------|-------------|-----------------|-------------------|
| **1** | MATLAB-native or 3P imported as dlnetwork | ARM&reg; Cortex&reg;-M (M33, M4, M7), Cortex-A/R, DSP | Embedded Coder&trade; |
| **2** | PyTorch (.pt2) or LiteRT (.tflite) direct code generation | Cortex-A/R, DSP, x86, GPU | MATLAB Coder&trade; + PyTorch & LiteRT SPKG |

### Pattern 1 vs Pattern 2 Capability Comparison

| Capability | Pattern 1 (dlnetwork) | Pattern 2 (PyTorch/LiteRT direct) |
|-----------|----------------------|----------------------|
| C code generation | Yes | Yes |
| Weight inspection / modification | **Yes** | No |
| dlquantizer (INT8) | **Yes** | No |
| Projection (compressNetworkUsingProjection) | **Yes** | No |
| Pruning | **Yes** | No |
| Simulink integration | **Yes** (exportNetworkToSimulink) | **Yes** (PyTorch SPKG Simulink blocks) |
| Fixed-point codegen | **Yes** | No |
| Combined compression (77%+ flash savings) | **Yes** | No |
| Speed to first C code | Slower | **Faster** |
| Requires native rebuild for 3P models | Yes | No |

**Rule of thumb:** Choose Pattern 1 for small models (< 500 KB) on lean hardware
(Cortex-M, DSP) where you need MathWorks compression and tight simulation-codegen
agreement. Choose Pattern 2 for larger models (> 1 MB) on high-performance hardware
(x86, GPU, Cortex-A) where simulation speed is a priority and compression is done
externally in Python. For Cortex-A/R and DSP targets, model size is the primary
discriminator. Pattern 2 supports PyTorch (.pt2) and LiteRT (.tflite) formats.
Both patterns support Simulink integration.

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

## Banned Legacy Functions

| Legacy (BANNED) | Modern Replacement |
|-----------------|-------------------|
| `trainNetwork` / `trainnetwork` / `train` (for DL) | `trainnet` |
| `DAGNetwork` / `SeriesNetwork` / `network` | `dlnetwork` |
| `importONNXNetwork` / `importONNXLayers` | `importNetworkFromONNX` |
| `importTensorFlowNetwork` / `importKerasNetwork` | `importNetworkFromTensorFlow` |
| `importTensorFlowLayers` / `importKerasLayers` | `importNetworkFromTensorFlow` |
| `taylorPrunableNetwork` / `updateScore` / `updatePrunables` | `compressNetworkUsingTaylorPruning` |
| `csvread` / `xlsread` | `readmatrix` / `readtable` |
| `datenum` | `datetime` |

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
- Use `rng("default")` before any data splitting
- Verify numerical equivalence at each transformation step
- Generate MEX for desktop validation before generating C code for target
- Use `arguments` blocks in all codegen-ready functions
- Use `single` precision for all inference inputs
- **Script-based execution:** For each workflow step done in MATLAB, create a `.m` script file and execute it with `run_matlab_file` or `evaluate_matlab_code`. Do NOT run ad-hoc MATLAB commands without first writing the script file. If a script needs changes, edit the script file and re-run it. This gives users full visibility into what code is being executed and enables reproducibility. **IMPORTANT:** `run_matlab_file` sets the working directory to the script's folder. Always use **absolute paths** (via `fullfile`) for model files, data, and saved outputs — never rely on `pwd` or relative paths.
- **Pause after each workflow step:** After every workflow step completes, pause and explicitly ask the user for permission to proceed to the next step. The goal is to let the user read/inspect the MATLAB scripts you created, review results, and ask questions before moving on.
- **Deep Network Designer:** When a model is trained in MATLAB, imported, or rebuilt as a native dlnetwork, load it in Deep Network Designer (`deepNetworkDesigner(net)`) so the user can visually inspect the architecture. Announce this action and wait for user acknowledgment before proceeding.
- **Numerical equivalency tests (import workflows):** For any import from PyTorch or ONNX:
  1. Run inference on the **original 3P model** (via bundled Python for PyTorch, or ONNX runtime) to collect ground-truth reference data. Do NOT use the imported MATLAB model as reference — its custom autogenerated layers may produce incorrect outputs.
  2. Run the same inputs through the **rebuilt native** MATLAB model and compare against ground truth
  3. After compression, report the accuracy delta vs. the uncompressed baseline (MAE, max error, % accuracy drop). Compute these from variables in the current run — never hardcode numeric values into `fprintf`/`disp` strings, because re-running the script with different inputs or a different model will then print stale numbers.
  4. Run tests to validate numerical equivalence between: compressed model in MATLAB, compressed model in Simulink, and final generated code
- **Test count proposal:** Before running numerical equivalency tests, propose how many tests you plan to run and explain why (considering model complexity, output range, class count, etc.). Wait for user agreement or correction before proceeding.
- **Code generation report:** After code generation is complete and the project is done, open the code generation report (`open(reportPath)` or `web(reportPath)`) so the user can inspect the generated code, warnings, and metrics.
- **Look up function signatures from MATLAB's help or the online reference page, not from this skill.** Argument lists, name-value pair (NVP) defaults, and supported-layer enumerations live in MATLAB's `help <function>` output and on the function's reference page. Use those as the source of truth instead of any inline parameter table in this skill — inline tables go stale across releases and burn context. This skill only flags name-value arguments that materially change the recipe (e.g., `ValidationThreshold` for accuracy-budgeted pruning). Lookup procedure:
  1. **First** try `help <function>` in the live MATLAB session. Fast and reflects the actually-installed release of the toolbox or support package.
  2. If `help` returns only a stub like "Run doc <function> for more information." — common for support-package functions whose help redirects to the browser doc — **fall back to the agent's web browsing of the online reference page** at `https://www.mathworks.com/help/<product>/ref/<funcname>.html` (lower-case function name). Extract every name-value argument with its default value, formatted as a markdown table, quoting defaults verbatim.
  3. If the function is not found at all (`which <func>` returns "not found") on a system that has the relevant support package installed, the support package is likely on a stale build. Ask the user to update via Add-On Explorer rather than working around the missing function.
- **Compression decision flow:** At the start of Phase 5 (Pattern 1), load `references/pattern1/compression-decision.md` and walk the user through the question flow (hardware + Simulink availability, primary goal, retraining tolerance). Pick the compression and code generation path based on the answers. Compression is not mandatory and the optimal combination of pruning, projection, and quantization depends on the goal — for example, on Cortex-M with a latency-bound LSTM model, the float32 path with CMSIS-DSP outperforms the quantized path because CMSIS-NN provides no INT8 kernel for recurrent layers.

### ASK FIRST

- Before each phase transition: "Is this step relevant to your project?"
- Before data splitting: existing train/val/test splits?
- Before model selection: problem type and constraints
- Before Simulink: existing Simulink model?
- Before quantization: hardware numeric capabilities (FP vs FXP)
- Before code generation: target deployment hardware
- Before compression and code generation (Pattern 1): walk the user through the decision flow in `references/pattern1/compression-decision.md` — hardware target + Simulink availability, primary goal, retraining tolerance. The answers determine the compression techniques and the code-replacement library to use. **Even if the hardware target is already stated**, you MUST still ask about the primary deployment goal (flash, SRAM, latency, accuracy) and present the user with the recommended recipe for confirmation before executing any compression step.

### NEVER

- Present the entire workflow at once
- Skip Environment Discovery or Project Discovery
- Open, load, or inspect user data before Project Discovery is confirmed
- Use banned legacy functions
- Assume toolbox or support package availability without checking
- Install support packages on the user's behalf
- Promise hardware-agnostic performance or "deploy anywhere"
- Generate `DAGNetwork`, `SeriesNetwork`, or `network` objects
- Run MATLAB commands directly in the MCP server without creating a script file first
- Skip numerical equivalency testing when importing 3P models
- Proceed to the next workflow step without explicit user permission
- Apply compression without first walking the user through the decision flow in `compression-decision.md`
- Use the imported model (with custom autogenerated layers) as numerical ground truth — always validate against the original 3P model via bundled Python
- Pass a `[C × T]` array with format `"CBT"` to a sequence model — always reshape to `[C × 1 × T]` for single-sequence inference
- Pass a `dlnetwork` to `prepareNetwork` — in R2026a the function takes a `dlquantizer` object (`prepareNetwork(quantObj)`) and mutates it in place. The legacy `net = prepareNetwork(net)` form is no longer defined

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See [www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list of additional trademarks. Other product or brand names may be trademarks or registered trademarks of their respective holders.


Copyright 2026 The MathWorks, Inc.
