---
name: matlab-analyze-time-frequency
description: >
  Perform time-frequency analysis in MATLAB using CWT, STFT, synchrosqueezing,
  reassignment, wavelet coherence, cross spectrogram, EMD/VMD, multiresolution
  analysis, and time-frequency filtering. Triggers on: time-frequency, spectrogram,
  scalogram, cwt, stft, istft, fsst, wsst, wcoherence, xspectrogram, modwt,
  modwtmra, modwpt, emd, vmd, hht, tffilt, dgt, gabor, instantaneous frequency,
  synchrosqueezing, reassignment, ridge extraction, wavelet coherence, cross
  spectrum, mode decomposition, signal decomposition, time-frequency filtering.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Time-Frequency Analysis in MATLAB

Analyze how frequency content evolves over time using STFT, CWT, synchrosqueezing,
reassignment, cross-signal methods, and data-adaptive decomposition.

> **Agent directive:** Consult the reference guides in `references/` before answering.
> Each guide covers a specific domain with syntax, gotchas, and common mistakes.

## When To Use

- Analyzing how frequency content evolves over time (spectrogram, scalogram)
- Choosing between STFT, CWT, synchrosqueezing, reassignment, or EMD/VMD
- Extracting and reconstructing individual signal components from a TF representation
- Computing time-varying coherence or cross-spectrum between two signals
- Decomposing signals into additive time-domain components (wavelet MRA, EMD, VMD)
- Estimating instantaneous frequency or Hilbert spectrum

## When Not To Use

- Designing or applying classical FIR/IIR filters — use `matlab-design-digital-filter`
- Extracting scalar features for ML classification — use `matlab-extract-signal-features`
- Signal preprocessing (resampling, detrending, gap filling) — use `matlab-prepare-signal-data`
- Quadratic/bilinear TFDs (Wigner-Ville) — not supported in MATLAB toolboxes
- Audio-specific representations (mel spectrogram, MFCC) — use Audio Toolbox

## Method Selection

Choose the analysis method based on the user's goal and signal characteristics:

| Goal | Method | Guide |
|------|--------|-------|
| Interactive TF exploration (spectrogram + scalogram) | `signalAnalyzer` | — |
| General TF visualization (uniform freq resolution) | `stft`, `spectrogram`, `pspectrum` | `references/stft-guide.md` |
| TF visualization (multi-resolution, constant-Q) | `cwt`, `cwtfilterbank` | `references/cwt-guide.md` |
| Sharpest TF picture (non-invertible) | `spectrogram("reassigned")`, `pspectrum(Reassigned=true)` | `references/reassignment-guide.md` |
| Remove specific TF regions (mask-based filtering) | `tffilt` with binary mask | `references/stft-guide.md` |
| Mode extraction + reconstruction (STFT domain) | `fsst` → `tfridge` → `ifsst` | `references/reassignment-guide.md` |
| Mode extraction + reconstruction (CWT domain) | `wsst` → `wsstridge` → `iwsst` | `references/reassignment-guide.md` |
| Signal reconstruction from CWT | `icwt` (exact or approximate) | `references/cwt-guide.md` |
| Additive decomposition (octave bands) | `modwt` + `modwtmra` | `references/multiresolution-guide.md` |
| Additive decomposition (uniform bands) | `modwptdetails` | `references/multiresolution-guide.md` |
| Adaptive decomposition (unknown components) | `emd` | `references/multiresolution-guide.md` |
| Adaptive decomposition (known mode count) | `vmd` | `references/multiresolution-guide.md` |
| Hilbert spectrum / instantaneous frequency | `hht`, `instfreq` | `references/multiresolution-guide.md` |
| Time-varying coherence between two signals | `wcoherence` | `references/cross-analysis-guide.md` |
| Cross spectrogram between two signals | `xspectrogram` | `references/cross-analysis-guide.md` |
| Global coherence (no time axis) | `mscohere`, `cpsd` | `references/cross-analysis-guide.md` |

For detailed decision logic, see `references/method-selection-guide.md`.

## Quick Decision Tree

```
What is the primary goal?
│
├── Interactive exploration (adjust parameters, compare views)
│   └── signalAnalyzer — supports spectrogram + scalogram (CWT) side by side
│
├── Visualize one signal's TF content
│   ├── Need uniform frequency resolution? → stft / spectrogram / pspectrum
│   ├── Need multi-resolution (better low-freq)? → cwt
│   └── Need sharpest picture (no reconstruction)? → spectrogram("reassigned")
│
├── Remove unwanted content visible in spectrogram
│   └── Define binary mask over TF plane → tffilt (Gabor domain)
│
├── Extract and reconstruct individual components
│   ├── From TF representation (invertible)?
│   │   ├── STFT domain → fsst → tfridge → ifsst
│   │   └── CWT domain → wsst → wsstridge → iwsst
│   ├── Additive time-domain components?
│   │   ├── Octave bands → modwt + modwtmra
│   │   ├── Uniform bands → modwptdetails
│   │   └── Data-adaptive → emd or vmd
│   └── From CWT directly? → icwt (see references/cwt-guide.md)
│
├── Compare two signals
│   ├── Time-varying coherence? → wcoherence
│   ├── Time-varying cross-spectrum? → xspectrogram
│   └── Global relationship? → mscohere / cpsd
│
└── Estimate instantaneous frequency
    ├── Single monocomponent signal? → instfreq(x, fs)
    ├── Multicomponent (want per-mode IF)? → emd → instfreq(imf, fs)
    └── Multicomponent (want single average)? → instfreq(x, fs, Method="tfmoment")
```

## Critical Rules

1. **`stft` has no reassignment option.** Use `fsst` for invertible synchrosqueezing or `spectrogram("reassigned")` for non-invertible visualization.

