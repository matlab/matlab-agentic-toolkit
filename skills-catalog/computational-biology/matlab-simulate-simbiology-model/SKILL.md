---
name: matlab-simulate-simbiology-model
description: "Simulate SimBiology models — ODE, stochastic (SSA), scenarios, and sensitivity analysis. Use when asked to run, simulate, predict, explore what-if, or identify influential parameters."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.2"
---

# Simulate SimBiology Models

Run simulations of SimBiology models: deterministic ODE, stochastic SSA,
scenario exploration, and sensitivity analysis.

## When to Use

- "simulate", "run", "predict" model behavior
- "what if" / "what happens if" (implies simulation or scenarios)
- Time-course results from a model
- Dose-response studies, parameter sweeps, factorial designs
- Stochastic, SSA, Gillespie, noise, gene expression variability
- "which parameters matter most", sensitivity, Sobol, Morris
- Keywords: "simulate", "run", "predict", "what-if", "stochastic", "sensitivity"

## When NOT to Use

- Model construction or diagram layout (use `matlab-build-simbiology-model`)
- Parameter estimation from data (use `matlab-fit-simbiology-model`)
- NCA / AUC / Cmax from data (use `matlab-fit-simbiology-model`)

## Must-Follow Rules

### 0. Add helper scripts to the MATLAB path first

Run at the start of every session:
```matlab
addpath(fullfile('<WORKSPACE_ROOT>', '.claude', 'skills', 'matlab-simulate-simbiology-model', 'scripts'));
```

### 1. Element-wise operators in observables

Use `./` and `.*` (element-wise) in observable expressions when mixing
time-varying species with constant parameters. Plain `/` and `*` cause
size mismatches at simulation time.

### 2. StatesToLog for constant parameters

When observables reference constant parameters (e.g., `Drug ./ Vd`),
add those parameters explicitly to `StatesToLog`:
```matlab
cs.RuntimeOptions.StatesToLog = [m.Species; sbioselect(m,'Type','parameter','Name','Vd')];
```
`StatesToLog = 'all'` does **not** log constant compartments or parameters.

### 3. All reactions must be MassAction for SSA

The stochastic solver does not support custom rate expressions. Every
reaction must use `addkineticlaw(rx, 'MassAction')`.

### 4. Do NOT combine Scenarios with `+`

The `+` operator is not supported on `SimBiology.Scenarios` objects.
Always use `add()` to append entries.

### 5. Reset local sensitivity options after use

Local sensitivity settings persist on the configset and affect
subsequent simulations. Always reset:
```matlab
cs.SolverOptions.SensitivityAnalysis = false;
cs.SensitivityAnalysisOptions.Inputs = [];
cs.SensitivityAnalysisOptions.Outputs = [];
```

### 6. Set `MaximumWallClock` to prevent hung simulations

When fitting or scanning, bad parameter values can make individual
simulations extremely slow. Protect against this:
```matlab
cs.MaximumWallClock = 60;  % seconds; default is Inf
```
This is a **configset** property (not a solver or optimizer option).
It stops any single simulation that exceeds the wall clock limit.

### 7. Unit conversion requires `TimeUnits`

When `cs.CompileOptions.UnitConversion = true`, you MUST also set
`cs.TimeUnits` to match your StopTime units (e.g., `'hour'`).
Otherwise SimBiology defaults to seconds and your 24-unit simulation
covers 24 seconds, not 24 hours:
```matlab
cs.CompileOptions.UnitConversion = true;
cs.TimeUnits = 'hour';
cs.StopTime = 24;  % now correctly 24 hours
```

### 8. Scenario results are interleaved, not blocked

Factorial scenario results come back interleaved by the first dimension.
Always use `generate(sc)` to map result indices to conditions — never
assume all entries of one factor appear consecutively.

## Decision Table

| Scenario | Approach |
|----------|----------|
| One-off simulation | `sbiosimulate` |
| Parameter sweep / Monte Carlo | `createSimFunction` |
| Dose/variant/parameter what-if | `SimBiology.Scenarios` + `createSimFunction` |
| Low molecule count / noise | SSA solver (`cs.SolverType = 'ssa'`) |
| Which parameters matter? | `sbiosobol` (Sobol) or `sbioelementaryeffects` (Morris) |
| Quick sensitivity check | Local sensitivity via configset |

## Basic Simulation (`sbiosimulate`)

