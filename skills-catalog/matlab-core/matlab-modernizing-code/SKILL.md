---
name: matlab-modernizing-code
description: >
  Modernize deprecated MATLAB functions and patterns. Use when
  check_matlab_code or checkcode reports "not recommended" or
  "to be removed" warnings, when migrating legacy code, or when
  replacing deprecated APIs (trainNetwork, csvread, xlsread,
  datenum, eval, subplot, guide, optimset, wavread, svmtrain,
  uicontrol) with current equivalents.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Code Modernization

Replace deprecated MATLAB functions and anti-patterns with modern equivalents. This skill is the resolver — `check_matlab_code` is the detector.

## When to Use

- `check_matlab_code` or `checkcode` returns "not recommended" or "to be removed" warnings
- User asks to modernize, migrate, or update old MATLAB code
- Code uses functions listed in the quick reference table below
- After static analysis reveals deprecated API usage
- Writing new code in a domain that has known deprecated patterns

## When NOT to Use

- Reviewing code quality broadly — use `matlab-reviewing-code` (which may then trigger this skill)
- Debugging runtime errors — use `matlab-debugging`
- Performance profiling — use performance skills (though anti-patterns below overlap)

## Quick Reference: Top Deprecated Functions

| Deprecated | Use instead | Since | Category |
|------------|------------|-------|----------|
| `csvread` / `dlmread` | `readmatrix` | R2019a | File I/O |
| `csvwrite` / `dlmwrite` | `writematrix` | R2019a | File I/O |
| `xlsread` | `readtable`, `readmatrix` | R2019a | File I/O |
| `xlswrite` | `writetable`, `writematrix` | R2019a | File I/O |
| `datenum` / `datestr` | `datetime` | R2014b | Date/Time |
| `subplot` | `tiledlayout` / `nexttile` | R2019b | Graphics |
| `eval` / `evalc` / `evalin` | Dynamic field names, function handles | — | Security |
| `str2num` | `str2double` | — | Security |
| `trainNetwork` | `trainnet` | R2024a | Deep Learning |
| `LayerGraph` / `SeriesNetwork` | `dlnetwork` | R2024a | Deep Learning |
| `classify` (DL) | `minibatchpredict` + `scores2label` | R2024a | Deep Learning |
| `uicontrol` | `uibutton`, `uidropdown`, etc. | R2016a | UI/App |
| `guide` | `appdesigner` | R2025a | UI (Removed) |
| `optimset` | `optimoptions` | R2013a | Optimization |
| `strmatch` | `startsWith`, `matches` | R2019b | Strings |
| `clear all` | `clearvars` | — | Performance |

## Critical Anti-Patterns

Never use these in new code:

| Anti-pattern | Problem | Use instead |
|-------------|---------|-------------|
| `eval` / `evalc` / `evalin` | Security risk, prevents JIT optimization, difficult to debug | Dynamic field names `s.(name)`, function handles |
| `str2num` | Uses `eval` internally — code injection risk | `str2double` |
| Growing arrays in loops | O(n²) memory reallocation | Preallocate with `zeros`, `cell` |
| `global` variables | Hidden state, performance penalty | Pass as arguments or use structs |
| `clear all` | Removes functions from memory, forces recompilation | `clearvars` |
| `cd` during execution | Forces function re-resolution | `fullfile` for paths |
| `exist('var','var')` in loops | Expensive state query | Initialize variable before loop |
| Large data in code | Slow parsing, hard to maintain | Save to `.mat` or `.csv` files |

## Modern Design Patterns

Prefer these in all new code:

### Table-Based Workflows
```matlab
data = readtable('sensors.csv');
data.Timestamp = datetime(data.Timestamp);
data.Status = categorical(data.Status);
recentData = data(data.Timestamp > datetime('today') - days(7), :);
summary = groupsummary(recentData, 'SensorID', 'mean', 'Value');
```

### String Arrays (not char arrays)
```matlab
name = "John";                        % not 'John'
names = ["John", "Jane", "Bob"];      % not {'John','Jane','Bob'}
fullName = firstName + " " + lastName; % not [first,' ',last]
idx = contains(names, "Jo");          % not cellfun + strfind
```

