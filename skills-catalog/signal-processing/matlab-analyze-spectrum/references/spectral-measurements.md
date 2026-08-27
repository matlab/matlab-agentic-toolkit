# Spectral Measurements

Built-in functions for extracting quantitative metrics from spectra. Use these instead of manual computation.

## Band Power

Measure power in a specific frequency band.

```matlab
% From time-domain signal
p = bandpower(x,Fs,[fLow fHigh]);

% From PSD (already computed)
p = bandpower(pxx,f,[fLow fHigh],'psd');

% Total signal power (equivalent to rms(x)^2 for zero-mean)
pTotal = bandpower(x,Fs,[0 Fs/2]);

% Relative band power (fraction of total)
relPower = bandpower(x,Fs,[fLow fHigh]) / bandpower(x,Fs,[0 Fs/2]);
```

## Occupied Bandwidth

The frequency band containing a specified percentage (default 99%) of total power.

```matlab
% 99% occupied bandwidth (default)
bw = obw(x,Fs);

% 95% occupied bandwidth
bw = obw(x,Fs,[0 Fs/2],95);

% With frequency bounds returned
[bw,fLow,fHigh,power] = obw(x,Fs);

% From power spectrum (not PSD) — must supply resolution bandwidth
[ps,f] = pwelch(x,win,[],[],Fs,'power');
rbw = enbw(win) * Fs / length(win);
bw = obw(ps,f,rbw);
```

## Power Bandwidth

The 3-dB bandwidth -- frequency range where PSD is within 3 dB of the peak.

```matlab
% Default (3-dB down from peak)
bw = powerbw(x,Fs);

% Custom reference level (6-dB bandwidth)
bw = powerbw(x,Fs,[],6);

% With bounds
[bw,fLow,fHigh] = powerbw(x,Fs);

% From power spectrum (not PSD) — must supply resolution bandwidth
[ps,f] = pwelch(x,win,[],[],Fs,'power');
rbw = enbw(win) * Fs / length(win);
bw = powerbw(ps,f,rbw);
```

## Spectral Peaks

Find dominant frequencies, harmonics, and interference tones.

```matlab
% Compute PSD first
[pxx,f] = pwelch(x,hann(1024),[],[],Fs);
pxxDB = pow2db(pxx);

% Find peaks with constraints
[peakPowers,peakFreqs] = findpeaks(pxxDB,f, ...
    MinPeakHeight=-30, ...       % ignore below -30 dB
    MinPeakDistance=20, ...      % at least 20 Hz apart
    MinPeakProminence=6, ...     % must stand out by 6 dB
    NPeaks=10, ...              % return at most 10 peaks
    SortStr="descend");          % strongest first
```

### Harmonic Detection Pattern

```matlab
f0 = peakFreqs(1);  % fundamental
nHarmonics = 5;
harmonicFreqs = f0 * (1:nHarmonics);
tolerance = 5;  % Hz

foundHarmonics = false(1,nHarmonics);
for k = 1:nHarmonics
    foundHarmonics(k) = any(abs(peakFreqs - harmonicFreqs(k)) < tolerance);
end
```

## Spectral Entropy

Measure spectral complexity/randomness (0 = pure tone, 1 = white noise).

**Use `spectralEntropy`** (introduced R2019a). The older `pentropy` is deprecated and will be removed.

```matlab
% Scalar entropy of the whole signal
se = spectralEntropy(x,Fs,Instantaneous=false);

% Time-varying spectral entropy (default)
[se,t] = spectralEntropy(x,Fs);

% Limit frequency range
se = spectralEntropy(x,Fs,Range=[50 400]);
```

Note: `spectralEntropy` requires column-vector input (`x(:)`).

## Lomb-Scargle Detection Thresholds (plomb)

`plomb` can return power-level thresholds for given detection probabilities via the `Pd` name-value pair. Use this to assess statistical significance of spectral peaks in non-uniformly sampled data.

```matlab
% Return thresholds for 50%, 90%, 99% detection probability
[pxx,f,pth] = plomb(x,t,[],'psd',Pd=[0.5 0.9 0.99]);

% Plot with significance line
figure
plot(f,pxx)
hold on
yline(pth(3),'--r',Label="99% detection")
hold off
xlabel("Frequency (Hz)")
ylabel("PSD")
title("Lomb-Scargle with Detection Threshold")
```

Key points:
- `pth` is a vector with one threshold per requested probability
- Works with `'psd'`, `'power'`, or `'normalized'` spectrum types
- With `'normalized'` output, thresholds follow an exponential distribution under the null hypothesis (no signal)

## Reassigned Periodogram

Reassignment sharpens spectral peaks by moving energy from each bin to its center-of-energy frequency. Useful for closely-spaced tones or chirps.

```matlab
% Reassigned periodogram: returns both reassigned and standard PSD + center freqs
[rpxx,f,pxx,fc] = periodogram(x,hann(N),N,Fs,'reassigned');

% fc contains the center-of-energy frequency for each bin
% rpxx is the reassigned PSD (energy redistributed to true frequencies)

% Also works with 'power' output
[rps,f,ps,fc] = periodogram(x,hann(N),N,Fs,'power','reassigned');
```

Key points:
- Output has 4 arguments: `[reassigned, f, standard, center_freqs]`
- `fc` (center-of-energy frequencies) tells you where energy truly lives within each bin
- Reassignment sharpens peaks but can create artifacts in noisy spectra
- Only available for `periodogram`, not `pwelch`

## Mean and Median Frequency

Scalar descriptors of the spectral "center of mass." Useful for characterizing where spectral energy is concentrated.

