# STFT Reference Guide

## Function Roles

| Function | Purpose | Inverse | Use when |
|----------|---------|---------|----------|
| `stft` | Complex-valued STFT coefficients | `istft` | Analysis-modify-resynthesize workflows |
| `spectrogram` | Power/magnitude spectrogram | None built-in | Visualization, exploratory analysis, PSD estimation |
| `pspectrum` | Calibrated power spectrum | None | Measurements, reassigned spectrograms |

### Key differences between spectrogram, stft, and pspectrum

| Aspect | `spectrogram` / `stft` | `pspectrum` |
|--------|----------------------|-------------|
| Window choice | Any user-specified window vector | Always Kaiser (`Leakage` 0–1; maps to `beta = 40*(1-leakage)`) |
| Resolution control | Window length in samples (user computes `M ≥ fs/Δf`) | `FrequencyResolution` or `TimeResolution` in Hz/seconds |
| Output normalization | `'psd'` or `'power'` flag (`spectrogram`) | Power only; `Type` selects mode (`"power"`, `"spectrogram"`, `"persistence"`) |
| Underlying transform | FFT (user-specified `nfft`) | CZT (Chirp Z-Transform) — can zoom into arbitrary `[f1, f2]` range |
| Overlap specification | Samples (`noverlap`) | Percentage (`OverlapPercent`) |
| Frequency zoom | Manual (user crops after computing full spectrum) | Built-in via `FrequencyLimits` — evaluates only the requested range |
| Edge handling | Truncates incomplete frames | Zero-pads to create extra segment |
| Invertible | `stft` → `istft` (yes); `spectrogram` (no) | No |
| Multichannel | Supported | Not supported for `"spectrogram"` or `"persistence"` types |
| Reassignment | Not available | Built-in (`Reassign=true`) |

**`spectrogram` and `stft` offer much more control than `pspectrum`** — the user specifies the exact window, number of DFT points, and overlap in samples. `pspectrum` abstracts these away (always Kaiser, internally computed window length, overlap as percentage), trading control for convenience.

`pspectrum`'s advantage is its CZT-based engine: it can efficiently zoom into a narrow frequency band via `FrequencyLimits` without computing the full-band spectrum, and it derives the window length automatically from the user's `FrequencyResolution` target.

**When to use which:**
- **`stft`/`istft`**: User needs to invert (modify spectrum and reconstruct the signal)
- **`stft` or `spectrogram`**: User needs full control over the STFT (specific window, nfft, overlap, PSD normalization)
- **`pspectrum`**: User just needs a quick analysis of the signal (auto-selects parameters, gives power directly, supports frequency zoom and reassignment)

## Analysis-Modify-Resynthesize with stft/istft

### CRITICAL: Check Length Preservation FIRST

**Before writing any stft→istft code, always check this condition:**

The ratio `(Nx - L) / (M - L)` must be an integer for `istft` to return the same length as the input, where:
- `Nx` = signal length (samples)
- `L` = overlap length
- `M` = window length

**If this ratio is not an integer, adjust M or L until it is.** Do not rely on padding or truncation as the primary fix — choose parameters that satisfy the condition.

```matlab
% FIRST: Check the integer-ratio condition
Nx = length(x);
M = 256; L = 128;
hop = M - L;
ratio = (Nx - L) / hop;
if ratio ~= floor(ratio)
    error("(Nx-L)/(M-L) = %.4f — not integer. Adjust M or L.", ratio)
end
```

Example — signal of 1000 samples:
```matlab
% BAD: (1000-128)/(256-128) = 6.8125 — not integer → length mismatch
% GOOD: (1000-100)/(200-100) = 9 — integer → same length, perfect reconstruction
```

**This is separate from the COLA condition.** A window can satisfy COLA but still produce a length mismatch if this integer ratio is not met.

### COLA Condition

For perfect reconstruction (when the STFT is unmodified), the window and overlap must satisfy the Constant Overlap-Add constraint:

```matlab
tf = iscola(win, noverlap);  % verify before committing to parameters
```

### Required Workflow for stft→istft

1. Choose window length `M` and overlap `L` based on resolution needs
2. **Check** `(Nx - L) / (M - L)` is an integer — **adjust M or L if not** (preferred over padding)
3. **Verify** `iscola(win, noverlap)` is true
4. Use identical `Window`, `OverlapLength`, `FFTLength` in both `stft` and `istft`