### Arguments Block (not nargin/varargin)
```matlab
function result = processData(data, options)
    arguments
        data (:,:) double
        options.Method (1,1) string {mustBeMember(options.Method, ["fast","accurate"])} = "fast"
        options.Verbose (1,1) logical = false
    end
end
```

### Vectorization (not loops)
```matlab
% Instead of: for i=1:n, V(i) = pi/12*(D(i)^2)*H(i); end
V = pi/12 * (D.^2) .* H;

% Instead of: loop with if
Vgood = V(D >= 0);   % logical indexing
```

### Preallocation
```matlab
result = zeros(1, n);     % numeric
C = cell(1, n);           % cell array
S(n) = struct('f1', []);  % struct array
```

## Key Migrations

### File I/O: csvread/xlsread → readmatrix/readtable

```matlab
% Old                          → Modern
M = csvread('data.csv');       % M = readmatrix('data.csv');
M = dlmread('data.txt','\t'); % M = readmatrix('data.txt','Delimiter','\t');
[n,t,r] = xlsread('f.xlsx');  % T = readtable('f.xlsx');
csvwrite('out.csv', M);       % writematrix(M, 'out.csv');
xlswrite('out.xlsx', data);   % writetable(T, 'out.xlsx');
```

### Deep Learning: trainNetwork → trainnet

```matlab
% Old: classificationLayer specifies loss implicitly
net = trainNetwork(X, Y, layers, options);

% Modern: specify loss explicitly, no classificationLayer needed
net = trainnet(X, Y, layers, "crossentropy", options);

% Prediction
scores = minibatchpredict(net, XTest);
YPred = scores2label(scores, classNames);
```

### eval → Dynamic Field Names / Function Handles

```matlab
% Old: eval([varName ' = 42;']);
s.(varName) = 42;

% Old: result = eval(['process_' method '(x)']);
handlers.fast = @processFast;
handlers.slow = @processSlow;
result = handlers.(method)(x);
```

## References

Load these when working in a specific domain:

| Load when... | Reference |
|---|---|
| Deprecated core MATLAB functions (file I/O, strings, deep learning, UI) | [reference/core-functions-guidance.md](reference/core-functions-guidance.md) |
| Performance anti-patterns, vectorization, preallocation | [reference/performance-guidance.md](reference/performance-guidance.md) |
| Signal processing deprecated functions | [reference/signal-processing-guidance.md](reference/signal-processing-guidance.md) |
| Audio/video I/O migration (wavread, aviread) | [reference/audio-video-guidance.md](reference/audio-video-guidance.md) |
| Optimization toolbox (optimset, optimtool) | [reference/optimization-guidance.md](reference/optimization-guidance.md) |
| Control systems plot options | [reference/control-systems-guidance.md](reference/control-systems-guidance.md) |
| Image processing ROI objects | [reference/image-processing-guidance.md](reference/image-processing-guidance.md) |
| Statistics/ML (svmtrain, dataset, classregtree) | [reference/statistics-ml-guidance.md](reference/statistics-ml-guidance.md) |
| Simulink configuration and blocks | [reference/simulink-guidance.md](reference/simulink-guidance.md) |
| Functions completely removed (guide, optimtool, fints, wavread) | [reference/removed-functions-guidance.md](reference/removed-functions-guidance.md) |
| Communications System objects | [reference/communications-guidance.md](reference/communications-guidance.md) |

## Conventions

- Always run `check_matlab_code` first — let static analysis find deprecated usage
- **After checkcode, scan the source for patterns checkcode misses:** `subplot` (not flagged), `str2num` (sometimes not flagged), `global` variables, growing arrays may only warn about size change
- Fix deprecated patterns before other code quality issues
- When writing new code, use the modern pattern from the start — don't write deprecated code and fix it later
- For functions marked "Removed" — they will cause immediate errors, not just warnings
- When migrating, test the modern replacement against the old behavior to confirm equivalence
- Consult the domain-specific reference file for detailed migration patterns with code examples
