# Generate C/C++/CUDA Code from a LiteRT Model

Complete workflow for generating C/C++ or CUDA code from a LiteRT model
(.tflite) using the MATLAB Coder Support Package for PyTorch and LiteRT Models (R2026a+).

## Critical: API Routing

Three different pipelines exist for `.tflite` models. Choose based on the goal:

| | Deep Learning Toolbox path (editable dlnetwork) | MATLAB Coder Support Package for PyTorch and LiteRT Models (code generation) | LiteRT Interpreter path (bit-true on-target) |
|---|---|---|---|
| Load | `importNetworkFromTensorFlow` | `loadLiteRTModel` | `loadTFLiteModel` |
| Object | `dlnetwork` | `LiteRTModel` | `TFLiteModel` |
| Inference | `predict(net, dlarray(...))` | `invoke(model, input)` | `predict(model, input)` |
| Codegen | `coder.loadDeepLearningNetwork` + `DeepLearningConfig` | Entry-point calls `loadLiteRTModel` + `invoke` | Generates code that calls LiteRT C++ API at runtime |
| Data layout (2-D images) | HWCN (MATLAB convention) | NHWC (LiteRT convention preserved) | HWCN |
| Since | R2022b | R2026a | R2024a |
| Use for | Transfer learning, compression (DLT tools) | Standalone C/C++/CUDA code generation | Bit-true inference via LiteRT interpreter on-target |
| Limitations | Converts model to dlnetwork; no support for quantized tensorflow models | — | No standalone C/CUDA — requires LiteRT runtime on target; must be built on target HW; not supported on macOS |

**Rule:** If the goal is to keep the model's source of truth in TensorFlow/LiteRT
and generate **standalone** C/C++/CUDA code from it, use the MATLAB Coder Support
Package for PyTorch and LiteRT Models path (`loadLiteRTModel` + `invoke`). Do not
use `importNetworkFromTensorFlow`, `importNetworkFromKeras`,
`coder.loadDeepLearningNetwork`, or `dlarray` on this path — those convert the
model to a `dlnetwork` first. **If the user needs quantization (`dlquantizer`),
projection, pruning, or `exportNetworkToSimulink`** and is OK with translating the
model to a `dlnetwork` using the Deep Learning Toolbox, then route to the
`matlab-deploy-embedded-ai` skill (Pattern 1), which covers `dlnetwork`-based
workflows.

**`loadTFLiteModel` path:** Use when the goal is bit-true inference that matches
the LiteRT interpreter exactly on the target hardware. The generated code calls
the LiteRT C++ API at runtime rather than producing standalone C/C++/CUDA — so the
LiteRT runtime library must be present on the target and the code must be built
on (or cross-compiled for) the target hardware. This path is not supported on
macOS. Choose `loadLiteRTModel` instead when you need portable standalone code
generation.

## Obtaining a .tflite Model

LiteRT models (`.tflite` files) can originate from multiple frameworks:

**From TensorFlow/Keras:** Convert using `tf.lite.TFLiteConverter` in Python.
See `references/tensorflow-to-litert-conversion.md` for complete workflows
covering SavedModel, `.keras`, and legacy `.h5` formats.

**From PyTorch:** Convert using `litert_torch` — a Google AI Edge workflow for
converting PyTorch models directly to LiteRT format without going through
TensorFlow. This is also a fallback route if `loadPyTorchExportedProgram` fails
due to unsupported operations — convert the model to `.tflite` via `litert_torch`
and use `loadLiteRTModel` instead.

**Note (R2026a):** After converting with `litert_torch`, the resulting `.tflite`
file may contain `keep_stablehlo_constant` metadata that prevents
`loadLiteRTModel` from loading it. Strip this metadata before use in MATLAB:

