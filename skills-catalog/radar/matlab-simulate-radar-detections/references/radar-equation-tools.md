# Radar Equation & Detection Probability Tools

## Derived Quantity Helpers

| Function | Toolbox | Syntax | Purpose |
|----------|---------|--------|---------|
| `radareqrng` | Radar | `radareqrng(lambda, snr, Pt, tau, 'Gain', G_dB, 'Ts', Ts, 'RCS', rcs)` | Max detection range from radar equation |
| `radareqpow` | Radar | `radareqpow(lambda, R, snr, tau, 'Gain', G_dB, 'Ts', Ts)` | Required Tx power |
| `radareqsnr` | Radar | `radareqsnr(lambda, R, Pt, tau, 'Gain', G_dB, 'Ts', Ts, 'RCS', rcs)` | Received SNR at range |
| `horizonrange` | Radar | `horizonrange(antennaHeight)` | Radar horizon from antenna height |
| `height2el` | Radar | `height2el(R, tgtHeight)` | Elevation angle from target height |
| `el2height` | Radar | `el2height(R, el)` | Target height from elevation angle |
| `freq2wavelen` | Phased Array | `freq2wavelen(freq)` or `freq2wavelen(freq, c)` | Wavelength from frequency. Optional `c` for non-vacuum propagation speed |
| `rangeres2bw` | Phased Array | `rangeres2bw(rangeRes)` or `rangeres2bw(rangeRes, c, 'RangeBroadening', rb)` | Bandwidth from range resolution. Optional `c` (propagation speed), `rb` (broadening factor, default 1.0) |
| `bw2rangeres` | Phased Array | `bw2rangeres(bw)` or `bw2rangeres(bw, c, 'RangeBroadening', rb)` | Range resolution from bandwidth. Optional `c`, `rb` |
| `time2range` | Phased Array | `time2range(t)` or `time2range(t, c)` | Range from round-trip time. Optional `c` |
| `speed2dop` | Phased Array | `speed2dop(radvel, lambda)` | **One-way** Doppler shift from radial velocity. Returns `v/lambda`. For monostatic (two-way): multiply by 2 → `fd_twoway = 2*speed2dop(v, lambda)` |
| `dop2speed` | Phased Array | `dop2speed(fd, lambda)` | Radial velocity from **one-way** Doppler shift. Returns `fd*lambda`. For monostatic (two-way): divide by 2 → `v = dop2speed(fd, lambda)/2`, or use `lambda*fd/2` directly |
| `beamwidth2gain` | Phased Array | `beamwidth2gain([azBW; elBW])` or `beamwidth2gain([azBW; elBW], apertureType)` | Gain from beamwidth. **Input must be column vector `[az; el]`** — scalar assumes symmetric beam (dangerous for fan beams). Row vector `[az, el]` is WRONG (treats as two separate symmetric beams). `apertureType`: `'IdealRectangular'` (default), `'UniformRectangular'`, `'PracticalGeneral'`, etc. |
| `aperture2gain` | Phased Array | `aperture2gain(A, lambda)` | Gain (dB) from effective aperture area (m²) |
| `gain2aperture` | Phased Array | `gain2aperture(G_dB, lambda)` | Effective aperture (m²) from gain (dB) |
| `ap2beamwidth` | Phased Array | `ap2beamwidth(d, lambda)` or `ap2beamwidth(d, lambda, azb)` | Beamwidth from aperture length. Optional `azb` broadening factor (default 1.0) |
| `beamwidth2ap` | Phased Array | `beamwidth2ap(hpbw, lambda)` or `beamwidth2ap(hpbw, lambda, azb)` | Aperture length from beamwidth. Optional `azb` broadening factor |
| `effbeamwidth` | Phased Array | `effbeamwidth(θTx, θRx)` | Effective two-way beamwidth from Tx/Rx beamwidths |
| `detectability` | Radar | `detectability(Pd, Pfa, N, 'SwerlingN')` | Required SNR (detectability factor) for Pd/Pfa/N/Swerling. **Sw is a string:** `'Swerling0'`..`'Swerling4'` |
| `albersheim` | Phased Array | `albersheim(Pd, Pfa, N)` | Required SNR for Pd/Pfa/N (Swerling 0 only) |
| `shnidman` | Phased Array | `shnidman(Pd, Pfa, N, SwCase)` | Required SNR for Pd/Pfa/N/Swerling 0–4 |
| `rocinterp` | Radar | `rocinterp(rocData, ...)` | Interpolate ROC curves (Pd from SNR, SNR from Pd, etc.) |
| `systemp` | Phased Array | `systemp(NF_dB)` | System noise temperature from noise figure |
| `noisepow` | Phased Array | `noisepow(BW, Ts)` | Noise power from temperature + bandwidth |

## Radar Equation Tools — Units & Common Traps

