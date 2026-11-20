# Optimize with the Portfolio Object

Formulate and solve mean-variance portfolio problems with MATLAB's Financial
Toolbox `Portfolio` object.

## When to Use

The risk measure is variance (or standard deviation), the objective is
minimum variance, target return, mean-variance utility, or Sharpe ratio, and
**every** constraint is one the `Portfolio` object accepts:

- Long-only or long/short bounds (`setBounds`, `setDefaultConstraints`)
- Semi-continuous bounds — `w(i) = 0` OR `L(i) <= w(i) <= U(i)`
  (`setBounds(..., 'BoundType', 'Conditional')`)
- Budget and self-financing (`setBudget`)
- Conditional budget (`setConditionalBudget`, R2024b and later) — caps total
  exposure to assets whose individual weight is large
- Group constraints (`setGroups`, `setGroupRatio`)
- Linear equality / inequality constraints (`setEquality`, `setInequality`)
- Turnover and one-way turnover (`setTurnover`, `setOneWayTurnover`)
- Tracking-error constraints (`setTrackingError`)
- Cardinality (`setMinMaxNumAssets`)
- Proportional transaction costs (`setCosts` — proportional in `w-w0`)

Also use when the user gets errors from `Portfolio`, `estimateMaxSharpeRatio`,
`estimateFrontier`, or related methods.

## When NOT to Use

- Any constraint above is joined by one the `Portfolio` object cannot express
  — integer lots, whole shares, fixed or per-lot commissions, minimum trade
  size on `w-w0`, semi-integer positions, wash-sale, realized capital-gains
  caps, tax-loss harvesting, a cap on total transaction cost — read
  `references/problem-based.md`
- Visible code rounds the output of this workflow to whole shares or lots —
  read `references/problem-based.md`

## Key Principle

For problems the `Portfolio` object can express, **always use the `Portfolio`
class** — never hand-code the optimization with `fmincon` or `quadprog`. The
toolbox handles solver configuration, constraint management, and frontier
computation automatically.

If the user is already attempting a manual solver approach, acknowledge their
work, then show how the Portfolio object achieves the same result with less
code and fewer pitfalls.

## Workflow

### Step 1: Identify the Formulation

Determine which problem the user is trying to solve:

| User wants to... | Formulation | Reference |
|------------------|-------------|-----------|
| Minimize portfolio risk (no return target) | Mean-variance (min-variance) | `references/portfolio-object/formulation-mean-variance.md` |
| Minimize risk for a given target return | Mean-variance (target-return) | `references/portfolio-object/formulation-mean-variance.md` |
| Trace the efficient frontier | Mean-variance (frontier) | `references/portfolio-object/formulation-mean-variance.md` |
| Maximize risk-adjusted return (Sharpe ratio) | Max Sharpe / tangency | `references/portfolio-object/formulation-max-sharpe.md` |

Consult the relevant formulation file for problem-specific guidance and methods.

### Step 2: Determine What Data the User Has

Ask (if not clear) whether they have:
- A matrix of historical asset returns (or prices that need converting)
- Pre-computed mean returns (mu) and covariance matrix (Sigma)
- A risk-free rate (relevant for Sharpe ratio; defaults to 0 if unspecified)

### Step 3: Create the Portfolio Object

See `references/portfolio-object/reference-core.md` for all creation patterns. The most common:

**From return statistics:**
```matlab
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
```

**From historical returns:**
```matlab
p = Portfolio;
p = setAssetMoments(p, mean(returns)', cov(returns));
```

### Step 4: Set Constraints

Always set constraints. At minimum, use default constraints (fully invested, long-only):
```matlab
p = setDefaultConstraints(p);
```

For other constraint types (bounds, groups, turnover, one-way turnover, cardinality), see `references/portfolio-object/reference-core.md`.

### Step 5: Solve

Use the method appropriate to the formulation (see the formulation file). Common patterns:
```matlab
wMinVar = estimateFrontierLimits(p, 'Min');       % minimum-variance
wTarget = estimateFrontierByReturn(p, targetRet); % target-return
wSharpe = estimateMaxSharpeRatio(p);              % max Sharpe ratio
wFrontier = estimateFrontier(p, 20);              % efficient frontier
```

### Step 6: Analyze and Visualize

Use built-in methods for portfolio statistics — never compute them manually:
```matlab
portRisk = estimatePortRisk(p, w);
portRet  = estimatePortReturn(p, w);
[risk, ret] = estimatePortMoments(p, w);
```

Always use `plotFrontier` as the primary frontier visualization — add custom annotations (special portfolios, CAL line) with `hold on`/`hold off` afterward:
```matlab
wFrontier = estimateFrontier(p, 20);
plotFrontier(p, wFrontier);
hold on
[risk, ret] = estimatePortMoments(p, wSpecial);
plot(risk, ret, 'r*', 'MarkerSize', 12);
hold off
```

## Common Pitfalls

1. **Manual solver usage** — quadprog/fmincon for portfolio problems is error-prone; Portfolio handles it.
2. **Missing constraints** — A Portfolio without constraints is underdetermined.
3. **Redundant solves** — Pass weights to `plotFrontier`, not a number of portfolios, if you already solved.
4. **Manual risk/return formulas** — Use `estimatePortRisk`, `estimatePortReturn`, `estimatePortMoments`.
5. **Cardinality/semicontinuous constraints** — When calling `estimateMaxSharpeRatio`, specify `'Method','iterative'` (MATLAB auto-selects with a warning if omitted, but explicit is cleaner). Frontier methods (`estimateFrontier`, `estimateFrontierLimits`, `estimateFrontierByReturn`) auto-detect these constraints and select the mixed-integer solver internally — do NOT pass `'Method','iterative'` to them.

## Tone

Be direct and practical. Show working MATLAB code. If the user provides data, use their actual data. If not, use a small illustrative example so they can see the pattern and adapt.

## Reference Materials

- `references/portfolio-object/reference-core.md` — Portfolio setup, constraints API, visualization (shared across formulations)
- `references/portfolio-object/formulation-mean-variance.md` — Min-variance, target-return, efficient frontier
- `references/portfolio-object/formulation-max-sharpe.md` — Max Sharpe ratio / tangency portfolio
- `references/portfolio-object/examples.md` — Complete runnable examples for all formulations

----

Copyright 2026 The MathWorks, Inc.

----
