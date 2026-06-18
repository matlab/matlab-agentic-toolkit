C Copyright 2026 The MathWorks, Inc.
C
C     complexDot.F
C
C     Fortran MEX function that computes the dot product of two
C     complex double vectors.
C
C     Usage:
C       d = complexDot(A, B)
C
C     Compile (dual-compatible):
C       mex -R2018a complexDot.F
C       mex -R2017b complexDot.F
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
#else
      mwPointer mxGetPr, mxGetPi
      mwPointer pr_a, pi_a, pr_b, pi_b, pr_out, pi_out
#endif

      real*8 xr_a(1024), xi_a(1024)
      real*8 xr_b(1024), xi_b(1024)
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
C     Interleaved complex API: get pointer to interleaved data
      pa = mxGetComplexDoubles(prhs(1))
      pb = mxGetComplexDoubles(prhs(2))

C     Copy interleaved complex data to separate real/imag arrays
      call mxCopyPtrToComplex16(pa, xr_a, xi_a, n)
      call mxCopyPtrToComplex16(pb, xr_b, xi_b, n)
#else
C     Separate complex API: get real and imaginary part pointers
      pr_a = mxGetPr(prhs(1))
      pi_a = mxGetPi(prhs(1))
      pr_b = mxGetPr(prhs(2))
      pi_b = mxGetPi(prhs(2))

C     Copy separate real and imaginary data to Fortran arrays
      call mxCopyPtrToReal8(pr_a, xr_a, n)
      call mxCopyPtrToReal8(pi_a, xi_a, n)
      call mxCopyPtrToReal8(pr_b, xr_b, n)
      call mxCopyPtrToReal8(pi_b, xi_b, n)
#endif

C     Compute complex dot product: sum(conj(A) .* B)
      dot_real = 0.0D0
      dot_imag = 0.0D0
      do i = 1, n
          dot_real = dot_real + xr_a(i)*xr_b(i) + xi_a(i)*xi_b(i)
          dot_imag = dot_imag + xr_a(i)*xi_b(i) - xi_a(i)*xr_b(i)
      end do

C     Create output: 1x1 complex scalar
      plhs(1) = mxCreateDoubleMatrix(1, 1, 1)

#if MX_HAS_INTERLEAVED_COMPLEX
C     Interleaved complex API: copy result as interleaved pair
      pout = mxGetComplexDoubles(plhs(1))
      call mxCopyComplex16ToPtr(dot_real, dot_imag, pout, 1)
#else
C     Separate complex API: copy real and imaginary parts separately
      pr_out = mxGetPr(plhs(1))
      pi_out = mxGetPi(plhs(1))
      call mxCopyReal8ToPtr(dot_real, pr_out, 1)
      call mxCopyReal8ToPtr(dot_imag, pi_out, 1)
#endif

      return
      end
