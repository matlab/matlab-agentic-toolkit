# Using PyTorch and LiteRT Models in Simulink

Integrate a PyTorch ExportedProgram (.pt2) or LiteRT (.tflite) model into a
Simulink model for simulation and C/C++ code generation. Two paths exist — both
support pre/post-processing; choose based on how you want to structure it:
separate Simulink blocks around the dedicated model block (Path A), or
everything inside a single block (Path B).

## Path A: Dedicated PyTorch ExportedProgram Block (preferred)

The `PyTorch ExportedProgram` block (from the `dlosslib` library) is the
recommended path. It auto-detects input/output shapes from the `.pt2` file — no
code to write.

### Setup

```matlab
% Create model and add the dedicated block
modelName = "my_pytorch_model";
new_system(modelName);
add_block("dlosslib/PyTorch ExportedProgram", [modelName "/MyModel"]);

% Point it at the .pt2 file (absolute path or on MATLAB path)
set_param([modelName "/MyModel"], "ModelFilePath", "/path/to/model.pt2");
```

After setting `ModelFilePath`, the block reads the `.pt2` and auto-configures:
- Input port shape and type from `inputSpecifications`
- Output port shape and type from `outputSpecifications`

### Block Mask Parameters

| Parameter | Purpose | Default |
|-----------|---------|---------|
| `ModelFilePath` | Path to the `.pt2` file | `"untitled.pt2"` |
| `FcnName` | Function name (if model defines multiple) | `'<empty>'` (uses default) |
| `SampleTime` | Block sample time | `"-1"` (inherited) |
| `InputsTable` | Per-input: name, type, model size, **permutation** | Auto-detected from `.pt2` |
| `OutputsTable` | Per-output: name, type, model size, port size, **permutation** | Auto-detected from `.pt2` |

### Input Permutation (feeding HWC image data)

The `InputsTable` 4th column is a permutation vector that maps Simulink port
signal dimensions to model dimensions. This lets you feed image data in NHWC
layout (natural for MATLAB/Simulink) without manual `permute` calls. For
multi-input models, each row in `InputsTable` specifies its own independent
permutation — inputs can have different layouts.

```matlab
% Default: identity [1 2 3 4] — port signal must be NCHW [1,3,224,224]
% To accept NHWC [1,224,224,3] at the port and permute internally:
set_param([modelName "/MyModel"], "InputsTable", ...
    "{'in1','single','[1 3 224 224]','[1 4 2 3]'}");
```

The permutation `[1 4 2 3]` means: port dim 1→model dim 1, port dim 2→model dim 4,
port dim 3→model dim 2, port dim 4→model dim 3. So port shape NHWC is permuted to
NCHW before inference.

**Source-signal shape must match the pre-permutation port shape, not the model
shape.** The permutation reorders *after* the port receives the signal, so:

- With `InputsTable` permutation `[1 2 3 4]` (identity, default): the source
  must produce **NCHW** (e.g., `[1 3 224 224]`) — same as the model.
- With `InputsTable` permutation `[1 4 2 3]`: the source must produce
  **NHWC** (e.g., `[1 224 224 3]`) — the block permutes it to NCHW internally.

Feeding NCHW to a port configured with `[1 4 2 3]` double-permutes the axes,
so `sim()` errors with a shape-mismatch inside the DL block. Verify the
source shape before wiring: `size(u)` on a signal probe or a Display block
inserted between the source and the DL block.

### Signal Dimensionality (1-D vs 2-D)

Simulink Constant blocks with `VectorParams1D = 'on'` (the default) produce
1-D signals. Simulink passes 1-D signals as **column vectors** into MATLAB
Function blocks and the internal MLFB of dedicated blocks. If the model
expects a row vector (e.g., `[1 4]`), the input arrives as `[4 1]` and
inference fails with a dimension mismatch.

This only affects models whose inputs are 2-D (e.g., `[1 N]` feature
vectors). Image models with 4-D inputs (`[1 H W C]`) are unaffected because
4-D arrays cannot be collapsed to 1-D.

**Fix:** Set `VectorParams1D = 'off'` on the Constant block so the signal
retains its 2-D shape:

```matlab
add_block("simulink/Sources/Constant", [modelName "/Input"], ...
    "Value", "ones(1,4,'single')", "VectorParams1D", "off");
```

Alternatively, use a Reshape block between the source and the model block to
enforce the expected dimensions.

### Variable-Size (Dynamic Batch) in Simulink

