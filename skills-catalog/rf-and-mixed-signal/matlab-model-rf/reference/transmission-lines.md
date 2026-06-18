# Transmission Line Elements

Reference material for all rfbudget-compatible transmission line objects.

All transmission line objects are 2-port and rfbudget-compatible. They all use `LineLength` for physical length (not `Length`).

## Delay Lines (Ideal)

```matlab
% Lossless -- constructor accepts Z0, TimeDelay, Name only (NOT LineLength)
tl = txlineDelayLossless('Z0', 50, 'TimeDelay', 33e-12);

% Lossy -- adds Resistance; accepts LineLength at construction
tl = txlineDelayLossy('Z0', 50, 'TimeDelay', 33e-12, 'Resistance', 0.5);
```

**Gotcha:** `txlineDelayLossless` constructor only accepts `Z0`, `TimeDelay`, and `Name`. Setting `LineLength` post-construction is allowed but does NOT affect the electrical delay. Physical txlines (Microstrip, Coaxial, RLCGLine, etc.) all accept `LineLength` at construction.

## Microstrip

```matlab
mstrip = txlineMicrostrip(Name='MS1');
mstrip.LineLength = 10e-3;       % 10 mm
mstrip.Width = 1.5e-3;           % 1.5 mm
mstrip.Height = 0.8e-3;          % Substrate height
mstrip.EpsilonR = 4.4;           % FR-4
```

## Coaxial

```matlab
coax = txlineCoaxial(Name='Coax1');
coax.LineLength = 0.1;           % 100 mm
coax.InnerRadius = 0.5e-3;
coax.OuterRadius = 2.3e-3;
coax.EpsilonR = 2.1;             % PTFE
```

## Other Physical Lines

| Object | Geometry |
|--------|----------|
| `txlineCPW` | Coplanar waveguide |
| `txlineStripline` | Stripline (embedded trace) |
| `txlineParallelPlate` | Parallel plate |
| `txlineTwoWire` | Two-wire (balanced) |

All use `LineLength` and geometric/material properties.

## RLCG Lines (Generic Models)

Two RLCG transmission line objects exist -- use the one matching your data:

| Object | Parameter Model | Use Case |
|--------|----------------|----------|
| `txlineRLCGLine` | Scalar R, L, C, G per unit length | Frequency-independent RLCG |
| `txlineWRLGC` | W-element: Lo, Co, Ro, Rs, Gd, Cd | Frequency-dependent skin/dielectric loss (R2026a) |

```matlab
% txlineRLCGLine -- frequency-independent RLCG
rlcg = txlineRLCGLine(Name='RLCG1');
rlcg.LineLength = 0.05;
rlcg.R = 0.5;                   % Ohm/m
rlcg.L = 250e-9;                % H/m
rlcg.C = 100e-12;               % F/m
rlcg.G = 0;                     % S/m

% txlineWRLGC -- frequency-dependent W-element model
tl = txlineWRLGC('Lo', 350e-9, 'Co', 130e-12, 'Ro', 2, ...
    'Rs', 5e-4, 'Gd', 1e-11, 'LineLength', 0.1, 'Name', 'WLine');
% For multi-conductor (coupled pair): set Nline=2 with matrix RLCG values
```

## Table-Based Model

`txlineWtable` accepts frequency-dependent R, L, G, C vectors for arbitrary loss profiles.

## Gotchas

- **`LineLength` not `Length`** -- all transmission line objects use `LineLength` for physical length.
- There is no `rlcgLine` object -- always use `txlineRLCGLine` or `txlineWRLGC`.
- `txlineDelayLossless` ignores `LineLength` -- delay is set solely by `TimeDelay`.

----

Copyright 2026 The MathWorks, Inc.

----
