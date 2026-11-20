---
name: matlab-specify-ssm
description: >-
  Convert state-space equations, given as an image or as text, into a MATLAB
  Econometrics Toolbox ssm object. Use only when the request contains the model
  equations and asks to convert, implement, or create ssm code. Do not use when
  no equations are given; for estimating, filtering, smoothing, forecasting, or
  diagnosing an existing or estimated ssm model; for explaining equations
  without code; or for Control System ss or System Identification idss models.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

Convert structural state-space equations into a MATLAB Econometrics Toolbox `ssm` object. Use the `ssm` class only; do not use other state-space classes. "Diffuse" always means `ssm` StateType 2.

## When to Use
- The user gives state-space equations (image, PDF, LaTeX, or plain text) and asks to convert, implement, or create an `ssm` object.
- The model is linear Gaussian, or can be made linear in the states by an exact transformation of the data (Step 1c).

## When NOT to Use
- No equations are given (e.g. "I want to build an ssm model").
- The user asks to estimate, filter, smooth, forecast, or run diagnostics on an existing model.
- The user only wants the equations explained, not converted to code.
- Control System Toolbox `ss` models.
- Identifying a state-space model (`idss`, `ssest`, `n4sid`) from input-output or measurement data — use `matlab-identify-linear-system`.
- Hidden Markov models (`hmmtrain`, `hmmviterbi`).

Images and PDFs may be typeset or handwritten; text may be LaTeX, semi-formal or plain math.

## Choose the Output Form

Use a **NaN-form script** whenever it can express the model (it can be pasted into the Command Window; a parameter-mapping function must first be saved in a file). Otherwise use a **parameter-mapping function** (ParamMap), which can express any model.

NaN-form applies when every unknown scalar parameter appears in exactly one entry of A, B, C, D, Mean0, Cov0 and equals that entry (a NaN means "estimate this entry"). A variance or a covariance matrix still qualifies through Rule 1 or Rule 7.

| Model feature | Form |
|---|---|
| Variance $\sigma^2$ of a disturbance that no other entry uses | NaN-form; the NaN estimates $\sigma$ (Rule 1) |
| Intercept | NaN-form; NaN on the constant-1 state (Rule 8) |
| Regression term $Z_t\beta$, and the cell array `A{t}` or `C{t}` has no unknown entry | NaN-form; $\beta$ as diffuse states (Rule 8) |
| Matrix of known time-varying data, e.g. TVP regression | NaN-form with a cell array (Rule 4) |
| Confounded initial state fixed at 0 (Rule 9), or a request that `estimate` fit all unknowns | Neither forces ParamMap |
| A parameter in two or more entries (sharing), whatever kind of parameter it is: an intercept shared across equations; one AR coefficient for several series; $\sigma$ in an ARMA MA term, where $B = [\sigma;\ \theta_1\sigma]$ puts $\sigma$ in two rows of B | ParamMap |
| An entry that is a function of parameters or a product of two parameters, e.g. a signal-to-noise ratio $q = \sigma_\xi^2/\sigma_\varepsilon^2$ used as a parameter, or $\theta_1\sigma$ | ParamMap |
| An unknown entry inside a cell array `A{t}` or `C{t}`: `ssm` counts each NaN in each cell as a separate parameter (T periods give T parameters) | ParamMap (Rule 8) |

**Reparameterize only noise scales:** a variance to a standard deviation (Rule 1), and a covariance matrix to its lower Cholesky factor (Rule 7). Writing a standard deviation as `exp(params(i))` is offered only in the exp() tip; do not use it in the code unless the user asks. Do not reparameterize any other parameter. In particular, never merge two user parameters into one free entry (e.g., estimating $\theta_1\sigma$ instead of $\theta_1$ in an MA term). When a parameter enters a matrix entry multiplied by another parameter, or through a function, use a parameter-mapping function so that every user parameter is estimated directly. Carrying regression coefficients as states (Rule 8) is not a reparameterization.

When you use ParamMap, tell the user why in one sentence.

---

## SSM Specification Workflow

### Step 1: Parse the Structural Equations

