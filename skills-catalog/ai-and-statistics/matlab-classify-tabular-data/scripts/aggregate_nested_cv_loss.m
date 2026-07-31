function [acc, accCI] = aggregate_nested_cv_loss(YHatOpt, Y, useUniformPrior, X)
    N = numel(Y);
    if useUniformPrior
        dummyTree = fitctree(X, Y, 'MaxNumSplits', 0, 'Prior', 'uniform');
        W = dummyTree.W;
        err = sum(W(~(YHatOpt == Y))) / sum(W);
    else
        err = sum(~(YHatOpt == Y)) / N;
    end
    acc = 1 - err;
    [~, ciErr] = binofit(round(err * N), N, 0.05);
    accCI = 1 - fliplr(ciErr);
end

% Copyright 2026 The MathWorks, Inc.
