# Data Preparation

## 3.1 Load and Inspect

```matlab
advice(data);   % automated data quality assessment
plot(data);     % visual inspection
```

## 3.2 Preprocessing Checklist

| Issue | Detection | Fix |
|-------|-----------|-----|
| Offset/trend | `mean(data.y)` far from zero | `data = detrend(data)` or set `InputOffset`/`OutputOffset` |
| Operating point offsets | I/O signals not centered at zero (system operates around non-zero equilibrium) | Remove operating point: `data = detrend(data, 0)` or specify `InputOffset`/`OutputOffset` in estimation options |
| Missing samples | `NaN` in signals | `data = misdata(data)` |
| Outliers | Visual or `isoutlier` | Remove, interpolate, or use `ErrorThreshold` (robust estimation) |
| Non-uniform sampling | `diff(data.SamplingInstants)` varies | Resample or use CT estimation |
| Multi-experiment | Multiple runs available | `data = merge(d1, d2, d3)` |
| InterSample behavior unknown | Estimating CT model from DT data | Set `data.InterSample = 'zoh'` or `'foh'` or `'bl'` |

**Operating point rule**: Linear identification assumes signals represent *deviations from equilibrium*. If the system operates around a non-zero steady state (e.g., temperature at 350K, valve at 40% open), you MUST subtract the operating point before identification. This is especially critical for MIMO systems where each channel may have a different offset. Failure to remove offsets corrupts DC gain estimates and biases the entire model.

```matlab
% Per-channel operating point removal (MIMO)
data = detrend(data, 0);  % removes mean from each I/O channel

% Or specify offsets explicitly (preserves physical meaning)
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false);
opt.InputOffset = [u1_op; u2_op];    % operating point for each input
opt.OutputOffset = [y1_op; y2_op];   % operating point for each output
model = ssest(data, n, opt);
```

**Outlier rule**: If outliers are > 5% of data, use `ErrorThreshold` (robust estimation) instead of removing them — the data may be telling you the system is nonlinear.

## 3.3 Prefiltering

Prefiltering both input and output BEFORE identification changes the frequency weighting of the estimation.

```matlab
% Band-pass to focus on dynamics of interest (e.g., 1-100 rad/s)
[b,a] = butter(4, [1 100]/(pi/Ts), 'bandpass');
ze_filt = idfilt(ze, {b,a});  % filters BOTH u and y with same filter

% High-pass to remove drift (alternative to detrend)
[b,a] = butter(2, 0.5/(pi/Ts), 'high');
ze_filt = idfilt(ze, {b,a});
```

**Critical rule**: Always filter BOTH input and output with the SAME filter. Filtering only one signal falsifies the transfer function estimate.

**When to prefilter:**
* Remove frequencies outside the range of interest (reduces bias from unmodeled dynamics)
* Suppress frequency bands with poor SNR
* Focus estimation on the control-relevant frequency range

**When NOT to prefilter:**
* If you want the noise model to be meaningful (prefiltering changes the noise model interpretation)
* If data is already clean and you're using `Focus` option instead (Focus achieves similar effect internally)

## 3.4 InterSample Behavior (Critical for Continuous-Time Models)

When estimating CT models from DT data, you MUST specify how the input behaves between samples:

| Setting | Meaning | When to use |
|---------|---------|-------------|
| `'zoh'` | Zero-order hold (piecewise-constant) | DAC output, relay, digital control signals |
| `'foh'` | First-order hold (piecewise-linear) | Smoothly varying analog inputs |
| `'bl'` | Band-limited (no power above Nyquist) | Filtered/anti-aliased analog signals |

```matlab
data.InterSample = 'foh';  % Set before CT estimation
% Access: for SISO single-experiment, InterSample is a char — use char comparison:
%   strcmp(data.InterSample, 'foh')
% For MIMO or multi-experiment, it is a cell array.
% Or per-channel for MIMO:
data.InterSample = {'zoh'; 'foh'};  % COLUMN cell (Nu×1): input 1 = ZOH, input 2 = FOH
% WARNING: row cell {'zoh', 'foh'} FAILS — must be column cell for multi-input data
```

**Rule**: Default is `'zoh'`. If your physical input is analog and smoothly varying, `'foh'` gives more accurate CT models. Wrong InterSample setting causes systematic bias at high frequencies.

