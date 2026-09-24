# Experiment Manager Assistant — Common Reference

Shared rules, setup, and API used by ALL six operations. Every task reference
([create](create.md), [load-project](load-project.md), [update](update.md),
[delete](delete.md), [rename](rename.md), [duplicate](duplicate.md)) assumes this file.

## Purpose
Create experiments from user code or problem descriptions AND keep the Experiment Manager (EM) UI
in sync — adding/deleting/editing experiments updates the browser tree and editor live,
without restarting EM.

## Setup

When this skill is invoked, add the skill's scripts folder to the MATLAB path so that
`manageExperimentHelpers` is available. Run this via the MATLAB MCP `evaluate_matlab_code` tool:

```matlab
addpath('<skill-base-directory>/scripts');
```

## When to Use
- User has code and wants to create an experiment (parameter sweep, training, etc.)
- User wants to add or remove experiments from an open EM session
- User wants to modify experiment parameters and see changes in the UI
- User wants to switch experiment types (Exhaustive Sweep ↔ Random Sampling ↔ Bayesian Optimization)

## When NOT to Use

If the user asks for one of the workflows below, this skill cannot perform it programmatically.
Instead, provide **only** the UI instructions listed here so the user can do it themselves
in the app.

**CRITICAL: Only say what is written here. Do NOT invent, guess, or embellish steps beyond
what this skill documents. If the user asks about details not covered here, refer them to
the official documentation:
- General-Purpose: https://www.mathworks.com/help/matlab/ref/experimentmanager-app.html
- Deep Learning: https://www.mathworks.com/help/deeplearning/ref/experimentmanager-app.html

If documentation is not reachable, make the best effort to satisfy the items above.
Never fabricate UI elements, options, or parameters.**

### Run / Execute an Experiment

Guide the user through the UI:

1. Open the experiment tab in Experiment Manager.
2. In the toolstrip **Execution** section, select a mode from the **Mode** dropdown:
   - **Sequential** — one trial at a time
   - **Simultaneous** — multiple trials in parallel (requires Parallel Computing Toolbox)
   - **Batch Sequential** — offload to cluster sequentially (requires MATLAB Parallel Server)
   - **Batch Simultaneous** — offload to cluster in parallel (requires MATLAB Parallel Server)
3. If using batch modes, select the **Cluster** profile and set **Pool Size**.
4. Click the **Run** button.
5. To stop: click **Stop** (finishes current trial) or **Cancel** (immediately ends execution).
6. To rerun failed/stopped trials: use the **Restart** dropdown and select criteria
   (`All Canceled`, `All Stopped`, `All Error`, `All Discarded`).

### Monitor / Collect Results

1. While the experiment runs, the **Results table** displays intermediate metric values
   (loss, accuracy, RMSE) in real time.
2. The **Status** column shows trial state: `Max epochs completed`, `Met validation criterion`,
   `Stopped by OutputFcn`, or `Training loss is NaN`.
3. In the **Experiment Browser** panel, double-click a result set name to open detailed results.
4. Click buttons in the **Review Results** gallery to view any available visualization in the
   **Visualizations** panel.

### Analyze Results

1. **Filter**: In the toolstrip, click **Filters** to open the filter panel.
   - Numeric columns: set upper/lower bounds.
   - String/categorical columns: specify exact match values.
   - Apply and reset filters independently.
2. **Sort**: Click any column header in the results table to sort by that metric or parameter.
3. **Annotate**: Right-click a results table cell → **Add Annotation** to record observations.
   Sort annotations by creation time or trial number.
4. **Compare**: View all trials in the results table simultaneously. Sort by metrics or
   hyperparameters to identify the best configurations.

### Post-Analysis / Iterate

1. Edit hyperparameters in the experiment definition and rerun.
2. Change strategy (e.g., Exhaustive Sweep → Bayesian Optimization) between runs.
3. Use the **Debug** button to test setup/training functions with chosen hyperparameters
   before a full run.
4. Click **Discard** in the Actions column to remove unwanted trial results.
5. Use **Restart** to rerun discarded, stopped, or errored trials.
6. Access **View Experiment Source** link in a result set to see the exact parameter values
   and function versions that produced those results.

### Export Results

