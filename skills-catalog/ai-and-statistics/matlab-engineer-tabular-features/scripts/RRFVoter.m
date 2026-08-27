classdef RRFVoter < ConsensusVoter
%RRFVoter Consensus ranking via Reciprocal Rank Fusion.
%
%   Score = sum(1 / (k + rank_i)) across all methods.
%
%   Standard in information retrieval (Cormack et al., 2009). The reciprocal
%   dampens large rank differences: a feature ranked 50th vs 100th barely
%   changes the score. This makes RRF robust to outlier rankings from
%   individual methods.
%
%   The constant k controls how much top ranks dominate:
%     - Small k (e.g., 1): top ranks dominate heavily
%     - Large k (e.g., 60): more uniform weighting across ranks
%     - k=60 is the standard value from the original paper
%
%   Properties:
%     K - (1,1) double. The ranking constant. Default: 60.
%
%   Example:
%     Voter = RRFVoter(K=60);
%     [RankedIdx, Scores] = Voter.rank({[3 1 2], [1 3 2]}, 3);
%
%     % More emphasis on top ranks:
%     Voter = RRFVoter(K=10);
%
%   See also: ConsensusVoter, createConsensusVoter

% Copyright 2026 The MathWorks, Inc.

    properties
        %K Ranking constant in 1/(K + rank). Higher = more uniform weighting.
        K (1,1) double {mustBePositive} = 60
    end

    methods
        function obj = RRFVoter(Options)
            arguments
                Options.K (1,1) double {mustBePositive} = 60
            end
            obj.K = Options.K;
        end

        function [RankedIdx, Scores] = rank(obj, Rankings, NumFeatures)
            arguments
                obj
                Rankings (1,:) cell
                NumFeatures (1,1) double {mustBePositive, mustBeInteger}
            end

            p = NumFeatures;
            NumMethods = numel(Rankings);
            Scores = zeros(p, 1);

            for m = 1:NumMethods
                r = Rankings{m};
                for k = 1:numel(r)
                    Scores(r(k)) = Scores(r(k)) + 1 / (obj.K + k);
                end
            end

            [~, RankedIdx] = sort(Scores, 'descend');
            RankedIdx = RankedIdx(:)';
        end
    end
end
