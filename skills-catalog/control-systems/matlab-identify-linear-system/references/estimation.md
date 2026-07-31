# Estimation

## 6.1 Critical Options

```matlab
% Focus — available on ssestOptions, n4sidOptions, arxOptions, etc. (NOT tfestOptions)
opt.Focus = 'simulation';   % USE THIS for simulation/control (minimizes sim error)
opt.Focus = 'prediction';   % USE THIS for forecasting (minimizes 1-step error)
% Default is 'prediction'. CHANGE IT if you will simulate.
% NOTE: tfest does NOT support Focus. For time-domain data, tfest always produces
% a stable model. Use WeightingFilter for frequency emphasis with tfest.

% Initial conditions
opt.InitialState = 'estimate';   % short data or transients present
opt.InitialState = 'zero';       % long data, steady-state start
opt.InitialState = 'auto';       % toolbox decides (default)

% Stability
opt.EnforceStability = true;   % force stable model (required for simulation)

% Regularization (ARX/FIR — prevents overfitting)
[Lambda, R] = arxRegul(data, orders, arxRegulOptions('RegularizationKernel', 'TC'));
opt.Regularization.Lambda = Lambda;
opt.Regularization.R = R;

% OutputWeight (MIMO systems)
opt.OutputWeight = 'noise';  % inverse noise variance weighting (recommended for MIMO)

% WeightingFilter — custom frequency emphasis
opt.WeightingFilter = {wnum, wden};  % TF filter applied to prediction error

% ErrorThreshold — robust estimation against outliers
opt.Advanced.ErrorThreshold = 1.6;  % errors > threshold treated linearly (not quadratic)

% StabilityThreshold — shift the stability boundary
opt.Advanced.StabilityThreshold.z = 0.99;   % DT: poles inside radius 0.99
opt.Advanced.StabilityThreshold.s = -0.01;  % CT: poles with Re < -0.01
```

## 6.2 Initialization Methods

### For ssest

| Method | Algorithm | When to use | I/O support |
|--------|-----------|-------------|-------------|
| `'auto'` | Toolbox picks best | Default — usually fine | Any |
| `'n4sid'` | Subspace (time-domain) | Standard time-domain data | Any |
| `'lsrf'` | fitRational (vector fitting) | Frequency-domain data or FRD | SISO, SIMO, MISO only |
| `'AAA'` | fitAAA_OE (rational AAA) | Frequency-domain; high modal density; often faster/more robust | **SISO, SIMO, MISO, MIMO** |

**LSRF vs AAA for frequency-domain data:**
* `'lsrf'` is also available via `tfest` (as the default FD method). Cannot handle full MIMO.
* `'AAA'` is **only** reachable through `ssest` (`ssestOptions('InitializeMethod','AAA')`). It is the only non-iterative method that handles full MIMO FRD data.
* For MIMO systems with high modal density (many closely-spaced resonances), **AAA is the preferred path** — it avoids the local-minima traps that plague iterative methods on dense modal spectra.

### For tfest

| Method | Algorithm | When to use |
|--------|-----------|-------------|
| `'all'` | Try all methods, pick best | Best results but slower |
| `'svf'` | State-variable filter | General time-domain |
| `'iv'` | Instrumental variables | Noisy time-domain data |
| `'n4sid'` | Subspace | Alternative init |
| `'gpmf'` | Generalized Poisson moment | Continuous-time from DT data |

## 6.3 Why ssest Outperforms n4sid

`ssest` uses `n4sid` (subspace) as initialization, then refines via block-coordinate descent (BCD) on the B, C, D matrices while holding A fixed. This iterative refinement:

* Outperforms standalone n4sid in ~74% of cases
* Is faster than full PEM because it solves structured sub-problems
* For SISO: the B,D iteration is locally optimal; for MIMO: alternates between C,D blocks

**Practical implication**: Always prefer `ssest` over standalone `n4sid`. Use `n4sid` only as a diagnostic (order selection via singular values) or when `ssest` fails to converge.

## 6.4 Frequency-Domain Estimation Path

**Key insight:** `fft(time-domain data)` is a lossless transformation. You can fit rational models directly in the frequency domain for fast, non-iterative initialization or even a final model.

**When to prefer:**
* Periodic input signals (multisine, swept sine)
* Very large datasets (N > 100k) — 10-100x faster than iterative time-domain PEM
* Frequency-domain data already available (idfrd objects)
* MIMO systems — AAA handles MIMO directly

```matlab
% State-space from frequency data using AAA
opt = ssestOptions('InitializeMethod', 'AAA', 'Focus', 'simulation', ...
    InteractiveOrderSelection=false);
model = ssest(fft(ze), n, opt);

% Transfer function from empirical frequency response
G_spa = spa(ze);
model = tfest(G_spa, np, nz);

% From measured idfrd
G_meas = idfrd(response, freqs, Ts);
model = tfest(G_meas, np, nz);
```

