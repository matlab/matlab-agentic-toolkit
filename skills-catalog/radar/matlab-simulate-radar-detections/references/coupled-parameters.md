# Coupled Parameters

Present this table to the user during Step 5 of the workflow. It shows which parameters are coupled, what the relationship is, and which Radar Toolbox API computes the conversion.

## Parameter-Relationship Table

| Group | Parameters (pick what you know) | Relationship | API / Function |
|-------|-------------------------------|--------------|----------------|
| Frequency | Center frequency ↔ wavelength | λ = c / f | `freq2wavelen` (Phased Array) |
| Antenna gain | Gain ↔ beamwidth (az, el) | Narrower beam → higher gain | `beamwidth2gain([azBW; elBW])` (Phased Array) — **must pass both dimensions as column vector** |
| Antenna gain | Gain ↔ effective aperture | Larger aperture → higher gain (freq-dependent) | `aperture2gain(A, lambda)` / `gain2aperture(G, lambda)` (Phased Array) |
| Antenna size | Aperture length ↔ beamwidth | Larger aperture → narrower beam (freq-dependent) | `ap2beamwidth(d, lambda)` / `beamwidth2ap(hpbw, lambda)` (Phased Array) |
| Angular resolution | Tx beamwidth + Rx beamwidth → effective | Two-way 3 dB width narrower than either alone | `effbeamwidth(θTx, θRx)` → `AzimuthResolution` / `ElevationResolution` (Phased Array) |
| Power | Peak power ↔ average power ↔ duty cycle | Pavg = Ppeak × duty | Manual: `Pavg = Pt * tau * PRF` |
| Timing | Pulse width ↔ PRF/PRI ↔ duty cycle | duty = τ × PRF | Manual: `duty = tau * PRF; PRI = 1/PRF` |
| Timing | Pulse width → minimum range (blind zone) | Rmin = c·τ/2 (uses actual pulse width, not 1/BW) | Manual: `Rmin = physconst('LightSpeed')*tau/2`. Suggest as `RangeLimits(1)` when τ is known. |
| Resolution | Bandwidth → range resolution | ΔR = c/(2·BW). BW is independent of τ for modulated pulses. | `rangeres2bw` / `bw2rangeres` (Phased Array) |
| Noise | Noise figure ↔ system temperature | Ts = T0·(NF−1) | `systemp(NF_dB)` (Phased Array) |
| Doppler | Speed ↔ Doppler shift | fd_twoway = 2v/λ (monostatic) | `speed2dop`/`dop2speed` use **one-way** convention (fd = v/λ). For monostatic: `fd_twoway = 2*speed2dop(v,lambda)` or `v = dop2speed(fd_twoway,lambda)/2`. Velocity resolution: `deltaV = lambda/(2*CPI)` — do NOT pass `1/CPI` to `dop2speed` directly. |
| Doppler | PRF → max unambiguous velocity | Vmax = λ·PRF/4 | Manual: `vMax = lambda*PRF/4` |
| Range ambiguity | PRF → max unambiguous range | Runamb = c/(2·PRF) | Manual: `rUnamb = physconst('LightSpeed')/(2*PRF)` |
| Integration | Ncoh + Nnoncoh + PRF → dwell time | Tdwell = Ncpi·(Ncoh·Nnoncoh)/PRF | Manual; maps to `radarDataGenerator.UpdateRate = 1/Tdwell` |
| Integration | Ncoh → coherent gain | Gcoh = 10·log10(Ncoh) dB | Manual: `-pow2db(Ncoh)` in detectability decomposition |
| Scan | Scan rate + sector + FoV → revisit time | Trevisit = 2·sector/scanRate (bidirectional) | Manual; `actualScanRate = min(FoV(1)*UpdateRate, MaxAzimuthScanRate)`. Note: FoV is the dwell extent (scan step), not the beamwidth. |
| Detection | Hardware → reference range via detectability | D01 + Gci + Lcustom (no Lf) | `detectability`, `radareqrng`, `radareqsnr` (Radar) |
| Horizon | Antenna height → radar horizon | Geometric + refraction | `horizonrange` (Radar) |

