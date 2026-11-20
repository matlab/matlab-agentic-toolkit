# Optimize Hyperparameters of Selected Classifiers

Run this after all training, comparisons and boosting resumes are complete.

## Required inputs (from SKILL.md)

- `modelNames` — cell array of model names
- `acc` — baseline accuracy for each model
- `accCI` — baseline accuracy confidence intervals
- Top-tier model indices (from pairwise comparison)
- `hasHoldout` — evaluation path flag
- `cvp` — `cvpartition` object created in SKILL.md Step 3 (CV path only — used as outer folds for nested CV)
- `X`, `Y` — full data (CV path)
- `XTrain`, `YTrain`, `XTest`, `YTest` — split data (holdout path)
- `Xsub`, `Ysub` — subsampled data (if subsampling was applied in holdout path)
- `useUniformPrior` — whether to pass `'Prior','uniform'`

## Step 1: Ask the user

Present the model list and ask which to optimize. Number every model by its position in `modelNames` (1-based), so the user can answer with numbers — model names are function-plus-settings strings that nobody types:

> Would you like to optimize hyperparameters for any models? Select from the list below, or type "none" to skip.
>
> **Top tier (suggested):** [list top-tier models, each as "[number]. [name]"]
> **Other models:** [list remaining models, each as "[number]. [name]"]
>
> Which models to optimize? (comma-separated numbers, "all", "top", or "none")

Accept model names too, if the user gives them instead of numbers.

If the user says "none", this reference is complete — return to SKILL.md Step 12 (Summary).

## Step 2: Run optimization

For each selected model, call the appropriate `fitc*` function with `'OptimizeHyperparameters','auto'`. Do NOT pass `'OptimizeHyperparameters'` to template objects — templates do not recognize this parameter. You must call the `fitc*` function directly.

**Uniform prior — mandatory when `useUniformPrior = true`:** Assemble a `priorNV` cell once, and prepend it to every `fitc*` call in this reference. If HPO forgets `'Prior','uniform'` while baseline training used it, imbalanced-data before/after comparisons silently switch prior between the two runs and are meaningless:

```matlab
if useUniformPrior
    priorNV = {'Prior', 'uniform'};
else
    priorNV = {};
end
% Every fitc* call below:  fitcXXX(X, Y, priorNV{:}, 'OptimizeHyperparameters', 'auto', ...)
```

### Template-to-fitc mapping for optimization

