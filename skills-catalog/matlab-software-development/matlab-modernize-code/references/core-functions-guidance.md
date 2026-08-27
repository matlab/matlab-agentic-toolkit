# Core Function Modernization

Core MATLAB (base-language) modernizations: File I/O, strings, UI components,
security anti-patterns, key-value containers, and base-language design patterns.
Toolbox-specific migrations live in their own reference files — see the
References table in `SKILL.md` (deep learning, signal, image, mapping,
statistics, control, optimization, and communications each have a dedicated
file).

## Quick Reference: Core Function Mappings

| Topic | Recommendation | Since | Category | Status |
|---|---|---|---|---|
| `csvread` / `dlmread` | `readmatrix` | R2019a | File I/O | Not Recommended |
| `csvwrite` / `dlmwrite` | `writematrix` | R2019a | File I/O | Not Recommended |
| `xlsread` | `readtable` / `readmatrix` / `readcell` | R2019a | File I/O | Not Recommended |
| `xlswrite` | `writetable` / `writematrix` / `writecell` | R2019a | File I/O | Not Recommended |
| `strmatch` | `startsWith` / `strncmp` / `matches` | R2019b | Strings | Not Recommended |
| `uicontrol` | `uibutton` / `uidropdown` / etc. | R2016a | UI/App | Not Recommended |
| `guide` | `appdesigner` | R2025a | UI/App | Removed |
| `hgexport('readstyle')` | `exportgraphics` | R2025a | Graphics | Removed |
| `nargin` / `nargout` in scripts | convert the script to a function | R2022a | Language | Removed |
| `str2num` | `str2num(text, Evaluation="restricted")` | R2022a | Security | Unrestricted form runs input via `eval` |
| `eval` / `evalc` / `evalin` | Dynamic field names, function handles / `feval`, cells for sequential names | — | Anti-pattern | Not compiled (slow); overwrites workspace vars; hard to debug; injection risk |
| `containers.Map` | `dictionary` | R2022b | Containers | Not Recommended — **not flagged by Code Analyzer** |
| `bsxfun` | Implicit expansion | R2016b | Arrays | Not Recommended (superseded) |

---

## File I/O Modernization

### csvread, dlmread → readmatrix

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
M = csvread('data.csv');
M = dlmread('data.txt', '\t');
M = dlmread('data.csv', ',', 1, 0);  % Skip header row
```

**Modern Pattern (Use This):**
```matlab
M = readmatrix('data.csv');
M = readmatrix("data.txt", Delimiter="\t");

% Skip header rows
opts = detectImportOptions('data.csv');
opts.DataLines = [2 Inf];
M = readmatrix('data.csv', opts);
```

**Why Modern is Better:**
- Better cross-platform support and performance
- Automatic detection of data format and types
- Import options for controlling the import process
- Better error handling and missing data management

---

### csvwrite, dlmwrite → writematrix

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
csvwrite('output.csv', M);
dlmwrite('output.txt', M, '\t');
dlmwrite('output.csv', M, '-append');
```

**Modern Pattern (Use This):**
```matlab
writematrix(M, 'output.csv');
writematrix(M, "output.txt", Delimiter="\t");
writematrix(M, "output.csv", WriteMode="append");
```

---

### xlsread → readtable, readmatrix, readcell

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
[num, txt, raw] = xlsread('data.xlsx');
data = xlsread('data.xlsx', 'Sheet1', 'A2:D100');
```

**Modern Pattern (Use This):**
```matlab
% For tabular data (most common)
T = readtable('data.xlsx');
T = readtable("data.xlsx", Sheet="Sheet1", Range="A2:D100");

% For numeric matrix
M = readmatrix('data.xlsx');

% For cell array (mixed types)
C = readcell('data.xlsx');
```

**Why Modern is Better:**
- `readtable` preserves variable names and types
- Better handling of mixed data types
- Works consistently across platforms
- Better datetime and categorical support

---

### xlswrite → writetable, writematrix, writecell

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
xlswrite('output.xlsx', data);
xlswrite('output.xlsx', data, 'Sheet1', 'A2');
```