## How to Use This Table

1. Present it to the user after they've stated their known parameters (Step 5)
2. For each group, mark which parameter(s) the user knows
3. Derive the unknowns using the listed API or manual formula
4. Flag any inconsistencies:
   - duty cycle AND pulse width AND PRF must be self-consistent: `duty = tau * PRF`
   - **PRF vs max range:** `Runamb = c/(2*PRF)` must exceed `ReferenceRange`. If not, the radar has range ambiguities — surface this to the user as a design constraint, not silently proceed.
   - **Tau vs min range:** `Rmin = c*tau/2` is the blind zone. If user specifies targets below this, they can't be detected.
   - Peak power, average power, duty cycle: only 2 of 3 are independent
5. Tag each derived value with its source in the requirements sheet

## Bridging Hardware to radarDataGenerator

`radarDataGenerator` has no hardware knobs. The bridge is the **detectability decomposition** (matches the `radarDesigner` export pattern):

### Step-by-step

1. **Collect hardware specs:** Pt (peak, Watts), G (dBi), NF (dB), Losses (dB), τ (seconds), PRF (Hz), BW (Hz), fc (Hz), Ncoh, Nnoncoh, Swerling case. **τ is mandatory** — it determines pulse energy (E = Pt × τ) and is a required positional argument to `radareqrng`. If not stated: derive from duty cycle (`tau = duty/PRF`). Do NOT assume `tau = 1/BW` unless user confirms an unmodulated pulse (TBP = 1). When both τ and BW are stated and `tau*BW > 1`, flag the time-bandwidth product as pulse compression ratio.
2. **Compute detectability components:**
   ```matlab
   D01     = detectability(Pd, Pfa, 1, 'Swerling0');       % baseline single-pulse
   Lf      = detectability(Pd, Pfa, Nnoncoh, Sw) - ...
             detectability(Pd, Pfa, Nnoncoh, 'Swerling0'); % fluctuation loss
   Gci     = -pow2db(Ncoh);                                % coherent integration gain (negative dB)
   Lcustom = systemLosses_dB;                              % implementation/system losses
   ```
3. **Compute threshold for ReferenceRange (exclude fluctuation loss):**
   ```matlab
   thresholdSNR = D01 + Gci + Lcustom;  % NO Lf — RDG applies Swerling internally
   ```
4. **Compute max range via `radareqrng`:**
   ```matlab
   Rmax = radareqrng(lambda, thresholdSNR, Pt, tau, ...
       'Gain', G_dBi, 'Ts', Ts, 'Loss', Lcustom, 'RCS', rcs_linear);
   ```
5. **Configure radarDataGenerator:**
   - `ReferenceRange` = Rmax
   - `ReferenceRCS` = reference target in **dBsm**
   - `DetectionProbability` and `FalseAlarmRate` = same Pd/Pfa used in step 2
   - `RangeLimits` = `[0, max(maxTargetRange, Rmax*1.2)]`
6. **Verify:** `RadarLoopGain` (read-only) now encodes all hardware implicitly

### Processing Gain (User-Facing Definition)

When users say "processing gain," they mean the total SNR improvement beyond a single pulse. Map it to the decomposition:

```
processingGain_dB = -Gci - Lcustom = 10*log10(Ncoh) - systemLosses_dB
```

More precisely, processing gain is everything that improves SNR beyond the single-pulse baseline:
- **Coherent integration gain:** `10*log10(Ncoh)` dB (always positive)
- **Non-coherent integration gain:** handled inside `detectability(Pd, Pfa, N, Sw)` — reduces required per-pulse SNR
- **Minus system losses:** implementation losses reduce effective gain

In `radareqrng`, processing gain enters via the `'CustomFactor'` Name-Value pair (positive dB = helps) or by reducing the `SNR` argument. Both approaches are equivalent.

### Critical Rule

