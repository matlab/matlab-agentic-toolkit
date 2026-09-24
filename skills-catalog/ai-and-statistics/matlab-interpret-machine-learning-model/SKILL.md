---
name: matlab-interpret-machine-learning-model
description: Interpret and explain a trained tabular machine-learning model (classification or regression) in MATLAB. Find which predictors, features, or columns matter most; explain why the model made a specific prediction, including diagnosing predictions it got wrong; show how a predictor affects the output; and compare how the model behaves across cohorts or subgroups. Uses model-agnostic techniques and model-native measures, and works on custom models (such as a dlnetwork) through a prediction function handle. Use for model interpretability, explainability, and feature-importance questions on tabular data, not for training, tuning, feature selection, deploying models, or models trained on image, text, signal, or other non-tabular data.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Interpret a Trained Tabular Model

Interpret a trained tabular model — a built-in Statistics and Machine Learning Toolbox (SMLT) classifier or regressor, or a custom model reached through a prediction function handle — by matching the user's intent to the right techniques, handling the custom-model case correctly, and avoiding the failure modes agents fall into on this workflow. This skill bundles the workflow in `references/` (per-technique procedures and branch tables read on-demand) and `scripts/` (the `functionHandleMap` helper). Do not invoke files in `references/` as separate skills — they are only read when the corresponding step runs.

## When to Use

- "Which predictors matter / feature importance / what drives the model"
- "Why did the model predict X for this case / explain this prediction"
- "What shape is the effect of predictor P / partial dependence / how does the prediction change with P"
- "Why did the model get these cases wrong / diagnose these errors / what would flip this"
- "Does the model behave differently for group Y / segment / cohort"
- Any of the above over a **custom / non-SMLT model** (a `dlnetwork` or a prediction function handle)

## When NOT to Use

- Training, tuning, hyperparameter search, or feature selection (this skill interprets an already-trained model)
- Deployment or code generation (downstream)
- Models trained on image, text, signal, or other non-tabular data
- Multi-response regression or multilabel classification (a model with more than one response variable); the interpretability functions here assume a single response
- A **partitioned / cross-validated model** (`ClassificationPartitionedModel`, `RegressionPartitionedModel`, or any object from `crossval` / a `KFold`/`Holdout`/`CVPartition`/`CrossVal` option); it holds K fold-models rather than one fitted model, so there is no single model to interpret
- The user wants to work in the Classification Learner or Regression Learner **app** → use `matlab-use-machine-learning-apps`
- Acting on a diagnosis (retraining, collecting data); this skill produces the diagnosis only

## Communication Style While Running This Skill

How you talk to the user matters as much as the analysis. These rules apply from the first message to the last.

- **Talk about their model and results, never the skill's machinery.** The user does not know this skill has sections, steps, references, or rules — do not mention them. Never say "the skill says," "the skill is clear that," "per the routing," "Decision 2," "the native gate," "the level," or "global vs cohort" — these are internal framing. State the reasoning as your own ("cohorts should come from you, so tell me which") and name what you are *doing* ("comparing the groups"), not the skill's name for it. The test: if a sentence only makes sense to someone who has read this skill's files, rephrase it. Domain terminology that stands on its own in a sentence is fine. **The exception:** if a real problem appears, name it plainly, and only then is it fine to point at the internal file where the fix belongs.
- **Read reference and support files silently — the STEP: heading is the only thing you announce.** Never narrate a file read. Any sentence that opens with "Let me read…", "Let me check…", "Let me pull up…", "Now let me read…", or "let me look at the … approach/reference/routing" is banned — delete it. The reads that prepare a phase happen silently *under* that phase's STEP: heading; do not emit a line between headings that describes reading, checking, or pulling up a file. The user does not know these files exist. After a read, the next thing you say is a fact about their model or the plan, never what you just read.
- **Announce each phase once, on entry, as a `STEP:` heading — not on every step within it.** As you begin a phase, mark it with a short heading of the form **STEP: phase name** on its own line, so the user can see at a glance where things stand. The phases: *STEP: Establishing inputs → STEP: Clarifying scope and intent → STEP: Confirming the plan → STEP: Creating and validating the function handle* (only when a custom model needs one) *→ STEP: Running the analysis → STEP: Results and summary.* Emit the heading a single time on entry; do not re-stamp it on each MATLAB call or sub-step inside the phase.
- **Facts only until the plan.** While establishing inputs and clarifying scope, report what is there — model kind, task, predictors, data — and nothing about technique. Do not pre-announce routing ("this will run agnostically through a prediction handle," "the model has no native measures," "this opens up …"). The routing rationale is the plan's job; stating it early commits you before scope is even chosen.
- **Format for scanning.** Put each heading or item label on its own line, with its explanation on the next — never a bold label with a long sentence trailing inline. One idea per sentence. A multi-part finding (a number, a caveat, a metric) is several lines or bullets, not one packed paragraph. **Any warning, caveat, or explicit note gets its own line** — never buried inside a sentence, since that is exactly what a user skims past. The reader should be able to skim the labels alone and know what happened.

