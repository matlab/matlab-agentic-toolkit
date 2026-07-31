# CWT Reference Guide

## Workflow

### 1. Understand the Signal and User Goals

Before computing the CWT, determine:

- **Signal type:** Real-valued or complex-valued?
- **Feature type:** Oscillatory components (frequency resolution matters) or impulsive events (time localization matters)?
- **Sampling frequency:** Known? If not, analysis uses normalized frequency (cycles/sample).
- **Goal:** Visualization only, numerical outputs, or both?

### 2. Run Pre-CWT Diagnostics (Recommended)

| Script | Inputs | Outputs | Purpose |
|--------|--------|---------|---------|
| `assessBoundary` | `x` (signal), optional `Fs` (sample rate) | Figure with endpoint zoom | Inspects signal endpoints to recommend `Boundary` property |
| `illustrateBoundary` | (none — loads `boundaryExDisjointSine.mat`) | Figure with 3 scalograms | Shows periodic/reflection/zeropad side-by-side |
| `assessSpectralEnergy` | `x` (signal), `Fs` (sample rate), optional `ThresholdDB` | Figure with PSD + suggested band | Computes PSD to suggest `FrequencyLimits` for reducing computation |
| `illustrateTransientLocalization` | (none) | Figure with 3 wavelet responses | Compares Morse/amor/bump time localization on impulse |
| `plotAntiAnalyticScalogram` | `cfs` (scalogram magnitude), `f` (frequencies), `t` (time) | Axes plot | Plots combined negative+positive frequency scalogram for complex signals |

```matlab
assessBoundary(x, Fs=1000)
illustrateBoundary()
assessSpectralEnergy(x, 1000, ThresholdDB=-20)
illustrateTransientLocalization()
plotAntiAnalyticScalogram(abs(cfs), f, t)
```

### 3. Choose the Calling Pattern

| Goal | Pattern |
|------|---------|
| Visualization only | `cwt(signal, ...)` — no output arguments, auto-plots |
| Visualization into specific axes/app | `cwt(signal, ..., 'Parent', ax)` — no output arguments |
| Data only | `[cfs, f, coi] = cwt(signal, ...)` |
| Data + visualization | Capture outputs, then reproduce plot manually (see Patterns) |
| Repeated analysis (same params) | Build `fb = cwtfilterbank(...)`, then `cwt(signal, 'FilterBank', fb)` or `wt(fb, signal)` |
| Inspect filter bank before analysis | Build `cwtfilterbank(...)`, use `wavelets`, `freqz`, `scales`, `powerbw` methods |

**Critical rule:** `nargout == 0` triggers auto-plotting. Capturing ANY output suppresses the plot entirely.

### 4. Configure the CWT

#### Wavelet Selection (signal-feature-driven)

| Signal features | Recommendation |
|----------------|---------------|
| General purpose / mixed content | `"Morse"` (default), gamma=3, P²=60 |
| Impulsive events, need precise timing | `"Morse"` with lower `TimeBandwidth` (e.g., 10–30) |
| Oscillatory, need frequency separation | `"Morse"` with higher `TimeBandwidth` (e.g., 80–120) |
| Reproducing published Morlet results | `"amor"` (equivalent to Morse with P²≈36 in time duration) |
| Purely oscillatory, extreme freq. resolution needed | `"bump"` (last resort — worst time localization) |

#### Key Parameters

| Parameter | Default | Guidance |
|-----------|---------|----------|
| `TimeBandwidth` | 60 | Primary tuning knob. Higher = better freq. resolution, worse time localization. Range: 3–120. Leave `gamma=3` (symmetric). |
| `VoicesPerOctave` | 10 | Higher (up to 48) = finer frequency sampling. Increases computation. |
| `FrequencyLimits` | auto | Set `[fmin fmax]` to reduce computation. Use PSD assessment to identify useful band. `[0 Fs/2]` for full range. |
| `Boundary` | `"reflection"` | See boundary guidance below. `"periodic"` is ~2x faster for large signals (>100K samples). |
| `SamplingFrequency` | 1 | Always set if known — gives physical frequency units (Hz). |