**Block-AAA Algorithm** (`InitializeMethod='AAA'`):
* Non-iterative (no initial guess needed — avoids local minima entirely)
* Handles MIMO natively (block extension of scalar AAA)
* Much faster than general nonlinear optimization for initialization
* Particularly effective for systems with well-separated resonances or high modal density
* Supports order search: `ssest(Gfrd, 1:maxOrder, opt)` with AAA — fast automatic order determination

**Speed optimization for FD path** (AAA or LSRF):

When using AAA/LSRF initialization on frequency-domain data, the iterative refinement after initialization is often unnecessary — the non-iterative result is already excellent. For maximum speed:

```matlab
opt = ssestOptions('InitializeMethod', 'AAA', 'Focus', 'simulation', ...
    InteractiveOrderSelection=false, EstimateCovariance=false);
opt.SearchOptions.MaxIterations = 0;  % skip iterative refinement entirely
model = ssest(Gfrd, n, opt);

% Order search with AAA (fast — no iterations per order)
model = ssest(Gfrd, 1:maxOrder, opt);
```

Setting `MaxIterations=0` + `EstimateCovariance=false` gives the AAA/LSRF solution directly without iterative PEM refinement. This is typically 5–50x faster with minimal quality loss on clean FRD data. Use full iterations only when noise is high or you need uncertainty estimates.

## 6.5 Estimation Commands

```matlab
% State-space (recommended default)
opt = ssestOptions('Focus', 'simulation', 'EnforceStability', true, ...
    'InitialState', 'estimate', InteractiveOrderSelection=false);
model = ssest(ze, n, opt);

% Transfer function
opt = tfestOptions('InitializeMethod', 'all');
model = tfest(ze, np, nz, delay, opt);

% Process model
model = procest(ze, bestStruct);

% ARX (with regularization for high order)
[L, R] = arxRegul(ze, nn, arxRegulOptions('RegularizationKernel', 'TC'));
opt = arxOptions;
opt.Regularization.Lambda = L;
opt.Regularization.R = R;
model = arx(ze, nn, opt);

% Output-Error
model = oe(ze, [nb nf nk]);

% Box-Jenkins
model = bj(ze, [nb nc nd nf nk]);

% Instrumental Variables (robust to colored noise)
model = iv4(data, [na nb nk]);
```

## 6.6 Regularized ARX to State-Space (ssregest)

For complex systems where standard order determination fails:

```matlab
% Full automated workflow: high-order regularized ARX -> reduced SS
opt = ssregestOptions('ARXOrder', [5 60 0]);
model = ssregest(data, n, 'Feedthrough', true, opt);
```

**Regularization kernels** (for `arxRegulOptions`):

| Kernel | Description | Best for |
|--------|-------------|----------|
| `'TC'` | Tuned/Correlated | General purpose (default) |
| `'SE'` | Squared Exponential | Very smooth impulse responses |
| `'SS'` | Stable Spline | Systems with fast decay |
| `'HF'` | High Frequency | When FIR response oscillates |
| `'DI'` | Diagonal | Simple ridge (same as L2) |
| `'DC'` | Diagonal/Correlated | Compromise between DI and TC |

## 6.7 Structured Estimation with Parameter Bounds

When physical knowledge constrains parameter ranges:

```matlab
% Transfer function with bounded coefficients
sys = idtf([1], [1 1 1]);
sys.Structure.Denominator.Minimum = [1 0.01 0.01];
sys.Structure.Denominator.Maximum = [1 100  10000];
sys.Structure.Numerator.Free = [true];
model = tfest(data, sys);

% State-space with fixed elements
sys = idss(A0, B0, C0, D0);
sys.Structure.A.Free = [1 1; 0 1];  % fix A(2,1)=0
sys.Structure.D.Free = false;       % fix D entirely
model = ssest(data, sys);
```

## 6.8 Multi-Model Strategy

For best results, estimate 2-3 model types and compare:

```matlab
m1 = ssest(ze, n, ssestOptions('Focus', 'simulation', InteractiveOrderSelection=false));
m2 = ssest(ze, n, ssestOptions('InitializeMethod', 'AAA', 'Focus', 'simulation', ...
    InteractiveOrderSelection=false));
m3 = tfest(ze, np, nz, delay, tfestOptions('InitializeMethod', 'all'));
m4 = arx(ze, nn);
[~, fits] = compare(zv, m1, m2, m3, m4);
% NOTE: fits is a CELL ARRAY for multi-model. Extract as: cell2mat(fits)
```

----

Copyright 2026 The MathWorks, Inc.

----
