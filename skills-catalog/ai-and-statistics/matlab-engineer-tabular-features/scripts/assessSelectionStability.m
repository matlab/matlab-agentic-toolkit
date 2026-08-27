function Result = assessSelectionStability(FullTbl, Response, ProblemType, Options)
%assessSelectionStability Fixed-pool selection stability via stratified subsampling.
%
%   Result = assessSelectionStability(FullTbl, Response, ProblemType) measures
%   how consistently the consensus selector picks the same features when the
%   ROWS IT IS GIVEN are resampled, holding the engineered pool FIXED. It draws
%   M stratified subsamples of size n*SubsampleFraction (default n/2) WITHOUT
%   replacement and re-runs only the selection step -- runConsensusSelection --
%   on each subsample, so it costs M selections and NO re-generation. Running
%   the full consensus panel M times is itself expensive; because the pool is
%   generated ONCE by the caller and never regenerated here, this is the LESS
%   expensive of the two stability reads -- assessGenerationStability additionally
%   refits the generator per subsample. Both are opt-in and off by default. Pass
%   it all working rows (WorkingIdx):
%   stability never scores a held slice, so there is no leakage in resampling
%   the whole working set, and it audits the all-working-data selector that
%   actually ships (deliver.md).
%
%   Rows are capped to Options.MaxRows FIRST via a stratified downsample that
%   preserves class proportions; all subsampling then operates on that capped
%   working table, keeping the M selections affordable on large inputs.
%
%   Because the pool never changes, the stability universe is the WHOLE pool:
%   every candidate feature is present in every subsample, so a 0 in the
%   selection matrix unambiguously means "rejected", never "absent". There is
%   therefore no intersection universe and no drift report (both of which exist
%   in assessGenerationStability only because its per-subsample pools differ).
%   This is the simpler read of the two.
%
%   SCOPE. This is a STABILITY read only, deliberately treating the pool as
%   given and asking "is the selector sensitive to row noise?". The pool is fit
%   ONCE before subsampling and held fixed, so this read isolates selector
%   variance alone; it does NOT capture how much the pool itself would move if
%   regenerated -- that is assessGenerationStability's job (pool refit per
%   subsample). Report this as selection stability, not as a performance
%   estimate.
%
%   DIAGNOSTIC ONLY. It grades the selection decision runConsensusSelection
%   makes; it never revises the delivered set.
%
%   Inputs:
%     FullTbl     - table of ENGINEERED predictors + response over the rows to
%                   resample -- pass all working rows (WorkingIdx), the same rows
%                   the delivered set is refit on. This is the fixed pool
%                   generateFeatures produced, sliced to those rows.
%     Response    - (1,1) string, response variable name in FullTbl
%     ProblemType - (1,1) string, "classification" or "regression"
%     Options.ExcludeFeatures - (1,:) string names dropped before ranking (e.g.
%                   GenInfo.BinaryReliant), passed straight to runConsensusSelection
%                   so the universe matches the delivered run's
%     Options.TargetModel   - (1,1) string model family, passed to
%                   runConsensusSelection so each subsample gates the ranker panel
%                   exactly as the delivered selection did (default "agnostic").
%                   Keeping this aligned matters: if the shipped selection ran a
%                   3-ranker family-gated panel, the stability read must too, or it
%                   would grade a different selector than the one delivered.
%     Options.CoreThreshold - (1,1) double in [0,1]; a feature is in the reported
%                   consensus core if selected in >= this fraction of subsamples
%                   (default 0.8; diagnostic label only)
%     Options.M             - (1,1) positive integer number of subsamples to draw
%                   (default 30)
%     Options.SubsampleFraction - (1,1) positive double < 1, fraction of rows in
%                   each subsample (default 0.5, i.e. n/2)
%     Options.MaxRows       - (1,1) positive integer row cap applied before
%                   subsampling (default 3000)
%
%   Output:
%     Result - struct with fields:
%       .M                   - (1,1) number of subsamples
%       .PoolSize            - (1,1) number of candidate features (the universe)
%       .Universe            - (1,:) string, every candidate feature (fixed pool)
%       .Nogueira            - (1,1) chance-corrected stability index (NaN if not
%                              computable)
%       .SelectionFrequency  - table(Feature, Frequency) over the pool, desc
%       .CoreFeatures        - (1,:) string, freq >= CoreThreshold
%       .MeanSubsetSize      - (1,1) mean number selected per subsample
%       .NSelectPerResample  - (1,M) double, features selected in each subsample
%                              (feeds the cut-point spread in plotSelectionStability)
%       .Scheme              - (1,1) string "subsample"
%       .SubsampleFraction   - (1,1) double, the fraction each subsample drew
%       .CoreThreshold       - (1,1) double, the consensus-core cutoff used
%       .MaxRows             - (1,1) double, the row cap applied before subsampling
%       .Reasoning           - human-readable summary (names every knob)
%
%   References:
%     Nogueira S, Sechidis K, Brown G. "On the Stability of Feature Selection
%     Algorithms." Journal of Machine Learning Research, 18(174):1-54, 2018.

