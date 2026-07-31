# Validation and Diagnostics

## Uncertainty Analysis

```matlab
% Bode with standard deviation (numeric)
w = logspace(-2, 3, 200);
[mag, phase, wout, sdmag, sdphase] = bode(model, w);
% sdmag = 1-sigma std dev of magnitude; sdphase = 1-sigma std dev of phase

% Step response with uncertainty
[y, t, ~, ysd] = step(model);

% Pole/zero with uncertainty regions
h = iopzplot(model);
showConfidence(h, 3);  % 3-sigma regions

% Nyquist with uncertainty
h = nyquistplot(model);
showConfidence(h, 3);
```

| Observation | Meaning | Action |
|-------------|---------|--------|
| Tight bounds everywhere | Well-identified model | Proceed with confidence |
| Wide bounds at high freq | High-freq dynamics uncertain (normal) | OK if control bandwidth is below |
| Wide bounds at all freq | Model not well identified | More data, reduce order, or add regularization |
| Pole near stability boundary with large uncertainty | Stability unreliable | Enforce stability or get more data |
| Zero uncertainty spans RHP/LHP | Non-minimum phase uncertain | Critical for control — need more data |

## Stability Assessment

```matlab
p = pole(model);
if model.Ts == 0
    is_stable = all(real(p) < 0);
    margin_ct = -max(real(p));
else
    is_stable = all(abs(p) < 1);
    margin_dt = 1 - max(abs(p));
end

% Gain and phase margins
[Gm, Pm, Wcg, Wcp] = margin(model);
fprintf('Gain margin: %.1f dB at %.2f rad/s\n', 20*log10(Gm), Wcg);
fprintf('Phase margin: %.1f deg at %.2f rad/s\n', Pm, Wcp);
```

**Stability rules:**
* If `EnforceStability=true` was used, stability is guaranteed by construction
* Poles very close to boundary (margin < 0.01) may be unstable in reality
* For control design: require margin > 2-sigma uncertainty
* Identified unstable model from open-loop data usually means: system IS unstable, or estimation went wrong

## Model Quality Metrics

```matlab
sys.Report.Fit.FitPercent     % fit on estimation data
sys.Report.Fit.FPE            % Final Prediction Error
sys.Report.Fit.AIC            % Akaike Information Criterion
sys.Report.Fit.AICc           % corrected AIC (for small samples)
sys.Report.Fit.BIC            % Bayesian Information Criterion
sys.Report.Fit.nAIC           % normalized AIC (comparable across datasets)
sys.Report.Termination        % convergence info

% Compare models
aic(sys1, sys2, 'BIC')  % compare multiple models
```

| Criterion | When to use |
|-----------|-------------|
| FPE | Quick penalty for overparameterization |
| AIC | Standard; compare models on same data |
| AICc | Small samples (N/d < 40) |
| BIC | Stronger penalty; use for large N |
| nAIC | Normalized; comparable across different N |

**Rule**: Use AICc for small datasets, BIC for large datasets. When models have similar AIC/BIC (within 2), prefer the simpler model.

## Diagnostic Checklist (if fit is insufficient)

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| High train fit, low validation fit | Overfitting | Reduce order or add regularization |
| Good prediction, bad simulation | Wrong Focus | Re-estimate with `Focus='simulation'` |
| Unstable model | Unconstrained | Set `EnforceStability=true` |
| Poor fit despite high order | Wrong delay | Re-run `delayest`, try nk +/- 1 |
| Oscillatory residuals | Missing dynamics | Increase order or add integrator |
| DC gain wrong | Offset in data | Detrend or use `InputOffset`/`OutputOffset` |
| Slow convergence | Bad initialization | Use n4sid result or AAA init |
| Stuck in local minimum | Single init method | Try `InitializeMethod='all'` or `'AAA'` |
| NaN/Inf in estimation | Numerical ill-conditioning | Add regularization, reduce order |
| Different runs give different models | Non-convex landscape | Overparameterized or insufficient data |

## Initial Conditions — Correct Usage

**Common misconception:** ICs are a permanent model property identified during training and automatically applied during any simulation. **This is wrong.**

**Reality:** ICs estimated during training apply ONLY to the training data's starting state. When simulating with different data, you must determine new ICs appropriate for that data. The model is stateless — ICs describe the system's state at the start of a PARTICULAR simulation.

### Methods for Specifying ICs (ranked by preference)

| Method | When to use | Code |
|--------|-------------|------|
| **Prior knowledge** | Known physical state | `opt.InitialCondition = x0_known` |
| **`findstates`** | Estimate ICs to match beginning of a dataset | `x0 = findstates(model, data)` |
| **`data2state`** | Map past I/O data to current state (Kalman filter) | `x0 = data2state(model, pastData)` |
| **`compare`/`sim` auto** | Let toolbox estimate ICs during comparison | `compare(data, model)` handles it |
| **Zero** | System starts at rest (long data, steady-state start) | `opt.InitialCondition = zeros(n,1)` |

```matlab
% findstates — optimize ICs to match data
x0 = findstates(model, validationData);
opt = simOptions('InitialCondition', x0);
y_sim = sim(model, validationData.u, opt);

% data2state — map past I/O history to state (no optimization)
pastData = data(1:100);
x0 = data2state(model, pastData);
opt = simOptions('InitialCondition', x0);
y_sim = sim(model, data(101:end).u, opt);
```

### When ICs Matter Most

* Short datasets (N < 50): transient dominates fit score
* Unstable or lightly damped systems: wrong ICs cause divergence
* Validation with different data: MUST re-estimate ICs

### When ICs Don't Matter

* Very long datasets (N > 1000) with stable system: transient decays quickly
* Prediction mode (1-step ahead): ICs only affect first few steps

### Simulink Deployment with Initial Conditions

When exporting an identified model to Simulink (via the **Idmodel** block), initial condition mismatch is the #1 cause of poor simulation results — especially if the training data had significant transients.

**Problem:** User identifies `sys = tfest(data, np, nz)`, places it in an Idmodel block, simulates with the same input signal as training data, and gets poor fit because the Idmodel block starts from zero state while the original data had non-zero initial conditions.

**Fix (two approaches):**

```matlab
% Approach 1: Use the initialCondition object from estimation directly
% (works when simulating with the SAME data used for training)
sys = tfest(ze, np, nz);
ic = sys.Report.Parameters.X0;  % initial states from estimation
% In Simulink: set Idmodel block's "Initial condition" parameter to ic

% Approach 2: Convert to idss and use findstates (GENERAL CASE)
% Use this when simulating with DIFFERENT (validation/test) data
sys_ss = idss(sys);  % convert idtf -> idss for state-vector access
x0 = findstates(sys_ss, validationData);  % optimize ICs for new data
% In Simulink: use sys_ss in the Idmodel block with x0 as initial state

% Approach 3: data2state for online/streaming scenarios
x0 = data2state(sys_ss, pastData);  % Kalman filter estimate of state
```

**Rule:** Always use Approach 2 (convert to `idss` + `findstates`) when the simulation input differs from training input. This is the robust general-purpose method that ensures the model's simulated output matches the beginning of any new dataset.

----

Copyright 2026 The MathWorks, Inc.

----
