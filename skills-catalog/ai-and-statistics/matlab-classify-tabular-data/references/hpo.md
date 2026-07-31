# Hyperparameter Optimization for Classification Models

This reference is dispatched from the orchestrator after all training, comparisons, and boosting resume are complete. It optimizes hyperparameters for user-selected models using Bayesian optimization via `'OptimizeHyperparameters','auto'`.

## Required inputs (from parent skill)

- `modelNames` — cell array of model names
- `acc` — baseline accuracy for each model
- `accCI` — baseline accuracy confidence intervals
- Top-tier model indices (from pairwise comparison)
- `hasHoldout` — evaluation path flag
- `cv` — `cvpartition` object created by the parent skill (CV path only — used as outer folds for nested CV)
- `X`, `Y` — full data (CV path)
- `XTrain`, `YTrain`, `XTest`, `YTest` — split data (holdout path)
- `Xsub`, `Ysub` — subsampled data (if subsampling was applied in holdout path)
- `N` — number of observations used for accuracy estimation
- `useUniformPrior` — whether to pass `'Prior','uniform'`

## Step 1: Ask the user

Present the model list and ask which to optimize:

> Would you like to optimize hyperparameters for any models? Select from the list below, or type "none" to skip.
>
> **Top tier (suggested):** [list top-tier model names]
> **Other models:** [list remaining model names]
>
> Which models to optimize? (comma-separated names, "all", "top", or "none")

