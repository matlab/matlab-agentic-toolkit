/* Copyright 2026 The MathWorks, Inc. */
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    mwSize n, i;

    if (nrhs != 2)
        mexErrMsgIdAndTxt("mex:complexConvolve:nrhs", "Two inputs required.");
    if (!mxIsDouble(prhs[0]) || !mxIsComplex(prhs[0]))
        mexErrMsgIdAndTxt("mex:complexConvolve:input1", "First input must be complex double.");
    if (!mxIsDouble(prhs[1]) || !mxIsComplex(prhs[1]))
        mexErrMsgIdAndTxt("mex:complexConvolve:input2", "Second input must be complex double.");

    n = mxGetNumberOfElements(prhs[0]);
    if (n != mxGetNumberOfElements(prhs[1]))
        mexErrMsgIdAndTxt("mex:complexConvolve:size", "Inputs must be same length.");

    plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxCOMPLEX);

#if MX_HAS_INTERLEAVED_COMPLEX
    {
        mxComplexDouble *x = mxGetComplexDoubles(prhs[0]);
        mxComplexDouble *h = mxGetComplexDoubles(prhs[1]);
        mxComplexDouble *y = mxGetComplexDoubles(plhs[0]);
        for (i = 0; i < n; i++) {
            y[i].real = x[i].real * h[i].real - x[i].imag * h[i].imag;
            y[i].imag = x[i].real * h[i].imag + x[i].imag * h[i].real;
        }
    }
#else
    {
        double *xr = mxGetPr(prhs[0]);
        double *xi = mxGetPi(prhs[0]);
        double *hr = mxGetPr(prhs[1]);
        double *hi = mxGetPi(prhs[1]);
        double *yr = mxGetPr(plhs[0]);
        double *yi = mxGetPi(plhs[0]);
        for (i = 0; i < n; i++) {
            yr[i] = xr[i] * hr[i] - xi[i] * hi[i];
            yi[i] = xr[i] * hi[i] + xi[i] * hr[i];
        }
    }
#endif
}
