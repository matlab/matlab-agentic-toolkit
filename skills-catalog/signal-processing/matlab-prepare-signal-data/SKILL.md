---
name: matlab-prepare-signal-data
description: |
  Use this skill when building a `signalDatastore` pipeline for ML training:
  loading signals from .mat / .csv / .dat folders (and `.wav` when Audio
  Toolbox is unavailable), deriving labels (filename, folder, in-file
  column, ROI), splitting into train/val/test, framing long signals for
  per-frame supervision, parallel processing across a parpool, or shaping
  a datastore output for `trainnet`. Triggers include the function names
  `signalDatastore`, `filenames2labels`, `folders2labels`, `splitlabels`,
  `countlabels`, `framesig`, `framelbl`, `signalMask`, `catmask`, and
  workflow phrases like "labels from filenames", "stratified split",
  "ReadFcn for signalDatastore", "load mat/csv/wav for training".
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Prepare Signal Data for ML Training

> **Look in Signal Processing Toolbox first.** The labeling, splitting,
> framing, and partitioning helpers for `signalDatastore` live in Signal
> Processing Toolbox — not in Stats & ML Toolbox or generic-MATLAB string
> utilities.

## When to Use

Loading or preparing signal / time-series data for ML training in MATLAB.
Reach for this skill especially when you want:

- labels derived from filenames or folder names
- stratified train/val/test splits over a datastore
- per-frame labels from ROI tables on long signals
- parallel processing of signals across a parpool
- a datastore shaped to feed `trainnet`

## When NOT to Use

- **Raw `.wav` audio classification with Audio Toolbox available.**
  `audioDatastore` is the canonical path. If Audio Toolbox is not
  available, this skill's custom-`ReadFcn` workflow handles `.wav`
  via base-MATLAB `audioread` — see references/wf-custom-readfcn.md.

## Best practices

- **Deliverable is a runnable `.m` script the user can save and re-run** —
  not workspace state. The output of this skill is a reusable data-prep
  pipeline the user can version and hand off.

## § 0 Common reflexes

If your first instinct is one of these, the canonical replacement is one
row away.

| Reflex | Canonical | Detail |
|---|---|---|
| Custom `ReadFcn` for a `.csv` | `signalDatastore` default reader + `SignalVariableNames` | references/fn-signaldatastore.md |
| `cvpartition` for a datastore split | `splitlabels` + `subset(ds, idx{k})` (cell-array indexing) | references/fn-splitlabels.md |
| `regexp` / `extractBefore` / `fileparts` to derive labels from filenames | `filenames2labels(sds, Extract=...)` | references/fn-filenames2labels.md |
| `regexp` / hand-rolled `fileparts(fileparts(...))` for labels from subfolders | `folders2labels(sds.Files)` — pass the datastore's file list | references/fn-folders2labels.md |
| `parfor i = 1:numel(ds.Files)` constructing a fresh datastore per file | `partition(ds, N, k)` per worker | references/fn-partition.md, references/wf-parallel-process.md |
| Manual framing loop with `(i-1)*hopSize+1` | `framesig(x, fl, OverlapLength=...)` | references/fn-framesig.md, references/wf-frame-and-label.md |
| Manual ROI-to-frame label vote with `containers.Map` | `framelbl(rois, ConsolidationMethod=..., PriorityList=...)` | references/fn-framelbl.md, references/wf-frame-and-label.md |
| `for` loop calling `load(file)` to extract labels from in-file variables | `signalDatastore(folder, SignalVariableNames=["x","label"])` — **the loop goes away**; both variables come back per `read(sds)` as a cell row | references/fn-signaldatastore.md |

## § 1 Workflows

Each workflow file is the **entry point**; it links the function-detail
files you'll need at each step.

| Workflow | Use when | Reference (entry → chain) |
|---|---|---|
| **Load + label + split** | Building a datastore from a folder of files for training. | wf-load-and-split.md → fn-signaldatastore, fn-filenames2labels / fn-folders2labels, fn-countlabels, fn-splitlabels, fn-subset |
| **Frame long signals + per-frame labels** | Signals are long; supervision is per-window. | wf-frame-and-label.md → fn-framesig, fn-framelbl, fn-signalmask-getmask |
| **Parallel processing across a parpool** | Computing per-signal results across workers. | wf-parallel-process.md → fn-partition |
| **Custom ReadFcn (only when needed)** | File format isn't `.mat` / `.csv`, or has a metadata prelude. | wf-custom-readfcn.md → fn-signaldatastore |
| **Hand-off to `trainnet`** | Datastore is ready; next step is shaping for `trainnet` / `combine` / `arrayDatastore` (routes to `minibatchqueue` / `dlarray` for custom batching or GPU prefetching). | wf-handoff-to-dl.md |

## § 2 Functions

| Function | Used for | Reference |
|---|---|---|
| `signalDatastore` | Datastore constructor (.mat / .csv / custom). | references/fn-signaldatastore.md |
| `filenames2labels` | Categorical labels from filename pattern. | references/fn-filenames2labels.md |
| `folders2labels` | Categorical labels from containing-folder name. | references/fn-folders2labels.md |
| `splitlabels` | Stratified train/val/test index sets. | references/fn-splitlabels.md |
| `countlabels` | Per-class file count for balance checks. | references/fn-countlabels.md |
| `subset` | Slice a datastore by index (single-process). | references/fn-subset.md |
| `partition` | Slice a datastore across parpool workers. | references/fn-partition.md |
| `framesig` | Frame a signal into windows with overlap. | references/fn-framesig.md |
| `framelbl` | Collapse ROI rows into per-frame labels. | references/fn-framelbl.md |
| `signalMask` / `catmask` / `binmask` | Per-sample masks from ROI tables. | references/fn-signalmask-getmask.md |

## § 3 Highest-frequency canonical patterns (inline)

### 3.1 CSV is first-class — no custom ReadFcn for tabular CSV

```matlab
sds = signalDatastore(folder, ...
    FileExtensions=".csv", ...
    SignalVariableNames=["ch1","ch2"]);
```

**Don't** wrap `readtable(..., 'SelectedVariableNames', ...)` in a custom
`ReadFcn`. The default reader does this directly.
Full table: references/fn-signaldatastore.md.

### 3.2 Filename labels — position-independent extraction

```matlab
labels = filenames2labels(sds, Extract = "G" + digitsPattern);
```

**Don't** reach for `extractBefore("_")` / `regexp` — silent wrong labels
when filename format varies.
More patterns: references/fn-filenames2labels.md.

### 3.3 Stratified split — splitlabels + subset

```matlab
splitIndices = splitlabels(labels, [0.7 0.15 0.15]);
sdsTrain = subset(sds, splitIndices{1});
sdsVal   = subset(sds, splitIndices{2});
sdsTest  = subset(sds, splitIndices{3});
% splitIndices{4} exists but is empty here (ratios sum to 1).
```

`splitlabels` returns an `(N+1)`-element **cell array** of index vectors. When `sum(ratios) == 1` (as above) the last cell is empty; when `sum(ratios) < 1` the last cell holds the leftover indices.

**Don't** use `cvpartition` for datastore-backed splits — requires materializing
labels first and doesn't compose with `subset`.
Full contract: references/fn-splitlabels.md.


----

Copyright 2026 The MathWorks, Inc.

----