% Copyright 2026 The MathWorks, Inc.

    arguments
        FullTbl table
        Response (1,1) string
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Options.ExcludeFeatures (1,:) string = string.empty(1,0)
        Options.TargetModel (1,1) string {mustBeMember(Options.TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])} = "agnostic"
        Options.CoreThreshold (1,1) double {mustBeGreaterThanOrEqual(Options.CoreThreshold, 0), ...
            mustBeLessThanOrEqual(Options.CoreThreshold, 1)} = 0.8
        Options.M (1,1) double {mustBePositive, mustBeInteger} = 30
        Options.SubsampleFraction (1,1) double {mustBePositive} = 0.5
        Options.MaxRows (1,1) double {mustBePositive, mustBeInteger} = 3000
    end

    AllVars = string(FullTbl.Properties.VariableNames);
    if ~ismember(Response, AllVars)
        error('assessSelectionStability:responseNotFound', ...
            'Response variable "%s" is not a column of the input table.', Response);
    end
    if Options.M < 2
        error('assessSelectionStability:tooFewResamples', ...
            'Need at least 2 subsamples to assess stability; got M=%d.', Options.M);
    end

    % The stability universe is the whole pool minus the same exclusions the
    % delivered selection used, so the two runs rank the identical candidate set.
    Universe = setdiff(AllVars, Response, "stable");
    Universe = setdiff(Universe, Options.ExcludeFeatures, "stable");
    p = numel(Universe);
    if p < 2
        error('assessSelectionStability:tooFewFeatures', ...
            'Need at least 2 candidate features to assess; have %d.', p);
    end

    % Cap rows first (stratified, class-proportion preserving), then subsample.
    KeepIdx = stratifiedDownsampleRows(FullTbl.(Response), Options.MaxRows);
    WorkTbl = FullTbl(KeepIdx, :);
    Sets = stratifiedSubsampleIndices(WorkTbl.(Response), Options.M, Options.SubsampleFraction);

    fprintf(['assessSelectionStability: re-selecting on %d stratified subsamples ' ...
        '(%.0f%% of rows) of a FIXED pool -- no re-generation, but %d full ' ...
        'consensus selections.\n'], Options.M, 100 * Options.SubsampleFraction, Options.M);

    % --- Per-subsample selection over the fixed pool ---------------------------
    Z = false(Options.M, p);
    NSelectPerResample = zeros(1, Options.M);
    for m = 1:Options.M
        SubsampleTbl = WorkTbl(Sets{m}, :);

        SelectedNames = runConsensusSelection(SubsampleTbl, Response, ProblemType, ...
            ExcludeFeatures = Options.ExcludeFeatures, TargetModel = Options.TargetModel);

        Z(m, :) = ismember(Universe, SelectedNames);
        NSelectPerResample(m) = numel(SelectedNames);
        fprintf('  Subsample %d/%d: selected %d of %d.\n', ...
            m, Options.M, NSelectPerResample(m), p);
    end

    % --- Nogueira stability + consensus core over the whole pool ---------------
    [Stability, StabInfo] = nogueiraStability(Z);
    Freq = StabInfo.SelectionFrequency(:);

    [FreqSorted, Ord] = sort(Freq, "descend");
    FreqTable = table(Universe(Ord)', FreqSorted, ...
        VariableNames = {'Feature', 'Frequency'});
    CoreFeatures = Universe(Freq >= Options.CoreThreshold);

    Result = struct();
    Result.M = Options.M;
    Result.PoolSize = p;
    Result.Universe = Universe;
    Result.Nogueira = Stability;
    Result.SelectionFrequency = FreqTable;
    Result.CoreFeatures = CoreFeatures;
    Result.MeanSubsetSize = StabInfo.MeanSubsetSize;
    Result.NSelectPerResample = NSelectPerResample;
    Result.Scheme = "subsample";
    Result.SubsampleFraction = Options.SubsampleFraction;
    Result.CoreThreshold = Options.CoreThreshold;
    Result.MaxRows = Options.MaxRows;
    Result.Reasoning = buildReasoning(Result);
    fprintf('%s\n', Result.Reasoning);
end


function Reasoning = buildReasoning(Result)
%buildReasoning One-line audit summary of the fixed-pool stability read.
    Fmt = "M=%d subsamples (%.0f%% of rows, stratified, no replacement) over a " + ...
        "fixed pool of %d features: Nogueira=%.3f, %d core feature(s) (selected " + ...
        "in >=%.0f%% of subsamples), mean subset size %.1f (range %d-%d).";
    Reasoning = string(sprintf(Fmt, ...
        Result.M, 100 * Result.SubsampleFraction, Result.PoolSize, ...
        Result.Nogueira, numel(Result.CoreFeatures), ...
        100 * Result.CoreThreshold, Result.MeanSubsetSize, ...
        min(Result.NSelectPerResample), max(Result.NSelectPerResample)));
end
