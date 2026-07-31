# Custom Layers and dlaccelerate

Custom layers should inherit `nnet.layer.Acceleratable` to participate in acceleration:

```matlab
classdef MyLayer < nnet.layer.Layer & nnet.layer.Acceleratable
    methods
        function Y = predict(layer, X)
            Y = myOp(X);
        end
    end
end
```

## Without `Acceleratable`

- The layer forces `Acceleration="auto"` to break the network into multiple accelerated functions (one per contiguous group of acceleratable layers)
- Performance degrades significantly due to multiple boundary crossings

## With `Acceleratable`

- The layer participates in the same accelerated function as surrounding layers
- Performance is close to built-in layers

## Important Distinction

`Acceleratable` only applies to automatic acceleration (`Acceleration="auto"` inside `forward`/`predict`). If you place the entire network execution inside your own `dlaccelerate` call, all layers are accelerated regardless of whether they inherit `Acceleratable`.

## Data-Dependent Control Flow in Custom Layers

A custom layer's `predict`/`forward` method must be trace-compatible. If the method contains data-dependent control flow (`if`/`while`/`for`/`break`/`continue` on dlarray values or values derived from `extractdata`), the first branch path gets baked into the trace and subsequent calls with different paths silently produce wrong results.

```matlab
% BAD: data-dependent iteration count, not trace-compatible
classdef SinkhornLayer < nnet.layer.Layer & nnet.layer.Acceleratable
    methods
        function Y = predict(layer, X)
            for i = 1:layer.MaxIter
                X = normalize(X);
                if extractdata(gather(norm(X - Xprev))) < layer.Tol
                    break;  % iteration count depends on data
                end
            end
            Y = X;
        end
    end
end
```

**Fix:** Remove data-dependent stopping before adding `Acceleratable`. Use a fixed iteration count:

```matlab
% GOOD: fixed iteration count, trace-compatible
classdef SinkhornLayer < nnet.layer.Layer & nnet.layer.Acceleratable
    methods
        function Y = predict(layer, X)
            for i = 1:layer.NumIter  % fixed, not data-dependent
                X = normalize(X);
            end
            Y = X;
        end
    end
end
```

If the layer cannot be made trace-compatible (the algorithm fundamentally requires data-dependent stopping), do NOT add `Acceleratable`. Accept fragmented acceleration or place the layer outside the accelerated boundary.

----

Copyright 2026 The MathWorks, Inc.
