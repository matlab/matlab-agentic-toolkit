# Optimization Result Validation Checklist

Quick reference for interpreting solver outputs, exitflags, and common validation patterns.

Doc reference: https://www.mathworks.com/help/optim/solver-outputs-and-iterative-display.html

## Exitflag Interpretation

Exitflag values indicate solver termination status. Meanings vary slightly by solver but follow common patterns:

### Positive Exitflags (Success)

| Exitflag | Meaning | Applies to |
|----------|---------|------------|
| `1` | First-order optimality conditions satisfied (gradient-based) or convergence tolerance met (derivative-free) | Most solvers |
| `2` | Change in `x` or `fval` below tolerance | `fmincon`, `fminunc`, `lsqnonlin`, `patternsearch` |
| `3` | Change in objective below tolerance, or mesh/poll below tolerance | `fmincon`, `patternsearch`, `ga` |
| `4` | Search direction magnitude below tolerance | `fmincon` |
| `5` | Directional derivative below tolerance | `fmincon` |

### Zero Exitflag (Limit Reached)

| Exitflag | Meaning |
|----------|---------|
| `0` | Maximum iterations or function evaluations reached without convergence |

**Action:** Check if solution is "good enough" despite not converging. If not, increase `MaxIterations` or `MaxFunctionEvaluations`.

### Negative Exitflags (Failure)

| Exitflag | Meaning | Common Causes |
|----------|---------|---------------|
| `-1` | Solver stopped by output function or plot function | User-defined `OutputFcn` returned `stop = true` |
| `-2` | No feasible point found | Infeasible constraints, inconsistent bounds |
| `-3` | Problem is unbounded | Objective decreases without bound; missing constraints |
| `-5` | Hessian not positive definite (for `quadprog`) | Problem is not convex; check formulation |

**Solver-specific negative exitflags:**
- `intlinprog`: `-2` = no feasible point, `-3` = root LP unbounded, `-9` = time limit exceeded
- `surrogateopt`: `-1` = output function stop, `-5` = time or objective limit reached
- `particleswarm`: `-2` = bounds inconsistent, `-3` = `SwarmSize` too small, `-4` = stall iterations reached

## Key Output Metrics

### All Solvers
- `output.iterations` — Number of iterations taken
- `output.funcCount` — Number of objective function evaluations
- `output.message` — Human-readable termination message (always print this!)

### Gradient-Based Solvers (`fmincon`, `fminunc`, `lsqnonlin`, etc.)
- `output.firstorderopt` — First-order optimality measure (should be < `OptimalityTolerance`, typically 1e-6)
- `output.constrviolation` — Maximum constraint violation (should be < `ConstraintTolerance`, typically 1e-6)
- `output.stepsize` — Size of final step
- `output.algorithm` — Algorithm used (e.g., `'interior-point'`, `'sqp'`)

**Validation pattern:**
```matlab
if output.firstorderopt > 1e-3
    warning('First-order optimality is large (%.3e) — may not have converged to local minimum.\n', output.firstorderopt);
end
if output.constrviolation > 1e-6
    warning('Constraint violation is %.3e — solution may be infeasible.\n', output.constrviolation);
end
```

### Derivative-Free Solvers

**`patternsearch`:**
- `output.meshsize` — Final mesh size (smaller = more refined search)
- `output.pollmethod` — Poll method used

**`surrogateopt`:**
- `output.elapsedtime` — Total time elapsed
- `output.funccount` — Function evaluations (important for expensive functions)
- `output.rngstate` — RNG state for reproducibility

**`ga`, `particleswarm`:**
- `output.generations` — Number of generations
- `output.stallgenerations` — Generations without improvement (if this equals `MaxStallGenerations`, solver stopped due to stall)

**Validation pattern:**
```matlab
% For patternsearch
if output.meshsize > 1e-3
    warning('Mesh size is still large (%.3e) — may not be converged. Consider tightening MeshTolerance.\n', output.meshsize);
end

% For ga/particleswarm
if output.stallgenerations == options.MaxStallGenerations
    warning('Solver stopped due to stall limit. Try increasing MaxStallGenerations or PopulationSize.\n');
end
```

## Constraint Evaluation

### Problem-Based

Use `issatisfied()` to check overall constraint satisfaction and identify violations:
```matlab
[allsat, sat] = issatisfied(prob, sol);
if ~allsat
    % sat contains logical satisfaction status for each constraint
    disp('Constraint satisfaction status:');
    disp(sat);
end
```

Use `infeasibility()` on individual constraints to quantify violations:
```matlab
% Check violation magnitude for each constraint
conNames = fieldnames(prob.Constraints);
for i = 1:numel(conNames)
    infeas = infeasibility(prob.Constraints.(conNames{i}), sol);
    if any(infeas > 1e-6)
        fprintf('Constraint "%s" violated by %.3e\n', conNames{i}, max(infeas));
    end
end
```

For evaluating constraint expressions at a solution:
```matlab
constraint_value = evaluate(prob.Constraints.myConstraint, sol);
```

### Solver-Based

Evaluate constraint functions directly at the solution:
```matlab
% Nonlinear constraints
[c, ceq] = nonlcon(x);
ineq_violation = max([c; 0]);  % should be <= 0
eq_violation = max(abs(ceq));  % should be == 0

fprintf('Max inequality violation: %.3e\n', ineq_violation);
fprintf('Max equality violation: %.3e\n', eq_violation);

% Linear constraints
Ax_violation = max(A*x - b);
Aeqx_violation = max(abs(Aeq*x - beq));

% Bounds
lb_violation = max(lb - x);
ub_violation = max(x - ub);
```

## Comprehensive Validation Pattern

For detailed reporting beyond the basic exitflag check (see SKILL.md Step 1):
```matlab
fprintf('=== Optimization Results ===\n');
fprintf('Exitflag: %d (%s)\n', exitflag, output.message);
fprintf('Objective: %.6f\n', fval);
fprintf('Iterations: %d\n', output.iterations);
fprintf('Function evals: %d\n', output.funcCount);

if isfield(output, 'firstorderopt')
    fprintf('First-order optimality: %.3e\n', output.firstorderopt);
end
if isfield(output, 'constrviolation')
    fprintf('Constraint violation: %.3e\n', output.constrviolation);
end

% Problem-based constraint check
if exist('prob', 'var') && exist('sol', 'var')
    [allsat, ~] = issatisfied(prob, sol);
    fprintf('All constraints satisfied: %s\n', string(allsat));
end
```

## When to Skip Optimality Checks

For derivative-free solvers, **do not check `firstorderopt`** — it is not computed. Instead:
- `patternsearch`: check `output.meshsize`
- `surrogateopt`: check `output.funccount` and consider if more evaluations are needed
- `ga`, `particleswarm`: check `output.stallgenerations`

These solvers use different convergence criteria that are problem-specific.

---
Copyright 2026 The MathWorks, Inc.
