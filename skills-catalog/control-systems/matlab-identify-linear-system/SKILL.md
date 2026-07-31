---
name: matlab-identify-linear-system
description: >
  Identify a linear dynamic model from input-output or time-series data using MATLAB System Identification Toolbox. Use when estimating transfer function, state-space, ARX, ARMAX, BJ, OE polynomial or process models from measurement data.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---
# Linear Model Identification
  Estimate a linear dynamic model from measurement data using MATLAB System Identification Toolbox. This skill selects the right model type, determines model order, estimates parameters, and validates results — following the methodology a System Identification Toolbox expert would use.

## When to Use
- Identify a transfer function, state-space, or process model from I/O data
- Determine model order from measurement data
- Fit a parametric model for simulation, prediction, or control design
- Convert frequency response data (FRD) to a parametric model
- Compare model structures (ARX vs state-space vs transfer function)  
- Determine frequency response from time-domain data
- Determine a plant model for PID tuning or control design
- Obtain a data-driven linear model when linearization of a Simulink model is not possible or practical
- Tune parameters of a physics-based model (grey-box) using data
- Compare multiple models to determine which best fits the data
- Simulate or predict system response using the identified model
- Perform subspace identification for high-order systems or MIMO systems, or use Eigenvalue Realization Algorithm (ERA) 
- Extract modal parameters (natural frequencies, damping ratios, mode shapes) from frequency response
- Compare model structures (ARX vs state-space vs transfer function)
- Study the possibility of feedback in data by analyzing the correlation between input and output signals
- Study persistence of excitation in the input signals to ensure that the data is informative enough for model identification

## When NOT to Use
- When the system is inherently nonlinear and a linear model is not appropriate
- When the available data is insufficient or of poor quality for reliable model identification
- When the primary goal is to identify a nonlinear model (e.g., neural state-space, NLARX, Hammerstein-Wiener)  
- When estimating the parameters of a Simulink model using experimental data; use Simulink Design Optimization Toolbox instead
- When designing a controller; use Control System Toolbox skills after identifying the plant
- Signal processing (filtering, spectral analysis without model fitting) — use signal processing skills


## Execution Strategy

**Write a single end-to-end MATLAB script and run it.** Do NOT step through phases one tool call at a time. The script should:
1. Create/load data + split into estimation/validation
2. Estimate delay, select structure, estimate model(s)
3. Validate on held-out data by simulation
4. Print results

Only break into multiple steps if the first script fails or produces poor results (fit < 70%).

**Critical rules for every script (MANDATORY — violating any of these is a bug):**
* `InteractiveOrderSelection=false` when using order vectors — this is a HIDDEN property (not visible in disp() or tab-complete) on BOTH ssestOptions AND n4sidOptions. It MUST be set explicitly or a GUI popup HALTS execution
* `EstimateCovariance=false` during ANY search loop (order scan, delay scan) — covariance for discarded models wastes time
* `Focus='simulation'` for simulation/control use on `ssestOptions`, `n4sidOptions`, `procestOptions` (NOT available on `tfestOptions` — tfest has no Focus)
* Multi-model compare returns CELL: `[~, fits] = compare(zv, m1, m2); fits{1}, fits{2}` — ALWAYS pass 2+ models to ONE compare() call, NEVER call compare() separately per model
* `data.InterSample = 'foh'` BEFORE CT estimation if input is smooth analog
* For multi-input InterSample: use column cell `{'zoh'; 'foh'}` (NOT row cell)
* **Delay-first**: ALWAYS call `delayest` or inspect impulse response BEFORE any model estimation (even for MIMO, even when delay seems small)
* **Hedge delays**: NEVER trust a single delay estimate — always try nk AND nk±1, compare fits, pick best
* **Order range**: When selecting order, use a RANGE (vector) not a single integer — `ssest(ze, 2:8, opt)` not `ssest(ze, 4, opt)`

## Arguments

The user provides: $ARGUMENTS

Parse:

* **project_name** (optional): name of a project under `projects/` that has a `SPEC.md`
* **data_source** (optional): path to a `.mat` file, variable name in workspace, or inline description of the data

If neither is provided, ask the user to specify a data source or describe the identification problem.

---

## Design Principles

