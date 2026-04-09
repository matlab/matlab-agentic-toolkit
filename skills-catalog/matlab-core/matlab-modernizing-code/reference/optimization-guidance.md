
# Optimization Modernization

## Quick Reference: Function Mappings

| Deprecated/Legacy | Recommended Replacement | Since | Status |
|-------------------|------------------------|-------|--------|
| optimtool | Optimize Live Editor Task | R2021a | Removed |
| optimset (for Optimization Toolbox) | optimoptions | R2013a | Not recommended |

## Optimization App Removal

### optimtool → Optimize Live Editor Task

**Status:** Removed in R2021a

The Optimization app (`optimtool`) was removed because it was based on Java, which became increasingly problematic. Additionally, the app had not kept pace with solver development (e.g., couldn't handle `intlinprog` or `particleswarm`).

**Old Pattern (Will Not Work in R2021a+):**
```matlab
% REMOVED: optimtool no longer exists
optimtool
optimtool(@objfun, x0)
optimtool('fmincon')
```

**Modern Pattern (Use This):**
```matlab
% Option 1: Use Optimize Live Editor Task
% In a Live Script, insert the Optimize task from the Live Editor tab

% Option 2: Programmatic approach (recommended for production)
options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp');
[x, fval] = fmincon(@objfun, x0, A, b, Aeq, beq, lb, ub, @nonlcon, options);
```

**Using Optimize Live Editor Task:**
1. Create a new Live Script (`.mlx`)
2. Go to **Live Editor** tab → **Task** → **Optimize**
3. Define objective, constraints, and solver visually
4. The task generates equivalent MATLAB code

**Why Modern is Better:**
- Optimize Live Editor Task integrates directly into Live Scripts
- Generates reusable MATLAB code
- Supports all current solvers including `intlinprog`, `coneprog`, `particleswarm`
- Better visualization and iteration tracking

---

## Options Configuration

### optimset → optimoptions

**Status:** `optimset` still works but `optimoptions` is recommended for Optimization Toolbox solvers.

**Old Pattern (Less Preferred):**
```matlab
% Legacy approach using optimset
options = optimset('Display', 'iter', 'TolFun', 1e-6, 'MaxIter', 1000);
[x, fval] = fmincon(@objfun, x0, A, b, [], [], lb, ub, [], options);
```

**Modern Pattern (Use This):**
```matlab
% Modern approach using optimoptions
options = optimoptions('fmincon', ...
    'Display', 'iter', ...
    'OptimalityTolerance', 1e-6, ...
    'MaxIterations', 1000, ...
    'Algorithm', 'sqp');
[x, fval] = fmincon(@objfun, x0, A, b, [], [], lb, ub, [], options);
```

**When to Still Use optimset:**
- For base MATLAB solvers without Optimization Toolbox: `fminbnd`, `fminsearch`, `fzero`, `lsqnonneg`
- These functions only accept `optimset` options

**Why optimoptions is Better:**
- Solver-specific options with validation
- Better option names (e.g., `MaxIterations` vs `MaxIter`)
- Supports all Optimization Toolbox and Global Optimization Toolbox solvers
- Required for newer solvers like `intlinprog`, `coneprog`
- IDE autocomplete and documentation integration

---

## Option Name Changes

When migrating from `optimset` to `optimoptions`, some option names changed:

| optimset Name | optimoptions Name | Notes |
|---------------|-------------------|-------|
| TolFun | OptimalityTolerance | Renamed for clarity |
| TolX | StepTolerance | Renamed for clarity |
| MaxIter | MaxIterations | Renamed for consistency |
| MaxFunEvals | MaxFunctionEvaluations | Renamed for consistency |
| TolCon | ConstraintTolerance | Renamed for clarity |
| GradObj | SpecifyObjectiveGradient | Boolean, clearer name |
| GradConstr | SpecifyConstraintGradient | Boolean, clearer name |
| Hessian | HessianFcn | Different value format |
| DerivativeCheck | CheckGradients | Renamed |
| FinDiffType | FiniteDifferenceType | Renamed |
| FinDiffRelStep | FiniteDifferenceStepSize | Renamed |
| OutputFcn | OutputFcn | Same name |
| PlotFcns | PlotFcn | Slightly different |

---

## Problem-Based Optimization (Modern Approach)

**Recommendation:** For new optimization code, consider the problem-based approach introduced in R2017b.

**Old Pattern (Solver-Based):**
```matlab
% Define objective and constraints as functions
fun = @(x) x(1)^2 + x(2)^2;
A = [1, 2];
b = 10;
lb = [0, 0];
x0 = [1, 1];

options = optimoptions('fmincon', 'Algorithm', 'sqp');
[x, fval] = fmincon(fun, x0, A, b, [], [], lb, ub, [], options);
```

**Modern Pattern (Problem-Based):**
```matlab
% Define optimization variables
x = optimvar('x', 2, 'LowerBound', 0);

% Create optimization problem
prob = optimproblem('Objective', x(1)^2 + x(2)^2);
prob.Constraints.linear = x(1) + 2*x(2) <= 10;

% Solve
x0.x = [1; 1];
[sol, fval] = solve(prob, x0);

% Access solution
xopt = sol.x;
```

**Why Problem-Based is Better:**
- More readable and maintainable code
- Automatic differentiation for gradients
- Easier constraint specification
- Automatic solver selection
- Better for complex problems with many constraints

---

## Global Optimization Patterns

### Using Modern Global Optimization

**Pattern for Global Search:**
```matlab
% Modern global optimization with GlobalSearch
problem = createOptimProblem('fmincon', ...
    'objective', @objfun, ...
    'x0', x0, ...
    'lb', lb, ...
    'ub', ub, ...
    'options', optimoptions('fmincon', 'Algorithm', 'sqp'));

gs = GlobalSearch('Display', 'iter');
[x, fval] = run(gs, problem);
```

**Pattern for Particle Swarm:**
```matlab
% Particle swarm optimization (R2014b+)
options = optimoptions('particleswarm', ...
    'SwarmSize', 100, ...
    'Display', 'iter', ...
    'MaxIterations', 200);

[x, fval] = particleswarm(@objfun, nvars, lb, ub, options);
```

**Pattern for Surrogate Optimization:**
```matlab
% Surrogate optimization for expensive functions (R2018b+)
options = optimoptions('surrogateopt', ...
    'MaxFunctionEvaluations', 200, ...
    'Display', 'iter');

[x, fval] = surrogateopt(@expensive_objfun, lb, ub, options);
```

---

## Mixed-Integer Programming

### intlinprog (Requires optimoptions)

**Important:** `intlinprog` only works with `optimoptions`, not `optimset`.

```matlab
% Mixed-integer linear programming
f = [-1; -2; -3];  % Objective coefficients
intcon = [1, 3];    % Integer variable indices
A = [1 1 1];
b = 7;
lb = zeros(3, 1);

options = optimoptions('intlinprog', 'Display', 'iter');
[x, fval] = intlinprog(f, intcon, A, b, [], [], lb, [], options);
```

---

## Version Compatibility Notes

- **R2021a:** `optimtool` removed → use Optimize Live Editor Task
- **R2018b:** `surrogateopt` introduced for expensive black-box optimization
- **R2017b:** Problem-based optimization introduced
- **R2014b:** `particleswarm` introduced
- **R2013a:** `optimoptions` introduced as preferred option-setting function

---

## Summary: Patterns to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `optimtool` | Optimize Live Editor Task | Removed in R2021a |
| `optimset` for Optimization Toolbox | `optimoptions` | Limited solver support, outdated option names |
| Old option names (TolFun, MaxIter) | New names (OptimalityTolerance, MaxIterations) | Clearer, consistent naming |

