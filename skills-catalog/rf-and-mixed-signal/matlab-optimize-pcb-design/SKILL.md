---
name: matlab-optimize-pcb-design
description: "Optimize RF PCB dimensions for bandwidth, return loss, or area via patternsearch and surrogateopt with constraints. TRIGGER: user asks to optimize an RF PCB component for performance (bandwidth, return loss, insertion loss, area) or apply constraints to a design. Invoke BEFORE writing optimization code — RF PCB Toolbox has a built-in optimize() function that differs from generic fmincon/ga approaches. SKIP: designing a component from scratch without an optimization objective (use the specific matlab-design-pcb-* skill), EM analysis without optimization (use matlab-analyze-em), material/stackup setup only (use matlab-manage-pcb-material)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Optimizing RF PCB Designs

## Critical: Always Use optimize() First

**The RF PCB Toolbox provides a built-in `optimize()` function that handles all standard optimization scenarios.** Always use it as the first approach — do NOT write manual optimization loops with `patternsearch`, `surrogateopt`, `fmincon`, or `ga` called directly unless `optimize()` is demonstrably insufficient for the specific problem.

## When to Use

- Tuning filter, coupler, or splitter dimensions for return loss, bandwidth, or area
- Running `optimize()` on catalog objects with bounds and constraints
- Using SADEA/TR-SADEA, patternsearch, or surrogateopt via the `optimize()` interface
- Defining custom objective functions over S-parameter responses

## When NOT to Use

- Designing components from scratch — use `matlab-design-pcb-filter`, `matlab-design-pcb-coupler`, etc. first, then optimize
- Running EM analysis without optimization — use `matlab-analyze-em`
- Parameter sweeps without an objective — just loop over `sparameters` calls directly
- Antenna-only optimization without PCB context — use Antenna Toolbox docs

## Typical Workflow

1. **Before:** A design skill (`matlab-design-pcb-filter`, `matlab-design-pcb-txline`, etc.) — create the initial component; `matlab-analyze-em` — baseline S-parameters
2. **This skill:** Define objective, bounds, constraints; run `optimize()`
3. **After:** `matlab-analyze-em` — validate optimized design → `matlab-integrate-pcb-circuit` — cascade into system → `matlab-write-pcb-layout` — export Gerber

## Quick Reference

| Task | Code |
|------|------|
| Design at frequency | `obj = design(ObjectType, fc)` |
| Optimize | `optObj = optimize(obj, freq, objective, props, bounds, solver)` |
| With constraints | `optimize(..., 'Constraints', constraints)` |
| With options | `optimize(..., 'OptimizerOptions', opts)` |

## Algorithm Overview

| Algorithm | Source | Best For | Typical Time |
|---|---|---|---|
| `sadea` | Antenna Toolbox (SADEA) | Default global search, few EM evaluations | 5--30 min |
| `trsadea` | Antenna Toolbox (TR-SADEA) | Trust-region variant, better local refinement | 5--30 min |
| `patternsearch` | Global Optimization Toolbox | Derivative-free, smooth/noisy EM objectives, fine-tuning | 2--15 min |
| `surrogateopt` | Global Optimization Toolbox | Expensive black-box functions, many variables, global optimum | 10--60 min |

- **Start with SADEA** -- it requires no additional toolbox beyond Antenna Toolbox and handles most RF/PCB optimization problems well.
- **Use `patternsearch` for fine-tuning** -- after SADEA finds a good region, refine with patternsearch starting from the SADEA result.
- **`surrogateopt` for expensive models** -- builds a surrogate model and is more sample-efficient when each EM solve is costly.

## Timing and Practical Considerations

- **MoM simulation per evaluation**: 2--30 seconds for simple components, minutes for high-order filters
- **Behavioral mode**: Use `pcbElement(comp, Behavioral=true)` for fast analytical evaluations during optimization sweeps
- **Iteration budget**: Set `MaxIterations` to 20--50 when running interactively to stay responsive; use 100--200 for batch runs
- **Parallel computing**: Set `UseParallel=true` if Parallel Computing Toolbox is available for significant speedup with patternsearch and surrogateopt

## design() — Initial Sizing

The `design` function sizes any catalog component for a target frequency:

```matlab
ws = design(wilkinsonSplitter, 3e9);
bl = design(couplerBranchline, 5e9);
fh = design(filterHairpin, 2.4e9);
ms = design(microstripLine, 3e9);
```

This produces a starting point for subsequent optimization. All geometric parameters are auto-computed for the target frequency.

## optimize() Syntax

```matlab
optObj = optimize(obj, freq, objective, properties, bounds, solver, ...
    'Constraints', constraints, 'OptimizerOptions', opts)
```

