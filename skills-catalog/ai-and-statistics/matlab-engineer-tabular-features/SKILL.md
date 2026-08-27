---
name: matlab-engineer-tabular-features
description: >
  Use when engineering or selecting the best features for single-response
  classification or regression in MATLAB, whatever the data's modality — for
  non-tabular data it routes extraction to a domain skill, then selects,
  assesses, and delivers on the resulting table. Not for multi-response
  problems, model training, or raw data acquisition.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Engineer Tabular Features

A lean, functional pipeline: **intake → feature pool → select → assess →
deliver → report**. There is no shared context object — each phase is a direct
call to leaf utilities in `scripts/`, and the reference file for each phase
carries the detail. Your value is the **structured, data-driven process** and,
above all, the **consensus selection** at its center — not an ad-hoc answer.

This skill bundles the workflow in `references/` (per-phase detail read on demand)
and `scripts/` (the computation and plotting utilities). Do not invoke files in
`references/` as separate skills — they are loaded only via the `Read` tool when
the phase that needs them runs. The per-phase files call the pipeline's leaf helpers
for you; if you ever need a helper's signature,
[references/internal-helpers.md](references/internal-helpers.md) documents each one's
inputs, outputs, and an example call — so you never open a helper's source.

## When to Use

- Engineering or selecting the best predictors for **single-response supervised
  classification or regression** on a plain in-memory `table`.
- You want a **structured, data-driven selection** — a ranker panel, a consensus
  vote, and an elbow cut — rather than an ad-hoc hand-picked feature set.
- The data is **non-tabular** (signals, images, battery/machinery telemetry): this
  skill routes extraction to the matching domain skill, then engineers, selects,
  assesses, and delivers on the resulting table (see
  [references/domain-routing.md](references/domain-routing.md)).

## When NOT to Use

- **Multi-response problems** — this skill is single-response only.
- **Model training, tuning, or deployment** — it prepares features and stops.
  Hand the delivered table to a model-training/classification workflow to fit and
  compare models.
- **Raw data acquisition.** And for the *extraction* step on non-tabular data, the
  actual feature computation belongs to the matching **domain extraction skill** —
  this skill orchestrates that handoff (see
  [references/domain-routing.md](references/domain-routing.md)), it does not
  re-implement it.

**Requires** the Statistics and Machine Learning Toolbox (SMLT) —
`gencfeatures`/`genrfeatures` build the pool and the ranker/assessment utilities
are SMLT-based. MATLAB Report Generator is optional (enables the PDF report;
markdown is always produced).

## Running MATLAB

Run all MATLAB through the MATLAB MCP server (`mcp__matlab__evaluate_matlab_code`,
or `mcp__matlab__run_matlab_file` for scripts). Set `project_path` to this skill's
`scripts/` directory so the utilities resolve on the current working folder
**without any `addpath` calls**. Every utility is a leaf function called directly —
there is no initialization step and no context object to construct. Validate any
code you author with `mcp__matlab__check_matlab_code` before running it.

**Start each dataset from scratch — but use the live workspace within a run.** The
MCP session is stateful, so a run's intermediates should live in the workspace: set
`RawTbl`, `Splits`, `FullEng`, `SelectedNames`, `Baseline`, etc. once and pass them
phase-to-phase. Do **not** round-trip them through `save`/`load` `.mat` files (noise,
risks stale reads) and do **not** `addpath`. Across *different* datasets/runs, carry
nothing — begin each analysis by setting every variable afresh.

## Communication style while running this skill

Talk to the user about their **data and results**, not the skill's plumbing.
Everything under `references/` and `scripts/` is internal. Rule of thumb: if a
sentence would only make sense to someone who has read this skill's source files,
don't say it.