## STEP: Establishing inputs

Before scoping the question, inventory what is available and **state it back** using relevant fields below, then **ask the user to confirm or correct it before scoping**. This is the first thing reported. Report **facts only**: do not pre-announce or hint at routing (native vs agnostic, which technique, "opens up …"); the routing rationale belongs in Confirming the plan, after Decisions 1 and 2 have run.

Load and inspect the model in MATLAB, then report:

- **Model** — run `class(Mdl)` and report it; if only a function handle is provided with no model, report it as "function handle". The class string may be namespaced (e.g. `classreg.learning.classif.ClassificationEnsemble`); report the kind from the trailing class name, not a leading prefix. Model determines whether native measures exist at all (a `dlnetwork` or function handle has none) and feeds the native gate in Decision 2. If `class(Mdl)` is a **partitioned model** (the class name contains `Partitioned`, e.g. `ClassificationPartitionedModel`), stop and tell the user this skill cannot interpret it: it holds K cross-validation fold-models, not one fitted model, so there is no single model to attribute. Do not proceed with an analysis.

- **Task** — classification or regression, and the response name. For an SMLT model, `Mdl.ResponseName` gives the response — it errors on `dlnetwork`. For a **classifier**, `Mdl.ClassNames` gives the classes (its count is binary vs multiclass); `ClassNames` exists on classifiers only.

- **Predictors** — count, names, and which are categorical. SMLT models: `Mdl.PredictorNames`; categoricals from `Mdl.CategoricalPredictors` or `Mdl.VariableInfo.IsCategorical` (`LinearModel` / GLM, which have no `CategoricalPredictors`).

- **Training data** — carried in the model, provided separately, or none; and its size. Full SMLT models usually carry it (`Mdl.X`/`Mdl.Y`, or `Mdl.Variables` for `LinearModel`/GLM); compact models and handles do not.

- **Test data** — provided or none, and its size.

**A `dlnetwork` or a function handle carries none of this metadata** — `ResponseName`, `ClassNames`, `PredictorNames`, and `CategoricalPredictors` all error, and a `dlnetwork`'s only readable width (`net.Layers(1).InputSize`) is the post-encoding channel count, not the predictor count. Because the object embeds no data, the user must supply a training and/or test set for these models — read the predictor names and count from that data's variable names, and which predictors are categorical from its column types. The task and response name are not recoverable from the object; confirm them with the user if not clear from the data.

The available data constrains which techniques are possible. **State the inventory back and ask the user to confirm or correct it before scoping** — call out any missing data especially. **No test set** (training only): without it, results reflect training behavior rather than generalization — proceed on training data with that caveat if the user confirms none. **No data at all**: this limits which interpretability functions can run, so ask whether any data can be provided before falling back. If the user has data, have them load it. Carry the confirmed inventory into Decision 2 and the setup rules.

## STEP: Clarifying scope and intent

If the user's prompt already makes the intent clear, read it off (Decision 1) and do not ask. If the skill was invoked bare, or the ask is vague, present this menu **once**, verbatim. Present this menu **only after inputs are established** (the inventory has been stated back) — never in the same message to help identify inputs.

> What do you want to learn about this trained model?
> 1. **Which predictors matter** — rank the predictors by how much each drives the model, across the whole dataset.
> 2. **Shape of a predictor's effect** — how the prediction changes as one or two predictors vary.
> 3. **Why a specific case was predicted** — a per-observation explanation for one or more rows, including diagnosing cases the model got wrong.
> 4. **Cohort differences** — rank the predictors within each cohort (a subgroup you name) and compare, to see what drives the model differently from one cohort to the next.

