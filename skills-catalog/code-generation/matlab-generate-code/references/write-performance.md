# Performance and Memory Patterns

Optimization patterns for generated C/C++ code: vectorization, loop structures, indexing, memory layout, and DMA-off mode.

## Vector Operations — Enable SIMD

Vectorized code is much more likely to generate SIMD instructions (SSE, AVX).

```matlab
% GOOD: vectorized — likely SIMD
y = a .* b + c;

% BAD: scalar loop — unlikely auto-vectorized
for i = 1:length(a), y(i) = a(i) * b(i) + c(i); end
```

Prefer element-wise operators (`.* `, `./ `, `.^`) and array slicing over explicit loops.

## Fuse Consecutive Loops

Fuse loops over the same range into one pass — improves cache locality and reduces loop overhead.

```matlab
% GOOD: fused
for i = 1:n
    y(i) = a(i) * b(i);
    z(i) = y(i) + c(i);
end
```

## Column-Major Access for Cache Efficiency

Generated code uses column-major layout by default (same as MATLAB). Inner loop should iterate over the first (row) index for contiguous access.

```matlab
% GOOD: inner loop over rows — contiguous in column-major
for j = 1:cols
    for i = 1:rows
        A(i, j) = compute(i, j);
    end
end
```

The leftmost index varies fastest in memory. For layout-aware code handling both row/column-major, see `coder.isRowMajor`/`coder.isColumnMajor` in [write-coder-directives.md](write-coder-directives.md).

## Assert Variable Sizes for Compiler Optimization

`assert` on variable sizes lets the compiler eliminate bounds checks, use fixed-size stack allocations, and unroll loops. They cost nothing in generated code.

```matlab
function y = processVector(x) %#codegen
    assert(numel(x) <= 256);        % compiler knows max size
    assert(size(x, 2) == 1);        % column vector
    y = zeros(size(x));
    for i = uint32(1):uint32(numel(x)), y(i) = x(i) * 2; end
end
```

**`assert` as size hints (`%<HINT>`):** Narrow the code generator's size inference:

```matlab
assert(numel(obj.x) <= L);       %<HINT>  — bounds for stack allocation
assert(numel(x) >= 2); %<HINT>            — eliminates scalar-specific branches
```

## Use Integer Types for Indexing

Numeric literals default to `double`, forcing float-to-int casts at every array access. Use `uint32` for loop iterators and indices.

```matlab
% BAD: double index — cast overhead at every access
for i = 1:n, y(i) = x(i) * 2; end

% GOOD: unsigned integer index
for i = uint32(1):uint32(n), y(i) = x(i) * 2; end

% Cast find() output to integer
idx = uint32(find(x > 0));
```

## Explicit Range Indexing Over Colon

Prefer `x(idx, 1:L)` over `x(idx, :)` when the dimension size is known — gives the code generator a concrete bound for stack allocation.

```matlab
row = A(i, 1:numCols);   % GOOD: concrete bound
row = A(i, :);           % BAD: dimension unbounded for inference
```

## Avoid Vector Indexing — Reduce Memory Overhead

Vector indexing creates temporary variables. Prefer scalar indexing in loops or contiguous ranges.

```matlab
idx = [1, 5, 9, 13];
subset = data(idx);              % BAD: temporary allocated

for k = 1:numel(idx)            % GOOD: scalar loop
    subset(k) = data(idx(k));
end

subset = data(1:4);              % GOOD: contiguous range
```

## Avoid Logical Indexing — Temporary Logical Arrays

Logical indexing creates a temporary logical matrix the size of the indexed array. Prefer explicit loops or `find` with scalar indexing.

```matlab
result = data(data > threshold);  % BAD: temporary logical array

% GOOD: explicit loop
count = 0;
for i = 1:numel(data)
    if data(i) > threshold
        count = count + 1;
        result(count) = data(i);
    end
end
```

## Avoid Array Deletion — Temporary Copies

`x(idx) = []` introduces temporary copies (shift + resize). Build output without unwanted elements instead.

```matlab
% BAD: deletion creates temporary copies
x(3) = [];  x(x < 0) = [];

% GOOD: build output directly
count = 0;
for i = 1:numel(x)
    if x(i) >= 0, count = count + 1; y(count) = x(i); end
end
```

