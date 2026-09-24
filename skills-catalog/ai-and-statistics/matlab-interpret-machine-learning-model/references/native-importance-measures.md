# Model-Native Importance Measures

Use a native importance measure only under the Decision-2 Step 1 trigger: importance is wanted but there is no test set to run agnostic importance on. For a bagged ensemble, OOB permutation importance is honest even with only training data (out-of-bag samples estimate out-of-sample importance); for the other families here, native is the fallback only when there is no data at all — or when the user explicitly asks for the model's own native measure — since agnostic on any data (training or test) is otherwise preferred. Never compare native measures across model families: they are not on one scale. **Every native measure is valid only under its training precondition, which cannot be checked programmatically**: the function returns a plausible number regardless. Compute the measure, then warn the user that its validity rests on the precondition below.

| Family                                                                                            | Measure                                                             | Precondition (warn after computing)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Decision trees and ensembles of trees                                                             | `predictorImportance`                                               | Works on `RegressionTree`, `CompactRegressionTree`, `ClassificationTree`, `CompactClassificationTree`, and ensembles of decision trees (`RegressionEnsemble`, `CompactRegressionEnsemble`, `ClassificationEnsemble`, `CompactClassificationEnsemble`). Trustworthy only if grown with `PredictorSelection="curvature"` or `"interaction-curvature"`. Default CART (`"allsplits"`) biases importance toward high-cardinality predictors. The setting is fixed at training and **not readable from the fitted model** (absent from `ens.ModelParameters`, the compacted learners, and the stored template), so warn that the ranking is trustworthy only if the model was grown that way. |
| Bagged ensembles / TreeBagger                                                                     | `oobPermutedPredictorImportance` (or the `OOBPermuted*` properties) | Works on `ClassificationBaggedEnsemble` / `RegressionBaggedEnsemble`<br>`TreeBagger` (grown with `OOBPredictorImportance="on"`, equivalently `ComputeOOBPredictorImportance=true`): read `OOBPermutedPredictorDeltaError`, `OOBPermutedPredictorDeltaMeanMargin`, `OOBPermutedPredictorCountRaiseMargin`. Reading these before the bag was grown that way errors with "Out-of-bag permutations were not saved. Run with 'OOBPredictorImportance' set to 'on'." Uses the model's own out-of-bag samples; needs no separate data.                                                                                                                                                         |
| Linear discriminant (`fitcdiscr`, DiscrimType `linear` / `diagLinear` / `pseudoLinear`)           | `DeltaPredictor` property                                           | Linear DiscrimType only; recovers the true ranking under it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `LinearModel` / `CompactLinearModel` / `GeneralizedLinearModel` / `CompactGeneralizedLinearModel` | `Coefficients` magnitude                                            | Raw coefficient magnitude is a valid ranking only if predictors were standardized, and `fitlm`/`fitglm` neither standardize nor record scaling. **If the training predictor data is available, self-standardize instead** (`coef × std(predictor)`) — an exact ranking, not a caveat — see [Self-standardizing coefficients](#self-standardizing-linearmodel--glm-coefficients) below. If training data is not available, warn that the raw-coefficient ranking assumes standardized predictors.                                                                                                                                                                                        |
| Linear SVM (`KernelFunction="linear"`), `RegressionLinear` / `ClassificationLinear`               | magnitude of `Beta` (sign gives direction)                          | Standardized data. On SVM, checkable on the object (`Mu`/`Sigma` populated when `Standardize=true`). On `RegressionLinear`/`ClassificationLinear` it is **not** verifiable on the object, so warn that the ranking assumes standardized data. `Beta` is empty for nonlinear kernels (RBF/polynomial) → no native importance.                                                                                                                                                                                                                                                                                                                                                            |

**If the family has no row above** (NN, KNN, NaiveBayes, quadratic discriminant, GP, or any model behind a function handle) and there is no data, importance cannot be computed: say so rather than emit a misleading number.

## Self-standardizing LinearModel / GLM coefficients

A raw coefficient's magnitude is not comparable across predictors on different scales. When the model retained its training predictors, convert to a **standardized** coefficient — `β_std = β_raw × σ`, where σ is the predictor's **training** standard deviation — which is comparable and gives an exact importance ranking. This is exact for `fitlm` (OLS) and `fitglm` (maximum likelihood); it does **not** apply to SVM (next row), whose regularization depends on input scale.

**Use the training σ, not test.** A standardized coefficient reconstructs the coefficient the model would have had if fit on standardized *training* data; it is a property of the fit, not a generalization measure, so the train/test choice does not apply here.

- **Full model** (`LinearModel` / `GeneralizedLinearModel`) → σ comes from `Mdl.Variables` (the embedded training data). Exact.
- **Compact model** (`CompactLinearModel` / `CompactGeneralizedLinearModel`) → self-standardize **only if the user supplies the training set**; a test set is not a substitute. Otherwise warn-only.

Report **signed** standardized coefficients ranked by magnitude, alongside the raw coefficient and the σ applied, so the standardization is auditable. Scale **numeric predictors only** — the categorical dummy coefficients (`cat_B`, `cat_C`) are left as-is, so the standardized ranking is comparable among the numeric predictors.

```matlab
% Self-standardized native importance for a FULL LinearModel / GLM.
% Exact under OLS / MLE (NOT valid for SVM). Signed; scales continuous only.
coefNames = Mdl.CoefficientNames;
predNames = Mdl.PredictorNames;

% Order-independent categorical flag (keyed by name; skips the response row):
isCatPred = false(1, numel(predNames));
for i = 1:numel(predNames)
    isCatPred(i) = Mdl.VariableInfo{predNames{i}, "IsCategorical"};
end

signedStd = Mdl.Coefficients.Estimate;          % raw coefficients (signed)
scale     = ones(numel(coefNames), 1);          % =1 for intercept + dummies
isScaled  = false(numel(coefNames), 1);         % true only where a continuous sigma was applied
for i = 1:numel(predNames)
    if ~isCatPred(i)                            % continuous predictors only
        p = predNames{i};
        c = coefNames == string(p);            % by-name mask: coef name == predictor name
        scale(c)    = std(Mdl.Variables.(p));  % numeric column -> std() is safe
        isScaled(c) = true;
    end
end
signedStd = signedStd .* scale;

keep = ~strcmp(coefNames, '(Intercept)');       % drop intercept for importance
[~, ord] = sort(abs(signedStd(keep)), 'descend');   % rank by magnitude, keep sign
importance = table( ...
    string(coefNames(keep))', Mdl.Coefficients.Estimate(keep), scale(keep), ...
    signedStd(keep), isScaled(keep), ...
    'VariableNames', ["Predictor" "RawCoef" "StdDev" "SignedStdImportance" "Standardized"]);
importance = importance(ord, :);
```

For a **compact** model, replace `Mdl.Variables.(p)` with the supplied training table's column `(p)` — same `std()`, training source in both cases.


----

Copyright 2026 The MathWorks, Inc.

----