**Positional argument order** (all three share a pattern):

```
radareqrng(lambda, SNR, Pt, tau, ...)   → range (meters)
radareqsnr(lambda, R, Pt, tau, ...)     → SNR (dB)
radareqpow(lambda, R, SNR, tau, ...)    → power (Watts)
```

**Unit table** — mixing dB and linear is the #1 agent failure mode:

| Parameter | Unit | Scale | Trap |
|-----------|------|-------|------|
| `lambda` | meters | linear | Pass wavelength, not frequency |
| `SNR` | dB | — | Output of `detectability`. Not linear ratio. |
| `Pt` | Watts | linear | Peak power. NOT dBW. NOT average power. |
| `tau` | seconds | linear | Actual transmitted pulse width. τ and BW are independent for modulated pulses (TBP > 1). |
| `Gain` | dBi | Name-Value | One-way antenna gain. Scalar = same Tx/Rx. [Gtx, Grx] for bistatic. |
| `Ts` | Kelvin | linear | System noise temperature. Use `systemp(NF_dB)` to convert from noise figure. Default 290 K. |
| `RCS` | m² | linear | NOT dBsm. Convert: `db2pow(rcs_dBsm)`. Negative values error. |
| `Loss` | dB | — | System losses (positive = more loss). Default 0. |
| `CustomFactor` | dB | — | Additive dB factor (positive = helps). Use for processing gain. |

**Key traps the agent hits:**

1. **Passing Gain in linear** — `Gain=1000` (linear for 30 dB) produces absurd ranges (10^49 km). Always pass dBi.
2. **Passing RCS in dBsm** — `RCS=-10` errors (negative not allowed). `RCS=10` meaning "10 dBsm" is actually 10 m² linear (correct by accident for positive dBsm, wrong intent).
3. **Swapping lambda and SNR** — both are scalars, no type check. Wrong order silently produces wrong range (no error, no Inf).
4. **Passing average power instead of peak** — underestimates range by `(duty)^(1/4)`. Always use peak power; compute from `Ppeak = Pavg / (tau * PRF)`.
5. **Forgetting tau** — tau is required. It determines pulse energy `E = Pt * tau`. If user provides bandwidth but not tau, ask for pulse width directly. Only assume `tau = 1/BW` if the user confirms an unmodulated pulse (TBP = 1). For chirp/LFM, τ and BW are independent.
6. **Processing gain not included** — `radareqrng` computes single-pulse range. For N-pulse integration, either reduce `SNR` input by processing gain, or add processing gain via `'CustomFactor', Gprocess_dB`.

**EIRP clarification:**

EIRP = Pt × Gt (linear) or EIRP_dBW = Pt_dBW + Gt_dBi. In the radar equation tools:
- `Pt` is **peak** transmit power in Watts (linear)
- `Gain` is one-way antenna gain in dBi

If user states "EIRP = X dBW" without specifying Pt and Gt separately, ask which they know. If only EIRP is available, one common decomposition: assume Gt from beamwidth (`beamwidth2gain`), then `Pt = db2pow(EIRP_dBW - Gt_dBi)`.

**Average vs peak power:** The radar equation uses **peak** power because `tau` (pulse width) already captures duty cycle via pulse energy. If user provides average power: `Ppeak = Pavg / (tau * PRF)`. If they provide duty cycle: `Ppeak = Pavg / duty`.

**Pulse compression and the energy form:** `radareqsnr` computes E/N0 (pulse energy over noise spectral density), which equals post-matched-filter SNR. BW does not appear because for a matched filter receiver it cancels: noise bandwidth BW × compression gain τ·BW = τ. This means:
- `tau` = actual transmitted pulse width regardless of waveform modulation
- The output is post-matched-filter SNR for both unmodulated and chirp/LFM pulses
- If the receiver is not a matched filter (suboptimal processing), add the lost compression gain as a `Loss`: `10*log10(tau*BW)` dB

## Detection Probability Functions

Three functions compute required single-pulse SNR for specified Pd/Pfa:

| Function | Toolbox | Swerling Cases | N (pulses) | Notes |
|----------|---------|----------------|------------|-------|
| `detectability` | Radar | 0–5 (strings) | Yes | **Preferred** — native Radar Toolbox |
| `shnidman` | Phased Array | 0–4 (integers) | Yes | Equivalent results, numeric Swerling input |
| `albersheim` | Phased Array | 0 only | Yes | Swerling 0 (non-fluctuating) only |

```matlab
% Preferred: detectability (Radar Toolbox)
D = detectability(0.9, 1e-6, 10, 'Swerling1');  % 13.5 dB required SNR

% Alternative: shnidman (Phased Array)
snr_req = shnidman(0.9, 1e-6, 10, 1);           % 13.6 dB (slight numeric difference)

% Limited: albersheim (Swerling 0 only)
snr_alb = albersheim(0.9, 1e-6, 10);            % 5.0 dB (non-fluctuating)
```

