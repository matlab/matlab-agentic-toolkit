# Formulation: Mean-Variance (Markowitz) Portfolio Optimization

## Problem Statement

Minimize portfolio variance (risk) subject to constraints:

```
minimize    w' * Σ * w
subject to  sum(w) = 1        (fully invested)
            w >= 0            (long-only, optional)
            additional constraints (bounds, groups, etc.)
```

Optionally, with a target return constraint:
```
            μ' * w >= targetReturn
```

## When This Formulation Applies

- User wants the **minimum-variance portfolio** (lowest risk, no return target)
- User wants to **minimize risk for a given target return**
- User wants to **trace the efficient frontier**
- User asks about "Markowitz optimization" or "mean-variance optimization"
- User is trying to use quadprog to minimize w'Σw

## Key Methods

### Frontier Endpoints: `estimateFrontierLimits`

Returns the portfolios at the endpoints of the efficient frontier.

```matlab
wMinVar = estimateFrontierLimits(p, 'Min');  % minimum-variance portfolio
wMaxRet = estimateFrontierLimits(p, 'Max');  % maximum-return portfolio
wBoth   = estimateFrontierLimits(p);         % [wMinVar, wMaxRet] (both columns)
```

- `'Min'` — the left-most point on the frontier (lowest risk)
- `'Max'` — the right-most point on the frontier (highest return)
- No argument — returns both as an N-by-2 matrix

### Target-Return Portfolio: `estimateFrontierByReturn`

Find the minimum-variance portfolio that achieves a specified target return.

```matlab
wTarget = estimateFrontierByReturn(p, targetReturn);
```

- Can pass a vector of target returns to get multiple portfolios at once
- Returns are infeasible if below min-variance return or above max-return

### Target-Risk Portfolio: `estimateFrontierByRisk`

Find the maximum-return portfolio at a specified risk level.

```matlab
wTarget = estimateFrontierByRisk(p, targetRisk);
```

### Efficient Frontier: `estimateFrontier`

Compute equally-spaced portfolios along the entire efficient frontier.

```matlab
wFrontier = estimateFrontier(p, nPortfolios);  % N-by-nPortfolios matrix
```

## Typical Workflow

```matlab
% 1. Setup
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = setDefaultConstraints(p);

% 2. Solve for minimum-variance portfolio
wMinVar = estimateFrontierLimits(p, 'Min');

% 3. Analyze
portRisk = estimatePortRisk(p, wMinVar);
portRet  = estimatePortReturn(p, wMinVar);
fprintf('Risk: %.4f, Return: %.4f\n', portRisk, portRet);

% 4. Efficient frontier
wFrontier = estimateFrontier(p, 20);
plotFrontier(p, wFrontier);
```

## Relationship to Max Sharpe Ratio

The maximum Sharpe ratio portfolio lies on the efficient frontier — it is the point where a line from the risk-free rate is tangent to the frontier. If the user wants this specific point, use [formulation-max-sharpe.md](formulation-max-sharpe.md) instead.

## Common Pitfalls

1. **Using quadprog directly** — The Portfolio object handles the QP formulation internally. Users who build H, f, Aeq, beq matrices manually often get sign conventions or constraint setup wrong.

2. **Requesting infeasible target returns** — If `targetReturn` is outside the range [min-variance return, max-return], `estimateFrontierByReturn` will error. Check the feasible range first:
   ```matlab
   wLimits = estimateFrontierLimits(p);
   muRange = estimatePortReturn(p, wLimits);  % [minReturn; maxReturn]
   ```

3. **Confusing risk and variance** — `estimatePortRisk` returns standard deviation (not variance). The Portfolio object works in std-dev space throughout.

----

Copyright 2026 The MathWorks, Inc.

----
