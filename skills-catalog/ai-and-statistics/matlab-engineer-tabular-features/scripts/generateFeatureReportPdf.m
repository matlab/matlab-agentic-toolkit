function ReportPath = generateFeatureReportPdf(Results, OutputDir, Options)
%generateFeatureReportPdf PDF report over the lean feature-engineering run.
%
%   ReportPath = generateFeatureReportPdf(Results, OutputDir) renders the same
%   content as generateFeatureReport (the Markdown report) as a PDF via MATLAB
%   Report Generator, writing <OutputDir>/feature_report.pdf and returning its
%   path. It is the toolbox-gated companion to the always-on Markdown report:
%   when Report Generator is unavailable it errors with the id
%   generateFeatureReportPdf:reportGeneratorUnavailable so the orchestrator can
%   skip it gracefully (try/catch) and keep only the Markdown output.
%
%   Results is the same plain struct generateFeatureReport consumes (see that
%   function's help for the field contract). .SelStab (fixed-pool selection
%   stability) and .GenStab (generation-variance stability) are each an
%   independent opt-in -- when .SelStab is absent, the chapter says "not
%   requested" if .StabilitySkipped is true, else "not recorded". Performance
%   comes from .Baseline (holdout point estimate) and/or .KFold (cross_validated
%   mean/std headline); .Quality and .Deliverables render as before.
%
%   Options.FileName     (1,1) string  = "feature_report.pdf"
%   Options.EmbedFigures (1,1) logical = true   include figures if PNGs exist
%
%   The PDF is generated under tempdir and copied to OutputDir, avoiding file
%   locks when OutputDir lives on a synced drive (e.g. OneDrive).

% Copyright 2026 The MathWorks, Inc.

    arguments
        Results (1,1) struct
        OutputDir (1,1) string
        Options.FileName (1,1) string = "feature_report.pdf"
        Options.EmbedFigures (1,1) logical = true
    end

    assertReportGenerator();

    import mlreportgen.report.*
    import mlreportgen.dom.*

    if ~isfolder(OutputDir)
        mkdir(OutputDir);
    end
    ReportPath = fullfile(OutputDir, Options.FileName);

    % Generate under tempdir then copy, so a synced OutputDir does not file-lock
    % the Report Generator's working files.
    [~, Stem] = fileparts(Options.FileName);
    TempPath = fullfile(tempdir, "ferpt_" + Stem);
    if isfolder(TempPath + "_files"), rmdir(char(TempPath + "_files"), 's'); end
    if isfile(TempPath + ".pdf"), delete(char(TempPath + ".pdf")); end

    Rpt = Report(char(TempPath), 'pdf');
    Closer = onCleanup(@() closeIfOpen(Rpt));

    addTitlePage(Rpt, Results);
    append(Rpt, TableOfContents);

    % Figures live in their owning chapters (consensus in Selection, baseline in
    % Model-Specific Baseline, stability in Selector Stability), so a section and
    % its supporting figure read together. EmbedDir is the folder to pull the
    % fig_*.svg from, or "" to suppress embedding.
    EmbedDir = "";
    if Options.EmbedFigures
        EmbedDir = OutputDir;
    end

    append(Rpt, overviewChapter(Results));
    append(Rpt, generationChapter(Results));
    append(Rpt, selectionChapter(Results, EmbedDir));
    append(Rpt, definitionsChapter(Results));
    append(Rpt, baselineChapter(Results, EmbedDir));
    append(Rpt, qualityChapter(Results));
    append(Rpt, selectorStabilityChapter(Results, EmbedDir));
    append(Rpt, deliverablesChapter(Results));
    appendAppendix(Rpt, Results);

    close(Rpt);
    clear Closer;
    copyfile(char(TempPath + ".pdf"), char(ReportPath));
    fprintf('Wrote PDF report to %s\n', ReportPath);
end


% ------------------------------------------------------------------ chapters

function addTitlePage(Rpt, Results)
    import mlreportgen.report.*
    Tp = TitlePage;
    Tp.Title = 'Feature Engineering Report';
    Name = getField(Results, "DatasetName", "dataset");
    Resp = getField(Results, "ResponseVar", "?");
    ProblemType = "";
    P = getField(Results, "Profile", struct());
    if isfield(P, 'ProblemType'), ProblemType = " (" + P.ProblemType + ")"; end
    Tp.Subtitle = char(sprintf("Dataset: %s | Response: %s%s", Name, Resp, ProblemType));
    Tp.Author = 'matlab-engineer-tabular-features skill';
    Tp.PubDate = string(datetime("today"));
    append(Rpt, Tp);
end


function Ch = overviewChapter(Results)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Overview');
    P = getField(Results, "Profile", struct());
    Rows = {'Response variable', char(getField(Results, "ResponseVar", "?"))};
    if isfield(P, 'ProblemType')
        Rows = [Rows; {'Problem type', char(P.ProblemType)}];
    end
    if isfield(P, 'NumRows')
        Rows = [Rows; {'Rows', formattedNumber(P.NumRows)}];
    end
    if isfield(Results, 'Baseline') && isfield(Results.Baseline, 'TargetModel')
        Rows = [Rows; {'Planned model family', char(Results.Baseline.TargetModel)}];
    end
    S = getField(Results, "Split", struct());
    Strategy = resolveStrategy(Results);
    Rows = [Rows; {'Evaluation strategy', char(Strategy)}];
    if isfield(S, 'TrainIdx')
        Label = 'Working rows (generation/selection)';
        if Strategy == "holdout"
            Label = 'Training rows';
        end
        Rows = [Rows; {Label, formattedNumber(numel(S.TrainIdx))}];
    end
    if isfield(S, 'TestIdx') && Strategy == "holdout"
        Rows = [Rows; {'Held-out test rows (point estimate)', formattedNumber(numel(S.TestIdx))}];
    end
    append(Ch, styledTable({'Property', 'Value'}, Rows));

    % Level-0 carve: rows set aside untouched for the user's own testing.
    R = getField(Results, "ReserveInfo", struct());
    if isfield(R, 'Reserved') && R.Reserved
        append(Ch, Paragraph(char(sprintf(...
            "Reserved for your own testing: %s rows (%.0f%%, %s) were set aside " + ...
            "untouched before the pipeline ran -- never seen by generation, " + ...
            "selection, assessment, or the final refit. Everything below is on the " + ...
            "remaining %s working rows.", formattedNumber(R.NumHeldOut), ...
            100 * R.Fraction, char(R.Method), formattedNumber(R.NumWorking)))));
    elseif isfield(R, 'Reserved')
        append(Ch, Paragraph(char(sprintf(...
            "Reserved for your own testing: none -- you supplied a separate test " + ...
            "set, so all %s rows are working data.", formattedNumber(R.NumWorking)))));
    end

    appendDataUsage(Ch, Results, Strategy);

    if isfield(P, 'ClassBalance') && isstruct(P.ClassBalance) ...
            && isfield(P.ClassBalance, 'NumClasses') && ~isnan(P.ClassBalance.NumClasses)
        CB = P.ClassBalance;
        append(Ch, Paragraph(char(sprintf(...
            "Class balance: %d classes; minority-class count %s%s.", ...
            CB.NumClasses, formattedNumber(CB.MinorityCount), imbalanceSuffix(CB)))));
        Rec = imbalanceRecommendation(CB);
        if strlength(Rec) > 0
            append(Ch, Paragraph(char(Rec)));
        end
    end
