# Pattern 1: MathWorks-Native Models for Lean Hardware

Interactive, step-by-step workflow for designing, training (or importing), verifying,
compressing, and deploying AI models to resource-constrained embedded targets using
MATLAB and Simulink.

## When to Use

- User wants to build and deploy a small AI model (< 500 KB) to embedded hardware
- User targets resource-constrained devices: Cortex-M, Cortex-A/R, DSPs, NPUs
- User needs compression (quantization, pruning, projection) before deployment
- User needs Simulink integration for system-level simulation
- User needs weight inspection, modification, or fixed-point codegen
- User mentions: virtual sensors, anomaly detection, predictive maintenance,
  state estimation, time-series classification, signal-based AI
- User imports a 3P model (PyTorch/ONNX/TF) and needs capabilities beyond raw C code

## When NOT to Use

- User has a large model (> 1 MB) and just needs C quickly from PyTorch → Pattern 2
- User wants GPU/CUDA deployment → Pattern 2
- User wants NPU or FPGA deployment (not covered by this skill)
- User wants to train purely in Python without MATLAB integration
- User is working with generative AI, LLMs, or foundation models

## Rules

### ALWAYS
- Complete Environment Discovery + Project Discovery (from shared/) before any technical work
- Check toolboxes and support packages before every phase
- **Create `.m` scripts** for each workflow step; execute via `run_matlab_file` -- never run ad-hoc MATLAB commands without first writing the script file
- **Pause after each step** and ask user for permission to proceed; let them inspect scripts
- Use `trainnet` for DL training (produces `dlnetwork`), `fitcnet`/`fitrnet` for MLPs
- Use `rng("default")` before data splitting
- Format sequence data as cell arrays of [T x C] single matrices for trainnet
- Use `networkDistributionDiscriminator` for OOD detection (not custom implementations)
- Use `exportNetworkToSimulink` with the **compressed** model when compression is applied
- For fixed-point C: export the **quantized** network (`quantize()` output) to Simulink
- For float32 C via direct MATLAB Coder: `lstmProjectedLayer` and `gruProjectedLayer` are codegen-supported; `ProjectedLayer` is supported when its contents are stateless. Call `unpackProjectedLayers` if a `ProjectedLayer` wraps a stateful LSTM/GRU. Quantized networks (`quantize()` output) are not supported by `coder.loadDeepLearningNetwork` — use the Simulink path instead.
- Generate MEX for desktop validation before generating C code for target
- Verify training calls with a tiny input (2-5 samples, 1-2 epochs) before full training
- Warn about missing Embedded Coder when doing code generation
- **Load trained/imported/rebuilt models in Deep Network Designer** for user inspection
- **Walk the user through the compression-decision question flow** (load `compression-decision.md`) at the start of Phase 5 to choose the right combination of pruning, projection, and quantization based on hardware target, deployment goal, and retraining tolerance
- **Propose test count** for numerical equivalency tests and get user agreement before running
- **Open code generation report** when code generation is complete

### NEVER
- Use banned legacy functions (see top-level SKILL.md)
- Assume toolbox or support package availability without checking
- Install support packages on the user's behalf
- Implement OOD detection, pruning, projection, or quantization with custom code
- Pass a quantized network (output of `quantize()`) to `coder.loadDeepLearningNetwork`
- Generate `DAGNetwork`, `SeriesNetwork`, or `network` objects
- Use `predict(discriminator, ...)` -- use `isInNetworkDistribution` / `distributionScores`
- Skip Environment Discovery or Project Discovery

---

## Workflow Phases

7 sequential phases. The workflow is iterative -- compression or Simulink results
may require returning to earlier phases. At each phase boundary, ask whether the
next phase is relevant.

**Prerequisites (already completed before this file is loaded):**
- Environment Discovery (silent) — via `references/shared/environment-setup.md`
- Project Discovery (interactive) — via `references/shared/project-discovery.md`

The Project Summary determines whether Phase 3 uses the **training** or **import** sub-path.

### Phase 1: Workflow Plan

Based on the Project Summary, determine applicable phases and present a tailored plan.

**Problem-to-approach mapping:**

| Problem Type | Recommended Approach | Toolbox |
|-------------|---------------------|---------|
| Tabular classification | `fitcnet` | Stats/ML |
| Tabular regression | `fitrnet` | Stats/ML |
| Time-series / sequence | LSTM, GRU, or 1D-CNN via `trainnet` | DLT |
| Signal classification | 1D-CNN via `trainnet` | DLT |
| Small image classification | CNN via `trainnet` | DLT |
| Anomaly detection (tabular) | Autoencoder via `trainnet` | DLT |
| 3P model import | Import + native rebuild | DLT + Converter |

Present the plan and get confirmation before proceeding.

**Pause.** "Does this workflow plan match your needs?"

### Phase 2: Data Preparation

Load [`data-preparation.md`](data-preparation.md).
- Load and inspect data for the first time
- Handle preprocessing, normalization, feature engineering
- Split data with `rng("default")` and `cvpartition`
- Format sequences as cell arrays of [T x C] single matrices

**Pause.** "Shall we proceed to model design?"

### Phase 3: AI Modeling

**Two sub-paths based on Project Discovery:**

#### Path A: MATLAB-Native Training

Load [`training-native.md`](training-native.md).
- Confirm approach from Phase 1 (Workflow Plan)
- Create a training script (`.m` file) and execute via `run_matlab_file`
- Train with `trainnet` (DL) or `fitcnet`/`fitrnet` (MLP)
- Verify training call with tiny input before full run
- Evaluate on test set; check accuracy requirements from Project Discovery
- **Load trained model in Deep Network Designer** (`deepNetworkDesigner(net)`) for user inspection

#### Path B: 3P Model Import and Native Rebuild