**Modern Pattern (Use This):**
```matlab
% For tables
writetable(T, 'output.xlsx');
writetable(T, "output.xlsx", Sheet="Sheet1", Range="A2");

% For matrices
writematrix(M, 'output.xlsx');

% For cell arrays
writecell(C, 'output.xlsx');
```

---

## String Function Modernization

### strmatch → startsWith, strncmp, matches

**Status:** Not recommended

**Old Pattern (Avoid):**
```matlab
idx = strmatch('abc', strArray);
idx = strmatch('abc', strArray, 'exact');
```

**Modern Pattern (Use This):**
```matlab
% Find strings starting with pattern
idx = find(startsWith(strArray, 'abc'));

% Find exact matches
idx = find(matches(strArray, 'abc'));

% Case-insensitive
idx = find(startsWith(strArray, "abc", IgnoreCase=true));
```

---

### Character Arrays → String Arrays

**Recommendation:** Use string arrays for new code

**Old Pattern (Less Preferred):**
```matlab
name = 'John';
names = {'John', 'Jane', 'Bob'};
fullName = [firstName, ' ', lastName];
```

**Modern Pattern (Preferred):**
```matlab
name = "John";
names = ["John", "Jane", "Bob"];
fullName = firstName + " " + lastName;
```

**Why Modern is Better:**
- String arrays work better with modern MATLAB functions
- Easier concatenation with `+` operator
- Better missing value handling with `<missing>`
- More intuitive indexing

---

### strfind → contains (for string arrays)

**Recommendation:** Use `contains` for string array searches

**Old Pattern:**
```matlab
idx = ~cellfun('isempty', strfind(cellstr, pattern));
```

**Modern Pattern:**
```matlab
idx = contains(stringArray, pattern);
```

---

## UI/App Development Modernization

### uicontrol → Modern UI Components

**Status:** Not recommended. Use App Designer components.

**Old Pattern (Avoid):**
```matlab
fig = figure;
btn = uicontrol('Style', 'pushbutton', 'String', 'Click Me', ...
    'Position', [20 20 100 30], 'Callback', @buttonCallback);
edit = uicontrol('Style', 'edit', 'Position', [20 60 100 25]);
popup = uicontrol('Style', 'popupmenu', 'String', {'A','B','C'});
```

**Modern Pattern (Use This):**
```matlab
fig = uifigure;
btn = uibutton(fig, 'Text', 'Click Me', ...
    'Position', [20 20 100 30], 'ButtonPushedFcn', @buttonCallback);
edit = uieditfield(fig, 'Position', [20 60 100 25]);
dropdown = uidropdown(fig, 'Items', {'A','B','C'});
```

**UI Component Mapping:**
| uicontrol Style | Modern Component |
|-----------------|------------------|
| pushbutton | uibutton |
| edit | uieditfield |
| text | uilabel |
| popupmenu | uidropdown |
| listbox | uilistbox |
| checkbox | uicheckbox |
| radiobutton | uiradiobutton |
| slider | uislider |
| togglebutton | uibutton (with state) |

**Why Modern is Better:**
- Modern appearance consistent with App Designer
- Better styling and customization options
- Responsive layouts with uigridlayout
- Better touch/mobile support

---

### guide → appdesigner

**Status:** Removed in R2025a (discouraged since R2021a).

GUIDE (Graphical User Interface Development Environment) was MATLAB's original drag-and-drop app
builder. The interactive environment has been removed and replaced by App Designer. `guide` now
resolves to a stub that errors when called (identifier `MATLAB:guide:GUIDEHasBeenRemoved`).

**Old Pattern (Will Error):**
```matlab
% REMOVED (R2025a): the GUIDE environment no longer exists
guide                    % Errors: GUIDE has been removed
guide('myapp.fig')       % Errors: GUIDE has been removed
```

