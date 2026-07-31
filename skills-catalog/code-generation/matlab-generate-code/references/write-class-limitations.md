# MATLAB Class Limitations for Code Generation

MATLAB classes (value and handle) are supported in code generation, but with significant restrictions compared to desktop MATLAB. This reference documents all constraints and recommended patterns.

## Entry-Point Constraints

### Direct class code generation with `coder.ClassSignature` (preferred when applicable)

When the user asks to generate code for a MATLAB class, **try direct class code generation first** using `coder.ClassSignature`. This produces a C++ class with methods — matching the user's intent of "generate C++ class code" rather than flattening the class into a free function.

`coder.ClassSignature` defines the class interface for code generation without requiring a wrapper function.

**PREREQUISITE — enable the Tech Preview feature before any class code generation:**

```matlab
enableCodegenForEntryPointClasses
```

This must be run once per MATLAB session before calling `codegen` with `-class`. If the feature is not enabled, `codegen` will fail with `'ClassName' is a MATLAB class. MATLAB Coder entry points must be MATLAB functions.` — always run this first.

```matlab
% 1. Enable Tech Preview (required once per session)
enableCodegenForEntryPointClasses

% 2. Define class signature from an instance
classSig = coder.ClassSignature(MyClass(initArgs));

% 3. Add constructor (use coder.Constant if arg is compile-time known)
classSig.addMethod('MyClass', {coder.Constant(initValue)});

% 4. Add methods — first arg is classSig itself (maps to 'this')
classSig.addMethod('compute', {classSig, coder.typeof(double(0))});

% 5. Generate C++ library
cfg = coder.config('lib');
cfg.TargetLang = 'C++';
codegen('-config', cfg, '-class', classSig, '-d', outDir)
```

If `coder.ClassSignature` is unavailable in the user's MATLAB version (pre-R2026a), fall back to the wrapper-function approach.

### Wrapper-function approach (fallback)

If direct class code generation is unavailable or unsupported for the class structure, wrap class usage in a function:

```matlab
function y = useMyClass(x) %#codegen
    obj = MyClass(x);
    y = obj.compute();
end
```

- **Handle class objects cannot be entry-point inputs or outputs.** A handle object cannot appear in any entry-point I/O, whether directly or nested inside a struct, cell, or value class.
- **Value classes containing handle objects** are also excluded from entry-point I/O.

## Constructor Rules

- Constructor must have a **single output** (the object being constructed).
- Constructor **cannot contain nested functions**.
- Constructors must produce a fully initialized object — all properties must be assigned on all code paths.

```matlab
classdef MyFilter %#codegen
    properties
        Order (1,1) uint32
        Coeffs (1,:) double
    end
    methods
        function obj = MyFilter(order, coeffs)
            % Single output, no nested functions, all properties assigned
            obj.Order = order;
            obj.Coeffs = coeffs;
        end
    end
end
```

## Method & Declaration Constraints

- **Cannot declare a class or method as extrinsic** via `coder.extrinsic`.
- **Cannot pass a class instance to `coder.ceval`** — however, individual properties can be passed:

```matlab
% BAD: passing object to C code
coder.ceval('processObj', coder.ref(obj));  % ERROR

% GOOD: pass individual properties
coder.ceval('processData', coder.ref(obj.Data), obj.Length);
```

## Operator Overloading

Cannot generate code for a class that overloads:
- `subsref` (custom indexing with `()`, `{}`, `.`)
- `subsasgn` (custom indexed assignment)
- `subsindex` (custom use as array index)

Use explicit method calls instead of custom subscripting syntax.

## Inheritance

- If a subclass derives from a **MATLAB built-in type** (e.g., `double`, `int32`), the subclass must be an **enumeration class**.
- **Diamond-shaped inheritance is not supported** — a class cannot inherit from two classes that share a common ancestor:

```matlab
% NOT SUPPORTED: diamond inheritance
%       Base
%      /    \
%   MidA    MidB
%      \    /
%      Child       ← codegen error

% SUPPORTED: linear or tree inheritance without diamond
%   Base → MidA → Child
```

- Standard class inheritance (non-built-in superclass) is supported.
- Subclass selection must be determinable at **compile time** — you cannot select which subclass to instantiate based on a runtime variable:

```matlab
% BAD: runtime subclass selection
if mode == 1
    obj = SubClassA();  % codegen cannot determine type at compile time
else
    obj = SubClassB();
end

% GOOD: compile-time selection via coder.const or separate entry points
function obj = createFilterA() %#codegen
    obj = SubClassA();
end
```

## Handle Class Specifics

### Static Lifetime Management

