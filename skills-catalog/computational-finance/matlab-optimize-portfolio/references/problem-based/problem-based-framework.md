# Set Up and Solve a Problem-Based Model

## The default: problem-based

Formulate every portfolio problem with `optimproblem` + `optimvar` and call
`solve(prob)`. This is the default, not a preference — the problem-based
framework carries three advantages that matter for the failure modes below:

- **Constraint expressions read like the math.** `sum(sell.*(price - basis)) <= 500`
  is a natural expression; `A*x <= b` in solver-based form obscures unit
  errors like the cap-gains `$² / share` bug (see `problem-data-hygiene.md`).
- **`solve` picks the right solver from the problem structure.** LP, QP,
  MILP, MIQP, NLP, MINLP are all dispatched automatically. No manual solver
  choice, no `A/Aeq/b/beq` indices bookkeeping.
- **Integer variables use `optimvar(..., "Type", "integer")`.** This one
  option turns a QP into a MIQP or an LP into a MILP without changing any of
  the constraint expressions.

## When solver-based is legitimate

Only in these narrow cases:

- The user explicitly asks for solver-based (`linprog(f, A, b, ...)`,
  `intlinprog(f, intcon, A, b, ...)`, `ga(fun, nvars, ...)`).
- Problem-based has a documented gap for the shape at hand.
- Legacy code the user is extending is already in solver-based form and they
  want a minimal diff.

Otherwise: stay in problem-based. Three common drops to solver-based on
portfolio MIPs — `linprog` matrix form on a MILP, `intlinprog` matrix form
on a MILP, `ga` function-handle form on a MIQP — are all avoidable and all
lose readability plus the `solve` dispatch safety net.

## The nonlinear escape: `fcn2optimexpr`

For genuinely nonlinear pieces that cannot be linearized (a custom pricing
function, a nonlinear risk measure, a nonconvex objective), wrap the MATLAB
function so it composes with `optimproblem`:

```matlab
prob = optimproblem(ObjectiveSense="maximize");
w = optimvar("w", nAssets, LowerBound=0, UpperBound=1);
prob.Objective = fcn2optimexpr(@customUtility, w, muParams);
prob.Constraints.budget = sum(w) == 1;
x0.w = ones(nAssets, 1) / nAssets;   % nonlinear (fmincon) needs a start point
sol = solve(prob, x0);
```

`fcn2optimexpr` keeps the formulation inside `optimproblem` so `solve` still
dispatches. Do **not** drop out to `ga(@objfun, nvars, ...)` function-handle
form for nonlinear pieces — you lose the ability to name and index
constraints and variables, and the code stops reading like the math.

## `solve` dispatch table

Read the problem structure off the formulation — objective form and variable
types together decide it:

| Objective form                     | All continuous vars | Any integer vars |
|------------------------------------|---------------------|------------------|
| Linear                             | LP                  | MILP             |
| Quadratic                          | QP                  | MIQP             |
| Nonlinear (via `fcn2optimexpr`)    | NLP                 | MINLP            |

Then `solve` picks the solver:

| Problem structure | Dispatched solver | Toolbox               | Deterministic?         |
|-------------------|-------------------|-----------------------|------------------------|
| LP                | `linprog`         | Optimization Toolbox  | yes                    |
| QP                | `quadprog`        | Optimization Toolbox  | yes                    |
| MILP              | `intlinprog`      | Optimization Toolbox  | yes                    |
| MIQP              | `ga`              | Global Optimization   | no (heuristic)         |
| NLP               | `fmincon`         | Optimization Toolbox  | local, depends on x0   |
| MINLP             | `ga`              | Global Optimization   | no (heuristic)         |

Dispatch is by **problem structure**, not by "has binaries." A MIQP has
integer variables and a quadratic objective — `solve` dispatches to `ga`,
not `intlinprog`, because `intlinprog` cannot handle quadratic objectives.

## Options must match the dispatched solver

`optimoptions(solverName, ...)` is bound to the solver name at construction.
If you pass options for a solver `solve` does not dispatch to, only the
options the dispatched solver also supports carry over.

Anti-pattern:

```matlab
opts = optimoptions("intlinprog", "Display", "iter", "MaxTime", 60, ...
                    "MaxNodes", 1e4);
[sol, fval, exitflag] = solve(prob, "Options", opts);   % prob is MIQP
% -> solve dispatches to ga
% -> Display, MaxTime carry over
% -> MaxNodes (intlinprog-specific) is dropped with a warning
```

Correct: check the dispatch first, then if the user asks for options on a
MIQP/MINLP set options on the actual dispatched solver:

```matlab
% Correct: the objective is quadratic + integer vars are present => MIQP => ga
opts = optimoptions("ga", "Display", "iter", "MaxTime", 60);
[sol, fval, exitflag] = solve(prob, "Options", opts);
```

Rule of thumb — read the dispatch off the objective form and the variable
types, then pick the solver name for `optimoptions`. When in doubt, run
`solve` once and inspect the diagnostic output; it names the solver.

## Common mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|----------------|------------------|
| `linprog(f, A, b, Aeq, beq, lb, ub)` on a portfolio LP | Manual row/column bookkeeping across `A`, `Aeq`, `b`, `beq`, `lb`, `ub` is error-prone; constraints stop reading like the math; unit errors (cap-gains, self-financing) get buried in coefficient matrices | `optimproblem` + `optimvar`; `solve(prob)` |
| `intlinprog(f, intcon, A, b, ...)` on a portfolio MILP | Same manual matrix bookkeeping — plus `intcon` is a separate list of integer column indices that must stay in sync with `A`'s column layout every time a variable is added or removed | `optimvar(..., "Type", "integer")` |
| `ga(@objfun, nvars, ...)` on a portfolio MIQP | Function-handle form breaks the `optimproblem` composition; nonlinear pieces cannot compose with other constraints cleanly | `optimproblem` + `optimvar` (integer type); `fcn2optimexpr` for nonlinear pieces |
| `optimoptions("intlinprog", ...)` passed to `solve` on a MIQP | `solve` dispatches to `ga`; `intlinprog`-specific options are dropped with a warning | Read dispatch first; `optimoptions("ga", ...)` on MIQP |

----

Copyright 2026 The MathWorks, Inc.

----
