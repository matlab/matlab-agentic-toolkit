# `signalFrequencyFeatureExtractor` reference

Frequency-domain feature extraction for 1D signals. Available since R2021b.

## Construction

```matlab
sFE = signalFrequencyFeatureExtractor(Name=Value, ...);
```

## Frame and output properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `FrameSize` | positive integer | not set | Samples per frame. |
| `FrameRate` | positive integer | not set | Samples between frame starts. Mutually exclusive with `FrameOverlapLength`. |
| `FrameOverlapLength` | positive integer | not set | Overlapping samples per frame. Must be `< FrameSize`. |
| `SampleRate` | positive scalar | `[]` | Required — frequency features need a real frequency axis. Set this. |
| `IncompleteFrameRule` | `"drop"` \| `"zeropad"` | `"drop"` | Last-frame handling. |
| `FeatureFormat` | `"matrix"` \| `"table"` | `"matrix"` | Output shape from `extract`. |
| `ScalarizationMethod` | `frequencyScalarFeatureOptions` | not set | Methods to scalarize per-frame feature vectors. Applies to `WelchPSD` and `PeakAmplitude` only. See `scalarization-options.md`. |

## Feature flags

| Flag | Description | Has per-feature params |
|---|---|---|
| `MeanFrequency` | Mean frequency of the spectrum. | no |
| `MedianFrequency` | Median frequency. | no |
| `BandPower` | Average power in a frequency band. The band is **not configurable** through `setExtractorParameters`. If a specific band is required, bandpass-filter the signal before extracting features. | no |
| `OccupiedBandwidth` | Bandwidth occupying a percentage of the total power. | yes |
| `PowerBandwidth` | Half-power (or relative-power) bandwidth. | yes |
| `WelchPSD` | Welch power spectral density estimate. | yes |
| `PeakAmplitude` | Amplitude(s) of spectral peak(s). | yes |
| `PeakLocation` | Frequency location(s) of spectral peak(s). | yes |

Names not in this list do not exist on this extractor.

## Per-feature parameters (set via `setExtractorParameters`)

`OccupiedBandwidth`:

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Percentage` | scalar in (0, 100) | `[]` (uses 99) | Power percentage to span. |

`PowerBandwidth`:

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `RelativeAmplitude` | positive scalar (dB) | `[]` (uses 3) | Relative amplitude in dB defining the bandwidth boundary. |

`WelchPSD`:

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `Window` | vector \| empty | `[]` | Window applied to each Welch segment. |
| `OverlapLength` | nonnegative integer | `[]` | Welch segment overlap. Distinct from `FrameOverlapLength`. |
| `FFTLength` | positive integer | `[]` | FFT size for the PSD. |
| `FrequencyVector` | vector | `[]` | Frequencies at which to evaluate the PSD (if specified). |

`PeakAmplitude` and `PeakLocation` (shared parameter set):

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `PeakType` | `'maxima'` \| `'minima'` | `'maxima'` | Direction of peak. |
| `MaxNumExtrema` | positive integer | `1` | Max peaks per frame. |
| `MinProminence` | scalar | `[]` | Minimum prominence. |
| `MinSeparation` | scalar | `[]` | Minimum frequency separation between peaks. |
| `FlatSelection` | `'first'` \| `'last'` \| `'center'` \| `[]` | `[]` | Tiebreaker for flat regions. |

Setting a parameter that doesn't exist for the chosen feature raises `MATLAB:InputParser:UnmatchedParameter`. Setting any parameter on a parameterless feature (`MeanFrequency`, `MedianFrequency`, `BandPower`) raises `shared_signal_featureextraction:feature:NoParameterFeature`.

## Methods

| Method | Signature | Purpose |
|---|---|---|
| `extract` | `features = extract(sFE, x)` | Run the configured extractor on signal `x`. |
| `getExtractorParameters` | `params = getExtractorParameters(sFE, "FeatureName")` | Read current per-feature parameters. |
| `setExtractorParameters` | `setExtractorParameters(sFE, "FeatureName", Param=Value, ...)` | Set per-feature parameters. The feature flag must be `true` first. |
| `getScalarizationMethods` | `m = getScalarizationMethods(sFE, "FeatureName")` | Read current scalarization for a vector-valued feature (`WelchPSD` or `PeakAmplitude`). |
| `setScalarizationMethods` | `setScalarizationMethods(sFE, "FeatureName", Mean=true, ...)` | **Add** scalar summary columns alongside the vector column. |
| `generateMATLABFunction` | `generateMATLABFunction(sFE)` | Emit a codegen-compatible function. |

### Scalarization

Only `WelchPSD` and `PeakAmplitude` (the vector-valued features) accept scalarization on this extractor — see `frequencyScalarFeatureOptions`. For the API, valid method names, and output behavior, see `scalarization-options.md`.

## `extract` output shape

For a single 1D signal:

- `FeatureFormat="matrix"` (default): per-frame numeric matrix. Scalar features each contribute one column; vector features (`WelchPSD`, multi-peak `PeakAmplitude`/`PeakLocation`) contribute multiple columns whose count depends on parameters.
- `FeatureFormat="table"`: a table that starts with `FrameStartTime` and `FrameEndTime` (**1-indexed sample positions**, not seconds — convert: `tSec = (T.FrameStartTime - 1) / fs`), then one column per feature. Vector-valued features (`WelchPSD`, multi-peak `PeakAmplitude`/`PeakLocation`) are stored as numeric matrix columns when per-frame length is fixed (index with `T.WelchPSD(k, :)`), or cell columns if length varies. Strip the time columns before training a classifier.

When mixing scalar and vector features, prefer `FeatureFormat="table"` to keep columns labeled.

**`WelchPSD` brace-indexing trap.** When `FFTLength` is constant across frames, `T.WelchPSD` is a numeric matrix, not a cell — `T.WelchPSD{k}` raises `Brace indexing is not supported for variables of this type.` Check first: `if iscell(T.WelchPSD), val = T.WelchPSD{k}; else, val = T.WelchPSD(k, :); end`.

## Common solutions

| What you tried | Fix |
|---|---|
| Guessed the `PowerBandwidth` parameter from the feature name (e.g. a `Power` keyword argument) | The parameter is `RelativeAmplitude` (in dB), not derived from the feature name. Use `setExtractorParameters(sFE, "PowerBandwidth", RelativeAmplitude=3)`. |
| Set parameters on `MeanFrequency` / `MedianFrequency` / `BandPower` | These features are parameterless. To restrict the analysis band, bandpass-filter the signal first. |
| `RMS=true` (or any time-domain flag) on this extractor | Wrong extractor. Use `signalTimeFeatureExtractor`. |
| Hallucinated feature flag | Use only the eight flags listed above (`MeanFrequency`, `MedianFrequency`, `BandPower`, `OccupiedBandwidth`, `PowerBandwidth`, `WelchPSD`, `PeakAmplitude`, `PeakLocation`). |
| `T.WelchPSD{k}` raised "Brace indexing is not supported" | Numeric matrix column; index with `T.WelchPSD(k, :)`. |
| `FrameOverlapLength >= FrameSize` | `FrameOverlapLength` must be `< FrameSize`. |

----

Copyright 2026 The MathWorks, Inc.

----