| Argument | Type | Description |
|----------|------|-------------|
| `obj` | Object | Catalog object (initial design) |
| `freq` | Scalar or vector | Single frequency or frequency vector for optimization |
| `objective` | String | Built-in or custom objective function name |
| `properties` | Cell array | Property names to vary |
| `bounds` | 2-element cell | `{[lower1 lower2 ...]; [upper1 upper2 ...]}` |
| `solver` | String | `'patternsearch'`, `'surrogateopt'`, `'sadea'`, or `'trsadea'` |
| `constraints` | Struct | S-parameter constraints (optional NV pair) |
| `opts` | optimoptions | Optimizer options object created with `optimoptions()` |

## Built-in Objectives

| Objective String | Minimizes/Maximizes |
|-----------------|---------------------|
| `"minimizeArea"` | Minimizes board area |
| `"maximizeBandwidth"` | Maximizes -10 dB return loss bandwidth |
| `"maximizeReturnLoss"` | Maximizes worst-case return loss |
| `"minimizeBandwidth"` | Narrows the passband |

## Example: Minimize Area with Constraints

```matlab
obj = design(wilkinsonSplitter, 3e9);

props = {'SplitLineLength', 'SplitLineWidth', 'Resistance', ...
         'PortLineLength', 'GroundPlaneWidth'};
bounds = {[10e-3 1e-3  50 2e-3  10e-3];    % Lower bounds
          [50e-3 8e-3 100 20e-3 50e-3]};    % Upper bounds (cell array!)

constraints.S11 = '<-10';
constraints.S21 = '>-4';
constraints.S22 = '<-10';
constraints.S12 = '>-4';

optObj = optimize(obj, 3e9, "minimizeArea", props, bounds, ...
    "patternsearch", 'Constraints', constraints);

show(optObj);
sp = sparameters(optObj, linspace(1e9, 5e9, 51), 'SweepOption', 'interp');
rfplot(sp);

% Verify area from shapes
s = shapes(optObj);           % Returns struct of shapes by layer
boardArea = area(s.GroundPlane);
fprintf('Optimized board area: %.2f mm²\n', boardArea * 1e6);
```

### Querying Area After Optimization

For catalog objects, use `shapes()` to extract the individual layer shapes, then `area()`:

```matlab
s = shapes(optObj);              % Catalog object → struct with named shapes
boardArea = area(s.GroundPlane); % Area of the board outline shape
```

For `pcbComponent`, shapes are in the `Layers` property:

```matlab
pcb = pcbComponent(optObj);
boardArea = area(pcb.BoardShape);
```

## Example: Maximize Return Loss for Hairpin Filter

```matlab
f = design(filterHairpin, 3e9);

props = {'CoupledLineLength', 'CoupledLineWidth', 'CoupledLineSpacing'};
bounds = {[5e-3 0.5e-3 0.1e-3];
          [40e-3 5e-3 2e-3]};

optF = optimize(f, 3e9, "maximizeReturnLoss", props, bounds, "patternsearch");
show(optF);
```

## S-Parameter Constraints

Constraints use string format `'<threshold'` or `'>threshold'` (in dB):

```matlab
constraints.S11 = '<-15';    % S11 below -15 dB
constraints.S21 = '>-1';     % S21 above -1 dB (low insertion loss)
constraints.S31 = '<-20';    % Isolation below -20 dB
```

Any S-parameter index can be constrained. The optimizer evaluates constraints across the entire frequency vector.

## Custom Objective Functions

For objectives beyond the built-in set, provide a function handle:

```matlab
% Objective function signature: cost = objFcn(obj, freq)
function cost = myObjective(obj, freq)
    sp = sparameters(obj, freq, 'SweepOption', 'interp');
    S21 = squeeze(sp.Parameters(2,1,:));
    S11 = squeeze(sp.Parameters(1,1,:));
    % Minimize worst-case insertion loss while maintaining match
    cost = -min(20*log10(abs(S21)));  % Negative because we maximize |S21|
end

optObj = optimize(obj, fc, @myObjective, props, bounds, "patternsearch");
```

## Surrogate-Based Optimization

For expensive EM solves, surrogate optimization builds a model and is more sample-efficient:

```matlab
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', 50);
optObj = optimize(obj, 3e9, "maximizeReturnLoss", props, bounds, ...
    "surrogateopt", 'OptimizerOptions', opts);
```

## Solver Options

The `OptimizerOptions` NV pair takes an `optimoptions` object for the chosen solver:

```matlab
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', 100, 'Display', 'off');
optObj = optimize(obj, fc, objective, props, bounds, 'patternsearch', ...
    'OptimizerOptions', opts);
```

Available solvers: `'patternsearch'`, `'surrogateopt'`, `'sadea'`, `'trsadea'`.

