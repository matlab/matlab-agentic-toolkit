function Result = assessGenerationStability(RawTrainTbl, Response, ProblemType, Options)
%assessGenerationStability Generation-variance read of selection stability.
%
%   Result = assessGenerationStability(RawTrainTbl, Response, ProblemType)
%   measures how consistently the consensus selector picks features when the
%   feature POOL is REGENERATED from scratch on every subsample. It draws M
%   stratified subsamples of the training rows, re-runs the WHOLE generate ->
%   select recipe on each, and compares the selection decisions over a shared
%   name universe with the Nogueira chance-corrected stability index. It does NO
%   performance scoring -- stability only.
%
%   COST. This runs the generator M times, so it costs roughly M times a single
%   generation and is the EXPENSIVE, opt-in "full-pipeline generation stability"
%   read. It is the companion to assessSelectionStability, which reselects over a
%   pool generated ONCE and held fixed; that read isolates selector variance
%   alone. This function uses the SAME stratified-subsampling scheme (same M,
%   same SubsampleFraction) as assessSelectionStability, so the two Nogueira
%   indices are directly comparable: the GAP between them (fixed-pool minus
%   regenerated-pool) is the generation-variance contribution to instability.
%
%   Domain paths need a Producer that re-runs its feature EXTRACTION per
%   subsample for this read to mean anything; a producer that returns a
%   pre-computed pool unchanged makes this read N/A (it collapses to the
%   fixed-pool case).
%
%   This is DIAGNOSTIC ONLY. It grades the trustworthiness of the selection made
%   once on the full training split by runConsensusSelection; it never revises
%   the delivered feature set.
%
%   Inputs:
%     RawTrainTbl - table of RAW predictors + response, TRAINING rows only (the
%                   final test set is held out upstream and never seen here)
%     Response    - (1,1) string, response variable name in RawTrainTbl
%     ProblemType - (1,1) string, "classification" or "regression"
%     Options.TargetModel  - (1,1) string model family, passed to the producer
%                            (default "agnostic")
%     Options.CoreThreshold- (1,1) double in (0,1); a feature is in the reported
%                            consensus core if selected in >= this fraction of
%                            subsamples (default 0.8; diagnostic label only)
%     Options.M            - (1,1) positive integer, number of subsamples
%                            (default 30; must be >= 2 to compute stability)
%     Options.SubsampleFraction - (1,1) positive double < 1, fraction of rows per
%                            subsample without replacement (default 0.5)
%     Options.MaxRows      - (1,1) positive integer, row cap applied class-
%                            proportionally before subsampling (default 3000)
%     Options.Producer     - (1,1) function_handle, the PLUGGABLE generator (see
%                            below). Default is the SMLT gencfeatures producer, so
%                            the SMLT path is unchanged; a domain path injects a
%                            producer that re-runs its extraction per subsample.
%
%   THE PLUGGABLE PRODUCER. Generation is injected so this one loop serves both
%   the SMLT path and a domain path. The producer contract matches assessKFold's:
%     [EngTrain, Apply, ExcludeFeatures] = Producer(SubsampleRaw, Response, ...
%                                                   ProblemType, TargetModel)
%   where EngTrain is the engineered TRAINING table (predictors + response), Apply
%   is the fitted recipe (unused here -- no held-out scoring), and ExcludeFeatures
%   are names to drop before ranking (e.g. GenInfo.BinaryReliant; string.empty for
%   a domain pool). Because the pool is regenerated per subsample and therefore
%   differs subsample to subsample, the intersection-universe + drift machinery
%   handles a wobbling pool with no special-casing.
%
%   Output:
%     Result - struct with fields:
%       .M                  - (1,1) number of subsamples
%       .Universe           - (1,:) string intersection universe U (features
%                             present in EVERY subsample's pool)
%       .Nogueira           - (1,1) stability index (NaN if not computable)
%       .SelectionFrequency - table(Feature, Frequency) over U, descending
%       .CoreFeatures       - (1,:) string, freq >= CoreThreshold
%       .MeanSubsetSize     - (1,1) mean selected-per-subsample within U
%       .Drift              - table(Feature, PoolCoverage, SelFreqWhenPresent)
%       .NSelectPerResample - (1,M) double, features selected each subsample
%       .Scheme             - (1,1) string, "subsample"
%       .SubsampleFraction  - (1,1) double, the fraction used
%       .CoreThreshold      - (1,1) double, the consensus-core cutoff used
%       .MaxRows            - (1,1) double, the row cap applied before subsampling
%       .Reasoning          - human-readable summary (names every knob)
%
%   References:
%     Nogueira S, Sechidis K, Brown G. "On the Stability of Feature Selection
%     Algorithms." Journal of Machine Learning Research, 18(174):1-54, 2018.

% Copyright 2026 The MathWorks, Inc.

    arguments
        RawTrainTbl table
        Response (1,1) string
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Options.TargetModel (1,1) string {mustBeMember(Options.TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])} = "agnostic"
        Options.CoreThreshold (1,1) double {mustBeGreaterThanOrEqual(Options.CoreThreshold, 0), ...
            mustBeLessThanOrEqual(Options.CoreThreshold, 1)} = 0.8
        Options.M (1,1) double {mustBePositive, mustBeInteger} = 30
        Options.SubsampleFraction (1,1) double {mustBePositive} = 0.5
        Options.MaxRows (1,1) double {mustBePositive, mustBeInteger} = 3000
        Options.Producer (1,1) function_handle = @smltProducer
    end

    AllVars = string(RawTrainTbl.Properties.VariableNames);
    if ~ismember(Response, AllVars)
        error('assessGenerationStability:responseNotFound', ...
            'Response variable "%s" is not a column of the input table.', Response);
    end

    M = Options.M;
    if M < 2
        error('assessGenerationStability:tooFewResamples', ...
            'Options.M must be at least 2 to compute a stability index; got %d.', M);
    end

    % Cap rows class-proportionally before subsampling, so a huge training block
    % does not make M full regenerations intractable.
    KeepIdx = stratifiedDownsampleRows(RawTrainTbl.(Response), Options.MaxRows);
    WorkRaw = RawTrainTbl(KeepIdx, :);

    % Same stratified-subsampling scheme as assessSelectionStability so the two
    % Nogueira indices are comparable. Caller owns rng.
    Sets = stratifiedSubsampleIndices(WorkRaw.(Response), M, Options.SubsampleFraction);

    fprintf(['assessGenerationStability: re-running generate -> select on %d ' ...
        'subsamples. The producer refits per subsample, so expect ~%dx a single ' ...
        'generation''s cost.\n'], M, M);

    % --- Per-subsample loop ----------------------------------------------------
    SelectedNames = cell(M, 1);
    PoolNames = cell(M, 1);

    for m = 1:M
        SubsampleRaw = WorkRaw(Sets{m}, :);

        % Regenerate the pool from scratch on this subsample (leakage-safe) via the
        % pluggable producer; Apply is unused here (no held-out scoring).
        [EngTrain, ~, ExcludeFeatures] = Options.Producer(SubsampleRaw, Response, ...
            ProblemType, Options.TargetModel);
        PoolNames{m} = setdiff(string(EngTrain.Properties.VariableNames), Response, "stable");

        % Select on this subsample's engineered pool. Omit TargetModel to match
        % the delivered per-fold selection call.
        SelectedNames{m} = runConsensusSelection(EngTrain, Response, ProblemType, ...
            ExcludeFeatures = ExcludeFeatures);

        fprintf('  Subsample %d/%d: pool=%d, selected=%d\n', ...
            m, M, numel(PoolNames{m}), numel(SelectedNames{m}));
    end

    % --- Selection stability over the intersection universe --------------------
    Result = selectionStability(SelectedNames, PoolNames, M, Options.CoreThreshold);
    Result.M = M;
    Result.NSelectPerResample = cellfun(@numel, SelectedNames(:)');
    Result.Scheme = "subsample";
    Result.SubsampleFraction = Options.SubsampleFraction;
    Result.CoreThreshold = Options.CoreThreshold;
    Result.MaxRows = Options.MaxRows;
    Result.Reasoning = buildReasoning(Result);
    fprintf('%s\n', Result.Reasoning);
end


function [EngTrain, Apply, ExcludeFeatures] = smltProducer(SubsampleRaw, Response, ProblemType, TargetModel)
%smltProducer Default producer: gencfeatures/genrfeatures via generateFeatures.
%   Fits the SMLT FeatureTransformer on the subsample's rows and returns its
%   transform method as the Apply handle. Apply is unused by this read (no
%   held-out scoring); it is returned only to satisfy the shared producer
%   contract. ExcludeFeatures forwards the binary-reliant WoE columns
%   generateFeatures flags, matching the delivered selection run.
    [EngTrain, Transformer, GenInfo] = generateFeatures(SubsampleRaw, Response, ...
        ProblemType, TargetModel = TargetModel);
    Apply = @(RawTbl) transform(Transformer, RawTbl);
    ExcludeFeatures = GenInfo.BinaryReliant;
end


function Sel = selectionStability(SelectedPerSubsample, PoolPerSubsample, M, CoreThreshold)
%selectionStability Nogueira index + consensus core over the intersection pool.
    Universe = PoolPerSubsample{1};
    UnionNames = PoolPerSubsample{1};
    for m = 2:M
        Universe = intersect(Universe, PoolPerSubsample{m}, "stable");
        UnionNames = union(UnionNames, PoolPerSubsample{m}, "stable");
    end

    p = numel(Universe);
    if p >= 1
        Z = false(M, p);
        for m = 1:M
            Z(m, :) = ismember(Universe, SelectedPerSubsample{m});
        end
    end

    if p >= 1 && M >= 2
        [Stability, Info] = nogueiraStability(Z);
        Freq = Info.SelectionFrequency(:);
        MeanSubset = Info.MeanSubsetSize;
    else
        Stability = NaN;
        Freq = zeros(p, 1);
        MeanSubset = NaN;
    end

    [FreqSorted, Ord] = sort(Freq, "descend");
    FreqTable = table(Universe(Ord)', FreqSorted, ...
        VariableNames = {'Feature', 'Frequency'});
    CoreFeatures = Universe(Freq >= CoreThreshold);

    % Drift: names that appear in some but not all pools, with pool coverage and
    % how often they were selected among the subsamples where they were available.
    Drifted = setdiff(UnionNames, Universe, "stable");
    Coverage = zeros(numel(Drifted), 1);
    SelWhenPresent = zeros(numel(Drifted), 1);
    for j = 1:numel(Drifted)
        InPool = false(M, 1);
        Selected = false(M, 1);
        for m = 1:M
            InPool(m) = ismember(Drifted(j), PoolPerSubsample{m});
            Selected(m) = ismember(Drifted(j), SelectedPerSubsample{m});
        end
        Coverage(j) = mean(InPool);
        SelWhenPresent(j) = sum(Selected) / max(sum(InPool), 1);
    end
    DriftTable = table(Drifted(:), Coverage, SelWhenPresent, ...
        VariableNames = {'Feature', 'PoolCoverage', 'SelFreqWhenPresent'});
    DriftTable = sortrows(DriftTable, 'PoolCoverage', 'descend');

    Sel = struct( ...
        Universe = Universe, ...
        Nogueira = Stability, ...
        SelectionFrequency = FreqTable, ...
        CoreFeatures = CoreFeatures, ...
        MeanSubsetSize = MeanSubset, ...
        Drift = DriftTable);
end


function Reasoning = buildReasoning(Result)
%buildReasoning One-line audit summary of the generation-variance read.
    nDrift = height(Result.Drift);
    Fmt = "M=%d subsamples (%.0f%% of rows, stratified, no replacement), pool " + ...
        "regenerated each: Nogueira=%.3f over %d shared features (%d core at " + ...
        ">=%.0f%%, %d drifted).";
    Reasoning = string(sprintf(Fmt, ...
        Result.M, 100 * Result.SubsampleFraction, Result.Nogueira, ...
        numel(Result.Universe), numel(Result.CoreFeatures), ...
        100 * Result.CoreThreshold, nDrift));
end
