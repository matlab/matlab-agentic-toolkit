function S = sampleSkewness(Col)
%sampleSkewness Compute skewness of a numeric vector.
%   S = sampleSkewness(Col) returns the sample skewness using the
%   standardized third central moment.
%
%   Input:
%     Col — numeric vector (NaN values should be pre-removed)
%
%   Output:
%     S — scalar skewness value (0 = symmetric)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Col (:,1) {mustBeFloat}
    end

    Sigma = std(Col);
    if numel(Col) < 3 || Sigma < eps
        S = 0;
        return;
    end
    Centered = (Col - mean(Col)) / Sigma;
    S = mean(Centered .^ 3);
end
