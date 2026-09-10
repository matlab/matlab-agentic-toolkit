# Portfolio Object — Core API Reference

## Portfolio Object Creation

### From pre-computed statistics
```matlab
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, 'RiskFreeRate', rf);
```

### From historical return data
```matlab
p = Portfolio;
p = setAssetMoments(p, mean(returns)', cov(returns));
% or let the object estimate moments from a time series:
p = estimateAssetMoments(p, returns);
```

### From price data (convert to returns first)
```matlab
returns = tick2ret(prices);  % log returns from price series
p = Portfolio;
p = estimateAssetMoments(p, returns);
```

### Optional metadata
```matlab
p = Portfolio('AssetList', ["AAPL","MSFT","GOOG"], ...
              'AssetMean', mu, 'AssetCovar', Sigma);
```

**Note:** `p.AssetList` is stored as a cell array of character vectors regardless of input type. Use curly-brace indexing (`p.AssetList{i}`) or convert with `string(p.AssetList)` before passing to `fprintf` or string operations.

### Setting the risk-free rate
```matlab
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, 'RiskFreeRate', 0.02);
% or after construction:
p.RiskFreeRate = 0.02;
```
**Note:** `estimateMaxSharpeRatio` does NOT accept a `'RiskFreeRate'` argument — it reads from the Portfolio object. Only `'Method'` and `'TolX'` are valid name-value pairs for that function.

### Periodicity and annualization

The Portfolio object is periodicity-agnostic — all outputs (`estimatePortRisk`, `estimatePortReturn`, `plotFrontier`, etc.) inherit the periodicity of the inputs. If the desired analysis periodicity differs from the data periodicity (e.g., user wants annualized results but has daily returns), convert the moments *before* creating the Portfolio. This way all downstream analysis produces results in the target periodicity directly, with no manual conversions in plotting or reporting code.

**From pre-computed statistics (annualize before passing in):**
```matlab
muAnn = muDaily * 252;
SigmaAnn = SigmaDaily * 252;
rfAnn = rfDaily * 252;
p = Portfolio('AssetMean', muAnn, 'AssetCovar', SigmaAnn, 'RiskFreeRate', rfAnn);
```

**From historical data via estimateAssetMoments (rescale after estimation):**
```matlab
p = Portfolio;
p = estimateAssetMoments(p, dailyReturns);
p.AssetMean = p.AssetMean * 252;
p.AssetCovar = p.AssetCovar * 252;
p.RiskFreeRate = rfDaily * 252;
```

All inputs must share the same periodicity — `AssetMean`, `AssetCovar`, and `RiskFreeRate` must all be expressed in the same units (daily, monthly, or annual).

## Constraints

### Default constraints (fully invested, long-only)
```matlab
p = setDefaultConstraints(p);
% Equivalent to:
%   p = setBudget(p, 1, 1);   % weights sum to 1
%   p = setBounds(p, 0, 1);   % each weight in [0, 1]
```

### Bounds (upper/lower limits per asset)
```matlab
p = setBounds(p, 0, 0.10);           % all assets: 0% to 10%
p = setBounds(p, lbVector, ubVector); % per-asset vectors
```

### Budget constraint (weights sum)
```matlab
p = setBudget(p, 1, 1);     % fully invested (sum = 1)
p = setBudget(p, 0.9, 1.1); % allow 90%-110% invested
```

### Allow short selling
```matlab
p = setBudget(p, 1, 1);
p = setBounds(p, -0.3, 1);   % short up to 30%, long up to 100%
```

### Group/sector constraints
```matlab
GroupMatrix = [1 1 0 0 0;    % assets 1-2 = sector A
              0 0 1 1 1];   % assets 3-5 = sector B
p = setGroups(p, GroupMatrix, [0.2; 0.3], [0.6; 0.7]);
% sector A: 20%-60%, sector B: 30%-70%
```

