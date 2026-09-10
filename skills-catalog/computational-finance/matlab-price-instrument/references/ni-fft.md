# Option Pricing with FFT and Numerical Integration in MATLAB

## When to Use

- Pricing European vanilla options under stochastic volatility or jump-diffusion models (Heston, Bates, or Merton)
- Computing Greeks (sensitivities) for European vanilla options
- Using FFT / FRFT or Numerical Integration techniques to compute prices and Greeks
- Tuning optimal FFT / FRFT parameters for accuracy and speed
- Cross-validating FFT / FRFT vs Numerical Integration
- Working with ratecurve / fininstrument / finmodel / finpricer objects
- Working with legacy option pricing functions supporting FFT / FRFT and Numerical Integration

## When NOT to Use

- Pricing or computing sensitivities for American options or other exotic options
- Pricing or computing sensitivities for any instruments other than European vanilla options
- Simulating paths using the Heston, Bates, or Merton models — read `references/monte-carlo.md`
- Models other than Heston, Bates, or Merton models
- Pricing or computing sensitivities using Monte Carlo, Finite Difference or Tree / Lattice methods
- Pricing or computing sensitivities using any techniques other than FFT / FRFT or Numerical Integration


## Models and Workflows Overview

MATLAB's Financial Instruments Toolbox supports three characteristic-function-based models for pricing European vanilla options via FFT (Carr-Madan) and Numerical Integration:

| Model | Dynamics | Use Case |
|-------|----------|----------|
| **Heston** | Stochastic volatility | Volatility smile/skew from mean-reverting variance |
| **Bates** | Stochastic volatility + jumps | Fat tails and skew beyond what Heston alone produces |
| **Merton** | Constant volatility + jumps | Jump risk with GBM diffusion (no stochastic vol) |

All three models share the same pricing workflow (OO API, R2020a+) and the same FFT accuracy tuning. The only difference is the model object (Step 3). Legacy workflow (Legacy API, R2018a+) is described in the section "Legacy Functional API".

**Default workflow:**
Always use the object-oriented API (ratecurve -> fininstrument -> finmodel -> finpricer -> price) UNLESS:
- Generating large surfaces (many strikes x many maturities) where speed matters — then recommend legacy with `'ExpandOutput', true` (see reference files)
- Inspecting the FFT grid by setting empty Strike input (see reference files)
- Or when the user explicitly requests legacy functions by name. If the user mentions `optByHestonFFT`, `optByBatesFFT`, `optByMertonFFT`, `optSensByHestonFFT`, `optSensByBatesFFT`, `optSensByMertonFFT`, or any other legacy function name (NI variants included), you MUST use that exact function — do NOT substitute the OO equivalent. See model-specific reference files for legacy function signatures.

| Pricer | Method | Speed | Accuracy |
|--------|--------|-------|----------|
| `finpricer("FFT", ...)` | Fast Fourier Transform (Carr-Madan) | Fast (~0.01-0.04s) | Grid-dependent — must tune `CharacteristicFcnStep` |
| `finpricer("NumericalIntegration", ...)` | Adaptive numerical integration | Slow (~0.5-2.0s) | High — use as ground-truth reference |

## Workflow (Object-Oriented API, R2020a+)

```
1. ratecurve -> 2. fininstrument -> 3. finmodel -> 4. finpricer -> 5. price()
```

### Key Setup Details

```matlab
% Step 1: Rate curve — use Compounding=-1 for continuous (matches legacy Rate arg)
rc = ratecurve("zero", Settle, Dates, Rates, 'Compounding', -1);

% Step 2: Vanilla — pass a column vector of strikes to create a column vector of instruments
VanillaObj = fininstrument("Vanilla", 'Strike', Strike(:), ...
    'ExerciseDate', Maturity, 'OptionType', "call");
```

### Step 3: Model (choose one)