1. **Export Results Table**: Select trial rows in the results table → use **Export** to save
   as a `table` array in the MATLAB workspace.
2. **Export Training Information**: Right-click a trial row → **Export Training Information**.
3. **Export Trained Network**: Right-click a trial row → **Export Trained Network**.

---

## General Principles

These policies apply to ALL operations.

1. **No pop-up windows** — All verifications, confirmations, and validations happen in the
   Agent conversation. No dialog boxes should appear to the user.
2. **Always sync with UI** — Every action is reflected in the UI immediately. Update fields =
   refresh the tab. Add/remove experiment = update the tree browser.
3. **Partial input support** — Users may provide incomplete information. The Agent identifies
   what is missing, highlights gaps, and offers to fill them.
4. **Validate before executing** — Check existence, types, and consistency of all inputs
   before performing any action.
5. **Check if an experiment is dirty before modifying** — Verify the experiment has no unsaved
   UI changes before touching it. If dirty — ask user to save first. Never overwrite unsaved work.
6. **Never expose internals** — Don't show template class names, internal error classes,
   stack traces, or implementation details. Translate all errors into plain language.
   Also don't narrate the specific MATLAB functions, helper methods, or API calls being
   run (e.g. `manageExperimentHelpers.update`, `AppController.refreshOrOpenExperiment`) —
   users care about results, not the calls behind them.
   This applies to **planning and preparatory narration too**, not just describing calls
   after the fact. Do NOT say things like "let me confirm the `createProject` helper
   signature before building" or "I'll check the `duplicate` helper first" — the fact that
   you are about to look up or call an internal helper is itself an internal detail. Describe
   the goal instead ("let me set up the new project"), never the helper you are reaching for.
   This covers **more than function names**. Never surface internal **data-structure names**
   or internal **strategy/enum values** either. Examples that must NOT appear in your reply:
   - `HyperTable` — say "the parameter values" or "the parameter table", never "the HyperTable".
   - `ParamSweep` — report the strategy by its plain name only ("Exhaustive Sweep"); never
     append or mention the internal value (not "Exhaustive Sweep (`ParamSweep`)").
   If in doubt whether a name is user-facing, it isn't — describe what it holds, not its code name.
7. **Suggest a fix** — When validation fails, tell the user what's wrong and suggest the fix
   immediately.
8. **Suggest and confirm when uncertain** — If user input is genuinely ambiguous, suggest what
   you think they meant and ask if correct. If several best guesses, present with a list of
   options and ask to choose.
9. **Batch errors from multi-command requests** — Report all failures together so the user can
   fix them in one pass, not one at a time.
10. **Always query live project state** — Never assume you know the current experiments,
   parameters, or project state from earlier in the conversation. The user may have changed
   things through the UI at any time. Before any operation (Update, Delete, Rename, Duplicate)
   AND before answering questions about experiment state (strategy, parameters, values):
   - Check dirty state first (the UI may have unsaved changes)
   - If dirty, the UI state is the truth — not the .mat file. Follow dirty state handling
     (ask user whether to save). Do NOT read the .mat file and report its values as current
     when the UI is dirty, because the user sees the UI, not the .mat file.
   - After saving (if dirty), ALWAYS read the .mat file from disk to get the current values
   - Never rely on values cached from earlier in the conversation — treat every modification
     as if the experiment state is unknown until you read it fresh from disk
   - The user can change parameters, strategy, description, or any field via the UI between
     your operations — your cached knowledge is always potentially stale
