---
name: matlab-extract-signal-features
description: >
  Extract features from 1D signals using signalTimeFeatureExtractor,
  signalFrequencyFeatureExtractor, and signalTimeFrequencyFeatureExtractor.
  Use when computing time-domain features (amplitude, energy, shape factors),
  frequency-domain features (spectral location, power, bandwidth, PSD), or
  time-frequency features (spectral shape, instantaneous, ridges, wavelet,
  EMD-derived) on a per-frame basis. Use when the user asks to "extract
  features", "compute spectral features", "build a feature table for a
  classifier", "get per-frame statistics", "run feature extraction on this
  signal", or describes a vibration / biosignal / radar / sensor signal
  needing features for downstream ML or analysis. Includes optional GPU
  acceleration via canUseGPU and gpuArray. Does not cover filter design,
  audio-specific feature extraction (use audioFeatureExtractor in Audio
  Toolbox instead), batch dataset orchestration, or 2D / image features.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Extract Signal Features

Per-frame feature extraction for 1D signals using the three Signal Processing Toolbox extractor objects. Picks the right extractor, configures it with real parameters only, and adds a GPU code path when one is available.

## When to Use

- The user has a 1D signal and wants per-frame features for analysis or ML.
- The user names specific features from any of the three extractor domains (time, frequency, time-frequency).
- The user asks for a feature table or feature matrix to feed `fitcecoc`, `fitcnet`, or any classifier / regressor.
- The user asks for per-frame statistics over a windowed signal.

## When NOT to Use

- **Filter design or signal preprocessing** — out of scope. Filtering before feature extraction is a separate concern.
- **Audio-specific features** (MFCC, mel-spectrogram, pitch, chroma, gammatone). Audio Toolbox's `audioFeatureExtractor` covers those — out of scope here.
- **Batch / dataset orchestration** — `signalDatastore`, `labeledSignalSet`, `tall` arrays. The per-file extraction is in scope; building the pipeline around it is not.
- **2D, image, or multivariate features** — out of scope by signal-type boundary.

## Workflow

0. **(Recommended) Run a quick preliminary analysis.** Check *spectral* stationarity — does the frequency content drift over time? — on a representative subset using Signal Processing Toolbox alone: a `pspectrum(x, fs, "spectrogram")` look plus a per-frame `MeanFrequency` drift ratio (no Econometrics Toolbox needed; `adftest`/`kpsstest` are an optional supplement only). Use the verdict to pick the *primary* extractor — non-stationary signals favour `signalTimeFrequencyFeatureExtractor`; spectrally stationary signals lean on the frequency extractor. See `references/preliminary-analysis.md`. Then write down a ranked candidate feature list, spanning **more than one domain** for a classifier/regressor feature table, with one-line justifications tying each feature to an observed signal characteristic, *before* configuring the extractors. The verdict picks the primary extractor, not the only one — a set that collapses onto a single extractor is the most common cause of a weak downstream classifier. Example: *"MeanFrequency — stationary harmonic, energy localized at known frequencies."* See `references/feature-ranking.md`.
1. **Pick the extractor** based on what the user wants. See "Choosing the right extractor" below.
2. **Configure** with `SampleRate`, `FrameSize`, and either `FrameRate` or `FrameOverlapLength` (not both). Enable feature flags as name-value pairs.
3. **(Optional) Set per-feature or per-transform parameters** via `setExtractorParameters` for features/transforms that have them. Only `signalFrequencyFeatureExtractor` and `signalTimeFrequencyFeatureExtractor` support this method. The second argument can be a feature name OR a transform name. **Before writing any `setExtractorParameters` call, open the matching reference file and copy the parameter name verbatim.** Parameter names are not what you'd guess. The references are the source of truth.
4. **(Optional) Move to GPU** using the guard pattern in `references/gpu-patterns.md`.
5. **Run `extract(sFE, x)`** on the signal. Output shape depends on `FeatureFormat` (matrix or table). `src` may also be a `signalDatastore` / `audioDatastore`, in which case `extract` returns one result per file (a cell array) and accepts `UseParallel=true` to process files on a parallel pool — use it whenever extracting over many files. For the input contract, the per-extractor output shape, datastore/parallel extraction, and how to combine outputs across extractors, see `references/extract-function.md`.
6. **Decide output shape.** Do NOT aggregate per-frame results by default. The per-frame table is a valid final output. Aggregate (mean/std across frames) only if the user's downstream model requires one fixed-length vector per signal (e.g., `fitcecoc`, `fitcsvm`, tree ensembles). If the model consumes sequences (LSTM, 1-D CNN, transformer), keep the per-frame table as-is. If the user has variable-length signals and the downstream task is unclear, ask rather than assuming aggregation. See `references/post-extraction-patterns.md`.

