# pspectrum vs pwelch/periodogram Equivalence

How to obtain equivalent results between `pspectrum` and `pwelch`/`periodogram`. This is a common user question because `pspectrum` is convenient but opaque, while `pwelch`/`periodogram` give full control.

## Key Differences

| Property | `pspectrum` | `pwelch` | `periodogram` |
|----------|-------------|----------|---------------|
| Default output | Power spectrum (PS) | PSD | PSD |
| Can output PS? | Yes (only PS) | Yes (`'power'` flag) | Yes (`'power'` flag) |
| Can output PSD? | No | Yes (default) | Yes (default) |
| Units (PS mode) | signal² | signal² | signal² |
| Window | Kaiser (fixed family) | Any | Any |
| Resolution control | `FrequencyResolution` or `Leakage` | Segment length | Signal length |
| DC/Nyquist handling | Doubled (known overcompensation) | Not doubled | Not doubled |
| Output points | Fixed (default 4096) | NFFT/2+1 | NFFT/2+1 |

## The Fundamental Relationship

```
Power Spectrum = PSD × RBW
PSD = Power Spectrum / RBW
```

Where **RBW** (Resolution Bandwidth) = `enbw(window) × Fs / segmentLength`

This is the bridge between power spectrum and PSD output from any function.

## pspectrum Internal Algorithm (Default Settings)

With default `Leakage=0.5`:

1. **Window family**: `kaiser(nWindow, beta)` where `beta = 40*(1-Leakage)` → default beta=20
2. **Target RBW**: `max(ENBW/duration, 4*Fs/4095)` where ENBW ≈ 2.57 for Kaiser(β=20)
   - First term (`ENBW/duration`): the best resolution achievable given the signal length
   - Second term (`4*Fs/4095`): ensures at least 4 bins per output point (smoothing floor)
   - pspectrum picks whichever is larger → short signals are resolution-limited, long signals hit the smoothing floor
3. **Window length**: `min(N, round(Fs * ENBW / targetRBW))` — derived from `RBW = ENBW*Fs/nWindow`, solved for nWindow
4. **Initial stride**: `nWindow / (2*ENBW - 1)` — gives ~76% overlap for Kaiser(β=20), maximizing averaging while avoiding redundant computation
5. **Number of segments**: `1 + ceil((N - nWindow) / stride)`
6. **Recomputed stride** (when nSegments > 1): `(N - nWindow) / (nSegments - 1)` — redistributes stride evenly across all segments (may become fractional internally)
7. **Output**: 4096 frequency points (single-sided, 0 to Fs/2). This means NFFT = 2×(4096−1) = **8190** (since single-sided output has NFFT/2+1 points → 8190/2+1 = 4096)
8. **One-sided scaling**: Multiplies ALL bins by 2 — this overcompensates DC and Nyquist (acknowledged in source code comments)
9. **Frequency reassignment**: OFF by default. Only active when `Reassign=true`.

**Single-segment threshold**: For the default 4096 output points and Fs=1000 Hz, `pspectrum` uses a window of length `N-1`. For short signals, the "second segment" has negligible data and the result is effectively a single-window periodogram. For longer signals (N > ~2628 at Fs=1000), genuine Welch-like averaging occurs.

## Recipe 1: Exact Match for Short Signals

For signals where `pspectrum` effectively uses a single segment (short signals):

```matlab
Fs = 1000;
N = length(x);
beta = 20;  % default Leakage=0.5

% NFFT=8190 matches pspectrum's 4096 output points: NFFT/2+1 = 4096
[ps,f] = periodogram(x,kaiser(N,beta),8190,Fs,'power');

% Compare
[ps_ref,f_ref] = pspectrum(x,Fs);
% ps ≈ ps_ref on interior bins
% ps_ref(1) = 2*ps(1) at DC (pspectrum overcompensation)
% ps_ref(end) = 2*ps(end) at Nyquist (pspectrum overcompensation)
```

Works perfectly for signals up to ~2628 samples (at Fs=1000).

## Recipe 2: Approximate Match for Long Signals

For longer signals where `pspectrum` performs Welch averaging:

```matlab
Fs = 1000;
N = length(x);
beta = 20;

% Step 1: Compute pspectrum's internal parameters
estENBW = enbw(kaiser(1000,beta));
duration = (N-1)/Fs;
targetRBW = max(estENBW/duration, 4*Fs/4095);
nWindow = min(N, round(Fs * estENBW / targetRBW));

% Step 2: Compute stride and overlap
stride = nWindow / (2*estENBW - 1);
nSegments = 1 + ceil((N - nWindow)/stride);
if nSegments > 1
    stride = (N - nWindow) / (nSegments - 1);  % recompute (key step!)
end
ovlp = nWindow - floor(stride);

% Step 3: Compute power spectrum with pwelch
% NFFT=8190 to match pspectrum's 4096 output points (NFFT/2+1 = 4096)
[ps,f] = pwelch(x,kaiser(nWindow,beta),ovlp,8190,Fs,'power');

% Compare to pspectrum
[ps_ref,f_ref] = pspectrum(x,Fs);
% ps matches ps_ref within ~0.2 dB on interior bins
% Remaining difference: pspectrum uses fractional stride (sample-level processing)
% while pwelch requires integer hop size
```