#### FrequencyLimits Details

- **Performance lever:** Restricting the range reduces scales computed (fewer rows in output).
- **Lower limit = 0:** Gives lowest valid frequency from `cwtfreqbounds` (no guesswork).
- **Upper limit = Fs/2:** Forces highest wavelet to peak at Nyquist. Use when signal has significant near-Nyquist content. Default is conservative (wavelet decays by Nyquist).
- Use `cwtfreqbounds` to query achievable range for given signal length and wavelet.

#### Boundary Selection

| Boundary | Best when | Avoid when | Performance |
|----------|-----------|------------|-------------|
| `"reflection"` | Signal is locally stationary at edges | Frequency discontinuity at boundary | ~2N FFT length |
| `"periodic"` | Endpoints match in value and trend | Endpoints differ significantly | N FFT length (fastest) |
| `"zeropad"` | Signal decays to zero at edges | Significant amplitude at boundaries | ~2N FFT length |

**Oscillations at boundaries:** When the signal has active oscillations at an edge, `"reflection"` reverses the wave direction at that point, creating a cusp (instantaneous frequency doubling artifact). Prefer `"zeropad"` in this case — it attenuates to zero rather than creating a false continuation. Use `"reflection"` only when the signal is locally stationary (slowly varying) at its edges.

For large signals (>100K samples), `"periodic"` avoids doubling the FFT length. Validate with boundary assessment script first.

**Why performance differs:** The CWT computation is dominated by inverse FFT of the signal-wavelet product. `"periodic"` uses N-point FFT (DFT naturally assumes periodicity). `"reflection"` or `"zeropad"` extend the signal to ~2N points before transforming.

### 5. Compute and Interpret

#### Output Signatures

**`cwt()`:**
```matlab
[cfs, f, coi, fb, scalcfs] = cwt(signal, ...);
```

**`wt()`:**
```matlab
[cfs, f, coi, scalcfs] = wt(fb, signal);
```

- `cfs` — Wavelet coefficients. For complex signals: 3D array (scales x time x 2) where page 1 = positive frequencies (analytic) and page 2 = negative frequencies (anti-analytic).
- `f` — Frequencies in Hz (if `SamplingFrequency` set), cycles/sample (if no Fs), or periods as `duration` (if `SamplingPeriod` used).
- `coi` — Cone of influence values (one per time sample).
- `fb` — Filter bank object (from `cwt` only, 4th output).
- `scalcfs` — Scaling coefficients (lowpass filter capturing near-DC content wavelets cannot reach).

#### Interpreting Coefficient Values

MATLAB CWT uses **L1 normalization**: wavelets scaled by `1/s`. This means:
- `abs(cfs)` ≈ **amplitude** of the signal component at each time-frequency point
- A unit-amplitude sinusoid yields `abs(cfs) ≈ 1` at the matching scale
- Values are directly comparable across frequencies
- Plot `abs(cfs)`, not `abs(cfs).^2` or `log(abs(cfs))`

This differs from DWT (which uses L2 normalization for energy preservation).

#### Scaling Coefficients

Wavelets must have zero mean — cannot capture DC/near-DC content. The scaling filter is a lowpass filter covering frequencies below the lowest wavelet. Request scaling coefficients (last output) when:
- Low-frequency content matters to the analysis
- Planning to reconstruct via `icwt` (required for perfect reconstruction)

#### Cone of Influence

The COI marks regions potentially affected by edge effects. It is a **caution zone**, not an exclusion zone:
- Inside COI boundary: coefficients are reliable
- Outside (near edges): potentially affected by boundary extension — treat with increased skepticism
- A well-chosen boundary method reduces (but never eliminates) edge contamination

### 6. Visualize (if needed)

See Patterns section below.

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `cwt` | Compute CWT, optionally plot scalogram | Wavelet Toolbox |
| `cwtfilterbank` | Construct reusable filter bank object | Wavelet Toolbox |
| `wt` | Compute CWT using filter bank (method) | Wavelet Toolbox |
| `cwtfreqbounds` | Query valid frequency range | Wavelet Toolbox |
| `icwt` | Inverse CWT (requires scaling coefficients for perfect reconstruction) | Wavelet Toolbox |
| `waveletTimeFrequencyAnalyzer` | Interactive CWT app (full options, script export) | Wavelet Toolbox |