## 3.5 Train/Validation Split

```matlab
ze = data(1:floor(end*0.7));    % 70% estimation
zv = data(floor(end*0.7)+1:end); % 30% validation
```

**Rule**: Never validate on training data. If data is short (N < 200), use k-fold cross-validation instead of a holdout split.

## 3.6 Frequency-Domain Conversion

FFT of time-domain data is **lossless** — it opens the door to fast, non-iterative frequency-domain identification. Consider converting when:

* **Data is very large** (N > 50000): rational fitting is much faster than iterative PEM on raw time data
* **Input is periodic** (multisine, swept sine, repeated PRBS): FFT gives exact frequency response at excited frequencies with no leakage
* **You want fast initialization** before iterative time-domain refinement

```matlab
% Convert time-domain to frequency-domain (lossless via FFT)
ze_frd = fft(ze);        % iddata in frequency domain

% Empirical frequency response estimates:
G_etfe = etfe(ze);       % raw (noisy but unbiased)
G_spa = spa(ze);         % smoothed (biased but low variance)

% For periodic data: use exactly one period (or integer multiple)
ze_periodic = ze(1:period_samples);
G_periodic = etfe(ze_periodic);  % exact at excited frequencies
```

## 3.7 Data Quality Red Flags (STOP — do not proceed)

Before starting identification, check for these conditions that will produce misleading results:

| Red Flag | Symptom | Action |
|----------|---------|--------|
| Feedback present | u correlates with past y | Use closed-loop methods (see Special Topics) |
| Actuator saturation | u clips at fixed values | Trim saturated segments or use nonlinear ID |
| Output quantization | y has staircase appearance | Increase measurement resolution or use longer data |
| Data too short | N < 3 * settling time / Ts | Collect more data |
| No excitation | Input is constant or nearly so | Cannot identify — need active excitation |
| Poor excitation | Only step/impulse (1–2 levels) | Insufficient for parametric ID — use PRBS, multisine, or at least 3–4 distinct input levels |
| Multi-rate I/O | Inputs and outputs at different rates | Resample to common rate or use CT estimation |

**Excitation rule**: Simple transient experiments (single step, impulse) are rarely informative enough for proper identification. A step response constrains only the DC gain and dominant time constant — it cannot reliably separate poles, zeros, or delay from dynamics. If experiment design is under your control, collect data where the input changes at least 3–4 distinct levels (amplitude and direction). Preferred excitation signals:

| Signal | Strengths | When to use |
|--------|-----------|-------------|
| PRBS | Broadband, easy to generate, binary | General purpose, robust |
| Multisine | Exact frequency content, periodic, low crest factor | When frequency range is known |
| Swept sine (chirp) | Continuous frequency coverage | Single-channel frequency sweep |
| Random steps (multilevel) | Practical for manual operation | When automated excitation is unavailable |

```matlab
% PRBS: broadband, N samples, band [0 0.8]*Nyquist
u = idinput(N, 'prbs', [0 0.8], [-1 1]);

% Multisine: controlled frequency content, N samples
u = idinput(N, 'sine', [0.01 0.9], [], struct('NumSinusoids', 20));

% Random multilevel steps (at least 4 levels)
levels = [-1 -0.5 0.5 1];
step_len = round(N / 20);  % ~20 transitions
u = repelem(levels(randi(4, 20, 1)), step_len);
u = u(1:N)';
```

## 3.8 Sampling Rate Assessment (Over/Undersampled Data)

Non-optimal sampling rate is one of the most common reasons for poor identification results. Diagnose it early — before wasting effort on model structure selection.

### Diagnostic: Is My Data Well-Sampled?

```matlab
% Quick sampling assessment
Ts = data.Ts;
N = size(data.y, 1);

% Estimate dominant time constant from impulse response
h = impulseest(data, [], impulseestOptions(RegularizationKernel="TC"));
[y_imp, t_imp] = impulse(h);
y_abs = abs(y_imp(:));
idx_settled = find(y_abs < 0.05 * max(y_abs), 1, 'first');
tau_est = t_imp(idx_settled) / 3;  % rough dominant time constant

% Compute sampling ratio
ratio = tau_est / Ts;
fprintf('Estimated tau: %.2f s, Ts: %.4f s, ratio tau/Ts: %.1f\n', tau_est, Ts, ratio);

if ratio > 100
    fprintf('WARNING: OVERSAMPLED (tau/Ts = %.0f >> 15)\n', ratio);
elseif ratio < 3
    fprintf('WARNING: UNDERSAMPLED (tau/Ts = %.1f < 3)\n', ratio);
else
    fprintf('Sampling rate OK (tau/Ts in 3-100 range)\n');
end
```

