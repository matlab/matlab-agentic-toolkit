/* Copyright 2026 The MathWorks, Inc. */
/*
 * realNorm.c
 *
 * MEX function that computes the 2-norm of a real double vector.
 *
 * Usage:
 *   n = realNorm(X)
 *
 * Compile:
 *   mex realNorm.c
 */

#include "mex.h"
#include <math.h>

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    double *data;
    double sum = 0.0;
    mwSize numElements;
    mwSize i;

    if (nrhs != 1)
        mexErrMsgIdAndTxt("mex:realNorm:nrhs", "One input required.");
    if (!mxIsDouble(prhs[0]))
        mexErrMsgIdAndTxt("mex:realNorm:notDouble", "Input must be double.");

    numElements = mxGetNumberOfElements(prhs[0]);
    data = mxGetPr(prhs[0]);

    for (i = 0; i < numElements; i++) {
        sum += data[i] * data[i];
    }

    plhs[0] = mxCreateDoubleScalar(sqrt(sum));
}
