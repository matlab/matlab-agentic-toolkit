# Preliminary Data Analysis

When a user presents signal data, run these diagnostic steps **before** recommending a spectral analysis technique. Report findings to the user and use them to justify your estimator choice.

## Step 1: Sampling Characterization

Determine whether data is uniformly or non-uniformly sampled.

```matlab
% Check what the user provided
if exist('Fs','var')
    samplingType = "uniform";
    dt = 1/Fs;
elseif exist('t','var')
    dtVec = diff(t);
    jitter = std(dtVec) / mean(dtVec);
    if jitter < 0.01
        samplingType = "uniform";
        Fs = 1/mean(dtVec);
    elseif jitter < 0.05
        samplingType = "nearly-uniform";  % small jitter — pspectrum can resample
        Fs = 1/mean(dtVec);
    else
        samplingType = "non-uniform";
    end
end
```

**Decision:**
- `samplingType == "uniform"` → all estimators viable (proceed to next steps)
- `samplingType == "nearly-uniform"` (jitter 1–5%) → `pspectrum(x,t)` handles this automatically (resamples to uniform internally), then computes spectrum. All other estimators also work after explicit resampling with `resample(x,t,Fs)`.
- `samplingType == "non-uniform"` (jitter >5% or irregular gaps) → use `plomb(x,t)`. Stop here for estimator selection (other methods require uniform sampling).

## Step 2: Data Quality

Check for issues that affect spectral estimates.

```matlab
N = length(x);
hasNaN = any(isnan(x));
hasInf = any(isinf(x));
dcLevel = mean(x);
hasTrend = abs(mean(diff(x))) > 1e-10 * std(x);

fprintf("Samples: %d (duration: %.3f s)\n",N,N/Fs)
fprintf("DC level: %.4g\n",dcLevel)
fprintf("Has NaN: %s | Has Inf: %s | Has trend: %s\n", ...
    string(hasNaN),string(hasInf),string(hasTrend))
```

**Actions:**
- NaN/Inf present → interpolate (`fillmissing`) or use `plomb` with valid indices
- DC offset or trend clearly distorting spectrum → apply `detrend(x)`. Do not detrend blindly
- Very short signal (N < 64) → parametric methods (`pburg`) or `rootmusic` only

## Step 3: Signal Length Classification

Signal length relative to sample rate determines which estimators are viable.

```matlab
duration = N / Fs;
segLenWelch = round(N/8);  % typical Welch: 8 segments
dfWelch = Fs / segLenWelch;
dfFull = Fs / N;

fprintf("Duration: %.3f s | N = %d samples\n",duration,N)
fprintf("Full-length resolution: %.2f Hz\n",dfFull)
fprintf("Welch resolution (8 segments): %.2f Hz\n",dfWelch)

if N < 128
    lengthClass = "very-short";
elseif N < 1024
    lengthClass = "short";
elseif N < 10000
    lengthClass = "medium";
else
    lengthClass = "long";
end
```

**Decision:**
| Length Class | Viable Estimators |
|---|---|
| very-short (<128) | `pburg`, `pmtm`, `rootmusic` only |
| short (128–1024) | `pspectrum` (quick look), `pmtm` (low-variance without segmenting), `periodogram`, `pburg`, `rootmusic` |
| medium (1024–10k) | `pspectrum` (quick look), `periodogram`, `pwelch` (few segments), `pmtm`, `pburg` |
| long (>10k) | `pspectrum` (quick look), `pwelch` (preferred for low-variance PSD), `periodogram`, `pmtm`, `pburg` |

## Step 4: Spectral Character (Wideband vs Narrowband)

Use a quick `pspectrum` to classify spectral shape. A tonal signal has sharp peaks; a wideband signal has energy spread across many frequencies.