1. **Start simple, add complexity only when data justifies it.** Try order 2-4 before 10-15.
2. **Delay first.** A wrong delay cannot be fixed by higher order — it's catastrophic.
3. **Set Focus correctly.** The #1 missed option. Default 'prediction' is sometimes wrong for simulation use.
4. **Always hold out validation data.** Never report training fit as performance.
5. **Regularization > high order.** A regularized ARX(30) often outperforms unregularized ARX(5). Use `arxRegul`, or `ssregest`.
6. **State-space is the default.** When unsure, `ssest` handles MIMO, CT/DT, needs only order n.
7. **Compare 2-3 structures.** The first model is rarely the best.
8. **Check residuals.** A high fit with correlated residuals means the model is missing dynamics.
9. **Know when to stop.** >90% fit with white residuals on validation data is success.

---

## Fast Path — Use When Problem Is Clear

If the problem maps directly to one of these patterns, write a single script immediately:

**Step/impulse response → process model** (do NOT split single-transient data):
```matlab
% Step data is one transient — splitting creates IC discontinuity. Use full data.
opt = procestOptions('Focus', 'simulation');
m1 = procest(data, "P1D", opt); m2 = procest(data, "P2D", opt);
[~, fits] = compare(data, m1, m2); fprintf('P1D: %.1f%%, P2D: %.1f%%\n', fits{:});
fprintf('K=%.2f, Tp=%.1f, Td=%.1f\n', m1.Kp, m1.Tp1, m1.Td);
```

**SISO time-domain → transfer function:**
```matlab
ze = data(1:floor(end*0.7)); zv = data(floor(end*0.7)+1:end);
nk = delayest(ze);
% Hedge delay: try nk-1, nk, nk+1
delays = max(1, nk + (-1:1));
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false, EstimateCovariance=false);
models = cell(1, numel(delays));
for i = 1:numel(delays)
    models{i} = tfest(ze, 3, 1, delays(i)*ze.Ts);
end
[~, fits] = compare(zv, models{:}); fprintf('Delay hedge fits: '); fprintf('%.1f%% ', fits{:}); fprintf('\n');
[~, best] = max(cell2mat(fits)); nk_best = delays(best);
% Final estimation with best delay
m1 = tfest(ze, 2, 0, nk_best*ze.Ts); m2 = tfest(ze, 3, 1, nk_best*ze.Ts);
m3 = ssest(ze, 2:6, opt);
[~, fits] = compare(zv, m1, m2, m3); fprintf('Fits: %.1f%%, %.1f%%, %.1f%%\n', fits{:});
```

**MIMO → state-space:**
```matlab
ze = data(1:floor(end*0.7)); zv = data(floor(end*0.7)+1:end);
nk = delayest(ze);  % delay-first, even for MIMO
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false, EstimateCovariance=false);
sys = ssest(ze, 1:10, opt);  % order RANGE, not single integer
[~, fit] = compare(zv, sys); fprintf('Fit: %.1f%%\n', fit);
% For MIMO bandwidth, use per-channel: bandwidth(sys(i,j))
for i = 1:size(sys,1), for j = 1:size(sys,2)
    fprintf('BW(%d,%d)=%.2f rad/s\n', i, j, bandwidth(sys(i,j)));
end, end
```

**FRD / large periodic data → frequency-domain path:**
```matlab
opt = ssestOptions('InitializeMethod', 'AAA', 'Focus', 'simulation', ...
    InteractiveOrderSelection=false, EstimateCovariance=false);
opt.SearchOptions.MaxIterations = 0;
sys = ssest(Gfrd, 1:maxOrder, opt);
```

If the fast path gives fit > 85%, you're done. Report results and move on.

---

## Deep Path — For Ambiguous or Failed First Attempts

Use this structured investigation when the fast path fails (fit < 70%), the problem is ambiguous, or the user asks for deeper analysis.

### Problem Characterization

Determine: SISO/MIMO, time/frequency domain, intended use (simulation/prediction/control), known constraints. See [references/data-preparation.md](references/data-preparation.md) for preprocessing details.

### Nonlinearity Check (STOP/GO Gate)

Before committing to linear identification, verify that a linear model is appropriate.