```python
from ai_edge_litert import schema_py_generated as schema
import flatbuffers

with open(tflite_path, "rb") as f:
    buf = f.read()

model = schema.ModelT.InitFromPackedBuf(buf, 0)
model.metadata = [
    m for m in model.metadata
    if (m.name.decode() if isinstance(m.name, bytes) else m.name)
    != "keep_stablehlo_constant"
]

builder = flatbuffers.Builder(len(buf) + 1024)
packed = model.Pack(builder)
builder.Finish(packed, b"TFL3")

with open(tflite_path, "wb") as f:
    f.write(bytes(builder.Output()))
```

This requires the `ai_edge_litert` and `flatbuffers` pip packages.

**From JAX:** JAX models can also be converted to `.tflite` format. This workflow
will be covered in a future skill update.

### Workaround: Stateful Models (R2026a)

`loadLiteRTModel` does not support models with stateful operations (e.g.,
stateful LSTM/GRU). Loading such a model produces:

> Models containing 'stateful' operations or tfl.assign_variable, tfl.call_once,
> tfl.read_variable, tfl.var_handle operations are not supported.

**Workaround:** Rewrite the model in Python to be stateless by passing hidden
and cell states as explicit inputs/outputs, then emulate stateful behavior in
MATLAB by feeding states back in a loop.

**Step 1 — Rewrite the model in Python:**

```python
import tensorflow as tf

# Original (fails): stateful=True stores state internally
# model = tf.keras.Sequential([
#     tf.keras.layers.LSTM(16, stateful=True, batch_input_shape=(1, 5, 3)),
#     tf.keras.layers.Dense(2)
# ])

# Workaround: stateful=False, pass states explicitly, unroll for tflite
input_seq = tf.keras.Input(batch_shape=(1, 5, 3), name='input_seq')
h_in = tf.keras.Input(batch_shape=(1, 16), name='h_in')
c_in = tf.keras.Input(batch_shape=(1, 16), name='c_in')

lstm_out, h_out, c_out = tf.keras.layers.LSTM(
    16, stateful=False, return_state=True, unroll=True
)(input_seq, initial_state=[h_in, c_in])
prediction = tf.keras.layers.Dense(2, name='prediction')(lstm_out)

model = tf.keras.Model(
    inputs=[input_seq, h_in, c_in],
    outputs=[prediction, h_out, c_out]
)

# Convert to tflite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open('stateless_lstm.tflite', 'wb') as f:
    f.write(tflite_model)
```

Key changes:
- `stateful=False` — no internal state variables
- `return_state=True` — outputs h and c explicitly
- `unroll=True` — required for tflite conversion (avoids TensorListReserve ops)
- States passed as explicit `Input` layers

**Step 2 — Emulate stateful inference in MATLAB:**

```matlab
model = loadLiteRTModel('stateless_lstm.tflite');

% Initialize states to zero
h = zeros(1, 16, 'single');
c = zeros(1, 16, 'single');

% Process sequence of inputs, carrying state forward
for step = 1:numSteps
    input_seq = getNextInput();  % [1 5 3] single
    [pred, h, c] = invoke(model, input_seq, h, c);
end
```

**Step 3 — Codegen entry-point:**

```matlab
function [pred, h_out, c_out] = statefulStep(modelPath, input_seq, h_in, c_in) %#codegen
    model = loadLiteRTModel(modelPath);
    [pred, h_out, c_out] = invoke(model, input_seq, h_in, c_in);
end
```

The caller maintains state between calls — the generated code itself is
stateless. This pattern works for any RNN (LSTM, GRU) that was originally
stateful.

## Load and Inspect

```matlab
model = loadLiteRTModel("model.tflite");
summary(model)
inSpecs = model.inputSpecifications;
outSpecs = model.outputSpecifications;
```

Use `inputSpecifications` to determine the expected input shape and type.
LiteRT models preserve NHWC layout (batch, height, width, channels).

**Variable-size batch dimension:** Models converted from TensorFlow often have
`Inf` as the first dimension (variable-size batch). Three options exist for
codegen:

| Option | When to use | Example |
|--------|-------------|---------|
| Fixed batch | Known batch size at deployment | `input = ones(1, 224, 224, 3, 'single')` |
| Unbounded variable | Batch varies with no upper limit (requires DMA) | `coder.typeof(single(0), [Inf 224 224 3], [1 0 0 0])` |
| Bounded variable | Batch varies up to a maximum (stack-allocates) | `coder.typeof(single(0), [8 224 224 3], [1 0 0 0])` |

