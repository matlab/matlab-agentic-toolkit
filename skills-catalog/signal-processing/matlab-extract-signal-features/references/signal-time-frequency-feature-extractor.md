# `signalTimeFrequencyFeatureExtractor` reference

Time-frequency feature extraction for 1D signals. Available since R2024a.

This extractor differs from the others in two important ways:

1. **Feature availability depends on `Transform`.** Each transform supports a specific subset of the 13 feature flags. Enabling an unsupported feature for the chosen transform raises an error at construction.
2. **`FrameSize` is not allowed for `emd` / `vmd` transforms.** For those transforms, leave `FrameSize` and `FrameOverlapLength` unset (the entire signal is processed as one).

## Construction

```matlab
sFE = signalTimeFrequencyFeatureExtractor(Name=Value, ...);
```

## Frame and output properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `Transform` | string or `timeFrequencyFeatureTransformOptions` (R2026a+) | `"spectrogram"` | One of `"spectrogram"`, `"synchrosqueezedspectrogram"`, `"scalogram"`, `"synchrosqueezedscalogram"`, `"wavelet"`, `"waveletpacket"`, `"emd"`, `"vmd"`. R2026a+: prefer `timeFrequencyFeatureTransformOptions("spectrogram")` — the string form emits a deprecation warning. Drives which features are valid. |
| `FrameSize` | positive integer | not set | Required for non-EMD/VMD transforms. Must be unset for `emd` / `vmd`. |
| `FrameRate` | positive integer | not set | Mutually exclusive with `FrameOverlapLength`. |
| `FrameOverlapLength` | positive integer | not set | Must be `< FrameSize`. Cannot be set when `Transform` is `emd` or `vmd`. |
| `SampleRate` | positive scalar | `[]` | Set this. |
| `IncompleteFrameRule` | `"drop"` \| `"zeropad"` | `"drop"` | Last-frame handling. |
| `FeatureFormat` | `"matrix"` \| `"table"` | `"matrix"` | Output shape. |
| `ScalarizationMethod` | `timeFrequencyScalarFeatureOptions` | not set | Methods to scalarize per-frame feature vectors. See `scalarization-options.md`. |

## Feature × Transform compatibility matrix

`Y` = supported, `N` = unsupported (`signal:featurextractor:timefrequency:SpectrogramFeaturesForInvalidTransform` or similar at construction).

| Feature | spectrogram | synchrosqueezed-spectrogram | wavelet | waveletpacket | scalogram | synchrosqueezed-scalogram | emd | vmd |
|---|---|---|---|---|---|---|---|---|
| `SpectralKurtosis` | Y | Y | N | N | N | Y | N | N |
| `SpectralSkewness` | Y | Y | N | N | N | Y | N | N |
| `SpectralCrest` | Y | Y | N | N | N | Y | N | N |
| `SpectralFlatness` | Y | Y | N | N | N | Y | N | N |
| `SpectralEntropy` | Y | Y | N | N | N | Y | N | N |
| `TFRidges` | Y | Y | N | N | N | Y | N | N |
| `InstantaneousBandwidth` | Y | Y | N | N | N | Y | N | N |
| `InstantaneousFrequency` | Y | Y | Y | Y | N | Y | Y | Y |
| `InstantaneousEnergy` | N | N | Y | Y | N | N | Y | Y |
| `MeanEnvelopeEnergy` | N | N | N | N | N | N | Y | N |
| `WaveletEntropy` | N | N | Y | Y | N | N | N | N |
| `TimeSpectrum` | N | N | N | N | Y | N | N | N |
| `ScaleSpectrum` | N | N | N | N | Y | N | N | N |

When a feature is unsupported for the chosen transform, MATLAB lists the valid set in the error message. Read that list — it's authoritative.

## Per-feature parameters

