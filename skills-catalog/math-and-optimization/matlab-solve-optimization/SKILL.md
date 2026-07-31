---
name: matlab-solve-optimization
description: >-
  Use when writing, solving, or debugging MATLAB optimization code — formulating
  problems (optimproblem, optimvar, fcn2optimexpr), selecting and configuring
  solvers (fmincon, linprog, quadprog, intlinprog, lsqnonlin, ga, surrogateopt,
  optimoptions), or validating results (exitflag, convergence, constraint
  violations). Covers problem-based and solver-based approaches, solver tuning,
  and solution verification.
license: "https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md"
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Optimization Workflow

Guide the full optimization lifecycle: classify the problem, formulate it, select and configure a solver, and validate the results.

## When to Use

- User is defining an optimization problem in MATLAB (variables, objectives, constraints)
- User asks about `optimproblem`, `optimvar`, `optimconstr`, `optimexpr`, or `fcn2optimexpr`
- User is selecting or configuring a solver (`optimoptions`, algorithm choice, tuning)
- User is interpreting results, debugging convergence, or checking exitflags
- User is deciding between problem-based and solver-based approaches
- User is writing optimization code with for-loops over decision variables or constraints

## When NOT to Use

- User is asking to solve a problem that doesn't require numerical optimization solvers (e.g., finding the minimum value in an array or table)
- User is working with non-optimization MATLAB code (data analysis, plotting, signal processing)
- User is using a third-party optimization toolbox (not MathWorks)
- User is solving symbolic equations with `solve(eqns, vars)`, ODE systems, or linear system solves (`A\b`)

---

## Stage 1: Classify & Formulate

### 1.1 Classify the Problem

Before formulating, identify the problem class — it determines which solver to use, what guarantee you can promise (global vs local), and whether a domain-specific tool should replace the generic path.

See [references/classify.md](references/classify.md) for the class→solver→guarantee table, convexity quick-checks, and "hidden easier class" heuristics. Key actions:
- Check if a purpose-built domain tool exists before falling back to `optimproblem`
- Watch for hidden easier classes (sum-of-squares disguised as NLP, linear structure missed)
- For QPs, check `eig(H)` — nonconvex QPs cannot use `quadprog` reliably
- Watch for hidden nonsmoothness: `max`, `min`, `abs`, `sort`, `if`/branching, or norms other than squared-2-norm

### 1.2 Choose Approach

**Use problem-based by default** for readable definitions, N-D modeling, and every LP, QP, conic, and mixed-integer problem (unless coefficients are already in matrix-vector form). Problem-based provides automatic differentiation and is less error-prone.

Even when AD is blocked (e.g., `ode45` in the objective), `fcn2optimexpr` can still wrap the function as a black-box — problem-based remains useful.

Only fall back to solver-based when one of these applies:

| Use solver-based when... | Reason |
|---|---|
| Trivial mapping to solver API — one vector `x`, pre-coded objective with exact gradients/Hessian | No benefit from abstraction; solver-based is direct |
| Overhead of building problem-based expressions dominates computation | Avoid tracing/transformation overhead |
| Need a solver feature problem-based doesn't expose (`CheckpointFile`, exact Hessians, custom `OutputFcn`) | Only available via solver-based calls |
| C code generation for embedded deployment is required | Problem-based does not support codegen |

**Converting between approaches:** `prob2struct(prob)` converts problem-based to solver-based form for deployment or performance.

**References:**
- Problem-based: [references/problem-based-guide.md](references/problem-based-guide.md)
- Solver-based (class→solver mapping): [references/classify.md](references/classify.md)

### 1.3 Formulate the Problem

**Problem-based canonical template:**

```matlab
% 1. Define decision variables
x = optimvar("x", N, LowerBound=lb, UpperBound=ub);

% 2. Create problem
prob = optimproblem("Objective", sum(x,"all"));

% 3. Add constraints
prob.Constraints.linear = A*x <= b;
prob.Constraints.nonlinear = fcn2optimexpr(@myNonlinFcn, x) <= rhs;

% 4. Set initial guess (must be struct with field names matching optimvar names)
x0.x = initialValues;

% 5. Solve
[sol, fval, exitflag, output] = solve(prob, x0);
```

**Solver-based key differences:**
- Initial guess is a **numeric vector**, not a struct
- You manage variable indexing manually (flat vector `x`)
- Supply gradients manually for best performance (`SpecifyObjectiveGradient=true`)
- Linear/quadratic solvers require explicit coefficient matrices

