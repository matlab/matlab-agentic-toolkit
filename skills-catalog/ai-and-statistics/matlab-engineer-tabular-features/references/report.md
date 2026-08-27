# Report — assemble one Results struct, emit markdown (+ PDF)

Reporting is the last phase. It does no analysis of its own: it gathers every
prior phase's output into **one plain `Results` struct** and hands that to the
generators. When it runs, the markdown report is always produced and the PDF is
produced **when MATLAB Report Generator is available**.

> **Optional (opt-out).** Reporting is ON by default but the user can decline it —
> the choice is collected up front at intake ([intake.md](intake.md)), so the cost
> is known before the run. When declined, **skip this entire phase**; the
> deliverables (inference script + `.mat`, figures) were
> already written by the deliver phase and still stand. Only the written report is
> gated — never suppress the deliverables. The figures the report would embed are
> produced by the plot steps regardless, so an opt-out loses only the prose
> assembly.

---

## Assemble the `Results` struct

Every sub-struct is passed through **verbatim**, so field names match the
producing function exactly. Assemble it from what you already hold:

```matlab
Results = struct();
Results.DatasetName   = DatasetName;      % title label
Results.ResponseVar   = ResponseVar;
Results.Profile       = Profile;          % profileForSplit
Results.ReserveInfo   = ReserveInfo;      % reserveHoldoutForUser (Level-0 carve)
Results.Split         = Split;            % splitStrategy
Results.Strategy      = Split.Strategy;   % "holdout" | "cross_validated"
Results.GenInfo       = GenInfo;          % generateFeatures
Results.Transformer   = Transformer;      % SMLT path: supplies feature definitions
% Domain path: set Results.Recipe = Recipe instead (the Kind=="domain" recipe);
% its .Describe table supplies the definitions. Set whichever your pool phase produced.
Results.SelectedNames = SelectedNames;    % runConsensusSelection
Results.VoteTable     = VoteTable;        % runConsensusSelection
Results.PanelInfo     = PanelInfo;        % runConsensusSelection
Results.Quality       = Quality;          % featureSetQuality (always)
% Stability: two independent opt-in gates, each present only if opted in:
Results.SelStab       = SelStab;          % assessSelectionStability  (Gate 1, fixed pool)
Results.GenStab       = GenStab;          % assessGenerationStability (Gate 2, pool regenerated)
% Exactly ONE performance read, by strategy:
Results.Baseline      = Baseline;         % baselineComparison  (holdout only)
Results.KFold         = KFold;            % assessKFold         (cross_validated only)
Results.Deliverables  = Deliverables;     % emitted file names (OPTIONAL)
```

`.Quality` is present on every run. Stability is **two independent opt-in gates**,
each present only when opted into — `.SelStab` (fixed pool) and/or `.GenStab`
(regenerated pool); when neither ran, both are absent and `.StabilitySkipped = true`.
The two performance reads are **mutually exclusive** — `.Baseline` under `holdout`,
`.KFold` under `cross_validated`; the generators branch on `.Strategy`.
`.Deliverables` is optional — when absent, its chapter degrades to a note rather than
erroring.
The *Selected Feature Definitions* chapter is **generator-agnostic**: it pulls
definitions through `describeFeatures`, which reads whichever recipe you supplied —
an SMLT `FeatureTransformer` (`.Transformer`) via its `describe()` table, or a
domain recipe (`.Recipe`) via its `.Describe` table. Set exactly one; `.Recipe`
takes precedence when both are present. Either way the definitions are the
producer's own, not reconstructed. If neither is set the chapter degrades to a note.

---

## Emit the reports

```matlab
MdPath = generateFeatureReport(Results, OutputDir);       % always

if hasReportGenerator()                                   % class + license check
    try
        PdfPath = generateFeatureReportPdf(Results, OutputDir);
    catch ME
        if ME.identifier == "generateFeatureReportPdf:reportGeneratorUnavailable"
            % Report Generator absent/unlicensed — markdown already stands.
        else
            rethrow(ME);
        end
    end
end
```

- **`generateFeatureReport`** — markdown, no toolbox gating, always writes
  `feature_report.md`. Options: `FileName`, `EmbedFigures` (embeds the `fig_*.svg`
  figures if they exist on disk in `OutputDir`).
- **`generateFeatureReportPdf`** — same content via `mlreportgen.report`/`dom`.
  Its `assertReportGenerator()` guard raises
  `generateFeatureReportPdf:reportGeneratorUnavailable` when the toolbox is
  missing, so wrap it in try/catch and keep markdown only. It generates under
  `tempdir` then copies to `OutputDir` (OneDrive file-lock avoidance).