### Cardinality constraints (min/max number of assets)
```matlab
p = setMinMaxNumAssets(p, 3, 5);  % hold between 3 and 5 assets
% NOTE: requires 'Method','iterative' when calling estimateMaxSharpeRatio.
% Frontier methods (estimateFrontier, estimateFrontierLimits) auto-detect.
```

**Important:** Cardinality alone does not prevent near-zero allocations. Pair with
conditional bounds to enforce a meaningful minimum position size:
```matlab
p = setMinMaxNumAssets(p, 3, 5);
p = setBounds(p, 0.05, 0.5, 'BoundType', 'Conditional');
% Each asset is either 0% (not held) or between 5% and 50%
```

### Semicontinuous bounds (minimum position size if held)
```matlab
p = setBounds(p, 0.02, 0.5, 'BoundType', 'Conditional');
% Each asset is either 0% or at least 2%
% NOTE: requires 'Method','iterative' when calling estimateMaxSharpeRatio.
% Frontier methods (estimateFrontier, estimateFrontierLimits) auto-detect.
```

### Turnover constraints
```matlab
p = setTurnover(p, 0.15);       % max 30% total turnover (constraint is 0.5*sum(|w-w0|) <= T)
p.InitPort = currentWeights;    % current portfolio for turnover calc
```

### One-way turnover constraints
```matlab
p = setOneWayTurnover(p, 0.10, 0.15);  % max 10% purchases, max 15% sales
p.InitPort = currentWeights;
```
`setOneWayTurnover(p, BuyTurnover, SellTurnover)` constrains purchases and sales independently:
- `sum(max(w - w0, 0)) <= BuyTurnover`
- `sum(max(w0 - w, 0)) <= SellTurnover`

Use instead of `setTurnover` when buy/sell costs are asymmetric or when rebalancing policy limits purchases differently from sales.

### Tracking error constraint
```matlab
benchmarkWgts = [0.2; 0.2; 0.2; 0.2; 0.2];
p = setTrackingError(p, 0.05, benchmarkWgts);  % max 5% TE
% NOTE: requires fmincon solver
```

### Linear inequality constraints (custom)
```matlab
% A*w <= b
A = [1 1 0 0 0];   % e.g., first two assets combined <= 40%
b = 0.4;
p = setInequality(p, A, b);
```

## Post-Solution Analysis

Always use built-in methods — never compute risk/return manually.

```matlab
portRisk = estimatePortRisk(p, w);           % standard deviation
portRet  = estimatePortReturn(p, w);         % expected return
[risk, ret] = estimatePortMoments(p, w);     % both at once
sharpe = estimatePortSharpeRatio(p, w);      % Sharpe ratio
```

These methods accept single portfolios (N-by-1) or multiple portfolios (N-by-K columns).

## Visualization

### Efficient frontier plot (from pre-computed weights)
```matlab
wFrontier = estimateFrontier(p, 20);
plotFrontier(p, wFrontier);
```

### Annotating special portfolios on the frontier
```matlab
wFrontier = estimateFrontier(p, 20);
plotFrontier(p, wFrontier);
hold on
[risk, ret] = estimatePortMoments(p, wSpecial);
plot(risk, ret, 'r*', 'MarkerSize', 12);
legend('Efficient Frontier', 'Special Portfolio');
hold off
```

## Solver Configuration

### Default solver (quadprog — works for most problems)
No configuration needed; Portfolio uses quadprog by default.

### Custom solver settings
```matlab
p = setSolver(p, 'quadprog', 'Display', 'off', ...
    'ConstraintTolerance', 1e-8, 'OptimalityTolerance', 1e-8);
```

### fmincon solver (required for nonlinear constraints like tracking error)
```matlab
p = setSolver(p, 'fmincon', 'Display', 'off', 'Algorithm', 'sqp', ...
    'SpecifyObjectiveGradient', true, 'SpecifyConstraintGradient', true, ...
    'ConstraintTolerance', 1e-8, 'OptimalityTolerance', 1e-8);
```

----

Copyright 2026 The MathWorks, Inc.

----
