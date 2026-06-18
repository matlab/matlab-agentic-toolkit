# FieldOfView, Resolution & Scan Modes

## FieldOfView vs Resolution (Beamwidth)

`FieldOfView` and `AzimuthResolution`/`ElevationResolution` are **independent properties** with distinct roles:

| Property | What It Represents | Controls |
|----------|-------------------|----------|
| `FieldOfView` [az; el] | Angular extent of one scan position. The statistical model produces at most one detection per target per scan position — consistent with an internal beam laydown and detection clustering. | Detection boundary (targets outside get 0 detections); scan step size (beam advances by FoV each step); number of false alarm opportunities per step. |
| `AzimuthResolution` | One-way half-power beamwidth (azimuth). The doc says: "typically the half-power beamwidth of the azimuth angle beamwidth of the radar." | Measurement noise (σ_az² ∝ resolution²). For antenna gain derivation: `beamwidth2gain([AzimuthResolution; ElevationResolution])` — must include BOTH dimensions. |
| `ElevationResolution` | One-way half-power beamwidth (elevation). Same definition as azimuth. | Measurement noise (σ_el²). |

**One-way vs two-way beamwidth:** The resolution properties represent the **one-way** half-power beamwidth. For monostatic radar (same Tx/Rx antenna), the one-way beamwidth equals the two-way effective beamwidth — Barton's formula gives `effbeamwidth(θ, θ) = θ`. The `effbeamwidth` function is needed when Tx and Rx apertures differ (e.g., bistatic, or different Tx/Rx beamwidths on the same platform).

**Typical FoV choices (from `radarDesigner` export pattern):**

| Configuration | FoV Setting | Why |
|---------------|-------------|-----|
| Scanning, single shared aperture | `[TxBeamwidth_az, TxBeamwidth_el]` | FoV = transmit beamwidth. For monostatic with same Tx/Rx antenna, this equals `[AzRes, ElRes]`. |
| AESA, wide Tx + digital BF Rx | `[TxBeamwidth_az, TxBeamwidth_el]` | Tx illuminates a wider extent; multiple Rx beams form within it. FoV > AzRes. |
| Staring / validation | `[180, 180]` | Wide open — detect any target in hemisphere regardless of bearing. Used for initial validation before adding scan. |

**Behavioral summary (confirmed empirically):**

- At most 1 true detection per target per scan position — FoV models the aggregate result of beam laydown and clustering, not individual beam positions within the FoV.
- Hard cutoff at ±FoV/2: targets inside are candidates for detection (subject to Pd); targets outside produce zero detections.
- False alarms scale with FoV (more angular coverage = more resolution cells tested per step).
- Neither FoV nor resolution affects `RadarLoopGain` — it depends only on `ReferenceRange`/`ReferenceRCS`/`Pd`/`Pfa`.
- Both properties are fully independent: FoV > resolution, FoV < resolution, and FoV = resolution are all valid.

**Scan mode dependency:**

- In non-Custom modes (Mechanical, Electronic, No scanning): `FieldOfView` is user-set, `BeamShape` is always Rectangular (hard detection boundary = FoV).
- In Custom mode: `FieldOfView` property is disabled. `EffectiveFieldOfView` is derived from resolution: `[AzRes, ElRes]` for Rectangular beam, `2*[AzRes, ElRes]` for Gaussian beam.

**For the link budget:** Antenna gain comes from beamwidth — `G = beamwidth2gain([AzimuthResolution; ElevationResolution])`. Both az and el beamwidths are required; passing only azimuth assumes a symmetric beam and overestimates gain by up to 10 dB for fan beams. FoV does not enter the gain calculation.

**For scan rate:** Use `FieldOfView(1)` — `actualScanRate = min(FoV(1) * UpdateRate, MaxAzimuthScanRate)`.

## Scan Modes

| ScanMode Value | Behavior |
|----------------|----------|
| `'Mechanical'` | `actualRate = min(FoV(1) * sensorUpdateRate, MaxAzimuthScanRate)`. Default sensor UpdateRate is **1 Hz** — must set explicitly. |
| `'Electronic'` | Beam jumps by `FieldOfView(1)` each update. `MaxAzimuthScanRate` is **ignored** (warning issued if set). |
| `'Mechanical and electronic'` | Mechanical provides coarse pointing; electronic beam steers within mechanical position. |
| `'No scanning'` | Fixed staring beam. |

Convenience constructors: `radarDataGenerator(id, 'Raster')`, `'Rotator'`, `'Sector'`, `'Custom'`

### Mechanical Scan Rate (Validated)

The scan rate is NOT simply `MaxAzimuthScanRate / UpdateRate`. The actual model:

```
actualScanRate = min(FieldOfView(1) * sensorUpdateRate, MaxAzimuthScanRate)  [deg/s]
stepPerScenarioUpdate = actualScanRate / scenarioUpdateRate  [deg]
```

Critical implications:
- Default sensor `UpdateRate` = 1 Hz. A 2-deg beam with default rate scans at 2 deg/s, **ignoring** MaxAzimuthScanRate=36.
- To get desired rate: set `sensorUpdateRate >= desiredRate / FieldOfView(1)`
- `AzimuthResolution` does NOT affect scan step size (tested and confirmed)
- `MechanicalElevationLimits` is irrelevant for 'Sector' convenience (warning issued, HasElevation=false)

----

Copyright 2026 The MathWorks, Inc.

----
