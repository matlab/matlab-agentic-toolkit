# STEP: Creating and validating the function handle

This file applies because `functionHandleMap` marked at least one **confirmed** function `"yes"` (Before You Compute → Rule 1). It builds **one** handle for the confirmed set and validates it. Whether a handle is needed is already settled beforehand.

## Why this matters

An unverified hand-rolled encoding (wrong one-hot orientation or column order), or a handle that returns the wrong output kind (a label where a score is needed, or two outputs where one is expected), silently scrambles attributions: the functions do not error, they return a confidently wrong answer. Validation is the only thing that catches this, so it is not optional.

## Output contract — per function

For a handle `f(X)` where `X` has one observation per row, each function requires a specific output. The formats genuinely differ, so do not build one output shape and reuse it blindly.

| Function | `f(X)` must return |
|----------|--------------------|
| `shapley` | a **single numeric score column** (one score per row). A handle is always treated as regression, so return one numeric column, **not** `[label, score]`. |
| `lime` (classification) | a **class label** per row (not a score) |
| `lime` (regression) | a numeric prediction per row |
| `partialDependence` / `plotPartialDependence` | a **numeric matrix**, one row per observation, one or more columns (real; the plot form rejects complex) |

## Multiclass: how the class is selected differs by function

- **`shapley`** takes a **single** column and rejects a multi-column handle output, so build **one handle per class of interest** whose adapter selects that class's score column. To explain a different class, point the adapter at that column and refit.
- **`partialDependence` / `plotPartialDependence`** accept the **full score matrix** from the handle and select the class with `OutputColumns` — one handle, no rebuild.

## Build one handle for the confirmed set

1. **Prediction function.** Write the single call into the model once and get it right — it is the one place errors hide.
2. **Per-function adapter.** Wrap the prediction function to each confirmed function's contract above: a score column for `shapley`, a label for classification `lime`, the score matrix for PD. One prediction function, thin adapters — not several unrelated handles.
3. **Match the input form** the interpretability call receives: table in → table into the handle; matrix in → matrix.

## dlnetwork

- Pass the predictor **table directly** to `minibatchpredict` and let it encode the categorical columns; do **not** hand-roll `onehotencode` / `dlarray`. But its **default encoding is `integer`** (one column per categorical), which is usually not how a network with a wide input layer was trained. The only options are `"integer"` and `"one-hot"`, and which one the network expects is **not stored in the `dlnetwork`**: set `CategoricalInputEncoding` to match the training recipe.
- Resolve the encoding from the input layer, not a guess. `net.Layers(1).InputSize` (the `featureInputLayer` channel count) is what the network expects. If it equals the number of predictor columns, the `integer` default fits; if it is larger, the categoricals were expanded, so pass `CategoricalInputEncoding="one-hot"` (channels = numeric columns plus one per category of each categorical). A `minibatchpredict` channel-size error ("expects 17 but received 12") is exactly this mismatch.
- Class names are **not recoverable from a bare `dlnetwork`**. For a `lime` label adapter, pass the true class names if the user knows them; otherwise use dummy names `"Class 1".."Class K"` in score-column order and tell the user they are placeholders.
- Because none of this is verifiable from the object, the validate step below is mandatory for a `dlnetwork`.

## Validate before trusting

Confirm the prediction function reproduces the model's own known predictions on a few rows before running any interpretability call. Only a validated handle becomes `Mdl`.

## Show the function, confirm class, file name and path, in one stop

The saved `.m` file is the named prediction function; the **handle** is the `@(...)` expression that calls it (e.g. `@(T) netFcnHandle(net, T, "score", classIdx)`) and is what you pass to `shapley` / `partialDependence` / `lime` as `Mdl`.

Before writing the file and running anything, stop once and put these in front of the user in plain terms they can check and correct:

- **The function and its handles** — show what they compute and return, not just that they passed.
- **The class order** — state it explicitly, e.g. `[Low, High]`, with the reason it came out that way, not a bare number. Confirm it if not obvious.
- **The encoding** (`dlnetwork`) — state which `CategoricalInputEncoding` you resolved so a wrong recipe can be corrected here rather than silently.
- **The file name path** — where the prediction function will be saved. Default file name:
  **`<model-variable-name>FcnHandle.m`** (e.g. a model in `net` → `netFcnHandle.m`, one in `Mdl` →
  `MdlFcnHandle.m`); suggest this and a default folder unless the user names it otherwise.