| Model | Parameters |
|-------|-----------|
| **Heston** | `V0`, `ThetaV`, `Kappa`, `SigmaV`, `RhoSV` (5 stochastic vol params) |
| **Bates** | Heston 5 + `MeanJ`, `JumpVol`, `JumpFreq` (8 total) |
| **Merton** | `Volatility`, `MeanJ`, `JumpVol`, `JumpFreq` (4 total) |

**Merton uses `Volatility` (a single constant), not `V0`/`ThetaV`/`Kappa`/`SigmaV`.** Feller condition for Heston/Bates: `2*Kappa*ThetaV > SigmaV^2`.

### Steps 4-5: Pricer and Pricing

```matlab
% FFT pricer — set CharacteristicFcnStep to 0.1 for accuracy
FFTPricer = finpricer("FFT", 'Model', Model, ...
    'DiscountCurve', rc, 'SpotPrice', AssetPrice, ...
    'CharacteristicFcnStep', 0.1);

% NumericalIntegration pricer — high accuracy, slower
NIPricer = finpricer("NumericalIntegration", 'Model', Model, ...
    'DiscountCurve', rc, 'SpotPrice', AssetPrice);

% Price with sensitivities
[Price, outPR] = price(FFTPricer, VanillaObj, "All");
disp(outPR.Results)   % Table with columns: Delta, Gamma, Vega, VegaLT, ...
```

The pricer accepts ANY of the three models — no changes needed.

## Pricer Properties

**FFT key properties:** `NumFFT` (default 4096), `CharacteristicFcnStep` (default 0.01 — **set to 0.1+, not above 0.4**), `LogStrikeStep` (set explicitly to trigger FRFT), `DampingFactor` (default 1.5 — leave alone), `DividendValue` (on pricer, not instrument/model). **Do NOT pass `DividendType`** — FFT always uses continuous dividends; `DividendType` is a read-only property, not a settable input.

**NI key properties:** `AbsTol` (1e-10), `RelTol` (1e-6), `IntegrationRange` ([1e-9 Inf]), `Framework` (`"heston1993"` or `"lewis2001"`), `DividendValue` (scalar yield, on pricer). **Do NOT pass `DividendType`** — NI always uses continuous dividends; unlike `AssetMonteCarlo`, this is not a settable parameter.

**Model-specific:** `VolRiskPremium` and `LittleTrap` apply to Heston/Bates only, NOT Merton.

**Sensitivities:** Heston and Bates support 6 Greek sensitivities: `"Delta"`, `"Gamma"`, `"Vega"`, `"Rho"`, `"Theta"`, `"Vegalt"`. Use `"All"` to request all of them plus `"Price"` (7 columns total in Results table). **Merton does NOT support `"Vegalt"`** — use `"All"` (returns 5 sensitivities + Price) or explicit list without it. Can request `"Vegalt"` (case-insensitive) but the Results table column is named `"VegaLT"`.

### When to Use Each Pricer

| Scenario | Recommended Pricer |
|----------|-------------------|
| Prices or sensitivities for many strikes | FFT with `'CharacteristicFcnStep', 0.1` or higher (not above 0.4) |
| Large-scale surface (many strikes x many maturities) | Legacy `optBy<Model>FFT` with `'ExpandOutput', true` (see reference files) |
| Single-strike high-accuracy | NumericalIntegration |
| Calibration (many evaluations) | FFT with `'CharacteristicFcnStep', 0.1` or higher (not above 0.4) |
| High accuracy at specific strikes (near-NI precision, faster) **or** calibration needing sub-$0.0001 accuracy + speed | FRFT: CharacteristicFcnStep=0.3, NumFFT=2048, LogStrikeStep=2*pi/(NumFFT*CharacteristicFcnStep)/10 |
| Validating FFT results | NumericalIntegration as benchmark |

## Critical: FFT Accuracy — CharacteristicFcnStep

**This applies to ALL three models.** The default `CharacteristicFcnStep=0.01` produces significant errors for OTM/ITM strikes. The root cause is the log-strike grid resolution:

```
LogStrikeStep = 2*pi / (NumFFT * CharacteristicFcnStep)
```

