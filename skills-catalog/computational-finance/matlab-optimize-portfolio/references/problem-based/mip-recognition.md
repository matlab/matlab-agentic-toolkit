# Recognize MIP Problems and Reject Anti-Patterns

Before picking a decomposition, decide the *class* of the problem. A
portfolio problem is a **mixed-integer program (MIP)** whenever it needs
integer or binary decision variables — not only for integer lots. Common
sources of integer variables in portfolio problems:

- **Integer lots or whole shares** — the position itself is integer.
- **Fixed per-trade or per-lot costs** — a binary "trade / no trade"
  indicator to switch the cost on and off (`references/problem-based/trade-aux-variables.md`).
- **Cardinality constraints** — a binary selector per asset with `sum <= K`
  (see also semi-integer bounds in `references/problem-based/disjunctive-big-m.md`).
- **Minimum trade size as a disjunction** — `|w - w0| >= δ` OR `w = w0`
  needs a direction binary and big-M (`references/problem-based/disjunctive-big-m.md`).
- **Semi-integer / semi-continuous positions** — `w = 0` OR `L <= w <= U`
  (`references/problem-based/disjunctive-big-m.md`).
- **Tax-lot decisions** — a binary "sell this lot / do not sell this lot"
  or an integer share count from a lot (`references/problem-based/tax-aware-constraints.md`).
- **Wash-sale coupling** — a binary buy indicator that must go to zero when
  the associated loss lot is sold (`references/problem-based/tax-aware-constraints.md`).

**The right pattern.** Use `optimvar(..., "Type", "integer")` for the
integer decision variable and let `solve` dispatch — `intlinprog` for MILP,
`ga` for MIQP.

**Prefer linear reformulations over MINLP.** When the "nonlinearity" is
`abs()`, `max()`, disjunction, or a fixed cost on a positive activity, a
linear reformulation almost always exists via auxiliary variables and
big-M constraints. Reach for `ga` only when the nonlinearity is real
(nonconvex utility, nonlinear risk metric) — it is slow, non-deterministic,
and gives no optimality guarantee.

## Three MIP anti-patterns to reject

Three common ways of avoiding the standard MIP pattern. All three yield
wrong or dominated answers.

### (a) Signed decision variable with `abs()` in the objective

A signed integer lot variable with `abs()` in the objective (typically to
express a symmetric or fixed commission) forces the problem into MINLP —
nonlinear only because of the formulation choice. `solve` dispatches to
`ga` and every solve is non-deterministic.

```matlab
% Anti-pattern: k is a signed integer, positive = buy, negative = sell
k = optimvar("k", nAssets, Type="integer", LowerBound=-Kmax, UpperBound=Kmax);
commission = fcn2optimexpr(@(k) 5*sum(abs(k)), k);          % ✗ nonlinear -> ga
prob.Objective = mu' * (price .* (h0 + lotSize*k)) - commission;
```

**Fix.** Buy/sell aux split (`references/problem-based/trade-aux-variables.md`). Two non-negative integer aux vars,
`commission` becomes linear, dispatch drops to `intlinprog`.

### (b) Continuous relaxation + rounding

A continuous `Portfolio` + `estimateFrontier` + `round` on the output. The
rounded point is not the efficient frontier of the discrete problem — it
is commonly Pareto-dominated by other integer allocations reachable by lot
swaps. Greedy "repair" heuristics restore feasibility, not optimality.

```matlab
% Anti-pattern — TEMPLATE — not executable
p = Portfolio(AssetMean=mu, AssetCovar=Sigma);
p = setDefaultConstraints(p);
pwgt = estimateFrontier(p, 10);
lots = round(V0 * pwgt ./ (lotSize * price));              % ✗ not the frontier
```

**Fix.** Formulate the discrete problem directly with
`optimvar(..., "Type", "integer")` and call `solve` (`references/problem-based/trade-aux-variables.md`).

### (c) Hand-rolled branch-and-bound

A DIY branch-and-bound driver — priority queue, `solveRelax` wrapping
`quadprog`, per-point warm-start plumbing — instead of `optimproblem` +
integer `optimvar`. Redundant with `intlinprog`/`ga` and error-prone.

**Fix.** `solve` dispatches to `intlinprog` and `ga` automatically when
integer variables are present. Both are correctness-hardened.


----

Copyright 2026 The MathWorks, Inc.

----
