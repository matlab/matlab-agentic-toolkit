# References — layout and conventions

`references/` holds the skill's **policy** content: the step-by-step markdown for each phase, plus the declarative branch tables that decide which classifiers apply on each kind of dataset. `scripts/` holds the **computation** (helpers that call MATLAB built-ins with the skill's conventions). The two directories are intentionally separate; editing a branch table changes which models the skill recommends, editing a script changes how a computation is performed.

## Markdown files

Read only when the corresponding step in `SKILL.md` says so:

- **`dataprep.md`** — Step 2 data-cleaning prescription.
- **`select-classifiers.md`** — Step 5 model-selection prescription.
- **`select-classifiers-imbalanced.md`** — Step 5 overlay when `flags.isImbalanced`.
- **`hpo.md`** — Step 11 hyperparameter-optimization prescription.

## Branch tables (`.m` files) — do not call directly

These are agent-invisible. The agent calls `scripts/build_model_definitions.m`; that helper `run(...)`s the following in sequence and reads the variables they populate in the caller's workspace:

- **`classifier_branches.m`** — walks the five branch files below and populates `BRANCHES`.
- **`classifier_thresholds.m`** — populates the `THRESHOLDS` struct shared by the branch files.
- **`branch_sparse.m`, `branch_many_missing.m`, `branch_categorical.m`, `branch_wide.m`, `branch_regular.m`** — one branch per file; each appends its recipes to `BRANCHES` via `model_recipe(...)`.
- **`imbalanced_boosting.m`** — populates `IMBALANCED_BOOSTING_MODELS`; loaded by the agent from Step 5 when `flags.isImbalanced` and passed to `build_model_definitions` via the `'ImbalancedOverlay'` name-value pair.
- **`model_recipe.m`** — recipe constructor used inside every branch file.

## Why `model_recipe.m` is here and not in `scripts/`

MATLAB's `run(scriptFile)` temporarily changes the current working folder to `scriptFile`'s directory while the script executes. So while `classifier_branches.m` runs, cwd is `references/`; while `branch_sparse.m` runs (chained via `run(...)` from `classifier_branches.m`), cwd is still `references/`.

`model_recipe` is called from inside those chained scripts. It has to resolve by cwd (since the SDK forbids `addpath`). That only works if `model_recipe.m` is in `references/` next to its callers. Moving it to `scripts/` breaks the chain — the helper becomes unreachable during `run(...)`, and every branch file errors with *"Undefined function 'model_recipe' for input arguments of type 'struct'"*.

The same reasoning applies to `classifier_branches.m`, `classifier_thresholds.m`, `imbalanced_boosting.m`, and the `branch_*.m` files: they populate variables in the caller's workspace and are only invoked via `run(...)` from `build_model_definitions`. Keeping them in `references/` alongside `model_recipe.m` keeps the whole chain resolvable without any path manipulation. Callers see only the entry point `scripts/build_model_definitions.m`, which is a proper function.

---

Copyright 2026 The MathWorks, Inc.