| Method | How | Interpretation |
|--------|-----|----------------|
| **Amplitude dependence** | Estimate models from datasets at different input amplitudes | If gain/dynamics change with amplitude -> nonlinear |
| **Harmonic analysis** | Apply periodic input, check for even harmonics in output spectrum | Even harmonics indicate nonlinearity |
| **Model order escalation** | Fit orders 2, 4, 8, 12, 16 — plot fit vs. order | Plateauing at low fit despite high order -> nonlinearity |
| **Residual structure** | Inspect residuals vs. amplitude of u or y | Systematic patterns -> nonlinear |
| **Split-data test** | Estimate on first half, validate on second half AND vice versa (use **low** model order, e.g. 2-4, to avoid false positives from estimation variance) | Asymmetric fits -> non-stationary or nonlinear |
| **ISNLARX** | Use the `isnlarx` method on `iddata` to assess severity of nonlinearity |

### Decision

* If nonlinearity is mild (gain varies <20%), proceed with linear ID but note limitations
* If strong nonlinearity detected, recommend: Hammerstein-Wiener, NLARX, or neural state-space
* If non-stationary (time-varying), consider segmented estimation or recursive methods

### Data Preparation

See [references/data-preparation.md](references/data-preparation.md) for the full preprocessing workflow including:
- Loading and inspection (`advice`, `plot`)
- Preprocessing checklist (offsets, missing data, outliers, non-uniform sampling)
- Prefiltering (band-pass, frequency weighting)
- InterSample behavior for CT models
- Train/validation split
- Frequency-domain conversion
- Data quality red flags
- Probability of output feedback in the data (`checkFeedback`)
- Persistence of excitation check (`pexcit`)

### Model Type Selection

Apply this decision tree. The FIRST matching branch is the recommendation:

```
1. Physical structure known (ODEs with unknown parameters)?
   --> idgrey + greyest (outside this skill's scope)

2. Frequency-domain data (idfrd), very large dataset (N > 50k), periodic input, or high modal density?
   --> Frequency-domain path:
       - ssest with InitializeMethod='AAA' (SISO/SIMO/MISO/MIMO — only option for full MIMO FRD)
       - ssest with InitializeMethod='lsrf' (SISO/SIMO/MISO only — vector fitting)
       - tfest on idfrd/etfe/spa data (uses lsrf internally; SISO/SIMO/MISO only)

3. Low-order process (1-3 poles, <=1 zero, with gain+delay)?
   --> idproc + procest

4. SISO, continuous-time, moderate complexity (np <= 10)?
   --> idtf + tfest

5. MIMO, or high-order, or "just need a good model quickly"?
   --> idss + ssest (with n4sid for initialization)

6. Need explicit noise model (prediction/filtering application)?
   --> Polynomial models: ARX, IV4, ARMAX, OE, BJ

7. Time-series (no input, output only)?
   --> ar() for AR, or ssest with nu=0 for state-space
```

See [references/model-structures.md](references/model-structures.md) for detailed guidance on process models, polynomial models, and when to use each.

### Order Determination

See [references/order-determination.md](references/order-determination.md) for methods:
- Delay estimation (`delayest`, impulse response)
- ARX structure search (`arxstruc`, `selstruc`)
- Subspace order selection (`n4sid` with order range)
- Iterative complexity (transfer function ladder)
- Process model ladder
- Frequency-domain path (AAA initialization)

**Rules of thumb:**
* Max useful order: `n_max ~ min(N/20, 30)`
* MIMO state-space: start with `n = max(ny, nu) * 2` up to `5`
* If ARX(10) and ssest(4) give similar fits, prefer ssest(4)
* Stop increasing order when improvement < 2% per additional parameter

### Estimation

See [references/estimation.md](references/estimation.md) for the full estimation workflow including:
- Critical options (Focus, InitialState, Stability, Regularization, OutputWeight, WeightingFilter, ErrorThreshold)
- Initialization methods for ssest and tfest
- Why ssest outperforms n4sid
- Frequency-domain estimation path (AAA, lsrf)
- Estimation commands for all model types
- Regularized ARX to state-space (ssregest)
- Structured estimation with parameter bounds
- Multi-model strategy

