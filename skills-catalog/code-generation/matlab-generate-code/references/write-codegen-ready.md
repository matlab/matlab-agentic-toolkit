# Write Codegen-Ready MATLAB Code

MATLAB Coder converts dynamically typed MATLAB to statically typed C/C++. Most code generation errors stem from this type system mismatch. This reference enforces the constraints, patterns, and best practices that produce codegen-ready MATLAB code.

## Preserve the Original API

When making existing MATLAB code codegen-compatible, do NOT change the function signature, input/output names, number of arguments, default values, or public calling conventions. Fix only the internal implementation — replace unsupported constructs, preallocate arrays, add `%#codegen`, use `coder.varsize`, etc. Existing callers must continue to work unchanged.

## First Step: Ask for Input Types

**Before writing any codegen-ready function, proactively ask the user to specify the types and sizes of all input variables.** Design choices (preallocation strategy, fixed vs. variable-size, memory layout, use of `coder.varsize`, integer width) depend critically on input characteristics.

Ask:
- What is the data type of each input? (double, single, int32, uint8, logical, struct, etc.)
- What is the size/shape? (scalar, fixed-size vector/matrix, variable-size?)
- Is the input real or complex?

**Variable bounds:** Do NOT ask the user about upper bounds on variable sizes unless they have explicitly requested DMA-off (no dynamic memory) code generation. Otherwise, either infer bounds automatically from context or use unbounded `coder.varsize`.

Do not proceed with implementation until input types are clarified.

## Core Requirements — Top 5 (inline)

These five constraints cause the majority of codegen failures. Apply them every time.

### 1. Always include `%#codegen`

Place after the function signature. Enables Code Analyzer warnings in the editor.

```matlab
function y = myFilter(x, coeffs) %#codegen
```

### 2. Preallocate arrays — never grow inside loops

```matlab
result = zeros(n, 1);           % GOOD: preallocated
for i = 1:n, result(i) = f(i); end

result = [result; f(i)];        % BAD: grows dynamically — codegen error
```

Static allocation (DMA-off): no `x = [x; row]`, no `x(idx) = []`, no unbounded `coder.varsize`.

### 3. One variable, one type, one size category

A variable cannot change class or complexity after first assignment. Assign different-sized values on different branches only after declaring `coder.varsize`.

### 4. Consistent function output types across all paths

All execution paths must return the same type and size for each output. C function signatures have fixed return types.

```matlab
% BAD: double on one path, char on another
if x > 0, result = x * 2; else, result = 'negative'; end

% GOOD: consistent double on all paths
if x > 0, result = x * 2; else, result = -1; end
```

### 5. Use only supported language features

**NOT supported:** `try`/`catch`, `eval`, `evalin`, Java, `import`, Map containers, scripts, arrays of class objects, handle objects as entry-point I/O. Note: `string` is a class — string arrays (`["a","b"]`) are object arrays and not supported; use string scalars only.

**ARE supported:** `datetime`, `duration` (full), `timetable` (with constraints — see [write-temporal-types.md](write-temporal-types.md)), string scalars, tables, sparse matrices, MATLAB classes (with limitations — see [write-class-limitations.md](write-class-limitations.md)).

## Remaining Constraints (load on demand)

For full details on all 11 constraints with extended examples, load [write-core-constraints.md](write-core-constraints.md) when you encounter:
- P-code distribution, numeric literal type issues, dimension-wise size inference, input shape normalization, or entry-point input type limitations.

## Quick Reference

