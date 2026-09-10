# IR Monte Carlo Pricing

Price interest rate derivatives using Monte Carlo simulation with `finpricer("IRMonteCarlo", ...)`.

## Model-to-Pricer Mapping

The model you pass to the pricer determines the underlying SDE engine. Always use `finpricer("IRMonteCarlo", ...)` and the engine is selected automatically based on the model class.

| finmodel | Parameters | Internal Pricer |
|----------|-----------|-----------------|
| `finmodel("HullWhite", "Alpha", 0.1, "Sigma", 0.01)` | Alpha, Sigma: positive scalar or timetable | HWMonteCarlo |
| `finmodel("BlackKarasinski", "Alpha", 0.1, "Sigma", 0.01)` | Alpha, Sigma: positive scalar or timetable | BKMonteCarlo |
| `finmodel("LinearGaussian2F", "Alpha1", 0.07, "Sigma1", 0.01, "Alpha2", 0.5, "Sigma2", 0.006, "Correlation", -0.7)` | 5 required parameters | G2PPMonteCarlo |
| `finmodel("BraceGatarekMusiela", "Volatility", VolFunc, "Correlation", CorrMat)` | VolFunc: cell array of function handles; Correlation: matrix | BGMMonteCarlo |
| `finmodel("SABRBraceGatarekMusiela", "Alpha", a, "Beta", b, "VolatilityofVolatility", vvFunc, "FwdFwdCorrelation", c1, "VolVolCorrelation", c2)` | Complex multi-parameter setup | SABRBGMMonteCarlo |

**Never use `finpricer("HWMonteCarlo", ...)` or `finpricer("BGMMonteCarlo", ...)` directly.** Always use `finpricer("IRMonteCarlo", ...)` and let the model determine the engine.

## Supported Instruments

| Instrument | Key Parameters | Notes |
|------------|---------------|-------|
| FixedBond | `Maturity`, `CouponRate`, `Period`, `Principal` | `CouponRate` can be scalar or timetable (stepped coupon). `Principal` can be timetable (amortizing). |
| FloatBond | `Maturity`, `Spread`, `Reset`, `Principal` | `LatestFloatingRate` for seasoned bonds. `Spread` of 0 gives par (price ~100). |
| FixedBondOption | `ExerciseDate`, `Strike`, `Bond`, `ExerciseStyle`, `OptionType` | **`Bond` must reference a FixedBond instrument.** Supports European, American, Bermudan. |
| FloatBondOption | `ExerciseDate`, `Strike`, `Bond`, `ExerciseStyle`, `OptionType` | **`Bond` must reference a FloatBond instrument.** Supports European, American, Bermudan. |
| OptionEmbeddedFixedBond | `Maturity`, `CouponRate`, `CallSchedule` or `PutSchedule` | Schedule is a timetable with dates and strike prices. `CallExerciseStyle`/`PutExerciseStyle` for American/Bermudan. |
| OptionEmbeddedFloatBond | `Maturity`, `Spread`, `CallSchedule` or `PutSchedule` | Same schedule pattern as OptionEmbeddedFixedBond. |
| Cap | `Maturity`, `Strike`, `Reset`, `Principal` | Caps on floating rate. `Reset` determines payment frequency. |
| Floor | `Maturity`, `Strike`, `Reset`, `Principal` | Floors on floating rate. Same structure as Cap. |
| Swap | `Maturity`, `LegRate`, `LegType`, `Reset`, `Notional` | `LegType`: `["fixed","float"]` or `["float","fixed"]`. `Notional` can be timetable (amortizing); **dates must align with coupon dates**. `StartDate` for forward-starting swaps. |
| Swaption | `ExerciseDate`, `Strike`, `Swap`, `OptionType` | **`Swap` must reference a Swap instrument.** European exercise only. |
| RangeAccrualNote | `Maturity`, `ReferenceType`, `ReferenceTenor`, `CouponRate`, `TargetRange` | `ReferenceType`: `"cms"` or `"spot"`. `ReferenceTenor` can be scalar (single rate) or a 2-element vector `[short long]` for CMS spread (e.g., `[2 10]`). Requires daily SimulationDates. **HullWhite and LinearGaussian2F only.** R2026a+; see SimulationDates Rules for fallback. |
| OptionEmbeddedRangeAccrualNote | Same as RangeAccrualNote + call/put schedule | **HullWhite and LinearGaussian2F only.** R2026a+; see SimulationDates Rules for fallback. |

### Model-Instrument Compatibility