Per-feature parameters depend on **both** the feature flag and the active transform. The tables below list parameters per `(transform, feature)` pair as captured from `getExtractorParameters`. Empty `[]` defaults mean "use the function's internal default" (typically the same default the underlying function would use without the extractor).

### `spectrogram` and `synchrosqueezedspectrogram`

| Feature | Parameters |
|---|---|
| `SpectralKurtosis`, `SpectralSkewness`, `SpectralCrest`, `SpectralFlatness` | none |
| `SpectralEntropy` | `Range` |
| `TFRidges` | `NumRidges`, `NumFrequencyBins`, `Penalty` |
| `InstantaneousBandwidth` | `FrequencyLimits`, `ScaleFactor` |
| `InstantaneousFrequency` | `FrequencyLimits` |

### `wavelet` and `waveletpacket`

| Feature | Parameters |
|---|---|
| `InstantaneousFrequency` | `FrequencyLimits`, `FrequencyResolution`, `MinThreshold` |
| `InstantaneousEnergy` | `FrequencyLimits`, `FrequencyResolution`, `MinThreshold` |
| `WaveletEntropy` | `Entropy`, `Exponent`, `Distribution`, `Scaled` |

### `scalogram`

| Feature | Parameters |
|---|---|
| `TimeSpectrum` | `Normalization`, `SpectrumType`, `TimeLimits` |
| `ScaleSpectrum` | `Normalization`, `SpectrumType`, `FrequencyLimits` |

### `synchrosqueezedscalogram`

Same as `synchrosqueezedspectrogram` plus `InstantaneousBandwidth` (`FrequencyLimits`, `ScaleFactor`).

### `emd` and `vmd`

| Feature | Parameters |
|---|---|
| `InstantaneousFrequency` | `FrequencyLimits`, `FrequencyResolution`, `MinThreshold` |
| `InstantaneousEnergy` | `FrequencyLimits`, `FrequencyResolution`, `MinThreshold` |
| `MeanEnvelopeEnergy` (emd only) | none |

## Per-transform parameters

Set via `setExtractorParameters(sFE, "TransformName", Param=Value, ...)`. These control the underlying transform computation, not individual features. The second argument is the **transform name** (e.g., `"spectrogram"`), not a feature name.

### `spectrogram`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Leakage` | scalar in [0, 1] | `[]` | Window leakage factor. |
| `OverlapPercent` | scalar in [0, 100) | `[]` | Overlap percentage for the internal spectrogram. |
| `TimeResolution` | positive scalar | `[]` | Time resolution in seconds. |

### `synchrosqueezedspectrogram`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Window` | vector | `[]` | Window applied to each segment. |

### `wavelet`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Wname` | string | `[]` | Wavelet name. |
| `LowPass` | vector | `[]` | Lowpass filter coefficients. |
| `HighPass` | vector | `[]` | Highpass filter coefficients. |
| `Level` | positive integer | `[]` | Decomposition level. |
| `Reflection` | logical | `[]` | Signal extension mode. |

### `waveletpacket`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Wname` | string | `[]` | Wavelet name. |
| `LowPass` | vector | `[]` | Lowpass filter coefficients. |
| `HighPass` | vector | `[]` | Highpass filter coefficients. |
| `Level` | positive integer | `[]` | Decomposition level. |
| `FullTree` | logical | `[]` | Use full decomposition tree. |

### `scalogram` and `synchrosqueezedscalogram`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Wavelet` | string | `[]` | Wavelet name. |
| `VoicesPerOctave` | positive integer | `[]` | Frequency resolution of the CWT. |
| `WaveletParameters` | vector | `[]` | Additional wavelet parameters. |
| `FrequencyLimits` | 2-element vector | `[]` | `[fLow fHigh]` in Hz. |

### `emd`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `MaxNumIMF` | positive integer | `[]` | Maximum number of intrinsic mode functions. |
| `MaxNumExtrema` | positive integer | `[]` | Stopping criterion: max extrema count. |
| `MaxEnergyRatio` | positive scalar | `[]` | Stopping criterion: energy ratio. |
| `Interpolation` | string | `[]` | Interpolation method for envelope. |

