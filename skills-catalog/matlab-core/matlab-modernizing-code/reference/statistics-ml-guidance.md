
# Statistics/ML Modernization

## Quick Reference: Function Mappings

| Deprecated/Removed | Recommended Replacement | Since | Status |
|--------------------|------------------------|-------|--------|
| classregtree | fitctree / fitrtree | R2018a | Removed |
| svmtrain | fitcsvm | R2018a | Removed |
| svmclassify | predict (ClassificationSVM) | R2018a | Removed |
| dataset | table | R2013b | Not recommended |
| nominal | categorical | R2013b | Not recommended |
| ordinal | categorical | R2013b | Not recommended |

---

## Removed Machine Learning Functions (R2018a)

### classregtree → fitctree / fitrtree

**Status:** Removed in R2018a. Use `fitctree` for classification or `fitrtree` for regression.

**Old Pattern (No Longer Works):**
```matlab
% Legacy classification tree
tree = classregtree(X, Y, 'Method', 'classification');
predictions = eval(tree, XTest);
```

**Modern Pattern (Use This):**
```matlab
% Modern classification tree
tree = fitctree(X, Y);
predictions = predict(tree, XTest);

% For regression trees
tree = fitrtree(X, Y);
predictions = predict(tree, XTest);
```

**Key API Changes:**
| Old (classregtree) | New (fitctree/fitrtree) |
|--------------------|------------------------|
| `eval(tree, X)` | `predict(tree, X)` |
| `eval(tree, X, subtree)` | `predict(tree, X, 'Subtrees', subtree)` |
| `tree.numnodes` | `tree.NumNodes` (property) |
| `view(tree)` | `view(tree)` (still works) |

**Complete Migration Example:**
```matlab
% Old code (won't work in R2018a+)
% tree = classregtree(X, Y, 'names', varNames);
% yfit = eval(tree, Xnew);
% err = test(tree, 'test', Xtest, Ytest);

% Modern equivalent
tree = fitctree(X, Y, 'PredictorNames', varNames);
yfit = predict(tree, Xnew);
cvtree = crossval(tree);
err = kfoldLoss(cvtree);
```

---

### svmtrain → fitcsvm

**Status:** Removed in R2018a. Use `fitcsvm` instead.

**Old Pattern (No Longer Works):**
```matlab
% Legacy SVM training
SVMStruct = svmtrain(XTrain, YTrain);
SVMStruct = svmtrain(XTrain, YTrain, 'kernel_function', 'rbf', 'showplot', true);
```

**Modern Pattern (Use This):**
```matlab
% Modern SVM training
SVMModel = fitcsvm(XTrain, YTrain);
SVMModel = fitcsvm(XTrain, YTrain, 'KernelFunction', 'rbf');

% For visualization (no built-in showplot in fitcsvm)
% Use custom plotting or Classification Learner app
```

**Key Differences:**
- `fitcsvm` returns a `ClassificationSVM` object, not a struct
- No built-in 'showplot' option - use custom plotting
- Name-value pairs use different naming conventions
- `fitcsvm` requires both X and Y as separate arguments (no single-argument call)

**Kernel Function Mapping:**
| svmtrain | fitcsvm |
|----------|---------|
| 'linear' | 'linear' |
| 'quadratic' | 'polynomial' (Degree=2) |
| 'polynomial' | 'polynomial' |
| 'rbf' | 'rbf' or 'gaussian' |
| 'mlp' | Use custom kernel |

---

### svmclassify → predict

**Status:** Removed in R2018a. Use `predict` method of ClassificationSVM instead.

**Old Pattern (No Longer Works):**
```matlab
% Legacy SVM classification
SVMStruct = svmtrain(XTrain, YTrain);
YPred = svmclassify(SVMStruct, XTest);
```

**Modern Pattern (Use This):**
```matlab
% Modern SVM classification
SVMModel = fitcsvm(XTrain, YTrain);
YPred = predict(SVMModel, XTest);

% With scores (probability-like values)
[YPred, scores] = predict(SVMModel, XTest);
```

**Complete SVM Migration Example:**
```matlab
% Old code (won't work in R2018a+)
% SVMStruct = svmtrain(X, Y, 'kernel_function', 'rbf', 'rbf_sigma', 1);
% predictions = svmclassify(SVMStruct, Xnew);

% Modern equivalent
SVMModel = fitcsvm(X, Y, 'KernelFunction', 'rbf', 'KernelScale', 1);
predictions = predict(SVMModel, Xnew);

% Cross-validation
CVSVMModel = crossval(SVMModel);
classLoss = kfoldLoss(CVSVMModel);
```

---

## Deprecated Data Types

### dataset → table

**Status:** Not recommended. Use MATLAB's built-in `table` data type instead.

**Old Pattern (Not Recommended):**
```matlab
% Legacy dataset (requires Statistics Toolbox)
ds = dataset(age, weight, height, 'VarNames', {'Age', 'Weight', 'Height'});
ds.BMI = ds.Weight ./ (ds.Height/100).^2;
subds = ds(ds.Age > 30, :);
```

