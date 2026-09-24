# Predictor Effect / Shape of One or Two Predictors (Agnostic)

Show how the model's output changes as one or two predictors vary. Three agnostic approaches; the y-axis is the tell for which to use.

## Data rule

Prefer **test** data: a shape estimated on training data reflects memorization, not generalization. With training-only data, tell the user the shape reflects training behavior.

**For a cohort effect shape**, subset the data by cohort and run PDP/ICE (or Shapley dependence) on **each cohort's subset separately**, producing one plot per cohort — a scoped effect-shape read for each. Each plot uses its own cohort's data, so no cohort is evaluated outside its observed range. State that each plot reflects that cohort only.

## Decision rule

**By default run PDP and centered ICE together** for the marginal-effect question (centered ICE is the go-to, not a fallback: PDP alone can hide heterogeneity ICE reveals); switch to Shapley dependence per the **When to use** column.

| Approach                                                             | Y-axis / what it shows                                                                                                      | Averaged or per-obs | When to use                                                                                                                                                                                                              | Chart                                  |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| **Partial Dependence (`partialDependence` and `plotPartialDependence`, R2020b)** | model's **predicted response** as the predictor varies (marginalized over others)                                           | averaged over data  | the user wants the **overall average shape** of one or two predictors' effect                                                                                                                                             | line (1-D) / surface (2-D)             |
| **ICE** (`plotPartialDependence`, `Conditional=`, R2020b)                    | same as PDP but **one curve per observation**; `centered` pins them at an anchor                                            | per-observation     | run alongside PDP by default: reveals **heterogeneity or an interaction** the average PDP hides                                                                                                                           | many lines; centered to compare shapes |
| **Shapley dependence** (`plotDependence`, R2024b; core `shapley` R2021a)                            | a predictor's **Shapley contribution** (signed attribution units) vs its value, over query points; color by a 2nd predictor | per-query-point     | a `shapley` object is already fitted in the workflow (`plotDependence` reuses it, so the view is nearly free); the user wants the effect in **attribution terms**; or to expose an interaction via 2nd-predictor coloring | scatter (numeric) / box (categorical)  |

## PDP / ICE API

```matlab
% Regression or classification. For classification, Labels is the 3rd positional arg.
plotPartialDependence(Mdl, "predictorName", "classLabel", Xtest, UseParallel="auto");

% ICE — both modes valid; centered is the default choice here.
% Regression:
plotPartialDependence(Mdl, "predictorName", Xtest, Conditional="centered", UseParallel="auto"); % or "absolute"
% Classification: the class label is still the 3rd positional arg (a label-less call errors on a classifier).
plotPartialDependence(Mdl, "predictorName", "classLabel", Xtest, Conditional="centered", UseParallel="auto");
```

- Classification `Labels` is the **3rd positional** argument; multiple labels give one line per class for a plain PDP.
- **ICE takes exactly one class label for a classifier** (passed as the 3rd positional arg, same as PDP): a label-less call errors, and a multi-label call with `Conditional` also errors. For a multiclass model, loop over `Mdl.ClassNames` and make one ICE plot per class.

## Shapley dependence API

`plotDependence` is available from R2024b (core `shapley` is R2021a). The chart type is automatic, not a choice: a **numeric** predictor gives a scatter, a **categorical** predictor gives a box chart.

For a multiclass model, `plotDependence` plots **one class per call** via singular `ClassName=` (plural `ClassNames` errors). With no `ClassName`, it **silently plots only the first class** (`ClassNames(1)`), so loop over `Mdl.ClassNames` for one plot per class and no class is missed.

```matlab
% Fit once over the query points, then plot per predictor. Reuse an existing
% explainer if the workflow already has one instead of refitting.
explainer = shapley(Mdl, Xtrain, QueryPoints=Xtest, UseParallel="auto");

plotDependence(explainer, "predictorName");                          % scatter for numeric, box for categorical
plotDependence(explainer, "predictorName", ColorPredictor="other");  % 2nd-predictor overlay
```

## Two-predictor views

Interactions are **visualize-only** here, not detected or quantified: 2-D PDP (`plotPartialDependence` on two predictors) and the 2nd-predictor color overlay on Shapley dependence. There is no interaction-detection procedure in this skill.

## If `Mdl` is a function handle

The handle is already resolved and validated (Before You Compute → Rule 1); here, only the call arguments change:

- **`partialDependence` / `plotPartialDependence`:** `CategoricalPredictors` and `OutputColumns` are **handle-only** — they error if passed alongside a model object, and exist to supply metadata the handle cannot. Set `CategoricalPredictors` (and **tell the user which predictors you are treating as categorical**, since it cannot be read from a handle). With matrix data and a handle, name the predictor by **numeric column index**, not a name like `"x1"`. For a multiclass model the handle can return the full score matrix; select the class to plot with `OutputColumns` — one handle, no rebuild.
- **Shapley dependence (`plotDependence`):** for the `shapley` call, pass the background (`Xtrain`) explicitly and set `CategoricalPredictors` (again, state which predictors are categorical; if there are **no** categorical predictors, omit it rather than passing `[]`, which `shapley` rejects). The handle returns a single class's score column, so build one explainer per class of interest (the per-class handle decided in [custom-model-wrapper.md](custom-model-wrapper.md)).

----

Copyright 2026 The MathWorks, Inc.

----
