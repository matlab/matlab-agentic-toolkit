# Merton Legacy API Reference

See `legacy-api-shared.md` for NV arguments, ExpandOutput, Strike=[], output mapping rules, and legacy-to-OO mapping.

## Function Signatures

```matlab
% Pricing — FFT returns [Price, StrikeOut]; NI returns Price only
[Price, StrikeOut] = optByMertonFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, Sigma, MeanJ, JumpVol, JumpFreq)
Price = optByMertonNI(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, Sigma, MeanJ, JumpVol, JumpFreq)

% Sensitivities — FFT returns [..., StrikeOut]; NI returns Price and Sensitivities only
[PriceSens, StrikeOut] = optSensByMertonFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, Sigma, MeanJ, JumpVol, JumpFreq, Name, Value)
PriceSens = optSensByMertonNI(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, Sigma, MeanJ, JumpVol, JumpFreq, Name, Value)
```

**Positional model params (4):** `Sigma, MeanJ, JumpVol, JumpFreq`

**Available OutSpec values:** `"price"`, `"delta"`, `"gamma"`, `"vega"`, `"rho"`, `"theta"` (6 total — **no `"vegalt"`**)

## Merton-Specific Differences

- **No `"vegalt"`** — Merton has no stochastic variance, so vol-of-vol sensitivity is undefined
- **No `LittleTrap`** — not applicable (no stochastic variance path)
- **No `VolRiskPremium`** — not applicable; passing either causes an error
- **Positional arg is `Sigma`** but the OO property is **`'Volatility'`** — do not confuse them

## Example: All Greeks with ExpandOutput

```matlab
Strike = [90; 95; 100; 105; 110];
Maturity = [datetime(2026,12,31); datetime(2027,6,30); datetime(2027,12,31)];

Sigma = 0.2; MeanJ = -0.1; JumpVol = 0.2; JumpFreq = 1.0;

% 6 sensitivities only — no "vegalt"
OutSpec = ["price", "delta", "gamma", "vega", "rho", "theta"];

% Returns six 5-by-3 matrices + StrikeOut
[Price, Delta, Gamma, Vega, Rho, Theta, StrikeOut] = ...
    optSensByMertonFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, Sigma, MeanJ, JumpVol, JumpFreq, ...
    'OutSpec', OutSpec, 'CharacteristicFcnStep', 0.1, 'ExpandOutput', true);
```

## OO Model Mapping

`Sigma, MeanJ, JumpVol, JumpFreq` → `finmodel("Merton", 'Volatility', Sigma, 'MeanJ', MeanJ, 'JumpVol', JumpVol, 'JumpFreq', JumpFreq)`

**Important:** Legacy positional arg is `Sigma`; OO property is `'Volatility'`.

----

Copyright 2026 The MathWorks, Inc.

----