| Model | Instruments | Sensitivities | Notes |
|-------|-------------|--------------|-------|
| HullWhite | All 12 instruments | price, delta, gamma, vega | Most complete support |
| BlackKarasinski | All except RangeAccrualNote variants | price, delta, gamma, vega | |
| LinearGaussian2F | All 12 instruments | price, delta, gamma, vega | **Vega returns a 2-element vector** (one per sigma factor) |
| BraceGatarekMusiela | FixedBond, FloatBond, FixedBondOption, FloatBondOption, OptionEmbeddedFixedBond, OptionEmbeddedFloatBond, Cap, Floor | price, delta, gamma | **No vega. No Swap/Swaption.** |
| SABRBraceGatarekMusiela | Same as BGM | price, delta, gamma | **No vega. No Swap/Swaption.** |

## Pricer Parameters

### Required

```matlab
pricer = finpricer("IRMonteCarlo", ...
    "DiscountCurve", rc, ...        % ratecurve object
    "Model", mdl, ...               % finmodel object (determines engine)
    "SimulationDates", simDates);   % datetime vector — MUST include exercise dates
```

### Optional

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `NumTrials` | positive integer | 1000 | Use 1e4+ for production |
| `RandomNumbers` | struct or numeric array | `[]` | Struct with field `Z`. Or pass the raw array directly. |

**Note:** Unlike AssetMonteCarlo, IRMonteCarlo does not have `SpotPrice`, `DividendType`, `DividendValue`, `MonteCarloMethod`, or `BrownianMotionMethod` parameters.

## SimulationDates Rules

- **Must be after `ratecurve.Settle`.** Dates on or before settle cause error `'fininst:finpricer:SimulationDateBeforeSettle'`.
- **Must include exercise dates** for bond options, swaptions, and option-embedded bonds. Missing dates cause error `'fininst:finpricer:ExerciseDateNotSim'`.
- **American exercise** needs sufficient intermediate dates to capture early exercise opportunities.
- **RangeAccrualNote** requires daily simulation dates (business days) for accurate accrual counting. Always try `fininstrument("RangeAccrualNote", ...)` first — it is the preferred API when available (R2026a and later). If MATLAB errors with an invalid instrument type, fall back to a manual implementation: use `finmodel("HullWhite", ...)` with `simTermStructs` to simulate daily short-rate paths, compute the reference rate (e.g., CMS 10Y par swap rate) at each date, count days within the target range, and discount the accrual-weighted coupons using the simulated discount factors.
- **BGM/SABR-BGM models**: SimulationDates cannot extend beyond the model's tenor dates (determined by `length(Volatility)+1` forward rates and `Period`). Error: `'fininst:finpricer:InvalidBGMSimulationDates'`.
- **Dates are automatically sorted and deduplicated.**

```matlab
% Short-rate models (HW, BK, G2PP): typical setup
simDates = Settle + calmonths(1:48)';

% American bond option: denser dates around exercise window
simDates = [Settle+calmonths(1:6:48)'; ZeroDates];

% Range accrual note: daily business dates
simDates = busdate(Settle:caldays(1):Maturity, 'follow', holidays);

% BGM: limited by tenor
simDates = Settle:calmonths(1):Maturity;  % must not exceed last tenor date
```

## Random Number Reuse

Same pattern as AssetMonteCarlo:

```matlab
% First run: capture random numbers
[p1, pr1] = price(pricer, inst, "all");
savedRN = pr1.PricerData.RandomNumbers;

% Second run: feed them back
pricer.RandomNumbers = savedRN;
[p2, pr2] = price(pricer, inst2, "all");
```

The Z array dimensions depend on the model:
- HullWhite, BlackKarasinski: `NumSimDates x 1 x NumTrials`
- LinearGaussian2F: `NumSimDates x 2 x NumTrials`
- BraceGatarekMusiela: `NumPeriods x NumBrownians x NumTrials` (NumBrownians = NumRates-1 or NumFactors)

## Instrument Composition Patterns

### Bond Options (FixedBondOption, FloatBondOption)

Bond options require a **reference to an existing bond instrument**:

```matlab
bond = fininstrument("FixedBond", "Maturity", datetime(2025,1,1), "CouponRate", 0.05);

% European bond option
bondOpt = fininstrument("FixedBondOption", ...
    "ExerciseDate", datetime(2024,1,1), ...
    "Strike", 95, ...
    "Bond", bond);

% American bond option (specify date range)
bondOptAm = fininstrument("FixedBondOption", ...
    "ExerciseDate", [datetime(2022,1,1) datetime(2024,1,1)], ...
    "Strike", 95, ...
    "Bond", bond, ...
    "ExerciseStyle", "american");

% Bermudan bond option (multiple dates and strikes)
bondOptBer = fininstrument("FixedBondOption", ...
    "ExerciseDate", [datetime(2022,1,1) datetime(2023,1,1) datetime(2024,1,1)], ...
    "Strike", [95 95 95], ...
    "Bond", bond, ...
    "ExerciseStyle", "bermudan");
```

