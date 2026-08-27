# Assess — is the engineered feature set actually good?

Assessment answers three independent questions about the set selection produced.
None of it revises the delivered set — it is **diagnostic only** — but it is what
lets you report the set honestly rather than asserting it.

| Question | Tool | Read |
|---|---|---|
| Does it **predict** better than raw / naive? | `baselineComparison` (`holdout`) **or** `assessKFold` (`cross_validated`) | point estimate, **or** cross-fold mean ± std |
| Is it a **good representation** regardless of model? | `featureSetQuality` | relevance / redundancy / compactness |
| Do we **trust the selector** — same set again (fixed pool)? re-generated pool? | `assessSelectionStability` / `assessGenerationStability` | Nogueira stability + reliably re-selected features |

The performance question is answered by **one** tool, chosen by the evaluation
strategy (§3): `baselineComparison` under `holdout`, `assessKFold` under
`cross_validated`. The model-specific read is scored through the lens of the
**declared model family** (`TargetModel`), not an assumed random forest, so the
baseline reflects the user's actual downstream model.

**Narrating — name each read correctly.** Call the performance read "cross-validated"
*only* under `cross_validated`; under `holdout` it is a single point estimate — say
so. The two stability gates (§3) both come from **stratified subsampling** of the
training rows, not the performance k-fold — frame them as "re-selecting on resampled
data," never as fold results. Name which one you mean: the fixed-pool read holds the
pool constant; the generation read regenerates it per subsample.

---

## 1. Model-specific baseline — `baselineComparison` (`holdout` strategy)

The performance read for the **`holdout`** evaluation strategy. Trains the declared
family on **original vs. engineered** features and contrasts both against a
**naive** predictor on the held `TestIdx`, as a **point estimate**. Under
`cross_validated` this is skipped — `assessKFold` (§3) is the headline instead.

```matlab
Baseline = baselineComparison(OriginalData, FullEng, TrainIdx, TestIdx, Response, ...
    OriginalPredVars, SelectedNames, ProblemType, ...
    TargetModel = TargetModel, PrimaryFamily = PrimaryFamily, InternalCV = false);
```

Both tables span **all** rows: this fits on `TrainIdx` and scores on the held-out
`TestIdx`, so it needs the engineered features present for the test rows too
(`FullEng`, not its train slice). **`InternalCV = false`** — a single split has no
honest performance variance, so no error bars are drawn (see the plot call below);
the number is reported as a plain point estimate.

**What "original" is — the reference the lift is measured against (path-dependent).**
`baselineComparison` and `featureSetQuality` both contrast an *original* set
(`OriginalData` + `OriginalPredVars`) against the *selected* set. `baselineComparison`
is agnostic about what "original" means — it fits a model on whatever columns you
name — so the orchestrator must set the reference, **once, at the end of the pool
phase**, by whether a model-ready raw predictor table exists:

```matlab
RawPredVars = setdiff(string(ScreenedTbl.Properties.VariableNames), Response, "stable");
% The original reference is FIT by a learner, so keep only model-ready predictor
% types. A datetime/duration column is a valid GENERATION input (the generator
% extracts components from it into the pool) but a learner cannot fit a bare
% datetime — drop those types from the reference only, never from generation.
IsModelReady = ~varfun(@(c) isdatetime(c) || isduration(c) || isa(c, "calendarDuration"), ...
    ScreenedTbl(:, RawPredVars), OutputFormat = "uniform");
RawPredVars = RawPredVars(IsModelReady);
if ~isempty(RawPredVars)     % model-ready raw predictor columns exist: SMLT path, or a domain TABLE input
    OriginalData = ScreenedTbl;  OriginalPredVars = RawPredVars;
    % The fitters and MI panel take floating-point, not integer types. Integer
    % predictors ARE fittable once widened, so cast them to double in the reference
    % copy only (generation already ran on the untouched integer columns).
    for v = OriginalPredVars
        if isinteger(OriginalData.(v)); OriginalData.(v) = double(OriginalData.(v)); end
    end
else                         % non-tabular domain input (signal/image/…), or only non-fittable raw types: no columns to fit on
    OriginalData = FullEng;      OriginalPredVars = setdiff(string(FullEng.Properties.VariableNames), Response, "stable");
end
```

