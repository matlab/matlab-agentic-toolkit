# dsphdl NumCycles: Resource Sharing in Decimation Chains

## Overview

The `NumCycles` property on `dsphdl` System objects controls **resource sharing** — it tells the filter how many clock cycles elapse between valid input samples, so the hardware can reuse multipliers across those idle cycles instead of instantiating one multiplier per tap.

**Key principle:** In a decimation chain, each stage's input arrives at a slower rate than the system clock. `NumCycles` should match that rate ratio so the filter exploits every available idle cycle for multiplier reuse.

## Objects with NumCycles

| System Object | Default | Required FilterStructure | Typical Use |
|---|---|---|---|
| `dsphdl.FIRDecimator` | `1` | `'Direct form systolic'` | Decimation chains — set to cumulative decimation at input |
| `dsphdl.FIRFilter` | `2` | `'Partly serial systolic'` | Standalone filters in multi-rate chains |
| `dsphdl.FarrowRateConverter` | `1` | — | Fractional rate converters after integer decimation stages |

**IMPORTANT — FilterStructure differs by object:**
- `dsphdl.FIRFilter`: `NumCycles` is only active with `'Partly serial systolic'`. Using `'Direct form systolic'` silently ignores `NumCycles` (produces a warning).
- `dsphdl.FIRDecimator`: `NumCycles` is active with `'Direct form systolic'` (the default).
- `dsphdl.FIRFilter` also requires setting `SerializationOption` to either `'Minimum number of cycles between valid input samples'` (then set `NumCycles`) or `'Maximum number of multipliers'` (then set `NumberOfMultipliers`).


## Critical Convention

**ALWAYS set `NumCycles`** to the number of system clock cycles between valid input samples at that stage. In a decimation chain, this equals the cumulative decimation factor at the stage's input:

- First filter after CIC(xR): `NumCycles = R`
- Second filter after CIC(xR) + FIR(xD): `NumCycles = R * D`
- Farrow after CIC(xR) + FIR(xD): `NumCycles = R * D`

## How It Works

Without resource sharing (`NumCycles = 1`), an N-tap FIR needs N multipliers running in parallel — one multiply per tap per clock. With `NumCycles = K`, the filter serializes computation across K clocks, needing only ceil(N/K) multipliers.

**Example:** A 32-tap FIR after a CIC that decimates by 16:
- `NumCycles = 1` → 32 multipliers (no sharing)
- `NumCycles = 16` → ceil(32/16) = 2 multipliers (16x reduction)

The filter accepts one sample, computes for 16 clocks using 2 multipliers, then is ready for the next sample — which arrives exactly 16 clocks later because of the CIC decimation.

## Decimation Chain Examples

### Two-Stage: CIC + FIR

```matlab
cicR = 8;
cicDec = dsphdl.CICDecimator('DecimationFactor', cicR, 'NumSections', 4);

compCoeffs = coeffs(dsp.CICCompensationDecimator(2, 'CICRateChangeFactor', cicR, 'CICNumSections', 4)).Numerator;
firDec = dsphdl.FIRDecimator( ...
    'DecimationFactor', 2, ...
    'Numerator', compCoeffs, ...
    'NumCycles', cicR, ...
    'FilterStructure', 'Direct form systolic');
```

### Three-Stage: CIC + FIR + FIR

```matlab
cicR = 16;
cicDec = dsphdl.CICDecimator('DecimationFactor', cicR, 'NumSections', 5);

compCoeffs = coeffs(dsp.CICCompensationDecimator(2, 'CICRateChangeFactor', cicR, 'CICNumSections', 5)).Numerator;
firDec1 = dsphdl.FIRDecimator( ...
    'DecimationFactor', 2, ...
    'Numerator', compCoeffs, ...
    'NumCycles', cicR, ...
    'FilterStructure', 'Direct form systolic');

chanCoeffs = designMultirateFIR(1, 2);
firDec2 = dsphdl.FIRDecimator( ...
    'DecimationFactor', 2, ...
    'Numerator', chanCoeffs, ...
    'NumCycles', cicR * 2, ...
    'FilterStructure', 'Direct form systolic');
% Total: 16 * 2 * 2 = 64x decimation
% firDec1: 16 clocks/sample → ceil(32/16) = 2 multipliers
% firDec2: 32 clocks/sample → ceil(64/32) = 2 multipliers
```

### With Farrow Rate Converter

```matlab
cicR = 4; firR = 2;
cicDec = dsphdl.CICDecimator('DecimationFactor', cicR, 'NumSections', 4);

compCoeffs = coeffs(dsp.CICCompensationDecimator(firR, 'CICRateChangeFactor', cicR, 'CICNumSections', 4)).Numerator;
firDec = dsphdl.FIRDecimator( ...
    'DecimationFactor', firR, ...
    'Numerator', compCoeffs, ...
    'NumCycles', cicR, ...
    'FilterStructure', 'Direct form systolic');

farrow = dsphdl.FarrowRateConverter( ...
    'RateChangeSource', 'Property', ...
    'RateChange', 41/40, ...
    'NumCycles', cicR * firR);
% Farrow input rate = CIC(x4) * FIR(x2) = 8 clocks between samples
```

### FIRFilter in a Multi-Rate Chain

```matlab
% Standalone FIR filter running after 8x decimation
fir = dsphdl.FIRFilter( ...
    'Numerator', fir1(63, 0.5), ...
    'FilterStructure', 'Partly serial systolic', ...
    'SerializationOption', 'Minimum number of cycles between valid input samples', ...
    'NumCycles', 8);
% 'Partly serial systolic' is required for NumCycles on FIRFilter
% ceil(64/8) = 8 multipliers instead of 64
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Not setting NumCycles (defaults to 1) | Set to cumulative decimation at that stage's input |
| Setting NumCycles larger than available clocks | NumCycles must not exceed the actual inter-sample gap — filter will miss samples |
| Setting NumCycles on CICDecimator | CICDecimator does not have NumCycles — it is inherently serial by design |
| Confusing NumCycles with DecimationFactor | NumCycles = clock cycles between valid inputs (for sharing); DecimationFactor = rate change ratio |
| Using NumCycles > 1 with frame (vector) input on FIRDecimator | Frame input with NumCycles > 1 is not supported on `Direct form systolic` — use scalar input |
| Using `'Direct form systolic'` with NumCycles on `dsphdl.FIRFilter` | `FIRFilter` requires `'Partly serial systolic'` for NumCycles — `'Direct form systolic'` silently ignores it (warning only). Also set `SerializationOption`. |
| Forgetting `SerializationOption` on `dsphdl.FIRFilter` | Set `'Minimum number of cycles between valid input samples'` (for NumCycles) or `'Maximum number of multipliers'` (for NumberOfMultipliers) |
| Assuming all objects use the same FilterStructure for NumCycles | `FIRDecimator` uses `'Direct form systolic'`; `FIRFilter` uses `'Partly serial systolic'` — they differ |

----

Copyright 2026 The MathWorks, Inc.