### `vmd`

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `NumIMFs` | positive integer | `[]` | Number of modes to decompose. |
| `CentralFrequencies` | vector | `[]` | Initial central frequencies. |
| `PenaltyFactor` | positive scalar | `[]` | Balances data fidelity vs. bandwidth. |
| `InitializeMethod` | string | `[]` | Initialization method for VMD. |

## Methods

| Method | Signature | Purpose |
|---|---|---|
| `extract` | `features = extract(sFE, x)` | Run the configured extractor on signal `x`. |
| `getExtractorParameters` | `params = getExtractorParameters(sFE, "FeatureName")` | Read current per-feature parameters. |
| `setExtractorParameters` | `setExtractorParameters(sFE, "FeatureName"\|"TransformName", Param=Value, ...)` | Set per-feature or per-transform parameters. See "Per-feature parameters" and "Per-transform parameters" sections above. |
| `getScalarizationMethods` | `m = getScalarizationMethods(sFE, "FeatureName")` | Read current scalarization (returns a string array). |
| `setScalarizationMethods` | `setScalarizationMethods(sFE, "FeatureName", Mean=true, StandardDeviation=true, ...)` | **Add** scalar summary columns alongside the vector column for a feature. |
| `generateMATLABFunction` | `generateMATLABFunction(sFE)` | Emit a codegen-compatible function. |

### Scalarization

All vector-valued features on this extractor accept scalarization. The exact set depends on the active `Transform` (e.g., on `Transform="spectrogram"`, `SpectralKurtosis` / `SpectralSkewness` / `SpectralCrest` / `SpectralFlatness` / `SpectralEntropy` are vector-valued and scalarizable). For the API, valid method names, the `WaveletEntropy` / `SpectralEntropy` `Entropy` exception, and output behavior, see `scalarization-options.md`.

**Memory budget.** Vector-valued features grow output linearly with frames × per-frame resolution. `InstantaneousFrequency`, `InstantaneousEnergy`, `WaveletEntropy`, `TFRidges`, `TimeSpectrum`, and `ScaleSpectrum` return a vector per frame — and on the wavelet/waveletpacket transforms, `InstantaneousFrequency` is per-sample-resolution, which can take a feature table to gigabytes for long signals or many recordings. Rough check before extracting: `numRecordings * numFrames * frameOutputLength * 8 bytes` per vector column. If that exceeds a few hundred MB and you only need summary statistics for a classifier, either (a) call `setScalarizationMethods` and drop the vector with `removevars` post-extract, or (b) drop the vector column post-extract directly.

## `extract` output shape

Same conventions as the other extractors. Most time-frequency features are scalars per frame; `TFRidges`, `TimeSpectrum`, `ScaleSpectrum`, and the spectral-shape features on `Transform="spectrogram"` (`SpectralKurtosis`, `SpectralSkewness`, `SpectralCrest`, `SpectralFlatness`, `SpectralEntropy`) are vector-valued (one value per frequency bin). On R2026a, output column names are `<FeatureName><TransformName>` (e.g., `SpectralKurtosisSpectrogram`). Inspect `T.Properties.VariableNames` after `extract` if uncertain.

With `FeatureFormat="table"` the table starts with `FrameStartTime` and `FrameEndTime` (**1-indexed sample positions**, not seconds — convert: `tSec = (T.FrameStartTime - 1) / fs`), then one column per feature. Vector-valued columns are stored as numeric matrices when per-frame length is fixed; as cell arrays when it varies. Use `iscell(T.(colName))` before indexing. Strip the time columns before training a classifier. Use `FeatureFormat="table"` when mixing scalar and vector features.

## R2026a+: `timeFrequencyFeatureTransformOptions`

On R2026a+, prefer `Transform=timeFrequencyFeatureTransformOptions(...)` over the string form `Transform="spectrogram"`. The string form still works but emits a deprecation warning.

