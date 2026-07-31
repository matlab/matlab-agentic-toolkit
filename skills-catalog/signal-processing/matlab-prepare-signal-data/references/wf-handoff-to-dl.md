# Workflow: hand-off to `trainnet`

> Functions used: `transform`, `combine`, `signalDatastore`, `arrayDatastore`, `trainnet`

The signal-side pipeline is done — datastore is ready, labels are aligned,
shape is per-observation. This file covers the last mile: shaping the
datastore output so `trainnet` accepts it, and the per-observation layout
each input-layer family expects.

## The `trainnet` datastore contract

`trainnet` requires the datastore to return **cell arrays or tables with
`numInputs+numOutputs` columns** — predictors first, targets last
(see `trainnet` doc, "Datastore" section under each input-data type).
For the common single-input / single-output supervised case, that is a
`1×2` cell `{predictor, response}` per `read`.

Two canonical signal-side ways to land in that shape:

### Path A — single `signalDatastore` with two variables

When predictor and response live in the same MAT file (e.g.
`spec`, `label`):

```matlab
sds = signalDatastore(folder, IncludeSubfolders=true, ...
    SignalVariableNames=["spec","label"], ReadOutputOrientation="row");
% read(sds) -> 1x2 cell: {spec, label}
trainedNet = trainnet(sds, layers, "crossentropy", options);
```

### Path B — two datastores joined with `combine`

When predictor and response live in **separate** datastores (signals on
disk; labels derived via `filenames2labels` / `folders2labels`):

```matlab
sigDs   = signalDatastore(sigFolder, FileExtensions=".mat", ...
    SignalVariableNames="signal");
labels  = filenames2labels(sigDs, Extract="Class" + lettersPattern(1));
sigDsT  = transform(sigDs, @(p) {zscoreSig(p)});   % cell-wrap is load-bearing
labelDs = arrayDatastore(labels);                  % default OutputType="cell"
cds     = combine(sigDsT, labelDs);
% read(cds) -> 1x2 cell: {signal, label}
trainedNet = trainnet(cds, layers, "crossentropy", options);
```

`combine` produces a `CombinedDatastore` whose per-read output is built
by `horzcat`ing the underlying reads. For that `horzcat` to produce the
`1×N` cell `trainnet` consumes, **every underlying datastore must emit
its value wrapped in a 1×1 cell**. The two halves of that contract:

- **Label side: `arrayDatastore(labels)` defaults to `OutputType="cell"`** —
  this is what makes the label come back as a `1×1` cell, not a bare
  scalar. Don't override to `OutputType="same"`; you'll strip the cell
  wrap and `horzcat` will try to concatenate a numeric signal with a
  categorical label — `Unable to concatenate a double array and a
  categorical array.`
- **Signal side: `transform(sigDs, @(p) {fn(p)})`** — the `{...}` around
  the function output is the cell wrap. Without it the read is a bare
  array and `horzcat` again fails with the same type-mismatch.

## Per-observation layout `trainnet` expects

`trainnet` interprets each cell-element via the input layer's data
format. The layout your datastore must emit per observation depends on
the input layer family. The shapes below are from the `trainnet` doc
(predictor tables under `images` / `sequences` / `features`).

| Input layer | Per-observation predictor shape | Format | Notes |
|---|---|---|---|
| `featureInputLayer(c)` | `1×c` row (or `c×1` col, with `InputDataFormats="CB"`) | `BC` | Tabular / per-window features. |
| `sequenceInputLayer(c)` | `s×c` (time × channel) | — | s = time steps, c = channels. **Datastore reads dim-1 as time, dim-2 as channel** — single-channel 1024-sample signal is `1024×1`, not `1×1024`. Wrong orientation triggers `Layer 'sequenceinput': Invalid size of channel dimension`. |
| `imageInputLayer([h w c])` | `h×w×c` | `SSC` (per obs) → `SSCB` batched | h, w, c = height, width, channels. |
| `image3dInputLayer([h w d c])` | `h×w×d×c` | `SSSC` (per obs) → `SSSCB` batched | 3-D images. |

> Older `trainNetwork`-era cell-array code often uses `c×s` (channel ×
> time). **That's not what a datastore read should emit.** Both modern
> `trainnet` cell arrays and datastore reads are `s×c` (time × channel).
> If your code path was originally written for the legacy cell-array
> form, drop the transpose when you migrate to a datastore.

If the read shape is right but `trainnet` still complains, the next
axis to check is the data format (`InputDataFormats` training option,
or a formatted `dlarray`); see the `trainnet` reference under
"Input Arguments" → the matching predictor section.

## End-to-end Path B (runnable, 1-D classifier)

A folder of `.mat` files, each with one `signal` variable (1024 samples,
single channel), classes encoded in the filename prefix
(`ClassA_001.mat`, `ClassB_001.mat`, ...), trained against a sequence
input layer.

