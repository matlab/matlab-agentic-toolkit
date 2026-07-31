# Cross-Signal Time-Frequency Analysis Guide

| Domain | Cross-spectrum | Coherence | Toolbox |
|--------|---------------|-----------|---------|
| CWT | `wcoherence` (2nd output) | `wcoherence` (1st output) | Wavelet |
| STFT | `xspectrogram` | — (no time-varying STFT coherence) | Signal Processing |
| Global (no time axis) | `cpsd` | `mscohere` | Signal Processing |

## Wavelet Coherence: wcoherence

`wcoherence` computes magnitude-squared wavelet coherence and the wavelet cross-spectrum between two equal-length real signals. It provides time-resolved coherence with automatic scale-smoothing.

### Syntax

```matlab
[wcoh, wcs, f, coi, wtx, wty] = wcoherence(x, y, fs);
[wcoh, wcs, f, coi, wtx, wty] = wcoherence(x, y, fs, ...
    FrequencyLimits=[flo fhi], VoicesPerOctave=16);
wcoherence(x, y, fs);   % no outputs → auto-plot with phase arrows
% NOTE: wcoherence has no Parent option — cannot direct plot to a specific
% axes/uiaxes. For App Designer or tiled layouts, compute outputs and
% reimplement the plot manually (imagesc + quiver for phase arrows).
```

### Outputs

| Output | Content | Size |
|--------|---------|------|
| `wcoh` | Magnitude-squared coherence ∈ [0, 1] | nFreq × nTime |
| `wcs` | Complex wavelet cross-spectrum (smoothed CWT_x · conj(CWT_y)) | nFreq × nTime |
| `f` | Frequency vector (Hz) | nFreq × 1 |
| `coi` | Cone of influence (Hz) | 1 × nTime |
| `wtx` | CWT of x (individual wavelet coefficients) | nFreq × nTime |
| `wty` | CWT of y (individual wavelet coefficients) | nFreq × nTime |

### Key Details

