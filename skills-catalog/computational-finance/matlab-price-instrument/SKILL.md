---
name: matlab-price-instrument
description: >
  Price financial instruments in MATLAB using the Financial Instruments Toolbox.
  Route to the appropriate numerical method reference based on the user's request:
  Monte Carlo simulation (AssetMonteCarlo, IRMonteCarlo, RoughVolMonteCarlo),
  FFT / Numerical Integration (Vanilla European options), or
  Interest-Rate Trees (option-embedded bonds with IRTree). Use when the user
  asks to price financial instruments or compute Greeks using any of these methods.
  Use one of the following models depending on the pricing method and instrument: 
  Black-Scholes, Bachelier, Heston, Bates, Merton, Hull-White, Black-Karasinski, 
  Black-Derman-Toy, Cox-Ingersoll-Ross, Linear Gaussian 2 Factor (G2PP), 
  Brace-Gatarek-Musiela (BGM), SABR-BGM, RoughBergomi, RoughHeston.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Price Financial Instruments in MATLAB

Price financial instruments in MATLAB using the Financial Instruments Toolbox. Route to the correct numerical pricing method based on the user's request, then follow the method-specific reference for implementation details.

## When to Use

- User asks to price options, bonds, swaps, or derivatives in MATLAB
- User asks for Greeks/sensitivities (delta, vega, gamma, theta, rho, lambda)
- User mentions finpricer, fininstrument, finmodel, or ratecurve
- User asks about Monte Carlo, tree / lattice, or FFT (Fast Fourier Transform) / FRFT (Fractional FFT) pricing
- User wants to compare pricing methods for the same instrument

## When NOT to Use

- User is working with a non-MATLAB environment
- User wants to build a custom instrument with a novel payoff function
- User explicitly asks for a from-scratch implementation without the Financial Instruments Toolbox

## Method Routing

Identify the pricing method from the user's request and read the corresponding reference:

| Method | Reference | When to Use |
|--------|-----------|-------------|
| Monte Carlo (MC) | `references/monte-carlo.md` | Simulation-based pricing: path-dependent options, exotic options, Interest Rate (IR) derivatives via MC, rough volatility |
| FFT / FRFT / Numerical Integration | `references/ni-fft.md` | Fast pricing: European vanilla options under Heston/Bates/Merton via characteristic functions |
| Interest Rate Trees | `references/embedded-bond-tree.md` | Callable/puttable fixed-rate bonds with Hull-White (HW), Black-Karasinski (BK), Black-Derman-Toy (BDT), Cox-Ingersoll-Ross (CIR) tree models |

### Routing Rules

**Read exactly one reference (and any relevant sub-references)** that best matches based on these rules:

1. **User mentions a specific pricer:**
   - `AssetMonteCarlo`, `RoughVolMonteCarlo`, `IRMonteCarlo` -> `references/monte-carlo.md`
   - `FFT`, `NumericalIntegration` -> `references/ni-fft.md`
   - `IRTree` -> `references/embedded-bond-tree.md`

2. **User mentions a specific numerical method and associated concepts:**
   - Monte Carlo, simulation, NumTrials, SimulationDates -> `references/monte-carlo.md`
   - FFT, FRFT, characteristic function, CharacteristicFcnStep, LogStrikeStep -> `references/ni-fft.md`
   - Interest-rate tree, TreeDates, exercise probability -> `references/embedded-bond-tree.md`

3. **User mentions instrument type without a method:**
   - Path-dependent options or other exotic options (Asian, Barrier, Lookback, Cliquet, Touch, Spread, Binary) -> `references/monte-carlo.md`   
   - European vanilla options under stochastic vol/jump models -> `references/ni-fft.md`
   - Callable/puttable fixed-rate bonds -> `references/embedded-bond-tree.md`
   - IR derivatives (caps, floors, swaptions, swaps) -> `references/monte-carlo.md`

4. **User mentions model name without a method:**
   - Heston, Bates, Merton + European vanilla -> `references/ni-fft.md`
   - Heston, Bates, Merton + exotic/path-dependent -> `references/monte-carlo.md`
   - Hull-White, Black-Karasinski, BDT, CIR + callable/puttable bond -> `references/embedded-bond-tree.md`
   - Hull-White, BK, Linear Gaussian 2 Factor (G2PP), Brace-Gatarek-Musiela (BGM), SABR-BGM + caps/floors/swaptions -> `references/monte-carlo.md`
   - Rough volatility (RoughBergomi, RoughHeston) -> `references/monte-carlo.md`

5. **Ambiguous:**
   - When asked to price European vanilla options without specifying pricing method (e.g., "price European call options with Heston in MATLAB"), default to `references/ni-fft.md` (faster, more accurate for European vanilla)
   - If user needs path simulation in addition to price and sensitivities, use `references/monte-carlo.md`
   - If user requests exercise probabilities at each time step for option embedded bonds, use `references/embedded-bond-tree.md`

## Shared Conventions

All three methods share these conventions:

- Always prefer to use `finpricer`/`fininstrument`/`finmodel`/`ratecurve` objects (modern OO API) over legacy functions
- Never use legacy functions unless the user explicitly names them, or the reference suggests them for specific use cases
- Use name-value pairs with string keys: `"DiscountCurve"`, not positional arguments
- Parameter names are case-insensitive but write them in MixedCase for clarity
- Always use `datetime` for dates (not `datenum`)
- Do not use `price` as a variable name — it shadows the `price` function; prefer `p`, or capitalized `Price`
- Request two outputs from `price()` when Greeks or tree data are needed: `[p, pr] = price(...)`

## Common Mistakes (Cross-Method)

Best practice: Check MATLAB documentation (`doc <functionName>`, or `help <functionName>`, etc.) via the MATLAB MCP server before writing code.

| Mistake | Correct |
|---------|---------|
| `finpricer("MonteCarlo", ...)` | `finpricer("AssetMonteCarlo", ...)` or `finpricer("IRMonteCarlo", ...)` |
| `finpricer("HWMonteCarlo", ...)` | `finpricer("IRMonteCarlo", ...)` with a HullWhite model |
| Mixing pricer families (e.g., FFT pricer for Asian option) | FFT/NI only works for European vanilla; use AssetMonteCarlo for exotics |
| Using `datenum` | Always use `datetime` |
| Forgetting second output for Greeks | `[p, pr] = price(pricer, inst, "delta")` — Greeks are in `pr.Results` |
| `discount(rc, dates)` | `discountfactors(rc, dates)` — `ratecurve` uses `discountfactors()`, not `discount()` |


----

Copyright 2026 The MathWorks, Inc.

----