| Need | Use |
|------|-----|
| Mark function for codegen | `%#codegen` after signature |
| P-code support | `coder.allowpcode('plain')` |
| Specify input types | `coder.typeof(val, sz, varDims)` |
| Declare variable-size | `coder.varsize('var', upperBound)` |
| Exclude from codegen (MEX only) | `coder.extrinsic('func')` |
| Compile-time constant | `coder.const(expr)` or `coder.const(@func, args)` |
| Enforce constant input | `{coder.mustBeConst}` in arguments block |
| Prevent specialization (value) | `coder.ignoreConst(arg)` |
| Prevent specialization (size) | `coder.ignoreSize(arg)` |
| Force inline | `coder.inline('always')` or `coder.inlineCall(@fn, args)` |
| Prevent inline | `coder.inline('never')` or `coder.nonInlineCall(@fn, args)` |
| Unroll loop | `for i = coder.unroll(1:n)` |
| Disable broadcasting (function) | `coder.noImplicitExpansionInFunction` |
| Disable broadcasting (expression) | `coder.sameSizeBinaryOp(@plus, a, b)` |
| Uninitialized allocation | `coder.nullcopy(zeros(m, n))` |
| Check array layout | `coder.isRowMajor` / `coder.isColumnMajor` |
| Call external C/C++ code | `coder.ceval('func', args...)` with `coder.ref`/`coder.wref`/`coder.rref` |
| Conditional codegen path | `if coder.target('MATLAB') ... end` |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Growing array in loop | Preallocate before loop |
| Using `try`/`catch` | Return status codes; use `coder.target` for MATLAB-only paths |
| Variable changes type | One variable = one type throughout scope |
| Function returns different types/sizes | Ensure consistent output on all paths |
| Using `eval` or dynamic field access with runtime string | Use explicit field names, `switch`, or `coder.const` |
| Missing input type specification | Add `arguments` block or use `coder.typeof` |
| Using unsupported toolbox function | Check docs; find supported alternative |
| C/C++ reserved word as identifier | Rename variable (e.g., `int` -> `intVal`) |
| Multiple specialized copies bloating binary | Apply `coder.ignoreConst` / `coder.ignoreSize` |
| Runtime computation of constants | Wrap with `coder.const()` |
| `coder.extrinsic` expecting runtime behavior in lib/dll | Extrinsic calls produce no code in portable targets; combine with `coder.const` |
| Variable assigned different shapes on different branches | Dimension-wise inference multiplies max per dimension — use `coder.varsize` with tight bounds |

## Troubleshooting by Symptom

| Error / Symptom | Likely Cause | Fix |
|----------------|--------------|-----|
| "Variable 'x' changes size on every loop iteration" | Array growing inside loop | Preallocate; see core-constraints §5 |
| "Type mismatch: variable assigned different types" | Type reassignment or inconsistent output paths | One variable = one type; see §8, §9 |
| "Size mismatch between two assignments" | First assignment locked size differently | Use `coder.varsize` or keep shapes consistent; see §4, §7 |
| "Function not supported for code generation" | Calling unsupported toolbox function | Check doc page "Extended Capabilities"; find alternative |
| "Extrinsic function has no effect" | Using `coder.extrinsic` in lib/dll target | Combine with `coder.const` for compile-time evaluation |
| "Unable to determine size" / unbounded inference | Missing bounds or inconsistent dimensions | Add `assert` size hints or explicit `coder.varsize` bounds |
| Stack overflow in generated code | Dimension-wise inference explosion (k×l) | Keep dimensions consistent; reduce upper bounds; see §7 |
| "Property of handle class has variable size" | Variable-size in handle class (treated unbounded) | Use fixed-size properties; see write-class-limitations.md |
| "Cannot determine which function to call" | Runtime dynamic dispatch on class | Select subclass at compile time; see write-class-limitations.md |
| MEX runs but standalone codegen fails | `coder.extrinsic` calls silently dropped in lib/dll | Guard with `coder.target`; use `coder.const` |

## Sub-References — Load on Demand

| Need | Load |
|------|------|
| Full details on the 11 core constraints | [write-core-constraints.md](write-core-constraints.md) (**always load for new function implementation**) |
| Specific `coder.*` directive reference | [write-coder-directives.md](write-coder-directives.md) |
| Performance tuning, indexing, DMA-off, memory | [write-performance.md](write-performance.md) |
| Numerical accuracy, NaN, MISRA, coding style | [write-numerical-style.md](write-numerical-style.md) |
| Calling C/C++ code, `coder.ceval`, linking | [write-c-interop.md](write-c-interop.md) |
| Using MATLAB classes in codegen | [write-class-limitations.md](write-class-limitations.md) |
| Using `datetime`, `duration`, `timetable` | [write-temporal-types.md](write-temporal-types.md) |

**Always-load rule:** For any new function implementation, load [write-core-constraints.md](write-core-constraints.md). Other sub-references load only when the specific topic applies.

----

Copyright 2026 The MathWorks, Inc.

----