**Modern Pattern (Use This):**
```matlab
appdesigner              % Create a new app
appdesigner('myapp.mlapp')  % Open an existing App Designer app
app = myapp;             % Run an app programmatically
```

**Migration:**
- Use the **GUIDE to App Designer Migration Tool** (App Designer → Designer tab → Open → Migration
  tool) to convert existing `.fig` + `.m` apps.
- Existing GUIDE apps can still **run** in R2025a+ (`.fig` + `.m`); you just can't **edit** them in
  the removed GUIDE environment. Migrate for maintainability.

**Callback pattern change (`handles` struct → app properties):**
```matlab
% OLD GUIDE callback (will not work interactively)
function pushbutton1_Callback(hObject, eventdata, handles)
    handles.data = handles.data + 1;
    guidata(hObject, handles);
    set(handles.text1, 'String', num2str(handles.data));
end

% NEW App Designer callback
function Button1Pushed(app, event)
    app.Data = app.Data + 1;
    app.Label1.Text = num2str(app.Data);
end
```

**Key differences:** single `.mlapp` file (not `.fig` + `.m`); callbacks live with the layout; data
sharing via app properties (`app.PropertyName`) instead of the `handles` struct and `guidata`.

---

### hgexport('readstyle') → exportgraphics

**Status:** Removed in R2025a.

The `hgexport('readstyle', ...)` function for reading export style files has been removed.

**Old Pattern (Will Error):**
```matlab
% REMOVED (R2025a):
style = hgexport('readstyle', 'mystyle.txt');
hgexport(gcf, 'output.eps', style);
```

**Modern Pattern (Use This):**
```matlab
exportgraphics(gcf, "output.pdf", ContentType="vector");
exportgraphics(gcf, "output.png", Resolution=300);
exportgraphics(gca, "output.eps", ContentType="vector");

% For more control, set figure/axes properties directly, then export
fig = gcf;
fig.Color = "white";
ax = gca;
ax.FontSize = 12;
exportgraphics(fig, "output.pdf");
```

`exportgraphics` needs no external style files, works with axes/figures/chart containers, and gives
better PDF and vector output.

---

## Security Recommendations

### str2num → str2num with restricted evaluation

**Recommendation:** Replace `str2num(text)` with `str2num(text, Evaluation="restricted")`
(R2022a+). Restricted evaluation accepts only numeric and basic math expressions, so injected code
cannot execute. This is the secure, drop-in replacement.

**Old Pattern (Security Risk):**
```matlab
% DANGEROUS: unrestricted str2num evaluates its input with eval, so a string
% like "system('rm -rf /')" would run.
value = str2num(userInput);
```

**Modern Pattern (Secure):**
```matlab
% SECURE: restricted evaluation accepts only numeric/math expressions.
value = str2num(userInput, Evaluation="restricted");
```

**Why This Matters:**
- Unrestricted `str2num` evaluates its input with `eval` and can run arbitrary code.
- `Evaluation="restricted"` confines evaluation to numeric and math expressions, so injected
  function calls cannot execute — closing the injection risk.

---

### eval → Structured Alternatives

