# Core Constraints for Code Generation

Mandatory requirements for all MATLAB code intended for C/C++ code generation.

## 1. Always Include the Codegen Pragma

Place `%#codegen` immediately after the function signature. Enables the Code Analyzer to flag codegen issues in the editor.

```matlab
function y = myFilter(x, coeffs) %#codegen
    % Function body
end
```

## 2. P-Code Support with coder.allowpcode

Include `coder.allowpcode('plain')` when distributing as p-code. When both `.p` and `.m` files exist on the path, p-files take precedence during code generation.

```matlab
function y = myAlgorithm(x) %#codegen
    coder.allowpcode('plain');
    y = x .* 2;
end
```

Generate p-file with `pcode myAlgorithm.m`. Distribute only the `.p` file.

## 3. Numeric Literals Default to Double

All numeric literals default to `double`. Cast explicitly for intended types to avoid unnecessary float ops in generated code.

```matlab
y = x + 0;              % double arithmetic even if x is single or integer
y = x + single(0);      % single arithmetic
count = count + uint32(1);  % integer arithmetic, no float conversion
```

## 4. Define Type and Size Before Use

Every variable must have its class and size determined before first use. The code generator infers size from the first fixed-size assignment — it locks in the size.

```matlab
% GOOD: type and size clear
y = zeros(1, 100);
for i = 1:100
    y(i) = computeValue(i);
end

% BAD: type/size ambiguous — y grows dynamically
for i = 1:100
    y(i) = computeValue(i);
end
```

If size may vary, declare `coder.varsize` BEFORE first assignment:

```matlab
coder.varsize('x', [1 10]);
x = zeros(1, 3);
x = zeros(1, 10);  % OK: within declared bounds
```

## 5. Preallocate Arrays

Never grow arrays inside loops. Preallocate immediately before the loop.

```matlab
% GOOD
result = zeros(n, m);
for i = 1:n
    for j = 1:m
        result(i, j) = compute(i, j);
    end
end

% BAD — dynamic growth
result = [];
for i = 1:n
    result = [result; computeRow(i)];
end
```

**Static allocation (DMA-off):** Avoid all dynamic resizing:
- No `x = [x; newRow]` or `x(end+1) = val` (growth)
- No `x(idx) = []` (shrinking)
- No unbounded `coder.varsize('x')` — always provide upper bounds
- All array sizes must be determinable at compile time or bounded

## 6. Normalize Input Shape Without Reshaping the Original

When a function accepts inputs in multiple shapes (row vector, column vector, matrix), do not reshape the original variable. Instead, create a new local variable with a consistent shape. This avoids dimension mismatch errors while preserving API flexibility.

```matlab
function y = process(d) %#codegen
    % Normalize to column vector in a new variable — never mutate d
    if isrow(d)
        dNorm = d(:);    % new variable, always column
    else
        dNorm = d;
    end

    % Use dNorm (consistent shape) for all subsequent computation
    y = cumsum(dNorm);
end
```

Reshaping the original input variable in-place can trigger size-mismatch or dimension-inference errors because the code generator may have already locked its shape from the entry-point type specification.

**Type-based branching:** `ischar`, `isnumeric`, `islogical`, `isstruct` are all codegen-supported and can be used to branch on input type within a single function.

```matlab
function result = convert(input) %#codegen
    if isnumeric(input)
        result = double(input);
    elseif islogical(input)
        result = double(input);
    else
        result = 0;  % default
    end
end
```

## 7. Dimension-Wise Size Inference

Codegen infers variable sizes **per dimension independently**. If a variable is `1000x1` on one path and `1x1000` on another, inferred size is `1000x1000` — may blow the stack.

```matlab
% BAD: infers x as 1000x1000
if flag
    x = zeros(1000, 1);    % first dim = 1000
else
    x = zeros(1, 1000);    % second dim = 1000
end

% GOOD: consistent shape
x = zeros(n, 1);  % same dimensions across paths
```

**Fix:** Keep dimensions consistent across branches, or use `coder.varsize` with tight bounds.

## 8. No Type Reassignment

One variable = one type, one size category. Cannot change class or complexity after first assignment.

```matlab
% BAD
x = 5; x = 'hello';  % codegen error — type changed

% GOOD
count = 5; label = 'hello';
```

Different-sized values on different paths require `coder.varsize`:

```matlab
coder.varsize('x', [1 5]);
if flag, x = [1, 2, 3]; else, x = [1, 2, 3, 4, 5]; end
```

**Transposing variable-size arrays is also a reassignment** — `d = d.'` changes shape from `[1x:?]` to `[:?x1]`. Use a new variable instead:

```matlab
coder.varsize('d', [1 100]);
d = getData();       % 1x:? (row)
dCol = d.';          % GOOD: new variable for transposed shape
```

## 9. Consistent Function Output Types

All execution paths must return outputs of identical type and size. C function signatures have fixed return types.

```matlab
% BAD: scalar on one path, 1x3 on another
function result = process(x)
    if x > 0, result = x * 2; else, result = [x, x, x]; end
end

% GOOD: consistent 1x3 output
function result = process(x)
    result = zeros(1, 3);
    if x > 0, result(:) = x * 2; else, result = [x, x, x]; end
end
```

## 10. Use Only Supported Language Features

**Supported:** `if`, `switch`, `for`, `while`, N-D arrays, structs, enums, cell arrays, variable-size (bounded), complex, local/nested/anonymous/recursive functions, `varargin`/`varargout`, argument validation, MATLAB classes (with limitations), dictionaries, string scalars, tables, sparse, `datetime` (full), `duration` (full), `timetable` (read-only). See [write-temporal-types.md](write-temporal-types.md).

**NOT Supported:**
- Scripts, `try`/`catch`, `import`, `eval`/`evalin`/`assignin`, Java, Map containers
- Tall arrays, GPU arrays (unless GPU Coder), `calendarDuration`, pattern arrays
- Arrays of class objects — use struct arrays or scalar objects with array-valued properties
- String arrays (`["a","b"]`) — `string` is a class, so string arrays are object arrays; use string scalars only
- Handle class instantiation in loops — create before the loop
- No dynamic dispatch at runtime — subclass must be chosen at compile time
- No recursive class construction — use struct arrays with index-based relationships
- No variable-size properties in handle classes — must have fixed sizes
- Direct class code generation is supported via `coder.ClassSignature` (R2026a+); on older releases, wrap the class in a function entry point
- Handle objects cannot be entry-point I/O (including nested in structs/cells/value classes)
- Constructor: single output only, no nested functions
- Cannot use `coder.extrinsic` on class/method; cannot pass class to `coder.ceval`
- Cannot overload `subsref`/`subsasgn`/`subsindex`
- No diamond-shaped inheritance; no events/listeners; no `AbortSet`
- Global variables cannot be handle objects

See [write-class-limitations.md](write-class-limitations.md) for full details and workarounds.

**`datetime`/`duration`/`timetable` key constraints:** No text inputs for construction; no `'Format'`/`'TimeZone'` on datetime; no growth/deletion by assignment; no conversion to text. `timetable`: must specify `'VariableNames'`, cannot restructure after creation. See [write-temporal-types.md](write-temporal-types.md) for details.

**Checking function support:** Look for the **"Extended Capabilities - C/C++ Code Generation"** section on any function's documentation page.

**Specify dimension arguments explicitly:** `find`, `all`, `any`, `sum`, `max`, `min`, `mean` — always pass explicit dimension.

```matlab
flag = all(mask, 1);     % GOOD: explicit dimension
colSums = sum(A, 1);    % 1-by-n result
idx = find(x > 0, numel(x));  % with max count
```

**Dual-purpose functions (e.g., `diag`):** Force unambiguous input shape — `diag(x(:))` always constructs.

**Dynamic struct field access** requires compile-time constant field names:

```matlab
val = s.(coder.const(getFieldName(idx)));  % compile-time constant
% Or use switch for runtime selection
switch idx, case 1, val = s.alpha; case 2, val = s.beta; end
```

## 11. Specify Entry-Point Input Types

All entry-point inputs must have types defined. **Cannot be entry-point inputs:** function handles, handle class instances.

Function handles work *within* generated code only. For entry-points needing a callable, use a wrapper or enum dispatch:

```matlab
% GOOD: wrapper with constant handle
function y = processSin(x) %#codegen
    y = process(x, @sin);
end
function y = process(x, func)
    y = feval(func, x);
end

% GOOD: enum/selector dispatch
function y = process(x, mode) %#codegen
    arguments, x (1,:) double; mode (1,1) uint32; end
    switch mode
        case uint32(1), y = sin(x);
        case uint32(2), y = cos(x);
        otherwise, y = x;
    end
end
```

**Prefer `feval`** for calling function handle/name arguments internally.

**Input validation:** Prefer `arguments` block over `validateattributes` — generates more optimized code because codegen uses declared types/sizes directly for inference.

```matlab
% arguments block (preferred)
function y = myFunc(x, n) %#codegen
    arguments, x (1,:) double; n (1,1) uint32; end
    y = x(1:n);
end
```

----

Copyright 2026 The MathWorks, Inc.

----
