
# Performance Patterns

## Quick Reference: Performance Do's and Don'ts

| Do | Don't |
|----|-------|
| Preallocate arrays | Grow arrays incrementally in loops |
| Vectorize operations | Use loops for element-wise operations |
| Use functions over scripts | Use scripts for repeated code |
| Prefer local functions | Use nested functions unnecessarily |
| Use `&&` and `\|\|` operators | Use `&` and `\|` for scalar logic |
| Use `str2double` | Use `str2num` (security risk) |
| Use `clearvars` | Use `clear all` |

---

## Vectorization

### Why Vectorize?

Vectorized code provides three key benefits:

1. **Appearance**: Code more closely resembles mathematical notation
2. **Fewer Errors**: Shorter code means fewer opportunities for bugs
3. **Performance**: Vectorized operations execute significantly faster than loops

### Array Operations (Loops -> Element-wise)

Replace loops with element-wise operators using the dot prefix (`.^`, `.*`, `./`).

**Slow (Avoid):**
```matlab
% Loop-based calculation
for n = 1:10000
    V(n) = 1/12*pi*(D(n)^2)*H(n);
end
```

**Fast (Use This):**
```matlab
% Vectorized calculation
V = 1/12*pi*(D.^2).*H;
```

### Implicit Expansion (Broadcasting)

MATLAB automatically expands arrays of compatible sizes for element-wise operations.

```matlab
% A is 7x3 matrix, mean(A) is 1x3 vector
% MATLAB implicitly expands the vector for subtraction
A_centered = A - mean(A);

% Create multiplication table without loops
x = (1:10)';
y = 1:10;
table = x .* y;  % 10x10 matrix
```

### Logical Indexing

Use logical arrays for conditional selection instead of loops with if statements.

**Slow (Avoid):**
```matlab
count = 0;
for i = 1:length(V)
    if D(i) >= 0
        count = count + 1;
        Vgood(count) = V(i);
    end
end
```

**Fast (Use This):**
```matlab
Vgood = V(D >= 0);
```

**Bulk Logical Tests:**
```matlab
% Check if all elements meet condition
if all(x > 0)
    disp('All positive');
end

% Check if any element meets condition
if any(isnan(data))
    warning('Data contains NaN values');
end
```

### Matrix Construction Functions

Use built-in functions to create matrices efficiently.

| Function | Purpose | Example |
|----------|---------|---------|
| `ones(m,n)` | Matrix of ones | `A = ones(100,100)` |
| `zeros(m,n)` | Matrix of zeros | `B = zeros(100,100)` |
| `repmat(x,m,n)` | Repeat array | `C = repmat([1 2 3], 4, 1)` |
| `meshgrid(x,y)` | 2D grid coordinates | `[X,Y] = meshgrid(1:10, 1:10)` |
| `ndgrid(x,y,z)` | N-D grid | `[X,Y,Z] = ndgrid(1:5, 1:5, 1:5)` |
| `linspace(a,b,n)` | Linear spacing | `x = linspace(0, 1, 100)` |
| `colon (a:b)` | Range generation | `x = 1:0.1:10` |

### Essential Vectorization Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `cumsum` | Cumulative sum | `runningTotal = cumsum(values)` |
| `cumprod` | Cumulative product | `factorial = cumprod(1:10)` |
| `diff` | Differences between elements | `velocity = diff(position)./diff(time)` |
| `find` | Locate nonzero indices | `idx = find(x > threshold)` |
| `sort` | Sort elements | `[sorted, idx] = sort(data)` |
| `unique` | Unique elements | `categories = unique(labels)` |
| `reshape` | Reshape array | `matrix = reshape(vector, [10,10])` |
| `permute` | Reorder dimensions | `transposed = permute(A, [2,1,3])` |
| `sum`, `mean`, `max`, `min` | Aggregation | `rowMeans = mean(A, 2)` |
| `bsxfun` | Binary operation with expansion | `normalized = bsxfun(@rdivide, A, max(A))` |

---

## Performance Techniques

### Code Structure: Functions vs Scripts

**Use Functions:**
- Functions execute faster than scripts
- Functions have their own workspace (better memory management)
- Functions enable code reuse

**Prefer Local Functions over Nested Functions:**
```matlab
function result = mainFunction(data)
    % Local function is faster when it doesn't need
    % access to parent function variables
    result = localHelper(data);
end

function out = localHelper(in)
    out = in .^ 2;
end
```

Use nested functions only when you need access to the parent function's variables.

### Preallocation

Always preallocate arrays before filling them in loops.

**Slow (Avoid):**
```matlab
% Array grows each iteration - very slow
for i = 1:10000
    result(i) = compute(i);
end
```

**Fast (Use This):**
```matlab
% Preallocate to maximum size
result = zeros(1, 10000);
for i = 1:10000
    result(i) = compute(i);
end
```

