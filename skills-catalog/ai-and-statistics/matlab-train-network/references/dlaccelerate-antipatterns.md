# dlaccelerate Anti-Patterns Reference

Patterns that break `dlaccelerate` function tracing, causing re-tracing on every call and destroying cache hit rates.

## Pattern 1: Data-Dependent Branches

**Problem:** `if`/`switch` conditions that depend on dlarray values or non-traced computations (like `rand()`) are evaluated only during the initial trace. The chosen branch is baked into the cached code permanently.

```matlab
% BAD: condition depends on dlarray value, cached path never changes
if gradientNorm > threshold
    gradients = gradients * (threshold / gradientNorm);
end

% BAD: rand() is not traced, always takes the branch from first call
if rand > 0.5
    y = x * 2;
else
    y = x * 3;
end
```

**Fix:** Replace with branch-free arithmetic:

```matlab
% GOOD: no branch, works for all values
scale = min(threshold / gradientNorm, 1);
gradients = gradients * scale;

% GOOD: for the rand case, pass the decision as a non-dlarray input
% (each value gets its own cached trace, only 2 needed for boolean)
function y = myFcn(x, useDoubling)
    if useDoubling
        y = x * 2;
    else
        y = x * 3;
    end
end
accFcn = dlaccelerate(@myFcn);
y = dlfeval(accFcn, x, rand > 0.5);  % Two traces: one for true, one for false
```

**Safe exception:** Branching on non-dlarray constants that never change between calls is fine. Watch out for non-dlarray scalars specifically, as they are typically the inputs that *appear* constant but actually change between calls (iteration counters, learning rates, scheduled hyperparameters).
```matlab
% SAFE: gradientThreshold and gradientClippingMethod are fixed for the entire training run. They produce one cached trace each and never retrace.
gradientThreshold = 1.0;
gradientClippingMethod = "l2norm";
accFcn = dlaccelerate(@trainStep);
for iteration = 1:numIterations
    [grad, loss] = dlfeval(accFcn, net, X, T, gradientThreshold, gradientClippingMethod);
    ...
end

function [grad, loss] = trainStep(net, X, T, gradientThreshold, gradientClippingMethod)
    [Y, state] = forward(net, X);
    loss = crossentropy(Y, T);
    grad = dlgradient(loss, net.Learnables);

    if gradientClippingMethod == "l2norm"
        grad = thresholdL2Norm(grad, gradientThreshold);
    elseif gradientClippingMethod == "absolute-value"
        grad = thresholdAbsoluteValue(grad, gradientThreshold);
    end
end
```

```matlab
% UNSAFE: learnRate and iteration change every call. Each unique value triggers a new trace.
accFcn = dlaccelerate(@trainStep);
numIterations = 50;
for i = 1:numIterations
    learnRate = baseLR * 0.5 * (1 + cos(pi * i / numIterations));
    [grad, loss] = dlfeval(accFcn, net, X, T, learnRate, i);
    ...
end

% Fix: wrap changing inputs as dlarray before the loop
accFcn = dlaccelerate(@trainStep);
iteration = dlarray(1);
for i = 1:numIterations
    learnRate = baseLR * 0.5 * (1 + cos(pi * iteration / numIterations));
    [grad, loss] = dlfeval(accFcn, net, X, T, learnRate, iteration);
    ...
    iteration = iteration + 1;
end

% Even better fix: move schedule computation inside the accelerated boundary
% Note: baseLR and numIterations are constants, safe as non-dlarray inputs.
accFcn = dlaccelerate(@trainStep);
iteration = dlarray(1);
for i = 1:numIterations
    [grad, loss] = dlfeval(accFcn, net, X, T, iteration, baseLR, numIterations);
    ...
    iteration = iteration + 1;
end
function [grad, loss] = trainStep(net, X, T, iteration, baseLR, numIterations)
    learnRate = baseLR * 0.5 * (1 + cos(pi * iteration / numIterations));
    ...
end
```

## Pattern 2: Logical Indexing — Count-Dependent Operations on Selections

**Problem:** Logical indexing for selection (`y = X(X > 0)`) produces a variable-length result whose element count varies with input values. The selection itself and value-only reductions on it (`sum`, `max`, `min`, `.^2`, `dot`) are traced correctly. However, `numel`, `size`, and `length` on a variable-length selection return the count from the first trace as a frozen constant. Functions that depend on the element count, `mean`, `var`, `std`, silently produce wrong results for the same reason.

```matlab
% BAD: numel on selection is frozen from first trace
selected = X(X > 0);
y = sum(selected) / numel(selected);  % wrong answers silently

% BAD: same issue with length or size on a selection
y = sum(X(X > 0)) / length(X(X > 0));

% BAD: mean, var, std on a selection — depend on element count
y = mean(X(X > 0));  % produces wrong answers (verify with CheckMode="tolerance")
y = var(X(X > 0));
```

**Safe patterns** — value-only operations that do not depend on element count:

```matlab
% SAFE: sum, max, min on selection
y = sum(X(X > 0));
y = max(X(X > 0));

% SAFE: element-wise operations on selection
y = sum(X(X > 0) .^ 2);
y = dot(X(X > 0), X(X > 0));

% SAFE: logical indexed assignment — preserves array shape
X(X >= 0) = 0;

% SAFE: cross-array logical indexed assignment — same mask applied to another array
T(Z >= 0) = 0;
```

**Key distinction:** Assignment into an array (`X(mask) = value`, where the indexed array is on the left of `=`) is shape-preserving and always safe — the output array has the same shape as the input. Selection from an array (`y = X(mask)`, where the indexed array is on the right of `=`) produces a variable-length result and is potentially problematic when combined with count-dependent operations.

