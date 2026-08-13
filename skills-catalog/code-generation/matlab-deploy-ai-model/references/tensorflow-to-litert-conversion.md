# Converting TensorFlow/Keras Models to LiteRT (.tflite)

How to convert TensorFlow models to LiteRT format for use with
`loadLiteRTModel` and MATLAB Coder code generation.

## Steps

1. Convert to `.tflite` in Python (this reference)
2. Load in MATLAB with `loadLiteRTModel`
3. Generate code with `codegen`

## Prerequisites

Python environment with TensorFlow installed:

```bash
pip install tensorflow
```

TensorFlow 2.x is required. The `tf.lite.TFLiteConverter` API is the standard
conversion tool.

## From SavedModel

A SavedModel is a directory containing `saved_model.pb` and a `variables/`
subdirectory. This is TensorFlow's standard serialization format.

```python
import tensorflow as tf

converter = tf.lite.TFLiteConverter.from_saved_model("saved_model_dir")
tflite_model = converter.convert()

with open("model.tflite", "wb") as f:
    f.write(tflite_model)
```

**Common sources of SavedModels:**
- TensorFlow Hub downloads
- `model.export("path")` (TF 2.16+)
- `tf.saved_model.save(model, "path")`
- Training pipelines that checkpoint as SavedModel

## From .keras Format

The `.keras` format is the recommended Keras serialization format (TF 2.12+).

```python
import tensorflow as tf

model = tf.keras.models.load_model("model.keras")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open("model.tflite", "wb") as f:
    f.write(tflite_model)
```

## From Legacy .h5 Format

The HDF5 (`.h5`) format is the legacy Keras format. Same conversion pattern —
load first, then convert:

```python
import tensorflow as tf

model = tf.keras.models.load_model("model.h5")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open("model.tflite", "wb") as f:
    f.write(tflite_model)
```

## From SavedModel with Multiple Signatures

A TensorFlow SavedModel can contain multiple serving signatures (functions).
To preserve them in the `.tflite` file, pass `signature_keys` to the converter:

```python
import tensorflow as tf

converter = tf.lite.TFLiteConverter.from_saved_model(
    "saved_model_dir",
    signature_keys=["adder", "multiplier"]
)
tflite_model = converter.convert()

with open("multi_sig.tflite", "wb") as f:
    f.write(tflite_model)
```

To discover available signature keys before conversion:

```python
loaded = tf.saved_model.load("saved_model_dir")
print(list(loaded.signatures.keys()))  # e.g. ['adder', 'multiplier']
```

The resulting `.tflite` file contains both functions. In MATLAB, these map to
`FcnNames` on the `LiteRTModel` object:

```matlab
model = loadLiteRTModel("multi_sig.tflite");
model.FcnNames  % ["adder", "multiplier"]
out = invoke(model, input, FcnName="adder");
```

**Note:** If `signature_keys` is omitted, only the default serving signature
is exported. To include all signatures, list them explicitly.

## Verifying the Converted Model

After conversion, verify the `.tflite` model produces correct outputs:

```python
import tensorflow as tf
import numpy as np

interpreter = tf.lite.Interpreter(model_path="model.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"Input shape: {input_details[0]['shape']}")
print(f"Input dtype: {input_details[0]['dtype']}")
print(f"Output shape: {output_details[0]['shape']}")

# Run test inference
test_input = np.random.randn(*input_details[0]['shape']).astype(np.float32)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()
output = interpreter.get_tensor(output_details[0]['index'])
print(f"Output shape: {output.shape}")
```

## Complete Example: Train, Save, Convert, Load in MATLAB

**Python — train and convert:**

```python
import tensorflow as tf
import numpy as np

# Build and train a model
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(28, 28, 1)),
    tf.keras.layers.Conv2D(16, 3, activation='relu'),
    tf.keras.layers.GlobalAveragePooling2D(),
    tf.keras.layers.Dense(10, activation='softmax')
])
model.compile(optimizer='adam', loss='sparse_categorical_crossentropy')
# model.fit(...)  # train on your data

# Convert directly from the in-memory model
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open("classifier.tflite", "wb") as f:
    f.write(tflite_model)
```

**MATLAB — load and generate code:**

```matlab
model = loadLiteRTModel("classifier.tflite");
specs = inputSpecifications(model);
disp(specs)  % Verify: should show [1, 28, 28, 1] single

% Write entry-point
% function out = mInvoke(modelPath, input) %#codegen
%     net = loadLiteRTModel(modelPath);
%     out = invoke(net, input);
% end

input = ones(specs.Size{1}, specs.Type{1});
cfg = coder.config("mex");
codegen -config cfg -args {coder.Constant("classifier.tflite"), input} mInvoke
```

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Using `importNetworkFromTensorFlow` for code generation | Convert to `.tflite` first, then `loadLiteRTModel` |
| Using `importNetworkFromKeras` for code generation | Convert to `.tflite` first, then `loadLiteRTModel` |
| Passing a SavedModel directory to `loadLiteRTModel` | Convert to `.tflite` first — `loadLiteRTModel` only accepts `.tflite` files |
| Passing a `.keras` or `.h5` file to `loadLiteRTModel` | Convert to `.tflite` first |
| Using `tflite_runtime` package for verification | Use `tf.lite.Interpreter` (built into TensorFlow) or `ai_edge_litert` |

## Notes

- The converted `.tflite` model preserves the original model's float32 weights
  by default (no quantization).
- Input/output shapes and types are preserved from the source model.
- LiteRT uses NHWC layout — same as TensorFlow's default, so no layout
  conversion is needed during the `.tflite` export step.
- For multi-output models, all outputs are preserved in the `.tflite` file.

----

Copyright 2026 The MathWorks, Inc.

----
