function printSummary(Results)
%printSummary Print a short terminal close-out of the feature-engineering run.
%
%   printSummary(Results) prints a few headline lines to the console over the
%   same plain Results struct the report generators consume. It is a SUMMARY,
%   not a copy of the report: what ran, how the pool was cut, whether the
%   engineered set paid off against the baseline, and where the full detail
%   lives. The written report (generateFeatureReport / generateFeatureReportPdf)
%   carries the per-dimension quality breakdown, CV, macro-F1, stability gloss,
%   and full file list -- this does not repeat them.
%
%   Every line guards on field presence, so a partial Results (baseline skipped,
%   files not yet recorded) prints what it has and omits the rest. It is a
%   pointer to the report, never a pass/fail gate.
%
%   Results fields read (all optional):
%     .DatasetName .Profile .GenInfo .PanelInfo .SelectedNames .Baseline
%     .Quality .KFold .SelStab .GenStab .OutputDir .Deliverables

% Copyright 2026 The MathWorks, Inc.

    arguments
        Results (1,1) struct
    end

    Name = getField(Results, "DatasetName", "dataset");
    fprintf('\n=== Feature Engineering Summary: %s ===\n', char(Name));

    printWhatRan(Results);
    printPoolToSelected(Results);
    printHeadlineResult(Results);
    printKFoldPerformance(Results);
    printModelFree(Results);
    printStability(Results);
    printWhereToLook(Results);

    fprintf('===============================================\n');
end


function printWhatRan(Results)
    P = getField(Results, "Profile", struct());
    if ~isfield(P, 'ProblemType')
        return;
    end
    Rows = "";
    if isfield(P, 'NumRows')
        Rows = sprintf(", %d rows", P.NumRows);
    end
    fprintf('  %s%s\n', char(P.ProblemType), char(Rows));
end


function printPoolToSelected(Results)
    Pool = poolSize(Results);
    NSel = selectedCount(Results);
    if isnan(Pool) && isnan(NSel)
        return;
    end
    if ~isnan(Pool) && ~isnan(NSel)
        fprintf('  Features:  %d candidates -> %d selected\n', Pool, NSel);
    elseif ~isnan(NSel)
        fprintf('  Features:  %d selected\n', NSel);
    end
end


function printHeadlineResult(Results)
    % Baseline (baselineComparison) is unconditional in a real run; the presence
    % guards only protect an early/partial Results assembled before it landed.
    if ~isfield(Results, 'Baseline') || ~isstruct(Results.Baseline)
        return;
    end
    B = Results.Baseline;
    if ~isfield(B, 'Original') || ~isfield(B, 'Engineered')
        return;
    end
    % Print one line per trained family, mirroring the k-fold panel below.
    % Whether engineering beats the originals is model-dependent, so a single
    % headline would misattribute the primary family's result to all of them;
    % each family shows its own engineered-vs-original score and its own secondary
    % metric. The primary (reported) family leads. Under a declared single-family
    % TargetModel the panel is one row. No win/lose verdict is tacked on -- the
    % report's per-family table carries the full picture.
    Panel = baselinePanel(B);
    fprintf('  Baseline (holdout):\n');
    for i = 1:numel(Panel)
        FP = Panel(i);
        Metric = char(getField(FP, "Metric", ""));
        fprintf('    %s: engineered %s = %s vs original %s\n', ...
            char(familyLabel(FP.Family)), Metric, fmtQ(FP.Engineered), fmtQ(FP.Original));
        Secondary = secondaryMetric(FP);
        if strlength(Secondary) > 0
            fprintf('               %s\n', char(Secondary));
        end
    end
end


