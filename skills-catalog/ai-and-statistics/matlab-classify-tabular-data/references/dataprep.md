# Prepare Data for Classification

Run this right after Step 1 (load data), before any splitting decision, model selection, or interpretability question.

## Required inputs (from SKILL.md)

- `X`, `Y` — full data (no pre-split), OR
- `XTrain`, `YTrain` — training data (if the dataset came with a separate test set), plus `XTest`, `YTest`

Work on the data SKILL.md Step 1 assigned. All analysis and flag computation uses this data — the training data only, when a test set was supplied.

**A supplied test set receives every edit.** When the dataset came with a separate test set (`hasHoldout`), apply every column edit below (`omitColumns`, `dropZeroVariance`) to `XTest` as well as `XTrain` — the same column names for a table, the same column indices for a matrix — and every class edit (`removeClasses`, `mergeClasses`) to `YTest` as well as `YTrain`. Decide each edit from the training data only; do not re-scan `XTest`. A matrix `XTest` that keeps a column the models were trained without errors at the first prediction, after every model has been trained.

**Input-shape assumption.** X must be either a fully-numeric matrix (dense or sparse) OR a table. Categorical features are recognised only via table columns whose dtype is `categorical`, `string`, or `cellstr` — `compute_data_flags.hasCategorical` looks at column dtypes, not values, so a categorical variable encoded as `double` inside a matrix is invisible to this skill. If the user supplies predictors as a set of separate workspace variables of mixed types, assemble them into a table with `table(varA, varB, ...)` before running this reference; do not `horzcat` them into a numeric matrix.

**Record every mutation in `preproc`.** Every user-driven or automatic edit to X or Y in this reference must be recorded in a struct-array variable named `preproc` (fields: `.op`, `.payload`, `.note`) *in the order it is applied*. This is what makes the Step 14 workflow-script export possible — the exported script replays `preproc` on new data via `apply_preproc`. Initialize `preproc` before any edits:

```matlab
preproc = struct('op', {}, 'payload', {}, 'note', {});
```

The ops emitted below are: `omitColumns` (user-selected feature removal), `dropZeroVariance` (automatic zero-variance drop), `removeClasses` (user chose to drop minority classes), `mergeClasses` (user chose to merge classes). Anything the caller does to the *sample count* alone (stratified subsampling for big-data speedups in Step 5, and the unusable-row drop below) is **not** recorded — subsampling only affects training speed, and the `fitc*` functions drop unusable rows from new data on their own.

## Step 1: Analyze data

### Drop unusable rows first

Before any reporting, remove the rows no classifier can use — rows whose class label is missing (categorical `<undefined>`, `NaN`, string `<missing>`, or an empty label `''`) and rows whose predictors are all missing. The `fitc*` functions drop these rows silently, so leaving them in makes the class counts, the imbalance flags, and the uniform-prior weights describe data the models never see; a single missing label otherwise counts as a class of size zero. The helper also turns a char-matrix `Y` (one label per row) into a cellstr column, so that `Y(idx)` selects labels rather than characters:

```matlab
[X, Y, rowInfo] = drop_unusable_rows(X, Y);   % (XTrain, YTrain) if hasHoldout
```

If `hasHoldout`, run it on `XTest`/`YTest` as well. When `rowInfo.nMissingLabel` or `rowInfo.nAllPredictorsMissing` is nonzero, tell the user how many rows were removed and why, for each data set.

Report the following before any cleaning:

- **Dimensions:** number of observations (rows) and features (columns)
- **Classes:** number of classes, class labels, and distribution (count and percentage per class)
- **Missing values:** identify features with missing values and report counts (count and percentage of missing per feature)
- **Feature types:** count numeric vs categorical features
- **High-cardinality categoricals:** identify categorical features with more than 10 levels; report each feature name and its number of levels
- **Zero-variance features (global):** features constant across all observations
- **Zero-variance features (within-class):** features constant within at least one class but not globally

Use `ismissing` for missing value detection. Identify globally zero-variance columns via `scripts/helpers/find_zero_variance_columns.m`, which is sparse-safe (it does not densify the matrix).

### Ask about feature omission

If any features have many missing values or any categorical features have more than 10 levels, present the specific features to the user and ask whether they want to omit them from the analysis. For example:

> The following features may be problematic for classification:
>
> **High missingness:**
> - `Feature3`: 342 missing (22.8%)
> - `Feature7`: 198 missing (13.2%)
>
> **High-cardinality categoricals (>10 levels):**
> - `Feature5`: 47 levels
> - `Feature12`: 23 levels
>
> Would you like to omit any of these features from the analysis? (list feature names, "all", or "none")