**Key reminders:**
```matlab
% Focus — available on ssestOptions, n4sidOptions, arxOptions, etc. (NOT tfestOptions)
opt = ssestOptions('Focus', 'simulation');   % for simulation/control
opt = ssestOptions('Focus', 'prediction');   % for forecasting
% NOTE: tfest does NOT have a Focus option. For time-domain data, tfest always
% produces a stable model. Use WeightingFilter for frequency emphasis with tfest.

% Disable interactive order selection when using an order vector
opt = n4sidOptions(InteractiveOrderSelection=false);
% or: opt = ssestOptions(InteractiveOrderSelection=false);

% Continuous-time estimation — set 'Ts',0 for ssest; tfest is CT by default
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false);
model_ct = ssest(data, n, 'Ts', 0, opt);
model_ct = tfest(data, np, nz);  % CT by default from sampled data
data.InterSample = 'foh';        % set BEFORE estimation for smooth analog inputs

% Regularization for high-order ARX
[Lambda, R] = arxRegul(data, orders, arxRegulOptions('RegularizationKernel', 'TC'));
```

---

## Validation (MANDATORY)

### Compare on Validation Data (MANDATORY)

**CRITICAL**: Always validate by **simulation** (infinite prediction horizon). A model estimated with `Focus='prediction'` can show excellent 1-step-ahead fits even when the dynamics are wrong.

```matlab
% Validate by simulation (default of compare)
[yhat, fit] = compare(zv, model);
fprintf('Validation fit (simulation): %.1f%%\n', fit);

% Multi-model comparison — fit is a CELL ARRAY, not a numeric vector
[yhat, fits] = compare(zv, m1, m2, m3);
fprintf('Fits: %.1f%%, %.1f%%, %.1f%%\n', fits{:});
% Extract as numeric vector: cell2mat(fits)

% 1-step prediction fit (for forecasting models ONLY)
[yhat_pred, fit_pred] = compare(zv, model, 1);
% WARNING: fit_pred >> fit_sim means the noise model is doing the heavy lifting
```

### Residual Analysis

```matlab
% Programmatic residual analysis (no plots — suitable for batch/agent mode)
[e, r] = resid(zv, model);
% e = residual iddata object
% r = 3D array [M x nz x nz] where nz = ny + nu, M = number of lags (26 default)
%   r(:,1:ny,1:ny)       = residual autocovariance (RAW, not normalized)
%   r(:,ny+1:end,1:ny)   = cross-covariance between input and residual
% Quick whiteness check (SISO: ny=1, nu=1, nz=2):
acf = r(:,1,1) / r(1,1,1);  % normalize by lag-0 to get correlation
N = size(zv.y, 1);
conf99 = 2.58 / sqrt(N);    % 99% confidence bound
is_white = all(abs(acf(2:end)) < conf99);
fprintf('Residuals white: %s (99%% bound = %.4f)\n', string(is_white), conf99);

% Cross-correlation: input-residual (SISO)
xcf = r(:,2,1) / sqrt(r(1,1,1) * r(1,2,2));  % normalized cross-covariance
is_uncorr = all(abs(xcf) < conf99);
fprintf('Residuals uncorrelated with input: %s\n', string(is_uncorr));
```

**Residual interpretation guide:**

| Autocorrelation (acf) | Cross-correlation (xcf) | Diagnosis | Action |
|----------------------|------------------------|-----------|--------|
| White | Uncorrelated | Model is adequate | Done |
| Significant at lags | Uncorrelated | Noise model insufficient, but plant model may be OK for simulation | Increase noise model order (C/D in ARMAX/BJ); plant G is still usable |
| White | Significant at lag k | Missing input dynamics at lag k | Add regressor u(t-k): increase nb or adjust nk in ARX/ARMAX/BJ |
| Significant at lags | Significant at lag k | Both plant and noise model inadequate | Increase both model order and noise order; check delay |

### Fit Interpretation

| Fit % | Verdict | Next Action |
|-------|---------|-------------|
| > 95% | Excellent | Done — report results |
| 85-95% | Good | Acceptable; try one alternative to confirm |
| 70-85% | Moderate | Increase order, try different structure, check data |
| 50-70% | Poor | Wrong structure, missing nonlinearity, or bad data |
| < 50% | Failed | Reassess fundamentals (delay? feedback? nonlinear?) |