**Fix for count-dependent operations:** Compute the count from the fixed-shape logical mask instead of from the variable-length selection:

```matlab
% GOOD: mask-based mean — count comes from fixed-shape mask via sum
mask = X > 0;
y = sum(X .* mask, 'all') / sum(mask, 'all');

% GOOD: element-wise clipping, assuming threshold remains a constant
gradients = min(gradients, threshold);
gradients = max(gradients, -threshold);
```

**Key insight:** The issue is not logical indexing itself — it is `numel`/`size`/`length` and functions that depend on element count (`mean`, `var`, `std`) applied to a variable-length selection. `sum(mask, 'all')` safely provides the count because the mask has fixed shape (same as the input).

## Pattern 3: Random Numbers Without Tracing

**Problem:** `rand(sz)` without `'like'` linkage to a dlarray is NOT traced. It produces a constant in the generated code (same random values every call).

```matlab
% BAD: same random mask reused from cache every iteration
mask = rand(size(x)) > dropoutRate;
```

**Fix:** Use `'like'` syntax to link to a traced dlarray:

```matlab
% GOOD: rand is traced because it's tied to dlarray x
mask = rand(size(x), 'like', x) > dropoutRate;
```

## Pattern 4: Side Effects

**Problem:** `disp`, `fprintf`, file I/O, datastore reads, plotting execute ONLY during the initial trace. On subsequent cached calls they are skipped entirely.

```matlab
% BAD: only prints during initial trace, then silent forever
function [loss, grad] = modelGrad(net, X, T)
    fprintf('Loss: %f\n', loss);
    ...
end
```

**Fix:** Move all side effects OUTSIDE the traced function:

```matlab
% GOOD: print outside dlfeval, always executes
[loss, grad] = dlfeval(accFcn, net, X, T);
fprintf('Loss: %f\n', loss);

% Alternative (for debugging): Temporarily disable acceleration:
accFcn.Enabled = false;
```

## Pattern 5: Using extractdata Inside Traced Function

**Problem:** Using `extractdata` with a traced argument removes the value from the trace. The result becomes a constant in the cached code. Subsequent calls reuse the stale value from the first trace instead of recomputing it.

```matlab
% BAD: extractdata removes loss from the trace, cached value never updates
function [loss, grad] = modelGrad(net, X, T)
    Y = forward(net, X);
    lossVal = extractdata(l2loss(Y, T));
    ...
end
```

`extractdata` may also be encountered because some functions do not accept formatted dlarray data or are not compatible at all with dlarray. Code like this can train correctly without `dlaccelerate` (gradients still flow through other paths), but it prevents acceleration because the extracted values become stale constants in the cached trace.

**Fix strategy — try in order:**

First verify whether `extractdata` can be replaced with `stripdims`. Many functions that reject formatted dlarrays accept unformatted ones.

**Step 1: Use `stripdims`** — `stripdims` removes format labels while preserving `dlaccelerate` compatibility. You cannot know whether a function accepts unformatted dlarray without running it. Implement the fix using `stripdims` with the original functions and execute it. Only move to Step 3 if execution produces a runtime error from one of those functions not accepting the input. Do not skip this step based on assumptions about function compatibility — many functions (including `awgn`, `fft`, `ifft`, `comm.`, etc) accept unformatted dlarray.

```matlab
% GOOD: stripdims preserves dlaccelerate compatibility, only removes format labels
noisySignal = awgn(originalSignal, stripdims(noiseLevel));
```

Always prefer `stripdims` + the original function over rewriting the math manually, because:
1. It preserves the original algorithm (easier for the user to verify correctness)
2. It is compatible with `dlaccelerate` tracing

**Step 2: Move `extractdata` outside `dlfeval`** — If the value is only needed for logging or postprocessing and does not feed back into the accelerated function:

```matlab
% GOOD: extractdata only outside dlfeval
[loss, grad] = dlfeval(accFcn, net, X, T);
lossVal = extractdata(loss);  % fine here, not inside the traced function
```

**Step 3: Reformulate as a last resort** — Only if Step 1 produces a runtime error (a function rejects the unformatted dlarray), reformulate that specific operation. Do not preemptively reformulate without first confirming `stripdims` fails.

## Pattern 6: Nested Functions Accessing Enclosing Workspace

**Problem:** Variables from the enclosing scope are captured as constants during tracing. If those variables change
between calls, the traced graph silently uses the stale values from the first trace.

```matlab
% BAD: threshold captured as constant at trace time
threshold = 0.1;
accFcn = dlaccelerate(@myFunc);

function grad = myFunc(net, X, T)
    ...
    grad = dlupdate(@(g) iClip(g, threshold), grad);  % threshold frozen at 0.1
end
```

**Fix:** Pass all changing values as function inputs:

```matlab
% GOOD: threshold is an explicit input, traced correctly
accFcn = dlaccelerate(@myFunc);

function grad = myFunc(net, X, T, threshold)
    ...
    grad = dlupdate(@(g) iClip(g, threshold), grad);
end
```

## Pattern 7: Anonymous Function Handles as Inputs

**Problem:** Anonymous functions recreated each call trigger a retrace because each instance is a distinct object:
`isequaln(@(x)x, @(x)x)` returns `false`.

**Fix:** Assign the anonymous function to a variable once to ensure identity:

```matlab
% BAD: retrace every call
result = dlfeval(accFcn, net, @(y,t) crossentropy(y,t), X, T);

% GOOD: same object → cache hit
fcn = @(y,t) crossentropy(y,t);
result = dlfeval(accFcn, net, fcn, X, T);
```

**Note:** Named function handles (@crossentropy) are always safe because they have stable identity.

----

Copyright 2026 The MathWorks, Inc.