Identify the observation equations ($y_t = C x_t + D e_t$), the state equations ($x_t = A x_{t-1} + B u_t$, or $x_{t+1} = A x_t + B u_t$), and which noise variances and covariances are known or unknown.

- **Lag test (key rule):** A variable that appears on both sides of an equation with a time offset ($t+1$ on the LHS and $t$ on the RHS, or $t$ and $t-1$) is a state, and its equation is a state equation. Equations whose LHS variable never appears lagged are observation equations. A symbol without a $t$ subscript is a coefficient. This test overrides naming conventions.
- **Noise terms** ($\varepsilon$, $\xi$, $\zeta$, $\eta$, ...) map to columns of B or D, one column per independent disturbance. B and D need not be square: equations without noise, or equations sharing a disturbance, make them tall (Rule 5).
- **Higher-order lags and MA terms:** rewrite in companion (first-order) form by augmenting the state vector. For ARMA, see the MA-term row in Choose the Output Form.
- **Timing:** `ssm` uses $x_t = A x_{t-1} + B u_t$. A model written as $x_{t+1} = A x_t + B u_t$ gives the same filter, likelihood and estimates; only smoothed disturbances shift by one period, so add the timing tip (Step 7) when the user will smooth disturbances.

Display the parsed equations in LaTeX so the user can check the interpretation, then continue without waiting for confirmation.

### Step 1b: Clarify Ambiguities (ask only if the matrices cannot be built)

**Observed vs. state variables unclear** (e.g. the model uses $x$, $f$, $z$, $p$, $c$ rather than $y$). First apply the lag test, then these conventions; ask only if both leave it ambiguous:
- $y$, $y_t$, $y_{i,t}$ → observed.
- $\alpha_t$ (Durbin & Koopman), $\mu_t$ (trend), $f_t$ (factor) → state.
- $Z_t$ or $X_t$ multiplying a variable or coefficient ($Z_t\alpha_t$, $Z_t\beta$, $X_t\beta$) → regressor data or loading, not a state (despite MATLAB naming states $x_t$).
- A Greek-letter variable with no transition equation → noise.

Question: "Which variables are observed in your data? (e.g., `p, c` or `y1, y2`)"

**Vector or matrix form with unknown dimensions** (bold symbols, matrix coefficients such as $\Lambda$, $\Phi$, $\Sigma$, $y_{i,t}$ for $i = 1,\ldots,n$ with $n$ unspecified, or $\in \mathbb{R}^n$ with symbolic $n$). If the code can take its dimensions from the data (`n = size(Y, 2)`, `p = size(Z, 2)`), do so without asking. Ask only when the matrices cannot be built at all (e.g. the number of factors is unspecified): "The equations are in vector/matrix form. What are the concrete dimensions? (e.g., n = 5 observed series, r = 2 factors)"

### Step 1c: Check for Nonlinearity

`ssm` requires linear Gaussian equations. If an equation is nonlinear in the states, check whether an exact transformation of the data (log, log-squared, ...) makes it linear in the states. If one exists, always use it: transform the data, rewrite the observation equation, and build the `ssm` from the result. A transformed disturbance that is not Gaussian is approximated by a Gaussian with the same mean and variance, so `estimate` gives quasi-ML estimates. For stochastic volatility, or any other log-squared transformation, read [references/linearization.md](references/linearization.md) for the transformed model and its matrices.

**No exact linearizing transformation** (e.g. the model can be linearized only by a Taylor expansion around the states): do not generate `ssm` code. Reply in 2-3 sentences: name the nonlinear term; say that `ssm` requires linear Gaussian equations, so this model cannot be written as an `ssm` object; and note that the Econometrics Toolbox's nonlinear state-space class (`bnlssm`, R2023b or later) handles such models. This is the only place another class may be named.

For standard models (local level, local linear trend, basic structural, ARMA, factor model), [references/standard-models.md](references/standard-models.md) lists the state vector and matrices.

---

### Step 2: Define the State Vector

List the states in a fixed order, $x_t = [x_{1,t}; \ldots; x_{m,t}]$, and document the order as a code comment. Add one shared constant-1 state (StateType 1) where Rule 8 requires it.

