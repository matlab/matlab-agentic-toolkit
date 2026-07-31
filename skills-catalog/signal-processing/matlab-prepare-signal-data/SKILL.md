---
name: matlab-prepare-signal-data
description: |
  Use this skill when conditioning, loading, preparing, or labeling signal
  data for analysis or ML training. Covers: cleaning a single signal (fill
  gaps, remove drift, deoutlier, denoise, resample/align a time base) BEFORE
  analysis; building a `signalDatastore` pipeline; creating a `labeledSignalSet`
  for Signal Labeler; deriving labels (filename, folder, in-file, ROI,
  time-frequency ROI); stratified train/val/test splits; framing long signals;
  parallel processing; and shaping datastore output for `trainnet`.

  Triggers include "clean up this signal", "remove drift / detrend", "fill
  gaps", "remove spikes / outliers", "denoise", "resample to a uniform rate",
  "align channels", "labels from filenames", "stratified split", "prepare for
  Signal Labeler", and function names like `fillgaps`, `fillmissing`,
  `detrend`, `filloutliers`, `smoothdata`, `resample`, `synchronize`,
  `signalDatastore`, `labeledSignalSet`, `filenames2labels`, `folders2labels`,
  `splitlabels`, `framesig`, `framelbl`, `createDatastores`.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Prepare Signal Data

> **Look in Signal Processing Toolbox first.** The conditioning, labeling,
> splitting, framing, and partitioning helpers here live in Signal Processing
> Toolbox — not in Stats & ML Toolbox or generic-MATLAB string utilities.

The arc: **condition** a raw signal (clean it) -> **load** a folder into a
datastore -> **label** -> **split / frame** -> **hand off** to `trainnet`. Each
stage is a workflow file; this page routes you to the right one.

## When to Use

- Cleaning a single signal before analysis: fill gaps, remove drift, deoutlier,
  denoise, put it on a uniform time base, align multiple channels.
- Loading / preparing signal data for ML training: datastores, labels from
  filenames or folders, stratified splits, framing, parallel processing.
- Structured labeling: `labeledSignalSet` for Signal Labeler, all label types.

## When NOT to Use

- **Raw `.wav` audio classification with Audio Toolbox available.**
  `audioDatastore` is the canonical path (this skill's custom-`ReadFcn`
  workflow handles `.wav` only when Audio Toolbox is absent —
  references/wf-custom-readfcn.md).
- **Frequency-selective filter DESIGN** (band isolation, notch, custom FIR/IIR)
  — see the `matlab-design-digital-filter` skill. This skill's conditioning is
  about cleaning, not designing filters.
- **Computing per-frame features** (RMS, crest factor, spectral / bandwidth,
  time-frequency features) from an already-conditioned signal — see the
  `matlab-extract-signal-features` skill. This skill's `framesig` / `framelbl`
  are for manual per-window labeling / supervision, not for deriving a feature
  table; the `signal*FeatureExtractor` objects window internally and emit the
  table.

## Best practices

- **Deliverable is a runnable `.m` script** the user can save, version, and
  re-run — not workspace state.
- **Prefer the highest-level function that does the job.** `detrend` /
  `smoothdata` / `fillmissing` / `resample` read cleanly and are easy for a
  non-expert to follow. Drop to a lower-level / more-configurable path
  (`designfilt` + `filtfilt`, a hand-built AR model, a named primitive) only
  when you need control the high-level call cannot give, or when the user asks.
  Readability first; escalate to low-level for necessity, not by default.
  - The high-level call usually exposes the control you think you need. In
    particular `smoothdata(x, "sgolay", fl)` takes the frame length `fl` as an
    argument — it does NOT hide it — so prefer it over calling `sgolayfilt`
    directly. Reach for `sgolayfilt` only for what the dispatcher genuinely
    lacks (derivative output via `dn`, or an unusual polynomial order).

## 0. Common reflexes

If your first instinct is one of these, the canonical replacement is one row away.

