# Improving Optimization Results

Systematic debugging guide for failed or poor-quality optimization results.

Doc reference: https://www.mathworks.com/help/optim/improving-results.html

## Debugging Workflow

When an optimization fails to converge or produces a poor solution, work through these steps in order:

### 1. Check Problem Formulation

**Common formulation errors:**

**Infeasible constraints:**
- Are the constraints mathematically consistent?
- Is the initial guess feasible?

**Test for feasibility:**
```matlab
% Problem-based
infeas_at_x0 = infeasibility(prob.Constraints, x0);
fprintf('Infeasibility at initial guess: %.3e\n', infeas_at_x0);

% Solver-based
[c0, ceq0] = nonlcon(x0);
fprintf('Inequality violations at x0: max = %.3e\n', max([c0; 0]));
fprintf('Equality violations at x0: max = %.3e\n', max(abs(ceq0)));
```

**Unbounded problems:**
- Does the objective have a finite minimum?
- Are there missing constraints that should bound the solution?

**Ill-defined objectives:**
- Does the objective function error at `x0`?
- Does it return `NaN` or `Inf` for some inputs?

**Feasibility-only solve (problem-based):**
```matlab
% Replace objective with a constant — solve() just seeks feasibility
probFeas = prob;
probFeas.Objective = 0;
[sol, ~, ef] = solve(probFeas, x0struct);
% ef > 0: constraints ARE compatible (bug is elsewhere)
% ef < 0 for NLP: may mean "couldn't reach feasible from THIS x0" — retry from other starts
```

**EnableFeasibilityMode (fmincon, smooth NLP):**
If the standard solve reports infeasible, try putting more effort into reaching feasibility:
```matlab
opts = optimoptions('fmincon', EnableFeasibilityMode=true, SubproblemAlgorithm="cg");
```
Confirm this option exists for the user's release with `optimoptions('fmincon')` before relying on it.

**Relaxation strategy (slack variables):**
If constraints appear infeasible, find which group conflicts:
```matlab
% Add slack s >= 0 to each inequality, minimize sum(s)
s = optimvar('s', nConstraints, 'LowerBound', 0);
probSlack = prob;
probSlack.Objective = sum(s);
% Relax: g(x) <= b becomes g(x) - s <= b
% Nonzero s_i at optimum → constraint i is part of the infeasibility
```

### 1b. NaN/Inf During Solve

If the solver produces NaN or Inf mid-run, the objective/constraint is undefined somewhere the solver stepped (e.g., `log`/`sqrt`/division by a variable that went ≤ 0).

**Fix:** Add bounds that keep arguments valid, and switch to the `sqp` algorithm — unlike the default `interior-point`, `sqp` evaluates only at points satisfying the bounds every iterate, so it won't step where `log`/`sqrt` are undefined.

**Important:** A bound *at* the singular value (`lb = 0` for `log(x)`) is not enough — the function is still undefined on the bound. Offset it: `lb = eps` or a small physical floor.

```matlab
options = optimoptions('fmincon', Algorithm='sqp');
% Ensure lb > 0 for log/sqrt arguments
lb(log_vars) = eps;
```

### 2. Check Scaling and Numerical Conditioning

**Poor scaling** is a top cause of convergence failure. Variables, objectives, and constraints should all be **O(1)** in magnitude.

**Diagnosis:**
- Are decision variables vastly different in scale? (e.g., `x1` in [0, 1] and `x2` in [1e6, 1e9])
- Does the objective vary by orders of magnitude across the feasible region?
- Do constraints have vastly different magnitudes?

**Fixes:**

**Rescale variables:**
```matlab
% Original: x in [0, 1e6]
% Scaled: y in [0, 1], x = 1e6 * y
% Reformulate objective and constraints in terms of y
```

**Rescale objective and constraints:**
```matlab
% If objective is O(1e8), divide by 1e8
% If constraint is A*x <= 1e-6, multiply by 1e6
```

**Adjust finite-difference step size:**
If gradients are inaccurate due to scaling:
```matlab
options = optimoptions('fmincon',FiniteDifferenceType="central");
```

**Condition number and definiteness check:**
For quadratic problems with `quadprog`, check the condition number and positive definiteness of `H`:
```matlab
cond_H = cond(H);
if cond_H > 1e12
    warning('Hessian is ill-conditioned (cond = %.3e). Consider rescaling.\n', cond_H);
end

% Check positive definiteness
try
    chol(H);
    fprintf('H is positive definite.\n');
catch
    warning('H is not positive definite. Check eigenvalues:\n');
    eig_H = eig(H);
    fprintf('  Min eigenvalue: %.3e\n  Max eigenvalue: %.3e\n', min(eig_H), max(eig_H));
    fprintf('A positive semi-definite or indefinite Hessian may cause stalling or divergence.\n');
end
```

