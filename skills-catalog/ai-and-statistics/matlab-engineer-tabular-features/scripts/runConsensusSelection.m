function [SelectedNames, VoteTable, PanelInfo] = runConsensusSelection(TrainTbl, Response, ProblemType, Options)
%runConsensusSelection Rank a feature pool with a panel and cut via consensus.
%
%   [SelectedNames, VoteTable, PanelInfo] = runConsensusSelection(TrainTbl, ...
%       Response, ProblemType) ranks the engineered feature pool in TrainTbl with
%       a diverse ranker panel (scoreFeaturePanel), fuses the rankings with a
%       data-driven consensus voter, and cuts the fused score vector at its elbow.
%
%   Running several complementary selectors and fusing their verdicts by vote is
%   this skill's distinctive value -- it is deliberately NOT what gencfeatures /
%   genrfeatures do internally (they select with a single learner-tied criterion).
%
%   The single selection path is: rank -> consensus -> elbow. There is
%   deliberately no per-N wrapper search: the rankers disagree by design, so
%   there is no well-defined "optimal N" until consensus has merged them into one
%   score vector, and cutting that one vector is exactly the elbow.
%
%   VOTER CHOICE. By default ("auto") mean pairwise Spearman agreement across the
%   panel's rankings picks the fusion rule: high agreement (>= 0.7) -> Borda count
%   (positional, rewards consistent placement); lower agreement -> Reciprocal Rank
%   Fusion (robust when methods disagree, emphasizes each method's top picks).
%   Set VoterMethod to "borda"/"rrf"/"majority" to override this data-driven
%   choice. "majority" (binary top-K vote, order-blind) is an expert opt-in for
%   when you trust WHICH features each ranker picked but not the ORDER it picked
%   them in (e.g. tie-heavy significance filters) -- the agreement gate cannot
%   detect that, so it is never chosen automatically.
%
%   FEATURE COUNT. The number kept is the score elbow of the fused consensus
%   vector (computeNSelect): the point of maximum below-chord distance on the
%   sorted scores. A convex curve cuts at its knee; a linear or concave decline
%   has no knee and keeps the whole pool.
%
%   Inputs:
%     TrainTbl    - table of engineered TRAINING features + response column. The
%                   full mixed pool is ranked; numeric and categorical engineered
%                   features share one column universe (scoreFeaturePanel aligns
%                   every ranker to it), so the fused vote is well defined.
%     Response    - (1,1) string, response variable name in TrainTbl
%     ProblemType - (1,1) string, "classification" or "regression"
%     Options.ExcludeFeatures - (1,:) string names to drop before ranking (e.g.
%                   GenInfo.BinaryReliant WoE columns from a dummy binarization,
%                   which are meaningless once the multiclass response is restored)
%     Options.VoterMethod - (1,1) string fusion rule: "auto" (default, agreement
%                   picks Borda vs RRF), or an explicit "borda" / "rrf" /
%                   "majority" override
%     Options.TargetModel - (1,1) string declared model family, gating the ranker
%                   panel (see scoreFeaturePanel): "agnostic" (default, full five-
%                   ranker panel), or "linear"/"tree_ensemble"/"kernel_distance",
%                   each of which runs its own embedded probe plus mrmr + the
%                   univariate filter. Mirrors how gencfeatures ties its embedded
%                   selector to the target learner. The consensus vote is unchanged.
%
%   Outputs:
%     SelectedNames - (1,:) string of selected feature names
%     VoteTable     - table: Feature, Score, Rank, Selected (consensus order)
%     PanelInfo     - struct with fields:
%                       .Rankers       - (1,:) string ranker methods used
%                       .Skipped       - (1,:) string any rankers that were skipped
%                       .PanelMode      - (1,1) string "full" or "family:<name>",
%                                        which ranker panel the family gate selected
%                       .VoterMethod   - "borda" | "rrf" | "majority"
%                       .VoterSelectedBy - "auto" | "user" (how VoterMethod was set)
%                       .MeanAgreement - mean pairwise Spearman rho
%                       .NSelect       - number of features selected (the elbow)
%                       .PoolSize      - features ranked
%                       .Excluded      - names excluded before ranking
%                       .PredVars      - (1,p) string shared column universe, the
%                                        row order of RankMatrix
%                       .RankMatrix    - (p,M) double per-method ranks (row k =
%                                        PredVars(k), col m = Rankers(m); lower =
%                                        more important); feeds plotSelectionConsensus
%                       .Reasoning     - human-readable explanation

% Copyright 2026 The MathWorks, Inc.

    arguments
        TrainTbl table
        Response (1,1) string
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Options.ExcludeFeatures (1,:) string = string.empty(1,0)
        Options.VoterMethod (1,1) string ...
            {mustBeMember(Options.VoterMethod, ["auto","borda","rrf","majority"])} = "auto"
        Options.TargetModel (1,1) string {mustBeMember(Options.TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])} = "agnostic"
    end

    if ~ismember(Response, string(TrainTbl.Properties.VariableNames))
        error('runConsensusSelection:responseNotFound', ...
            'Response variable "%s" is not a column of the input table.', Response);
    end

    % --- Candidate universe: all engineered predictors, minus exclusions -------
    AllVars = string(TrainTbl.Properties.VariableNames);
    PredVars = setdiff(AllVars, Response, "stable");

    Excluded = intersect(PredVars, Options.ExcludeFeatures, "stable");
    PredVars = setdiff(PredVars, Options.ExcludeFeatures, "stable");

    if ~isempty(Excluded)
        fprintf('runConsensusSelection: excluding %d feature(s) before ranking (%s).\n', ...
            numel(Excluded), join(Excluded, ", "));
    end

    p = numel(PredVars);
    if p < 2
        error('runConsensusSelection:tooFewFeatures', ...
            'Need at least 2 candidate features to select; have %d.', p);
    end

    % --- Diverse ranker panel over the shared mixed-type universe --------------
    [Rankings, Rankers, PanelNotes] = scoreFeaturePanel(TrainTbl, Response, ProblemType, ...
        IncludeFeatures=PredVars, TargetModel=Options.TargetModel);

    % Per-method rank matrix for the consensus heatmap (plotSelectionConsensus).
    % Rankings{m} is a best-first permutation of 1:p over PredVars, so writing
    % 1:p into those positions gives each PredVars(k) its rank under method m.
    % Rows align to PredVars, columns to Rankers; surfaced on PanelInfo so the
    % plot needs no re-ranking.
    RankMatrix = zeros(p, numel(Rankings));
    for m = 1:numel(Rankings)
        RankMatrix(Rankings{m}, m) = 1:p;
    end

    % --- Voter: agreement picks Borda vs RRF, unless the caller overrides ------
    % MeanRho is always computed (the report narrates it) even when the caller
    % forces a method, so the two cases stay comparable.
    MeanRho = rankAgreement(Rankings);
    if Options.VoterMethod == "auto"
        VoterSelectedBy = "auto";
        if MeanRho >= 0.7
            VoterMethod = "borda";
        else
            VoterMethod = "rrf";
        end
    else
        VoterSelectedBy = "user";
        VoterMethod = Options.VoterMethod;
    end
    Voter = createConsensusVoter(VoterMethod);
    [RankedIdx, Scores] = Voter.rank(Rankings, p);

    % --- Cut the fused score vector at its elbow -------------------------------
    NSelect = computeNSelect(Scores, p);

    SelectedNames = PredVars(RankedIdx(1:NSelect));

    % --- Vote table (consensus order) ------------------------------------------
    ConsensusRank = zeros(p, 1);
    ConsensusRank(RankedIdx) = 1:p;
    SelectedMask = false(p, 1);
    SelectedMask(RankedIdx(1:NSelect)) = true;
    VoteTable = table(PredVars(:), Scores(:), ConsensusRank, SelectedMask, ...
        VariableNames={'Feature','Score','Rank','Selected'});
    VoteTable = sortrows(VoteTable, 'Rank', 'ascend');

    if VoterSelectedBy == "user"
        VoterClause = sprintf("voter=%s (user override; mean rho=%.2f)", VoterMethod, MeanRho);
    else
        VoterClause = sprintf("voter=%s (mean rho=%.2f)", VoterMethod, MeanRho);
    end
    if startsWith(PanelNotes.PanelMode, "family:")
        Family = extractAfter(PanelNotes.PanelMode, "family:");
        PanelClause = sprintf("%d rankers (%s, gated to the %s family probe + agnostic rankers)", ...
            numel(Rankers), join(Rankers, "+"), Family);
    else
        PanelClause = sprintf("%d rankers (%s)", numel(Rankers), join(Rankers, "+"));
    end
    CutClause = sprintf("elbow -> %d of %d", NSelect, p);
    Reasoning = sprintf("%s, %s; %s", PanelClause, VoterClause, CutClause);

    PanelInfo = struct( ...
        Rankers = Rankers, ...
        Skipped = PanelNotes.Skipped, ...
        PanelMode = PanelNotes.PanelMode, ...
        VoterMethod = VoterMethod, ...
        VoterSelectedBy = VoterSelectedBy, ...
        MeanAgreement = MeanRho, ...
        NSelect = NSelect, ...
        PoolSize = p, ...
        Excluded = Excluded, ...
        PredVars = PredVars, ...
        RankMatrix = RankMatrix, ...
        Reasoning = string(Reasoning));

    fprintf('Consensus selection: %d of %d features (voter=%s).\n', ...
        NSelect, p, VoterMethod);
end
