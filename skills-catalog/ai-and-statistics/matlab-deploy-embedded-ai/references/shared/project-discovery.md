# Project Discovery (Interactive)

Gather complete project context through conversation **before any technical work**.
Do NOT open, load, inspect, or analyze user data, models, or Simulink files during
this phase. Record file paths only.

## Conversational Exchanges

Conduct 3-4 natural back-and-forth conversations (not a wall-of-text questionnaire).

### Exchange 1: Problem and Application

1. What is your application domain? (automotive, industrial, medical, consumer, aerospace, etc.)
2. What AI task are you solving? (classification, regression, anomaly detection, virtual sensor, control, object detection, etc.)
3. Describe the system: what does the AI component do within the larger system?
4. What physical signals or data types are involved? (sensor data, images, audio, time-series, tabular)

### Exchange 2: Hardware and Constraints

5. What is the target deployment hardware? (specific MCU/SoC, or general category like Cortex-M, Cortex-A, GPU, FPGA, NPU)
6. Does the target have floating-point hardware, or is fixed-point / integer-only required?
7. What are the hard constraints? (flash/ROM budget, RAM budget, latency, power)
8. Are there safety or compliance requirements? (DO-178C, ISO 26262, IEC 62304, etc.)
9. What accuracy level is needed vs. acceptable tradeoffs for memory/speed/power?

### Exchange 3: Data and Model Status

10. Do you have training data? What format, size, and location?
11. Do you already have train/validation/test splits?
12. Do you have an existing trained model, or are you starting from scratch?
13. If importing: what framework? (PyTorch, ONNX, TensorFlow) What format? (.pt, .pt2, .onnx, .h5)
14. If importing: do you have the original Python training code / environment?

### Exchange 4: System Integration and Workflow Goals

15. Do you have an existing Simulink model for the system?
16. What verification/testing approach is needed? (SIL, PIL, HIL, formal verification)
17. What is the goal of this session? (end-to-end deployment, compression study, Simulink integration, code generation, etc.)

## Gate Checks

After gathering information, cross-reference with Environment Discovery results:

**Import Converter Gate:**
- If user wants PyTorch import (Pattern 1) → verify `Deep Learning Toolbox Converter for PyTorch Models` is installed
- If user wants ONNX import → verify `Deep Learning Toolbox Converter for ONNX Model Format`
- If user wants TensorFlow import → verify `Deep Learning Toolbox Converter for TensorFlow Models`
- If user wants direct PyTorch-to-C (Pattern 2) → verify `MATLAB Coder Support Package for PyTorch and LiteRT Models`
- If converter is missing → **STOP**, ask user to install from Add-On Explorer

**Codegen Gate:**
- If user wants C code → verify MATLAB Coder is installed
- If user wants optimized embedded C → verify Embedded Coder (warn if missing)
- If user wants HDL → verify HDL Coder + Deep Learning HDL Toolbox

**Compression Gate:**
- If user needs compression → verify Deep Learning Toolbox Model Compression Library

## Determine Workflow Pattern

Apply the decision tree from the top-level SKILL.md:

1. **FPGA or NPU target** → Not covered by this skill. Inform the user and stop.
2. **GPU (CUDA) target** → Pattern 2
3. **MCU/DSP/embedded CPU + train from scratch** → Pattern 1 (native training path)
4. **MCU/DSP/embedded CPU + 3P model + needs compression/Simulink/weight inspection** → Pattern 1 (import path)
5. **MCU/DSP/embedded CPU + 3P PyTorch model + just needs C fast** → Pattern 2

## Compile Project Summary

Present a structured summary for user confirmation:

```
Project Summary:
- Domain: [domain]
- AI Task: [task type]
- Model Origin: [MATLAB-native / PyTorch / ONNX / TensorFlow]
- Target Hardware: [specific or category]
- Numeric Type: [floating-point / fixed-point / integer-only]
- Constraints: [flash, RAM, latency, power]
- Compression Needed: [yes/no, which techniques]
- Simulink Integration: [yes/no, existing model?]
- Verification: [SIL/PIL/HIL/formal/none]
- Workflow Pattern: [1/2]
- Session Goal: [goal]
```

**Do NOT proceed until the user confirms the summary.**

After confirmation, load the appropriate pattern workflow file:
- Pattern 1 → `references/pattern1/workflow.md`
- Pattern 2 → `references/pattern2/workflow.md`


Copyright 2026 The MathWorks, Inc.
