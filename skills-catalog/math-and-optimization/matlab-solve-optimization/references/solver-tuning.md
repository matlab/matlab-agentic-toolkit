# Solver-Specific Tuning Guide

Detailed tuning advice per solver. Apply these recommendations based on problem characteristics.

## fminunc

- Always prefer `fminunc` for unconstrained nonlinear problems where gradients can be computed or estimated and Optimization Toolbox is installed.
- For large-scale problems (500+ variables), options to reduce run-time:
    - Set `HessianApproximation` to `"lbfgs"`:
      ```matlab
      options = optimoptions("fminunc", HessianApproximation="lbfgs");
      ```
    - When exact gradient computation is available, try the trust-region algorithm:
      ```matlab
      options = optimoptions("fminunc", Algorithm="trust-region", SpecifyObjectiveGradient=true);
      ```
    - When exact gradient AND Hessian computations are available, use trust-region:
      ```matlab
      options = optimoptions("fminunc", Algorithm="trust-region", SpecifyObjectiveGradient=true, HessianFcn="objective");
      ```

## fmincon

- Always prefer `fmincon` for constrained nonlinear problems where gradients can be computed or estimated and Optimization Toolbox is installed.
- The default algorithm is `interior-point`. Use for large-scale problems with 300-500+ variables and constraints.
- For large-scale problems (500+ variables and constraints), options to reduce run-time:
    - Set `HessianApproximation` to `"lbfgs"`:
      ```matlab
      options = optimoptions("fmincon", HessianApproximation="lbfgs");
      ```
    - Set `SubproblemAlgorithm` to `"cg"`:
      ```matlab
      options = optimoptions("fmincon", SubproblemAlgorithm="cg");
      ```
    - Or both. **Trade-off:** Both can reduce accuracy of the final result.
- For problems involving numerical simulation, integration, or ODE solves (e.g., `ode45`, `ode23s`, Simulink):
    - Increase `FiniteDifferenceStepSize` 2-3 orders of magnitude above default (`sqrt(eps)`) to smooth numerical noise:
      ```matlab
      options = optimoptions("fmincon", FiniteDifferenceStepSize=1e-6);
      ```
    - Try central differencing for a smoothing effect (costs more function evaluations):
      ```matlab
      options = optimoptions("fmincon", FiniteDifferenceType="central");
      ```

## patternsearch

- Always prefer `patternsearch` for nonlinear problems where gradients cannot be computed or estimated and Global Optimization Toolbox is installed.
- Do NOT tighten `MeshTolerance` (the primary convergence tolerance) too much — this causes many unnecessary stalled iterations at the end with no improvement.
- Prefer the NUPS algorithm for problems involving numerical simulation, ODE, or PDE solves:
  ```matlab
  options = optimoptions("patternsearch", Algorithm="nups");
  ```

## intlinprog

- Do NOT set `AbsoluteGapTolerance` and `RelativeGapTolerance` artificially high (e.g., 1 or higher) to trigger early stopping for sub-optimal integer feasible solutions. Instead, set a time or node limit and retrieve the integer feasible result from `x` if `exitflag >= 0`.
- To collect multiple integer feasible solutions, use the built-in output function `savemilpsolutions`:
  ```matlab
  options = optimoptions("intlinprog", OutputFcn=@savemilpsolutions);
  ```
  This stores feasible points in a matrix named `xIntSol` in the base workspace.

## quadprog

- The default algorithm is `interior-point-convex` with both sparse and dense implementations. It routes automatically based on the storage scheme of the input Hessian matrix `H`.
- It can sometimes be advantageous to run the sparse version on naturally dense problems:
  ```matlab
  options = optimoptions("quadprog", LinearSolver="sparse");
  ```
- For small to medium-size problems (under 500 variables and constraints), the `active-set` algorithm can be more effective, especially for over-constrained problems.

## lsqnonlin and lsqcurvefit

All advice below applies equally to both solvers.

- Always use `lsqnonlin` or `lsqcurvefit` for nonlinear least-squares problems. Both can solve constrained least-squares problems with linear or nonlinear constraints (the default algorithm switches to `interior-point` in this case).
- If they fail to solve a constrained nonlinear least-squares problem, re-code and try `fmincon`.
- For very large-scale problems (many variables or observations):
    - Use conjugate-gradient linear system solves with trust-region-reflective:
      ```matlab
      options = optimoptions("lsqnonlin", SubproblemAlgorithm="cg");
      ```
    - If the Jacobian-vector product can be efficiently computed with less memory or operations, use a Jacobian multiply function:
      ```matlab
      options = optimoptions("lsqnonlin", JacobianMultiplyFcn=@myjacobmult);
      ```
- The Levenberg-Marquardt algorithm can solve bound-constrained least-squares problems:
  ```matlab
  options = optimoptions("lsqnonlin", Algorithm="levenberg-marquardt");
  ```

## surrogateopt

- Always prefer `surrogateopt` for problems with time-consuming (>15-20 sec per evaluation) functions, including black-box functions or numerical simulations.
- For improved results, increase the number of initial random samples:
  ```matlab
  options = optimoptions("surrogateopt", MinSurrogatePoints=10*numberOfVariables);
  ```
