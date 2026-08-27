function ReportPath = generateFeatureReport(Results, OutputDir, Options)
%generateFeatureReport Markdown report over the lean feature-engineering run.
%
%   ReportPath = generateFeatureReport(Results, OutputDir) writes a self-
%   contained Markdown report summarizing one generate -> select -> assess ->
%   deliver run to <OutputDir>/feature_report.md and returns its path. The
%   report is always produced (no toolbox gating); the PDF companion
%   (generateFeatureReportPdf) is what depends on Report Generator.
%
%   Results is a plain struct assembled by the orchestrator from the actual
%   phase outputs -- every sub-struct is passed through verbatim, so field
%   names here match the producing function exactly:
%     .DatasetName   (1,1) string  - dataset label for the title
%     .ResponseVar   (1,1) string  - response column name
%     .Profile       struct         - profileForSplit output (problem type,
%                                     rows, ClassBalance)
%     .ReserveInfo   struct         - OPTIONAL; reserveHoldoutForUser output. When
%                                     .Reserved is true the Overview reports the
%                                     untouched slice set aside for the user
%     .Split         struct         - splitStrategy output (TrainIdx/TestIdx,
%                                     .Strategy)
%     .Strategy      (1,1) string  - OPTIONAL; "holdout" | "cross_validated". When
%                                     absent it is inferred from Split.Strategy, or
%                                     from which performance read is present
%     .GenInfo       struct         - generateFeatures output (PoolSize,
%                                     TargetLearner, Standardization, ...)
%     .Transformer   FeatureTransformer - the generator's transformer; its
%                                     describe() table supplies the selected
%                                     features' human-readable definitions
%     .SelectedNames (1,:) string  - the delivered feature set
%     .VoteTable     table          - runConsensusSelection vote table
%                                     (Feature, Score, Rank, Selected)
%     .PanelInfo     struct         - runConsensusSelection panel diagnostics
%     .Quality       struct         - featureSetQuality output (model-free, always)
%     .SelStab       struct         - assessSelectionStability output (fixed-pool
%                                     selection stability, chapter 7a; OPTIONAL —
%                                     opt-in, absent when not requested or the pool
%                                     was too small)
%     .GenStab       struct         - assessGenerationStability output (generation
%                                     stability, pool regenerated per subsample,
%                                     chapter 7b; OPTIONAL — a separate opt-in read)
%     .StabilitySkipped logical      - OPTIONAL; true when no stability read was
%                                     requested, so the chapter says "not requested"
%                                     rather than "not recorded"
%   Exactly ONE performance read is present, chosen by the evaluation strategy:
%     .Baseline      struct         - baselineComparison output (holdout: the model
%                                     panel as a point estimate, chapter 5)
%     .KFold         struct         - assessKFold output (cross_validated: the
%                                     performance mean/std headline in chapter 5)
%     .Deliverables  (1,:) string  - emitted file names (OPTIONAL)
%
%   Options.FileName     (1,1) string  = "feature_report.md"
%   Options.EmbedFigures (1,1) logical = true   include figures if the PNGs
%                                               exist on disk in OutputDir

% Copyright 2026 The MathWorks, Inc.

    arguments
        Results (1,1) struct
        OutputDir (1,1) string
        Options.FileName (1,1) string = "feature_report.md"
        Options.EmbedFigures (1,1) logical = true
    end

    if ~isfolder(OutputDir)
        mkdir(OutputDir);
    end
    ReportPath = fullfile(OutputDir, Options.FileName);

    Fid = fopen(ReportPath, 'w');
    if Fid < 0
        error('generateFeatureReport:cannotOpen', ...
            'Could not open "%s" for writing.', ReportPath);
    end
    Closer = onCleanup(@() fclose(Fid));

    % Figures live in their owning sections (consensus in Consensus Selection,
    % baseline in Model-Specific Baseline, stability in Selector Stability), so a
    % section and its supporting figure read together. EmbedDir is the folder to
    % pull the fig_*.svg from, or "" to suppress embedding.
    EmbedDir = "";
    if Options.EmbedFigures
        EmbedDir = OutputDir;
    end

    writeHeader(Fid, Results);
    writeOverview(Fid, Results);
    writeGeneration(Fid, Results);
    writeSelection(Fid, Results, EmbedDir);
    writeSelectedDescriptions(Fid, Results);
    writeBaseline(Fid, Results, EmbedDir);
    writeQuality(Fid, Results);
    writeSelectorStability(Fid, Results, EmbedDir);
    writeDeliverables(Fid, Results);
    writeAppendix(Fid, Results);

    fprintf('Wrote Markdown report to %s\n', ReportPath);
end


% ------------------------------------------------------------------ chapters

function writeHeader(Fid, Results)
    Name = getField(Results, "DatasetName", "dataset");
    w(Fid, '# Feature Engineering Report: %s', char(Name));
    w(Fid, '');
    w(Fid, ['Generated by the `matlab-engineer-tabular-features` skill ' ...
        '(generate -> consensus select -> assess -> deliver).']);
    w(Fid, '');
end


function writeOverview(Fid, Results)
    w(Fid, '## 1. Overview');
    w(Fid, '');
    P = getField(Results, "Profile", struct());
    Rows = {};
    Rows(end+1, :) = {'Response variable', char(getField(Results, "ResponseVar", "?"))};
    if isfield(P, 'ProblemType')
        Rows(end+1, :) = {'Problem type', char(P.ProblemType)};
    end
    if isfield(P, 'NumRows')
        Rows(end+1, :) = {'Rows', formattedNumber(P.NumRows)};
    end
    if isfield(Results, 'Baseline') && isfield(Results.Baseline, 'TargetModel')
        Rows(end+1, :) = {'Planned model family', char(Results.Baseline.TargetModel)};
    end
    % Evaluation strategy + split sizes.
    S = getField(Results, "Split", struct());
    Strategy = resolveStrategy(Results);
    Rows(end+1, :) = {'Evaluation strategy', char(Strategy)};
    if isfield(S, 'TrainIdx')
        Label = 'Working rows (generation/selection)';
        if Strategy == "holdout"
            Label = 'Training rows';
        end
        Rows(end+1, :) = {Label, formattedNumber(numel(S.TrainIdx))};
    end
    if isfield(S, 'TestIdx') && Strategy == "holdout"
        Rows(end+1, :) = {'Held-out test rows (point estimate)', formattedNumber(numel(S.TestIdx))};
    end
    mdTable(Fid, {'Property', 'Value'}, Rows);
    w(Fid, '');

    % Level-0 carve: rows set aside untouched for the user's own testing.
    R = getField(Results, "ReserveInfo", struct());
    if isfield(R, 'Reserved') && R.Reserved
        w(Fid, ['**Reserved for your own testing:** %s rows (%.0f%%, %s) were set ' ...
            'aside **untouched** before the pipeline ran — never seen by generation, ' ...
            'selection, assessment, or the final refit. Everything below is on the ' ...
            'remaining %s working rows.'], formattedNumber(R.NumHeldOut), ...
            100 * R.Fraction, char(R.Method), formattedNumber(R.NumWorking));
        w(Fid, '');
    elseif isfield(R, 'Reserved')
        w(Fid, ['**Reserved for your own testing:** none — you supplied a separate ' ...
            'test set, so all %s rows are working data.'], formattedNumber(R.NumWorking));
        w(Fid, '');
    end

    writeDataUsage(Fid, Results, Strategy);

    % Class balance, when classification.
    if isfield(P, 'ClassBalance') && isstruct(P.ClassBalance) ...
            && isfield(P.ClassBalance, 'NumClasses') && ~isnan(P.ClassBalance.NumClasses)
        CB = P.ClassBalance;
        w(Fid, '**Class balance:** %d classes; minority-class count %s%s.', ...
            CB.NumClasses, formattedNumber(CB.MinorityCount), imbalanceSuffix(CB));
        w(Fid, '');
        w(Fid, '%s', char(imbalanceRecommendation(CB)));
    end
end


function writeDataUsage(Fid, Results, Strategy)
%writeDataUsage One compact table stating which rows each section uses, so the
%   graded-vs-shipped distinction is on the page. Strategy-aware: the performance
%   and stability rows differ between holdout and cross_validated. Mirrors the
%   worked example in the technical audit's data-flow note.
    StabSkipped = isfield(Results, 'StabilitySkipped') && Results.StabilitySkipped;
    if Strategy == "holdout"
        PerfRow = {'Performance (§5)', 'fit on the training rows, scored on the held-out test rows (one point estimate)'};
    else
        PerfRow = {'Performance (§5)', 'k folds of the working rows: each fold regenerates + reselects on the other folds, scores the held fold (mean ± std)'};
    end
    Rows = {
        'Graded generate + select', 'a training subset (holdout: the train block; cross-validated: each fold''s other folds) — measured, then discarded';
        'Delivered (shipped) features', '**refit on all working rows** — this is what the inference recipe reproduces';
        PerfRow{:};
        'Model-free quality (§6)', 'all working rows'};
    if ~StabSkipped
        Rows(end+1, :) = {'Selection stability (§7)', 'resamples **all working rows** on the fixed pool (never scores a held slice)'};
    end
    Rows(end+1, :) = {'Reserved slice', 'untouched — never used by any section above'};
    w(Fid, '**Which rows each section uses**');
    w(Fid, '');
    mdTable(Fid, {'Section', 'Rows used'}, Rows);
    w(Fid, '');
    w(Fid, ['_Generation and selection run twice: a **graded** fit on a training ' ...
        'subset (whose held rows produce the performance number above), then a ' ...
        '**shipped** refit on all working rows. The reported performance therefore ' ...
        'grades a recipe trained on less data than the one delivered — it is ' ...
        'conservative._']);
    w(Fid, '');
