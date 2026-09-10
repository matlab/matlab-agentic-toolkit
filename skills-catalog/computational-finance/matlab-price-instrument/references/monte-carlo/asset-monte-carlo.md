# Asset Monte Carlo Pricing

Price equity and FX options using Monte Carlo simulation with `finpricer("AssetMonteCarlo", ...)`.

## Model-to-Pricer Mapping

The model you pass to the pricer determines the underlying SDE engine:

| finmodel | Vol Dynamics | Internal Pricer |
|----------|-------------|-----------------|
| `finmodel("BlackScholes", "Volatility", sigma)` | Constant vol (GBM) | GBMMonteCarlo |
| `finmodel("Heston", "V0", v0, "ThetaV", theta, "Kappa", kappa, "SigmaV", sigmaV, "RhoSV", rho)` | Stochastic vol | HestonMonteCarlo |
| `finmodel("Bates", "V0", v0, "ThetaV", theta, "Kappa", kappa, "SigmaV", sigmaV, "RhoSV", rho, "MeanJ", mu, "JumpVol", sigmaJ, "JumpFreq", lambda)` | Stochastic vol + jumps | BatesMonteCarlo |
| `finmodel("Merton", "Volatility", sigma, "MeanJ", mu, "JumpVol", sigmaJ, "JumpFreq", lambda)` | Constant vol + jumps | MertonMonteCarlo |
| `finmodel("Bachelier", "Volatility", sigma)` | Normal model | BachelierMonteCarlo |

For rough volatility models, use `finpricer("RoughVolMonteCarlo", ...)` instead:

| finmodel | Internal Pricer |
|----------|-----------------|
| `finmodel("RoughBergomi", "Alpha", alpha, "Eta", eta, "Xi", xi, "RhoSV", rho)` | RoughBergomiMonteCarlo |
| `finmodel("RoughHeston", "V0", v0, "ThetaV", theta, "Kappa", kappa, "SigmaV", sigmaV, "RhoSV", rho, "Alpha", alpha)` | RoughHestonMonteCarlo |

**RoughVolMonteCarlo works best with evenly spaced SimulationDates.** The documentation recommends uniform spacing for accuracy; non-uniform dates may work but can reduce simulation quality.

## Supported Instruments

| Instrument | Key Parameters | Notes |
|------------|---------------|-------|
| Vanilla | `ExerciseDate`, `Strike`, `OptionType`, `ExerciseStyle` | European, American (daily SimDates), Bermudan (SimDates must include all exercise dates). Bermudan `Strike` can be a vector (one per exercise date). |
| Asian | `ExerciseDate`, `Strike`, `OptionType`, `AverageType`, `AverageStartDate`, `AveragePrice` | `AverageType`: `"arithmetic"` or `"geometric"`. `Strike=NaN` for floating strike. `AveragePrice` is the running average to date for seasoned options (set `AverageStartDate` to when averaging began). |
| Barrier | `ExerciseDate`, `Strike`, `BarrierType`, `BarrierValue`, `Rebate` | `BarrierType`: `"di"`, `"do"`, `"ui"`, `"uo"`. Use `ExerciseStyle="american"` for continuous monitoring. |
| DoubleBarrier | `ExerciseDate`, `Strike`, `BarrierType`, `BarrierValue`, `Rebate` | `BarrierType`: `"dki"`, `"dko"`. `BarrierValue` is `[UpperBarrier LowerBarrier]`. `Rebate` can be scalar or `[UpperRebate LowerRebate]`. |
| Lookback | `ExerciseDate`, `Strike`, `OptionType`, `AssetMinMax` | `Strike=NaN` for floating strike. `AssetMinMax` for seasoned options. |
| PartialLookback | `ExerciseDate`, `Strike`, `OptionType`, `MonitorDate`, `StrikeScaler`, `AssetMinMax` | `Strike=NaN` for floating strike. `MonitorDate` is end of monitoring window (monitoring starts at settle). `StrikeScaler` multiplies the extremum (default 1). `AssetMinMax` for seasoned options (pre-existing min/max). |
| Binary | `ExerciseDate`, `Strike`, `OptionType`, `PayoffValue` | Digital option. `PayoffValue` is the fixed cash payout (default 1). |
| Touch | `ExerciseDate`, `BarrierType`, `BarrierValue`, `PayoffValue`, `PayoffType` | `BarrierType`: `"ot"` (one-touch) or `"nt"` (no-touch). `BarrierValue` is the trigger level. `PayoffValue` is the fixed payout amount. `PayoffType`: `"hit"` (pay at barrier touch) or `"expiry"` (pay at maturity). |
| DoubleTouch | `ExerciseDate`, `BarrierType`, `BarrierValue`, `PayoffValue`, `PayoffType` | `BarrierType`: `"dot"` (double one-touch), `"dnt"` (double no-touch), `"unt-lot"` (upper no-touch, lower one-touch), `"uot-lnt"` (upper one-touch, lower no-touch). `BarrierValue` is `[UpperBarrier LowerBarrier]`. `PayoffValue` is the fixed payout. `PayoffType`: `"hit"` or `"expiry"`. |
| Cliquet | `ResetDates`, `OptionType`, `LocalCap`, `LocalFloor`, `GlobalCap`, `GlobalFloor`, `ReturnType`, `InitialStrike` | `ReturnType`: `"absolute"` (default) or `"relative"`. Caps/floors default to `Inf`/`0`. `ResetDates` defines reset schedule (first date is start, last is expiry). |
| Spread | `ExerciseDate`, `Strike`, `OptionType` | **BlackScholes model only.** Requires multi-asset pricer setup (see below). |

