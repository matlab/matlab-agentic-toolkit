# Portfolio Optimization — Complete Examples

## Mean-Variance Examples

### Example MV1: Minimum-Variance Portfolio (basic)

```matlab
% Asset statistics (5 assets)
mu = [0.08; 0.06; 0.12; 0.05; 0.10];
Sigma = [0.040 0.010 0.015 0.005 0.008;
         0.010 0.025 0.008 0.003 0.006;
         0.015 0.008 0.070 0.010 0.020;
         0.005 0.003 0.010 0.020 0.004;
         0.008 0.006 0.020 0.004 0.035];

% Create portfolio, set default constraints
p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = setDefaultConstraints(p);

% Minimum-variance portfolio
wMinVar = estimateFrontierLimits(p, 'Min');

% Analyze using built-in methods
portRisk = estimatePortRisk(p, wMinVar);
portRet  = estimatePortReturn(p, wMinVar);
fprintf('Min-Variance Portfolio:\n');
fprintf('  Risk (Std Dev): %.4f\n', portRisk);
fprintf('  Return:         %.4f\n', portRet);
fprintf('  Weights: %s\n', mat2str(wMinVar', 4));
```

### Example MV2: Minimum-Variance with Upper Bounds

```matlab
mu = [0.08; 0.06; 0.12; 0.05; 0.10; 0.07; 0.09; 0.11; 0.06; 0.08];
Sigma = 0.01*eye(10) + 0.005*ones(10);

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = setDefaultConstraints(p);
p = setBounds(p, 0, 0.15);  % max 15% per asset

wMinVar = estimateFrontierLimits(p, 'Min');
fprintf('Min-Variance Std Dev: %.4f\n', estimatePortRisk(p, wMinVar));
```

### Example MV3: Target-Return Portfolio

```matlab
mu = [0.08; 0.06; 0.12; 0.05; 0.10];
Sigma = [0.040 0.010 0.015 0.005 0.008;
         0.010 0.025 0.008 0.003 0.006;
         0.015 0.008 0.070 0.010 0.020;
         0.005 0.003 0.010 0.020 0.004;
         0.008 0.006 0.020 0.004 0.035];

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = setDefaultConstraints(p);

% Check feasible return range
wLimits = estimateFrontierLimits(p);
muRange = estimatePortReturn(p, wLimits);
fprintf('Feasible return range: [%.4f, %.4f]\n', muRange(1), muRange(2));

% Solve for a target return within the feasible range
targetRet = 0.09;
wTarget = estimateFrontierByReturn(p, targetRet);
fprintf('Target-Return Portfolio (target=%.2f%%):\n', targetRet*100);
fprintf('  Achieved Return: %.4f\n', estimatePortReturn(p, wTarget));
fprintf('  Risk:            %.4f\n', estimatePortRisk(p, wTarget));
```

### Example MV4: Efficient Frontier with Visualization

```matlab
mu = [0.08; 0.06; 0.12; 0.05; 0.10];
Sigma = [0.040 0.010 0.015 0.005 0.008;
         0.010 0.025 0.008 0.003 0.006;
         0.015 0.008 0.070 0.010 0.020;
         0.005 0.003 0.010 0.020 0.004;
         0.008 0.006 0.020 0.004 0.035];

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, ...
    'AssetList', ["Equities","Bonds","Growth","Defensive","Balanced"]);
p = setDefaultConstraints(p);

% Compute frontier and plot (pass weights to avoid redundant solves)
wFrontier = estimateFrontier(p, 20);
figure;
plotFrontier(p, wFrontier);
title('Mean-Variance Efficient Frontier');

% Annotate min-variance and max-return endpoints
wMinVar = estimateFrontierLimits(p, 'Min');
wMaxRet = estimateFrontierLimits(p, 'Max');
hold on
[rMin, retMin] = estimatePortMoments(p, wMinVar);
[rMax, retMax] = estimatePortMoments(p, wMaxRet);
plot(rMin, retMin, 'gs', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
plot(rMax, retMax, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
legend('Efficient Frontier', 'Min-Variance', 'Max-Return');
hold off
```

### Example MV5: From Historical Returns

```matlab
rng(42);
nAssets = 10;
nObs = 252;
assetReturns = 0.0004 + 0.02 * randn(nObs, nAssets);

p = Portfolio('AssetList', compose("Asset%d", 1:nAssets));
p = setAssetMoments(p, mean(assetReturns)', cov(assetReturns));
p = setDefaultConstraints(p);
p = setBounds(p, 0, 0.30);

% Minimum-variance
wMinVar = estimateFrontierLimits(p, 'Min');
fprintf('Min-Variance Std Dev: %.4f%%\n', 100*estimatePortRisk(p, wMinVar));

% Target-return at midpoint
wLimits = estimateFrontierLimits(p);
muRange = estimatePortReturn(p, wLimits);
targetRet = mean(muRange);
wTarget = estimateFrontierByReturn(p, targetRet);
fprintf('Target Return: %.4f%%, Std Dev: %.4f%%\n', ...
    100*targetRet, 100*estimatePortRisk(p, wTarget));

% Frontier
wFrontier = estimateFrontier(p, 20);
figure;
plotFrontier(p, wFrontier);
title('Mean-Variance Efficient Frontier');
```

---

## Max Sharpe Ratio Examples

### Example SR1: Basic — From Known Mean and Covariance