```matlab
% Detrend only if Step 2 identified DC/trend distortion
% x = detrend(x);

% Use periodogram (Hann) for classification — pspectrum's Kaiser window
% widens peaks and distorts width measurements
[pxx,f] = periodogram(x,hann(N),N,Fs);
pxxDB = pow2db(pxx);
df = f(2) - f(1);

% Spectral flatness: 1 = white noise, near 0 = tonal/concentrated
spectralFlat = db2pow(mean(pxxDB)) / mean(db2pow(pxxDB));

% Peak detection with width measurement
noiseFloor = median(pxxDB);
[peaks,peakFreqs,peakWidths,peakProms] = findpeaks(pxxDB,f,MinPeakProminence=10);
nProminentPeaks = numel(peaks);

% Peak width check: use the STRONGEST peak (most prominent) to distinguish
% narrow tones (~3-4 bins with Hann) from broadband bands/chirps (>>10 bins)
if nProminentPeaks >= 1
    [~,iStrongest] = max(peakProms);
    strongestWidth = peakWidths(iStrongest);  % Hz (half-prominence width)
    isNarrowPeaks = strongestWidth < 10*df;
else
    strongestWidth = 0;
    isNarrowPeaks = false;
end

fprintf("Spectral flatness: %.4f (1=white noise, 0=concentrated)\n",spectralFlat)
fprintf("Noise floor: %.1f dB | Prominent peaks: %d | Strongest peak width: %.1f Hz (%.1f bins)\n", ...
    noiseFloor,nProminentPeaks,strongestWidth,strongestWidth/df)

if spectralFlat > 0.3
    spectralChar = "wideband-noise";  % flat spectrum dominates; peaks are noise fluctuations
elseif nProminentPeaks >= 1 && spectralFlat < 0.1 && isNarrowPeaks
    spectralChar = "tonal";           % narrow peaks = discrete tones
elseif nProminentPeaks >= 1 && spectralFlat < 0.1 && ~isNarrowPeaks
    spectralChar = "wideband-structured";  % wide peaks = chirps, bands, or shaped noise
elseif nProminentPeaks >= 1
    spectralChar = "mixed";  % tones in noise (flatness 0.1–0.3)
else
    spectralChar = "wideband-structured";  % shaped but no prominent peaks
end
```

**Decision:**
- `"wideband-noise"` → `pwelch` for low-variance PSD (averaging reduces variance on broadband)
- `"tonal"` → `pspectrum(x,Fs)` for quick look; `periodogram` with `'power'` for accurate tone amplitudes; `rootmusic` if resolution-limited
- `"mixed"` → `pspectrum(x,Fs)` for initial exploration; `pwelch` for noise floor + `findpeaks` for tones; `pburg` if short
- `"wideband-structured"` → `pwelch` or `poctave` (if octave-band view appropriate)

## Step 5: AR Model Fitness Test

Determine if a low-order autoregressive model explains the signal well. If yes, `pburg` gives a clean, sidelobe-free PSD.

```matlab
% Fit AR models of increasing order, track prediction error
maxOrder = min(32,round(N/4));
orders = 2:2:maxOrder;
predErrors = zeros(size(orders));

for k = 1:numel(orders)
    [~,predErrors(k)] = arburg(x,orders(k));
end

% Normalized prediction error (relative to signal variance)
normPE = predErrors / var(x);

% Find "knee" — order beyond which error barely drops
relDrop = -diff(normPE) ./ normPE(1:end-1);
kneeIdx = find(relDrop < 0.05,1,'first');
if isempty(kneeIdx)
    bestOrder = orders(end);
    arFit = "poor";  % error still dropping, not a good AR model
else
    bestOrder = orders(kneeIdx);
    finalPE = normPE(kneeIdx);
    if finalPE < 0.1
        arFit = "excellent";
    elseif finalPE < 0.3
        arFit = "good";
    else
        arFit = "moderate";
    end
end

fprintf("AR fit: %s (best order: %d, residual energy: %.1f%%)\n", ...
    arFit,bestOrder,normPE(kneeIdx)*100)
```

