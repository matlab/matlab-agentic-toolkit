# Deliver — the feature set and a self-contained inference script

Delivery turns the run into artifacts the user keeps: the engineered+selected
feature set, and — the important one — a **self-contained inference function** that
reproduces that exact set on new raw data. Everything is written to the confirmed
output directory (a **hard-halt** collected at intake — never write elsewhere).

The key simplification: the pool `Recipe` **is** the inference recipe, and
`writeInferenceScript` is **generator-agnostic** — it packages whichever of the two
contract shapes built the pool, dispatching on the recipe just like the rest of the
pipeline. For the SMLT path the recipe is a `FeatureTransformer` and
`transform(Transformer, NewRawTbl)` reproduces the engineered columns; for the
domain path it is a `Kind=="domain"` struct whose `.Apply` replays the captured
extraction. Either way there is no op-log to replay — delivery just packages that
recipe plus the selected names, and the emitted function **inlines** everything it
needs (it never calls this skill's `scripts/`, which aren't on the path at
inference time).

---

## 1. Domain path only — validate and request the selected-only extractor

On the **domain path**, selection has now fixed which features to build, so ask
the domain skill for a targeted `ApplySelected(RawTbl, SelectedNames)` — an
extractor that computes **only** the selected columns, sparing inference the cost
of regenerating the whole pool. Attach it to the recipe and validate it against the
pool, in deliver mode. Do this **before the §2 refit**, on the train-fit pool from
the pool phase (`FullEng`, all rows, row-aligned with `ScreenedTbl`):

```matlab
Recipe.ApplySelected = < the domain skill's selected-only extractor >;
validateRecipe(Recipe, FullEng, ScreenedTbl, ResponseVar = ResponseVar, ...
    SelectedNames = SelectedNames, CheckIdx = TestIdx);
```

`CheckIdx` names rows **outside the fit** — otherwise a response-based out-of-fold
encoding false-mismatches (fit rows hold OOF values, `Apply` replays the full map).
`TestIdx` (the held slice) is that clean set under `holdout`. Under
`cross_validated` there is no held slice, so no in-pipeline row is OOF-clean — omit
`CheckIdx` and note that a response-based domain encoding's *values* can't be
re-verified here; the describe and over-return contract checks still run. This
validates the `ApplySelected`↔`Apply` **contract**, which is a property of the
handles; the §2 refit re-attaches the same handle to the shipping recipe.

It errors (`validateRecipe:applySelectedMismatch` / `:missingArtifact`) if the
handle is absent, over-returns, or disagrees with the pool; on error **re-request
it and re-validate**. If the pool doesn't decompose per-feature (all features
share one expensive intermediate), the extractor may internally fall back to
full-`Apply`-then-subset — correct, if not cheaper. The **SMLT path skips this
step**: `transform` already subsets natively.

---

## 2. Refit the shipping recipe on all working data

Generation and selection so far ran on `TrainIdx` — that fit is the one assessment
**graded**. What **ships** is refit on **all working rows** (`WorkingIdx`), so the
delivered recipe sees every row the user let the pipeline use, not just the training
part. Re-run generation and selection once more on the full working set (on the
domain path, the domain skill re-runs its extractor on `WorkingTbl` and you
re-attach the `ApplySelected` validated in §1):

```matlab
WorkingTbl = ScreenedTbl(WorkingIdx, :);                  % Level-0 carve already excluded
[~, Recipe, GenInfo] = generateFeatures(WorkingTbl, Response, ProblemType, OptArgs{:});
FullEng = transformFeatures(Recipe, WorkingTbl);
FullEng.(Response) = WorkingTbl.(Response);
[SelectedNames, VoteTable, PanelInfo] = runConsensusSelection( ...
    FullEng, Response, ProblemType, ExcludeFeatures = GenInfo.BinaryReliant);
```

Under `cross_validated`, `TrainIdx` already spans all working rows, so this
re-confirms the same fit; under `holdout` it also retrains on the slice held for the
point estimate. Either way the reported held-out / cross-fold number is therefore
**conservative** — it grades a recipe trained on *less* data than the one delivered.
The report states this ([report.md](report.md)). The `Recipe` and `SelectedNames`
carried into the rest of delivery are these refit ones. (The consensus figure and
stability read reflect the graded train-fit; only the shipped artifact is refit.)

