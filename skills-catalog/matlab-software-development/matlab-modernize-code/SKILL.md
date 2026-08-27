---
name: matlab-modernize-code
description: >
  Modernize removed or discouraged MATLAB functions and patterns. Use when the
  check_matlab_code MCP tool reports that a function "is not recommended",
  "will be removed in a future release", or "has been removed" — at any
  severity (info, warning, or error) — when migrating legacy code, or when
  replacing removed or discouraged APIs with current equivalents. Also applies
  to discouraged patterns Code Analyzer does not flag (containers.Map, bsxfun,
  str2num, eval, clear all) and to removed or discouraged functions such as
  trainNetwork, csvread, xlsread, datenum, guide, svmtrain, ltln2val, webmap.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.3"
---

# Code Modernization

Replace removed or discouraged MATLAB functions and anti-patterns with modern equivalents. This skill is the resolver — the MCP tool `check_matlab_code` (MATLAB's Code Analyzer) is the detector.

**Terms used in this skill:**
- **Removed** — the function is no longer in MATLAB; calling it errors.
- **Discouraged** — the function still works, but a better API exists. It may or may not be slated for removal in a future release.

## When to Use

- `check_matlab_code` reports a lifecycle diagnostic — any of these three
  wordings, matched case-insensitively (`STRMATCH is not recommended` is the
  same signal as the lowercase form):
  - `'X' is not recommended...` (severity: info)
  - `'X' will be removed in a future release...` (severity: warning)
  - `'X' has been removed...` (severity: error — the code errors today)
- Code uses a discouraged pattern Code Analyzer does *not* flag — e.g. `containers.Map`, `bsxfun`, `str2num`, `eval`, `clear all` — scan the source, not just the diagnostics (see Conventions)
- User asks to modernize, migrate, or update old MATLAB code
- Code uses functions listed in the quick reference table below
- After static analysis reveals removed or discouraged API usage
- Writing new code in a domain that has known removed or discouraged patterns

## When NOT to Use

This skill swaps removed or discouraged APIs for modern equivalents. It does not:

- Review code quality broadly
- Debug runtime behavior (removed-function errors excepted — those are modernization fixes)
- Optimize already-correct code for speed → hand off to `matlab-optimize-performance`
- Write or migrate function input/output validation (`arguments` blocks, `inputParser`/`validateattributes` → `mustBe*` validators, repeating args, name-value forwarding) → hand off to `matlab-validate-function-arguments`

## Quick Reference: Removed, Discouraged & Anti-Patterns

| Topic | Recommendation | Since | Category | Rationale |
|---|---|---|---|---|
| `csvread` / `dlmread` | `readmatrix` | R2019a | File I/O | |
| `csvwrite` / `dlmwrite` | `writematrix` | R2019a | File I/O | |
| `xlsread` | `readtable`, `readmatrix` | R2019a | File I/O | |
| `xlswrite` | `writetable`, `writematrix` | R2019a | File I/O | |
| `datenum` / `datestr` / `now` | `datetime` (use `string`/`char` to format) | R2022b | Date/Time (Not recommended) | Flagged by Code Analyzer |
| `eval` / `evalc` / `evalin` | Dynamic field names `s.(name)`, function handles / `feval`, cells for sequential names | — | Anti-pattern | Not compiled (slow); can overwrite workspace vars; hard to debug; injection risk |
| `str2num` | `str2num(text, Evaluation="restricted")` | R2022a | Security | Unrestricted form runs input via `eval` (injection risk); see references |
| `uicontrol` | `uibutton`, `uidropdown`, etc. | R2016a | UI/App | |
| `guide` | `appdesigner` | R2025a | UI (Removed) | |
| `strmatch` | `startsWith`, `matches` | R2019b | Strings | |
| `clear all` | `clearvars` | — | Workspace | Clears functions from memory; forces recompilation |

> **`datestr` nuance:** `datestr`'s job was to format a date as *text*, so its modern replacement is
> `string(dt)` / `char(dt)` or setting `dt.Format` — not a bare `datetime(...)` call. Use `datetime`
> to replace `datenum`/`now` (the numeric/serial-date path). Neither is removed; both are Code
> Analyzer "not recommended" as of R2022b.
>
> ```matlab
> s = datestr(t, 'yyyy-mm-dd HH:MM:SS');          % old
> s = string(t, 'yyyy-MM-dd HH:mm:ss');           % new — note the specifiers change:
>                                                 % datetime uses MM=month, mm=minute (datestr had mm=month, MM=minute)
> ```

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

## Key Migrations

### File I/O: csvread/xlsread → readmatrix/readtable

```matlab
% Old                          → Modern
M = csvread('data.csv');       % M = readmatrix("data.csv");
M = dlmread('data.txt','\t'); % M = readmatrix("data.txt", Delimiter="\t");
[n,t,r] = xlsread('f.xlsx');  % T = readtable("f.xlsx");
csvwrite('out.csv', M);       % writematrix(M, "out.csv");
xlswrite('out.xlsx', data);   % writetable(T, "out.xlsx");
```

### eval → Structured Alternatives

Avoid `eval`/`evalc`/`evalin`: the text isn't compiled (slower), can silently overwrite workspace
variables, and is hard to read/debug. Match the intent to a construct — see
`references/core-functions-guidance.md` for the full set (sequential names, `sprintf` filenames,
`try/catch`).

```matlab
% Old: eval([varName ' = 42;']);          -> dynamic field name
s.(varName) = 42;

% Old: result = eval(['process_' method '(x)']);  -> handle dispatch table
handlers.fast = @processFast;
handlers.slow = @processSlow;
result = handlers.(method)(x);

% Old: for n=1:10, eval(['A' int2str(n) '=magic(n);']); end  -> index a cell
A = cell(10,1);
for n = 1:10, A{n} = magic(n); end
```

## References

Load these when working in a specific domain:

| Load when... | Reference |
|---|---|
| Core MATLAB functions (file I/O, strings, UI); security anti-patterns (`eval`/`str2num`), `containers.Map`→`dictionary`, `bsxfun`→implicit expansion | [references/core-functions-guidance.md](references/core-functions-guidance.md) |
| Deep Learning (trainNetwork→trainnet, LayerGraph/SeriesNetwork/DAGNetwork→dlnetwork, classify, activations) | [references/deep-learning-guidance.md](references/deep-learning-guidance.md) |
| Signal processing functions | [references/signal-processing-guidance.md](references/signal-processing-guidance.md) |
| Audio/video I/O migration (wavread, aviread) | [references/audio-video-guidance.md](references/audio-video-guidance.md) |
| Optimization toolbox (optimset, optimtool) | [references/optimization-guidance.md](references/optimization-guidance.md) |
| Control systems plot options | [references/control-systems-guidance.md](references/control-systems-guidance.md) |
| Image processing ROI objects | [references/image-processing-guidance.md](references/image-processing-guidance.md) |
| Statistics/ML (svmtrain, dataset, classregtree) | [references/statistics-ml-guidance.md](references/statistics-ml-guidance.md) |
| Communications System objects | [references/communications-guidance.md](references/communications-guidance.md) |
| Mapping Toolbox (webmap, wmmarker, wmline, geotiffread, mfwdtran, makerefmat) | [references/mapping-guidance.md](references/mapping-guidance.md) |

## Conventions

- Always run `check_matlab_code` first — let static analysis find removed or discouraged usage
- **After running it, scan the source for patterns the Code Analyzer may under-flag:** `str2num` (framed only as a perf tip); `containers.Map` (see next point).
- **`containers.Map` is *not* flagged by `check_matlab_code`.** A plain script using it returns zero diagnostics; a `containers.Map` *property default* surfaces only a handle-default-sharing warning ("all instances share the same object data"). The detect-first workflow will not find this migration — treat any `containers.Map` usage, and that handle-sharing warning on a property, as a `containers.Map`→`dictionary` trigger.
- **`subplot` is *not* deprecated or discouraged.** It is fully supported and is never flagged by `check_matlab_code`. `tiledlayout`/`nexttile` is a *preferred alternative for new code, not a required migration* — do not tell the user to replace working `subplot` code.
- Fix removed or discouraged patterns before other code quality issues
- When writing new code, use the modern pattern from the start — don't write legacy code and fix it later
- A `'X' has been removed` diagnostic (severity `error`) means the function errors *today* — treat it as a break-fix modernization, ahead of "not recommended" (info) and "will be removed" (warning) cases
- When migrating, test the modern replacement against the old behavior to confirm equivalence
- **Legacy `.m` files are often Windows-1252 encoded.** After an edit, verify non-ASCII characters (`°`, `µ`, `±`) survived — a diff showing an unrelated one-line change on a comment or string is usually a re-encoded byte, not your edit.
- Consult the domain-specific reference file for detailed migration patterns with code examples

----

Copyright 2026 The MathWorks, Inc.

----

