# Adjust Classifier Selection for Imbalanced Data

Follow this when `isImbalanced = true`: ask the mandatory uniform-prior question, apply the boosting overlay, and give the extreme-imbalance advisory when it applies.

## 1. Uniform-prior question (MANDATORY)

Ask the user this question before proceeding. Do NOT assume a default or skip this step:

> The data are imbalanced (ratio [imbalanceRatio]:1). Boosting models will include both RUSBoost (which undersamples the majority class) and standard boosting so they can be compared.
>
> Additionally, I can set `'Prior','uniform'` on all models to weight all classes equally. This increases sensitivity to minority classes at the cost of lower overall accuracy.
>
> Would you like to use a uniform prior? (yes / no)

If yes: set `useUniformPrior = true`; otherwise `false`. Pass it on as SKILL.md Steps 5 and 6 show (`'UseUniformPrior'` to `build_model_definitions` on the CV path, the 6th argument of `train_and_score_holdout` on the holdout path); the helpers add `'Prior','uniform'` to every fit. Do not type `fitc*` calls to add it.

If no: set `useUniformPrior = false` and proceed with default (empirical) priors.

## 2. Apply the boosting overlay

```matlab
run(fullfile(skillPath, 'scripts', 'model_catalog', 'imbalanced_boosting.m'));
% IMBALANCED_BOOSTING_MODELS is now in your workspace.
```

Pass `IMBALANCED_BOOSTING_MODELS` to `build_model_definitions` as `'ImbalancedOverlay'` (SKILL.md Step 5); the helper replaces the branch's boosting recipes (LogitBoost, RoughAdaBoost, FineAdaBoost — any boosting method other than `Bag`) with it. Do not edit the recipe list yourself. The overlay itself includes RUSBoost only when `smallestClassSize >= THRESHOLDS.rusboost_smallest_class` — you do not need to re-check that yourself; recipes with a false `condition(flags)` drop out during the normal filter.

## 3. Extreme-imbalance advisory

If `imbalanceRatio > THRESHOLDS.extreme_imbalance_ratio` AND `smallestClassSize < THRESHOLDS.extreme_smallest_class`, warn the user in chat before any model is trained and wait for the answer. In a non-interactive session, include the warning in your reply and say which choice you applied (the user's instruction, or proceeding with all classes). Interpolate `THRESHOLDS.exclude_class_min` into the prompt via `sprintf` — do not hardcode the number:

> The smallest class has only [smallestClassSize] observations with an imbalance ratio of [imbalanceRatio]:1. Consider:
> - Excluding classes with fewer than [THRESHOLDS.exclude_class_min] observations
> - Collecting more minority-class data
> - Reframing as anomaly detection rather than classification
>
> Would you like to proceed anyway, or exclude small classes? (proceed / exclude)

If the user chooses to exclude, remove classes with fewer than `THRESHOLDS.exclude_class_min` observations from both training and test data, then recompute class flags before continuing.

----

Copyright 2026 The MathWorks, Inc.

----