Accuracy is governed by `LogStrikeStep` (smaller = better). Increasing `CharacteristicFcnStep` is free (no speed penalty); increasing `NumFFT` costs O(N log N) time.

### Key Insight: CharacteristicFcnStep Matters More Than NumFFT

**Always state both parts explicitly in every accuracy recommendation:** (1) increasing `CharacteristicFcnStep` has **zero computational cost** (same FFT size, same speed), and (2) this distinguishes it from increasing `NumFFT` which costs O(N log N) time. The contrast between the two is the key insight users need.

| CharacteristicFcnStep | LogStrikeStep | Worst Price Error | Use Case |
|----------------------|---------------|-------------------|----------|
| 0.01 (default) | 0.1534 | $0.30-0.96 | **Never use** |
| 0.10 | 0.0153 | $0.004-0.009 | Safe default |
| 0.20 | 0.0077 | $0.001-0.005 | Higher precision |
| 0.30 | 0.0051 | $0.0006-0.001 | Large-notional trades |
| 0.40 | 0.0038 | $0.0003 | Best classical FFT accuracy |
| >=0.50 | <=0.0031 | Degrades ($0.003+) | Negative prices for deep OTM — do not use |

Increasing `CharacteristicFcnStep` is free (no speed penalty). Accuracy peaks around 0.3-0.4; above 0.5, accuracy degrades because the characteristic function integration becomes too coarse, and deep OTM strikes can produce negative prices. Once `CharacteristicFcnStep` is at its optimal limit (~0.3-0.4), use FRFT (set `LogStrikeStep` explicitly) for further accuracy, or increase `NumFFT` at the cost of O(N log N) time.

## FRFT (Fractional FFT) — Beyond Classical FFT Accuracy

When `LogStrikeStep` is set explicitly to a value different from `2*pi/(NumFFT*CharacteristicFcnStep)`, MATLAB automatically uses Fractional FFT (FRFT) internally. FRFT decouples the characteristic function grid from the output strike grid, allowing both to be optimized independently.

**Recommended FRFT LogStrikeStep:** Set to 1/10th of the classical default:

```
LogStrikeStep = 2*pi / (NumFFT * CharacteristicFcnStep) / 10
```

This heuristic delivers 100-160x accuracy improvement over classical FFT across all NumFFT and CharacteristicFcnStep combinations. The `/10` factor provides a finer output strike grid while keeping the grid range (`NumFFT x LogStrikeStep / 2`) large enough for typical strike ranges. Be flexible with the `/10` factor for extreme cases of required strike ranges, accuracy, and speed.

### Why FRFT Outperforms Classical FFT

Classical FFT constraint: `LogStrikeStep = 2*pi / (NumFFT * CharacteristicFcnStep)`. Increasing CharacteristicFcnStep makes LogStrikeStep smaller (better), but CharacteristicFcnStep saturates at ~0.3 — beyond that, accuracy degrades. Once at this limit, the only way to get finer strike resolution is increasing NumFFT (costs O(N log N) time). FRFT breaks this coupling — you can keep CharacteristicFcnStep near its optimal value AND further reduce LogStrikeStep from its FFT constraint, without increasing NumFFT.

### FRFT Configurations

| Use Case | Config | LogStrikeStep value | MaxErr | Speed |
|----------|--------|---------------------|--------|-------|
| Standard FRFT | CharacteristicFcnStep=0.3, NumFFT=2048 | 2pi/(2048x0.3)/10 ~ 0.001 | ~$0.00003 | ~6ms |
| High-Accuracy FRFT | CharacteristicFcnStep=0.3, NumFFT=4096 | 2pi/(4096x0.3)/10 ~ 0.0005 | ~$0.000006 | ~8ms |
| Classical FFT (comparison) | CharacteristicFcnStep=0.3, NumFFT=4096, no LogStrikeStep | (governed by formula) | ~$0.0009 | ~6ms |
| Classical FFT high-acc (comparison) | CharacteristicFcnStep=0.3, NumFFT=2^14, no LogStrikeStep | (governed by formula) | ~$0.00005 | ~14ms |

