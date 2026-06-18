C Copyright 2026 The MathWorks, Inc.
C
C     complexDot_ic.F
C
C     Fortran MEX function that computes the dot product of two
C     complex double vectors.
C
C     Dual-compatible: works with both mex -R2017b and mex -R2018a.
C
C     Usage:
C       d = complexDot_ic(A, B)
C
C     Compile:
C       mex -R2018a complexDot_ic.F    (interleaved complex)
C       mex -R2017b complexDot_ic.F    (separate complex)
C
#include "fintrf.h"

      subroutine mexFunction(nlhs, plhs, nrhs, prhs)
      implicit none

      mwPointer plhs(*), prhs(*)
      integer nlhs, nrhs

      mwPointer mxCreateDoubleMatrix
      mwPointer mxGetNumberOfElements
      mwSize n
      integer mxIsComplex, mxIsDouble

#if MX_HAS_INTERLEAVED_COMPLEX
      mwPointer mxGetComplexDoubles
      mwPointer pa, pb, pout
      real*8 interleaved_a(2048)
      real*8 interleaved_b(2048)
      real*8 interleaved_out(2)
#else
      mwPointer mxGetPr, mxGetPi
      mwPointer pr_a, pi_a, pr_b, pi_b, pr_out, pi_out
      real*8 xr_a(1024), xi_a(1024)
      real*8 xr_b(1024), xi_b(1024)
#endif

      real*8 dot_real, dot_imag
      integer i

C     Check inputs
      if (nrhs .ne. 2) then
          call mexErrMsgIdAndTxt('mex:complexDot:nrhs',
     +        'Two inputs required.')
      end if
      if (mxIsDouble(prhs(1)) .ne. 1) then
          call mexErrMsgIdAndTxt('mex:complexDot:notDouble',
     +        'Inputs must be double.')
      end if
      if (mxIsComplex(prhs(1)) .ne. 1) then
          call mexErrMsgIdAndTxt('mex:complexDot:notComplex',
     +        'Inputs must be complex.')
      end if

      n = mxGetNumberOfElements(prhs(1))

#if MX_HAS_INTERLEAVED_COMPLEX
C     --- Interleaved Complex path (mex -R2018a) ---
C     Get pointers to interleaved complex data
      pa = mxGetComplexDoubles(prhs(1))
      pb = mxGetComplexDoubles(prhs(2))

C     Copy interleaved data: [re1,im1,re2,im2,...] into real*8 arrays
      call mxCopyPtrToReal8(pa, interleaved_a, 2*n)
      call mxCopyPtrToReal8(pb, interleaved_b, 2*n)

C     Compute complex dot product: sum(conj(A) .* B)
      dot_real = 0.0D0
      dot_imag = 0.0D0
      do i = 1, n
C         interleaved layout: real at 2*i-1, imag at 2*i
          dot_real = dot_real
     +        + interleaved_a(2*i-1)*interleaved_b(2*i-1)
     +        + interleaved_a(2*i)*interleaved_b(2*i)
          dot_imag = dot_imag
     +        + interleaved_a(2*i-1)*interleaved_b(2*i)
     +        - interleaved_a(2*i)*interleaved_b(2*i-1)
      end do

C     Create output: 1x1 complex scalar
      plhs(1) = mxCreateDoubleMatrix(1, 1, 1)
      pout = mxGetComplexDoubles(plhs(1))

C     Pack result as interleaved [real, imag]
      interleaved_out(1) = dot_real
      interleaved_out(2) = dot_imag
      call mxCopyReal8ToPtr(interleaved_out, pout, 2)

#else
C     --- Separate Complex path (mex -R2017b) ---
C     Get pointers to real and imaginary parts
      pr_a = mxGetPr(prhs(1))
      pi_a = mxGetPi(prhs(1))
      pr_b = mxGetPr(prhs(2))
      pi_b = mxGetPi(prhs(2))

C     Copy data from MATLAB to Fortran arrays
      call mxCopyPtrToReal8(pr_a, xr_a, n)
      call mxCopyPtrToReal8(pi_a, xi_a, n)
      call mxCopyPtrToReal8(pr_b, xr_b, n)
      call mxCopyPtrToReal8(pi_b, xi_b, n)

C     Compute complex dot product: sum(conj(A) .* B)
      dot_real = 0.0D0
      dot_imag = 0.0D0
      do i = 1, n
          dot_real = dot_real + xr_a(i)*xr_b(i) + xi_a(i)*xi_b(i)
          dot_imag = dot_imag + xr_a(i)*xi_b(i) - xi_a(i)*xr_b(i)
      end do

C     Create output: 1x1 complex scalar
      plhs(1) = mxCreateDoubleMatrix(1, 1, 1)
      pr_out = mxGetPr(plhs(1))
      pi_out = mxGetPi(plhs(1))
      call mxCopyReal8ToPtr(dot_real, pr_out, 1)
      call mxCopyReal8ToPtr(dot_imag, pi_out, 1)
#endif

      return
      end
