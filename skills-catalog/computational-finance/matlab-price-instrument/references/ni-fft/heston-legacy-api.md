# Heston Legacy API Reference

See `legacy-api-shared.md` for NV arguments, ExpandOutput, Strike=[], output mapping rules, and legacy-to-OO mapping.

## Function Signatures

```matlab
% Pricing — FFT returns [Price, StrikeOut]; NI returns Price only
[Price, StrikeOut] = optByHestonFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV)
Price = optByHestonNI(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV)

% Sensitivities — FFT returns [..., StrikeOut]; NI returns Price and Sensitivities only
[PriceSens, StrikeOut] = optSensByHestonFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, Name, Value)
PriceSens = optSensByHestonNI(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, Name, Value)
```

**Positional model params (5):** `V0, ThetaV, Kappa, SigmaV, RhoSV`

**Available OutSpec values:** `"price"`, `"delta"`, `"gamma"`, `"vega"`, `"rho"`, `"theta"`, `"vegalt"` (7 total)

## Example: All Greeks with ExpandOutput

```matlab
Strike = [90; 95; 100; 105; 110];
Maturity = [datetime(2026,12,31); datetime(2027,6,30); datetime(2027,12,31)];

V0 = 0.04; ThetaV = 0.04; Kappa = 1.5; SigmaV = 0.3; RhoSV = -0.7;

OutSpec = ["price", "delta", "gamma", "vega", "rho", "theta", "vegalt"];

% Returns seven 5-by-3 matrices + StrikeOut
[Price, Delta, Gamma, Vega, Rho, Theta, Vegalt, StrikeOut] = ...
    optSensByHestonFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, ...
    'OutSpec', OutSpec, 'CharacteristicFcnStep', 0.1, 'ExpandOutput', true);
```

## OO Model Mapping

`V0, ThetaV, Kappa, SigmaV, RhoSV` → `finmodel("Heston", 'V0', V0, 'ThetaV', ThetaV, 'Kappa', Kappa, 'SigmaV', SigmaV, 'RhoSV', RhoSV)`

----

Copyright 2026 The MathWorks, Inc.

----
