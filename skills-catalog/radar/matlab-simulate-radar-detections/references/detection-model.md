# Detection Model & Property Reference

Quick-reference for correct property names, detection model internals, and configuration options.

## radarDataGenerator Detection Model

```
SNR = RadarLoopGain + RCS(dBsm) - 40*log10(R)
```

- `RadarLoopGain` is **read-only**, derived from: `ReferenceRange`, `ReferenceRCS`, `DetectionProbability`, `FalseAlarmRate`
- No hardware knobs (Pt, Gain, NF, Losses) — all lumped into reference performance
- `CenterFrequency` and `Bandwidth` affect **resolution only**, not detection range
- Measurement accuracy: `σ² = (Δ/√(2·SNR))² + (BiasFraction·Δ)²` — SNR-dependent random component plus systematic bias floor. Defaults: `AzimuthBiasFraction=0.1` (floor=0.3° for 3° resolution), `RangeBiasFraction=0.05` (floor=3.75m for 75m resolution), `ElevationBiasFraction=0.1`. At high SNR the bias dominates — errors never go below the floor regardless of signal strength.

## Property Names — Correct vs Hallucinated

| Correct | Common Hallucination |
|---------|---------------------|
| `MechanicalAzimuthLimits` | `MechanicalScanLimits`, `ScanLimits` |
| `MechanicalElevationLimits` | `ElevationScanLimits` |
| `ElectronicAzimuthLimits` | `ElectronicScanLimits` |
| `ReferenceRCS` (dBsm) | `RCS`, `TargetRCS` |
| `FalseAlarmRate` [1e-7, 1e-3] | `Pfa`, `FalseAlarmProb` |
| `HasScanLoss` (Custom mode only) | `ScanLoss` |
| `MaxAzimuthScanRate` | `ScanRate`, `AzimuthScanRate` |
| `RangeLimits` (default [0, 100e3]) | Gates on TRUE range (before ambiguity folding). Target range must be within `RangeLimits` or it will not be detected. |

## Read-Only (Dependent) Properties

These properties are computed from other settings. Use them for validation, not configuration:

| Property | Returns | Use For |
|----------|---------|---------|
| `RadarLoopGain` | dB scalar | Verify link budget: should match analytical prediction from hardware specs |
| `LookAngle` | [az, el] deg | Current beam pointing direction during simulation |
| `MechanicalAngle` | [az, el] deg | Current mechanical scan position |
| `ElectronicAngle` | [az, el] deg | Current electronic steer angle |
| `EffectiveFieldOfView` | [az, el] deg | Actual FoV accounting for beam shape and scan loss |
| `EffectiveAzimuthResolution` | deg | Actual azimuth resolution (scan-loss adjusted) |
| `EffectiveElevationResolution` | deg | Actual elevation resolution (scan-loss adjusted) |

**Validation pattern:** After configuring a radar, read `RadarLoopGain` and compare to your analytical link budget. If they disagree, a parameter is wrong.

## Property Tunability

`radarDataGenerator` is a System object. After `detect()` is called, non-tunable properties are locked. Call `release(radar)` before changing them, then `restart(scenario)` before re-running.

**Non-tunable (require `release()` before changing):**
`ScanMode`, `FieldOfView`, `HasGhosts`, `HasScanLoss`, `BeamShape`, `UpdateRate`, `MountingLocation`, `MountingAngles`, `MaxAzimuthScanRate`, `MaxElevationScanRate`, `MechanicalAzimuthLimits`, `MechanicalElevationLimits`, `ElectronicAzimuthLimits`, `ElectronicElevationLimits`, `DetectionMode`, `InterferenceInputPort`, `EmissionsInputPort`, `EmitterIndex`, `WaveformTypes`, `ConfusionMatrix`, `Sensitivity`, `DetectionThreshold`, `HasRangeAmbiguities`, `HasRangeRateAmbiguities`, `HasElevation`, `HasRangeRate`, `HasINS`, `MaxNumReports`, `DetectionCoordinates`, `TrackCoordinates`, `Profiles`, `AzimuthBiasFraction`, `ElevationBiasFraction`, `RangeBiasFraction`, `RangeRateBiasFraction`, `HasNoise`, `HasFalseAlarms`, `HasOcclusion`, `FilterInitializationFcn`, `ConfirmationThreshold`, `DeletionThreshold`, `TargetReportFormat`, `SensorIndex`, `MaxNumReportsSource`

