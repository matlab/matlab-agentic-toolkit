function [model, trainTime, acc, accCI, YHat] = train_and_score_holdout(template, XTrain, YTrain, XTest, YTest, useUniformPrior)
    if nargin < 6
        useUniformPrior = false;
    end

    tic;
    if isa(template, 'ClassificationNeuralNetwork')
        % R2026a and earlier: templateNeuralNetwork is unavailable; the "template"
        % is a trained ClassificationNeuralNetwork. Calling fit() on it resolves
        % to Curve Fitting Toolbox's fit and errors. Retrain via fitcnet directly.
        if useUniformPrior
            model = fitcnet(XTrain, YTrain, 'Standardize', true, 'Prior', 'uniform');
        else
            model = fitcnet(XTrain, YTrain, 'Standardize', true);
        end
    else
        if useUniformPrior
            model = fit(template, XTrain, YTrain, 'Prior', 'uniform');
        else
            model = fit(template, XTrain, YTrain);
        end
    end
    trainTime = toc;

    err = loss(model, XTest, YTest);
    YHat = predict(model, XTest);
    acc = 1 - err;

    NTest = numel(YTest);
    [~, ci] = binofit(round(err * NTest), NTest, 0.05);
    accCI = 1 - fliplr(ci);
end

% Copyright 2026 The MathWorks, Inc.
