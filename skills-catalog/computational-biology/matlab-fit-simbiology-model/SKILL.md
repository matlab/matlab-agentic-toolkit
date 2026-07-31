---
name: matlab-fit-simbiology-model
description: "Fit SimBiology model parameters to data — fitproblem, population NLME, virtual patients, and NCA. Use when asked to fit, estimate, calibrate, or compute PK metrics."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Fit SimBiology Models

Estimate parameters from data using `fitproblem`, fit population models
with NLME, generate virtual patients, and compute NCA metrics.

## When to Use

- "fit", "estimate", "calibrate" model parameters
- Parameter estimation from experimental/observed data
- Population PK/PD, NLME, mixed effects, inter-individual variability
- Virtual patients, virtual cohorts
- NCA, AUC, Cmax, Tmax, half-life, clearance
- Keywords: "fit", "estimate", "calibrate", "population", "NCA", "AUC"

## When NOT to Use

- Model construction or diagram (use `matlab-build-simbiology-model`)
- Simulation without fitting (use `matlab-simulate-simbiology-model`)
- Sensitivity analysis (use `matlab-simulate-simbiology-model`)

## Must-Follow Rules

### 1. Use `fitproblem` for parameter estimation

Always use `fitproblem` instead of calling `sbiofit` or `sbiofitmixed`
directly. `fitproblem` provides a unified, declarative interface:
```matlab
prob = fitproblem;
prob.Model = model;
prob.Data = data;
prob.ResponseMap = "Species = DataColumn";
prob.Estimated = estimatedInfo({'param'}, 'Bounds', [lo hi]);
results = fit(prob);
```
Do NOT call `sbiofit(model, data, ...)` or `sbiofitmixed(model, data, ...)`
directly — their positional argument signatures are error-prone.

### 2. Fitting requires `groupedData`, NOT a plain table

Always wrap data:
```matlab
data = groupedData(table(...));
data.Properties.IndependentVariableName = 'Time';
```

### 3. `ResponseMap` maps model outputs to data columns

Format is always `"ModelOutput = DataColumnName"`:

```matlab
% Single compartment — use species name on the left
prob.ResponseMap = "Drug = DrugConc";

% Multi-compartment — use qualified name to disambiguate
prob.ResponseMap = "Central.Drug = DrugConc";

% When species name matches data column name, still use the = format
prob.ResponseMap = "Drug = Drug";
```

Use the unqualified species name unless the same species name exists
in multiple compartments (then qualify with `Compartment.Species`).

### 4. Always set bounds

Prevent non-physical values (negative rates, etc.):
```matlab
estimParams = estimatedInfo({'ke','ka'}, ...
    'InitialValue', [0.2, 1.0], ...
    'Bounds', [0.01 1; 0.1 5]);
```

### 5. Use log transform for rate constants

Parameters spanning orders of magnitude (clearances, rate constants)
benefit from log-transform estimation. Set `.Transform` after creation:
```matlab
ei = estimatedInfo({'ke','ka'}, 'InitialValue', [0.1, 0.5], 'Bounds', [0.01 1; 0.1 5]);
ei(1).Transform = 'log';
ei(2).Transform = 'log';
```

Alternative: use `'log(param)'` name syntax (equivalent result):
```matlab
ei = estimatedInfo({'log(ke)','log(ka)'}, 'InitialValue', [0.1, 0.5], 'Bounds', [0.01 1; 0.1 5]);
```

**Important:** `InitialValue` and `Bounds` are always in the
**untransformed** (natural) domain. Do NOT pass `log(value)`.

Available transforms: `'log'`, `'logit'`, `'probit'`

Do NOT pass `'Transform'` as a name-value pair to the `estimatedInfo`
constructor — it errors. Always set the `.Transform` property after.

### 6. Error models for population fitting

Choose the error model that matches the noise structure:
- `'constant'` — absolute noise uniform
- `'proportional'` — noise scales with magnitude (most PK data)
- `'combined'` — both constant and proportional
- `'exponential'` — log-normal residual

### 7. NCA requires `sbioncaoptions` object

Do not use name-value pairs. Column names are camelCase.
EVDose column uses `NaN` for non-dose rows.

## Decision Table

| Scenario | Approach |
|----------|----------|
| Single subject or pooled fit | `fitproblem` with `FitFunction="sbiofit"` |
| Individual fits per subject | `fitproblem` with `Pooled=false` |
| Population NLME (IIV, random effects) | `fitproblem` with `FitFunction="sbiofitmixed"` |
| Model-independent PK metrics | `sbionca` |

## `fitproblem` Workflow (Preferred)

Use `fitproblem` for all parameter estimation. It provides a unified,
declarative interface that replaces direct calls to `sbiofit`/`sbiofitmixed`:

```matlab
% 1. Prepare data
data = groupedData(table(tSample, yData, 'VariableNames', {'Time','Drug'}));
data.Properties.IndependentVariableName = 'Time';

% 2. Define parameters with bounds
estimParams = estimatedInfo({'ke','ka'}, ...
    'InitialValue', [0.2, 1.0], ...
    'Bounds', [0.01 1; 0.1 5]);

% 3. Build the fit problem
prob = fitproblem;
prob.Model = model;
prob.Data = data;
prob.ResponseMap = "Drug = Drug";
prob.Estimated = estimParams;
prob.Doses = dose;                  % optional
prob.FunctionName = 'scattersearch';
prob.ProgressPlot = true;           % show live progress

% 4. Fit
results = fit(prob);

% 5. Inspect
disp(results.ParameterEstimates);
plot(results);
```

### Key `fitproblem` properties

| Property | Purpose |
|----------|---------|
| `Model` | The SimBiology model object |
| `Data` | `groupedData` table |
| `Estimated` | `estimatedInfo` object (**not** `EstimatedParameters`) |
| `ResponseMap` | Maps model species to data columns |
| `Doses` | Dose object(s) (**not** `Dose`) |
| `FitFunction` | `"sbiofit"` (default) or `"sbiofitmixed"` |
| `FunctionName` | Algorithm: `'scattersearch'`, `'nlinfit'`, `'fminsearch'`, `'lsqnonlin'`, `'particleswarm'` |
| `ProgressPlot` | `true` to show live fitting progress |
| `UseParallel` | `true` for parallel evaluation |
| `Pooled` | `true`/`false`/`"auto"` (sbiofit only) |
| `ErrorModel` | `"constant"`, `"proportional"`, `"combined"`, `"exponential"` |
| `Variants` | Variants to apply during fitting |

**Common property name mistakes:** `prob.Estimated` (not `EstimatedParameters`),
`prob.Doses` (not `Dose`), `prob.FunctionName` (not `Algorithm` or `Method`).

### Estimation algorithms

| Method | Use Case |
|--------|----------|
| `'scattersearch'` | Built-in global search, no extra toolbox — **start here** |
| `'nlinfit'` | Default local; smooth problems |
| `'lsqnonlin'` | Bounded least squares (Optimization Toolbox) |
| `'fminsearch'` | Derivative-free, simple problems |
| `'particleswarm'` | Global search (Global Optimization Toolbox) |

### Dosing from multi-subject data

When subjects receive different doses, use `createDoses` to extract
per-subject dose objects from the data. The dose column must have `NaN`
on non-dosing rows:

```matlab
% Data format: dose amount only at administration time, NaN elsewhere
%   ID  Time  Dose  DrugConc  Group
%   1   0     50    0         LowDose
%   1   1     NaN   2.05      LowDose
%   ...
%   3   0     200   0         HighDose

% Create template dose targeting the depot species
tempDose = sbiodose('StudyDose');
tempDose.TargetName = 'Depot.Drug';   % match your model's dose target

% Extract per-subject doses from groupedData
doseArray = createDoses(gData, 'Dose', '', tempDose);

% Pass to fitproblem
prob.Doses = doseArray;
```

**Critical:** If all rows have the dose value (not just dosing times),
`createDoses` will treat every row as a dose event. Use `NaN` on
non-dosing rows.

### Population fitting (pooled vs individual)

```matlab
data.Properties.GroupVariableName = 'SubjectID';

% Pooled — one parameter set for all
prob.Pooled = true;

% Individual — separate per subject
prob.Pooled = false;
```

### Category-based pooling (per-group estimates)

To estimate parameters separately per category (e.g., dose group), use
`CategoryVariableName` on the `estimatedInfo` object — **not** on
`fitproblem` or `sbiofit`:

```matlab
estimParams = estimatedInfo({'ke'}, 'InitialValue', 0.1, 'Bounds', [0.01 1]);
estimParams.CategoryVariableName = 'DoseGroup';  % column in data table
% Do NOT set prob.Pooled — leave it at the default
```

**Warning:** Do NOT set `prob.Pooled` when using `CategoryVariableName`.
Setting `Pooled=false` triggers per-subject individual fitting that
**ignores** `CategoryVariableName` (MATLAB issues a warning). Leave
`Pooled` unset to let the category-based pooling work correctly.

## NLME Population Fitting

For inter-individual variability and random effects estimation,
set `FitFunction` to `"sbiofitmixed"`:

```matlab
% 1. Load & tag grouped data
data = groupedData(readtable('pop_pk_data.csv'));
data.Properties.IndependentVariableName = 'Time';
data.Properties.GroupVariableName = 'SubjectID';

% 2. Define parameters (Bounds ignored by sbiofitmixed — use InitialValue only)
estimParams = estimatedInfo({'CL','Vd','ka'}, ...
    'InitialValue', [5, 50, 1.2]);

% 3. Build the fit problem
prob = fitproblem;
prob.Model = model;
prob.Data = data;
prob.ResponseMap = "DrugConc = Concentration";
prob.Estimated = estimParams;
prob.FitFunction = "sbiofitmixed";
prob.ErrorModel = "proportional";
prob.ProgressPlot = true;

% 4. Fit
results = fit(prob);

% 5. Inspect
results.FixedEffects
results.RandomEffectCovarianceMatrix
results.IndividualParameterEstimates
```

### When to use NLME vs sbiofit

| Criterion | `FitFunction="sbiofit"` | `FitFunction="sbiofitmixed"` |
|-----------|-----------|----------------|
| Single subject | Yes | |
| Multiple subjects, no IIV | Yes (pooled) | |
| Inter-individual variability | | Yes |
| Random effects estimation | | Yes |
| Covariate modeling | | Yes |
| Small datasets (< 5 subjects) | Yes | May not converge |
| Bounds on parameters | Yes (enforced) | **Ignored** — use good InitialValue instead |

### NLME with covariates (CovariateModel)

When covariates (e.g., weight, age) influence parameters, use a
`CovariateModel` instead of `estimatedInfo`:

```matlab
covModel = CovariateModel;
covModel.Expression = {
    'CL = theta1 + theta2*WT + eta1'
    'Vd = theta3 + theta4*WT + eta2'
    'ka = theta5 + eta3'
};
initVals = covModel.constructDefaultFixedEffectValues;
initVals.theta1 = 5; initVals.theta2 = 0.1;
initVals.theta3 = 50; initVals.theta4 = 0.5;
initVals.theta5 = 1.2;
covModel.FixedEffectValues = initVals;

prob = fitproblem;
prob.Model = model;
prob.Data = data;  % groupedData with WT column
prob.ResponseMap = "DrugConc = Concentration";
prob.FitFunction = "sbiofitmixed";
prob.Estimated = covModel;
prob.ErrorModel = "proportional";
results = fit(prob);
```

**When to use which:**
- `estimatedInfo` — NLME without covariates (simpler, fewer parameters)
- `CovariateModel` — NLME with covariates (parameter-covariate relationships)

**Expression rules:** `theta` prefix for fixed effects, `eta` for random
effects. One random effect max per expression. Use `verify(covModel)` to
validate syntax before fitting.

## Virtual Patient Generation

### From assumed distributions (Scenarios)

Use `SimBiology.Scenarios` with `makedist` — avoids manual matrix construction:

```matlab
sc = SimBiology.Scenarios;
add(sc, 'elementwise', 'ke', makedist('Lognormal', 'mu', log(0.1), 'sigma', 0.3), 'Number', 100);
add(sc, 'elementwise', 'ka', makedist('Lognormal', 'mu', log(0.5), 'sigma', 0.25), 'Number', 100);

simfun = createSimFunction(model, sc, {'Drug'}, []);
results = simfun(sc, 24);
```

### From NLME results (sbiosampleparameters)

Use `sbiosampleparameters` to sample from fitted population parameters —
it respects the covariate model parameterization automatically:

```matlab
% Extract from NLME results
covModel = covariateModel(nlmeResults);
thetas = nlmeResults.FixedEffects;
omega = nlmeResults.RandomEffectCovarianceMatrix;

% Sample 200 virtual patients
nVP = 200;
vpParams = sbiosampleparameters(covModel.Expression, thetas, omega, nVP);

% Simulate
simfun = createSimFunction(model, {'CL','Vd','ka'}, {'Cp'}, []);
vpSim = simfun(vpParams, 48);
```

## Non-Compartmental Analysis (NCA)

### From simulation output

Use explicit `OutputTimes` to ensure sufficient time-resolution for NCA
(the default solver output may have too few points near Cmax):

```matlab
cs = getconfigset(m, 'active');
cs.SolverOptions.OutputTimes = linspace(0, 24, 200);

[t, x, names] = sbiosimulate(m);
drugIdx = find(strcmp(names, 'Drug'));
Vd = sbioselect(m, 'Type', 'parameter', 'Name', 'Vd');
conc = x(:, drugIdx) ./ Vd.Value;
evDose = NaN(size(t)); evDose(1) = 100;
data = table(t, conc, evDose, 'VariableNames', {'Time','Concentration','EVDose'});

opt = sbioncaoptions;
opt.concentrationColumnName = 'Concentration';
opt.timeColumnName = 'Time';
opt.EVDoseColumnName = 'EVDose';
opt.AdministrationRoute = 'ExtraVascular';
ncaResults = sbionca(data, opt);
```