**Decision:**
- `"excellent"` or `"good"` → `pburg(x,bestOrder,[],Fs)` is a strong candidate (smooth, no sidelobes)
- `"moderate"` or `"poor"` → nonparametric methods preferred (`pwelch`, `periodogram`)

## Step 6: Discrete Tone Count (for Subspace Methods)

If the signal appears tonal, estimate the number of sinusoidal components. This is required for MUSIC/root-MUSIC.

```matlab
% Only run if spectral character is tonal or mixed
if ismember(spectralChar,["tonal","mixed"])
    % Use pwelch for smoother PSD (pspectrum oversamples, inflates peak count)
    [pWelch,fWelch] = pwelch(x,hann(min(N,256)),[],[],Fs);
    pWelchDB = pow2db(pWelch);
    [~,locs] = findpeaks(pWelchDB,fWelch, ...
        MinPeakProminence=6, ...
        MinPeakDistance=max(dfFull*3,Fs/100));
    nTones = numel(locs);

    % Cross-check with eigenvalue analysis (MDL criterion)
    if N >= 64
        corrOrder = min(floor(N/2)-1,64);  % must be < N
        [~,~,~,eigvals] = pmusic(x,corrOrder,[],Fs);
        % Sharp drop in eigenvalues separates signal from noise subspace
        logEig = log(eigvals(1:min(30,numel(eigvals))));
        dLogEig = diff(logEig);
        nTonesMDL = find(abs(dLogEig) < 0.5*median(abs(dLogEig)),1,'first');
        if isempty(nTonesMDL)
            nTonesMDL = nTones;  % fallback to peak count
        end
    else
        nTonesMDL = nTones;
    end

    fprintf("Estimated tone count: %d (peak-based) / %d (eigenvalue-based)\n", ...
        nTones,nTonesMDL)
end
```

**Decision:**
- Known/estimated tone count + short data or resolution limit → `rootmusic(x,2*nTones,Fs)` for frequency estimates
- Unknown tone count or broadband → stick with nonparametric

## Summary: Mapping Diagnostics to Estimator

| Diagnostic Result | Recommended Estimator |
|---|---|
| Quick look (any signal) | `pspectrum(x,Fs)` — good defaults, tune `Leakage` if needed |
| Nearly-uniform (small jitter <5%) | `pspectrum(x,t)` — resamples internally; or `resample(x,t,Fs)` then any estimator |
| Non-uniform sampling (large jitter/gaps) | `plomb(x,t)` |
| Very short + tonal | `rootmusic` or `pburg` |
| Short + low-variance PSD needed | `pmtm(x,nw,[],Fs)` — no AR assumption, no segmentation |
| Short + good AR fit | `pburg(x,order,[],Fs)` |
| Short + poor AR fit | `pmtm(x,nw,[],Fs)` or `periodogram(x,win,N,Fs)` |
| Long + wideband | `pwelch` (averaging smooths noise) |
| Long + tonal | `periodogram(x,win,N,Fs,'power')` → `findpeaks` |
| Tonal + resolution-limited (tones closer than Fs/N) | `rootmusic(x,2*nTones,Fs)` |
| Mixed (tones + noise) | `pwelch` for noise characterization + `findpeaks` for tones |
| Acoustics/vibration (any length) | `poctave(x,Fs,'BandsPerOctave',3)` |

## Reporting Template

After running the diagnostics, report to the user:

```
Preliminary Analysis:
- Sampling: [uniform at Fs Hz / non-uniform]
- Duration: X s (N samples)
- Frequency resolution: X Hz (full-length)
- Spectral character: [wideband-noise / tonal / mixed / wideband-structured]
- AR model fit: [excellent/good/moderate/poor] (order N, residual X%)
- Estimated tones: N (if tonal)

Recommendation: [estimator] because [1-sentence justification]
```

----

Copyright 2026 The MathWorks, Inc.

----