| Reflex | Canonical | Detail |
|---|---|---|
| Hand-design a highpass/`designfilt` to remove a smooth drift | `detrend(x, n)` — escalate `n` = 1 -> 2 -> 3 before reaching for a filter; polynomial detrend has unity passband gain | references/fn-detrend.md |
| Invent a gap-filler (`regularizeNaNs`, `inpaintn` — not real) | `fillmissing` (interp) for short gaps; `fillgaps` (SPT, AR) for long gaps in oscillatory signals | references/wf-repair-missing.md |
| Hand-roll `retime` + shift + `retime` + concat to align channels | `synchronize(A, B, ...)` — one call to a shared grid | references/wf-align-channels.md |
| Custom `ReadFcn` for a `.csv` | `signalDatastore` default reader + `SignalVariableNames` | references/fn-signaldatastore.md |
| `cvpartition` for a datastore split | `splitlabels` + `subset(ds, idx{k})` | references/fn-splitlabels.md |
| `regexp` / `extractBefore` / `fileparts` for labels from filenames | `filenames2labels(sds, Extract=...)` | references/fn-filenames2labels.md |
| `regexp` / nested `fileparts` for labels from subfolders | `folders2labels(sds.Files)` | references/fn-folders2labels.md |
| Manual framing loop with `(i-1)*hop+1` | `framesig(x, fl, OverlapLength=...)` | references/wf-frame-and-label.md |
| Manual ROI-to-frame vote with `containers.Map` | `framelbl(rois, ...)` | references/wf-frame-and-label.md |
| `for` loop `load(file)` to read in-file label variables | `signalDatastore(folder, SignalVariableNames=["x","label"])` | references/fn-signaldatastore.md |
| `signalMask` when you need Signal Labeler interop | `labeledSignalSet` with ROI labels (signalMask can't import) | references/fn-labeledsignalset.md |
| `signalLabeler(lss)` (pass the set as an arg) | Launch bare `signalLabeler` (zero args), then Import -> From Workspace or From File | references/wf-label-and-export.md |

> **SPT-specialized functions exist — reach for them, don't reinvent.**
> `fillgaps` (AR gap fill), `medfilt1` / `hampel` (impulse handling),
> `sgolayfilt` / `smoothdata(...,"sgolay")` (feature-preserving smoothing) are
> in Signal Processing Toolbox.

## 1. Workflows

Each workflow file is the entry point and lists the functions it uses. Start here.

| Workflow | Use when | Reference |
|---|---|---|
| **Repair missing samples** | NaN gaps / dropouts to fill. | references/wf-repair-missing.md |
| **Detrend, smooth, deoutlier** | Drift, spikes, and/or broadband noise on one signal (smoothing/denoising lives here). | references/wf-detrend-smooth-deoutlier.md |
| **Align multi-rate / offset channels** | Several channels onto a shared time base. | references/wf-align-channels.md |
| **Put one channel on a uniform rate** | One channel -> uniform grid at a chosen rate: jittery timestamps to regularize, OR already uniform but the wrong rate to `resample`. | references/wf-uniform-rate.md |
| **Wavelet denoising (escalation)** | Non-stationary/multi-scale noise a tuned `sgolayfilt` can't remove; `wdenoise` (Wavelet TB). | references/wf-denoise.md |
| **Envelope extraction** | Amplitude outline (AM demod, peak hull) — not cleaning. | references/wf-envelope.md |
| **Load + label + split** | Folder of files -> datastore for training. | references/wf-load-and-split.md |
| **Frame long signals + per-frame labels** | Long signals, per-window supervision. | references/wf-frame-and-label.md |
| **Label + export (all label types)** | Structured labels (attribute/ROI/point/TF-ROI), export to Signal Labeler / DL. | references/wf-label-and-export.md |
| **Parallel processing across a parpool** | Per-signal work across workers. | references/wf-parallel-process.md |
| **Custom ReadFcn (only when needed)** | Format isn't `.mat` / `.csv`, or has a metadata prelude. | references/wf-custom-readfcn.md |
| **Hand-off to `trainnet`** | Datastore ready; shape for `trainnet` / `combine`. | references/wf-handoff-to-dl.md |

> Each workflow file names the `fn-` reference pages for the functions it uses;
> there is no separate function index — enter through the workflow that matches
> your task, or the reflex table above.

## 2. Ordering when a signal needs several conditioning steps

**The governing principle (this is the real rule):** order the steps so an
earlier operation does not corrupt the input to a later one. Spikes bias
least-squares fits and get smeared by filters/resamplers; an un-removed trend
gets averaged into the signal by a smoother; most operations choke on `NaN`.
Reason from that for the signal in front of you — do not follow a fixed chain
blindly.

**Default heuristic** (a good starting order, not a universal law):

**outliers -> detrend -> smooth**, with fill and align placed by the principle above.

- **outliers -> detrend -> smooth** is the verified core: remove spikes before
  a polynomial `detrend` (a spike biases the fit) and before a smoother (a
  smoother spreads the spike across its window); detrend before smooth so the
  smoother isn't averaging across a trend.
- **Fill** `NaN` before any step that can't handle missing data (detrend,
  filters, most smoothers).
- **Align / resample:** putting a signal on a new grid (`retime`/`synchronize`)
  *creates* `NaN` at non-overlapping times, so fill after aligning. BUT if the
  signal has spikes, deoutlier *before* resampling — `resample`'s anti-alias
  filter will smear an un-removed spike. So align-vs-outliers order depends on
  the signal; the principle decides, not a fixed sequence.

Not every signal needs every step — identify which apply, order them by the
principle, and each workflow file has an off-ramp if your problem is actually a
different family.

----

Copyright 2026 The MathWorks, Inc.

----