### Model-Instrument Restrictions

Not all instruments work with all models:

| Model | Supported Instruments | Notes |
|-------|----------------------|-------|
| BlackScholes | All instruments including Spread | Only model supporting full instrument set with multi-asset |
| Merton | All single-asset instruments (no Spread) | Supports Cliquet. Error: `'fininst:finpricer:InvalidInst'` for Spread |
| Heston, Bates | All single-asset instruments (no Spread) | Supports Cliquet. Also supports `"vegalt"` sensitivity. Error: `'fininst:finpricer:SingleAsset'` for multi-asset |
| Bachelier | Binary, Vanilla, Spread only | Supports multi-asset for Spread. No Cliquet. |

## Pricer Parameters

### Required

```matlab
pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, ...        % ratecurve object
    "Model", mdl, ...               % finmodel object
    "SpotPrice", S0, ...            % positive scalar (or vector for multi-asset)
    "SimulationDates", simDates);   % datetime vector — MUST include all exercise dates
```

### Optional

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `NumTrials` | positive integer | 1000 | Use 1e4+ for production |
| `RandomNumbers` | struct or numeric array | `[]` | Struct with field `Z` (and `N`, `SizeJ` for jump models). Or pass the raw array directly. |
| `DividendType` | `"continuous"` or `"cash"` | `"continuous"` | |
| `DividendValue` | scalar or timetable | 0 | Scalar for continuous yield. `timetable(dates, amounts)` for cash dividends. |
| `MonteCarloMethod` | `"standard"`, `"quasi"`, `"randomized-quasi"` | `"standard"` | Ignored if `RandomNumbers` is supplied. |
| `BrownianMotionMethod` | `"standard"`, `"brownian-bridge"`, `"principal-components"` | `"standard"` | Ignored if `RandomNumbers` is supplied. |

## SimulationDates Rules

This is the most common source of errors:

- **Must include all exercise dates.** For European options, include at least the expiry date. For American options, use daily dates from settle to expiry. For Bermudan, include all exercise dates.
- **Must be after `ratecurve.Settle`.** Dates on or before settle cause an error.
- **Path-dependent options** (Asian, Barrier, Lookback) need enough intermediate dates to capture the path accurately. Daily or near-daily dates are typical.
- **Dates are automatically sorted.** You can pass them in any order.

```matlab
% European: just needs expiry
simDates = ExerciseDate;

% American: daily dates
simDates = rc.Settle+days(1):days(1):ExerciseDate;

% Asian with monitoring: regular intervals
simDates = rc.Settle+days(1):days(5):ExerciseDate;
% Make sure ExerciseDate is included
if simDates(end) ~= ExerciseDate
    simDates = [simDates, ExerciseDate];
end
```

## Random Number Reuse

To compare pricing runs with identical paths (e.g., different strikes, different instruments):

```matlab
% First run: capture random numbers from output
[p1, pr1] = price(pricer, inst1, "all");
savedRN = pr1.PricerData.RandomNumbers;

% Second run: feed them back
pricer.RandomNumbers = savedRN;
[p2, pr2] = price(pricer, inst2, "all");
```

You can also pass just the Z matrix directly:

```matlab
pricer.RandomNumbers = pr1.PricerData.RandomNumbers.Z;
```

The output `pr.PricerData` also contains:
- `Paths`: simulated asset paths (NumDates x NumAssets x NumTrials)
- `SimulationTimes.Dates`: datetime vector of simulation dates
- `SimulationTimes.Times`: year fraction vector

## Dividend Configuration

### Continuous dividend yield

```matlab
pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, "Model", mdl, "SpotPrice", 100, ...
    "SimulationDates", simDates, ...
    "DividendValue", 0.03);  % 3% continuous yield
% DividendType defaults to "continuous"
```

### Discrete cash dividends

```matlab
divDates = [datetime(2025,3,15); datetime(2025,9,15)];
divAmounts = [2; 2];
divSchedule = timetable(divDates, divAmounts);

pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, "Model", mdl, "SpotPrice", 100, ...
    "SimulationDates", simDates, ...
    "DividendType", "cash", ...
    "DividendValue", divSchedule);
```

## Multi-Asset / Spread Pricing

Spread options require two correlated assets:

```matlab
% Model with 2 volatilities and correlation
mdl = finmodel("BlackScholes", ...
    "Volatility", [0.20; 0.10], ...
    "Correlation", [1 0.5; 0.5 1]);

% Pricer with 2 spot prices
pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SpotPrice", [110, 90], ...
    "SimulationDates", ExerciseDate, ...
    "DividendType", ["continuous"; "continuous"], ...
    "DividendValue", [0; 0]);

% Spread instrument
spreadOpt = fininstrument("Spread", ...
    "ExerciseDate", ExerciseDate, ...
    "Strike", 15);

[p, pr] = price(pricer, spreadOpt, "all");
```

