# Sensitivity Analysis Guidance

Full patterns for Sobol, Morris, and local sensitivity analysis including
interpretation, dispatch heuristics, and troubleshooting.

---

## Method Selection

| Method | Function | Samples Needed | Best For |
|--------|----------|----------------|----------|
| **Sobol** | `sbiosobol` | 500-1000 | Quantifying first-order and interaction effects |
| **Morris** | `sbioelementaryeffects` | 50-100 | Quick screening/ranking as a first pass |
| **Local** | configset `SensitivityAnalysis` | 1 sim | Quick check near current parameter values |

**Dispatch heuristic:**
- < 5 parameters → Sobol directly
- 5-20 parameters → Morris first to screen, then Sobol on top parameters
- > 20 parameters → Morris to narrow down, then Sobol on top 5-10

---

## Sobol Analysis (Detailed)

```matlab
m = getModelByUUID(modelId);
paramNames = {'ke', 'ka', 'Vd', 'k12', 'k21'};
bounds = [0.01 1; 0.1 5; 5 50; 0.01 1; 0.01 1];  % [low high] per param

sobolResults = sbiosobol(m, paramNames, {'Drug'}, ...
    'OutputTimes', 0:1:24, ...
    'NumberSamples', 500, ...
    'Bounds', bounds);

% Plot built-in visualization
plot(sobolResults);
```

### Interpreting Sobol indices

- **First-order index (Si):** fraction of output variance due to
  parameter i alone (main effect)
- **Total-order index (STi):** fraction due to parameter i + all its
  interactions with other parameters
- **Interaction contribution:** STi - Si (large means parameter has
  strong synergistic effects with others)

| Pattern | Interpretation |
|---------|----------------|
| Si high, STi ≈ Si | Parameter is influential, mostly independently |
| Si low, STi high | Parameter is influential only via interactions |
| Si ≈ 0, STi ≈ 0 | Parameter can likely be fixed |
| Sum(Si) ≈ 1 | Additive model (no interactions) |
| Sum(Si) << 1 | Strong interaction effects present |

### Accessing results programmatically

```matlab
for i = 1:numel(sobolResults.SobolIndices)
    si = sobolResults.SobolIndices(i);
    fprintf('Parameter: %s\n', si.Parameter);
    fprintf('  First-order (mean over time): %.3f\n', mean(si.FirstOrder, 'omitnan'));
    fprintf('  Total-order (mean over time): %.3f\n', mean(si.TotalOrder, 'omitnan'));
end
```

Note: Indices at t=0 may be NaN (zero output variance).

---

## Morris Screening (Detailed)

```matlab
bounds = [0.01 1; 0.1 5; 5 50];
eeResults = sbioelementaryeffects(m, {'ke','ka','Vd'}, {'Drug'}, ...
    'OutputTimes', 0:1:24, ...
    'NumberSamples', 50, ...
    'Bounds', bounds);
```

### Interpreting Morris results

```matlab
for i = 1:numel(eeResults.Results)
    r = eeResults.Results(i);
    fprintf('Parameter: %s\n', r.Parameter);
    fprintf('  Mean effect: %.3f\n', mean(r.Mean, 'omitnan'));
    fprintf('  Std deviation: %.3f\n', mean(r.StandardDeviation, 'omitnan'));
end
```

| Mean Effect | Std Dev | Interpretation |
|-------------|---------|----------------|
| High | Low | Linear, influential |
| High | High | Nonlinear or interacting, influential |
| Low | Low | Not influential (can fix) |
| Low | High | Nonlinear but weak overall effect |

---

## Local Sensitivity (Detailed)

```matlab
cs = getconfigset(m, 'active');
cs.SolverOptions.SensitivityAnalysis = true;
cs.SensitivityAnalysisOptions.Normalization = 'Full';
cs.SensitivityAnalysisOptions.Inputs = ...
    sbioselect(m, 'Type', 'parameter', 'Name', {'ke','ka'});
cs.SensitivityAnalysisOptions.Outputs = ...
    sbioselect(m, 'Type', 'species', 'Name', 'Drug');

simData = sbiosimulate(m);
[t, R] = getsensmatrix(simData);

% R is nTimepoints x nOutputs x nInputs
% Plot sensitivity of Drug to ke over time
figure;
plot(t, R(:,1,1));
xlabel('Time'); ylabel('Sensitivity (dDrug/dke, normalized)');

% IMPORTANT: Reset after use
cs.SolverOptions.SensitivityAnalysis = false;
cs.SensitivityAnalysisOptions.Inputs = [];
cs.SensitivityAnalysisOptions.Outputs = [];
```

### Normalization options

| Option | Formula | When to Use |
|--------|---------|-------------|
| `'None'` | dY/dp | When absolute magnitudes matter |
| `'Half'` | (p/Y) dY/dp | Fractional change in output per unit change in param |
| `'Full'` | (p/Y)(dY/dp) | Dimensionless elasticity — comparable across parameters |

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| NaN in Sobol indices at t=0 | Zero output variance at initial time | Normal — variance grows over time |
| All indices ≈ 0 | Bounds too narrow | Widen parameter bounds |
| Sum(STi) > 1 | Normal for total-order indices | This is expected; sum of Si <= 1 |
| Morris all same rank | Too few samples | Increase NumberSamples |
| Local sensitivity persists | Didn't reset configset | Reset after every local run |


----

Copyright 2026 The MathWorks, Inc.

----
