# Model Structures

## Process Model (idproc) Guide

Low-order physical models ideal for simple dynamics with gain, time constants, and delay:

| Structure | Transfer Function | Physical meaning |
|-----------|-------------------|-----------------|
| `'P1'` | K/(1+Tp1*s) | First-order, no delay |
| `'P1D'` | K*e^(-Td*s)/(1+Tp1*s) | First-order with delay |
| `'P2'` | K/((1+Tp1*s)(1+Tp2*s)) | Overdamped second-order |
| `'P2D'` | K*e^(-Td*s)/((1+Tp1*s)(1+Tp2*s)) | Overdamped 2nd-order + delay |
| `'P2U'` | K*w^2/(s^2+2*zeta*w*s+w^2) | Underdamped second-order |
| `'P2UD'` | K*w^2*e^(-Td*s)/(s^2+2*zeta*w*s+w^2) | Underdamped 2nd-order + delay |
| `'P2Z'` | K(1+Tz*s)/((1+Tp1*s)(1+Tp2*s)) | Second-order with zero |
| `'P3'` | K/((1+Tp1*s)(1+Tp2*s)(1+Tp3*s)) | Third-order |

```matlab
% Process model with integrator and delay
model = procest(data, 'P2ID');  % 'I' = integrator

% With disturbance model (for prediction applications)
opt = procestOptions('DisturbanceModel', 'ARMA1');
model = procest(data, 'P2D', opt);
```

**When to use**: Step response shows clear first/second-order dynamics. Physical parameters (gain K, time constants T, delay Td, damping zeta) are directly interpretable. Always try process models first for simple SISO plants before escalating to higher-order tf/ss.

## Polynomial Model Guide

| Model | Equation | Best for | Avoid when |
|-------|----------|----------|------------|
| ARX | A(q)y = B(q)u + e | High SNR, baseline, regularized high-order | Colored noise (biased estimates) |
| IV4 | A(q)y = B(q)u + e (instrumental vars) | Same as ARX but robust to colored noise | — |
| ARMAX | A(q)y = B(q)u + C(q)e | Load disturbances at plant input | Simple problems (overparameterized) |
| OE | y = [B/F]u + e | Dynamics-only, good for control design | Need prediction/filtering |
| BJ | y = [B/F]u + [C/D]e | Max flexibility, separate dynamics & noise | Small data (too many params) |

**Rule**: Start with ARX for delay + rough orders, then upgrade to OE or BJ if residuals show structure. If ARX residuals are colored, try `iv4` before jumping to ARMAX — same model structure but consistent estimates under colored noise.

## Experiment Design (if data not yet collected)

### Input Signal Selection

| Signal | Advantages | Best for | Avoid when |
|--------|-----------|----------|------------|
| **PRBS** | Flat spectrum, crest factor=1, binary | General broadband excitation | Need to detect static nonlinearities |
| **Multisine** | Precise frequency placement, low crest factor | Frequency-domain ID, specific band excitation | Very fast systems where DAC resolution limits |
| **Filtered white noise** | Any spectral shape, simple to generate | Flexible spectrum needed | Low SNR (crest factor ~3) |
| **Chirp/swept sine** | Covers frequency band sequentially, good SNR per frequency | Frequency response measurement | Need simultaneous excitation |
| **Step/pulse** | Simple, reveals time constants and delay directly | Process models, PID tuning | Need accurate high-frequency model |

### Input Signal Design Rules

1. **Amplitude**: As large as possible within actuator/linearity constraints. Larger = better SNR.
2. **Crest factor**: Low crest factor = efficient use of amplitude budget. Binary signals (CF=1) are theoretically optimal.
3. **Bandwidth**: Must cover the frequency range of interest. For PRBS: clock period P determines bandwidth.
4. **Persistence of excitation**: For nth-order system, input spectrum must be nonzero at >= n distinct frequencies.
5. **Periodicity**: Use periodic signals when possible — eliminates leakage, enables nonlinearity detection.

```matlab
% PRBS generation
u = idinput(N, 'prbs', [0 band], [-amplitude amplitude]);

% Multisine (Schroeder-phased for low crest factor)
freqs = logspace(log10(fmin), log10(fmax), nFreqs);
phases_schroeder = -pi*(1:nFreqs).*((1:nFreqs)-1)/nFreqs;
u = sum(amplitudes .* sin(2*pi*freqs'*(0:N-1)*Ts + phases_schroeder'), 1)';
```

### Sampling Rate Selection

Optimal sampling: ~5-15 samples per dominant time constant (tau_dom).

| Scenario | Recommended Ts | Rationale |
|----------|---------------|-----------|
| General | Ts ~ tau_dom / 10 | 10x bandwidth covers dynamics well |
| Oscillatory system | Ts ~ T_osc / (5 to 15) | T_osc = oscillation period |
| Unknown dynamics | Start at Ts = 1/(20*f_max_expected) | Can always downsample later |

**Pitfalls:**
* **Too fast** (Ts << tau/100): Poles cluster near z=1, numerical conditioning degrades
* **Too slow** (Ts >> tau): Aliasing, loss of dynamics information
* **Always anti-alias filter** before sampling

----

Copyright 2026 The MathWorks, Inc.

----
