# Multiresolution Analysis in MATLAB

Decompose signals into additive time-domain components at different scales or equivalently different center frequencies using wavelet-based or data-adaptive methods.

## Method Selection

| Signal characteristic | Method | Why |
|---|---|---|
| Broadband transients + slow trends | `modwt` + `modwtmra` | Dyadic (octave) bands; shift-invariant; perfect reconstruction |
| Closely-spaced tones at similar frequencies | `modwptdetails` or `vmd` | Uniform-bandwidth bands resolve components MODWT cannot separate. `modwptdetails` uses a fixed grid; `vmd` adapts band centers to the data (think of VMD as the data-adaptive analog of MODWPT) |
| Unknown number of components, exploratory | `emd` | Fully adaptive; no parameters needed |
| Known number of narrowband components | `vmd` | Optimization-based; specify exact mode count; robust to noise |
| ML feature extraction (fixed-structure required) | `modwt` + `modwtmra` or `modwtLayer` | Deterministic output topology; consistent feature dimensionality |

## Deterministic Methods: MODWT and MODWPT

### MODWT + MODWTMRA Pipeline

`modwt` computes wavelet coefficients. `modwtmra` converts them to additive time-domain components. These are sequential steps, not alternatives.

```matlab
% Decompose into additive components
wt = modwt(x, "sym4", 6);
mra = modwtmra(wt, "sym4");

% Components sum to original (perfect reconstruction)
maxErr = max(abs(x - sum(mra, 1)));  % ~1e-12

% Selective reconstruction: remove trend (approximation at last level)
detrended = x - mra(end, :);

% Keep only levels 3-5 (specific frequency band)
bandFiltered = sum(mra(3:5, :), 1);
```

**When to use `modwt` alone (without `modwtmra`):**

- Wavelet variance analysis: `modwtvar`
- Wavelet correlation by scale: `modwtcorr`, `modwtxcorr`
- Energy partitioning — the L2 norm of the coefficients equals the L2 norm of the signal

**When to add `modwtmra`:**

- Need time-domain signal components (for plotting, listening, reconstruction)
- Need to remove or keep specific frequency bands
- Need components that sum pointwise back to the original

### MODWPT and modwptdetails

`modwptdetails` computes uniform-bandwidth signal components directly. It takes the **signal as input** — it is NOT a post-processor for `modwpt` output.

```matlab
% Uniform-bandwidth decomposition — takes signal directly
[details, packetlevs, cfreq] = modwptdetails(x, "sym4", 4);

% Components sum to original (perfect reconstruction)
maxErr = max(abs(x - sum(details, 1)));  % ~1e-12

% Center frequencies in Hz (cfreq is normalized 0-0.5)
centerFreqsHz = cfreq * fs;
```

**When to use `modwpt` alone (without `modwptdetails`):**

- Energy or relative energy by frequency band — `modwpt` returns these directly:

```matlab
[wpt, packetlevs, cfreq, energy, relenergy] = modwpt(x, "fk18", 4);
% energy: energy of wavelet packet coefficients at each terminal node
% relenergy: fraction of total signal energy in each band
```

- Wavelet packet coefficients for classification or feature extraction

**When to use `modwptdetails`:**

- Need time-domain signal components in uniform-width frequency bands
- Need to separate closely-spaced components that fall in the same MODWT detail level

### Choosing MODWT vs MODWPT

| Criterion | MODWT + MODWTMRA | modwptdetails |
|-----------|-----------------|---------------|
| Frequency grid | Dyadic (octave): bandwidths double at each level | Uniform: all bands same width |
| Best for | Broadband signals, trends, multi-scale structure | Narrowband components at similar frequencies |
| Number of bands at level L | L details + 1 approximation | 2^L uniform bands |
| When MODWT fails | Two components in same octave band (e.g., 150 Hz and 200 Hz both in D2 at fs=1000) | — |
| When MODWPT is overkill | Signal has clear multi-scale structure (one component per octave) | — |

### Frequency Band Computation

**MODWT** — dyadic bands:

- Detail level j: `[fs/2^(j+1), fs/2^j]` Hz
- Approximation at level L: `[0, fs/2^(L+1)]` Hz

**MODWPT** — uniform bands at terminal level L:

- Bandwidth per band: `bw = (fs/2) / 2^L`
- Band k (1-indexed): `[(k-1)*bw, k*bw]` Hz
- Center frequency of band k: `(k - 0.5) * bw` Hz

`modwpt` and `modwptdetails` return rows in **sequency order** (monotonically increasing center frequency). Row 1 is the lowest frequency band, row 2^L is the highest. No reordering is needed — indexing by row directly corresponds to frequency.

