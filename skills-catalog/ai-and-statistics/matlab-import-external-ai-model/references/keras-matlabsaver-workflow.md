# matlabsaver + importNetworkFromKeras Workflow

Complete step-by-step for importing Keras 3 models into MATLAB R2026a+ with full
layer structure preserved.

## Prerequisites

- MATLAB R2026a or newer
- Deep Learning Toolbox Converter for TensorFlow Models support package installed
- Python environment with TensorFlow 2.16+ and Keras 3.x

Verify the support package is installed:

```matlab
matlabsaverPath = which("matlabsaver.py");
assert(~isempty(matlabsaverPath), ...
    "matlabsaver.py not found. Install the Deep Learning Toolbox " + ...
    "Converter for TensorFlow Models support package.")
disp("matlabsaver.py location: " + matlabsaverPath)
```

## Step 1: Locate and Deploy matlabsaver.py

From MATLAB, find the utility script:

```matlab
matlabsaverPath = which("matlabsaver.py");
disp(matlabsaverPath)
```

Copy `matlabsaver.py` to the Python project directory, or add its parent folder
to `sys.path` in the Python script.

## Step 2: Save the Model (Python)

In the Python training script:

```python
import sys
sys.path.insert(0, "/path/to/folder/containing/matlabsaver")
import matlabsaver

# model is your trained keras.Model (Functional, Sequential, or subclass)
matlabsaver.save_for_matlab(model, "exportedModelFolder")
```

### What save_for_matlab Does

For Functional and Sequential models:
1. Saves the model as `.keras` format, then unzips it into the output folder
2. Iterates through layers and creates `ExportArchive` entries for custom layers
3. Writes a `layerClassesAndNames.json` mapping custom layer classes to instance names

For subclassed (custom) models:
1. Calls `model.export(modelFolder)` to create a SavedModel with full tracing

### Requirements

- The model must be built (`model.built == True`)
- The model must be a `keras.Model` instance (Functional, Sequential, or subclass)
- Custom layers must have deterministic `call()` methods for tracing to succeed

## Step 3: Import into MATLAB

```matlab
net = importNetworkFromKeras("exportedModelFolder");
```

The function:
- Reads the Keras 3 architecture from the saved folder
- Maps Keras 3 layers to MATLAB equivalents
- Initializes weights from the saved variables
- Returns an initialized `dlnetwork`

## Step 4: Verify the Import

The code below is illustrative — adapt the input shape and dlarray format labels to match the imported network's expected inputs.

```matlab
summary(net)
analyzeNetwork(net)

numLearnables = numel(net.Learnables.Value);
assert(numLearnables > 0, "Import produced 0 learnables — check the export step")

inputSize = net.Layers(1).InputSize;
testInput = dlarray(randn([inputSize 1], "single"), "CB");
output = predict(net, testInput);
disp("Inference OK. Output size: " + join(string(size(output)), "x"))
```

## Handling Custom Layers

When the model contains custom layers (subclasses of `keras.layers.Layer`), the
importer creates auto-generated custom layers in MATLAB. These layers are
functional but may appear as opaque blocks in `analyzeNetwork`.

To check which layers were imported as custom:

```matlab
layerNames = {net.Layers.Name}';
layerTypes = arrayfun(@(l) class(l), net.Layers, UniformOutput=false)';
customIdx = contains(layerTypes, "nnet.keras");
if any(customIdx)
    disp("Custom layers imported:")
    disp(layerNames(customIdx))
end
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Brace indexing is not supported for variables of type char" | Keras 3.10+ changed `config.json` — `input_layers`/`output_layers` are flat instead of nested | Apply the config.json patch (see Step 2 note in SKILL.md) to wrap them in a list |
| 0 learnables after import | Used `model.export` instead of `matlabsaver.save_for_matlab` | Re-export using `matlabsaver.save_for_matlab` |
| "model must be a keras.Model" error in Python | Passed a layer or non-Model object | Wrap in `keras.Model(inputs, outputs)` first |
| Import warning about untested Keras version | Keras is newer than the support package was tested against | Usually works despite warning. Update support package if errors occur |

----

Copyright 2026 The MathWorks, Inc.

----
