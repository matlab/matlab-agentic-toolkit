# Workflow: label signals + export for training / Signal Labeler

> Functions used: `signalLabelDefinition`, `labeledSignalSet`,
> `labelSpectrogramOptions`, `setLabelValue`, `getLabelValues`,
> `createDatastores`, `countLabelValues`

Define labels programmatically, populate them, verify, and export — either
to datastores for `trainnet` or to Signal Labeler for manual review /
refinement.

> **Off-ramp.** If you only need per-sample masks from an ROI table
> (no `labeledSignalSet` needed), see fn-signalmask-getmask.md.
> If your signals are one-label-per-file with no ROI structure, the
> `filenames2labels` path in wf-load-and-split.md may be simpler.

## When to use this workflow

- You have signals + external annotation data (CSV, JSON, metadata) and
  want to wrap them into a `labeledSignalSet` for Signal Labeler or DL.
- You need time-frequency bounding-box labels (R2025a+).
- You want programmatic labels that can be visually verified in Signal
  Labeler before training.
- You're building a labeled dataset from scratch with mixed label types
  (attributes + ROIs + points on the same signals).

---

## Recipe

### Step 1 — Choose label types

| Your annotation shape | LabelType | LabelDataType |
|---|---|---|
| One class per signal (e.g., "normal" / "fault") | `"attribute"` | `"categorical"` |
| Binary flag per signal (e.g., "contains_voice") | `"attribute"` | `"logical"` |
| Time regions (e.g., burst start/end) | `"roi"` | `"logical"` or `"categorical"` |
| Time instants (e.g., peaks, onsets) | `"point"` | `"numeric"` |
| Time-freq bounding boxes (e.g., wireless signals) | `"roiTimeFrequency"` | `"logical"` or `"categorical"` |
| Numeric feature per signal (e.g., SNR) | `"attribute"` | `"numeric"` |

### Step 2 — Create label definitions

```matlab
% Attribute: signal-level class
lblClass = signalLabelDefinition("SignalType", ...
    LabelType="attribute", ...
    LabelDataType="categorical", ...
    Categories=["WLAN" "BT" "LTE" "noise"]);

% ROI: time-domain events
lblEvent = signalLabelDefinition("Event", ...
    LabelType="roi", ...
    LabelDataType="categorical", ...
    Categories=["burst" "interference"]);

% Point: detected peaks
lblPeak = signalLabelDefinition("Peak", ...
    LabelType="point", ...
    LabelDataType="numeric");

% TF ROI: time-frequency bounding box (R2025a)
opts = labelSpectrogramOptions("leakage", ...
    Leakage=20, Overlap=90, ...
    TimeResolutionMode="specify", TimeResolution=0.1e-3);

lblTF = signalLabelDefinition("TFSignal", ...
    LabelType="roiTimeFrequency", ...
    LabelDataType="categorical", ...
    Categories=["WLAN" "BT" "LTE"], ...
    TimeFrequencyOptions=opts);
```

### Step 3 — Create the labeled signal set

```matlab
% From cell array of signals
lss = labeledSignalSet(signals, [lblClass lblEvent lblPeak lblTF], ...
    SampleRate=Fs, ...
    MemberNames=memberNames);
```

Or from a `signalDatastore`:

```matlab
sds = signalDatastore(dataFolder, FileExtensions=".mat");
lss = labeledSignalSet(sds, [lblClass lblEvent lblPeak lblTF]);
```

> **Make each member signal finite before you build the lss.** A
> `labeledSignalSet` (and Signal Labeler) should not carry `NaN` in the signal
> data, whatever the source - raw dropouts, sensor outages, a `MaxGap`-gated
> fill that deliberately left wide gaps `NaN`, or the endpoint `NaN` that
> `synchronize`/alignment leaves when one channel starts late or ends early.
> `labeledSignalSet` stores `NaN` without erroring at construction, so the
> problem is silent: the `NaN`s then propagate into the Signal Labeler display
> and into anything you train. Handle them first via wf-repair-missing.md
> (fill, or gate + accept truncation), then verify with
> `assert(all(isfinite(sig)))` per member before constructing the set. If the
> `NaN`s are endpoint gaps on an oscillatory channel (a common alignment
> leftover), that fill is bare `fillgaps(x)`, not
> `fillmissing(..., EndValues=...)`, and never a drop-the-NaN-rows crop - see
> wf-align-channels.md step 4.

### Step 4 — Populate labels

**Attribute:**
```matlab
setLabelValue(lss, k, "SignalType", "WLAN");
```

**ROI (time-domain):**
```matlab
roiLimits = [0.1 0.5; 0.7 1.2];          % Nx2 seconds
values = categorical(["burst"; "interference"], ...
    ["burst" "interference"]);
setLabelValue(lss, k, "Event", roiLimits, values);
```

