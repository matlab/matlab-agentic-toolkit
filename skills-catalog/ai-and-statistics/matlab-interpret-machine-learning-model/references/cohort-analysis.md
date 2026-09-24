# Cohort / Subgroup Behavior

Compare how the model behaves across operational cohorts (segments, groups): which predictors drive it within each cohort, and how their influence shifts from one cohort to the next.

This is a **group-conditioned analysis**: pick a grouping variable, then compare the model's drivers across its groups.

## Data rule

The **cohorts come from the user** — the segments they want compared (a region, an age band, an operating regime). Subset the data by cohort. Keep the analysis **consistent across cohorts** so the differences are attributable to the cohorts themselves, not to the setup: for `shapley`, hold the **background (`Xtrain`) fixed** across all cohorts; for `permutationImportance`, use the **same predictors and response** on each cohort subset. Prefer **test** data; with training-only data, tell the user the comparison reflects training behavior.

## Decision rule

The per-cohort measure is the same choice as [agnostic-global-importance.md](agnostic-global-importance.md), applied within each cohort; see that reference for the full `permutationImportance`-vs-`shapley` reasoning. In brief:

- **Per-cohort `permutationImportance`** (R2024a) when the comparison is about **magnitude / rank** and a response is available per cohort: gives a stability std for free, answers what each cohort **relies on for accuracy**. It is **unsigned**, so it cannot show a direction flip.
- **Per-cohort `shapley`** (R2021a) when **direction** matters (does a predictor push up in cohort A but down in cohort B), when no response labels are available, or when a Shapley workflow is already running. Signed and complete.

Then, whichever measure is used, **compare with a shift-sensitive lens:**

- Report what **changed** between cohorts predictor-by-predictor: rank deltas and magnitude deltas (and, for `shapley`, direction changes).
- **Do not collapse the comparison to a single global-similarity score** (cosine, correlation, or the like). A global score averages over predictors and hides the local signal that matters: a single-predictor rank flip between two cohorts can leave a high similarity score intact, so the model reads as "reasoning the same way" across cohorts when a decisive predictor has in fact swapped rank. The predictor-by-predictor deltas are the deliverable; a summary score is not a substitute.

## Implementation

**Per-cohort `shapley`** — background fixed across cohorts:

```matlab
explA = shapley(Mdl, Xtrain, QueryPoints=XqueryCohortA, UseParallel="auto");
explB = shapley(Mdl, Xtrain, QueryPoints=XqueryCohortB, UseParallel="auto");
% Compare explA.MeanAbsoluteShapley vs explB.MeanAbsoluteShapley predictor-by-predictor:
% which predictors changed rank, magnitude, or direction between the cohorts?
```

For direction, read signed values from the explainer's `Shapley` property (`MeanAbsoluteShapley` is unsigned). Its value columns are `predictors × query points` matrices; a classifier has one per class, regression and a function handle have one named `Value`. (`Shapley` was `ShapleyValues` before R2024b.)

`swarmchart` / `boxchart` per cohort show each cohort's contribution distribution (see [agnostic-global-importance.md](agnostic-global-importance.md) for the plural-`plot` vs singular-`swarmchart`/`boxchart` method-name split).

**Per-cohort `permutationImportance`** — same response name on each subset:

```matlab
impA = permutationImportance(Mdl, XcohortA, "responseName", Options=statset(UseParallel="auto"));
impB = permutationImportance(Mdl, XcohortB, "responseName", Options=statset(UseParallel="auto"));
% Compare impA.ImportanceMean vs impB.ImportanceMean predictor-by-predictor.
```

Plot each cohort's `ImportanceMean` as a grouped bar chart with `ImportanceStandardDeviation` as error bars — overlapping error bars across cohorts signal the difference is within noise.

## If `Mdl` is a function handle

`permutationImportance` has **no handle path**, so a custom model compares cohorts with per-cohort `shapley` instead (the reroute from Decision 2). Build and call the `shapley` handle exactly as in [agnostic-global-importance.md](agnostic-global-importance.md) (pass `Xtrain`, set `CategoricalPredictors` or omit it when none, and state which predictors you are treating as categorical). For a multiclass model the handle returns a single class's score column, so `MeanAbsoluteShapley` covers that one class; build one explainer per class of interest (the per-class handle decided in [custom-model-wrapper.md](custom-model-wrapper.md)), and compare the same class across cohorts.

----

Copyright 2026 The MathWorks, Inc.

----
