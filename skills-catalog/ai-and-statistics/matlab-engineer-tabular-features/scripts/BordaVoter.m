classdef BordaVoter < ConsensusVoter
%BordaVoter Consensus ranking via Borda count.
%
%   Feature at rank k (out of N ranked by that method) receives N-k+1 points.
%   Unranked features receive 0 points. Scores are summed across all methods.
%
%   Borda count favors features that rank consistently high across methods.
%   A feature ranked #2 by all 5 methods will outscore one ranked #1 by 2
%   methods and unranked by the other 3.
%
%   Properties:
%     Weights - (1,:) double. Per-method weights. Must have one element per
%               ranking passed to rank(). If not set, all methods are
%               weighted equally.
%
%   Example:
%     Voter = BordaVoter();
%     [RankedIdx, Scores] = Voter.rank({[3 1 2], [1 3 2]}, 3);
%
%     % Weighted: trust method 2 more
%     Voter = BordaVoter(Weights=[1 2 1]);
%
%   See also: ConsensusVoter, createConsensusVoter

% Copyright 2026 The MathWorks, Inc.

    properties
        %Weights Per-method weights (empty = uniform)
        Weights (1,:) double = double.empty(1,0)
    end

    methods
        function obj = BordaVoter(Options)
            arguments
                Options.Weights (1,:) double = double.empty(1,0)
            end
            obj.Weights = Options.Weights;
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

            % Determine weights
            if isempty(obj.Weights)
                W = ones(1, NumMethods);
            else
                W = obj.Weights;
                assert(numel(W) == NumMethods, ...
                    'BordaVoter:weightMismatch', ...
                    'Weights length (%d) must match number of rankings (%d).', ...
                    numel(W), NumMethods);
            end

            for m = 1:NumMethods
                r = Rankings{m};
                NumRanked = numel(r);
                for k = 1:NumRanked
                    Scores(r(k)) = Scores(r(k)) + W(m) * (NumRanked - k + 1);
                end
            end

            [~, RankedIdx] = sort(Scores, 'descend');
            RankedIdx = RankedIdx(:)';
        end
    end
end