### Option-Embedded Bonds

Callable/putable bonds use schedule timetables:

```matlab
% Callable bond (Bermudan)
CallDates = [datetime(2022,1,1); datetime(2023,1,1); datetime(2024,1,1)];
CallStrikes = [100; 100; 105];
CallSchedule = timetable(CallDates, CallStrikes);

callableBond = fininstrument("OptionEmbeddedFixedBond", ...
    "Maturity", datetime(2025,1,1), ...
    "CouponRate", 0.05, ...
    "CallSchedule", CallSchedule, ...
    "CallExerciseStyle", "bermudan");

% Putable bond
PutSchedule = timetable(datetime(2023,1,1), 100);
putableBond = fininstrument("OptionEmbeddedFixedBond", ...
    "Maturity", datetime(2025,1,1), ...
    "CouponRate", 0.05, ...
    "PutSchedule", PutSchedule);
```

### Swaptions

Swaptions require a **reference to an existing swap instrument**:

```matlab
swap = fininstrument("Swap", ...
    "Maturity", datetime(2025,1,1), ...
    "LegRate", [0.05, 0], ...
    "LegType", ["fixed", "float"]);

swaption = fininstrument("Swaption", ...
    "ExerciseDate", datetime(2023,1,1), ...
    "Strike", 0.02, ...
    "Swap", swap);
```

## Model Setup Examples

### Hull-White (simplest)

```matlab
% Constant parameters
mdl = finmodel("HullWhite", "Alpha", 0.1, "Sigma", 0.01);

% Time-varying parameters (timetable)
AlphaTT = timetable(datetime(2019,1,1), 0.1);
SigmaTT = timetable([datetime(2019,1,1); datetime(2021,1,1)], [0.01; 0.015]);
mdl = finmodel("HullWhite", "Alpha", AlphaTT, "Sigma", SigmaTT);
```

### LinearGaussian2F (G2++)

```matlab
mdl = finmodel("LinearGaussian2F", ...
    "Alpha1", 0.07, ...
    "Sigma1", 0.01, ...
    "Alpha2", 0.5, ...
    "Sigma2", 0.006, ...
    "Correlation", -0.7);
```

### BraceGatarekMusiela (BGM / LIBOR Market Model)

```matlab
% Volatility: cell array of function handles (one per forward rate)
BGMVolFunc = @(a,t) (a(1)*t + a(2)).*exp(-a(3)*t) + a(4);
BGMVolParams = [.3 -.02 .7 .14];

numRates = 6;
VolFunc = cell(1, numRates-1);
for i = 1:numRates-1
    VolFunc{i} = @(t) BGMVolFunc(BGMVolParams, t);
end

% Correlation: exponential decay
Beta = 0.08;
CorrFunc = @(i,j,B) exp(-B*abs(i-j));
Correlation = CorrFunc(meshgrid(1:numRates-1)', meshgrid(1:numRates-1), Beta);

mdl = finmodel("BraceGatarekMusiela", ...
    "Volatility", VolFunc, ...
    "Correlation", Correlation, ...
    "Period", 2);  % semiannual forward rates (default)
```

### SABRBraceGatarekMusiela

```matlab
numRates = 5;
Alpha = 0.12 * ones(numRates-1, 1);
Beta = ones(numRates-1, 1);

SABRVolVolFunc = @(a,t) (a(1)*t + a(2)).*exp(-a(3)*t) + a(4);
SABRVolVolParams = [.3 -.02 .7 .14];
VolVolFunc = cell(numRates-1, 1);
for i = 1:numRates-1
    VolVolFunc{i} = @(t) SABRVolVolFunc(SABRVolVolParams, t);
end

CorrFunc = @(i,j,B) exp(-B*abs(i-j));
FwdFwdCorrelation = CorrFunc(meshgrid(1:numRates-1)', meshgrid(1:numRates-1), 0.08);
VolVolCorrelation = CorrFunc(meshgrid(1:numRates-1)', meshgrid(1:numRates-1), 0.04);

mdl = finmodel("SABRBraceGatarekMusiela", ...
    "Alpha", Alpha, ...
    "Beta", Beta, ...
    "VolatilityofVolatility", VolVolFunc, ...
    "FwdFwdCorrelation", FwdFwdCorrelation, ...
    "VolVolCorrelation", VolVolCorrelation);
```

