# Function: `framelbl`

> Used in: wf-frame-and-label.md
> Toolbox: Signal Processing Toolbox

Collapse a per-sample ROI label table into **per-frame** labels, using a
frame schedule that matches `framesig`. Replaces the hand-rolled
`containers.Map` accumulator and the most-prevalent voting loop.

## Signature

```matlab
frameLabels = framelbl(x, frameLength)
frameLabels = framelbl(x, frameLength, Name=Value, ...)
[frameLabels, fnlcond] = framelbl(___)               % final condition for streaming (overlap)
[frameLabels, fnlcond, fnlidx] = framelbl(___)       % + final index for streaming (underlap)
```

`x` is the input label sequence — accepts:
- **categorical** vector
- **string** array
- **numeric** array
- **logical** matrix (one column per category)
- **ROI table** (start/end limits + label per row — the most common form)

Output shape depends on `ConsolidationMethod`:

- **Consolidated** (`ConsolidationMethod` set to `"mode"` / `"priority"` /
  `"max"` / `"median"` / `"mean"`): returns a `1 × numFrames` row vector of
  per-frame consolidated labels, aligned with `framesig`'s column index.
- **Non-consolidated** (`ConsolidationMethod="none"`, the default): returns
  an `fl × numFrames` matrix for string / numeric / logical inputs (one
  column per frame, one row per sample within that frame). Categorical
  input returns the same per-sample-per-frame layout as a categorical
  matrix.

## Name-value arguments (all 11)

Valid combinations depend on input type — see the cross-table below.

| NV-pair | Default | Purpose |
|---|---|---|
| `InputLabelMode` | `"mask"` | `"mask"` = each element of `x` is a per-sample label; `"attribute"` = `x` is a single label that applies to every sample (requires `SignalLength`). |
| `SignalLength` | inferred from ROI / required for `"attribute"` | Length of the underlying signal in samples. Must exceed `frameLength`. For ROI tables, defaults to `max(ROILimits)`. |
| `SampleRate` | unset | Positive scalar; only valid when `x` is an ROI table. When set, ROI limits are interpreted in **seconds** and converted to sample indices (rounded to nearest integer). |
| `Categories` | inferred | String array naming logical-matrix columns. Only valid when `x` is a logical matrix. |
| `ConsolidationMethod` | `"none"` | How to collapse multiple labels in a frame: `"none"` (no collapse — return raw per-frame), `"mode"` (most-prevalent vote), `"priority"` (rank-based, requires `PriorityList`), `"max"` (numeric / ordinal categorical), `"median"` (numeric / ordinal), `"mean"` (numeric only). Type restrictions: categorical/string allow only `"mode"` / `"priority"` (or `"median"` / `"max"` for ordinal); numeric forbids `"priority"`. |
| `PriorityList` | inferred | Rank-ordered list of unique labels for `ConsolidationMethod="priority"` (or for ROI / logical inputs). Highest priority first. Defaults to lex-ordered for non-logical, or `Categories` for logical. |
| `OverlapLength` | `0` | Samples shared between adjacent frames. **Must match `framesig`**'s `OverlapLength`. Mutually exclusive with `UnderlapLength`. |
| `UnderlapLength` | `0` | Samples skipped between adjacent frames. Mutually exclusive with `OverlapLength`. |
| `InitialCondition` | `[]` | Stacks on top of `x` along the framing dimension. Must match `x`'s data type and shape. For ROI-table inputs, must also be an ROI table whose limits don't overlap the input. Forbidden when `InputLabelMode="attribute"`. |
| `InitialIndex` | `1` | Index of the first sample to start framing from. `InitialIndex - 1` samples at the start are discarded. |
| `IncompleteFrameRule` | `"drop"` | What to do with the trailing partial frame: `"drop"` discards it; `"padwithmissing"` pads with `<undefined>` / `<missing>` / `<false>` / `NaN` depending on label type. (Note: this is `"padwithmissing"`, not `"zeropad"` as in `framesig`.) |

> Setting both `OverlapLength` and `UnderlapLength` is an error — they are
> alternative scheduling modes, not stackable. **Don't pass both names even
> at default values** (e.g. `OverlapLength=0, UnderlapLength=4` errors too).
> Pass at most one.

## Canonical pattern

```matlab
% Frame the signal:
frames = framesig(x, 1024, OverlapLength=512);

% Frame the labels with the same schedule:
frameLabels = framelbl(rois, 1024, OverlapLength=512, ...
    ConsolidationMethod="mode");

% frames(:, k) and frameLabels(k) are aligned.
```

## `ConsolidationMethod` — the default surprises you

The default is `"none"`, which returns an **`fl × numFrames` matrix of raw
per-sample labels**, not the `1 × numFrames` row of one-label-per-frame a
training pipeline usually wants. Pass an explicit `ConsolidationMethod` (and
read it as a named arg so the choice is visible), e.g.:

```matlab
frameLabels = framelbl(rois, 1024, OverlapLength=512, ConsolidationMethod="mode");
```

Choosing *which* method - `"mode"` (most-prevalent vote) vs `"priority"` (when
labels nest), and the ROI-containment check that decides it - is the workflow
decision: see wf-frame-and-label.md ("Decision point — ConsolidationMethod").
The mechanism that forces `"priority"` when labels nest is the containment trap
below.

## Anti-pattern — hand-rolled most-prevalent voting

Don't accumulate per-sample labels into a `containers.Map` and pick the
most-prevalent — that has a containment trap.

```matlab
% Bad — hand-rolled voting buries the containment trap:
labelMap = containers.Map();
for k = 1:numFrames
    frameStart = (k-1)*hopSize + 1;
    frameEnd   = frameStart + frameLength - 1;
    % ... look up labels in [frameStart, frameEnd], count, pick max ...
end

% Good:
frameLabels = framelbl(rois, frameLength, OverlapLength=overlap, ...
    ConsolidationMethod="mode");
```

### The containment trap

If label A's ROI fully contains label B's ROI inside a frame, a
most-prevalent vote always picks A — label B never wins, even when B is
the more semantically important class (e.g. "voiced speech" inside
"speech"). When labels nest, **use `ConsolidationMethod="priority"` with
an explicit `PriorityList`**, not most-prevalent.

```matlab
% Containment-trap-safe — voiced wins inside speech:
frameLabels = framelbl(rois, 1024, OverlapLength=512, ...
    ConsolidationMethod="priority", ...
    PriorityList=["voiced", "unvoiced", "speech", "silence"]);
```

## Gotchas

- **`OverlapLength` must match `framesig`.** The two functions schedule
  frames independently; only matching parameters keep them aligned.
- **Output shape depends on `ConsolidationMethod`.** With a consolidation
  method set, the output is `1 × numFrames` — index with the same `k` you'd
  use into `framesig`'s column index. With the default `"none"`, the output
  is `fl × numFrames` (sample-within-frame down rows, frames across
  columns); index frame `k` as `out(:, k)`. *Don't* expect a row vector in
  the default case.
- **An ROI shorter than a hop can fall in zero frames** if the hop steps
  over it. Tighten the hop or pre-validate ROI durations.
- **An ROI longer than the signal** is silently clamped — no error.

## See also

- `fn-framesig.md` — the signal-side counterpart.
- `wf-frame-and-label.md` — joint recipe.
- `fn-signalmask-getmask.md` — for per-sample (not per-frame) labels.

----

Copyright 2026 The MathWorks, Inc.

----
