function Voter = createConsensusVoter(Method, Options)
%createConsensusVoter Factory function to create a ConsensusVoter.
%
%   Voter = createConsensusVoter(Method) creates a consensus voter using
%   the specified voting scheme with default parameters.
%
%   Voter = createConsensusVoter(Method, Name=Value) passes additional
%   configuration to the voter's constructor.
%
%   Input:
%     Method - (1,1) string, one of:
%                "borda"    — Borda count (positional scoring)
%                "majority" — Majority vote (binary top-K)
%                "rrf"      — Reciprocal Rank Fusion
%
%   Name-Value Arguments (passed to the corresponding class):
%     For "borda":
%       Weights  - (1,:) double, per-method weights (empty = uniform)
%
%     For "majority":
%       TopK - double, features each method votes for (default: auto)
%
%     For "rrf":
%       K - double, ranking constant (default: 60)
%
%   Output:
%     Voter - ConsensusVoter subclass instance with rank() and select() methods
%
%   Example:
%     % Default Borda voter
%     Voter = createConsensusVoter("borda");
%
%     % RRF with custom constant
%     Voter = createConsensusVoter("rrf", K=10);
%
%     % Majority with fixed top-K
%     Voter = createConsensusVoter("majority", TopK=5);
%
%     % Weighted Borda (trust some methods more)
%     Voter = createConsensusVoter("borda", Weights=[2 1 1 1]);
%
%     % Then use uniformly:
%     Rankings = {r1, r2, r3};
%     [RankedIdx, Scores] = Voter.rank(Rankings, nFeatures);
%     [Selected, Tbl] = Voter.select(Rankings, FeatureNames, 10);
%
%   See also: ConsensusVoter, BordaVoter, MajorityVoter, RRFVoter

% Copyright 2026 The MathWorks, Inc.

    arguments
        Method (1,1) string {mustBeMember(Method, ["borda","majority","rrf"])}
        Options.Weights (1,:) double = double.empty(1,0)
        Options.TopK (1,1) double {mustBeNonnegative, mustBeInteger} = 0
        Options.K (1,1) double {mustBePositive} = 60
    end

    switch Method
        case "borda"
            Voter = BordaVoter(Weights=Options.Weights);
        case "majority"
            Voter = MajorityVoter(TopK=Options.TopK);
        case "rrf"
            Voter = RRFVoter(K=Options.K);
    end
end
