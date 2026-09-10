# Price Option-Embedded Fixed Bonds with Interest-Rate Trees

Price callable and puttable fixed-rate bonds using interest-rate tree models
in MATLAB Financial Instruments Toolbox. Covers model selection, instrument
construction, pricing, exercise probability extraction, and exercise policy
modification.

## When to Use

- Pricing callable or puttable fixed-rate bonds with embedded options
- Building interest-rate trees (HW, BK, BDT, CIR) for bond pricing
- Choosing between rate models for different market conditions
- Extracting exercise probabilities from tree-based pricing
- Modifying exercise policies on existing instruments
- Comparing prices across multiple IR tree models

## When NOT to Use

- Monte Carlo pricing for option-embedded bonds — read `references/monte-carlo.md` (use `IRMonteCarlo` pricer)
- Floating-rate option-embedded bonds — use `OptionEmbeddedFloatBond` instrument
- Convertible bonds — use `ConvertibleBond` instrument
- Vanilla fixed-bond pricing without embedded options — use `FixedBond` instrument
- OAS computation — the `oas` function works directly after pricing; no special guidance needed

## Workflow

The workflow follows four steps: **instrument -> model -> pricer -> price**.

### Step 1: Create the Instrument

Use `fininstrument("OptionEmbeddedFixedBond", ...)` for bonds with embedded
call or put options. Define the exercise schedule as a timetable.

```matlab
CallDates = [datetime(2026,1,15); datetime(2029,1,15)];
CallPrices = [101; 101];
CallSchedule = timetable(CallDates, CallPrices);

Bond = fininstrument("OptionEmbeddedFixedBond", ...
    CouponRate=0.03, ...
    Maturity=datetime(2029,1,15), ...
    Period=2, ...
    Principal=100, ...
    CallSchedule=CallSchedule, ...
    CallExerciseStyle="American", ...
    Name="CallableBond");
```

**Exercise schedule conventions:**
- **European:** single date in the schedule
- **Bermudan:** list each allowed exercise date explicitly
- **American:** either a single date (callable from settlement up to that date) or two rows defining a restricted exercise window (start and end)

**Bermudan example** (callable at par on years 3, 4, and 5):

```matlab
CallDates = (datetime(2027,1,15):calyears(1):datetime(2029,1,15))';
CallPrices = repmat(100, numel(CallDates), 1);
CallSchedule = timetable(CallDates, CallPrices);

Bond = fininstrument("OptionEmbeddedFixedBond", ...
    CouponRate=0.035, ...
    Maturity=datetime(2029,1,15), ...
    Period=2, ...
    Principal=100, ...
    CallSchedule=CallSchedule, ...
    CallExerciseStyle="Bermudan", ...
    Name="BermudanCallable");
```

**American puttable example** (puttable at par from year 5 through maturity):

```matlab
% American exercise: exactly 2 rows — window start and end
PutDates = [datetime(2029,1,15); datetime(2034,1,15)];
PutPrices = [100; 100];
PutSchedule = timetable(PutDates, PutPrices);

Bond = fininstrument("OptionEmbeddedFixedBond", ...
    CouponRate=0.0275, ...
    Maturity=datetime(2034,1,15), ...
    Period=1, ...
    Principal=100, ...
    PutSchedule=PutSchedule, ...
    PutExerciseStyle="American", ...
    Name="PuttableBond");
```

### Step 2: Create the Model

Four models support IRTree pricing for option-embedded bonds:

| Model | Function | Parameters | Rates | Best For |
|-------|----------|-----------|-------|----------|
| Hull-White | `finmodel("HullWhite", ...)` | Alpha, Sigma | Allows negative | Negative rate environments |
| Black-Karasinski | `finmodel("BlackKarasinski", ...)` | Alpha, Sigma | Positive only | Low positive rates, mean reversion control |
| Black-Derman-Toy | `finmodel("BlackDermanToy", ...)` | Sigma | Positive only | Simple calibration, shorter maturities |
| Cox-Ingersoll-Ross | `finmodel("CoxIngersollRoss", ...)` | Alpha, Theta, Sigma | Non-negative | Square-root diffusion, rate-dependent vol |

```matlab
HWModel = finmodel("HullWhite", Alpha=0.05, Sigma=0.01);
BKModel = finmodel("BlackKarasinski", Alpha=0.05, Sigma=0.10);
BDTModel = finmodel("BlackDermanToy", Sigma=0.10);
CIRModel = finmodel("CoxIngersollRoss", Alpha=0.03, Theta=0.04, Sigma=0.05);
```

**Time-varying volatility:** BK and HW accept Sigma as a timetable:

```matlab
VolDates = [datetime(2026,1,15); datetime(2029,1,15); datetime(2032,1,15)];
VolValues = [0.10; 0.15; 0.12];
SigmaTT = timetable(VolDates, VolValues, VariableNames={'Value'});
BKModel = finmodel("BlackKarasinski", Alpha=0.05, Sigma=SigmaTT);
```

### Step 3: Create the IRTree Pricer

**Critical difference:** CIR uses `Maturity` + `NumPeriods`. All others use `TreeDates`.

```matlab
% Hull-White, Black-Karasinski, Black-Derman-Toy:
TreeDates = (Settle + calyears(1:5))';
Pricer = finpricer("IRTree", Model=HWModel, DiscountCurve=myRC, TreeDates=TreeDates);

% Cox-Ingersoll-Ross (different interface):
CIRPricer = finpricer("IRTree", Model=CIRModel, DiscountCurve=myRC, ...
    Maturity=datetime(2029,1,15), NumPeriods=10);
```

### Step 4: Price and Extract Results

```matlab
[P, priceResult] = price(Pricer, Bond);
```