Wait for the user's response. Remove any features the user chooses to omit before proceeding (from `XTest` too, if `hasHoldout`), and record the operation in `preproc`:

```matlab
% Table X: record by name.
preproc(end+1) = struct( ...
    'op',      'omitColumns', ...
    'payload', struct('columnNames', {omittedNames}), ...
    'note',    'User omitted high-missingness / high-cardinality features');
X = X(:, ~ismember(X.Properties.VariableNames, omittedNames));

% Matrix X: record by index.
% preproc(end+1) = struct('op','omitColumns', ...
%     'payload', struct('columnIndices', omittedIdx), ...
%     'note', 'User omitted columns');
% X(:, omittedIdx) = [];
```

### Ask about class handling (imbalanced data)

After the feature omission question (or if no features are problematic), compute the class ratio: `max(classSize) / min(classSize)`. If the class ratio exceeds 5, identify minority classes with less than 1% of the data and present them to the user:

> The data is highly imbalanced (class ratio [classRatio]:1). The following classes have fewer than 1% of observations:
>
> - Class `[label]`: [count] ([percentage]%)
> - Class `[label]`: [count] ([percentage]%)
> - ...
>
> I suggest removing these minority classes from the analysis. Alternatively, you can specify classes to remove, classes to merge together, or keep all classes as-is. How would you like to handle these classes?

Wait for the user's response, then apply whatever class modifications they request, recording each in `preproc`:

- **Removing classes:** Remove all observations belonging to the specified classes from the training data (and test data if `hasHoldout`). Update `Y` (or `YTrain`/`YTest`) to remove unused categories.

  ```matlab
  preproc(end+1) = struct( ...
      'op',      'removeClasses', ...
      'payload', struct('classes', {removedClasses}), ...
      'note',    'User removed minority classes');
  ```

- **Merging classes:** Relabel the specified classes with the label the user provides. Update `Y` (or `YTrain`/`YTest`) accordingly.

  ```matlab
  preproc(end+1) = struct( ...
      'op',      'mergeClasses', ...
      'payload', struct('map', struct('from', {sourceLabels}, 'to', targetLabel)), ...
      'note',    'User merged minority classes into a single label');
  ```

- **Keep all:** Proceed unchanged (no `preproc` entry).

After any modification, re-run `compute_data_flags` to refresh `flags` before proceeding.

## Step 2: Clean data

- Remove features identified as globally zero-variance (constant across all observations)
- Do NOT remove features that are zero-variance within a single class but vary globally — these carry discriminative signal
- Report how many features were removed and the final dimensions
- If `hasHoldout`, drop the same columns from `XTest` (scan `XTrain` only, then remove by the same names or indices)
- Record the drop in `preproc` so the workflow-script export can replay it:

```matlab
zvIdx = find_zero_variance_columns(X);
if ~isempty(zvIdx)
    if istable(X)
        zvNames = X.Properties.VariableNames(zvIdx);
        preproc(end+1) = struct( ...
            'op',      'dropZeroVariance', ...
            'payload', struct('columnNames', {zvNames}), ...
            'note',    'Globally zero-variance columns');
        X(:, zvIdx) = [];
    else
        preproc(end+1) = struct( ...
            'op',      'dropZeroVariance', ...
            'payload', struct('columnIndices', zvIdx), ...
            'note',    'Globally zero-variance columns');
        X(:, zvIdx) = [];
    end
end
```

### Check the supplied test set's classes (`hasHoldout` only)

After every edit above, remove the test observations of any class the training data does not have — for example labels split unevenly between two files. No model can predict such a class, and scoring a test set that contains one errors after the first model has been trained:

```matlab
[XTest, YTest, testInfo] = drop_unseen_test_classes(XTest, YTest, YTrain);
```

If `testInfo.removedClasses` is not empty, tell the user which classes were removed from the test set and how many observations each (`testInfo.removedCounts`). If `testInfo.nRemaining` is 0, stop before training and tell the user that the test set has no class in common with the training data.

## Step 3: Compute data characteristic flags

After cleaning, call `compute_data_flags` to populate a single `flags` struct in the workspace:

```matlab
flags = compute_data_flags(X, Y);   % or (XTrain, YTrain) if hasHoldout
```

The struct carries `N`, `D`, `nClasses`, `classSize`, `smallestClassSize`, `classRatio`, `isBinary`, `isImbalanced`, `isWide`, `isHighD`, `isBig`, `hasManyMissing`, `isSparse`, `hasCategorical`. These fields are used by the `select-classifiers` reference to choose appropriate models. Do not compute them yourself — the helper is the single source.

----

Copyright 2026 The MathWorks, Inc.

----