For the general concept of bounded/unbounded variable-size inputs with
`coder.typeof`, see the `matlab-generate-code` skill. Below is the
LiteRT-specific application:

```matlab
% Fixed batch
input = ones(1, 224, 224, 3, 'single');
codegen -config cfg -args {coder.Constant("model.tflite"), input} mInvoke

% Unbounded variable batch
inputCT = coder.typeof(single(0), [Inf 224 224 3], [1 0 0 0]);
codegen -config cfg -args {coder.Constant("model.tflite"), inputCT} mInvoke

% Bounded variable batch (max 8)
inputCT = coder.typeof(single(0), [8 224 224 3], [1 0 0 0]);
codegen -config cfg -args {coder.Constant("model.tflite"), inputCT} mInvoke
```

**Multi-signature models:** A LiteRT model can contain multiple functions
(signatures). Use `FcnNames` to discover them and `FcnName` to target one:

```matlab
model = loadLiteRTModel("multi_sig.tflite");
model.FcnNames   % e.g. ["adder", "multiplier"]

% Inspect a specific function's I/O
summary(model, FcnName="adder")
inSpecs = inputSpecifications(model, FcnName="adder");

% Invoke a specific function
out = invoke(model, in, FcnName="adder");
```

If the model contains multiple functions, you **must** specify `FcnName` when
calling `invoke`, `inputSpecifications`, `outputSpecifications`, or `summary`.
Single-signature models have `FcnNames = {'main'}` — you do not need to pass
`FcnName` for these; `invoke(model, input)` works directly.

**Entry-point for multi-signature codegen:**

```matlab
function out = mInvokeAdder(modelPath, input) %#codegen
    model = loadLiteRTModel(modelPath);
    out = invoke(model, input, FcnName="adder");
end
```

**ExecutionMode:** Controls how the LiteRTModel executes inference in MATLAB.
Options are `"JIT"` (default — just-in-time compiled) and `"MEX"` (compiles a
MEX for faster repeated inference in MATLAB). This is a MATLAB-side execution
setting and is separate from generating a MEX via `codegen` for deployment.

```matlab
model = loadLiteRTModel("model.tflite", ExecutionMode="MEX");
model = loadLiteRTModel("model.tflite", ExecutionMode="JIT");
```

## Entry-Point Pattern

The standard entry-point for LiteRT model codegen:

```matlab
function out = mInvoke(modelPath, input) %#codegen
    model = loadLiteRTModel(modelPath);
    out = invoke(model, input);
end
```

**Entry-point for multi-signature codegen:**

```matlab
function out = mInvokeAdder(modelPath, input) %#codegen
    model = loadLiteRTModel(modelPath);
    out = invoke(model, input, FcnName="adder");
end
```

## Code Generation (MEX, Library, Executable)

For the full codegen workflow (MEX generation, verification, library/executable
targets, `coder.Constant` usage, and `coder.DeepLearningConfig` notes), see
`codegen-workflow.md`.

Quick reference — CPU MEX:

```matlab
cfg = coder.config("mex");
input = ones(1, 224, 224, 3, "single");  % NHWC — match inputSpecifications
codegen -config cfg -args {coder.Constant("model.tflite"), input} mInvoke
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `importNetworkFromTensorFlow("model")` | Returns `dlnetwork` (DLT path), cannot use `invoke` | `loadLiteRTModel("model.tflite")` |
| `importNetworkFromKeras("model.keras")` | Returns `dlnetwork` (DLT path), unrelated to LiteRT codegen | Convert to `.tflite` first, then `loadLiteRTModel` |
| `loadTFLiteModel(...)` for standalone codegen | Generates code that calls LiteRT C API at runtime — not standalone C/CUDA | `loadLiteRTModel("model.tflite")` for standalone code generation |
| `predict(model, input)` | Wrong inference function for LiteRTModel | `invoke(model, input)` |
| `classify(model, input)` | Wrong inference function for LiteRTModel | `invoke(model, input)` |
| `coder.loadDeepLearningNetwork(...)` | DLT codegen API, not compatible with LiteRTModel | Use `loadLiteRTModel` in the entry-point directly |
| `coder.DeepLearningConfig('tensorrt')` | Ignored by the MATLAB Coder Support Package path | Optional — has no effect on LiteRTModel codegen |
| Input shape `[224, 224, 3]` (HWC) from `imread` | LiteRTModel expects NHWC with batch dim | Use `[1, 224, 224, 3]` (check `inputSpecifications`) |
| Input shape `[1, 3, 224, 224]` (NCHW) | That's PyTorch convention, not LiteRT | LiteRT uses NHWC: `[1, 224, 224, 3]` |
| Passing LiteRTModel object to codegen | Rare pattern, not recommended | Pass model path as `coder.Constant` string |
| Confusing `ExecutionMode` with codegen MEX target | `ExecutionMode` controls in-MATLAB execution, not code generation | Use `coder.config("mex")` + `codegen` for the MEX-first verification workflow |
| Omitting `coder.Constant` for model path | Codegen needs model path at compile time | Always wrap model path: `coder.Constant("model.tflite")` |
| Calling `invoke` without `FcnName` on a multi-signature model | Error — must specify which function to invoke | `invoke(model, input, FcnName="adder")` |

## Conventions

- Always use `loadLiteRTModel` for `.tflite` code generation workflows
- LiteRT models use NHWC layout — do not confuse with PyTorch's NCHW
- For multi-signature models, always specify `FcnName` in `invoke`
- Do NOT use `importNetworkFromTensorFlow`, `importNetworkFromKeras`, `coder.loadDeepLearningNetwork`, `dlarray`, `predict`, or `classify` on this skill's `.tflite` codegen path. If the user needs a `dlnetwork` for quantization/projection/pruning or `exportNetworkToSimulink` prior to codegen, route to the `matlab-deploy-embedded-ai` skill
- Do NOT use `loadTFLiteModel` on this path — it produces code that calls the LiteRT C API at runtime (bit-true interpreter path), not standalone C/CUDA. Use `loadLiteRTModel` for standalone code generation
- For shared conventions (MEX-first, `coder.Constant`, verify before lib), see `codegen-workflow.md`

## Use in Simulink

The `dlosslib` library provides a dedicated `LiteRT` block for `.tflite` models.
Usage is identical to the PyTorch ExportedProgram block:

```matlab
modelName = "my_litert_model";
new_system(modelName);
add_block("dlosslib/LiteRT", [modelName "/MyModel"]);
set_param([modelName "/MyModel"], "ModelFilePath", "/path/to/model.tflite");
```

The block auto-detects input/output shapes from the `.tflite` file.

**Multi-signature models in Simulink:** For `.tflite` models with multiple
functions, the LiteRT block provides a `FcnName` drop-down parameter to
select which function to invoke. Set it programmatically with:

```matlab
set_param([modelName "/MyModel"], "FcnName", "detect");
```

For full Simulink integration details (simulation modes, code generation config,
MATLAB Function block alternative), see `simulink-workflow.md`.

## Detailed References

- `codegen-workflow.md` — Shared codegen steps: MEX generation, verification,
  library/executable targets, `coder.Constant`, `coder.DeepLearningConfig`.
- `litert-numeric-verification.md` — pyrun-based pattern for comparing Python
  LiteRT Interpreter vs MATLAB outputs.
- `simulink-workflow.md` — Simulink integration for both PyTorch and LiteRT
  models (dedicated blocks, MATLAB Function block path, code generation config).
- "Generate CUDA Code for YOLO v11 (LiteRT)" (MATLAB documentation) —
  End-to-end example with preprocessing, postprocessing (NMS), and GPU Coder CUDA
  code generation from a LiteRT object detection model.

----

Copyright 2026 The MathWorks, Inc.

----
