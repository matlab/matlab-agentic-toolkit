# Global Predictor Importance (Agnostic)

Answer two distinct questions with different techniques:

- **(a) Magnitude** — which predictors have the largest average impact. `permutationImportance` (bar + std) or `shapley` importance = mean|Shapley| (bar). Both are unsigned.
- **(b) Direction** — the sign of each predictor's contribution. `shapley` **summary** swarm/box chart (signed per-observation contributions). For the *shape* of that effect (curve, knee), see [agnostic-effect-shape.md](agnostic-effect-shape.md).

## Data rule

Prefer **test** data: importance on training data reflects what the model memorized (inflated for an overfit model), while test reflects generalization. This is a validity preference, not a hard gate: both agnostic techniques run on train or test. With **training data only**, both techniques are affected by what the model memorized, so warn the user that the result reflects **training behavior, not generalization**. With **no data at all**, agnostic is impossible: fall back to a native measure ([native-importance-measures.md](native-importance-measures.md)), or for a bagged ensemble use `oobPermutedPredictorImportance` (honest even without a test set). See Decision 2 Step 1 for the full native gate. With **test but no training data**, prefer `permutationImportance` — it needs no background, whereas `shapley`'s background would collapse onto the test query points.

## Decision rule

They measure different things and can legitimately disagree; the disagreement itself signals redundancy or correlation.

|                    | `permutationImportance`                                                                                  | `shapley` importance (mean\|Shapley\|)                               |
| ------------------ | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Measures           | drop in **model performance** when a predictor is shuffled → what the model **relies on to be accurate** | average **contribution magnitude** → what **moves predictions** most |
| Needs response?    | yes                                                                                                      | no                                                                   |
| Stability estimate | std for free                                                                                             | none                                                                 |
| Available from     | R2024a                                                                                                   | R2021a                                                               |

**The two answer different questions** — `permutationImportance` measures what the model **relies on for accuracy** (importance-to-accuracy), `shapley` what **moves predictions** (importance-to-predictions) — so the user's goal and the data decide, not a fixed winner. **Use `shapley` when** there are no response labels (it needs none), the goal is importance-to-predictions rather than importance-to-accuracy, or a Shapley workflow is already running. **Otherwise `permutationImportance` is a reasonable default** — it gives a stability std for free. When it is picked this way (no goal or data reason singled it out), offer `shapley` as the alternative at the plan-confirmation step.

### Shapley view: bar vs summary

- **Bar plot (mean|Shapley|) using `plot(explainer)`** — magnitude only; compact ranking. Use when the question is just "which predictors" (no direction needed), or when there are too many predictors for a swarm/box to render cleanly.
- **Summary swarm/box using `swarmchart(explainer)` / `boxchart(explainer)`** — sign + spread; contains the ranking and shows direction/variation. **Default: swarm** (strictly more informative); use **box** when too many points to render cleanly.

## Implementation

**`permutationImportance`** — returns a table with `Predictor`, `ImportanceMean`, `ImportanceStandardDeviation`:

```matlab
% Xtest here is a table containing the response column; pass its name as the 3rd arg.
% For a predictor matrix, pass a separate Y vector instead: permutationImportance(Mdl, Xmat, Y)
imp = permutationImportance(Mdl, Xtest, "responseName", Options=statset(UseParallel="auto"));
```

**Report the stability, don't drop it.** Report the `ImportanceStandardDeviation` alongside each predictor's `ImportanceMean`, and render the ranking as a bar chart with error bars so the spread is visible.

**It can be slow — weigh the model against the data, not size alone.** `permutationImportance` re-scores the whole dataset once per predictor, per permutation, so cost rises with both the number of **observations** and the number of **predictors**. But the dominant factor is how expensive one prediction is, which you can judge from what the model is: a **function handle or `dlnetwork`** (a network forward pass per call), a **`RegressionGP`** (prediction scales with training-set size), a **GAM**, or a **large ensemble** (`NumTrained` in the hundreds) are expensive; a single tree, linear/GLM, or discriminant is not. Warn the user it may take a while when an **expensive model** meets a dataset with **more than 1000 observations and more than 5 predictors** — for example, a GAM at 8000×90 runs for many minutes. The larger the dataset in either dimension, the longer it runs. A large dataset on a light model is usually fine.

