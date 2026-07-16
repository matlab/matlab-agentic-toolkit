# `extract` function — input contract, output shape, common errors

`extract(sFE, x)` runs a configured extractor on a signal. The contract is largely shared across the three extractors, with documented per-extractor differences below.

## Input contract

| Input | Requirement |
|---|---|
| `sFE` | A configured `signalTimeFeatureExtractor`, `signalFrequencyFeatureExtractor`, or `signalTimeFrequencyFeatureExtractor` with at least one feature flag enabled. |
| `src` | The signal source. A column vector `(L × 1)` of real `double` (or `gpuArray` of doubles when the GPU path is in use), a `timetable`, or a file-backed `signalDatastore` / `audioDatastore`. |

**Single-vector input is the common case;** `extract(sFE, x)` on one column vector returns one result. When `src` is a datastore, `extract` iterates every file — see "Batch extraction over a datastore" below.

**Multichannel signals are not supported.** A matrix `(L × C)` will raise an error. Split into per-channel calls and concatenate the resulting tables host-side.

**Length requirement.** With the default `IncompleteFrameRule="drop"`, `length(x) >= FrameSize`. If the signal is shorter, `extract` returns an empty result (zero rows). Use `IncompleteFrameRule="zeropad"` to keep the last partial frame.

## Output shape

Driven by `FeatureFormat`.

### `FeatureFormat="matrix"` (default)

A `[numFrames, numColumns]` numeric matrix.

- Scalar features contribute one column each.
- Vector-valued features (`WelchPSD`, multi-peak `PeakAmplitude` / `PeakLocation`, most TF features) contribute multiple columns whose count depends on parameters.

When mixing scalar and vector features, prefer `FeatureFormat="table"` — the matrix layout loses column identity.

### `FeatureFormat="table"` (recommended for mixed features)

A table with:

- `FrameStartTime`, `FrameEndTime` as the first two columns. **These are 1-indexed sample positions, not seconds.** Convert: `tSec = (T.FrameStartTime - 1) / fs`.
- One column per enabled feature, named after the feature flag.
- Vector-valued columns are numeric matrices when per-frame length is fixed across frames, **cell columns** when length varies. Check before indexing:

  ```matlab
  if iscell(T.WelchPSD)
      psd = T.WelchPSD{k};
  else
      psd = T.WelchPSD(k, :);
  end
  ```

Strip `FrameStartTime` / `FrameEndTime` before passing the table to a classifier — they are positional metadata, not features.

## Per-extractor specifics

| Extractor | Output character |
|---|---|
| `signalTimeFeatureExtractor` | All features scalar per frame — output has one column per enabled feature. |
| `signalFrequencyFeatureExtractor` | `WelchPSD`, multi-peak `PeakAmplitude`/`PeakLocation` are vector-valued; the rest are scalar. |
| `signalTimeFrequencyFeatureExtractor` | Most features are vector-valued and gated by the `Transform` choice. See `signal-time-frequency-feature-extractor.md` for the compatibility matrix. |

## Combining outputs across extractors

To row-align tables from two extractors (e.g., time + frequency on the same signal), configure both with the **same `SampleRate`, `FrameSize`, and `FrameOverlapLength`** so the per-frame indices align. Then:

```matlab
T = [Ttime(:, 3:end), Tfreq(:, 3:end)];     % drop FrameStartTime/EndTime from one
T.FrameStartTime = Ttime.FrameStartTime;
T.FrameEndTime   = Ttime.FrameEndTime;
```

A worked end-to-end pattern for combining is deferred to v1.1; this reference describes the contract that makes it possible.

## Batch extraction over a datastore (parallel)

When `src` is a file-backed `signalDatastore` or `audioDatastore`, `extract` runs once per file and returns a **cell array, one entry per file** — not a single concatenated table:

```matlab
sds  = signalDatastore(dataDir, SampleRate=fs, SignalVariableNames="x");
feats = extract(sFE, sds);          % N-by-1 cell; feats{k} is the table/matrix for file k
```

Pass `UseParallel=true` to distribute files across a parallel pool (requires Parallel Computing Toolbox — an optional accelerator, not needed for serial extraction):

```matlab
feats = extract(sFE, sds, UseParallel=true);   % same cell-array shape, files processed on workers
```

Notes verified in R2026a:

- **Return shape is identical** with and without `UseParallel` — an `N × 1` cell array. Only the wall-clock time changes.
- **A pool is started automatically** on the first `UseParallel=true` call if none is open, so that first call carries a one-time pool-startup cost (tens of seconds). The pool stays alive for subsequent calls — measure speedup on a warm pool, not the first run.
- **Speedup scales with worker count and is bounded by file I/O.** A real 3000-file extraction dropped from ≈1140 s to ≈345 s (≈3.3× on 6 workers) — treat this as an order-of-magnitude expectation, not a guarantee.
- **Minimize passes over the datastore.** Each `extract` call re-reads every file. Running three extractors (time, frequency, time-frequency) as three separate `extract` calls reads the whole dataset three times. `UseParallel=true` on each call is the cheapest win; reducing the number of passes is the next lever.

Building, labeling, and orchestrating the datastore itself (`signalDatastore` construction, `labeledSignalSet`, `tall`) is out of this skill's scope — see SKILL.md "When NOT to Use." This section documents only what `extract`'s own input contract accepts.

## Common errors and fixes

| What you tried | Fix |
|---|---|
| `extract(sFE, x)` with `x` as a row vector | Reshape to a column: `x = x(:);` |
| `extract(sFE, X)` with `X` an `L×C` matrix | Multichannel not supported; loop over columns and concatenate the resulting tables. |
| `length(x) < FrameSize` with default `IncompleteFrameRule="drop"` | Empty output. Either pass a longer signal or set `IncompleteFrameRule="zeropad"`. |
| Treating `FrameStartTime` as seconds | 1-indexed sample positions. Convert: `tSec = (T.FrameStartTime - 1) / fs`. |
| `T.WelchPSD{k}` raised "Brace indexing is not supported" | Numeric matrix column when `FFTLength` is constant. Index with `T.WelchPSD(k, :)` or guard with `iscell` first. |
| Two extractors' tables don't row-align | `FrameSize` and `FrameOverlapLength` must match across extractors for row alignment. |
| `extract` returned a `gpuArray` and a specific downstream function errored | Call `gather` on that variable only. Many functions (tables, plotting, ML) accept gpuArrays directly. See `gpu-patterns.md`. |
| `extract` returned empty | At least one feature flag must be `true` at construction; check enabled flags. |
| Datastore extraction over many files runs slowly | `extract(sFE, sds)` is serial by default. Pass `UseParallel=true` to spread files across a pool; also minimize the number of `extract` passes over the same datastore (each pass re-reads every file). |
| Expected one combined table from a datastore, got a cell array | Datastore input returns an `N × 1` cell (one result per file) — index `feats{k}` or `vertcat(feats{:})` to stack per-frame tables. |

----

Copyright 2026 The MathWorks, Inc.

----
