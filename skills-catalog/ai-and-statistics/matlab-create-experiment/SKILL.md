---
name: matlab-create-experiment
description: >
  Create an experiment for the MATLAB Experiment Manager app from user code, script, or problem description.
  TRIGGER when: user asks to create an experiment from a script/function, wants to sweep parameters
  or hyperparameters, asks to compare configurations, or describes a problem suitable for experimentation.
  DO NOT TRIGGER when: user is debugging an existing experiment, wants to run/resume trials,
  or already has a working experiment set up.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Create Experiment for Experiment Manager

Plans and creates experiments in MATLAB Experiment Manager by analyzing user code or problem
descriptions, determining the experiment type, and generating the appropriate experiment
function, hyperparameter table, and experiment object.

## When to Use
- User has a MATLAB script/function and wants to sweep parameters or hyperparameters
- User asks to create an experiment or compare configurations
- User describes a problem and wants to explore parameter space
- User wants to track outputs across different parameter combinations

## When NOT to Use
- User is debugging an existing experiment or training failure
- User wants to run, resume, or view results of an existing experiment
- User already has a working Experiment Manager experiment set up
- User wants to edit experiment settings (hyperparameters, strategy, description) — direct them to make changes in the Experiment Manager app. However, editing the experiment function code (.m file) is allowed.
- User wants Bayesian optimization or random sampling strategy — direct them to configure from the Experiment Manager app

---

## Autonomy Model

This skill follows a guidance + autonomy pattern. Decision points are tagged:

| Tag | Meaning |
|-----|---------|
| `[user]` | Always pause and ask. Non-negotiable. |
| `[auto]` | Agent decides silently. Escalates on failure. |
| `[depends]` | Resolved by clarity of signals — auto if clear, ask if ambiguous. |

After analysis, tell the user how you intend to work in one plain sentence.
Always add: "Let me know if you'd prefer more or less control."

---

## Phase 1: Analysis

Read the user's code or problem description and classify the experiment type.

### Type Classification

Classify into one of three types using API-level and semantic signals.

**IMPORTANT:** If semantic signals indicate training (even without explicit DL API calls),
classify as training — NOT general purpose.

| Type | Signals | Template class |
|------|---------|----------------|
| General purpose | No DL functions, no training indicators. Optimization, simulation, data analysis. | `'experiments.internal.experimentTemplates.MATLABFunction'` |
| Built-in training | Uses `trainnet`/`trainNetwork`/`trainingOptions`, standard layers, datastores. OR: file name contains "train", user mentions "classification"/"transfer learning". | `'experiments.internal.experimentTemplates.BlankTrainnetTraining'` |
| Custom training (custom loop) | Uses `dlnetwork`/`dlfeval`/`dlgradient`/`dlarray`, manual gradients, GANs. OR: training loop with loss computation, user mentions "fine-tune"/"detector". | `'experiments.internal.experimentTemplates.CustomTraining'` |

### Classification Priority
1. Training loop structure (epoch iteration, loss tracking) → Custom training
2. Sets up data/layers/options without looping → Built-in training
3. Neither semantic nor API signals indicate training → General purpose

### Discovery Variables

| Variable | Tag | Notes |
|----------|-----|-------|
| Experiment type | `[depends]` | Auto if signals are clear; ask if ambiguous |
| Parameters to sweep | `[depends]` | Auto-infer from hardcoded values; ask if unclear |
| Parameter values | `[auto]` | Suggest 2-3 alternatives around hardcoded values |
| Init function needed | `[auto]` | Yes if expensive ops independent of params detected |
| Function signature | `[auto]` | Determined by type (see REFERENCES.md) |

Exit criteria: type classified, parameters identified, outputs known.

---

## Phase 2: Design

Generate the experiment function and prepare the full design for user review.

1. **Description** — Create a 2-4 line description covering: what the experiment does,
   parameters being swept, outputs captured per trial, and evaluation criterion.

2. **Parameters** — Build the parameter table (Name | Values | Description).
   - Hardcoded value → suggest 2-3 alternatives around it
   - Categorical → list reasonable alternatives
   - `[auto]` Warn if total trials > 50 (suggest reducing values)

3. **Function signature** — Select based on type:

   | Type | Signature |
   |------|-----------|
   | General purpose | `[out1, out2, ...] = func(params)` |
   | Built-in (Form A, targets in datastore) | `[trainingData, net, lossFcn, options] = func(params)` |
   | Built-in (Form B, targets separate) | `[trainingData, targets, net, lossFcn, options] = func(params)` |
   | Custom training | `output = func(params, monitor)` |

   Last 3 outputs for built-in must always be `net`, `lossFcn`, `options`.
   See references/REFERENCES.md for Form A vs B selection guide and supported loss functions.

4. **Generate experiment function** — Adapt user's code into the experiment function.

   **Heading convention when presenting:**
   - General purpose → "Generated Experiment Function"
   - Built-in training → "Generated Setup Function"
   - Custom training loop → "Generated Training Function"

   **Key rules:**
   - Use `params.<field>` for all tunable values (never hardcode swept values)
   - Each `params.<field>` is a single scalar value (numeric, string, or logical) — Experiment Manager assigns one value per trial. Never loop over parameter values inside the function; the sweep is handled externally.
   - Use `'Plots', 'none'` in trainingOptions
   - Include H1 help comment block
   - Use absolute paths for all file/data references — see REFERENCES.md § "Absolute Path Rules"
   - For custom training monitor pattern — see REFERENCES.md § "Custom Training Monitor Pattern"

   | Type | Body contains | Returns |
   |------|--------------|---------|
   | General purpose | User's computation logic, including figure/plot code | Named outputs (any serializable type) |
   | Built-in training | Data loading, network definition, trainingOptions | [data..., net, lossFcn, options] |
   | Custom training | Training loop with monitor integration, including figure/plot code | output (any serializable type) |