Models with a variable-size batch dimension (`Inf` in `inputSpecifications`)
require additional configuration in Simulink:

**OutputsTable maximum size:** The OutputsTable has an "Inferred Size" column
that shows `Inf` for variable-size dimensions and a "Maximum Size" column that
defaults to the same values. Users can set a finite upper bound in the Maximum
Size column to constrain memory allocation.

**When a maximum bound is required:**
- Rapid Accelerator mode
- Accelerator mode
- GPU Acceleration enabled (generated CUDA code)

In these modes, you must specify a finite maximum size for all variable-size
dimensions — unbounded `Inf` is not supported.

**Enable dynamic memory allocation:** For variable-size signals, enable
dynamic memory allocation on the model:

```matlab
set_param(modelName, 'MATLABDynamicMemAlloc', 'on');
```

**MATLAB Function block variable-size outputs:** If using Path B (MATLAB
Function block) and the block output is variable-size, you must enable
variable-size output on the MATLAB Function block port. In the Ports and Data
Manager, set the output port's "Variable size" property to on.

### Connect and Simulate

```matlab
% InputsTable permutation drives the required source shape:
%   [1 2 3 4] (default) → source produces NCHW, e.g. [1 3 224 224]
%   [1 4 2 3]           → source produces NHWC, e.g. [1 224 224 3]

% Example: identity permutation → NCHW source
add_block("simulink/Sources/Constant", [modelName "/Input"], ...
    "Value", "randn(1,3,224,224,'single')");   % NCHW
add_block("simulink/Sinks/Display", [modelName "/Output"]);
add_line(modelName, "Input/1", "MyModel/1");
add_line(modelName, "MyModel/1", "Output/1");

% Example: [1 4 2 3] permutation → NHWC source
% (Use this variant only when InputsTable was set with [1 4 2 3])
%   "Value", "randn(1,224,224,3,'single')"     % NHWC

% Simulate
out = sim(modelName, "StopTime", "0");
```

### Simulation Modes

The dedicated `PyTorch ExportedProgram` block runs in all Simulink simulation
modes: **Normal**, **Accelerator**, and **Rapid Accelerator**.

**Contrast with the PyTorch co-execution block.** MATLAB also offers a PyTorch
co-execution path (the model is invoked via a Python interpreter through
MATLAB↔Python interop). The co-execution block does **NOT** support
Accelerator or Rapid Accelerator modes — those modes require the model to be
compiled into the Simulink build, which the Python-interop path cannot
provide. If Accelerator or Rapid Accelerator is needed, the dedicated
`dlosslib/PyTorch ExportedProgram` block (Path A) is the only option.
Co-execution is Normal-mode only.

**Selecting the simulation mode.** Simulink defaults to Normal mode — you
must explicitly set `SimulationMode` to switch. Even with the dedicated
block, Accelerator / Rapid Accelerator is not automatic:

```matlab
set_param(modelName, "SimulationMode", "rapid-accelerator");  % "normal" | "accelerator" | "rapid-accelerator"
```

Do this before calling `sim(modelName)`.

#### Optional: native hardware acceleration

For faster simulation on any mode, enable native hardware acceleration so
Simulink uses SIMD instructions tuned to the host CPU:

```matlab
set_param(modelName, "SimHardwareAcceleration", "native");   % default is "generic"
```

`SimHardwareAcceleration` accepts three values: `"off"`, `"generic"` (default —
baseline SIMD, portable across hosts), and `"native"` (host-CPU-specific SIMD,
fastest). `"native"` may force a rebuild when the model is moved to a different
host machine. This setting affects simulation only — it has no effect on
generated code.

### Generate Code

Configure the model for code generation, then build:

```matlab
set_param(modelName, "Solver", "FixedStepDiscrete");
set_param(modelName, "FixedStep", "1");
set_param(modelName, "SystemTargetFile", "grt.tlc");  % Simulink Coder (generic)
% Or: set_param(modelName, "SystemTargetFile", "ert.tlc"); % Embedded Coder (embedded targets, requires EC license)
slbuild(modelName);
```

The code generator fully inlines the model inference into the generated code —
no external runtime or `.pt2` file needed at deployment.

For SIMD instruction sets, reduction-loop vectorization, and multithreaded loops,
see the `matlab-generate-code` skill. For serializing large DNN weight constants
to data files, see `references/dnn-codegen-options.md`. Those options apply
equally to `slbuild` and command-line `codegen`.

