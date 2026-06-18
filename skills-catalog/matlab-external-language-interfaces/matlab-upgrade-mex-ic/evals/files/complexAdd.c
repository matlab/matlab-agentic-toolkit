/* Copyright 2026 The MathWorks, Inc. */
/*
 * complexAdd.c
 *
 * MEX function that adds two complex double arrays element-wise.
 *
 * Usage:
 *   C = complexAdd(A, B)
 *
 * Compile:
 *   mex complexAdd.c
 */

#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    double *pr_a, *pi_a;
    double *pr_b, *pi_b;
    double *pr_out, *pi_out;
    mwSize numElements;
    mwSize i;

    if (nrhs != 2)
        mexErrMsgIdAndTxt("mex:complexAdd:nrhs", "Two inputs required.");
    if (!mxIsDouble(prhs[0]) || !mxIsDouble(prhs[1]))
        mexErrMsgIdAndTxt("mex:complexAdd:notDouble", "Inputs must be double.");
    if (mxGetNumberOfElements(prhs[0]) != mxGetNumberOfElements(prhs[1]))
        mexErrMsgIdAndTxt("mex:complexAdd:sizeMismatch", "Inputs must be same size.");

    numElements = mxGetNumberOfElements(prhs[0]);

    /* Check if either input is complex */
    if (mxGetPi(prhs[0]) != NULL || mxGetPi(prhs[1]) != NULL) {
        /* Complex addition */
        pr_a = mxGetPr(prhs[0]);
        pi_a = mxGetPi(prhs[0]);
        pr_b = mxGetPr(prhs[1]);
        pi_b = mxGetPi(prhs[1]);

        plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxCOMPLEX);
        pr_out = mxGetPr(plhs[0]);
        pi_out = mxGetPi(plhs[0]);

        for (i = 0; i < numElements; i++) {
            pr_out[i] = pr_a[i] + pr_b[i];
            pi_out[i] = (pi_a ? pi_a[i] : 0.0) + (pi_b ? pi_b[i] : 0.0);
        }
    } else {
        /* Real addition */
        pr_a = mxGetPr(prhs[0]);
        pr_b = mxGetPr(prhs[1]);

        plhs[0] = mxCreateDoubleMatrix(mxGetM(prhs[0]), mxGetN(prhs[0]), mxREAL);
        pr_out = mxGetPr(plhs[0]);

        for (i = 0; i < numElements; i++) {
            pr_out[i] = pr_a[i] + pr_b[i];
        }
    }
}
