# Runtime File Reference Detection

`requiredFilesAndProducts` only traces code dependencies (.m, .mlx, MEX, p-code). It never returns data files, images, config files, or other non-code assets. A separate static scan is needed to detect runtime file references that must ship with the toolbox.

## Functions to Scan

Only scan for **input** (read) functions — output functions (save, writetable, imwrite) are not dependencies.

| Priority | Functions | Typical file types |
|----------|-----------|-------------------|
| High | `load`, `readtable`, `readmatrix`, `readcell`, `readtimetable`, `importdata` | .mat, .csv, .xlsx, .txt, .parquet |
| Medium | `imread`, `fileread`, `readlines`, `xmlread`, `audioread`, `VideoReader` | .png, .jpg, .json, .xml, .wav, .mp4 |
| Low | `dlmread`, `csvread` (legacy), `run`, `load_system` | tabular data, .m scripts, .slx |

## Detection Patterns

### 1. Function call with string literal (most common)

```matlab
pattern = '(load|readtable|readmatrix|readcell|readtimetable|importdata|fileread|readlines|xmlread|imread|audioread|VideoReader|run|load_system)\s*\(\s*[''"]([^''"]+)[''"]\s*[,\)]';
tokens = regexp(content, pattern, 'tokens');
```

### 2. Command syntax (load only)

```matlab
commandPattern = '(?<=^|\s)load\s+([^\s;%(]+)';
tokens = regexp(content, commandPattern, 'tokens');
```

Note: `load data.mat` is equivalent to `load('data.mat')`. Only `load` commonly uses command syntax for file paths.

### 3. fullfile with all-literal arguments

```matlab
fullfilePattern = 'fullfile\s*\(\s*([''"][^''"]+[''"](?:\s*,\s*[''"][^''"]+[''"])*)\s*\)';
tokens = regexp(content, fullfilePattern, 'tokens');
% Reconstruct path from quoted components
parts = regexp(tokens{1}{1}, '[''"]([^''"]+)[''"]', 'tokens');
resolvedPath = strjoin(cellfun(@(x) x{1}, parts, 'UniformOutput', false), filesep);
```

## Classification

For each detected file path, classify:

| Path type | Condition | Action |
|-----------|-----------|--------|
| Absolute external | Starts with drive letter (`C:\`), UNC (`\\`), or Unix root (`/`) | CRITICAL — will never resolve on end-user machine |
| Relative, in effective set | `fullfile(toolboxRoot, path)` exists and is in `effectiveFiles` | OK — ships with toolbox |
| Relative, excluded | File exists in toolbox root but not in `effectiveFiles` | CONFLICT — ignore file is blocking a needed file |
| Relative, not found | File does not exist on disk | SKIP — likely generated at runtime or user-supplied |

## Design Rules

- Only flag paths to files that **exist** but won't ship. Don't flag references to non-existent files (e.g., output paths, user-supplied at runtime).
- Exception: absolute paths to existing external files are always flagged — hardcoded paths will break on any other machine.
- Resolve relative paths from the directory of the `.m` file containing the reference.
- Group multiple references to same directory (same as external-code grouping logic).

----

Copyright 2026 The MathWorks, Inc.
