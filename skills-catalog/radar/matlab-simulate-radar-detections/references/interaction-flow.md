# Interaction Flow

Full 9-step interactive workflow with suggested phrasings. The agent should adapt tone to context but preserve the structure and decision points.

## Step 1: Recommend Approach and Explain Fidelity Tradeoff

Suggested phrasing:

> "I'll start with a statistical-level simulation using `radarDataGenerator`. This gives you detections consistent with reasonable models of signal processing and atmospheric effects — fast enough that we can iterate together on the scenario design, review results, and fine-tune parameters before committing to a higher-fidelity I/Q simulation if needed. The tradeoff is less fine control over specific signal processing and beam laydown. Want to proceed, or do you need signal-level fidelity from the start?"

If user says no, explain the I/Q path:
- Full waveform simulation → pulse-Doppler processing → CFAR → detections
- Fine control over beam laydown, specific signal processing configuration, AoA estimation
- Higher complexity, slower runtime, shorter scenarios practical
- Required for: custom CFAR, adaptive beamforming, specific waveform effects

When confirmed, state: "We'll use `radarScenario` as the scenario container, `radarDataGenerator` for the sensor, `platform` for each entity, and `waypointTrajectory` (or `geoTrajectory` for earth-centered scenarios) for target motion."

## Step 2: Confirm Use Case

Suggest a concrete use case. Example:

> "I'll set up a ground-based surveillance radar mechanically scanning a sector, detecting airborne targets at various ranges and altitudes. Sound right, or are you working a different geometry?"

Key decisions to confirm:
- **Scan type:** "I'll start with mechanical scanning. Would you prefer electronic (AESA), both, or is mechanical right?"
- **Coordinate frame:** "I'll use NED (North-East-Down). In NED, elevation is negative above horizon. Want ENU or Earth-centered instead?" If earth-centered: set `IsEarthCentered = true` and use `geoTrajectory` (lat/lon/alt waypoints). Note that `DetectionCoordinates = 'Scenario'` will report ECEF meters.
- **Monostatic:** "Confirming this is monostatic (single radar, co-located Tx/Rx)."
- **Propagation environment:** "I'll start with free-space propagation (no refraction). If you're working long-range or low-elevation targets where earth curvature matters, I can add an atmosphere model — `'EffectiveEarth'` (4/3 radius) is the most common. This affects range calculations in Steps 4–5, so best to decide now." Weather/precipitation is NOT modeled at statistical level — only refraction. **Important constraint:** All atmosphere models require `IsEarthCentered = true`. If the user wants refraction but chose a flat-earth frame, flag immediately: "Atmosphere modeling requires an earth-centered scenario — I'll switch to `IsEarthCentered=true` with `geoTrajectory`."

## Step 3: Ask Direction for Parameter Sourcing

> "Which direction are you working?"
>
> - **Top-down:** "I need 80 km on 1 m² at Pd=0.9" → I'll derive what hardware is needed
> - **Bottom-up:** "Here are my hardware specs" → I'll derive what performance falls out
> - **Mixed:** Some requirements + some hardware → I'll close the loop and flag inconsistencies
> - **Datasheet:** "Here's my radar datasheet" → I'll extract parameters, map them, and fill gaps

### Datasheet Flow

Follow the procedure in [coupled-parameters.md](coupled-parameters.md) § "Datasheet Ingestion" (7 steps). When presenting results back to the user, say:

> "From your datasheet I got [X, Y, Z]. I still need [A, B] — here's what I'd suggest based on closing the link budget: [computed values]. Does that look right?"

## Step 4: Propose Key Parameters (Reference Performance)

Present concrete defaults as a **reference target** specification. For bottom-up or datasheet users, derive these from their hardware specs rather than proposing arbitrary values.

> "Here's a starting reference performance spec. React to any of these — I'll adjust:"
>
> | Parameter | Value | Notes |
> |-----------|-------|-------|
> | Reference range | 80 km | Detection range on reference target |
> | Reference RCS | 0 dBsm (1 m²) | Mid-size aircraft |
> | Detection probability | 0.9 | Single-scan |
> | False alarm rate | 1e-6 | Within valid range [1e-7, 1e-3] |
> | Integration | Coherent, N pulses | Assume coherent unless stated otherwise |
> | Configuration | Monostatic | Single radar |
> | Environment | Clear sky, free-space | No precipitation, no terrain |

The user can modify any value. Their modifications become "User-provided" tagged parameters.

### Integration Type (must ask for bottom-up / datasheet users)

When deriving `ReferenceRange` from hardware, the integration assumption is critical. Default to **coherent** and ask:

> "I'll assume coherent integration. How many pulses per dwell (or what's the CPI duration)? If you know the processing gain directly, I can use that instead."

| User says | Action |
|-----------|--------|
| "N pulses coherent" or CPI duration | Coherent gain = `10*log10(N)`. Use decomposition below. |
| "N pulses non-coherent" | Pass N to `detectability(Pd, Pfa, N, Sw)` for fluctuation + non-coh combined |
| "N coherent + M non-coherent" | Full decomposition: Gci from N, pass M to detectability |
| Processing gain in dB directly | `SNR_req = detectability(Pd, Pfa, 1, Sw) - processingGain_dB` |
| Reference range directly | Use as-is — integration already baked in |

**Full detectability decomposition** (matches radarDesigner export pattern):

```
D01     = detectability(Pd, Pfa, 1, 'Swerling0')       % baseline
Lf      = detectability(Pd, Pfa, Nnoncoh, Sw) -
          detectability(Pd, Pfa, Nnoncoh, 'Swerling0')  % fluctuation loss
Gci     = -10*log10(Ncoh)                               % coherent gain (negative)
Lcustom = system losses (dB)                            % implementation losses

thresholdForRDG = D01 + Gci + Lcustom                   % NO fluctuation loss
refRange = range where availableSNR = thresholdForRDG
```

**Critical:** `radarDataGenerator` applies Swerling fluctuation internally at detection time. The `ReferenceRange` must be computed WITHOUT fluctuation loss. Including it produces a pessimistic (too-short) reference range.

**Consistency checks:**
- If user provides CPI and PRF: verify `Ncoh = CPI * PRF`
- If user provides integration gain: verify `gain = 10*log10(Ncoh)` for coherent
- If total pulses and both types: verify `Ntotal = Ncoh * Nnoncoh`
- If user provides system losses: include as Lcustom in decomposition
- **PRF vs max range:** `Runamb = c/(2*PRF)` must exceed `ReferenceRange`. If not, flag to user: "Your PRF implies a max unambiguous range of X km, but your detection requirement is Y km. This means range ambiguities — is that intentional (PRF stagger), or should we reduce PRF?"
- **Tau vs blind zone:** `Rmin = c*tau/2`. If targets are specified below this range, they fall in the blind zone.
- **Peak vs average power:** If user provides power, ask: "Is that peak or average?" If average, compute peak: `Ppeak = Pavg / (tau * PRF)`. The radar equation requires peak power.

**Important:** Set `RangeLimits` to cover both the reference range and all targets. Default is [0, 100 km] — targets beyond 100 km silently produce no detections. After Step 6 target geometry is locked, set `'RangeLimits', [0, R]` where R = max(maxTargetRange, ReferenceRange * 1.2).

## Step 5: Present Coupled-Parameter Table

Show the table from [coupled-parameters.md](coupled-parameters.md). Frame it as:

> "Here's how the parameters relate. This helps us check consistency and identify what to derive:"

After presenting, mark which parameters are known (from user or datasheet) and which need derivation.

### FieldOfView Selection

Once beamwidth (AzimuthResolution) is established, ask the user to set `FieldOfView`. FoV is the angular coverage per scan position — it determines the scan step size and how many steps are needed per scan. FoV is not necessarily equal to the beamwidth (see [fov-and-scan.md](fov-and-scan.md) § "FieldOfView vs Resolution").

Suggested phrasing:

> "Now I need to set `FieldOfView` — this is the angular extent the radar covers at each scan position before stepping to the next. A few options:"
>
> - **Transmit beamwidth** (typical for scanning radars): FoV = [Tx azimuth beamwidth, Tx elevation beamwidth]. This models one transmit illumination per scan position. This is the pattern used by the `radarDesigner` export.
> - **Multiple simultaneous beams** (AESA with digital BF on receive): FoV = transmit beamwidth. The Tx beam is wider than the Rx beams — FoV captures the full illuminated extent, while `AzimuthResolution` reflects the narrower receive beamwidth that drives measurement accuracy.
> - **Wide open** (staring / validation): FoV = [180, 180]. Detects all targets in hemisphere regardless of bearing — useful for initial validation before adding scan.
> - **Specific value**: "If you know the angular coverage per scan position, I can set it directly."

If scan parameters are already known (sector width, revisit time, UpdateRate), compute and offer as a derived option:

> - **Derived from your revisit requirement**: To scan [sector] degrees in [revisit] seconds at [UpdateRate] Hz, you need FoV ≥ [sector / (revisit × UpdateRate)] = [X] degrees.