### Step 3: Construct System Matrices

$$x_{t} = A \, x_{t-1} + B \, u_{t}, \quad u_t \sim N(0, I) \qquad y_{t} = C \, x_{t} + D \, e_{t}, \quad e_t \sim N(0, I)$$

A is m×m, B is m×k, C is n×m, D is n×h (m states, n observed series, k state disturbances, h observation disturbances).

1. **B and D contain standard deviations, not variances.** For a std dev $\sigma$, put NaN in the B or D entry. For a variance that no other entry uses (e.g. $\varepsilon_t \sim N(0, \sigma_\varepsilon^2)$), still use NaN: it estimates the std dev, and by MLE invariance its square is the MLE of $\sigma^2$. Add a comment such as `% sigma_eps^2 = D(1,1)^2`.
   - Enter a known variance as its numeric square root (e.g. `sqrt(pi^2/2)`).
   - In ParamMap form, write noise loadings as std devs: `B(i,j) = params(k)`. Use `exp(params(k))` only if the user asks for it; otherwise mention it in the exp() tip. Never `sqrt(params(k))`: it is complex when the optimizer tries a negative value.
2. **Parameter order:** `ssm` maps the parameter vector to NaN entries column by column (column-major). Document this order.
3. **Known coefficients** are finite numbers (e.g. a loading fixed at 1). A, B, C, D must not contain Inf. Do not use Inf in Cov0 either; Step 4 says what Cov0 holds. Put **missing observations** in Y as NaN; never use zero placeholders with `D{t} = Inf` (a textbook device that `ssm` rejects: "must be a finite numeric array").
4. **Time-varying matrices:** pass a matrix that changes over time as a cell array `{C_1, ..., C_T}`, one matrix per period. Cell arrays and numeric matrices can be mixed in one call, e.g. `ssm(A, B, C_cells, D)`. Cells keep the same size unless the state or observation dimension changes over time; then A need not be square at a change, so prefer fixed dimensions. Whether to use NaN-form: Choose the Output Form.
5. **No noise → empty matrix, never a zero column:** with no observation noise set `D = []`; with no state noise set `B = []`. `ssm` expands these to `zeros(n, 0)` / `zeros(m, 0)`, so the disturbance does not exist; `D = 0` or `B = zeros(m, 1)` creates a zero-impact disturbance that slows filtering, smoothing and simulation. Never include an all-zero column in B or D.
6. **Multiple observed series:** C and D have one row per observed series.
7. **Correlated noise:** for a noise covariance $\Omega$ (e.g. a VAR $x_t = A x_{t-1} + v_t$, $v_t \sim N(0, \Omega)$), set B to the lower-triangular Cholesky factor, so $\Omega = BB'$, and estimate its $m(m+1)/2$ free entries. This keeps $\Omega$ positive semidefinite; use `chol(Omega, 'lower')`, never `chol(Omega)` (upper-triangular, so $BB' \neq \Omega$). Add the comment `% Omega = B * B'`. The same applies to D for correlated observation noise.
8. **Intercepts and regression coefficients:** if ParamMap is required for another reason, use the fewest states. All intercepts share **one constant-1 state** (StateType 1), except an observation intercept in ParamMap form, which goes into DeflateY. An intercept multiplies the constant 1, so it is one NaN entry; $Z_t\beta$ multiplies time-varying data, so in NaN-form $\beta$ must become states.

   | | State equation | Observation equation |
   |---|---|---|
   | **Intercept c, NaN-form** | c = NaN in A on the constant-1 state: $x_t = c + \phi x_{t-1} + u_t$ → states $[x;\,1]$, A = [NaN NaN; 0 1], B = [NaN; 0], StateType [0; 1]. The default initialization then starts x at $c/(1-\phi)$ exactly | c = NaN in C, e.g. C = [1 NaN]. A mean $\mu$ in $y_t = \mu + \phi(y_{t-1} - \mu) + \varepsilon_t$ is $y_t = \mu + x_t$, $x_t = \phi x_{t-1} + \varepsilon_t$ |
   | **Intercept c, ParamMap** | same as NaN-form | `DeflateY = y - c` (with regressors, a column of ones in Z); no extra state |
   | **Regression $\beta$, NaN-form** | $\beta$ as diffuse static states (StateType 2), cell `A{t} = [A Z_t; 0 I]`, zero rows in B; x is StateType 2 too (its initial mean depends on the unknown past Z path) | $\beta$ as diffuse static states, cell `C{t} = [C Z_t]` |
   | **Regression $\beta$, ParamMap** | one constant-1 state, `A{t} = [A Z_t*beta; 0 1]` (Z passed as in the DeflateY template), B = [B; 0] (one extra state however many regressors) | `DeflateY = y - Z*beta` (8th output, Step 5); no extra state |

   - With $\beta$ as diffuse states, $\beta$ is still estimated: `estimate` fits the other parameters, and the filtered or smoothed states at the last period give the $\beta$ estimates (GLS given the fitted variances). So a request that `estimate` fit all unknowns, $\beta$ included, keeps NaN-form. Use DeflateY only when ParamMap is required for another reason.
   - A known offset (e.g. the SV constant −1.2704) is an intercept with a known value.
   - Do not move the regression into `estimate` name-value arguments (`'Predictors'`, `'Beta0'`): it works, but it leaves the regression outside the `ssm` object.