### Oversampling (Ts << tau, ratio > 50–100)

**Symptoms:**
* DT poles cluster very close to z=1 (ill-conditioned numerics)
* ARX/ARMAX models need very high orders to capture slow dynamics
* Noise dominates the useful signal bandwidth
* `d2c` conversion becomes numerically unstable
* High-order FIR impulse response needed (thousands of taps)
* **Poorly-damped modes are especially vulnerable**: a lightly-damped pole at wn with fast sampling maps to `z = exp((-zeta*wn ± j*wn)*Ts)` — both magnitude and angle increments become tiny, making the pole nearly indistinguishable from the unit circle. Noise pushes the estimate outside |z|=1, producing a spuriously unstable model. This is the single most common cause of "my identified model is unstable even though the system is clearly stable."

**Fixes (in order of preference):**

```matlab
% Option 1: Decimate with anti-alias filter (preferred for DT estimation)
target_ratio = 10;  % aim for ~10 samples per tau
dec_factor = max(1, round(ratio / target_ratio));
data_dec = idresamp(data, dec_factor, 1);  % decimate by dec_factor
fprintf('Decimated: Ts %.4f -> %.4f (factor %d)\n', Ts, data_dec.Ts, dec_factor);

% Option 2: Estimate in continuous time (bypass DT ill-conditioning entirely)
data.InterSample = 'foh';
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false);
model_ct = ssest(data, n, 'Ts', 0, opt);

% Option 3: Use regularized ARX if DT model is required
% Regularization handles the ill-conditioning from near-unit-circle poles
[Lambda, R] = arxRegul(data, [na nb nk], arxRegulOptions('RegularizationKernel', 'TC'));
opt = arxOptions;
opt.Regularization.Lambda = Lambda;
opt.Regularization.R = R;
model = arx(data, [na nb nk], opt);
```

**Decision rule:** If `tau/Ts > 50`, either decimate or use CT estimation. Do not attempt unregularized DT polynomial models — they will be numerically ill-conditioned.

### Undersampling (Ts >> tau, ratio < 3)

**Symptoms:**
* Fast dynamics aliased — model cannot distinguish modes above Nyquist
* Step response appears instantaneous (settling in 1-2 samples)
* Identified bandwidth limited to `π/Ts` regardless of true system
* `delayest` unreliable when true delay ≈ Ts or less
* Bode plot meaningless above Nyquist — model extrapolates

**Fixes:**

```matlab
% Option 1: Resample if raw (higher-rate) data is available
% (This requires going back to the data source)

% Option 2: Accept limited bandwidth — identify only what's resolvable
% Constrain model bandwidth to Nyquist
wN = pi / Ts;
fprintf('Nyquist freq: %.2f rad/s — cannot resolve dynamics above this\n', wN);

% Option 3: Use CT estimation with band-limited InterSample
data.InterSample = 'bl';  % signals are band-limited below Nyquist
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false);
model = ssest(data, n, 'Ts', 0, opt);

% Option 4: For mildly undersampled (ratio 2-3), increase model order
% to approximate the fast modes that leak through aliasing
```

**Decision rule:** If `tau/Ts < 3`, the data cannot resolve the dominant dynamics. Either acquire faster-sampled data or accept that the identified model is a low-bandwidth approximation.

### Summary Table

| Condition | tau/Ts ratio | Primary symptom | Best fix |
|-----------|-------------|-----------------|----------|
| Severely oversampled | > 100 | Poles at z≈1, high-order FIR | Decimate or CT estimation |
| Moderately oversampled | 50–100 | Slow convergence, noise-dominated | Decimate by 5-10x |
| Well-sampled | 5–50 | — | No action needed |
| Marginally undersampled | 3–5 | Some fast modes near Nyquist | CT estimation with 'bl' |
| Severely undersampled | < 3 | Aliasing, dynamics unresolvable | Re-acquire data |

----

Copyright 2026 The MathWorks, Inc.

----
