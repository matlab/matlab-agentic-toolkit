---
name: matlab-simulate-radar-detections
description: >
  Configure, simulate, debug, and analyze radarDataGenerator within radarScenario.
  Use for: interactively building radar detection scenarios from datasheets or
  performance requirements; diagnosing missed detections and configuration errors;
  interpreting sensor spherical, body, and scenario-frame outputs; deriving
  ReferenceRange from hardware specs via link budget; scan mode configuration
  (mechanical, electronic/AESA, hybrid); and validating simulation results against
  analytical predictions.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Radar Data Generator — Statistical Detection Simulation

Build detection-level radar simulations using `radarDataGenerator` within `radarScenario`. This skill bridges user hardware specs and performance requirements to the Radar Toolbox statistical simulation API.

## When to Use

- User wants to simulate radar detections on moving targets
- User has radar hardware specs (datasheet) or performance requirements and wants to build a simulation
- User mentions surveillance radar, scanning, revisit time, detection probability, or radar coverage
- User wants to compare scan strategies (mechanical vs electronic vs hybrid)
- User wants to generate detections to feed a tracker (trackerGNN, trackerJPDA) or do sensor fusion
- User wants Monte Carlo analysis, trade studies, or validation against link budget predictions
- User is studying radar placement or geometry to maximize coverage
- User has existing `radarDataGenerator` code that isn't working — missed detections, configuration errors
- User wants to validate simulation results against expected performance

## When NOT to Use

- User needs I/Q-level waveform simulation (use `radarTransceiver` + pulse-Doppler chain)
- User needs CFAR detector design or beamforming
- User needs waveform design (ambiguity functions, chirp optimization)
- User already has detections and wants to process them
- User needs bistatic or multistatic radar configurations
- User needs interference or jamming modeling (EW scenarios)
- User wants to call `radarDataGenerator` standalone (without `radarScenario`) in a custom simulation loop

If the user needs signal-level fidelity, explain the tradeoff and hand off.

## Detection Pathways

`radarDataGenerator` supports two detection pathways. This skill uses the **target-pose pathway** exclusively:

| Pathway | Call Signature | Detection Governed By | When Used |
|---------|---------------|----------------------|-----------|
| **Target-pose** (this skill) | `detect(scenario)` | `DetectionProbability`, `FalseAlarmRate`, `ReferenceRange`, `ReferenceRCS` | Standard radar simulation — targets defined as platforms with trajectories |
| **Emissions** | `detect(scenario, propagatedEmissions)` | `Sensitivity`, `DetectionThreshold` | ESM receivers, bistatic with explicit emission propagation |

Properties from one pathway have **zero effect** on the other. Setting `Sensitivity` or `DetectionThreshold` in the target-pose pathway produces a "not relevant" warning.

**Standalone mode:** `radarDataGenerator` can also be called outside a scenario: `[dets, numDets, config] = rdg(targetPoses, simTime)`. Use for integration into custom loops (Simulink, event-driven). Loses `advance()`, trajectory automation, multi-sensor aggregation, and coverage visualization. See [references/detection-model.md](references/detection-model.md) for the full standalone API and pose struct requirements.

## Workflow

Follow these 9 steps interactively. Do NOT silently choose parameters — engage the user at each decision point.

### Step 1: Recommend Approach

Recommend statistical-level simulation using `radarDataGenerator` within `radarScenario`. Explain the tradeoff: fast iteration on scenario design vs less control over signal processing. If user needs I/Q-level fidelity, name the alternative path (`radarTransceiver` + pulse-Doppler + CFAR) and stop the structured 9-step flow.

When they confirm statistical-level, state the approach and name the APIs: `radarScenario`, `radarDataGenerator`, `platform`, `waypointTrajectory`/`kinematicTrajectory`/`geoTrajectory`.

### Step 2: Confirm Use Case

Suggest a use case (e.g., ground-based surveillance scanning a sector). Confirm:
- **Scan type:** Propose mechanical, offer electronic or both
- **Coordinate frame:** NED (default), ENU, or Earth-centered. State implications.
- **Configuration:** Confirm monostatic
- **Propagation environment:** Default is FreeSpace (no refraction). If user mentions long range, low-elevation targets, or over-the-horizon, offer atmosphere models: `atmosphere(scenario, model)` — `'EffectiveEarth'` (4/3 radius), `'RefractivityGradient'`, or `'CRPL'`. These add refraction bias to propagation paths (ray bending), affecting reported target positions — they do NOT add atmospheric attenuation to the link budget. Weather/precipitation is NOT modeled at statistical level.

### Step 3: Ask Parameter Sourcing Direction

> "Which direction are you working? Top-down (specify requirements, derive hardware)? Bottom-up (specify hardware, derive performance)? Or a mix?"

If user provides a **datasheet**: follow the datasheet ingestion procedure in [references/coupled-parameters.md](references/coupled-parameters.md) — extract parameters, map to groups, identify gaps, close link budgets, flag conflicts.