end


function appendDataUsage(Ch, Results, Strategy)
%appendDataUsage One compact table stating which rows each section uses, so the
%   graded-vs-shipped distinction is on the page. Strategy-aware: the performance
%   and stability rows differ between holdout and cross_validated. Mirrors the
%   markdown report's writeDataUsage and the technical audit's data-flow note.
    import mlreportgen.dom.*
    StabSkipped = isfield(Results, 'StabilitySkipped') && Results.StabilitySkipped;
    if Strategy == "holdout"
        PerfRow = {'Performance (Ch. 5)', 'fit on the training rows, scored on the held-out test rows (one point estimate)'};
    else
        PerfRow = {'Performance (Ch. 5)', 'k folds of the working rows: each fold regenerates + reselects on the other folds, scores the held fold (mean +/- std)'};
    end
    Rows = {
        'Graded generate + select', 'a training subset (holdout: the train block; cross-validated: each fold''s other folds) -- measured, then discarded';
        'Delivered (shipped) features', 'refit on ALL working rows -- this is what the inference recipe reproduces';
        PerfRow{:};
        'Model-free quality (Ch. 6)', 'all working rows'};
    if ~StabSkipped
        Rows(end+1, :) = {'Selection stability (Ch. 7)', 'resamples ALL working rows on the fixed pool (never scores a held slice)'};
    end
    Rows(end+1, :) = {'Reserved slice', 'untouched -- never used by any section above'};
    append(Ch, Heading3('Which rows each section uses'));
    append(Ch, styledTable({'Section', 'Rows used'}, Rows));
    append(Ch, Paragraph(char(...
        "Generation and selection run twice: a graded fit on a training subset " + ...
        "(whose held rows produce the performance number above), then a shipped " + ...
        "refit on all working rows. The reported performance therefore grades a " + ...
        "recipe trained on less data than the one delivered -- it is conservative.")));
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
        Str = sprintf(['The data is imbalanced (ratio %.1f:1). We recommend reading ' ...
            'AUC and macro-F1 rather than raw accuracy, which is favored by the ' ...
            'classes other than the minority class at this balance.'], CB.ImbalanceRatio);
    else
        Str = sprintf(['The data is roughly balanced (ratio %.1f:1), so accuracy is a ' ...
            'trustworthy read alongside AUC and macro-F1.'], CB.ImbalanceRatio);
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


function Ch = generationChapter(Results)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Generation');
    G = getField(Results, "GenInfo", struct());
    if ~isfield(G, 'PoolSize')
        append(Ch, Paragraph('No generation information available.'));
        return;
    end
    % A domain-routed pool has no SMLT TargetLearner/Standardization -- describe
    % it on its own terms (mirrors writeGeneration in generateFeatureReport.m).
    Recipe = getRecipe(Results);
    IsDomain = isstruct(Recipe) && isfield(Recipe, 'Kind') && Recipe.Kind == "domain";
    if IsDomain
        Provider = "a domain extractor";
        if isfield(Recipe, 'Provider') && strlength(string(Recipe.Provider)) > 0
            Provider = string(Recipe.Provider);
        end
        append(Ch, Paragraph(char(sprintf(['Candidate features were produced by %s ' ...
            '(a purpose-built domain extractor), not the generic SMLT generator; ' ...
            'the final set is then chosen by the consensus selection step.'], char(Provider)))));
        Rows = {
            'Candidate pool size', formattedNumber(G.PoolSize);
            'Target learner', char(targetLearnerLabel(Results));
            'Standardization', sprintf('N/A -- %s controls this', char(Provider))};
        append(Ch, styledTable({'Property', 'Value'}, Rows));
    else
        append(Ch, Paragraph(['Candidate features were generated with SMLT in ' ...
            'generate-only mode: SMLT builds the candidate pool but does not ' ...
            'choose the final set -- that is decided by the consensus selection step.']));
        Rows = {
            'Candidate pool size', formattedNumber(G.PoolSize);
            'Target learner', char(getField(G, "TargetLearner", "?"));
            'Standardization', char(getField(G, "Standardization", "?"))};
        append(Ch, styledTable({'Property', 'Value'}, Rows));
        if isfield(G, 'StandardizationReasoning') && strlength(G.StandardizationReasoning) > 0
            append(Ch, Paragraph(char("Standardization rationale: " + G.StandardizationReasoning)));
        end
    end
    if isfield(G, 'Reasoning') && strlength(G.Reasoning) > 0
        append(Ch, Paragraph(char("Dispatch: " + G.Reasoning)));
    end
end


function Label = targetLearnerLabel(Results)
%targetLearnerLabel The declared model family, spelling out the agnostic panel.
%   Mirrors the helper in generateFeatureReport.m: on the domain path there is no
%   SMLT TargetLearner, but the declared family still governs the baseline panel.
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


function Ch = selectionChapter(Results, EmbedDir)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Consensus Selection');
    PI = getField(Results, "PanelInfo", struct());
    Selected = getField(Results, "SelectedNames", string.empty(1, 0));

    if isfield(PI, 'Rankers')
        append(Ch, Paragraph(char("Ranker panel: " + joinNames(PI.Rankers))));
        if isfield(PI, 'Skipped') && ~isempty(PI.Skipped)
            append(Ch, Paragraph(char("Skipped rankers: " + joinNames(PI.Skipped))));
        end
    end

    Rows = {};
    Rows = addRow(Rows, PI, 'VoterMethod', 'Consensus voter', @(v) char(v));
    Rows = addRow(Rows, PI, 'MeanAgreement', 'Mean rank agreement', @fmtQuality);
    Rows = addRow(Rows, PI, 'PoolSize', 'Pool size', @formattedNumber);
    Rows = addRow(Rows, PI, 'NSelect', 'Features selected', @formattedNumber);
    if ~isempty(Rows)
        append(Ch, styledTable({'Property', 'Value'}, Rows));
    end

    appendSelectionCountNote(Ch, PI);

    ByUser = isfield(PI, 'VoterSelectedBy') && PI.VoterSelectedBy == "user";
    if ByUser
        % Forced by the caller -- do not attribute the choice to the agreement gate.
        if PI.VoterMethod == "majority"
            append(Ch, Paragraph(['Majority vote (order-blind top-K count) was ' ...
                'used by user override -- appropriate when the rankers'' selected ' ...
                'sets are trusted but their orderings are not (e.g. tie-heavy ' ...
                'filters).']));
        else
            append(Ch, Paragraph(char(sprintf(['%s was used by user override, ' ...
                'not chosen by the rank-agreement gate (mean agreement %s).'], ...
                voterLongName(PI.VoterMethod), fmtQuality(PI.MeanAgreement)))));
        end
    elseif isfield(PI, 'VoterMethod') && PI.VoterMethod == "borda"
        append(Ch, Paragraph(['Borda count was used because mean rank agreement ' ...
            'met the consensus threshold (rankers largely concur).']));
    elseif isfield(PI, 'VoterMethod') && PI.VoterMethod == "rrf"
        append(Ch, Paragraph(['Reciprocal-rank fusion was used because rankers ' ...
            'disagreed (low mean agreement), so top-rank consensus is weighted ' ...
            'over aggregate position.']));
    end

    if isfield(PI, 'Excluded') && ~isempty(PI.Excluded)
        append(Ch, Paragraph(char("Excluded from the pool before voting: " + joinNames(PI.Excluded))));
    end

    appendVoteTable(Ch, Results);

    append(Ch, Paragraph(char(sprintf("Selected feature set (%d): %s", ...
        numel(Selected), joinNames(Selected)))));
    if isfield(PI, 'Reasoning') && strlength(PI.Reasoning) > 0
        append(Ch, Paragraph(char(PI.Reasoning)));
    end

    embedFigure(Ch, EmbedDir, 'fig_selection_consensus.svg', 'Consensus selection');
    embedFigure(Ch, EmbedDir, 'fig_selection_decision.svg', ...
        'Selection decision: consensus-score elbow with the cut (stability audited in the Selector Stability chapter)');
    appendSelectionGlossary(Ch, Results);