### cwtfilterbank Inspection Methods

| Method | Returns |
|--------|---------|
| `wavelets` | All wavelets at all scales (time domain) |
| `freqz` | Frequency responses of all wavelets |
| `scales` | Scale factors used to dilate wavelets |
| `powerbw` | Table: center frequency, half-power bandwidth, band edges |

## Patterns

### Basic Scalogram (Visualization Only)

```matlab
% Auto-plots scalogram — do NOT capture outputs
cwt(signal, "Morse", Fs);
```

### Scalogram into Specific Axes (App Designer)

```matlab
% Plot into uiaxes or axes — no outputs
cwt(signal, "Morse", Fs, 'Parent', ax);
```

### Efficient Repeated Analysis

```matlab
fb = cwtfilterbank(SignalLength=length(signal), SamplingFrequency=Fs, ...
    Wavelet="Morse", TimeBandwidth=60, VoicesPerOctave=12);

% Option A: familiar cwt interface + auto-plot
cwt(signal1, 'FilterBank', fb);

% Option B: programmatic access
[cfs, f, coi] = wt(fb, signal2);
```

### Manual Scalogram (Real-Valued Signal)

Use when you need both the data AND a plot.

```matlab
[cfs, f, coi] = cwt(signal, "Morse", Fs);
t = (0:length(signal)-1) / Fs;

ax = newplot;
imagesc(ax, t, f, abs(cfs))
ax.YDir = "normal";
ax.YScale = "log";
xlabel(ax, "Time (s)")
ylabel(ax, "Frequency (Hz)")
title(ax, "Scalogram")
colorbar(ax)

% Optional: add COI
hold(ax, "on")
plot(ax, t, coi, 'w--', LineWidth=1.2)
```

### Manual Scalogram (Complex-Valued Signal, Combined Plot)

For complex signals, `cfs` is a 3D array (scales x time x 2): page 1 contains positive-frequency (analytic) coefficients and page 2 contains negative-frequency (anti-analytic) coefficients. Use `scripts/plotAntiAnalyticScalogram.m` for a combined -Fs/2 to Fs/2 view:

```matlab
fb = cwtfilterbank(SignalLength=length(signal), SamplingFrequency=Fs);
[cfs, f] = wt(fb, signal);
t = (0:length(signal)-1) / Fs;

plotAntiAnalyticScalogram(abs(cfs), f, t);
```

**Why `surf` instead of `imagesc` for complex signals:** The frequency axis spans negative to positive. Setting `YScale = "log"` would fail (log of negative numbers). `surf` handles the non-uniform logarithmic spacing correctly without requiring a log axis setting.

### Transient Localization

When the goal is to precisely locate impulsive events or abrupt changes:

**Wavelet choice for time localization (best to worst):**

| Wavelet | Time Localization | Why |
|---------|-------------------|-----|
| `"Morse"` with `TimeBandwidth=10–20` | **Best** | Low TB makes wavelet compact in time |
| `"amor"` (analytic Morlet) | Good | Equivalent to Morse with P²≈36, naturally biased toward time localization |
| `"bump"` | **Worst** | Compact in *frequency* domain → maximally spread in time (Heisenberg) |

```matlab
[cfs, f, coi] = cwt(signal, "Morse", Fs, TimeBandwidth=20);
t = (0:length(signal)-1) / Fs;

% Extract the highest-frequency scale (first row = finest scale)
finestScale = abs(cfs(1, :));

% Plot to identify transient locations
figure
plot(t, finestScale)
xlabel("Time (s)")
ylabel("|CWT| at finest scale")
title("Transient Detection")
```

Run `scripts/illustrateTransientLocalization.m` to compare all three wavelets on an impulse signal.

## Constant-Q Property and Limitations

CWT is a constant-Q analysis: bandwidth is proportional to center frequency.
- **High frequencies:** broad bandwidth (less frequency resolution), short time support (better time resolution)
- **Low frequencies:** narrow bandwidth (better frequency resolution), long time support (less time resolution)

