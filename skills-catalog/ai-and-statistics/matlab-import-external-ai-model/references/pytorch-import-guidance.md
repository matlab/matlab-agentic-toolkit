# Import PyTorch Models into MATLAB

## Two Import Paths

| Format | File | Created by | Input sizes needed? | PyTorch version |
|--------|------|-----------|--------------------|-----------------| 
| Exported program | `.pt2` | `torch.export.export` | No (embedded) | Exactly 2.8 |
| Traced model | `.pt` | `torch.jit.trace` | Yes (`PyTorchInputSizes`) | 2.8 or earlier |

## Importing an Exported Program (.pt2)

```matlab
net = importNetworkFromPyTorch("model.pt2");
```

No additional arguments needed. The .pt2 format embeds input shape, dtype, and
graph information.

### With Namespace control

```matlab
net = importNetworkFromPyTorch("model.pt2", ...
    Namespace="myModel");
```

Use `Namespace` to control where auto-generated custom layer files are stored.
This avoids conflicts when importing multiple models in the same session.

## Importing a Traced Model (.pt)

```matlab
net = importNetworkFromPyTorch("model.pt", ...
    PyTorchInputSizes=[1 3 224 224]);
```

`PyTorchInputSizes` is **mandatory**. Specify dimensions in PyTorch NCHW format.

### Multiple inputs

```matlab
net = importNetworkFromPyTorch("model.pt", ...
    PyTorchInputSizes={[1 3 224 224], [1 128]});
```

Use a cell array for models with multiple input tensors.

## Name-Value Arguments Reference

| Argument | Type | Description |
|----------|------|-------------|
| `PyTorchInputSizes` | numeric or cell | Input dimensions in PyTorch format. Required for .pt |
| `Namespace` | string | Package folder for generated custom layers |
| `PreferredNestingType` | `"networklayer"` or `"customlayer"` | Controls network composition style |

### Arguments that DO NOT exist

- `InputShape` — **does not exist**. Will error with "Invalid argument name"
- `PackageName` — **deprecated**. Works but produces a warning. Use `Namespace`

## Interpreting Import Results

### Success with no warnings

The network imported cleanly. Proceed to numeric validation.

### Success with placeholder warnings

```
Warning: Unable to represent the following PyTorch operators...
```

This means some operations were converted to auto-generated custom layer files
that need manual implementation. See `placeholder-guidance.md`.

### Version mismatch error

```
Error: ... exported using 'torch.export.export' in PyTorch version 2.8
```

The model was exported with a PyTorch version other than 2.8. Re-export with
PyTorch 2.8 (for .pt2) or 2.8-or-earlier (for .pt).

## After Import: Inspecting the Network

```matlab
% View network summary
disp(net);

% Detailed architecture analysis
analyzeNetwork(net);

% Check layer count
fprintf("Layers: %d\n", numel(net.Layers));
```

## After Import: Verifying Input Order and Format (MIMO Models)

The importer may reorder inputs relative to the PyTorch `forward()` signature.
**Always check `net.InputNames` after import** to determine the correct argument
order for `predict`.

```matlab
% 1. Check input ordering (may NOT match PyTorch forward() signature)
disp(net.InputNames);

% 2. Determine expected format from the input layer CLASS (not a Format property)
for i = 1:numel(net.InputNames)
    layer = net.Layers(strcmp({net.Layers.Name}, net.InputNames{i}));
    fprintf("%s: %s\n", net.InputNames{i}, class(layer));
end
% ImageInputLayer   -> pass SSCB formatted dlarray
% FeatureInputLayer -> pass CB formatted dlarray
% For arbitrary/unlabeled tensors -> pass 'U'-labeled dlarray:
%   dlarray(single(data), repmat('U', 1, ndims(data)))

% 3. Pass predict arguments in net.InputNames order, NOT PyTorch forward() order
[y1, y2] = predict(net, dlIn1, dlIn2);
```

**Do NOT** access `layer.Format` — this property does not exist on input layers.

## Re-importing in the Same Session

Use `Namespace` to avoid package name collisions:

```matlab
net1 = importNetworkFromPyTorch("modelA.pt2", Namespace="modelA");
net2 = importNetworkFromPyTorch("modelB.pt2", Namespace="modelB");
```

----

Copyright 2026 The MathWorks, Inc.

----
