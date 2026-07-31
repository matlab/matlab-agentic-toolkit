# Coder Directives Reference

All `coder.*` API functions for controlling code generation behavior.

## coder.extrinsic — MATLAB-Only Functions

Declares functions that should not be compiled. Behavior differs by target:
- **MEX:** Extrinsic function executes in MATLAB at runtime via callback.
- **lib/dll/exe:** Extrinsic calls are excluded entirely — no C/C++ output. Use only with `coder.const` for compile-time evaluation.

```matlab
function y = myFunc(x) %#codegen
    coder.extrinsic('loadConfigFromFile');
    config = coder.const(loadConfigFromFile('params.mat'));
    y = x * config.gain;
end
```

**Use only for:** (1) MEX-time debugging/visualization, (2) compile-time constants with `coder.const` in portable targets.

## coder.target — Specialize for Code Generation

Branch between MATLAB and generated code paths. The inactive branch is eliminated from generated code.

```matlab
function y = compute(x) %#codegen
    if ~coder.target('MATLAB')
        y = optimizedCompute(x);
    else
        try, y = compute_reference(x); plot(y);
        catch e, warning(e.message); y = zeros(size(x)); end
    end
end
```

Common targets: `'MATLAB'`, `'MEX'`, `'Sfun'`, `'Rtw'` (standalone), `'Custom'`.

## coder.const — Constant Folding

Evaluate expressions at code generation time to eliminate runtime cost.

```matlab
lut = coder.const(computeLookupTable(params));

coder.extrinsic('loadCalibration');
cal = coder.const(loadCalibration('sensor.mat'));
```

**Function handle form:** `coder.const(@func, arg1, ...)`

```matlab
fd = coder.const(@deblank, f);  % built-in OK
```

## coder.mustBeConst — Require Compile-Time Constant Inputs

Enforce in an `arguments` block that a parameter must be a compile-time constant.

```matlab
function y = filterData(x, options) %#codegen
    arguments
        x (:,:) double
        options.Method (1,:) char {coder.mustBeConst}
        options.Order (1,1) uint32 {coder.mustBeConst} = uint32(4)
    end
    switch options.Method
        case 'lowpass', y = lpFilter(x, options.Order);
        case 'highpass', y = hpFilter(x, options.Order);
    end
end
```

| | `coder.mustBeConst` | `coder.const()` |
|---|---|---|
| Where | Callee's `arguments` block | Caller's code |
| Effect | Error if caller passes non-constant | Evaluates expression at compile time |
| Use when | Authoring — enforce the contract | Calling — make a value constant |

Use for: string/char algorithm selectors, mode flags, enum selectors in `switch`.

## coder.ignoreConst / coder.ignoreSize — Prevent Specialization

Prevent the code generator from creating multiple specialized function variants (reduces binary bloat).

```matlab
result = processData(coder.ignoreConst(mode), coder.ignoreSize(data));
```

- `coder.ignoreConst(arg)` — multiple call sites pass different constant values
- `coder.ignoreSize(arg)` — multiple call sites pass different-sized inputs

## coder.inline — Inlining Control

Control inlining for speed vs. binary size.

```matlab
function y = fastKernel(x) %#codegen
    coder.inline('always');  % force inline for hot path
    y = x .* x + 2*x;
end

% At call site:
y = coder.inlineCall(@fastKernel, x);    % force inline this call
z = coder.nonInlineCall(@bigUtility, x); % prevent inline this call
```

Use `'always'` on small utility methods (getters, converters, math helpers). Use `'never'` for large functions where binary size matters.

## coder.unroll — Loop Unrolling

Expands a loop into sequential statements at compile time — enables per-iteration type inference.

```matlab
for i = coder.unroll(1:4)
    out(i) = processChannel(i, data);
end
```

**Must unroll:** Heterogeneous cell arrays, `varargin` indexing (each element may differ in type).

**Don't unroll:** Large iteration counts (1000 iterations = 1000x code), homogeneous data.

**Conditional unrolling** (second arg is logical flag):

```matlab
for i = coder.unroll(1:n, ~allHomogeneous)
    result{i} = transform(input{i});
end
```

**`varargin` pattern:**

```matlab
function out = processInputs(varargin) %#codegen
    for i = coder.unroll(1:nargin)
        out{i} = sanitizeAndConvert(varargin{i});
    end
end
```

## coder.noImplicitExpansionInFunction — Eliminate Broadcast Overhead

Tells codegen all binary operands have matching sizes — eliminates runtime size checks, temp buffers, and expansion loops.

```matlab
function y = processColumns(A, B) %#codegen
    coder.noImplicitExpansionInFunction;
    y = A .* B + A;  % direct element-wise C, no size checks
end
```

**Don't use** when function intentionally broadcasts (scalar bias, row-mean subtraction).

**Fine-grained:** `result = coder.sameSizeBinaryOp(@times, x, weights);` (single expression only).

## coder.varsize — Variable-Size Declarations

Always provide upper bounds when possible — enables static allocation.

```matlab
coder.varsize('y', [1 1000]);           % max 1x1000, static allocation
coder.varsize('result', [100 3], [1 0]); % first dim variable (max 100), second fixed
coder.varsize('tokens');                  % no bounds — requires DMA (less optimal)
```

Without bounds, the code generator must use dynamic memory allocation.

## coder.nullcopy — Uninitialized Array Allocation

Allocate without zero-initialization when every element will be written before read. Eliminates `memset` cost.

```matlab
y = coder.nullcopy(zeros(1, n));
for i = uint32(1):uint32(n), y(i) = x(i) * 2 + 1; end
```

**Caution:** Reading before writing produces undefined behavior. Only use when all elements are assigned before access.

## coder.isRowMajor / coder.isColumnMajor — Layout-Aware Iteration

Compile-time constants for writing iteration patterns optimal for both memory layouts.

```matlab
function B = processMatrix(A, rows, cols) %#codegen
    B = coder.nullcopy(zeros(rows, cols));
    if coder.isRowMajor
        for i = 1:rows, for j = 1:cols, B(i,j) = A(i,j)*2; end, end
    else
        for j = 1:cols, for i = 1:rows, B(i,j) = A(i,j)*2; end, end
    end
end
```

Use for multi-dimensional iteration in performance-critical code targeting both layouts. Skip for column-major-only code or element-wise vectorized operations.

## coder.ceval — Call External C/C++ Code

See [write-c-interop.md](write-c-interop.md) for full documentation on calling C/C++ functions, passing arguments by reference (`coder.ref`/`coder.wref`/`coder.rref`), header/build configuration (`coder.cinclude`, `coder.updateBuildInfo`), `coder.opaque`, and memory safety constraints.

----

Copyright 2026 The MathWorks, Inc.

----
