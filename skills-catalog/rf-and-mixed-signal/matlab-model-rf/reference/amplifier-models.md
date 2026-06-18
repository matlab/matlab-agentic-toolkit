# Amplifier Nonlinear Models and Compression

Reference material for the `amplifier` element's nonlinear model options and compression parameter conventions.

## Nonlinear Models

| Model | Description | Use Case |
|-------|-------------|----------|
| `'poly'` (default) | Higher-order polynomial using ALL set compression params (e.g., OIP3, OP1dB, OPsat) | System budgets with compression |
| `'cubic'` | 3rd-order polynomial from ONE param selected by `Nonlinearity` | Legacy or single-param characterization |
| `'ampm'` | AM/AM and AM/PM table-based | Detailed compression analysis |
| `'sparam'` | S-parameter file data | Measured device characterization |

### `'poly'` Model (Default)

Set whichever compression params you have -- the model uses all of them to fit a higher-order polynomial:

```matlab
pa = amplifier('Gain', 30, 'NF', 5, 'OIP3', 40, ...
    'OP1dB', 28, 'OPsat', 35, 'Name', 'PA');
```

Do NOT set `Nonlinearity` for poly -- it is irrelevant and emits a warning.

### `'cubic'` Model

Uses a single compression parameter selected by the `Nonlinearity` property for a 3rd-order fit:

```matlab
amp = amplifier('Gain', 15, 'NF', 2, 'Model', 'cubic', ...
    'Nonlinearity', 'OIP3', 'OIP3', 35, 'Name', 'Amp');
```

Valid `Nonlinearity` values: `'OIP3'` (default), `'IP1dB'`, `'OP1dB'`, `'OPsat'`, `'IPsat'`.

Extra params are stored but ignored by the cubic model.

## Compression Parameters -- Input vs Output

| Parameter | Related Through | Convention |
|-----------|----------------|------------|
| OIP3 / IIP3 | OIP3 = IIP3 + Gain | Set either one |
| OP1dB / IP1dB | OP1dB = IP1dB + Gain - 1 | Set either one |
| OPsat / IPsat | Independent (not related through gain) | Both can be set |

- **Amplifier** datasheets typically specify output-referred: OIP3, OP1dB, OPsat
- **Mixer/modulator** datasheets typically specify input-referred: IIP3, IP1dB, IPsat
- It is rare to set both IPsat and OPsat -- parameters are usually all from the same reference plane

## Compression Properties Availability

`IP1dB`, `OP1dB`, `IPsat`, and `OPsat` are available on `amplifier`, `modulator`, and `rfelement` -- but NOT on `attenuator`, `phaseshift`, `rffilter`, `nport`, or `rfantenna` (passive/fixed elements).

```matlab
pa = amplifier('Gain', 30, 'NF', 5, 'OIP3', 40, ...
    'IP1dB', 10, 'OPsat', 35, 'Name', 'PA');
% OP1dB auto-computed: IP1dB + Gain - 1 ~ 39 dBm
```

Setting `IP1dB` automatically computes `OP1dB` (and vice versa). `IPsat`/`OPsat` are independent. All default to `Inf` (no compression).

## From S-Parameter File

```matlab
ampFromFile = amplifier('FileName', 'default.s2p', 'Name', 'LNAMeasured');
% Sets Model='sparam', UseNetworkData=true
% Gain comes from S-parameter data, not the Gain property
s = ampFromFile.NetworkData;     % sparameters object
```

----

Copyright 2026 The MathWorks, Inc.

----
