# A-priori feature ranking from preliminary analysis

Before configuring an extractor, write down a ranked candidate feature list with one-line justifications tying each feature to the signal characteristics observed during preliminary analysis. This is **a-priori** ranking — driven by signal physics and domain knowledge, not by labels. Empirical (label-driven) ranking is v2.1 scope.

## Why rank features before extraction

- **Forces the question "why this feature?"** A justification per feature surfaces missing rationale before you spend compute extracting noise.
- **Right-sizes the feature set.** A ranked list with reasons is easy to trim — extracting 30 features when 6 carry the signal wastes time and risks overfitting downstream.
- **Documents intent.** When a downstream classifier underperforms, the ranked list is the artifact you re-examine.

## Pattern

After `spectralStationarityVerdict` (see `preliminary-analysis.md`) produces a verdict, build a candidate list:

```matlab
candidates = [
    "Feature",            "Justification";
    "MeanFrequency",      "Stationary harmonic — energy localizes at known frequencies";
    "PeakLocation",       "Identifies the dominant harmonic per frame";
    "BandPower",          "Quantifies energy in the band of interest";
    "OccupiedBandwidth",  "Sanity-check the spectrum width across frames"
];
disp(candidates)
```

Or as a string array printed before any `extract` call. Keep justifications to one line each.

## Span more than one domain for classification

For a **classifier or regressor feature table**, the strongest starting set almost always draws from more than one of the three extractors — even after the stationarity verdict names a single *primary* extractor. The verdict tells you which domain carries the *most* information, not the *only* information.

A non-stationary verdict is the most common trap: it is tempting to load up on time-frequency spectral-shape features (`SpectralEntropy`, `SpectralCrest`, `SpectralFlatness`, …) and stop there. In practice a spectrogram-only feature set often under-performs, because it discards two cheap and complementary signals:

- **Frequency-domain locators** — `PeakLocation` / `PeakAmplitude` (dominant-peak / formant proxies), `MedianFrequency`, `OccupiedBandwidth`. These pin *where* the energy sits per frame, which spectral-shape scalars do not.
- **Time-domain envelope / impulsiveness** — `RMS`, `CrestFactor`, `ShapeFactor`, `ImpulseFactor`, `PeakValue`. These capture onset, energy envelope, and transients.

Rule of thumb: for a classification feature table, aim for candidates from **at least two** of the three extractors, and include frequency-domain locators and time-domain envelope metrics alongside any time-frequency spectral-shape features. If a first-pass classifier scores near chance, **breadth across domains is the first lever to pull** — add the missing domains before reaching for a more complex model.

## Signal-profile → feature mapping

The four profiles below drop out of the preliminary analysis verdict. Use the row that matches your signal as the starting candidate set; trim once you have empirical evidence (v2.1).

| Signal profile | Recommended starting features | Why |
|---|---|---|
| Stationary periodic harmonic | `MeanFrequency`, `MedianFrequency`, `PeakAmplitude`, `PeakLocation`, `BandPower`, `THD`, `SINAD` | Periodic harmonics localize energy at discrete known frequencies; harmonic-distortion metrics quantify deviation from a single tone. |
| Stationary broadband | `SpectralEntropy` (TF), `OccupiedBandwidth`, `WelchPSD` (with scalarization), `BandPower` | Broadband energy needs distributional descriptors (entropy, occupied width) rather than single-tone metrics. |
| Non-stationary | **TF (primary):** `SpectralEntropy`, `InstantaneousFrequency`, `InstantaneousBandwidth`, `TFRidges`, `WaveletEntropy`. **Add Freq:** `MeanFrequency`, `MedianFrequency`, `PeakLocation`, `PeakAmplitude`, `OccupiedBandwidth`. **Add Time:** `RMS`, `CrestFactor`, `ShapeFactor`, `ImpulseFactor` | The spectrum changes over time, so time-frequency features are primary — but frequency-domain locators (where the energy sits) and time-domain envelope/impulsiveness metrics are cheap, complementary, and usually lift a classifier well above a spectrogram-only set. Do not stop at TF spectral-shape features. |
| Transient-dominated (or mixed harmonic + impulsive) | `RMS`, `PeakValue`, `CrestFactor`, `ImpulseFactor`, `ClearanceFactor`, `SpectralKurtosis` (TF), `PeakEnvelope` (TF, `wavelet` transform) | Impulsive events drive higher-order time-domain ratios; `SpectralKurtosis` detects impulsive events in the frequency domain and is especially strong when the signal has both harmonic content and transients; envelope-based TF features capture transient shape. |

`SpectralEntropy` is a `signalTimeFrequencyFeatureExtractor` feature, not a frequency-extractor feature. `THD` / `SINAD` live on the time extractor (with `SampleRate` set). `SpectralKurtosis` is a `signalTimeFrequencyFeatureExtractor` feature (requires `spectrogram`, `synchrosqueezedspectrogram`, or `synchrosqueezedscalogram` transform) — it is especially useful for signals with mixed harmonic and impulsive character where time-domain ratios alone may not discriminate faults. When in doubt, check the per-extractor reference before enabling a flag.

## What this is not

- Not label-driven scoring (`fscchi2`, `fscmrmr`, `fscnca`, `relieff`, mutual information) — v2.1.
- Not pairwise correlation pruning or constant-feature removal — v2.1.
- Not the v2.0 full mapping (rotating machinery, biosignals, modulation-specific features) — v2.0.

The deliverable here is a ranked candidate list with one-line reasons, written before `extract` runs. That's it.

----

Copyright 2026 The MathWorks, Inc.

----