**Modern Pattern (Use This):**
```matlab
% Modern table (core MATLAB, no toolbox required)
T = table(age, weight, height, 'VariableNames', {'Age', 'Weight', 'Height'});
T.BMI = T.Weight ./ (T.Height/100).^2;
subT = T(T.Age > 30, :);
```

**Migration Function:**
```matlab
% Convert existing dataset to table
T = dataset2table(ds);
```

**Why table is Better:**
- Part of core MATLAB (no Statistics Toolbox required)
- Better integration with modern MATLAB functions
- More consistent syntax
- Better datetime and categorical support
- Improved display and indexing options

**Property/Method Name Changes:**
| dataset | table |
|---------|-------|
| 'VarNames' | 'VariableNames' |
| ds.Properties.VarNames | T.Properties.VariableNames |
| export(ds, ...) | writetable(T, ...) |
| join(ds1, ds2) | join(T1, T2) or outerjoin(T1, T2) |

---

### nominal → categorical

**Status:** Not recommended. Use `categorical` instead.

**Old Pattern (Not Recommended):**
```matlab
% Legacy nominal array (requires Statistics Toolbox)
colors = nominal({'red', 'blue', 'red', 'green', 'blue'});
counts = countlevels(colors);
```

**Modern Pattern (Use This):**
```matlab
% Modern categorical array (core MATLAB)
colors = categorical({'red', 'blue', 'red', 'green', 'blue'});
counts = countcats(colors);
```

**Key Changes:**
| nominal | categorical |
|---------|-------------|
| `nominal({'a','b'})` | `categorical({'a','b'})` |
| `getlevels(x)` | `categories(x)` |
| `countlevels(x)` | `countcats(x)` |
| `droplevels(x)` | `removecats(x)` |
| `mergelevels(x)` | `mergecats(x)` |

---

### ordinal → categorical (with ordering)

**Status:** Not recommended. Use `categorical` with `'Ordinal', true` instead.

**Old Pattern (Not Recommended):**
```matlab
% Legacy ordinal array
sizes = ordinal({'small', 'medium', 'large', 'medium'}, ...
    {'small', 'medium', 'large'});
```

**Modern Pattern (Use This):**
```matlab
% Modern ordinal categorical array
sizes = categorical({'small', 'medium', 'large', 'medium'}, ...
    {'small', 'medium', 'large'}, 'Ordinal', true);

% Comparisons work as expected
largeSizes = sizes > 'medium';
```

**Key Differences:**
- `categorical` with `'Ordinal', true` allows comparison operators (`<`, `>`, `<=`, `>=`)
- Use `isordinal(x)` to check if a categorical array is ordinal
- Use `categories(x)` to get ordered category list

---

## Modern Machine Learning Workflow

### Recommended Pattern for Classification

```matlab
% 1. Prepare data
data = readtable('data.csv');
X = data{:, 1:end-1};
Y = categorical(data.Label);

% 2. Partition data
cv = cvpartition(Y, 'HoldOut', 0.3);
XTrain = X(cv.training, :);
YTrain = Y(cv.training);
XTest = X(cv.test, :);
YTest = Y(cv.test);

% 3. Train model (choose appropriate function)
% For decision trees:
model = fitctree(XTrain, YTrain);

% For SVM:
model = fitcsvm(XTrain, YTrain, 'KernelFunction', 'rbf');

% For ensemble methods:
model = fitcensemble(XTrain, YTrain, 'Method', 'Bag');

% 4. Evaluate
YPred = predict(model, XTest);
accuracy = mean(YPred == YTest);
confusionchart(YTest, YPred);

% 5. Cross-validation
cvModel = crossval(model);
cvLoss = kfoldLoss(cvModel);
```

---

## Function Reference: fit* Family

The modern Statistics and Machine Learning Toolbox uses a consistent `fit*` naming convention:

| Function | Purpose |
|----------|---------|
| `fitctree` | Classification tree |
| `fitrtree` | Regression tree |
| `fitcsvm` | Support vector machine (classification) |
| `fitrsvm` | Support vector machine (regression) |
| `fitcensemble` | Classification ensemble |
| `fitrensemble` | Regression ensemble |
| `fitcknn` | k-nearest neighbors (classification) |
| `fitcnb` | Naive Bayes (classification) |
| `fitcdiscr` | Discriminant analysis |
| `fitclinear` | Linear classification (high-dimensional) |
| `fitrgp` | Gaussian process regression |
| `fitglm` | Generalized linear model |
| `fitlm` | Linear model |

---

## Version Compatibility Notes

- **R2018a:** classregtree, svmtrain, svmclassify removed
- **R2014a:** fitcsvm introduced as svmtrain replacement
- **R2013b:** table introduced as dataset replacement
- **R2013b:** categorical introduced as nominal/ordinal replacement

---

## Summary: Functions to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `classregtree` | `fitctree` / `fitrtree` | Removed in R2018a |
| `svmtrain` | `fitcsvm` | Removed in R2018a |
| `svmclassify` | `predict` | Removed in R2018a |
| `dataset` | `table` | Not recommended, use core MATLAB |
| `nominal` | `categorical` | Not recommended, use core MATLAB |
| `ordinal` | `categorical(..., 'Ordinal', true)` | Not recommended, use core MATLAB |

