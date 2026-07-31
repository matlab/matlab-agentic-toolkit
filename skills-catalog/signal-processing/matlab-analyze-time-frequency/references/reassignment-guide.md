# Time-Frequency Reassignment Guide

## Overview

Reassignment techniques sharpen time-frequency representations by moving energy from each analysis bin to a more precise location. Two fundamentally different approaches exist:

1. **Full reassignment** (time + frequency) — produces the sharpest visual picture but is **not invertible**. Energy is displaced in both axes, destroying the structure needed for reconstruction.
2. **Synchrosqueezing** (frequency only) — reassigns energy only along the frequency axis toward instantaneous frequency. Because the time axis is untouched, the transform remains **invertible** — individual oscillatory modes can be extracted and reconstructed.

Choose full reassignment for visualization and detection. Choose synchrosqueezing when you need to extract and reconstruct individual signal components.

## Function Landscape

| Function | Domain | Type | Invertible | Toolbox |
|----------|--------|------|------------|---------|
| `fsst` | STFT | Synchrosqueezing | Yes (`ifsst`) — machine precision | Signal Processing |
| `wsst` | CWT | Synchrosqueezing | Yes (`iwsst`) — approximate (Morlet formula) | Wavelet |
| `spectrogram(..., "reassigned")` | STFT | Full reassignment | No | Signal Processing |
| `pspectrum(..., Reassigned=true)` | STFT | Full reassignment | No | Signal Processing |

**No reassignment option exists for:**
- `stft` / `istft` — use `fsst` instead for STFT-domain synchrosqueezing
- `cwt` — use `wsst` instead for CWT-domain synchrosqueezing

## When to Use

- **Visualization only (sharpest picture):** `spectrogram("reassigned")` or `pspectrum(Reassigned=true)`
- **Mode extraction + reconstruction (STFT domain):** `fsst` → `tfridge` → `ifsst`
- **Mode extraction + reconstruction (CWT domain):** `wsst` → `wsstridge` → `iwsst`

## Full Reassignment: spectrogram / pspectrum

Full reassignment displaces each STFT coefficient to the local centroid of the Wigner-Ville distribution — both in time (group delay) and frequency (instantaneous frequency). The result is maximally concentrated but non-invertible.

### spectrogram (reassigned)

```matlab
[s, f, t] = spectrogram(x, window, noverlap, nfft, fs, "reassigned");
```

- Returns reassigned time-frequency matrix directly
- Same window/overlap/nfft interface as standard spectrogram
- The `"reassigned"` flag is a trailing positional argument

### pspectrum (reassigned)

```matlab
[p, f, t] = pspectrum(x, fs, "spectrogram", Reassigned=true);
```

- Name-value syntax: `Reassigned=true`
- Built-in resolution/leakage controls via `FrequencyResolution`, `Leakage`
- Output is power spectrum (not complex STFT coefficients)

### Limitations

- **Not invertible** — cannot reconstruct individual signal components
- **Ridge extraction still works** — use `tfridge` on the reassigned matrix for instantaneous frequency estimation, but you cannot invert back to time domain from the reassigned representation alone
- Useful for detection, classification, and visualization — not for signal separation

## STFT Synchrosqueezing: fsst / ifsst

### Forward Transform

```matlab
[sst, f, t] = fsst(x, fs);            % default: Kaiser(256, beta=10)
[sst, f, t] = fsst(x, fs, window);    % custom window
fsst(x, fs);                           % no outputs → auto-plot
```

**Key constraints:**
- Overlap is **always** `window_length - 1` (hop = 1 sample) — not configurable
- `nfft = window_length` — DFT length equals window length
- Real input → one-sided spectrum; complex input → two-sided centered spectrum

### Inverse Transform

```matlab
xrec = ifsst(sst);                         % full reconstruction
xrec = ifsst(sst, window, f, [flo fhi]);   % frequency-range reconstruction
xrec = ifsst(sst, window, iridge);         % mode extraction via ridge
xrec = ifsst(sst, [], iridge, NumFrequencyBins=4);  % control bandwidth around ridge
```

- **Full reconstruction is machine-precision** (~1e-14 error)
- Window must match the forward `fsst` call
- Ridge-based extraction: pass `iridge` from `tfridge`

### Ridge Extraction with tfridge