11. **Frontend support detection** — All frontend sync methods
   (`experiments.internal.AppController.syncTree`, `.refreshOrOpenExperiment`, `.getActiveTab`,
   `.renameExperiment`, `.deleteExperiment`, `.expandParameter`, `.saveExperiment`) may not
   be available on all MATLAB versions. If a call fails with an error mentioning `emitEvent`
   (e.g., "Unrecognized method 'emitEvent'"), the frontend lacks agent support — do NOT call
   any sync method again for the rest of the session. Instead:
   - Modify .mat files directly (this always works)
   - Tell the user to refresh the UI manually (close and reopen the experiment tab)
   - Provide step-by-step UI instructions for operations that require frontend sync
   - Never surface raw MATLAB errors to the user — translate to plain language

   If a call returns `status: 'timeout'`, the same applies — no further sync calls.

   **When a sync call times out or fails, always tell the user in plain language which
   parts of the UI did not update, and that they may need to refresh.** Every sync call
   returns a status, so you know whether it went through — do not report an operation as
   fully complete when a UI update did not confirm. Do what you can on disk (this always
   works: the `.mat` file, tree refresh via a fresh `syncTree`), then in your reply name
   the specific UI pieces that may be stale and how to fix them. For a delete this means:
   state that the file and tree entry are removed, but the experiment's **open tab may
   still be showing** — tell the user to close that tab. For an update or rename, state
   that the change is saved to disk but the **open editor/tab may still show the old
   values or name** — tell the user to close and reopen the experiment tab to see it.
   Keep this in user terms; never surface the raw status value or internal method name.

   Other exceptions (e.g., "Experiment Manager must be open") are recoverable — open EM
   and retry.

---

## Six Operations

| # | Operation | Description |
|---|-----------|-------------|
| 1 | [Create](create.md) | From code or description, generate function, open in EM |
| 2 | [Load Project](load-project.md) | Open project in EM, list experiments, offer actions |
| 3 | [Update](update.md) | Modify parameters, strategy, functions, supporting files |
| 4 | [Delete](delete.md) | Remove experiment tab, results, tree entry, and file |
| 5 | [Rename](rename.md) | Update name, tree label, and tab title |
| 6 | [Duplicate](duplicate.md) | Copy with custom name |

**Two buckets:**
- **Project Management** — Load Project, Create
- **Experiment Management** — Update, Rename, Duplicate, Delete

---

## The Modification Flow

Every operation follows this sequence:

```
1. Interview → 2. Pre-check (Name Resolution) → 3. Pre-check (Internal) → 4. Confirm → 5. Execute & Sync
```

Not every step applies to every operation. Low-stakes ops skip confirmation. Simple requests
skip interview. But the sequence never reorders.

---

## Step 1: Interview

Gather what's missing. The required inputs vary by operation:

| Operation | Required Inputs | Defaults (inferred) |
|-----------|----------------|---------------------|
| Create | Code or description | Type, params, values, function name, project name, description, metric, strategy (default: Exhaustive Sweep) |
| Load Project | Project path | — (none) |
| Update | What to change, new value | Which experiment (active tab) |
| Delete | Which experiment | — (none) |
| Rename | New name | Which experiment (active tab) |
| Duplicate | — (none) | Source (active tab), name (source + "_copy") |

**Rules:**
- Skip questions when the answer is obvious.
- Suggest what makes sense for missing pieces and ask if correct.
- If user provides existing code: ask about goal, which values to sweep, what metrics matter.
- If user provides a problem description: ask about existing code, parameters, ranges, metric.
- For Create: if the user hasn't specified a strategy, ask which one they'd like (Exhaustive
  Sweep, Random Sampling, or Bayesian Optimization). Suggest Exhaustive Sweep as the default.

---

## Step 2: Pre-check — Name Resolution

Resolve which project and experiment to act on.

| Check | What to verify |
|-------|---------------|
| Project | Is one open? Is it the right one? |
| Experiment | Which one? Active tab? Name match? |
| Dirty state | Save menu if experiment has unsaved UI changes |
| Disambiguation | If the user types a name of an experiment or a project that doesn't exactly match but is close to an existing name, suggest the best match and ask to choose one only if there are multiple matches |

**Rules for name resolution:**
- Opened project = project to use in case of doubt
- Active tab = current experiment (or result → no active experiment)
- Always update both tab and browser tree when syncing
- Check if projects, experiments, and all functions exist on disk
- Close names → ask to disambiguate only if there are multiple matches.
  For this case, a confirmation in the end is also requested.

**Dirty state handling:**
```matlab
clear classes
result = experiments.internal.AppController.refreshOrOpenExperiment(fullfile('<projectPath>', '<experimentName>.mat')); disp(result);
```

If `status: 'error'` with "unsaved changes", you MUST STOP and ask the user. Present this
menu and WAIT for their response before proceeding:

1. Save automatically (the Agent saves via API and continues)
2. Save manually (user does Ctrl+S, then tells the Agent to proceed)

**Do NOT silently save and continue.** The user may have made intentional UI changes they
want to discard, or they may prefer to save manually. Always ask.

After the user chooses option 1:
```matlab
clear classes
expFile = '<expFile>';
result = experiments.internal.AppController.saveExperiment(expFile); disp(result);
```

**CRITICAL ordering:** When the UI is dirty, you MUST save the UI FIRST, THEN apply your
programmatic modification, THEN refresh. If you modify the .mat file and then save the UI,
the UI save overwrites your programmatic change with its stale state.

Correct sequence:
1. `AppController.saveExperiment(expFile)` — flush UI state to disk
2. **Read the current .mat file state** — after saving, the .mat file contains the user's
   latest changes. ALWAYS read the current parameter values/distributions from disk rather
   than using stale values from earlier in the conversation. The user may have changed
   values in the UI.
3. `manageExperimentHelpers.update(expFile, modifications)` — apply ONLY the requested
   change (e.g., strategy switch) while preserving the current parameter values from step 2
4. `AppController.refreshOrOpenExperiment(expFile)` — reload UI from updated disk

**IMPORTANT:** Never use hardcoded parameter values from earlier in the conversation when
applying modifications after a save. The user's UI changes must be preserved. Always read
the current state from the .mat file after saving.

**Save from backend available in:** R2026b, R2026a Update 6, R2025b Update 7

---

## Step 3: Pre-check — Internal Validation

Check the experiment's internal consistency using MATLAB's built-in validation.

```matlab
clear classes
result = manageExperimentHelpers.validate('<expFile>'); disp(result);
```

**Do NOT skip this step.** Run it before any modification and after any modification.

If errors are found:
- Surface them to the user in plain language
- Suggest a fix immediately
- Fix the issue before proceeding to confirmation

**Also validate:**
- Field names (exact case-sensitive match against HyperTable)
- Parameter values (valid MATLAB expressions)
- Function existence on path
- Supporting file existence on disk

---

## Step 4: Confirm

Only for high-stakes actions. If user says no → suggest next steps.

| Operation | Confirm? | How |
|-----------|----------|-----|
| Create | Yes | Present summary of defaults and choices |
| Update | Yes | Show before → after values (e.g., "Alpha: [1,2,3] → [1,5,7]") |
| Delete | Yes | Stronger warning, name consequences explicitly. Never batch with other ops |
| Load Project | No | Just opening |
| Rename | No | Trivial, reversible |
| Duplicate | No | Additive, doesn't destroy anything |

**Standard modification (Create, Update):**
- Present summary of all changes for create
- Show before → after values for update — this applies to ALL updates without exception,
  including single value changes (e.g., "k Lower: 0 → 0.5"), strategy switches, distribution
  changes, nTrials changes, etc. No update is too small to skip confirmation.
- Wait for explicit "yes" / "proceed"

**Destructive action (Delete):**
- Delete removes experiment + all results
- Stronger warning language
- Name the consequences explicitly
- Never batch destructive with other ops

---

## Step 5: Execute & Sync

Perform the action and keep UI in sync:

1. Modify .mat file on disk
2. `refreshOrOpenExperiment` — reload experiment tab
3. `syncTree` — update browser tree
4. Report result to user

---

## EM State Model

- Projects can be opened and closed.
- Active tab corresponds to an open experiment.
- Opened project = project to use in case of doubt.
- Opened experiment = current experiment.
- When syncing, always update both tab and browser tree.
- An experiment tab can be dirty (unsaved UI changes) — check before modifying.
- Multiple experiments can be open as tabs simultaneously, but only one is active.
- A result tab can also be active — in that case there is no active experiment.
- `getActiveTab` returns the currently focused experiment (name, ID, path) or `status: 'none'`.

---

## Operation: Query Experiment State

**IMPORTANT:** Before reading ANY property from an experiment (strategy, parameters, values,
description, etc.) — even just to answer a user's question — you MUST:

1. Call `getActiveTab()` to determine which experiment is active NOW (not cached from earlier)
2. Check dirty state via `refreshOrOpenExperiment`. If dirty, follow dirty state handling.
3. Only THEN read the .mat file.

