# SC to IC API Function Mappings

Complete mapping of Separate Complex API functions to their Interleaved Complex replacements. These mappings apply to both C and Fortran MEX files — the function names are identical in both languages.

## Required Replacements (Breaking in IC Mode)

These functions do not exist or behave differently in IC mode. Code using them will not compile with `mex -R2018a`.

### Complex Data Accessors

| SC Function | IC Replacement | Notes |
|-------------|---------------|-------|
| `mxGetPi(arr)` | `mxGetComplexDoubles(arr)` → access `.imag` | Returns NULL in IC; must use typed accessor |
| `mxSetPi(arr, ptr)` | `mxSetComplexDoubles(arr, ptr)` | Single interleaved buffer replaces separate imag |
| `mxGetImagData(arr)` | Type-specific complex accessor | See typed accessors below |
| `mxSetImagData(arr, ptr)` | Type-specific complex setter | See typed setters below |

### Complexity Checking

| SC Pattern | IC Replacement | Notes |
|------------|---------------|-------|
| `mxGetPi(arr) != NULL` | `mxIsComplex(arr)` | `mxIsComplex` works in both SC and IC |

## Required Replacements — Wrong Results on Complex Arrays; Untyped

These functions still compile in IC mode on real-only arrays, but return **wrong data on complex arrays** (pointer to interleaved buffer interpreted as real-only). They are also untyped (`double*` or `void*`). Always convert when upgrading to IC.

### Real/Generic Data Accessors

| SC Function | IC Replacement | Why required |
|-------------|---------------|--------------|
| `mxGetPr(arr)` | `mxGetDoubles(arr)` | Wrong results on complex arrays in IC; untyped |
| `mxSetPr(arr, ptr)` | `mxSetDoubles(arr, ptr)` | Wrong results on complex arrays in IC; untyped |
| `mxGetData(arr)` | Type-specific accessor (see below) | Wrong results on complex arrays in IC; `void*` cast unsafe |
| `mxSetData(arr, ptr)` | Type-specific setter (see below) | Wrong results on complex arrays in IC; `void*` cast unsafe |

## Type-Specific Accessors (IC Mode)

### Real Data

| Data Type | Accessor | Setter | Return Type |
|-----------|----------|--------|-------------|
| double | `mxGetDoubles` | `mxSetDoubles` | `mxDouble*` |
| single | `mxGetSingles` | `mxSetSingles` | `mxSingle*` |
| int8 | `mxGetInt8s` | `mxSetInt8s` | `mxInt8*` |
| uint8 | `mxGetUint8s` | `mxSetUint8s` | `mxUint8*` |
| int16 | `mxGetInt16s` | `mxSetInt16s` | `mxInt16*` |
| uint16 | `mxGetUint16s` | `mxSetUint16s` | `mxUint16*` |
| int32 | `mxGetInt32s` | `mxSetInt32s` | `mxInt32*` |
| uint32 | `mxGetUint32s` | `mxSetUint32s` | `mxUint32*` |
| int64 | `mxGetInt64s` | `mxSetInt64s` | `mxInt64*` |
| uint64 | `mxGetUint64s` | `mxSetUint64s` | `mxUint64*` |

### Complex Data

| Data Type | Accessor | Setter | Return Type |
|-----------|----------|--------|-------------|
| complex double | `mxGetComplexDoubles` | `mxSetComplexDoubles` | `mxComplexDouble*` |
| complex single | `mxGetComplexSingles` | `mxSetComplexSingles` | `mxComplexSingle*` |
| complex int8 | `mxGetComplexInt8s` | `mxSetComplexInt8s` | `mxComplexInt8*` |
| complex uint8 | `mxGetComplexUint8s` | `mxSetComplexUint8s` | `mxComplexUint8*` |
| complex int16 | `mxGetComplexInt16s` | `mxSetComplexInt16s` | `mxComplexInt16*` |
| complex uint16 | `mxGetComplexUint16s` | `mxSetComplexUint16s` | `mxComplexUint16*` |
| complex int32 | `mxGetComplexInt32s` | `mxSetComplexInt32s` | `mxComplexInt32*` |
| complex uint32 | `mxGetComplexUint32s` | `mxSetComplexUint32s` | `mxComplexUint32*` |
| complex int64 | `mxGetComplexInt64s` | `mxSetComplexInt64s` | `mxComplexInt64*` |
| complex uint64 | `mxGetComplexUint64s` | `mxSetComplexUint64s` | `mxComplexUint64*` |

## Complex Data Struct Layout (IC Mode)

```c
/* Each complex element is a struct with .real and .imag fields */
typedef struct {
    double real;
    double imag;
} mxComplexDouble;

typedef struct {
    float real;
    float imag;
} mxComplexSingle;

typedef struct {
    int32_T real;
    int32_T imag;
} mxComplexInt32;
/* ... similar for all numeric types */
```