### 1.4 Validate at the Start Point

Before calling any solver, evaluate the objective and constraints at `x0` to catch sign/size/NaN errors early:

```matlab
% Problem-based
fval0 = evaluate(prob.Objective, x0);
assert(isfinite(fval0), 'Objective is not finite at x0');
infeas0 = infeasibility(prob.Constraints, x0);
fprintf('Max infeasibility at x0: %.3e\n', max(infeas0));
```

For solver-based, call `fun(x0)` and `nonlcon(x0)` directly and confirm finite, correctly-sized outputs. If gradients are supplied, run `checkGradients` at this point.

---

## Stage 2: Select & Configure Solver

### 2.1 Select the Narrowest Solver

Choose the **narrowest solver that matches the problem structure.** Do not default to `fmincon` or heuristic global solvers when a more specific solver applies.

Key selection rules:
- Always prefer: `linprog` > `quadprog` > `coneprog` > `lsqlin` > `lsqnonlin` > `fmincon` > global solvers
- Always prefer `fminunc` over `fminsearch` when Optimization Toolbox is installed
- Always prefer `lsqnonlin`/`lsqcurvefit` over `fmincon` for least-squares problems
- Always prefer `lsqlin` over `lsqnonlin` for linear least-squares with bounds or linear constraints
- Use `patternsearch` when gradients are unavailable/unreliable AND the problem is not extremely expensive
- Use `surrogateopt` when each evaluation takes >15-20 seconds
- For nearly linear MIPs, linearize and use `intlinprog` rather than calling Global Optimization solvers
- For unit commitment / binary operating modes, keep mixed-integer with `intlinprog`

See [references/classify.md](references/classify.md) for the full class→solver table.

### 2.2 Verify Options — Never Guess

**ALWAYS verify that solver options are valid before using them.** Options change across MATLAB releases and hallucinated options cause runtime errors.

```matlab
% Verify options for a solver
opts = optimoptions('solvername')
```

Run `optimoptions('solvername')` to see all valid options for the user's installed version before writing options code.

### 2.3 Verify Gradients (if supplied)

If analytic gradients are supplied (`SpecifyObjectiveGradient=true`), verify them before solving:

```matlab
[valid, err] = checkGradients(@myObjective, x0, Display="on");
```

For constraint gradients: `checkGradients(@myConstraints, x0, IsConstraint=true)`.

### 2.4 Parallelize (if expensive)

If the solver supports `UseParallel` and Parallel Computing Toolbox is available:

```matlab
ver('parallel')  % Check for PCT
options = optimoptions('solvername', UseParallel=true);
```

Solvers supporting `UseParallel`: `fmincon`, `fminunc`, `lsqnonlin`, `lsqcurvefit`, `patternsearch`, `surrogateopt`, `ga`, `particleswarm`, `paretosearch`, `gamultiobj`.

Do NOT suggest `UseParallel` for: `quadprog`, `intlinprog`, `fminsearch`, `linprog`, `lsqlin`.

### 2.5 Performance (after correctness)

If the solve is correct but too slow, see [references/performance-levers.md](references/performance-levers.md). Key levers: analytic gradients, sparsity patterns, warm starting, code generation. Apply only after Stage 3 confirms correctness — re-validate after any performance change.

**Reference:** [references/solver-tuning.md](references/solver-tuning.md) for per-solver algorithm and tuning guidance.

---

## Stage 3: Validate Results

### 3.1 Basic Validation (Always Include)

**Every time solver-calling code is written, add basic output validation:**

```matlab
[sol, fval, exitflag, output] = solve(prob, x0);

% Check convergence
if exitflag > 0
    fprintf('Optimization converged: %s\n', output.message);
else
    warning('Optimization did not converge (exitflag = %d): %s\n', exitflag, output.message);
end

% Report key metrics
fprintf('Objective value: %.6f\n', fval);
fprintf('Iterations: %d\n', output.iterations);
if isfield(output, 'constrviolation')
    fprintf('Constraint violation: %d\n', output.constrviolation);
end
```

See [references/validation-checklist.md](references/validation-checklist.md) for detailed exitflag meanings per solver.

### 3.2 Extended Validation

**Constraint violations (problem-based):**
```matlab
[allsat, sat] = issatisfied(prob, sol);
if ~allsat
    conNames = fieldnames(prob.Constraints);
    for i = 1:numel(conNames)
        infeas = infeasibility(prob.Constraints.(conNames{i}), sol);
        if any(infeas > 0)
            fprintf('Constraint "%s" violated by %.3e\n', conNames{i}, max(infeas));
        end
    end
end
```

