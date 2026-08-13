# Example Live Script Conventions

## Location

`toolbox/examples/` (ships to users inside the .mltbx)

## Format

Plain-text MATLAB scripts (`.m`) with `%%` section breaks per design guidelines:
> "Examples are an effective way for users to learn how to use your toolbox."

Generate one example per function or logical group.

## Naming Convention

`<descriptiveAction>.m` (e.g., `usingAdd.m`, `plotTimeSeries.m`)

## Structure Template

```matlab
%% Title: Descriptive Action with Function Name
% Brief description of what this example demonstrates.

%% Setup
% Load any required data or configure parameters.

data = [1 2 3 4 5];

%% Basic Usage
% Show the primary usage pattern.

result = functionName(data);
disp(result)

%% Visualization (if applicable)
% Show output graphically.

figure
plot(result)
title("Result of functionName")
xlabel("Index")
ylabel("Value")

%% Variations
% Show different parameter combinations or options.

result2 = functionName(data, Method="fast");
```

## Key Rules

- Each example MUST run without user interaction or modification
- Use `%%` section breaks for publishable format
- Include at least one usage demonstrating the primary function signature
- Add figures with titles, labels, and legends where appropriate
- Set `rng(seed)` before random number generation for reproducibility
- For GUI functions: demonstrate concepts programmatically, don't launch the GUI
- Keep execution time reasonable (< 30s per example; reduce problem size if needed)
- For functions requiring optional toolboxes: guard with `license('test', 'toolbox_name')`

## File Format

Write examples as plain-text `.m` files with `%%` section breaks. These render as rich documents in the MATLAB Live Editor and are version-control friendly. Do not convert to binary `.mlx`.

## Publishing to HTML (optional)

If the user wants HTML output for static hosting or offline viewing:

```matlab
addpath(toolboxFolder);
addpath(examplesPath);

htmlDir = fullfile(examplesPath, 'html');
mkdir(htmlDir);

opts = struct('format', 'html', 'outputDir', htmlDir, ...
    'showCode', true, 'evalCode', true, 'catchError', true);

exFiles = dir(fullfile(examplesPath, '*_example.m'));
for i = 1:length(exFiles)
    close all
    publish(fullfile(examplesPath, exFiles(i).name), opts);
end
```

Note: The examples folder MUST be on the MATLAB path before calling `publish` with `evalCode=true`.

----

Copyright 2026 The MathWorks, Inc.

----