function Panel = baselinePanel(B)
%baselinePanel The per-family holdout panel, primary family first.
%   Falls back to a one-family panel synthesized from the top-level fields when an
%   older Result carried no .Panel -- the top-level fields are the primary family's.
    if isfield(B, 'Panel') && ~isempty(B.Panel)
        Panel = B.Panel;
        Primary = string(getField(B, "Primary", "bag"));
        Fams = arrayfun(@(P) string(P.Family), Panel);
        Idx = find(Fams == Primary, 1);
        if ~isempty(Idx)
            Panel = Panel([Idx, setdiff(1:numel(Panel), Idx, 'stable')]);
        end
        return;
    end
    Panel = struct(Family = string(getField(B, "Primary", "bag")), ...
        Metric = getField(B, "Metric", ""), ...
        Engineered = B.Engineered, Original = B.Original, ...
        MacroF1 = getField(B, "MacroF1", struct()), ...
        Accuracy = getField(B, "Accuracy", struct()));
end


function printKFoldPerformance(Results)
%printKFoldPerformance One line for the full-pipeline k-fold performance read.
%   The baseline headline above is a single-holdout point estimate. When the
%   opt-in Mode 3 k-fold ran (Results.KFold.Performance), it carries the honest
%   end-to-end mean +/- std over folds -- the number worth paying for -- so give
%   it its own line right under the headline, parallel to how the stability line
%   surfaces the k-fold Nogueira index. Prints only when that read exists.
%
%   The primary metric (AUC or RMSE) leads; each companion metric assessKFold
%   aggregated across folds (classification: macro-F1, and accuracy when balanced)
%   follows on its own sub-line. Under agnostic every trained family (bag/linear/
%   kernel) gets its own block; a declared model prints a single block.
    if ~isfield(Results, 'KFold') || ~isstruct(Results.KFold) ...
            || ~isfield(Results.KFold, 'Performance') || ~isstruct(Results.KFold.Performance)
        return;
    end
    KF = Results.KFold;
    Perf = KF.Performance;
    if ~isfield(Perf, 'Engineered') || ~isstruct(Perf.Engineered) ...
            || ~isfinite(getField(Perf.Engineered, "Mean", NaN))
        return;
    end
    Metric = char(getField(KF, "MetricName", ""));
    K = getField(KF, "K", NaN);
    Folds = "";
    if ~isnan(K)
        Folds = sprintf(" (%d folds)", K);
    end
    fprintf('  K-fold performance%s:\n', char(Folds));
    Panel = kfoldPanel(Perf);
    for i = 1:numel(Panel)
        FP = Panel(i);
        fprintf('    %s: engineered %s %s vs original %s\n', ...
            char(familyLabel(FP.Family)), Metric, ...
            fmtMeanStd(FP.Engineered), fmtMeanStd(FP.Original));
        printKFoldSecondary(getField(FP, "Secondary", ...
            struct('Name', {}, 'Engineered', {}, 'Original', {})));
    end
end


function Panel = kfoldPanel(Perf)
%kfoldPanel The per-family panel, falling back to a one-family primary-only panel
%   when an older Result carried no .Panel.
    if isfield(Perf, 'Panel') && ~isempty(Perf.Panel)
        Panel = Perf.Panel;
        return;
    end
    Panel = struct(Family = "bag", Engineered = Perf.Engineered, ...
        Original = getField(Perf, "Original", struct()), ...
        Secondary = getField(Perf, "Secondary", ...
            struct('Name', {}, 'Engineered', {}, 'Original', {})));
end


function printKFoldSecondary(Secondary)
%printKFoldSecondary Sub-lines for each companion metric aggregated across folds.
    for i = 1:numel(Secondary)
        S = Secondary(i);
        if ~isfinite(getField(S.Engineered, "Mean", NaN))
            continue
        end
        fprintf('               %s: eng %s vs orig %s\n', ...
            char(S.Name), fmtMeanStd(S.Engineered), fmtMeanStd(S.Original));
    end
end


