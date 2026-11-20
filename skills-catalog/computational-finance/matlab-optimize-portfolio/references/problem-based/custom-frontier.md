# Build a Custom Efficient Frontier

The frontier is traced by solving three problems: **lower endpoint**, **upper
endpoint**, and a sweep of **interior points**. Each has a specific correct
form.

## Endpoint problems

The lower endpoint is **not** a min-return problem. Solving `min mu'*w`
walks the *inefficient* lower branch of the parabola — a stretch of points
that are on the feasible set but Pareto-dominated by points at the same
risk with higher return.

**Correct endpoints:**

| Endpoint  | Problem                                | Solver dispatch (typical) |
|-----------|----------------------------------------|---------------------------|
| Lower     | Minimize risk (variance or std. dev.)  | QP (or MIQP with integer vars) |
| Upper     | Maximize expected return               | LP (or MILP with integer vars) |

The lower endpoint gives the minimum-risk point of the feasible set; the
upper endpoint gives the maximum-return point. Every point on the efficient
frontier lies between these two on both axes.

**Neither endpoint problem carries a return-target constraint.** The
return-target constraint (`mu' * w >= target`) belongs only to the
interior sweep — it is what makes the interior a *constrained* min-risk
problem. Attaching it to the endpoint problems, even as a placeholder
that is "trivially satisfied" (e.g., `mu' * w >= 0`), is wrong for two
reasons:

1. It changes the feasibility set of the endpoint problem. Even a
   placeholder like `mu' * w >= 0` becomes a real constraint whenever
   short-selling, cash, or a negative-return asset is allowed — the
   endpoint no longer solves the intended problem.
2. It couples endpoint solutions to a constraint that was designed to be
   varied per interior point. If the endpoint solver's `prob` is later
   reused for the interior sweep, the placeholder must be *replaced*
   (not left in place) — mixing the two roles into one object invites
   silent errors when the endpoint problem is edited later.