**Limitation:** At high frequencies, the wide bandwidth means CWT **cannot resolve closely-spaced tones**. If tone separation `Δf` is small relative to center frequency (`Δf/fc < 1/Q`), the components will be smeared together. Use STFT (constant bandwidth) instead.

Example: DTMF tones at 3600 and 3700 Hz (100 Hz apart) at fs=8000 Hz. CWT at 3650 Hz with bump wavelet (Q~20) has bandwidth ~182 Hz — cannot separate them. STFT with M=256 gives 31.25 Hz resolution — easily resolves both.

## Scale-Frequency Relationship

Scale and frequency are inversely related: `s = f_psi / f`, where `f_psi` is the mother wavelet's peak frequency (in cycles/sample).

| Wavelet | Peak frequency `f_psi` (cycles/sample) |
|---------|----------------------------------------|
| Morse(gamma, TB) | `(beta/gamma)^(1/gamma) / (2*pi)`, where `beta = TB/gamma` |
| amor (analytic Morlet) | `6/(2*pi) ≈ 0.9549` (fixed) |
| bump | `5/(2*pi) ≈ 0.7958` (fixed) |

To convert to physical Hz: `f_Hz = f_psi * Fs / s`.

Key points:
- Scale is unitless regardless of Fourier transform convention
- Large scale → low frequency, small scale → high frequency
- The CWT uses L1 normalization, so dilating by `s` gives a filter centered at `f_psi/s`
- `centerFrequencies(fb)` returns the frequency at each scale for a given filter bank

## Interactive Exploration

| Tool | Launch | Capabilities |
|------|--------|--------------|
| `waveletTimeFrequencyAnalyzer` | Command line or Apps Gallery | Full wavelet options, COI toggle, period/frequency display, complex signal support, **script generation** |
| Signal Analyzer scalogram | `signalAnalyzer(signal)` → Display tab → Scalogram | Quick scalogram, Morse only, real signals only |

Recommend `waveletTimeFrequencyAnalyzer` when the user needs to explore parameters and export a script.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Calling `figure` then `[cfs,f] = cwt(...)` expecting a plot | Capturing outputs suppresses auto-plotting (`nargout==0` triggers plot) | Call `cwt(...)` with no outputs, or reproduce manually |
| Using `cwt()` in a loop without pre-building filter bank | Rebuilds filter bank every iteration (expensive) | Build `fb = cwtfilterbank(...)` once, pass via `'FilterBank'` or use `wt` |
| Plotting `abs(cfs).^2` thinking it's a "power" scalogram | L1 normalization means `abs(cfs)` already gives amplitude — squaring distorts interpretation | Plot `abs(cfs)` |
| Using `imagesc` for combined complex-signal plot with negative frequencies | Cannot set `YScale="log"` with negative frequencies | Use `plotAntiAnalyticScalogram` or `surf` |
| Leaving `FrequencyLimits` at default for known narrowband signals | Computes unnecessary scales, wastes time | Run PSD assessment, set `FrequencyLimits` to energy-containing band |
| Using `"periodic"` boundary when endpoints differ | Creates artificial discontinuity | Inspect endpoints first; use `"reflection"` if they differ |
| Adjusting `WaveletParameters` gamma without specific reason | Breaks Morse wavelet symmetry in Fourier domain | Use `TimeBandwidth` alone (keeps gamma=3) |
| Using `"bump"` wavelet for time localization of transients | `"bump"` is compact in *frequency* domain — worst time localization | Use `"Morse"` with low `TimeBandwidth` (10–20) |

## Low-Frequency Analysis

The lowest achievable frequency depends on signal length and wavelet time standard deviation:
- Constraint: 2σ_t of wavelet ≤ signal length at largest scale
- Higher `TimeBandwidth` → wider wavelets → lowest frequency further from DC
- Use `cwtfreqbounds` to check achievable range
- Request scaling coefficients (last output of `cwt`/`wt`) to capture near-DC content

## Inverse CWT (icwt)

### Reconstruction Methods

`icwt` has two fundamentally different inversion paths:

| Method | Fidelity | Requirements | Use when |
|--------|----------|--------------|----------|
| **Analysis filter bank** (exact) | Machine precision (~1e-16) | `Boundary="periodic"` in forward CWT + analysis filters from `freqz` | Need exact reconstruction |
| **Morlet single-integral** (approximate) | Approximate (error depends on signal) | None — works with any CWT output | Quick reconstruction, bandpass filtering, exploratory work |

### Exact Reconstruction (filter bank method)

Perfect reconstruction requires the analysis filter bank, which you obtain from `cwtfilterbank`:

```matlab
% Forward CWT — must use periodic boundary
fb = cwtfilterbank(SignalLength=length(x), SamplingFrequency=Fs, Boundary="periodic");
[cfs, ~, ~, scalcfs] = wt(fb, x);

% Get analysis filters
psif = freqz(fb, FrequencyRange="twosided", IncludeLowpass=true);

% Exact inversion
xrec = icwt(cfs, [], ScalingCoefficients=scalcfs, AnalysisFilterBank=psif);
% norm(xrec' - x, Inf) ≈ 1e-16
```

Or equivalently using `cwt` (filter bank is the 4th output):

```matlab
[cfs, f, coi, fb, scalcfs] = cwt(x, Fs, Boundary="periodic");
psif = freqz(fb, FrequencyRange="twosided", IncludeLowpass=true);
xrec = icwt(cfs, [], ScalingCoefficients=scalcfs, AnalysisFilterBank=psif);
```

**Critical:** `AnalysisFilterBank` cannot be combined with `SignalMean`, `VoicesPerOctave`, `TimeBandwidth`, or `WaveletParameters`. It is a separate inversion path.

### Approximate Reconstruction (Morlet single-integral)

Uses the admissibility constant to sum CWT coefficients over scale. Misses DC/near-DC content that wavelets cannot capture.

```matlab
% Option A: scalar mean (simplest)
[cfs, f] = cwt(x, Fs);
xrec = icwt(cfs, 'SignalMean', mean(x));

% Option B: time-varying trend (better low-frequency recovery)
trend = smoothdata(x, 'movmean', 100);
xrec = icwt(cfs, 'SignalMean', trend);

% Option C: scaling coefficients (best approximate method)
[cfs, ~, ~, ~, scalcfs] = cwt(x, Fs);
xrec = icwt(cfs, 'ScalingCoefficients', scalcfs);
```

**Cannot specify both `SignalMean` and `ScalingCoefficients`** — they serve the same role (DC recovery).

### Bandpass-Filtered Reconstruction

Extract a frequency-localized approximation by specifying a frequency range:

```matlab
[cfs, f] = cwt(x, Fs);
xrec = icwt(cfs, [], f, [flo fhi], 'SignalMean', mean(x));
```

This zeros out coefficients outside `[flo, fhi]` before applying the Morlet formula. Useful for isolating specific oscillatory components.

### Wavelet Must Match

If you used a non-default wavelet in the forward CWT, pass it to `icwt`:

```matlab
[cfs, ~, ~, ~, scalcfs] = cwt(x, 'bump');
xrec = icwt(cfs, 'bump', 'ScalingCoefficients', scalcfs);
```

### Decision Tree

```
Need exact reconstruction?
├── Yes → Use AnalysisFilterBank + ScalingCoefficients
│         (requires Boundary="periodic" in forward CWT)
└── No
    ├── Need bandpass filtering? → icwt(cfs, [], f, [flo fhi], SignalMean=...)
    └── Just need approximate signal back?
        ├── Have scaling coefficients? → icwt(cfs, ScalingCoefficients=scalcfs)
        ├── Know the mean? → icwt(cfs, SignalMean=mean(x))
        └── Have a trend estimate? → icwt(cfs, SignalMean=trend)
```

### Deep Learning Integration

| Function | Context | Input type | Output |
|----------|---------|------------|--------|
| `dlicwt` | Custom training loops | Complex or real `dlarray` (CBT/SCBT) | `dlarray` (CBT) |
| `icwtLayer` | `dlnetwork` architectures | **Real only** (concatenated real/imag along channel dim) | Real `dlarray` (CBT) |

