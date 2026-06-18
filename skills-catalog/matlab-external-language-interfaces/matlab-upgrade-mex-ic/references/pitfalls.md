# IC Conversion Pitfalls

Common mistakes when converting C and Fortran MEX files from Separate Complex to Interleaved Complex API.

## Pitfall 1: mxGetElementSize Doubling for Complex Data

### The Problem

In SC mode, `mxGetElementSize()` returns 8 for a complex double array (just the real part size). Code often compensates:

```c
/* SC code — multiplies by 2 for complex */
bufSize = numElements * mxGetElementSize(array) * 2;
```

In IC mode, `mxGetElementSize()` already returns 16 (the full `mxComplexDouble` struct size). Keeping the `* 2` allocates double the needed memory.

### Correct IC Code

```c
/* IC code — mxGetElementSize already includes both parts */
size_t elementSize = mxGetElementSize(array);  /* Returns 16 for complex double */
size_t bufSize = numElements * elementSize;     /* No multiplication by 2 */
```

### Size Reference

| Array Type | SC `mxGetElementSize` | IC `mxGetElementSize` |
|-----------|----------------------|----------------------|
| real double | 8 | 8 |
| complex double | 8 | 16 |
| real single | 4 | 4 |
| complex single | 4 | 8 |
| real int32 | 4 | 4 |
| complex int32 | 4 | 8 |

## Pitfall 2: Complexity Checking with mxGetPi

### The Problem

SC code commonly checks if an array is complex by testing if `mxGetPi` returns NULL:

```c
/* SC pattern — BREAKS in IC mode */
if (mxGetPi(prhs[0]) != NULL) {
    /* Handle complex case */
}
```

In IC mode, `mxGetPi` does not exist. This will not compile.

### Correct Approach (Works in Both Modes)

```c
/* Correct — works in both SC and IC */
if (mxIsComplex(prhs[0])) {
    /* Handle complex case */
}
```

`mxIsComplex()` is available in all MATLAB versions and works correctly in both API modes.

## Pitfall 3: Separate Buffer Allocation for Real and Imaginary

### The Problem

SC code allocates separate buffers for real and imaginary parts:

```c
/* SC pattern */
double *realBuf = (double *)mxMalloc(n * sizeof(double));
double *imagBuf = (double *)mxMalloc(n * sizeof(double));
/* Fill separately, then: */
mxSetPr(output, realBuf);
mxSetPi(output, imagBuf);
```

### Correct IC Approach (Preferred)

```c
/* IC pattern — create complex output, write directly into its buffer */
output = mxCreateDoubleMatrix(1, n, mxCOMPLEX);
mxComplexDouble *buf = mxGetComplexDoubles(output);
for (i = 0; i < n; i++) {
    buf[i].real = /* ... */;
    buf[i].imag = /* ... */;
}
```

### Alternative (when you need a temporary buffer)

```c
/* IC pattern — allocate separately, then attach */
mxComplexDouble *buf = (mxComplexDouble *)mxMalloc(n * sizeof(mxComplexDouble));
for (i = 0; i < n; i++) {
    buf[i].real = /* ... */;
    buf[i].imag = /* ... */;
}
output = mxCreateDoubleMatrix(0, 0, mxCOMPLEX);
mxSetComplexDoubles(output, buf);
mxSetM(output, 1);
mxSetN(output, n);
```

## Pitfall 4: Accessing mxGetPr on Complex Arrays in IC Mode

### The Problem

In SC mode, `mxGetPr` on a complex array returns the real part buffer. In IC mode, `mxGetPr` on a complex array returns a pointer to the interleaved data — the "real" values are interleaved with imaginary values, so iterating element-by-element gives wrong results.

### Correct IC Approach

For complex arrays, always use `mxGetComplexDoubles` and access `.real`/`.imag` fields:

```c
mxComplexDouble *pc = mxGetComplexDoubles(prhs[0]);
for (i = 0; i < n; i++) {
    double re = pc[i].real;
    double im = pc[i].imag;
}
```

For real-only arrays, `mxGetDoubles` (or even `mxGetPr`) works fine:

```c
mxDouble *pr = mxGetDoubles(prhs[0]);  /* Real array only */
```

## Pitfall 5: Creating Complex Output Arrays

### The Problem

