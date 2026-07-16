# Scalarization options reference

How to add scalar summary columns to vector-valued features in the
three signal feature extractors. Covers the three sibling
options objects and the shared `setScalarizationMethods` /
`getScalarizationMethods` API.

## The three options objects

Each extractor has a paired options object that lists which features
on that extractor accept scalarization, and the methods available.

| Object | Pairs with | Available since |
|---|---|---|
| `timeScalarFeatureOptions` | `signalTimeFeatureExtractor` | R2021a |
| `frequencyScalarFeatureOptions` | `signalFrequencyFeatureExtractor` | R2021b |
| `timeFrequencyScalarFeatureOptions` | `signalTimeFrequencyFeatureExtractor` | R2024a |

Construct any of them with no arguments to inspect the surface:

```matlab
opts = timeFrequencyScalarFeatureOptions;
disp(opts)
```

The displayed properties name the features that accept scalarization
on that extractor; their values name the methods currently enabled.

## Valid scalarization methods

Across all three extractors, exactly ten method names are valid:

| Method | Time | Frequency | Time-Frequency |
|---|---|---|---|
| `Mean` | Y | Y | Y |
| `StandardDeviation` | Y | Y | Y |
| `PeakValue` | Y | Y | Y |
| `Kurtosis` | Y | Y | Y |
| `Skewness` | Y | Y | Y |
| `ClearanceFactor` | N | Y | Y |
| `CrestFactor` | N | Y | Y |
| `ImpulseFactor` | N | Y | Y |
| `Energy` | N | Y | Y |
| `Entropy` | N | Y | Y |

**`Entropy` exception.** `Entropy` scalarization is *not* supported
on `WaveletEntropy` or `SpectralEntropy` (raises
`shared_signal_featureextraction:feature:EntropyScalarizationNotSupported`)
even though both features live on extractors that otherwise accept
`Entropy`.

Common guesses that are NOT valid: `Maximum`, `Minimum`, `Median`,
`RMS`, `Range`, `Variance`, `Sum`. They raise
`MATLAB:InputParser:UnmatchedParameter`.

## Which features accept scalarization

* **`signalTimeFeatureExtractor`:** scalarization is technically
  callable on `PeakValue` only, but is degenerate — time features
  are already scalar per frame, so `Mean` returns the value itself,
  `StandardDeviation` is `0`, and `Skewness` is `NaN`. Compute
  cross-frame statistics host-side instead:
  `mean(T.PeakValue)`, `std(T.PeakValue)`.
* **`signalFrequencyFeatureExtractor`:** only the vector-valued
  features accept scalarization — `WelchPSD` and `PeakAmplitude`.
* **`signalTimeFrequencyFeatureExtractor`:** all vector-valued
  features accept scalarization. The exact set depends on the
  active `Transform` (e.g., on `Transform="spectrogram"`,
  `SpectralKurtosis` / `SpectralSkewness` / `SpectralCrest` /
  `SpectralFlatness` / `SpectralEntropy` are vector-valued; on
  `Transform="wavelet"`, `InstantaneousFrequency` /
  `InstantaneousEnergy` / `WaveletEntropy` are vector-valued).
  See the per-transform feature × parameter tables in
  `signal-time-frequency-feature-extractor.md`.

## API: `setScalarizationMethods`

```matlab
setScalarizationMethods(sFE, "FeatureName", Mean=true, StandardDeviation=true, ...);
```

Rules:

* **Name-value syntax only.** Passing a positional string for the
  method (e.g., `..., "mean"`) raises
  `No value was given for 'Mean'`.
* **Multiple methods in one call.** All ten can be set together:
  `setScalarizationMethods(sFE, "InstantaneousFrequency", Mean=true, StandardDeviation=true, Kurtosis=true)`.
* **Output is additive, not substitutive.** Each enabled method
  adds a new column named `<FeatureName><MethodName>` (e.g.,
  `InstantaneousFrequencyMean`) next to the original vector
  column. The vector column is retained unchanged.
* **Drop the vector column post-extract** if you only need the
  scalars: `t = removevars(t, "InstantaneousFrequency")`.
* **The feature flag must be `true` first.** Calling
  `setScalarizationMethods` for a feature that isn't enabled does
  not enable it.

## API: `getScalarizationMethods`

```matlab
m = getScalarizationMethods(sFE, "FeatureName");
```

Returns a string array of method names currently enabled for that
feature. Use this to verify the configuration before calling
`extract`.

A separate internal method `getScalarMethods` (without the "ization"
infix) exists on the time-frequency extractor object but takes no
arguments and is not part of the documented surface — do not call
it as `getScalarMethods(sFE, "FeatureName")`.

## Choosing scalarization vs. host-side aggregation

Use `setScalarizationMethods` when you want the scalar summary
inside the feature *table*, alongside per-frame values, so a
classifier can consume both. Useful when the per-frame vector is
long (`InstantaneousFrequency` on the wavelet transform is
per-sample resolution and can dominate memory).

Compute host-side (`mean(T.col, 2)`, `std(T.col, 0, 2)`) when:

* You only need cross-frame statistics, not intra-row.
* The vector column is small enough that you'd rather post-process
  in one place.
* You're working with the time extractor (where scalarization is
  degenerate).

## Common solutions

| What you tried | Fix |
|---|---|
| Used `Maximum` / `Median` / `RMS` / `Variance` etc. | Pick from the ten valid names: `Mean`, `StandardDeviation`, `PeakValue`, `Kurtosis`, `Skewness`, `ClearanceFactor`, `CrestFactor`, `ImpulseFactor`, `Energy`, `Entropy`. |
| Used `Entropy=true` on `WaveletEntropy` or `SpectralEntropy` | Drop `Entropy` from the call for those two features; the other nine methods still work. |
| Called scalarization on a time-extractor feature expecting cross-frame stats | Time features are already scalar per frame. Use `mean(T.col)`, `std(T.col)` host-side. |
| Vector column still in the output table after scalarization | `setScalarizationMethods` adds columns, doesn't replace. Drop with `removevars(t, "FeatureName")`. |
| `setScalarizationMethods(sFE, "FeatureName", "mean")` raised "No value was given for 'Mean'" | Use name-value: `setScalarizationMethods(sFE, "FeatureName", Mean=true)`. |

----

Copyright 2026 The MathWorks, Inc.

----