Never skip these steps. The user can switch tabs or make UI changes at any time between
your operations.

---

## API Reference

### AppController Methods

All frontend sync methods are on `experiments.internal.AppController`. Internally,
`AppController` dispatches these calls to the JS frontend through
`experiments.internal.AgentFrontendBridge`; you never call the bridge directly. They return
`status: 'timeout'` if no JS listener responds within the timeout period.

| Method | Purpose |
|--------|---------|
| `syncTree()` | Update browser tree |
| `refreshOrOpenExperiment(matFilePath)` | Reload/open experiment tab |
| `getActiveTab()` | Query active experiment tab |
| `renameExperiment(matFilePath, newName)` | Rename experiment |
| `deleteExperiment(matFilePath)` | Delete experiment + results |
| `expandParameter(matFilePath, paramName)` | Expand parameter row (RandomSampling) |
| `saveExperiment(matFilePath)` | Save unsaved UI changes to disk |

### Query Active Tab

```matlab
clear classes
result = experiments.internal.AppController.getActiveTab();
disp(result);
```

Returns `status: 'ok'` with `expId`, `name`, `path` — or `status: 'none'`.

Use this before any modification when user doesn't name a specific experiment. The active
tab IS the default target.

### Expand Parameter (RandomSampling)

After modifying a distribution, expand its row for visual feedback:
```matlab
clear classes
expFile = fullfile('<projectPath>', '<experimentName>.mat');
result = experiments.internal.AppController.expandParameter(expFile, '<paramName>');
disp(result);
```

---

## Pre-Operation Validation Rules

Before any operation, validate inputs:

- **Before renaming:** Check target name doesn't already exist as .mat file.
- **Before deleting:** Check file exists. If not, list available experiments.
- **Before creating/cloning:** Check name doesn't conflict. If exists, ask about suffix.
- **Before adding supporting file:** Check file exists on disk.
- **Before modifying a parameter:** Exact case-sensitive match against HyperTable. If no
  match, list available parameters and ask. If the user's input matches multiple parameters
  (e.g., case-insensitive duplicates like `learningRate` and `LearningRATE`), always
  disambiguate — list the candidates with their current values and ask which one to modify.
- **Before adding a parameter:** Check for duplicates. If a duplicate exists, warn the user that the experiment won't be runnable and confirm they still want to proceed.

---

## Constraints

1. Always create new files — never overwrite existing ones (append numeric suffix).
2. Write function files inside MATLAB — use `writelines` directly into project folder.
3. Warn about trial count — if > 50, suggest reducing or Bayesian optimization.
4. Preserve user logic — adapt code into experiment function; don't rewrite their algorithm.
5. No plots in experiment functions — use `'Plots', 'none'`.
6. Use params struct — all tunable values from `params`, not hardcoded.
7. Project-based — experiments must live in a MATLAB project.
8. Unique names — generate descriptive, unique names for functions and experiment files.
9. Use absolute paths — resolve all relative paths at generation time.

---

## Limitations (NOT YET IMPLEMENTED)

- **Get list of open experiments** — cannot query which experiments are open as tabs
- **Clone experiment via UI** — use the manual copy approach (load, new UUID, save, addFile)

---

## Common DL Hyperparameters Reference

| Category | Parameters |
|----------|-----------|
| Optimizer | InitialLearnRate, Momentum, GradientDecayFactor |
| Schedule | LearnRateSchedule, LearnRateDropPeriod, LearnRateDropFactor |
| Training | MaxEpochs, MiniBatchSize, Shuffle, ValidationFrequency |
| Regularization | L2Regularization, DropoutProbability |
| Architecture | NumLayers, NumHiddenUnits, FilterSize, NumFilters |

---

## Notes

- Run `clear classes` before retrying if you get "Invalid or deleted object" errors.
- The `'project'` parameter in View constructor ensures both MATLAB project and EM frontend
  are initialized correctly.
- Valid `ExperimentType` API values: `'ParamSweep'` (Exhaustive Sweep), `'RandomSampling'`, and `'BayesOpt'` (training only).
- `deleteExperiment` handles full cleanup including results.

----

Copyright 2026 The MathWorks, Inc.

----
