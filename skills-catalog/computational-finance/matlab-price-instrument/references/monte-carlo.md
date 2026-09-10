# Price Instruments with Monte Carlo Simulation

Price derivatives and fixed-income instruments using Monte Carlo simulation in the
Financial Instruments Toolbox. Covers AssetMonteCarlo, RoughVolMonteCarlo, and
IRMonteCarlo pricers.

## When to Use

- User asks to price options or derivatives using Monte Carlo simulation
- User mentions AssetMonteCarlo, IRMonteCarlo, or RoughVolMonteCarlo pricers
- User asks to price path-dependent or exotic options (Asian, Barrier, Lookback, Cliquet, Touch, Spread)
- User asks to price IR derivatives via simulation (caps, floors, swaptions, callable bonds with MC)
- User mentions simulation paths, NumTrials, or SimulationDates
- User asks for Greeks/sensitivities computed via Monte Carlo
- User mentions rough volatility models (RoughBergomi, RoughHeston)

## When NOT to Use

- FFT, FRFT, NumericalIntegration, or characteristic-function-based pricing of European options — read `references/ni-fft.md`
- Pricing callable/puttable bonds with interest-rate trees (IRTree pricer) — read `references/embedded-bond-tree.md`
- Analytic/closed-form pricing (Black-Scholes formula, Kirk approximation) without simulation
- Binomial/trinomial tree pricing for equity options
- User wants to build a custom instrument with a novel payoff function
- User is working with a non-MATLAB environment
- User explicitly asks for a from-scratch implementation without the toolbox

## Workflow

Every Monte Carlo pricing task follows this 5-step pattern:

```matlab
% Step 1: Create a discount curve
rc = ratecurve('zero', Settle, Dates, Rates);

% Step 2: Create a stochastic model
mdl = finmodel("BlackScholes", "Volatility", 0.3);

% Step 3: Create the instrument
inst = fininstrument("Vanilla", "ExerciseDate", ExDate, "Strike", K);

% Step 4: Create the Monte Carlo pricer
pricer = finpricer("AssetMonteCarlo", "DiscountCurve", rc, ...
    "Model", mdl, "SpotPrice", S0, "SimulationDates", simDates);

% Step 5: Price (with optional Greeks)
[p, pr] = price(pricer, inst, ["delta", "vega", "gamma"]);
```

### Greeks / Sensitivities

- Request via the third argument to `price`: a string or string array
- Supported: `"delta"`, `"gamma"`, `"vega"`, `"theta"`, `"rho"`, `"lambda"`, `"price"`, `"all"` (Heston/Bates also support `"vegalt"` for long-term vega)
- Results returned in `pr.Results` as a table with columns matching requested sensitivities
- Order of columns in the table matches the order you requested

### Multiple Instruments

Pass an array of instruments to price them with the same pricer in one call:

```matlab
instruments = [inst1; inst2; inst3];
[prices, prResults] = price(pricer, instruments, "all");
```

`prices` is a vector; `prResults` is a struct array with one entry per instrument.

## Pricer-Specific Guidance

After identifying the Monte Carlo pricer family, read the corresponding reference:

| Pricer Family | When to Use | Reference |
|---------------|-------------|-----------|
| AssetMonteCarlo | MC simulation for equity/FX options (Vanilla, Asian, Barrier, Lookback, Spread, Cliquet, Touch, Binary) | `references/monte-carlo/asset-monte-carlo.md` |
| RoughVolMonteCarlo | MC for rough volatility models (RoughBergomi, RoughHeston) | `references/monte-carlo/asset-monte-carlo.md` |
| IRMonteCarlo | MC for interest rate products (HW, BK, G2PP, BGM, SABR-BGM) | `references/monte-carlo/ir-monte-carlo.md` |

**Routing rules** (use when user doesn't name the pricer explicitly):

- User mentions equity/FX options, path-dependent options, or exotic options -> read `references/monte-carlo/asset-monte-carlo.md`
- User mentions rough volatility, RoughBergomi, or RoughHeston -> read `references/monte-carlo/asset-monte-carlo.md`
- User mentions interest rate, swap, cap, floor, swaption, callable bond with MC or simulation -> read `references/monte-carlo/ir-monte-carlo.md`

## Conventions

- Always use `finpricer`/`fininstrument`/`finmodel`/`ratecurve` objects. Never write raw simulation math.
- Never use legacy functions: `optstockbymcls`, `mcprice`, `optstockbyblk`, `blsprice` for new code.
- Use name-value pairs (string keys): `"DiscountCurve"`, not positional arguments.
- Parameter names are case-insensitive but always write them in MixedCase in code for clarity.
- `ratecurve` uses lowercase first argument: `ratecurve('zero', ...)` not `ratecurve("Zero", ...)`.

## Common Mistakes

| Mistake | Correct |
|---------|---------|
| `finpricer("MonteCarlo", ...)` | `finpricer("AssetMonteCarlo", ...)` |
| `"NumSimulations"` parameter | `"NumTrials"` |
| `"Volatility"` on the pricer | `"Volatility"` belongs on `finmodel`, not on `finpricer` |
| `optstockbymcls` | `finpricer("AssetMonteCarlo", ...)` |
| Forgetting second output for Greeks | `[p, pr] = price(pricer, inst, "delta")` -- Greeks are in `pr.Results` |
| Using `price` as a variable name | Shadows the `price` function. Use `p` instead. |
| Raw `gbm`/`simulate` for option pricing | Use `finpricer("AssetMonteCarlo", ...)` which handles SDE setup internally |
| `finpricer("AssetMonteCarlo", ...)` with RoughBergomi/RoughHeston | Use `finpricer("RoughVolMonteCarlo", ...)` for rough volatility models |
| `"ExerciseStyle", "european"` on Barrier with daily SimDates | `"ExerciseStyle", "american"` — required to enable barrier checking at each SimulationDate |

----

Copyright 2026 The MathWorks, Inc.

----