---

## The chapters

Both generators emit the same layout over the same struct:

1. **Overview** — dataset, problem type, rows, class balance, response. State the
   **Level-0 carve** (`.ReserveInfo`): when a slice was reserved, "N rows (X%) set
   aside untouched for your own testing; M rows are the working data" — everything
   below is on the working data; when nothing was reserved (user supplied a separate
   test set), say so.
2. **Generation** — producer, pool size, target learner, standardization; any
   excluded (WoE) columns.
3. **Consensus Selection** — ranker panel, voter + mean agreement,
   `NSelect of p`, the **vote table**, the consensus-agreement figure
   (`fig_selection_consensus.svg`) and the selection-decision elbow
   (`fig_selection_decision.svg`), and a one-line **glossary** of the terms shown
   (rankers, voter). The decision elbow lives here; its stability under
   resampling is chapter 7.
4. **Selected Feature Definitions** — `Feature | Type | Definition` for the
   selected set, via `describeFeatures` (the transformer's `describe()` on the SMLT
   path, or the domain recipe's `.Describe` table).
5. **Performance** — branches on `.Strategy`. Under **`holdout`** (`.Baseline`): the
   per-family panel (naive/original/engineered, AUC+F1 or RMSE) as a **point
   estimate**, and the baseline bar chart (`fig_validation_baseline.svg`); **no
   internal-CV line** (a single split has no honest variance — omit it, don't print
   "N/A" as if a number were expected). Under **`cross_validated`** (`.KFold`): the
   cross-fold **mean ± std** of every metric as the headline, and no baseline bar
   chart. Either way, close with the **conservative-estimate caveat**: the shipped
   recipe is refit on all working data, so this estimate grades a recipe trained on
   less data than the one delivered — the real set is at least this good.
6. **Model-Free Quality** — relevance / redundancy / compactness, with verdicts
   (always present).
7. **Selector Stability** — the two opt-in stability gates, each drawn only when it
   ran (else "not requested"). Gate 1 (`.SelStab`): the fixed-pool Nogueira index +
   the reliably-re-selected features over the whole pool. Gate 2 (`.GenStab`): the
   intersection-universe Nogueira, reliably-re-selected features and drift, plus —
   when Gate 1 also ran — the fixed-pool ↔ generation gap as the generation-variance
   read. The chapter opens by **explaining the Nogueira scale in words** (`1.0`
   identical every subsample, `~0` no better than chance, may go slightly negative;
   ≥ 0.75 highly stable / 0.4–0.75 moderate / < 0.4 unstable) and prints a
   **fragile-shipped-picks** line: shipped features whose re-selection frequency fell
   below the 0.5 floor, named with percentages and flagged for confirmation — a
   warning only, nothing is removed (or "none" when all cleared). This mirrors the
   `fig_selection_stability` figure's short-blue-bar-left-of-floor signal, so the
   prose and the plot tell the same story. The figure is embedded in this chapter.
8. **Deliverables** — emitted file list (optional).
9. **Appendix A. Complete tables** — the last chapter, the untruncated forms of the
   tables the body only previews: the full consensus vote (A1) and the full
   per-feature selection-frequency table for each stability read that ran (A2 fixed
   pool, A3 regenerated pool). The body chapters cap their vote and frequency tables
   at a readable window (`max(20, #shipped)`, always including every shipped
   feature) and point here; this appendix carries them whole. Nothing new is
   computed — the same `VoteTable` / `SelectionFrequency` structs, rendered in full.
   It names the results `.mat` (below) as the machine-readable form of the same data.
   Absent only when there is no vote table and no stability read to list.

Each `fig_*.svg` is embedded in the chapter it supports, not collected in a
trailing gallery, so a section and its figure read together.

The report **previews**, the `.mat` is the **record.** The body windows and the
plots show a top slice; the appendix carries the full tables in prose form; and
`fe_results_<dataset>.mat` (written unconditionally by the deliver phase —
[deliver.md](deliver.md) §5b) holds the entire `Results` struct at full resolution,
the machine-readable copy. The same struct is live in the workspace this session.
So no result that a plot or a windowed table only previews is ever lost — it is in
the appendix, the `.mat`, and the workspace.

---

## Report the outcome faithfully

- **Selection is evaluation, not reduction** — if the pool passed through intact,
  say so; don't frame it as a cut that didn't happen.
- **Surface what was dropped** — screened predictors (intake), excluded WoE
  columns (generation), rankers skipped (selection). A silently shrunk set reads
  as data loss.
- **State skipped phases plainly** — a missing K-fold chapter is "not run", not a
  pass.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