## Complete Examples

### Cap with Hull-White and Greeks

```matlab
Settle = datetime(2019,1,1);
ZeroTimes = calyears(1:4)';
ZeroDates = Settle + ZeroTimes;
ZeroRates = [0.035; 0.042; 0.047; 0.053];

rc = ratecurve('zero', Settle, ZeroDates, ZeroRates, "Compounding", 4);
mdl = finmodel("HullWhite", "Alpha", 0.1, "Sigma", 0.01);

cap = fininstrument("Cap", "Maturity", datetime(2022,9,15), "Strike", 0.01, "Reset", 2);

pricer = finpricer("IRMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SimulationDates", [Settle+calmonths(3:6:48)'; ZeroDates]);

rng('default')
[p, pr] = price(pricer, cap, "all");
fprintf("Cap Price: %.4f, Delta: %.4f, Vega: %.4f\n", p, pr.Results.Delta, pr.Results.Vega);
```

### Callable Bond (Bermudan) with Hull-White

```matlab
Settle = datetime(2019,1,1);
ZeroDates = Settle + calyears(1:4)';
ZeroRates = [0.035; 0.042; 0.047; 0.053];
rc = ratecurve('zero', Settle, ZeroDates, ZeroRates, "Compounding", 4);
mdl = finmodel("HullWhite", "Alpha", 0.1, "Sigma", 0.01);

CallSchedule = timetable( ...
    [datetime(2020,1,1); datetime(2021,1,1); datetime(2022,1,1)], ...
    [100; 100; 100]);

callableBond = fininstrument("OptionEmbeddedFixedBond", ...
    "Maturity", datetime(2022,9,15), ...
    "CouponRate", 0.05, ...
    "CallSchedule", CallSchedule, ...
    "CallExerciseStyle", "bermudan");

simDates = [Settle+calmonths(3:6:48)'; ZeroDates];
pricer = finpricer("IRMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SimulationDates", simDates);

rng('default')
[p, pr] = price(pricer, callableBond, "all");
```

### Swaption with G2++ and Two-Factor Vega

```matlab
Settle = datetime(2019,1,1);
ZeroDates = Settle + calyears(1:10)';
ZeroRates = 0.025 * ones(10,1);
rc = ratecurve('zero', Settle, ZeroDates, ZeroRates, "Compounding", -1);

mdl = finmodel("LinearGaussian2F", ...
    "Alpha1", 0.07, "Sigma1", 0.01, ...
    "Alpha2", 0.5, "Sigma2", 0.006, ...
    "Correlation", -0.7);

swap = fininstrument("Swap", ...
    "Maturity", datetime(2029,1,1), ...
    "LegRate", [0.05, 0], ...
    "Reset", [1, 1], ...
    "Notional", 100);

swaption = fininstrument("Swaption", ...
    "ExerciseDate", datetime(2023,1,1), ...
    "Strike", 0.02, ...
    "Swap", swap);

pricer = finpricer("IRMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SimulationDates", ZeroDates);

rng('default')
[p, pr] = price(pricer, swaption, "all");
% pr.Results.Vega is a 1x2 vector: [vega_sigma1, vega_sigma2]
```

### BGM Cap Pricing

```matlab
Settle = datetime(2019,1,1);
ZeroTimes = [calmonths(6) calyears([1 2 3 4 5])];
ZeroRates = [0.0052 0.0055 0.0061 0.0073 0.0094 0.0119];
ZeroDates = Settle + ZeroTimes;
rc = ratecurve('zero', Settle, ZeroDates, ZeroRates, "Compounding", -1);

BGMVolFunc = @(a,t) (a(1)*t + a(2)).*exp(-a(3)*t) + a(4);
BGMVolParams = [.3 .02 .7 .14];
numRates = 4;
VolFunc(1:numRates-1) = {@(t) BGMVolFunc(BGMVolParams, numRates*0.5-t)};

Beta = 0.08;
CorrFunc = @(i,j,B) exp(-B*abs(i-j));
Correlation = CorrFunc(meshgrid(1:numRates-1)', meshgrid(1:numRates-1), Beta);

mdl = finmodel("BraceGatarekMusiela", ...
    "Volatility", VolFunc, ...
    "Correlation", Correlation);

cap = fininstrument("Cap", "Maturity", datetime(2021,1,1), "Strike", 0.005, "Reset", 2);

pricer = finpricer("IRMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SimulationDates", Settle:calmonths(1):datetime(2021,1,1));

rng('default')
[p, pr] = price(pricer, cap, "all");
```