**Why not exact for long signals**: `pspectrum` uses multiple parallel estimators with fractional sample offsets (CZT-based, sample-by-sample processing), while `pwelch` requires integer hop sizes. When the stride is not an integer, rounding introduces small differences (~0.2 dB typical).

## Recipe 3: Convert pwelch PSD to Power Spectrum

When you have `pwelch` PSD output and want to compare with `pspectrum`:

```matlab
% pwelch gives PSD by default
[psd,f] = pwelch(x,win,ovlp,[],Fs);
rbw = enbw(win) * Fs / length(win);
ps = psd * rbw;  % PSD → Power Spectrum

% Or directly request power spectrum:
[ps,f] = pwelch(x,win,ovlp,[],Fs,'power');
```

## Recipe 4: Convert pspectrum to PSD

```matlab
[ps,f] = pspectrum(x,Fs);

% Compute pspectrum's effective RBW
beta = 20;
estENBW = enbw(kaiser(1000,beta));
duration = (length(x)-1)/Fs;
targetRBW = max(estENBW/duration, 4*Fs/4095);
nWindow = min(length(x), round(Fs*estENBW/targetRBW));
rbw = enbw(kaiser(nWindow,beta)) * Fs / nWindow;

% Convert
psd = ps / rbw;
```

## Controlling pspectrum Parameters

| What you want | pspectrum parameter | Effect |
|---------------|-------------------|--------|
| Better frequency resolution | `'FrequencyResolution',value` | Longer window → narrower peaks |
| Less spectral leakage | `'Leakage',0.2` (lower) | Higher Kaiser beta → lower sidelobes, wider main lobe |
| More leakage, narrower peaks | `'Leakage',0.8` (higher) | Lower Kaiser beta → higher sidelobes, narrower main lobe |
| More output frequency points | `'FrequencyResolution',small_value` | More points, finer grid |
| Frequency reassignment | `Reassign=true` | Moves energy to true frequency bins (not default) |

**Leakage-to-beta mapping**: `beta = 40 * (1 - Leakage)`

| Leakage | Beta | ENBW (bins) | Approximate sidelobe level |
|---------|------|-------------|---------------------------|
| 0.0 | 40 | ~4.4 | -100 dB |
| 0.2 | 32 | ~3.6 | -82 dB |
| 0.5 (default) | 20 | ~2.6 | -55 dB |
| 0.8 | 8 | ~1.6 | -32 dB |
| 1.0 | 0 | 1.0 | -13 dB (rectangular) |

## Matching Resolution Between Functions

To match `pspectrum`'s resolution with `pwelch` (or vice versa):

```matlab
% If you have a pwelch call with segLen and window:
segLen = 1024;
win = hann(segLen);
rbw_welch = enbw(win) * Fs / segLen;

% Set pspectrum to use similar resolution:
[ps,f] = pspectrum(x,Fs,'FrequencyResolution',rbw_welch);
% Note: window shape differs (Kaiser vs Hann) so peak amplitudes
% may vary 1-5% even at matched resolution
```

## Common Pitfalls

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| Comparing `pspectrum` values directly to `pwelch` default | Different units (PS vs PSD) | Use `pwelch(...,'power')` or multiply PSD by RBW |
| Expecting exact match for long signals | Fractional stride vs integer hop | Accept ~0.2 dB tolerance |
| Trying `pspectrum(x,Fs,'psd')` | No PSD output option in pspectrum | Divide output by RBW manually, or use `pwelch` |
| Ignoring DC/Nyquist difference | pspectrum doubles them (overcompensation) | Skip first/last bin when comparing, or halve them |
| Assuming pspectrum uses Hann/Hamming window | Always Kaiser | Use `kaiser(N,20)` when matching |
| Thinking `Reassign` is on by default | Off by default | Only set `Reassign=true` when explicitly needed |

## When to Use Which

| Scenario | Recommended |
|----------|-------------|
| Quick exploration, unknown signal | `pspectrum` — adaptive, good defaults |
| Need exact control of window/overlap/NFFT | `pwelch` or `periodogram` |
| Comparing two signals fairly (length-independent) | `pwelch` (PSD output) |
| Measuring tone amplitude | `periodogram(x,win,[],Fs,'power')` then `sqrt` |
| Need both PSD and power spectrum | `pwelch` with both output modes |
| Publishing results with stated parameters | `pwelch` — all parameters explicit and reproducible |
| Interactive analysis in Signal Analyzer app | `pspectrum` — same engine as the app |

----

Copyright 2026 The MathWorks, Inc.

----
