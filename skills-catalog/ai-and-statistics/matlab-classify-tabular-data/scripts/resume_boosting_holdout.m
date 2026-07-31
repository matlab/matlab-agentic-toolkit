function [boostModel, trainTime, acc, accCI, YHat] = resume_boosting_holdout(boostModel, nMoreTrees, XTest, YTest)
    tic;
    boostModel = resume(boostModel, nMoreTrees);
    trainTime = toc;

    err = loss(boostModel, XTest, YTest);
    YHat = predict(boostModel, XTest);
    acc = 1 - err;

    NTest = numel(YTest);
    [~, ci] = binofit(round(err * NTest), NTest, 0.05);
    accCI = 1 - fliplr(ci);
end

% Copyright 2026 The MathWorks, Inc.
