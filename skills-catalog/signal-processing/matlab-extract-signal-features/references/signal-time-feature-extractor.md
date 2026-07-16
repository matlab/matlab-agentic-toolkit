# `signalTimeFeatureExtractor` reference

Time-domain feature extraction for 1D signals. Available since R2021a.

## Construction

```matlab
sFE = signalTimeFeatureExtractor(Name=Value, ...);
```

All properties are name-value pairs. None are required at construction, but `extract` will produce no output unless at least one feature flag is enabled.

## Frame and output properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `FrameSize` | positive integer | not set | Samples per frame. |
| `FrameRate` | positive integer | not set | Samples between frame starts. Mutually exclusive with `FrameOverlapLength`. |
| `FrameOverlapLength` | positive integer | not set | Overlapping samples between consecutive frames. Mutually exclusive with `FrameRate`. Must be `< FrameSize`. |
| `SampleRate` | positive scalar | `[]` | Required for any feature with a time-unit interpretation (e.g., SNR, THD). |
| `IncompleteFrameRule` | `"drop"` \| `"zeropad"` | `"drop"` | How to treat the last frame when fewer than `FrameSize` samples remain. |
| `FeatureFormat` | `"matrix"` \| `"table"` | `"matrix"` | Output shape from `extract`. |
| `ScalarizationMethod` | `timeScalarFeatureOptions` | not set | Degenerate on this extractor — time features are already scalar per frame. See `scalarization-options.md`. |

## Feature flags

Set any of these to `true` at construction (or via direct property assignment) to enable the feature. Names not in this list do not exist on this extractor.

| Flag | Description |
|---|---|
| `Mean` | Arithmetic mean of the frame. |
| `RMS` | Root mean square. |
| `StandardDeviation` | Standard deviation of the frame. |
| `ShapeFactor` | RMS divided by mean of absolute values. |
| `SNR` | Signal-to-noise ratio (requires `SampleRate`). |
| `THD` | Total harmonic distortion (requires `SampleRate`). |
| `SINAD` | Signal to noise and distortion ratio (requires `SampleRate`). |
| `PeakValue` | Maximum absolute value in the frame. |
| `CrestFactor` | Peak value divided by RMS. |
| `ClearanceFactor` | Peak divided by squared mean of square roots of absolute values. |
| `ImpulseFactor` | Peak divided by mean of absolute values. |

## Methods

| Method | Signature | Purpose |
|---|---|---|
| `extract` | `features = extract(sFE, x)` | Run the configured extractor on signal `x`. |
| `generateMATLABFunction` | `generateMATLABFunction(sFE)` | Emit a code-generation-compatible MATLAB function. |

**Not on this extractor.** `getExtractorParameters` and `setExtractorParameters` exist on the frequency and time-frequency extractors but do not apply to the time extractor — every time feature is parameterless. Calling them raises `signal:featurextractor:time:NoFeatureWithExtractorParams`.

`setScalarizationMethods` is callable on this extractor (for `PeakValue` only) but produces degenerate output: time features are already scalar per frame, so scalarization is intra-row and yields `Mean` = the value itself, `StandardDeviation` = 0, `Skewness` = NaN. Compute cross-frame statistics host-side (`mean(T.PeakValue)`, `std(T.PeakValue)`). See `scalarization-options.md` for the full API.

## `extract` output shape

For a single 1D signal of length `L`:

- With `FeatureFormat="matrix"` (default): output is a `[numFrames, numFeatures]` numeric matrix. Column ordering matches the order of the feature flags as listed above (only enabled features are included).
- With `FeatureFormat="table"`: output is a table with `FrameStartTime`, `FrameEndTime` (**1-indexed sample positions**, not seconds — convert: `tSec = (T.FrameStartTime - 1) / fs`), then one column per enabled feature; the feature column names match the property names. Strip the time columns before passing the table to a classifier.

`numFrames` depends on `FrameSize`, `FrameRate` / `FrameOverlapLength`, and `IncompleteFrameRule`.

## Common solutions

| What you tried | Fix |
|---|---|
| `Skewness=true` or `Kurtosis=true` on this extractor | Not on the time extractor. Use `signalTimeFrequencyFeatureExtractor` for spectral skewness/kurtosis, or compute host-side from the frame values. |
| `MeanFrequency=true` (or any frequency-domain flag) | Wrong extractor. Use `signalFrequencyFeatureExtractor`. |
| `FrameLength=N` instead of `FrameSize=N` | Property is `FrameSize`. |
| `FrameOverlapLength >= FrameSize` | `FrameOverlapLength` must be `< FrameSize`. |
| Set both `FrameRate` and `FrameOverlapLength` | Pick one; they are mutually exclusive. |
| Called `getExtractorParameters` / `setExtractorParameters` | Not supported on this extractor — every time feature is parameterless. |
| Used `setScalarizationMethods` for cross-frame stats | Degenerate here. Use `mean(T.col)` / `std(T.col)` host-side. |
| `extract` returned empty | At least one feature flag must be `true` at construction. |

If `SampleRate` is omitted, frequency-derived features (`SNR`, `THD`, `SINAD`) still compute but interpret the signal as having `fs = 1`, which is rarely what the user wants. Set `SampleRate` whenever the signal has a real-world time axis.

----

Copyright 2026 The MathWorks, Inc.

----