If adjusting parameters is not possible (e.g., M is fixed by resolution requirements), then pad the signal to make `Nx` satisfy the condition and trim after `istft`.

## Inversion: Which Function to Use

| Situation | Function | Notes |
|-----------|----------|-------|
| Have full complex STFT (magnitude + phase) | `istft` | Exact, one-shot overlap-add reconstruction |
| Have only STFT magnitude (no phase) | `stftmag2sig` | Iterative phase recovery (Griffin-Lim and variants) |
| Used `spectrogram` | Switch to `stft`/`istft` | `spectrogram` is not invertible |

### Phaseless Reconstruction with stftmag2sig

When the user only has the STFT magnitude — e.g., "phaseless reconstruction", "I only have the magnitude", "how can I recover the phase" — use `stftmag2sig`:

```matlab
% Reconstruct signal from STFT magnitude only
[x, t, info] = stftmag2sig(S_mag, nfft, fs, ...
    Window=win, OverlapLength=noverlap, ...
    Method="fgla", MaxIterations=200);

% Check convergence
fprintf("Inconsistency: %.2e (after %d iterations)\n", ...
    info.Inconsistency(end), info.NumIterations);
```

**Methods:** `"gla"` (Griffin-Lim, default), `"fgla"` (fast variant), `"legla"` (Le Roux), `"gd"` (gradient descent, requires Deep Learning Toolbox)

**Key requirements:**
- `Window` and `OverlapLength` must match the original STFT computation
- The same integer-ratio length condition `(Nx - L)/(M - L)` applies
- Result is approximate (phase is estimated, not exact)

## Interpreting Spectral Values Across Functions

Users often compare values from different functions at the same frequency and get confused because the numbers don't match. Here's how to reconcile them.

For a sine wave of amplitude A at frequency f₀, true average power = A²/2.

### What each function returns at f₀

| Function | Value at f₀ | Depends on window? | Physical meaning |
|----------|-------------|-------------------|-----------------|
| `pspectrum` (power or spectrogram) | A²/2 | No — normalized internally | True average power (V²) |
| `pwelch(...,'power')` | A²/2 | No — normalized internally | True average power (V²) |
| `pwelch(...,'psd')` | A²/(2×ENBW) | Yes — via ENBW | Power spectral density (V²/Hz) |
| `stft` | (A/2) × sum(win) | **Yes — scales with window** | Raw complex coefficient |

### Converting stft output to physical values

`stft` values scale directly with the window sum — changing window length changes the numbers:

```matlab
% stft values are window-dependent:
%   hann(256):  sum(win) = 127.5  → |S| = 63.75
%   hann(512):  sum(win) = 255.5  → |S| ≈ 127.75
%   hann(1024): sum(win) = 511.5  → |S| ≈ 255.75

% To get physical values from stft:
amplitude = 2 * abs(S) / sum(win);         % one-sided amplitude
power     = 2 * abs(S).^2 / sum(win)^2;    % one-sided power (matches pspectrum)
```

### Converting PSD to power

For windowed PSD estimates (pwelch with `'psd'`), power = PSD × **ENBW** (not PSD × df):

```matlab
ENBW = fs * sum(win.^2) / sum(win)^2;  % effective noise bandwidth
power = psd_value * ENBW;               % matches pwelch 'power' output
```

The ENBW accounts for the window's spectral spreading. For Hann(256) at fs=1000: ENBW ≈ 5.88 Hz (wider than the 1 Hz bin width).

### Summary

- **`pspectrum` and `pwelch(...,'power')`** give true power directly — no conversion needed
- **`pwelch(...,'psd')`** gives density — multiply by ENBW for power
- **`stft`** gives window-scaled coefficients — divide by sum(win) for amplitude, or use `2×|S|²/sum(win)²` for power

## Time-Frequency Filtering with tffilt (R2025a+)

`tffilt` applies a binary mask to the discrete Gabor transform (DGT) of a signal, then reconstructs the filtered result. It enables "paint-and-remove" workflows: identify unwanted regions in the time-frequency plane, mask them, and get a clean signal back.

### Syntax

```matlab
y = tffilt(bmask, x);
y = tffilt(bmask, x, WindowLength=128, HopLength=32, NumFrequencyBins=256, Method="igm");
```

### Creating the Binary Mask

The mask is a logical matrix (nFreqBins × nTimeSteps) where `true` = **remove** that TF bin. The mask dimensions must match the DGT of `x` with the same `HopLength`, `NumFrequencyBins`, and `FrequencyRange`.