**Stop and check the matching per-extractor reference before:**
- Enabling any feature on `signalTimeFrequencyFeatureExtractor` — each `Transform` supports a different subset.
- Calling `setExtractorParameters` — parameter names differ per feature and per transform.
- Using any feature flag, parameter, or `Transform` value not already shown in this file's patterns. If it isn't in the per-extractor reference, it doesn't exist on the object.

## Choosing the right extractor

| User wants | Use |
|---|---|
| Time-domain features (amplitude, energy, shape factors) | `signalTimeFeatureExtractor` |
| Frequency-domain features (spectral location, power, bandwidth, PSD) | `signalFrequencyFeatureExtractor` |
| Time-frequency features (spectral shape, instantaneous, ridges, wavelet, EMD-derived) | `signalTimeFrequencyFeatureExtractor` |
| Multiple of the above | Use multiple extractors; concatenate the resulting tables |

For the time-frequency extractor, the `Transform` property gates which features are valid. See the compatibility matrix in `references/signal-time-frequency-feature-extractor.md`.

## Key Functions

| Function | Purpose | Toolbox | Available From |
|---|---|---|---|
| `signalTimeFeatureExtractor` | Time-domain feature extractor object | Signal Processing Toolbox | R2021a |
| `signalFrequencyFeatureExtractor` | Frequency-domain feature extractor object | Signal Processing Toolbox | R2021b |
| `signalTimeFrequencyFeatureExtractor` | Time-frequency feature extractor object | Signal Processing Toolbox | R2024a |
| `extract` | Run a configured extractor on a signal | Signal Processing Toolbox | R2021a |
| `getExtractorParameters` / `setExtractorParameters` | Read/write per-feature or per-transform parameters (frequency and time-frequency only) | Signal Processing Toolbox | R2021b |
| `timeFrequencyFeatureTransformOptions` | Create transform options object for `signalTimeFrequencyFeatureExtractor` (replaces string `Transform=`) | Signal Processing Toolbox | R2026a |
| `generateMATLABFunction` | Emit a codegen-compatible MATLAB function from an extractor | Signal Processing Toolbox | R2021a |
| `canUseGPU`, `gather` | GPU availability check and data transfer (core MATLAB, no toolbox) | MATLAB | R2020b |
| `gpuArray` | Move array to GPU memory | Parallel Computing Toolbox | R2012a |

**`gpuArray` input to `extract` is available per extractor from:** `signalTimeFeatureExtractor` R2023a, `signalFrequencyFeatureExtractor` R2023a, `signalTimeFrequencyFeatureExtractor` **R2024b** (one release after the object itself). Requires Parallel Computing Toolbox. See [`references/gpu-patterns.md`](references/gpu-patterns.md) for per-transform limitations.

`generateMATLABFunction` exists for codegen workflows. Mention it when relevant; full codegen guidance is out of scope for this skill.

## Patterns

### Time-domain features per frame

```matlab
function featureTable = extractTimeFeaturesExample(x, fs)
%extractTimeFeaturesExample Per-frame time-domain features as a table.
    arguments
        x  (:, 1) double {mustBeFinite}
        fs (1, 1) double {mustBePositive}
    end

    sFE = signalTimeFeatureExtractor( ...
        SampleRate=fs, ...
        FrameSize=round(0.1 * fs), ...
        FrameOverlapLength=round(0.05 * fs), ...
        RMS=true, ...
        CrestFactor=true, ...
        PeakValue=true, ...
        FeatureFormat="table");

    featureTable = extract(sFE, x);
end
```

For valid time-feature flags, see `references/signal-time-feature-extractor.md`.

### Frequency-domain features with per-feature parameters

```matlab
function featureTable = extractBandPowerExample(x, fs)
%extractBandPowerExample Band power and occupied bandwidth per frame.
    arguments
        x  (:, 1) double {mustBeFinite}
        fs (1, 1) double {mustBePositive}
    end

    sFE = signalFrequencyFeatureExtractor( ...
        SampleRate=fs, ...
        FrameSize=round(0.1 * fs), ...
        FrameOverlapLength=round(0.05 * fs), ...
        BandPower=true, ...
        OccupiedBandwidth=true, ...
        FeatureFormat="table");

    setExtractorParameters(sFE, "OccupiedBandwidth", Percentage=95);

    featureTable = extract(sFE, x);
end
```