end


function appendSelectionCountNote(Ch, PI)
%appendSelectionCountNote State what set the delivered count (PDF mirror of the
%   markdown writeSelectionCountNote): the score elbow, or a full-pool keep-all
%   when the score curve had no elbow. Silent only when the fields the note needs
%   are absent.
    import mlreportgen.dom.*
    if ~isfield(PI, 'NSelect')
        return;
    end
    if isfield(PI, 'PoolSize') && PI.NSelect >= PI.PoolSize
        Txt = "No elbow -- the full pool was kept. The consensus scores declined " + ...
            "too gradually to mark a cut (no point falls below the chord joining the " + ...
            "first and last candidate), so every feature was retained. Read this as " + ...
            """the candidates are comparably useful,"" not as a failure to select.";
    else
        Txt = sprintf(...
            "The score elbow set this count. The consensus curve's elbow fell at %d " + ...
            "features, so the delivered count reflects where the fused scores stop " + ...
            "paying off.", PI.NSelect);
    end
    P = Paragraph(char(Txt));
    P.Style = {Bold(false)};
    append(Ch, P);
end


function appendSelectionGlossary(Ch, Results)
%appendSelectionGlossary A little dictionary of the selection terms used above.
%   Present-tense definitions only, and only for terms this run actually shows.
%   Each method leads with its acronym in UPPER CASE and its spelled-out name.
    import mlreportgen.dom.*
    PI = getField(Results, "PanelInfo", struct());

    % Ranking methods actually in the panel, keyed by the short code the tables use.
    Methods = strings(0, 1);
    if isfield(PI, 'Rankers')
        R = string(PI.Rankers);
        Defs = [ ...
            "mrmr",  "MRMR (Minimum Redundancy, Maximum Relevance) -- ranks features high when they track the response but duplicate each other little."; ...
            "oob",   "OOB (Out-Of-Bag importance) -- permutation importance from a bagged tree ensemble; how much prediction error rises when a feature is shuffled."; ...
            "nca",   "NCA (Neighbourhood Component Analysis) -- learns per-feature weights that make same-class points nearest neighbours."; ...
            "lasso", "LASSO (Least Absolute Shrinkage and Selection Operator) -- an L1-penalised linear fit; ranks features by how long their coefficient survives as the penalty tightens."; ...
            "chi2",  "Chi-Square filter -- tests each feature's association with a categorical response."; ...
            "ftest", "F-Test filter -- ranks features by the strength of its univariate association with the response."];
        for i = 1:size(Defs, 1)
            if any(contains(R, Defs(i, 1)))
                Methods(end+1, 1) = Defs(i, 2); %#ok<AGROW>
            end
        end
    end

    % Concepts: the fusion voter in play.
    Terms = strings(0, 1);
    if isfield(PI, 'VoterMethod')
        switch string(PI.VoterMethod)
            case "borda"
                Terms(end+1, 1) = "Borda count -- fuses the ranker lists by " + ...
                    "summing each feature's position across them.";
            case "rrf"
                Terms(end+1, 1) = "RRF (Reciprocal-Rank Fusion) -- fuses the ranker " + ...
                    "lists by summing 1/(k+rank), so top-of-list agreement outweighs " + ...
                    "aggregate position.";
            case "majority"
                Terms(end+1, 1) = "Majority vote -- keeps features that most " + ...
                    "rankers place in their own top set (order-blind).";
        end
    end

    append(Ch, Heading2('Glossary'));
    if ~isempty(Methods)
        append(Ch, Paragraph('Ranking methods in the panel (each scores the pool; the voter fuses them):'));
        MethodList = UnorderedList();
        for i = 1:numel(Methods)
            append(MethodList, ListItem(char(Methods(i))));
        end
        append(Ch, MethodList);
    end
    if ~isempty(Terms)
        append(Ch, Paragraph('Fusion terms:'));
        TermList = UnorderedList();
        for i = 1:numel(Terms)
            append(TermList, ListItem(char(Terms(i))));
        end
        append(Ch, TermList);
    end
end


function appendVoteTable(Ch, Results)
    import mlreportgen.dom.*
    if ~isfield(Results, 'VoteTable') || ~istable(Results.VoteTable) || isempty(Results.VoteTable)
        return;
    end
    V = Results.VoteTable;
    if ismember("Rank", string(V.Properties.VariableNames))
        V = sortrows(V, "Rank");
    end
    [Data, NTotal, NShown, NOmitted] = voteRowsToShow(V);
    append(Ch, Paragraph(char(sprintf("Consensus vote (top %d of %d):", NShown, NTotal))));
    append(Ch, styledTable({'Feature', 'Consensus score', 'Rank', 'Selected'}, Data));
    if NOmitted > 0
        append(Ch, Paragraph(char(sprintf(['%d further features omitted here; the ' ...
            'complete vote table is in the appendix and in %s.'], ...
            NOmitted, resultsMatName(Results)))));
    end
end


function [Data, NTotal, NShown, NOmitted] = voteRowsToShow(V)
%voteRowsToShow See generateFeatureReport.m/voteRowsToShow -- same rule (top
%   max(20, #selected) by rank, never hide a selected feature), returning DOM-ready
%   {Feature, Consensus score, Rank, Selected} rows. The complete table is in the
%   appendix + results .mat.
    NTotal = height(V);
    HasSel = ismember("Selected", string(V.Properties.VariableNames));
    if HasSel
        IsSel = logical(V.Selected);
    else
        IsSel = false(NTotal, 1);
    end
    Window = max(20, sum(IsSel));
    Keep = IsSel;
    Keep(1:min(Window, NTotal)) = true;
    Idx = find(Keep);
    NShown = numel(Idx);
    NOmitted = NTotal - NShown;
    Data = cell(NShown, 4);
    for r = 1:NShown
        i = Idx(r);
        Data{r, 1} = char(string(V.Feature(i)));
        Data{r, 2} = fmtQuality(double(V.Score(i)));
        Data{r, 3} = sprintf('%d', V.Rank(i));
        if HasSel
            Data{r, 4} = tickMark(V.Selected(i));
        else
            Data{r, 4} = '';
        end
    end
end


function Ch = definitionsChapter(Results)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Selected Feature Definitions');
    Selected = string(getField(Results, "SelectedNames", string.empty(1, 0)));
    if isempty(Selected)
        append(Ch, Paragraph('No features selected.'));
        return;
    end
    Recipe = getRecipe(Results);
    if isempty(Recipe)
        append(Ch, Paragraph('Recipe unavailable; feature definitions not shown.'));
        return;
    end
    % describeFeatures returns the already-normalized, generator-agnostic
    % Feature | Type | Definition table (all string columns) for exactly the
    % selected features, in order, whatever produced the pool.
    D = describeFeatures(Recipe, Selected);
    Data = cell(height(D), 3);
    for i = 1:height(D)
        Data(i, :) = {D.Feature(i), D.Type(i), D.Definition(i)};
    end
    append(Ch, styledTable({'Feature', 'Type', 'Definition'}, Data));
end


function Ch = baselineChapter(Results, EmbedDir)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Performance');
    Strategy = resolveStrategy(Results);
    if Strategy == "cross_validated"
        appendKFoldPerformance(Ch, Results, EmbedDir);
        appendConservativeCaveat(Ch, Strategy);
        return;
    end
    if ~isfield(Results, 'Baseline') || ~isfield(Results.Baseline, 'Panel')
        append(Ch, Paragraph('No performance read available.'));
        return;
    end
    B = Results.Baseline;
    append(Ch, Paragraph(char("Point estimate on the held-out test rows (single " + ...
        "split, so no error bars). Downstream lens: " + baselineLensLabel(B) + ".")));
    Metric = char(getField(B, "Metric", "metric"));
    Panel = B.Panel;
    Data = cell(numel(Panel), 5);
    for i = 1:numel(Panel)
        FR = Panel(i);
        Data{i, 1} = char(familyLabel(FR.Family));
        Data{i, 2} = fmtQuality(FR.Naive);
        Data{i, 3} = fmtQuality(FR.Original);
        Data{i, 4} = fmtQuality(FR.Engineered);
        Data{i, 5} = fmtSigned(FR.Improvement);
    end
    append(Ch, styledTable({'Family', ['Naive (' Metric ')'], 'Original', ...
        'Engineered', 'Improvement (eng-orig)'}, Data));

    % Supplementary classification metrics. Macro-F1 and accuracy are always
    % reported; when the response is imbalanced (AccuracyReliable=false, ratio
    % > 1.5:1) accuracy is kept but flagged unreliable rather than hidden, so the
    % reader decides whether to trust it. AUC above is the primary metric.
    if strcmp(Metric, 'auc')
        AccuracyReliable = ~isfield(Panel(1), 'AccuracyReliable') || Panel(1).AccuracyReliable;
        SupHead = {'Family', 'Macro-F1 (orig)', 'Macro-F1 (eng)', ...
            'Accuracy (orig)', 'Accuracy (eng)'};
        SupData = cell(numel(Panel), 5);
        for i = 1:numel(Panel)
            FR = Panel(i);
            SupData{i, 1} = char(familyLabel(FR.Family));
            SupData{i, 2} = fmtQuality(FR.MacroF1.Original);
            SupData{i, 3} = fmtQuality(FR.MacroF1.Engineered);
            SupData{i, 4} = fmtQuality(FR.Accuracy.Original);
            SupData{i, 5} = fmtQuality(FR.Accuracy.Engineered);
        end
        append(Ch, Paragraph('Supplementary classification metrics:'));
        append(Ch, styledTable(SupHead, SupData));
        if ~AccuracyReliable
            append(Ch, Paragraph(['Accuracy above is unreliable: the response is ' ...
                'imbalanced (ratio > 1.5:1), where a raw hit-rate is favored by ' ...
                'the classes other than the minority class. AUC (the primary ' ...
                'metric) and macro-F1 are the metrics to trust.']));
        end
    end

    % No collapsed engineered-vs-{naive,original} verdict here: whether
    % engineering helps is model-dependent, so the per-family table above is the
    % read, not a single headline-family yes/no that reads as holding for every model.

    embedFigure(Ch, EmbedDir, 'fig_validation_baseline.svg', 'Validation baseline');
    appendConservativeCaveat(Ch, "holdout");
end


function appendKFoldPerformance(Ch, Results, EmbedDir)
%appendKFoldPerformance Chapter-5 performance under cross_validated: the k-fold
%   mean +/- std headline (no held-out slice, so no point estimate). Under agnostic
%   the panel spans all trained families (bag/linear/kernel), one row per family; a
%   declared model is a single row.
    import mlreportgen.dom.*
    if ~isfield(Results, 'KFold') || ~isstruct(Results.KFold) ...
            || ~isfield(Results.KFold, 'Performance')
        append(Ch, Paragraph('No cross-validated performance read available.'));
        return;
    end
    KF = Results.KFold;
    Perf = KF.Performance;
    MetricName = char(getField(KF, "MetricName", "metric"));
    append(Ch, Paragraph(char(sprintf(...
        "Cross-validated: the whole generate -> select pipeline is re-run per fold " + ...
        "(the pool is regenerated each time), so performance is reported as mean " + ...
        "+/- std across %d folds -- the honest end-to-end variance a single split " + ...
        "hides.", getField(KF, "K", 0)))));

    Panel = kfoldPanel(Perf);

    Data = cell(numel(Panel), 5);
    for i = 1:numel(Panel)
        FP = Panel(i);
        Data{i, 1} = char(familyLabel(FP.Family));
        Data{i, 2} = fmtMeanStd(FP.Naive);
        Data{i, 3} = fmtMeanStd(FP.Original);
        Data{i, 4} = fmtMeanStd(FP.Engineered);
        Data{i, 5} = fmtMeanStd(FP.Improvement);
    end
    append(Ch, styledTable({'Family', ['Naive (' MetricName ')'], 'Original', ...
        'Engineered', 'Improvement (eng-orig)'}, Data));

    if strcmp(MetricName, 'auc')
        SupData = cell(numel(Panel), 5);
        for i = 1:numel(Panel)
            FP = Panel(i);
            SupData{i, 1} = char(familyLabel(FP.Family));
            SupData{i, 2} = fmtMeanStd(kfoldSecondaryFor(FP, "macro-F1", "Original"));
            SupData{i, 3} = fmtMeanStd(kfoldSecondaryFor(FP, "macro-F1", "Engineered"));
            SupData{i, 4} = fmtMeanStd(kfoldSecondaryFor(FP, "accuracy", "Original"));
            SupData{i, 5} = fmtMeanStd(kfoldSecondaryFor(FP, "accuracy", "Engineered"));
        end
        append(Ch, Paragraph('Supplementary classification metrics (mean +/- std):'));
        append(Ch, styledTable({'Family', 'Macro-F1 (orig)', 'Macro-F1 (eng)', ...
            'Accuracy (orig)', 'Accuracy (eng)'}, SupData));
    end

    if nargin >= 3
        embedFigure(Ch, EmbedDir, 'fig_validation_baseline.svg', 'Validation baseline');
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


function appendConservativeCaveat(Ch, Strategy)
%appendConservativeCaveat The shipped recipe is refit on ALL working data, so the
%   estimate grades a recipe trained on less data than the one delivered.
    import mlreportgen.dom.*
    if Strategy == "holdout"
        Detail = ['the estimate above used the training rows only, while the ' ...
            'delivered recipe is refit on all working rows (training + the held-out ' ...
            'slice)'];
    else
        Detail = ['each fold trained on a subset of the working rows, while the ' ...
            'delivered recipe is refit on all working rows'];
    end
    append(Ch, Paragraph(char("Conservative by construction: " + Detail + ...
        ". The delivered feature set is therefore at least as good as this estimate " + ...
        "suggests.")));
end


function Ch = qualityChapter(Results)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Model-Free Quality');
    if ~isfield(Results, 'Quality') || ~isstruct(Results.Quality)
        append(Ch, Paragraph('No model-free quality panel available.'));
        return;
    end
    Q = Results.Quality;
    append(Ch, styledTable({'Dimension', 'Original', 'Engineered'}, modelFreeQualityRows(Q)));
    if isfield(Q, 'Verdicts')
        Verds = struct2cell(Q.Verdicts);
        Bullets = cellfun(@(v) char(string(v)), Verds, UniformOutput=false);
        append(Ch, UnorderedList(Bullets));
    end
    appendQualityStability(Ch, Results);
end


function appendQualityStability(Ch, Results)
%appendQualityStability Section 6b: per-fold engineered-side quality band, a
%   property of the recipe as a procedure. Cross-validated strategy only.
    import mlreportgen.dom.*
    if ~isfield(Results, 'KFold') || ~isstruct(Results.KFold) ...
            || ~isfield(Results.KFold, 'QualityStability')
        return
    end
    QS = Results.KFold.QualityStability;
    append(Ch, Heading(3, 'Quality consistency across folds (cross-validated)'));
    append(Ch, Paragraph(char(sprintf(['How much the engineered set''s model-free ' ...
        'quality varies as the recipe is refit across folds — a property of the ' ...
        'procedure, not the shipped set above. Each read is the engineered side on ' ...
        'that fold''s training rows, mean +/- std across %d folds.'], Results.KFold.K))));
    append(Ch, styledTable({'Dimension', 'Engineered (mean +/- std)'}, {
        'Peak relevance (max MI with response)', fmtMeanStd(QS.MaxRelevance);
        'Relevant features (above threshold)', fmtMeanStd(QS.NumRelevant);
        'Redundancy (mean pairwise MI)', fmtMeanStd(QS.MeanRedundancy);
        'Redundancy (max pairwise MI, worst pair)', fmtMeanStd(QS.MaxRedundancy);
        'Effective dimensionality', fmtMeanStd(QS.EffectiveDim)}));
end


function Ch = selectorStabilityChapter(Results, EmbedDir)
%selectorStabilityChapter Fixed-pool selection stability + the separately opted-in
%   generation-variance read, plus their Nogueira gap = generation variance. Each
%   read is its own opt-in. Resampling grades the procedure; never the shipped set.
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Selector Stability (diagnostic)');

    HasFixedPool = isfield(Results, 'SelStab') && isstruct(Results.SelStab);
    HasGenStab = isfield(Results, 'GenStab') && isstruct(Results.GenStab);
    SkippedByRequest = isfield(Results, 'StabilitySkipped') && Results.StabilitySkipped;

    % No read ran: one line, no explainer and no figure.
    if ~HasFixedPool && ~HasGenStab
        if SkippedByRequest
            append(Ch, Paragraph('Selection stability analysis skipped per user request.'));
        else
            append(Ch, Paragraph('Selection stability analysis was not recorded.'));
        end
        return;
    end

    % A labeled "how to read" note: everything here is fixed methodology, the same
    % on every run. The shaded aside sets it apart from the run-specific findings
    % (Nogueira values, feature tiers, tables) that follow below.
    append(Ch, methodologyNote('How to read this section.', ...
        ['The question here is simple: if you had trained on a slightly ' ...
        'different set of rows, would the selector have picked the same features? ' ...
        'This section grades how repeatable the selection is -- not the feature set ' ...
        'you are shipping, which is the one picked on your full data. ' ...
        'How it is measured: we take many random subsamples of your training rows, ' ...
        're-run the selection on each, and see how often the same features come ' ...
        'back. For classification the subsamples keep your original class balance, ' ...
        'and very large datasets are trimmed first so this stays affordable. Each ' ...
        'part below says how many subsamples it used and how big they were. ' ...
        'The Nogueira index boils all that agreement down to one number: 1.0 means ' ...
        'every subsample picked exactly the same features, around 0 means they ' ...
        'agreed no more than random chance would, and it can dip slightly below ' ...
        'zero. Rule of thumb: 0.75 and up is very stable, 0.4-0.75 is moderate, ' ...
        'below 0.4 is shaky.']));

    Shipped = string(getField(Results, "SelectedNames", string.empty(1, 0)));
    Floor = 0.5;   % same reference the figure and the fragile warning use
    if HasFixedPool
        appendFixedPool(Ch, Results.SelStab, Shipped, Floor);
    end

    if HasGenStab
        appendGenStab(Ch, Results.GenStab, Shipped, Floor);
        if HasFixedPool
            appendStabilityGap(Ch, Results.SelStab, Results.GenStab);
        end
    end

    % Single-panel stability figure (the decision elbow lives in the Consensus
    % Selection chapter now); embed at full text width with its caption strip.
    embedFigure(Ch, EmbedDir, 'fig_selection_stability.svg', ...
        'Selection stability: per-feature re-selection frequency, in the same consensus-rank order as the decision elbow', ...
        '15cm');
end


function appendFixedPool(Ch, Sel, Shipped, Floor)
%appendFixedPool Fixed-pool selection stability (opt-in).
    import mlreportgen.dom.*
    append(Ch, Heading2('Selection stability (fixed pool)'));
    append(Ch, methodologyNote('What this part checks.', ...
        ['It keeps the engineered features fixed and only re-runs the selection on ' ...
        'different subsamples of rows. So it tells you how much the selector''s ' ...
        'choices wobble when the training rows change, on its own. The subsamples ' ...
        'are drawn the same way every run, so these numbers reproduce exactly.']));
    if isfield(Sel, 'Nogueira')
        append(Ch, metricHeadline(sprintf("Fixed-pool Nogueira index: %s %s", ...
            fmtQuality(Sel.Nogueira), nogueiraGloss(Sel.Nogueira))));
        append(Ch, Paragraph(['The pool is held fixed and only selection re-runs, ' ...
            'so this measures selector sensitivity to row noise alone.']));
    end
    if isfield(Sel, 'CoreFeatures') && ~isempty(Sel.CoreFeatures)
        append(Ch, Paragraph(char(sprintf("Reliably re-selected (the consensus " + ...
            "core, picked in at least %.0f%% of subsamples): %s", ...
            100 * coreThreshold(Sel), joinNames(Sel.CoreFeatures)))));
    end
    % Reliable -> mid-band -> fragile, so all three tiers of shipped features read
    % together, before the backing table splits them apart by frequency.
    appendMidBand(Ch, Sel, Shipped, Floor);
    appendFragileWarning(Ch, Sel, Shipped, Floor, 'resample');
    if isfield(Sel, 'SelectionFrequency') && istable(Sel.SelectionFrequency) ...
            && ~isempty(Sel.SelectionFrequency)
        appendFreqTable(Ch, Sel.SelectionFrequency, Shipped, Floor, coreThreshold(Sel));
    end
end


function appendFragileWarning(Ch, Sel, Shipped, Floor, Kind)
%appendFragileWarning Flag shipped features re-selected below FLOOR in one stability
%   read (PDF mirror of writeFragileWarning). A warning only -- nothing is removed.
%   KIND names the resampling ('resample' fixed pool, 'regenerated-pool' generation)
%   so the two reads' warnings do not read as duplicates. The generation read is
%   scoped to features still in the regenerated pool; drop-outs are the drift table.
    import mlreportgen.dom.*
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
        append(Ch, Paragraph(char(sprintf("Fragile shipped picks: none -- every " + ...
            "shipped feature cleared the %.0f%% %s floor.", 100 * Floor, Kind))));
        return;
    end
    Pct = arrayfun(@(f) string(sprintf('%s (%.0f%%)', f, ...
        100 * ShippedFreq(Shipped == f))), Fragile);
    append(Ch, Paragraph(char(sprintf("Fragile shipped picks (below the %.0f%% " + ...
        "%s floor): %s. These were kept by the full-data consensus but " + ...
        "re-selected in a minority of the %s runs. This " + ...
        "is a flag only; nothing was removed.", ...
        100 * Floor, Kind, strjoin(Pct, ", "), Kind))));
end


function appendMidBand(Ch, Sel, Shipped, Floor)
%appendMidBand PDF mirror of writeMidBand: the shipped features above the FLOOR but
%   below the consensus-core cut -- kept, not fragile, but short of "reliably
%   re-selected". Naming them keeps the report from leaving a silent gap between the
%   two headline sentences. Prints nothing when the band is empty.
    import mlreportgen.dom.*
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
    append(Ch, Paragraph(char(sprintf("Above the floor but below core " + ...
        "(%.0f%%-%.0f%%): %s -- kept with moderate support: re-selected in most " + ...
        "runs but not consistently enough to count as core.", ...
        100 * Floor, 100 * Core, strjoin(Pct, ", ")))));
end


function appendGenStab(Ch, Sel, Shipped, Floor)
%appendGenStab Generation-variance SELECTION STABILITY over the intersection
%   universe: re-runs generate -> select per subsample, so the pool is regenerated
%   each time. Expensive, separately opted-in. Any cross-validated PERFORMANCE
%   mean/std lives in the Performance chapter; here we report only the stability
%   read, so the chapters don't duplicate it.
    import mlreportgen.dom.*
    append(Ch, Heading2('Generation stability (pool regenerated)'));
    append(Ch, methodologyNote('What this part checks.', ...
        ['It re-runs the whole pipeline on each subsample -- building the features ' ...
        'from scratch and then selecting -- so it also captures how much the ' ...
        'feature-building step itself wobbles, on top of the selection. It uses ' ...
        'the same subsamples as the fixed-pool check above, which is what lets you ' ...
        'compare the two numbers directly, as the gap below reports.']));

    if isfield(Sel, 'Nogueira')
        append(Ch, metricHeadline(sprintf("Generation Nogueira index (shared features): %s %s", ...
            fmtQuality(Sel.Nogueira), nogueiraGloss(Sel.Nogueira))));
        append(Ch, Paragraph(['The pool is regenerated every subsample, so this ' ...
            'folds generation variance in on top of selection. Distinct from the ' ...
            'fixed-pool value above; their gap is quantified below.']));
    end
    if isfield(Sel, 'CoreFeatures') && ~isempty(Sel.CoreFeatures)
        append(Ch, Paragraph(char(sprintf("Reliably re-selected (the consensus " + ...
            "core, picked in at least %.0f%% of subsamples): %s", ...
            100 * coreThreshold(Sel), joinNames(Sel.CoreFeatures)))));
    end
    % Same reliable -> mid-band -> fragile trio as the fixed-pool read, scoped to the
    % regenerated pool (drop-outs are the drift table, not a low frequency here).
    appendMidBand(Ch, Sel, Shipped, Floor);
    appendFragileWarning(Ch, Sel, Shipped, Floor, 'regenerated-pool');
    if isfield(Sel, 'Drift') && istable(Sel.Drift) && ~isempty(Sel.Drift)
        appendDriftTable(Ch, Sel.Drift, Shipped);
    end
    if isfield(Sel, 'SelectionFrequency') && istable(Sel.SelectionFrequency) ...
            && ~isempty(Sel.SelectionFrequency)
        appendFreqTable(Ch, Sel.SelectionFrequency, Shipped, Floor, coreThreshold(Sel));
    end
end


function appendStabilityGap(Ch, SelStab, GenStab)
%appendStabilityGap The fixed-pool <-> generation Nogueira gap = generation
%   variance. Both indices come from the same subsampling draw, so their
%   difference isolates how much instability comes from regenerating the pool per
%   subsample versus re-selecting on a fixed pool.
    import mlreportgen.dom.*
    if ~isfield(SelStab, 'Nogueira') || ~isfield(GenStab, 'Nogueira')
        return;
    end
    Fixed = SelStab.Nogueira;
    Gen = GenStab.Nogueira;
    if isnan(Fixed) || isnan(Gen)
        return;
    end
    Gap = Fixed - Gen;
    append(Ch, metricHeadline(sprintf(...
        "Generation variance (fixed-pool minus generation stability): %+.2f", Gap)));
    append(Ch, Paragraph(char(sprintf(...
        "Fixed-pool stability was %s and generation stability %s; the gap is the " + ...
        "share of instability attributable to regenerating the pool rather than " + ...
        "to selection. %s", ...
        fmtQuality(Fixed), fmtQuality(Gen), gapGloss(Gap)))));
end


function Gloss = gapGloss(Gap)
    if Gap >= 0.15
        Gloss = "A large gap: generation is the major source of instability.";
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


function appendFreqTable(Ch, FreqTbl, Shipped, Floor, Core)
%appendFreqTable Per-feature re-selection frequency, mirroring the markdown report's
%   writeFreqTable: a Status column ties each row to the shipped decision (shipped,
%   core / shipped / shipped, fragile / not shipped), and EVERY shipped feature is
%   listed (so a fragile low-frequency pick is never hidden), with the tail filled by
%   the highest-frequency non-shipped candidates up to the same window the selection
%   plots use.
    import mlreportgen.dom.*
    Shipped = string(Shipped);
    [Data, NTotal, NShown, NOmitted] = freqRowsToShow(FreqTbl, Shipped, Floor, Core);
    append(Ch, Paragraph(char(sprintf(['Per-feature re-selection frequency — how often ' ...
        'each feature was picked across the resamples (100%% = every subsample). Every ' ...
        'shipped feature is listed; read each against the %.0f%% floor:'], 100 * Floor))));
    append(Ch, styledTable({'Feature', 'Re-selected in', 'Status'}, Data));
    if NOmitted > 0
        append(Ch, Paragraph(char(sprintf(['Showing %d of %d features: all shipped plus ' ...
            'the top non-shipped by frequency; %d lower-frequency non-shipped candidates ' ...
            'are in the complete table in the appendix.'], NShown, NTotal, NOmitted))));
    end
end


function [Data, NTotal, NShown, NOmitted] = freqRowsToShow(FreqTbl, Shipped, Floor, Core)
%freqRowsToShow See generateFeatureReport.m/freqRowsToShow -- same selection rule
%   (all shipped, then top non-shipped up to max(20, #shipped)), returning DOM-ready
%   {Feature, Re-selected in, Status} rows. Complete table is in the appendix + .mat.
    Shipped = string(Shipped);
    NTotal = height(FreqTbl);
    Feats = string(FreqTbl.Feature);
    IsShipped = ismember(Feats, Shipped);
    Window = max(20, numel(Shipped));
    Keep = IsShipped;
    Keep(1:min(Window, NTotal)) = true;
    Idx = find(Keep);
    NShown = numel(Idx);
    NOmitted = NTotal - NShown;
    Data = cell(NShown, 3);
    for r = 1:NShown
        i = Idx(r);
        Feat = Feats(i);
        Freq = double(FreqTbl.Frequency(i));
        Data{r, 1} = char(Feat);
        Data{r, 2} = sprintf('%.0f%%', 100 * Freq);
        Data{r, 3} = char(freqStatus(Feat, Freq, Shipped, Floor, Core));
    end
end


function Status = freqStatus(Feat, Freq, Shipped, Floor, Core)
%freqStatus Per-row tie-back to the shipped decision (see appendFreqTable). Three
%   tiers for a shipped feature: at/above CORE = "shipped, core"; between FLOOR and
%   CORE = plain "shipped"; below FLOOR = "shipped, fragile".
    if any(string(Shipped) == Feat)
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


function appendDriftTable(Ch, Drift, Shipped)
%appendDriftTable Pool-availability drift, PDF mirror of writeDriftTable. Drift is
%   binary pool membership: a feature generated in every subsample's pool is stable
%   and omitted; any feature missing from one is listed, "Absent from" naming that
%   gap directly (see driftRowsToShow). A shipped feature that drifts is called out
%   first, always listed, then the most-drifted non-shipped up to a window.
    import mlreportgen.dom.*
    Shipped = string(Shipped);
    ShippedDrift = string(Drift.Feature(ismember(string(Drift.Feature), Shipped)));
    if ~isempty(ShippedDrift)
        append(Ch, Paragraph(char(sprintf(['Shipped features that drifted: %s left ' ...
            'the regenerated pool on some subsamples, so they could not always be ' ...
            're-selected. A delivered feature whose availability is unstable is worth ' ...
            'confirming on a fresh pool before relying on it.'], joinNames(ShippedDrift)))));
    end
    append(Ch, Paragraph(['Drift — features NOT generated in every subsample''s pool ' ...
        '(a feature present in all of them is stable and is omitted here). "Absent ' ...
        'from" is the share of subsamples that lacked it — the drift itself; "picked ' ...
        'when present" is its selection frequency among just the subsamples that had it:']));
    [Data, NTotal, NShown, NOmitted] = driftRowsToShow(Drift, Shipped);
    append(Ch, styledTable({'Feature', 'Absent from', 'Picked when present', 'Status'}, Data));
    if NOmitted > 0
        append(Ch, Paragraph(char(sprintf(['Showing %d of %d drifted features: all ' ...
            'shipped plus the most-drifted non-shipped; %d less-drifted non-shipped ' ...
            'omitted.'], NShown, NTotal, NOmitted))));
    end
end


function [Data, NTotal, NShown, NOmitted] = driftRowsToShow(Drift, Shipped)
%driftRowsToShow See generateFeatureReport.m/driftRowsToShow -- same rule (every
%   shipped-drifted feature, then most-drifted non-shipped up to a window), returning
%   DOM-ready {Feature, Absent from, Picked when present, Status} rows.
    Shipped = string(Shipped);
    Feats = string(Drift.Feature);
    Absent = 1 - double(Drift.PoolCoverage);
    IsShipped = ismember(Feats, Shipped);
    NTotal = numel(Feats);
    Window = max(20, sum(IsShipped));
    ShipIdx = find(IsShipped);
    RestIdx = find(~IsShipped);
    [~, so] = sort(Absent(ShipIdx), 'descend'); ShipIdx = ShipIdx(so);
    [~, ro] = sort(Absent(RestIdx), 'descend'); RestIdx = RestIdx(ro);
    NRest = min(numel(RestIdx), max(0, Window - numel(ShipIdx)));
    Idx = [ShipIdx; RestIdx(1:NRest)];
    NShown = numel(Idx);
    NOmitted = NTotal - NShown;
    Data = cell(NShown, 4);
    for r = 1:NShown
        i = Idx(r);
        Data{r, 1} = char(Feats(i));
        Data{r, 2} = sprintf('%.0f%%', 100 * Absent(i));
        Data{r, 3} = sprintf('%.0f%%', 100 * double(Drift.SelFreqWhenPresent(i)));
        if IsShipped(i)
            Data{r, 4} = 'shipped, drifted';
        else
            Data{r, 4} = 'not shipped';
        end
    end
end


function Ch = deliverablesChapter(Results)
    import mlreportgen.dom.*
    Ch = mlreportgen.report.Chapter('Deliverables');
    Files = string(getField(Results, "Deliverables", string.empty(1, 0)));
    if isempty(Files)
        append(Ch, Paragraph('Delivery phase not recorded.'));
        return;
    end
    append(Ch, UnorderedList(cellstr(Files)));
end


function appendAppendix(Rpt, Results)
%appendAppendix The complete, untruncated tables the body chapters only preview,
%   as the report's final chapter. Mirrors generateFeatureReport.m/writeAppendix:
%   nothing new is computed -- the same vote and selection-frequency structs,
%   rendered whole. The results .mat (named here) carries the same data plus every
%   other run result. Skipped entirely when there is nothing to list.
    import mlreportgen.dom.*
    HasVote = isfield(Results, 'VoteTable') && istable(Results.VoteTable) ...
        && ~isempty(Results.VoteTable);
    HasSel = hasFreq(Results, 'SelStab');
    HasGen = hasFreq(Results, 'GenStab');
    if ~HasVote && ~HasSel && ~HasGen
        return;
    end
    Ch = mlreportgen.report.Chapter('Appendix A. Complete tables');
    append(Ch, Paragraph(char(sprintf(['The body chapters above show a readable top ' ...
        'slice of each table. This appendix lists them in full. The same values, plus ' ...
        'every other run result, are in %s — load it and read Results (e.g. ' ...
        'Results.VoteTable, Results.SelStab.SelectionFrequency).'], resultsMatName(Results)))));

    if HasVote
        append(Ch, Heading2('A1. Consensus vote — full'));
        appendFullVoteTable(Ch, Results.VoteTable);
    end
    if HasSel || HasGen
        appendFullFreqTable(Ch, Results, HasSel, HasGen);
    end
    append(Rpt, Ch);
end


function Tf = hasFreq(Results, Field)
%hasFreq True when a stability read carries a non-empty SelectionFrequency table.
    Tf = isfield(Results, Field) && isstruct(Results.(Field)) ...
        && isfield(Results.(Field), 'SelectionFrequency') ...
        && istable(Results.(Field).SelectionFrequency) ...
        && ~isempty(Results.(Field).SelectionFrequency);
end


function appendFullVoteTable(Ch, V)
%appendFullVoteTable The consensus vote table, every row, in rank order.
    import mlreportgen.dom.*
    if ismember("Rank", string(V.Properties.VariableNames))
        V = sortrows(V, "Rank");
    end
    HasSel = ismember("Selected", string(V.Properties.VariableNames));
    append(Ch, Paragraph(char(sprintf("%d features, in consensus-rank order:", height(V)))));
    Data = cell(height(V), 4);
    for i = 1:height(V)
        Data{i, 1} = char(string(V.Feature(i)));
        Data{i, 2} = fmtQuality(double(V.Score(i)));
        Data{i, 3} = sprintf('%d', V.Rank(i));
        if HasSel
            Data{i, 4} = tickMark(V.Selected(i));
        else
            Data{i, 4} = '';
        end
    end
    append(Ch, styledTable({'Feature', 'Consensus score', 'Rank', 'Selected'}, Data));
end


function appendFullFreqTable(Ch, Results, HasSel, HasGen)
%appendFullFreqTable The per-feature re-selection frequency, every row, one column
%   per stability read that ran: the fixed-pool read (rows resampled, pool held
%   fixed) and the generation read (rows resampled AND the pool regenerated). When
%   both ran they share one table so the fixed -> regenerated drop is visible per
%   feature; when only one ran the table has that single column. Features are the
%   union of both reads, ordered by fixed-pool frequency (then generation) so the
%   most reliably re-selected sit at the top; a feature a read never saw prints "—".
%   No status column -- the body chapter carries the floor/core tie-back; this is
%   the raw complete list.
    import mlreportgen.dom.*
    if HasSel && HasGen
        append(Ch, Heading2('A2. Selection frequency — full (fixed pool and regenerated pool)'));
        Header = {'Feature', 'Fixed pool', 'Regenerated pool'};
    elseif HasSel
        append(Ch, Heading2('A2. Selection frequency — full (fixed pool)'));
        Header = {'Feature', 'Re-selected in'};
    else
        append(Ch, Heading2('A2. Selection frequency — full (generation, pool regenerated)'));
        Header = {'Feature', 'Re-selected in'};
    end
    [Feats, SelFreq, GenFreq] = mergeFreq(Results, HasSel, HasGen);
    NCol = numel(Header);
    Data = cell(numel(Feats), NCol);
    for i = 1:numel(Feats)
        Data{i, 1} = char(Feats(i));
        if HasSel && HasGen
            Data{i, 2} = pctOrDash(SelFreq(i));
            Data{i, 3} = pctOrDash(GenFreq(i));
        elseif HasSel
            Data{i, 2} = pctOrDash(SelFreq(i));
        else
            Data{i, 2} = pctOrDash(GenFreq(i));
        end
    end
    append(Ch, styledTable(Header, Data));
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


function Name = resultsMatName(Results)
%resultsMatName The fe_results_<dataset>.mat file name, matching saveResults'
%   stem rule, so the report's pointers name the exact file on disk.
    DS = getField(Results, "DatasetName", "dataset");
    Name = "fe_results_" + matlab.lang.makeValidName(string(DS)) + ".mat";
end


% ------------------------------------------------------------- small helpers

function assertReportGenerator()
%assertReportGenerator Error out cleanly if Report Generator is unavailable.
    HasDom = exist('mlreportgen.report.Report', 'class') == 8;
    HasLicense = license('test', 'MATLAB_Report_Gen');
    if ~HasDom || ~HasLicense
        error('generateFeatureReportPdf:reportGeneratorUnavailable', ...
            ['MATLAB Report Generator is required for the PDF report but is ' ...
            'not available. The Markdown report (generateFeatureReport) covers ' ...
            'the same content without it.']);
    end
end


function closeIfOpen(Rpt)
%closeIfOpen Best-effort close so a mid-build error does not leak a handle.
    try
        close(Rpt);
    catch
        % Already closed or never opened; nothing to clean up.
    end
end


function Rows = addRow(Rows, S, Field, Label, Fmt)
%addRow Append {Label, Fmt(value)} when the struct carries the field.
    if isfield(S, Field)
        Rows = [Rows; {Label, Fmt(S.(Field))}];
    end
end


function Suffix = imbalanceSuffix(CB)
    if isfield(CB, 'ImbalanceRatio') && ~isnan(CB.ImbalanceRatio)
        Suffix = sprintf(' (imbalance ratio %.1f:1)', CB.ImbalanceRatio);
    else
        Suffix = '';
    end
end


function Str = fmtMeanStd(S)
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


function P = metricHeadline(Text)
%metricHeadline A bold, slightly larger stand-alone line for a headline metric
%   (the Nogueira indices, the generation-variance gap), so the number does not
%   blend into the surrounding explanation. The prose stays a plain Paragraph
%   right below it -- the mirror of the markdown report's bold blockquote line.
    import mlreportgen.dom.*
    P = Paragraph(char(Text));
    P.Style = {Bold(true), FontSize('11pt')};
end


function P = methodologyNote(Label, Body)
%methodologyNote A shaded, indented aside for FIXED instructional text (methodology
%   that reads the same on every run), so it stays visually distinct from the
%   run-specific findings that follow. LABEL is bolded and leads; BODY is the prose.
%   The PDF mirror of the markdown report's labeled "How to read" blockquote.
    import mlreportgen.dom.*
    P = Paragraph();
    Lead = Text(char(Label));
    Lead.Bold = true;
    append(P, Lead);
    append(P, Text([' ' char(Body)]));
    P.Style = {BackgroundColor('#F2F2F2'), FontSize('9pt'), ...
        OuterMargin('0pt', '0pt', '6pt', '6pt'), ...
        InnerMargin('6pt', '6pt', '4pt', '4pt')};
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


% ----------------------------------- salvaged mlreportgen scaffold + formatters

function Tbl = styledTable(Headers, Data)
%styledTable A bordered, header-styled FormalTable with all cells stringified.
    import mlreportgen.dom.*
    for r = 1:size(Data, 1)
        for c = 1:size(Data, 2)
            Val = Data{r, c};
            if ~ischar(Val)
                if isstring(Val)
                    Data{r, c} = char(Val);
                elseif isnumeric(Val)
                    Data{r, c} = sprintf('%g', Val);
                else
                    Data{r, c} = char(string(Val));
                end
            end
        end
    end
    Tbl = FormalTable(Headers, Data);
    Tbl.Width = '100%';
    Tbl.Border = 'solid';
    Tbl.ColSep = 'solid';
    Tbl.RowSep = 'solid';
    Tbl.TableEntriesStyle = {FontSize('9pt'), FontFamily('Arial')};
    Tbl.Header.Style = {Bold, BackgroundColor('#4472C4'), ...
        Color('white'), FontSize('9pt'), FontFamily('Arial')};
end


function embedFigure(Ch, OutputDir, FileName, Caption, Width)
    arguments
        Ch
        OutputDir
        FileName
        Caption
        Width = '15cm'
    end
    import mlreportgen.dom.*
    if strlength(string(OutputDir)) == 0
        return;   % embedding suppressed (Options.EmbedFigures false)
    end
    FigPath = fullfile(OutputDir, FileName);
    if isfile(FigPath)
        append(Ch, Heading3(Caption));
        Img = Image(char(FigPath));
        Img.Width = Width;
        P = Paragraph(Img);
        P.Style = {HAlign('center')};
        append(Ch, P);
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