```matlab
% Compute DGT to see the TF plane
c = dgt(x, WindowLength=128, HopLength=32, NumFrequencyBins=256);
f = (0:size(c,1)-1) * fs / 256;
t = (0:size(c,2)-1) * 32 / fs;

% Create mask — example: remove a frequency band between 200-300 Hz
bmask = false(size(c));
bmask(f >= 200 & f <= 300, :) = true;

% Or: remove energy above a threshold in a time range
bmask = abs(c) > threshold & t_grid > t1 & t_grid < t2;

% Apply mask and reconstruct
y = tffilt(bmask, x, WindowLength=128, HopLength=32, NumFrequencyBins=256);
```

### Reconstruction Methods

| Method | Algorithm | Quality | Speed | Use when |
|--------|-----------|---------|-------|----------|
| `"gm"` | Direct mask × DGT → IDGT | Artifacts at mask edges | Fast | Quick preview; large masks |
| `"igm"` (default) | Inverse Gabor multiplier (PCG solver) | Good | Moderate | General use |
| `"rigm"` | Regularized optimization (Nyström eigendecomposition) | Best | Slow | Critical quality; complex mask shapes |

### Name-Value Options

| Option | Default | Purpose |
|--------|---------|---------|
| `WindowLength` | 128 | Gaussian window length (determines time-freq tradeoff) |
| `HopLength` | 32 | Hop size (must match mask creation) |
| `NumFrequencyBins` | 256 | Freq bins (must exceed HopLength for redundancy) |
| `FrequencyRange` | `"centered"` | `"centered"`, `"onesided"`, or `"twosided"` |
| `Method` | `"igm"` | Reconstruction method |

### When to Use tffilt vs Other Approaches

| Scenario | Use | Why |
|----------|-----|-----|
| Remove a known interferer visible in the spectrogram | `tffilt` | Define mask by frequency band or TF region |
| Separate harmonic from percussive (audio) | `tffilt` with ratio-based mask | Mask from `abs(Dperc) > 0.5*abs(Dmix)` |
| Remove transient at a known time | `tffilt` | Time-localized mask |
| Extract a single mode/ridge | `fsst` → `tfridge` → `ifsst` | Ridge-following is more precise for narrowband modes |
| Denoise (threshold-based) | `stft` → soft-threshold → `istft` | Direct coefficient modification, no mask needed |

### Key Constraints

- `NumFrequencyBins` must exceed `HopLength` (ensures redundancy for reconstruction)
- All DGT parameters must be identical between mask creation and `tffilt` call
- Signal is zero-padded internally if length is not a multiple of LCM(HopLength, WindowLength)
- Supports codegen (MATLAB Coder) and GPU arrays (R2026a+)

## Frequency Resolution

The frequency resolution of the STFT is determined by the window length:

```
df = fs / M
```

where `M` is the window length in samples. Longer windows give finer frequency resolution at the cost of time resolution (the time-frequency uncertainty tradeoff).

Zero-padding (`FFTLength > M`) interpolates the spectrum for smoother display but does **not** improve true frequency resolution.

## Parameter Recommendation Workflow

When the user provides a signal and asks for time-frequency analysis via STFT, gather these inputs and compute parameters systematically.

### Inputs to gather

| Input | How to determine | Default if unknown |
|-------|------------------|--------------------|
| Sample rate `fs` | User provides or read from data | Required — ask |
| Signal length `Nx` | `length(x)` | Read from signal |
| Minimum frequency separation to resolve `Δf` | User's goal (e.g., "separate 48 Hz from 50 Hz" → Δf = 2 Hz) | fs/256 |
| Whether istft reconstruction is needed | User mentions filtering, denoising, modification | Assume no |

### Parameter computation

```matlab
% 1. Window length from resolution requirement
%    Minimum: M >= fs / delta_f
%    Practical (Hann/Hamming mainlobe ~2x wider): M >= 2*fs / delta_f
M_min = ceil(2 * fs / delta_f);

% Round up to a convenient value (power of 2 helps FFT speed, not required)
M = 2^nextpow2(M_min);  % or just use M_min directly

% 2. Overlap — 75% is standard for Hann/Hamming (good COLA, smooth time axis)
L = round(0.75 * M);

% 3. If istft is needed, verify length preservation
hop = M - L;
if mod(Nx - L, hop) ~= 0
    % Adjust overlap to satisfy integer constraint
    % Find largest L < M such that (Nx - L) is divisible by (M - L)
    for L_try = L:-1:1
        if mod(Nx - L_try, M - L_try) == 0
            L = L_try;
            break
        end
    end
end

% 4. Verify COLA
win = hann(M, 'periodic');
assert(iscola(win, L), "Window/overlap do not satisfy COLA")
```

