function [pvalMatrix, hMatrix] = compute_pairwise_pvalues_holdout(YHat, YTest, alpha)
    nModels = numel(YHat);
    pvalMatrix = NaN(nModels);
    pvalMatrix(1:nModels+1:end) = 1;   % diagonal: self-comparison p=1
    hMatrix    = false(nModels);
    for i = 1:nModels
        for j = i+1:nModels
            [hij, pij] = testcholdout(YHat{i}, YHat{j}, YTest, 'Alpha', alpha);
            pvalMatrix(i,j) = pij; pvalMatrix(j,i) = pij;
            hMatrix(i,j)    = hij; hMatrix(j,i)    = hij;
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
