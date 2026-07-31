# Function: `labeledSignalSet`

> Used in: wf-label-and-export.md
> Toolbox: Signal Processing Toolbox
> Since: R2018b (roiTimeFrequency support since R2025a)

Store labeled signals alongside label definitions. The container that ties
signals, label definitions, and label values together.

## Signatures

```matlab
lss = labeledSignalSet                                  % empty
lss = labeledSignalSet(src)                             % from data source
lss = labeledSignalSet(src, lbldefs)                    % with label definitions
lss = labeledSignalSet(src, lbldefs, Name=Value)        % with properties
```

## Data sources (`src`)

| Source form | Members | Signals per member |
|---|---|---|
| Numeric matrix `NxM` | 1 | M columns |
| Cell array of matrices `{NxM, PxQ, ...}` | numel(cell) | columns per matrix |
| Cell array of cell vectors `{{v1}, {v2, v3}}` | numel(outer) | numel(inner), variable length |
| Timetable | 1 | variables |
| Cell array of timetables | numel(cell) | variables per TT |
| `signalDatastore` | number of files | signals per file |
| `audioDatastore` | number of files | channels per file |

## Properties

| Property | Settable | Notes |
|---|---|---|
| `Source` | at creation only | Data source |
| `NumMembers` | read-only | Number of members |
| `Labels` | read-only | Table; rows = members, columns = label definitions |
| `TimeInformation` | read-only | `"none"` \| `"sampleRate"` \| `"sampleTime"` \| `"timeValues"` \| `"inherent"` |
| `Description` | yes | Free text |
| `SampleRate` | at creation only | Scalar or vector (one per member) |
| `SampleTime` | at creation only | Scalar/vector/duration |
| `TimeValues` | at creation only | Vector/matrix/cell |

## Key object functions

### Adding/removing structure

| Function | Does |
|---|---|
| `addMembers(lss, newSrc)` | Append members |
| `removeMembers(lss, idx)` | Remove by index |
| `addLabelDefinitions(lss, defs)` | Add label definitions after creation |
| `removeLabelDefinition(lss, name)` | Remove a label definition |
| `editLabelDefinition(lss, name, NV)` | Edit definition properties |

### Setting/getting label values

| Function | Signature |
|---|---|
| `setLabelValue` | See per-type signatures below |
| `getLabelValues(lss)` | Full label table |
| `getLabelValues(lss, idx, name)` | One label for one member |
| `getLabelValues(lss, idx, [parent child])` | Sublabel values |
| `resetLabelValues(lss, idx, name)` | Reset to defaults |
| `removeRegionValue(lss, idx, name, rowIdx)` | Remove specific ROI row |
| `removePointValue(lss, idx, name, rowIdx)` | Remove specific point row |

### Querying

| Function | Returns |
|---|---|
| `getLabelNames(lss)` | String array of label names |
| `getLabelDefinitions(lss)` | signalLabelDefinition vector |
| `getLabelIndices(lss, name)` | Index information |
| `getMemberNames(lss)` | Member name strings |
| `setMemberNames(lss, names)` | Rename members |
| `getSignal(lss, idx)` | Raw signal data |
| `getLabeledSignal(lss, idx)` | Signal + labels together |
| `countLabelValues(lss, name)` | Per-class counts and percentages |
| `labelDefinitionsHierarchy(lss)` | Text hierarchy |
| `labelDefinitionsSummary(lss)` | Summary table |
| `head(lss)` | Top rows of Labels table |

### Export

| Function | Returns |
|---|---|
| `createDatastores(lss, labelNames)` | `[signalDS, labelDS]` for ML training |
| `createDatastores(lss, name, TF NV-pairs)` | TF image + mask datastores (R2025a) |
| `createFeatureData(lss, ...)` | Feature table/matrix + response vectors |
| `merge(lss1, lss2)` | Combined labeled signal set |
| `subset(lss, idx)` | New lss with subset of members |

## `setLabelValue` — per-type signatures

### Attribute

```matlab
setLabelValue(lss, memberIdx, "LabelName", value)
% value: scalar matching LabelDataType
```

### ROI (time-domain)

```matlab
setLabelValue(lss, memberIdx, "LabelName", roiLimits, values)
% roiLimits: Nx2 [start end] in seconds (or samples if no SampleRate)
% values: Nx1 matching LabelDataType
```

### Point

```matlab
setLabelValue(lss, memberIdx, "LabelName", locations, values)
% locations: Nx1 time points
% values: Nx1 matching LabelDataType
```

### Time-frequency ROI (R2025a)

```matlab
setLabelValue(lss, memberIdx, "LabelName", timeLimits, freqLimits, values)
% timeLimits: Nx2 [tStart tEnd] in seconds
% freqLimits: Nx2 [fLow fHigh] in Hz
% values: 1xN or Nx1 matching LabelDataType
```

### Sublabel

```matlab
setLabelValue(lss, memberIdx, ["Parent" "Child"], ..., LabelRowIndex=k)
% LabelRowIndex selects which parent ROI/point the sublabel belongs to
```