Prefer returning **SimData** (single output) — it carries state names,
units, and metadata, and works directly with `sbioplot` and `selectbyname`:

```matlab
m = getModelByUUID(modelId);
cs = getconfigset(m, 'active');
cs.StopTime = 24;
cs.SolverType = 'ode15s';
simData = sbiosimulate(m);
```

With a dose (configset is **required** as 2nd argument when passing doses):
```matlab
d = sbiodose('Bolus', 'schedule');
d.TargetName = 'Drug'; d.Amount = 100; d.Time = 0;
simData = sbiosimulate(m, cs, d);  % NOT sbiosimulate(m, d) — errors
```

## Plotting Results

Use `sbioplot` for quick visualization of SimData:
```matlab
simData = sbiosimulate(m, cs, d);
sbioplot(simData);
```

For custom plots, extract numeric data first:
```matlab
[t, x, names] = getdata(simData);
plot(t, x);
legend(names, 'Interpreter', 'none');
xlabel('Time'); ylabel('Amount');
```

## Extracting State Data from SimData

Use `selectbyname` to extract specific states. It returns a **SimData
object**, not a numeric array — extract numeric data before doing math:
```matlab
simData = sbiosimulate(m, cs, d);
result = selectbyname(simData, 'Central.Drug');  % returns SimData, NOT double
drugData = result.Data;   % numeric column vector
drugTime = result.Time;   % time column vector
```

Or use `getdata()` to get arrays:
```matlab
[t, x, names] = getdata(selectbyname(simData, 'Central.Drug'));
```

For quick numeric access to all states without SimData, use the
three-output form:
```matlab
[t, x, names] = sbiosimulate(m, cs, d);  % t, x are double arrays directly
```

### Acceleration (`sbioaccelerate`)

For repeated `sbiosimulate` calls on the same model, accelerate once first:
```matlab
sbioaccelerate(m);
simData = sbiosimulate(m);  % faster
```

**Rules:**
- Call only right before `sbiosimulate` — not before fitting or analysis functions
- Valid after changing parameter/species **values** (e.g., `p.Value = 0.2`)
- **Invalidated** by structural changes (adding reactions, species, compartments) — must re-accelerate
- Do NOT use with `createSimFunction`, Scenarios, sensitivity, or fitting — these handle acceleration internally via `AutoAccelerate`

## Repeated Simulation (`createSimFunction`)

```matlab
% Signature: createSimFunction(model, params, observables, dosedSpecies)
simfun = createSimFunction(model, {'ke','ka'}, {'Drug'}, []);
r1 = simfun([0.1, 0.5], 24);           % single run
r2 = simfun([0.1, 0.5; 0.3, 1.0], 24); % multiple parameter sets (rows)
[t, x] = r1.getdata();
```

- Compiles once, runs many — much faster than `sbiosimulate` in a loop
- **Exception:** SSA (stochastic) requires `sbiosimulate` in a loop because each run needs fresh random state; `createSimFunction` does not support stochastic solvers
- Compatible with `parfor` (Parallel Computing Toolbox)
- Returns `SimData` objects; use `.getdata()` to extract arrays

### SimFunction with doses

The 4th argument to `createSimFunction` declares which species receive
doses. When executing, pass doses as a **table** (NOT a dose object):

```matlab
% Create: specify dosed species names in 4th argument
simfun = createSimFunction(model, {'ke'}, {'Drug'}, {'Drug'});

% Execute: pass dose as a table with Time and Amount columns
doseTable = table(0, 100, 'VariableNames', {'Time', 'Amount'});
result = simfun(0.1, 24, doseTable);

% Multiple dose events
multiDose = table([0; 12], [100; 50], 'VariableNames', {'Time', 'Amount'});
result = simfun(0.1, 24, multiDose);

% Multiple dosed species: cell array of tables (one per species, same order)
simfun2 = createSimFunction(model, {'ke'}, {'Drug','Drug2'}, {'Drug','Drug2'});
doses = {doseTable1, doseTable2};
result = simfun2(0.1, 24, doses);
```

**Common mistake:** passing a `sbiodose` object to a SimFunction — this
errors. Always convert to a table with `Time` and `Amount` columns.

## Scenarios (`SimBiology.Scenarios`)

Systematically explore combinations of doses, variants, and parameters.

### `add()` signature (argument order is critical)

```matlab
add(sc, combination, name, values, ...)
%     ^^^^^^^^^^^^^
%     MUST be 2nd argument: 'cartesian' or 'elementwise'
```

