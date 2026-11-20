function [cvBoostModel, trainTime, acc, accCI, foldAcc, oofPreds] = resume_boosting_cv(cvBoostModel, nMoreTrees)
    fprintf(1, 'Resuming boosting with %d more learning cycles\n', nMoreTrees);
    tic;
    cvBoostModel = resume(cvBoostModel, nMoreTrees);
    trainTime = toc;
    fprintf(1, 'Boosting resumed in %.1f s\n', trainTime);

    err = kfoldLoss(cvBoostModel);
    acc = 1 - err;

    N = numel(cvBoostModel.Y);
    [~, ci] = binofit(round(err * N), N, 0.05);
    accCI = 1 - fliplr(ci);

    foldAcc = 1 - kfoldLoss(cvBoostModel, 'Mode', 'individual');

    if nargout >= 6
        oofPreds = kfoldPredict(cvBoostModel);
    end

    if nargout == 0
        clear cvBoostModel trainTime acc accCI foldAcc oofPreds
    end
end

% Copyright 2026 The MathWorks, Inc.