Load [`import-weight-extraction.md`](import-weight-extraction.md).
- Import PyTorch/ONNX/TensorFlow model
- Extract weights from imported network

Then load [`native-rebuild-patterns.md`](native-rebuild-patterns.md).
- Build fresh native dlnetwork using standard MATLAB layers
- Transfer weights from imported to native network
- **Run numerical equivalency tests:**
  1. Propose test count and rationale to user; wait for agreement
  2. Collect reference outputs from original 3P model
  3. Run same inputs through imported/rebuilt MATLAB model
  4. Compare and report: MAE, max error, cosine similarity
  5. Verify max error < 1e-5 for identical architectures
- **Load rebuilt model in Deep Network Designer** (`deepNetworkDesigner(netNative)`) for user inspection

If custom layers are needed for the rebuild, also load
[`custom-layers-codegen.md`](custom-layers-codegen.md).

**Pause.** "Shall we proceed to AI verification?"

### Phase 4: AI Verification

Load [`references/shared/ai-verification.md`](../shared/ai-verification.md).
- **Always** recommend OOD detection with `networkDistributionDiscriminator`
- Convert `fitcnet`/`fitrnet` to `dlnetwork` for verification if needed
- Check AI Verification Library availability for formal verification
- Suggest empirical testing: adversarial, corner-case, distribution shift

**Pause.** "Shall we proceed to model compression?"

### Phase 5: Model Compression and Quantization

**Step 5.1 — Walk the user through the decision flow.**
Load [`compression-decision.md`](compression-decision.md) FIRST. Ask the user about
their hardware target (combined with Simulink availability), primary deployment
goal (flash, SRAM, latency, integer-only, accuracy), and retraining tolerance. Skip
the retraining question if the dataset is unavailable. Present the recommended path
and confirm with the user before applying any technique.

**Step 5.2 — Apply the chosen techniques.**
Load [`compression.md`](compression.md) for the technique-level details.
- Compression order when multiple techniques apply: **(1) Pruning, (2) Projection, (3) Quantization**
- Use official functions only -- no custom implementations
- After each compression step, **report the accuracy delta vs the uncompressed baseline** on a held-out set. The compressed network is not expected to be numerically equivalent to the original; the relevant question is how much the deployment-relevant metric (classification accuracy, regression MAE/RMSE, etc.) has degraded and whether the budget from Project Discovery still holds.
- Revisit verification (Phase 4) after compression
- Re-check accuracy requirements from Project Discovery against compressed model
- If the accuracy-vs-size tradeoff is unacceptable: iterate back to Phase 3

**Step 5.3 — Try alternative paths when retraining is acceptable.**
For an LSTM-heavy flash-bound model, generate both project+quantize and quantize-only
variants, measure flash and MAE, and let the user choose. Don't assume the combined
pipeline is best without comparison.

**Pause.** "Shall we proceed to Simulink integration?"

### Phase 6: Simulink Integration and Simulation

Load [`simulink-integration.md`](simulink-integration.md).
- For fixed-point deployment: export the **quantized** network via `exportNetworkToSimulink(qNet)`
  (produces fixed-point Simulink blocks → integer C code)
- For float32 deployment: export the projected (or pruned) network directly. In R2026a,
  `exportNetworkToSimulink` accepts projected networks; `unpackProjectedLayers` is no
  longer required for the Simulink path. For the direct MATLAB Coder path,
  `lstmProjectedLayer` and `gruProjectedLayer` are codegen-supported; unpack only
  when a `ProjectedLayer` wraps a stateful LSTM/GRU.
- If placeholder layers appear, load [`placeholder-blocks.md`](placeholder-blocks.md)
- For `fitcnet`/`fitrnet`: use Stats/ML Predict blocks
- Open-loop fallback if no Simulink model available
- Simulate with `Simulink.SimulationInput` + `sim()`
- **Run numerical equivalency tests** comparing Simulink outputs to compressed MATLAB model outputs. Report MAE, max error. Ensure results are within expected tolerances.

**Pause.** "Shall we proceed to code generation?"

### Phase 7: Code Generation and Deployment

Load [`codegen-embedded.md`](codegen-embedded.md).
- Check for MATLAB Coder, Simulink Coder, Embedded Coder
- Generate MEX first for desktop validation
- **Run numerical equivalency tests** comparing MEX/generated code outputs to Simulink and MATLAB compressed model outputs. This validates the full pipeline: 3P model → MATLAB → compressed → Simulink → C code.
- Generate C code for target hardware
- **Open the code generation report** (`web(reportPath)`) so the user can inspect generated code, warnings, and metrics
- Present deployment summary and checklist

---

## Deliverable Structure

When generating scripts, organize as:

```
project_name/
  embeddedAIWorkflow.mlx          Main Live Script (orchestration)
  scripts/
    step01_prepareData.m          Data preprocessing (executed via run_matlab_file)
    step02_buildNetwork.m         Network construction
    step03_trainModel.m           Training wrapper
    step04_evaluateModel.m        Evaluation metrics
    step05_compressModel.m        Compression pipeline
    step06_exportToSimulink.m     Simulink export
    step07_generateCode.m         Code generation
    step08_verifyEquivalency.m    Full pipeline numerical equivalency tests
  helpers/
    checkOOD.m                    OOD detection (codegen-ready)
    predictForCodegen.m           Codegen entry-point (codegen-ready)
  data/
```

**Script-based execution:** Each `stepXX_*.m` script is self-contained and executed
via `run_matlab_file`. This gives users full visibility
into what code runs at each step and enables them to inspect, modify, and re-run
individual steps. Never run ad-hoc commands in the MCP server.

Functions for code generation must use `arguments` blocks, avoid dynamic features,
and use `single` precision.


Copyright 2026 The MathWorks, Inc.