### Administration routes

| Route | Dose column | Extra config |
|-------|-------------|--------------|
| `'ExtraVascular'` | `opt.EVDoseColumnName` | — |
| `'IVBolus'` | `opt.IVDoseColumnName` | — |
| `'IVInfusion'` | `opt.IVDoseColumnName` | `opt.infusionRateColumnName` |

### Key NCA metrics

**All metric names use underscores** (e.g., `C_max` not `Cmax`):

| Metric | Description |
|--------|-------------|
| `AUC_0_last` | Area under curve (0 to last time) |
| `AUC_infinity` | AUC extrapolated to infinity |
| `C_max` | Maximum observed concentration |
| `T_max` | Time of Cmax |
| `T_half` | Terminal elimination half-life |
| `CL` | Clearance (dose / AUC) |
| `V_z` | Volume of distribution (terminal) |
| `MRT` | Mean residence time |

### Multi-subject NCA

```matlab
data.Properties.GroupVariableName = 'SubjectID';
opt.groupColumnName = 'SubjectID';
ncaResults = sbionca(data, opt);
```

## Confidence Intervals and Profile Likelihood

**Restriction:** `sbioparameterci` only works with results from nonlinear
regression (`sbiofit`). It does NOT support NLME results (`sbiofitmixed`).

After fitting with `sbiofit`, compute confidence intervals:

### Gaussian (asymptotic) CI — fast, default

```matlab
ciResults = sbioparameterci(fitResults);
disp(ciResults.Results);  % table: Name (cell), Estimate, Bounds, ConfidenceInterval (Nx2 double), Status (categorical)
plot(ciResults);
```

**Column types in `.Results` table:**
- `Name` — cell array of char (`Results.Name{i}`)
- `ConfidenceInterval` — Nx2 double matrix (`Results.ConfidenceInterval(i,:)`)
- `Status` — **categorical** (`Results.Status(i)`, NOT `{i}`)

### Profile likelihood CI — more accurate for nonlinear models

```matlab
ciPL = sbioparameterci(fitResults, 'Type', 'ProfileLikelihood');
plot(ciPL);  % shows profile likelihood curves with CI bounds
% Custom confidence level: 'Alpha', 0.10 for 90% CI
```

| Type | Speed | Use when |
|------|-------|----------|
| `'Gaussian'` (default) | Fast | Quick check, well-behaved problems |
| `'ProfileLikelihood'` | Slower | Final results, parameter identifiability |

## Conventions

- **Species names must differ from compartment names.** Use distinct names: compartment `Depot` with species `DrugDepot` (not species `Depot` inside compartment `Depot`).
- **Units on compartment volumes:** Always specify units on compartment volumes (e.g., `'liter'`). Set `DimensionalAnalysis = true` and `VariableUnits` on `groupedData`. For pure amount-based models, set `Value = 1` and omit units.
- **Loading `.sbproj`:** `proj = sbioloadproject('f.sbproj'); model = proj.(fieldnames(proj){1});`
- **Extracting data:** `selectbyname(sbiosimulate(m), 'Drug')` for specific variables; `resample(sd, tSample, 'linear')` for specific times
- Start with `'scattersearch'` if unsure about parameter landscape
- Use `'log'` transform for parameters spanning orders of magnitude (see Rule 5)
- Do NOT call `sbioaccelerate(model)` before fitting — no effect, wastes time
- Set `cs.MaximumWallClock = 60` — stops hung simulations from bad guesses
- Set `prob.ProgressPlot = true` for long-running fits

## Evaluating Fit Quality

```matlab
plot(results);                      % observed vs predicted overlay
plotResiduals(results);             % residuals vs time
plotResidualDistribution(results);  % histogram — should be ~normal
plotActualVersusPredicted(results); % identity line check

results.LogLikelihood  % higher = better
results.AIC            % lower = better (penalizes complexity)
results.BIC            % lower = better (stronger penalty)
results.MSE            % mean squared error
```

**Model comparison:** Compare by BIC — `deltaBIC < -10` = strong evidence
for complex model; `deltaBIC > 0` = simpler model preferred.

**When to escalate to NLME:** Multiple subjects with different parameter
values, systematic subject-specific residual patterns, need to quantify
inter-individual variability, or covariates may explain differences.
- Pass **model objects** (not UUID strings) to fitting functions
- Do NOT call `sbiofit`/`sbiofitmixed`/`sbionlmefit` directly — use `fitproblem`

## References
Load on demand for detailed guidance:
- `references/nca-analysis-guidance.md` — full NCA patterns, IV infusion, metrics interpretation

----

Copyright 2026 The MathWorks, Inc.

----
