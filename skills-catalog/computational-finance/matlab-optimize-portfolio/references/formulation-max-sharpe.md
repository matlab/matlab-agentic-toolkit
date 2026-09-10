# Formulation: Maximum Sharpe Ratio (Tangency) Portfolio

## Problem Statement

Maximize the Sharpe ratio (risk-adjusted return):

```
maximize    (μ'w - rf) / sqrt(w' * Σ * w)
subject to  sum(w) = 1        (fully invested)
            w >= 0            (long-only, optional)
            additional constraints
```

This is a nonlinear objective (ratio of linear over square root of quadratic). The Portfolio object reformulates it internally as a QP via variable substitution.

## When This Formulation Applies

- User wants to **maximize the Sharpe ratio**
- User asks about the **tangency portfolio** or **optimal risk-adjusted portfolio**
- User wants the **Capital Market Line (CML)** tangent point
- User is trying to use fmincon to maximize return/risk ratio

## Key Method: `estimateMaxSharpeRatio`

### Direct method (default, recommended)
```matlab
weights = estimateMaxSharpeRatio(p);
```

### With buy/sell information
```matlab
[weights, buy, sell] = estimateMaxSharpeRatio(p);
% buy/sell relative to p.InitPort
```

### Iterative method (required for cardinality/semicontinuous constraints)
```matlab
weights = estimateMaxSharpeRatio(p, 'Method', 'iterative');
```

## Algorithm (Direct Method)

The direct method transforms the nonlinear Sharpe ratio into a QP:

1. Substitution: t = 1/(μ'x - rf), y = t*x
2. Solve: minimize y'Σy subject to μ'y - rf*sum(y) = 1 and transformed constraints
3. Recover: x* = y* / sum(y*)

This yields a global optimum in one solve. The iterative method instead evaluates Sharpe ratio at many points along the frontier using `fminbnd` — slower but handles discrete constraints.

## Typical Workflow

```matlab
% 1. Setup (risk-free rate is important for Sharpe ratio)
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, 'RiskFreeRate', rf);
p = setDefaultConstraints(p);

% 2. Solve
weights = estimateMaxSharpeRatio(p);

% 3. Analyze
[risk, ret] = estimatePortMoments(p, weights);
sharpe = estimatePortSharpeRatio(p, weights);
fprintf('Return: %.4f, Risk: %.4f, Sharpe: %.4f\n', ret, risk, sharpe);

% 4. Visualize on frontier
wFrontier = estimateFrontier(p, 20);
plotFrontier(p, wFrontier);
hold on
plot(risk, ret, 'r*', 'MarkerSize', 12);
legend('Efficient Frontier', 'Max Sharpe Portfolio');
hold off
```

## Common Pitfalls

1. **User writes their own objective function** — The Sharpe ratio is nonlinear. Users who try fmincon directly often hit convergence issues or local optima. `estimateMaxSharpeRatio` uses the variable substitution trick to get a global optimum via QP.

2. **Negative excess returns** — If all asset means are below the risk-free rate, maximizing Sharpe ratio is ill-defined (the "best" portfolio has the least negative Sharpe). Warn the user.

3. **Missing risk-free rate** — Defaults to 0. If the user has a nonzero risk-free rate, they must set it on the Portfolio object — either at construction or via property assignment:
   ```matlab
   p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, 'RiskFreeRate', rf);
   % or after construction:
   p.RiskFreeRate = rf;
   ```
   **Do NOT pass `'RiskFreeRate'` as an argument to `estimateMaxSharpeRatio`** — it only accepts `'Method'` and `'TolX'`.

4. **Cardinality/semicontinuous constraints with default method** — These need `'Method','iterative'`. MATLAB auto-selects it with a warning if omitted, but specifying it explicitly is cleaner and avoids the warning.

5. **Short selling** — To allow short positions, replace `setDefaultConstraints` with explicit budget and bound constraints:
   ```matlab
   p = setBudget(p, 1, 1);
   p = setBounds(p, -1, 1);
   ```

----

Copyright 2026 The MathWorks, Inc.

----