9. **Identification:**
   - **Never drop a parameter the user wrote.** An intercept or drift can be confounded with the initial value of a diffuse (random-walk) state: an observation intercept c with a random-walk level $\mu_t$ when every observation equation that loads on $\mu_t$ also carries an intercept (only $c + \mu_0$ is identified), or a constant d in the level equation of a local linear trend (confounded with $\nu_0$). Keep the parameter and fix the confounded initial state(s) at 0 **in the code**, e.g. `'Mean0', [0; 0; 1], 'Cov0', zeros(3), 'StateType', [2; 2; 1]`; explain why in one sentence. In NaN-form pass Mean0 and Cov0 as `ssm` name-value arguments; in ParamMap form return them as outputs.
   - Keep the state diffuse when the constant is identified: a constant in the slope equation; a drift without an observation intercept; or another series pins down $\mu_0$ (e.g. $y_{1t} = \mu_t + e_{1t}$, $y_{2t} = a + b\mu_t + e_{2t}$).
   - **Overparameterized models:** write the model as given and add a one-line note.

### Step 4: Handle Initialization

Classify every state:
- **0 = Stationary:** initialized from its stationary distribution. Use it for an AR(1) or VAR(1) state with unknown coefficients (assume stationarity), unless regressors enter its state equation (then StateType 2, Rule 8).
- **1 = Constant one:** a static state ($x_t = x_{t-1}$) with **no noise at all**, fixed at 1. Carries intercepts and known offsets (Rule 8).
- **2 = Diffuse:** a unit-root, random-walk, or regression-coefficient state, initialized from N(0, 1e7). A state driven by noise with A = 1 (random walk) is StateType 2, not 1: A = 1 does not mean StateType 1.

When uncertain, use 2: diffuse initialization is always safe (it costs a few initial observations) except for a confounded state (Rule 9).

**Always write StateType explicitly:** in NaN-form as `'StateType'` in the `ssm` call, in ParamMap form as the `StateType` output. Without it, `ssm` assigns state types by default rules that can misclassify states.

With StateType 2, leave Cov0 empty: when Cov0 is given, `ssm` ignores StateType and uses Cov0 as given. The only exception is fixing a confounded initial state at 0 (Rule 9); then give each state that stays diffuse 1e7 on the diagonal of Cov0, the value StateType 2 uses.

### Step 5: Generate MATLAB Code

#### NaN-form script

```matlab
% TEMPLATE — not executable
% State-Space Model: [Model Name]
% State vector: x_t = [state1_t; state2_t; ...]  (m = ?)
% Observation:   y_t = [obs1_t; obs2_t; ...]     (n = ?)

A = [...];
B = [...];
C = [...];
D = [...];
StateType = [...];  % 0=stationary, 1=constant, 2=diffuse

mdl = ssm(A, B, C, D, 'StateType', StateType);

% Parameter order (column-major NaN scan):
%   params(1) -> B(row, col) = sigma_...

% Estimation:
% params0 = [...];
% estMdl = estimate(mdl, y, params0);
```