```matlab
% Mean frequency (power-weighted average frequency)
fMean = meanfreq(x,Fs);

% Median frequency (frequency that divides power in half)
fMed = medfreq(x,Fs);

% From PSD (already computed)
fMean = meanfreq(pxx,f);
fMed = medfreq(pxx,f);

% Restrict to a band
fMean = meanfreq(x,Fs,[100 500]);

% From power spectrum (not PSD) — supply resolution bandwidth
[ps,f] = pwelch(x,win,[],[],Fs,'power');
rbw = enbw(win) * Fs / length(win);
fMean = meanfreq(ps,f,rbw);
```

Key points:
- `meanfreq` = power-weighted centroid; sensitive to spectral tails
- `medfreq` = frequency splitting total power 50/50; robust to outlier energy
- Both accept time-domain signals or pre-computed PSD/power spectrum

## Signal-to-Noise Ratio (from spectrum)

```matlab
% SNR of a sinusoidal signal in noise
r = snr(x,Fs);

% SNR with known signal frequency
r = snr(x,Fs,f0);

% Total harmonic distortion
thd_value = thd(x,Fs);

% SINAD (signal-to-noise-and-distortion)
s = sinad(x,Fs);
```

## Spurious Free Dynamic Range (SFDR)

Distance (dB) between fundamental and the largest spurious component.

```matlab
% From time-domain signal
r = sfdr(x,Fs);

% With minimum spur distance (ignore spurs within 100 Hz of fundamental)
r = sfdr(x,Fs,100);

% From power spectrum
[ps,f] = periodogram(x,hann(N),N,Fs,'power');
r = sfdr(ps,f,'power');

% Get spur frequency and power
[r,spurPow,spurFreq] = sfdr(x,Fs);
```

## Third-Order Intercept (TOI/OIP3)

Measures third-order intermodulation distortion in a two-tone signal.

```matlab
% From time-domain two-tone signal
oip3 = toi(x,Fs);

% Full output: fundamental + intermod powers and frequencies
[oip3,fundPow,fundFreq,imodPow,imodFreq] = toi(x,Fs);

% From PSD
[pxx,f] = pwelch(x,[],[],[],Fs);
oip3 = toi(pxx,f,'psd');
```

Key points:
- Input must be a two-tone signal (two sinusoids)
- Returns OIP3 in dBW (or dB relative to input units)
- Intermodulation products appear at `2*f1-f2` and `2*f2-f1`

## Spectral Shape Descriptors

Scalar statistics describing the shape of the power spectrum. All accept time-domain signals (with windowed STFT internally) or pre-computed spectra.

```matlab
% Spectral flatness: ratio of geometric to arithmetic mean (0=tonal, 1=white noise)
flatness = spectralFlatness(x,Fs);

% Spectral crest: peak-to-mean ratio (high=tonal, low=flat/noise-like)
crest = spectralCrest(x,Fs);

% Spectral skewness: asymmetry of the spectral distribution
skew = spectralSkewness(x,Fs);

% Spectral kurtosis: peakedness/tailedness of spectral distribution
kurt = spectralKurtosis(x,Fs);

% With confidence threshold for non-stationarity detection (requires Scaled=false)
[kurt,~,~,threshold] = spectralKurtosis(x,Fs,Scaled=false,ConfidenceLevel=0.95);

% Restrict frequency range
flatness = spectralFlatness(x,Fs,Range=[100 4000]);

% From frequency-domain input (pre-computed spectrum + freq vector)
flatness = spectralFlatness(pxx,f);
```

Key points:
- All require **column-vector** input (`x(:)`) — a row vector is treated as multi-channel with length 1 per channel.
- These return **time-varying** values by default (one per frame). Use `Instantaneous=false` (for `spectralEntropy`) or process the full signal as one window to get a scalar.
- `spectralFlatness` ≈ same concept as Wiener entropy; use to distinguish tonal vs broadband signals
- `spectralKurtosis` is useful for detecting transients/non-stationarity in vibration signals; values exceeding the confidence threshold indicate non-Gaussian frequency content. `ConfidenceLevel` requires `Scaled=false`
- All share the same name-value interface: `Window`, `OverlapLength`, `FFTLength`, `Range`, `SpectrumType`

## Summary Table

| Measurement | Function | Input | Output |
|-------------|----------|-------|--------|
| Power in band | `bandpower` | Signal or PSD + freq range | Watts (linear) |
| 99% bandwidth | `obw` | Signal + Fs | Hz |
| 3-dB bandwidth | `powerbw` | Signal + Fs | Hz |
| Mean frequency | `meanfreq` | Signal or PSD + Fs | Hz |
| Median frequency | `medfreq` | Signal or PSD + Fs | Hz |
| Peak frequencies | `findpeaks` | PSD in dB + freq vector | dB, Hz |
| Spectral entropy | `spectralEntropy` | Signal + Fs | 0-1 (normalized) |
| Spectral flatness | `spectralFlatness` | Signal or spectrum + Fs | 0-1 |
| Spectral crest | `spectralCrest` | Signal or spectrum + Fs | ratio |
| Spectral skewness | `spectralSkewness` | Signal or spectrum + Fs | unitless |
| Spectral kurtosis | `spectralKurtosis` | Signal or spectrum + Fs | unitless |
| SNR | `snr` | Signal + Fs | dB |
| THD | `thd` | Signal + Fs | dB |
| SINAD | `sinad` | Signal + Fs | dB |
| SFDR | `sfdr` | Signal or spectrum + Fs | dB |
| TOI (OIP3) | `toi` | Two-tone signal or PSD + Fs | dBW |

----

Copyright 2026 The MathWorks, Inc.

----
