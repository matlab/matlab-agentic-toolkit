function [MeanRho, PairwiseRho] = rankAgreement(Rankings)
%rankAgreement Compute mean pairwise Spearman correlation among ranking vectors.
%   [MeanRho, PairwiseRho] = rankAgreement(Rankings) measures how much
%   multiple ranking methods agree. Used to select the consensus voter:
%   high agreement (MeanRho >= 0.7) favors Borda, low agreement favors RRF.
%
%   Input:
%     Rankings — 1-by-M cell array where each cell contains a 1-by-P
%                vector of feature indices sorted by descending importance
%                (output of rankFeatures)
%
%   Outputs:
%     MeanRho     — scalar mean of all pairwise Spearman correlations
%     PairwiseRho — M-by-M symmetric matrix of pairwise correlations

% Copyright 2026 The MathWorks, Inc.

    arguments
        Rankings (1,:) cell
    end

    M = numel(Rankings);
    p = numel(Rankings{1});

    % Each column is one method's position vector (feature index -> rank), so
    % corr returns the full M-by-M pairwise Spearman matrix in one call.
    Positions = zeros(p, M);
    for m = 1:M
        Positions(Rankings{m}, m) = 1:p;
    end
    PairwiseRho = corr(Positions, Type="Spearman");

    if M > 1
        UpperTriIdx = triu(true(M), 1);
        MeanRho = mean(PairwiseRho(UpperTriIdx));
    else
        MeanRho = 1.0;
    end
end
