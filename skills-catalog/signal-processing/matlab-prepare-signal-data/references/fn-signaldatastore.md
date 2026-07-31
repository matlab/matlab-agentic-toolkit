# Function: `signalDatastore`

> Used in: wf-load-and-split.md, wf-frame-and-label.md, wf-parallel-process.md, wf-custom-readfcn.md
> Toolbox: Signal Processing Toolbox

Constructor for a datastore over a folder of signal files. Default reader
covers `.mat` and `.csv` first-class — `.wav` requires `audioDatastore` or
a custom `ReadFcn`. Custom `ReadFcn` is reserved for genuinely non-tabular
formats.

## Signature

```matlab
sds = signalDatastore(location)
sds = signalDatastore(location, Name=Value, ...)
sds = signalDatastore(data)            % in-memory form; use MemberNames + Members
```

`location` accepts:
- A folder path (string or char). Files are returned alphabetically in
  `sds.Files`.
- A single file path (string scalar or char vector).
- Multiple file paths (string array or cell array of char vectors).
- Wildcard `*` in local paths (e.g. `"data/*.mat"`).
- A `matlab.io.datastore.FileSet` object (recommended for fast construction
  on large file sets) or a `matlab.io.datastore.DsFileSet` object.
- Remote URLs (`hdfs://`, `http://`, `https://`).

## Name-value pairs / properties (full surface)

`signalDatastore` accepts two construction-only NV-pairs (`IncludeSubfolders`,
`FileExtensions`) plus any of its properties as NV-pairs (except `Files`,
which is set by `location`). Properties can also be set after construction.

### File-location and reader controls

| NV-pair | Default | Purpose |
|---|---|---|
| `FileExtensions` | `.mat` if any `.mat` files exist, else `.csv` | Filter the folder by extension. With the default reader, only `.mat` and `.csv` are valid; for other formats use `ReadFcn`. Errors at construction if neither `.mat` nor `.csv` files are present and no `ReadFcn` is set. **Always set** when the data folder also contains scripts or sub-folders. |
| `IncludeSubfolders` | `false` | Recurse into sub-folders (`true`) or stop at top level. |
| `ReadFcn` | built-in `read` | Custom reader function handle. Both 1-output `data = readFcn(filename)` and 2-output `[data, info] = readFcn(filename)` signatures are valid (see "Custom `ReadFcn`" below). Required for non-`.mat` / non-`.csv` formats. When set, `SampleRateVariableName` / `SampleTimeVariableName` / `TimeValuesVariableName` are not valid. |
| `AlternateFileSystemRoots` | unset | String vector or cell array mapping equivalent root paths across machines (Windows ↔ Linux, local ↔ cluster). Required when the datastore is created on one machine and read on another with a different filesystem layout. |

### Variable-naming controls (file data, default reader only)

| NV-pair | Default | Purpose |
|---|---|---|
| `SignalVariableNames` | first variable in each file | Names of variables (`.mat`) or column headers (`.csv`) to read as signal data. Scalar string returns the array directly; vector returns a cell array. |
| `MemberNames` | `"Member1" .. "MemberN"` | Names for in-memory data members (only when `location` is in-memory data, not file data). |
| `ReadOutputOrientation` | `"column"` | Cell-array orientation when `SignalVariableNames` is a vector: `"column"` returns N×1, `"row"` returns 1×N. No effect with a single variable name. |

### Time-information controls (file data, default reader only — mutually exclusive)

| NV-pair | Default | Purpose |
|---|---|---|
| `SampleRateVariableName` | unset | Name of a per-file variable / column that holds a scalar sample rate. |
| `SampleTimeVariableName` | unset | Name of a per-file variable / column that holds a scalar sample time. |
| `TimeValuesVariableName` | unset | Name of a per-file variable / column that holds a time-values vector. |

> Pick at most one of the three `*VariableName` properties — they are
> mutually exclusive. None of them are valid when `ReadFcn` is set.

### Read-output controls