### 3. Tune Solver Options and Algorithms

**Try a different algorithm:**

Most solvers support multiple algorithms. Consult the solver's documentation for available options. For example:

```matlab
% Example: try 'sqp' algorithm for fmincon
opts_sqp = optimoptions('fmincon', 'Algorithm', 'sqp');
[x, fval] = fmincon(fun, x0, A, b, Aeq, beq, lb, ub, nonlcon, opts_sqp);
```

**Increase iteration/evaluation limits (only if still progressing):**

Before raising limits, check if the solver is actually making progress — run with `Display='iter'` and watch whether the objective and `firstorderopt` are still decreasing. If they've gone flat for ~10+ iterations, more iterations won't help — the cause is scaling, formulation, or a wrong gradient. Only raise limits if the solver *is* still improving.

```matlab
options = optimoptions('fmincon', ...
    'MaxIterations', 1000, ...
    'MaxFunctionEvaluations', 5000);
```

**Hybrid function for solution polishing:**
For derivative-free solvers (`ga`, `gamultiobj`, `patternsearch`, `particleswarm`), use `HybridFcn` to refine the final solution with a gradient-based method:
```matlab
options = optimoptions('ga', 'HybridFcn', @fmincon);
```

**Adjust tolerances:**
```matlab
% Tighten for more accurate solution
options = optimoptions('fmincon', ...
    'OptimalityTolerance', 1e-8, ...
    'ConstraintTolerance', 1e-8, ...
    'StepTolerance', 1e-10);

% Loosen if struggling to converge
options = optimoptions('fmincon', ...
    'OptimalityTolerance', 1e-4, ...
    'ConstraintTolerance', 1e-4);
```

### 4. Try Different Initial Points

For **nonlinear problems**, the initial guess strongly affects:
- Which local minimum is found
- Whether the solver converges at all

**Strategies:**

**Manual exploration:**
Try several initial guesses based on domain knowledge:
```matlab
x0_candidates = [x0_default, x0_midpoint, x0_boundary, x0_random];
for i = 1:size(x0_candidates, 2)
    [x, fval, exitflag] = fmincon(fun, x0_candidates(:,i), ...);
    fprintf('Initial guess %d: exitflag=%d, fval=%.6f\n', i, exitflag, fval);
end
```

**Multi-start:**
Automatically run from multiple starting points and select the best. Choose the start-points based on the problem dimensionality, but not too large — never open-end a multi-start search:
```matlab
ms = MultiStart;
problem = createOptimProblem('fmincon', 'objective', fun, 'x0', x0, ...
    'Aineq', A, 'bineq', b, 'lb', lb, 'ub', ub, 'nonlcon', nonlcon, ...
    'options', optimoptions('fmincon'));
[x, fval] = run(ms, problem, 50);  % 50 random start points
```

For problem-based:
```matlab
ms = MultiStart;
[sol, fval] = solve(prob, x0, ms, 'MinNumStartPoints', 30);
```

**Global optimization:**
If the problem has many local minima and you need a global solution:
- `surrogateopt` — surrogate-based, good for expensive objectives
- `ga` — genetic algorithm, handles integer and nonlinear
- `particleswarm` — particle swarm, good for continuous problems
- `GlobalSearch` — multistart with clustering and basin-hopping

```matlab
opts = optimoptions('surrogateopt', ...
    'MaxFunctionEvaluations', 500, ...
    'MinSurrogatePoints', 10*(nvars+1));  % Increase initial random samples
[x, fval] = surrogateopt(fun, lb, ub, opts);
```

For `surrogateopt`, you can also provide initial points and pre-computed function values:
```matlab
opts = optimoptions('surrogateopt', 'InitialPoints', x0_matrix);
% where x0_matrix is a matrix with each row being an initial point
```

### 5. Verify Gradient Accuracy

Inaccurate gradients (when using finite differences or analytical gradients) can cause convergence failure.

**Check gradient accuracy:**
Use `checkGradients` to verify analytical gradients. **Note:** `checkGradients` requires a named function (not an anonymous function) that returns `[f, grad]` as two outputs:
```matlab
% Define objective function that returns both value and gradient
function [f, grad] = myObjective(x)
    f = x(1)^2 + 2*x(2)^2;
    grad = [2*x(1); 4*x(2)];
end

% Check gradients at initial point
[valid, err] = checkGradients(@myObjective, x0, Display="on");
if ~valid
    warning('Gradient check failed. Review analytical gradient implementation.');
end
```

For constraint gradients, use `IsConstraint=true`:
```matlab
[valid, err] = checkGradients(@myConstraints, x0, IsConstraint=true, Display="on");
```

