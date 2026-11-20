---
name: matlab-optimize-portfolio
description: >
  Formulate and solve portfolio optimization problems in MATLAB. Routes to the
  Financial Toolbox Portfolio object for mean-variance (Markowitz), minimum-
  variance, target-return, maximum Sharpe ratio, and efficient frontier
  problems with bounds, budget, group, turnover, tracking-error, or
  cardinality constraints; or to the problem-based framework
  (optimproblem/optimvar/solve) when constraints exceed what Portfolio can
  express: integer round lots, whole shares, per-lot or fixed commissions,
  minimum trade sizes, semi-integer positions, wash-sale rules, realized
  capital-gains caps, tax-loss harvesting, asymmetric or bucketed transaction-
  cost caps, or a custom efficient frontier over such constraints. Use when
  users ask about portfolio optimization, when they attempt quadprog, fmincon,
  intlinprog, or ga for a portfolio problem, or when code rounds Portfolio
  weights to whole shares or lots.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Portfolio Optimization in MATLAB

Formulate and solve portfolio optimization problems in MATLAB. Route to the
correct framework — the Financial Toolbox `Portfolio` object or the
problem-based framework (`optimproblem`/`optimvar`/`solve`) — based on the
constraints in the user's request, then follow that framework's reference for
implementation details.

## When to Use

- User wants to optimize a portfolio (minimize variance, maximize Sharpe ratio, trace efficient frontier)
- User asks about Markowitz, mean-variance, minimum-variance, target-return, or tangency portfolios
- User asks how to set up portfolio constraints (bounds, groups, turnover, one-way turnover, tracking error, cardinality, semicontinuous)
- User mentions **integer lots**, **round lots**, **whole shares**, or a **per-lot** / **per-trade** / **fixed** commission
- User mentions a **minimum trade size**, **semi-integer** position, or an either/or bound (`|w-w0| >= δ` OR `w = w0`)
- User mentions **wash sale**, **realized capital gains**, **tax-loss harvesting**, or **tax-aware rebalancing**
- User asks for an efficient frontier over constraints such as asymmetric or class-varying transaction-cost caps
- User is trying to use `quadprog`, `fmincon`, `intlinprog`, `ga`, or problem-based `solve` for a portfolio problem
- Visible code applies `round`/`floor`/`ceil` to `Portfolio` output to obtain whole shares or lots
- User gets errors from `Portfolio`, `estimateMaxSharpeRatio`, `estimateFrontier`, or related methods

## When NOT to Use

- General optimization problem (QP, NLP, MILP) that is NOT financial asset allocation (e.g., filter design, resource allocation, mixture proportions) — use `matlab-solve-optimization`
- User needs to retrieve market data from Bloomberg, FRED, or Haver Analytics — use `matlab-access-datafeed`
- User wants to predict returns or portfolio weights using neural networks or ML — use `matlab-train-network`
- User only wants to clean, explore, or summarize a returns table without optimization — use `matlab-analyze-data`
- User wants Experiment Manager parameter sweeps (not portfolio frontier) — use `matlab-use-experiment-manager`
- Covariance estimation from historical returns (`cov`, `covarianceShrinkage`, `covarianceDenoising`, `nearcorr`)
- Fixed-income analytics — yield curves, key-rate durations, cash-flow modeling
- Scenario-based or stochastic optimization — multi-stage, chance constraints
- CVaR, MAD, or other non-variance risk measures (`PortfolioCVaR`, `PortfolioMAD`), custom objectives (`estimateCustomObjectivePortfolio`), or custom frontiers over non-variance risk — **not covered by this skill.** Tell the user so, then proceed without this skill's guidance.

## Framework Routing

Identify the framework from the user's constraints and read the corresponding reference:

| Framework | Reference | When to Use |
|-----------|-----------|-------------|
| `Portfolio` object | `references/portfolio-object.md` | Mean-variance, max Sharpe, or efficient frontier where **every** constraint is one the `Portfolio` object accepts |
| Problem-based | `references/problem-based.md` | **Any** constraint the `Portfolio` object cannot express, alone or mixed with constraints it accepts |

### Routing Rules

**Read exactly one reference (and any relevant sub-references).** Apply the rules in order; the first match wins:

1. **Risk measure is not variance** (CVaR, MAD, downside deviation, custom risk) -> say this case is not covered by this skill and read neither reference
2. **Any constraint the `Portfolio` object cannot express** -> `references/problem-based.md`. One such constraint is enough, whatever else is in the problem:
   - Integer lots or whole shares
   - Fixed or per-lot commissions
   - Minimum trade size on the change `w-w0`
   - Semi-integer positions
   - Wash-sale rules, realized capital-gains caps, tax-loss harvesting
   - A cap on total, asymmetric, or bucketed transaction cost
3. **Visible code rounds `Portfolio` output** (`round`/`floor`/`ceil` on weights to get shares or lots) -> `references/problem-based.md`
4. **User names a `Portfolio` API** (`Portfolio`, `estimateFrontier*`, `estimateMaxSharpeRatio`, `setBounds`, ...) -> `references/portfolio-object.md`
5. **User writes `quadprog`/`fmincon`/`optimproblem` for a problem the `Portfolio` object can express** -> `references/portfolio-object.md`, and show the `Portfolio` equivalent
6. **Ambiguous** (e.g., "optimize my portfolio") -> `references/portfolio-object.md`

**Lookalike constraints** — check these before applying rule 2:

| Constraint | Framework |
|------------|-----------|
| Semi-continuous on the level: `w = 0` OR `L <= w <= U` | `Portfolio` (`setBounds(..., 'BoundType', 'Conditional')`) |
| Minimum trade on the change: `\|w-w0\| >= δ` OR `w = w0` | Problem-based |
| Proportional costs in net return | `Portfolio` (`setCosts`) |
| Proportional costs alone, not as part of net return | Problem-based |
| Cap on total cost, or a fixed fee per trade or lot | Problem-based |
| Cardinality on its own | `Portfolio` (`setMinMaxNumAssets`) |

## Shared Conventions

Both frameworks share these conventions:

- Validate MATLAB code with `check_matlab_code` and run it with `evaluate_matlab_code` (or `run_matlab_file` for a saved script) before returning it
- Plot efficient frontiers with risk on the x-axis and return on the y-axis
- Never `round`/`floor`/`ceil` continuous weights to obtain shares or lots
- State the decision-variable unit (weights, dollars, or shares) and use it consistently
- Always use `datetime` for dates (not `datenum`)
- Do not reuse `p` for both the `Portfolio` object and a price vector

## Common Mistakes (Cross-Framework)

| Mistake | Correct |
|---------|---------|
| Hand-coded `quadprog`/`fmincon` for a problem the `Portfolio` object can express | Use the `Portfolio` object — see `references/portfolio-object.md` |
| Forcing integer lots or fixed commissions into `Portfolio` with workarounds | Formulate in `optimproblem`/`optimvar` — see `references/problem-based.md` |
| Continuous solve followed by `round` to get lots | Formulate an integer program with `optimvar(..., 'Type', 'integer')` — see `references/problem-based.md` |
| `abs()` on a signed decision variable | Linearize with auxiliary variables (magnitude aux or buy/sell split) — see `references/problem-based.md` |
| Assuming `setCosts` can cap total transaction cost | `setCosts` models proportional costs only; a cost cap needs `references/problem-based.md` |

## Reference Materials

- `references/portfolio-object.md` — `Portfolio` object workflow: formulation choice, creation, constraints, solving, analysis, visualization
  - `references/portfolio-object/reference-core.md` — Portfolio setup, constraints API, visualization
  - `references/portfolio-object/formulation-mean-variance.md` — Min-variance, target-return, efficient frontier
  - `references/portfolio-object/formulation-max-sharpe.md` — Max Sharpe ratio / tangency portfolio
  - `references/portfolio-object/examples.md` — Complete runnable examples for all formulations
- `references/problem-based.md` — Problem-based workflow for custom constraints: formulate, dispatch, validate
  - `references/problem-based/mip-recognition.md` — MIP class recognition, MIP anti-patterns
  - `references/problem-based/trade-aux-variables.md` — Trade-magnitude aux vars, buy/sell aux split
  - `references/problem-based/disjunctive-big-m.md` — Min-trade and semi-integer big-M disjunctions
  - `references/problem-based/tax-aware-constraints.md` — Wash-sale rules, realized cap-gains caps
  - `references/problem-based/problem-based-framework.md` — Problem-based default, `fcn2optimexpr`, `solve` dispatch, solver options
  - `references/problem-based/problem-data-hygiene.md` — Decision-variable units, rescaling, coefficient-range checks
  - `references/problem-based/custom-frontier.md` — Endpoint problems, inequality target sweep, frontier plot convention

----

Copyright 2026 The MathWorks, Inc.

----
