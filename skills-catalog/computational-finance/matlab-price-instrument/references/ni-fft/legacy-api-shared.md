# Legacy API — Shared Reference

All legacy functions follow the pattern `optBy<Model>FFT`, `optBy<Model>NI`, `optSensBy<Model>FFT`, `optSensBy<Model>NI`. They are supported (R2018a+) but the OO workflow (R2020a+) is recommended for new code. Use legacy when you need `ExpandOutput` for surfaces or `Strike=[]` for grid inspection.

## Output Rules

- **FFT functions** return `[..., StrikeOut]` — StrikeOut is always the **last** output (optional)
- **NI functions** return price or sensitivity outputs only — **no StrikeOut**
- For optSensBy* functions, `OutSpec` controls which sensitivities are returned; outputs are positional (1:1 with entries)

```matlab
% FFT: StrikeOut is always LAST, after all OutSpec entries
[Delta, Gamma, Vega, StrikeOut] = optSensBy<Model>FFT(..., ...
    'OutSpec', ["delta", "gamma", "vega"], 'CharacteristicFcnStep', 0.1);

% NI: no StrikeOut
[Delta, Gamma, Vega] = optSensBy<Model>NI(..., ...
    'OutSpec', ["delta", "gamma", "vega"]);
```

## Name-Value Arguments

### FFT-Specific

| Name | Default | Recommendation |
|------|---------|----------------|
| `NumFFT` | 4096 | Keep default; increase `CharacteristicFcnStep` instead |
| `CharacteristicFcnStep` | 0.01 | **Set to 0.1 or higher but not above 0.4** |
| `LogStrikeStep` | 2*pi/NumFFT/CharacteristicFcnStep | Set to 2*pi/NumFFT/CharacteristicFcnStep/10 for FRFT |
| `DampingFactor` | 1.5 | Leave at default |
| `Quadrature` | `"simpson"` | Leave at default |

### NI-Specific

| Name | Default | Notes |
|------|---------|-------|
| `AbsTol` | 1e-10 | Absolute error tolerance (leave at default) |
| `RelTol` | 1e-6 | Relative error tolerance (leave at default) |
| `IntegrationRange` | [1e-9 Inf] | Adjust if integration warnings appear |
| `Framework` | `"heston1993"` | Also `"lewis2001"` |

### Shared (all models)

| Name | Default | Notes |
|------|---------|-------|
| `Basis` | 0 | Day-count basis (numeric: 0,1,2,...,13) |
| `DividendYield` | 0 | Continuously compounded yield |
| `ExpandOutput` | false | Expand to strike-by-maturity matrices |

**Model-specific NV args:** Heston/Bates have `LittleTrap` (default true, always keep true) and `VolRiskPremium` (default 0). **Merton does NOT support either** — passing them causes an error.

## ExpandOutput: Efficient Surface Generation

Setting `'ExpandOutput', true` returns outputs as **NumStrikes-by-NumMaturities matrices**. This is the fastest way to generate surfaces — 2–6× faster than looping over maturities. Not available in the OO workflow.

```matlab
% Pattern: column vector of strikes, vector of maturities
Strike = (80:5:120)';       % column vector
Maturity = [datetime(2026,9,30); datetime(2026,12,31); ...
            datetime(2027,6,30); datetime(2027,12,31)];

% Pricing surface (9-by-4 matrix)
[PriceSurface, StrikeOut] = optBy<Model>FFT(Rate, AssetPrice, Settle, ...
    Maturity, OptSpec, Strike, <model params>, ...
    'CharacteristicFcnStep', 0.1, 'ExpandOutput', true);

% Sensitivity surfaces (each 9-by-4)
[Delta, Vega, StrikeOut] = optSensBy<Model>FFT(Rate, AssetPrice, Settle, ...
    Maturity, OptSpec, Strike, <model params>, ...
    'OutSpec', ["delta", "vega"], 'CharacteristicFcnStep', 0.1, ...
    'ExpandOutput', true);
```

## Strike=[] Grid Inspection (Legacy Only)

Pass empty Strike to compute prices on the entire internal FFT/FRFT grid. `StrikeOut` then returns all `NumFFT` grid strikes centered around `log(AssetPrice)`.

```matlab
[Price, StrikeOut] = optBy<Model>FFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, [], <model params>, 'CharacteristicFcnStep', 0.1);
% StrikeOut has NumFFT entries — inspect grid density and coverage
```

Not possible in the OO API (which requires specific strikes on `fininstrument`).

## Legacy-to-OO Mapping

| Legacy | OO Equivalent |
|--------|---------------|
| `Rate` (scalar) | `ratecurve("zero", Settle, Maturity, Rate, 'Compounding', -1)` |
| `AssetPrice` | `'SpotPrice', AssetPrice` on pricer |
| `OptSpec`, `Strike`, `Maturity` | `fininstrument("Vanilla", 'Strike', K, 'ExerciseDate', T, 'OptionType', OptSpec)` |
| `'DividendYield', q` | `'DividendValue', q` on pricer |
| `'OutSpec', ["delta","vega"]` | Third arg to `price()`: `["Delta","Vega"]` |
| Positional sensitivity outputs | `outPR.Results` table with named columns |
| `StrikeOut` (last FFT output) | Not needed — OO prices at exact requested strikes |

----

Copyright 2026 The MathWorks, Inc.

----