These are approximate ideal passbands. Actual selectivity depends on the wavelet filter length.

### Wavelet Selection and Frequency Selectivity

Longer wavelet filters produce sharper frequency bands (closer to ideal rectangular passbands) at the cost of worse time localization:

| Wavelet family | Filter length | Frequency selectivity | Time localization |
|---------------|---------------|----------------------|-------------------|
| `"haar"` (db1) | 2 | Poor | Best |
| `"db4"` | 8 | Moderate | Good |
| `"sym8"` | 16 | Good | Moderate |
| `"fk18"` | 18 | Excellent (optimized) | Moderate |
| `"fk22"` | 22 | Excellent | Lower |

The Fejér-Korovkin (`fk`) family is specifically optimized for frequency concentration at a given filter length. `"fk18"` is the default for `modwpt`/`modwptdetails`.

### Properties

| Property | MODWT/MODWPT coefficients | MODWTMRA/modwptdetails components |
|----------|--------------------------|----------------------------------|
| What it provides | L2 norm preservation (energy) | Perfect reconstruction (additivity) |
| Domain | Transform domain | Time domain |
| Use for | Variance/energy analysis by scale | Signal reconstruction, denoising, component visualization |
| Relationship | `sum(||W_j||^2) + ||V_L||^2 = ||x||^2` | `sum(components) = x` pointwise |

### Input Support

| Capability | modwt / modwtmra | modwpt / modwptdetails | emd | vmd |
|------------|-----------------|----------------------|-----|-----|
| Matrix (multichannel) | Yes — 3D output | No (software limitation) | No (fundamental — variable IMF count per channel) | No (fundamental — per-signal optimization) |
| Complex-valued signal | Yes | Yes | No (requires extrema — undefined for complex) | No (assumes analytic modes) |
| Complex wavelet filters | No (real orthogonal only; `csym` not yet supported) | No (same limitation) | N/A | N/A |

For complex-valued wavelet filters (`csym` family), use `wavedec` + `wrcoef`. This is the DWT path — it is NOT shift-invariant and has length constraints.

### Energy Analysis with wavedec

`wavedec` provides L2-norm-preserving energy partitioning **only** when all three conditions are met:

1. Signal length is a power of 2
2. Orthogonal wavelet is used
3. `dwtmode("per")` (periodic extension)

If any condition is violated, energy partitioning is not exact. Prefer `modwt` for energy/variance analysis — it preserves the L2 norm unconditionally.

## Data-Adaptive Methods: EMD and VMD

### EMD (Empirical Mode Decomposition)

```matlab
[imf, residual, info] = emd(x);
% imf: matrix where each column is an IMF (highest to lowest frequency)
% residual: monotonic remainder
% info: diagnostics (number of extrema, iterations per IMF)
```

**Key behavior:** `MaxNumIMF` is an **upper bound**, not a target. The algorithm terminates when the residual has fewer than `MaxNumExtrema` extrema (default 1), regardless of `MaxNumIMF`.

```matlab
% This may return fewer than 10 IMFs
[imf, residual] = emd(x, MaxNumIMF=10);
numReturned = size(imf, 2);  % could be 5, 7, etc.
```

### VMD (Variational Mode Decomposition)

```matlab
[imf, residual, info] = vmd(x, NumIMFs=3);
% Always returns exactly 3 modes
% info.CentralFrequencies: normalized center frequencies of each mode
```

**Key behavior:** `NumIMFs` is an **exact count**. The optimization always returns this many modes. Central frequencies are in `info.CentralFrequencies` (normalized), NOT in the second output (which is the residual).

```matlab
% Convert central frequencies to Hz (normalized cycles/sample * fs)
centralFreqsHz = info.CentralFrequencies * fs;
```

**PenaltyFactor** (default 1000): controls mode bandwidth. Lower values allow wider bandwidth modes — useful for chirps or frequency-varying components.

### EMD Decomposes into Modes, Not Frequencies

EMD extracts **intrinsic mode functions** (IMFs) — signals with well-defined instantaneous frequency — not sinusoidal components. An amplitude-modulated signal is already a valid IMF:

```matlab
t = linspace(0, 1, 1000);
x = (1 + cos(2*pi*10*t)) .* cos(2*pi*100*t);
imf = emd(x);
size(imf, 2)  % Returns 1 — EMD sees one mode
```

The STFT sees the same signal as three separate tones (90, 100, 110 Hz), but EMD correctly identifies the underlying modulated carrier as a single entity with time-varying envelope.

This means EMD is not interchangeable with MODWPT or VMD for separating closely-spaced tones. It operates on a fundamentally different notion of "component" — one defined by oscillatory structure and instantaneous frequency, not by Fourier frequency content.

