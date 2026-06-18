/* Copyright 2026 The MathWorks, Inc. */
/*
 * complexScale_ic.c
 *
 * MEX function that scales a complex double array by a real scalar factor.
 * Interleaved Complex API version — zero-copy at the MATLAB boundary.
 *
 * Usage:
 *   Y = complexScale_ic(X, factor)
 *
 * Compile (Interleaved Complex API, R2018a+):
 *   mex -R2018a complexScale_ic.c
 *
 * Original (Separate Complex API):
 *   mex complexScale.c
 *
 * API Migration:
 *   mxGetPr/mxGetPi -> mxGetComplexDoubles
 *   mxCalloc + mxSetPr/mxSetPi -> mxGetComplexDoubles (direct buffer write)
 */

#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    mxComplexDouble *pc_in, *pc_out;
    double factor;
    mwSize numElements;
    mwSize i;

    if (nrhs != 2)
        mexErrMsgIdAndTxt("mex:complexScale:nrhs", "Two inputs required.");
    if (!mxIsDouble(prhs[0]) || !mxIsComplex(prhs[0]))
        mexErrMsgIdAndTxt("mex:complexScale:notComplex", "First input must be complex double.");
    if (!mxIsDouble(prhs[1]) || mxIsComplex(prhs[1]) || mxGetNumberOfElements(prhs[1]) != 1)
        mexErrMsgIdAndTxt("mex:complexScale:notScalar", "Second input must be a real scalar.");

    numElements = mxGetNumberOfElements(prhs[0]);
    factor = mxGetDoubles(prhs[1])[0];

    /* Zero-copy access to input complex data in MATLAB's native interleaved layout */
    pc_in = mxGetComplexDoubles(prhs[0]);

    /* Create output and write directly into its buffer — no intermediate allocation */
    plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxCOMPLEX);
    pc_out = mxGetComplexDoubles(plhs[0]);

    /* Single-pass loop with perfect spatial locality */
    for (i = 0; i < numElements; i++) {
        pc_out[i].real = pc_in[i].real * factor;
        pc_out[i].imag = pc_in[i].imag * factor;
    }
}