### Flag tradeoffs to the user

After computing parameters, report:

- **Time resolution:** each window spans `M/fs` seconds
- **Frequency resolution:** `df = fs/M` Hz (true), practical ~`2*fs/M` for Hann
- **Number of time frames:** `floor((Nx - L) / (M - L))`

If the window spans a large fraction of the signal (M > Nx/4), warn:
> "Window length is M samples (T seconds) — you will have very few time frames. Consider whether CWT or synchrosqueezing would better serve your time-frequency localization needs."

### When to recommend a different method

| Situation | Recommendation |
|-----------|---------------|
| Need both fine frequency AND fine time resolution | CWT (`cwt`) — multi-resolution, no fixed window |
| Need sharper TF representation of the STFT | Synchrosqueezed STFT (`fsst`) |
| Transient detection + spectral analysis | CWT or reassigned spectrogram (`pspectrum` with `Reassign=true`) |
| Stationary signal, only need spectrum (no time axis) | `pwelch` or `periodogram` |
| Log-frequency spacing (music/audio) | Constant-Q transform (`cqt`/`icqt`) |

## Deep Learning Integration

| Use case | Functions | Notes |
|----------|-----------|-------|
| Network layer (standard architecture) | `stftLayer` / `istftLayer` | Drop into `dlnetwork`; `TransformMode` controls output (`"mag"`, `"realimag"`, etc.) |
| Custom training loop | `dlstft` / `dlistft` | Accept `dlarray` inputs; support automatic differentiation |

**`stftLayer` properties:**
- `TransformMode`: `"mag"`, `"squaremag"`, `"logmag"`, `"logsquaremag"`, or `"realimag"` — controls what representation feeds the next layer
- `WeightLearnRateFactor`: default 0 (fixed window). Set > 0 to learn the analysis window during training.
- Input: `"CBT"` (channels, batch, time). Output: `"SCBT"` (S = frequency).

**Gotcha — real/complex data flow between layers and dl-functions:**

- `stftLayer` only outputs real-valued data. `istftLayer` only accepts real-valued data. The layer pair uses `TransformMode="realimag"` to concatenate real and imaginary parts along the channel dimension.
- `dlstft` outputs complex-valued `dlarray`. `dlistft` accepts both complex-valued and real-valued inputs.

**`dlistft` input conventions (can be confusing):**

- Accepts `"SCBT"` or `"CBT"` formatted `dlarray` (S = frequency, C = channel, B = batch, T = time)
- If `"CBT"` format: the function unflattens to `"SCBT"` internally. The `"C"` dimension must be divisible by `floor(FFTLength/2)+1`.
- If `"SCBT"` format: the `"S"` dimension must equal `floor(FFTLength/2)+1`.
- **If the input is real-valued**, `dlistft` assumes real and imaginary parts are concatenated along the channel dimension (same convention as `istftLayer`). Therefore the number of channels C must be **even** — the true number of channels is C/2.
- If the input is complex-valued, channels are interpreted directly.

**Gotcha — formatted vs unformatted `dlarray`:**

`dlstft` and `dlistft` produce formatted `dlarray` outputs **only** when the input is a formatted `dlarray`. If the input is an unformatted `dlarray`, you **must** specify `DataFormat` — otherwise the call errors. The output will then also be unformatted.

```matlab
% Formatted input → formatted output (preferred)
x_fmt = dlarray(x, "CBT");
y = dlstft(x_fmt, fs, Window=win);  % output is formatted "SCBT"

% Unformatted input → MUST specify DataFormat, output is unformatted
x_raw = dlarray(x);
y = dlstft(x_raw, fs, Window=win, DataFormat="CBT");  % output is unformatted

% This ERRORS:
% y = dlstft(x_raw, fs, Window=win);  % no DataFormat, unformatted input → error
```

## Further Reading

For a visual comparison of all time-frequency methods (STFT, CWT, Wigner-Ville, synchrosqueezing, constant-Q, data-adaptive MRA), see the [Time-Frequency Gallery](https://www.mathworks.com/help/signal/ug/time-frequency-gallery.html).


----

Copyright 2026 The MathWorks, Inc.

----
