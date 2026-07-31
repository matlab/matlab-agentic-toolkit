# Save Trained Models and Export a Retraining Workflow Script

This reference is dispatched from the orchestrator after Step 12 (Summary) has been delivered to the user. It covers the two optional wrap-up steps:

- **Step 13** — save any of the trained models to a `.mat` file for later reuse (`save_selected_models`).
- **Step 14** — emit a self-contained MATLAB script that reproduces the entire workflow on new data (`export_workflow_script`). Only offered if the user saved at least one model in Step 13.

Present the two decisions in order. Do not read this reference until Step 12 has been reported, because the user's answer to "which models should I save?" depends on the per-model accuracy table they just saw.

## Step 13 — save trained models (optional)

Ask the user whether they want to save any of the trained models to a `.mat` file for later reuse.

Present the full model list with a suggested default (top-tier models), and let the user pick freely:

> Would you like to save any of the trained models to a `.mat` file? You can pick individual models, "top" for the top-tier list, "all", or "none".
>
> **Top tier:** [top-tier model names]
> **All models:** [full model list]

If the user says "none", skip to Step 14.

If the user picks one or more models, ask about the save form and location.

### Save form

Ask the user:

> Save as **compact** (deployment-ready, smaller file — recommended) or **full** (keeps training data reference, supports resubstitution loss and CV)? (compact / full)

Default is compact. Record the answer as `useCompact` (logical). The helper calls `compact()` on every model that supports it when `useCompact = true`.

### Save location

Propose a default and let the user override:

> I'll save these to `<default-path>`. Enter a different path to override, or press Enter to accept.

**Default path.** Use `fullfile(pwd, sprintf('classification_models_%s.mat', string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))))`. Do not write anywhere outside the user's current working folder without asking.

### Call the helper

```matlab
metadata = struct( ...
    'evalPath',        evalPath, ...          % 'cv' or 'holdout'
    'flags',           flags, ...
    'interpretability',interpretability, ...
    'useUniformPrior', useUniformPrior, ...
    'modelNames',      {modelNames}, ...
    'accuracy',        acc, ...
    'accuracyCI',      accCI);

savedPath = save_selected_models(selectedNames, modelDefs, trainedModels, ...
    X, Y, savePath, metadata, useCompact);
fprintf('Saved %d model(s) to %s\n', numel(selectedNames), savedPath);
```

- `trainedModels` is a cell array aligned with `modelDefs`. On the holdout path each cell holds the trained model returned by `train_and_score_holdout`; on the CV path each cell holds the cross-validated model returned by `train_and_score_cv`. The helper detects CV-wrapped models and **retrains them on the full `(X, Y)` via `modelDefs(k).fitFcn`** so the saved model is directly usable via `predict(loadedModel, XNew)`.
- On the CV path, pass the full `X` and `Y` as arguments 4 and 5. On the holdout path, pass `XTrain` and `YTrain` — but note the helper only uses them when a cell contains a CV wrapper, which the holdout path never produces.
- The helper sanitizes model names for `save`: `LinearSVM-OVO` becomes the variable name `LinearSVM_OVO`. The original name is preserved in `metadata.modelNameMap`.

## Step 14 — export retraining workflow script (optional)

If the user saved models in Step 13, offer to generate a self-contained MATLAB script that reproduces the entire workflow on new data drawn from the same distribution:

> Would you like me to generate a script that retrains these models on new data (same columns, same class labels)? The script will replay the data-preparation steps you chose, re-fit the models, and save them. (yes / no)

If the user says no, the workflow is complete.

If yes, propose a default script path and let the user override it, then call the bundled helper:

```matlab
config = struct( ...
    'skillPath',         skillPath, ...
    'selectedNames',     {selectedNames}, ...
    'preproc',           preproc, ...
    'interpretability',  interpretability, ...
    'useUniformPrior',   useUniformPrior, ...
    'hpoModels',         {hpoModelNames}, ...       % {} if none
    'resumeCycles',      resumeCycles, ...          % struct() if none
    'useCompact',        useCompact, ...
    'modelSavePath',     modelSavePath, ...
    'datasetLabel',      datasetLabel);

scriptPath = export_workflow_script(scriptPath, config);
fprintf('Workflow script written to %s\n', scriptPath);
```

`flags` from Step 2 is intentionally NOT part of `config` — the exported script re-runs `compute_data_flags` on the new data so branch dispatch reflects whatever the retraining input actually looks like.

### What the emitted script does

The generated `.m` loads new data (`Xnew`, `Ynew`) from a `.mat` file the user supplies, replays every recorded `preproc` op via `apply_preproc`, recomputes `flags` on the new data, rebuilds `modelDefs` via the same `build_model_definitions` call (with the original `interpretability` and `useUniformPrior`), and trains only the selected models. Models on `hpoModelNames` are re-trained with **single-shot HPO on the full training set** — not the nested-CV design from Step 11 — because nested CV does not produce a single deployable parameter set. The emitted script includes a note surfacing this to the user, and reminds them that the interactive-run accuracy is a slight overestimate for this configuration.

### What the emitted script does not carry over

Stratified subsampling from Step 5 (a training-speed hack, not a data-preparation decision), and interactive Step 10 "resume with more trees" decisions unless captured in `resumeCycles`. Everything else — feature omissions, class removals, class merges, zero-variance drops — replays exactly.

---

Copyright 2026 The MathWorks, Inc.