```matlab
folder = "data/classify";

% 1. datastore + labels
sds    = signalDatastore(folder, FileExtensions=".mat", ...
    SignalVariableNames="signal");
labels = filenames2labels(sds, Extract="Class" + lettersPattern(1));

% 2. transform: z-score, keep 1024x1 (time-by-channel), wrap in 1x1 cell
sdsT = transform(sds, @(p) {zscoreSig(p)});

% 3. combine signal + label datastores -> {predictor, response} per read
labelDs = arrayDatastore(labels);   % default OutputType="cell"
cds     = combine(sdsT, labelDs);

% 4. small 1-D CNN
layers = [
    sequenceInputLayer(1, MinLength=1024)   % c=1; reads are 1024x1 (s×c)
    convolution1dLayer(16, 16, Padding="same")
    reluLayer
    globalAveragePooling1dLayer
    fullyConnectedLayer(3)
    softmaxLayer
];

opts = trainingOptions("adam", ...
    MaxEpochs=1, MiniBatchSize=8, Shuffle="every-epoch", ...
    Verbose=true, Plots="none");

net = trainnet(cds, layers, "crossentropy", opts);

function out = zscoreSig(p)
    if iscell(p), p = p{1}; end
    x = p(:);                       % force column -> 1024x1 (s×c)
    out = (x - mean(x)) / max(std(x), eps);
end
```

Three load-bearing details that are easy to miss:

1. **`p(:)` returns a column.** That's `1024×1` — `s×c` for the sequence
   layer. A row vector here triggers the channel-dimension error.
2. **`@(p) {zscoreSig(p)}` cell-wraps the transform output.** The `{ }`
   around the call is the wrap; without it, `combine` can't produce a
   `1×2` cell.
3. **`arrayDatastore(labels)` default `OutputType="cell"` is load-bearing.**
   Don't pass `OutputType="same"`.

## Wrapping a transform into the cell-pair shape

If you `transform` a multi-variable datastore (path A, two variables in
each MAT file), unpack with `c{1}` / `c{2}` and re-wrap:

```matlab
sdsT = transform(sds, @(c) {preprocess(c{1}), c{2}});
% per-read: 1x2 cell {predictor, response}
```

The cell-unpack idiom (`c{1}`, `c{2}`) is the same one used in
wf-frame-and-label.md step 4 for joint signal+label framing.

> **Per-observation string→categorical conversion in a transform must
> pin the category set:** `categorical(str, cats)` where
> `cats = categories(labels)` is read once upstream. Plain
> `categorical(str)` produces 1-element category sets per read;
> `trainnet` then aborts at the validation peek.

If you only have a single-variable predictor (no label in the
datastore), `transform(sds, @(p){preprocess(p)})` is a predictor-only
wrap — fine for inference, **not** sufficient for supervised training,
which still needs the response column from somewhere (path A or B).

## `OutputDataType` / `OutputEnvironment` (R2024b+)

Two `signalDatastore` properties that affect the data you hand off,
without writing a `transform`:

- `OutputDataType` — `"same"` (default) / `"double"` / `"single"`, or a
  per-variable string array. Casts each read so it matches the
  precision your network expects. Prefer this over a casting `transform`.
- `OutputEnvironment` — `"cpu"` (default) / `"gpu"`. With `"gpu"`,
  numeric reads are returned as `gpuArray`, so `trainnet` consumes
  them directly. Requires Parallel Computing Toolbox.

> **Don't confuse `signalDatastore.OutputDataType` (precision cast) with
> `arrayDatastore.OutputType` (wrap mode).** They sound alike and they
> both have a `"same"` value, but they do different things:
> `OutputDataType="same"` keeps the stored numeric class; `OutputType="same"`
> on `arrayDatastore` strips the cell wrap. For the `combine` → `trainnet`
> pattern, `arrayDatastore`'s **default `"cell"`** is what you want —
> overriding to `"same"` breaks the contract.

## When `trainnet` still complains after the read shape is right

The issue has moved past data ingestion. Check `InputDataFormats` (or a
formatted `dlarray`) against the matching predictor section in the
`trainnet` doc.

## Decision boundary — when `transform()` is enough

If `transform(sds, @fn)` returns the per-observation cell-pair shape
above, `trainnet(sdsT, layers, lossFn, opts)` is the next call.

If you need:
- **Custom batching** (e.g. grouping by sequence length) → `minibatchqueue`.
- **GPU prefetching** → either set `OutputEnvironment="gpu"` on the
  `signalDatastore`, or use `minibatchqueue` with `OutputEnvironment="gpu"`.
- **Per-batch transformations** → `minibatchqueue` with a `MiniBatchFcn`.

## See also

- wf-load-and-split.md — produces the datastore that feeds in here.
- wf-frame-and-label.md — joint framing recipe; step 4 shows the same
  `c{1}` / `c{2}` cell-unpack idiom.
- fn-signaldatastore.md — `OutputDataType` / `OutputEnvironment` full
  surface and SignalVariableNames variations.

----

Copyright 2026 The MathWorks, Inc.

----
