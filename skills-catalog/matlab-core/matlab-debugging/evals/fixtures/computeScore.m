function score = computeScore(measurements, baseline)
%computeScore Compute a weighted percentage-change score.
%   score = computeScore(measurements, baseline) returns a single scalar
%   summarizing how much measurements deviate from baseline, weighted by
%   the inverse magnitude of each change.

    delta = measurements - baseline;
    pctChange = delta ./ baseline * 100;
    weights = 1 ./ abs(delta);
    score = sum(pctChange .* weights) / sum(weights);
end
% Copyright 2026 The MathWorks, Inc.
