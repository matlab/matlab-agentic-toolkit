# Preliminary analysis before extractor selection

A small amount of upfront triage on a representative subset of signals will rule out the wrong extractor — and reduce the time spent debugging features that don't carry information. This is **preliminary triage**, not a full signal profile (the full profile is v2.0 scope).

## Why this matters

The three feature extractors target different signal regimes:

- `signalTimeFeatureExtractor` — impulsive / transient time-domain content.
- `signalFrequencyFeatureExtractor` — assumes a (locally) stationary spectrum.
- `signalTimeFrequencyFeatureExtractor` — non-stationary content where the spectrum changes over time.

Picking the wrong one wastes compute and produces features that don't separate classes. The decision that matters for extractor choice is **spectral** stationarity — does the frequency content change over time? — and you can answer it with Signal Processing Toolbox alone.

## Spectral-stationarity check (Signal Processing Toolbox only)

This is the primary, dependency-free method. It requires **no Econometrics Toolbox** — only the Signal Processing Toolbox you already have for the extractors.

**1. Look at a spectrogram.** One line tells you whether the dominant frequency drifts over time:

```matlab
pspectrum(x, fs, "spectrogram")
```

If a ridge of energy clearly moves across the frame (a rising/falling tone, a sweep, a formant track), the spectrum is non-stationary — reach for `signalTimeFrequencyFeatureExtractor`. If the energy sits at fixed frequencies for the whole signal, it's spectrally stationary.

**2. Quantify the drift.** For a numeric verdict that doesn't rely on eyeballing, track per-frame mean frequency and measure its relative spread. This *dogfoods* the frequency extractor — the same object you'll use downstream — so it needs nothing extra:

```matlab
function [verdict, driftRatio] = spectralStationarityVerdict(x, fs, thresh)
%spectralStationarityVerdict Signal-only spectral-stationarity check.
%   Tracks per-frame mean frequency and reports the coefficient of
%   variation (drift ratio). A spectrum that drifts over time produces a
%   large drift ratio. Uses only Signal Processing Toolbox.
    arguments
        x      (:, 1) double {mustBeFinite}
        fs     (1, 1) double {mustBePositive}
        thresh (1, 1) double {mustBePositive} = 0.05
    end

    sFE = signalFrequencyFeatureExtractor( ...
        SampleRate=fs, ...
        FrameSize=round(0.1 * fs), ...
        FrameOverlapLength=round(0.05 * fs), ...
        MeanFrequency=true, ...
        FeatureFormat="matrix");

    meanFreqPerFrame = extract(sFE, x);
    meanFreqPerFrame = meanFreqPerFrame(:);
    driftRatio = std(meanFreqPerFrame) / mean(meanFreqPerFrame);

    if driftRatio > thresh
        verdict = "non-stationary";   % spectrum drifts -> time-frequency extractor
    else
        verdict = "stationary";       % spectrum stable  -> frequency extractor
    end
end
```

A drift ratio well above the threshold means the spectral center moves frame to frame. As a calibration point: a fixed two-tone signal scores ≈ 0.002, while a 500→4000 Hz chirp scores ≈ 0.44 — over two orders of magnitude apart, so the exact threshold is not delicate. Run this on a small representative subset (e.g., one signal per class), not every file.

## Optional: mean/unit-root tests (Econometrics Toolbox)

**Skip this section if you do not have Econometrics Toolbox** — the spectral check above is the decisive one for extractor choice, and it stands alone.

If you *do* have Econometrics Toolbox, `adftest` and `kpsstest` add a second, orthogonal signal: they test for **mean / unit-root** stationarity (a random-walk trend), which the spectral check does not measure.

| Test | Returns `h = 1` when | Returns `h = 0` when |
|---|---|---|
| `adftest` | Stationary (rejects unit root) | Non-stationary |
| `kpsstest` | Non-stationary (rejects stationarity) | Stationary |

**Critical caveat — these do not replace the spectral check.** `adftest` and `kpsstest` test mean/unit-root stationarity, **not** spectral stationarity. A deterministic chirp has no random walk, so both tests will report it as "stationary" even though its spectrum sweeps across the band. For extractor selection — where the whole question is *does the spectrum change over time* — the spectrogram / drift-ratio check above is authoritative; treat a drifting spectrum as non-stationary regardless of the ADF/KPSS verdict.

```matlab
function verdict = meanStationarityVerdict(x)
%meanStationarityVerdict Combined ADF + KPSS mean-stationarity verdict.
%   Requires Econometrics Toolbox. Tests mean/unit-root stationarity only —
%   NOT spectral stationarity. Use spectralStationarityVerdict for extractor
%   choice; this is a supplementary trend check.
    arguments
        x (:, 1) double {mustBeFinite}
    end

    hAdf  = adftest(x);            % 1 = stationary
    hKpss = kpsstest(x);           % 0 = stationary

    if hAdf == 1 && hKpss == 0
        verdict = "stationary";
    elseif hAdf == 0 && hKpss == 1
        verdict = "non-stationary";
    else
        verdict = "ambiguous";     % tests disagree — inspect manually
    end
end
```

## Decision rules

| Verdict + character | Recommended extractor(s) | Starter feature flags |
|---|---|---|
| Stationary, narrowband / harmonic | `signalFrequencyFeatureExtractor` | `MeanFrequency`, `MedianFrequency`, `PeakAmplitude`, `PeakLocation`, `BandPower` |
| Stationary, broadband | `signalFrequencyFeatureExtractor` | `OccupiedBandwidth`, `WelchPSD` (with scalarization), `BandPower` |
| Non-stationary | `signalTimeFrequencyFeatureExtractor` **primary**, but pair with `signalFrequencyFeatureExtractor` (per-frame spectral shape) **and** `signalTimeFeatureExtractor` (envelope / impulsive metrics) | TF: `SpectralEntropy`, `InstantaneousFrequency`, `TFRidges`; Freq: `MeanFrequency`, `PeakLocation`, `OccupiedBandwidth`; Time: `RMS`, `CrestFactor` |
| Transient-dominated | `signalTimeFeatureExtractor` | `RMS`, `PeakValue`, `CrestFactor`, `ImpulseFactor`, `ClearanceFactor` |
| Ambiguous | Inspect a spectrogram before deciding. If the spectrum shifts over time, treat as non-stationary. | — |

**The verdict picks the *primary* extractor, not the *only* one.** For a classification or regression feature table, the strongest starting set almost always spans more than one domain — a non-stationary verdict does not mean "time-frequency features alone." See `feature-ranking.md` for the multi-domain candidate-list pattern; a set that collapses onto a single extractor is the most common cause of a weak downstream classifier.

For impulsiveness, the time extractor exposes `CrestFactor` / `ImpulseFactor` / `ClearanceFactor` — `Kurtosis` is **not** a time-extractor flag. See `signal-time-feature-extractor.md`.

## What this is not

- Not a full signal profile (periodicity, SNR, modulation, harmonic structure, sample-rate adequacy) — v2.0.
- Not label-driven empirical ranking — v2.1.
- Not preprocessing (DC removal, denoising, resampling) — v1.2.

The goal here is one decision: which extractor(s) to start with. Anything more is out of scope for v1.0.

----

Copyright 2026 The MathWorks, Inc.

----