function printModelFree(Results)
%printModelFree One diagnostic line: relevance / redundancy / count, orig->eng.
%   Model-free means no model is fit -- it reads the feature set's own structure
%   (mutual information with the response, pairwise MI between features, size).
%   A one-line headline only; the report carries the per-dimension detail.
%   featureSetQuality is unconditional in a real run; the guard only protects an
%   early/partial Results assembled before it landed.
    if ~isfield(Results, 'Quality') || ~isstruct(Results.Quality)
        return;
    end
    Q = Results.Quality;
    Parts = string.empty(1, 0);
    if isfield(Q, 'Relevance') && isfield(Q.Relevance, 'MaxOriginal')
        Parts(end+1) = sprintf("relevance %s->%s", ...
            fmtQ(Q.Relevance.MaxOriginal), fmtQ(Q.Relevance.MaxEngineered));
    end
    if isfield(Q, 'Redundancy') && isfield(Q.Redundancy, 'MeanPairwiseMIOriginal')
        Parts(end+1) = sprintf("redundancy %s->%s", ...
            fmtQ(Q.Redundancy.MeanPairwiseMIOriginal), fmtQ(Q.Redundancy.MeanPairwiseMIEngineered));
    end
    if isfield(Q, 'Compactness') && isfield(Q.Compactness, 'NumFeaturesOriginal')
        Parts(end+1) = sprintf("%d->%d features", ...
            Q.Compactness.NumFeaturesOriginal, Q.Compactness.NumFeaturesEngineered);
    end
    if isempty(Parts)
        return;
    end
    fprintf('  Model-free:  %s\n', char(join(Parts, " | ")));

    % Under cross_validated, the recipe's engineered-side quality also has a
    % per-fold band (assessKFold) -- print it as a companion sub-line.
    if isfield(Results, 'KFold') && isstruct(Results.KFold) ...
            && isfield(Results.KFold, 'QualityStability')
        QS = Results.KFold.QualityStability;
        fprintf('               across folds: relevance %s | redundancy %s (eng)\n', ...
            fmtMS(QS.MaxRelevance), fmtMS(QS.MeanRedundancy));
    end
end


function Str = fmtMS(S)
%fmtMS Format a meanStd sub-struct as "mean +/- std".
    Str = sprintf('%.3f +/- %.3f', S.Mean, S.Std);
end


function printStability(Results)
%printStability One line per selection-stability read that was computed.
%   Two INDEPENDENT opt-in reads can exist: the fixed-pool read (Results.SelStab)
%   and the generation-variance read (Results.GenStab), each requested on its own.
%   The fixed-pool read is the base, so print it first; print the generation read
%   when it also ran. Name which resampling produced each number so it is not
%   mistaken for a single-split result. Neither requested => nothing prints.
    Shipped = string(getField(Results, "SelectedNames", string.empty(1, 0)));
    Nog = stabNogueira(Results, 'SelStab');
    if ~isnan(Nog)
        fprintf('  Stability:  Nogueira %s %s (fixed-pool resampling)\n', ...
            fmtQ(Nog), char(nogueiraGloss(Nog)));
        printFreqDigest(Results, 'SelStab', Shipped);
    end
    GenNog = stabNogueira(Results, 'GenStab');
    if ~isnan(GenNog)
        fprintf('  Stability:  Nogueira %s %s (generation, pool regenerated)\n', ...
            fmtQ(GenNog), char(nogueiraGloss(GenNog)));
        printFreqDigest(Results, 'GenStab', Shipped);
        printDriftDigest(Results, Shipped);
    end
end


