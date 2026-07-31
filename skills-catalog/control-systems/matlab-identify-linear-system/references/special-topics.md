# Special Topics

## 9.1 Closed-Loop Identification

When data is collected under feedback control, special methods are required.

### When is Closed-Loop ID Necessary?

* Unstable plants — cannot operate without feedback
* Safety/economic constraints — cannot open loop
* Systems already in operation — only routine data available

### Methods

| Method | Requirements | Consistent? | When to use |
|--------|-------------|-------------|-------------|
| **Direct** | Known controller, high SNR | Only with correct noise model | Simple cases, high SNR |
| **Indirect** (two-stage) | Known controller, reference signal | Yes | Industry default — most robust |
| **IV methods** | Instruments uncorrelated with noise | Yes | Colored noise in closed loop |
| **Coprime factorization** | Known controller | Yes | Unstable plants |

### Do's and Don'ts

**DO:**
* Ensure reference/setpoint has sufficient excitation
* Use indirect method as default — robust, no noise model needed
* If using direct method, specify a noise model (ARMAX, BJ) — ARX is biased in closed loop
* Use `iv4` when ARX/OE give biased results
* Validate by simulation (prediction fit is misleadingly good in closed loop)

**DON'T:**
* Don't use `arx` directly on closed-loop data expecting unbiased plant estimates
* Don't ignore the controller
* Don't open the loop on an unstable plant

### Practical Workflow

```matlab
% Indirect method: identify closed-loop TF from r->y, then back-calculate G
T_ry = tfest(iddata(y, r, Ts), np_cl, nz_cl);

% Direct method with noise model (biased without it!)
model = bj(iddata(y, u, Ts), [nb nc nd nf nk]);

% IV method (consistent in closed loop without noise model)
model = iv4(iddata(y, u, Ts), [na nb nk]);

% For unstable plants
opt = ssestOptions('Focus', 'simulation', 'EnforceStability', false, ...
    InteractiveOrderSelection=false);
model = ssest(iddata(y, u, Ts), n, opt);
```

### Bias Reference

| Estimator | Open loop | Closed loop (no noise model) | Closed loop (correct noise model) |
|-----------|-----------|------------------------------|-----------------------------------|
| ARX/LS | Consistent | **BIASED** | N/A (fixed noise model) |
| IV4 | Consistent | Consistent | Consistent |
| OE | Consistent | **BIASED** | N/A (no noise model) |
| ARMAX | Consistent | Consistent (if C correct) | Consistent |
| BJ | Consistent | Consistent (if C,D correct) | Consistent |
| ssest/n4sid | Consistent | Depends on noise handling | Consistent |

---

## 9.2 Control-Oriented Identification

When the model will be used for controller design, identification choices must be guided by the control objective.

### Core Philosophy

| Concern | Simulation-oriented ID | Control-oriented ID |
|---------|----------------------|---------------------|
| Frequency focus | Full bandwidth | Crossover region (+/-1 decade around wc) |
| Error metric | Time-domain NRMSE | Frequency-weighted H-inf or nu-gap |
| Bias tolerance | Low everywhere | Low near crossover; bias OK at extremes |
| Noise model | Important for prediction | Only matters for observer design |
| Uncertainty | Nice-to-have | Essential for robust design |
| Model order | Minimize for parsimony | Must be enough for gain/phase near wc |

### Frequency Weighting for Control

```matlab
% Emphasize crossover region (e.g., wc = 10 rad/s)
wc = 10;
[bw, aw] = butter(2, [wc/10, wc*5]/(pi/Ts), 'bandpass');
opt = ssestOptions('Focus', 'simulation', 'WeightingFilter', {bw, aw}, ...
    InteractiveOrderSelection=false);
model = ssest(data, n, opt);
```

### Uncertainty for Robust Control

```matlab
% Extract pointwise uncertainty
w = logspace(-2, 3, 200);
[mag, phase, wout, sdmag, sdphase] = bode(model, w);

% Convert to multiplicative uncertainty
Delta_mult = squeeze(sdmag) ./ squeeze(mag);
% Fit bounding filter (Robust Control Toolbox)
W_I = fitmagfrd(frd(Delta_mult, w, model.Ts), 2);
```

### nu-gap Metric

```matlab
[~, nugap_val] = gapmetric(model_new, model_old);
[~, gam] = ncfmargin(model_old, controller);
% SAFE if nugap_val < gam (controller remains stabilizing)
```

---

## 9.3 MIMO Identification

### Practical Tips

* For large number of outputs, set `OutputWeight` to `eye(ny)`
* Consider separating outputs into sub-groups, identifying separately, then vertically concatenating models
* If input is periodic, use `etfe`/`spa` for empirical FRD, then `ssest` with `InitializeMethod='AAA'`

