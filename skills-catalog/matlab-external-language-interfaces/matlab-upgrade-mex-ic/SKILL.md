---
name: matlab-upgrade-mex-ic
description: >
  Upgrade C, C++, and Fortran MEX source files from the Separate Complex (SC) API
  to the Interleaved Complex (IC) API. Use when converting mxGetPr/mxGetPi to
  mxGetComplexDoubles, migrating MEX files to -R2018a, adding
  MX_HAS_INTERLEAVED_COMPLEX guards for SC/IC guarded builds, or modernizing
  legacy MEX code that uses mxGetData/mxSetData/mxGetImagData/mxSetImagData.
  Covers C (.c), C++ (.cpp, .cxx), and Fortran (.F, .f90) MEX functions.
  Triggers on: interleaved complex, IC MEX, mex upgrade, mex migration,
  separate complex, mxGetPi, mxGetPr replacement, -R2018a, complex MEX,
  Fortran MEX, .F MEX file, C++ MEX, .cpp MEX file, MEX performance,
  MEX slow complex, MEX call overhead, improve MEX performance complex.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Upgrade MEX Files to Interleaved Complex API

Convert C, C++, and Fortran MEX source files from the Separate Complex (SC) API to the Interleaved Complex (IC) API, following the MathWorks upgrade workflow with guardrails for SC/IC guarded builds using `MX_HAS_INTERLEAVED_COMPLEX`, required vs recommended changes, and verification.

## When to Use

- User has a C, C++, or Fortran MEX file using `mxGetPr`/`mxGetPi`, `mxGetData`/`mxGetImagData`, or `mxSetPr`/`mxSetPi`
- User wants to build with `mex -R2018a`
- User asks about interleaved complex, IC MEX, or modernizing MEX code
- User has legacy MEX code from File Exchange, GitHub, or pre-R2018a era
- User has a C++ MEX file (`.cpp`, `.cxx`) using the C Matrix API (`mxGetPr`/`mxGetPi`, etc.)
- User has a Fortran MEX file (`.F`, `.f90`) using `mxGetPr`/`mxGetPi` via `%val()` pointers
- User reports a MEX function is slow on large complex arrays (call overhead, not loop)
- User asks how to improve MEX performance for complex data

## When NOT to Use

- Writing a new MEX function from scratch — no conversion needed, but advise the user to use IC APIs (`mxGetDoubles`, `mxGetComplexDoubles`, etc.) from the start for better performance on complex data and modern, type-safe data access instead of legacy `mxGetPr`/`mxGetPi`
- C++ MEX API (`matlab::mex::Function`) — different API entirely; this skill covers C++ files that use the C Matrix API (`mex.h`), not the MATLAB Data API for C++ and C++ Engine
- MEX file already uses typed accessors (`mxGetDoubles`, `mxGetComplexDoubles`, etc.) — already IC-compatible, no conversion needed

## Workflow

Follow these 7 steps in order. Do NOT skip steps.

### Step 1: Pre-Upgrade Verification

Before changing anything, understand the current state:

