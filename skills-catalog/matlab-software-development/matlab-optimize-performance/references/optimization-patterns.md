# Optimization Patterns Catalog

Proven MATLAB optimization patterns with typical speedup ranges. Apply these after profiling identifies the bottleneck (Step 3 of the workflow).

## 1. Vectorization — Replace Loops with Array Operations (2–200x+)

The single most impactful optimization in MATLAB. Replace element-wise loops with built-in array operations.

### Basic vectorization
```matlab
% Before: loop over elements
result = zeros(1, n);
for i = 1:n
    result(i) = sqrt(x(i)^2 + y(i)^2);
end

% After: vectorized
result = hypot(x, y);
```

### discretize — replace multi-pass classification loops
```matlab
% Before: loop checking thresholds
for i = 1:numel(A)
    for k = 1:numel(levels)
        if A(i) >= levels(k)
            idx(i) = k;
        end
    end
end

% After: O(N log K) with discretize
idx = discretize(A, [-inf; levels(:); inf]) - 1;
```

### filter — replace recursive accumulation loops
```matlab
% Before: recursive loop
R = zeros(size(r));
R(end) = r(end);
for i = numel(r)-1:-1:1
    R(i) = r(i) + gamma * R(i+1);
end

% After: filter (single pass)
tmp = filter(1, [1 -gamma], r(end:-1:1));
R = tmp(end:-1:1);
```

### cumsum — replace O(N^2) partial sums
```matlab
% Before: O(N^2) — sum(1:i) in each iteration
for i = 1:n
    total(i) = sum(x(1:i));
end

% After: O(N)
total = cumsum(x);
```

## 2. Preallocation (2–100x)

MATLAB must copy the entire array each time it grows. Preallocate to avoid this.

```matlab
% Before: array grows each iteration (O(N^2) memory copies)
output = [];
for i = 1:n
    output = [output; computeRow(i)];
end

% After: preallocate
output = zeros(n, numCols);
for i = 1:n
    output(i, :) = computeRow(i);
end
```

**When output size is unknown**, preallocate an upper bound and trim:
```matlab
output = zeros(maxPossible, 1);
count = 0;
for i = 1:n
    if condition(i)
        count = count + 1;
        output(count) = value(i);
    end
end
output = output(1:count);
```

## 3. Function Call Reduction / Inlining (5–130x)

When a simple function is called millions of times in a loop, the call overhead dominates.

```matlab
% Before: function called per-element
for i = 1:n
    result(i) = convertUnits(x(i), 'deg', 'rad');
end

% After: inline the computation
deg2rad = pi / 180;
result = x * deg2rad;
```

**Persistent lookup for repeated conversions:**
```matlab
persistent slopes
if isempty(slopes)
    slopes = struct('deg', pi/180, 'rad', 1, 'rev', 2*pi);
end
y = x * (slopes.(fromUnit) / slopes.(toUnit));
```

## 4. inputParser to arguments Block (1.1–1.8x)

Replace `inputParser` with native `arguments` blocks (R2019b+). Faster while preserving validation.

```matlab
% Before: inputParser (slow)
function result = myFunc(x, y, varargin)
    p = inputParser;
    p.addRequired('x', @isnumeric);
    p.addRequired('y', @isnumeric);
    p.addParameter('Tol', 1e-6, @isnumeric);
    p.parse(x, y, varargin{:});
    tol = p.Results.Tol;
    ...
end

% After: arguments block (fast, same caller syntax)
function result = myFunc(x, y, options)
    arguments
        x {mustBeNumeric}
        y {mustBeNumeric}
        options.Tol (1,1) double = 1e-6
    end
    tol = options.Tol;
    ...
end
```

Impact is highest when parsing overhead is a large fraction of total runtime (lightweight functions called frequently).

## 5. Persistent Caching (1.5–95x)

Cache expensive-to-create objects or data that don't change between calls.

### Cache loaded data
```matlab
persistent cachedFile cachedData
if isempty(cachedFile) || ~strcmp(cachedFile, filename)
    cachedData = load(filename);
    cachedFile = filename;
end
data = cachedData;
```

### Cache computed objects
```matlab
persistent filterObj
if isempty(filterObj)
    filterObj = designfilt('lowpassfir', 'FilterOrder', 50, ...
        'CutoffFrequency', 0.4);
end
y = filter(filterObj, x);
```

## 6. Logical Indexing Instead of find (1.2–5x)