```matlab
% Check input directionality
G_frd = spa(data);
for k = 1:numel(G_frd.Frequency)
    cond_G(k) = cond(squeeze(G_frd.ResponseData(:,:,k)));
end
% High condition number -> some input directions poorly identified

% Ensure inputs excite ALL directions (uncorrelated PRBS)
u1 = idinput(N, 'prbs', [0 0.5], [-1 1]);
u2 = idinput(N, 'prbs', [0 0.3], [-1 1]);  % different clock rate
data_mimo = iddata(y, [u1 u2], Ts);

% OutputWeight for balanced MIMO fitting with statistically optimal weighting
opt = ssestOptions('OutputWeight', 'noise', InteractiveOrderSelection=false);
model = ssest(data_mimo, n, opt);
```

### MIMO Validation

* Check singular value plots: `sigma(model)`
* Validate each I/O channel separately AND together
* For control: check sensitivity and complementary sensitivity, not just open-loop fit

---

## 9.4 Continuous-Time Identification from Sampled Data

Direct CT estimation avoids discretization artifacts:

```matlab
% Direct CT state-space
model_ct = ssest(data, n, 'Ts', 0, ssestOptions('Focus', 'simulation', ...
    InteractiveOrderSelection=false));

% Direct CT transfer function (default is CT when data.Ts > 0)
model_ct = tfest(data, np, nz);

% Critical: set InterSample correctly
data.InterSample = 'foh';  % for smooth analog inputs
```

**When to prefer CT identification:**
* Physical parameters needed (mass, damping, stiffness)
* Multiple datasets with different sampling rates
* Very fast sampling (DT poles cluster near z=1, ill-conditioned)
* Need to combine with physics (ODE models)

---

## 9.5 Physics-Informed Constraints

| Prior knowledge | How to encode | MATLAB implementation |
|----------------|---------------|----------------------|
| Stability | Poles inside stable region | `opt.EnforceStability = true` |
| Stability margin | Poles inside radius rho < 1 | `opt.Advanced.StabilityThreshold.z = 0.98` |
| DC gain known | G(0) or G(1) fixed | `Structure` constraints on num/den |
| Positive gain | K > 0 | `Structure.Numerator.Minimum` |
| Zero coupling | Off-diagonal = 0 | `Structure.D.Free(i,j) = false` |
| Known integrator | Pole at s=0 / z=1 | Use process model with 'I' |

```matlab
% Grey-box regularization (stay close to physics-based prior)
opt = ssestOptions(InteractiveOrderSelection=false);
opt.Regularization.Lambda = 100;
opt.Regularization.Nominal = 'model';
sys0 = idss(A_prior, B_prior, C_prior, D_prior);
model = ssest(data, sys0, opt);
```

---

## 9.6 Frequency-Domain Data: Limitations

| Can estimate | Cannot estimate |
|-------------|----------------|
| Transfer function (tfest) | Noise model K |
| State-space (ssest with AAA/lsrf) | BJ/ARMAX (require noise model) |
| Output-Error (oe) | DT models from CT frequency data (Ts=0) |
| ARX (arx) | Meaningful residual analysis |
| Process models (procest) | |

---

## 9.7 Troubleshooting Frequency-Domain Fits

When fitting a transfer function to FRD data (`idfrd`), the cost function is:

```
J = Σ |W(ωk) · (G(ωk) - f(ωk))|²
```

where W is the weighting, G is the model, and f is the measured data. Uneven SNR across frequency causes the optimizer to waste parameters on noisy regions while ignoring dynamics of interest.

### Diagnostic: Identify Where the Fit is Poor

Plot the squared error magnitude vs. frequency to see which data points dominate the loss:

```matlab
[resp_model] = squeeze(freqresp(model, Gfrd.Frequency));
resp_data = squeeze(Gfrd.ResponseData);
err = abs(resp_model - resp_data).^2;
semilogx(Gfrd.Frequency, err);
xlabel('Frequency (rad/s)'); ylabel('|G(w) - f(w)|^2');
```

If errors concentrate in a frequency band with high magnitude but poor SNR, the optimizer is chasing noise there and ignoring low-magnitude dynamics elsewhere.

### Preprocessing FRD Data

| Technique | Purpose | Command |
|-----------|---------|---------|
| Truncate frequency range | Remove out-of-band noise | `Gfrd = fselect(Gfrd, wlow, whigh)` |
| Smooth noisy regions | Reduce variance while preserving shape | `movmean(resp(idx), 3)` on low-SNR band |
| Preserve resonant peaks | Don't smooth dynamics of interest | Apply smoothing selectively by frequency band |