function printDriftDigest(Results, Shipped)
%printDriftDigest One line per shipped feature that drifted out of the regenerated
%   pool -- the actionable slice of the generation read's Drift table. "Drift" is
%   binary pool membership: a feature not generated in every subsample was not always
%   available to re-select, so the "absent from N%" gap is worth surfacing alongside
%   the fragile picks. Prints nothing when no shipped feature drifted (the common,
%   healthy case).
    if ~isfield(Results, 'GenStab') || ~isstruct(Results.GenStab) ...
            || ~isfield(Results.GenStab, 'Drift') || ~istable(Results.GenStab.Drift) ...
            || isempty(Results.GenStab.Drift)
        return;
    end
    Drift = Results.GenStab.Drift;
    Shipped = string(Shipped);
    Feats = string(Drift.Feature);
    IsShipped = ismember(Feats, Shipped);
    if ~any(IsShipped)
        return;
    end
    Idx = find(IsShipped);
    Absent = 1 - double(Drift.PoolCoverage);
    Parts = arrayfun(@(i) sprintf('%s (absent from %.0f%%)', Feats(i), 100 * Absent(i)), ...
        Idx(:)', UniformOutput=false);
    fprintf('              shipped but drifted from pool: %s\n', ...
        char(joinNames(string(Parts))));
end


function printFreqDigest(Results, Field, Shipped)
%printFreqDigest The per-feature re-selection read as a short digest -- the terminal
%   counterpart to the report's frequency table, and it uses the SAME three tiers the
%   report does so the two don't disagree: core (>= the CoreThreshold, default 80%),
%   above the 50% floor but below core (kept, moderate support), and fragile (below
%   the floor -- the single most important thing to eyeball). The full per-feature
%   table lives in the report.
    Freq = stabFreqTable(Results, Field);
    Shipped = string(Shipped);
    if isempty(Freq) || isempty(Shipped)
        return;
    end
    Floor = 0.5;
    Core = coreThreshold(Results, Field);
    Feats = string(Freq.Feature);
    [IsShipped, Loc] = ismember(Shipped, Feats);
    ShippedFreq = nan(size(Shipped));
    ShippedFreq(IsShipped) = double(Freq.Frequency(Loc(IsShipped)));
    NCore = sum(ShippedFreq >= Core);
    MidBand = Shipped(ShippedFreq >= Floor & ShippedFreq(:)' < Core);
    Fragile = Shipped(ShippedFreq(:)' < Floor & ~isnan(ShippedFreq(:)'));
    fprintf('              %d of %d shipped features are core (re-selected in >= %.0f%% of resamples)\n', ...
        NCore, numel(Shipped), 100 * Core);
    if ~isempty(MidBand)
        fprintf('              above the %.0f%% floor but below core (moderate support): %s\n', ...
            100 * Floor, char(joinNames(MidBand)));
    end
    if ~isempty(Fragile)
        fprintf('              fragile (below the %.0f%% floor, rarely re-picked): %s\n', ...
            100 * Floor, char(joinNames(Fragile)));
    end
end


function T = coreThreshold(Results, Field)
%coreThreshold The read's own CoreThreshold (re-selection fraction at/above which a
%   feature is "core"), matching the report; falls back to 0.8 when the field is
%   absent (a Result predating it).
    T = 0.8;
    if isfield(Results, Field) && isstruct(Results.(Field)) ...
            && isfield(Results.(Field), 'CoreThreshold') ...
            && ~isempty(Results.(Field).CoreThreshold)
        T = Results.(Field).CoreThreshold;
    end
end


function Tbl = stabFreqTable(Results, Field)
%stabFreqTable The SelectionFrequency table from a stability read, or [] if absent.
    Tbl = [];
    if isfield(Results, Field) && isstruct(Results.(Field)) ...
            && isfield(Results.(Field), 'SelectionFrequency') ...
            && istable(Results.(Field).SelectionFrequency)
        Tbl = Results.(Field).SelectionFrequency;
    end
end


function Str = joinNames(Names)
%joinNames Comma-joined name list, truncated after a few so the line stays short.
    Names = string(Names);
    Max = 5;
    if numel(Names) > Max
        Str = join(Names(1:Max), ", ") + sprintf(", +%d more", numel(Names) - Max);
    else
        Str = join(Names, ", ");
    end
end


function Val = stabNogueira(Results, Field)
%stabNogueira The Nogueira index from a stability read struct, or NaN when absent.
    Val = NaN;
    if isfield(Results, Field) && isstruct(Results.(Field)) ...
            && isfield(Results.(Field), 'Nogueira')
        Val = Results.(Field).Nogueira;
    end
end