end


function Str = imbalanceRecommendation(CB)
%imbalanceRecommendation One line naming the ratio and the metric to trust.
%   Reports the number and recommends; it does not gate anything. The 1.5:1
%   line is where a raw hit-rate starts to flatter a majority-class predictor.
    if ~isfield(CB, 'ImbalanceRatio') || isnan(CB.ImbalanceRatio)
        Str = "";
        return;
    end
    if CB.ImbalanceRatio > 1.5
        Str = sprintf(['_The data is imbalanced (ratio %.1f:1). We recommend reading ' ...
            'AUC and macro-F1 rather than raw accuracy, which is favored by the ' ...
            'classes other than the minority class at this balance._\n'], CB.ImbalanceRatio);
    else
        Str = sprintf(['_The data is roughly balanced (ratio %.1f:1), so accuracy is a ' ...
            'trustworthy read alongside AUC and macro-F1._\n'], CB.ImbalanceRatio);
    end
end


function Strategy = resolveStrategy(Results)
%resolveStrategy The evaluation strategy in force. Prefers the explicit field;
%   otherwise infers from which performance read is present (KFold => cross-
%   validated, else holdout), so a pre-Strategy Results struct still reads right.
    if isfield(Results, 'Strategy') && strlength(string(Results.Strategy)) > 0
        Strategy = string(Results.Strategy);
        return;
    end
    S = getField(Results, "Split", struct());
    if isfield(S, 'Strategy') && strlength(string(S.Strategy)) > 0
        Strategy = string(S.Strategy);
        return;
    end
    if isfield(Results, 'KFold') && isstruct(Results.KFold) ...
            && ~(isfield(Results, 'Baseline') && isfield(Results.Baseline, 'Panel'))
        Strategy = "cross_validated";
    else
        Strategy = "holdout";
    end
end


function writeGeneration(Fid, Results)
    w(Fid, '## 2. Generation');
    w(Fid, '');
    G = getField(Results, "GenInfo", struct());
    if ~isfield(G, 'PoolSize')
        w(Fid, '_No generation information available._');
        w(Fid, '');
        return;
    end

    % A domain-routed pool has no SMLT TargetLearner/Standardization -- those are
    % generator concepts. Detect the domain path and describe it on its own terms.
    Recipe = getRecipe(Results);
    IsDomain = isstruct(Recipe) && isfield(Recipe, 'Kind') && Recipe.Kind == "domain";

    if IsDomain
        Provider = "a domain extractor";
        if isfield(Recipe, 'Provider') && strlength(string(Recipe.Provider)) > 0
            Provider = string(Recipe.Provider);
        end
        w(Fid, ['Candidate features were produced by %s (a purpose-built domain ' ...
            'extractor), not the generic SMLT generator; the final set is then ' ...
            'chosen by the consensus selection step.'], char(Provider));
        w(Fid, '');
        Rows = {
            'Candidate pool size', formattedNumber(G.PoolSize);
            'Target learner', char(targetLearnerLabel(Results));
            'Standardization', sprintf('N/A — %s controls this', char(Provider))};
        mdTable(Fid, {'Property', 'Value'}, Rows);
        w(Fid, '');
    else
        w(Fid, ['Candidate features were generated with SMLT in generate-only ' ...
            'mode: SMLT builds the candidate pool but does not choose the final ' ...
            'set -- that is decided by the consensus selection step.']);
        w(Fid, '');
        Rows = {
            'Candidate pool size', formattedNumber(G.PoolSize);
            'Target learner', char(getField(G, "TargetLearner", "?"));
            'Standardization', char(getField(G, "Standardization", "?"))};
        mdTable(Fid, {'Property', 'Value'}, Rows);
        w(Fid, '');
        if isfield(G, 'StandardizationReasoning') && strlength(G.StandardizationReasoning) > 0
            w(Fid, '_Standardization rationale: %s_', char(G.StandardizationReasoning));
            w(Fid, '');
        end
    end
    if isfield(G, 'Reasoning') && strlength(G.Reasoning) > 0
        w(Fid, '_Dispatch: %s_', char(G.Reasoning));
        w(Fid, '');
    end
end


function Label = targetLearnerLabel(Results)
%targetLearnerLabel The declared model family, spelling out the agnostic panel.
%   On the domain path there is no SMLT TargetLearner, but the family the user
%   declared still governs the baseline panel -- report that. "agnostic" fans out
%   to all three families, so name them.
    TargetModel = "agnostic";
    B = getField(Results, "Baseline", struct());
    KF = getField(Results, "KFold", struct());
    if isfield(B, 'TargetModel')
        TargetModel = string(B.TargetModel);
    elseif isfield(KF, 'TargetModel')
        TargetModel = string(KF.TargetModel);
    end
    if TargetModel == "agnostic"
        Label = "agnostic (Random Forest, Linear, Kernel)";
    else
        Label = TargetModel;
    end
end


function writeSelection(Fid, Results, EmbedDir)
    w(Fid, '## 3. Consensus Selection');
    w(Fid, '');
    PI = getField(Results, "PanelInfo", struct());
    Selected = getField(Results, "SelectedNames", string.empty(1, 0));

    if isfield(PI, 'Rankers')
        w(Fid, '**Ranker panel:** %s', char(joinNames(PI.Rankers)));
        if isfield(PI, 'Skipped') && ~isempty(PI.Skipped)
            w(Fid, '**Skipped rankers:** %s', char(joinNames(PI.Skipped)));
        end
        w(Fid, '');
    end

    Rows = {};
    if isfield(PI, 'VoterMethod')
        Rows(end+1, :) = {'Consensus voter', char(PI.VoterMethod)};
    end
    if isfield(PI, 'MeanAgreement')
        Rows(end+1, :) = {'Mean rank agreement', fmtQuality(PI.MeanAgreement)};
    end
    if isfield(PI, 'PoolSize')
        Rows(end+1, :) = {'Pool size', formattedNumber(PI.PoolSize)};
    end
    if isfield(PI, 'NSelect')
        Rows(end+1, :) = {'Features selected', formattedNumber(PI.NSelect)};
    end
    if ~isempty(Rows)
        mdTable(Fid, {'Property', 'Value'}, Rows);
        w(Fid, '');
    end

    writeSelectionCountNote(Fid, PI);

    ByUser = isfield(PI, 'VoterSelectedBy') && PI.VoterSelectedBy == "user";
    if ByUser
        % Forced by the caller -- do not attribute the choice to the agreement gate.
        if PI.VoterMethod == "majority"
            w(Fid, ['_Majority vote (order-blind top-K count) was used by user ' ...
                'override -- appropriate when the rankers'' selected sets are ' ...
                'trusted but their orderings are not (e.g. tie-heavy filters)._']);
        else
            w(Fid, ['_%s was used by user override, not chosen by the rank-' ...
                'agreement gate (mean agreement %s)._'], voterLongName(PI.VoterMethod), ...
                fmtQuality(PI.MeanAgreement));
        end
    elseif isfield(PI, 'VoterMethod') && PI.VoterMethod == "borda"
        w(Fid, ['_Borda count was used because mean rank agreement met the ' ...
            'consensus threshold (rankers largely concur)._']);
    elseif isfield(PI, 'VoterMethod') && PI.VoterMethod == "rrf"
        w(Fid, ['_Reciprocal-rank fusion was used because rankers disagreed ' ...
            '(low mean agreement), so top-rank consensus is weighted over ' ...
            'aggregate position._']);
    end
    w(Fid, '');

    if isfield(PI, 'Excluded') && ~isempty(PI.Excluded)
        w(Fid, '**Excluded from the pool before voting:** %s', char(joinNames(PI.Excluded)));
        w(Fid, '');
    end

    % Vote table: top features by consensus rank.
    writeVoteTable(Fid, Results);

    w(Fid, '**Selected feature set (%d):** %s', numel(Selected), char(joinNames(Selected)));
    w(Fid, '');
    if isfield(PI, 'Reasoning') && strlength(PI.Reasoning) > 0
        w(Fid, '_%s_', char(PI.Reasoning));
        w(Fid, '');
    end

    mdFigure(Fid, EmbedDir, 'fig_selection_consensus.svg', 'Consensus selection', ...
        'Per-method rank agreement across the selector panel.');
    mdFigure(Fid, EmbedDir, 'fig_selection_decision.svg', 'Selection decision', ...
        ['Consensus-score elbow: candidates in rank order with the cut at the ' ...
        'selected count. A sharp drop at the cut is a clean separation; a shallow ' ...
        'slope is a soft cut. How stable this decision is under resampling is ' ...
        'audited in chapter 7.']);
    writeSelectionGlossary(Fid, Results);