```matlab
% Truncate to frequency range of interest
Gfrd = fselect(Gfrd, 1, 2e4);

% Selective smoothing: only below 40 rad/s where SNR is poor
f = squeeze(Gfrd.ResponseData);
w = Gfrd.Frequency;
idx_low = w < 40;
f(idx_low) = movmean(f(idx_low), 3);
Gfrd.ResponseData = reshape(f, [1 1 numel(f)]);
```

### Frequency Weighting for tfest

`tfestOptions('WeightingFilter', W)` accepts three forms:

| Form | Syntax | Effect |
|------|--------|--------|
| String shortcut | `'inv'` | Weight = `1/|f(w)|` — emphasizes low-magnitude regions |
| String shortcut | `'invsqrt'` | Weight = `1/√|f(w)|` — balanced (good default) |
| Custom vector | `Weight` (Nf×1) | Full per-frequency control |

```matlab
% Start with 'invsqrt' — typically a good initial choice
opt = tfestOptions('WeightingFilter', 'invsqrt');
model = tfest(Gfrd, np, nz, opt);

% If that's insufficient, build a custom weight vector
w = Gfrd.Frequency;
Weight = ones(size(w));
Weight(w < 10) = Weight(w < 10) / 10;       % down-weight noisy low-freq
Weight(w > 40 & w < 6000) = Weight(w > 40 & w < 6000) * 30;  % up-weight dynamics band
opt = tfestOptions('WeightingFilter', Weight);
model = tfest(Gfrd, np, nz, opt);
```

### Iterative Troubleshooting Loop

1. Estimate with default weighting
2. Plot `|W(w)·(G(w)-f(w))|²` — identify which frequencies dominate the error
3. Adjust: preprocess data (truncate/smooth) OR adjust weights (reduce noisy bands, boost dynamics bands)
4. Re-estimate and compare
5. Repeat until the model captures all dynamics of interest

### Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| Model fits high-magnitude noise, misses resonances | Unweighted cost dominated by high-|f| region | Use `'invsqrt'` or custom weights boosting resonance band |
| Spurious poles/zeros at low frequency | Optimizer chasing noisy low-freq data | Truncate via `fselect` or down-weight below noise floor |
| Model misses valley/antiresonance | Low magnitude = low contribution to J | Up-weight that frequency band |
| Good fit at most frequencies but wrong at extremes | Insufficient data or extrapolation | Truncate to reliable range before fitting |

---

## 9.8 tfest vs. tfestimate — Clarification

| | `tfest` (System Identification Toolbox) | `tfestimate` (Signal Processing Toolbox) |
|-|----------------------------------------|------------------------------------------|
| **What it does** | Parametric: fits a transfer function model (idtf) | Non-parametric: computes empirical frequency response |
| **Output** | `idtf` object | Complex frequency response vector |
| **Model?** | Yes — simulate, convert, design controllers | No — frequency response plot only |
| **Extract coefficients** | `[num, den] = tfdata(model, 'v')` | N/A |
| **Use when** | You need a parametric model | Quick look at frequency response |

**Workflow combining both:** Use `tfestimate` (or `spa`/`etfe`) first to see the empirical frequency response, then use `tfest` to fit a parametric model to that shape.

---

## 9.9 Model Conversion and Reduction

### d2c, c2d, d2d

```matlab
model_ct = d2c(model_dt);               % default ZOH
model_ct = d2c(model_dt, 'tustin');     % Tustin (bilinear)
model_dt = c2d(model_ct, Ts_new);       % default ZOH
model_new = d2d(model_dt, Ts_new);      % change sample time
```

**Pitfalls:**
* ZOH discretization of systems with relative degree >= 2 introduces unstable sampling zeros
* Tustin avoids sampling zeros but distorts near Nyquist
* Very fast sampling causes ill-conditioning in d2c

### Model Reduction

```matlab
% Balanced reduction
R = reducespec(model, "balanced");
view(R)
R.Order = n_reduced;
model_red = getrom(R);

% Modal reduction (preserves dominant modes)
R = reducespec(model, "modal");
view(R)
R.Order = n_reduced;
model_red = getrom(R);
```

### Model Export

```matlab
% Extract numerator/denominator (transfer function)
[num, den] = tfdata(model, 'v');

% Extract state-space matrices
[A, B, C, D] = ssdata(model);

% To Control System Toolbox format (strip identification metadata)
sys_css = ss(model);   % or tf(model), zpk(model)
```

----

Copyright 2026 The MathWorks, Inc.

----