Treat a free-text answer, or more than one number, as one or more intents and resolve each in Decision 1. If the answer names cases or a subgroup, capture which ones.

## Decision 1: What Is the User Asking?

| Intent                                                  | Level            |
| ------------------------------------------------------- | ---------------- |
| Which predictors drive the model (magnitude, direction)     | global           |
| Shape of one or two predictors' effect                      | global or cohort |
| Why the model predicted Y for this case                     | per-observation  |
| Does behavior differ across cohorts (importance per cohort) | cohort           |

**Level follows from intent.** Importance is split by level across two menu items — "which predictors matter" is **global**, "cohort differences" is **cohort** — so neither asks; picking both just runs each. "Why the model predicted Y" is **per-observation**. Only **effect shape** has an open level: ask once — *"Across the whole dataset (global), or within a specific cohort? If a cohort, tell me which."* A cohort named anywhere in the request resolves this without asking.

There is no standalone "interaction detection" intent: two-predictor interactions are visualize-only inside effect-shape (2-D PDP, Shapley 2nd-predictor coloring).

A request can carry **more than one intent** (the prompt asks for more than one). Handle each intent on its own, unless the answers must be **read together or compared** — then keep the whole set on one consistent technique so the results line up (Decision 2 explains why a mixed native/agnostic set cannot be compared). A custom model is always all-agnostic.

## Decision 2: Which Technique?

When a request spans intents that must be **compared** (see Decision 1), keep them all agnostic: native measures are not on a common scale across families or measures, so a mixed native/agnostic set cannot be lined up side by side.

**Step 1 — Native gate.** Go native only when one of the below holds, or when the user explicitly asks for the model's own native measure; otherwise use agnostic (Step 2).

