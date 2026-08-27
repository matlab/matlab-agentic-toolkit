# Robust Spectral Peak Detection

How to reliably identify real spectral peaks and avoid false positives from noise. The key principle: **always set thresholds relative to the noise floor, not as absolute values.**

## The Problem

A single FFT of a noisy signal has variance equal to its mean — noise peaks look as tall as weak signal peaks. Using `findpeaks` with a fixed `MinPeakHeight` threshold set near the noise floor produces massive false positive rates (80%+ spurious peaks).

## Solution: Noise-Floor-Relative Detection

### Step 1: Estimate the Noise Floor

```matlab
[pxx,f] = pwelch(x,hann(segLen),[],[],Fs);
pxxDB = pow2db(pxx);

% Median is robust to outliers (signal peaks don't bias it)
noiseFloorDB = median(pxxDB);
```

Alternatives:
- `quantile(pxxDB, 0.25)` — more conservative (lower quartile)
- Fit a polynomial to the log-spectrum and subtract (for colored noise)

### Step 2: Set Threshold Relative to Noise

```matlab
% Peaks must be at least 6 dB above noise floor
threshold = noiseFloorDB + 6;

[peaks,locs] = findpeaks(pxxDB,f, ...
    MinPeakHeight=threshold, ...
    MinPeakProminence=6, ...     % must stand out 6 dB from surroundings
    MinPeakDistance=10);         % at least 10 Hz apart (adjust per application)
```

### Step 3: Report with Confidence

```matlab
% SNR of each peak above noise floor
peakSNR = peaks - noiseFloorDB;

% Build results table
peakTable = table(locs(:),peaks(:),peakSNR(:), ...
    VariableNames=["Frequency_Hz","Power_dB","SNR_dB"]);
peakTable = sortrows(peakTable,"Power_dB","descend");
disp(peakTable)
```

Output:
```
    Frequency_Hz    Power_dB    SNR_dB
    ____________    ________    ______
         50          -12.3       18.7
        120          -18.1       12.9
```

## Complete Pattern

```matlab
Fs = 1000;
x = detrend(x);  % remove DC/trend if not meaningful

% Use pwelch for peak detection (averaging reduces noise variance)
segLen = min(1024,length(x)/4);  % ensure at least 4 segments
[pxx,f] = pwelch(x,hann(segLen),[],[],Fs);
pxxDB = pow2db(pxx);

% Estimate noise floor
noiseFloorDB = median(pxxDB);

% Detect peaks with noise-relative threshold
[peaks,locs] = findpeaks(pxxDB,f, ...
    MinPeakHeight=noiseFloorDB + 6, ...
    MinPeakProminence=6, ...
    SortStr="descend", ...
    NPeaks=10);

% Visualize
figure
plot(f,pxxDB)
hold on
yline(noiseFloorDB,"--r",Label="Noise floor")
yline(noiseFloorDB+6,"--g",Label="Detection threshold")
plot(locs,peaks,"vk",MarkerFaceColor="r",MarkerSize=8)
hold off
xlabel("Frequency (Hz)")
ylabel("PSD (dB/Hz)")
title("Peak Detection with Noise Floor Estimation")
legend("PSD","Noise floor","Threshold","Peaks",Location="best")
```

## Why pwelch Is Better Than FFT for Peak Detection

| Method | Noise Variance | Peak Detection Quality |
|--------|:-------------:|----------------------|
| Single FFT (`periodogram`) | High (chi-squared, 2 DOF) | Many false positives |
| `pwelch` (K segments) | Low (reduced by factor K) | Clean, reliable peaks |
| `pspectrum` (adaptive) | Medium-Low | Good for exploration |

A single FFT has so much spectral noise variance that weak tones are indistinguishable from noise fluctuations. Welch averaging with K segments reduces variance by ~K, making real peaks stand out clearly.

## Guideline: How Many dB Above Noise?

| SNR above noise floor | Confidence |
|:--------------------:|-----------|
| < 3 dB | Unreliable — could be noise |
| 3-6 dB | Possible — verify with more data or different parameters |
| 6-10 dB | Likely real — report with caveat |
| > 10 dB | Confident — real spectral peak |

## Advanced: Harmonic Detection

When you find a fundamental frequency, check for harmonics:

```matlab
f0 = locs(1);  % strongest peak = assumed fundamental
nHarmonics = 5;
tolerance = f(2)-f(1);  % one bin width

harmonicFreqs = f0 * (2:nHarmonics+1);
foundHarmonics = false(1,nHarmonics);
harmonicPowers = nan(1,nHarmonics);

for k = 1:nHarmonics
    [~,idx] = min(abs(f - harmonicFreqs(k)));
    if pxxDB(idx) > noiseFloorDB + 6
        foundHarmonics(k) = true;
        harmonicPowers(k) = pxxDB(idx);
    end
end

fprintf("Fundamental: %.1f Hz (%.1f dB)\n",f0,peaks(1));
fprintf("Harmonics found: %d of %d\n",sum(foundHarmonics),nHarmonics);
```

## Sub-Bin Peak Refinement with refinepeaks

After `findpeaks` identifies peaks at discrete frequency bins, use `refinepeaks` to get sub-bin frequency and amplitude accuracy (interpolation beyond the FFT grid).

```matlab
% Detect peaks at bin locations (use dB scale + noise-floor threshold)
[pxx,f] = periodogram(x,hann(N),N,Fs);
pxxDB = pow2db(pxx);
noiseFloorDB = median(pxxDB);
[~,peakIdx] = findpeaks(pxxDB, ...
    MinPeakHeight=noiseFloorDB+10, ...
    MinPeakProminence=10);

% Refine to sub-bin accuracy (QLS = quadratic least squares, default)
[yRefined,fRefined] = refinepeaks(pxx,peakIdx,f);

% Or use NLS (nonlinear least squares) for higher accuracy on windowed data
[yRefined,fRefined] = refinepeaks(pxx,peakIdx,f,Method="NLS");
```

**When to use:**
- Tone frequency is not exactly on an FFT bin → `findpeaks` gives the nearest bin, `refinepeaks` interpolates to true frequency
- Need amplitude accuracy better than scalloping loss allows
- Alternative to using `flattopwin` when you need both frequency and amplitude accuracy

**Methods:**
- `"QLS"` (default): Fits a parabola to the peak neighborhood — fast, good for most cases
- `"NLS"`: Fits a sinc kernel iteratively (Gauss-Newton) — more accurate for windowed DFTs, slower

**Key points:**
- Input `xPeaksIdx` must be integer indices (from `findpeaks` second output using index form, not frequency form)
- Works with any spectral data (PSD, power spectrum, amplitude spectrum)
- Pairs naturally with `findpeaks`: detect first, refine second

## Common Mistakes

| Mistake | Result | Fix |
|---------|--------|-----|
| `MinPeakHeight=0.1` (absolute) on dB spectrum | Threshold at wrong scale | Use noise-floor-relative threshold |
| Using raw FFT for peak detection | 80%+ false positives | Use `pwelch` for averaged spectrum |
| Not using `MinPeakProminence` | Detects shoulders and ripples | Always set prominence ≥ 3 dB |
| `MinPeakDistance` too small | Multiple detections of one broad peak | Set to expected minimum separation between real peaks |
| Not detrending when DC is irrelevant | DC peak dominates, masks real peaks | `x = detrend(x)` before analysis |

----

Copyright 2026 The MathWorks, Inc.

----
