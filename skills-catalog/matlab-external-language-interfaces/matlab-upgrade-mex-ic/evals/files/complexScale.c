/* Copyright 2026 The MathWorks, Inc. */
/*
 * complexScale.c
 *
 * MEX function that scales a complex double array by a real scalar factor.
 * Uses mxCalloc + mxSetPr/mxSetPi pattern (separate buffer allocation).
 *
 * Usage:
 *   Y = complexScale(X, factor)
 *
 * Compile:
 *   mex complexScale.c
 */

#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    double *pr_in, *pi_in;
    double *pr_out, *pi_out;
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
    factor = mxGetScalar(prhs[1]);

    pr_in = mxGetPr(prhs[0]);
    pi_in = mxGetPi(prhs[0]);

    /* Allocate output using mxCalloc + mxSetPr/mxSetPi pattern */
    plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxCOMPLEX);
    pr_out = (double *)mxCalloc(numElements, sizeof(double));
    pi_out = (double *)mxCalloc(numElements, sizeof(double));

    for (i = 0; i < numElements; i++) {
        pr_out[i] = pr_in[i] * factor;
        pi_out[i] = pi_in[i] * factor;
    }

    mxSetPr(plhs[0], pr_out);
    mxSetPi(plhs[0], pi_out);
}