If the user says "none", this reference is complete — return to the parent skill's summary step.

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
| GaussianSVM (multiclass) | `fitcecoc(X, Y, 'Learners','svm', 'OptimizeHyperparameters','auto', ...)` — do NOT specify `'Coding'`; it is optimized automatically |
| LinearSVM / LogisticRegression (binary) | `[mdl, fitInfo, hpoResults] = fitclinear(X, Y, 'OptimizeHyperparameters','auto', ...)` — use 3 outputs; the 3rd output contains optimization results |
| LinearSVM / LogisticRegression (multiclass) | `fitcecoc(X, Y, 'Learners',templateLinear(...), 'OptimizeHyperparameters','auto', ...)` — do NOT specify `'Coding'`; it is optimized automatically |
| NeuralNetwork | `fitcnet(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| KNN | `fitcknn(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| NaiveBayes | `fitcnb(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| QuadraticDiscriminant / LinearDiscriminant | `fitcdiscr(X, Y, 'OptimizeHyperparameters','auto', 'FillCoeffs','off','SaveMemory','on', ...)` |
| Ensemble (Bag/Boost) | `fitcensemble(X, Y, 'Method','...', 'OptimizeHyperparameters','auto', ...)` |
| GAM | `fitcgam(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| KernelSVM / KernelLogistic (binary) | `fitckernel(X, Y, 'OptimizeHyperparameters','auto', ...)` |
| KernelSVM / KernelLogistic (multiclass) | `fitcecoc(X, Y, 'Learners',templateKernel(...), 'OptimizeHyperparameters','auto', ...)` — do NOT specify `'Coding'`; it is optimized automatically |

**ECOC deduplication:** If the user selected both OVO and OVA variants of the same base learner (e.g., GaussianSVM-OVO and GaussianSVM-OVA), run only ONE `fitcecoc` optimization without specifying `'Coding'` — the optimizer will search over coding designs automatically. Report the result for both variants.

**Base learner determination:** Determine shared base learners by inspecting `modelDefs(k).innerLearner_fnName` — do NOT infer from model names. Two models are "the same base learner" only if they have identical `innerLearner_fnName` values. For example, LinearSVM-OVA (innerLearner: templateLinear) and LinearStandardizedSVM-OVA (innerLearner: templateSVM) are distinct and require separate optimization calls.

**Ensemble deduplication:** If the user selected multiple ensemble models (e.g., RoughRUSBoost, FineRUSBoost, RoughAdaBoost, DarkRandomForest), run only ONE `fitcensemble` optimization without specifying `'Method'` — the `'auto'` option searches over ensemble methods automatically. Report the result for all ensemble variants the user selected.

**ECOC with templateLinear or templateKernel (CRITICAL):** You MUST call `fitcecoc` with 2 outputs when optimizing models that use `templateLinear` or `templateKernel`. The returned model object is compact and does NOT have a `HyperparameterOptimizationResults` property — the only way to access the optimization results is via the 2nd output. Calling with 1 output will lose all hyperparameter information.

```matlab
[optimModel, hpoResults] = fitcecoc(X, Y, 'Learners', templateKernel(...), ...
    'OptimizeHyperparameters','auto', ...
    'HyperparameterOptimizationOptions', struct(...));
% hpoResults.HyperparameterOptimizationResults contains the optimization table
% hpoResults.HyperparameterOptimizationResults.XAtMinObjective has the best params
```

### Holdout path (`hasHoldout = true`)

Cross-validate on the training set only. Do NOT pass the parent's `cv` partition — it was created for the full dataset `X` and its size does not match `XTrain`. Create a new partition for the training data and pass it via `HyperparameterOptimizationOptions`:

Before starting each model, display: `fprintf('Optimizing %s...\n', modelName);`

```matlab
cvHPO = cvpartition(YTrain, 'KFold', 5, 'Stratify', true);

fprintf('Optimizing %s...\n', modelName);
tic;
optimModel = fitctree(XTrain, YTrain, 'OptimizeHyperparameters','auto', ...
    'HyperparameterOptimizationOptions', struct('CVPartition',cvHPO,'ShowPlots',false,'Verbose',0));
elapsed = toc;
fprintf('%s optimization complete (%.1f s)\n', modelName, elapsed);
```

(Use `Xsub`/`Ysub` instead of `XTrain`/`YTrain` if subsampling was applied.)

The optimization returns a trained (non-cross-validated) model. Extract the optimized hyperparameters and retrain with cross-validation:

```matlab
bestParams = optimModel.HyperparameterOptimizationResults.XAtMinObjective;
% Retrain with CV using the optimized params — example for fitctree:
cvOptModel = fitctree(XTrain, YTrain, 'CVPartition', cvHPO, ...
    'MaxNumSplits', bestParams.MaxNumSplits, ...
    'MinLeafSize', bestParams.MinLeafSize);
errOpt = kfoldLoss(cvOptModel);
accOpt = 1 - errOpt;
```

Then evaluate on the held-out test set for the final reported accuracy via `scripts/score_holdout_test.m`:

```matlab
[accHoldout, accCIHoldout] = score_holdout_test(optimModel, XTest, YTest);
```

### CV path (`hasHoldout = false`) — nested cross-validation

Use nested CV to avoid optimistic bias: for each outer fold of the existing `cv` partition, optimize on the training portion and predict on the test portion. This gives unbiased accuracy estimates for the optimized model.

Before starting each model, display: `fprintf('Optimizing %s...\n', modelName);`

```matlab
% Preallocate an out-of-fold prediction vector in Y's own type (categorical,
% string, cellstr, or numeric). Using Y for the seed guarantees the
% container matches what fitc*/predict will emit fold by fold.
YHatOpt = Y;
YHatOpt(:) = Y(1);  % overwrite every entry so leftover values from Y do not leak into folds not yet visited
nFolds = cv.NumTestSets;

fprintf('Optimizing %s...\n', modelName);
tic;
for k = 1:nFolds
    trainIdx = training(cv, k);
    testIdx  = test(cv, k);
    
    % Optimize on outer training fold (inner CV is automatic)
    optimFold = fitctree(X(trainIdx,:), Y(trainIdx), ...
        'OptimizeHyperparameters','auto', ...
        'HyperparameterOptimizationOptions', struct('ShowPlots',false,'Verbose',0));
    
    % Predict on held-out outer fold
    YHatOpt(testIdx) = predict(optimFold, X(testIdx,:));
    fprintf('  Fold %d/%d done\n', k, nFolds);
end
elapsed = toc;
fprintf('%s optimization complete (%.1f s)\n', modelName, elapsed);

% Aggregate out-of-fold predictions into accuracy + 95% CI. Pass Y (the
% original response) so aggregate_nested_cv_loss can compare like-for-like.
[accOpt, accCIOpt] = aggregate_nested_cv_loss(YHatOpt, Y, useUniformPrior, X);
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

For each model, identify which hyperparameters were optimized by comparing `optimModel.HyperparameterOptimizationResults.XAtMinObjective` against the defaults or values originally set in the model template. Only show hyperparameters that changed or were searched over.

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

After optimization, re-run pairwise statistical comparisons only if `hasHoldout = true`. Use `testcholdout` with the predictions on the holdout test set. Obtain predictions from each optimized model via `predict(optimModel, XTest)` and compare against stored predictions from non-optimized models:

```matlab
[h, p] = testcholdout(YHatOpt{i}, YHat{j}, YTest, 'Alpha', alpha_corrected);
```

Apply Bonferroni correction: `alpha_corrected = 0.05 / nchoosek(nModels, 2)` where `nModels` is the total number of models (optimized + non-optimized).

### Report updated top tier

After running all pairwise comparisons, report the updated p-value matrix and identify the new top tier. Note any changes from the pre-optimization top tier (e.g., "Optimized TreeIC has entered the top tier" or "GAM remains the sole top-tier model").

### CV path (`hasHoldout = false`) — no post-HPO comparison

Do NOT re-run pairwise statistical comparisons in the CV path. If the user asks for a statistical comparison between optimized and non-optimized models, explain that this would require a nested cross-validation design and is not available at present.

---

Copyright 2026 The MathWorks, Inc.