Key rules for multi-asset:
- `Volatility` on the model must be a vector matching the number of assets
- `Correlation` must be an NxN positive definite matrix
- `SpotPrice` must be a vector matching the number of assets
- `DividendType` and `DividendValue` must also have one entry per asset
- Non-Spread instruments (Vanilla, Asian, etc.) require exactly 1 asset

## Complete Examples

### European Call with Greeks

```matlab
Settle = datetime(2024,1,1);
ExerciseDate = datetime(2025,1,1);
Rates = 0.05;

rc = ratecurve('zero', Settle, ExerciseDate, Rates);
mdl = finmodel("BlackScholes", "Volatility", 0.3);
call = fininstrument("Vanilla", "ExerciseDate", ExerciseDate, "Strike", 100);

pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SpotPrice", 100, ...
    "SimulationDates", ExerciseDate, ...
    "NumTrials", 1e4);

[p, pr] = price(pricer, call, ["delta", "vega", "gamma"]);
fprintf("Price: %.4f, Delta: %.4f, Vega: %.4f\n", p, pr.Results.Delta, pr.Results.Vega);
```

### Asian Call with Path Reuse

```matlab
Settle = datetime(2024,1,1);
ExerciseDate = datetime(2025,1,1);

rc = ratecurve('zero', Settle, ExerciseDate, 0.05);
mdl = finmodel("BlackScholes", "Volatility", 0.3);

simDates = [Settle+days(5):days(5):ExerciseDate-days(5), ExerciseDate];

asianCall = fininstrument("Asian", ...
    "ExerciseDate", ExerciseDate, ...
    "Strike", 100, ...
    "OptionType", "call");

pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SpotPrice", 100, ...
    "SimulationDates", simDates, ...
    "NumTrials", 1e4);

[p1, pr1] = price(pricer, asianCall, "all");

% Reuse paths for different strike
asianCall2 = fininstrument("Asian", ...
    "ExerciseDate", ExerciseDate, ...
    "Strike", 110, ...
    "OptionType", "call");

pricer.RandomNumbers = pr1.PricerData.RandomNumbers;
p2 = price(pricer, asianCall2);
```

### Heston Stochastic Vol

```matlab
Settle = datetime(2024,1,1);
ExerciseDate = datetime(2025,1,1);

rc = ratecurve('zero', Settle, ExerciseDate, 0.05);

mdl = finmodel("Heston", ...
    "V0", 0.04, ...
    "ThetaV", 0.04, ...
    "Kappa", 2, ...
    "SigmaV", 0.3, ...
    "RhoSV", -0.7);

call = fininstrument("Vanilla", "ExerciseDate", ExerciseDate, "Strike", 100);

pricer = finpricer("AssetMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SpotPrice", 100, ...
    "SimulationDates", ExerciseDate, ...
    "NumTrials", 1e4);

[p, pr] = price(pricer, call, "all");
```

## Common Mistakes

| Mistake | Why It Fails | Correct |
|---------|-------------|---------|
| SimulationDates missing ExerciseDate | Runtime error: `'fininst:finpricer:ExerciseDateNotSim'` | Always include ExerciseDate in SimulationDates |
| `"NumSimulations"` | Not a valid parameter | `"NumTrials"` |
| `"Paths"` as input | Not a valid parameter (it's an output in `pr.PricerData.Paths`) | Use `"RandomNumbers"` to control simulation input |
| `"AntitheticVariates"` | Not a valid parameter; antithetic variates are not supported | Use `"MonteCarloMethod", "quasi"` or `"BrownianMotionMethod", "brownian-bridge"` for variance reduction |
| `finpricer("RoughVolMonteCarlo", "Model", finmodel("BlackScholes",...))` | Wrong pricer for BlackScholes | Use `finpricer("AssetMonteCarlo", ...)` for BlackScholes/Heston/Bates/Merton |
| `finpricer("AssetMonteCarlo", "Model", finmodel("RoughBergomi",...))` | Wrong pricer for rough vol | Use `finpricer("RoughVolMonteCarlo", ...)` for RoughBergomi/RoughHeston |
| Single SpotPrice for Spread instrument | Error: `'fininst:finpricer:SpreadNeedTwoAssets'` | Provide vector of SpotPrices and correlation matrix |
| Pricing Vanilla/Asian with multi-asset pricer | Error: `'fininst:finpricer:OptionNeedOneAsset'` | Use single SpotPrice for non-Spread instruments |
| Spread with Heston/Merton/Bates model | Only BlackScholes and Bachelier support multi-asset. Error: `'fininst:finpricer:SingleAsset'` | Use `finmodel("BlackScholes", ...)` for Spread pricing |
| Non-uniform SimulationDates with RoughVolMonteCarlo | Accuracy degrades with irregular spacing | Prefer uniform spacing: `Settle+days(1):days(1):ExerciseDate` |

----

Copyright 2026 The MathWorks, Inc.

----