SC code creates a real array and then "promotes" it to complex by setting imaginary data:

```c
/* SC pattern */
plhs[0] = mxCreateNumericArray(ndim, dims, mxDOUBLE_CLASS, mxREAL);
mxSetPr(plhs[0], realData);
mxSetImagData(plhs[0], imagData);  /* Promotes to complex */
```

### Correct IC Approach

Create the array as complex from the start:

```c
/* IC pattern */
plhs[0] = mxCreateNumericArray(ndim, dims, mxDOUBLE_CLASS, mxCOMPLEX);
mxComplexDouble *buf = (mxComplexDouble *)mxMalloc(n * sizeof(mxComplexDouble));
/* Fill buf[i].real and buf[i].imag */
mxSetComplexDoubles(plhs[0], buf);
```

## Pitfall 6: Forgetting SC/IC Guards for Shared Code

### The Problem

Converting to IC-only when the source is shared across teams or MATLAB versions. The IC-only version cannot be built without `-R2018a`.

### When to Use SC/IC Guarded Pattern

Use `#if MX_HAS_INTERLEAVED_COMPLEX` when:
- Source is on File Exchange or GitHub (users have different MATLAB versions)
- Organization has mixed MATLAB installations
- Code is part of a toolbox supporting multiple releases

Use IC-only when:
- Team only uses R2018a or later
- Internal code with controlled MATLAB version
- User explicitly requests IC-only

## Pitfall 7: Wrong Fortran File Extension for SC/IC Guards

### The Problem

Fortran files with lowercase extensions (`.f`, `.f90`) do not invoke the C preprocessor. Adding `#if MX_HAS_INTERLEAVED_COMPLEX` guards to a `.f` file results in syntax errors — the compiler sees `#if` as invalid Fortran.

### Correct Approach

Rename to uppercase extension before adding guards:
- `.f` → `.F`
- `.f90` → `.F90`

The uppercase extension tells the MEX build system to invoke the C preprocessor first.

If renaming is not possible (e.g., build system constraints), use IC-only conversion without preprocessor guards.

## Pitfall 8: Copying Complex Data Separately in Fortran IC Mode

### The Problem

In SC Fortran MEX, complex data is accessed as two separate real arrays:

```fortran
c     SC Fortran — separate real and imaginary
      call mxCopyPtrToReal8(mxGetPr(prhs(1)), xr, n)
      call mxCopyPtrToReal8(mxGetPi(prhs(1)), xi, n)
```

Naively replacing `mxGetPr`→`mxGetDoubles` and `mxGetPi`→`mxGetComplexDoubles` does NOT work for the imaginary part — `mxGetComplexDoubles` returns the full interleaved buffer, not just the imaginary part.

### Correct IC Approach

Copy the entire interleaved buffer to a Fortran `complex*16` array, then extract parts if needed:

```fortran
c     IC Fortran — copy interleaved to complex*16
      complex*16 zdata(MAXN)
      call mxCopyPtrToComplex16(mxGetComplexDoubles(prhs(1)), zdata, n)
c     Now zdata(i) contains both real and imaginary parts
c     Access: dble(zdata(i)) for real, dimag(zdata(i)) for imaginary
```

## Pitfall 9: Using %val() with IC Typed Accessors in Fortran

### The Problem

Some SC Fortran MEX code passes pointers via `%val()` directly to computational subroutines:

```fortran
c     SC Fortran — %val() pattern
      call myCompute(%val(mxGetPr(prhs(1))), n, result)
```

In IC mode, `mxGetDoubles` returns the same type (`mwPointer`), so `%val()` still works for real data. But for complex data, the interleaved layout means `%val(mxGetComplexDoubles(...))` passes a pointer to `{re, im, re, im, ...}` — the receiving subroutine must expect interleaved data.

### Correct Approach

For real data — `%val()` with typed accessors works unchanged:
```fortran
      call myCompute(%val(mxGetDoubles(prhs(1))), n, result)
```

For complex data — copy to a Fortran `complex*16` array first, then pass to the subroutine:
```fortran
      call mxCopyPtrToComplex16(mxGetComplexDoubles(prhs(1)), zdata, n)
      call myComplexCompute(zdata, n, result)
```

----

Copyright 2026 The MathWorks, Inc.

----