end


function writeSelectionCountNote(Fid, PI)
%writeSelectionCountNote State what set the delivered count -- the score elbow, or
%   a keep-all when the score curve had no elbow to cut at. Silent only if the
%   fields the note needs are absent.
    if ~isfield(PI, 'NSelect')
        return;
    end
    KeptAll = isfield(PI, 'PoolSize') && PI.NSelect >= PI.PoolSize;
    if KeptAll
        w(Fid, ['> **No elbow — the full pool was kept.** The consensus scores ' ...
            'declined too gradually to mark a cut (no point falls below the chord ' ...
            'joining the first and last candidate), so every feature was retained. ' ...
            'Read this as "the candidates are comparably useful," not as a failure ' ...
            'to select.']);
    else
        w(Fid, ['> **The score elbow set this count.** The consensus curve''s elbow ' ...
            'fell at **%d** features, so the delivered count reflects where the fused ' ...
            'scores stop paying off.'], PI.NSelect);
    end
    w(Fid, '');
end


function writeSelectionGlossary(Fid, Results)
%writeSelectionGlossary A little dictionary of the selection terms used above.
%   Present-tense definitions only, and only for terms this run actually shows.
%   Each method leads with its acronym in UPPER CASE and its spelled-out name, so
%   the short codes in the tables above read as words here.
    PI = getField(Results, "PanelInfo", struct());

    % Ranking methods actually in the panel, keyed by the short code the tables use.
    Methods = {};
    if isfield(PI, 'Rankers')
        R = string(PI.Rankers);
        add = @(Key, Name, Text) mustShow(R, Key, Name, Text);
        Methods = [Methods, add("mrmr", "MRMR (Minimum Redundancy, Maximum Relevance)", ...
            ['ranks features high when they track the response but duplicate each ' ...
            'other little.'])];
        Methods = [Methods, add("oob", "OOB (Out-Of-Bag importance)", ...
            ['permutation importance from a bagged tree ensemble; how much ' ...
            'prediction error rises when a feature is shuffled.'])];
        Methods = [Methods, add("nca", "NCA (Neighbourhood Component Analysis)", ...
            'learns per-feature weights that make same-class points nearest neighbours.')];
        Methods = [Methods, add("lasso", "LASSO (Least Absolute Shrinkage and Selection Operator)", ...
            ['an L1-penalised linear fit; ranks features by how long their ' ...
            'coefficient survives as the penalty tightens.'])];
        Methods = [Methods, add("chi2", "Chi-Square filter", ...
            'tests each feature''s association with a categorical response.')];
        Methods = [Methods, add("ftest", "F-Test filter", ...
            'ranks features by the strength of its univariate association with the response.')];
    end

    % Concepts: the fusion voter in play.
    Terms = {};
    if isfield(PI, 'VoterMethod')
        switch string(PI.VoterMethod)
            case "borda"
                Terms = [Terms, {['**Borda count** — fuses the ranker lists by ' ...
                    'summing each feature''s position across them.']}];
            case "rrf"
                Terms = [Terms, {['**RRF (Reciprocal-Rank Fusion)** — fuses the ' ...
                    'ranker lists by summing `1/(k+rank)`, so top-of-list agreement ' ...
                    'outweighs aggregate position.']}];
            case "majority"
                Terms = [Terms, {['**Majority vote** — keeps features that most ' ...
                    'rankers place in their own top set (order-blind).']}];
        end
    end
    w(Fid, '### 3a. Glossary');
    w(Fid, '');
    if ~isempty(Methods)
        w(Fid, '_Ranking methods in the panel (each scores the pool; the voter fuses them):_');
        w(Fid, '');
        for i = 1:numel(Methods)
            w(Fid, '- %s', Methods{i});
        end
        w(Fid, '');
    end
    if ~isempty(Terms)
        w(Fid, '_Fusion terms:_');
        w(Fid, '');
        for i = 1:numel(Terms)
            w(Fid, '- %s', Terms{i});
        end
        w(Fid, '');
    end
end


function Cell = mustShow(Rankers, Key, Name, Text)
%mustShow A "**Name** — text" bullet when Key is in the panel, else {} (so absent
%   methods drop from the list). Name leads with the UPPER-CASE acronym.
    if any(contains(Rankers, Key))
        Cell = {sprintf('**%s** — %s', Name, Text)};
    else
        Cell = {};
    end
end


function writeVoteTable(Fid, Results)
    if ~isfield(Results, 'VoteTable') || ~istable(Results.VoteTable) || isempty(Results.VoteTable)
        return;
    end
    V = Results.VoteTable;
    if ismember("Rank", string(V.Properties.VariableNames))
        V = sortrows(V, "Rank");
    end
    [Rows, NTotal, NShown, NOmitted] = voteRowsToShow(V);
    w(Fid, '**Consensus vote (top %d of %d):**', NShown, NTotal);
    w(Fid, '');
    mdTable(Fid, {'Feature', 'Consensus score', 'Rank', 'Selected'}, Rows);
    w(Fid, '');
    if NOmitted > 0
        w(Fid, ['_%d further features omitted here; the complete vote table is in ' ...
            'Appendix A and in `%s`._'], NOmitted, char(resultsMatName(Results)));
        w(Fid, '');
    end
end


function [Rows, NTotal, NShown, NOmitted] = voteRowsToShow(V)
%voteRowsToShow Choose consensus-vote rows for the body preview, matching the
%   frequency table's rule: at least the top max(20, #selected) by rank, and never
%   hide a selected feature (one that sorts past the window is still shown). The
%   complete table always lives in the appendix + the results .mat, so the body is
%   a preview, not the record. V is already sorted best-rank-first.
    NTotal = height(V);
    HasSel = ismember("Selected", string(V.Properties.VariableNames));
    if HasSel
        IsSel = logical(V.Selected);
    else
        IsSel = false(NTotal, 1);
    end
    Window = max(20, sum(IsSel));
    Keep = IsSel;                            % every selected feature, wherever it ranks
    Keep(1:min(Window, NTotal)) = true;      % fill the window with the top-ranked rows
    Idx = find(Keep);
    NShown = numel(Idx);
    NOmitted = NTotal - NShown;
    Rows = cell(NShown, 4);
    for r = 1:NShown
        i = Idx(r);
        Rows{r, 1} = char(string(V.Feature(i)));
        Rows{r, 2} = fmtQuality(double(V.Score(i)));
        Rows{r, 3} = sprintf('%d', V.Rank(i));
        if HasSel
            Rows{r, 4} = tickMark(V.Selected(i));
        else
            Rows{r, 4} = '';
        end
    end
end


function writeSelectedDescriptions(Fid, Results)
    w(Fid, '## 4. Selected Feature Definitions');
    w(Fid, '');
    Selected = getField(Results, "SelectedNames", string.empty(1, 0));
    if isempty(Selected)
        w(Fid, '_No features selected._');
        w(Fid, '');
        return;
    end
    Recipe = getRecipe(Results);
    if isempty(Recipe)
        w(Fid, '_Recipe unavailable; feature definitions not shown._');
        w(Fid, '');
        return;
    end

    % describeFeatures returns the already-normalized, generator-agnostic
    % Feature | Type | Definition table (all string columns) for exactly the
    % selected features, in order, whatever produced the pool -- no inline
    % describe() reshaping here. mdTable indexes its data cell-wise, so wrap each
    % string scalar in a cell (mdTable renders string values as-is).
    D = describeFeatures(Recipe, string(Selected));
    Rows = cell(height(D), 3);
    for i = 1:height(D)
        Rows(i, :) = {D.Feature(i), D.Type(i), D.Definition(i)};
    end
    mdTable(Fid, {'Feature', 'Type', 'Definition'}, Rows);
    w(Fid, '');
end


