classdef MajorityVoter < ConsensusVoter
%MajorityVoter Consensus ranking via majority vote.
%
%   Each method's top-K features receive 1 vote. A feature's score is
%   the number of methods that selected it. Features are ranked by vote count.
%
%   This is a binary scheme — it ignores relative ranking within the top-K.
%   Feature #1 and feature #K get the same credit from each method.
%
%   Properties:
%     TopK - (1,1) double. Number of features each method "votes for."
%            Default: 0 (auto = ceil(nFeatures / 3)).
%
%   Example:
%     Voter = MajorityVoter(TopK=5);
%     [RankedIdx, Scores] = Voter.rank({[3 1 2 5 4], [1 3 5 2 4]}, 6);
%     % Scores = vote counts: how many methods put each feature in their top-5
%
%   See also: ConsensusVoter, createConsensusVoter

% Copyright 2026 The MathWorks, Inc.

    properties
        %TopK Number of features each method votes for (0 = auto)
        TopK (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    end

    methods
        function obj = MajorityVoter(Options)
            arguments
                Options.TopK (1,1) double {mustBeNonnegative, mustBeInteger} = 0
            end
            obj.TopK = Options.TopK;
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

            CurrentTopK = obj.TopK;
            if CurrentTopK == 0
                CurrentTopK = ceil(p / 3);
            end
            CurrentTopK = min(CurrentTopK, p);

            for m = 1:NumMethods
                r = Rankings{m};
                NumVote = min(CurrentTopK, numel(r));
                Scores(r(1:NumVote)) = Scores(r(1:NumVote)) + 1;
            end

            [~, RankedIdx] = sort(Scores, 'descend');
            RankedIdx = RankedIdx(:)';
        end
    end
end