- **Raw predictor table exists** → original = the **model-ready raw screened
  columns** (datetime/duration and other non-fittable types filtered out — they
  still feed generation, they just can't be a learner's input), so the baseline
  reports the **lift of feature engineering + selection over the raw inputs**. This
  is the SMLT path and any domain path whose input was already a table of
  model-ready predictors.
- **No raw predictor table** (a signal vector, image, `timetable` the domain skill
  extracted from) → there are no columns a learner could fit on, so original = the
  **full extracted pool** (`FullEng`) and the baseline reports the **lift of
  consensus selection over the whole pool** ("did cutting to the selected set beat
  keeping everything?"). This is the case you'd otherwise mis-handle: passing empty
  raw columns collapses `baselineComparison` to engineered-vs-naive only (its
  `HasOrig = ~isempty(OrigX)` guard), losing the comparison entirely.

Either way it is the honest lift question **for that input**; the shipped decision
(selection on train rows) is unchanged. `assessKFold` sets its own equivalent
internally (`assessKFold.m:108`, raw-columns case). See
[domain-routing.md](domain-routing.md) §5.

- The **panel** of families follows `TargetModel`: `agnostic` → all three
  (bagged ensemble, linear, kernel); a declared family trains through that family
  alone (the user named their downstream model, so a reference lens adds nothing).
  The panel is evaluation-only — N families scored on the **one** engineered set;
  it never produces N feature sets.
- The **primary lens** (the family whose metrics become the top-level fields)
  defaults to the panel's first family. Under `agnostic` only, a `PrimaryFamily`
  of `"bag"`, `"linear"`, or `"kernel"` promotes that family instead — keeping the
  broad panel yet headlining on the chosen lens. A declared single-family model
  fixes its own primary; naming `PrimaryFamily` there errors.
- Linear/kernel learners **auto-encode categorical** predictors from a table (no
  manual dummy-coding); multi-class classification is wrapped in one-vs-one ECOC.
  No manual scaling — engineered features arrive standardized from the generator;
  originals are scored raw.
- Metric is **AUC + macro-F1** (classification) or **RMSE** (regression).
  `Result` carries `.Naive/.Original/.Engineered`, `.Improvement`, pass/beat
  flags, `.Primary`, and `.Panel`. With `InternalCV = false`, `.CV`/`.CVOriginal`
  carry `NumFolds = 0` (no variance computed).

`.Naive`, `.Original`, `.Engineered`, and `.Metric` are the primary family's
**scalars**; `.MacroF1` and `.Accuracy` are **structs** with `.Engineered`/`.Original`
fields — index into them, don't print them whole. `.Accuracy` is always present, with
a separate `.AccuracyReliable` flag (true when the training imbalance ratio ≤ 1.5).

**Narrate the metrics and imbalance in words.** State which metric leads and why
(classification: **AUC**, with **macro-F1** as a balanced-per-class read; regression:
**RMSE** vs a train-mean naive), before quoting its value. For classification, speak
the imbalance ratio (`Profile.ClassBalance.ImbalanceRatio`): when `.AccuracyReliable`
is false, say the classes are imbalanced (ratio in words, e.g. "about 4:1"), that raw
accuracy is therefore misleading, and that this is why AUC/macro-F1 lead — report
accuracy with that caveat, never drop it, and never name the flag field.

`plotValidationBaseline` takes the **`.Panel` struct array** — one naive/original/
engineered bar group per family (three under `agnostic`, one for a declared family).
Holdout point estimates carry no std, so no error caps. **Draw only when the report
is on** (`GenerateReport`) — like every figure, it's a report input:

```matlab
if GenerateReport
    plotValidationBaseline(Baseline.Panel, Baseline.Metric, OutputDir);
end
```

---

## 2. Model-free quality — `featureSetQuality`

Judges the representation with **no trained model**, comparing raw originals vs.
the selected engineered set along three model-agnostic dimensions. It fits nothing
and grades nothing for generalization, so it has no leakage exposure — it describes
the **shipped** set (refit on all working rows) and runs at delivery, not here
([deliver.md](deliver.md) §2b).

- **Relevance** — mutual information with the response, computed with the
  same algorithm `fscmrmr`/`fsrmrmr` use. `.Max` (peak single-feature signal) and
  `.NumRelevant` (breadth above threshold). A raw→eng rise means FE concentrated
  signal onto an accessible axis; a drop means it destroyed the best signal.
- **Redundancy** — pairwise MI across feature pairs, both the **mean** (set-wide
  duplication) and the **max** (the single worst near-duplicate pair the mean can
  hide). One statistic spanning numeric–numeric, categorical–categorical, and
  numeric–categorical pairs, so a numeric feature duplicating a categorical one
  is visible. Lower is better.
- **Compactness** — feature count and effective dimensionality (participation
  ratio of the numeric correlation eigenvalues). Lower effective dim at a
  comparable count is a tighter representation.

**Announce every model-free output.** The console close-out (`printSummary`, run at
delivery — [deliver.md](deliver.md) §6) prints the full
`relevance | redundancy | compactness` line — narrate all of it, not a subset.

Verdicts are diagnostic; this never gates the pipeline. Under `cross_validated`,
`assessKFold` also reports a **per-fold quality band** on these dimensions (§3) —
how much the recipe's output varies across resampling, not the shipped set's quality.

---

## 3. Performance strategy + two opt-in stability gates

Everything here **grades the procedure**; the shipped set is refit on all working
data ([deliver.md](deliver.md)) and never revised. Performance and stability are
separate axes.

**Performance** follows the evaluation strategy, and the two are mutually exclusive:

```matlab
if Splits.Strategy == "holdout"          % §1: point estimate on the held slice
    Baseline = baselineComparison(OriginalData, FullEng, TrainIdx, TestIdx, Response, ...
        OriginalPredVars, SelectedNames, ProblemType, TargetModel = TargetModel, InternalCV = false);
else                                     % cross_validated: the folds ARE the estimate
    rng(0, "twister");
    CVP = cvpartition(RawTrainTbl.(Response), KFold=5);   % height(...) for regression
    KFold = assessKFold(RawTrainTbl, Response, ProblemType, CVP, TargetModel = TargetModel);
end
```

`assessKFold` is **performance-only** (mean ± std over folds, plus a per-fold quality
band); it carries no stability read. Plot either with `plotValidationBaseline` —
holdout point estimates draw no error caps, k-fold panels do (pass a fold-count
`Subtitle`).

**Stability** is **two independent opt-in gates, both default OFF**, each requested
on its own under either strategy:

| | Gate 1 — `assessSelectionStability` | Gate 2 — `assessGenerationStability` |
|---|---|---|
| **Asks** | is the *selector* sensitive to row noise? | how much does the *whole recipe* move? |
| **Per subsample** | re-select on a **fixed** pool | **regenerate** the pool, then select |
| **Cost / fitter** | M× the consensus panel; no fitter | M× (generate + select); needs a re-runnable fitter (§3c) |

Both draw **M stratified subsamples** (`stratifiedSubsampleIndices`) and report the
**Nogueira** chance-corrected stability index + per-feature **selection frequency**;
features re-selected in ≥ `CoreThreshold` of subsamples are the **reliably
re-selected** list (say it in those plain words, never "consensus core"). Run on the
**same M and SubsampleFraction**, their Nogueira numbers are comparable and the
**gap is the generation-variance contribution** — so Gate 1 is the base and Gate 2's
gap only means something alongside it. The pool-regenerating Gate 2 additionally
reports **drift** (features present in only some subsamples' pools).

```matlab
rng(0, "twister");                                                    % caller owns the seed
SelStab = assessSelectionStability(StabEng, Response, ProblemType, ...          % Gate 1
    ExcludeFeatures = StabExclude, TargetModel = TargetModel, MaxRows = RowBudget);
GenStab = assessGenerationStability(RawTrainTbl, Response, ProblemType, ...      % Gate 2
    TargetModel = TargetModel, MaxRows = RowBudget);                             % Producer defaults to SMLT
```

`RowBudget` is the intake row budget: when the user names a working-set size for
speed, both gates stratified-downsample to it before the subsample re-runs (unset →
default 3000). It's the first lever to reach for on a slow audit — cut rows before
cutting `M` or `SubsampleFraction`, since fewer rows keeps the subsample count (and
the Nogueira estimate's precision) intact.

**Both gates are expensive and both default OFF.** Gate 1 re-runs the full consensus
panel M times over a pool built once; Gate 2 is heavier still — it also regenerates
the pool each subsample (≈ M× a full generation), slowing sharply on wide data.
**Announce the cost in one sentence before running either** (not just Gate 2), and
offer to lower `M` or `SubsampleFraction` if it's too slow. Both print a live
per-subsample cost line as they run.

`StabEng` is the fixed pool sliced to all working rows (matched to the shipped
selector); under `holdout` regenerate it on the working set first, since `FullEng`
was fit on `TrainIdx` alone. **Knobs (both gates):** `M` (default 30),
`SubsampleFraction` (0.5), `MaxRows` (3000), `CoreThreshold` (0.8, a reporting label
only). See each function's help for the full contract, scope caveats, and error ids.

### 3c. Domain path — generation stability needs a `Fit`

Gate 1 works on any path. Gate 2 and the `cross_validated` read both **regenerate**
the pool, so they need a re-runnable fitter. A domain path captures only a **frozen
`Apply`** (fit once, replayed), which cannot regenerate the pool — so it supplies the
optional `Recipe.Fit` (same signature as the producer contract, validated by
`buildRecipe`; see [domain-routing.md](domain-routing.md) §4). When present the
orchestrator passes `Recipe.Fit` as the `Producer`; it is **diagnostic-time only**
(inference always ships the frozen `Apply`). Absent `Fit`, both regenerating reads
are **N/A** — Gate 1 is the honest read; don't fake the rest.

### 3d. The figures — `plotSelectionDecision` + `plotSelectionStability`

**Only when the report is on** (`GenerateReport`) — under a report opt-out neither
is drawn. When on: `plotSelectionDecision` draws the **decision** (consensus-score
elbow, cut at `NSelect`), always, independent of whether a stability gate ran.
`plotSelectionStability` draws the **stability** of that decision (same features,
same rank order; bar length = re-selection frequency), and takes an optional
`GenStabSelection = GenStab` to add the generation bar series; with no stability read
it draws nothing and returns `[]`. Drawing spec is in each function's help.

```matlab
if GenerateReport
    plotSelectionDecision(VoteTable, NSelect, OutputDir);                        % elbow (always, when report on)
    plotSelectionStability(VoteTable, NSelect, SelStab, OutputDir, ...
        GenStabSelection = GenStab);                                             % second series optional
end
```

**Narrate it after drawing** — plain-language read of *this run's numbers*: the
Nogueira value on its scale (≥ 0.75 stable / 0.4–0.75 moderate / < 0.4 unstable);
any **fragile shipped picks** (shipped but rarely re-selected) named with their
percentages, flagged for confirmation, never removed; and, if Gate 2 ran, the gap as
the generation-variance read. This mirrors report.md ch. 7.

---

## Handing off

The orchestrator carries `Quality` (always) and one performance read — `Baseline`
(`holdout`) or `KFold` (`cross_validated`) — into the plain `Results` struct
delivery and reporting consume. A stability read is added only when its gate was
opted into: `SelStab` and/or `GenStab`. Record `Results.Strategy = Splits.Strategy`.
When no gate was requested, omit both and set `Results.StabilitySkipped = true` so
the report says "not requested" rather than "not recorded".

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