- **Never name internal files, helpers, or phase/gating mechanics.**
  `runConsensusSelection`, `GenInfo.BinaryReliant`, "the redundancy dimension", etc.
  are internal — give the *outcome* ("these features duplicate each other, so I'm
  keeping the strongest"), not the mechanism. Name an internal only when it *is* a
  problem the user can act on. Read reference files silently.
- **Use plain words for each check.** The three assessment reads: performance →
  whether the new features improve predictions (a held-out estimate, or a
  cross-validated mean ± std); fixed-pool stability → whether the same features get
  picked when rows are resampled; generation stability → whether the same features
  get *built and* picked when the whole pipeline re-runs on resampled rows. Say "the
  ranking step" not "the borda voter"; "reliably re-selected" not "consensus core".
- **Don't narrate uncertainty or mid-flight course-corrections** — settle how a
  function is called silently, then report only the outcome. Surface a difficulty
  only when the user must decide on it.
- **Announce cost before long work**, one sentence — pool size before selection,
  expected time before a K-fold, and **before either stability gate** (both re-run
  selection many times; the generation gate also re-builds the pool each time). And
  **surface user-facing questions verbatim** where a phase specifies one (output
  directory, wide-input, domain routing).
- **Report what was dropped** at every phase (screened predictors, excluded WoE
  columns, skipped rankers) — a silent shrink reads as data loss. But **selection
  evaluates the pool, it doesn't necessarily shrink it** — never call it a reduction.

## Output directory — REQUIRED, HARD HALT

Deliverables are written to disk. **Always confirm the output directory with the
user before writing anything.** Do not assume the working directory, do not
create one silently.

---

## The pipeline

Follow the phases in order. Each links to its reference; read the reference
before executing the phase.

### 1. Intake — [references/intake.md](references/intake.md)

**Ask before running any code.** Intake is a required conversation, not a
default-fill. Confirm every run parameter with the user *before* proceeding past
the screen — data source, response, dataset name, output directory (hard-halt),
domain description, separate-test-set, model family (+ lens if `agnostic`),
evaluation strategy, report opt-out — **asked one at a time, in the order pinned in
[intake.md](references/intake.md) §1** (never dump the whole list in one message).
Every item must be asked; offer a default where one exists, but confirm rather than
assume — when the opening request implies an answer, state what you inferred and
have the user confirm it. Two are
non-negotiable — do not proceed without an explicit answer:

- **Output directory** — the disk-write hard-halt (see above).
- **Domain description** — the sole input to domain routing. Ask what the data is
  and where it came from; route to a domain extractor if one fits, else the generic
  path. Never infer the domain from column names or fall through to generic
  generation on silence. Verbatim prompt in [intake.md](references/intake.md).

Then assemble the data into **one plain table**, briefly **confirm what was
loaded** (shape, response, problem type), and **screen** degenerate predictors. A
`timetable`/`tall`/`gpuArray`/`datastore` isn't a dead end — it's a signal to run a
tabularizing step first (often a domain skill, see
[domain-routing.md](references/domain-routing.md)) and then re-enter intake with
the resulting table; only halt if no tabular path exists.

```matlab
[ScreenedTbl, ScreenInfo] = screenPredictors(RawTbl, Response);   % or (X, y)
```

`screenPredictors` handles the polymorphic response (a name already in the table,
or a separately-supplied vector/table it concatenates) and drops constant and
near-empty predictors. Then profile, reserve the user's untouched slice, and split:

```matlab
Profile = profileForSplit(ScreenedTbl, ScreenInfo.ResponseVar);
[WorkingIdx, UserHeldOutIdx, ReserveInfo] = reserveHoldoutForUser( ...
    ScreenedTbl, Profile.ProblemType, ScreenInfo.ResponseVar, ReserveForUser = HasNoSeparateTest);
[Splits, SplitDecision] = splitStrategy(ScreenedTbl, Profile.ProblemType, ...
    ScreenInfo.ResponseVar, Subset = WorkingIdx, EvaluationStrategy = EvaluationStrategy);
```

`reserveHoldoutForUser` sets aside an untouched slice for the user's own testing
when they have no separate test set (default 20%, user-settable via `HoldoutFraction`;
else nothing); the rest is the **working data** all phases run on. When a carve
happens, materialize the slice as the table variable's name + `_test` from the original
rows and narrate the split in plain words (fraction, row counts, and method —
`stratified`/`random` — from `ReserveInfo`); see [intake.md](references/intake.md). `splitStrategy` then sets
`Splits.TrainIdx`/`.TestIdx` over the working rows — a train/test split under
`holdout`, or all working rows with **empty `TestIdx`** under `cross_validated`.
**Generation and selection run on `TrainIdx` only.**

### 2. Feature pool — [references/feature-pool.md](references/feature-pool.md)

Produce the candidate pool. First check whether a domain skill fits the data
([references/domain-routing.md](references/domain-routing.md)); otherwise use the
default SMLT path:

```matlab
Opts.TargetModel = TargetModel;   Opts.Standardization = "auto";
OptArgs = namedargs2cell(Opts);
TrainIdx = Splits.TrainIdx;   TestIdx = Splits.TestIdx;
TrainTbl = ScreenedTbl(TrainIdx, :);                       % fit generation on train rows only
[~, Transformer, GenInfo] = generateFeatures(TrainTbl, Response, ProblemType, OptArgs{:});
Recipe  = Transformer;                                     % SMLT recipe (domain path: the captured struct)
FullEng = transformFeatures(Recipe, ScreenedTbl);          % engineered pool over ALL rows
FullEng.(Response) = ScreenedTbl.(Response);               % transformFeatures returns predictors only
```

Generate-only (external consensus does the cutting). Mind the **wide-input guard**
(`generateFeatures:tooManyPredictors`) — hold the wide-input conversation and
re-call with `Opts.NumFeatures` set. `FullEng` is the canonical pool: engineered
over **all** rows with the response re-attached, train-fit so the held-out rows
stay leakage-clean. On the **domain path** the captured table already spans all
rows — use it as `FullEng` directly. Whichever path runs, downstream reads only
the **pool contract** (`Recipe`, `describeFeatures`, `transformFeatures`) — never
the producer. Announce `GenInfo.PoolSize`.

Set `OriginalData`/`OriginalPredVars` here — the baseline's "original" reference is
**path-dependent** (raw columns when they exist, else the full pool). [assess.md](references/assess.md) §1 pins the rule.

### 3. Select — [references/select.md](references/select.md)

The heart of the skill. One call runs the ranker panel, the consensus vote, and
the elbow cut:

```matlab
[SelectedNames, VoteTable, PanelInfo] = runConsensusSelection( ...
    FullEng(TrainIdx, :), Response, ProblemType, ExcludeFeatures = GenInfo.BinaryReliant, ...
    TargetModel = TargetModel);
```

Selection runs on the **training rows only** — slice `FullEng(TrainIdx,:)`; the
held-out rows never enter ranking. `TargetModel` gates the ranker panel: a declared
family runs its own embedded probe (linear→lasso, tree_ensemble→oob,
kernel_distance→nca) plus the two model-agnostic rankers; `agnostic` (the default)
keeps the full five-ranker panel. Report `PanelInfo.Reasoning`. Build a
`plotSelectionConsensus` figure **only when the report is on** (`GenerateReport`) —
every figure is a report input, so a report opt-out skips all plot calls.

The score elbow alone sets the count (see [select.md](references/select.md)); when
the scores decline too gradually to show a knee the full pool is kept — report a
keep-all as *"the candidates are comparably useful,"* not as a failure to select.

### 4. Assess — [references/assess.md](references/assess.md)

Diagnostic only; never revises the delivered set. The performance read follows the
**evaluation strategy** chosen at intake:

```matlab
Quality = featureSetQuality(ScreenedTbl, FullEng, TrainIdx, Response, ...
    OriginalPredVars, SelectedNames, ProblemType);          % model-free, always

if Splits.Strategy == "holdout"                              % point estimate on the held slice
    Baseline = baselineComparison(ScreenedTbl, FullEng, TrainIdx, TestIdx, Response, ...
        OriginalPredVars, SelectedNames, ProblemType, TargetModel = TargetModel, InternalCV = false);
else                                                         % cross_validated: folds ARE the estimate
    KFold = assessKFold(ScreenedTbl(TrainIdx, :), Response, ProblemType, CVP, TargetModel = TargetModel);
end

% Stability — two independent opt-in gates, both default OFF (assess.md §3):
rng(0, "twister");
SelStab = assessSelectionStability(StabEng, Response, ProblemType, ...        % Gate 1 (fixed pool)
    ExcludeFeatures = StabExclude, TargetModel = TargetModel, MaxRows = RowBudget);
GenStab = assessGenerationStability(RawTrainTbl, Response, ProblemType, ...    % Gate 2 (pool regenerated)
    TargetModel = TargetModel, MaxRows = RowBudget);
```

Pass a **row budget** to both gates as `MaxRows` **only when the user named one**
(*"~1000 patients is fine"* → `MaxRows = 1000`) to keep the audit affordable; else
omit it (default 3000) — don't pass an empty value.

`Quality` (model-free representation quality) and the strategy's performance read
are **unconditional**: under `holdout`, `baselineComparison` scores the held
`TestIdx` as a point estimate (`InternalCV = false`, no error bars); under
`cross_validated` (`TestIdx` empty), `assessKFold` is the headline (regenerates per
fold, reports **mean ± std**, performance-only) — skip `baselineComparison`.

Stability is **two independent opt-in gates, both default OFF** (see
[assess.md](references/assess.md) §3): **Gate 1** `SelStab` (re-selects on a fixed
pool) and **Gate 2** `GenStab` (also regenerates the pool per subsample; needs a
re-runnable fitter — SMLT by default, a domain path needs `Recipe.Fit`, §3c). **Both
are computationally expensive** — each re-runs the consensus selection M times, and
Gate 2 adds a full regeneration on top — so both stay off unless asked for. Both
grade the *procedure*; neither revises the delivered set. **Offer the choice, don't
default them on, and announce the cost** — ask *"Want a stability check — would the
same features get picked if the data were resampled? It re-runs selection many times
so it takes a while; a deeper version also re-builds the features each time, costing
more again."* and run only what the user opts into. When neither is requested, add
neither and set `Results.StabilitySkipped = true` (report says "not requested"). Skip
a requested gate automatically with that flag when the pool has < 2 features or < 2
subsamples are possible.

### 5. Deliver — [references/deliver.md](references/deliver.md)

Write the artifacts to the confirmed output directory:

```matlab
[ScriptPath, MatPath] = writeInferenceScript(Recipe, SelectedNames, OutputDir, ...
    DatasetName = DatasetName, ResponseVar = ResponseVar);
SelectedTbl = selectFeatures(Recipe, RawTbl, SelectedNames);   % in-workspace CHECK only — do NOT write to disk
```

The recipe **is** the inference recipe — `fe_transform_<dataset>.m` +
its companion `.mat` reproduce the exact selected set on new raw data with one
call. `writeInferenceScript` is generator-agnostic (SMLT `FeatureTransformer` or a
`Kind=="domain"` recipe) and inlines its logic, so the deliverable stands alone.
`SelectedTbl` is only a verification value — **never** write the feature table to
disk (`features_<dataset>.mat`/`.csv`); the inference script regenerates it on
demand, so a materialized dump is redundant. Write the figures' `fig_*.svg`
alongside **only when the report is on**; under a report opt-out the inference
script + state are the whole deliverable.

Also save the full `Results` struct **unconditionally** — every run result at full
resolution, so nothing a plot or a truncated table only previews is lost:

```matlab
ResultsMatPath = saveResults(Results, OutputDir, DatasetName = DatasetName);
```

This `fe_results_<dataset>.mat` ships even on a report opt-out (assemble `Results`
first — see [report.md](references/report.md)). Tell the user it exists, and that
the same data is live in the `Results` workspace variable this session.

### 6. Report — [references/report.md](references/report.md)

**Optional (opt-out, default on)** — run only if the user kept the report at intake
(`GenerateReport == true`), the **same flag** that gates every figure in
Select/Assess/Deliver. When run, assemble the plain `Results` struct from every
prior phase and emit:

```matlab
MdPath = generateFeatureReport(Results, OutputDir);            % always
if hasReportGenerator(); PdfPath = generateFeatureReportPdf(Results, OutputDir); end   % if available
```

### 7. Hand off to model training (offer, don't invoke)

This skill stops at features. If the user's ask mentioned training a model
(supervised learning, classification, regression, etc.) **and** an installed skill
covers tabular model training, name that candidate once at close-out and offer to
hand off — semantic match against the injected skill list, confirm before invoking,
no hardcoded skill names (same discovery rule as
[domain-routing.md](references/domain-routing.md)). If nothing fits or the ask was
features-only, stop silently.

---

## Behavioral contract (all phases)

- **Train/test discipline** — generation, selection, and all training-side
  statistics use the training rows only; the test rows certify the delivered
  artifact and are never seen before then.
- **Generator-agnostic downstream** — after the pool phase, touch generator
  internals *only* through `describeFeatures` / `transformFeatures`.
- **No hidden truncation** — if you cap, sample, or skip anything, say so.
- **Never fabricate a pool** — when routing offers a choice, or the data needs a
  tabularizing step this skill can't perform, presenting the choice or asking
  **ends the turn**. Wait for the user before building the pool by any means (domain
  skill, generic path, or an extractor of your own).
- **Confirm outward-facing actions** — writing to disk is confirmed once at
  intake (the output-dir hard-halt); don't write outside it.
- **MathWorks Coding Guidelines** for any MATLAB you author (lowerCamelCase,
  `arguments` blocks, ≤6 in / ≤4 out, `end` terminators; modern APIs).

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