- Wavelet is **always `amor`** (analytic Morlet) — not configurable
- VoicesPerOctave range: **10–32** (default 12; narrower than `wsst`'s 10–48)
- Coherence formula: `|smooth(CWT_x · conj(CWT_y))|² / (smooth(|CWT_x|²) · smooth(|CWT_y|²))`
- Smoothing is across **scales** (not time) via `NumScalesToSmooth` (default: min(floor(nScales/2), VoicesPerOctave))
- Both signals must be **real** and **equal length** (≥ 4 samples)
- `NumOctaves` controls frequency range (default: `fix(log2(N))-1`); cannot combine with `FrequencyLimits` or `PeriodLimits`
- Supports `duration` objects for sampling period and `PeriodLimits` for geophysical/climate data
- COI boundary effects are significant at low frequencies — discard or flag regions outside COI

### Period-Based Analysis (Geophysical / Climate Data)

```matlab
% Input sampling interval as a duration → output in period units
wcoherence(x, y, years(1/12), PhaseDisplayThreshold=0.7);
[wcoh, wcs, P, coi] = wcoherence(x, y, seconds(0.1));
% P is now period vector (not frequency), COI is in period units
% PeriodLimits restricts the analysis range
[wcoh, wcs, P, coi] = wcoherence(x, y, years(1/12), PeriodLimits=[years(0.5) years(8)]);
```

When using period-based input, the y-axis displays period (low periods at top, high periods at bottom) and the COI is inverted relative to frequency-based plots.

### Phase Relationship

The cross-spectrum phase `angle(wcs)` gives the phase lag of Y relative to X at each time-frequency point. When plotted (zero-output call), arrows show this lag:
- → (right): in-phase — Y and X aligned (lag = 0)
- ← (left): anti-phase (lag = ±π)
- ↑ (up): Y lags X by π/2
- ↓ (down): Y leads X by π/2 (lag = −π/2)

The arrow angle equals `angle(wcs)` measured counterclockwise from rightward.

`PhaseDisplayThreshold` (default 0.5) suppresses phase arrows where coherence is below the threshold — **plot-only, has no effect on returned outputs**. Values above 0.7 typically produce clean, interpretable plots. When working programmatically (with outputs), apply your own mask: `phase(wcoh < 0.7) = NaN`.

### Converting Phase to Time Delay

At a given frequency (or period), phase difference translates to time delay:

```matlab
% Frequency-based: delay in seconds
delay = angle(wcs) ./ (2*pi*f);     % f is frequency vector (Hz)

% Period-based: delay as fraction of period
delay = angle(wcs) / (2*pi) .* (1./f);  % equivalent
```

For geophysical data at period P: a phase of π (anti-phase) = delay of P/2.

### Typical Workflow

```matlab
% 1. Compute coherence
[wcoh, wcs, f, coi] = wcoherence(x, y, fs);

% 2. Identify time-frequency regions of high coherence
mask = wcoh > 0.8;

% 3. Extract phase relationship in those regions
phase_diff = angle(wcs);
phase_diff(~mask) = NaN;

% 4. Determine lead/lag (convert phase to time delay)
% At frequency f_k, a phase difference φ corresponds to delay φ/(2πf_k)
delay = phase_diff ./ (2*pi*f);
```

### When wcoherence vs cwt

| Goal | Use |
|------|-----|
| Analyze ONE signal's time-frequency content | `cwt` |
| Compare TWO signals' shared oscillatory activity | `wcoherence` |
| Extract phase/lag between signals at specific frequencies | `wcoherence` (use `angle(wcs)`) |
| Perform individual CWTs of both signals | `wcoherence` (use 5th/6th outputs `wtx`, `wty`) |

### Advanced: Unsmoothed Cross-Spectrum and Velocity Change Estimation

The smoothed `wcs` (2nd output) trades temporal precision for stable coherence estimates. For applications requiring finer temporal resolution (e.g., seismic velocity monitoring), compute the **unsmoothed** cross-wavelet spectrum from the individual CWTs (5th/6th outputs):

```matlab
[wcoh, wcs, f, coi, wtref, wtcurr] = wcoherence(ref, curr, fs, ...
    FrequencyLimits=[0.5 5], VoicesPerOctave=32, NumScalesToSmooth=3);

% Unsmoothed cross-wavelet spectrum — finer temporal detail
xwt = wtref .* conj(wtcurr);

% Phase-to-delay: Δt(f,t) = φ(f,t) / (2πf)
phi = unwrap(angle(xwt), [], 2);       % unwrap along time axis
timeDelay = phi ./ (2*pi*f);            % f is column vector, broadcasts

% Weight by cross-spectrum amplitude (suppress low-energy regions)
W = log(1 + abs(xwt));
W = W ./ max(W, [], 2);                % normalize per frequency

% Relative velocity change: dv/v = -Δt/t
% Fit delay vs. travel-time using weighted least squares (lscov)
```

**Key points:**
- `NumScalesToSmooth=3` reduces smoothing for tighter temporal tracking
- `unwrap(..., [], 2)` prevents ±π jumps along the time dimension
- Weighting by `log(1+|xwt|)` downweights regions with poor SNR
- Use `lscov` for weighted least-squares when fitting delay vs. frequency or delay vs. time
- The smoothed `wcs` is appropriate for coda-wave analysis (scattered energy); unsmoothed `xwt` is better for direct-wave phase tracking

## Cross Spectrogram: xspectrogram

`xspectrogram` computes the time-varying cross-spectrum between two signals using the STFT. It uses the same windowed-segment approach as `spectrogram`.

### Syntax

```matlab
[S, F, T, P] = xspectrogram(x, y, window, noverlap, nfft, fs);
xspectrogram(x, y, window, noverlap, nfft, fs);   % no outputs → plot
```

### Outputs

| Output | Content |
|--------|---------|
| `S` | Magnitude of cross-spectrum (|CPSD|) — real, non-negative |
| `F` | Frequency vector |
| `T` | Time vector |
| `P` | Complex cross-power spectral density (4th output) — use for phase |

### Key Details

- Interface mirrors `spectrogram`: same window/noverlap/nfft/fs positional args
- **Critical difference from `spectrogram`:** `spectrogram`'s first output is the complex STFT; `xspectrogram`'s first output `S` is the cross-spectrogram — a purely real, non-negative quantity (`abs(cpsd(...))`). For the complex cross-spectrum (needed for phase), request the 4th output `P`.
- Internally computes `cpsd` segment-by-segment (no cross-segment averaging)
- **No reassignment option** — unlike `spectrogram("reassigned")`
- Both signals must be real, finite, non-sparse vectors
- Supports `FrequencyRange` ("onesided", "twosided", "centered") and `SpectrumType` ("psd", "power")

### Typical Workflow

```matlab
% 1. Compute cross spectrogram
win = hann(256);
[S, F, T, P] = xspectrogram(x, y, win, 200, 512, fs);

% 2. Plot magnitude
figure;
imagesc(T, F, 10*log10(S));
axis xy; colorbar;
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Cross Spectrogram Magnitude');

% 3. Extract phase difference (from 4th output)
phase_diff = angle(P);

% 4. Find coherent regions (threshold on magnitude)
coherent = S > 0.1 * max(S(:));
```

## Non-Time-Resolved Cross-Analysis (Welch Methods)

When you don't need time resolution (stationary relationship):

| Function | Output | Use Case |
|----------|--------|----------|
| `cpsd(x, y, window, noverlap, nfft, fs)` | Complex cross-PSD | Frequency-domain transfer function estimation |
| `mscohere(x, y, window, noverlap, nfft, fs)` | Coherence ∈ [0, 1] | Frequency bands where signals are linearly related |

These use Welch averaging (segment + average), giving a single spectrum — no time axis. The time-dependent nature of coherent behavior is completely obscured by these methods. Use `wcoherence` when the coherence relationship is non-stationary (appears/disappears over time, or the phase lag evolves).

## Decision Guide: Which Cross-Analysis Function?

```
Need time-resolved cross-analysis?
├── YES
│   ├── Want coherence (normalized measure)?
│   │   └── wcoherence (wavelet domain, multi-resolution)
│   ├── Want cross-spectrum with uniform frequency resolution?
│   │   └── xspectrogram (STFT domain)
│   └── Want both time-varying coherence AND uniform freq resolution?
│       └── No single function — compute xspectrogram, then manually
│           normalize: |Sxy|² / (Sxx · Syy) per time-frequency bin
│           (requires spectrogram of each signal individually)
└── NO (stationary/global relationship)
    ├── Cross-power spectral density → cpsd
    └── Magnitude-squared coherence → mscohere
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `mscohere` when time resolution is needed | `mscohere` averages across time (Welch method) — no time axis | Use `wcoherence` for time-varying coherence |
| Expecting `xspectrogram` to give coherence | `xspectrogram` returns cross-spectrum magnitude, not normalized coherence | Normalize manually, or use `wcoherence` |
| Using first output of `xspectrogram` for phase | First output `S` is magnitude (real) | Use 4th output `P` for complex cross-spectrum |
| Passing complex signals to `wcoherence` | Only real signals accepted | Take real/imag parts separately, or use magnitude |
| Expecting `xspectrogram("reassigned")` | Cross spectrogram has no reassignment option | Use standard `xspectrogram`; for sharp cross-analysis, use `wcoherence` |
| Using different VoicesPerOctave > 32 with `wcoherence` | Maximum is 32 (unlike `wsst` which allows 48) | Keep VoicesPerOctave ≤ 32 |
| Ignoring cone of influence in `wcoherence` | Boundary effects contaminate edge regions | Mask or discard time-frequency points outside COI |
| Interpreting `wcoherence` phase without checking coherence magnitude | Phase is meaningless where coherence is low | Only interpret `angle(wcs)` where `wcoh > threshold` (typically 0.5–0.8) |
| Using `wcoherence(..., Parent=ax)` to embed in App Designer | `wcoherence` has no `Parent` option (unlike `xspectrogram`/`spectrogram`) | Compute outputs programmatically, then build the plot manually with `imagesc` + `quiver` for phase arrows |

## Documentation References

| Topic | Link |
|-------|------|
| `wcoherence` reference | https://www.mathworks.com/help/wavelet/ref/wcoherence.html |
| `xspectrogram` reference | https://www.mathworks.com/help/signal/ref/xspectrogram.html |
| `cpsd` reference | https://www.mathworks.com/help/signal/ref/cpsd.html |
| `mscohere` reference | https://www.mathworks.com/help/signal/ref/mscohere.html |
| Wavelet coherence example | https://www.mathworks.com/help/wavelet/ug/compare-time-frequency-content-in-signals-with-wavelet-coherence.html |
| Seismic velocity changes via coherence | https://www.mathworks.com/help/wavelet/ug/relative-velocity-changes-in-seismic-waves-using-time-frequency-analysis.html |


----

Copyright 2026 The MathWorks, Inc.

----