The code generator statically determines handle object lifetimes. There is no garbage collection or reference counting — memory is reused based on static analysis. This enables:
- Avoidance of dynamic memory allocation
- Deterministic memory usage (important for safety-critical/real-time systems)

### Variable-Size Data in Handle Classes

- Variable-size matrices in handle classes are treated as **unbounded** regardless of any specified upper bound.
- If `DynamicMemoryAllocation = 'Off'`, code generation **fails** for handle classes with variable-size properties.
- Workaround: use fixed-size properties with padding, or move variable-size data outside the handle class.

```matlab
% BAD: variable-size in handle class — treated as unbounded
classdef MyHandle < handle %#codegen
    properties
        Data  % coder.varsize bounds are ignored here
    end
end

% GOOD: fixed-size property with explicit bound
classdef MyHandle < handle %#codegen
    properties
        Data (1,256) double  % fixed max size
        DataLen (1,1) uint32 % track actual length
    end
end
```

### Events and Listeners

Not supported in code generation. Use callback function properties or flag-based notification patterns instead.

### Recursive Data Structures

Recursive structures (linked lists, trees, graphs) are **not supported**. The code generator cannot handle a class that references itself:

```matlab
% NOT SUPPORTED: self-referencing class
classdef TreeNode < handle
    properties
        Value
        Children  % array of TreeNode — recursive, not supported
    end
end

% SUPPORTED: flat struct-based alternative
% Use index-based parent/child relationships in arrays
nodes.Value = zeros(1, maxNodes);
nodes.Parent = zeros(1, maxNodes, 'uint32');
nodes.ChildStart = zeros(1, maxNodes, 'uint32');
nodes.ChildCount = zeros(1, maxNodes, 'uint32');
```

### AbortSet Property Attribute

The `AbortSet` attribute is not supported. Remove it from any class used in code generation.

### Instantiation in Loops

Handle objects cannot be instantiated inside `for` loops. Create them before the loop or use persistent variables:

```matlab
% BAD: handle instantiation in loop
for i = 1:n
    obj = MyHandle();  % ERROR
    obj.process(data(i));
end

% GOOD: create before loop
obj = MyHandle();
for i = 1:n
    obj.reset();
    obj.process(data(i));
end
```

## Object Arrays

Arrays of class objects (`obj(1:n)`) are **not supported**. Use these alternatives:

- **Scalar object with array-valued properties** — the object holds arrays, not the other way around:

```matlab
% NOT SUPPORTED: array of objects
filters(1:4) = MyFilter();

% SUPPORTED: scalar object with array properties
classdef FilterBank %#codegen
    properties
        Coeffs (4,64) double    % 4 filters, each up to 64 taps
        Orders (1,4) uint32
    end
end
```

- **Struct arrays** — when each element needs different field values.

**Caveat — `string` arrays:** MATLAB's `string` type is a class. Only **string scalars** (`"hello"`) are supported for code generation. String arrays (`["a", "b", "c"]`) are object arrays under the hood and are not supported. Use `char` vectors or cell arrays of character vectors for collections of text.

## Global Variables

Global variables **cannot** be handle class objects. Use persistent variables within functions, or pass handle objects as function arguments.

## Value Class vs. Handle Class: Choosing for Codegen

| Factor | Value Class | Handle Class |
|--------|-------------|--------------|
| Copy semantics | Deep copy on assignment | Reference (shared state) |
| Entry-point I/O | Allowed (if no handle properties) | NOT allowed |
| Variable-size properties | Supported with `coder.varsize` | Treated as unbounded |
| DMA-off compatibility | Good | Limited (var-size fails) |
| Loop instantiation | Allowed | NOT allowed |
| Object arrays | Not supported (either type) | Not supported |

**Recommendation:** Prefer value classes for codegen unless you specifically need shared-state semantics. Value classes have fewer restrictions and better compatibility with DMA-off targets.

## Simulink-Specific Constraints

- Cannot use classes for Simulink signals, parameters, or data store memory.
- Debugger cannot view class information inside MATLAB Function blocks.

## Summary: Class Codegen Checklist

Before generating code that uses MATLAB classes:

1. Use `coder.ClassSignature` for direct class entry-point codegen (R2026a+); fall back to wrapper function only if unavailable
2. No handle objects in entry-point I/O
3. Constructor has single output, no nested functions
4. No `subsref`/`subsasgn`/`subsindex` overloading
5. No runtime subclass selection (compile-time only)
6. No object arrays — use scalar objects with array properties
7. No handle instantiation in loops
8. No recursive self-referencing classes
9. No events/listeners
10. Handle class properties are fixed-size (or accept DMA)
11. No `AbortSet` attribute on properties
12. Individual properties (not the object) passed to `coder.ceval`

----

Copyright 2026 The MathWorks, Inc.

----
