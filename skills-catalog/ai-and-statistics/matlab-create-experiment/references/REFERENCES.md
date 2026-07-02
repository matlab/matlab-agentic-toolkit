# Experiment Manager References

## Template Classes

| Experiment Type | Template Class |
|----------------|----------------|
| General purpose | `experiments.internal.experimentTemplates.MATLABFunction` |
| Built-in training (trainnet) | `experiments.internal.experimentTemplates.BlankTrainnetTraining` |
| Custom training loop | `experiments.internal.experimentTemplates.CustomTraining` |

## Function Signatures Summary

| Experiment Type | Signature | Maps to |
|----------------|-----------|---------|
| General purpose | `[out1, out2, ...] = func(params)` | Named return values |
| Built-in training (targets in datastore) | `[trainingData, net, lossFcn, options] = func(params)` | `trainnet(trainingData, net, lossFcn, options)` |
| Built-in training (targets separate) | `[trainingData, targets, net, lossFcn, options] = func(params)` | `trainnet(trainingData, targets, net, lossFcn, options)` |
| Custom training | `output = func(params, monitor)` | Struct with fields |

**Rule:** Last 3 outputs for built-in must always be `net`, `lossFcn`, `options` in that order.
Experiment Manager uses `nargout` to determine how many data arguments to pass to `trainnet`.

## Common DL Hyperparameters

| Category | Parameters |
|----------|-----------|
| Optimizer | InitialLearnRate, Momentum, GradientDecayFactor |
| Schedule | LearnRateSchedule, LearnRateDropPeriod, LearnRateDropFactor |
| Training | MaxEpochs, MiniBatchSize, Shuffle, ValidationFrequency |
| Regularization | L2Regularization, DropoutProbability |
| Architecture | NumLayers, NumHiddenUnits, FilterSize, NumFilters |

## Built-in Training: Form A vs Form B

| Data scenario | Form | Example |
|---|---|---|
| Image classification with folder-organized data | A (4 outputs) | `imageDatastore` with labels |
| Augmented image data | A (4 outputs) | `augmentedImageDatastore` |
| Semantic segmentation with pixel label datastore | A (4 outputs) | `CombinedDatastore` |
| Numeric feature matrix + categorical targets | B (5 outputs) | `XTrain`, `TTrain` |
| Sequence data as cell arrays + labels | B (5 outputs) | `XTrain` (cell), `TTrain` (categorical) |
| Regression with numeric inputs and outputs | B (5 outputs) | `XTrain`, `TTrain` (numeric) |

## Built-in Training: Supported Loss Functions

`"crossentropy"`, `"index-crossentropy"`, `"binary-crossentropy"`, `"mse"`,
`"mean-squared-error"`, `"mae"`, `"mean-absolute-error"`, `"huber"`, `"l2loss"`, `"l1loss"`,
or a function handle with signature `loss = f(Y1,...,Yn,T1,...,Tm)`,
or a `deep.DifferentiableFunction`.

## Absolute Path Rules

When the user's code references data files, MAT-files, images, or any external resource,
resolve the path to its absolute form at generation time and embed it directly.

**Pattern:**
```matlab
% Original user code:        data = load('data/training.mat');
% Script located at:         /projects/antenna/scripts/optimizeAntenna.m
% Resolved in generated code (each folder as a separate fullfile argument):
data = load(fullfile('/', 'projects', 'antenna', 'scripts', 'data', 'training.mat'));
```

**Rules:**
- At generation time, resolve all relative paths against the source script's directory
- Use `fullfile()` with each path component as a separate comma-separated argument
  (e.g., `fullfile('/', 'users', 'data', 'file.mat')` not `fullfile('/users/data', 'file.mat')`)
  so MATLAB constructs the correct separator for the current platform
- Never embed pre-joined path strings with `/` or `\` inside `fullfile()`
- Never leave relative paths like `'./data'` or `'../models'` in generated code
- Never assume `pwd` will match any particular directory at runtime
- If a path cannot be resolved (file doesn't exist), ask the user for the full path

## Custom Training Monitor Pattern

```matlab
monitor.Metrics = ["TrainingLoss", "ValidationAccuracy"];
monitor.Info = ["Epoch", "LearningRate"];
for epoch = 1:numEpochs
    if monitor.Stop, break; end
    % ... training logic ...
    recordMetrics(monitor, iteration, TrainingLoss=double(loss));
    monitor.Progress = 100 * epoch / numEpochs;
    updateInfo(monitor, Epoch=epoch);
end
```

## Initialization Function Template

```matlab
function output = <experimentName>_init()
%<EXPERIMENTNAME>_INIT Load shared data for all trials.
%   OUTPUT = <EXPERIMENTNAME>_INIT() runs once before trials begin.
%   Access in experiment function via params.InitializationFunctionOutput.

    % [Extracted data loading / preprocessing code]
    output.trainingData = ...;
    output.validationData = ...;
