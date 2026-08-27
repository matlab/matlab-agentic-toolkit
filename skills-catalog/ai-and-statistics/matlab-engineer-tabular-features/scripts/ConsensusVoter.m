classdef (Abstract) ConsensusVoter
%ConsensusVoter Abstract base class for consensus feature ranking.
%
%   Subclasses implement the rank method using different voting schemes.
%   Use createConsensusVoter() factory to instantiate the appropriate subclass.
%
%   See also: createConsensusVoter, BordaVoter, MajorityVoter, RRFVoter

% Copyright 2026 The MathWorks, Inc.

    methods (Abstract)
        %rank Produce a consensus ranking from multiple method rankings.
        %
        %   [RankedIdx, Scores] = Voter.rank(Rankings, NumFeatures)
        %
        %   Inputs:
        %     Rankings    - (1,:) cell array of (1,:) double index vectors.
        %                   Each cell is a ranking from one method (best first).
        %     NumFeatures - (1,1) double, total number of features (p).
        %
        %   Outputs:
        %     RankedIdx - (1,p) double, feature indices ordered by consensus
        %                 score (highest score first).
        %     Scores    - (p,1) double, raw consensus score per feature.
        [RankedIdx, Scores] = rank(obj, Rankings, NumFeatures)
    end

    methods
        function [SelectedFeatures, VoteTable] = select(obj, Rankings, FeatureNames, NumSelect)
        %select Rank features then select the top N.
        %
        %   [Selected, Tbl] = Voter.select(Rankings, FeatureNames, NumSelect)
        %
        %   Inputs:
        %     Rankings     - (1,:) cell array of ranking vectors
        %     FeatureNames - (1,p) string array of feature names
        %     NumSelect    - (1,1) double, number of features to keep
        %
        %   Outputs:
        %     SelectedFeatures - (1,:) string of selected feature names
        %     VoteTable        - table: Feature, Score, Rank, Selected

            arguments
                obj
                Rankings (1,:) cell
                FeatureNames (1,:) string
                NumSelect (1,1) double {mustBePositive, mustBeInteger}
            end

            p = numel(FeatureNames);
            NumSelect = min(NumSelect, p);

            [RankedIdx, Scores] = obj.rank(Rankings, p);

            SelectedMask = false(p, 1);
            SelectedMask(RankedIdx(1:NumSelect)) = true;
            SelectedFeatures = FeatureNames(SelectedMask);

            ConsensusRank = zeros(p, 1);
            ConsensusRank(RankedIdx) = 1:p;

            VoteTable = table(FeatureNames', Scores, ConsensusRank, SelectedMask, ...
                VariableNames={'Feature', 'Score', 'Rank', 'Selected'});
            VoteTable = sortrows(VoteTable, 'Rank', 'ascend');
        end
    end
end