function writeBaseline(Fid, Results, EmbedDir)
    w(Fid, '## 5. Performance');
    w(Fid, '');
    Strategy = resolveStrategy(Results);
    if Strategy == "cross_validated"
        writeKFoldPerformance(Fid, Results, EmbedDir);
        writeConservativeCaveat(Fid, Strategy);
        return;
    end
    if ~isfield(Results, 'Baseline') || ~isfield(Results.Baseline, 'Panel')
        w(Fid, '_No performance read available._');
        w(Fid, '');
        return;
    end
    B = Results.Baseline;
    w(Fid, ['Point estimate on the held-out test rows (single split, so no error ' ...
        'bars). Downstream lens: **%s**.'], char(baselineLensLabel(B)));
    w(Fid, '');

    Metric = char(getField(B, "Metric", "metric"));
    Panel = B.Panel;
    Rows = cell(numel(Panel), 5);
    for i = 1:numel(Panel)
        FR = Panel(i);
        Rows{i, 1} = char(familyLabel(FR.Family));
        Rows{i, 2} = fmtQuality(FR.Naive);
        Rows{i, 3} = fmtQuality(FR.Original);
        Rows{i, 4} = fmtQuality(FR.Engineered);
        Rows{i, 5} = fmtSigned(FR.Improvement);
    end
    mdTable(Fid, {'Family', ['Naive (' Metric ')'], 'Original', 'Engineered', ...
        'Improvement (eng-orig)'}, Rows);
    w(Fid, '');

    % Supplementary classification metrics (AUC is the primary metric above).
    % Macro-F1 and accuracy are always reported; when the response is imbalanced
    % (AccuracyReliable=false, ratio > 1.5:1) accuracy is kept but flagged as
    % unreliable rather than hidden, so the reader decides whether to trust it.
    if strcmp(Metric, 'auc')
        AccuracyReliable = ~isfield(Panel(1), 'AccuracyReliable') || Panel(1).AccuracyReliable;
        SupHeader = {'Family', 'Macro-F1 (orig)', 'Macro-F1 (eng)', ...
            'Accuracy (orig)', 'Accuracy (eng)'};
        SupRows = cell(numel(Panel), 5);
        for i = 1:numel(Panel)
            FR = Panel(i);
            SupRows{i, 1} = char(familyLabel(FR.Family));
            SupRows{i, 2} = fmtQuality(FR.MacroF1.Original);
            SupRows{i, 3} = fmtQuality(FR.MacroF1.Engineered);
            SupRows{i, 4} = fmtQuality(FR.Accuracy.Original);
            SupRows{i, 5} = fmtQuality(FR.Accuracy.Engineered);
        end
        w(Fid, 'Supplementary classification metrics:');
        w(Fid, '');
        mdTable(Fid, SupHeader, SupRows);
        w(Fid, '');
        if ~AccuracyReliable
            w(Fid, ['_Accuracy above is **unreliable**: the response is imbalanced ' ...
                '(ratio > 1.5:1), where a raw hit-rate is favored by the classes ' ...
                'other than the minority class. AUC (the primary metric) and ' ...
                'macro-F1 are the metrics to trust._']);
            w(Fid, '');
        end
    end

    % No collapsed engineered-vs-{naive,original} verdict here: whether
    % engineering helps is model-dependent, so the per-family table above (Naive /
    % Original / Engineered / Improvement per model) is the read, not a single
    % headline-family yes/no that reads as holding for every model.

    mdFigure(Fid, EmbedDir, 'fig_validation_baseline.svg', 'Validation baseline', ...
        'Engineered vs. original vs. naive on the declared model family (point estimate, no error bars).');
    writeConservativeCaveat(Fid, "holdout");
end


function writeKFoldPerformance(Fid, Results, EmbedDir)
%writeKFoldPerformance Chapter-5 performance under cross_validated: the k-fold
%   mean +/- std is the headline (no held-out slice, so no point estimate). Under
%   agnostic the panel spans all trained families (bag/linear/kernel), one table
%   row per family; a declared model is a single row.
    if ~isfield(Results, 'KFold') || ~isstruct(Results.KFold) ...
            || ~isfield(Results.KFold, 'Performance')
        w(Fid, '_No cross-validated performance read available._');
        w(Fid, '');
        return;
    end
    KF = Results.KFold;
    Perf = KF.Performance;
    MetricName = char(getField(KF, "MetricName", "metric"));
    w(Fid, ['Cross-validated: the whole generate -> select pipeline is re-run per ' ...
        'fold (the pool is regenerated each time), so performance is reported as ' ...
        '**mean +/- std** across %d folds — the honest end-to-end variance a single ' ...
        'split hides.'], getField(KF, "K", numel(fieldOr(KF, 'PerFold', []))));
    w(Fid, '');

    Panel = kfoldPanel(Perf);

    % Primary-metric table: one row per family (mean +/- std each measure).
    Rows = cell(numel(Panel), 5);
    for i = 1:numel(Panel)
        FP = Panel(i);
        Rows{i, 1} = char(familyLabel(FP.Family));
        Rows{i, 2} = fmtMeanStd(FP.Naive);
        Rows{i, 3} = fmtMeanStd(FP.Original);
        Rows{i, 4} = fmtMeanStd(FP.Engineered);
        Rows{i, 5} = fmtMeanStd(FP.Improvement);
    end
    mdTable(Fid, {'Family', sprintf('Naive (%s)', MetricName), 'Original', ...
        'Engineered', 'Improvement (eng-orig)'}, Rows);
    w(Fid, '');

    % Supplementary classification metrics, per family (mean +/- std).
    if strcmp(MetricName, 'auc')
        SupRows = cell(numel(Panel), 5);
        for i = 1:numel(Panel)
            FP = Panel(i);
            SupRows{i, 1} = char(familyLabel(FP.Family));
            SupRows{i, 2} = fmtMeanStd(kfoldSecondaryFor(FP, "macro-F1", "Original"));
            SupRows{i, 3} = fmtMeanStd(kfoldSecondaryFor(FP, "macro-F1", "Engineered"));
            SupRows{i, 4} = fmtMeanStd(kfoldSecondaryFor(FP, "accuracy", "Original"));
            SupRows{i, 5} = fmtMeanStd(kfoldSecondaryFor(FP, "accuracy", "Engineered"));
        end
        w(Fid, 'Supplementary classification metrics (mean +/- std):');
        w(Fid, '');
        mdTable(Fid, {'Family', 'Macro-F1 (orig)', 'Macro-F1 (eng)', ...
            'Accuracy (orig)', 'Accuracy (eng)'}, SupRows);
        w(Fid, '');
    end

    if nargin >= 3
        mdFigure(Fid, EmbedDir, 'fig_validation_baseline.svg', 'Validation baseline', ...
            ['Naive vs. original vs. engineered per model family, cross-validated ' ...
            'mean +/- std across folds.']);
    end
end


function Panel = kfoldPanel(Perf)
%kfoldPanel The per-family panel, falling back to a one-row primary-only panel
%   when an older Result carried no .Panel (keeps the report robust either way).
    if isfield(Perf, 'Panel') && ~isempty(Perf.Panel)
        Panel = Perf.Panel;
        return;
    end
    Panel = struct(Family = "bag", Naive = Perf.Naive, Original = Perf.Original, ...
        Engineered = Perf.Engineered, Improvement = Perf.Improvement, ...
        Secondary = getField(Perf, "Secondary", ...
            struct('Name', {}, 'Engineered', {}, 'Original', {})));
end


function MS = kfoldSecondaryFor(FamilyPanel, Name, Side)
%kfoldSecondaryFor A named companion metric (macro-F1/accuracy) for one family and
%   side (Engineered/Original), or a NaN meanStd when that family never recorded it.
    MS = struct(Mean = NaN, Std = NaN);
    if ~isfield(FamilyPanel, 'Secondary')
        return;
    end
    Sec = FamilyPanel.Secondary;
    for i = 1:numel(Sec)
        if string(Sec(i).Name) == Name
            MS = Sec(i).(Side);
            return;
        end
    end
end


function writeConservativeCaveat(Fid, Strategy)
%writeConservativeCaveat The shipped recipe is refit on ALL working data, so the
%   estimate above grades a recipe trained on less data than the one delivered.
    if Strategy == "holdout"
        Detail = ['the estimate above used the training rows only, while the ' ...
            'delivered recipe is refit on all working rows (training + the held-out ' ...
            'slice)'];
    else
        Detail = ['each fold trained on a subset of the working rows, while the ' ...
            'delivered recipe is refit on all working rows'];
    end
    w(Fid, ['_Conservative by construction: %s. The delivered feature set is ' ...
        'therefore at least as good as this estimate suggests._'], Detail);
    w(Fid, '');
end


function writeQuality(Fid, Results)
    w(Fid, '## 6. Model-Free Quality');
    w(Fid, '');
    if ~isfield(Results, 'Quality') || ~isstruct(Results.Quality)
        w(Fid, '_No model-free quality panel available._');
        w(Fid, '');
        return;
    end
    Q = Results.Quality;
    mdTable(Fid, {'Dimension', 'Original', 'Engineered'}, modelFreeQualityRows(Q));
    w(Fid, '');
    if isfield(Q, 'Verdicts')
        Verds = struct2cell(Q.Verdicts);
        for i = 1:numel(Verds)
            w(Fid, '- %s', char(string(Verds{i})));
        end
        w(Fid, '');
    end
    writeQualityStability(Fid, Results);
end