5. **`[auto]` Initialization function** — If expensive one-time operations independent of
   hyperparameters are detected (data downloads, large file loads, datastores not depending
   on `params`), extract into an initialization function.
   See references/REFERENCES.md § "Initialization Function Template" for the code template.

---

## Phase 3: Confirmation

### Gate: `[user]` — Present design for review before execution.

**MANDATORY:** Always present the design and wait for explicit user confirmation before creating any files or running any MATLAB code. Never skip this gate, even if the user has confirmed similar experiments before. The only exception is if the user explicitly says to skip confirmation (e.g., "just create it without asking").

**Presentation order matters:**
1. Generated experiment function code
2. Generated initialization function code (if applicable)
3. Summary table
4. Ask for confirmation

Do NOT show the summary table before the function code.

**Summary table:**

| Topic | Details |
|-------|---------|
| Experiment type | <type chosen and why> |
| Parameters/Hyperparameters | <comma-separated list> |
| Total trials | <number> |
| Function name | `<functionName>` |
| Initialization function | `<initFunctionName>` if generated, otherwise reason why not |
| Key metric | <metric name> (<minimize/maximize>) |
| Logged live metrics | <comma-separated list> |

Proceed to Phase 4 only after user confirms.

---

## Phase 4: Creation & Validation

Execute the experiment setup in MATLAB.

### 4a: Project Setup `[auto]`

1. Check `currentProject` — if open, use it; otherwise create a new project
2. **Never close or replace an open project.** If `currentProject` succeeds, always use that project — write the experiment function and .mat file into its root folder. Only call `matlab.project.createProject` when no project is open.
3. `matlab.project.createProject` changes `pwd` — use `pwd` directly after, don't prepend folder
4. Write function file into project root using `writelines` AFTER project exists
5. Generate unique folder names (append `_2`, `_3`) when creating new projects

See references/REFERENCES.md § "Step 6 Code Template" for the full code.

### 4b: Create Experiment Object `[auto]`

Use the `createExperiment` helper (in `scripts/`). It handles:
- Building the hyperparameter table from a params struct
- Generating unique .mat file names (never overwrites)
- Setting experiment name from file name
- Adding to project

### 4c: Validate `[auto]`

Before running validation, briefly tell the user what it checks: "I'm validating that the function exists on path, passes static analysis, has the correct signature, and that its parameter references match the hyperparameter table."

**Path portability check:** Before validation, scan for relative file paths in the
generated function. If found, resolve to absolute and rewrite.

Run tiered validation (see REFERENCES.md § "Validation"):

1. **Tier 0 — Existence:** Confirm function is on path via `which()`
2. **Tier 1 — Static analysis:** Run `checkcode()`. Block on severity > 1 (errors). Warn on severity ≤ 1.
3. **Tier 2a — Signature:** Verify `nargin` and `nargout` match the experiment type:
   - `general`: nargin=1, nargout≥1
   - `builtin_A`: nargin=1, nargout=4
   - `builtin_B`: nargin=1, nargout=5
   - `custom`: nargin=2, nargout=1
4. **Tier 2b — Parameter coverage:** Parse function source for `params.<field>` references.
   Fail if function references params not in the hyperparameter table. Warn if table entries are unused.

### Gate: `[auto]` — Validation result
- All tiers pass → open Experiment Manager (see REFERENCES.md § "Open Experiment Manager")
- Blocking failure → fix, rewrite `.m` and `.mat`, re-validate (max 2 attempts)
- Fail after 2 attempts → `[user]` escalate with error details

---

## Phase 5: Handoff

After the experiment is created and Experiment Manager is open:

> Your experiment is ready in Experiment Manager! Here are some things you can do before running:

**Suggested authoring actions:**
- Edit hyperparameter values or add new parameters in the Hyperparameter Table
- Modify the experiment description
- Open and adjust the function from the Experiment Manager app:
  - General purpose → "experiment function"
  - Built-in training → "setup function"
  - Custom training loop → "training function"
- Add or configure an initialization function from the app UI

> When you're ready, click **Run** in the Experiment Manager toolbar to start your trials.

---

## Key Rules

1. **Always create new files** — never overwrite existing ones (append numeric suffix).
2. **Write function files inside MATLAB** — use `writelines` directly into project folder.
3. **Preserve user logic** — adapt code into experiment function; don't rewrite their algorithm.
4. **No training-progress plots** — use `'Plots', 'none'` in `trainingOptions` (built-in training only). For general purpose and custom training, preserve the user's figure/plot code.
5. **Use params struct** — all tunable values from `params`, not hardcoded.
6. **Project-based** — experiments must live in a MATLAB project.
7. **Unique names** — generate descriptive, unique names for functions and experiment files. Use suffix `Project` for project names and `Experiment` for experiment names (e.g., `AntennaProject`, `AntennaExperiment`).
8. **Never expose internal APIs** — don't show template class names to the user.
9. **Use absolute paths** — all file references must use `fullfile()` with absolute path components.

See references/REFERENCES.md for template classes, signature mappings, and common hyperparameters.

---

## Error Recovery

| Error | Fix |
|-------|-----|
| Validation fails | Fix function, rewrite .mat, re-validate (max 2 attempts) |
| Relative path found | Resolve to absolute against source script directory, rewrite |
| Project not open & can't create | Ask user for project location |
| >50 trials | Warn, suggest reducing values |
| Ambiguous experiment type | Ask user to clarify |
| File already exists | Append numeric suffix (_2, _3, ...) |
| Path cannot be resolved | Ask user for the full path |

---

Copyright 2026 The MathWorks, Inc.