### Choosing EMD vs VMD

| Criterion | EMD | VMD |
|-----------|-----|-----|
| Parameters required | None | Must specify `NumIMFs` |
| Output count | Variable (signal-dependent) | Fixed (always `NumIMFs` modes) |
| What it separates | Modes (instantaneous frequency) | Narrowband components (Fourier frequency) |
| Mode mixing | Common (energy bleeds across IMFs) | Rare (optimization separates cleanly) |
| AM signals | Keeps as one mode (correct for IF analysis) | Splits into carrier +/- modulation tones |
| Chirp handling | Splits across IMFs | Can capture in one mode (reduce `PenaltyFactor`) |
| Mathematical basis | Iterative sifting (empirical) | Variational optimization (rigorous) |
| Use when | Exploratory; IF analysis; unknown modulated structure | Known number of narrowband components; need clean Fourier-sense separation |

### Why Wavelet MRA is Preferred for Machine Learning

Deterministic methods produce the **same decomposition structure for every signal**:

- Fixed number of bands at fixed frequencies → consistent feature dimensionality
- Training and inference use the identical transform
- Reproducible and parallelizable (no iterative convergence)

EMD produces different numbers of IMFs per signal — incompatible with fixed-shape feature matrices without padding/alignment. VMD has fixed count but mode frequency assignments vary across signals ("mode 2" means different bands for different inputs).

**Deep learning entry points:**

| Use case | Function | Notes |
|----------|----------|-------|
| Network layer (standard architecture) | `modwtLayer` | Drop into `dlnetwork`; `Algorithm="MODWTMRA"` (default) or `"MODWT"`; calls `dlmodwt` under the hood |
| Custom training loop | `dlmodwt` | Accepts `dlarray` inputs; supports automatic differentiation; second output is the MRA |

```matlab
% dlmodwt in a custom training loop — filters MUST be numeric vectors
% (not wavelet name) so gradient-descent updates to the filters persist
[Lo, Hi] = wfilters("sym4");
dlX = dlarray(reshape(x, 1, 1, []), "CBT");  % Channel-Batch-Time
[wt, mra] = dlmodwt(dlX, Lo, Hi, 4);
% Use mra directly as multi-channel features — no separate modwtmra call needed
```

**Why filter vectors, not wavelet name:** `dlmodwt` makes the filters optionally learnable via automatic differentiation. Passing a wavelet name string would re-read fixed coefficients each call, discarding any gradient updates. Always pass `Lo`/`Hi` vectors obtained from `wfilters`.

## Hilbert-Huang Transform and Instantaneous Frequency

### hht — Hilbert Spectrum

`hht` computes the Hilbert spectrum: a time-frequency representation built from the instantaneous frequency and energy of each IMF. Unlike STFT/CWT which spread energy across a kernel, the Hilbert spectrum places energy at a single frequency per IMF per time sample.

**Input is IMFs, not the raw signal.** The correct workflow:

```matlab
imf = emd(x);               % or vmd(x, NumIMFs=K)
[hs, f, t] = hht(imf, fs);  % Hilbert spectrum (sparse matrix)
```

**Outputs (up to 5):**

| Output | Content | Type |
|--------|---------|------|
| `hs` | Hilbert spectrum — energy at each (freq, time) bin | Sparse matrix (nFreq × nTime) |
| `f` | Frequency vector | Column vector |
| `t` | Time vector | Column vector |
| `insf` | Instantaneous frequency per IMF | nTime × nIMFs |
| `inse` | Instantaneous energy per IMF | nTime × nIMFs |

**Name-value options:**

| Option | Default | Purpose |
|--------|---------|---------|
| `FrequencyLimits` | `[0, fs/2]` | Restrict frequency axis |
| `FrequencyResolution` | `(fmax-fmin)/100` | Bin width — default gives only 100 bins |
| `MinThreshold` | `-inf` (dB) | Zero out low-energy bins (useful for clean display) |

**Key points:**
- Zero-output call produces a plot
- The sparse matrix `hs` is the actual Hilbert spectrum — a legitimate TF representation, not just visualization data
- Default frequency resolution (100 bins) is coarse — increase with `FrequencyResolution` for finer analysis
- Multiple IMFs contribute additively: if two IMFs have the same instantaneous frequency at time t, their energies accumulate in the same bin
- Internally computes: analytic signal → `|z|²` (energy), `d/dt(unwrap(angle(z))) × fs/(2π)` (frequency)

### instfreq — Instantaneous Frequency Estimation

`instfreq` estimates instantaneous frequency of a signal. Two methods exist:

```matlab
% Method 1: Hilbert (default) — requires monocomponent or pre-decomposed signal
[ifq, t] = instfreq(x, fs);                        % single signal via Hilbert
[ifq, t] = instfreq(imf, fs);                      % IMF matrix — one IF curve per column

% Method 2: TF-moment — works on raw multicomponent signals (centroid of spectrogram)
[ifq, t] = instfreq(x, fs, Method="tfmoment");     % first spectral moment of pspectrum
[ifq, t] = instfreq(P, F, T);                      % from pre-computed TFD (power, freq, time)
```

**Critical distinction:**
- **Hilbert method:** `fs/(2π) × diff(unwrap(angle(hilbert(x))))` — physically meaningful only for narrowband/monocomponent signals. For multicomponent signals, decompose first with `emd`/`vmd`, then pass IMFs.
- **TF-moment method:** Weighted mean frequency from `pspectrum` at each time step. Works on raw signals but gives only a single average frequency (not per-component).

**Output is 1 sample shorter** with Hilbert method (forward difference loses one sample).

### instbw — Instantaneous Bandwidth

```matlab
[ibw, t] = instbw(x, fs);                          % from signal (via pspectrum internally)
[ibw, t] = instbw(P, F, T);                        % from pre-computed TFD
[ibw, t] = instbw(x, fs, FrequencyLimits=[flo fhi]);
```

- Only uses the TF-moment method (2nd central spectral moment of `pspectrum`) — no Hilbert option
- Measures spectral spread at each time instant
- Useful for detecting transitions, broadband transients, or time-varying bandwidth

### Workflow Summary

```
Raw signal
    │
    ├── instfreq(x, fs, Method="tfmoment") → average IF (single curve)
    ├── instbw(x, fs) → spectral spread over time
    │
    └── emd(x) or vmd(x, NumIMFs=K)
            │
            ├── instfreq(imf, fs) → per-IMF IF curves (Hilbert method)
            └── hht(imf, fs) → Hilbert spectrum (full TF representation)
```

## Interactive Exploration

`signalMultiresolutionAnalyzer` — interactive app for comparing MRA methods side by side.

- **Supports:** MODWT, EMD, VMD, EWT, TQWT
- **Does NOT support:** MODWPT
- **Filters out complex-valued signals** (only MODWT handles complex among app methods)
- **Recommend when:** User is exploring which method works best for their signal
- **Use programmatic workflow when:** Production code, batch processing, multichannel, complex-valued data, or need MODWPT

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Plotting `modwt` output as signal components | Coefficients are not time-domain components; they don't sum to the original | Use `modwtmra` to get additive components |
| Using `TimeAlign=true` with `modwtmra` | Time-aligning circularly shifts coefficients for visual display; `modwtmra` needs unshifted coefficients for perfect reconstruction | Only use `TimeAlign=true` when visualizing coefficients directly; never before calling `modwtmra` |
| Passing `modwpt` output to `modwptdetails` | `modwptdetails` takes the signal directly, not wavelet packet coefficients | Call `modwptdetails(x, wname, level)` |
| Using Butterworth filters when MODWT can't separate tones | Classical filters work but ignore the wavelet packet solution designed for this | Use `modwptdetails` for uniform-bandwidth separation |
| Using `"NumIMFs"` with `emd` or `"MaxNumIMF"` with `vmd` | Parameter names are not interchangeable | `emd`: `MaxNumIMF`; `vmd`: `NumIMFs` |
| Assuming EMD returns exactly `MaxNumIMF` modes | It's an upper bound; algorithm terminates on stopping criteria | Check `size(imf, 2)` after calling `emd` |
| Using `wavedec` for energy analysis without checking conditions | Energy partitioning is only exact with power-of-2 length + orthogonal wavelet + periodic mode | Prefer `modwt` — L2 norm preservation is unconditional |
| Recommending `signalMultiresolutionAnalyzer` for complex data | App filters out complex signals | Use `modwt`/`modwtmra` programmatically |
| Passing raw signal to `hht` | `hht` expects IMFs (columns), not the raw signal — a single column gives meaningless single-mode spectrum | Decompose first: `imf = emd(x); hht(imf, fs)` |
| Using `instfreq` (Hilbert) on multicomponent signals | Hilbert IF is only meaningful for narrowband/monocomponent signals | Decompose with `emd`/`vmd` first, or use `Method="tfmoment"` for a weighted average |
| Expecting `instfreq` (Hilbert) output to be same length as input | Forward difference loses 1 sample | Output has `N-1` samples |
| Using default `FrequencyResolution` in `hht` for detailed analysis | Default is only 100 bins across `[0, fs/2]` — very coarse | Specify finer resolution: `hht(imf, fs, FrequencyResolution=1)` |

----

Copyright 2026 The MathWorks, Inc.

----