**When model is inadequate — re-estimation recipe:**
```matlab
% Scan an order RANGE (never just guess one number)
opt = ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false, EstimateCovariance=false);
model_new = ssest(ze, 2:8, opt);
% Compare old and new with multi-model compare (MANDATORY pattern)
[~, fits] = compare(zv, model_old, model_new);
fprintf('Old: %.1f%%, New: %.1f%%\n', fits{:});
```

See [references/validation-and-diagnostics.md](references/validation-and-diagnostics.md) for uncertainty analysis, stability assessment, diagnostic checklist, and initial conditions guidance.

---

## Results and Artifacts

### Generate Outputs

1. **Model summary** — type, order, fit percentage, key parameters
2. **Comparison plot** — measured vs. simulated on validation data
3. **Bode plot** — frequency response with confidence bounds
4. **Residual plot** — autocorrelation and cross-correlation

```matlab
% Comparison plot
[yhat, fit] = compare(zv, model);
title(sprintf('Validation: %.1f%% fit', fit));

% Bode with confidence
h = bodeplot(model);
showConfidence(h, 3);

% Residuals
resid(zv, model);
```

### Results Summary

```
================================================================
  Linear Model Identification — Results
================================================================
  Model type:     <idss / idtf / idpoly / idproc>
  Order:          <n / [na nb nk] / np poles, nz zeros>
  Delay:          <nk samples (X seconds)>
  Focus:          <simulation / prediction>

  Validation fit: XX.X% (NRMSE on held-out data)
  FPE:            <value>
  AIC:            <value>

  Key dynamics:
    Poles:        <dominant pole locations>
    Zeros:        <zero locations if few>
    DC gain:      <value>
    Bandwidth:    <-3dB frequency (SISO only; for MIMO use bandwidth(model(i,j)) per channel)>

  Status: FIT ACHIEVED / BELOW TARGET — <recommendation>
================================================================
```

### Save Artifacts

1. **MATLAB script** — `identify_model.m` containing the full reproducible workflow
2. **Model MAT file** — `identified_model.mat` with the final model object
3. **Figures** — PNG files for comparison, Bode, residuals
4. **Results summary** — printed to console

---

## Special Topics

For advanced scenarios, see:
- [references/special-topics.md](references/special-topics.md) — closed-loop ID, control-oriented ID, MIMO, continuous-time, physics-informed constraints, frequency-domain limitations, recursive estimation, tfest vs. tfestimate

---

## Common Gotchas — Quick Reference

| # | Mistake | Consequence | Fix |
|---|---------|-------------|-----|
| 1 | Validating on training data | Overfitting undetected | Always hold out validation set |
| 2 | Using prediction fit to judge simulation quality | False confidence in dynamics | Validate by simulation (horizon=Inf) |
| 3 | Wrong InterSample setting | Systematic bias at high freq in CT models | Set `'foh'` for smooth analog inputs |
| 4 | Ignoring Focus option | Model optimizes wrong criterion | Set `Focus='simulation'` for sim/control use |
| 5 | Not detrending data with offsets | DC gain wrong, poor overall fit | `detrend(data)` or use offsets |
| 6 | Using ARX in closed loop | Biased plant estimate | Use `iv4`, BJ, or indirect method |
| 7 | Wrong delay assumed | Catastrophic — no amount of order helps | Estimate delay first, try +/-1 |
| 8 | Over-parameterizing | Great training fit, poor generalization | Regularize or reduce order |
| 9 | Ignoring uncertainty | False precision in model | Always check `showConfidence` on Bode |
| 10 | Assuming ICs from training apply to new data | Poor validation fit | Re-estimate ICs for each new dataset |
| 11 | Not passing `'Ts',Value` as name-value pair (Value>0) to ssest, tfest for DT model | Gets CT model instead | `ssest(data, n, 'Ts', data.Ts, opt)` |
| 12 | Using wrong initial conditions for simulation | Bad fit to validation data | use `findstates' or `data2state' to determine the initial conditions that maximize the fit to the validation data |
|13| Forget to scale data | Ill-conditioned identification problem leading to bad results | Ensure your inputs and outputs, and time units are scaled appropriately, especially when using numerical optimization algorithms.|

----

Copyright 2026 The MathWorks, Inc.

----