```matlab
[fridge, iridge] = tfridge(sst, f, penalty);
[fridge, iridge] = tfridge(sst, f, penalty, NumRidges=2);
```

- `tfridge` is generic — works on any TF matrix (fsst, spectrogram, wsst, etc.)
- Default penalty = 0 (no smoothing)

## CWT Synchrosqueezing: wsst / iwsst

### Forward Transform

```matlab
[sst, f] = wsst(x, fs);                    % default: amor wavelet, VoicesPerOctave=32
[sst, f] = wsst(x, fs, 'bump');            % specify wavelet
[sst, f, fbparam] = wsst(x, fs, 'bump', VoicesPerOctave=32);
wsst(x, fs);                                % no outputs → auto-plot
```

**Key details:**
- Only accepts **real-valued** signals
- Default wavelet is `"amor"` (not Morse like `cwt`)
- VoicesPerOctave must be **even**, range 10–48, default 32
- **Subtracts the signal mean** before analysis internally
- Supports `Boundary`: `"periodic"` (default), `"reflection"`, `"zeropad"`

### Inverse Transform

```matlab
xrec = iwsst(sst);                              % full reconstruction (approximate)
xrec = iwsst(sst, 'bump');                      % specify wavelet (must match forward)
xrec = iwsst(sst, iridge);                      % mode extraction
xrec = iwsst(sst, iridge, NumFrequencyBins=16); % control bandwidth
xrec = iwsst(sst, f, [flo fhi]);                % frequency-range reconstruction
```

- **Reconstruction is approximate** — uses Morlet single-integral formula (`2/Rpsi * real(sum(sst,1))`)
- Wavelet must match between `wsst` and `iwsst`
- Default NumFrequencyBins = 16 (half of default VoicesPerOctave=32)
- `wsst` subtracts the mean but `iwsst` does NOT add it back — user must add `mean(x)` if needed

### Ridge Extraction with wsstridge

```matlab
[fridge, iridge] = wsstridge(sst, penalty, f, NumRidges=2);
```

- `wsstridge` is `wsst`-specific — handles filter bank parameters and log-spaced frequency
- Penalty is the **2nd positional argument** (before `f`)
- Calls the same underlying engine as `tfridge`: `signalwavelet.internal.tfridge.extractRidges`

## Penalty Term for Ridge Extraction

### Why It's Needed

Without a penalty, the ridge extraction is purely greedy — it picks the bin with maximum energy at each time step. When a component's amplitude dips below competing energy (noise, another mode), the ridge **jumps** to the wrong frequency.

### When to Use

- **Multiple ridges** (`NumRidges > 1`) — almost always needed to prevent cross-assignment between modes
- **Single modulated component in noise** — prevents jumping to noise peaks during amplitude dips
- **FM signals** — prevents short-cutting across rapid frequency excursions

### How It Works

The penalty adds cost `penalty × (distance_in_bins)²` for changing frequency between adjacent time steps. This trades energy-maximization against trajectory smoothness.

**The penalty operates in bins, not Hz.** For `wsst` (log-spaced bins), the physical frequency change per bin varies with frequency. For `fsst` (linear bins), it's uniform.

### Value Selection

No automatic method exists. Start with penalty = 5 and adjust:
- Too low → ridge still jumps between modes
- Too high → over-smooths, can't track legitimate rapid frequency changes (FM content)

## Synchrosqueezing Can Rescue CWT's Constant-Q Limitation

CWT's constant-Q property means bandwidth grows with frequency — closely-spaced high-frequency tones get smeared together. `wsst` can **partially rescue** this by concentrating the smeared energy back toward the true instantaneous frequencies.

```matlab
% DTMF tones: CWT smears high-freq group, wsst sharpens them
[sst, f] = wsst(tones, Fs, 'bump');
```

**Decision hierarchy:**
1. Tones well-separated relative to bandwidth → raw `cwt` works
2. Tones moderately close → `wsst` sharpens enough to resolve
3. Tones within 2Δ of each other → synchrosqueezing also fails → use `stft`/`fsst`

## Resolvability Condition

For synchrosqueezing (both `fsst` and `wsst`) to resolve two modes:

`|φ₁'(t) - φ₂'(t)| > 2Δ`

where:
- `φ'(t)` = instantaneous frequency of each mode
- `Δ` = bandwidth of the analysis wavelet/window at that frequency