**Tunable (can change while locked):**
`CenterFrequency`, `Bandwidth`, `DetectionProbability`, `ReferenceRange`, `ReferenceRCS`, `FalseAlarmRate`, `RangeLimits`, `RangeRateLimits`, `MaxUnambiguousRange`, `MaxUnambiguousRadialSpeed`, `AzimuthResolution`, `ElevationResolution`, `RangeResolution`, `RangeRateResolution`

## Emissions-Pathway Properties (Leave at Default)

`radarDataGenerator` has two detection pathways:

1. **Target-pose pathway** (default): `detect(scenario)` or `rdg(targetPoses, simTime)`. Detection governed by `DetectionProbability`, `FalseAlarmRate`, `ReferenceRange`, `ReferenceRCS`. This is the pathway the skill uses.
2. **Emissions pathway**: `detect(scenario, propagatedEmissions)` with `EmissionsInputPort=true` or `DetectionMode='ESM'`. Detection governed by `Sensitivity` and `DetectionThreshold`.

The following properties are **irrelevant** in the target-pose pathway. Setting them produces a "not relevant" warning and has zero effect on detection:

| Property | Default | Purpose (emissions pathway only) |
|----------|---------|----------------------------------|
| `Sensitivity` | -50 dBmi | Receiver noise floor; controls max ESM detection range |
| `DetectionThreshold` | 5 dB | Receiver dynamic range above noise floor; higher = more sensitive |
| `WaveformTypes` | 0 | Waveform IDs for classification (ESM only) |
| `ConfusionMatrix` | 1 | Waveform classification confusion probabilities (ESM only) |
| `HasScanLoss` | false | Beam broadening off-broadside (requires `ScanMode='Custom'`) |

### How Sensitivity and DetectionThreshold Interact (Emissions Pathway)

In ESM mode, `Sensitivity` and `DetectionThreshold` jointly determine detection probability vs range:

- **`Sensitivity`** (dBmi): Sets the receiver noise floor. Lower value = detects weaker signals at longer range. Acts like `ReferenceRange` for the target-pose pathway.
- **`DetectionThreshold`** (dB): Sets the receiver dynamic range above the noise floor. **Higher value = better detection performance** (counterintuitive naming). Acts like a receiver quality factor.

Detection is probabilistic (Swerling-like curve) near the sensitivity boundary, not a hard cutoff. Neither property affects target-pose pathway detection.

**In the target-pose pathway**, detection is governed SOLELY by `DetectionProbability`, `FalseAlarmRate`, `ReferenceRange`, and `ReferenceRCS`. No other properties affect the detection decision.

## Standalone API (Without radarScenario)

`radarDataGenerator` can be called outside a scenario for integration into custom simulation loops:

```matlab
rdg = radarDataGenerator(1, 'ScanMode', 'Mechanical', ...);
[dets, numDets, config] = rdg(targetPoses, simTime);
```

**Required inputs:**
- `targetPoses` — struct array. Minimum fields: `PlatformID`, `ClassID`, `Position`, `Velocity`, `Acceleration`, `Orientation` (quaternion), `AngularVelocity`. `Signatures` and `Dimensions` are optional (defaults: 10 dBsm Swerling0, zero-size).
- `simTime` — scalar (seconds). Drives beam position for scanning modes. Must advance between calls for the beam to step.

**Limitations vs `radarScenario`-based usage:**

| Feature | Scenario-based | Standalone |
|---------|---------------|------------|
| Time management | `advance(scenario)` | User manages loop and time stamps |
| Platform trajectories | Automatic from `waypointTrajectory` etc. | User constructs pose structs each step |
| Multi-sensor aggregation | `detect(scenario)` returns all sensors | Each sensor called independently |
| Coverage visualization | `coverageConfig(scenario)` + `coveragePlotter` | Not available |
| Self-platform exclusion | Automatic (own platform never detected) | Must filter manually by PlatformID |
| Scenario restart | `restart(scenario)` | User resets time and sensor state via `reset(rdg)` |

**When to use standalone:**
- Integrating into an existing simulation framework (e.g., Simulink, custom event-driven loop)
- Sensor-level unit tests (single target, single time step)
- Embedding in a tracking loop where `radarScenario` overhead is unwanted

**When to prefer `radarScenario`:**
- Multi-platform scenarios with trajectories
- Coverage analysis or visualization
- Multi-sensor fusion pipelines
- Any task where `advance()`/`detect(scenario)` simplifies the loop

