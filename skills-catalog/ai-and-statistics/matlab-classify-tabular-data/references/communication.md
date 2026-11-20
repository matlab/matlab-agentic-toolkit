# Talk About the Data and Results, Not the Skill

Apply these rules for the whole run, from Step 1 to the last message.

Talk to the user about their **data and results**, not about the skill's plumbing. Everything under `references/` and `scripts/` (both `helpers/` and `model_catalog/`) is internal — a user watching the run should never have to ask what a filename means.

Concretely, while executing this skill:

- **Do not name internal files or helpers** in progress messages. `references/select-classifiers.md`, `build_model_definitions`, `compute_pairwise_pvalues_cv`, `classifier_branches`, `resolve_recipe`, `modelDefs`, `cvFitFcn`, etc., are all internal. If you must reference them (e.g., surfacing a bug the user can act on), name them once and explain what they are.
- **Do not narrate branch dispatch or filter decisions** by name. "Dispatching to the wide branch", "applying the imbalanced overlay", "`isSparse` is false so we skip the sparse branch" — all internal. The user only needs to hear the *outcome*: "This dataset is wide (200 features, 40 samples), so I'm using linear models."
- **Do not read reference files out loud.** When a step says *STOP and read `references/foo.md`*, that is a directive to you, not a status update to broadcast. Read it silently and continue.
- **Do announce what the user chose to run, and roughly how long it will take**, before a long training loop or HPO run. One sentence.
- **Do surface user-facing questions verbatim** where the step specifies them (evaluation strategy, interpretability, uniform prior, HPO selection). Those *are* the user's interface to the skill.
- **Do surface a real problem** if one appears — a failed check gate, a branch that couldn't match, a fit call that errored. Name it plainly; then, and only then, is it fine to reference the internal file where the fix belongs.

Illustrative contrast:

> **Don't:** "Reading `references/dataprep.md`... computing `flags` via `compute_data_flags`... `isImbalanced=true`, so reading `references/select-classifiers-imbalanced.md` and applying `IMBALANCED_BOOSTING_MODELS` overlay to `build_model_definitions`. `modelDefs` now has 8 entries including RUSBoost-OVO and RUSBoost-OVA."
>
> **Do:** "Class ratio is 9:1, so I'll use imbalance-aware boosting models. Before I train, I need to ask you about the class prior — [uniform-prior question verbatim]."

Rule of thumb: if a sentence would only make sense to someone who has read this skill's source files, don't say it.

----

Copyright 2026 The MathWorks, Inc.

----