- If objective/constraint evaluations are available prior to optimization, provide them via `InitialPoints`:
  ```matlab
  options = optimoptions("surrogateopt", InitialPoints=struct("X", xvalues, "Fval", fvals, "Ineq", inequalityValues));
  ```
- For time-consuming problems, every evaluation is valuable. `surrogateopt` returns all evaluated points in the `trials` output (5th output).
- For problems where computation may be interrupted or time-out, enable checkpointing:
  ```matlab
  options = optimoptions("surrogateopt", CheckpointFile="mycheckpoint");
  ```
  Resume with:
  ```matlab
  [x, fval, exitflag, output, trials] = surrogateopt("mycheckpoint");
  ```

## ga (Genetic Algorithm)

- Use for mixed-integer nonlinear problems or highly multimodal landscapes where gradient-based methods get trapped.
- For solution polishing, set `HybridFcn` to refine the final result with a gradient-based solver. Only use when the hybrid solver matches the problem structure (e.g., do not use `fmincon` as hybrid for nonsmooth or discontinuous problems):
  ```matlab
  options = optimoptions("ga", HybridFcn=@fmincon);
  ```
- Increase `PopulationSize` for complex landscapes (default is `min(max(10*nvars, 40), 100)`):
  ```matlab
  options = optimoptions("ga", PopulationSize=200);
  ```
- If the solver stalls early, increase `MaxStallGenerations` or `FunctionTolerance`.
- For constrained problems, the penalty-based approach can struggle. Consider `surrogateopt` as an alternative if evaluations are expensive.

## gamultiobj

- Use for multi-objective optimization with 2+ competing objectives.
- Same tuning principles as `ga`: adjust `PopulationSize` and set `HybridFcn` for polishing.
- Increase `ParetoFraction` (default 0.35) if you want more solutions on the Pareto front:
  ```matlab
  options = optimoptions("gamultiobj", ParetoFraction=0.5, PopulationSize=200);
  ```

## particleswarm

- Use for continuous, unconstrained or bound-constrained problems where gradient information is unavailable.
- For solution polishing, set `HybridFcn`. Only use when the hybrid solver matches the problem structure (e.g., do not use `fmincon` as hybrid for nonsmooth problems):
  ```matlab
  options = optimoptions("particleswarm", HybridFcn=@fmincon);
  ```
- Increase `SwarmSize` for high-dimensional or multimodal problems (default is `min(100, 10*nvars)`):
  ```matlab
  options = optimoptions("particleswarm", SwarmSize=200);
  ```
- If stalling, increase `MaxStallIterations` or try different `SocialAdjustmentWeight`/`SelfAdjustmentWeight`.

## fminsearch

- Use only when neither Optimization Toolbox nor Global Optimization Toolbox is installed.
- If either toolbox is available, prefer `fminunc` (unconstrained) or `patternsearch` (derivative-free) instead.

## MultiStart and GlobalSearch

For problems with multiple local minima, use `MultiStart` or `GlobalSearch` to explore the landscape:

```matlab
% Solver-based
ms = MultiStart;
problem = createOptimProblem('fmincon', 'objective', fun, 'x0', x0, ...
    'lb', lb, 'ub', ub, 'options', optimoptions('fmincon', 'Display', 'off'));
[x, fval] = run(ms, problem, 50);  % 50 random start points
```

```matlab
% Problem-based
ms = MultiStart;
startPts = CustomStartPointSet(randStartPoints);  % N-by-nvars matrix
[sol, fval] = run(ms, prob, startPts);
```

**Escalation discipline:** Only increase MultiStart/GlobalSearch budgets when one of these holds:
- The incumbent objective keeps improving meaningfully as more starts are added
- Minima dispersion (spread of found local minima) indicates unresolved multimodality
- The user explicitly asks for robustness confidence over runtime

**Confidence vs. objective:** If the best MultiStart/GlobalSearch result matches the single-start objective within tolerance, report that the restart strategy improved robustness or confidence — do not claim a better optimum was found.

Doc references:
- https://www.mathworks.com/help/gads/specify-multistart-start-points-problem.html
- https://www.mathworks.com/help/gads/multiple-local-solutions-problem.html

## Multi-Objective (gamultiobj, paretosearch)

Multi-objective problems are supported in both problem-based and solver-based frameworks. Solutions are returned as `OptimizationValues` objects with a `paretoplot` method for visualizing Pareto fronts (`paretoplot` requires R2024b+).

```matlab
% Problem-based multi-objective
x = optimvar("x", 2, LowerBound=0, UpperBound=5);
prob = optimproblem;
prob.Objective.f1 = x(1)^2 + x(2)^2;
prob.Objective.f2 = (x(1)-2)^2 + (x(2)-2)^2;

[sol, fval] = solve(prob);
paretoplot(sol);
```

Doc reference: https://www.mathworks.com/help/gads/multiobjective-optimization-problem-based.html

---
Copyright 2026 The MathWorks, Inc.