---

## 2b. Model-free quality on the shipped set — `featureSetQuality`

Run the quality read ([assess.md](assess.md) §2) here, on the §2 refit outputs, so
it describes the **shipped** set on all working rows (both strategies):

```matlab
Quality = featureSetQuality(WorkingTbl, FullEng, (1:height(WorkingTbl))', Response, ...
    OriginalPredVars, SelectedNames, ProblemType);
```

Populates `Results.Quality` → report ch6.

---

## 3. The inference script — `writeInferenceScript`

```matlab
[ScriptPath, MatPath] = writeInferenceScript(Recipe, SelectedNames, OutputDir, ...
    DatasetName = DatasetName, ...     % names the file pair; sanitized to a valid identifier
    ResponseVar = ResponseVar);        % documented as optional/ignored on new data
```

`Recipe` is whatever built the pool — the SMLT `FeatureTransformer` or the
`Kind=="domain"` struct; `writeInferenceScript` dispatches on it and errors with
`writeInferenceScript:unknownRecipe` on anything else. It writes two files whose
stems match, so the pair is unambiguous and relocatable together:

- **`fe_transform_<dataset>.mat`** — the recipe (`Transformer` on the SMLT path,
  `Recipe` on the domain path) + `SelectedNames`, the complete inference state.
- **`fe_transform_<dataset>.m`** — a function that loads its companion `.mat` (via
  `mfilename`, so the pair moves together), reproduces the pool, and subsets to the
  selected columns:

  ```matlab
  Features = fe_transform_<dataset>(NewRawTbl);
  ```

The emitted function performs the same two contract halves `selectFeatures` does
(reproduce the pool, then filter to the selected names in order), but **inlines**
them rather than calling into `scripts/` — the SMLT branch subsets natively through
`transform(Transformer, RawTbl, SelectedNames)`; the domain branch replays
`Recipe.Apply` and subsets by name with an inlined missing-column guard. That keeps
the deliverable self-contained: it depends only on base MATLAB (plus whatever
`Apply` itself carries), never on this skill. `NewRawTbl` must carry the same
predictor columns present at fit time; the response column is optional and ignored
if present.

**Selection may have kept the whole pool** — then `SelectedNames` covers
everything and the filter is a reorder, not a cut. That is correct, not
degenerate (see [feature-pool.md](feature-pool.md)).

---

## 4. The selected feature set — an in-workspace check, NOT a written file

Reproduce the delivered set from the recipe to confirm it matches what inference
will emit:

```matlab
SelectedTbl = selectFeatures(Recipe, RawTbl, SelectedNames);   % verification only — do NOT write to disk
```

`SelectedTbl` is a **workspace verification value**, not a deliverable. **Do not
write it to disk** — no `features_<dataset>.mat`, no `.csv`, no `writetable`/`save`
of the feature values. The delivered inference script (§1) *is* how the user
regenerates this exact table on demand — `fe_transform_<dataset>(RawTbl)` returns
it — so a materialized dump is redundant and can drift from the recipe. If a user
explicitly asks for a portable feature-value file, that is a one-off they
requested, not part of the standard deliverables; write only what they named, in
the format they asked for, and nowhere else.

If — **and only if** — the user explicitly asks for the recipe that **generated** the
pool (to re-run generation themselves, not just replay it), that is another on-request
one-off. **Do not read [reproduce-pool.md](reproduce-pool.md) as part of a normal
run** — open it only when that specific request is made. It reassembles generation
from the run's own captured pieces and verifies the result against this shipped set;
the inference script above stays the source of truth for exact feature values.

---

## 5. Figures

**Gated on `GenerateReport` (intake).** Figures exist only to illustrate the report,
so on a report opt-out **draw none of them** — skip every plotter call, no SVG is
written, and the inference script + state `.mat` (§1–4) ship as the whole
deliverable. When the report is on, each plotter writes a `fig_*.svg` into
`OutputDir` under the exact name the report embeds:

- `plotSelectionConsensus` — rank-agreement heatmap across the ranker panel
  (`fig_selection_consensus.svg`).
- `plotSelectionDecision` — the consensus-cut elbow (`fig_selection_decision.svg`),
  the selection decision itself. Always drawable, even when stability was skipped;
  the report shows it in the selection chapter.
- `plotSelectionStability` — per-feature selection frequency across subsamples
  (`fig_selection_stability.svg`), the stability of that decision, shown in the
  stability chapter. Fed the fixed-pool read (`SelStab` from
  `assessSelectionStability`) as `Stability`; pass `GenStabSelection = GenStab` (from
  `assessGenerationStability`) to add the generation bar series (grouped bars + drift
  band). With no stability read it draws nothing and returns `[]`.
- `plotValidationBaseline` — grouped naive/original/engineered bar chart, one group
  per model family (`fig_validation_baseline.svg`). Under `holdout` it's a plain
  point-estimate chart with no error caps; under `cross_validated` the per-family
  panel carries mean ± std, so the bars draw error caps. Fed `Baseline.Panel` under
  `holdout` or the mean-mapped `KFold.Performance.Panel` under `cross_validated`
  ([assess.md](assess.md) §1 and §3b give the exact calls).

---

## 5b. Save the full results — `saveResults` (unconditional)

Assemble the plain `Results` struct (delivery already holds every sub-struct — see
[report.md](report.md) for the assembly), then save it to disk **regardless of the
report opt-out**:

```matlab
ResultsMatPath = saveResults(Results, OutputDir, DatasetName = DatasetName);
```

This writes `fe_results_<dataset>.mat`, the machine-readable companion to the
written report. The report only *previews* the top features (the vote and stability
tables are windowed, the plots capped); this `.mat` holds every table at full
resolution, so a run's numbers are always recoverable — `load` it and read
`Results.VoteTable`, `Results.SelStab.SelectionFrequency`, etc. It is **not** gated
on `GenerateReport`: on a report opt-out the prose and figures are skipped but this
file still ships, alongside the inference script + state. `Results` is also live in
the workspace this session — the same data, no load needed. Add
`fe_results_<dataset>.mat` to `Results.Deliverables` before the summary so it is
listed. (The `Results` assembly is unconditional; only the report *generation* in
[report.md](report.md) is gated.)

---

## 6. Console summary

Print a short human-readable close-out with `printSummary`:

```matlab
printSummary(Results);
```

It reads the **same plain `Results` struct** the report generators consume (see
[report.md](report.md)), but it is a **summary, not a copy of the report**: a few
headline lines that point at the report rather than reproduce it. Every line
guards on field presence, so a partial `Results` prints what it has and omits the
rest. It names where the full data lives — the `fe_results_<dataset>.mat` file and
the live `Results` workspace variable — but is a pointer, never a pass/fail gate;
see the function's own help for the exact lines.

Assemble `Results` first (delivery already holds every sub-struct), then call
`printSummary(Results)` after the file reports are written.

---

## Deliverables list

Collect the emitted file names into `Results.Deliverables` (a string array) so the
report's Deliverables chapter lists them. Only files actually written are listed —
under a report opt-out the `fig_*.svg` and `feature_report.*` rows are absent, and
`Deliverables` is the inference script + state + the results `.mat`. Full set
(report on):

```
fe_transform_<dataset>.m     (always)
fe_transform_<dataset>.mat   (always)
fe_results_<dataset>.mat     (always)
fig_selection_consensus.svg  (report on)
fig_selection_decision.svg   (report on)
fig_selection_stability.svg  (report on)
fig_validation_baseline.svg  (report on)
feature_report.md            (report on; + feature_report.pdf if Report Generator present)
```

The delivered set itself is **not** a file — it is reproduced on demand by the
inference script above. Do not add `features_<dataset>.*` to this list.

---

## Handing off

Delivery and reporting share the same plain `Results` struct. Once the files are
written and their names recorded, reporting ([report.md](report.md)) assembles the
markdown (always) and the PDF (if available) over that struct.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
