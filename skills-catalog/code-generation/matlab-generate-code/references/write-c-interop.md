# C/C++ Interop for Code Generation

Calling external C/C++ code from MATLAB during code generation using `coder.ceval` and related functions.

## coder.ceval — Call External C/C++ Code

Use `coder.ceval` to call existing C/C++ functions directly from MATLAB code during code generation. This enables integration of legacy C libraries, hand-optimized routines, or hardware-specific code into the generated output.

```matlab
function y = applyFilter(x, n) %#codegen
    coder.cinclude('myFilter.h');
    coder.updateBuildInfo('addSourceFiles', 'myFilter.c');

    % Pre-assign output to establish type for code generator
    y = zeros(1, n);

    % Call C function — pass array by reference for non-scalar output
    coder.ceval('myFilter', coder.ref(x), n, coder.wref(y));
end
```

**Key rules:**

- `coder.ceval` only works in generated code, not in MATLAB execution. Always guard with `coder.target`:

```matlab
if coder.target('MATLAB')
    y = matlabFallback(x);
else
    coder.ceval('optimizedFunc', coder.ref(x), coder.wref(y));
end
```

- The function name must be a **compile-time constant** (string literal or `coder.const` result) and must be a function, not a macro or a C++ method name.
- Return value is **scalar only**. Pre-assign the output variable before the call to establish its type:

```matlab
result = double(0);  % establish type
result = coder.ceval('computeScalar', x);
```

- For non-scalar outputs, pass by reference using `coder.wref` (write-only), `coder.ref` (read/write), or `coder.rref` (read-only):

```matlab
output = zeros(1, 256);
coder.ceval('fillBuffer', coder.rref(input), n, coder.wref(output));
```

## Header and Build Configuration

```matlab
% Include header — Specify header inline with coder.ceval - prefer this approach over coder.cinclude
coder.ceval('-headerfile', 'myLib.h', 'myFunc', x);

% or use coder.cinclude('headerfile') - angle brackets for system headers, no brackets for custom
coder.cinclude('myLib.h');
coder.cinclude('<math.h>');

% Add source files and include paths to the build
coder.updateBuildInfo('addSourceFiles', 'myLib.c');
coder.updateBuildInfo('addIncludePaths', '$(START_DIR)/src');
```

## coder.opaque — C Types Without MATLAB Equivalents

Use `coder.opaque` for C/C++ types that have no MATLAB representation (pointers, FILE*, macros):

```matlab
% Declare a FILE* pointer — no MATLAB equivalent exists
fp = coder.opaque('FILE*', 'NULL');
fp = coder.ceval('fopen', ['data.csv' 0], ['r' 0]);
% ...
coder.ceval('fclose', fp);
```

Also used to pass predefined C macros:

```matlab
status = coder.opaque('int', 'STATUS_OK');
```

## Passing Arguments: By Value vs. By Reference

| Mechanism | Direction | Use when |
|-----------|-----------|----------|
| (default) | By value | Scalar inputs the C function only reads |
| `coder.ref(x)` | Read/write | C function reads and modifies the data |
| `coder.rref(x)` | Read-only | C function only reads (optimizer can exploit) |
| `coder.wref(x)` | Write-only | C function fills output buffer (no read needed) |

Arrays are automatically passed by reference. Use explicit `coder.ref`/`coder.wref`/`coder.rref` for clarity and to avoid unnecessary copies in generated code.

## Character Vectors and Null Termination

Character vectors passed to C must be **null-terminated** — append `0` explicitly:

```matlab
fileName = ['data.csv' 0];   % null-terminated for C
mode = ['rb' 0];
fp = coder.ceval('fopen', fileName, mode);
```

String scalars and string arrays are **not supported** as `coder.ceval` arguments — use char vectors only.

## Memory Safety — Critical Constraints

- External C code must **NOT free or reallocate** memory pointed to by arguments passed via `coder.ref`/`coder.wref`/`coder.rref`. The MATLAB code generator owns that memory.
- External C code must **NOT retain or access** pointers after the MATLAB caller's scope ends. The variable's lifetime is tied to the MATLAB function scope — once that scope exits, the memory may be reclaimed.
- External code and generated code share the same process and memory space — erroneous writes in C code can corrupt MATLAB-managed data and cause crashes.

## coder.ceval Options

| Option | Purpose |
|--------|---------|
| `'-global'` | Indicates function uses global variables; inhibits certain optimizations |
| `'-headerfile', 'file.h'` | Specifies header file; generates `#include` in output |
| `'-layout:rowMajor'` or `'-row'` | Converts data to/from row-major layout |
| `'-layout:columnMajor'` or `'-col'` | Converts data to/from column-major layout (default) |
| `'-layout:any'` | Passes data without layout conversion |

## Limitations

- Cannot call functions declared `coder.extrinsic`
- String scalars and string arrays are not supported as arguments (use char vectors)
- Cannot change the size of an array that was initialized in MATLAB code
- Properties with get/set methods or validators cannot be passed by reference
- Cannot pass a class instance to `coder.ceval` — pass individual properties instead

----

Copyright 2026 The MathWorks, Inc.

----