function writeQualityStability(Fid, Results)
%writeQualityStability Chapter 6b: per-fold engineered-side quality band, a
%   property of the recipe as a procedure. Cross-validated strategy only.
    if ~isfield(Results, 'KFold') || ~isstruct(Results.KFold) ...
            || ~isfield(Results.KFold, 'QualityStability')
        return
    end
    QS = Results.KFold.QualityStability;
    w(Fid, '### 6b. Quality consistency across folds (cross-validated)');
    w(Fid, '');
    w(Fid, ['How much the engineered set''s model-free quality varies as the ' ...
        'recipe is refit across folds — a property of the *procedure*, not the ' ...
        'shipped set above. Each read is the engineered side on that fold''s ' ...
        'training rows, mean +/- std across %d folds.'], Results.KFold.K);
    w(Fid, '');
    mdTable(Fid, {'Dimension', 'Engineered (mean +/- std)'}, {
        'Peak relevance (max MI with response)', fmtMeanStd(QS.MaxRelevance);
        'Relevant features (above threshold)', fmtMeanStd(QS.NumRelevant);
        'Redundancy (mean pairwise MI)', fmtMeanStd(QS.MeanRedundancy);
        'Redundancy (max pairwise MI, worst pair)', fmtMeanStd(QS.MaxRedundancy);
        'Effective dimensionality', fmtMeanStd(QS.EffectiveDim)});
    w(Fid, '');
end


function writeSelectorStability(Fid, Results, EmbedDir)
%writeSelectorStability Chapter 7: fixed-pool selection stability (7a) + the
%   optional generation-variance read (7b), plus their Nogueira gap. Each read is
%   its own opt-in. Resampling grades the *procedure*; it never revises the
%   shipped feature set (certified on the held-out test rows). When neither read
%   ran the chapter is a single line — "analysis skipped per user request" when
%   the user opted out, or "analysis was not recorded" when no gate ran and no skip
%   was flagged — with none of the resampling explainer or figure.
    HasFixedPool = isfield(Results, 'SelStab') && isstruct(Results.SelStab);
    HasGenStab = isfield(Results, 'GenStab') && isstruct(Results.GenStab);
    SkippedByRequest = isfield(Results, 'StabilitySkipped') && Results.StabilitySkipped;

    w(Fid, '## 7. Selector Stability (diagnostic)');
    w(Fid, '');
    if ~HasFixedPool && ~HasGenStab
        if SkippedByRequest
            w(Fid, '_Selection stability analysis skipped per user request._');
        else
            w(Fid, '_Selection stability analysis was not recorded._');
        end
        w(Fid, '');
        return;
    end

    % A labeled "how to read" note: everything here is fixed methodology, the same
    % on every run. Blockquote-wrapping it sets it apart from the run-specific
    % findings (Nogueira values, feature tiers, tables) that follow below.
    w(Fid, '> **How to read this section.**');
    w(Fid, '>');
    w(Fid, ['> The question here is simple: *if you had trained on a slightly ' ...
        'different set of rows, would the selector have picked the same features?* ' ...
        'This section grades how repeatable the selection is — not the feature set ' ...
        'you are shipping, which is the one picked on your full data.']);
    w(Fid, '>');
    w(Fid, ['> **How it is measured.** We take many random subsamples of your ' ...
        'training rows, re-run the selection on each, and see how often the same ' ...
        'features come back. For classification the subsamples keep your original ' ...
        'class balance, and very large datasets are trimmed first so this stays ' ...
        'affordable. Each part below says how many subsamples it used and how big ' ...
        'they were.']);
    w(Fid, '>');
    w(Fid, ['> **The Nogueira index** boils all that agreement down to one number: ' ...
        '**1.0** means every subsample picked exactly the same features, **around ' ...
        '0** means they agreed no more than random chance would, and it can dip ' ...
        'slightly below zero. Rule of thumb: **0.75 and up is very stable, ' ...
        '0.4-0.75 is moderate, below 0.4 is shaky.**']);
    w(Fid, '');

    Shipped = string(getField(Results, "SelectedNames", string.empty(1, 0)));
    Floor = 0.5;   % same reference the figure and the fragile warning use
    if HasFixedPool
        writeFixedPool(Fid, Results.SelStab, Shipped, Floor);
    end

    if HasGenStab
        writeGenStab(Fid, Results.GenStab, Shipped, Floor);
        if HasFixedPool
            writeStabilityGap(Fid, Results.SelStab, Results.GenStab);
        end
    end

    mdFigure(Fid, EmbedDir, 'fig_selection_stability.svg', 'Selection stability', ...
        ['Per-feature selection frequency across resamples, in the same ' ...
        'consensus-rank order as the selection-decision elbow in chapter 3.']);
end


function writeFixedPool(Fid, Sel, Shipped, Floor)
%writeFixedPool Fixed-pool selection stability (opt-in read).
    w(Fid, '### 7a. Selection stability (fixed pool)');
    w(Fid, '');
    w(Fid, ['_What this part checks: it keeps the engineered features fixed and ' ...
        'only re-runs the selection on different subsamples of rows. So it tells ' ...
        'you how much the selector''s choices wobble when the training rows change, ' ...
        'on its own. The subsamples are drawn the same way every run, so these ' ...
        'numbers reproduce exactly._']);
    w(Fid, '');
    if isfield(Sel, 'Nogueira')
        w(Fid, '> **Fixed-pool Nogueira index: %s %s**', ...
            fmtQuality(Sel.Nogueira), nogueiraGloss(Sel.Nogueira));
        w(Fid, '');
        w(Fid, ['The pool is held fixed and only selection re-runs, so this measures ' ...
            '*selector* sensitivity to row noise alone.']);
        w(Fid, '');
    end
    if isfield(Sel, 'CoreFeatures') && ~isempty(Sel.CoreFeatures)
        w(Fid, '**Reliably re-selected** (the consensus core, picked in at least %.0f%% of subsamples): %s', ...
            100 * coreThreshold(Sel), char(joinNames(Sel.CoreFeatures)));
        w(Fid, '');
    end
    % Reliable -> mid-band -> fragile, so all three tiers of shipped features read
    % together, before the backing table splits them apart by frequency.
    writeMidBand(Fid, Sel, Shipped, Floor);
    writeFragileWarning(Fid, Sel, Shipped, Floor, 'resample');
    if isfield(Sel, 'SelectionFrequency') && istable(Sel.SelectionFrequency) ...
            && ~isempty(Sel.SelectionFrequency)
        writeFreqTable(Fid, Sel.SelectionFrequency, Shipped, Floor, coreThreshold(Sel));
    end
end


function writeFragileWarning(Fid, Sel, Shipped, Floor, Kind)
%writeFragileWarning Flag shipped features re-selected below FLOOR in one stability
%   read. A warning only -- it never removes anything. A shipped feature the
%   full-data consensus kept but resampling rarely re-picked is fragile: it may be
%   riding this training split. Mirrors the plot's "short bar left of the floor".
%   KIND names which resampling this read used ('resample' for the fixed pool,
%   'regenerated-pool' for generation stability), so the two reads' warnings do not
%   read as duplicates. For the generation read this is scoped to shipped features
%   still present in the regenerated pool -- ones that dropped out entirely are the
%   drift table's job, not a low frequency here.
    if ~isstruct(Sel) || ~isfield(Sel, 'SelectionFrequency') ...
            || ~istable(Sel.SelectionFrequency) || isempty(Shipped)
        return;
    end
    Freq = Sel.SelectionFrequency;
    Shipped = string(Shipped);
    [InFreq, Loc] = ismember(Shipped, string(Freq.Feature));
    ShippedFreq = nan(numel(Shipped), 1);
    ShippedFreq(InFreq) = Freq.Frequency(Loc(InFreq));
    Fragile = Shipped(ShippedFreq < Floor & ~isnan(ShippedFreq));
    if isempty(Fragile)
        w(Fid, ['**Fragile shipped picks:** none -- every shipped feature cleared ' ...
            'the %.0f%% %s floor.'], 100 * Floor, Kind);
        w(Fid, '');
        return;
    end
    Pct = arrayfun(@(f) string(sprintf('%s (%.0f%%)', f, ...
        100 * ShippedFreq(Shipped == f))), Fragile);
    w(Fid, ['**Fragile shipped picks (below the %.0f%% %s floor):** %s. ' ...
        'These were kept by the full-data consensus but re-selected in a minority ' ...
        'of the %s runs. This is a flag only; nothing was removed.'], ...
        100 * Floor, Kind, char(strjoin(Pct, ", ")), Kind);
    w(Fid, '');
end


function writeMidBand(Fid, Sel, Shipped, Floor)
%writeMidBand The shipped features between the FLOOR and the consensus-core cut --
%   above the fragile floor but short of "reliably re-selected". They pass the floor
%   so they are NOT flagged fragile, yet naming them keeps the report from leaving a
%   silent gap between the two headline sentences (e.g. a 72%% pick with an 80%% core
%   and a 50%% floor). Prints nothing when the band is empty.
    if ~isstruct(Sel) || ~isfield(Sel, 'SelectionFrequency') ...
            || ~istable(Sel.SelectionFrequency) || isempty(Shipped)
        return;
    end
    Core = coreThreshold(Sel);
    Freq = Sel.SelectionFrequency;
    Shipped = string(Shipped);
    [InFreq, Loc] = ismember(Shipped, string(Freq.Feature));
    ShippedFreq = nan(numel(Shipped), 1);
    ShippedFreq(InFreq) = Freq.Frequency(Loc(InFreq));
    InBand = ShippedFreq >= Floor & ShippedFreq < Core & ~isnan(ShippedFreq);
    if ~any(InBand)
        return;
    end
    Mid = Shipped(InBand);
    Pct = arrayfun(@(f) string(sprintf('%s (%.0f%%)', f, ...
        100 * ShippedFreq(Shipped == f))), Mid);
    w(Fid, ['**Above the floor but below core (%.0f%%-%.0f%%):** %s -- kept with ' ...
        'moderate support: re-selected in most runs but not consistently enough to ' ...
        'count as core.'], 100 * Floor, 100 * Core, char(strjoin(Pct, ", ")));
    w(Fid, '');