The second output is a `priceresult` object containing:
- `priceResult.Results` — table with the price
- `priceResult.PricerData.PriceTree` — struct with tree data including:
  - `ExTree` — exercise decision at each node
  - `ExProbTree` — exercise probability at each node
  - `ExProbsByTreeLevel` — aggregate exercise probability per time step
  - `PTree` — bond prices at each node
  - `ProbTree` — transition probabilities
  - `tObs` — observation times

## Model Selection Guide

| Market Condition | Recommended Model | Rationale |
|-----------------|------------------|-----------|
| Negative interest rates | Hull-White | Gaussian process naturally allows negative rates |
| Low positive rates | Black-Karasinski | Lognormal with explicit mean-reversion control |
| Simple/short-dated | Black-Derman-Toy | Single parameter (Sigma), easy calibration |
| Rate-dependent volatility | Cox-Ingersoll-Ross | Square-root diffusion, vol scales with rate level |

**LinearGaussian2F is NOT supported for IRTree pricing.** It will fail at runtime
with "Model not supported in IRTree." Use it only with other pricer types.

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `fininstrument("OptionEmbeddedFixedBond", ...)` | Create callable/puttable bond | R2020a |
| `finmodel("CoxIngersollRoss", ...)` | Create CIR rate model | R2023b |
| `finpricer("IRTree", ...)` | Create tree-based pricer | R2020a |
| `price(pricer, instrument)` | Compute bond price | R2020a |
| `setCallExercisePolicy(bond, schedule, style)` | Modify call exercise policy | R2020b |
| `setPutExercisePolicy(bond, schedule, style)` | Modify put exercise policy | R2020b |
| `oas(pricer, instrument, marketPrice)` | Compute option-adjusted spread | R2020a |

## Patterns

### Modify Exercise Policy Without Rebuilding

Use `setCallExercisePolicy` or `setPutExercisePolicy` to change an existing
instrument's exercise style and schedule without creating a new instrument:

```matlab
NewSchedule = timetable([datetime(2027,1,15); datetime(2031,1,15)], [100; 100]);
BondAmerican = setCallExercisePolicy(Bond, NewSchedule, "American");

% Same pattern for puts:
PutBondEuropean = setPutExercisePolicy(PutBond, timetable(datetime(2030,1,15), 100), "European");
```

### Extract Exercise Probabilities

```matlab
[P, priceResult] = price(Pricer, Bond);
pt = priceResult.PricerData.PriceTree;

% Aggregate probability of exercise at each tree level (1 x nLevels double)
disp(pt.ExProbsByTreeLevel);

% Per-node exercise probabilities (cell array, one per tree level)
% Each cell contains probabilities of exercise at each node for that level
disp(pt.ExProbTree{3});

% Exercise indicator: 1 = exercised, 0 = not (cell array of logical arrays)
disp(pt.ExTree{3});

% Probability of reaching each node from root (cell array of doubles)
% Use to weight node-level results for custom analytics
disp(pt.ProbTree{3});
```

### Compute OAS, Duration, and Convexity

```matlab
MarketPrice = 97.50;
[OAS, OAD, OAC] = oas(Pricer, Bond, MarketPrice);
```

### Compare All Models

```matlab
Settle = datetime(2024,1,15);
Maturity = datetime(2029,1,15);
TreeDates = (Settle + calyears(1:5))';

models = {
    finmodel("HullWhite", Alpha=0.05, Sigma=0.01)
    finmodel("BlackKarasinski", Alpha=0.05, Sigma=0.10)
    finmodel("BlackDermanToy", Sigma=0.10)
};
modelNames = ["Hull-White", "Black-Karasinski", "Black-Derman-Toy"];

for i = 1:numel(models)
    p = finpricer("IRTree", Model=models{i}, DiscountCurve=myRC, TreeDates=TreeDates);
    prices(i) = price(p, Bond);
end

% CIR uses different interface
CIRModel = finmodel("CoxIngersollRoss", Alpha=0.03, Theta=0.04, Sigma=0.05);
CIRPricer = finpricer("IRTree", Model=CIRModel, DiscountCurve=myRC, ...
    Maturity=Maturity, NumPeriods=10);
prices(4) = price(CIRPricer, Bond);
modelNames(4) = "CoxIngersollRoss";

table(modelNames', prices', VariableNames=["Model", "Price"])
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `FixedBondOption` for callable/puttable bonds | `FixedBondOption` is an option ON a bond (separate contract). `OptionEmbeddedFixedBond` is a bond WITH embedded options. | Use `fininstrument("OptionEmbeddedFixedBond", ...)` |
| Using `TreeDates` with CIR model | CIR pricer requires `Maturity` and `NumPeriods` | Use `finpricer("IRTree", Model=CIRModel, DiscountCurve=rc, Maturity=mat, NumPeriods=n)` |
| Using `LinearGaussian2F` with IRTree | Not supported — fails at runtime | Use HW, BK, BDT, or CIR only |
| Listing every date for American exercise | American uses at most two rows, not a list of dates | Use a single date (callable from settlement to that date) or two rows (restricted window start + end) |
| Rebuilding instrument to change exercise style | Unnecessary — methods exist for this | Use `setCallExercisePolicy` or `setPutExercisePolicy` |
| Using only 3 models (HW, BK, BDT) | CIR is also available (since R2023b) | Include CoxIngersollRoss in model comparisons |

## Conventions

- Always use `datetime` for dates (not `datenum`)
- Always use column vectors for `TreeDates` (row vectors cause concatenation errors)
- Always request two outputs from `price()` when exercise analysis is needed
- Prefer `OptionEmbeddedFixedBond` over `FixedBondOption` + `FixedBond` combination
- Use `Principal` (not `Face`) for the notional amount parameter

----

Copyright 2026 The MathWorks, Inc.

----