### Single-transform usage

```matlab
tfOpts = timeFrequencyFeatureTransformOptions(SpectralEntropy="spectrogram");
sFE = signalTimeFrequencyFeatureExtractor(Transform=tfOpts, ...);
```

### Multi-transform routing (one extractor, different transforms per feature)

A single extractor can route different features to different transforms. You do NOT need separate extractors. Each property on the options object specifies which transform to use for that feature:

```matlab
tfOpts = timeFrequencyFeatureTransformOptions( ...
    SpectralKurtosis="synchrosqueezedspectrogram", ...
    SpectralEntropy="spectrogram");
sFE = signalTimeFrequencyFeatureExtractor( ...
    Transform=tfOpts, ...
    SampleRate=fs, ...
    FrameSize=256, ...
    FrameOverlapLength=128, ...
    SpectralKurtosis=true, ...
    SpectralEntropy=true, ...
    FeatureFormat="table");
featureTable = extract(sFE, x);
```

### Per-feature transform options

| Property | Valid transforms | Default |
|---|---|---|
| `SpectralKurtosis`, `SpectralSkewness`, `SpectralCrest`, `SpectralFlatness`, `SpectralEntropy`, `TFRidges`, `InstantaneousBandwidth` | `"spectrogram"`, `"synchrosqueezedspectrogram"`, `"synchrosqueezedscalogram"` | `"spectrogram"` |
| `InstantaneousFrequency` | all of the above + `"emd"`, `"vmd"`, `"wavelet"`, `"waveletpacket"` | `"spectrogram"` |
| `InstantaneousEnergy` | `"emd"`, `"vmd"`, `"wavelet"`, `"waveletpacket"` | `"emd"` |
| `MeanEnvelopeEnergy` | `"emd"` | `"emd"` |
| `WaveletEntropy` | `"wavelet"`, `"waveletpacket"` | `"wavelet"` |
| `TimeSpectrum`, `ScaleSpectrum` | `"scalogram"` | `"scalogram"` |

### Important notes

- The options object routes features to transforms but does NOT carry transform-level parameters — those are still set via `setExtractorParameters(sFE, "spectrogram", Leakage=..., OverlapPercent=...)`.
- Only set properties for features you actually enable on the extractor. Unset properties use their defaults.
- The compatibility matrix above still applies — a feature must be valid for the transform you route it to.

## Common solutions

| What you tried | Fix |
|---|---|
| `Transform="STFT"` | Not a valid value. Use `Transform="spectrogram"` for STFT-style analysis. Valid set: `spectrogram`, `synchrosqueezedspectrogram`, `wavelet`, `waveletpacket`, `scalogram`, `synchrosqueezedscalogram`, `emd`, `vmd`. |
| `MeanEnvelopeEnergy=true` on `Transform="spectrogram"` (or any non-EMD) | `MeanEnvelopeEnergy` is EMD-only. Either drop the feature or switch to `Transform="emd"` (and unset `FrameSize`/`FrameOverlapLength`). |
| `FrameSize` set with `Transform="emd"` or `"vmd"` | EMD/VMD process the entire signal — leave `FrameSize` and `FrameOverlapLength` unset. |
| Feature enabled that isn't valid for the chosen `Transform` | Read the error message — MATLAB lists the valid set. Cross-check with the compatibility matrix above. |
| `setExtractorParameters` with an unknown param name | Per-feature parameters depend on `(transform, feature)`. Check the per-feature parameter table above for the active transform. |
| `setExtractorParameters` raised `NoParameterFeature` | The `(transform, feature)` pair has no parameters. Check the per-feature parameter tables above. |
| `getScalarMethods(sFE, "FeatureName")` | That's an internal method that takes no arguments. Use `getScalarizationMethods(sFE, "FeatureName")`. |

----

Copyright 2026 The MathWorks, Inc.

----
