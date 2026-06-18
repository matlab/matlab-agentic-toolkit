C Copyright 2026 The MathWorks, Inc.
C
C     complexDot_dual.F
C
C     Fortran MEX function that computes the dot product of two
C     complex double vectors. SC/IC dual-compatible version.
C
C     Usage:
C       d = complexDot(A, B)
C
C     Compile (Interleaved Complex API, R2018a+):
C       mex -R2018a complexDot_dual.F
C
C     Compile (Separate Complex API):
C       mex -R2017b complexDot_dual.F
C
C     Original (Separate Complex API):
C       mex complexDot.F
C
C     API Migration:
C       mxGetPr/mxGetPi -> mxGetComplexDoubles (IC path)
C       mxCopyPtrToReal8 -> mxCopyPtrToComplex16 (IC path)
C       mxCopyReal8ToPtr -> mxCopyComplex16ToPtr (IC path)
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

      real*8 dot_real, dot_imag
      integer i

#if MX_HAS_INTERLEAVED_COMPLEX
      mwPointer mxGetComplexDoubles
      mwPointer pc_a, pc_b, pc_out
      complex*16 za(1024), zb(1024)
      complex*16 dot_result
#else
      mwPointer mxGetPr, mxGetPi
      mwPointer pr_a, pi_a, pr_b, pi_b, pr_out, pi_out
      real*8 xr_a(1024), xi_a(1024)
      real*8 xr_b(1024), xi_b(1024)
#endif

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
C     IC path: get pointers to interleaved complex buffers
      pc_a = mxGetComplexDoubles(prhs(1))
      pc_b = mxGetComplexDoubles(prhs(2))

C     Copy interleaved complex data to Fortran complex*16 arrays
      call mxCopyPtrToComplex16(pc_a, za, n)
      call mxCopyPtrToComplex16(pc_b, zb, n)

C     Compute complex dot product: sum(conj(A) .* B)
      dot_real = 0.0D0
      dot_imag = 0.0D0
      do i = 1, n
          dot_real = dot_real + dreal(za(i))*dreal(zb(i))
     +                        + dimag(za(i))*dimag(zb(i))
          dot_imag = dot_imag + dreal(za(i))*dimag(zb(i))
     +                        - dimag(za(i))*dreal(zb(i))
      end do

C     Create output: 1x1 complex scalar
      plhs(1) = mxCreateDoubleMatrix(1, 1, 1)
      pc_out = mxGetComplexDoubles(plhs(1))
      dot_result = dcmplx(dot_real, dot_imag)
      call mxCopyComplex16ToPtr(dot_result, pc_out, 1)
#else
C     SC path: get separate real and imaginary pointers
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