## SC/IC Guarded Pattern (`#if MX_HAS_INTERLEAVED_COMPLEX`)

Use `#if MX_HAS_INTERLEAVED_COMPLEX` to support both APIs in one source.

### C Example

```c
#if MX_HAS_INTERLEAVED_COMPLEX
    /* IC path: single interleaved buffer */
    mxComplexDouble *pc = mxGetComplexDoubles(prhs[0]);
    for (i = 0; i < n; i++) {
        result[i].real = pc[i].real * scale;
        result[i].imag = pc[i].imag * scale;
    }
#else
    /* SC path: separate real and imaginary arrays */
    double *pr = mxGetPr(prhs[0]);
    double *pi = mxGetPi(prhs[0]);
    for (i = 0; i < n; i++) {
        result_r[i] = pr[i] * scale;
        result_i[i] = pi[i] * scale;
    }
#endif
```

### Fortran Example (`.F` file)

```fortran
#if MX_HAS_INTERLEAVED_COMPLEX
c     IC path: interleaved complex*16 buffer
      pc = mxGetComplexDoubles(prhs(1))
      call mxCopyPtrToComplex16(pc, zdata, n)
      do i = 1, n
          zdata(i) = zdata(i) * scale
      end do
#else
c     SC path: separate real and imaginary arrays
      pr = mxGetPr(prhs(1))
      pi = mxGetPi(prhs(1))
      call mxCopyPtrToReal8(pr, xr, n)
      call mxCopyPtrToReal8(pi, xi, n)
      do i = 1, n
          xr(i) = xr(i) * scale
          xi(i) = xi(i) * scale
      end do
#endif
```

### Build Commands

| Language | SC mode | IC mode |
|----------|---------|---------|
| C | `mex file.c` | `mex -R2018a file.c` |
| Fortran | `mex file.F` | `mex -R2018a file.F` |

## Fortran-Specific Considerations

### File Extension Requirements

| Extension | Preprocessor? | SC/IC guarded? |
|-----------|--------------|-----------------|
| `.F` (uppercase) | Yes | Yes — `#if` guards work |
| `.F90` (uppercase) | Yes | Yes — `#if` guards work |
| `.f` (lowercase) | No | No — must use IC-only |
| `.f90` (lowercase) | No | No — must use IC-only |

### Fortran Data Copy Functions

Fortran MEX files use `mxCopyPtrTo*` and `mxCopy*ToPtr` for data transfer between MATLAB arrays and Fortran variables:

| SC Pattern | IC Replacement | Notes |
|-----------|---------------|-------|
| `mxCopyPtrToReal8(mxGetPr(a), x, n)` | `mxCopyPtrToReal8(mxGetDoubles(a), x, n)` | Real double data |
| `mxCopyPtrToReal4(mxGetPr(a), x, n)` | `mxCopyPtrToReal4(mxGetSingles(a), x, n)` | Real single data |
| `mxCopyPtrToReal8(mxGetPi(a), x, n)` | Use `mxCopyPtrToComplex16(mxGetComplexDoubles(a), z, n)` | Complex: copy interleaved, then extract imag |
| `mxCopyReal8ToPtr(x, mxGetPr(a), n)` | `mxCopyReal8ToPtr(x, mxGetDoubles(a), n)` | Write real double data |
| `mxCopyComplex16ToPtr(z, ptr, n)` | `mxCopyComplex16ToPtr(z, mxGetComplexDoubles(a), n)` | Write complex data (IC) |

### Fortran Complex Data Pattern

In SC mode, Fortran MEX files access real and imaginary parts separately:

```fortran
c     SC Fortran pattern
      mwPointer mxGetPr, mxGetPi
      pr = mxGetPr(prhs(1))
      pi = mxGetPi(prhs(1))
      call mxCopyPtrToReal8(pr, xr, n)
      call mxCopyPtrToReal8(pi, xi, n)
```

In IC mode, complex data is interleaved and can be copied directly to a Fortran `complex*16` array:

```fortran
c     IC Fortran pattern
      mwPointer mxGetComplexDoubles
      pc = mxGetComplexDoubles(prhs(1))
      call mxCopyPtrToComplex16(pc, zdata, n)
c     zdata is complex*16 — real and imag parts are together
```

## Build Flags Reference

| Flag | API Mode | Macro Value | Notes |
|------|----------|-------------|-------|
| (none) | Depends on MATLAB version | Varies | Default changed to IC in R2018a |
| `-R2017b` | Separate Complex | 0 | Forces SC mode |
| `-R2018a` | Interleaved Complex | 1 | Forces IC mode |

----

Copyright 2026 The MathWorks, Inc.

----
