# Local Explanation of Specific Predictions (Agnostic)

Explain why the model produced the output it did for one or more specific observations. Default to local `shapley`; use `lime` for a sparse top-k summary.

## Data rule

The **query point(s) come from the user** — the specific observation(s) they want explained. If the user has not pinned specific rows but wants to explore (for example, "explain some of the misclassified ones"), surface candidate rows for them to choose from (misclassified points, large-residual points, or rows of interest) rather than picking silently. Use **`Xtrain` as the background** and keep the query point out of its own reference set. If only training data is available for the background (a separate set or embedded in the model), tell the user explicitly.

## Decision rule

|                 | Local `shapley`                                                     | `lime`                                                                                                   |
| --------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| What it gives   | each predictor's **signed contribution** to (prediction − baseline) | a **sparse local surrogate** (linear or tree) → **top-k** predictors only                                |
| Required inputs | model + background + query point                                    | model + background + query point **+ k** (`NumImportantPredictors`; `fit` errors without it, no default) |
| Completeness    | sums exactly over **all** predictors                                | top-k only                                                                                               |
| Cost            | usually expensive; less so on the exact tree/linear path            | one surrogate fit per point                                                                              |
| Trust risk      | none (not a surrogate)                                              | valid **only if the surrogate is locally faithful**                                                      |
| Available from  | R2021a                                                              | R2020b                                                                                                   |

**Default to local Shapley**, and offer `lime` as the alternative at the plan-confirmation step (CONFIRM). `lime` is the better pick when:

- the user asks for LIME (or a surrogate-style explanation) by name;
- the user needs an inspectable local formula (linear coefficients or tree rules) rather than attribution scores.

## Construct once, fit per point

Build the explainer once (background fixed), then `fit` per query point. Do **not** reconstruct the explainer per point: that regenerates the background/synthetic data each iteration, which is needlessly expensive.

```matlab
% Shapley: construct once, fit per point
explainer = shapley(Mdl, Xtrain, UseParallel="auto");   % Xtrain is the background
explainer = fit(explainer, queryPoint);
plot(explainer)

% LIME: construct once, fit per point; k is the 3rd positional NumImportantPredictors
r = lime(Mdl, Xtrain);
r = fit(r, queryPoint, k);
```

The `lime` constructor fits a surrogate only if **both** `QueryPoint` and `NumImportantPredictors` are passed; otherwise `SimpleModel` is empty and `fit` must be called.

## LIME discipline

- `NumImportantPredictors` (k) is how many predictors LIME **fits the surrogate on** (it selects the k most locally-important predictors and trains the simple model on just those). If the user has not already provided this value, ask for it.
- Report the surrogate's agreement with the model on the fitted object. How to read it depends on the surrogate type: for a **classification** task the default surrogate is `ClassificationLinear`, and `SimpleModelFitted` is itself the agreement flag, `1` when the surrogate's prediction matches `BlackboxFitted` and `-1` when it differs, so no comparison is needed; with a **tree surrogate** (`SimpleModelType="tree"`), both `SimpleModelFitted` and `BlackboxFitted` are class labels, so compare them directly. For regression, compare the fitted values. If the user finds the agreement poor, suggest:
  1. increasing `NumImportantPredictors`
  2. switching `SimpleModelType` from linear to tree
  3. using shapley

## Counterfactuals (what would flip this prediction)

For a **single query point**, `counterfactuals` (R2026a) finds the smallest predictor change(s) that flip its prediction, answering "what would have to change for a different outcome."

```matlab
[ce, metrics] = counterfactuals(Mdl, observation, UseParallel="auto");
% observation: numeric row vector or one-row table
% Default NumCounterfactualExamples = 10 -> ce is a 10-row table of examples; metrics is a diagnostics table.
```

- **Binary classification only:** regression and multiclass reject with clear errors.
- **Slow and verbose:** runs an internal Bayesian optimization (tens of seconds to minutes, prints a bayesopt log). Pass `UseParallel="auto"` to distribute it, and set expectations with the user.
- It returns **several** counterfactuals (10 by default), each showing *a* minimal flip. Constrain them to plausible, on-distribution values with `ModifiablePredictors` (restrict to actionable predictors), `AnomalyModel` + `MaxAnomalyScore`, `MaxNumModifiablePredictors`, or `NumCounterfactualExamples`.
- It requires an SMLT classification model object; there is no function-handle path (see "If `Mdl` is a function handle").

## If `Mdl` is a function handle

The handle is already resolved and validated (Before You Compute → Rule 1); here, only the call arguments change:

- **`shapley`:** pass the background (`Xtrain`) explicitly as the second argument — with a handle there is no `Mdl.X` to fall back on — and set `CategoricalPredictors`, which defaults to none for a handle and cannot be read from one, so **tell the user which predictors you are treating as categorical** (and if there are **no** categorical predictors, omit it rather than passing `[]`, which `shapley` rejects). For a multiclass model the handle returns a single class's score column, so build one explainer per class of interest (the per-class handle decided in [custom-model-wrapper.md](custom-model-wrapper.md)).
- **`lime`:** set `Type=` (`"classification"` or `"regression"`) — it cannot be inferred from a handle — and pass the background (`Xtrain`) and `CategoricalPredictors` (again, state which predictors you treat as categorical).
- **`counterfactuals`:** no handle path (see above); explain the point with Shapley/LIME instead.

----

Copyright 2026 The MathWorks, Inc.

----