If you only use `find` to index into another array, use logical indexing directly.

```matlab
% Before
idx = find(x > threshold);
y = data(idx);

% After
y = data(x > threshold);
```

## 7. Common Subexpression Elimination (1.05–1.7x)

Compute repeated subexpressions once and reuse.

```matlab
% Before: gamma-1 and mach^2 computed multiple times
T = T0 * (1 + (gamma-1)/2 * mach.^2);
P = P0 * (1 + (gamma-1)/2 * mach.^2).^(gamma/(gamma-1));

% After: compute once
gm1 = gamma - 1;
m2term = 1 + gm1/2 * mach.^2;
T = T0 * m2term;
P = P0 * m2term.^(gamma/gm1);
```

## 8. Algebraic Simplification (1.5–3x)

Simplify redundant math operations.

```matlab
% Before: flip + cumsum + flip (3 passes)
Y = flip(cumsum(flip(X)));

% After: one pass, no flip (and no cancellation at the tail)
Y = cumsum(X, 'reverse');
```

```matlab
% Before: sqrt then square
dist = sqrt((x2-x1)^2 + (y2-y1)^2);
if dist^2 < threshold^2 ...

% After: skip the sqrt entirely
distSq = (x2-x1)^2 + (y2-y1)^2;
if distSq < threshold^2 ...
```

## 9. Batched Vectorization for Large Data (150–274x)

For operations that would create too-large intermediate arrays, batch the vectorization:

```matlab
% Before: per-element loop (slow)
for k = 1:numel(y)
    [~, idx] = min(abs(y(k) - refValues(:)));
    result(k) = idx;
end

% After: batched vectorized (controls memory)
M = numel(refValues);
batchSize = max(1, floor(1e7 / M));  % ~80 MB intermediate
result = zeros(size(y));
for bStart = 1:batchSize:numel(y)
    bEnd = min(bStart + batchSize - 1, numel(y));
    [~, idx] = min(abs(y(bStart:bEnd) - refValues(:).'), [], 2);
    result(bStart:bEnd) = idx;
end
```

## 10. O(N^2) Partial Sum to Running Index (1.3–2.3x)

Replace `sum(array(1:i-1))` inside a loop with a running accumulator.

```matlab
% Before: O(N^2)
for i = 1:N
    offset = sum(lengths(1:i-1));
    out(offset + (1:lengths(i))) = data{i};
end

% After: O(N)
currentIdx = 0;
for i = 1:N
    out(currentIdx + (1:lengths(i))) = data{i};
    currentIdx = currentIdx + lengths(i);
end
```

## 11. GPU-Specific Patterns

### GPU sync batching (1.1–1.6x)
Consolidate multiple GPU-to-CPU transfers:
```matlab
% Before: multiple gather calls
normA = norm(gather(gpuA));
normB = norm(gather(gpuB));

% After: gather once
results = gather(cat(1, gpuA(:), gpuB(:)));
normA = norm(results(1:nA));
normB = norm(results(nA+1:end));
```

### max/min instead of logical masking (2.5–7x)
```matlab
% Before: creates intermediate logical array on GPU
y = x .* (x > 0);

% After: single kernel
y = max(x, 0);
```

### gputimeit for measurement
```matlab
f = @() myGpuFunction(gpuData);
t = gputimeit(f);  % handles wait(gpuDevice) internally
```

## 12. Replace General-Purpose Functions with Direct Computation (2–4x)

When a general-purpose function is called in a tight loop but only a fraction of its functionality is needed:

```matlab
% Before: ecdf does sorting, NaN removal, step function — all unnecessary here
for b = 1:nBoot
    [F, p0] = ecdf(pValues);
    pi0(b) = interp1q(p0, 1-F, lambda) ./ (1-lambda);
end

% After: direct counting (all we actually need)
for b = 1:nBoot
    pi0(b) = sum(pValues > lambda) / (m * (1 - lambda));
end
```

## 13. Uniform-Vector Fast Path (1.8–4x)

Detect when a vector parameter has all-equal elements and use the scalar fast path:

```matlab
if isscalar(param) || all(param(2:end) == param(1))
    % Fast: use scalar path (vectorized reshape)
    result = reshape(data, uniformSize);
else
    % Slow: per-element loop (only for truly variable values)
    for i = 1:numel(param)
        result{i} = processOne(data, param(i));
    end
end
```

Copyright 2026 The MathWorks, Inc.