end


function writeGenStab(Fid, Sel, Shipped, Floor)
%writeGenStab Generation-variance SELECTION STABILITY over the intersection
%   universe. Regenerates the pool on each subsample, so this read folds
%   generation variance in on top of selection. Its own opt-in gate, separate
%   from the fixed-pool read in 7a and from the performance read in chapter 5.
    w(Fid, '### 7b. Generation stability (pool regenerated)');
    w(Fid, '');
    w(Fid, ['_What this part checks: it re-runs the *whole* pipeline on each ' ...
        'subsample — building the features from scratch and then selecting — so it ' ...
        'also captures how much the feature-building step itself wobbles, on top of ' ...
        'the selection. It uses the same subsamples as the fixed-pool check above, ' ...
        'which is what lets you compare the two numbers directly, as the gap below ' ...
        'reports._']);
    w(Fid, '');

    if isfield(Sel, 'Nogueira')
        w(Fid, '> **Generation-stability Nogueira index: %s %s**', ...
            fmtQuality(Sel.Nogueira), nogueiraGloss(Sel.Nogueira));
        w(Fid, '');
        w(Fid, ['The pool is regenerated every subsample, so this folds *generation* ' ...
            'variance in on top of selection (measured over the features shared by ' ...
            'all subsamples). Distinct from the fixed-pool value in 7a; their gap ' ...
            'is quantified below.']);
        w(Fid, '');
    end
    if isfield(Sel, 'CoreFeatures') && ~isempty(Sel.CoreFeatures)
        w(Fid, '**Reliably re-selected** (the consensus core, picked in at least %.0f%% of subsamples): %s', ...
            100 * coreThreshold(Sel), char(joinNames(Sel.CoreFeatures)));
        w(Fid, '');
    end
    % Same reliable -> mid-band -> fragile trio as the fixed-pool read, scoped to the
    % regenerated pool (features that dropped out entirely are the drift table).
    writeMidBand(Fid, Sel, Shipped, Floor);
    writeFragileWarning(Fid, Sel, Shipped, Floor, 'regenerated-pool');
    if isfield(Sel, 'Drift') && istable(Sel.Drift) && ~isempty(Sel.Drift)
        writeDriftTable(Fid, Sel.Drift, Shipped);
    end
    if isfield(Sel, 'SelectionFrequency') && istable(Sel.SelectionFrequency) ...
            && ~isempty(Sel.SelectionFrequency)
        writeFreqTable(Fid, Sel.SelectionFrequency, Shipped, Floor, coreThreshold(Sel));
    end
end


function writeStabilityGap(Fid, SelStab, GenStab)
%writeStabilityGap The fixed-pool <-> generation Nogueira gap = generation variance.
%   Both indices come from the SAME subsampling scheme, so their difference
%   isolates how much instability comes from regenerating the pool per subsample
%   versus re-selecting on a fixed pool.
    if ~isfield(SelStab, 'Nogueira') || ~isfield(GenStab, 'Nogueira')
        return;
    end
    Fixed = SelStab.Nogueira;
    Full = GenStab.Nogueira;
    if isnan(Fixed) || isnan(Full)
        return;
    end
    Gap = Fixed - Full;
    w(Fid, '> **Generation variance (fixed-pool minus generation stability): %+.2f**', Gap);
    w(Fid, '');
    w(Fid, ['Fixed-pool stability was %s and generation stability %s; the ' ...
        'gap is the share of instability attributable to regenerating the pool ' ...
        'rather than to selection. %s'], ...
        fmtQuality(Fixed), fmtQuality(Full), char(gapGloss(Gap)));
    w(Fid, '');
end


function Gloss = gapGloss(Gap)
    if Gap >= 0.15
        Gloss = "A large gap: generation is the dominant source of instability.";
    elseif Gap >= 0.05
        Gloss = "A moderate gap: regeneration adds noticeable instability.";
    else
        Gloss = "A small gap: selection, not generation, is the moving part.";
    end
end


function T = coreThreshold(Sel)
%coreThreshold The read's own CoreThreshold (the re-selection fraction above which
%   a feature is listed as reliable), read back for display; falls back to 0.8 for
%   a Result predating the field. Not a new threshold -- just the stored value.
    if isfield(Sel, 'CoreThreshold') && ~isempty(Sel.CoreThreshold)
        T = Sel.CoreThreshold;
    else
        T = 0.8;
    end
end


function writeFreqTable(Fid, FreqTbl, Shipped, Floor, Core)
%writeFreqTable The per-feature re-selection frequency, the one place to read the
%   stability of each individual feature. A Status column ties each row back to the
%   shipped decision -- "shipped, core" (a shipped feature at or above the CORE cut),
%   "shipped" (above the FLOOR but below core), "shipped, fragile" (below the FLOOR,
%   i.e. rarely re-picked), or "not shipped" (a candidate the resamples liked but the
%   consensus did not) -- so the table reads as more than a bare percent list. EVERY
%   shipped feature is always listed, including a fragile one that sorts to the
%   bottom on low frequency; the tail is filled with the highest-frequency
%   non-shipped candidates up to the same window the plots use.
    Shipped = string(Shipped);
    [Rows, NTotal, NShown, NOmitted] = freqRowsToShow(FreqTbl, Shipped, Floor, Core);
    w(Fid, ['**Per-feature re-selection frequency** — how often each feature was ' ...
        'picked across the resamples (100%% = every subsample). Every shipped feature ' ...
        'is listed; read each against the %.0f%% floor:'], 100 * Floor);
    w(Fid, '');
    mdTable(Fid, {'Feature', 'Re-selected in', 'Status'}, Rows);
    if NOmitted > 0
        w(Fid, ['_Showing %d of %d features: all shipped plus the top non-shipped ' ...
            'by frequency; %d lower-frequency non-shipped candidates are in the ' ...
            'complete table in Appendix A._'], NShown, NTotal, NOmitted);
        w(Fid, '');
    end
end