## detect() Signature

```matlab
dets = detect(scenario);                              % cell array of objectDetection
[dets, sensorConfigs] = detect(scenario);             % + sensor config struct array
[dets, sensorConfigs, configPIDs] = detect(scenario); % + platform IDs per config
```

- `dets`: cell array of `objectDetection` objects
- Each detection: `.Measurement`, `.ObjectAttributes{1}.TargetIndex`, `.Time`, `.SensorIndex`
- `TargetIndex` is the platform ID (radar = 1, first target = 2, etc.)
- `sensorConfigs`: struct array with `SensorIndex`, `IsValidTime`, `IsScanDone`, `FieldOfView`, `RangeLimits`, `RangeRateLimits`, `MeasurementParameters`
- `configPIDs`: platform IDs corresponding to each sensor config

The single-output form is sufficient for most workflows. Use the 2-output form when you need to check `IsScanDone` (scan-complete triggering) or inspect the sensor's current state.

### TargetReportFormat

| Value | Output | Notes |
|-------|--------|-------|
| `'Clustered detections'` (default) | Cell array of `objectDetection` | One detection per resolved target per scan |
| `'Detections'` | Cell array of `objectDetection` | One detection per resolution cell (multiple per target possible) |
| `'Tracks'` | Array of `objectTrack` | Internal tracker (EKF); uses `ConfirmationThreshold`, `DeletionThreshold`, `FilterInitializationFcn` |

**Tracks mode notes:**
- `Profiles` property (struct array with `PlatformID`, `ClassID`, `Dimensions`, `Signatures`) feeds the internal classifier
- `TrackCoordinates` replaces `DetectionCoordinates` (which becomes "not relevant")
- Track confirmation requires multiple detections — no output until confirmation threshold met

**Recommendation:** Use `'Clustered detections'` and feed an external tracker (`radarTracker`, `trackerGNN`, `trackerJPDA`) for production workflows. The internal tracker in Tracks mode offers less control.

## Target RCS (rcsSignature)

Each platform has a default `rcsSignature` in its `Signatures` property: 10 dBsm constant, Swerling0.

### Setting per-target RCS

```matlab
% Constant RCS: -20 dBsm (0.01 m²), Swerling 1
uavSig = rcsSignature('Pattern', [-20 -20; -20 -20], ...
    'Azimuth', [-180 180], ...
    'Elevation', [-90 90], ...
    'FluctuationModel', 'Swerling1');

tgt = platform(scenario, 'Position', [15000 0 -500], ...
    'Signatures', {uavSig});
```

### Key properties

| Property | Format | Notes |
|----------|--------|-------|
| `Pattern` | Q×P matrix in **dBsm** | Q = elevation samples, P = azimuth samples |
| `Azimuth` | 1×P vector (deg) | Must span [-180, 180] for full coverage |
| `Elevation` | 1×Q vector (deg) | Must span [-90, 90] for full coverage |
| `FluctuationModel` | `'Swerling0'`, `'Swerling1'`, `'Swerling3'` | No Swerling 2 or 4 at this level |
| `Frequency` | 1×K vector (Hz) | Default [0, 1e20] covers all frequencies |

### FluctuationModel options

- **Swerling0**: Non-fluctuating (deterministic RCS). Use for initial validation.
- **Swerling1**: Slow-fluctuating (constant within a dwell, independent scan-to-scan). Most targets.
- **Swerling3**: One dominant scatterer plus many small (chi-squared 4 DOF). Missiles, certain aspects.

Swerling 2 and 4 (fast-fluctuating, pulse-to-pulse) are not available at statistical level — they require I/Q simulation.

### Aspect-dependent pattern

For targets with directional RCS (e.g., higher from nose/tail than broadside):

```matlab
sigFighter = rcsSignature( ...
    'Pattern', [5 -5 0 -5 5; 5 -5 0 -5 5], ...
    'Azimuth', [-180 -90 0 90 180], ...
    'Elevation', [-90 90], ...
    'FluctuationModel', 'Swerling1');
% nose/tail: 5 dBsm, broadside: -5 dBsm, head-on: 0 dBsm
```

## Deprecated Functions

| Deprecated | Replacement |
|-----------|-------------|
| `range2bw` | `rangeres2bw` |
| `bw2range` | `bw2rangeres` |

----

Copyright 2026 The MathWorks, Inc.

----