For `sadea`/`trsadea`, pass a struct instead of an `optimoptions` object:

```matlab
opts = struct('MaxIterations', 50, 'UseParallel', false);
optObj = optimize(obj, fc, objective, props, bounds, 'sadea', ...
    'OptimizerOptions', opts);
```

## Nested Property Optimization

Optimize nested properties using dot notation:

```matlab
% Optimize substrate thickness along with width
optObj = optimize(ml, 2.4e9, 'maximizeReturnLoss', ...
    {'Width', 'Substrate.Thickness'}, ...
    {0.001 0.5e-3; 0.01 3e-3}, 'sadea');
```

## Decision: optimize() vs Manual Loop

**Always use `optimize()`.** It wraps all four solvers (sadea, trsadea, patternsearch, surrogateopt) internally. There is no performance or capability advantage to calling these solvers directly. The only scenario where direct solver usage is justified is a non-S-parameter, non-EM objective function that `optimize()` cannot express (extremely rare).

## Optimization Workflow

1. **Design initial geometry**: `obj = design(Type, fc)`
2. **Select properties to vary**: Choose 3-6 most impactful dimensions
3. **Set reasonable bounds**: ±50% of initial values is a good starting range
4. **Define constraints**: Ensure feasibility (S11 < -10 dB at minimum)
5. **Choose solver**: Start with `'sadea'`; use `'patternsearch'` for refinement
6. **Run optimize()**: `optObj = optimize(obj, freq, objective, props, bounds, solver)`
7. **Validate**: Check optimized design meets specs across full band

## Antenna Objects with optimize()

The same `optimize()` function works on antenna objects with antenna-specific objectives:

| Objective | Description |
|---|---|
| `'maximizeGain'` | Maximize antenna gain at target frequency |
| `'frontToBackRatio'` | Maximize front-to-back lobe ratio |
| `'maximizeSLL'` | Maximize sidelobe level suppression |

```matlab
ant = design(patchMicrostrip, 2.4e9);
optAnt = optimize(ant, 2.4e9, 'maximizeGain', ...
    {'Length', 'Width'}, {[0.02 0.02]; [0.06 0.06]}, 'sadea', ...
    'OptimizerOptions', struct('MaxIterations', 100));
pattern(optAnt, 2.4e9);
```

These objectives are for antenna objects only. RF PCB catalog objects use the objectives in the Built-in Objectives table above.

## Fallback: Direct Solver Usage (Last Resort)

Direct solver calls are almost never needed — `optimize()` already wraps patternsearch, surrogateopt, sadea, and trsadea. Only bypass `optimize()` for non-EM objectives it cannot express (e.g., multi-objective Pareto front via `paretosearch`).

```matlab
% Extremely rare: multi-objective Pareto (not supported by optimize())
objFcn = @(x) [emObjective(obj, x, freq); thermalObjective(obj, x)];
[xopt, fval] = paretosearch(objFcn, nVars, [], [], [], [], lb, ub);
```

## Design Iteration Patterns

### Variable Naming Conventions

Use these names consistently across optimization scripts and iterative design loops:

```matlab
sub    % dielectric substrate
cond   % metal conductor
ml     % microstripLine
sl     % stripLine
cpw    % coplanarWaveguide
cm     % coupledMicrostripLine
filt   % any filter object
coup   % any coupler object
split  % any splitter object
comp   % pcbComponent
sp     % sparameters result
freq   % frequency vector
```

### Metric Extraction Patterns

Always extract numerical summaries after analysis -- tools like Amp cannot interpret MATLAB figures.

```matlab
sp = sparameters(comp, freq, 'SweepOption', 'interp');
S = sp.Parameters;
s21_dB = 20*log10(abs(squeeze(S(2,1,:))));
s11_dB = 20*log10(abs(squeeze(S(1,1,:))));
freq_GHz = sp.Frequencies/1e9;

% Key metrics
insertionLoss = max(s21_dB);
returnLoss = min(s11_dB);
[~, idx] = max(s21_dB);
centerFreq = freq_GHz(idx);

% 3 dB bandwidth
aboveCutoff = find(s21_dB >= max(s21_dB) - 3);
bw3dB = NaN;
if ~isempty(aboveCutoff)
    bw3dB = (freq_GHz(aboveCutoff(end)) - freq_GHz(aboveCutoff(1))) * 1e3;
end

fprintf('Center: %.3f GHz | IL: %.2f dB | RL: %.2f dB | BW: %.0f MHz\n', ...
    centerFreq, insertionLoss, returnLoss, bw3dB);
```

### Before/After Comparison Workflow