FRFT with NumFFT=2048 achieves **34x better accuracy** than classical NumFFT=4096 at the same speed, and **2x better accuracy** than classical NumFFT=2^14 at half the time. Works identically for Heston, Bates, and Merton. Greeks also improve by 28-39x. Be flexible with the `/10` factor for extreme cases of required strike ranges, accuracy, and speed.

### Grid Range Constraint

**Critical:** `NumFFT x LogStrikeStep / 2` must exceed `max|log(K/S)|` for all requested strikes. If violated, MATLAB errors: "Specified Strike has a value out of range of the FFT strike grid."

**Always verify coverage:** When recommending or generating FRFT code, explicitly compute and state the grid half-range (`NumFFT x LogStrikeStep / 2`) and confirm it covers the requested strikes. For example: "Grid half-range = 2048 x 0.001 / 2 = 1.024, covering strikes from $36 to $279 for spot=$100 — adequate for the 80-120 range."

| Strike range (K/S) | Minimum half-range needed | NumFFT=2048, LogStrikeStep=0.001 provides |
|---------------------|--------------------------|-------------------------------------------|
| 0.7-1.4 | 0.357 | 1.024 |
| 0.5-2.0 | 0.693 | 1.024 |
| 0.3-3.0 | 1.204 | 1.024 **X** (increase NumFFT or LogStrikeStep) |

**Coverage guarantee of the 1/10th formula:** With the recommended `/10` LogStrikeStep, the grid half-range simplifies to `pi/(10 x CharacteristicFcnStep)`. For CharacteristicFcnStep=0.3: half-range = pi/(10x0.3) ~ 1.047, covering strikes from ~$35 to ~$285 (for spot=$100). For comparison, classical FFT (no user-set LogStrikeStep) has half-range = `pi/CharacteristicFcnStep` — for CharacteristicFcnStep=0.3 that's ~10.5, so the grid constraint is never an issue with classical FFT. The 1/10th FRFT formula has a much tighter grid, but still covers most practical strike ranges. If the constraint IS violated, increase NumFFT (not LogStrikeStep — that defeats the precision purpose) or verify that the strike range is truly needed.

### When to Use FRFT vs Classical FFT

| Scenario | Recommendation |
|----------|---------------|
| Simple pricing, moderate accuracy | Classical FFT: CharacteristicFcnStep=0.1, NumFFT=4096 |
| Simple pricing, higher accuracy | Classical FFT: CharacteristicFcnStep=0.3, NumFFT=4096 (~$0.001 error is adequate) |
| Further improve accuracy from classical FFT | **FRFT: add `LogStrikeStep = 2*pi/(NumFFT*CharacteristicFcnStep)/10`** |
| Near-NI precision at FFT speed | **FRFT: CharacteristicFcnStep=0.3, NumFFT=4096, LogStrikeStep=0.0005** |
| Fast and accurate pricing | **FRFT: CharacteristicFcnStep=0.3, NumFFT=2048, LogStrikeStep=0.001** |
| CharacteristicFcnStep >= 0.5 | **Do not use** — accuracy degrades regardless of FRFT |

## LittleTrap Formulation

**Always use `LittleTrap = true` (the default).** Setting to `false` causes NI to produce NaN due to branch-cut discontinuities. The "Little Heston Trap" (Albrecher et al.) reformulation eliminates this instability. Applies to Heston and Bates models (both have stochastic variance). This property does not apply to the Merton model because the Merton model has no stochastic variance path.

## DampingFactor — Leave at Default (1.5)

**Never tune `DampingFactor`.** Across 700+ test cases (all three models, OO and legacy APIs, calls and puts, moneyness 50%-150%, maturities 3M-5Y), DampingFactor=1.5 is adequate for every scenario. Any error observed at DampingFactor=1.5 is a grid error (CharacteristicFcnStep/LogStrikeStep/NumFFT), not a damping error — changing DampingFactor alone does not fix it. Change DampingFactor from 1.5 (default) only when explicitly asked to do so.