If analytical gradients are incorrect, either:
- Fix coding errors in the gradient function
- Switch to finite differences if the scale is very large or small

For finite-difference gradients with poor accuracy due to scaling:
```matlab
options = optimoptions('fmincon', 'FiniteDifferenceType', 'central');
```
Central differences are more accurate than forward differences but require twice as many function evaluations.

For problem-based, let automatic differentiation compute gradients (preferred over manual finite differences).

### 6. Inspect Solver Progress

Enable iterative display to monitor convergence:

```matlab
options = optimoptions('fmincon', 'Display', 'iter');
```

Use `'PlotFcn'` to visualize solver progress:

```matlab
options = optimoptions('fmincon', ...
    'Display', 'iter', ...
    'PlotFcn', {@optimplotfval, @optimplotfirstorderopt, @optimplotconstrviolation});
```

**What to look for:**
- **Oscillation:** Objective or constraint violations oscillate without improving — consider tightening tolerances or switching algorithm
- **Stalling:** Objective plateaus for many iterations — may be at a local minimum, or step size is too small
- **Early termination:** Solver stops after just a few iterations — check if initial guess is already optimal or if constraints are immediately violated

**Custom output function:**
```matlab
options = optimoptions('fmincon', 'OutputFcn', @myOutputFcn);

function stop = myOutputFcn(x, optimValues, state)
    stop = false;
    if strcmp(state, 'iter')
        fprintf('Iter %d: fval=%.6f, constrViolation=%.3e\n', ...
            optimValues.iteration, optimValues.fval, optimValues.constrviolation);
    end
end
```

### 7. Validate Regularization

If regularization was introduced (e.g., Tikhonov, L2 penalty, smoothing), verify it actually helps:

1. **Report the baseline:** Solve and record the unregularized metric first.
2. **Test at least one nonzero level:** Try one or more nonzero regularization parameters.
3. **Publish the best defensible result:** Keep the regularization level with the best metric you can defend.
4. **If regularization doesn't help, say so:** If no regularization level improves the defended metric, keep the unregularized result and state that explicitly.

Do not claim a larger regularization parameter is better just because the solution looks smoother. Publish the result that validates best under the metric you can defend.

```matlab
lambdas = [0, 1e-4, 1e-3, 1e-2];
bestIdx = 1;
bestMetric = inf;
for k = 1:numel(lambdas)
    % Solve with regularization level lambdas(k)
    % ...
    metric = computeValidationMetric(solution);
    if metric < bestMetric
        bestMetric = metric;
        bestIdx = k;
    end
end
fprintf("Best regularization: lambda = %.1e (metric = %.4f)\n", lambdas(bestIdx), bestMetric);
```

### 8. Integer Solve Too Slow (MILP/MIQP)

Integer solve time is dominated by the **formulation**, not solver options. Tighten it:

- **Smaller big-M constants** — oversized M values weaken LP relaxations and explode the branch-and-bound tree
- **Tighter variable bounds** — every tighter bound prunes branches
- **Valid inequalities** — extra constraints that don't cut feasible integer points but tighten the relaxation
- **Warm-start** from a known feasible solution where supported

Set a **relative-gap or time limit** and accept the best incumbent when a proven optimum isn't worth the wait:
```matlab
options = optimoptions('intlinprog', ...
    RelativeGapTolerance=0.01, ...  % accept 1% gap
    MaxTime=600);                    % or 10-minute cap
```

If the problem is MIQP/MINLP with no exact solver (`intlinprog` is linear-only), reformulate to MILP or switch to `ga`/`surrogateopt` (heuristic — report it as such).

### 9. Nonsmooth Objective Detected

If the objective or constraints contain `abs`, `max`, `min`, sorting, or `if` branches, gradient-based solvers will struggle (they assume smoothness).

**Options:**
- **Reformulate** the nonsmooth term into a smooth/LP/QP form (e.g., minimax → epigraph trick, abs → auxiliary variables). This often turns the problem convex.
- **Switch to a derivative-free solver** (`patternsearch`, `surrogateopt`) that doesn't need gradients.

Reformulating is usually better — it moves the problem to an easier class with stronger guarantees.

## Checklist Summary

When debugging a failed optimization:

- [ ] **Formulation:** Is the problem well-posed? Are constraints feasible?
- [ ] **Scaling:** Are variables, objective, and constraints O(1)?
- [ ] **Algorithm:** Have you tried alternative algorithms?
- [ ] **Tolerances:** Are they appropriate for your problem?
- [ ] **Initial guess:** Have you tried multiple starting points?
- [ ] **Gradients:** Are finite-difference gradients accurate?
- [ ] **Progress:** Have you inspected the solver's iteration history?

Work through this list systematically. Most convergence issues fall into the first three categories.

---
Copyright 2026 The MathWorks, Inc.