| Model type | Optimization call |
|---|---|
| Tree / TreeIC | `fitctree(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| GaussianSVM (binary) | `fitcsvm(X, Y, 'OptimizeHyperparameters','auto', 'KernelFunction','rbf', ...)` |
| GaussianSVM (multiclass) | `fitcecoc(X, Y, 'Learners',model_inner_template(modelDefs(k)), 'OptimizeHyperparameters','auto', ...)` — the model's own Gaussian-kernel `templateSVM`; `'Learners','svm'` would drop the kernel. Do NOT specify `'Coding'`; it is optimized automatically |
| LinearSVM / LogisticRegression (binary) | `[mdl, fitInfo, hpoResults] = fitclinear(X, Y, 'OptimizeHyperparameters','auto', ...)` — use 3 outputs; the 3rd output contains optimization results |
| LinearSVM / LogisticRegression (multiclass) | `fitcecoc(X, Y, 'Learners',model_inner_template(modelDefs(k)), 'OptimizeHyperparameters','auto', ...)` — do NOT specify `'Coding'`; it is optimized automatically |
| NeuralNetwork | `fitcnet(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| KNN | `fitcknn(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| NaiveBayes | `fitcnb(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| LinearDiscriminant | `fitcdiscr(X, Y, 'OptimizeHyperparameters','auto', 'FillCoeffs','off','SaveMemory','on', ...)` |
| QuadraticDiscriminant (any quadratic `DiscrimType`) | `fitcdiscr(X, Y, 'OptimizeHyperparameters',{'DiscrimType','Gamma'}, ...)` without the model's `DiscrimType`. `'auto'` (and `{'Gamma'}` alone) fails for a quadratic discriminant: it searches `Delta`, which a quadratic discriminant does not have, so every evaluation errors. The search may return a linear type — report that as a changed setting (see below) |
| Ensemble (Bag/Boost/Subspace) | `fitcensemble(X, Y, 'Learners',model_inner_template(modelDefs(k)), 'OptimizeHyperparameters','auto', ...)` — the model's own inner learner keeps, e.g., its trees' `MaxNumSplits`; do not pass `'Method'` (see Ensemble deduplication) |
| GAM | `fitcgam(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| KernelSVM / KernelLogistic (binary) | `fitckernel(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| KernelSVM / KernelLogistic (multiclass) | `fitcecoc(X, Y, 'Learners',model_inner_template(modelDefs(k)), 'OptimizeHyperparameters','auto', ...)` — do NOT specify `'Coding'`; it is optimized automatically |

`model_inner_template(modelDefs(k))` (in `scripts/helpers/`) builds a model's own inner learner from `modelDefs(k).innerLearner_fnName` and `.innerLearner_hyperparameters`, typed for classification, exactly as the model was trained with it.

**`'auto'` searches some settings even when the model sets them.** For `fitcknn` it searches `NumNeighbors` and `Distance`; for `fitcensemble`, `Method`, `NumLearningCycles`, `LearnRate` and `MinLeafSize`; for `fitcdiscr` (linear), `Delta` and `Gamma`; for the quadratic search above, `DiscrimType`. A value passed in the call for one of these is ignored without a warning, so the optimized model can differ from the model the user confirmed in what defines it (a 1-nearest-neighbor model coming back as 8-nearest with Chebychev distance; an AdaBoost model as a bagged ensemble). Settings outside the search, such as the inner learner passed as `'Learners'`, are kept.

**ECOC deduplication:** If the user selected both OVO and OVA variants of the same base learner (e.g., GaussianSVM-OVO and GaussianSVM-OVA), run only ONE `fitcecoc` optimization without specifying `'Coding'` — the optimizer will search over coding designs automatically. Report the result for both variants.

**Base learner determination:** Determine shared base learners by inspecting `modelDefs(k).innerLearner_fnName` — do NOT infer from model names. Two models are "the same base learner" only if they have identical `innerLearner_fnName` values. For example, LinearSVM-OVA (innerLearner: templateLinear) and LinearStandardizedSVM-OVA (innerLearner: templateSVM) are distinct and require separate optimization calls.

**Ensemble deduplication:** Ensembles share one `fitcensemble` optimization only when their inner learners are identical — the same `modelDefs(k).innerLearner_fnName` AND the same `.innerLearner_hyperparameters` (e.g. RoughAdaBoost and LogitBoost, both trees with `MaxNumSplits` 10). Run that one search without `'Method'` (`'auto'` searches the ensemble method) and with `'Learners', model_inner_template(modelDefs(k))`, and report its result for every ensemble in the group. Ensembles whose inner learners differ get separate searches: a random forest's default-depth trees, FineAdaBoost's deeper trees, and a subspace ensemble of KNN learners (`templateKNN`) are three searches. One search without `'Learners'` would optimize default tree ensembles and report a tree ensemble as the optimized KNN-subspace model.

**ECOC with templateLinear or templateKernel (CRITICAL):** You MUST call `fitcecoc` with 2 outputs when optimizing models that use `templateLinear` or `templateKernel`. The returned model object is compact and does NOT have a `HyperparameterOptimizationResults` property — the only way to access the optimization results is via the 2nd output. Calling with 1 output will lose all hyperparameter information.

```matlab
[optimModel, hpoResults] = fitcecoc(X, Y, 'Learners', model_inner_template(modelDefs(k)), ...
    'OptimizeHyperparameters','auto', ...
    'HyperparameterOptimizationOptions', struct(...));
% hpoResults IS the optimization results object (it has no
% HyperparameterOptimizationResults property of its own).
% bestPoint(hpoResults) gives the hyperparameters optimModel was trained with.
```

**Read optimized hyperparameters with `bestPoint`, never `XAtMinObjective`.** After a Bayesian search, a `fitc*` call with `'OptimizeHyperparameters'` trains the returned model at `bestPoint(results)` — the visited point with the lowest upper confidence bound on the objective — not at the lowest observed objective (`XAtMinObjective`). The two differ often on a noisy cross-validated loss (e.g. a tree reported with `MinLeafSize` 3 that was trained with 23). Here `results` is `optimModel.HyperparameterOptimizationResults`, or the results output for the `fitcecoc` (2nd) and `fitclinear` (3rd) calls above.

### Holdout path (`hasHoldout = true`)

Cross-validate on the training set only. Do NOT reuse a CV partition of the full data (the CV path's `cvp`) — it was created for the full dataset `X` and its size does not match `XTrain`. Create a new partition for the training data and pass it via `HyperparameterOptimizationOptions`:

```matlab
cvHPO = cvpartition(YTrain, 'KFold', 5, 'Stratify', true);

modelName = modelNames{k};   % k: the model's index in modelDefs
fprintf('Optimizing %s...\n', modelName);
tic;
optimModel = fitctree(XTrain, YTrain, 'OptimizeHyperparameters','auto', ...
    'HyperparameterOptimizationOptions', struct('CVPartition',cvHPO,'ShowPlots',false,'Verbose',1));
elapsed = toc;
fprintf('%s optimization complete (%.1f s)\n', modelName, elapsed);
```

(Use `Xsub`/`Ysub` instead of `XTrain`/`YTrain` if subsampling was applied.)

The optimization returns a trained (non-cross-validated) model, fitted at `bestPoint(optimModel.HyperparameterOptimizationResults)`. Score it on the held-out test set — this is the reported accuracy; do not also retrain it with cross-validation on the training set (that number is never reported). It replaces the original model in `trainedModels` and `YHat`:

```matlab
[accHoldout, accCIHoldout, YHatOpt{k}] = score_holdout_test(optimModel, XTest, YTest);   % YHatOpt feeds Step 4
trainedModels{k} = optimModel;
```

### CV path (`hasHoldout = false`) — nested cross-validation

Use nested CV to avoid optimistic bias: for each outer fold of the existing `cvp` partition, optimize on the training portion and predict on the test portion. This gives unbiased accuracy estimates for the optimized model.

```matlab
% Preallocate an out-of-fold prediction vector in Y's own type (categorical,
% string, cellstr, or numeric). Using Y for the seed guarantees the
% container matches what fitc*/predict will emit fold by fold.
YHatOpt = Y;
YHatOpt(:) = Y(1);  % overwrite every entry so leftover values from Y do not leak into folds not yet visited
nFolds = cvp.NumTestSets;

% k is the model being optimized (its index in modelDefs); f is the outer fold.
modelName = modelNames{k};
fprintf('Optimizing %s...\n', modelName);
tic;
for f = 1:nFolds
    trainIdx = training(cvp, f);
    testIdx  = test(cvp, f);
    
    % Optimize on outer training fold (inner CV is automatic)
    optimFold = fitctree(X(trainIdx,:), Y(trainIdx), ...
        'OptimizeHyperparameters','auto', ...
        'HyperparameterOptimizationOptions', struct('ShowPlots',false,'Verbose',0));
    
    % Predict on held-out outer fold
    YHatOpt(testIdx) = predict(optimFold, X(testIdx,:));
    fprintf('  Fold %d/%d done\n', f, nFolds);
end
elapsed = toc;
fprintf('%s optimization complete (%.1f s)\n', modelName, elapsed);

% Aggregate out-of-fold predictions into accuracy + 95% CI. The helper
% compares labels of any type and derives the uniform-prior weights from Y.
[accOpt, accCIOpt] = aggregate_nested_cv_loss(YHatOpt, Y, useUniformPrior);
```

Replace `fitctree` with the appropriate `fitc*` function for each model (see mapping table above). Prepend `priorNV{:}` (defined at the top of this step) to every `fitc*` call inside the loop — this is what carries `'Prior','uniform'` through to HPO when `useUniformPrior = true`.

## Step 3: Report optimization results

### Holdout path

Report both the hyperparameter changes and accuracy changes for each optimized model:

> **Optimization results:**
>
> **[ModelName]:**
>
> | Hyperparameter | Before (default/set) | After (optimized) |
> |---|---|---|
> | MaxNumSplits | 100 | 27 |
> | MinLeafSize | 1 | 12 |
> | ... | ... | ... |
>
> | Metric | Before | After |
> |---|---|---|
> | Accuracy | 82.3% | 86.1% |
> | 95% CI | [79.8%, 84.8%] | [83.8%, 88.4%] |
> | Optimization time | — | 120.3s |

For each model, identify which hyperparameters were optimized by comparing `bestPoint(optimModel.HyperparameterOptimizationResults)` (or `bestPoint` of the results output, for the `fitcecoc`/`fitclinear` calls) against the defaults or values originally set in the model template. Only show hyperparameters that changed or were searched over. When a setting that defines the model changed (one of the searched settings listed above, e.g. `NumNeighbors`, `Distance`, `Method`, `DiscrimType`), add one sentence saying that the optimized model is no longer the model the user confirmed, e.g. "The optimized KNN is an 8-nearest-neighbor model with Chebychev distance, not the 1-nearest-neighbor Euclidean model in the list."

### CV path (nested)

Do NOT report a single set of optimized hyperparameters — each outer fold produced its own optimized model, so there is no single "best" parameter set to display. Instead, report only the accuracy change:

> **Optimization results:**
>
> **[ModelName]:**
> Optimized via nested 5-fold CV (each fold optimized independently — no single parameter set to report).
>
> | Metric | Before | After |
> |---|---|---|
> | Accuracy | 82.3% | 86.1% |
> | 95% CI | [79.8%, 84.8%] | [83.8%, 88.4%] |
> | Optimization time | — | 120.3s |

## Step 4: Re-run pairwise statistical comparisons (holdout path only)

After optimization, re-run pairwise statistical comparisons only if `hasHoldout = true`. Use `testcholdout` with the predictions on the holdout test set. Use each optimized model's test-set predictions (`YHatOpt{k}`, returned by `score_holdout_test` above) and compare them against the stored predictions from non-optimized models:

```matlab
[h, p] = testcholdout(YHatOpt{i}, YHat{j}, YTest, 'Alpha', alpha_corrected);
```

Each optimized model **replaces** its original in the comparison — the comparison set is the same models as before, with the optimized ones in place of their originals. Apply Bonferroni correction: `alpha_corrected = 0.05 / nchoosek(nModels, 2)` where `nModels` is the number of models in that set, i.e. the same count as the original comparison (optimized models are not added on top of their originals).

### Report updated top tier

After running all pairwise comparisons, report the updated p-value matrix and identify the new top tier. Note any changes from the pre-optimization top tier (e.g., "Optimized TreeIC has entered the top tier" or "GAM remains the sole top-tier model").

### CV path (`hasHoldout = false`) — no post-HPO comparison

Do NOT re-run pairwise statistical comparisons in the CV path. If the user asks for a statistical comparison between optimized and non-optimized models, explain that this would require a nested cross-validation design and is not available at present.

Say this unprompted, once, wherever optimized accuracies appear next to the earlier comparison (this Step 3 report or the SKILL.md Step 12 summary): the top tier and p-values were computed before optimization, and the optimized models were not re-tested — so a higher optimized accuracy does not mean a model has joined the top tier.

----

Copyright 2026 The MathWorks, Inc.

----