| DampingFactor Range | Behavior |
|---------------------|----------|
| **[0.75, 3.0]** | Safe plateau — all values produce near-identical errors |
| **1.5 (default)** | Optimal and universally safe |
| < 0.5 | Dangerous at higher CharacteristicFcnStep — can produce negative prices for deep OTM |
| >= 15 | Catastrophic overflow — negative prices or values exceeding 10^200 (all models) |

If asked about DampingFactor tuning: explain that accuracy is governed by `CharacteristicFcnStep` and grid density, not DampingFactor. Always redirect with this accuracy hierarchy:
1. **CharacteristicFcnStep** (increase to 0.1-0.3) — primary lever, zero speed cost
2. **FRFT with LogStrikeStep** — secondary lever for sub-$0.001 precision
3. **Increased NumFFT** — last resort, costs O(N log N)

## Recommended FFT Pricer Settings

```matlab
% SAFE DEFAULT: Works for any strike range, all models (~$0.004 error)
FFTPricer = finpricer("FFT", 'Model', Model, ...
    'DiscountCurve', rc, 'SpotPrice', AssetPrice, ...
    'CharacteristicFcnStep', 0.1);

% HIGH PRECISION: Sub-$0.001 error, zero speed cost (~$0.0006 error)
FFTPricer = finpricer("FFT", 'Model', Model, ...
    'DiscountCurve', rc, 'SpotPrice', AssetPrice, ...
    'CharacteristicFcnStep', 0.3);

% ULTRA PRECISION via FRFT: Set LogStrikeStep to 1/10th of the classical default
% Formula: LogStrikeStep = 2*pi / (NumFFT * CharacteristicFcnStep) / 10
% With NumFFT=2048, CharacteristicFcnStep=0.3: LogStrikeStep ~ 0.001
FFTPricer = finpricer("FFT", 'Model', Model, ...
    'DiscountCurve', rc, 'SpotPrice', AssetPrice, ...
    'CharacteristicFcnStep', 0.3, 'NumFFT', 2048, ...
    'LogStrikeStep', 2*pi/(2048*0.3)/10);

% NEAR-NI PRECISION via FRFT: Same formula with NumFFT=4096
% With NumFFT=4096, CharacteristicFcnStep=0.3: LogStrikeStep ~ 0.0005
FFTPricer = finpricer("FFT", 'Model', Model, ...
    'DiscountCurve', rc, 'SpotPrice', AssetPrice, ...
    'CharacteristicFcnStep', 0.3, 'NumFFT', 4096, ...
    'LogStrikeStep', 2*pi/(4096*0.3)/10);

% AVOID: Default CharacteristicFcnStep=0.01 — errors up to $1
% AVOID: CharacteristicFcnStep >= 0.5 — accuracy degrades (even with FRFT)
```

## Legacy Functional API

Legacy functions (R2018a+) follow the pattern `optBy<Model>FFT`, `optBy<Model>NI`, `optSensBy<Model>FFT`, `optSensBy<Model>NI`:

| Model | Pricing Functions | Sensitivity Functions |
|-------|-------------------|---------------------|
| Heston | `optByHestonFFT`, `optByHestonNI` | `optSensByHestonFFT`, `optSensByHestonNI` |
| Bates | `optByBatesFFT`, `optByBatesNI` | `optSensByBatesFFT`, `optSensByBatesNI` |
| Merton | `optByMertonFFT`, `optByMertonNI` | `optSensByMertonFFT`, `optSensByMertonNI` |

### Legacy Function Signatures

All legacy FFT functions return `[Price, StrikeOut]`; all NI functions return `Price` only (**no `StrikeOut`**). Positional args: `Rate, AssetPrice, Settle, Maturity, OptSpec, Strike, <model params>`. Model params: Heston has 5 (V0->RhoSV), Bates has 8 (adds MeanJ, JumpVol, JumpFreq), Merton has 4 (Sigma, MeanJ, JumpVol, JumpFreq). See model-specific reference files for full signatures.

### Legacy Sensitivity OutSpec Values