**Cell array deletion (`c(i) = []`) is not supported.** Use a logical mask:

```matlab
ignoreArgsIdx = false(1, numel(varargin));
for i = uint32(1):uint32(numel(varargin))
    if ~ignoreArgsIdx(i) && strcmp(varargin{i}, 'Option')
        val = varargin{i+1};
        ignoreArgsIdx(i) = true;
        ignoreArgsIdx(i+1) = true;
    end
end
```

## Comma-Separated List Expansion is Fixed-Size Only

`c{:}` requires cell size known at compile time. For variable-size cells, iterate explicitly.

```matlab
% BAD: variable-size cell — codegen error
coder.varsize('c');
result = [c{:}];

% GOOD: explicit iteration
result = zeros(1, totalLen);
pos = uint32(1);
for i = uint32(1):uint32(numel(c))
    len = numel(c{i});
    result(pos:pos+len-1) = c{i};
    pos = pos + len;
end
```

## Struct-of-Arrays vs Array-of-Structs

When fields differ in size per element, prefer **struct-of-arrays** with zero-padded fixed-size matrix — enables static allocation. Array-of-structs with variable-size fields forces heap allocation.

```matlab
% BAD: array-of-structs — variable field sizes, forces DMA
Ch(nchannel).SigAndTNanPos = [];
for i = 1:nchannel
    Ch(i).SigAndTNanPos = find(isnan(x(:,i)));
end

% GOOD: struct-of-arrays — fixed 2D matrix
Ch.SigAndTNanPos = zeros(nchannel, maxLen);
for i = 1:nchannel
    idx = find(isnan(x(:,i)));
    Ch.SigAndTNanPos(i, 1:numel(idx)) = idx;
end
```

## Generating Code Without Dynamic Memory Allocation (DMA-Off)

> **Apply ONLY when user explicitly requests DMA-off** (no-heap, stack-only, embedded without malloc).

All memory must be stack-allocated with sizes known at compile time.

### Patterns That Require DMA (avoid in DMA-off mode)

| Pattern | Why it needs DMA | Fix |
|---------|-----------------|-----|
| `coder.varsize('x')` (no bounds) | Unbounded size → heap | Add upper bounds: `coder.varsize('x', [1 N])` |
| `x = [x; newRow]` | Dynamic growth | Preallocate full size before loop |
| `x(idx) = []` | Dynamic shrinking | Use logical mask or build new array |
| `result = x(x > 0)` (unbounded) | Output size unknown | Bound with assert + `coder.varsize` |
| `c{:}` on variable-size cell | Expansion size unknown | Iterate explicitly |
| Unbounded `find()`, `unique()` | Output size depends on data | Provide max count or post-assert |
| String concatenation in loops | Growing char array | Preallocate fixed buffer |

### DMA-Off Checklist

1. Every `coder.varsize` has explicit upper bounds
2. No array growth/deletion inside loops
3. All function outputs have bounded sizes (use `assert` hints)
4. No unbounded filtering (`x(x > 0)`) without bounds
5. All cell arrays are fixed-size
6. Struct-of-arrays instead of array-of-structs with variable fields
7. `coder.const` used to fold compile-time-computable sizes
8. All `varargin` loops use `coder.unroll`:

```matlab
for i = coder.unroll(1:numel(varargin))  % GOOD: resolved at compile time
    process(varargin{i});
end
```

### Stack Size Awareness

DMA-off places all arrays on the stack. Keep upper bounds tight — excessively large bounds waste stack even when actual usage is small.

```matlab
assert(nfft <= 4096); %<HINT>
buffer = coder.nullcopy(zeros(1, 4096));
```

**Bound computed dimensions by input size:**

```matlab
numHops = floor((rows - windowLength) / hopLength) + 1;
assert(numHops <= rows); %<HINT>
assert(numSegments <= inputLength);                  %<HINT>
assert(outputLength <= ceil(inputLength * p / q));   %<HINT>
```

**Mitigation for large stacks:**
- Reduce upper bounds to actual maximums
- Use `persistent` variables (allocated once, reused across calls)
- Split into smaller sub-functions with their own stack frames
- Use `coder.nullcopy` to avoid double-write (allocation + zeroing)

----

Copyright 2026 The MathWorks, Inc.

----