2. **`wsstridge` argument order differs from `tfridge`:**
   - `wsstridge(sst, penalty, f, ...)` — penalty is 2nd positional arg
   - `tfridge(tfm, f, penalty, ...)` — penalty is 3rd positional arg

3. **`wsst` subtracts the signal mean** internally. `iwsst` does NOT restore it. Add `mean(x)` back manually if DC matters.

4. **`ifsst` is machine-precision; `iwsst` is approximate** (Morlet single-integral formula).

5. **`xspectrogram` first output is real** (cross-spectrogram magnitude). For phase, use the 4th output `P`. This differs from `spectrogram` whose first output is complex STFT.

6. **`wcoherence` has no `Parent` option.** For App Designer, compute outputs and plot manually.

7. **`wcoherence` phase arrows** show the phase lag of Y relative to X:
   - ↑ = Y lags X by π/2
   - ↓ = Y leads X by π/2
   - → = in-phase
   - ← = anti-phase
   `PhaseDisplayThreshold` (default 0.5) is plot-only — it controls which arrows are drawn but has no effect on returned numeric outputs.

8. **`hht` takes IMFs, not raw signal.** Always decompose first: `imf = emd(x); hht(imf, fs)`.

9. **`instfreq` Hilbert method** is meaningless for multicomponent signals. Decompose first, or use `Method="tfmoment"` for a single average curve.

10. **Synchrosqueezing is precision-sensitive.** Use double-precision data with `fsst`/`wsst` for reproducible results across MATLAB, codegen, and GPU.

## Signal Assessment Workflow

When the user provides a signal and asks "what should I use?", run the assessment script then apply agent-side interpretation:

### Step 1: Run MATLAB assessment

```matlab
report = assessSignalForTF(x, fs);
disp(report)
disp(report.recommendations)
```

The script returns: signal length, occupied bandwidth, number of spectral peaks (with frequencies), nonstationarity indicator, DC content, precision, and auto-generated recommendations.

### Step 2: Agent-side interpretation (combine script output with user goals)

| User Goal | Key Report Fields | Recommendation Logic |
|-----------|-------------------|---------------------|
| "Explore / I'm not sure what I need" | — | Suggest `signalAnalyzer` for interactive exploration (spectrogram + scalogram views, adjustable parameters) |
| "Visualize frequency content over time" | `likelyNonstationary`, `fractionalBandwidth` | If wideband (>2 octaves): cwt. If narrowband or uniform resolution needed: stft/spectrogram |
| "Separate/extract components" | `numSpectralPeaks`, `peakFrequenciesHz` | 2–3 peaks: synchrosqueezing (fsst/wsst). Many peaks: emd/vmd. Closely-spaced: modwptdetails or fsst |
| "Reconstruct after filtering" | `hasDC`, precision | fsst/ifsst for exact. wsst/iwsst for CWT-domain (warn about mean). icwt for CWT bandpass |
| "Compare two signals" | (run on both) | wcoherence for coherence. xspectrogram for cross-spectrum |
| "Detect transients/events" | `signalLength`, `occupiedBandHz` | cwt with low TimeBandwidth. Or short-window stft |

### Step 3: Refine with follow-up questions if ambiguous

- "Do you need to reconstruct the signal, or just visualize?"
- "Do you need uniform frequency resolution, or is multi-resolution acceptable?"
- "Are you comparing this signal to another?"

## Reference Guides

| File | Coverage |
|------|----------|
| `references/stft-guide.md` | stft/istft, spectrogram, pspectrum, stftmag2sig, length preservation, COLA |
| `references/cwt-guide.md` | cwt, cwtfilterbank, icwt, dlicwt/icwtLayer, boundary, constant-Q |
| `references/reassignment-guide.md` | fsst/ifsst, wsst/iwsst, spectrogram("reassigned"), pspectrum(Reassigned=true), ridge extraction, penalty |
| `references/cross-analysis-guide.md` | wcoherence, xspectrogram, cpsd, mscohere, phase arrows, unsmoothed cross-spectrum |
| `references/multiresolution-guide.md` | modwt/modwtmra, modwpt/modwptdetails, emd, vmd, hht, instfreq, instbw |
| `references/method-selection-guide.md` | Decision logic for choosing among all methods |

## Toolbox Requirements

| Toolbox | Functions |
|---------|-----------|
| Signal Processing | stft, istft, spectrogram, pspectrum, fsst, ifsst, tfridge, xspectrogram, instfreq, instbw, stftmag2sig, cpsd, mscohere |
| Wavelet | cwt, cwtfilterbank, icwt, wsst, iwsst, wsstridge, wcoherence, modwt, modwtmra, modwpt, modwptdetails, emd, vmd, hht, tffilt, dgt |

| Function | Available From | Note |
|----------|---------------|------|
| `tffilt` | R2025a | TF mask-based filtering; all other functions available in R2024b |

## Documentation References

| Topic | Link |
|-------|------|
| Time-frequency gallery | https://www.mathworks.com/help/signal/time-frequency-analysis.html |
| Wavelet time-frequency | https://www.mathworks.com/help/wavelet/time-frequency-analysis.html |
| CWT reference | https://www.mathworks.com/help/wavelet/ref/cwt.html |
| STFT reference | https://www.mathworks.com/help/signal/ref/stft.html |
| Synchrosqueezing example | https://www.mathworks.com/help/wavelet/ug/time-frequency-reassignment-and-mode-extraction-with-synchrosqueezing.html |
| Wavelet coherence example | https://www.mathworks.com/help/wavelet/ug/compare-time-frequency-content-in-signals-with-wavelet-coherence.html |

----

Copyright 2026 The MathWorks, Inc.

----
