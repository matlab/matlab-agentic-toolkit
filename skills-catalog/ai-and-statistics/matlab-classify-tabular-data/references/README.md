# References — layout and conventions

`references/` holds the skill's **policy prose**: the step-by-step markdown for each phase. Computation lives under `scripts/`, which is split into two subfolders: `scripts/helpers/` (functions the agent calls directly, e.g. `build_model_definitions`, `train_and_score_cv`) and `scripts/model_catalog/` (declarative `.m` files chained via `run(...)` from inside `build_model_definitions`, deciding which classifiers apply on each kind of dataset).

## Markdown files

Read only when the corresponding step in `SKILL.md` says so:

- **`dataprep.md`** — Step 2 data-cleaning prescription.
- **`select-classifiers.md`** — Step 5 model-selection prescription.
- **`select-classifiers-imbalanced.md`** — Step 5 overlay when `flags.isImbalanced`.
- **`hpo.md`** — Step 11 hyperparameter-optimization prescription.
- **`save-and-export.md`** — Steps 13 and 14 save/export prescription.

## Model catalog — do not call directly

The files in `scripts/model_catalog/` are agent-invisible. The agent calls `scripts/helpers/build_model_definitions.m`; that helper `run(...)`s the following in sequence and reads the variables they populate in the caller's workspace:

- **`classifier_branches.m`** — walks the five branch files below and populates `BRANCHES`.
- **`classifier_thresholds.m`** — populates the `THRESHOLDS` struct shared by the branch files.
- **`branch_sparse.m`, `branch_many_missing.m`, `branch_categorical.m`, `branch_wide.m`, `branch_regular.m`** — one branch per file; each appends its recipes to `BRANCHES` via `model_recipe(...)`.
- **`imbalanced_boosting.m`** — populates `IMBALANCED_BOOSTING_MODELS`; loaded by the agent from Step 5 when `flags.isImbalanced` and passed to `build_model_definitions` via the `'ImbalancedOverlay'` name-value pair.
- **`model_recipe.m`** — recipe constructor used inside every branch file.

## Why the catalog files live together in `scripts/model_catalog/`

MATLAB's `run(scriptFile)` temporarily changes the current working folder to `scriptFile`'s directory while the script executes. So while `classifier_branches.m` runs, cwd is `scripts/model_catalog/`; while `branch_sparse.m` runs (chained via `run(...)` from `classifier_branches.m`), cwd is still `scripts/model_catalog/`.

`model_recipe` is called from inside those chained scripts. It has to resolve by cwd (since the SDK forbids `addpath`). That only works if `model_recipe.m` sits next to its callers. Splitting these files across directories breaks the chain — the recipe helper becomes unreachable during `run(...)`, and every branch file errors with *"Undefined function 'model_recipe' for input arguments of type 'struct'"*.

The same reasoning applies to `classifier_branches.m`, `classifier_thresholds.m`, `imbalanced_boosting.m`, and the `branch_*.m` files: they populate variables in the caller's workspace and are only invoked via `run(...)` from `build_model_definitions`. Keeping them together in `scripts/model_catalog/` keeps the whole chain resolvable without any path manipulation. Callers see only the entry point `scripts/helpers/build_model_definitions.m`, which is a proper function.

---

Copyright 2026 The MathWorks, Inc.
