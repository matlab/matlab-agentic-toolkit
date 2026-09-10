# Bates Legacy API Reference

See `legacy-api-shared.md` for NV arguments, ExpandOutput, Strike=[], output mapping rules, and legacy-to-OO mapping.

## Function Signatures

```matlab
% Pricing — FFT returns [Price, StrikeOut]; NI returns Price only
[Price, StrikeOut] = optByBatesFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, MeanJ, JumpVol, JumpFreq)
Price = optByBatesNI(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, MeanJ, JumpVol, JumpFreq)

% Sensitivities — FFT returns [..., StrikeOut]; NI returns Price and Sensitivities only
[PriceSens, StrikeOut] = optSensByBatesFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, MeanJ, JumpVol, JumpFreq, Name, Value)
PriceSens = optSensByBatesNI(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, MeanJ, JumpVol, JumpFreq, Name, Value)
```

**Positional model params (8):** `V0, ThetaV, Kappa, SigmaV, RhoSV, MeanJ, JumpVol, JumpFreq`

**Available OutSpec values:** `"price"`, `"delta"`, `"gamma"`, `"vega"`, `"rho"`, `"theta"`, `"vegalt"` (7 total)

## Example: All Greeks with ExpandOutput

```matlab
Strike = [90; 95; 100; 105; 110];
Maturity = [datetime(2026,12,31); datetime(2027,6,30); datetime(2027,12,31)];

V0 = 0.04; ThetaV = 0.04; Kappa = 1.5; SigmaV = 0.3; RhoSV = -0.7;
MeanJ = -0.1; JumpVol = 0.2; JumpFreq = 1.0;

OutSpec = ["price", "delta", "gamma", "vega", "rho", "theta", "vegalt"];

% Returns seven 5-by-3 matrices + StrikeOut
[Price, Delta, Gamma, Vega, Rho, Theta, Vegalt, StrikeOut] = ...
    optSensByBatesFFT(Rate, AssetPrice, Settle, Maturity, ...
    OptSpec, Strike, V0, ThetaV, Kappa, SigmaV, RhoSV, ...
    MeanJ, JumpVol, JumpFreq, ...
    'OutSpec', OutSpec, 'CharacteristicFcnStep', 0.1, 'ExpandOutput', true);
```

## OO Model Mapping

`V0, ThetaV, Kappa, SigmaV, RhoSV, MeanJ, JumpVol, JumpFreq` → `finmodel("Bates", 'V0', V0, 'ThetaV', ThetaV, 'Kappa', Kappa, 'SigmaV', SigmaV, 'RhoSV', RhoSV, 'MeanJ', MeanJ, 'JumpVol', JumpVol, 'JumpFreq', JumpFreq)`

----

Copyright 2026 The MathWorks, Inc.

----