**Recommendation:** Avoid `eval`, `evalc`, and `evalin`. Per MathWorks best practice
([Alternatives to the eval Function](https://www.mathworks.com/help/matlab/matlab_prog/string-evaluation.html)),
`eval` code:

- **Is not compiled.** MATLAB compiles code on first run to speed up later runs, but because
  `eval` text can change at run time it cannot be compiled — so it is slower.
- **Can silently overwrite workspace variables.** `eval` may create or assign to a variable
  already in the current workspace, clobbering existing data.
- **Is hard to read and debug**, and (for `eval`/`str2num` on external input) opens a code-injection
  risk. The Code Analyzer cannot see through the string, so it can't help.

Almost every `eval` use maps to a clearer construct. Match the pattern, don't reach for `eval`:

**1. Sequentially named variables (`A1`, `A2`, …) → one array / cell / struct**
```matlab
% Old:
% for n = 1:10
%     eval(['A' int2str(n) ' = magic(n);']);
% end
numArrays = 10;
A = cell(numArrays,1);
for n = 1:numArrays
    A{n} = magic(n);          % index instead of building a name
end
```

**2. Sequentially named files → build the name with `sprintf`, call in function syntax**
```matlab
% Old: eval(['save myfile' int2str(n) '.mat randomData']);
for n = 1:10
    randomData = rand(n);
    currentFile = sprintf('myfile%d.mat', n);   % sprintf beats int2str
    save(currentFile, 'randomData')
end
```

**3. Function name held in a variable → function handle or `feval`**
```matlab
% Old: result = eval(['process_' methodName '(x)']);

% Preferred: map names to handles (dispatch table)
methodHandles = struct("fast", @processFast, "slow", @processSlow);
result = methodHandles.(methodName)(x);

% Or convert a name to a handle
h = str2func("process_" + methodName);
result = h(x);

% Or, when the name arrives at run time (e.g. user input), feval
result = feval(methodName, x);
```
`feval` is a *recommended* alternative here, not itself an anti-pattern.

**4. Dynamic struct field → parenthesized field name**
```matlab
% Old: eval(['s.' fieldName ' = 42;']);
s.(fieldName) = 42;                 % assign
dataToUse = myData.(fieldName);     % read
```

**5. `eval` used as an implicit try/catch → explicit `try/catch`**
```matlab
% Old (implicit catch): eval("B = A;", "disp('A is undefined')")
try
    B = A;
catch exception
    disp("A is undefined")
end
```
The older `eval(expression, catch_expr)` form is not recommended — an explicit `try/catch` is
significantly clearer.

**6. `evalc('disp(x)')` to capture a variable's display text → `formattedDisplayText`**

A common `evalc` use is capturing what `disp` *would* print — for a log line, an error message, or a
report — by running `disp` for its side effect and grabbing the command-window output. `evalc` runs
the string uncompiled and is opaque to the Code Analyzer. Since R2021a, `formattedDisplayText`
returns that same text directly, as a string.

```matlab
% Old: run disp for its side effect, capture the command-window text
txt = evalc('disp(x)');

% Modern: get the formatted display text directly (returns a string)
txt = formattedDisplayText(x);
```

The two are identical except that `evalc` appends one extra trailing newline (from the command-window
echo) that `formattedDisplayText` omits — usually what you want. Because it returns a string, it
composes directly:

```matlab
A = [1 2 3; 4 5 6];
msg = "Matrix A =" + newline + formattedDisplayText(A);
```

`formattedDisplayText` also takes name-value options for full control over the rendering — e.g.
`NumericFormat="longG"`, `LineSpacing="compact"`, `SuppressMarkup=true` — which the `evalc('disp(...)')`
form cannot express.

**When you truly need a run-time key-value store** (not a fixed set of fields), reach for a
`dictionary` (R2022b+, preferred over `containers.Map`) rather than synthesizing variable names —
see the Map Container section below.

---

## Map Container Modernization

### containers.Map → dictionary

**Status:** `dictionary` (R2022b+) is the preferred key-value type. `containers.Map` is a legacy
*handle* class and still works, but `dictionary` is a value type, is faster, supports vectorized
lookup, and integrates with the modern data types. Migrate new code to `dictionary`.

**Old Pattern (Legacy):**
```matlab
m = containers.Map({'alpha','beta','gamma'}, {1.5, 2.0, 0.75});
s = m('beta');            % -> 2.0
m('delta') = 3.0;         % add
tf = isKey(m, 'alpha');   % membership
remove(m, 'gamma');       % delete (mutates in place — handle semantics)
n = m.Count;              % number of entries
allKeys = keys(m);        % cell array of keys
```

**Modern Pattern (Use This):**
```matlab
d = dictionary(["alpha" "beta" "gamma"], [1.5 2.0 0.75]);
s = d("beta");            % -> 2.0
d("delta") = 3.0;         % add
tf = isKey(d, "alpha");   % membership
d = remove(d, "gamma");   % delete — VALUE semantics, so REASSIGN d
n = numEntries(d);        % number of entries (not .Count)
allKeys = keys(d);        % string array of keys (not a cell array)
```

**Key differences when migrating — these bite if you swap the name blindly:**

| Concern | `containers.Map` | `dictionary` |
|---|---|---|
| Semantics | **handle** — `remove(m,k)` mutates in place | **value** — `d = remove(d,k)` must be reassigned |
| Construct | `containers.Map(keys, vals)` (cell arrays) | `dictionary(keys, vals)` (arrays; string keys, not char) |
| Count | `m.Count` | `numEntries(d)` |
| Keys/values | `keys(m)`/`values(m)` → **cell** arrays | `keys(d)`/`values(d)` → typed **arrays** |
| Missing key | errors (`MATLAB:Containers:Map:NoKey`) | errors (`MATLAB:dictionary:ScalarKeyNotFound`) — use `lookup(d, k, FallbackValue=...)` for a default |
| Key type | `'char'` keys | prefer `"string"` keys; numeric keys also supported |

**Incremental build (empty then fill):**
```matlab
% Old
m = containers.Map('KeyType','char','ValueType','double');
m('x') = 10;

% Modern, fill-immediately — start empty, key/value types are inferred on first insert
d = dictionary;
d("x") = 10;

% Modern, query-before-insert — configure the types up front so isKey/lookup
% work while the dictionary is still empty (the registry / cache / singleton shape)
d = configureDictionary("string","double");
tf = isKey(d, "x");   % -> false, no error
d("x") = 10;
```

**Critical for stateful maps:** a bare `dictionary` is *unconfigured* until its first insert. Calling
`lookup`, `isKey`, or indexing it before then errors with
`MATLAB:dictionary:UnconfiguredLookupNotSupported`. This is the single most likely failure when
migrating a registry or cache class that queries the map before it is populated — use
`configureDictionary(keyType, valueType)` instead of bare `dictionary`. Guard any dictionary that may
be unconfigured with `isConfigured(d)` before iterating `keys`/`values`.

**Values that are not scalars** (vectors, mixed types) — use a cell-valued dictionary, same as
`containers.Map`'s cell values:
```matlab
d = dictionary(["u" "v"], {[1 2 3], "hello"});
row = d("u");        % row is a 1x1 cell
row = row{1};        % -> [1 2 3]
```

**`ValueType='any'` (heterogeneous values) — the migration that bites hardest.** A
`containers.Map('KeyType','char','ValueType','any')` stores values of *mixed* class per key
(scalars, vectors, strings, structs). `dictionary` has no `'any'` value type — a dictionary's values
share one type. The correct target is a **cell-valued** dictionary: configure it as `"cell"` and use
**brace indexing** (`d{"k"}`), which auto-wraps on assign and auto-unwraps on read.
```matlab
% Old — heterogeneous value store
m = containers.Map('KeyType','char','ValueType','any');
m('scalar') = 42;
m('vec')    = [1 2 3];
m('cfg')    = struct('a',1);

% Modern — cell value type; brace indexing auto-wraps/unwraps
d = configureDictionary("string","cell");
d{"scalar"} = 42;
d{"vec"}    = [1 2 3];
d{"cfg"}    = struct('a',1);

v = d{"vec"};    % -> [1 2 3]  (brace read unwraps the cell — no temp needed)
```
- **Use brace indexing (`d{"k"}`).** Brace assignment wraps the value in the cell for you and brace
  read unwraps it, so the call sites read exactly like the old `containers.Map` (`m(k) = v` → `d{k} = v`) —
  no manual `{...}` wrapping. This is the cleanest target for an `'any'` map.
- **Paren indexing still exposes the raw cell.** `d("k")` returns the 1x1 cell (`v = d("k"); v = v{1}`
  to unwrap); `d{"k"}` returns the value directly. Prefer braces unless you deliberately want the cell.
- **`d("k"){1}` does not parse** — `{}` directly after `()` is disallowed (same rule as chained `()`
  above). Brace-indexing the dictionary itself (`d{"k"}`) sidesteps this — no temp variable needed.
- **Don't reach for `"cell"` when the values are actually homogeneous.** Many `ValueType='any'` maps
  hold one type in practice (all doubles, all strings). If so, migrate to the natural typed dictionary
  (`configureDictionary("string","double")`) and skip the cell wrapping entirely — inspect the real
  values before choosing. Reserve the cell-valued form for genuinely mixed-type stores.

**Iterate over entries:**
```matlab
% Old
for k = keys(m)          % k is a 1x1 cell
    disp(m(k{1}))
end

% Modern — keys(d) is a string array; transpose to loop columns
for k = keys(d)'
    disp(d(k))
end
```

**Watch-outs:**
- **`remove` returns the updated dictionary** — `remove(d,k)` without reassignment does nothing
  visible, because `dictionary` is a value type. `containers.Map` mutated in place; `dictionary` does
  not. This is the single most common migration bug.
- **Don't index a lookup result with chained parentheses** — `d(k)(1)` is illegal in R2026a
  (`Using parentheses '()' directly after parentheses '()' is disallowed`). Use a temp: `v = d(k); v(1)`.
- **The missing-key error identifier changes.** `containers.Map` throws `MATLAB:Containers:Map:NoKey`;
  `dictionary` throws `MATLAB:dictionary:ScalarKeyNotFound`. Any `catch` block that tests
  `e.identifier` against the Map id must be updated — otherwise it silently rethrows instead of
  handling the missing key.
- Keys are best kept as **string** (`"beta"`). char (`'beta'`) is not supported as a key. If passed a char, `dictionary` coerces it to a string.

---

## Superseded Vectorization Idioms

### bsxfun → implicit expansion

**Status:** `bsxfun` is **superseded** — avoid it in new code. Since R2016b, MATLAB applies implicit
expansion (broadcasting) to element-wise operators and two-input functions automatically, so the
explicit `bsxfun` call is legacy and no longer recommended.

**Old Pattern (superseded — do not use `bsxfun`):**
```matlab
normalized = bsxfun(@rdivide, A, max(A));   % legacy: bsxfun is superseded
centered   = bsxfun(@minus,   A, mean(A));  % legacy: avoid bsxfun here too
```

**Modern Pattern (implicit expansion, R2016b+):**
```matlab
normalized = A./max(A);      % broadcasts the 1×n max across rows
centered = A - mean(A);      % broadcasts the 1×n mean across rows
```

This is a *modernization* swap (a superseded API → its current equivalent), which is why it lives in
this skill. Making an already-correct loop *faster* by vectorizing it — choosing whether to vectorize
at all, and measuring the speedup — is optimization work owned by `matlab-optimize-performance` (see
SKILL.md "When NOT to Use").

---

## Language Removals

### nargin / nargout in scripts

**Status:** Support removed in R2022a.

`nargin` and `nargout` report the argument counts of a **function** call. Calling them at script
scope errors in R2022a+.

```matlab
% OLD — errors in R2022a+ when used in a script
if nargin > 0
    % ...
end
```

**Fix:** convert the script to a function so it has a real argument list.
```matlab
function processData(varargin)
    if nargin > 0
        % ...
    end
end
```

---

## Design Pattern Modernization

`SKILL.md` shows the always-loaded base-language patterns (table workflows, string
arrays, `arguments` blocks) as terse snippets. This
section adds the patterns that don't fit inline.

### Tall Arrays for Big Data

**For data that doesn't fit in memory:**

```matlab
% Modern: Use tall arrays
ds = datastore('bigdata/*.csv');
T = tall(ds);
result = gather(mean(T.Value));  % Processes in chunks
```


----

Copyright 2026 The MathWorks, Inc.

----
