function [XTrain, YTrain, XTest, YTest] = make_holdout_split(X, Y, holdoutFraction)
    if nargin < 3
        holdoutFraction = 0.3;
    end
    hpart = cvpartition(Y, 'HoldOut', holdoutFraction, 'Stratify', true);
    XTrain = X(training(hpart), :);
    YTrain = Y(training(hpart));
    XTest  = X(test(hpart), :);
    YTest  = Y(test(hpart));
end

% Copyright 2026 The MathWorks, Inc.