For per-feature parameter tables (including the trap that `PowerBandwidth` takes `RelativeAmplitude` not `Power`), see `references/signal-frequency-feature-extractor.md`.

### Time-frequency features (spectrogram transform)

```matlab
function featureTable = extractTFFeaturesExample(x, fs)
%extractTFFeaturesExample Spectral entropy and instantaneous frequency per frame.
    arguments
        x  (:, 1) double {mustBeFinite}
        fs (1, 1) double {mustBePositive}
    end

    % R2026a+ (preferred): use timeFrequencyFeatureTransformOptions.
    % Constructor is name-value only, keyed by FEATURE name -> transform.
    % There is no positional-string form: timeFrequencyFeatureTransformOptions("spectrogram") errors.
    tfOpts = timeFrequencyFeatureTransformOptions( ...
        SpectralEntropy="spectrogram", ...
        InstantaneousFrequency="spectrogram");
    sFE = signalTimeFrequencyFeatureExtractor( ...
        Transform=tfOpts, ...
        SampleRate=fs, ...
        FrameSize=256, ...
        FrameOverlapLength=128, ...
        SpectralEntropy=true, ...
        InstantaneousFrequency=true, ...
        FeatureFormat="table");

    % R2024a–R2025b: use string directly (deprecated from R2026a)
    % sFE = signalTimeFrequencyFeatureExtractor( ...
    %     Transform="spectrogram", ...
    %     SampleRate=fs, ...
    %     FrameSize=256, ...
    %     FrameOverlapLength=128, ...
    %     SpectralEntropy=true, ...
    %     InstantaneousFrequency=true, ...
    %     FeatureFormat="table");

    setExtractorParameters(sFE, "spectrogram", Leakage=0.9, OverlapPercent=85);

    featureTable = extract(sFE, x);
end
```

Each `Transform` supports a different subset of features, and per-feature parameters depend on `(transform, feature)`. Always check `references/signal-time-frequency-feature-extractor.md` before enabling a feature or calling `setExtractorParameters`.

**Multi-transform routing (R2026a+):** A single extractor can route different features to different transforms — you do NOT need separate extractors. Use `timeFrequencyFeatureTransformOptions` with per-feature properties (e.g., `SpectralKurtosis="synchrosqueezedspectrogram"`, `SpectralEntropy="spectrogram"`). See the full example and valid-transform table in `references/signal-time-frequency-feature-extractor.md`.

### GPU-accelerated extraction

> **Toolbox note:** The GPU path (`gpuArray`) and the `UseParallel=true` datastore path both require **Parallel Computing Toolbox**. It is *not* required for core feature extraction — the skill runs fully on CPU without it, because the `canUseGPU()` guard skips the GPU branch and `UseParallel` defaults to `false`. Enable these paths only when Parallel Computing Toolbox is installed.

```matlab
function featureTable = extractWithGPU(x, fs)
%extractWithGPU Run feature extraction on GPU when available, CPU otherwise.
    arguments
        x  (:, 1) double {mustBeFinite}
        fs (1, 1) double {mustBePositive}
    end

    sFE = signalTimeFeatureExtractor( ...
        SampleRate=fs, ...
        FrameSize=round(0.1 * fs), ...
        FrameOverlapLength=round(0.05 * fs), ...
        RMS=true, ...
        StandardDeviation=true, ...
        FeatureFormat="table");

    if canUseGPU()
        x = gpuArray(x);
    end
    featureTable = extract(sFE, x);
end
```

The feature table may contain gpuArray columns. Downstream code (ML training, plotting) often accepts these directly. Call `gather` only when a specific consumer requires it (e.g., `save` to .mat, `writetable` to CSV).

See `references/gpu-patterns.md` for the rationale behind the `canUseGPU` guard and why unconditional `gpuArray` calls are wrong. If the GPU path unexpectedly falls back to CPU or `gpuArray` errors, the `matlab-setup-gpu` skill diagnoses GPU availability problems (unlicensed PCT, outdated driver, compute mode).

### Post-extraction: aggregation and reproducibility

Do not aggregate unless the user's workflow explicitly requires one feature vector per signal. The per-frame table is the default output. Two optional patterns that run after `extract`:

- **Per-frame → per-signal aggregation** — only when the downstream model requires a fixed-length vector per example (tree ensembles, SVM, etc.). Collapse with `varfun(@mean, ...)` / `varfun(@std, ...)`, dropping `FrameStartTime` / `FrameEndTime` first. Skip aggregation for sequence models (LSTM, 1-D CNN) that consume the frame sequence directly. For scalar summaries of vector-valued features, use `setScalarizationMethods` at extraction time instead.
- **Save extractor + data card** — `save("featureConfig.mat", "sFE", "dataCard")` where `dataCard` records `SampleRate`, `FrameSize`, `FrameOverlapLength`, `class(sFE)`, and `version("-release")`. Minimum sidecar to reproduce the extraction on new data.

See `references/post-extraction-patterns.md` for the worked code blocks and edge cases (vector-valued columns, label-column handling, alternative scalarization route).

## Conventions (apply to all three extractors)

- **Always set `SampleRate`.** Frequency-derived features interpret the signal as `fs = 1` if `SampleRate` is omitted.
- **Pick `FrameRate` or `FrameOverlapLength`, not both.** They control the same thing two different ways. Setting both raises an error.
- **`FrameOverlapLength` must be `< FrameSize`.**
- **Set `FrameSize` and `FrameOverlapLength` in samples**, not seconds. Convert: `FrameSize = round(durationSeconds * fs)`.
- **Prefer `FeatureFormat="table"`** when the extractor produces a mix of scalar and vector features.
- **`FrameStartTime` / `FrameEndTime` are 1-indexed sample positions**, not seconds. Convert: `tSec = (T.FrameStartTime - 1) / fs`. Strip them before training a classifier.
- **Vector-valued feature columns are numeric matrices when per-frame length is fixed, cells when it varies.** Check with `iscell(T.(colName))` before indexing.
- **Don't guess feature names or parameters.** Read the relevant per-extractor reference. Anything not in the reference does not exist on the object.

## Common cross-cutting pitfalls

| What you tried | Fix |
|---|---|
| Hand-rolled per-frame statistics over a windowed signal (e.g. RMS / crest factor loop on a buffered signal) | Use the extractor object — composes with `extract`, has a codegen path. |
| `FrameLength=N` instead of `FrameSize=N` | Property is `FrameSize` on all three extractors. |
| Set both `FrameRate` and `FrameOverlapLength` | Pick one. |
| `gpuArray(x)` without `canUseGPU()` guard | Hard-errors on CPU-only machines. Wrap in `if canUseGPU(); x = gpuArray(x); end`. |

For extractor-specific pitfalls (e.g., `Skewness=true` on the time extractor, `MeanEnvelopeEnergy` on a non-EMD transform, the `PowerBandwidth` parameter being `RelativeAmplitude` rather than guessed from the feature name), see the per-extractor references.

## References

- [`references/preliminary-analysis.md`](references/preliminary-analysis.md) — Signal-Processing-only spectral-stationarity check (`pspectrum` spectrogram + per-frame `MeanFrequency` drift ratio), the optional Econometrics `adftest`/`kpsstest` supplement, and the verdict→extractor decision rules. Read before picking an extractor when the signal character is unclear.
- [`references/feature-ranking.md`](references/feature-ranking.md) — a-priori candidate-feature list pattern and the signal-profile→feature mapping. Read when the user asks for a starting feature set or wants a ranked list.
- [`references/extract-function.md`](references/extract-function.md) — `extract` input/output contract, per-extractor output character, multi-extractor row alignment, and common error modes. Read when debugging shape or alignment issues.
- [`references/signal-time-feature-extractor.md`](references/signal-time-feature-extractor.md) — full property and feature-flag surface for the time extractor. Read when verifying a time-feature name or property.
- [`references/signal-frequency-feature-extractor.md`](references/signal-frequency-feature-extractor.md) — full property surface plus per-feature parameter tables (`OccupiedBandwidth`, `PowerBandwidth`, `WelchPSD`, peak parameters). Read when configuring frequency features.
- [`references/signal-time-frequency-feature-extractor.md`](references/signal-time-frequency-feature-extractor.md) — Transform×feature compatibility matrix and per-transform parameter tables. Read this before enabling any feature on the time-frequency extractor.
- [`references/scalarization-options.md`](references/scalarization-options.md) — the three `*ScalarFeatureOptions` objects and the `setScalarizationMethods` API. Read when adding scalar summary columns to vector-valued features.
- [`references/gpu-patterns.md`](references/gpu-patterns.md) — `canUseGPU` guard pattern and rationale. Read when the user mentions GPU.

----

Copyright 2026 The MathWorks, Inc.

----