end
```

Then modify the experiment function to replace inline data loading with:
```matlab
data = params.InitializationFunctionOutput;
```

**Signature:** `function output = initFcnName()` — 0 inputs, 1 output.
Output can be any serializable type (struct, array, datastore, table, etc.).

## createExperiment Function Reference

```matlab
expFilePath = createExperiment(name, templateClass, functionName, Name=Value)
```

**Positional arguments:**

| Argument | Type | Description |
|----------|------|-------------|
| `name` | string | Experiment name (must be non-empty) |
| `templateClass` | string | One of the template class strings (see Template Classes table) |
| `functionName` | string | Name of the experiment function (without `.m`) |

**Name-Value arguments:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `Parameters` | struct | `struct()` | Each field is a parameter name; value is an array of values to sweep (required, must have at least one field) |
| `Description` | string | `""` | Experiment description |
| `ExperimentType` | string | `"ParamSweep"` | Type of sweep |
| `InitFunction` | string | `""` | Name of initialization function (omit or "" to skip) |
| `OutputDir` | string | `pwd` | Directory to write the .mat file (must exist) |
| `AddToProject` | logical | `true` | Add .mat file to current MATLAB project |

**Returns:** `expFilePath` — full path to the created `.mat` experiment file.

**Parameter values format:**
- Numeric: row vector, e.g., `[0.001, 0.01, 0.1]`
- String: string array, e.g., `["adam", "sgdm"]`
- Logical: logical array, e.g., `[true, false]`

**Behavior:**
- Generates a unique file name (appends `_2`, `_3`, ...) if the file already exists
- Builds the hyperparameter table from the `Parameters` struct automatically
- Sets the experiment name from the file name

## Open Experiment Manager

```matlab
emView = experiments.internal.View.feature.instance;
if isempty(emView) || ~isvalid(emView.cef)
    experiments.internal.View('project', pwd);
end
```

## Step 6 Code Template

```matlab
% --- Check for currently open project ---
try
    prj = currentProject;
    projectFolder = prj.RootFolder;
    fprintf('Using existing project: %s (%s)\n', prj.Name, projectFolder);
catch
    % --- No project open — create a new one ---
    baseDir = '<working_directory>';
    projectPath = fullfile(baseDir, '<Name>Project');
    suffix = 1;
    while isfolder(projectPath)
        suffix = suffix + 1;
        projectPath = fullfile(baseDir, sprintf('<Name>Project_%d', suffix));
    end
    matlab.project.createProject('Folder', projectPath, 'Name', '<Name>Project');
    prj = currentProject;
    projectFolder = prj.RootFolder;
end

% --- Ensure Results folder exists ---
if ~isfolder(fullfile(projectFolder, 'Results'))
    mkdir(fullfile(projectFolder, 'Results'));
end

% --- Write experiment function into project folder ---
functionCode = { ...
    'function output = <functionName>(params, monitor)'; ...
    % ... (full function content as cell array of strings) ...
    'end'};
writelines(functionCode, fullfile(projectFolder, '<functionFileName>.m'));
addFile(prj, fullfile(projectFolder, '<functionFileName>.m'));

% --- Write initialization function (if opted in) ---
% initCode = { ...
%     'function output = <experimentName>_init()'; ...
%     % ... (init function content) ...
%     'end'};
% writelines(initCode, fullfile(projectFolder, '<initFunctionName>.m'));
% addFile(prj, fullfile(projectFolder, '<initFunctionName>.m'));

% --- Create experiment object using helper ---
addpath('<absolute_path_to_skill>/scripts');

params = struct();
params.<ParamName1> = <values_array>;
params.<ParamName2> = <values_array>;

expFilePath = createExperiment('<Name>Experiment', '<templateClass>', '<functionName>', ...
    'Parameters', params, ...
    'Description', '<generated_description>', ...
    'ExperimentType', 'ParamSweep', ...
    'OutputDir', projectFolder, ...
    ... % 'InitFunction', '<initFunctionName>', ...  % include only if init function opted in
    'AddToProject', true);
```

## Documentation Links
- [General purpose experiment (visualize results)](https://www.mathworks.com/help/matlab/data_analysis/visualize-results.html)
- [Initialization functions](https://www.mathworks.com/help/matlab/data_analysis/init-fcn.html)
- [Evaluate with metric functions](https://www.mathworks.com/help/deeplearning/ug/evaluate-experiment-using-metric-functions.html)
- [Custom training with Bayesian optimization](https://www.mathworks.com/help/deeplearning/ug/custom-training-experiment-using-bayesian-optimization.html)

## Validation

### Tier 0 — Function Existence

```matlab
funcName = '<functionName>';
result = which(funcName);
if isempty(result)
    error('Tier 0 FAIL: Function "%s" not found on path.', funcName);
end
fprintf('Tier 0 PASS: %s found at %s\n', funcName, result);
```

### Tier 1 — Static Analysis

```matlab
issues = checkcode(which('<functionName>'));
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

### Tier 2a — Signature Check

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
        fprintf('Tier 2a FAIL: nargout=%d, expected >=1\n', actualNargout);
        passed = false;
    end
else
    if actualNargout ~= expectedNargout
        fprintf('Tier 2a FAIL: nargout=%d, expected %d\n', actualNargout, expectedNargout);
        passed = false;
    end
end
if passed
    fprintf('Tier 2a PASS: nargin=%d, nargout=%d\n', actualNargin, actualNargout);
end
```

### Tier 2b — Parameter Coverage

```matlab
funcName = '<functionName>';
hyperparamNames = {<"param1", "param2", ...>};  % from hyperparameter table

% Parse function source for params.<field> references
srcText = fileread(which(funcName));
tokens = regexp(srcText, 'params\.(\w+)', 'tokens');
usedParams = unique(string(cellfun(@(c) c{1}, tokens, 'UniformOutput', false)));

% Remove InitializationFunctionOutput from check (framework-provided)
usedParams = usedParams(usedParams ~= "InitializationFunctionOutput");

% Check for undefined params (used but not in table)
undefined = setdiff(usedParams, hyperparamNames);
if ~isempty(undefined)
    fprintf('Tier 2b FAIL: Function references undefined params: %s\n', join(undefined, ', '));
end

% Check for unused table entries (in table but not used)
unused = setdiff(string(hyperparamNames), usedParams);
if ~isempty(unused)
    fprintf('Tier 2b WARN: Table entries not referenced in function: %s\n', join(unused, ', '));
end

if isempty(undefined)
    fprintf('Tier 2b PASS: All referenced params exist in hyperparameter table.\n');
end
```

---

Copyright 2026 The MathWorks, Inc.