**The flow branches here:**

**Top-down path** (Steps 4 → 5): User specifies performance requirements first, then derive hardware.
- Step 4: Propose reference performance (range, RCS, Pd, Pfa)
- Step 5: Present coupled-parameter table, derive hardware needed to meet requirements

**Bottom-up path** (Steps 5 → 4): User specifies hardware first, then derive performance.
- Step 5: Present coupled-parameter table, collect hardware specs (power, gain, NF, bandwidth, etc.)
- Step 4: Derive and present reference performance from hardware via `radareqrng`

**Mixed/Datasheet**: Collect what they have, fill gaps from both directions, flag inconsistencies.

Both paths converge at Step 6 (Target Set Design).

### Step 4: Propose Reference Performance

Present as a reference target specification:
- Reference range, reference RCS (note: `ReferenceRCS` is in **dBsm**)
- Detection probability, false alarm rate (valid: [1e-7, 1e-3])
- Integration type and number of pulses (assume coherent; ask for N or CPI)
- Monostatic, clear sky

**Top-down:** Present concrete defaults. Let user react/modify.
**Bottom-up:** Present values *derived from their hardware*. Show the derivation (which function, which inputs). For integration: assume coherent, ask number of pulses or CPI duration. Use `detectability(Pd, Pfa, 1, 'SwerlingN') - 10*log10(N)` for required SNR. The Swerling argument is a **string**: `'Swerling0'`, `'Swerling1'`, ..., `'Swerling4'`. Never pass N to `detectability` for coherent systems — that applies non-coherent loss. See [references/interaction-flow.md](references/interaction-flow.md) § Step 4 for the full decision table.

### Step 5: Present Coupled-Parameter Table

Show the parameter-relationship table from [references/coupled-parameters.md](references/coupled-parameters.md). This builds confidence, shows traceability, invites correction.

**Top-down:** Use the table to derive what hardware is needed to meet the agreed reference performance.
**Bottom-up:** Use the table to collect the user's hardware specs and identify which groups are constrained.

### Step 6: Target Set Design

Confirm geometry (radar placement, scan sector, airborne targets). Propose physically representative targets varying:
- RCS (UAV ~0.01 m², fighter ~1 m², commercial ~10 m²)
- Speed (50 m/s rotary, 250 m/s jet, 300+ m/s fast mover)
- Altitude (500 m nap, 5 km mid, 10 km high)

Offer Swerling models (I = slow-fluctuating, III = dominant scatterer). Configure per-target RCS via `rcsSignature` on each platform's `Signatures` property — see [references/detection-model.md](references/detection-model.md) for patterns. Default platform RCS is 10 dBsm (Swerling0).

**Sanity checks before proceeding:**

1. Verify target geometry is within radar horizon using `horizonrange(antennaHeight)`. If any target is beyond LOS at its specified altitude, flag this to the user.

2. Compute the expected 0.9 Pd reference range for each target. Report a table like:

| Target | RCS (dBsm) | Swerling | Range (km) | Expected Pd |
|--------|-----------|----------|-----------|-------------|
| UAV | -20 | 1 | 15 | 0.72 |
| Fighter | 0 | 1 | 40 | 0.95 |

