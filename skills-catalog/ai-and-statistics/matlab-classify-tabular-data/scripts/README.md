# Use Built-in Functions and Treat Templates as Opaque

Follow these rules in every helper in `scripts/` and in any inline MATLAB you write that calls the same APIs.

## Use built-in functions, not custom code

Before writing any computation, check whether a built-in function or method already does what you need. The following must come from MATLAB:

- `kfoldLoss` / `loss` — never manually compute error rates from predictions. Two helpers are the only exceptions, each for a case those functions cannot score: `score_holdout_test` when `loss` returns NaN (a boosted ensemble that kept no learner), and `aggregate_nested_cv_loss` for out-of-fold predictions from separately optimized models. Both weight observations exactly as `loss` does.
- `testckfold` / `testcholdout` — never implement manual paired t-tests or McNemar's test
- `predict` — never reimplement prediction logic
- `binofit` — never manually compute binomial confidence intervals
- `cvpartition` — never manually split data into folds
- `friedman` — never compute ranks manually
- `bootci` — never resample manually for bootstrap CIs

## Do not inspect or deconstruct template objects

Template objects are opaque. NEVER access their internal properties (e.g., `.ModelParams`, `.ModelParameters`, `.LearnerType`) to extract parameters. This will error — internal property names are undocumented and change between releases.

**Wrong** (causes errors like "Unrecognized property 'LearnerType'"):
```matlab
mdl = fitclinear(X, Y, 'Learner', templates{m}.ModelParams.LearnerType, 'Solver', 'lbfgs');
```

**Right** (always works):
```matlab
mdl = fit(templates{m}, X, Y);
```

`fit(template, X, Y)` is the correct way to train from a template in the holdout path. It dispatches to the correct `fitc*` function internally. Do not attempt to replicate this dispatch yourself.

## Sparse data

- Do NOT call `var` on sparse matrices — it densifies the matrix and can exhaust memory. Use `scripts/helpers/find_zero_variance_columns.m` (sparse-safe) instead.

## Training-time rules

- Do NOT use `fitcecoc` for 2-class problems.
- Do NOT impute missing values before training. Models that cannot handle NaN natively (SVM, KNN, neural network) will still be trained on the data as-is — MATLAB's `fitcsvm`, `fitcknn`, and `fitcnet` remove rows with NaN internally. Do not pre-process or offer to pre-process missing data.
- Always use the `loss` method to compute error rates — never manually compare predictions to ground truth.

## Figures

- Use plain `figure;`. Do NOT pass `'Position'` — let MATLAB use its default placement.

----

Copyright 2026 The MathWorks, Inc.

----