Default: if the user has no preference, set `FieldOfView` to the transmit beamwidth. For monostatic with a single shared aperture, this equals `[AzimuthResolution, ElevationResolution]`. Note this in the requirements sheet as a domain assumption.

## Step 6: Target Set Design

Confirm geometry:
- Radar on ground (or tower — ask height if relevant)
- Mechanically scanning the sector
- Airborne targets at various altitudes

### Coverage Check

Before finalizing the target set, verify that key targets (those intended to be detected) fall within the radar's coverage established in Step 5:
- **Azimuth:** target bearing within `MechanicalAzimuthLimits` or `ElectronicAzimuthLimits`
- **Elevation:** `atand(altitude / groundRange)` within `FieldOfView(2)` or elevation scan limits
- **Range:** target range within `RangeLimits`

Targets intentionally placed outside coverage (to demonstrate limitations or exercise edge cases) are fine — label them as "out-of-coverage" in the target table so their non-detection is expected, not a bug to debug.

**Debugging rule:** If a target is not detected and it's within the Step 5 coverage, debug normally. If it's outside coverage, that's expected — do NOT widen FoV or change Step 5 parameters to accommodate it. Step 5 reflects the system design; Step 6 targets exercise it.

Propose physically representative targets:

> "I'll set up a target mix that exercises the full dynamic range:"
>
> | Target | RCS | Speed | Altitude | Swerling | In Coverage? |
> |--------|-----|-------|----------|----------|--------------|
> | Small UAV | -20 dBsm (0.01 m²) | 50 m/s | 500 m | I | Yes |
> | Fighter | 0 dBsm (1 m²) | 250 m/s | 5 km | I | Yes |
> | Commercial | 10 dBsm (10 m²) | 200 m/s | 10 km | I | Yes |
> | Fast mover | 0 dBsm (1 m²) | 350 m/s | 3 km | III | Yes |

Explain Swerling model choice:
- **I:** Slow-fluctuating (constant over pulse train, independent scan-to-scan). Most targets.
- **III:** One dominant scatterer plus many small. Missiles, certain aircraft aspects.

Ask: "Do you need a terrain model or ground returns, or is free-space sufficient for now?"

## Step 7: Terrain / Occlusion

Only enter this step if user mentions tower height, terrain, ground effects, or line-of-sight concerns. Atmosphere model should already be established in Step 2.

Explain incrementally:
- **Terrain:** `landSurface` for height maps, `seaSurface` for sea state, `customSurface` for user-defined.
- **Occlusion:** `landSurface` `occlusion()` blocks radar-to-target LOS. `HasOcclusion` on radarDataGenerator is target-to-target.
- **Radar horizon:** `horizonrange(antennaHeight)` for quick LOS estimate.

> "I'd suggest validating detections in free-space first, then adding terrain/occlusion incrementally."

If user wants **ground clutter**, add after terrain:
- **Clutter:** `clutterGenerator(scene, radar, 'Resolution', 100, 'RangeLimit', R)` — requires a surface (land/sea/custom) already defined. One clutter generator per radar sensor. Default `UseBeam=true` generates clutter in current beam footprint. See [terrain-clutter-atmosphere.md](terrain-clutter-atmosphere.md) § "Clutter Generation" for full configuration.
- Warn: clutter detections appear mixed with target detections (same struct format, `ObjectClassID=0`). Distinguishing requires TargetIndex tracking or downstream processing.

## Step 8: Simulation Duration

Ask in the user's terms:

> "How long should the simulation run? I can work in any of these units:"
> - Seconds/minutes of scenario time
> - Number of complete sector scans
> - Number of target illuminations
> - Event-based (target exits sector, crosses range threshold)

Once scan parameters are locked, offer conversion:
> "At [scan rate] deg/s over [sector] degrees, one complete scan takes [X] seconds. [N] scans = [Y] seconds."

## Step 9: Produce Requirements Sheet

Generate the three-section artifact per [requirements-sheet-template.md](requirements-sheet-template.md).

Before writing the MATLAB script, present the requirements sheet for review:

> "Here's the full requirements sheet. Review it — once you approve, I'll generate the simulation script with design-rationale comments and validation checks."

The script must include:
- Design-rationale comment block (approach, tradeoffs, what's modeled)
- Coupled-parameter table as a comment block
- Parameter source tags (user-provided / domain assumption / derived)
- Validation comparing detections to analytical predictions
- **Explicit values for every `radarDataGenerator` property** — never rely on defaults. Even when using the default value, state it explicitly in the constructor call so the code is self-documenting and auditable.

----

Copyright 2026 The MathWorks, Inc.

----