function Gloss = nogueiraGloss(Value)
%nogueiraGloss One-word band for a Nogueira stability index.
    if isnan(Value)
        Gloss = "";
    elseif Value >= 0.75
        Gloss = "(highly stable)";
    elseif Value >= 0.4
        Gloss = "(moderate)";
    else
        Gloss = "(unstable)";
    end
end


function printWhereToLook(Results)
    Files = string(getField(Results, "Deliverables", string.empty(1, 0)));
    Dir = string(getField(Results, "OutputDir", ""));
    if strlength(Dir) > 0
        fprintf('  Written:   %d files to %s\n', numel(Files), char(Dir));
    elseif ~isempty(Files)
        fprintf('  Written:   %d files (see feature_report)\n', numel(Files));
    end

    % Point at the two ways to get the run's numbers at full resolution -- the
    % report only previews the top features, so name the results .mat (every
    % table, unconditionally saved) and the live workspace struct that holds the
    % same thing this session. Print the .mat line only if it was actually saved.
    Res = Files(endsWith(Files, ".mat") & startsWith(Files, "fe_results_"));
    if ~isempty(Res)
        fprintf('  Full data: every table (vote, stability, quality) saved to %s\n', ...
            char(Res(1)));
    end
    fprintf(['             also live in the `Results` struct in your workspace ' ...
        'this session.\n']);
end


% ------------------------------------------------------------- small helpers

function Out = getField(S, Name, Default)
%getField Struct field with a default when absent (string name).
    if isfield(S, Name)
        Out = S.(Name);
    else
        Out = Default;
    end
end


function N = poolSize(Results)
    N = NaN;
    G = getField(Results, "GenInfo", struct());
    if isfield(G, 'PoolSize')
        N = G.PoolSize;
        return;
    end
    PI = getField(Results, "PanelInfo", struct());
    if isfield(PI, 'PoolSize')
        N = PI.PoolSize;
    end
end


function N = selectedCount(Results)
    N = NaN;
    PI = getField(Results, "PanelInfo", struct());
    if isfield(PI, 'NSelect')
        N = PI.NSelect;
        return;
    end
    if isfield(Results, 'SelectedNames')
        N = numel(string(Results.SelectedNames));
    end
end


function Str = secondaryMetric(B)
%secondaryMetric The companion score alongside the primary metric.
%   Classification: macro-F1 (class-balanced companion to AUC), or accuracy when
%   the panel logged it for a balanced problem. Regression's RMSE stands alone,
%   so this is empty there.
    Str = "";
    if isfield(B, 'MacroF1') && isfinite(getField(B.MacroF1, "Engineered", NaN))
        Str = sprintf("macro-F1: eng %s vs orig %s", ...
            fmtQ(B.MacroF1.Engineered), fmtQ(B.MacroF1.Original));
    elseif isfield(B, 'Accuracy') && isfinite(getField(B.Accuracy, "Engineered", NaN))
        Str = sprintf("accuracy: eng %s vs orig %s", ...
            fmtQ(B.Accuracy.Engineered), fmtQ(B.Accuracy.Original));
    end
end


function Label = familyLabel(Family)
%familyLabel Short human-readable name for a model family.
    switch string(Family)
        case "linear"
            Label = "linear";
        case "kernel"
            Label = "kernel";
        case "bag"
            Label = "random forest";
        otherwise
            Label = string(Family);
    end
end


function Str = fmtQ(X)
    if ~isnumeric(X) || ~isscalar(X) || isnan(X)
        Str = 'n/a';
    else
        Str = sprintf('%.3f', X);
    end
end


function Str = fmtMeanStd(MS)
%fmtMeanStd Format a meanStd struct (.Mean/.Std) as "mean +/- std", or n/a.
    if ~isstruct(MS) || ~isfield(MS, 'Mean') || ~isfinite(getField(MS, "Mean", NaN))
        Str = 'n/a';
        return;
    end
    Std = getField(MS, "Std", NaN);
    if isfinite(Std)
        Str = sprintf('%.3f +/- %.3f', MS.Mean, Std);
    else
        Str = sprintf('%.3f', MS.Mean);
    end
end