**Implications:**
- Parallel chirps with constant separation: resolvable if separation > 2Δ everywhere
- Crossing chirps: always unresolvable at the crossing point (IF difference = 0)
- For CWT/wsst (constant-Q): Δ grows with frequency → harder to resolve at high frequencies
- For STFT/fsst: Δ is fixed by window → uniform resolving ability

## Precision Sensitivity

The synchrosqueezing algorithm reassigns energy to the nearest frequency bin based on estimated instantaneous frequency. In single precision, rounding at bin boundaries causes off-by-one differences in reassignment.

**Affected scenarios:**
- **Code generation** (C/C++ via MATLAB Coder) — results may differ from MATLAB
- **GPU arrays** (Parallel Computing Toolbox) — floating-point order-of-operations differs from CPU

**Recommendation:** Use **double-precision** data with `fsst`/`wsst` when:
- Comparing results across MATLAB, codegen, and GPU
- Ridge extraction must be reproducible
- Mode reconstruction fidelity matters

## Complete Workflow: Mode Extraction

### STFT-based (fsst)

```matlab
% 1. Compute synchrosqueezed STFT
[sst, f, t] = fsst(x, fs, kaiser(256, 10));

% 2. Extract ridges with penalty
[fridge, iridge] = tfridge(sst, f, 5, NumRidges=2);

% 3. Reconstruct individual modes
xmode1 = ifsst(sst, kaiser(256, 10), iridge(:,1));
xmode2 = ifsst(sst, kaiser(256, 10), iridge(:,2));
```

### CWT-based (wsst)

```matlab
% 1. Compute synchrosqueezed CWT
[sst, f] = wsst(x, fs, 'bump');

% 2. Extract ridges with penalty
[fridge, iridge] = wsstridge(sst, 5, f, NumRidges=2);

% 3. Reconstruct individual modes
xrec = iwsst(sst, iridge);
xmode1 = xrec(:,1);
xmode2 = xrec(:,2);
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `stft` and expecting reassignment | `stft` has no reassignment option | Use `fsst` for invertible synchrosqueezing, or `spectrogram("reassigned")` for visualization |
| Omitting penalty with `NumRidges > 1` | Ridges jump between modes at energy crossings | Always use penalty ≥ 1 when extracting multiple ridges |
| Expecting `iwsst` to give exact reconstruction | `iwsst` uses Morlet single-integral (approximate) | Accept the approximation, or use `fsst`/`ifsst` for machine-precision reconstruction |
| Forgetting to add back the mean after `iwsst` | `wsst` internally subtracts `mean(x)` but `iwsst` doesn't restore it | Add `mean(x)` to the reconstruction if DC level matters |
| Using single precision with `fsst`/`wsst` | Off-by-one bin reassignment differences vs double | Use double precision for reproducible results across MATLAB/codegen/GPU |
| Expecting synchrosqueezing to resolve modes within 2Δ | Resolvability condition requires IF separation > 2× bandwidth | If modes are too close, switch to STFT with narrow window |
| Using `wsstridge(sst, f, penalty, ...)` | Penalty is the 2nd argument for `wsstridge`, before `f` | `wsstridge(sst, penalty, f, NumRidges=n)` |
| Using `tfridge(tfm, f)` without penalty for FM signals | FM components have time-varying frequency — greedy search jumps | Add penalty: `tfridge(tfm, f, penalty)` |

## Documentation References

| Topic | Link |
|-------|------|
| `fsst` reference | https://www.mathworks.com/help/signal/ref/fsst.html |
| `ifsst` reference | https://www.mathworks.com/help/signal/ref/ifsst.html |
| `tfridge` reference | https://www.mathworks.com/help/signal/ref/tfridge.html |
| `wsst` reference | https://www.mathworks.com/help/wavelet/ref/wsst.html |
| `iwsst` reference | https://www.mathworks.com/help/wavelet/ref/iwsst.html |
| `wsstridge` reference | https://www.mathworks.com/help/wavelet/ref/wsstridge.html |
| Time-frequency reassignment and mode extraction | https://www.mathworks.com/help/wavelet/ug/time-frequency-reassignment-and-mode-extraction-with-synchrosqueezing.html |


----

Copyright 2026 The MathWorks, Inc.

----