| NV-pair | Default | Purpose |
|---|---|---|
| `ReadSize` | `1` | Number of files (or members) returned per `read` call. When `> 1`, `read` returns a cell array. |
| `OutputEnvironment` | `"cpu"` | `"cpu"` or `"gpu"`. With `"gpu"`, numeric `read` outputs are returned as `gpuArray`. Requires Parallel Computing Toolbox. *Since R2024b.* |
| `OutputDataType` | `"same"` | Cast `read` output to `"single"`, `"double"`, or leave as `"same"`. Pass either a scalar string (applied to all variables) or a string array of length N matching `SignalVariableNames` (per-variable). Length must be 1 or N — anything else errors. Each element must be one of `"same"`, `"single"`, `"double"`. *Since R2024b.* |

### In-memory data parameters

`SampleRate` (positive scalar / vector), `SampleTime` (positive scalar /
vector / `duration`), and `TimeValues` (vector / matrix / cell) work for
both in-memory and file data, attaching time information directly to the
datastore. Vector forms must have one element per signal.

### Inspection-only properties

| Property | Set by | Purpose |
|---|---|---|
| `Files` | `location` (read-only after construction) | Cell of resolved file paths in alphabetical order. Use `sds.Files{k}` to inspect the k-th file. |
| `Members` | in-memory construction only | Cell array of in-memory member labels (paired with `MemberNames`). Not used for file-backed datastores. |

## CSV is first-class

```matlab
sds = signalDatastore(folder, ...
    FileExtensions=".csv", ...
    SignalVariableNames=["ch1","ch2"]);
```

`read(sds)` returns a `1×N` cell of column vectors per file (where N is the
number of named variables). For a single-column CSV, `SignalVariableNames`
is optional.

**Headerless CSV.** When the CSV has no header row, the default reader
autonames columns `Var1`, `Var2`, … — those are valid `SignalVariableNames`:

```matlab
sds = signalDatastore(folder, FileExtensions=".csv", ...
    SignalVariableNames=["Var1","Var2"]);
```

**2-output `read` works for the default reader, not just custom `ReadFcn`.**
Use it when you want the per-file metadata that the datastore attaches
(e.g. `info.FileName`, `info.SampleRate` if `SampleRateVariableName` is
set):

```matlab
[data, info] = read(sds);
% info.FileName -> path of the file just read
% info.SampleRate -> scalar Fs (when SampleRateVariableName is set)
```

```matlab
sds = signalDatastore(folder, ...
    FileExtensions=".csv", ...
    SignalVariableNames="x", ...
    SampleRateVariableName="fs");   % fs column carries scalar Fs per file
```

## In-file labels — replace the `load(file)` loop

If the label is a variable inside each `.mat` file (e.g. `x` is the signal,
`label` is a categorical scalar), name **both** in `SignalVariableNames`.
The datastore returns `{signal, label}` per `read` — **the manual
`load(file)` loop goes away entirely**.

```matlab
% Files contain variables: x (signal) and label (categorical scalar).
sds = signalDatastore(folder, ...
    FileExtensions=".mat", ...
    SignalVariableNames=["x", "label"]);

% read returns {signal, label} per file:
out = read(sds);
signalK = out{1};
labelK  = out{2};

% Aggregate labels for splitlabels in one readall (lazy until then):
contents = readall(sds);                          % numFiles×1 cell of {x, label}
labelCells = cellfun(@(c) c{2}, contents, ...
    UniformOutput=false);                         % cell of label scalars
labels = vertcat(labelCells{:});                  % categorical column vector
```

Anti-pattern this replaces:

```matlab
% Bad — manual load loop just to extract labels:
labels = strings(numel(sds.Files), 1);
for k = 1:numel(sds.Files)
    s = load(sds.Files{k}, "label");
    labels(k) = s.label;
end
```

If the only reason you're looping is to read a single in-file variable for
labels, list it in `SignalVariableNames` and let the datastore handle it.

**Large signals — read the labels separately.** If the signal is gigabytes
and the label is one scalar per file, `readall(sds)` with both variables
named pulls every signal into memory just to get the labels. Build a
**second, label-only datastore** and `readall` that one instead:

```matlab
% Signal datastore — keeps the signal lazy:
sds = signalDatastore(folder, FileExtensions=".mat", ...
    SignalVariableNames="x");

% Label-only datastore — same files, only the label variable:
labelSds = signalDatastore(folder, FileExtensions=".mat", ...
    SignalVariableNames="label");
labelCells = readall(labelSds);             % numFiles×1 cell of label scalars
labels     = vertcat(labelCells{:});        % loads only the labels
```

Both datastores walk `folder` in alphabetical order, so `labels(k)`
corresponds to `sds.Files{k}` — the index spaces line up for
`splitlabels` → `subset`.

## Anti-pattern

Don't write a custom `ReadFcn` wrapping `readtable(..., 'SelectedVariableNames', ...)`
for tabular CSV. The default reader does this directly via `SignalVariableNames`.

```matlab
% Bad — re-implements what the default reader already does:
sds = signalDatastore(folder, ReadFcn=@(f) ...
    table2array(readtable(f, "SelectedVariableNames", ["ch1","ch2"])));

% Good — default reader, NV pair only:
sds = signalDatastore(folder, FileExtensions=".csv", ...
    SignalVariableNames=["ch1","ch2"]);
```

## Before reaching for `ReadFcn`

Tabular `.mat`/`.csv` almost never needs a custom reader - the default reader
plus `SignalVariableNames` / `SampleRateVariableName` covers it. The full
decision tree (default reader vs NV-pair vs custom `ReadFcn`, and where
`.wav` / non-tabular formats go) is the workflow decision: see
wf-custom-readfcn.md.

## Custom `ReadFcn` (only when needed)

For genuinely non-tabular formats — custom binary, metadata prelude, etc.

Two signatures are valid:

```matlab
% 1-output — when the reader has nothing to add beyond the data:
function data = myReader(filename)
    data = ...;
end

% 2-output — when you need to inject SampleRate or other per-file metadata:
function [data, info] = myReader(filename)
    fid = fopen(filename, "r");
    % ... read header, sample rate, signal ...
    data = signalVector;
    info.SampleRate = fs;
    fclose(fid);
end
```

Use the 2-output form **only when** the reader needs to surface per-file
metadata (e.g. `info.SampleRate`) to downstream consumers. Otherwise the
1-output form is sufficient.

Datastore appends `info.FileName` automatically; user-supplied values are
overwritten.

## Anti-pattern — eager-load inside `ReadFcn`

Don't `load(file)` and discard most variables. At scale this wastes memory
proportional to total file size, not to the variable you actually need.

```matlab
% Bad — loads everything, uses one variable:
function data = badReader(filename)
    s = load(filename);          % loads all variables
    data = s.x;                  % ... but only x is used
end

% Good — named load:
function data = goodReader(filename)
    s = load(filename, "x");     % loads only x
    data = s.x;
end

% Better — matfile for lazy access:
function data = lazyReader(filename)
    m = matfile(filename);
    data = m.x;
end
```

## Gotchas

- **Always set `FileExtensions`** when the data folder also contains scripts
  or sub-folders. Without it, `signalDatastore` will try to ingest non-data
  files and fail at first read.
- **`SignalVariableNames` (not `VariableNames`).** The NV pair has `Signal`
  in the name. Wrong name = silent fall-through to the default behavior.
- **`read()` return shape depends on `SignalVariableNames` count.** One
  variable → returns the array directly. N variables → returns `1×N` cell.
- **Order matches `sds.Files`.** The k-th file's read corresponds to
  `sds.Files{k}` and (for filename labels) `labels(k)`.
- **`ReadOutputOrientation` doesn't transpose your data on disk** — it
  controls how the datastore emits already-oriented data. If your stored
  signal is row-shaped and your network expects column-shaped, set this NV
  pair instead of writing a `transform` to transpose.

## See also

- `transform(sds, fn)` — apply preprocessing per observation. Cell-wrap
  pattern: `transform(sds, @(p){fn(p{:})})` for multi-output reads.
- `read(sds)` / `readall(sds)` / `hasdata(sds)` — datastore consumption
  primitives (MATLAB; not Signal Toolbox).
- For the default-reader CSV path end-to-end, see wf-load-and-split.md
  step 1.

----

Copyright 2026 The MathWorks, Inc.

----