**Optimality conditions (gradient-based solvers only — skip for `patternsearch`, `ga`, `particleswarm`, `surrogateopt`):**
```matlab
if isfield(output, 'firstorderopt')
    fprintf('First-order optimality: %.6e\n', output.firstorderopt);
    if output.firstorderopt > 1e-3
        warning('First-order optimality measure is large — solution may not be optimal.\n');
    end
end
```

### 3.3 Debugging Failed or Poor Solutions

When `exitflag <= 0` or convergence is poor, follow the improving-results checklist in [references/improving-results.md](references/improving-results.md):

1. **Check formulation** — constraints feasible? bounds consistent? objective well-defined at x0?
2. **Check scaling** — scale variables to O(1); rescale if objective/constraints differ by orders of magnitude; use `FiniteDifferenceType='central'` if finite-difference gradients are inaccurate
3. **Try different algorithms** — `options.Algorithm`, increase `MaxIterations`/`MaxFunctionEvaluations`, adjust tolerances, set `HybridFcn` for heuristic solvers
4. **Try different initial points** — `MultiStart`, `GlobalSearch`, or `surrogateopt`/`ga` for global optimization

**Debug discipline:**
- **Smallest-first.** Shrink to 2-3 variables. A bug in a toy problem is minutes; at full scale is hours.
- **One change at a time, justified by a symptom.**
- **Stop-and-ask budget.** Stop coding and talk to the user when: >3 rounds with no improvement, >2 option tweaks that don't move diagnostics, or you can't get a finite objective at x0 even on a toy problem.

### 3.4 Application-Specific Visualization

| Problem Domain | Suggested Plots |
|---|---|
| Optimal control / navigation | State trajectories vs time, control input profiles, phase portraits |
| Scheduling / assignment | Gantt charts, resource utilization over time |
| Design optimization | Contour plots with optimum marked, sensitivity plots |
| Parameter estimation / fitting | Residual plots, fitted surface vs data |
| Portfolio / allocation | Bar charts of allocations, efficient frontier plots |

---

## Gotchas

### Formulation
1. **Initial guess must be a struct** with field names matching `optimvar` names exactly. NOT a flat vector.
2. **Do NOT set `SpecifyObjectiveGradient` or `SpecifyConstraintGradient`** in options for problem-based — AD manages gradients internally.
3. **Use N-D `optimvar` for multi-dimensional problems.** Do NOT create scalar variables in a loop.
4. **Preallocate constraint arrays with `optimconstr(N)`.** Do NOT concatenate in a loop.
5. **Call `fcn2optimexpr` ONCE per function, not inside loops.** See [references/fcn2optimexpr-guide.md](references/fcn2optimexpr-guide.md).
6. **Use `"like"` for preallocation inside traced functions** to preserve AD type: `zeros(n,1,"like",x)`.

### Solver Configuration
7. **Never guess option names from memory.** Always verify with `optimoptions('solvername')`.
8. **Do NOT tighten `MeshTolerance` for `patternsearch`** too much.
9. **Do NOT set `AbsoluteGapTolerance`/`RelativeGapTolerance` high for `intlinprog`** for early stopping — use time/node limits.
10. **Keep tolerances well above machine epsilon.** Use `1e-6` to `1e-8` range unless specifically required.

### Validation
11. **`output.constrviolation` does not exist for unconstrained solvers.** Always check with `isfield`.
12. **Do NOT check `output.firstorderopt` for derivative-free solvers.** Check solver-specific metrics instead (`output.meshsize`, `output.stallgenerations`).
13. **`infeasibility()` operates on individual constraints, not entire problems.** Use `issatisfied(prob, sol)` for overall checks.
14. **For `fmincon` with `exitflag <= 0`, check `output.bestfeasible`.** Use it as a starting point for a new solve.

## Conventions

- Default to problem-based unless a specific blocker applies.
- When vectorization is possible, always prefer it over loops.
- When wrapping complex logic in `fcn2optimexpr`, encapsulate in a single helper function rather than calling inside a loop.
- Always show the initial guess setup.
- Mark code blocks as **templates** when they depend on user-supplied functions.
- When suggesting tuning options, explain the trade-off (speed vs accuracy).
- Do not over-tune: for simple or small problems, defaults are usually sufficient.
- **Always** include basic validation (exitflag check) when writing solver-calling code.
- When debugging, start with formulation and scaling before changing algorithms.

---
Copyright 2026 The MathWorks, Inc.
