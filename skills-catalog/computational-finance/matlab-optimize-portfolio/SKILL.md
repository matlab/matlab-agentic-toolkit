---
name: matlab-optimize-portfolio
description: Help users formulate and solve portfolio optimization problems using Financial Toolbox's Portfolio object. Covers mean-variance (Markowitz), maximum Sharpe ratio (tangency), and efficient frontier workflows. Use when users ask about portfolio optimization, Markowitz, efficient frontier, Sharpe ratio, or attempt to use generic solvers (quadprog, fmincon, ga, problem-based optimize) for portfolio problems.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Portfolio Optimization with Financial Toolbox

You are helping a user formulate and solve a portfolio optimization problem using MATLAB's Financial Toolbox `Portfolio` object.

## When to Use

- User wants to optimize a portfolio (minimize variance, maximize Sharpe ratio, trace efficient frontier)
- User asks about Markowitz, mean-variance, minimum-variance, or tangency portfolios
- User asks about the efficient frontier or target-return portfolios
- User is trying to use fmincon, quadprog, ga, or problem-based optimize for portfolio optimization (redirect to Portfolio object)
- User asks how to set up constraints for portfolio optimization (bounds, groups, turnover, one-way turnover, cardinality, semicontinuous)
- User asks about mean-variance with cardinality or semi-continuous constraints
- User gets errors from Portfolio, estimateMaxSharpeRatio, estimateFrontier, or related methods

## When NOT to Use

- User has a general optimization problem (QP, NLP, MILP) that is NOT financial asset allocation (e.g., filter design, resource allocation, mixture proportions) — use `matlab-solve-optimization`
- User needs to retrieve market data from Bloomberg, FRED, or Haver Analytics — use `matlab-access-datafeed`
- User wants to predict returns or portfolio weights using neural networks or ML — use `matlab-train-network`
- User only wants to clean, explore, or summarize a returns table without optimization — use `matlab-analyze-data`
- User wants Experiment Manager parameter sweeps (not portfolio frontier) — use `matlab-create-experiment`
- User wants CVaR, MAD, or other non-mean-variance risk measures — use `PortfolioCVaR` or `PortfolioMAD` classes (not covered by this skill)

## Key Principle

**Always use the `Portfolio` class** — never let users manually code the optimization with `fmincon` or `quadprog`. The toolbox handles solver configuration, constraint management, and frontier computation automatically.

If the user is already attempting a manual solver approach, acknowledge their work, then show how the Portfolio object achieves the same result with less code and fewer pitfalls.

## Step 1: Identify the Formulation

Determine which problem the user is trying to solve:

| User wants to... | Formulation | Reference |
|------------------|-------------|-----------|
| Minimize portfolio risk (no return target) | Mean-variance (min-variance) | [formulation-mean-variance.md](references/formulation-mean-variance.md) |
| Minimize risk for a given target return | Mean-variance (target-return) | [formulation-mean-variance.md](references/formulation-mean-variance.md) |
| Trace the efficient frontier | Mean-variance (frontier) | [formulation-mean-variance.md](references/formulation-mean-variance.md) |
| Maximize risk-adjusted return (Sharpe ratio) | Max Sharpe / tangency | [formulation-max-sharpe.md](references/formulation-max-sharpe.md) |

Consult the relevant formulation file for problem-specific guidance and methods.

## Step 2: Determine What Data the User Has

Ask (if not clear) whether they have:
- A matrix of historical asset returns (or prices that need converting)
- Pre-computed mean returns (mu) and covariance matrix (Sigma)
- A risk-free rate (relevant for Sharpe ratio; defaults to 0 if unspecified)

## Step 3: Create the Portfolio Object

See [reference-core.md](references/reference-core.md) for all creation patterns. The most common:

**From return statistics:**
```matlab
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
```

**From historical returns:**
```matlab
p = Portfolio;
p = setAssetMoments(p, mean(returns)', cov(returns));
```

## Step 4: Set Constraints

Always set constraints. At minimum, use default constraints (fully invested, long-only):
```matlab
p = setDefaultConstraints(p);
```

For other constraint types (bounds, groups, turnover, one-way turnover, cardinality), see [reference-core.md](references/reference-core.md).

## Step 5: Solve

Use the method appropriate to the formulation (see the formulation file). Common patterns:
```matlab
wMinVar = estimateFrontierLimits(p, 'Min');       % minimum-variance
wTarget = estimateFrontierByReturn(p, targetRet); % target-return
wSharpe = estimateMaxSharpeRatio(p);              % max Sharpe ratio
wFrontier = estimateFrontier(p, 20);              % efficient frontier
```

## Step 6: Analyze and Visualize

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

- [reference-core.md](references/reference-core.md) — Portfolio setup, constraints API, visualization (shared across formulations)
- [formulation-mean-variance.md](references/formulation-mean-variance.md) — Min-variance, target-return, efficient frontier
- [formulation-max-sharpe.md](references/formulation-max-sharpe.md) — Max Sharpe ratio / tangency portfolio
- [examples.md](references/examples.md) — Complete runnable examples for all formulations

----

Copyright 2026 The MathWorks, Inc.

----