function [Rows, NTotal, NShown, NOmitted] = freqRowsToShow(FreqTbl, Shipped, Floor, Core)
%freqRowsToShow Choose the frequency-table rows to render, shared shape for both
%   report generators: always every shipped feature (so a fragile low-frequency
%   pick is never hidden), then the highest-frequency non-shipped candidates up to
%   max(20, #shipped) -- the same window the vote and drift previews use. FreqTbl
%   is already sorted descending by frequency; returned rows keep that order. The
%   complete table always lives in Appendix A + the results .mat.
    Shipped = string(Shipped);
    NTotal = height(FreqTbl);
    Feats = string(FreqTbl.Feature);
    IsShipped = ismember(Feats, Shipped);
    Window = max(20, numel(Shipped));
    Keep = IsShipped;                       % every shipped feature, wherever it sorts
    Keep(1:min(Window, NTotal)) = true;     % fill the window with the top-frequency rows
    Idx = find(Keep);
    NShown = numel(Idx);
    NOmitted = NTotal - NShown;
    Rows = cell(NShown, 3);
    for r = 1:NShown
        i = Idx(r);
        Feat = Feats(i);
        Freq = double(FreqTbl.Frequency(i));
        Rows{r, 1} = char(Feat);
        Rows{r, 2} = sprintf('%.0f%%', 100 * Freq);
        Rows{r, 3} = char(freqStatus(Feat, Freq, Shipped, Floor, Core));
    end
end


function Status = freqStatus(Feat, Freq, Shipped, Floor, Core)
%freqStatus Per-row tie-back to the shipped decision (see writeFreqTable). Three
%   tiers for a shipped feature: at/above CORE = "shipped, core"; between FLOOR and
%   CORE = plain "shipped"; below FLOOR = "shipped, fragile".
    if any(Shipped == Feat)
        if Freq < Floor
            Status = "shipped, fragile";
        elseif Freq >= Core
            Status = "shipped, core";
        else
            Status = "shipped";
        end
    else
        Status = "not shipped";
    end
end


function writeDriftTable(Fid, Drift, Shipped)
%writeDriftTable Features whose pool AVAILABILITY varied across subsamples -- a
%   different axis from re-selection frequency: this asks "was the feature even in
%   the pool to be picked?", not "how often was it picked?". Drift here is binary
%   membership -- a feature generated in EVERY subsample's pool is stable and does
%   not appear; any feature missing from even one pool is listed, and "Absent from"
%   states that gap directly (a stable feature would read 0%). The second rate is
%   its selection frequency WHEN present, so a low overall number can be read as a
%   pool-availability problem rather than a selection one. A shipped feature that
%   drifts is the actionable case -- called out first, always listed, tagged in
%   Status.
    Shipped = string(Shipped);
    ShippedDrift = string(Drift.Feature(ismember(string(Drift.Feature), Shipped)));
    if ~isempty(ShippedDrift)
        w(Fid, ['**Shipped features that drifted:** %s left the regenerated pool on ' ...
            'some subsamples, so they could not always be re-selected. A delivered ' ...
            'feature whose availability is unstable is worth confirming on a fresh ' ...
            'pool before relying on it.'], char(joinNames(ShippedDrift)));
        w(Fid, '');
    end
    w(Fid, ['**Drift** — features NOT generated in every subsample''s pool (a feature ' ...
        'present in all of them is stable and is omitted here). "Absent from" is the ' ...
        'share of subsamples that lacked it — the drift itself; "picked when present" ' ...
        'is its selection frequency among just the subsamples that had it:']);
    w(Fid, '');
    [Rows, NTotal, NShown, NOmitted] = driftRowsToShow(Drift, Shipped);
    mdTable(Fid, {'Feature', 'Absent from', 'Picked when present', 'Status'}, Rows);
    if NOmitted > 0
        w(Fid, ['_Showing %d of %d drifted features: all shipped plus the ' ...
            'most-drifted non-shipped; %d less-drifted non-shipped omitted._'], ...
            NShown, NTotal, NOmitted);
        w(Fid, '');
    end
end


function [Rows, NTotal, NShown, NOmitted] = driftRowsToShow(Drift, Shipped)
%driftRowsToShow Choose drift-table rows, shared shape for both generators: every
%   shipped-drifted feature (the actionable rows) always shown, then the most-drifted
%   non-shipped (highest "absent from") up to a window, so a churny regenerating pool
%   cannot flood the table. Rows are ordered worst-drift-first within each group.
    Shipped = string(Shipped);
    Feats = string(Drift.Feature);
    Absent = 1 - double(Drift.PoolCoverage);
    IsShipped = ismember(Feats, Shipped);
    NTotal = numel(Feats);
    Window = max(20, sum(IsShipped));           % always room for every shipped pick
    ShipIdx = find(IsShipped);
    RestIdx = find(~IsShipped);
    [~, so] = sort(Absent(ShipIdx), 'descend'); ShipIdx = ShipIdx(so);
    [~, ro] = sort(Absent(RestIdx), 'descend'); RestIdx = RestIdx(ro);
    NRest = min(numel(RestIdx), max(0, Window - numel(ShipIdx)));
    Idx = [ShipIdx; RestIdx(1:NRest)];
    NShown = numel(Idx);
    NOmitted = NTotal - NShown;
    Rows = cell(NShown, 4);
    for r = 1:NShown
        i = Idx(r);
        Rows{r, 1} = char(Feats(i));
        Rows{r, 2} = sprintf('%.0f%%', 100 * Absent(i));
        Rows{r, 3} = sprintf('%.0f%%', 100 * double(Drift.SelFreqWhenPresent(i)));
        if IsShipped(i)
            Rows{r, 4} = 'shipped, drifted';
        else
            Rows{r, 4} = 'not shipped';
        end
    end
end


function writeDeliverables(Fid, Results)
    w(Fid, '## 8. Deliverables');
    w(Fid, '');
    Files = getField(Results, "Deliverables", string.empty(1, 0));
    if isempty(Files)
        w(Fid, '_Delivery phase not recorded._');
        w(Fid, '');
        return;
    end
    % Iterate a ROW: `for` walks columns, so a column string array would bind
    % the whole vector to `f` in a single pass (char() then pads it to a matrix
    % that %s reads column-major -> interleaved mush). Force a row vector.
    Files = string(Files);
    Files = Files(:).';
    for f = Files
        w(Fid, '- `%s`', char(f));
    end
    w(Fid, '');
end


function writeAppendix(Fid, Results)
%writeAppendix The complete, untruncated tables the body chapters only preview.
%   The chapters cap their vote and stability tables at a readable window; this
%   appendix carries them at full length so nothing shown in a plot or a windowed
%   table is lost from the report. The same data is also in the results .mat (named
%   here), the machine-readable form. Nothing new is computed -- these are the same
%   structs, rendered whole.
    HasVote = isfield(Results, 'VoteTable') && istable(Results.VoteTable) ...
        && ~isempty(Results.VoteTable);
    HasSel = hasFreq(Results, 'SelStab');
    HasGen = hasFreq(Results, 'GenStab');
    if ~HasVote && ~HasSel && ~HasGen
        return;
    end
    w(Fid, '## Appendix A. Complete tables');
    w(Fid, '');
    w(Fid, ['The body chapters above show a readable top slice of each table. This ' ...
        'appendix lists them in full. The same values, plus every other run result, ' ...
        'are in `%s` — load it and read `Results` (e.g. `Results.VoteTable`, ' ...
        '`Results.SelStab.SelectionFrequency`).'], char(resultsMatName(Results)));
    w(Fid, '');

    if HasVote
        writeFullVoteTable(Fid, Results.VoteTable);
    end
    if HasSel || HasGen
        writeFullFreqTable(Fid, Results, HasSel, HasGen);
    end
end


function Tf = hasFreq(Results, Field)
%hasFreq True when a stability read carries a non-empty SelectionFrequency table.
    Tf = isfield(Results, Field) && isstruct(Results.(Field)) ...
        && isfield(Results.(Field), 'SelectionFrequency') ...
        && istable(Results.(Field).SelectionFrequency) ...
        && ~isempty(Results.(Field).SelectionFrequency);
end


function writeFullVoteTable(Fid, V)
%writeFullVoteTable The consensus vote table, every row, in rank order.
    if ismember("Rank", string(V.Properties.VariableNames))
        V = sortrows(V, "Rank");
    end
    HasSel = ismember("Selected", string(V.Properties.VariableNames));
    w(Fid, '### A1. Consensus vote — full (%d features)', height(V));
    w(Fid, '');
    Rows = cell(height(V), 4);
    for i = 1:height(V)
        Rows{i, 1} = char(string(V.Feature(i)));
        Rows{i, 2} = fmtQuality(double(V.Score(i)));
        Rows{i, 3} = sprintf('%d', V.Rank(i));
        if HasSel
            Rows{i, 4} = tickMark(V.Selected(i));
        else
            Rows{i, 4} = '';
        end
    end
    mdTable(Fid, {'Feature', 'Consensus score', 'Rank', 'Selected'}, Rows);
    w(Fid, '');
end


function writeFullFreqTable(Fid, Results, HasSel, HasGen)
%writeFullFreqTable The per-feature re-selection frequency, every row, one column
%   per stability read that ran: the fixed-pool read (rows resampled, pool held
%   fixed) and the generation read (rows resampled AND the pool regenerated). When
%   both ran they share one table so the fixed -> regenerated drop is visible per
%   feature; when only one ran the table has that single column. Features are the
%   union of both reads, ordered by fixed-pool frequency (then generation) so the
%   most reliably re-selected sit at the top; a feature a read never saw prints "—".
%   No status column -- the body chapter carries the floor/core tie-back; this is
%   the raw complete list.
    if HasSel && HasGen
        Title = '### A2. Selection frequency — full (fixed pool and regenerated pool)';
        Header = {'Feature', 'Fixed pool', 'Regenerated pool'};
    elseif HasSel
        Title = '### A2. Selection frequency — full (fixed pool)';
        Header = {'Feature', 'Re-selected in'};
    else
        Title = '### A2. Selection frequency — full (generation, pool regenerated)';
        Header = {'Feature', 'Re-selected in'};
    end
    w(Fid, Title);
    w(Fid, '');

    [Feats, SelFreq, GenFreq] = mergeFreq(Results, HasSel, HasGen);
    NCol = numel(Header);
    Rows = cell(numel(Feats), NCol);
    for i = 1:numel(Feats)
        Rows{i, 1} = char(Feats(i));
        if HasSel && HasGen
            Rows{i, 2} = pctOrDash(SelFreq(i));
            Rows{i, 3} = pctOrDash(GenFreq(i));
        elseif HasSel
            Rows{i, 2} = pctOrDash(SelFreq(i));
        else
            Rows{i, 2} = pctOrDash(GenFreq(i));
        end
    end
    mdTable(Fid, Header, Rows);
    w(Fid, '');
end


function [Feats, SelFreq, GenFreq] = mergeFreq(Results, HasSel, HasGen)
%mergeFreq Align the two reads' SelectionFrequency tables onto one feature list.
%   Feats is the union (fixed-pool order first, then any generation-only features);
%   SelFreq/GenFreq are NaN where a read never saw that feature.
    SelTbl = table(string.empty(0, 1), [], VariableNames={'Feature','Frequency'});
    GenTbl = SelTbl;
    if HasSel
        SelTbl = Results.SelStab.SelectionFrequency;
    end
    if HasGen
        GenTbl = Results.GenStab.SelectionFrequency;
    end
    SelFeats = string(SelTbl.Feature);
    GenFeats = string(GenTbl.Feature);
    Feats = [SelFeats(:); setdiff(GenFeats(:), SelFeats(:), 'stable')];
    SelFreq = lookupFreq(SelTbl, Feats);
    GenFreq = lookupFreq(GenTbl, Feats);
end


function Freq = lookupFreq(Tbl, Feats)
%lookupFreq Frequency for each name in Feats, NaN when the table lacks it.
    Freq = nan(numel(Feats), 1);
    if isempty(Tbl)
        return;
    end
    [Tf, Loc] = ismember(Feats, string(Tbl.Feature));
    Freq(Tf) = double(Tbl.Frequency(Loc(Tf)));
end


function Str = pctOrDash(Frac)
%pctOrDash A frequency as a percent, or an em dash when the read never saw it.
    if isnan(Frac)
        Str = '—';
    else
        Str = sprintf('%.0f%%', 100 * Frac);
    end
end


% ------------------------------------------------------------- small helpers


function Name = resultsMatName(Results)
%resultsMatName The fe_results_<dataset>.mat file name, matching saveResults'
%   stem rule, so the report's pointers name the exact file on disk.
    DS = getField(Results, "DatasetName", "dataset");
    Name = "fe_results_" + matlab.lang.makeValidName(string(DS)) + ".mat";
end

function Suffix = imbalanceSuffix(CB)
    if isfield(CB, 'ImbalanceRatio') && ~isnan(CB.ImbalanceRatio)
        Suffix = sprintf(' (imbalance ratio %.1f:1)', CB.ImbalanceRatio);
    else
        Suffix = '';
    end
end


function Str = fmtMeanStd(S)
%fmtMeanStd Format a Mean/Std sub-struct as "mean +/- std".
    if isstruct(S) && isfield(S, 'Mean') && isfield(S, 'Std')
        Str = sprintf('%.3f +/- %.3f', S.Mean, S.Std);
    elseif isnumeric(S) && isscalar(S)
        Str = fmtQuality(S);
    else
        Str = 'n/a';
    end
end


function Str = fmtSigned(X)
    if isnan(X)
        Str = 'n/a';
    else
        Str = sprintf('%+.3f', X);
    end
end


function Gloss = nogueiraGloss(Value)
    if isnan(Value)
        Gloss = '';
    elseif Value >= 0.75
        Gloss = '(highly stable across folds)';
    elseif Value >= 0.4
        Gloss = '(moderately stable)';
    else
        Gloss = '(unstable: selection varies substantially across folds)';
    end
end


function Out = joinNames(Names)
    Names = string(Names);
    if isempty(Names)
        Out = "(none)";
    else
        Out = strjoin(Names, ", ");
    end
end


function Str = tickMark(Tf)
    if logical(Tf)
        Str = 'yes';
    else
        Str = '';
    end
end


function Label = familyLabel(Family)
    switch string(Family)
        case "linear"
            Label = "Linear";
        case "kernel"
            Label = "Kernel (KernelScale=auto)";
        case "bag"
            Label = "Random Forest";
        otherwise
            Label = string(Family);
    end
end


function Val = getField(S, Name, Default)
    if isstruct(S) && isfield(S, Name)
        Val = S.(Name);
    else
        Val = Default;
    end
end


function Val = fieldOr(S, Name, Default)
    Val = getField(S, Name, Default);
end


function Recipe = getRecipe(Results)
%getRecipe The opaque pool recipe to pass to describeFeatures.
%   Prefers an explicit .Recipe (a domain recipe struct); falls back to
%   .Transformer (an SMLT FeatureTransformer, which IS its own recipe). Returns
%   [] when neither is present, so the caller can degrade gracefully.
    if isfield(Results, 'Recipe') && ~isempty(Results.Recipe)
        Recipe = Results.Recipe;
    elseif isfield(Results, 'Transformer') && ~isempty(Results.Transformer)
        Recipe = Results.Transformer;
    else
        Recipe = [];
    end
end


% ----------------------------------- salvaged mechanical helpers (ctx-free)

function w(Fid, Fmt, varargin)
    if nargin > 2
        fprintf(Fid, [Fmt '\n'], varargin{:});
    else
        fprintf(Fid, '%s\n', Fmt);
    end
end


function mdTable(Fid, Headers, Data)
    NCols = numel(Headers);
    HeaderLine = strjoin(cellfun(@(h) [' ' h ' '], Headers, UniformOutput=false), '|');
    fprintf(Fid, '|%s|\n', HeaderLine);
    SepParts = repmat({'---'}, 1, NCols);
    SepLine = strjoin(cellfun(@(s) [' ' s ' '], SepParts, UniformOutput=false), '|');
    fprintf(Fid, '|%s|\n', SepLine);
    for r = 1:size(Data, 1)
        Row = cell(1, NCols);
        for c = 1:NCols
            Val = Data{r, c};
            if isstring(Val), Val = char(Val); end
            if isnumeric(Val), Val = sprintf('%g', Val); end
            if ~ischar(Val), Val = char(string(Val)); end
            Val = strrep(Val, '|', '\|');
            Val = strrep(Val, newline, ' ');
            Row{c} = [' ' Val ' '];
        end
        fprintf(Fid, '|%s|\n', strjoin(Row, '|'));
    end
end


function mdFigure(Fid, OutputDir, FileName, Caption, Description)
    if strlength(string(OutputDir)) == 0
        return;   % embedding suppressed (Options.EmbedFigures false)
    end
    FigPath = fullfile(OutputDir, FileName);
    if isfile(FigPath)
        fprintf(Fid, '\n### %s\n\n', Caption);
        if nargin >= 5 && strlength(Description) > 0
            fprintf(Fid, '%s\n\n', Description);
        end
        fprintf(Fid, '![%s](%s)\n\n', Caption, FileName);
    end
end


function Str = formattedNumber(N)
    RawStr = sprintf('%d', N);
    NDigits = numel(RawStr);
    if NDigits <= 3
        Str = RawStr;
        return;
    end
    Parts = strings(0);
    while NDigits > 3
        Parts = [string(RawStr(NDigits-2:NDigits)), Parts]; %#ok<AGROW>
        RawStr = RawStr(1:NDigits-3);
        NDigits = numel(RawStr);
    end
    Parts = [string(RawStr), Parts];
    Str = char(join(Parts, ","));
end


function Str = fmtQuality(X)
    if isnan(X)
        Str = 'n/a';
    else
        Str = sprintf('%.3f', X);
    end
end


function Rows = modelFreeQualityRows(Q)
%modelFreeQualityRows Original-vs-engineered rows for the model-free panel.
    Rel = Q.Relevance;
    Red = Q.Redundancy;
    Comp = Q.Compactness;
    Rows = {
        'Peak relevance (max MI with response)', ...
            fmtQuality(Rel.MaxOriginal), fmtQuality(Rel.MaxEngineered);
        sprintf('Relevant features (MI >= %.2f)', Rel.Threshold), ...
            sprintf('%d', Rel.NumRelevantOriginal), sprintf('%d', Rel.NumRelevantEngineered);
        'Redundancy (mean pairwise MI)', ...
            fmtQuality(Red.MeanPairwiseMIOriginal), fmtQuality(Red.MeanPairwiseMIEngineered);
        'Redundancy (max pairwise MI, worst pair)', ...
            fmtQuality(Red.MaxPairwiseMIOriginal), fmtQuality(Red.MaxPairwiseMIEngineered);
        'Feature count', ...
            sprintf('%d', Comp.NumFeaturesOriginal), sprintf('%d', Comp.NumFeaturesEngineered);
        'Effective dimensionality', ...
            fmtQuality(Comp.EffectiveDimOriginal), fmtQuality(Comp.EffectiveDimEngineered)};
end


function Label = baselineLensLabel(Baseline)
%baselineLensLabel Human-readable label for the primary baseline model lens.
    if isfield(Baseline, 'Primary')
        Primary = Baseline.Primary;
    else
        Primary = "bag";
    end
    if isfield(Baseline, 'TargetModel')
        TargetModel = Baseline.TargetModel;
    else
        TargetModel = "agnostic";
    end
    PrimaryLabel = familyLabel(Primary);
    if TargetModel == "agnostic"
        % Under agnostic the primary defaults to the bagged ensemble; any other
        % value can only have come from an explicit user choice of lens, so name
        % it a choice rather than the default.
        if Primary == "bag"
            Label = sprintf("%s (model-agnostic default)", PrimaryLabel);
        else
            Label = sprintf("%s (chosen primary lens; model-agnostic panel)", PrimaryLabel);
        end
    else
        Label = sprintf("%s (declared: %s)", PrimaryLabel, TargetModel);
    end
end


function Name = voterLongName(Method)
%voterLongName Spelled-out name for a consensus voter method.
    switch string(Method)
        case "borda"
            Name = "Borda count";
        case "rrf"
            Name = "Reciprocal-rank fusion";
        case "majority"
            Name = "Majority vote";
        otherwise
            Name = string(Method);
    end
end
