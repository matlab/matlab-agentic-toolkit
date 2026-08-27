# Spectral Estimator Comparison

Detailed trade-offs for choosing between nonparametric spectral estimators.

## Decision Matrix

| Criterion | `pspectrum` | `periodogram` | `pwelch` | `pmtm` | Manual FFT |
|-----------|-------------|---------------|----------|--------|------------|
| Ease of use | Best | Good | Good | Good | Manual |
| Frequency resolution | Adaptive | Fs/N | Fs/segLen | 2*nw*Fs/N | Fs/N (or Fs/nfft if zero-padded, but no true improvement) |
| Variance | Low (adaptive) | High | Low | Low | High |
| Amplitude accuracy | Calibrated | Calibrated | Calibrated | Calibrated | Manual normalization |
| Window control | Automatic | Full | Full | nw parameter | Full |
| Output type | Power spectrum | PSD or power | PSD or power | PSD | Raw complex |
| Streaming capable | No | No | No | No | Yes (with overlap-save) |
| Best for short data | OK | High variance | Can't segment | Excellent | High variance |

## When to Use Each

### `pspectrum` (default choice)

- Quick exploration of frequency content
- When you don't want to tune window/overlap parameters
- Returns calibrated power spectrum

```matlab
% Power spectrum (default)
[p,f] = pspectrum(x,Fs);

% Explicit 'power' type (same as default — pspectrum has NO PSD output)
[p,f] = pspectrum(x,Fs,'power');
```

### `periodogram`

- Short signals where segmentation isn't possible
- Need exact frequency resolution = Fs/N
- Single-window analysis (no averaging)
- Supports modified periodogram (custom window)

```matlab
[pxx,f] = periodogram(x,hann(length(x)),length(x),Fs);
```

### `pwelch`

- Long signals where you want low-variance PSD
- Need to control segment length (frequency resolution) explicitly
- Statistical reliability matters (averaged segments)
- Classic choice for noise floor estimation

```matlab
segLen = 1024;
[pxx,f] = pwelch(x,hann(segLen),segLen/2,[],Fs);
```

### `pmtm` (multitaper)

- Short signals where Welch can't segment effectively
- Need low-variance PSD without losing frequency resolution
- No assumption about underlying signal model (unlike `pburg`)
- Need well-characterized confidence intervals (chi-squared with 2K DOF)
- Maximum spectral information extraction from limited data

```matlab
nw = 4;  % time-halfbandwidth product; K = 2*nw-1 = 7 tapers
[pxx,f] = pmtm(x,nw,[],Fs);

% With 95% confidence bounds
[pxx,f,pxxc] = pmtm(x,nw,[],Fs,ConfidenceLevel=0.95);
```

**Key trade-off vs. Welch:** Multitaper uses the full record (resolution = 2*nw*Fs/N) while Welch segments it (resolution = Fs/segLen). For the same data length, multitaper preserves resolution while reducing variance through orthogonal tapers rather than segment averaging.

**Choosing `nw`:** Default is 4 (7 tapers). Increase for smoother PSD (wider bandwidth); decrease for finer resolution. Resolution bandwidth = 2*nw*Fs/N Hz.

### Manual FFT

- Need complex spectrum (magnitude AND phase)
- Need single-sided amplitude spectrum in physical units
- Building custom spectral processing pipelines
- Educational or when full control over normalization is required

```matlab
N = length(x);
w = hann(N);
X = fft(x .* w,N);
f = (0:N/2) * Fs/N;
P = (2/(N*mean(w)))^2 * abs(X(1:N/2+1)).^2;  % power, window-corrected
```

## Window Effects on Spectral Estimates

| Window | Main-lobe width (bins) | Side-lobe level (dB) | Best for |
|--------|----------------------|---------------------|----------|
| Rectangular | 1 | -13 | Frequency resolution (no leakage concern) |
| Hann | 2 | -31 | General purpose |
| Hamming | 2 | -43 | Better side-lobe suppression |
| Blackman-Harris | 4 | -92 | Detecting weak signals near strong ones |
| Kaiser (beta=5) | ~2.4 | -37 | Tunable trade-off |
| Flat-top | 5 | -44 | Amplitude accuracy (calibration) |

**Rule of thumb:** Use Hann as default. Use flat-top when amplitude accuracy matters more than frequency resolution. Use Blackman-Harris when dynamic range matters.

## Frequency Resolution vs. Variance Trade-off

For `pwelch` with a signal of length `N` samples:

- **Segment length `L`** controls frequency resolution: `df = Fs/L`
- **Number of segments `K`** controls variance: `K ~ N/L` (with 50% overlap, `K ~ 2N/L - 1`)
- **Variance of PSD estimate** ~ `1/K` (more segments = smoother)

You cannot simultaneously have fine frequency resolution AND low variance from a fixed-length signal. This is a fundamental trade-off:
- Want better frequency resolution? Use longer segments (fewer averages, higher variance)
- Want lower variance? Use shorter segments (more averages, coarser frequency resolution)
- Want both? Acquire more data

----

Copyright 2026 The MathWorks, Inc.

----
