# Antenna and Array Optimization

## Tier Selection

| Condition | Tier |
|-----------|------|
| Catalog antenna + built-in objective string | Tier 1: `optimize()` |
| `customAntenna`/`pcbStack` or custom objective | Tier 2: `OptimizerSADEA`/`OptimizerTRSADEA` |

## Tier 1: Built-in optimize()

### Syntax

```matlab
[optAnt, optinfo] = optimize(element, freq, objective, propertynames, bounds, Name=Value)
```

### Built-in Objectives

| Objective String | Goal |
|-----------------|------|
| `"maximizeGain"` | Maximize peak gain |
| `"maximizeBandwidth"` | Maximize impedance bandwidth |
| `"minimizeBandwidth"` | Minimize bandwidth (narrowband) |
| `"maximizeSLL"` | Maximize front-lobe to sidelobe ratio |
| `"frontToBackRatio"` | Maximize front-to-back ratio |
| `"minimizeArea"` | Minimize antenna footprint |

### String Constraints

```matlab
Constraints={'S11 < -10', 'Gain > 5', 'Area < 0.03'}
```

| Constraint | Units | Description |
|-----------|-------|-------------|
| `'S11 < value'` | dB | Maximum return loss |
| `'Gain > value'` | dBi | Minimum gain |
| `'F/B > value'` | dB | Minimum front-to-back |
| `'SLL > value'` | dB | Minimum sidelobe level |
| `'Area < value'` | m^2 | Maximum area |
| `'Volume < value'` | m^3 | Maximum volume |

### Name-Value Arguments

| Name | Default | Description |
|------|---------|-------------|
| `Constraints` | none | Cell array of strings |
| `Weights` | equal | Penalty weights (1-100) |
| `FrequencyRange` | +/-5% | Frequency vector for BW analysis |
| `ReferenceImpedance` | 50 | Reference Z (ohms) |
| `MainLobeDirection` | [0, 90] | [az, el] for gain eval |
| `Iterations` | 200 | Optimization iterations |
| `UseParallel` | false | Parallel evaluation |
| `EnableCoupling` | true | Mutual coupling in arrays |
| `GeometricConstraints` | none | From `initGeomConstraint` |
| `UseAlgorithm` | `"SADEA"` | `"SADEA"` or `"TR-SADEA"` |

**`FrequencyRange` trap:** Default is +/-5%. For bandwidth optimization, always set explicitly.

### Bounds Format

Two-row cell array: `{lower1, lower2; upper1, upper2}`:

```matlab
ant = design(patchMicrostrip, 2.4e9);
[optAnt, optinfo] = optimize(ant, 2.4e9, "maximizeGain", ...
    {'Length', 'Width'}, {0.6*ant.Length, 0.6*ant.Width; 1.4*ant.Length, 1.4*ant.Width}, ...
    Constraints={'S11 < -10'}, Iterations=50);
```

**Vector-valued properties** (like `FeedOffset = [x, y]`):
```matlab
optimize(ant, freq, "maximizeGain", ...
    {'Length', 'Width', 'FeedOffset'}, ...
    {lbL, lbW, [0, 0]; ubL, ubW, [0.01, 0.005]}, Iterations=50);
```

### Common Design Variables

| Antenna | Variables |
|---------|----------|
| `patchMicrostrip` | `Length`, `Width`, `Height`, `FeedOffset` |
| `dipole` | `Length`, `Width` |
| `yagiUda` | `ReflectorLength`, `DirectorLength`, `ReflectorSpacing`, `DirectorSpacing` |
| `horn` | `FlareLength`, `FlareWidth`, `FlareHeight` |
| `linearArray` | `ElementSpacing` |

Keep to 2-6 design variables for catalog antennas.

**System antennas (reflector, cavity, etc.):** Properties like `Length` and `Width` belong to `Exciter` or `Element`, not the top-level object. Use dot notation:

```matlab
% Wrong: {'Length', 'Width', 'Spacing'}  — errors on reflector
% Right:
designVars = {'Exciter.Length', 'Exciter.Width', 'Spacing'};
```

If a property isn't found on the top-level object, check `properties(ant.Exciter)` or `properties(ant.Element)`.

## Geometric Constraints

Enforce relationships between design variables via `Ax <= b`.

### Translation Recipe

1. Write constraint in English: "Length must be at most 5× Width"
2. Standard form: `Length - 5*Width <= 0`
3. Map to A row: `[1, -5]`, `b = 0`

### Example

```matlab
designVars = {'Length', 'Width', 'Height'};

gc = initGeomConstraint;
gc.A = [1, -3, 0;     % Length <= 3*Width
        0, -1, 1];    % Height <= Width
gc.b = [0; 0];

optimize(ant, freq, "maximizeGain", designVars, bounds, ...
    GeometricConstraints=gc, Iterations=50);
```

### Common Templates

| Constraint | A Row | b |
|-----------|-------|---|
| Length <= k*Width | `[1, -k, 0, ...]` | `0` |
| Prop_i - Prop_j >= gap | `[..., -1, ..., 1, ...]` | `-gap` |
| Sum <= max | `[..., 1, ..., 1, ...]` | `max` |

### Nonlinear Geometric Constraints

Use a **named function** (not anonymous):