```matlab
% 1. Save baseline metrics before adjusting
oldIL = insertionLoss;
oldBW = bw3dB;

% 2. Adjust property (or run optimize)
filt.FilterOrder = 5;  % was 3

% 3. Re-analyze and extract new metrics
sp_new = sparameters(filt, freq, 'SweepOption', 'interp');
s21_new = 20*log10(abs(squeeze(sp_new.Parameters(2,1,:))));
newIL = max(s21_new);
aboveCutoff = find(s21_new >= max(s21_new) - 3);
newBW = (freq_GHz(aboveCutoff(end)) - freq_GHz(aboveCutoff(1))) * 1e3;

% 4. Compare
fprintf('Before: IL=%.2f dB, BW=%.0f MHz\n', oldIL, oldBW);
fprintf('After:  IL=%.2f dB, BW=%.0f MHz\n', newIL, newBW);
```

### Design Adjustment Guide

| Problem | Property to Adjust | Direction |
|---|---|---|
| Passband too wide | `FilterOrder` / `Spacing` | Increase order / decrease spacing |
| Passband too narrow | `Spacing` | Increase |
| Insertion loss too high | `Conductor` thickness / `FilterOrder` | Use real metal / reduce order |
| Center freq shifted | Re-run `design(filt, newFreq)` | -- |
| Z0 too high | `Width` | Increase |
| Z0 too low | `Width` | Decrease |
| Coupling too tight | `Spacing` | Increase |
| Coupling too loose | `Spacing` | Decrease |

## Pitfalls

1. **Do NOT write manual optimization loops.** Never call `patternsearch`, `surrogateopt`, `fmincon`, or `ga` directly with a hand-written objective function wrapping `sparameters`. The built-in `optimize()` already wraps these solvers and handles property assignment, bounds checking, and S-parameter evaluation internally. Writing a manual loop duplicates this logic incorrectly and produces brittle code.

2. **EM solve cost**: Each optimization iteration requires a full EM solve. Use interpolating sweep for faster convergence.

3. **Bound width**: Too-wide bounds increase search space exponentially. Start with ±30-50% of initial values and narrow after first pass.

4. **Initial feasibility**: If the initial design violates constraints, the optimizer may struggle. Always start from a `design()`-generated initial point.

5. **Property dependencies**: Some properties are coupled (e.g., ArmLength and PortLineLength overlap spatially). Choose independent properties to avoid infeasible geometries.

6. **Convergence check**: Pattern search may stall at local minima. Run multiple times with different initial meshes or use `surrogateopt` for global exploration.

7. **Requires toolbox licenses**: `patternsearch` and `surrogateopt` require Global Optimization Toolbox. `sadea` and `trsadea` require Antenna Toolbox.

8. **Frequency can be scalar or vector**: `optimize` accepts both a single frequency and a frequency vector. Vectors evaluate the objective across the band but increase solve time per iteration.

9. **Bounds are a cell array**: Pass bounds as `{[lb1 lb2 ...]; [ub1 ub2 ...]}`, not a numeric matrix. Each cell element is a row vector.

10. **OptimizerOptions format depends on solver**: For `patternsearch`/`surrogateopt`, pass `optimoptions('patternsearch', ...)`. For `sadea`/`trsadea`, pass a struct: `struct('MaxIterations', 50, 'UseParallel', false)`.

11. **Vector properties expand bounds count.** After `design()`, some properties become vectors (e.g., `filterCoupledLine.CoupledLineLength` is a 4-element vector for a 4-section filter). Bounds must match the **total scalar count** across all properties. If you optimize `{'CoupledLineLength','CoupledLineSpacing'}` and each is a 4-element vector, bounds need 8 lower and 8 upper values — not 2. Check `numel(obj.PropertyName)` before setting bounds.

12. **Interp sweep requires ≥2 frequencies.** `sparameters(obj, scalarFreq, 'SweepOption', 'interp')` errors — the interpolating solver needs at least 2 frequency points. When validating baseline S-parameters outside of `optimize()`, use a frequency vector: `sparameters(obj, linspace(f1, f2, N), 'SweepOption', 'interp')`.

13. **Variables at bounds suggest wider search.** If an optimized property converges to exactly the lower or upper bound, the true optimum may lie outside the search region. Re-run with widened bounds in that direction.

14. **Constraint tolerance.** The optimizer may accept solutions that violate constraints by a small margin (~0.3 dB). If strict compliance is required, tighten constraints slightly (e.g., use `'<-10.5'` when the spec is -10 dB).

## Related Skills

- `matlab-design-pcb-filter` — Filter objects to optimize
- `matlab-design-pcb-coupler` — Coupler/splitter objects to optimize
- `matlab-analyze-em` — Understanding S-parameter results

----

Copyright 2026 The MathWorks, Inc.