**`ReferenceRange` must be computed WITHOUT fluctuation loss.** The `radarDataGenerator` applies Swerling fluctuation internally at detection time. Including Lf in the threshold produces a pessimistic (too-short) reference range that double-counts fluctuation.

### Key Insight

The statistical API lumps all hardware into reference performance. The radar equation tools (`radareqrng`, `radareqpow`, `radareqsnr`) and the detection probability function (`detectability`) are the translation layer between hardware specs and the statistical interface.

## Ambiguity Properties and Limit Gating

`HasRangeAmbiguities` and `HasRangeRateAmbiguities` have **asymmetric pipelines**:

### Range: Gate Then Fold

```
True range → RangeLimits gates on TRUE range → HasRangeAmbiguities folds REPORTED range
```

| Step | What happens |
|------|-------------|
| 1. `RangeLimits` | Accepts/rejects based on true target range |
| 2. `MaxUnambiguousRange` | Folds the reported position: `mod(trueRange, MaxUnambiguousRange)` |

A target at 50 km with `RangeLimits=[0, 80e3]` and `MaxUnambiguousRange=30e3` passes the gate (50 < 80) and reports at 20 km (mod 30). The same target with `RangeLimits=[0, 29e3]` is rejected before folding ever applies.

### Range Rate: Fold Then Gate

```
True radial speed → HasRangeRateAmbiguities folds into [-MaxUnambiguousRadialSpeed, +Max] → RangeRateLimits gates on FOLDED speed
```

| Step | What happens |
|------|-------------|
| 1. `MaxUnambiguousRadialSpeed` | Wraps velocity into unambiguous interval (Doppler aliasing) |
| 2. `RangeRateLimits` | Accepts/rejects based on the folded value |

A target with true radial speed -120 m/s and `MaxUnambiguousRadialSpeed=50` folds to -20 m/s. `RangeRateLimits=[-25, 25]` accepts it; `[-10, 10]` rejects it.

### Physical Interpretation

- **Range:** The radar illuminates targets out to `RangeLimits` (physical detection envelope). Ambiguity arises because pulse repetition makes the *measurement* ambiguous — the radar detects the target but reports a folded range.
- **Range rate:** Doppler aliasing is inherent to the waveform — the radar never observes true speed, only the aliased value. Gating naturally applies to what the radar measures.

### Configuration Guidance

- `RangeLimits` must encompass all true target ranges you want detected, regardless of `MaxUnambiguousRange`. Setting `RangeLimits=[0, MaxUnambiguousRange]` defeats the purpose of range ambiguity modeling.
- `RangeRateLimits` operates on folded speed. To reject targets by true speed, filter detections post-hoc (not possible from measurement alone without resolving ambiguity).
- PRF-derived values: `MaxUnambiguousRange = c/(2*PRF)`, `MaxUnambiguousRadialSpeed = lambda*PRF/4`.
- Ghost targets at folded ranges are a real modeling effect — a target at 50 km reports at 20 km and is indistinguishable from a true 20 km target in the detection output.

## Datasheet Ingestion

When a user provides a radar datasheet:

1. Extract all stated parameters and map to the groups above
2. Identify which groups are fully constrained, partially constrained, or unconstrained
3. For partially constrained groups, compute the missing parameter using the API in the table
4. For unconstrained groups, propose reasonable defaults with justification
5. Flag any conflicts (e.g., stated range exceeds what the hardware can achieve)
6. Determine integration type:
   - If CPI or number of coherent pulses stated: coherent. `Gci = -pow2db(Ncoh)`
   - If "N pulses non-coherent" or "post-detection integration": pass N to `detectability`
   - If both: full decomposition (Gci from Ncoh, Nnoncoh passed to `detectability`)
7. Compute achievable range via the full bridge procedure above (detectability decomposition → `radareqrng`)
8. Compare to any stated range requirement — this is the self-consistency check
9. If stated range > computed range: the hardware cannot achieve the requirement. Quantify the gap and suggest which parameter to trade (power, gain, integration time, or relaxed Pd)

----

Copyright 2026 The MathWorks, Inc.

----