**Point:**
```matlab
peakLocs = [0.23; 0.89; 1.45];           % seconds
peakAmps = [0.95; 1.2; 0.7];             % numeric values
setLabelValue(lss, k, "Peak", peakLocs, peakAmps);
```

**Time-frequency ROI:**
```matlab
timeLimits = [tStart tEnd];               % Nx2 seconds
freqLimits = [fLow fHigh];               % Nx2 Hz
values = categorical(classes, categories);
setLabelValue(lss, k, "TFSignal", timeLimits, freqLimits, values);
```

### Step 5 — Verify

```matlab
% Class balance
countLabelValues(lss, "SignalType")

% Inspect specific member
getLabelValues(lss, 1, "Event")
getLabelValues(lss, 1, "TFSignal")

% Visual check with signalMask (for time-domain ROIs)
rois = getLabelValues(lss, k, "Event");
msk = signalMask(rois, SampleRate=Fs);
plotsigroi(msk, signal);
```

### Step 6a — Export to datastores for training

> **Before you call `createDatastores`,** check its exact signature in
> fn-labeledsignalset.md - it has no per-member form and won't take a bare cell
> of file paths. That page lists the three API-shape traps to avoid here.

**Time-domain labels:**
```matlab
[sds, lds] = createDatastores(lss, ["SignalType" "Event"]);
% Use with trainnet, combine, etc.
```

**TF labels as image + mask (for detection/segmentation networks):**
```matlab
[tfDS, maskDS] = createDatastores(lss, "TFSignal", ...
    TimeFrequencyMapFormat="image", ...
    TimeFrequencyImageSize=[256 512], ...
    TimeFrequencyLabelFormat="mask");
```

**TF labels as image + mask (logical labels with priority):**
```matlab
[tfDS, maskDS] = createDatastores(lss, "TFLogicalLabel", ...
    TimeFrequencyMapFormat="image", ...
    TimeFrequencyImageSize=[512 768], ...
    TimeFrequencyLabelFormat="mask", ...
    TimeFrequencyMaskPriority=true);
```

### Step 6b — Export to Signal Labeler for manual review

> **`signalLabeler` takes NO input arguments.** Do NOT write
> `signalLabeler(lss)` - it errors (`Too many input arguments`; the app
> accepts zero args since R2019a). Launch it bare, then in the app use
> Import -> From Workspace -> select the `lss` variable, or Import ->
> From File -> the saved `.mat`.

```matlab
% Save to file
save("labeled_dataset.mat", "lss");

% Open Signal Labeler
signalLabeler
% Then: Import -> From Workspace -> select "lss"
```

In Signal Labeler:
- Time-domain ROI labels appear as shaded regions on the time plot.
- Time-frequency ROI labels appear as rectangles on the spectrogram view.
- Use Display -> Spectrogram to visualize TF labels.
- After manual edits: Export -> To Workspace.

---

## Batch labeling from external annotations

Common pattern: CSV/JSON with per-file annotations -> loop to populate.

```matlab
annotations = readtable("labels.csv");
% Columns: File, tStart, tEnd, fLow, fHigh, Class

sds = signalDatastore(dataFolder);
lss = labeledSignalSet(sds, lblTF);

for k = 1:lss.NumMembers
    [~, fname] = fileparts(sds.Files{k});
    rows = annotations(strcmp(annotations.File, fname), :);   % strcmp handles char/string/cellstr; == errors on cellstr
    if ~isempty(rows)
        timeLims = [rows.tStart rows.tEnd];
        freqLims = [rows.fLow rows.fHigh];
        vals = categorical(rows.Class, categories);
        setLabelValue(lss, k, "TFSignal", timeLims, freqLims, vals);
    end
end
```

---

## Anti-patterns

| Anti-pattern | Why | Instead |
|---|---|---|
| Building `signalMask` + `catmask` when you need a `labeledSignalSet` | Two different containers; you can't open a `signalMask` in Signal Labeler | Use `labeledSignalSet` with ROI labels |
| Storing TF bounding boxes as time-domain ROI labels | Loses frequency information; can't visualize in spectrogram view | Use `LabelType="roiTimeFrequency"` (R2025a) |
| Hard-coding spectrogram parameters separately from label definition | Labels drift from visualization | Put params in `labelSpectrogramOptions` and attach to the definition |
| Calling `setLabelValue` in a loop without checking existing values | Additive — duplicates accumulate | Call `resetLabelValues` first if repopulating |
| Using `createDatastores` with array of TF label names | Only scalar string supported for TF labels | One TF label per `createDatastores` call |

---

## Next in the chain

- **Already have per-file labels, no ROI structure?** -> wf-load-and-split.md
- **Need per-sample masks from ROI table?** -> fn-signalmask-getmask.md
- **Need per-frame labels from ROI table?** -> wf-frame-and-label.md
- **Ready to train?** -> wf-handoff-to-dl.md

----

Copyright 2026 The MathWorks, Inc.

----
