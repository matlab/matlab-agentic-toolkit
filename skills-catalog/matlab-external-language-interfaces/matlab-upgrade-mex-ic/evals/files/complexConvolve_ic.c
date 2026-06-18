/* Copyright 2026 The MathWorks, Inc. */
/*
 * complexConvolve_ic.c
 *
 * MEX function that performs element-wise complex multiplication
 * of two equal-length complex double vectors (frequency-domain convolution).
 * Uses the Interleaved Complex API (R2018a+).
 *
 * Usage:
 *   Y = complexConvolve_ic(X, H)
 *
 * Compile (IC mode):
 *   mex -R2018a complexConvolve_ic.c
 */

#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    mxComplexDouble *x, *h, *y;
    mwSize n, i;

    /* Input validation */
    if (nrhs != 2)
        mexErrMsgIdAndTxt("mex:complexConvolve:nrhs", "Two inputs required.");
    if (!mxIsDouble(prhs[0]) || !mxIsComplex(prhs[0]))
        mexErrMsgIdAndTxt("mex:complexConvolve:input1", "First input must be complex double.");
    if (!mxIsDouble(prhs[1]) || !mxIsComplex(prhs[1]))
        mexErrMsgIdAndTxt("mex:complexConvolve:input2", "Second input must be complex double.");

    n = mxGetNumberOfElements(prhs[0]);
    if (n != mxGetNumberOfElements(prhs[1]))
        mexErrMsgIdAndTxt("mex:complexConvolve:size", "Inputs must be same length.");

    /* Get interleaved complex data pointers — zero-copy access */
    x = mxGetComplexDoubles(prhs[0]);
    h = mxGetComplexDoubles(prhs[1]);

    /* Allocate output */
    plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxCOMPLEX);
    y = mxGetComplexDoubles(plhs[0]);

    /* Element-wise complex multiply: Y = X .* H */
    for (i = 0; i < n; i++) {
        y[i].real = x[i].real * h[i].real - x[i].imag * h[i].imag;
        y[i].imag = x[i].real * h[i].imag + x[i].imag * h[i].real;
    }
}
