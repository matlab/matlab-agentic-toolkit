/* Copyright 2026 The MathWorks, Inc. */
/*
 * complexConvolve.c
 *
 * MEX function that performs element-wise complex multiplication
 * of two equal-length complex double vectors (frequency-domain convolution).
 * Uses the Separate Complex API.
 *
 * Usage:
 *   Y = complexConvolve(X, H)
 *
 * Compile:
 *   mex complexConvolve.c
 */

#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    double *xr, *xi, *hr, *hi;
    double *yr, *yi;
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

    xr = mxGetPr(prhs[0]);
    xi = mxGetPi(prhs[0]);
    hr = mxGetPr(prhs[1]);
    hi = mxGetPi(prhs[1]);

    plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxCOMPLEX);
    yr = mxGetPr(plhs[0]);
    yi = mxGetPi(plhs[0]);

    for (i = 0; i < n; i++) {
        yr[i] = xr[i] * hr[i] - xi[i] * hi[i];
        yi[i] = xr[i] * hi[i] + xi[i] * hr[i];
    }
}
