function [acc, accCI] = score_holdout_test(model, XTest, YTest)
    err = loss(model, XTest, YTest);
    acc = 1 - err;
    nTest = numel(YTest);
    [~, ciErr] = binofit(round(err * nTest), nTest, 0.05);
    accCI = 1 - fliplr(ciErr);
end

% Copyright 2026 The MathWorks, Inc.