Both use the exact filter-bank reconstruction path only (no Morlet approximation).

#### `dlicwt` — Custom Training Loops

```matlab
% Forward: dlcwt outputs complex dlarray
fb = cwtfilterbank(SignalLength=N, Boundary="periodic");
[psif, indices] = cwtfilters2array(fb, 1e-8, IncludeLowpass=true);

% In training loop:
cfs = dlcwt(x_dl, psif, indices);          % complex output
xrec = dlicwt(cfs, psif, indices);          % accepts complex input
```

- Accepts **complex** `dlarray` — pairs naturally with `dlcwt`
- Requires `psif` (analysis filters as `(1,1,:)` dlarray) and `indices` (filter index matrix)
- Formatted/unformatted pattern: if input is formatted, output is formatted `"CBT"`; if `DataFormat` is specified explicitly, output is unformatted

#### `icwtLayer` — dlnetwork

```matlab
% Construct layer
layer = icwtLayer(SignalLength=1024, VoicesPerOctave=12, ...
    IncludeLowpass=true, Wavelet="Morse", TimeBandwidth=60);
```

- **Input must be real** — expects real/imaginary parts concatenated along channel dimension (pairs with `cwtLayer` which outputs real)
- Channel dimension gets halved in output (real/imag → complex → real signal)
- **Weights are learnable** — initialized from `cwtfilterbank` analysis filters but can be fine-tuned. Default `WeightLearnRateFactor=0` (frozen). Set > 0 to learn modified reconstruction filters.
- Always uses `Boundary="periodic"` internally

#### Deep Learning Gotchas

| Gotcha | Detail |
|--------|--------|
| `icwtLayer` only accepts real | If CWT output is complex, concatenate real/imag along channel dim before passing to `icwtLayer` |
| `dlicwt` accepts complex | Pairs directly with `dlcwt` output — no concatenation needed |
| No Morlet approximation | Both DL paths use exact filter-bank inversion only |
| Filter bank must match | `psif` and `indices` used in `dlicwt` must come from the same `cwtfilterbank` used for the forward `dlcwt` |
| `icwtLayer` weights are learnable | Default is frozen (rate=0). Enable learning only if you want the network to adapt the reconstruction |

### Common icwt Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `AnalysisFilterBank` without periodic boundary in forward CWT | Filters are derived assuming periodic convolution — mismatch causes reconstruction error | Always use `Boundary="periodic"` in `cwt`/`cwtfilterbank` when planning exact reconstruction |
| Omitting `ScalingCoefficients` with `AnalysisFilterBank` | Loses DC/near-DC content the wavelets can't capture | Always pass `ScalingCoefficients=scalcfs` alongside the filter bank |
| Specifying both `SignalMean` and `ScalingCoefficients` | Mutually exclusive — both fill the same role | Choose one |
| Combining `AnalysisFilterBank` with `VoicesPerOctave` or `TimeBandwidth` | These are Morlet-method options, incompatible with filter bank path | Use filter bank path alone, or Morlet path alone |
| Expecting perfect reconstruction from Morlet method | Single-integral formula is inherently approximate | Use filter bank path if exact reconstruction is required |
| Forgetting to pass wavelet name to `icwt` when using non-default wavelet | `icwt` defaults to Morse — admissibility constant will be wrong | Pass the same wavelet: `icwt(cfs, 'bump', ...)` |

## Documentation References

| Topic | Link |
|-------|------|
| `cwt` function reference | https://www.mathworks.com/help/wavelet/ref/cwt.html |
| `cwtfilterbank` reference | https://www.mathworks.com/help/wavelet/ref/cwtfilterbank.html |
| `icwt` function reference | https://www.mathworks.com/help/wavelet/ref/icwt.html |
| Practical introduction to CWT | https://www.mathworks.com/help/wavelet/ug/practical-introduction-to-time-frequency-analysis-using-the-continuous-wavelet-transform.html |
| Morse wavelet family | https://www.mathworks.com/help/wavelet/ug/morse-wavelets.html |


----

Copyright 2026 The MathWorks, Inc.

----