```matlab
gc = initGeomConstraint;
gc.nlcon = @areaConstraint;
gc.nrlv = [1, 1];    % relevance: matches total design variable count

function [c, ceq] = areaConstraint(x)
    c = x(1)*x(2) - 0.04;    % c <= 0
    ceq = 0;                  % must return nonempty
end
```

**Three gotchas:**
1. Must use named function handle (not anonymous)
2. Must set `gc.nrlv` (vector of 1s/0s for participating variables)
3. `ceq` must be nonempty (return `0`, not `[]`)

## Tier 2: OptimizerSADEA / OptimizerTRSADEA

### Custom Evaluation Function Pattern

The function takes a vector and returns a **scalar fitness**. SADEA **minimizes**.

```matlab
% TEMPLATE — not executable (createMyAntenna must be defined for your design)
function fitness = evaluateAntenna(x)
    freq = 2.4e9;
    try
        ant = createMyAntenna(x);
    catch
        fitness = 1e6;    % penalty for invalid geometry
        return;
    end

    try
        gain = pattern(ant, freq, 0, 90, Type="realizedgain");
        objective = -gain;    % negate to maximize
    catch
        objective = 1e6;
        return;
    end

    s = sparameters(ant, linspace(freq*0.9, freq*1.1, 11));
    s11_max = max(20*log10(abs(rfparam(s, 1, 1))));
    constraint = max(s11_max - (-10), 0);

    fitness = objective + 100 * constraint;
end
```

**Key rules:**
- Wrap in `try/catch`, return `1e6` for invalid geometries
- Negate metrics for maximization
- Mesh `customAntenna` explicitly: `mesh(ant, MaxEdgeLength=lambda/8)`
- Save as separate `.m` file (not inline)

**Before writing the eval function**, identify the analysis function for your objective and verify its required inputs:

| Function | Required Inputs | Common Mistake |
|----------|----------------|----------------|
| `bandwidth(ant, freqVector)` | Frequency vector (not scalar) | Passing single freq |
| `pattern(ant, freq, az, el)` | Frequency + angles | Omitting angle args |
| `beamwidth(ant, freq, az, el)` | Frequency + angle cut | Wrong cut plane |
| `impedance(ant, freqVector)` | Frequency vector | Passing single freq |
| `sparameters(ant, freqVector)` | Frequency vector | Passing single freq |

Test the analysis call standalone before wrapping in try/catch — the penalty value masks silent failures.

### Geometric Constraints in Tier 2

**Prefer `GeometricConstraints` over penalty terms** — the optimizer handles them natively with better convergence. Do not embed constraint penalties inside the eval function.

```matlab
bounds = [lb1, lb2, lb3; ub1, ub2, ub3];
s = OptimizerSADEA(bounds);
s.CustomEvaluationFunction = @evaluateAntenna;

% Add geometric constraints (same API as Tier 1)
gc = initGeomConstraint;
gc.A = [1, -2, 0];   % Length <= 2*Width (L - 2W <= 0)
gc.b = 0;
s.GeometricConstraints = gc;
```

### Running the Optimizer

```matlab
bounds = [lb1, lb2, lb3; ub1, ub2, ub3];  % numeric matrix
s = OptimizerSADEA(bounds);
s.CustomEvaluationFunction = @evaluateAntenna;
setMaxFunctionEvaluations(s, 200);
defineInitialPopulation(s, 10);
s.optimizeWithPlots(50);
bestData = s.getBestMemberData;
```

### TR-SADEA for High-Dimensional Problems

For 30+ design variables. Requires Statistics and Machine Learning Toolbox.

```matlab
s = OptimizerTRSADEA(bounds);
s.CustomEvaluationFunction = @evaluateAntenna;
s.optimizeWithPlots(100);
```

## Result Extraction

### Built-in optimize()

```matlab
[optAnt, optinfo] = optimize(ant, freq, "maximizeGain", vars, bounds, Iterations=50);
bestData = optinfo.getBestMemberData;
fprintf("Best fitness: %.4f\n", bestData.fitness);
fprintf("Converged: %d\n", optinfo.isConverged);
figure; optinfo.showConvergenceTrend;
```

### Optimizer Objects

```matlab
bestData = s.getBestMemberData;
optimizedVars = bestData.member;
bestFitness = bestData.fitness;
fprintf("Converged: %d\n", s.isConverged);
figure; s.showConvergenceTrend;
```

## Post-Optimization Validation

Always verify independently:

```matlab
figure; show(optAnt);
figure; impedance(optAnt, freqRange);
sParams = sparameters(optAnt, freqRange);
figure; rfplot(sParams);
figure; pattern(optAnt, freq);
```

## Iteration Guidelines

| Design Variables | Iterations | Expected Evaluations |
|-----------------|------------|---------------------|
| 2-3 | 30-50 | 40-80 |
| 4-6 | 50-100 | 70-140 |
| 7-15 | 100-200 | 130-260 |
| 16-30 | 200+ (TR-SADEA) | 250+ |

## How SADEA Works

SADEA builds a surrogate model from a small number of EM simulations, then searches efficiently. Initial phase runs ~m*N evaluations (N = design variables) to build the model. TR-SADEA adds local search for high-dimensional problems.

**Fitness sign:** For maximization, SADEA negates internally. Fitness plot trends downward as objective improves.

----

Copyright 2026 The MathWorks, Inc.