## `createDatastores` — two modes

### Standard (time-domain labels)

```matlab
[sds, lds] = createDatastores(lss, ["Label1" "Label2" ...])
% sds: signalDatastore — read(sds) returns signal
% lds: arrayDatastore — read(lds) returns table of label values
```

### Time-frequency (R2025a)

```matlab
[sds, ads] = createDatastores(lss, "TFLabel", ...
    TimeFrequencyMapFormat="image", ...         % "image" | "matrix"
    TimeFrequencyImageSize=[H W], ...           % pixel dimensions
    TimeFrequencyLabelFormat="mask", ...         % "mask" | "table"
    TimeFrequencyMaskPriority=true);            % logical labels only
% sds: reads TF images (HxWx3 uint8 or HxW double)
% ads: reads label masks (HxW logical or HxW categorical)
```

## Canonical pattern — full pipeline

```matlab
% 1. Define labels
lblClass = signalLabelDefinition("Type", ...
    LabelType="attribute", LabelDataType="categorical", ...
    Categories=["normal" "fault"]);
lblROI = signalLabelDefinition("Event", ...
    LabelType="roi", LabelDataType="logical");

% 2. Create labeled signal set
lss = labeledSignalSet(signals, [lblClass lblROI], ...
    SampleRate=Fs, MemberNames=memberNames);

% 3. Set values
setLabelValue(lss, 1, "Type", "normal");
setLabelValue(lss, 1, "Event", [0.5 1.2; 2.0 2.8], true(2,1));

% 4. Verify
countLabelValues(lss, "Type")

% 5. Export
[sds, lds] = createDatastores(lss, ["Type" "Event"]);
```

## Signal Labeler round-trip

> **`signalLabeler` takes NO input arguments.** Do NOT write
> `signalLabeler(lss)` - it errors (`Too many input arguments`; the app
> accepts zero args since R2019a). Launch it bare, then import via the
> app menu.

```matlab
% Export to workspace, open Signal Labeler
save("myLabels.mat", "lss");
signalLabeler
% In app: Import -> From Workspace -> select lss

% After labeling in app: Export -> To Workspace -> variable name "lss"
% Continue programmatically with the updated lss
```

## Gotchas

- **`SampleRate` is read-only after creation.** Set it at construction
  time. If you need different rates per member, pass a vector.
- **Do NOT pass `SampleRate` when the source is a `signalDatastore` (or
  `audioDatastore`).** A datastore already carries inherent time information, so
  `labeledSignalSet(sds, defs, SampleRate=fs)` errors with *"'SampleRate' is not
  supported when data source has inherent time information."* Drop the argument
  (the rate comes from the datastore). `SampleRate` is only for in-memory sources
  (numeric matrix / cell of matrices) that have no time info of their own.
- **`setLabelValue` is additive for ROI/point labels.** Calling it again
  appends new regions; it doesn't replace. Use `resetLabelValues` to
  clear first, or `removeRegionValue` to delete specific rows.
- **`createDatastores` for TF labels requires the label name as a scalar
  string, not an array.** Only one TF label at a time.
- **`TimeFrequencyMaskPriority=true` only works with logical labels.**
  For categorical TF labels, omit this option.
- **Member names must be unique.** Duplicate names error at construction.
- **`Labels` table row names are the member names.** Access via
  `lss.Labels("MemberName", :)`.
- **Merging two sets requires compatible label definitions.** Same names,
  same types, same categories.

### Do-not-guess-this-API gotchas

- **`createDatastores` has NO per-member overload.** The only signatures are
  `createDatastores(lss, lblNames)` and `createDatastores(lss, lblNames, Name=Value)`.
  There is no `createDatastores(lss, idx, name)` form. For a paired-signal
  training setup, build the two datastores then `combine(sigData, lblData)`.
- **Cell-of-paths is NOT a valid `src`.** The constructor takes a numeric
  matrix, a cell array of matrices/cell-vectors, a timetable, a cell array of
  timetables, a `signalDatastore`, or an `audioDatastore` (see the Data-sources
  table above). A bare cell array of file-path strings is not accepted -- wrap
  the files in a `signalDatastore` first, then pass that.
- **`signalLabelDefinition('LabelType','roi')` rejects xywh-style limits.**
  Time-frequency bounding boxes need 2-column limits per dimension
  (`timeLimits` Nx2 + `freqLimits` Nx2 via `LabelType="roiTimeFrequency"`),
  not a single 4-column xywh row. Storing a TF box as a time-domain ROI loses
  the frequency axis. Use `roiTimeFrequency` (R2025a) -- see the TF signature
  above.

## See also

- `fn-signallabeldefinition.md` — create label definitions.
- `fn-labelspectrogramoptions.md` — TF spectrogram options.
- `fn-signalmask-getmask.md` — per-sample masks from ROI tables.
- `wf-label-and-export.md` — end-to-end labeling workflow.

----

Copyright 2026 The MathWorks, Inc.

----
