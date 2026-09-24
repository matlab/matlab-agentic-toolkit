# Operation: Update Experiment

> Shared rules, setup, the Modification Flow, validation, and API are in
> [common.md](common.md). Read it first.

Modify an experiment's parameters, strategy, functions, metrics, or supporting files, and
keep the UI in sync.

> **Reply wording (do this every time).** `HyperTable` below is an internal field name used
> only in the code you run — it must NEVER appear in your reply to the user. When you talk to
> the user, call it **"the parameter values"** or **"the parameter table"**. Say "I'll read the
> current parameter values", not "I'll read the HyperTable". This applies to all narration,
> before/during/after the update.

## Pre-check (Steps 2-3)

**IMPORTANT:** ALWAYS call `getActiveTab()` FIRST, before any other operation (before
reading .mat state, before refreshing, before modifying). The active tab determines the
target experiment. Do NOT call `refreshOrOpenExperiment` or any other method that could
change focus before querying the active tab.

1. Call `getActiveTab()` to resolve which experiment (active tab if not specified)
2. **Check dirty state BEFORE modifying** — attempt `refreshOrOpenExperiment`. If it returns
   `status: 'error'` with "unsaved changes", follow the dirty state handling procedure
   ([common.md](common.md#step-2-pre-check--name-resolution)) (save UI first, then apply
   modification, then refresh). Do NOT skip this step and modify
   the .mat file directly — even if the update "succeeds", the UI may overwrite your change
   when it saves its stale state later.
3. Run `manageExperimentHelpers.validate(expFile)` — surface and fix issues first
4. Validate field names with exact case-sensitive match

## Confirm (Step 4)

Show before → after: `"Alpha: [1,2,3] → [1,5,7]. Proceed?"`

## Execute (Step 5)

```matlab
clear classes
expFile = '<expFile>';
modifications = struct();
modifications.HyperTable = {
    {'<ParamName1>'; '<new_values>'; 'real'; 'none'};
    {'<ParamName2>'; '<new_values>'; 'real'; 'none'};
};
result = manageExperimentHelpers.update(expFile, modifications);
disp(result);

% Sync
result = experiments.internal.AppController.refreshOrOpenExperiment(expFile);
disp(result);
```

## Keeping the function in sync with parameters

**IMPORTANT:** Every time a parameter is added or removed from the HyperTable (or
RandomSamplingData), you MUST also update the experiment function file to match:
- **Adding a parameter:** Add `params.<newParam>` usage in the function. Choose a sensible
  place to use it (e.g., as an argument to a relevant function call or assignment).
- **Removing a parameter:** Remove all `params.<removedParam>` references from the function.

The function and the parameter list must always be consistent. A parameter in the HyperTable
that is never referenced in the function is useless. A `params.X` reference in the function
without a matching HyperTable entry will error at runtime.

**CRITICAL: Live Script (`.mlx`) functions — never rewrite their content.** Before editing a
function file's *content*, check its extension. A `.mlx` is a binary (OOXML/ZIP) file: reading
it as text yields garbage and writing text back **corrupts it** — the Live Script no longer
opens ("Could not open source package"). `writelines`/`readlines` on a `.mlx` is destructive.
There is no supported in-place code-write API (`matlab.internal.setCode` does not exist).

So when the experiment's function file is a `.mlx`:
- Do **not** edit it with `writelines`. Do **not** attempt a format round-trip.
- You MAY read its current code (non-destructive) to show the user:
  `code = matlab.internal.getCode('<functionFile>.mlx');`
- Make the `.mat`/parameter-table change as normal, then **stop and give the user the exact
  edit to make themselves** in the Live Editor (which `params.X` line to add or remove, and
  where), rather than editing the file. Then refresh the UI.

This applies only to editing function *content*. Renaming a `.mlx` function is safe (the file
is moved as-is, not rewritten) — see [rename.md](rename.md).

**CRITICAL: Shared function check.** Before modifying an experiment function file, check if
any OTHER experiment in the project uses the same function (by scanning all .mat files'
`Process.FunctionSection`). If the function is shared by multiple experiments, do NOT modify
it. Instead, stop and ask the user how to proceed (e.g., create a separate function copy for
this experiment, or skip the function update).

After updating the function file, refresh the UI.

## Modifying parameters (ExhaustiveSweep / HyperTable)

Pass the full updated `HyperTable` cell array in `modifications.HyperTable`.
To add a parameter, append to the array. To remove, omit it.

**Always write 4-column rows** `{Name; Values; Type; Transform}` (Type `'real'`/`'integer'`/
`'categorical'`, Transform `'none'`/`'log'`) — even in Exhaustive Sweep. Experiment Manager
appends a hidden row id at a fixed column position that assumes all four columns exist; a
2-column row makes the UI's strategy switch (Exhaustive ↔ Random Sampling) mis-map ids and
collapse every parameter to a single name.

## Modifying parameters (RandomSampling)

```matlab
clear classes
expFile = '<expFile>';
modifications = struct();
modifications.RandomSamplingData.params(1).Name = '<ParamName1>';
modifications.RandomSamplingData.params(1).Dist = 'Uniform';
modifications.RandomSamplingData.params(1).properties = struct( ...
    'Characteristic', {'Lower'; 'Upper'}, ...
    'value', {'0'; '1'});
modifications.RandomSamplingData.params(2).Name = '<ParamName2>';
modifications.RandomSamplingData.params(2).Dist = 'Uniform';
modifications.RandomSamplingData.params(2).properties = struct( ...
    'Characteristic', {'Lower'; 'Upper'}, ...
    'value', {'1'; '10'});
modifications.RandomSamplingData.nTrials = 25;
result = manageExperimentHelpers.update(expFile, modifications);
disp(result);
```

**CRITICAL — `Characteristic` names must match `makedist`.** The `Characteristic` values are
passed verbatim as the name-value arguments to `makedist(Dist, ...)` when the experiment is
validated or run. They are NOT free-form labels — they must be the exact constructor parameter
names for that distribution, or validation fails with `Invalid parameter name` and the
experiment cannot run. The write itself always succeeds (the helper does not check them), so
**always run `manageExperimentHelpers.validate` after the update** to catch a bad name.

**Never hardcode the parameter names from memory.** Different distributions use different
names (e.g. Normal uses `mu`/`sigma`, NOT `Mean`/`Sigma`). Look up the correct names at
runtime before building the `properties` struct:

```matlab
makedist('<Dist>').ParameterNames   % e.g. makedist('Normal') -> ["mu" "sigma"]
```

Common examples (verify with the line above rather than trusting this table):

| Dist | `Characteristic` names |
|------|------------------------|
| `Uniform` | `Lower`, `Upper` |
| `Normal` | `mu`, `sigma` |
| `Lognormal` | `mu`, `sigma` |
| `Exponential` | `mu` |
| `Poisson` | `lambda` |

**IMPORTANT:** Field name is `nTrials` (NOT `numTrials` or `NumTrials`).

**IMPORTANT:** Every `params` entry MUST include a `Name` field matching the corresponding
HyperTable parameter name. Without `Name`, the parameter appears unnamed in the UI.

**IMPORTANT:** After modifying any RandomSampling parameter distribution, ALWAYS expand the
modified parameter row(s) for visual feedback:
```matlab
result = experiments.internal.AppController.expandParameter(expFile, '<ParamName>');
disp(result);
```
Do this for each parameter whose distribution was changed.

## Switching experiment type

```matlab
clear classes
expFile = '<expFile>';
modifications = struct();
modifications.ExperimentType = 'RandomSampling';
result = manageExperimentHelpers.update(expFile, modifications);
disp(result);
```

**IMPORTANT:** The API value for Exhaustive Sweep is `'ParamSweep'` — do NOT use `'ExhaustiveSweep'` (crashes editor).

Valid API values:
- General purpose: `'ParamSweep'` (Exhaustive Sweep), `'RandomSampling'`
- Training: `'ParamSweep'` (Exhaustive Sweep), `'RandomSampling'`, `'BayesOpt'`

**IMPORTANT:** Before switching experiment type, check if the target type is valid for the
experiment's template type. If the user requests BayesOpt on a general purpose experiment,
do NOT apply the change. Instead, refuse and explain that BayesOpt is only available for
training experiments, then ask if they'd like Exhaustive Sweep or Random Sampling instead.

When switching to `'RandomSampling'`, MUST also include `RandomSamplingData` with `params`
and `nTrials`. When switching to Random Sampling for the first time (no existing
`RandomSamplingData` in the .mat file), use Uniform distribution with Lower=0 and Upper=1
as defaults for all parameters. When switching back to Random Sampling (existing
`RandomSamplingData` is present), preserve the previously configured distributions and values.

When switching to `'BayesOpt'`, MUST include `BayesOptOptions` AND update the
HyperTable to 4-column format.

**IMPORTANT:** BayesOpt requires HyperTable entries with 4 columns: `{Name; Range; Type; Transform}`.
- **Type**: `'real'`, `'integer'`, or `'categorical'`
- **Transform**: `'none'` or `'log'` (use `'log'` for parameters spanning orders of magnitude,
  e.g., learning rates)

If the current HyperTable only has 2 columns (Name, Range), you MUST add Type and Transform
columns when switching to BayesOpt. Otherwise the UI will show empty Types and Transforms.

**Exhaustive Sweep / RandomSampling → BayesOpt:**
```matlab
clear classes
expFile = '<expFile>';
modifications = struct();
modifications.ExperimentType = 'BayesOpt';
modifications.HyperTable = {
    {'<ParamName1>'; '[lower, upper]'; '<type>'; '<transform>'};
    {'<ParamName2>'; '[lower, upper]'; '<type>'; '<transform>'};
};
modifications.BayesOptOptions.MaxExecutionTime = 'Inf';
modifications.BayesOptOptions.MaxTrials = '30';
modifications.BayesOptOptions.XConstraintFcn = '';
modifications.BayesOptOptions.ConditionalVariableFcn = '';
modifications.BayesOptOptions.AcquisitionFunctionName = 'expected-improvement-plus';
result = manageExperimentHelpers.update(expFile, modifications);
disp(result);
```

## Renaming the experiment function

Renaming the function is more than a `.mat` field change: the `.m` file on disk and its
`function` signature must also be renamed. The `renameFunction` helper does all of it —
renames the file, rewrites the signature, sets `Process.FunctionSection`, and re-adds the
file to the project.

```matlab
clear classes
result = manageExperimentHelpers.renameFunction('<expFile>', '<oldName>', '<newName>'); disp(result);
result = experiments.internal.AppController.refreshOrOpenExperiment('<expFile>'); disp(result);
```

**IMPORTANT:** Do NOT try to rename the function through `manageExperimentHelpers.update` —
it only edits fields inside the `.mat` file and cannot touch the `.m` file. Use
`renameFunction`.

## Adding post-training custom metrics (training experiments only)

Post-training custom metrics are function files that compute a scalar value after training
completes. They receive `trialInfo` with fields: `trainedNetwork`, `trainingInfo`, `parameters`.

Steps:
1. Write the metric function file to the project folder
2. Add it to the MATLAB project
3. Set `Process.Metrics` directly in the .mat file (the helper doesn't support this field)

```matlab
clear classes
projectPath = '<projectPath>';
expFile = '<expFile>';

% 1. Write metric function
metricCode = {
'function metricOutput = <metricName>(trialInfo)'
'% Post-training custom metric'
'metricOutput = 0;'
'end'
};
writelines(strjoin(metricCode, newline), fullfile(projectPath, '<metricName>.m'));
prj = currentProject;
addFile(prj, fullfile(projectPath, '<metricName>.m'));

% 2. Set in .mat file (MUST use nested cell array format)
s = load(expFile);
s.Experiment.Process.Metrics = {{'<metricName>'}};
save(expFile, '-struct', 's');

% 3. Refresh UI
result = experiments.internal.AppController.refreshOrOpenExperiment(expFile);
disp(result);
```

**IMPORTANT:** `Process.Metrics` must be a nested cell array: `{{'metric1'}; {'metric2'}}`.
Using `{'metric1'}` (flat cell) will display only the first character. This is because the
UI iterates the outer cell and expects each element to be a cell containing the function name.

## Adding an initialization function to an existing experiment

```matlab
clear classes
expFile = '<expFile>';
initCode = {
'function output = <initFunctionName>()'
'% Initialization function for <ExperimentName> experiment'
'output = struct();'
'end'
};
result = manageExperimentHelpers.addInitializationFunction(expFile, '<initFunctionName>', initCode); disp(result);

% Refresh UI
result = experiments.internal.AppController.refreshOrOpenExperiment(expFile);
disp(result);
```

**IMPORTANT:** The correct field is `Process.InitializationFunctionValue`. Do NOT use
`Process.InitializationSection` — that field is not consumed by the frontend or backend.

**IMPORTANT:** When adding an initialization function, you MUST also update the experiment
function, setup function, or training function to access the init output via
`params.InitializationFunctionOutput`. This applies to ALL experiment types:

General purpose (experiment function):
```matlab
function output = myExperiment(params)
data = params.InitializationFunctionOutput;
output.result = data.someField * params.k;
end
```

Built-in training (setup function):
```matlab
function [imdsTrain,layers,lossFcn,options] = mySetup(params)
data = params.InitializationFunctionOutput;
imdsTrain = data.imdsTrain;
...
end
```

Custom training (training function):
```matlab
function output = myTraining(params, monitor)
data = params.InitializationFunctionOutput;
trainingData = data.trainingData;
...
end
```

Without this, the init function runs but its output is never used.

**`.mlx` functions:** if the experiment function to be wired up is a Live Script (`.mlx`), do
NOT rewrite it (see the Live Script warning under "Keeping the function in sync with
parameters" — a text write corrupts it). Add the init function and set
`Process.InitializationFunctionValue` as usual, then tell the user the exact
`params.InitializationFunctionOutput` line to add in the Live Editor themselves.

## Adding/removing supporting files

```matlab
clear classes
expFile = '<expFile>';
% Verify file exists FIRST: isfile(fullfile('<projectPath>', '<fileName>.m'))
modifications = struct();
modifications.SupportingFiles = struct('filePath', '<fileName>.m', 'isRelativePath', true);
result = manageExperimentHelpers.update(expFile, modifications);
disp(result);
```

----

Copyright 2026 The MathWorks, Inc.

----