### Mixed Instruments in One Call

```matlab
Settle = datetime(2019,1,1);
ZeroDates = Settle + calyears(1:4)';
ZeroRates = [0.035; 0.042; 0.047; 0.053];
rc = ratecurve('zero', Settle, ZeroDates, ZeroRates, "Compounding", 4);
mdl = finmodel("HullWhite", "Alpha", 0.1, "Sigma", 0.01);

fixBond = fininstrument("FixedBond", "Maturity", datetime(2022,9,15), "CouponRate", 0.05);
fltBond = fininstrument("FloatBond", "Maturity", datetime(2022,9,15), "Spread", 0.05);
cap = fininstrument("Cap", "Maturity", datetime(2022,9,15), "Strike", 0.01, "Reset", 2);
swap = fininstrument("Swap", "Maturity", datetime(2022,9,15), "LegRate", [0.05, 0.05], ...
    "LegType", ["float", "fixed"], "Reset", [2, 4]);

simDates = [Settle+calmonths(3:6:48)'; ZeroDates];
pricer = finpricer("IRMonteCarlo", ...
    "DiscountCurve", rc, ...
    "Model", mdl, ...
    "SimulationDates", simDates);

rng('default')
[prices, pr] = price(pricer, [fixBond; fltBond; cap; swap], "all");
```

## Common Mistakes

| Mistake | Why It Fails | Correct |
|---------|-------------|---------|
| `finpricer("HWMonteCarlo", ...)` | Not a valid pricer name | `finpricer("IRMonteCarlo", ...)` with a HullWhite model |
| `finpricer("IRMonteCarlo", ..., "SpotPrice", 100)` | IRMonteCarlo has no SpotPrice parameter | Remove SpotPrice; that belongs to AssetMonteCarlo |
| `finmodel("HullWhite", "MeanReversion", 0.1, "Volatility", 0.01)` | Wrong parameter names | `finmodel("HullWhite", "Alpha", 0.1, "Sigma", 0.01)` |
| `finmodel("LinearGaussian2F", "Alpha", ..., "Sigma", ...)` | Wrong parameter names for G2PP | Use `Alpha1`, `Sigma1`, `Alpha2`, `Sigma2`, `Correlation` |
| Bond option without `"Bond"` parameter | Missing required instrument reference | `fininstrument("FixedBondOption", ..., "Bond", bondInst)` |
| Swaption without `"Swap"` parameter | Missing required instrument reference | `fininstrument("Swaption", ..., "Swap", swapInst)` |
| `price(pricer, swaption, "vega")` with BGM model | BGM doesn't support vega | Only `"delta"` and `"gamma"` are available for BGM/SABR-BGM |
| Pricing Swap/Swaption with BGM model | BGM only supports bonds, bond options, caps, floors | Use HullWhite, BK, or G2PP for Swap/Swaption |
| `bondbyhw`, `capbyhw`, `swaptionbyhw` | Legacy functions | Use `finpricer("IRMonteCarlo", ...) + price(pricer, inst)` |
| BGM SimulationDates beyond tenor dates | Error: `'fininst:finpricer:InvalidBGMSimulationDates'` | SimulationDates must not exceed last tenor date of the model |
| RangeAccrualNote with BK or BGM model | Not supported | Use HullWhite or LinearGaussian2F only |
| `fininstrument("RangeAccrualNote", ...)` on pre-R2026a | Not a valid instrument type | RangeAccrualNote requires R2026a or later — implement manually with `simTermStructs` (see SimulationDates Rules) |
| Expecting scalar Vega from G2PP | G2PP returns `[vega_sigma1, vega_sigma2]` | Handle 2-element Vega vector for LinearGaussian2F |
| BGM Volatility as scalar or vector | Must be cell array of function handles | `VolFunc = {@(t) 0.2, @(t) 0.15, ...}` |
| `finmodel("BraceGatarekMusiela", "Volatility", 0.2, ...)` | Volatility must be cell of function handles | `finmodel("BraceGatarekMusiela", "Volatility", {@(t) 0.2}, ...)` |
| Amortizing `Notional` timetable with arbitrary dates | Error: "Sinking Face Schedule Dates must be cash flow dates" | Notional timetable dates must align with coupon payment dates |

----

Copyright 2026 The MathWorks, Inc.

----
