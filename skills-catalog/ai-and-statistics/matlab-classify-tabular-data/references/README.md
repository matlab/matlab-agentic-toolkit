# Keep the Reference and Script Layout Intact

Keep step instructions in `references/` (markdown), callable functions in `scripts/helpers/`, and the branch tables in `scripts/model_catalog/` (run only from inside `build_model_definitions`).

## Markdown files

Read each file only when the SKILL.md step that names it says so (SKILL.md "Bundled files" lists them).

## Model catalog — do not call directly

Do not read these files, and run only the two that SKILL.md Steps 3 and 5 `run(...)` (`classifier_thresholds.m`, `imbalanced_boosting.m`). Keep them together in that folder; do not move or split them. Call `build_model_definitions`; that helper `run(...)`s the following in sequence and reads the variables they populate in the caller's workspace:

- **`classifier_branches.m`** — walks the five branch files below and populates `BRANCHES`.
- **`classifier_thresholds.m`** — populates the `THRESHOLDS` struct shared by the branch files.
- **`branch_sparse.m`, `branch_many_missing.m`, `branch_categorical.m`, `branch_wide.m`, `branch_regular.m`** — one branch per file; each appends its recipes to `BRANCHES` via `model_recipe(...)`.
- **`imbalanced_boosting.m`** — populates `IMBALANCED_BOOSTING_MODELS`. When `flags.isImbalanced`, run it in Step 5 and pass the result to `build_model_definitions` as `'ImbalancedOverlay'`.
- **`model_recipe.m`** — recipe constructor used inside every branch file.


----

Copyright 2026 The MathWorks, Inc.

----
