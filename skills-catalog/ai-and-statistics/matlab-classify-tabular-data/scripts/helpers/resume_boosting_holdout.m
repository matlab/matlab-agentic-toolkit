function [boostModel, trainTime, acc, accCI, YHat] = resume_boosting_holdout(boostModel, nMoreTrees, XTest, YTest)
    fprintf(1, 'Resuming boosting with %d more learning cycles\n', nMoreTrees);
    tic;
    boostModel = resume(boostModel, nMoreTrees);
    trainTime = toc;
    fprintf(1, 'Boosting resumed in %.1f s\n', trainTime);

    [acc, accCI, YHat] = score_holdout_test(boostModel, XTest, YTest);

    if nargout == 0
        clear boostModel trainTime acc accCI YHat
    end
end

% Copyright 2026 The MathWorks, Inc.
