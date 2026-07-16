# tf_keras Downgrade Workflow

Use this path when the Keras 3 model uses only standard layers (no `keras.ops`,
no multi-backend features) and the target MATLAB release is older than R2026a.

## Prerequisites

- MATLAB R2023b or newer (for `importNetworkFromTensorFlow`)
- Python environment with TensorFlow 2.16+
- The model must NOT use Keras 3-specific features

## Step 1: Install tf_keras

```bash
pip install tf_keras
```

This installs Keras 2 as a standalone package that TensorFlow 2.16+ can use
in place of the bundled Keras 3.

## Step 2: Configure the Environment

The environment variable MUST be set before any TensorFlow import:

```python
import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"

# NOW import TensorFlow / tf_keras
import tf_keras as keras
from tf_keras import layers
```

### Critical: Import Ordering

```python
# WRONG - env var has no effect after TF import
import tensorflow as tf
os.environ["TF_USE_LEGACY_KERAS"] = "1"  # Too late!

# CORRECT - env var before any TF import
os.environ["TF_USE_LEGACY_KERAS"] = "1"
import tf_keras as keras
```

### Jupyter Notebooks

If working in Jupyter, restart the kernel after installing `tf_keras`. The old
kernel has Keras 3 cached in memory and will not pick up the environment
variable change without a fresh process.

## Step 3: Verify Keras 2 Is Active

```python
import tf_keras as keras
assert not hasattr(keras, "version"), (
    "Still using Keras 3! Check TF_USE_LEGACY_KERAS and import ordering."
)
print(f"Using: {keras.__name__}")  # Should print: tf_keras
```

The `version` attribute is Keras 3-specific. Its absence confirms the
downgrade worked.

## Step 4: Build and Save the Model

Use `tf_keras` APIs (they mirror Keras 2 exactly):

```python
import tf_keras as keras
from tf_keras import layers

inputs = keras.Input(shape=(784,), name="input")
x = layers.Dense(128, activation="relu", name="hidden")(inputs)
outputs = layers.Dense(10, activation="softmax", name="output")(x)
model = keras.Model(inputs, outputs)
model.compile(optimizer="adam", loss="sparse_categorical_crossentropy")
model.fit(xTrain, yTrain, epochs=10)

# Save as SavedModel (Keras 2 format with keras_metadata.pb)
model.save("savedModelFolder")
```

The saved folder will contain `keras_metadata.pb` — this is what
`importNetworkFromTensorFlow` needs to decompose the layer structure.

## Step 5: Import into MATLAB

```matlab
net = importNetworkFromTensorFlow("savedModelFolder");
summary(net)
```

## Step 6: Verify

```matlab
numLearnables = numel(net.Learnables.Value);
assert(numLearnables > 0, "Import failed: 0 learnables")
disp("Layers: " + numel(net.Layers) + ", Learnables: " + numLearnables)
```

## When NOT to Use This Path

Do not use `tf_keras` if the model relies on:
- `keras.ops.*` (the backend-agnostic operation API)
- `keras.Operation` subclasses
- Multi-backend execution (JAX, PyTorch backends)
- Keras 3-only layer types (check Keras 3 changelog)
- Any feature introduced after Keras 2.x was frozen

If any of these are present, the model will fail to build under `tf_keras`.
Use Path 3 (ONNX export) instead.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `hasattr(keras, 'version')` returns `True` | `TF_USE_LEGACY_KERAS` not set early enough | Move env var to first line of script, before all imports |
| `ModuleNotFoundError: tf_keras` | Package not installed | Run `pip install tf_keras` |
| Model builds but `model.save()` produces `.keras` file | Using `keras` (Keras 3) instead of `tf_keras` | Change import to `import tf_keras as keras` |
| Kernel restart didn't help (Jupyter) | Multiple Python environments | Check `sys.executable` matches the env where tf_keras is installed |
| 0 learnables after import | SavedModel missing `keras_metadata.pb` | Verify the saved folder contains `keras_metadata.pb`. If missing, the save used Keras 3 not tf_keras |

----

Copyright 2026 The MathWorks, Inc.

----