**CONFIRM — stop here and wait for the user's reply before writing the file or running anything.** This is the **single** handle stop and is separate from plan approval: the plan gate settled *what* to compute; this settles *that the handle's prediction logic is right* and *where its prediction function lives*. Keep it inline (an anonymous handle with no saved prediction function) only when it needs no named helper **and** the user explicitly asks for inline.

After the user confirms, write the function to the agreed path and make its folder callable — `addpath` the folder, and with `UseParallel` add it before the parallel call so the workers see it too. Then make a call through the saved handle and confirm it reproduces the result you validated inline. This is a distinct check from the logic validation above: that one proved the *logic*; this proves the *file resolves* (right folder, on the path, no name collision shadowing it). Only after both pass does the real interpretability call run.

## A handle carries no metadata

A handle cannot expose which predictors are categorical, whether it is classification or regression, or how many output columns it has. Supply these at each call through name-value arguments; the exact argument per function is in that function's reference.

## If the user provided a handle

Do not construct one. Vet the given handle against the contract for the confirmed set, and if it does not fit, tell the user exactly what to correct rather than adapting it silently — for example, "`shapley` needs a single numeric score column, but this returns `[label, score]`; return only the target-class score."

## Worked example: dlnetwork

```matlab
% net is a trained dlnetwork; Xtrain is a table of predictors.
% One prediction function (netFcnHandle), conditioned to return the output each function
% needs; thin per-function adapters capture only what they use. The model call
% lives in ONE place.

% Resolve the encoding from the input layer, not a guess: the channel count
% net.Layers(1).InputSize is what the net expects. If it exceeds width(Xtrain),
% the categoricals were expanded, so use "one-hot"; if equal, "integer" fits.
classIdx   = 2;                               % REPLACE: index of the class to explain
classNames = ["classA" "classB" "classC"];   % REPLACE: true names, or dummy "Class "+string(1:K)
% If class names are NOT recoverable (a bare dlnetwork does not carry them), use
% dummy "Class 1".."Class K" and TELL THE USER they are placeholders in column order.

% Thin adapters — each passes only what its output needs.
scoreFcn  = @(T) netFcnHandle(T, net, "score", classIdx);    % shapley: one class's score column
labelFcn  = @(T) netFcnHandle(T, net, "label", classNames);  % lime: a class label per row
% partialDependence takes the full matrix:  @(T) netFcnHandle(T, net, "matrix")

% Verify the core reproduces the network's own scores on a few rows before
% trusting any adapter: compare netFcnHandle(Xtrain(1:5,:), net, "matrix") against
% the network's known scores. A wrong CategoricalInputEncoding errors on channel
% size, or if the widths happen to match it silently misencodes — this check
% catches it.

% Categorical predictors cannot be read from a handle — supply them.
% (Columns 3 and 7 here — confirm per model.)
explainer = shapley(scoreFcn, Xtrain, QueryPoints=Xquery, ...
    CategoricalPredictors=[3 7], UseParallel="auto");
plot(explainer)

limeExplainer = lime(labelFcn, Xtrain, Type="classification", CategoricalPredictors=[3 7]);

function out = netFcnHandle(T, net, outputKind, classSelector)
    % Prediction function — the ONE place the model call lives. Get it right once.
    scores = minibatchpredict(net, T, CategoricalInputEncoding="one-hot"); % REPLACE: "integer" if no expansion
    switch outputKind
        case "score"    % shapley needs a single numeric score column
            out = scores(:, classSelector);            % classSelector = class index
        case "label"    % lime (classification) needs a class label per row
            out = scores2label(scores, classSelector); % classSelector = class names
        case "matrix"   % partialDependence takes the full score matrix
            out = scores;
    end
end
```

For other custom models the body of the core differs, but the build-place-validate procedure is identical.

----

Copyright 2026 The MathWorks, Inc.

----