#### Parameter-mapping function

Always a named function with 7 outputs (8 with DeflateY). Never `ssm(@(p) deal(...))`.

```matlab
% TEMPLATE — not executable
function [A, B, C, D, Mean0, Cov0, StateType] = ssmParamsMap(params)
% State-Space Model: [Model Name]
% State vector: x_t = [state1_t; state2_t; ...]  (m = ?)
% params(1) = sigma_...

A = [...];
B = zeros(m, k);
B(...) = params(1);
C = [...];
D = zeros(n, h);
D(...) = params(...);
Mean0 = [];
Cov0 = [];
StateType = [...];  % 0=stationary, 1=constant, 2=diffuse
end
```

Companion script:
```matlab
mdl = ssm(@ssmParamsMap);
% params0 = [...];
% estMdl = estimate(mdl, y, params0);
```

For regression or an intercept through DeflateY, pass the data through an anonymous function that calls the named function; y and Z are captured when `mdl` is created. DeflateY must be the **8th** output; in any other position `ssm` misreads it and errors with a misleading "Length of the initial mean vector" message:
```matlab
% TEMPLATE — not executable
function [A, B, C, D, Mean0, Cov0, StateType, DeflateY] = ssmParamsMap(params, y, Z)
% ... A, B, C, D, Mean0, Cov0, StateType as above ...
p = size(Z, 2);
beta = params(end-p+1:end);
DeflateY = y - Z * beta(:);
end
```
```matlab
mdl = ssm(@(params) ssmParamsMap(params, y, Z));
```

### Step 6: Validation Checks

Before finalizing, check:
- [ ] Dimensions (Step 3) and the column-major parameter list (Rule 2).
- [ ] NaN count equals the free-parameter count; no NaN in a fixed entry.
- [ ] Observation equation uses $x_t$; state equation takes $x_{t-1}$ to $x_t$.
- [ ] Rules 1, 5 and 9, the output form, and StateType (Step 4).
- [ ] Each constant-1 state has a zero B row and A diagonal entry 1.

### Step 7: Tips and Summary Table

After the commented `% estMdl = estimate(...)` line, add as MATLAB comments each tip that applies; the text of each tip is in [references/tips.md](references/tips.md):
- **Univariate:** n = 1, or n > 1 with D*D' diagonal (including `D = []`). Omit it when D*D' is not diagonal.
- **Parameter bounds:** a parameter has a domain restriction, e.g. an AR coefficient in (−1, 1) for a stationary state, a frequency in (0, π), a std dev > 0. Bounds make `estimate` use `fmincon` instead of `fminunc`.
- **exp():** ParamMap form with std dev parameters.
- **Timing:** the model is written as $x_{t+1} = A x_t + B u_t$ and the user will smooth disturbances (Step 1).

End the output with this markdown table:

| Property | Value |
|----------|-------|
| Model | [name] |
| States (m) | [number] |
| Observations (n) | [number] |
| Free parameters | [number] |
| StateType | [e.g., all diffuse / mixed / all stationary] |
| Output form | NaN-form script / parameter-mapping function |

---

## Output Rules

- Display the complete code in the conversation, in this order: parsed equations (Step 1) → code, with the `estimate` call as a commented line → tips → summary table. Write nothing after the table.
- Do not run MATLAB. The code is displayed, not executed, so it must work exactly as displayed.
- Do not write files, for any input type (clipboard image, image file, PDF, or text). Save only on explicit request (e.g. "save it as a .m file"), to the location the user specifies.
- For ParamMap output, tell the user to save the function in a file named after the function (e.g. "Save this function as `ssmParamsMap.m` on your MATLAB path"), or as a local function at the end of the companion script, since `ssm(@fcn)` needs the function defined in a file.

----
Copyright 2026 The MathWorks, Inc.
----