- **Local explanation + the model is a GAM** → `plotLocalEffects(mdl, queryPoint)`: the model's **exact** additive decomposition, not an approximation. Prefer over agnostic Shapley/LIME.
- **Effect shape + the model is a LinearModel** → `plotAdjustedResponse` (one predictor) / `plotInteraction` (a pair; needs the interaction term in the model formula, otherwise it can't show it): the effect is closed-form and free, whereas agnostic PDP recomputes the same curve at far higher cost. (GLM has no such plot — use agnostic.) **`plotAdjustedResponse` is not defined on a `CompactLinearModel`** (only the full `LinearModel`); on a compact model use agnostic PDP for the one-predictor effect, though `plotInteraction` still works for a pair.
- **Importance with no test set** → use a native measure that reads from the fitted model. Out-of-bag permutation importance is honest even with only training data (no held-out set needed) for a **bagged ensemble** (`ClassificationBaggedEnsemble` / `RegressionBaggedEnsemble`) or a **`TreeBagger`**; the access differs by object, see [native-importance-measures.md](references/native-importance-measures.md). For every other family, native is the fallback only when there is **no data at all** (with any data, training or test, agnostic is preferred).

Native measures are not on a common scale across families, and each is valid only under its training precondition, which cannot be always checked programmatically: compute the native measure, then warn the user that its validity rests on the assumption specified in the trigger above (for importance, see [native-importance-measures.md](references/native-importance-measures.md)).

**Step 2 — Agnostic technique.** No native condition fired: use the agnostic technique for the intent and read its reference. 

Run `functionHandleMap(mdl)` here (it ships in `scripts/`; see the Scripts section for the call): a `"not supported"` value **reroutes selection** (e.g. a custom model has no `permutationImportance` — fall back to `shapley` importance); a `"yes"` value means the chosen technique runs through a prediction handle to resolve before implementing (Before You Compute → Rule 1). 

Reading a reference below happens in two passes: now, read its **intro, data rule, and decision rule** to select the sub-technique — data availability rules out techniques first, then the decision rule picks among what remains; at implementation, once `Mdl` is resolved, read its **data rule and implementation** to write the call.

| Intent                                  | Agnostic technique                                                                    | Reference                                                                 |
| --------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Which predictors drive the model        | `permutationImportance`, global `shapley`                                             | [agnostic-global-importance.md](references/agnostic-global-importance.md) |
| Shape of one or two predictors' effect  | PDP / ICE (`partialDependence`), Shapley dependence                                   | [agnostic-effect-shape.md](references/agnostic-effect-shape.md)           |
| Why the model predicted Y for this case | local `shapley`, `lime`, `counterfactuals`                                            | [agnostic-local-explanation.md](references/agnostic-local-explanation.md) |
| Does behavior differ across cohorts     | per-cohort `permutationImportance` or `shapley`, then compare each predictor's rank, magnitude (and `shapley` direction) across cohorts | [cohort-analysis.md](references/cohort-analysis.md)                       |

Model support is **per-function**: `functionHandleMap(mdl)` reports, for each function, whether this model is used directly (`"no"`), needs a prediction handle (`"yes"`), or is unsupported (`"not supported"`). "Custom" is a property of the (model, function) pair, not the model alone. How to act on a `"yes"` is Before You Compute → Rule 1.

## STEP: Confirming the plan

Before resolving `Mdl` or computing anything, present the plan to the user and get approval. This is an always-on gate, not the conditional Clarifying scope and intent ask: it confirms the concrete work, not just the level of analysis.

Show, for the request:

- **The intents to be addressed** (from Decision 1), including any the prompt raised that are out of scope.
- **The function(s) to be run per intent** (from Decision 2): name the **actual MATLAB function** to be called, not the statistical concept behind it (say `shapley` / `plotPartialDependence`, not "SHAP / partial-dependence plot"), and why native or agnostic. Where a default was picked over a viable alternative, state it so the user can switch:
  - **Local explanation** — `shapley` (more accurate, no surrogate model). **Alternative:** `lime` (surrogate-based).
  - **Global importance** — `permutationImportance` (default). **Alternative:** `shapley`.
- **Which functions need a prediction handle** — *only if any do* (`functionHandleMap` marked `"yes"`): name them so the user knows a handle will be built and validated. If every routed function runs on the model directly, say **nothing** about handles — do not report that no handle is needed; the user should not have to think about handles that aren't there.
- **A slow-run warning — *when a run will actually be slow***. Two independent triggers: **(a)** the routed technique is inherently slow — `counterfactuals`, or `shapley` on its **kernelSHAP** fallback — which warn whenever routed, regardless of data size; or **(b)** an **expensive model** meets a dataset **over 1000 observations and 5 predictors** (see [agnostic-global-importance.md](references/agnostic-global-importance.md)). Say in one line that it may run for a while, and **offer** the way to shrink it (a query-point subset for `shapley`; the observation / predictor / permutation levers for `permutationImportance`). This is a user choice made at the plan stop, **never** a silent shrink. If nothing routed hits either trigger, say **nothing** about runtime.
- **Which data the analysis will run on** — *only when the user hasn't already said which to use*. When both train and test are available: using **test** (name the actual variable, e.g. `Xtest` — reflects generalization). **Alternative:** the training set (name it too, e.g. `Xtrain`). When only training data is available, don't offer a choice — state that results reflect **training behavior, not generalization**. Skip this line for a technique that takes no data (a native measure with no dataset), or when the user already specified the dataset — just use what they asked for.

**CONFIRM — this is an explicit go/no-go on the plan itself. Stop and wait for the user to approve the plan before resolving `Mdl` or computing anything.** You may collect run settings at this same stop (for example, for a LIME explanation, `k` — how many top predictors the local explanation should report), but the user answering those settings is **not** plan approval — still require a clear "proceed" on the plan before continuing. The approved set is the **confirmed set** that Before You Compute resolves `Mdl` for. If the user changes an intent or a technique, revise the list and re-confirm before proceeding.

## Before You Compute: Two Setup Rules

1. **Resolve `Mdl`, once, for the whole confirmed set of interpretability functions to run.** `Mdl` is what gets passed to every interpretability function: the model object, or a validated prediction handle. After the technique set is confirmed (Confirming the plan), read the `functionHandleMap` rows for the functions to be run. If every routed function is `"no"`, pass the model object as `Mdl` directly. If any is `"yes"`, build a **single** prediction handle for the union of those functions before implementing anything, and pass it as `Mdl`; give it per-function output adapters where the functions demand different outputs, then validate it reproduces the model's own known predictions. If the user supplied a handle, vet it against the same contract and tell them what to correct rather than adapting it silently. See [custom-model-wrapper.md](references/custom-model-wrapper.md) for the create-and-validate procedure. A `"not supported"` function has no handle path — reroute per Decision 2. Resolve `Mdl` before running any reference snippet; a hand-rolled encoding produced a confidently reported, silently wrong attribution in testing, so the validate step is not optional.
2. **Background and data convention.** Use `Xtrain` as the Shapley/LIME background; never place the query point in its own reference set. Run importance, effect, and query points on the **data confirmed at the plan stop** (test by default; see CONFIRM). The background stays `Xtrain` regardless of that train/test choice — the choice governs what gets *scored/queried*, not the reference set.

## STEP: Running the analysis

**Then compute.** With `Mdl` resolved, return to the routed reference and run its **data rule + implementation** (the second pass) to write and execute the call. Apply the **Core Idioms** as you write it (they prevent the most common failures), and check **Key Functions** for the release floor of any function not yet confirmed available in the running release. Verify the output against what the intent asked for before reporting.

## STEP: Results and summary

Report the finding in the user's terms — what the analysis said about their model, tied back to the intent that was asked. Surface any caveat or assumption on its own line.

## Core Idioms

- **Reach for the built-in, do not hand-roll.** `permutationImportance`, `shapley`, `plotPartialDependence(...,Conditional=...)` for ICE, `lime` all exist. Hand-rolling them is the most common failure.
- **Batch `shapley`; build the explainer once.** Pass a `QueryPoints` matrix (or construct once and `fit` per point) instead of reconstructing the explainer each iteration. Batching gives `MeanAbsoluteShapley` (the values) **and its built-in views for free: `plot(explainer)` is the mean\|Shapley\| bar, `swarmchart(explainer)` the signed summary. Render the summary with these — do not read `MeanAbsoluteShapley` and hand-build a `bar` chart from it.** Use `swarmchart` / `boxchart` for multi-observation and cohort views. Control cost with `NumObservationsToSample` on the background (**default 100**), **not** by silently dropping query points — *lower* it (e.g. 50) to reduce runtime; larger values or `"all"` increase it. Do not raise it above 100 and call it "keeping it tractable."
  - Method-name split (verified): `plot(explainer, ClassNames=...)` is **plural**; `swarmchart` / `boxchart(explainer, ClassName=...)` are **singular**. Plural on swarm/box errors.
- **`lime` is one point per explainer.** Call `lime(Mdl, Xtrain)` once, then `fit(explainer, queryPoint, k)` per point (`k` is the 3rd positional `NumImportantPredictors`). The constructor fits a surrogate only if **both** `QueryPoint` and `NumImportantPredictors` are given; otherwise `SimpleModel` is empty. Ask the user for `k`; report the surrogate's fidelity (its agreement with the model at the fitted point), and if the fit is poor suggest raising `k` or switching `SimpleModelType` linear→tree.
- **Native preconditions are silent traps.** Curvature splits, standardization, and linear DiscrimType are not enforced by the function and cannot be read back from the fitted model; compute the native measure, then warn the user its validity rests on the training-time assumption (see Decision 2).
- **Render plots in the visible MATLAB UI.** Figures appear in the user's MATLAB desktop; do not create them with `Visible="off"`. If a saved image is also wanted, `exportgraphics` it *in addition*, without hiding or closing the live figure. The user is watching MATLAB; a file on disk is not a substitute for a figure they can see.
- **Set expectations before a slow operation.** Before a long-running call, tell the user in one sentence what is running and that it may take a while; don't leave them watching a silent stall. Runtime is worst on **expensive models** (a handle that runs a network, a GP, a GAM, a large ensemble) and grows with the size of the work: for `shapley`, the **number of query points times the per-prediction cost** (worst when it falls back to **kernelSHAP**); for `permutationImportance`, the **observations × predictors** re-scored each permutation. `counterfactuals` is also typically slow. When a run will be slow, say so and **offer an explicit way to shrink it** — a representative subset of query points for `shapley` (or lower `NumObservationsToSample` for its background, which has a default value of 100), the observation/predictor/permutation levers for `permutationImportance` (see [agnostic-global-importance.md](references/agnostic-global-importance.md)). This is a user choice, **never** a silent drop to fake tractability. And never sell a technique as **fast or cheap**: the honest register is a slowness warning when one is warranted and silence otherwise. Comparative/reduction language is fine ("lower this to cut runtime," "the exact tree/linear path avoids sampling") — an absolute "this is fast/cheap" is not.
- **Keep expensive objects and results in the workspace; do not overwrite them.** A batched `shapley` explainer, a `counterfactuals` result, a fitted `lime` explainer, and `permutationImportance` tables are costly to recompute — assign each to its own named variable and leave it in the workspace. Do not reuse one variable name across runs or intents; that silently destroys a prior result. Overwrite only when a run was erroneous and a corrected run supersedes it — otherwise keep both, so results stay comparable.

## Key Functions

| Function                                                                                                                                                          | Purpose                                                                                                                  | Toolbox                                 | Available From |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- | -------------- |
| `shapley` (+ `fit`, `plot`, `swarmchart`, `boxchart`, `MeanAbsoluteShapley`)                                                                                      | Agnostic local + global attribution; batched query points                                                                | Statistics and Machine Learning Toolbox | R2021a         |
| `plotDependence` (a `shapley` object function)                                                                                                                    | Shapley dependence view: a predictor's contribution vs its value                                                         | Statistics and Machine Learning Toolbox | R2024b         |
| `lime` (+ `fit`)                                                                                                                                                  | Agnostic sparse local surrogate (top-k reasons)                                                                          | Statistics and Machine Learning Toolbox | R2020b         |
| `permutationImportance`                                                                                                                                           | Agnostic global importance by accuracy drop; no function-handle path                                                     | Statistics and Machine Learning Toolbox | R2024a         |
| `partialDependence` / `plotPartialDependence` (`Conditional=` for ICE)                                                                                            | Agnostic effect/shape; accepts function handles                                                                          | Statistics and Machine Learning Toolbox | R2020b         |
| `predictorImportance`, `oobPermutedPredictorImportance` (or `TreeBagger` `OOBPermuted*` properties), `DeltaPredictor`, `Coefficients`, `Beta`, `plotLocalEffects` | Native tree/ensemble/discriminant/linear/GAM measures                                                                    | Statistics and Machine Learning Toolbox | R2021a         |
| `plotAdjustedResponse`, `plotInteraction` (`LinearModel` object functions)                                                                                        | Native closed-form effect shape for a `LinearModel`: one predictor / a pair                                              | Statistics and Machine Learning Toolbox | R2012a         |
| `counterfactuals`                                                                                                                                                 | Minimal actionable change to flip a prediction (binary classification only; slow, verbose)                               | Statistics and Machine Learning Toolbox | R2026a         |
| `minibatchpredict`, `scores2label`                                                                                                                                | Correct `dlnetwork` encoding and score-to-label conversion for the custom-model handle (example only)                    | Deep Learning Toolbox                   | R2024a         |

Gate `counterfactuals` by the running release; the core agnostic surface is long-standing.

## Scripts

Shipped with this skill in `scripts/`. Derive `SKILL_DIR` from the location of this SKILL.md and call via the MATLAB MCP server with `project_path` set to `SKILL_DIR/scripts`.

| Script | Input | Output | Purpose |
|--------|-------|--------|---------|
| `functionHandleMap(mdl)` | a model object or a prediction function handle | table with `Function` and `NeedsFunctionHandle` (`no` / `yes` / `not supported`) per interpretability function | Decide the handle question per function when selecting the technique (Decision 2, Step 2), without trial-and-error. |

Example call: `functionHandleMap(mdl)` with `project_path` = `SKILL_DIR/scripts`.

## Reference Index

- [custom-model-wrapper.md](references/custom-model-wrapper.md) — correctness-critical procedure for interpreting a custom / non-SMLT model through a prediction function handle; worked `dlnetwork` example. Load whenever `functionHandleMap` marks a routed function `yes` (a prediction handle is needed).
- [agnostic-global-importance.md](references/agnostic-global-importance.md) — `permutationImportance` vs `shapley` importance, bar vs summary view, and the data-availability ladder. Load for "which predictors matter."
- [agnostic-local-explanation.md](references/agnostic-local-explanation.md) — local `shapley` vs `lime`, construct-once/fit-per-point, fidelity-driven k. Load for "why this prediction."
- [agnostic-effect-shape.md](references/agnostic-effect-shape.md) — PDP, ICE, Shapley dependence, and two-predictor views. Load for "shape of the effect."
- [native-importance-measures.md](references/native-importance-measures.md) — model-native importance measures per family, with their training preconditions. Load only for the Decision 2 Step 1 importance-with-no-data trigger.
- [cohort-analysis.md](references/cohort-analysis.md) — per-cohort Shapley and shift-sensitive comparison. Load for "how does behavior differ across groups."

----

Copyright 2026 The MathWorks, Inc.

----
