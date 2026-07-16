# Problem-Based Optimization Guide

Detailed reference for formulating optimization problems using `optimproblem`, `optimvar`, `optimexpr`, and `optimconstr`.

Doc reference: https://www.mathworks.com/help/optim/problem-based-details.html

## Variable Declaration

```matlab
% Scalar
t = optimvar("t", LowerBound=0);

% Vector with uniform bounds
x = optimvar("x", n, LowerBound=0, UpperBound=1);

% Vector with different bounds per element
theta = optimvar("theta", 3, LowerBound=[0 1 5]);

% Matrix
X = optimvar("X", m, n);

% Integer variable
k = optimvar("k", 5, Type="integer", LowerBound=1, UpperBound=10);

% Binary variable
y = optimvar("y", n, Type="integer", LowerBound=0, UpperBound=1);
```

**Key rules:**
- Use `optimvar` ONLY for decision variables, not for constants or parameters.
- Match the shape to the mathematical model (or sometimes the data for simpler expressions): if the model has a matrix of decisions, use a matrix `optimvar`.

## Objective Function

**Linear/quadratic — use inline expressions:**
```matlab
prob.Objective = sum(cost .* x);          % linear
prob.Objective = x' * H * x + f' * x;     % quadratic
```

**Nonlinear with supported operations — use direct expressions:**
```matlab
prob.Objective = sum(x.^2 .* log(x));
```

**Nonlinear with complex logic or black-box function — use `fcn2optimexpr`:**
```matlab
prob.Objective = fcn2optimexpr(@myObjective, x, data);
```

**Multi-objective - assign with labels**
```matlab
prob.Objective.Analytical = sum(x.^2 .* log(x));                  % Objective 1
prob.Objective.BlackBox = fcn2optimexpr(@myObjective, x, data);   % Objective 2
```

## Constraints

### Variable bounds (set on `optimvar`)
```matlab
x = optimvar("x", n, LowerBound=0, UpperBound=100);
```

### Linear constraints
```matlab
prob.Constraints.budget = sum(x) <= B;
prob.Constraints.equality = A * x == b;
```

### Nonlinear constraints
```matlab
prob.Constraints.nonlin = sum(x.^2) <= 1;
% Or via fcn2optimexpr:
prob.Constraints.nonlin = fcn2optimexpr(@myConstraint, x) <= 0;
```

### Array constraints (preallocate!)
```matlab
cons = optimconstr(N);
for i = 1:N
    cons(i) = x(i)^2 + x(i+1)^2 <= radius(i)^2;
end
prob.Constraints.circles = cons;
```

**WARNING:** Do NOT build constraints by concatenation in a loop (`cons = [cons; newcon]`). This causes quadratic memory growth. Always preallocate with `optimconstr`.

## Efficiency Best Practices

1. **Vectorize over loops.** Convert:
   ```matlab
   % BAD: scalar loop
   obj = 0;
   for i = 1:N
       obj = obj + cost(i) * x(i);
   end
   ```
   To:
   ```matlab
   % GOOD: vectorized
   obj = sum(cost .* x);
   ```

2. **Use N-D variables for structured problems.** A scheduling problem with workers × shifts should use `optimvar("schedule", nWorkers, nShifts, Type="integer", LowerBound=0, UpperBound=1)`, not `N*M` scalar variables.

3. **Wrap tight loops in a helper function** and call `fcn2optimexpr` once, rather than calling `fcn2optimexpr` inside a loop.

4. **Leverage automatic sparsity detection.** Do not manually pre-sparsify — the AD system detects sparsity patterns automatically.

5. **Use `show(prob)`** to inspect the symbolic formulation before solving. This helps catch formulation errors early.

## Initial Guess

The initial guess **must be a struct** with field names matching `optimvar` names:

```matlab
% Variables declared as:
x = optimvar("x", 5);
Y = optimvar("Y", 3, 4);

% Initial guess:
x0.x = [1; 2; 3; 4; 5];      % matches "x"
x0.Y = rand(3, 4);            % matches "Y"
```

**Common error:** Passing a flat numeric vector (fmincon-style) instead of a struct. This always fails.

## Automatic Differentiation (AD) Support

Problem-based optimization uses AD to compute gradients automatically. AD traces through most standard math and matrix operations on `optimvar`.

AD **cannot** trace through:
- ODE solvers (`ode45`, `ode23s`, etc.)
- Control flow that branches on `optimvar` values (e.g., `if x(1) > 0`)
- External compiled code (MEX) on the `optimvar` path

For the full list of supported operations, see: https://www.mathworks.com/help/optim/ug/supported-operations-on-optimization-variables-expressions.html

When a function uses unsupported operations, `fcn2optimexpr` can still wrap it as a black-box (without AD). See [fcn2optimexpr-guide.md](fcn2optimexpr-guide.md) for details.

**Key rule:** Do NOT set `SpecifyObjectiveGradient` or `SpecifyConstraintGradient` in options when using problem-based. AD manages gradients internally.

## Solver Selection (Automatic)

`solve()` automatically selects the appropriate solver based on problem structure:
- Linear objective + linear constraints → `linprog`
- Quadratic objective + linear constraints → `quadprog`
- Integer variables → `intlinprog` (linear) or `ga` (nonlinear)
- Nonlinear + unconstrained → `fminunc`
- Nonlinear + constrained → `fmincon`

Override with: `[sol, fval] = solve(prob, x0, Solver="fmincon");`

Pass options: `[sol, fval] = solve(prob, x0, Options=opts);`

## Multi-Start and Multi-Objective

For multi-start and multi-objective optimization with problem-based formulations, see [reference/solver-tuning.md](reference/solver-tuning.md).

---
Copyright 2026 The MathWorks, Inc.