The combination type (`'cartesian'` or `'elementwise'`) is **always the
second argument** to `add()`. Putting it elsewhere errors.

### Dose sweep

```matlab
d1 = sbiodose('Low','schedule'); d1.TargetName = 'Drug'; d1.Amount = 50; d1.Time = 0;
d2 = sbiodose('High','schedule'); d2.TargetName = 'Drug'; d2.Amount = 200; d2.Time = 0;
sc = SimBiology.Scenarios('DoseLevel', [d1, d2]);
```

### Full factorial (dose x parameter)

```matlab
sc = SimBiology.Scenarios('DoseLevel', [d1, d2]);
add(sc, 'cartesian', 'ke', [0.05 0.1 0.2]);  % 2 x 3 = 6 combinations
simfun = createSimFunction(model, sc, {'Drug'}, []);
results = simfun(sc, 24);
```

### Parameter sweep with dosed SimFunction

```matlab
sc = SimBiology.Scenarios('ke', [0.05 0.1 0.2]);
simfun = createSimFunction(model, sc, {'Drug'}, {'Drug'});
doseTable = table(0, 100, 'VariableNames', {'Time', 'Amount'});
results = simfun(sc, 24, doseTable);  % dose table as 3rd argument
```

### Result ordering (critical)

Scenario results are **interleaved by the first dimension**, not blocked.
For a 2-dose × 3-ke factorial, results come back as:

```
results(1): Dose1, ke1
results(2): Dose2, ke1
results(3): Dose1, ke2
results(4): Dose2, ke2
results(5): Dose1, ke3
results(6): Dose2, ke3
```

Use `generate(sc)` to get a table mapping each result index to its conditions:
```matlab
genTable = generate(sc);  % table with one row per scenario
for i = 1:numel(results)
    [t, x] = results(i).getdata();
    fprintf('Dose=%s, ke=%.2f: Drug at t=end = %.2f\n', ...
        genTable.DoseLevel(i).Name, genTable.ke(i), x(end,1));
end
```

**Never assume blocked ordering** (all of Dose1 first, then all of Dose2).
Always use `generate(sc)` to map results to conditions.

### Entry types

| Content Type | Example |
|---|---|
| Dose vector | `SimBiology.Scenarios('DoseLevel', [d1, d2])` |
| Variant vector | `SimBiology.Scenarios('Pop', [v1, v2])` |
| Parameter values | `SimBiology.Scenarios('ke', [0.05 0.1 0.2])` |
| Species values | `SimBiology.Scenarios('Drug', [50 100 200])` |
| Probability distribution | `add(sc, 'elementwise', 'ke', makedist('Lognormal',...), 'Number', 50)` |

### Virtual population via distribution sampling

Scenarios can sample from probability distributions — use this for virtual
patient simulations instead of manually generating parameter matrices:

```matlab
pd = makedist('Lognormal', 'mu', log(0.1), 'sigma', 0.3);
sc = SimBiology.Scenarios;
add(sc, 'elementwise', 'ke', pd, 'Number', 50);
simfun = createSimFunction(model, sc, {'Drug'}, []);
results = simfun(sc, 24);
```

### Steady-state with repeat dosing

```matlab
d = sbiodose('RepeatDose', 'repeat');
d.TargetName = 'Drug'; d.Amount = 100;
d.StartTime = 0; d.Interval = 12; d.RepeatCount = 50;
cs.StopTime = d.Interval * (d.RepeatCount + 1);
[t, x, names] = sbiosimulate(model, cs, d);
```

## Stochastic Simulation (SSA)

For low molecule count systems where continuous ODE breaks down.

### Single trajectory

```matlab
cs = getconfigset(model, 'active');
cs.SolverType = 'ssa';
cs.StopTime = 100;
simData = sbiosimulate(model);
[t, x, names] = getdata(simData);
```

### Ensemble (multiple trajectories)

```matlab
nRuns = 200;
allResults = cell(nRuns, 1);
for i = 1:nRuns
    allResults{i} = sbiosimulate(model);
end
```

### Gene expression template (all MassAction)