Keep the endpoint problems return-target-free. Add the return-target
constraint only when preparing the interior sweep (see "Build once,
reassign inside the loop" below).

### Lower endpoint — min-variance

```matlab
probLo = optimproblem(ObjectiveSense="minimize");
w = optimvar("w", nAssets, LowerBound=0, UpperBound=1);
probLo.Objective   = w' * Sigma * w;
probLo.Constraints.budget = sum(w) == 1;
% ... any additional custom constraints ...
solLo = solve(probLo);
retLo = mu' * solLo.w;
riskLo = sqrt(solLo.w' * Sigma * solLo.w);
```

### Upper endpoint — max-return

```matlab
probHi = optimproblem(ObjectiveSense="maximize");
w = optimvar("w", nAssets, LowerBound=0, UpperBound=1);
probHi.Objective   = mu' * w;
probHi.Constraints.budget = sum(w) == 1;
% ... same additional custom constraints ...
solHi = solve(probHi);
retHi = mu' * solHi.w;
```

For integer-lot frontiers, the upper endpoint is a MILP (`intlinprog`,
deterministic) and the lower endpoint is a MIQP (`ga`, heuristic).

## Interior sweep — inequality target

Sweep return targets between `retLo` and `retHi`. Use an inequality
constraint on return, **not** an equality:

```matlab
prob.Constraints.retTarget = mu' * w >= target;   % ✓ inequality
% NOT:
% prob.Constraints.retTarget = mu' * w == target; % ✗ equality
```

Why inequality:

- Equality forces the solver onto the exact target line even when a
  higher-return, lower-risk point is feasible for the given constraints.
  On non-convex frontiers (integer lots, disjunctions), this can put the
  interior points on the inefficient side of the feasible set.
- Inequality lets the solver pick the min-risk point *among all portfolios
  reaching at least the target return*. This is the mean-variance-efficient
  point for that target — exactly what an efficient frontier should trace.

## Build once, reassign inside the loop

Rebuilding the whole `optimproblem` inside the frontier loop re-parses the
symbolic expressions on every iteration. Correct idiom: build the interior
problem once **after** the endpoints are solved and **immediately before**
the interior sweep begins; inside the loop, reassign only the mutable
right-hand side of the target constraint.

Do **not** attach `retTarget` to the min-variance / max-return endpoint
problems. If you constructed a common shared problem for feasibility (all
the wash-sale, cap-gains, budget, trade-balance constraints), *copy* it
into the interior problem and add `retTarget` at that step — not before.

```matlab
% 1. Endpoint problems — NO retTarget constraint.
% (See "Endpoint problems" above for the min-variance / max-return forms.)
solLo = solve(probLo);    retLo = mu' * solLo.w;
solHi = solve(probHi);    retHi = mu' * solHi.w;

% 2. Interior sweep problem — build once, add retTarget with a placeholder
%    RHS that will be overwritten inside the loop.
prob = optimproblem(ObjectiveSense="minimize");
w = optimvar("w", nAssets, LowerBound=0, UpperBound=1);
prob.Objective = w' * Sigma * w;
prob.Constraints.budget    = sum(w) == 1;
% ... any additional custom constraints (wash-sale, cap-gains, etc.) ...
prob.Constraints.retTarget = mu' * w >= retLo;    % placeholder, overwritten below

nPoints = 20;
targets = linspace(retLo, retHi, nPoints);
riskPath = zeros(nPoints, 1);
retPath  = zeros(nPoints, 1);
wPath    = zeros(nAssets, nPoints);

for k = 1:nPoints
    prob.Constraints.retTarget = mu' * w >= targets(k);
    [sol, ~, exitflag] = solve(prob);
    if exitflag <= 0
        warning("Frontier point %d did not converge (exitflag=%d).", k, exitflag);
        continue
    end
    wPath(:, k)  = sol.w;
    riskPath(k)  = sqrt(sol.w' * Sigma * sol.w);
    retPath(k)   = mu' * sol.w;
end
```

Reassigning the constraint replaces only that field on the problem object;
`optimproblem` does not re-parse the objective or the other constraints.

**Anti-pattern to avoid.** Building a single `prob` up-front (with
`retTarget` already attached), solving the lower endpoint from it, then
overwriting the objective for the upper endpoint, then looping the
interior sweep on the same object. The endpoint solves get a stray
`retTarget` constraint they should not carry, and downstream edits to
`prob.Constraints` risk propagating between roles. Either give each role
its own `optimproblem` or use `rmfield(prob.Constraints, "retTarget")`
explicitly for the endpoint solves — better yet, add `retTarget` only
after the endpoints are done.

## Plot convention — risk on x, return on y

Efficient frontiers plot **risk on the x-axis, expected return on the
y-axis**. The frontier appears as a concave-up-to-the-right curve. This is
the convention every finance textbook and every `Portfolio` plot uses;
matching it makes the shape read as an efficient frontier at a glance.

Swapping the axes — return on x, risk on y — leaves the data correct but
makes the curve look convex and read as *inefficient at a glance*.

```matlab
figure;
plot(riskPath, retPath);
xlabel("Risk (standard deviation)");
ylabel("Expected return");
title("Efficient frontier");
grid on;
```

## Frontier shape sanity check

After solving, verify the frontier is monotone-nondecreasing in return as
risk increases:

```matlab
tol = 1e-6;   % slack for solver tolerance in the return path
assert(all(diff(retPath) >= -tol), "Frontier is not monotone in return.");
```

If the check fails, the most likely cause is one of:

- **Min-return endpoint bug** — first few interior points lie on the
  inefficient lower branch.
- **Equality-target sweep on a non-convex feasibility set** — the equality
  forced the solver onto a dominated point.
- **`ga` non-determinism on MIQP dispatch** — a single `ga` run can leave
  small ripples in the interior points. This is expected on MIQP-shaped
  frontiers; it is not a bug. Report `ga` results as heuristic. If the
  monotonicity check fails and the frontier was solved via `ga`, do not
  re-solve on your own: warn the user that the frontier is not monotone
  and suggest re-solving with different seeds, keeping at each target the
  feasible point with the minimum risk (the closest to the true frontier).
  Do not average across seeds.

## Common mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|----------------|------------------|
| Min-return LP for the lower endpoint | Walks the inefficient lower branch of the parabola; the low-return sweep points are Pareto-dominated | Min-variance QP for lower endpoint |
| Return target as equality `mu' * w == target` | On non-convex feasibility sets, forces dominated points | Inequality `mu' * w >= target` |
| `retTarget` placeholder attached to the endpoint problems | Endpoint solves carry a stray return constraint; a placeholder like `mu' * w >= 0` is not always trivially satisfied and changes the feasibility set | Add `retTarget` only when preparing the interior sweep, after both endpoints are solved |
| Rebuilding `optimproblem` inside the loop | Re-parses symbolic expressions on every iteration | Build once outside; reassign only the RHS of the target constraint |
| Return on x-axis, risk on y-axis | Convex-looking curve reads as inefficient | Risk on x, return on y |
| Averaging `ga` results across seeds on a MIQP-shaped frontier | Averaging blends dominated points into "the frontier"; the mean of feasible points is not itself efficient | A single `ga` run is fine; if you do run multiple seeds, keep the feasible point with minimum risk at each target |

----

Copyright 2026 The MathWorks, Inc.

----