**Always use `detectability`.** It is the Radar Toolbox native function and covers all Swerling cases. The others are Phased Array equivalents you may encounter in existing user code:
- `shnidman` — same capability, numeric Swerling input (0–4 instead of strings)
- `albersheim` — Swerling 0 only subset; recognize in legacy code but prefer `detectability`

## Coherent vs Non-Coherent Integration

**Critical:** the `N` parameter in `detectability`/`shnidman`/`albersheim` assumes **non-coherent** integration. For coherent integration, do NOT pass N — compute differently.

| Integration Type | Required per-pulse SNR | Function Call |
|-----------------|----------------------|---------------|
| Single pulse | `detectability(Pd, Pfa, 1, Sw)` | Direct |
| Non-coherent (N pulses) | `detectability(Pd, Pfa, N, Sw)` | Pass N — function accounts for integration loss |
| Coherent (N pulses) | `detectability(Pd, Pfa, 1, Sw) - 10*log10(N)` | Do NOT pass N — subtract coherent gain manually |

```matlab
N = 10; Pd = 0.9; Pfa = 1e-6;

% Non-coherent: pass N to function
snr_noncoh = detectability(Pd, Pfa, N, 'Swerling1');  % 13.5 dB

% Coherent: single-pulse minus processing gain
snr_coh = detectability(Pd, Pfa, 1, 'Swerling1') - 10*log10(N);  % 11.1 dB

% Convert to reference range
R_noncoh = radareqrng(lambda, snr_noncoh, Pt, tau, 'Gain', G_dB, 'Ts', Ts);
R_coh = radareqrng(lambda, snr_coh, Pt, tau, 'Gain', G_dB, 'Ts', Ts);
% R_coh > R_noncoh (coherent is more efficient)
```

**Mapping to radarDataGenerator:** The sensor has no explicit integration property. Integration is embedded in `ReferenceRange` via the link budget derivation:

- User provides reference range directly → use as-is (integration already baked in)
- User provides hardware + "coherent N pulses" → derive ReferenceRange using coherent formula
- User provides hardware + "non-coherent N pulses" → derive ReferenceRange using non-coherent formula
- User specifies neither → **ASK** integration type and number of pulses

**Agent trap:** Passing N to `detectability` for a coherent system gives a pessimistic (too-short) reference range. The non-coherent integration loss penalty is applied when it shouldn't be.

## Detectability Decomposition (radarDesigner Pattern)

When deriving `ReferenceRange` from full hardware specs, decompose the detectability factor into its components. This is the pattern used by `radarDesigner` export:

```matlab
% Components of effective detectability
D01     = detectability(Pd, Pfa, 1, 'Swerling0');        % single-pulse, non-fluctuating
Lf      = detectability(Pd, Pfa, Nnoncoh, SW) - ...
          detectability(Pd, Pfa, Nnoncoh, 'Swerling0');  % fluctuation loss
Gci     = -pow2db(Ncoh);                                 % coherent integration gain (negative = gain)
Lcustom = systemLosses_dB;                               % implementation/system losses

% Total detectability (required SNR including all factors)
Dx = D01 + Lf + Gci + Lcustom;

% Processing gain (everything beyond single-pulse)
processingGain = -(Lf + Gci + Lcustom);
```

**Critical: radarDataGenerator handles fluctuation internally.** The `ReferenceRange` must be derived WITHOUT fluctuation loss — the sensor applies Swerling fluctuation at detection time:

```matlab
% Threshold for computing ReferenceRange (exclude fluctuation loss)
thresholdForRDG = Dx - Lf;   % = D01 + Gci + Lcustom

% Compute available SNR vs range (free-space, no propagation losses)
availSNR = radareqsnr(lambda, ranges, Pt, tau, 'Gain', G, 'RCS', refRCS, 'Ts', Ts);

% ReferenceRange is where available SNR meets the threshold
refRange = interp1(availSNR, ranges, thresholdForRDG, 'spline', 'extrap');
```

| Component | Meaning | Typical values |
|-----------|---------|----------------|
| `D01` | Baseline SNR for Pd/Pfa, single pulse, Swerling 0 | 12–14 dB |
| `Lf` | Fluctuation loss (Swerling penalty vs non-fluctuating) | 3–8 dB (Sw1), 0 dB (Sw0) |
| `Gci` | Coherent integration gain = `-10*log10(Ncoh)` | −10 to −20 dB |
| `Lcustom` | System/implementation losses | 3–10 dB |

## Validation Pattern (SNR vs Range)

After configuring `radarDataGenerator`, validate by comparing simulated detection SNR against analytical prediction:

```matlab
% 1. Compute expected SNR at each detection range
expectedSNR = radareqsnr(lambda, detRanges, Pt, tau, 'Gain', G, ...
    'RCS', targetRCS, 'Ts', Ts) + processingGain;

% 2. Compare to simulated SNR from detections
snrError = simSNR - expectedSNR;

% Swerling 0: error ≈ 0 (deterministic)
% Swerling 1: error scatters (fluctuation), mean ≈ 0
% Systematic offset → link budget error in ReferenceRange derivation
```

Use `radarmetricplot` for visual validation:

```matlab
radarmetricplot(ranges, availableSNR, detThreshold, ...
    'MetricName', 'SNR', 'MetricUnit', 'dB', ...
    'RangeUnit', 'km', 'ShowStoplight', true, ...
    'MaxRangeRequirement', reqRange, ...
    'RequirementName', 'Detectability');
hold on;
scatter(simRanges/1e3, simSNR, 'filled', 'DisplayName', 'Simulated');
plot(ranges/1e3, availableSNR + processingGain, 'DisplayName', 'Expected');
```

## Pd vs Range Prediction (FluctuationModel-Dependent)

Predicting Pd at arbitrary ranges requires knowing the target's Swerling type. **The default platform uses Swerling0** (non-fluctuating), NOT Swerling I. Using the wrong fluctuation formula produces dramatically wrong predictions (e.g., Pd=0.52 instead of Pd=0.89 at reference range).

**Step 1: Identify the target's fluctuation model:**

```matlab
sig = targetPlatform.Signatures{1};  % rcsSignature object
disp(sig.FluctuationModel)  % 'Swerling0', 'Swerling1', or 'Swerling3'
```

Default (no explicit rcsSignature): Swerling0, 10 dBsm constant.

**Step 2: Get the required SNR at reference range:**

```matlab
SNR_ref = detectability(Pd, Pfa, 1, SwCase);
% Swerling0: ~13.1 dB for Pd=0.9, Pfa=1e-6
% Swerling1: ~21.1 dB for Pd=0.9, Pfa=1e-6 (8 dB more!)
```

**Step 3: Compute SNR at each range:**

```matlab
SNR_at_R = SNR_ref + 40*log10(refRange ./ R);
```

**Step 4: Map SNR to Pd using the correct formula:**

```matlab
Pfa = 1e-6;
SNR_lin = 10.^(SNR_at_R / 10);

switch FluctuationModel
    case 'Swerling0'
        % Marcum Q-function (non-fluctuating target)
        threshold = sqrt(-2*log(Pfa));
        Pd_predicted = marcumq(sqrt(2*SNR_lin), threshold);
    case 'Swerling1'
        % Exponential (slow-fluctuating, chi-squared 2 DOF)
        Pd_predicted = Pfa.^(1./(1 + SNR_lin));
    case 'Swerling3'
        % Chi-squared 4 DOF — use rocsnr for numerical solution
        [Pd_roc, Pfa_roc] = rocsnr(SNR_at_R, ...
            'SignalType', 'Swerling3', 'NumPoints', 1001);
        % Interpolate at desired Pfa (numerical)
end
```

| FluctuationModel | Required SNR (Pd=0.9, Pfa=1e-6) | Pd at SNR=13 dB | Curve Shape |
|-----------------|----------------------------------|-----------------|-------------|
| Swerling0 | 13.1 dB | 0.89 | Steep (cliff-like) |
| Swerling1 | 21.1 dB | 0.53 | Gradual (exponential tail) |
| Swerling3 | 17.6 dB | 0.71 | Between Sw0 and Sw1 |

**Common mistake:** Applying the Swerling 1 formula (`Pfa^(1/(1+SNR))`) to a default platform that is actually Swerling 0. This underpredicts Pd by ~40% at reference range.

## Analytical Pd vs Range (Swerling0 default)

```matlab
% Step 1: Get required SNR at reference range for the configured Pd/Pfa
Pd_ref = 0.9; Pfa = 1e-6;
SNR_ref_dB = detectability(Pd_ref, Pfa, 1, 'Swerling0');

% Step 2: SNR at each range (40*log10 model)
refRange = 80e3;  % from radar config
SNR_at_R = SNR_ref_dB + 40*log10(refRange ./ targetRanges);

% Step 3: Map SNR to Pd using marcumq (Swerling0 = non-fluctuating)
SNR_lin = 10.^(SNR_at_R / 10);
threshold = sqrt(-2*log(Pfa));
Pd_analytical = marcumq(sqrt(2*SNR_lin), threshold);
```

**If targets use Swerling1** (check `platform.Signatures{1}.FluctuationModel`):
```matlab
Pd_analytical = Pfa.^(1./(1 + SNR_lin));
```

----

Copyright 2026 The MathWorks, Inc.

----