```matlab
model = sbiomodel('GeneExpr');
comp = addcompartment(model, 'cell');
addspecies(comp, 'Gene', 1);
addspecies(comp, 'mRNA', 0);
addspecies(comp, 'Protein', 0);
addparameter(model, 'k_txn', 0.1);
addparameter(model, 'k_tln', 0.5);
addparameter(model, 'k_mdeg', 0.05);
addparameter(model, 'k_pdeg', 0.01);

% Transcription: Gene -> Gene + mRNA (Gene is catalyst)
rx1 = addreaction(model, 'Gene -> Gene + mRNA');
kl1 = addkineticlaw(rx1, 'MassAction'); kl1.ParameterVariableNames = {'k_txn'};
% Translation: mRNA -> mRNA + Protein
rx2 = addreaction(model, 'mRNA -> mRNA + Protein');
kl2 = addkineticlaw(rx2, 'MassAction'); kl2.ParameterVariableNames = {'k_tln'};
% Degradation
rx3 = addreaction(model, 'mRNA -> null');
kl3 = addkineticlaw(rx3, 'MassAction'); kl3.ParameterVariableNames = {'k_mdeg'};
rx4 = addreaction(model, 'Protein -> null');
kl4 = addkineticlaw(rx4, 'MassAction'); kl4.ParameterVariableNames = {'k_pdeg'};
```

After SSA, reset solver: `cs.SolverType = 'ode15s';`

## Sensitivity Analysis

### Sobol (global, quantitative)

```matlab
bounds = [0.01 1; 0.1 5];  % [low high] per parameter
sobolResults = sbiosobol(m, {'ke','ka'}, {'Drug'}, ...
    'OutputTimes', 0:1:24, 'NumberSamples', 500, 'Bounds', bounds);
plot(sobolResults);

% Extract indices from struct array
for i = 1:numel(sobolResults.SobolIndices)
    Si  = mean(sobolResults.SobolIndices(i).FirstOrder, 'omitnan');
    STi = mean(sobolResults.SobolIndices(i).TotalOrder, 'omitnan');
    fprintf('%s: Si=%.3f, STi=%.3f\n', sobolResults.SobolIndices(i).Parameter, Si, STi);
end
```

- **First-order (Si):** variance due to parameter alone
- **Total-order (STi):** variance due to parameter + all interactions
- Large gap STi - Si → strong interaction effects
- Access via `sobolResults.SobolIndices(i).FirstOrder` / `.TotalOrder` (struct array, one per parameter)

### Morris screening (global, ranking)

```matlab
bounds = [0.01 1; 0.1 5];
eeResults = sbioelementaryeffects(m, {'ke','ka'}, {'Drug'}, ...
    'OutputTimes', 0:1:24, 'NumberSamples', 50, 'Bounds', bounds);
```

- High mean effect → influential parameter
- High standard deviation → nonlinear or interaction effects

### Local sensitivity

```matlab
cs.SolverOptions.SensitivityAnalysis = true;
cs.SensitivityAnalysisOptions.Normalization = 'Full';
cs.SensitivityAnalysisOptions.Inputs = sbioselect(m,'Type','parameter','Name',{'ke','ka'});
cs.SensitivityAnalysisOptions.Outputs = sbioselect(m,'Type','species','Name','Drug');
simData = sbiosimulate(m);
[t, R] = getsensmatrix(simData);
% IMPORTANT: Reset after use
cs.SolverOptions.SensitivityAnalysis = false;
cs.SensitivityAnalysisOptions.Inputs = [];
cs.SensitivityAnalysisOptions.Outputs = [];
```

| Normalization | Meaning |
|---|---|
| `'None'` | Raw dY/dp |
| `'Half'` | (p/y) dY/dp |
| `'Full'` | Dimensionless; both sides normalized |

## Conventions

- **Loading `.sbproj` files:** `sbioloadproject` returns a struct with the model name as field — extract dynamically:
  ```matlab
  proj = sbioloadproject('file.sbproj');
  fn = fieldnames(proj);
  model = proj.(fn{1});
  ```
- Pass **model objects** (not UUID strings) to simulation functions
- Use `getModelByUUID(uuid)` to recover handles (provided by this skill's `scripts/` directory — add to path at session start)
- `createSimFunction` returns `SimData`; extract with `.getdata()`
- Pass model directly to `sbiosobol`/`sbioelementaryeffects` (not a SimFunction)
- Bounds matrix: one row per parameter, columns `[low high]`

## References

Load on demand for detailed guidance:

- `references/stochastic-simulation-guidance.md` — ensemble plotting, distribution analysis
- `references/sensitivity-analysis-guidance.md` — full Sobol/Morris/Local patterns and interpretation


----

Copyright 2026 The MathWorks, Inc.

----
