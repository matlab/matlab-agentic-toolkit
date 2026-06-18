/* Copyright 2026 The MathWorks, Inc. */
/*
 * multiTypeSum.c
 *
 * MEX function that sums elements of any numeric type using mxGetData.
 * Returns the sum as a double scalar.
 *
 * Usage:
 *   s = multiTypeSum(X)
 *
 * Compile:
 *   mex multiTypeSum.c
 */

#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    void *data;
    double sum = 0.0;
    mwSize numElements;
    mwSize i;
    mxClassID classID;

    if (nrhs != 1)
        mexErrMsgIdAndTxt("mex:multiTypeSum:nrhs", "One input required.");
    if (!mxIsNumeric(prhs[0]))
        mexErrMsgIdAndTxt("mex:multiTypeSum:notNumeric", "Input must be numeric.");

    numElements = mxGetNumberOfElements(prhs[0]);
    classID = mxGetClassID(prhs[0]);
    data = mxGetData(prhs[0]);

    switch (classID) {
        case mxDOUBLE_CLASS:
            for (i = 0; i < numElements; i++)
                sum += ((double *)data)[i];
            break;
        case mxSINGLE_CLASS:
            for (i = 0; i < numElements; i++)
                sum += (double)((float *)data)[i];
            break;
        case mxINT32_CLASS:
            for (i = 0; i < numElements; i++)
                sum += (double)((int *)data)[i];
            break;
        case mxUINT8_CLASS:
            for (i = 0; i < numElements; i++)
                sum += (double)((unsigned char *)data)[i];
            break;
        default:
            mexErrMsgIdAndTxt("mex:multiTypeSum:unsupported", "Unsupported type.");
    }

    plhs[0] = mxCreateDoubleScalar(sum);
}
