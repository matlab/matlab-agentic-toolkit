# Filling Placeholder Layers After Import

## How Placeholders Work

When `importNetworkFromPyTorch` encounters an unsupported PyTorch operation, it
generates a custom layer `.m` file in the namespace directory. These files contain
a skeleton class with an `error(...)` call in the `predict` method that must be
replaced with a working implementation.

## Identifying Placeholders

1. Check import warnings for lines like:
   ```
   'aten::unbind' operator in 'ModelName_unbind_view_6' layer class
   ```

2. Find the generated file in the namespace folder:
   ```
   +<namespace>/+ops/pyAtenUnbind.m
   ```

3. The file contains `error('...')` at the bottom of `predict` — this must be
   removed after you implement the operation.

## Implementation Rules

### Rule 1: Dynamic batch sizes

**Never hardcode dimension sizes from the export.** The exported graph may
record specific sizes (e.g., batch=4) but your implementation must work for
any batch size.

```matlab
% WRONG — hardcoded batch size from export
output = reshape(input, [4, -1]);

% CORRECT — dynamic batch
batchSize = size(input, ndims(input));  % batch is last dim in MATLAB
output = reshape(input, [], batchSize);
```

### Rule 2: Preserve dlarray format labels

When your custom op manipulates dimensions, ensure the output retains correct
format labels. Operations that remove or add dimensions need explicit relabeling.

```matlab
% If input has format 'SSCB' and you remove spatial dims:
output = dlarray(extractdata(result), 'CB');
```

Key behaviors of dlarray indexing:
- Indexing with `:` preserves that dimension and its label
- Scalar indexing (e.g., `X(:,:,i,:)`) **removes** that dimension from the format
- Use `squeeze` carefully — it removes all singleton dims and their labels

### Rule 3: Handle arbitrary input ranks

Don't assume 4D input. Build indexing dynamically:

```matlab
ndX = ndims(X);
idx = repmat({':'}, 1, ndX);
idx{targetDim} = i;
slice = X(idx{:});
```

### Rule 4: Ignore template helper references

The auto-generated placeholder may reference helper functions like
`permuteToPyTorchDimensionOrder` or `permutePyTorchToReversePyTorch`.
These **do not exist** in the generated package. Implement the operation
from scratch based on what the PyTorch op actually computes.

### Rule 5: Remove the error call

After implementing, delete the `error(...)` line at the bottom of `predict`.
The import warning will still appear on re-import (it's a static check for the
operator name), but this is cosmetic — the network will execute correctly.

## Example: Implementing aten::unbind

`aten::unbind(tensor, dim)` splits a tensor along `dim` into individual slices,
removing that dimension.

```matlab
function varargout = predict(~, X, dim)
    % Convert 0-based PyTorch dim to 1-based MATLAB dim
    if isa(dim, 'dlarray')
        dim = extractdata(dim);
    end
    matlabDim = double(dim) + 1;

    % Get number of slices dynamically
    numSlices = size(X, matlabDim);

    % Build dynamic indexing for any rank
    ndX = ndims(X);
    idx = repmat({':'}, 1, ndX);

    % Extract each slice
    varargout = cell(1, nargout);
    for i = 1:nargout
        idx{matlabDim} = i;
        slice = X(idx{:});
        % Squeeze the indexed dimension (now singleton)
        slice = squeeze(slice);
        varargout{i} = slice;
    end
end
```

## Example: Implementing pyView (reshape with dynamic batch)

```matlab
function Y = predict(~, X, targetShape, ~)
    % targetShape comes from the export graph — may have hardcoded batch
    if isa(targetShape, 'dlarray')
        targetShape = extractdata(targetShape);
    end
    targetShape = double(targetShape);

    % Replace any hardcoded batch dimension with actual batch size
    % In MATLAB dlarray 'SSCB' format, batch is the last dimension
    actualBatch = size(X, ndims(X));

    % Find -1 in target shape (inferred dim) or replace batch
    targetShape(targetShape == -1) = [];
    newShape = [prod(targetShape), actualBatch];

    Y = reshape(X, newShape);
end
```

## Validation After Fixing

After implementing all placeholders:

```matlab
% Test with a sample input
dlIn = dlarray(randn(32, 32, 3, 1, 'single'), 'SSCB');
dlOut = predict(net, dlIn);

% Verify output shape and no errors
fprintf("Output size: [%s]\n", num2str(size(dlOut)));
```

----

Copyright 2026 The MathWorks, Inc.

----