```matlab
mu = [0.3; 0.1; 0.5];
Sigma = [0.01  -0.010  0.004;
        -0.010  0.040 -0.002;
         0.004 -0.002  0.023];

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = setDefaultConstraints(p);
weights = estimateMaxSharpeRatio(p);

% Display
fprintf('Max Sharpe Weights: %s\n', mat2str(weights', 4));
sharpe = estimatePortSharpeRatio(p, weights);
fprintf('Sharpe Ratio: %.4f\n', sharpe);

% Visualize
wFrontier = estimateFrontier(p, 20);
figure;
plotFrontier(p, wFrontier);
[risk, ret] = estimatePortMoments(p, weights);
hold on
plot(risk, ret, 'r*', 'MarkerSize', 12);
legend('Efficient Frontier', 'Max Sharpe Portfolio', 'Location', 'southeast');
hold off
```

### Example SR2: From Historical Returns with Risk-Free Rate

```matlab
rng(42);
T = 252; N = 5;
returns = mvnrnd([0.0004 0.0003 0.0006 0.0002 0.0005], ...
    gallery('randcorr',5)*0.0004, T);

p = Portfolio;
p = estimateAssetMoments(p, returns);
p = setDefaultConstraints(p);
p.RiskFreeRate = 0.02/252;  % annualized 2%, converted to daily

weights = estimateMaxSharpeRatio(p);

[risk, ret] = estimatePortMoments(p, weights);
annualizedReturn = ret * 252;
annualizedRisk = risk * sqrt(252);
annualizedSharpe = (annualizedReturn - 0.02) / annualizedRisk;

fprintf('Annualized Return: %.2f%%\n', annualizedReturn*100);
fprintf('Annualized Risk:   %.2f%%\n', annualizedRisk*100);
fprintf('Sharpe Ratio:      %.4f\n', annualizedSharpe);
```

### Example SR3: With Sector Constraints

```matlab
mu = [0.10; 0.08; 0.14; 0.07; 0.12; 0.09];
Sigma = 0.01 * eye(6) + 0.005 * ones(6);

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, 'RiskFreeRate', 0.02);
p = setDefaultConstraints(p);

% Tech (assets 1-3): 20%-60%, Finance (assets 4-6): 30%-70%
GroupMatrix = [1 1 1 0 0 0;
              0 0 0 1 1 1];
p = setGroups(p, GroupMatrix, [0.20; 0.30], [0.60; 0.70]);

weights = estimateMaxSharpeRatio(p);
fprintf('Tech allocation:    %.1f%%\n', sum(weights(1:3))*100);
fprintf('Finance allocation: %.1f%%\n', sum(weights(4:6))*100);
fprintf('Sharpe Ratio:       %.4f\n', estimatePortSharpeRatio(p, weights));
```

### Example SR4: Cardinality Constraints (hold exactly K assets)

```matlab
mu = [0.0101; 0.0044; 0.0137; 0.0089; 0.0062];
Sigma = [0.0032  0.0002  0.0042  0.0010  0.0005;
         0.0002  0.0005  0.0002  0.0001  0.0001;
         0.0042  0.0002  0.0076  0.0015  0.0008;
         0.0010  0.0001  0.0015  0.0030  0.0003;
         0.0005  0.0001  0.0008  0.0003  0.0020];

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma);
p = setDefaultConstraints(p);
p = setMinMaxNumAssets(p, 3, 3);  % exactly 3 assets
p = setBounds(p, 0.05, 1, 'BoundType', 'Conditional');  % min 5% if held (prevents near-zero allocations)

% Must use iterative method for cardinality constraints
weights = estimateMaxSharpeRatio(p, 'Method', 'iterative');
fprintf('Assets held: %d\n', sum(weights > 1e-6));
fprintf('Weights: %s\n', mat2str(weights', 4));
```

### Example SR5: Full Workflow with CML Visualization

```matlab
mu = [0.12; 0.10; 0.18; 0.08; 0.14];
Sigma = [0.040 0.010 0.015 0.005 0.008;
         0.010 0.025 0.008 0.003 0.006;
         0.015 0.008 0.070 0.010 0.020;
         0.005 0.003 0.010 0.020 0.004;
         0.008 0.006 0.020 0.004 0.035];
rf = 0.03;
assetNames = {'Equities','Bonds','Growth','Defensive','Balanced'};

p = Portfolio('AssetMean', mu, 'AssetCovar', Sigma, ...
    'RiskFreeRate', rf, 'AssetList', assetNames);
p = setDefaultConstraints(p);

% Solve
weights = estimateMaxSharpeRatio(p);
[optRisk, optRet] = estimatePortMoments(p, weights);
optSharpe = estimatePortSharpeRatio(p, weights);

% Frontier
wFrontier = estimateFrontier(p, 50);

% Visualization
figure('Position', [100 100 1000 400])
tiledlayout(1, 2)

nexttile
plotFrontier(p, wFrontier); hold on
plot(optRisk, optRet, 'r*', 'MarkerSize', 12, 'LineWidth', 2);
% Capital Market Line
[maxRisk, ~] = estimatePortMoments(p, wFrontier(:,end));
cmlX = linspace(0, maxRisk*1.1, 100);
cmlY = rf + optSharpe * cmlX;
plot(cmlX, cmlY, 'r--', 'LineWidth', 1);
plot(0, rf, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
title('Efficient Frontier & Capital Market Line');
legend('Efficient Frontier', 'Max Sharpe Portfolio', 'CML', 'Risk-Free Rate', ...
    'Location', 'southeast');
hold off

nexttile
bar(weights);
set(gca, 'XTickLabel', assetNames, 'XTickLabelRotation', 45);
ylabel('Weight'); title(sprintf('Max Sharpe Portfolio (SR = %.3f)', optSharpe));
ylim([0 max(weights)*1.2]); grid on

fprintf('\nSharpe Ratio: %.4f\n', optSharpe);
fprintf('Expected Return: %.2f%%\n', optRet*100);
fprintf('Risk (Std Dev):  %.2f%%\n', optRisk*100);
```

----

Copyright 2026 The MathWorks, Inc.

----