Use: `SNR_at_R = RadarLoopGain + RCS_dBsm - 40*log10(range)`, then map SNR to Pd with the correct Swerling formula (see [references/radar-equation-tools.md](references/radar-equation-tools.md#pd-vs-range-prediction-fluctuationmodel-dependent)). Flag any target where expected Pd < 0.5 — the user should know which targets will have unreliable detection before running the sim.

Ask: "Do you need terrain or ground returns, or is free-space sufficient?"

### Step 7: Terrain / Occlusion

If applicable — see [references/terrain-clutter-atmosphere.md](references/terrain-clutter-atmosphere.md) for terrain options. Terrain and occlusion are additive after validating detections in free-space. `landSurface` for height maps, `seaSurface` for sea state, `customSurface` for user-defined. `landSurface` has `occlusion()` for LOS blocking. `HasOcclusion` on `radarDataGenerator` is target-to-target occlusion.

### Step 8: Simulation Duration

Ask in user's terms: seconds, number of scans, number of target illuminations, or event-based. Convert between these once scan parameters are locked.

### Step 9: Produce Requirements Sheet

Generate a standalone document with three sections — see [references/requirements-sheet-template.md](references/requirements-sheet-template.md).

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `radarScenario` | Scenario container (platforms, time, detect) | Radar |
| `radarDataGenerator` | Statistical detection sensor | Radar |
| `platform` | Add platform to scenario | Radar |
| `waypointTrajectory` | Waypoint-based motion in local coords (has `ReferenceFrame`) | Radar |
| `kinematicTrajectory` | State-based motion in local coords (NO `ReferenceFrame`) | Radar |
| `geoTrajectory` | Waypoint-based motion in geodetic coords (lat/lon/alt) — requires `IsEarthCentered = true` | Radar |
| `radareqrng` | Max detection range from radar equation | Radar |
| `radareqpow` | Required Tx power | Radar |
| `radareqsnr` | Received SNR at range | Radar |
| `detectability` | Required SNR (detectability factor) for Pd/Pfa/N/Swerling | Radar |
| `albersheim` | Required SNR for Pd/Pfa/N (Swerling 0 only) | Phased Array |
| `shnidman` | Required SNR for Pd/Pfa/N/Swerling 0–4 | Phased Array |
| `horizonrange` | Radar horizon from antenna height | Radar |
| `height2el` | Elevation angle from target height/range | Radar |
| `freq2wavelen` | Wavelength from frequency | Phased Array |
| `rangeres2bw` | Bandwidth from range resolution | Phased Array |
| `bw2rangeres` | Range resolution from bandwidth | Phased Array |
| `speed2dop` | Doppler shift from speed. **One-way convention** — for monostatic two-way: `fd = 2*speed2dop(v, lambda)` | Phased Array |
| `dop2speed` | Speed from Doppler shift. **One-way convention** — for monostatic two-way: `v = dop2speed(fd, lambda)/2` or use `lambda*fd/2` directly | Phased Array |
| `beamwidth2gain` | Antenna gain from half-power beamwidth. **Must pass [azBW; elBW] column vector** — scalar assumes symmetric beam. | Phased Array |
| `aperture2gain` | Antenna gain from effective aperture | Phased Array |
| `gain2aperture` | Effective aperture from antenna gain | Phased Array |
| `ap2beamwidth` | Beamwidth from aperture length and wavelength | Phased Array |
| `beamwidth2ap` | Aperture length from beamwidth and wavelength | Phased Array |
| `effbeamwidth` | Two-way effective beamwidth (Tx+Rx) → maps to `AzimuthResolution`/`ElevationResolution` | Phased Array |
| `systemp` | System noise temperature | Phased Array |
| `noisepow` | Noise power from temperature + bandwidth | Phased Array |
| `theaterplot` | Scenario visualization | Radar |
| `coverageConfig` | Coverage diagram | Radar |
| `radarmetricplot` | Plot metric vs range with objective/threshold lines and stoplight | Radar |
| `orientationPlotter` | Visualize beam pointing direction (theaterPlot plotter) | Radar |
| `detectionPlotter` | Visualize detections on theater plot | Radar |
| `landSurface` | Static terrain (height matrix or DTED) — occlusion only with `IsEarthCentered=true` | Radar |
| `seaSurface` | Dynamic ocean surface (spectral model, wind, fetch) | Radar |
| `customSurface` | Polarization scattering matrix surface for clutter | Radar |
| `surfaceReflectivityLand` | Land clutter reflectivity model (Barton, GIT, etc.) | Radar |
| `surfaceReflectivitySea` | Sea clutter reflectivity model | Radar |
| `clutterGenerator` | Add clutter to scenario (1:1 with radar sensor, requires a surface) | Radar |
| `ringClutterRegion` | Define explicit clutter region (required when `UseBeam=false`) | Radar |
| `getClutterGenerator` | Retrieve existing clutter generator for a radar | Radar |

## Conventions

### Traceability

- Every stochastic quantity traces to a configured parameter
- `radarDataGenerator` provides built-in traceability — property names ARE the documentation
- If hand-rolling any computation, comment the model, its parameters, and how it connects to system design

### Coordinate Frames

- Pick ONE frame and use it consistently throughout
- `waypointTrajectory` has `'ReferenceFrame'` property: `'NED'` or `'ENU'` — use with `IsEarthCentered = false`
- `kinematicTrajectory` has NO `ReferenceFrame` — inherits from scenario — use with `IsEarthCentered = false`
- `geoTrajectory` uses geodetic waypoints [lat, lon, alt] in [deg, deg, m] — **requires** `IsEarthCentered = true`
  - Has `'ReferenceFrame'` (`'NED'`/`'ENU'`) for velocity/orientation interpretation
  - Also supports `Course`, `GroundSpeed`, `ClimbRate` as alternatives to `Velocities`
  - `DetectionCoordinates = 'Scenario'` reports in ECEF (meters), not lat/lon
  - Single waypoint = stationary platform (TimeOfArrival is ignored)
- **Constraint:** trajectory type and `IsEarthCentered` are strictly coupled — mixing produces an error
- NED: elevation is **negative** above horizon. ENU: elevation is **positive** above.
- Always validate: compute expected elevation analytically, compare to measured

### Parameter Source Tags

Every parameter in the requirements sheet gets a tag:
- **User-provided** — they told us
- **Domain assumption** — reasonable default, justified
- **Derived** — computed from other params (show which function)

### System Parameters vs Simulation Parameters

Once the user's requirements and use case are confirmed (Steps 2–6), distinguish between:
- **System parameters** (user's design): FieldOfView, CenterFrequency, Bandwidth, MaxAzimuthScanRate, ReferenceRange, antenna height, etc. Never change these to fix a simulation issue.
- **Simulation parameters** (our configuration): UpdateRate, RangeLimits, scenario UpdateRate, DetectionCoordinates, simulation duration. These can be tuned freely.

If a simulation artifact occurs (e.g., missed detections due to beam stepping), fix it by adjusting simulation parameters. If the fix requires changing a system parameter, surface it to the user with physical intuition — it's a design insight, not a sim fix.

### Self-Consistency

After deriving all parameters, validate the loop closes:
- Compute Rmax from hardware via `radareqrng`
- Configure `ReferenceRange` = Rmax
- Run simulation, confirm ~Pd at reference range
- If mismatch, diagnose and flag

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Changing non-tunable properties without `release()` | `radarDataGenerator` is a System object — non-tunable properties (`FieldOfView`, `ScanMode`, `AzimuthResolution`, scan limits) are locked after first call to `detect()` | Call `release(radar)` before modifying non-tunable properties, then `restart(scenario)` before re-running |
| `ReferenceRCS` in linear m² | Property expects **dBsm** | Convert: `10*log10(rcs_linear)` |
| `range2bw` / `bw2range` | Deprecated | Use `rangeres2bw` / `bw2rangeres` |
| `MechanicalScanLimits` | Does not exist | Use `MechanicalAzimuthLimits`, `MechanicalElevationLimits` |
| Setting `MaxAzimuthScanRate` for electronic scan | Ignored (warning issued) | Beam steps by `FieldOfView(1)` per update in electronic mode |
| Confusing `detect(scenario)` with `detect(platform, time)` | Different signatures — scenario-level returns all sensors' detections combined | `dets = detect(scenario)` or `[dets, configs] = detect(scenario)` — both valid. Per-platform: `[dets, ~, configs] = detect(platform, time)` |
| Forgetting elevation sign in NED | Targets above horizon have negative elevation | Check sign: `el = -asind(alt/range)` in NED |
| `HasScanLoss` with non-Custom scan | Only applies when `ScanMode='Custom'` | Omit for Mechanical/Electronic modes |
| Mixing trajectory reference frames | Causes silent position errors | Set all `waypointTrajectory` objects to same `'ReferenceFrame'` |
| `waypointTrajectory` shorter than `StopTime` | Scenario stops at max trajectory endpoint, NOT at `StopTime`. Platform goes to NaN position after trajectory ends — silently stops being detected. | Extend all `waypointTrajectory` endpoints to >= `StopTime` (add hold waypoint). Or use `kinematicTrajectory` for constant-velocity platforms. |
| Confusing `radar/waypointTrajectory` with `drivingScenario` trajectories | Different API — `drivingScenario` uses actor waypoints, not this class | In `radarScenario`, always use `waypointTrajectory`, `kinematicTrajectory`, or `geoTrajectory` |
| Using `kinematicTrajectory` for a moving platform with a forward-looking sensor | Body frame orientation is FIXED (default: identity = scenario axes). Does NOT rotate with velocity — a forward-looking sensor will not track the flight path. | Use `waypointTrajectory` or `geoTrajectory` for moving platforms with sensors. Their body frame rotates with heading. |
| Hardcoded noise (e.g., `0.2*randn`) | Not traceable, breaks self-consistency | Use `radarDataGenerator` built-in noise model or comment the source |
| Not setting sensor `UpdateRate` | Default is 1 Hz — scan rate = `FoV(1)*1` = crawl | Always set `'UpdateRate'` explicitly on `radarDataGenerator` |
| Scenario `UpdateRate` < sensor `UpdateRate` | Aliasing: only a fraction of FoV dwell positions are sampled. Targets between sampled positions get **zero detections silently**. | Set scenario `UpdateRate` = sensor `UpdateRate` for detection-complete sims. |
| Comparing sensor rectangular measurements directly to scenario-frame truth | Sensor rectangular is a **beam-rotating frame** — each detection's coordinate system depends on where the beam was pointing at detection time. Raw measurements will differ from truth by tens of km. | Use per-detection `MeasurementParameters(1)`: `scenarioPos = Orientation * Measurement + OriginPosition`. The Orientation matrix encodes mounting + current scan angle. |
| Assuming spherical measurement order is [range, az, el] | Actual order is **[az, el, range]** for `'Sensor spherical'` | Check `DetectionCoordinates` setting; default is `'Body'` (Cartesian) |
| Not setting `RangeLimits` | Default is [0, 100 km] — targets beyond 100 km silently produce no detections | Set `'RangeLimits', [0, R]` where R = max(maxTargetRange, ReferenceRange * 1.2) |
| Using `'Sector'` with `MechanicalElevationLimits` | 'Sector' sets `HasElevation=false` — elevation limits are ignored (warning issued) | Use explicit `'ScanMode','Mechanical'` with `HasElevation=true` if elevation scanning is needed |
| Setting or investigating `HasElevation` for detection issues | `HasElevation` does NOT affect whether targets are detected. It only controls whether elevation angle is measured and whether the beam scans in elevation. Default is `false` (azimuth-only). | Never set `HasElevation=false` (it's already the default). Never investigate `HasElevation` when debugging missing detections — it cannot cause them. Missing detections are caused by: `RangeLimits`, target outside scan sector, insufficient `ReferenceRange`/`ReferenceRCS`, or `UpdateRate` too low. |
| Calling `atmosphere(scene, model)` with `IsEarthCentered=false` | Errors: "The IsEarthCentered property must be true to modify the atmosphere model" | All atmosphere/refraction models require `IsEarthCentered=true`. Flat-earth scenarios are always free-space. |
| Expecting terrain to block targets with `IsEarthCentered=false` | Terrain occlusion in `detect()` only works with `IsEarthCentered=true` | If terrain masking matters, use earth-centered scenario with `geoTrajectory` |
| Confusing `HasOcclusion` with terrain occlusion | `HasOcclusion` is target-to-target (extended objects); terrain LOS is via `SurfaceManager` | For terrain masking: `IsEarthCentered=true` + `landSurface`. For target-to-target: `HasOcclusion=true` |
| `clutterGenerator` without any surface | Produces 0 clutter detections silently | Add `landSurface(scene)` or `seaSurface(scene)` before creating clutter generator |
| `ScattererDistribution='RangeDopplerCells'` with `radarDataGenerator` | Error at `detect()` | Only works with `radarTransceiver`; use `'Uniform'` (default) for radarDataGenerator |
| `UseBeam=false` without `ringClutterRegion` | 0 clutter detections | Add explicit regions: `ringClutterRegion(cg, minR, maxR, azSpan, azCenter)` |
| Setting `Sensitivity` or `DetectionThreshold` in target-pose mode | "Not relevant" — these are emissions-pathway only | In the target-pose pathway (`detect(scenario)`), detection is governed solely by `Pd`/`Pfa`/`ReferenceRange`/`ReferenceRCS` |
| Increasing `FalseAlarmRate` to simulate surface clutter | `FalseAlarmRate` produces uniformly distributed false detections (white noise); it does not model spatially correlated surface clutter with realistic sigma-zero, geometry, or Doppler | Use `clutterGenerator` with a surface (`landSurface`/`seaSurface`) and reflectivity model. See [terrain-clutter-atmosphere.md](references/terrain-clutter-atmosphere.md). |
| Expecting `radarDataGenerator` to model signal processing losses (MTI, STAP, CFAR) | The statistical model does not simulate clutter-rejection filter losses, STAP adaptive weight losses, or detectability degradation near the clutter ridge in range-Doppler space | These effects require I/Q-level simulation (Phased Array System Toolbox waveform + receiver chain). For statistical-level approximation, add expected processing losses via the `Loss` parameter in the link budget (`radareqsnr`), or reduce `DetectionProbability` in clutter-affected regions. |
| `dop2speed(1/CPI, lambda)` for monostatic velocity resolution | Gives 2× correct value (3.0 m/s instead of 1.5 m/s) | `dop2speed` uses one-way convention. Monostatic velocity resolution = `lambda/(2*CPI)`. Either use manual formula or `dop2speed(fd,lambda)/2`. |
| `radareqrng(SNR, lambda, ...)` — wrong arg order | Silent wrong answer (no error) | Correct: `radareqrng(lambda, SNR, Pt, tau, ...)` — lambda first |
| Passing `Gain` in linear to `radareqrng` | Absurd range (10^49 km) | `Gain` is **dBi**, not linear. Pass `30`, not `1000`. |
| Passing `RCS` in dBsm to `radareqrng` | Wrong by 3× or errors on negative | `RCS` is **linear m²**. Convert: `db2pow(rcs_dBsm)` |
| Passing average power to `radareqrng` as Pt | Underestimates range | Pt is **peak** power (Watts). Derive: `Ppeak = Pavg / (tau * PRF)` |
| Using `FieldOfView` for antenna gain derivation | Wrong gain when FoV ≠ beamwidth | Gain comes from `beamwidth2gain([AzimuthResolution; ElevationResolution])`. Both beamwidths required — scalar input assumes symmetric beam (up to 10 dB error for fan beams). FoV is the angular coverage per scan position; it is not necessarily equal to the receive beamwidth. |
| Assuming `FieldOfView` must equal `AzimuthResolution` | Incorrect scan step for AESA or wide-Tx configurations | FoV and resolution are independent. FoV = Tx beamwidth (typical). For shared aperture, FoV = AzRes. For wide Tx + narrow Rx, FoV > AzRes. |
| Applying Swerling I Pd formula to a default (Swerling0) target | Underpredicts Pd by ~40% at reference range (0.52 vs 0.89) | Check `target.Signatures{1}.FluctuationModel`. Default is Swerling0 — use `marcumq`. For Swerling1 targets: `Pfa^(1/(1+SNR_lin))`. |

## Scan Mode Quick Reference

| Mode | Key Behavior |
|------|-------------|
| `'Mechanical'` | `actualRate = min(FieldOfView(1) * sensorUpdateRate, MaxAzimuthScanRate)`. See scan rate model below. |
| `'Electronic'` | Beam steps by `FieldOfView(1)` per update. `MaxAzimuthScanRate` irrelevant. |
| `'Mechanical and electronic'` | Mechanical provides coarse pointing, electronic refines. |
| `'No scanning'` | Fixed staring beam. |

Convenience constructors: `radarDataGenerator(id, 'Raster')`, `'Rotator'`, `'Sector'`, `'Custom'`.

### Mechanical Scan Rate Model (Critical)

The actual scan rate for mechanical mode is:

```
actualScanRate = min(FieldOfView(1) * sensorUpdateRate, MaxAzimuthScanRate)  [deg/s]
stepPerScenarioUpdate = actualScanRate / scenarioUpdateRate  [deg]
```

**Default sensor `UpdateRate` is 1 Hz.** If not set explicitly, a 2-deg beam scans at only 2 deg/s regardless of `MaxAzimuthScanRate`. Always set sensor `UpdateRate` explicitly:

```matlab
radar = radarDataGenerator(1, 'Sector', ...
    'UpdateRate', 20, ...  % MUST set — default 1 Hz causes very slow scan
    'FieldOfView', [2; 20], ...
    'MaxAzimuthScanRate', 36, ...
    ...);
% actualRate = min(2*20, 36) = 36 deg/s ✓
```

To achieve a desired scan rate with a narrow beam:
- `sensorUpdateRate >= desiredRate / FieldOfView(1)`
- Example: 36 deg/s with 2-deg beam needs `UpdateRate >= 18` Hz

### Scenario vs Sensor UpdateRate

The sensor fires at its own `UpdateRate`; the scenario `UpdateRate` controls how often `advance()`/`detect()` execute. If scenario rate < sensor rate, only a fraction of dwell positions are sampled — targets between sampled positions produce **zero detections silently**.

**Rule:** Always set scenario `UpdateRate` = sensor `UpdateRate` unless you specifically want sparse detection cadence.

## Detection Model

```
SNR = RadarLoopGain + RCS_dBsm - 40*log10(Range)
```

- `RadarLoopGain`: read-only, derived from `ReferenceRange` + `ReferenceRCS` + `DetectionProbability` + `FalseAlarmRate`. The reference SNR uses Swerling0 (non-fluctuating) internally — target fluctuation models are applied separately at detection time.
- No hardware knobs (Pt, Gain, NF) — all lumped into reference performance
- `CenterFrequency`/`Bandwidth` affect resolution only, not detection range
- Measurement accuracy: `σ² = (Δ/√(2·SNR))² + (BiasFraction·Δ)²` — Cramér-Rao plus bias floor. Defaults: `AzimuthBiasFraction=0.1`, `RangeBiasFraction=0.05`, `ElevationBiasFraction=0.1`. At high SNR the bias floor dominates (0.3° azimuth, 3.75m range).
- **Pd vs range depends on target FluctuationModel** — default platforms are Swerling0 (non-fluctuating). Use `marcumq` for Swerling0, `Pfa^(1/(1+SNR))` for Swerling1. Using the wrong formula gives ~40% Pd error. See [references/radar-equation-tools.md](references/radar-equation-tools.md) for the full recipe.

The agent's job is to **bridge** between user hardware specs and this statistical interface using radar equation tools as the translation layer.

## Troubleshooting

| Symptom | Likely Cause | Diagnostic / Fix |
|---------|-------------|-----------------|
| No detections at all | `RangeLimits` too short | Check `radar.RangeLimits(2)` >= max target range |
| No detections at all | Sensor `UpdateRate` = 1 Hz (default) | Beam scanning too slowly — set `UpdateRate` explicitly |
| No detections at all (UpdateRate is set) | Scenario `UpdateRate` < sensor `UpdateRate` | FoV dwell aliasing — only sampled positions produce detections. Set scenario `UpdateRate` = sensor `UpdateRate`. |
| No detections at all | Target outside beam FoV | Use `coverageConfig(radar)` to get current beam direction; compare to target bearing |
| Detections only on some scans | Target near beam step boundary | Normal for mechanical scan — fast targets at bearings aligned with beam step positions may be missed on some sweeps. Increase sensor/scenario `UpdateRate` to reduce step size (never change system parameters like `FieldOfView` to fix a simulation artifact). |
| Too many detections | Self-detection (radar platform) | Filter: ignore detections where `TargetIndex == radar platform ID` (usually 1) |
| Pd much lower than configured | Target beyond `ReferenceRange` | SNR drops as 40·log10(R) — expected; Pd is specified AT reference range only |
| Pd higher than expected | Target RCS > `ReferenceRCS` | Higher RCS increases SNR — check `rcsSignature` on target platform |
| Empirical Pd > 1.0 | Dividing detections by scans, not illuminations | Mechanical scan is bidirectional: illuminations = 2 × scans for sector scan. Count beam passes from `IsScanDone` or compute from scan timing: `nIlluminations = StopTime / (sector / scanRate)`. |
| Measured position far from truth | Plotting raw `.Measurement` against scenario-frame truth | **Must convert to scenario frame first.** Use `MeasurementParameters.Orientation` and `.OriginPosition` to transform. "0 azimuth" = sensor boresight, not north. See API Answer Key for conversion recipes. |
| Range-limited vs LOS-limited | Targets beyond radar horizon | Use `horizonrange(antennaHeight)` to check. Comment in code where missed detections are expected due to LOS. This should also be caught as a sanity check before writing code (Step 6 — verify target geometry is within radar horizon). |
| Self-consistency check fails | Hardware-derived Rmax ≠ configured ReferenceRange | Recheck `radareqrng` inputs match the hardware specs fed to the derivation |

### Programmatic Verification

**Detection accuracy check** — verify measurement errors are within expected bounds. **This must account for DetectionCoordinates mode** — raw `.Measurement` values cannot be compared to scenario-frame truth unless using `'Scenario'` mode:

```matlab
% Convert detection to scenario frame FIRST (required for all non-Scenario modes)
mp = dets{k}.MeasurementParameters(1);  % first element = position transform
meas = dets{k}.Measurement;
switch mp.Frame
    case 'Spherical'
        az = meas(1); el = meas(2); R = meas(3);
        posSensor = [R*cosd(el)*cosd(az); R*cosd(el)*sind(az); R*sind(el)];
        measScenario = mp.Orientation * posSensor + mp.OriginPosition(:);
    case 'Rectangular'
        measScenario = mp.Orientation * meas(1:3)' + mp.OriginPosition(:);
end
posError = norm(measScenario - truthPos);
expectedSigma = sqrt(trace(dets{k}.MeasurementNoise(1:3,1:3)));
assert(posError < 5*expectedSigma, 'Position error exceeds 5-sigma');
```

**SNR check** — verify reported SNR matches link budget prediction (within ~1 dB):

```matlab
expectedSNR = radar.RadarLoopGain + rcs_dBsm - 40*log10(slantRange);
reportedSNR = dets{k}.ObjectAttributes{1}.SNR;
assert(abs(reportedSNR - expectedSNR) < 1.0, 'SNR mismatch > 1 dB');
```

See [Coordinates & Transforms — Verification](references/coordinates-and-transforms.md#verification-spot-check-detections-against-truth) for full mode-aware verification patterns.

### Debugging: Isolate Beam Pointing

When diagnosing "no detections" or unexpected detection gaps, isolate whether the problem is beam pointing vs. something else:

1. **Release the sensor, then go omnidirectional:**
```matlab
origFoV = radar.FieldOfView;
origScan = radar.ScanMode;
release(radar);
radar.FieldOfView = [360; 180];
radar.ScanMode = 'No scanning';
```
2. **Restart and re-run the scenario** (`restart(scenario)` + advance loop)
3. **Interpret:**
   - Detections appear → problem is beam pointing (scan limits, MountingAngles, FoV, scan stepping over target)
   - Still no detections → problem is elsewhere (RangeLimits, UpdateRate aliasing, ReferenceRange, horizon, target RCS)
4. **Release and restore original config before continuing:**
```matlab
release(radar);
radar.FieldOfView = origFoV;
radar.ScanMode = origScan;
```

**Note:** `radarDataGenerator` is a System object. Non-tunable properties (`FieldOfView`, `ScanMode`, `AzimuthResolution`, scan limits, etc.) cannot be changed after `detect()` has been called without first calling `release(radar)`. Always `release()` before modifying non-tunable properties.

Do this BEFORE drilling into individual parameters — it splits the problem space in half with one test.

### Debugging Order

1. **Omnidirectional isolation** (above) — rules out beam pointing in one test
2. **Inspect systematic causes** — RangeLimits gate, scan sector bounds, UpdateRate aliasing. These produce deterministic failures (0% Pd) and are identifiable from a single run.
3. **Monte Carlo trials (last)** — only after systematic causes are ruled out. Use repeated runs to characterize *stochastic* behavior: Swerling fluctuation, intermittent detections near the detection boundary, empirical Pd vs analytical Pd. Never run Monte Carlo to diagnose a target that gets 0 detections — that is always a systematic cause.

### Fix Forward: Step Hierarchy

When validation fails, fix the latest step that could be wrong. Never change a system parameter (Steps 1–5) to accommodate a scenario choice (Steps 6–7). If the radar's FoV doesn't cover a target, the target is out of coverage — don't widen FoV to "fix" it. Only revisit earlier steps when there is a genuine design error.

## Analyzing Simulation Outputs

Critical NED traps that cause silent errors:

- **Geometric elevation (positive up):** `atand(-dx(3) ./ horizRange)` — negate D-axis so airborne targets get positive angle. **Sensor spherical elevation has opposite sign** for NED (sensor +z = Down): airborne targets get negative `el`.
- **Azimuth:** `atan2d(East, North)` — swapping arguments gives azimuth from East (90° error)
- **Empirical Pd:** `platformID = targetIndex + 1` (radar is platform 1) — off-by-one is common
- **Analytical Pd:** Default is **Swerling0** (`marcumq`), not Swerling I — using wrong formula gives 40% error
- **SNR:** `RadarLoopGain + RCS_dBsm - 40*log10(R)` — do NOT add integration gain (already in RLG)

See [Coordinates & Transforms](references/coordinates-and-transforms.md) for full conversion recipes and verification patterns.

## Output Requirements

1. **Requirements sheet** — standalone document (see template in references)
2. **MATLAB script** — runnable, with design-rationale comments and coupled-parameter table
3. **Validation** — compare simulation detections to analytical predictions

### Code Generation Rules

- **Never rely on defaults for `radarDataGenerator`.** Set every relevant property explicitly in the constructor, even when using the default value. This makes the code self-documenting — a reader should see every parameter choice without consulting documentation. Hidden defaults are hidden assumptions. **Exception — property gating:** Do NOT set properties that are irrelevant to the current configuration. Setting gated properties produces warnings ("not relevant in this configuration"). See the property-gating table below.
- Tag each parameter value with its source: user-provided, derived (from which inputs), or domain assumption (with justification).

### Property-Gating Rules

Properties gated by `Has*` flags — do NOT set these when the flag is `false`:

| Gate (when `false`) | Do NOT set |
|---------------------|-----------|
| `HasElevation` | `ElevationResolution`, `ElevationBiasFraction`, `MaxElevationScanRate`, `MechanicalElevationLimits`, `ElectronicElevationLimits` |
| `HasRangeRate` | `RangeRateResolution`, `RangeRateBiasFraction`, `RangeRateLimits`, `HasRangeRateAmbiguities` |
| `HasRangeAmbiguities` | `MaxUnambiguousRange` |
| `HasRangeRateAmbiguities` | `MaxUnambiguousRadialSpeed` |

Properties gated by `ScanMode`:

| ScanMode | Do NOT set |
|----------|-----------|
| `'No scanning'` | `MaxAzimuthScanRate`, `MaxElevationScanRate`, `MechanicalAzimuthLimits`, `MechanicalElevationLimits`, `ElectronicAzimuthLimits`, `ElectronicElevationLimits` |
| `'Mechanical'` | `ElectronicAzimuthLimits`, `ElectronicElevationLimits` |
| `'Electronic'` | `MechanicalAzimuthLimits`, `MechanicalElevationLimits`, `MaxAzimuthScanRate`, `MaxElevationScanRate` |
| `'Mechanical and electronic'` | (all scan properties valid) |

Never set `HasScanLoss` — it warns in all scan modes (not valid in any current configuration).

When `EmissionsInputPort=true`: do NOT set `ScanMode`, `FieldOfView`, or any scan-limit/rate properties (scan is driven by emissions).

Properties gated by `TargetReportFormat`:

| Format | Do NOT set |
|--------|-----------|
| `'Clustered detections'` or `'Detections'` | `FilterInitializationFcn`, `ConfirmationThreshold`, `DeletionThreshold`, `TrackCoordinates` |
| `'Tracks'` | `DetectionCoordinates` |

Properties gated by `DetectionMode`:

| Mode | Do NOT set |
|------|-----------|
| `'ESM'` | `ReferenceRange`, `ReferenceRCS`, `DetectionProbability` |

## References
Load only what the task requires — do not read all references for every prompt.

| Reference | When to Read |
|-----------|-------------|
| [Detection Model](references/detection-model.md) | Configuring radar properties, debugging property names, understanding detection pathway |
| [FoV & Scan](references/fov-and-scan.md) | Setting FieldOfView, scan mode config, UpdateRate/scan rate derivation |
| [Coordinates & Transforms](references/coordinates-and-transforms.md) | Interpreting detections, converting frames, NED elevation/azimuth, plotting |
| [Trajectories](references/trajectories.md) | Target motion, stationary platforms, scenario duration, body frame orientation |
| [Terrain, Clutter & Atmosphere](references/terrain-clutter-atmosphere.md) | Adding surfaces, clutter generator, atmosphere models, occlusion |
| [Radar Equation Tools](references/radar-equation-tools.md) | Bottom-up derivation, hardware-to-ReferenceRange bridge, Pd vs range |
| [Visualization](references/visualization.md) | theaterPlot, coverage plots, radarmetricplot |
| [Coupled Parameters](references/coupled-parameters.md) | Step 5: parameter-relationship table, datasheet ingestion |
| [Interaction Flow](references/interaction-flow.md) | Full 9-step workflow with suggested phrasings |
| [Requirements Sheet Template](references/requirements-sheet-template.md) | Step 9: three-section output artifact structure |

----
Copyright 2026 The MathWorks, Inc.