## Path B: MATLAB Function Block (single-block custom logic)

Use when you want pre/post-processing (normalization, permutation, argmax) and
model inference all within a single block. Note: pre/post-processing can also be
done with separate Simulink blocks around the dedicated PyTorch block (Path A) —
Path B is for when you want everything self-contained in one block.

### Setup

```matlab
modelName = "my_pytorch_custom";
new_system(modelName);
add_block("simulink/User-Defined Functions/MATLAB Function", ...
    [modelName "/Inference"]);
```

### Set the Block Script

Use `MATLABFunctionConfiguration` to set the function body:

```matlab
config = get_param([modelName "/Inference"], "MATLABFunctionConfiguration");
config.FunctionScript = sprintf([ ...
    'function out = fcn(input)\n' ...
    '%%#codegen\n' ...
    'net = loadPyTorchExportedProgram(''model.pt2'');\n' ...
    'out = invoke(net, input);\n' ...
    'end\n']);
```

The model file path is a string literal in the block — do NOT use
`coder.Constant` (that is only needed for MATLAB `codegen`). Simulink
resolves compile-time constants from string literals automatically.

### Key Differences from MATLAB Codegen

| Aspect | MATLAB `codegen` | Simulink (both paths) |
|--------|----------------------|----------------------|
| Model path | `coder.Constant("model.pt2")` in `-args` | String literal in block / mask parameter |
| Entry-point | Separate `.m` file | Inline in MATLAB Function block or not needed (Path A) |
| Solver | N/A | Must be fixed-step for codegen |
| Target | `coder.config("mex")` / `coder.config("lib")` | `SystemTargetFile` (`grt.tlc` for Simulink Coder, `ert.tlc` for Embedded Coder) |
| Build command | `codegen` | `slbuild` |

## When to Use Each Path

| Scenario | Recommended |
|----------|-------------|
| Drop-in model inference, no pre/post-processing | Path A (dedicated block) |
| Pre/post-processing with separate Simulink blocks around the model | Path A (dedicated block) + surrounding blocks |
| All logic (pre-processing + inference + post-processing) in one block | Path B (MATLAB Function block) |
| Need the model inside a larger Simulink system with signal routing | Either — Path A for clean interfaces, Path B for tight coupling |
| Need to parameterize the model file path at runtime | Neither — the `.pt2` must be known at compile time |

## LiteRT Models

The same two paths apply to LiteRT (`.tflite`) models:

### Path A: Dedicated LiteRT Block (preferred)

The `dlosslib/LiteRT` block has the same integration pattern as the PyTorch
ExportedProgram block — set `ModelFilePath` to the `.tflite` file:

```matlab
add_block("dlosslib/LiteRT", [modelName "/MyModel"]);
set_param([modelName "/MyModel"], "ModelFilePath", "/path/to/model.tflite");
```

The block auto-detects input/output shapes from the `.tflite` file.

**Multi-signature models:** For `.tflite` models containing multiple functions,
use the `FcnName` drop-down (or set it programmatically) to select which
function to invoke:

```matlab
set_param([modelName "/MyModel"], "FcnName", "detect");
```

### Path B: MATLAB Function Block

Same pattern as PyTorch but using `loadLiteRTModel` and `invoke`:

```matlab
config = get_param([modelName "/Inference"], "MATLABFunctionConfiguration");
config.FunctionScript = sprintf([ ...
    'function out = fcn(input)\n' ...
    '%%#codegen\n' ...
    'net = loadLiteRTModel(''model.tflite'');\n' ...
    'out = invoke(net, input);\n' ...
    'end\n']);
```

For multi-signature models in a MATLAB Function block, pass `FcnName` to
`invoke`:

```matlab
'out = invoke(net, input, FcnName="detect");\n' ...
```

## Code Generation Configuration Checklist

For either path, the Simulink model must be configured for code generation:

1. **Fixed-step solver** — `set_param(model, "Solver", "FixedStepDiscrete")`
2. **System target file** — `"grt.tlc"` (Simulink Coder, generic) or `"ert.tlc"` (Embedded Coder, embedded targets — requires EC license)
3. **Target language** — `"C"` or `"C++"` (both work; defaults to `"C"`)
4. **Build** — `slbuild(model)` generates and compiles

The generated code fully inlines all model operations (convolutions, activations,
etc.) with SIMD intrinsics where applicable. No external runtime dependency.

----

Copyright 2026 The MathWorks, Inc.

----
