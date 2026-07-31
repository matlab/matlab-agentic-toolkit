# Function: `signalLabelDefinition`

> Used in: wf-label-and-export.md
> Toolbox: Signal Processing Toolbox
> Since: R2018b (roiTimeFrequency since R2025a)

Create signal label definitions for use with `labeledSignalSet`.

## Signatures

```matlab
sld = signalLabelDefinition(name)
sld = signalLabelDefinition(name, Name=Value)
```

## Label types (`LabelType`)

| Type | Describes | ROI limits | Freq limits | Example |
|---|---|---|---|---|
| `"attribute"` (default) | Whole-signal characteristic | — | — | Signal class, patient ID |
| `"roi"` | Time-domain region of interest | Nx2 `[start end]` (seconds or samples) | — | Moan region, QRS complex |
| `"point"` | Time-domain point of interest | Scalar locations | — | R-peak, onset |
| `"roiTimeFrequency"` | Time-frequency bounding box | Nx2 `[tStart tEnd]` (seconds) | Nx2 `[fLow fHigh]` (Hz) | Wireless burst, spectral event |
| `"attributeFeature"` | Signal-level feature (auto-extracted) | — | — | RMS, spectral centroid |
| `"roiFeature"` | Per-frame feature over ROI | Frame-level | — | Per-window energy |

## Properties

| Property | Applies to | Type | Default | Notes |
|---|---|---|---|---|
| `Name` | all | string | (required) | Unique within a labeledSignalSet |
| `LabelType` | all | string | `"attribute"` | See table above |
| `LabelDataType` | all | string | `"logical"` | `"logical"` \| `"categorical"` \| `"numeric"` \| `"string"` \| `"table"` \| `"timetable"` |
| `Categories` | categorical only | string array | — | Required when `LabelDataType="categorical"` |
| `DefaultValue` | all | matches LabelDataType | `[]` | Must be in `Categories` if categorical |
| `ValidationFunction` | logical/numeric/table/timetable | function_handle | — | `@(x) x > 0` etc. |
| `Description` | all | string | `""` | Free text |
| `Tag` | all | string | `""` | Cross-reference identifier |
| `Sublabels` | attribute, roi, point, roiTimeFrequency | signalLabelDefinition vector | — | Children; sublabels cannot have sublabels |
| `ROILimitsDataType` | roi, roiFeature | `"double"` \| `"duration"` | `"double"` | Do NOT set for roiTimeFrequency |
| `PointLocationsDataType` | point | `"double"` \| `"duration"` | `"double"` | |
| `TimeFrequencyOptions` | roiTimeFrequency | `labelSpectrogramOptions` | — | See fn-labelspectrogramoptions.md |
| `MemberChannel` | roiTimeFrequency | positive integer | — | Which channel for TF map (R2025a) |
| `FrameSize` | roiFeature | positive integer | — | Required for roiFeature |
| `FrameOverlapLength` | roiFeature | nonneg integer | `0` | Cannot combine with FrameRate |
| `FrameRate` | roiFeature | positive scalar | `0` | Cannot combine with FrameOverlapLength |

## Object functions

| Function | Returns |
|---|---|
| `labelDefinitionsHierarchy(lss)` | Hierarchical text listing labels and sublabels |
| `labelDefinitionsSummary(lss)` | Table summarizing all definitions |

## Canonical patterns

### Attribute (whole-signal class)

```matlab
lblClass = signalLabelDefinition("SignalClass", ...
    LabelType="attribute", ...
    LabelDataType="categorical", ...
    Categories=["normal" "anomaly" "artifact"]);
```

### ROI (time-domain region)

```matlab
lblRegion = signalLabelDefinition("BurstRegion", ...
    LabelType="roi", ...
    LabelDataType="logical");
```

### ROI with categorical values

```matlab
lblSegment = signalLabelDefinition("Segment", ...
    LabelType="roi", ...
    LabelDataType="categorical", ...
    Categories=["speech" "music" "silence"]);
```

### Point (time-domain event)

```matlab
lblPeak = signalLabelDefinition("RPeak", ...
    LabelType="point", ...
    LabelDataType="numeric", ...
    Description="R-peak amplitude");
```

### Time-frequency ROI (R2025a)

```matlab
opts = labelSpectrogramOptions("leakage", ...
    Leakage=32, Overlap=90, ...
    TimeResolutionMode="specify", TimeResolution=0.05);

lblTF = signalLabelDefinition("Signal", ...
    LabelType="roiTimeFrequency", ...
    LabelDataType="categorical", ...
    Categories=["WLAN" "BT" "LTE"], ...
    TimeFrequencyOptions=opts);
```

### Sublabels

```matlab
lblPeaks = signalLabelDefinition("Peaks", ...
    LabelType="point", LabelDataType="numeric");
lblTrill = signalLabelDefinition("Trill", ...
    LabelType="roi", LabelDataType="logical", ...
    Sublabels=lblPeaks);
```

## `setLabelValue` call signatures by type

| LabelType | Syntax |
|---|---|
| attribute | `setLabelValue(lss, memberIdx, "Name", value)` |
| roi | `setLabelValue(lss, memberIdx, "Name", roiLimits, values)` |
| point | `setLabelValue(lss, memberIdx, "Name", locations, values)` |
| roiTimeFrequency | `setLabelValue(lss, memberIdx, "Name", timeLimits, freqLimits, values)` |
| sublabel | `setLabelValue(lss, memberIdx, ["Parent" "Child"], ..., LabelRowIndex=k)` |

Where:
- `roiLimits` — Nx2 `[start end]` in seconds (or samples if no SampleRate)
- `timeLimits` — Nx2 `[tStart tEnd]` in seconds
- `freqLimits` — Nx2 `[fLow fHigh]` in Hz
- `values` — scalar, vector, or array matching N

## Gotchas

- **`roiTimeFrequency` requires `TimeFrequencyOptions`.** Omitting it
  creates the definition but labels won't render correctly in Signal
  Labeler.
- **Don't set `ROILimitsDataType` for `roiTimeFrequency`.** It's only for
  time-domain `"roi"` and `"roiFeature"`.
- **Sublabels cannot have sublabels.** Only one level of nesting.
- **`Categories` must be unique strings.** Duplicate categories error at
  construction time.
- **`createDatastores` with `TimeFrequencyMaskPriority=true` requires
  `LabelDataType="logical"`.** For categorical TF labels, omit that
  option and use `TimeFrequencyLabelFormat="mask"` alone.
- **Label names must be valid MATLAB identifiers.** They become table
  variable names in `lss.Labels`.

## See also

- `fn-labeledsignalset.md` — container that holds these definitions.
- `fn-labelspectrogramoptions.md` — TF spectrogram options.
- `wf-label-and-export.md` — end-to-end labeling workflow.

----

Copyright 2026 The MathWorks, Inc.

----
