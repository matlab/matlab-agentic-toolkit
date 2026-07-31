function [cvModel, trainTime, acc, accCI, foldAcc] = train_and_score_cv(cvFitFcn, X, Y, cv)
    N = numel(Y);

    tic;
    cvModel = cvFitFcn(X, Y, cv);
    trainTime = toc;

    err = kfoldLoss(cvModel);
    acc = 1 - err;

    [~, ci] = binofit(round(err * N), N, 0.05);
    accCI = 1 - fliplr(ci);

    foldAcc = 1 - kfoldLoss(cvModel, 'Mode', 'individual');
end

% Copyright 2026 The MathWorks, Inc.