**For Cell Arrays and Structures:**
```matlab
% Preallocate cell array
C = cell(1, 1000);

% Preallocate structure array
S(1000) = struct('field1', [], 'field2', []);
```

### Loop Optimization

**Move Invariant Computations Outside Loops:**

```matlab
% Slow - recomputes length each iteration
for i = 1:length(data)
    result(i) = data(i) / length(data);
end

% Fast - compute once
n = length(data);
for i = 1:n
    result(i) = data(i) / n;
end

% Fastest - vectorize entirely
result = data / length(data);
```

### Short-Circuit Operators

Use `&&` and `||` for scalar logical operations. MATLAB evaluates the second operand only when necessary.

```matlab
% Short-circuit: isfield only called if s is a struct
if isstruct(s) && isfield(s, 'data')
    process(s.data);
end

% Short-circuit: expensive check only if needed
if ~isempty(data) && validateData(data)
    proceed();
end
```

### Parallel Computing

**Background Execution:**
```matlab
% Run in background for responsive applications
f = parfeval(backgroundPool, @longComputation, 1, data);
% ... do other work ...
result = fetchOutputs(f);
```

**Parallel Loops:**
```matlab
% parfor for independent iterations
parfor i = 1:1000
    results(i) = expensiveComputation(data(i));
end
```

**GPU Computing:**
```matlab
% Move data to GPU
gpuData = gpuArray(data);
result = gather(gpuData .^ 2 + gpuData);
```

---

## Anti-Patterns to Avoid

### Dynamic Evaluation (eval family)

**Avoid:** `eval`, `evalc`, `evalin`, indirect `feval`

**Problems:**
- Security risk with untrusted input
- Performance penalty (code cannot be optimized)
- Debugging difficulty
- Code analysis tools cannot check the code

**Instead of:**
```matlab
eval([varName ' = 42;']);
result = eval(['process_' methodName '(x)']);
```

**Use:**
```matlab
% Dynamic field names
s.(varName) = 42;

% Function handles in a struct
methods.method1 = @process_method1;
methods.method2 = @process_method2;
result = methods.(methodName)(x);

% Or containers.Map
handlers = containers.Map;
handlers('method1') = @process_method1;
result = handlers(methodName)(x);
```

### Global Variables

**Avoid:** Global variables degrade performance and make code harder to understand.

**Instead of:**
```matlab
global CONFIG;
CONFIG.threshold = 0.5;
```

**Use:**
```matlab
% Pass as arguments
result = processData(data, options);

% Or use a configuration object
config = struct('threshold', 0.5);
result = processData(data, config);
```

### Runtime Path Modifications

**Avoid:** `cd`, `addpath`, `rmpath` during execution

**Problems:**
- Forces MATLAB to re-resolve function locations
- Can cause unexpected behavior
- Slows down function calls

**Instead of:**
```matlab
cd('dataFolder');
data = load('file.mat');
cd(originalPath);
```

**Use:**
```matlab
data = load(fullfile('dataFolder', 'file.mat'));
```

### State-Query Functions in Loops

**Avoid in performance-critical code:** `inputname`, `which`, `whos`, `exist`, `dbstack`

These functions query MATLAB's state and are expensive.

**Instead of:**
```matlab
for i = 1:1000
    if exist('result', 'var')
        result(i) = compute(i);
    end
end
```

**Use:**
```matlab
result = zeros(1, 1000);  % Initialize once
for i = 1:1000
    result(i) = compute(i);
end
```

### Data as Code

**Avoid:** Large data embedded in code (500+ lines of data definitions)

**Problems:**
- Slow to parse
- Difficult to maintain
- Cannot be easily updated

**Instead of:**
```matlab
data = [1.234, 2.345, 3.456, ...  % 1000 lines of numbers
        ...];
```

**Use:**
```matlab
% Save to file
save('data.mat', 'data');

% Or use CSV/text files
data = readmatrix('data.csv');
```

### clear all

**Avoid:** `clear all` removes functions from memory, forcing recompilation.

**Use instead:**
```matlab
clearvars  % Clear variables only
clearvars -except keepVar1 keepVar2  % Keep specific variables
```

---

## Performance Profiling

Use MATLAB's profiler to identify bottlenecks:

```matlab
profile on
myFunction(data);
profile viewer
```

Key metrics to watch:
- **Self Time**: Time spent in the function itself
- **Total Time**: Time including called functions
- **Calls**: Number of times function was called

---

## Summary Checklist

Before optimizing, use the profiler to identify actual bottlenecks.

- [ ] Preallocate arrays before loops
- [ ] Vectorize element-wise operations
- [ ] Use logical indexing instead of loops with conditions
- [ ] Move invariant computations outside loops
- [ ] Use functions instead of scripts
- [ ] Avoid eval, global variables, and runtime path changes
- [ ] Use short-circuit operators for scalar logic
- [ ] Store large data in files, not in code
- [ ] Consider parallel computing for independent operations

----

Copyright 2026 The MathWorks, Inc.

----

