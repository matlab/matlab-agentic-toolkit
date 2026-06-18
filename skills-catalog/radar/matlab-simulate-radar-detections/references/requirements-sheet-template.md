# Requirements Sheet Template

The requirements sheet is the primary artifact produced by Step 9 of the workflow. It must be standalone — a fresh agent or human can pick it up cold and build the simulation.

## Structure

### Section 1: Parameters

Grouped by domain. Each parameter includes value + source tag.

```markdown
## Parameters

### Frequency & Wavelength
| Parameter | Value | Source | Notes |
|-----------|-------|--------|-------|
| Center frequency | 3 GHz | User-provided | S-band |
| Wavelength | 0.1 m | Derived (freq2wavelen) | |

### Antenna
| Parameter | Value | Source | Notes |
|-----------|-------|--------|-------|
| Gain (1-way) | 35 dB | User-provided | From datasheet |
| Beamwidth (az) | 2 deg | Derived (G ≈ 4πAe/λ²) | |
| Beamwidth (el) | 4 deg | Domain assumption | 2:1 aspect ratio |

### Power & Timing
| Parameter | Value | Source | Notes |
|-----------|-------|--------|-------|
| Peak power | 100 kW | User-provided | |
| PRF | 1000 Hz | User-provided | |
| Pulse width | 10 µs | Derived (duty = τ×PRF) | duty = 0.01 |
| Duty cycle | 1% | Derived | |

### Detection Performance
| Parameter | Value | Source | Notes |
|-----------|-------|--------|-------|
| Reference range | 82.3 km | Derived (radareqrng) | From hardware specs |
| Reference RCS | 0 dBsm | User-provided | 1 m² reference |
| Detection probability | 0.9 | User-provided | |
| False alarm rate | 1e-6 | User-provided | |

### Resolution
| Parameter | Value | Source | Notes |
|-----------|-------|--------|-------|
| Bandwidth | 1 MHz | User-provided | |
| Range resolution | 150 m | Derived (bw2rangeres) | |
| Azimuth resolution | 2 deg | Derived (= beamwidth) | |

### Scan
| Parameter | Value | Source | Notes |
|-----------|-------|--------|-------|
| Scan mode | Mechanical | User-provided | |
| Sector | 90 deg | User-provided | |
| Scan rate | 36 deg/s | Derived (from revisit req) | |
| Revisit time | 5 s | Domain assumption | Unidirectional |

### Targets
| Target | RCS (dBsm) | Speed | Altitude | Swerling | Source |
|--------|-------------|-------|----------|----------|--------|
| Small UAV | -20 | 50 m/s | 500 m | I | Domain assumption |
| Fighter | 0 | 250 m/s | 5 km | I | User-provided |
| Commercial | 10 | 200 m/s | 10 km | I | Domain assumption |
```

Source tags:
- **User-provided** — explicitly stated by user or from datasheet
- **Domain assumption** — reasonable default with justification
- **Derived** — computed from other params (show function name)

### Section 2: Simulation Approach

Plain-language description:

```markdown
## Simulation Approach

**Fidelity:** Statistical-level (radarDataGenerator)
- Detections generated using models consistent with signal processing and atmospheric effects
- No full I/Q waveform simulation
- Chosen for fast iteration; upgrade to signal-level if fine processing control needed

**What is modeled:**
- Detection probability vs range (from reference performance)
- Measurement noise (Cramér-Rao bound from resolution + SNR)
- Scan pattern and revisit timing
- Target motion and geometry
- [Terrain/atmosphere if applicable]

**What is NOT modeled:**
- Specific signal processing chain
- Waveform effects (sidelobes, ambiguities beyond Runamb/Vmax)
- Weather/precipitation
- Clutter (unless terrain added)
- Electronic countermeasures

**Self-consistency check:**
- Hardware specs → radareqrng → ReferenceRange = [X] km
- Simulation should produce ~Pd = [Y] at reference range
- If mismatch > [threshold], investigate
```

### Section 3: API Configuration Plan

Exact API calls with property values traced to Section 1:

```markdown
## API Configuration Plan

### Scenario
| Property | Value | From |
|----------|-------|------|
| UpdateRate | 30 Hz | Domain assumption (adequate for scan step) |
| IsEarthCentered | false | Design choice |

### radarDataGenerator
| Property | Value | From |
|----------|-------|------|
| SensorIndex | 1 | — |
| ScanMode | 'Mechanical' | Section 1: Scan |
| CenterFrequency | 3e9 | Section 1: Frequency |
| Bandwidth | 1e6 | Section 1: Resolution |
| ReferenceRange | 82300 | Section 1: Detection (derived) |
| ReferenceRCS | 0 | Section 1: Detection (dBsm!) |
| DetectionProbability | 0.9 | Section 1: Detection |
| FalseAlarmRate | 1e-6 | Section 1: Detection |
| FieldOfView | [2; 4] | Section 1: Scan (instantaneous detection window, NOT beamwidth) |
| MechanicalAzimuthLimits | [-45 45] | Section 1: Scan (±sector/2) |
| MechanicalElevationLimits | [-30 0] | Section 1: Scan (NED: negative = up) |
| MaxAzimuthScanRate | 36 | Section 1: Scan |
| AzimuthResolution | 2 | Section 1: Resolution |
| RangeResolution | 150 | Section 1: Resolution |
| RangeLimits | [0, 120e3] | max(maxTargetRange, ReferenceRange*1.2) — default 100 km clips silently |
| DetectionCoordinates | 'Scenario' | Set explicitly — default 'Body' gives Cartesian in platform body frame |
| UpdateRate | 20 | Must set — default 1 Hz causes slow scan. See scan rate model. |

### Platforms
| Platform | Position | Trajectory | Notes |
|----------|----------|-----------|-------|
| Radar | [0,0,-30] | Static (tower) | NED: -30 = 30m above ground |
| UAV | [20000,5000,-500] | waypointTrajectory, 50 m/s | NED |
| Fighter | [40000,-10000,-5000] | waypointTrajectory, 250 m/s | NED |
| Commercial | [60000,20000,-10000] | waypointTrajectory, 200 m/s | NED |

### Visualization Plan
- `theaterplot` with detection plotter for scenario overview
- Detection count vs time to verify scan timing
- Range-azimuth scatter of detections to verify coverage
- Compare measured Pd at reference range to configured value
```

## Key Properties of a Good Requirements Sheet

1. **Standalone** — a fresh agent or human can build the simulation from this alone
2. **Traceable** — every value has a source tag; derived values show the function
3. **Self-consistent** — hardware-derived range matches configured reference range
4. **Reviewable** — an expert can audit without running code
5. **Actionable** — Section 3 maps directly to MATLAB code

----

Copyright 2026 The MathWorks, Inc.

----