1. Read the source file completely
2. Identify all SC API calls (see [Key API Mappings](#key-api-mappings))
3. Note which data types the MEX handles (double, single, int32, etc.)
4. Note whether it handles complex data (`mxGetPi`, `mxIsComplex`, `mxCOMPLEX`)

Report to the user:
- Number of SC API calls found
- Whether file processes complex numbers (complex arrays in SC mode incur deinterleave/re-interleave overhead)
- **Performance impact:** If the file handles complex data, note that SC MEX calls incur O(n) deinterleave/re-interleave copies at the MATLAB boundary. For large arrays, IC conversion eliminates this overhead entirely (see [Performance Benefits](#performance-benefits-of-ic-conversion)).
- Any other issues noticed (missing error checking, etc.)

### Step 2: Output File Decision

**ASK the user before proceeding:**

> "Where should I write the converted code?
> - **New file** — creates a separate file (e.g., `<name>_ic.c` or `<name>_dual.c`), preserving the original untouched
> - **Modify in place** — edits the original file directly. Choose this if the file is under version control and you can revert if needed."

If user chooses **new file**, use these naming defaults (or a user-specified name):
- IC-only: `<name>_ic.c` / `<name>_ic.F`
- SC/IC guarded: `<name>_dual.c` / `<name>_dual.F`

If user chooses **modify in place**, confirm the file is recoverable (e.g., "This file is tracked by git — you can revert with `git checkout <file>` if needed."). Then edit the original directly.

Tell the user which file you're writing to and why.

### Step 3: Decision Point — IC-Only or SC/IC Guarded?

> **What is "SC/IC guarded"?** A single source file that uses `#if MX_HAS_INTERLEAVED_COMPLEX` preprocessor guards to compile under both the Separate Complex API (`mex -R2017b`) and the Interleaved Complex API (`mex -R2018a`). The compiler defines `MX_HAS_INTERLEAVED_COMPLEX=1` in IC mode and `0` in SC mode, so the guards select the correct code path at build time.

**ASK the user before proceeding:**

> "Do you need this MEX file to compile under both the old SC API and the new IC API? 
> - **SC/IC guarded** — wraps code in `#if MX_HAS_INTERLEAVED_COMPLEX` / `#else` guards so the same source builds with both `mex -R2017b file.c` (SC mode) and `mex -R2018a file.c` (IC mode). Choose this if you support multiple MATLAB versions.
> - **IC-only** — converts fully to IC API. Requires `mex -R2018a` to build. Simpler code but only works on R2018a+."

If user chooses **SC/IC guarded**, use the `#if MX_HAS_INTERLEAVED_COMPLEX` preprocessor pattern:

**C/C++ files:**
```c
#if MX_HAS_INTERLEAVED_COMPLEX
    /* IC code path */
    mxComplexDouble *pc = mxGetComplexDoubles(prhs[0]);
#else
    /* SC code path */
    double *pr = mxGetPr(prhs[0]);
    double *pi = mxGetPi(prhs[0]);
#endif
```

**Fortran files** (`.F` preprocessed source):
```fortran
#if MX_HAS_INTERLEAVED_COMPLEX
      mwPointer mxGetComplexDoubles
      complex*16, pointer :: pc(:)
      call mxGetComplexDoubles(prhs(1), pc)
#else
      mwPointer mxGetPr, mxGetPi
      mwPointer pr, pi
      pr = mxGetPr(prhs(1))
      pi = mxGetPi(prhs(1))
#endif
```

> **Fortran note:** SC/IC guarded Fortran files MUST use `.F` extension (uppercase) so the MEX compiler invokes the C preprocessor. The `.f` or `.f90` extension skips preprocessing and `#if` guards will not work. For `.f90` files that cannot use preprocessor guards, use IC-only conversion.

If user chooses **IC-only**, convert directly without guards.

### Step 4: Iterative Refactoring

All legacy data-access APIs are **REQUIRED** to be converted for a complete IC upgrade. Convert every pattern in this table:

| Legacy Pattern | Replacement | Reason |
|----------------|-------------|--------|
| `mxGetPi(arr)` for data access | `mxGetComplexDoubles(arr)` + `.imag` | Does not exist in IC |
| `mxSetPi(arr, ptr)` | `mxSetComplexDoubles(arr, ptr)` | Does not exist in IC |
| `mxGetImagData(arr)` | Type-specific complex accessor | Does not exist in IC |
| `mxSetImagData(arr, ptr)` | Type-specific complex setter | Does not exist in IC |
| `mxGetPi(arr) != NULL` for complexity check | `mxIsComplex(arr)` — works in both SC and IC | Does not exist in IC |
| `mxGetPr(arr)` | `mxGetDoubles(arr)` | Wrong results on complex arrays in IC; untyped |
| `mxSetPr(arr, ptr)` | `mxSetDoubles(arr, ptr)` | Wrong results on complex arrays in IC; untyped |
| `mxGetData(arr)` + void* cast | Type-specific accessor (`mxGetDoubles`, `mxGetInt32s`, etc.) | Wrong results on complex arrays in IC; untyped |
| `mxSetData(arr, ptr)` | Type-specific setter (`mxSetDoubles`, `mxSetInt32s`, etc.) | Wrong results on complex arrays in IC; untyped |

> **Why all REQUIRED?** `mxGetPr`/`mxGetData` on complex arrays in IC mode return a pointer to interleaved data (real and imaginary interleaved) — iterating as if it were real-only gives **wrong results silently**. On real-only arrays they still work, but are untyped (`void*` or always `double*`). When upgrading to IC, convert everything in one pass for correctness and type safety.

See `references/pitfalls.md` for common conversion mistakes (complexity checks, output allocation, buffer sizing, Fortran interleaved layout).

### Reducing Code Duplication in SC/IC Guarded Mode

In SC/IC guarded mode, minimize duplication by guarding only the accessor calls, not entire logic blocks.

**C/C++ files:**
```c
/* Guard only the pointer acquisition — logic stays shared */
double *pr_in, *pr_out;

#if MX_HAS_INTERLEAVED_COMPLEX
    pr_in = mxGetDoubles(prhs[0]);
#else
    pr_in = mxGetPr(prhs[0]);
#endif

plhs[0] = mxCreateDoubleMatrix(m, n, mxREAL);

#if MX_HAS_INTERLEAVED_COMPLEX
    pr_out = mxGetDoubles(plhs[0]);
#else
    pr_out = mxGetPr(plhs[0]);
#endif

/* Shared logic — no duplication */
for (i = 0; i < numElements; i++) {
    pr_out[i] = pr_in[i] * factor;
}
```

**Fortran files (`.F`):**
```fortran
c     Guard only the pointer acquisition
#if MX_HAS_INTERLEAVED_COMPLEX
      pr_in = mxGetDoubles(prhs(1))
#else
      pr_in = mxGetPr(prhs(1))
#endif

c     Shared logic — no duplication
      call mxCopyPtrToReal8(pr_in, data, numElements)
      do i = 1, numElements
          data(i) = data(i) * factor
      end do
```

For complex data, the layout differs between modes (interleaved struct vs separate arrays), so full `#if`/`#else` blocks around the logic are unavoidable.

**Rule of thumb:**
- **Real data paths** — guard only the accessor, share the loop
- **Complex data paths** — guard the entire block (different data layouts require different loop bodies). See `references/api-mappings.md` § "SC/IC Guarded Pattern" for full complex loop examples in C, C++, and Fortran.

See `references/api-mappings.md` for the complete function mapping table.

### Step 5: Build

Provide the exact build commands (adjust extension for language):

```matlab
% C/C++ files
mex -R2018a <filename>.c       % Explicit IC mode
mex -R2017b <filename>.c       % Explicit SC mode
mex <filename>.c               % Default (version-dependent)
% For C++: same flags with .cpp or .cxx extension
mex -R2018a <filename>.cpp     % Explicit IC mode

% Fortran files (.F with preprocessor guards)
mex -R2018a <filename>.F       % Explicit IC mode
mex -R2017b <filename>.F       % Explicit SC mode
mex <filename>.F               % Default (version-dependent)
```

If the file is SC/IC guarded, remind the user to test all three build modes: `-R2017b` (SC), `-R2018a` (IC), and default (no flag).

> **Fortran:** Files must use `.F` (uppercase) extension for preprocessor guards to work. If the source is `.f` or `.f90`, rename to `.F` or `.F90` when adding `#if` guards.

### Step 6: Verify

Provide MATLAB test commands that compare the converted MEX against the original.

**For IC-only conversions** (separate source files):

```matlab
%% Build original with SC, converted with IC
mex -R2017b originalFile.c -output func_sc    % Explicit SC build
mex -R2018a convertedFile_ic.c -output func_ic % Explicit IC build

%% Compare outputs
Z = complex(rand(4,4), rand(4,4));
assert(isequal(func_sc(Z), func_ic(Z)), 'Output mismatch!');
```

**For SC/IC guarded files** (same source, three build modes):

```matlab
%% Build same source in all three modes
mex -R2017b convertedFile.c -output func_sc       % Explicit SC (forces separate complex)
mex -R2018a convertedFile.c -output func_ic       % Explicit IC (forces interleaved complex)
mex convertedFile.c -output func_default           % Default (no API flag)

%% Compare outputs — all three must match
Z = complex(rand(4,4), rand(4,4));
out_sc = func_sc(Z);
out_ic = func_ic(Z);
out_default = func_default(Z);
assert(isequal(out_sc, out_ic), 'SC vs IC mismatch!');
assert(isequal(out_sc, out_default), 'SC vs default mismatch!');
```

Always test with:
- Complex inputs (if the MEX handles complex data)
- Real inputs (if the MEX handles real data)
- Edge cases: empty arrays, scalars, large arrays
- All three build modes: `-R2017b` (SC), `-R2018a` (IC), and default (no flag)
- The original source file still compiles with `mex -R2017b` (confirms it was not modified)

### Step 7: Document

Add build information to the converted file's header comment:

```c
/*
 * Compile (Interleaved Complex API, R2018a+):
 *   mex -R2018a filename.c
 *
 * Original (Separate Complex API):
 *   mex originalFilename.c
 *
 * API Migration:
 *   mxGetPr/mxGetPi -> mxGetComplexDoubles
 *   mxSetPr/mxSetPi -> mxSetComplexDoubles
 */
```

## Performance Benefits of IC Conversion

IC conversion is not just API modernization — it delivers measurable performance gains for MEX functions that handle complex data.

### Why IC Is Faster

Since R2018a, MATLAB stores complex arrays internally in **interleaved format** (`[re0, im0, re1, im1, ...]`). When a MEX function compiled with the SC API is called:

1. **On entry:** MATLAB deinterleaves the input — splitting one contiguous buffer into two separate real/imag arrays. This is an O(n) copy.
2. **On exit:** MATLAB re-interleaves the output — merging separate buffers back. Another O(n) copy.

For a 10M-element complex double array, that's ~80 MB per complex array crossing the boundary (N × 16 bytes). A MEX with one complex input and one complex output pays ~160 MB total; a MEX with three complex inputs pays ~240 MB on input alone.

IC MEX functions access data in MATLAB's native layout — **zero copy** at the boundary.

### Additional Performance Advantages

- **Cache locality:** `z[i].real` and `z[i].imag` are adjacent (same cache line). SC requires jumping between two arrays millions of elements apart.
- **Single memcpy for bulk copy:** Duplicating a complex array is one `memcpy(dst, src, n * sizeof(mxComplexDouble))` vs two separate copies.
- **FFTW/BLAS/LAPACK interop:** IC layout is byte-for-byte compatible with `fftw_complex`, `double _Complex` (C99), and cuBLAS/cuFFT types — no pack/unpack needed.
- **SIMD-friendly:** Compilers can emit packed-double instructions that load a full complex number in one operation.

### When Performance Justifies IC Migration

| Scenario | Speedup Significance |
|----------|---------------------|
| Large complex arrays (>100K elements) | High — boundary copy dominates |
| Frequent MEX calls in a loop | High — copy overhead accumulates |
| MEX wraps FFTW/BLAS calls | High — eliminates pack/unpack |
| Small arrays (<1K elements) | Low — copy overhead negligible |
| Real-only data (no `mxGetPi`) | None — no deinterleave occurs |

Tell the user: *"For your [N]-element complex array, the SC API forces MATLAB to copy ~[N×16/1e6] MB per complex array argument. With [K] complex arrays crossing the boundary, that's ~[K×N×16/1e6] MB per call. IC eliminates this entirely."*

### Benchmark Template

After conversion, offer this benchmark to quantify the speedup:

```matlab
%% Benchmark SC vs IC MEX performance
N = 1e7;  % 10M complex elements
Z = randn(1,N) + 1i*randn(1,N);
numIter = 20;

% Build both versions
mex -R2017b originalFile.c -output func_sc
mex -R2018a convertedFile_ic.c -output func_ic

% Warmup
for k = 1:3, func_sc(Z); func_ic(Z); end

% Time SC
tSC = zeros(numIter,1);
for k = 1:numIter, tic; func_sc(Z); tSC(k) = toc; end

% Time IC
tIC = zeros(numIter,1);
for k = 1:numIter, tic; func_ic(Z); tIC(k) = toc; end

fprintf('SC median: %.2f ms\n', median(tSC)*1000);
fprintf('IC median: %.2f ms\n', median(tIC)*1000);
fprintf('Speedup: %.1fx\n', median(tSC)/median(tIC));
assert(isequal(func_sc(Z), func_ic(Z)), 'Output mismatch!');
```

### Optimization Tips

- **Use `mxDuplicateArray` for in-place-style operations:** `plhs[0] = mxDuplicateArray(prhs[0]); z = mxGetComplexDoubles(plhs[0]);` — then modify `z[i]` directly. Avoids manual allocation and lets MATLAB optimize the copy.
- **Single-pass loops:** In IC mode, conjugation or scaling touches both `.real` and `.imag` in one loop iteration with perfect spatial locality.
- **Avoid unnecessary `mxMalloc`:** Create output as `mxCOMPLEX` and write directly into the buffer from `mxGetComplexDoubles` — no intermediate allocation.

## Key API Mappings

Summary of the most common conversions. Full table in `references/api-mappings.md`.

### Complex Data Access

| SC API | IC API | Type |
|--------|--------|------|
| `mxGetPr` + `mxGetPi` | `mxGetComplexDoubles` | Required |
| `mxSetPr` + `mxSetPi` | `mxSetComplexDoubles` | Required |
| `mxGetImagData` | Type-specific complex accessor | Required |
| `mxSetImagData` | Type-specific complex setter | Required |
| `mxGetPi(x) != NULL` | `mxIsComplex(x)` | Required |

### Real Data Access (Not Recommended in IC)

| SC API | IC API | Status |
|--------|--------|--------|
| `mxGetPr` | `mxGetDoubles` | Not recommended — replace |
| `mxSetPr` | `mxSetDoubles` | Not recommended — replace |
| `mxGetData` | `mxGetDoubles`/`mxGetInt32s`/etc. | Not recommended — replace |
| `mxSetData` | `mxSetDoubles`/`mxSetInt32s`/etc. | Not recommended — replace |

### Complex Data Types (IC mode)

```c
mxComplexDouble  /* struct with .real and .imag (both double) */
mxComplexSingle  /* struct with .real and .imag (both float) */
mxComplexInt32   /* struct with .real and .imag (both int32_T) */
```

## Conventions

- **Always ask** whether to create a new file or modify in place before writing
- **Always explain** the reason for each change (does not exist in IC, or wrong results on complex arrays / untyped)
- **Always ask** whether to use SC/IC guarded mode or IC-only before converting
- **Always provide** verification test commands
- **Use `mxIsComplex()`** for complexity checks — never `mxGetPi() != NULL`. `mxIsComplex` works in both SC and IC modes, so it can be placed outside `#if` guards.
- **Buffer sizing in IC mode:** `mxGetElementSize()` returns the full interleaved size (16 bytes for complex double). Do NOT multiply by 2.
- **File naming (when creating new file):** `_ic.c`/`_ic.cpp` or `_ic.F` suffix for IC-only conversions; `_dual.c`/`_dual.cpp`/`_dual.F` for SC/IC guarded; or modify in place if user chooses
- **C89 compatibility (C files only):** Declare variables at the top of each `#if`/`#else` block or at the top of the function. MEX compilers may enforce C89 rules where declarations must precede statements. C++ files do not have this restriction.
- **Fortran file extensions:** Use `.F` (uppercase) for SC/IC guarded Fortran files so the C preprocessor processes `#if MX_HAS_INTERLEAVED_COMPLEX` guards. `.f` and `.f90` do not invoke the preprocessor.
- **Fortran pointer handling:** In Fortran MEX, data pointers are `mwPointer` integers passed via `%val()` to copy routines (`mxCopyPtrToReal8`, `mxCopyPtrToComplex16`). In IC mode, use `mxGetComplexDoubles` which returns an `mwPointer` to the interleaved buffer.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Modifying without asking | User may lose the working SC version if not under version control | Always ask: new file or modify in place? |
| Leaving `mxGetPr`/`mxGetData` calls unchanged | Not recommended by MathWorks in IC MEX functions | Replace with typed accessors (`mxGetDoubles`, `mxGetInt32s`, etc.) |
| `numElements * mxGetElementSize(arr) * 2` for complex buffer | `mxGetElementSize` already returns 16 in IC mode | Use `numElements * mxGetElementSize(arr)` without doubling |
| Using `mxGetPi(arr) != NULL` to check complexity | `mxGetPi` doesn't exist in IC mode | Use `mxIsComplex(arr)` |
| Converting without asking about compatibility needs | User may need the file to work on older MATLAB | Always ask: IC-only or SC/IC guarded? |
| Not providing verification steps | Silent wrong answers are catastrophic in MEX | Always provide test commands comparing old vs new output |

----

Copyright 2026 The MathWorks, Inc.

----
