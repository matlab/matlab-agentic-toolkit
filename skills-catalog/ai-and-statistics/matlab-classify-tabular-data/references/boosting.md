# Plot Boosting Learning Curves and Resume Training

Run this as Step 10, after the Step 9 plots, for every boosting model in `modelDefs`.

For each boosting model (RUSBoost, AdaBoost, LogitBoost), plot its learning curve and offer to resume training.

First, identify which entries in `modelDefs` are boosting models. Boosting means `fnName == 'fitcensemble'` AND `hyperparameters.Method` is one of `RUSBoost`, `LogitBoost`, `AdaBoostM1`, `AdaBoostM2`, `GentleBoost` — *not* `Bag` or `Subspace`. Iterate over these `boostIdx` values; every code snippet below uses `boostIdx` as the current model's index into the per-model arrays (`acc`, `accCI`, `foldAcc`, `trainTime`).

```matlab
boostMethods = {'RUSBoost','LogitBoost','AdaBoostM1','AdaBoostM2','GentleBoost'};
isBoost = false(1, numel(modelDefs));
for k = 1:numel(modelDefs)
    hp = modelDefs(k).hyperparameters;
    isBoost(k) = strcmp(modelDefs(k).fnName, 'fitcensemble') ...
        && isfield(hp, 'Method') && ismember(hp.Method, boostMethods);
end
boostIndices = find(isBoost);
```

Loop `for boostIdx = boostIndices`, then call `plot_boosting_curve`:

```matlab
boostModelName = modelDefs(boostIdx).name;

% Holdout path: pass the trained model and test set
plot_boosting_curve(trainedModels{boostIdx}, boostModelName, true, XTest, YTest);

% CV path: pass the cross-validated model; XTest/YTest unused
plot_boosting_curve(cvModels{boostIdx}, boostModelName, false, [], []);
```

After displaying the plot, ask the user:

> The learning curve for [modelName] shows accuracy at each number of trees. Please inspect the curve.
>
> Would you like to resume training with more trees? If yes, how many additional trees? (no / number)

If the user provides a number, call the path-appropriate resume script and update the per-model results:

```matlab
% Holdout path
[trainedModels{boostIdx}, resumeTime, acc(boostIdx), accCI(boostIdx,:), YHat{boostIdx}] = ...
    resume_boosting_holdout(trainedModels{boostIdx}, nMoreTrees, XTest, YTest);
trainTime(boostIdx) = trainTime(boostIdx) + resumeTime;

% CV path
[cvModels{boostIdx}, resumeTime, acc(boostIdx), accCI(boostIdx,:), foldAcc(:, boostIdx), oofPreds] = ...
    resume_boosting_cv(cvModels{boostIdx}, nMoreTrees);
trainTime(boostIdx) = trainTime(boostIdx) + resumeTime;
```

On both paths, then update the model's definition so later steps (the CV comparison, saving) use the resumed model: `modelDefs(boostIdx) = resume_model_definition(modelDefs(boostIdx), nMoreTrees, useUniformPrior);`

After each resume, report the boosting model's final mean accuracy and cumulative training time (pre-resume + resume).

Once all resuming is done, re-run the Step 8 comparison for the resumed models' pairs only, so the other p-values stay as reported: on the CV path `compute_pairwise_pvalues_cv(modelDefs, X, Y, alpha_corrected, 'UseUniformPrior', useUniformPrior, 'Models', resumedIdx, 'PValues', pvalMatrix)`, where `resumedIdx` lists the resumed `boostIdx` values; on the holdout path `compute_pairwise_pvalues_holdout` with the updated `YHat`. Report the results, then redraw the Step 8 heatmap and the Step 9 plots with the updated values; the earlier figures show pre-resume numbers.

After each resume, ALWAYS ask the user again whether they want to continue training with more trees — regardless of whether the model's accuracy is still far from the top tier. You may note the remaining gap, but the decision to stop belongs to the user. Never unilaterally conclude that further training is futile.

----

Copyright 2026 The MathWorks, Inc.

----