When you warn, **offer** these levers as explicit choices — never apply them silently, since each changes what the result means:

- **Fewer observations** — evaluate on a representative subsample (pass a smaller `X`). The result is then an estimate on a subset, not the full data.
- **Fewer predictors** — `PredictorsToPermute` (default `"all"`) restricts scoring to a named subset; the predictors left out get **no** importance reported (excluded, not found unimportant).
- **Fewer repeats** — `NumPermutations` (default `10`) cuts runtime roughly linearly when lowered, but a smaller value gives a noisier ranking **and** a less reliable `ImportanceStandardDeviation` (the stability estimate). A speed/stability trade, not free.

If the user declines the levers, keep MATLAB's defaults.

**`shapley` importance** — no response needed; returns `MeanAbsoluteShapley` (one column per class):

- **Set expectations before a slow operation.** Before a long-running call, tell the user in one sentence what is running and that it may take a while; don't leave them watching a silent stall. Runtime scales with the **number of query points times the per-prediction cost**, so it is worst on expensive models (for example a custom model whose handle runs a network) and whenever `shapley` falls back to its **kernelSHAP** algorithm — a large query set there can run for many minutes. When the query set is large (more than 100 observations) on such a model, say so and **offer to explain a representative subset** of query points as an explicit user choice — this is different from silently dropping query points to fake tractability (for background cost, lower `NumObservationsToSample` instead, which has a default value of 100, per above).

**Check the algorithm before computing.** Construct the explainer with no query point and read `explainer.Method` — this computes nothing (`ShapleyValues` stays empty):

```matlab
explainer = shapley(Mdl, Xtrain);   % construct only; nothing computed yet
algo = explainer.Method;
```

- **`interventional-tree` / `interventional-linear`** → exact (no sampling).
- **`interventional-kernel` / `conditional-kernel`** → sampled and slower; set expectations about runtime per the bullet above.

Then compute the importance over the query points:

```matlab
explainer = shapley(Mdl, Xtrain, QueryPoints=Xtest, UseParallel="auto");
mas = explainer.MeanAbsoluteShapley;   % the values, for reporting

% Render the summary with the built-in views — do not hand-build a bar chart from mas.
plot(explainer);         % mean|Shapley| magnitude bar
swarmchart(explainer);   % signed per-observation summary (default; box if too many points)
```

Method-name split: `plot(explainer, ClassNames=...)` is **plural** and takes several classes at once; `swarmchart` / `boxchart(explainer, ClassName=...)` are **singular** and render **one class per call**, so for a multiclass model call them once per class. Using the plural name on swarm/box errors.

## If `Mdl` is a function handle

`permutationImportance` has no handle path, so a custom model cannot use it — use `shapley` importance (`MeanAbsoluteShapley`) instead (the reroute from Decision 2). For the `shapley` call, pass the background (`Xtrain`) explicitly and set `CategoricalPredictors` — it defaults to none for a handle and cannot be read from one, so **tell the user which predictors you are treating as categorical** so they can correct it. If there are **no** categorical predictors, **omit `CategoricalPredictors` entirely — do not pass `[]`**: `shapley` rejects an empty value ("Expected input to be nonempty"). For a multiclass model the handle returns a single class's score column, so `MeanAbsoluteShapley` covers that one class; build one explainer per class of interest (the per-class handle decided in [custom-model-wrapper.md](custom-model-wrapper.md)). A handle explainer has no class names (its `Shapley`/`MeanAbsoluteShapley` tables carry a single `Value` column), so plot its summary with a bare `plot(explainer)` / `swarmchart(explainer)` / `boxchart(explainer)` and **do not pass `ClassName=`/`ClassNames=`** — those accept a class only for a real classification model.

----

Copyright 2026 The MathWorks, Inc.

----
