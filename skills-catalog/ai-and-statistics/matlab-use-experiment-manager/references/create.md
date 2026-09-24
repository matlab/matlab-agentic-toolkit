# Operation: Create Experiment

> Shared rules, setup, the Modification Flow, validation, and API are in
> [common.md](common.md). Read it first.

Create an experiment from user code or a problem description: generate the function,
create/extend the project, write files, validate, open in Experiment Manager (EM), and sync.

## Interview (Step 1)

Gather: code/description, goal, parameters, metrics. See the Step 1 table in
[common.md](common.md#step-1-interview) for required vs defaults.

## Analyze & Propose

### Determine Experiment Type

Classify into one of three types using API-level and semantic signals.

**IMPORTANT:** If semantic signals indicate training (even without explicit DL API calls),
classify as training — NOT general purpose.

| Type | API Signals | Semantic Signals | templateType value |
|------|-------------|------------------|-------------------|
| General purpose | No DL functions, optimization/simulation/data analysis | Parameters are NOT typical DL hyperparameters | `'general'` |
| Built-in training | `trainnet`/`trainNetwork`/`trainingOptions`, standard layers, datastores | File name contains "train" + model type, references pre-trained networks, user mentions "train a network"/"classification"/"transfer learning" | `'builtin-training'` |
| Custom training | `dlnetwork`/`dlfeval`/`dlgradient`/`dlarray`, manual gradients | Training loop with loss computation, DL hyperparameters (lr, epochs, batch size), user mentions "training"/"detector"/"fine-tune" | `'custom-training'` |

**Classification priority:**
1. Training loop structure (epoch iteration, loss tracking) → Custom training
2. Sets up data/layers/options without looping → Built-in training
3. Neither semantic nor API signals indicate training → General purpose

If ambiguous, ask the user.

**IMPORTANT — Bayesian Optimization requires a training type.** If the user asks for the
Bayesian Optimization strategy, do NOT default to General purpose — it does not support
BayesOpt (only Exhaustive Sweep and Random Sampling). BayesOpt is available only for training
experiments (`builtin-training` or `custom-training`). If the request has no training signals
but the user wants BayesOpt, stop and ask: either classify it as a training experiment, or
pick a strategy General purpose supports (Exhaustive Sweep or Random Sampling).

### Function Signature

| Type | Signature |
|------|-----------|
| General purpose | `[out1, out2, ...] = func(params)` |
| Built-in (Form A, targets in datastore) | `[trainingData, net, lossFcn, options] = func(params)` |
| Built-in (Form B, targets separate) | `[trainingData, targets, net, lossFcn, options] = func(params)` |
| Custom training | `output = func(params, monitor)` |

Last 3 outputs for built-in must always be `net`, `lossFcn`, `options`. Experiment Manager
uses `nargout` to determine how many data arguments to pass to `trainnet`.

**Form A vs Form B selection:**

| Data scenario | Form |
|---|---|
| Image classification with folder-organized data (`imageDatastore` with labels) | A (4 outputs) |
| Augmented image data (`augmentedImageDatastore`) | A (4 outputs) |
| Semantic segmentation with pixel label datastore (`CombinedDatastore`) | A (4 outputs) |
| Numeric feature matrix + categorical targets | B (5 outputs) |
| Sequence data as cell arrays + labels | B (5 outputs) |
| Regression with numeric inputs and outputs | B (5 outputs) |

**Supported loss functions for trainnet:**
`"crossentropy"`, `"index-crossentropy"`, `"binary-crossentropy"`, `"mse"`,
`"mean-squared-error"`, `"mae"`, `"mean-absolute-error"`, `"huber"`, `"l2loss"`, `"l1loss"`,
or a function handle with signature `loss = f(Y1,...,Yn,T1,...,Tm)`,
or a `deep.DifferentiableFunction`.

### Parameters

Build a table: Parameter Name | Values | Description

Rules:
- Hardcoded value → suggest 2-3 alternatives around it
- Categorical → list reasonable alternatives
- Warn if total trials > 50

### Initialization Function (if applicable)

If code has expensive one-time operations independent of hyperparameters (downloads, large
file loads, datastore creation), suggest extracting into init function.

## Generate Description

Create a 2-4 line description covering:
- What the experiment does
- Parameters/hyperparameters being swept
- Outputs captured per trial
- Evaluation criterion

## Confirm Plan (Step 4)

**Do NOT create anything on disk yet.**

**IMPORTANT: Presentation order matters.** Show information in this exact sequence:
1. Generated function code (use heading: "Generated Experiment Function" for general purpose,
   "Generated Setup Function" for built-in training, "Generated Training Function" for custom)
2. Generated initialization function code, if applicable
3. Summary table (below)
4. Ask for confirmation

Do NOT show the summary table before the function code. The user needs to review the
function first, then see the summary as a concise confirmation.

| Topic | Details |
|-------|---------|
| Experiment type | <type chosen and why> |
| Strategy | <Exhaustive Sweep / Random Sampling / Bayesian Optimization> |
| Parameters | <table: name, values, description> |
| Total trials | <number> |
| Function name | `<functionName>` |
| Initialization function | `<initFunctionName>` if generated, otherwise reason why not (e.g., "None — all setup depends on swept parameters") |
| Key metric | <metric name> (<minimize/maximize>) |
| Logged live metrics | <comma-separated list> |

Wait for explicit approval.

## Execute (Step 5)

### Generate Function

**For training experiments (`builtin-training` or `custom-training`):** Invoke the
`ai-and-statistics:matlab-train-network` skill to get guidance on modern training APIs,
network architecture, loss functions, and best practices before generating the setup or
training function code.

**Key rules:**
- Use `params.<field>` for all tunable values
- Use `'Plots', 'none'` in trainingOptions
- Include H1 help comment block
- **Use absolute paths for all file/data references** — resolve at generation time:

  **Pattern:**
  ```matlab
  % Original user code:        data = load('data/training.mat');
  % Script located at:         /projects/antenna/scripts/optimizeAntenna.m
  % Resolved in generated code (each folder as a separate fullfile argument):
  data = load(fullfile('/', 'projects', 'antenna', 'scripts', 'data', 'training.mat'));
  ```

  **Rules:**
  - Use `fullfile()` with each path component as a separate comma-separated argument
  - Never embed pre-joined path strings with `/` or `\` inside `fullfile()`
  - Never leave relative paths like `'./data'` or `'../models'` in generated code
  - Never assume `pwd` will match any particular directory at runtime
  - If a path cannot be resolved (file doesn't exist), ask the user for the full path

**Custom training monitor pattern:**
```matlab
monitor.Metrics = ["TrainingLoss", "ValidationAccuracy"];
monitor.Info = ["Epoch", "LearningRate"];
for epoch = 1:numEpochs
    if monitor.Stop, break; end
    recordMetrics(monitor, iteration, TrainingLoss=double(loss));
    monitor.Progress = 100 * epoch / numEpochs;
    updateInfo(monitor, Epoch=epoch);
end
```

**Initialization function:**
```matlab
function output = <experimentName>_init()
    output.trainingData = ...;
    output.validationData = ...;
end
```

**Accessing init output in the experiment/setup/training function:**

The experiment function receives init output via `params.InitializationFunctionOutput`:
```matlab
function output = myExperiment(params)
data = params.InitializationFunctionOutput;
% use data.trainingData, data.validationData, etc.
end
```

### Create Project and Write Files

**IMPORTANT:** The experiment name must not be empty (after trimming whitespace). Reject an
empty or all-whitespace name and ask the user for a real name before creating anything on disk.

**IMPORTANT:** If the user did not specify whether to create a new project or add to an
existing one, ASK them: "Would you like me to add this experiment to the current project
(`<projectName>`) or create a new project?" Then follow the user's choice.

**Option A — New project** (use `createProject`):

```matlab
clear classes
result = manageExperimentHelpers.createProject('<working_directory>', '<ExperimentName>', functionCode, '<templateType>', '<generated_description>', hyperTable, '<experimentType>', '<functionName>'); disp(result);
```

**Option B — Add to existing project** (use `createExperimentFile`):

```matlab
clear classes
projectPath = '<existingProjectPath>';
prj = currentProject;

% Write function file(s)
writelines(functionCode, fullfile(projectPath, '<functionName>.m'));
addFile(prj, fullfile(projectPath, '<functionName>.m'));

% Write init function if applicable
writelines(initCode, fullfile(projectPath, '<initFunctionName>.m'));
addFile(prj, fullfile(projectPath, '<initFunctionName>.m'));

% Create experiment .mat file
expFile = fullfile(projectPath, '<ExperimentName>.mat');
manageExperimentHelpers.createExperimentFile(expFile, '<templateType>', '<description>', hyperTable, '<experimentType>', '<functionName>', 'InitializationFunction', '<initFunctionName>');
addFile(prj, expFile);
```

Where `functionCode` is a cell array of code lines and `hyperTable` is a cell array of
**4-element** rows `{Name; Values; Type; Transform}`:
`{{'Param1';'[1 2 3]';'real';'none'}; {'Param2';'[4 5]';'real';'none'}}`.

**IMPORTANT — always write 4-column rows, even for Exhaustive Sweep.** Use `'real'` (or
`'integer'`/`'categorical'`) for Type and `'none'` (or `'log'`) for Transform. This is the
same format Experiment Manager itself writes. A 2-column row (`{Name; Values}`) loads and runs,
but the UI tags each row with a hidden id at a fixed column position that assumes all four
columns are present — so switching strategy in the UI (e.g. Exhaustive ↔ Random Sampling) on a
2-column experiment collapses every parameter to a single name. Writing all four columns avoids
this.

With init function for Option A, add: `'InitializationFunction', '<initFunctionName>', 'InitializationCode', initCode`

**`templateType` values:** `'general'`, `'builtin-training'`, `'custom-training'`

### Validate

**Path portability check:** Before validation, scan the generated function for relative file
paths (strings passed to `load`, `readtable`, `imread`, `dir`, `fileread`, `audioread`,
`imageDatastore`, `fullfile` without an absolute root, or similar I/O functions). If found:
- Emit a warning: "Relative path detected (`'<path>'` on line N). Resolving to absolute."
- Resolve against the original source script's directory and rewrite the function file.
- If the resolved path does not exist on disk, ask the user for the correct full path.

Validation has two layers. **Both are hard gates** — a blocking failure at any tier means
fix the function or experiment file, rewrite, and re-validate (max 2 attempts). After 2 failed
attempts, stop and escalate to the user with the reported errors. Each tier prints an explicit
PASS/FAIL line so the specific failure (line number, expected vs actual, offending name) is
surfaced, not just "validation failed."

#### Layer 1 — Function validation (tiered)

Validate the generated function *before* touching the experiment object.

**Tier 0 — Function exists on path** (blocking):

```matlab
funcName = '<functionName>';
loc = which(funcName);
if isempty(loc)
    fprintf('Tier 0 FAIL: Function "%s" not found on path.\n', funcName);
else
    fprintf('Tier 0 PASS: %s found at %s\n', funcName, loc);
end
```

**Tier 1 — Static analysis** (blocking on severity > 1):

```matlab
issues = checkcode(which('<functionName>'), '-severity');
errors = issues([issues.severity] > 1);
warnings = issues([issues.severity] <= 1);
if ~isempty(errors)
    fprintf('Tier 1 FAIL: %d error(s):\n', numel(errors));
    for i = 1:numel(errors)
        fprintf('  Line %d: %s\n', errors(i).line, errors(i).message);
    end
else
    fprintf('Tier 1 PASS: 0 errors, %d warning(s)\n', numel(warnings));
end
```

**Tier 2a — Signature** (blocking): `nargin`/`nargout` must match the experiment type —
`general`: nargin=1, nargout≥1; `builtin_A`: nargin=1, nargout=4; `builtin_B`: nargin=1,
nargout=5; `custom`: nargin=2, nargout=1.

```matlab
funcName = '<functionName>';
expectedNargin = <1 or 2>;   % 1 for general/builtin, 2 for custom
expectedNargout = <N>;        % >=1 for general, 4 for builtin_A, 5 for builtin_B, 1 for custom
actualNargin = nargin(funcName);
actualNargout = nargout(funcName);
passed = true;
if actualNargin ~= expectedNargin
    fprintf('Tier 2a FAIL: nargin=%d, expected %d\n', actualNargin, expectedNargin);
    passed = false;
end
if strcmp('<type>', 'general')
    if actualNargout < 1
        fprintf('Tier 2a FAIL: nargout=%d, expected >=1\n', actualNargout); passed = false;
    end
elseif actualNargout ~= expectedNargout
    fprintf('Tier 2a FAIL: nargout=%d, expected %d\n', actualNargout, expectedNargout); passed = false;
end
if passed, fprintf('Tier 2a PASS: nargin=%d, nargout=%d\n', actualNargin, actualNargout); end
```

**Tier 2b — Parameter coverage**: undefined params (used in code but not in the table) are
**blocking**; unused table entries are a **warning**.

```matlab
funcName = '<functionName>';
hyperparamNames = {<"param1", "param2", ...>};  % from the hyperparameter table
srcText = fileread(which(funcName));
tokens = regexp(srcText, 'params\.(\w+)', 'tokens');
usedParams = unique(string(cellfun(@(c) c{1}, tokens, 'UniformOutput', false)));
usedParams = usedParams(usedParams ~= "InitializationFunctionOutput");
undefined = setdiff(usedParams, hyperparamNames);
unused = setdiff(string(hyperparamNames), usedParams);
if ~isempty(undefined)
    fprintf('Tier 2b FAIL: Function references undefined params: %s\n', join(undefined, ', '));
end
if ~isempty(unused)
    fprintf('Tier 2b WARN: Table entries not referenced in function: %s\n', join(unused, ', '));
end
if isempty(undefined)
    fprintf('Tier 2b PASS: All referenced params exist in the hyperparameter table.\n');
end
```

#### Layer 2 — Experiment-object validation

After the function passes Layer 1, validate the experiment object itself (EM's built-in
internal-consistency check):

```matlab
result = manageExperimentHelpers.validate('<projectPath>/<ExperimentName>.mat'); disp(result);
```

If `result.status` is not `'ok'` (i.e. `result.errors` is non-empty): fix, rewrite, and
re-validate (max 2 attempts).

### Open EM and Sync

```matlab
clear classes
result = manageExperimentHelpers.openEM('<projectPath>'); disp(result);
result = experiments.internal.AppController.syncTree(); disp(result);
result = experiments.internal.AppController.refreshOrOpenExperiment(fullfile('<projectPath>', '<ExperimentName>.mat')); disp(result);
```

### After Creation

Your final reply MUST include, in this order, even if you already showed a plan earlier:
1. The **generated experiment function code** in a code block (the full function, not a
   bullet-point description of what it does).
2. A short summary of the experiment: type, parameters, and strategy.
3. The ready-to-run message below.

Do not report the experiment as created without showing the actual generated code — a
behavior summary alone is not enough.

After the experiment is created and synced, tell the user:

> Your experiment is ready! If Experiment Manager asks whether to open the current project,
> confirm to open it. Then, to run it, click the **Run** button in Experiment Manager.

**DO NOT run experiments.** Running is out of scope. If the user asks to run,
provide the UI instructions from the "When NOT to Use" section in [common.md](common.md#when-not-to-use).
**Never close Experiment Manager to run programmatically.**

----

Copyright 2026 The MathWorks, Inc.

----
