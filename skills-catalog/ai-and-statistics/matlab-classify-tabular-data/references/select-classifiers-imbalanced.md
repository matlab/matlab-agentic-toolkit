# Imbalanced Data Modifier for Classifier Selection

Dispatched from `select-classifiers.md` when `isImbalanced = true`. This document contains only the **user-facing procedure** (the mandatory uniform-prior question and the extreme-imbalance advisory). The boosting-model list itself lives in `scripts/model_catalog/imbalanced_boosting.m`.

## What this reference decides

1. **Whether to use uniform prior** (mandatory user question).
2. **Whether to warn the user** about extreme imbalance.

The boosting model list is data, not procedure — see `scripts/model_catalog/imbalanced_boosting.m`.

## 1. Uniform-prior question (MANDATORY)

Ask the user this question before proceeding. Do NOT assume a default or skip this step:

> The data are imbalanced (ratio [imbalanceRatio]:1). Boosting models will include both RUSBoost (which undersamples the majority class) and standard boosting so they can be compared.
>
> Additionally, I can set `'Prior','uniform'` on all models to weight all classes equally. This increases sensitivity to minority classes at the cost of lower overall accuracy.
>
> Would you like to use a uniform prior? (yes / no)

If yes: set `useUniformPrior = true`. Used during training (Step 6) to pass `'Prior','uniform'` to `fit` and `fitc*` calls for all models. The `'Prior'` parameter cannot be passed to `template*` functions — it must be passed at training time.

If no: set `useUniformPrior = false` and proceed with default (empirical) priors.

## 2. Apply the boosting overlay

```matlab
run(fullfile(skillPath, 'scripts', 'model_catalog', 'imbalanced_boosting.m'));
% IMBALANCED_BOOSTING_MODELS is now in your workspace.
```

Substitute the branch's boosting recipes (LogitBoost, RoughAdaBoost, FineAdaBoost — anything whose `args.Method` is a boosting method other than `Bag`) with `IMBALANCED_BOOSTING_MODELS`. The overlay itself gates RUSBoost inclusion on `smallestClassSize >= THRESHOLDS.rusboost_smallest_class` (see `scripts/model_catalog/classifier_thresholds.m`) — you do not need to re-check that yourself; recipes with a false `condition(flags)` drop out during the normal filter.

## 3. Extreme-imbalance advisory

If `imbalanceRatio > THRESHOLDS.extreme_imbalance_ratio` AND `smallestClassSize < THRESHOLDS.extreme_smallest_class`, warn the user before proceeding. Interpolate `THRESHOLDS.exclude_class_min` into the prompt via `sprintf` — do not hardcode the number:

> The smallest class has only [smallestClassSize] observations with an imbalance ratio of [imbalanceRatio]:1. Consider:
> - Excluding classes with fewer than [THRESHOLDS.exclude_class_min] observations
> - Collecting more minority-class data
> - Reframing as anomaly detection rather than classification
>
> Would you like to proceed anyway, or exclude small classes? (proceed / exclude)

If the user chooses to exclude, remove classes with fewer than `THRESHOLDS.exclude_class_min` observations from both training and test data, then recompute class flags before continuing.

---

Copyright 2026 The MathWorks, Inc.