| Model | Available `OutSpec` values |
|-------|---------------------------|
| Heston | `"price"`, `"delta"`, `"gamma"`, `"vega"`, `"rho"`, `"theta"`, `"vegalt"` |
| Bates | `"price"`, `"delta"`, `"gamma"`, `"vega"`, `"rho"`, `"theta"`, `"vegalt"` |
| Merton | `"price"`, `"delta"`, `"gamma"`, `"vega"`, `"rho"`, `"theta"` (**no `"vegalt"`**) |

### Legacy Key Differences from OO API

- FFT functions return `StrikeOut` as the last output; NI functions do NOT return `StrikeOut`
- `OutSpec` controls positional outputs (1:1 mapping to output variables)
- `'ExpandOutput', true` returns strike-by-maturity matrices — 2-6x faster for surfaces (not available in OO)
- Heston/Bates have `LittleTrap` and `VolRiskPremium`; Merton does NOT
- **`Strike=[]` for grid exploration** — pass empty `Strike` to compute prices on the entire internal FFT/FRFT strike grid. The `StrikeOut` output then returns all `NumFFT` grid strikes (`exp(log-strike grid)`), centered around `log(AssetPrice)`. Use this to inspect grid density, coverage, and spacing at different `CharacteristicFcnStep`/`NumFFT`/`LogStrikeStep` settings. Not possible in the OO API (which requires a specific Strike on `fininstrument`).

For full legacy API details, see `references/ni-fft/legacy-api-shared.md`, `references/ni-fft/heston-legacy-api.md`, `references/ni-fft/bates-legacy-api.md`, and `references/ni-fft/merton-legacy-api.md`.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Large FFT vs NI discrepancy at OTM strikes | Default `CharacteristicFcnStep=0.01` too small | Set 'CharacteristicFcnStep' to 0.1 (or higher up to 0.3) on pricer |
| NI returns NaN | `LittleTrap = false` or extreme params | Keep `'LittleTrap', true` (default) |
| `"Vegalt"` error with Merton | Merton has no stochastic vol | Use `"All"` (returns 6 sensitivities) or explicit list without `"Vegalt"` |
| NI warns "integration failed" | Integrand oscillates beyond range | Adjust `'IntegrationRange'` on pricer |
| Negative prices at deep OTM | FFT grid artifacts | Increase `CharacteristicFcnStep` to 0.1 or 0.15 |
| Increasing `NumFFT` alone doesn't help | `LogStrikeStep` depends on N*step product | Increase `CharacteristicFcnStep` (free) before `NumFFT` (costly) |

## Source Verification Notes

Verified against official MATLAB `help` output (Financial Instruments Toolbox). Common LLM errors corrected:

| Item | Common LLM Hallucination | Verified Truth |
|------|--------------------------|----------------|
| `optByHestonNI` / `optByBatesNI` / `optByMertonNI` signature | `[Price, StrikeOut] = ...` | `Price = ...` — **no `StrikeOut`** |
| Merton sensitivities | Supports `"vegalt"` | Only 6: price, delta, gamma, vega, rho, theta — **no vegalt** |
| Merton legacy NV args | Has `LittleTrap`, `VolRiskPremium` | **Neither** — Merton legacy has no stochastic variance |
| NI `IntegrationRange` default | `[0 Inf]` | `[1e-9 Inf]` |
| FFT NV arg name | `'CharacteristicFcn'` | Correct: `'CharacteristicFcnStep'` |
| Legacy `StrikeOut` position | Second output always | **Last output** — position depends on `OutSpec` entries for optSensBy*FFT functions|
| OO sensitivity column name | `Vegalt` | Results table column is `VegaLT` |
| Merton model param name | `Sigma` or `Vol` | Correct: `'Volatility'` in OO; `Sigma` positional arg in legacy |

**Best practice:** Run `doc optByBatesFFT`, `doc finmodel.Merton`, etc. via the MATLAB MCP server to confirm signatures before writing code.

----

Copyright 2026 The MathWorks, Inc.

----
