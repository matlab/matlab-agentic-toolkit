---
name: matlab-fuse-inertial-sensors
description: >
  Analyzes sensor configurations and creates inertial fusion filters in MATLAB
  Navigation Toolbox. Manages filter selection (imufilter, ahrsfilter,
  complementaryFilter, insfilterMARG, insfilterAsync, insfilterNonholonomic,
  insfilterErrorState, insEKF, insCF), construction, tuning, and fusion loops.
  Use when fusing IMU/AHRS/INS/GPS+IMU data, estimating orientation or pose,
  or choosing a filter. Do NOT use for vision-only SLAM, Simulink fusion, or
  IMU simulation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: R2022a+
metadata:
  author: MathWorks
  version: "1.1"
---

## When to Use

Select, implement, or tune an inertial sensor fusion filter in MATLAB Navigation Toolbox.

## When NOT to Use

- Vision-only or LiDAR-only SLAM (no inertial sensor): use nav SLAM functions instead
- Sensor simulation or data generation only: no filter needed
- Simulink model-based sensor fusion

---

## Choose Your Filter

### Step 1 — Configured or Flexible?

Configured filters cover these sensor combinations exactly:

- Accel + Mag only (no gyro)
- Accel + Gyro (no mag, no GPS)
- Accel + Gyro + Mag
- Accel + Gyro + Mag + Altimeter
- Accel + Gyro + GPS (ground vehicle, no mag)
- Accel + Gyro + GPS + monocular visual odometry (ground vehicle)
- Accel + Gyro + Mag + GPS (synchronous rates)
- Accel + Gyro + Mag + GPS (mixed rates or dropped samples)

```
Is your sensor set one of the above?
        │ No ─────────────────────────────────────────────────────► Step 2B (Flexible)
        │ Yes
        ▼
Need a custom motion model (constant-velocity, bicycle, etc.)?
        │ Yes ────────────────────────────────────────────────────► Step 2B (Flexible)
        │ No
        ▼
Need RTS smoothing, StateCovariance output, or optimizer-based tune()?
        │ Yes ────────────────────────────────────────────────────► Step 2B (Flexible)
        │ No
        ▼
Batch-only processing (no real-time predict/fuse loop needed)?
        │ Yes ────────────────────────────────────────────────────► Step 2B (Flexible)
        │ No
        ▼
        Step 2A (Configured)
```

---

### Step 2A — Pick a configured filter

```
What output do you need?
│
├─ Orientation only (no position)
│   │
│   ├─ Accel + Mag only (no gyro)
│   │   └──► ecompass   [function, not object; single-shot; useful for filter init]
│   │
│   ├─ Accel + Gyro (no mag)
│   │   └──► imufilter   [heading drifts over time without mag]
│   │
│   ├─ Accel + Gyro + Mag
│   │   ├──► ahrsfilter   [default; KF-based, statistically tunable]
│   │   └── lowest compute cost needed?
│   │       └──► complementaryFilter   [gain-based only; no KF, no tune()]
│   │
│   └─ Accel + Gyro + Mag + Altimeter
│       └──► ahrs10filter   [adds altitude + vertical velocity output]
│
└─ Full pose (orientation + position + velocity)
    │
    ├─ No motion constraints (aerial, or ground vehicle without side-slip constraint)
    │   ├─ Accel + Gyro + Mag + GPS, all sensors sync
    │   │   └──► insfilterMARG
    │   └─ Accel + Gyro + Mag + GPS, mixed rates or dropped samples
    │       └──► insfilterAsync
    │
    └─ Ground vehicle with zero side-slip constraint
        ├─ Accel + Gyro + GPS
        │   └──► insfilterNonholonomic
        └─ Accel + Gyro + GPS + monocular visual odometry
            └──► insfilterErrorState
```

---

### Step 2B — Pick a flexible filter

```
Need real-time fusion, StateCovariance output, or optimizer-based tune()?
        │ Yes ──► insEKF   [production use; full KF; real-time and batch APIs]
        │ No
        ▼
Batch-only processing, no covariance needed, quick setup (R2026a+)?
        └──► insCF   [complementary filter; gain-based; not for production]
```

---

## Data Preparation

### Sample Rate

`SampleRate` (Group A filters) and `IMUSampleRate` (Group B filters) must match the actual data rate — a mismatch directly scales the noise model and corrupts all filter outputs. `insfilterAsync`, `insEKF`, and `insCF` are timestamp-driven and have no rate property.

**Convert timestamps to seconds first**, then infer the rate:

```matlab
tSec = rawTimestamp / 1e6;   % µs → s; divide by 1e3 for ms, or skip if already seconds
fs = 1 / median(diff(tSec));
```

**If timestamps are unusable** (all identical, or non-finite result):

```matlab
if numel(unique(tSec)) < 2 || ~isfinite(fs)
    fs = 100;   % use the stated or datasheet rate
end
```

### Time Gaps

All stateful filters accumulate error across a recording gap (a large jump in timestamps). Split the data at each gap and reset the filter at the start of each segment.

```matlab
gapThreshold = 5 / fs;                   % 5× the expected sample interval
gapIdx = find(diff(tSec) > gapThreshold);
segments = [1; gapIdx+1];                % start index of each segment
```

**Group A System object filters** (`imufilter`, `ahrsfilter`, `complementaryFilter`): call `release(filt)` between segments — resets state while preserving all tuned noise properties.

**Group B and other filters**: re-construct the filter object at the start of each segment.

---

## Implementation

Consult the reference file for the filter you chose:

| Filter group              | Reference                                                             |
| ------------------------- | --------------------------------------------------------------------- |
| Attitude filters          | [references/attitude-filters.md](references/attitude-filters.md)     |
| Navigation filters        | [references/navigation-filters.md](references/navigation-filters.md) |
| `insEKF`                  | [references/insekf.md](references/insekf.md)                         |
| `insCF`                   | [references/inscf.md](references/inscf.md)                           |

---

## Tuning

Two `tune` signatures exist — mixing them up is a common error:

- **Signature A** (`imufilter`, `ahrsfilter`) — modifies filter in-place:
  `tune(filt, sensorData, groundTruth)`
- **Signature B** (`ahrs10filter`, `insfilterMARG`, `insfilterAsync`, `insfilterNonholonomic`, `insfilterErrorState`, `insEKF`) — returns noise struct:
  `tunedNoise = tune(filt, tunernoise(filt), sensorData, groundTruth)`

Not tunable via `tune`:
- `ecompass`, `complementaryFilter` — no tune method; adjust properties manually
- `insCF` — use `gainparts(filt, sensorName, value)` instead

`insEKF` only: `tunerconfig` requires a filter **instance** — `tunerconfig(filt)`, not `tunerconfig('insEKF')`

### tunerconfig

| Property | Default | Description |
| -------- | ------- | ----------- |
| `MaxIterations` | 20 | Stop after this many iterations |
| `ObjectiveLimit` | 0.1 | Stop when cost drops below this value |
| `Display` | `"iter"` | `"iter"` prints progress each iteration; `"none"` suppresses output |
| `Cost` | `"RMS"` | `"RMS"` minimizes RMS error; `"Custom"` uses `CustomCostFcn` |
| `CustomCostFcn` | `[]` | Function handle; active only when `Cost = "Custom"` |

### tunernoise Field Names by Filter

Signature B filters require `tunernoise(filt)` before calling `tune`. Signature A filters (`imufilter`, `ahrsfilter`) do not use `tunernoise` — `tune` modifies their noise properties directly in-place.

| Filter | Fields returned by `tunernoise` |
| ------ | ------------------------------- |
| `ahrs10filter` | `MagnetometerNoise`, `AltimeterNoise` |
| `insfilterMARG` | `MagnetometerNoise`, `GPSPositionNoise`, `GPSVelocityNoise` |
| `insfilterAsync` | `AccelerometerNoise`, `GyroscopeNoise`, `MagnetometerNoise`, `GPSPositionNoise`, `GPSVelocityNoise` |
| `insfilterNonholonomic` | `GPSPositionNoise`, `GPSVelocityNoise` |
| `insfilterErrorState` | `MVOOrientationNoise`, `MVOPositionNoise`, `GPSPositionNoise`, `GPSVelocityNoise` |
| `insEKF` | Named by `filt.SensorNames` + `Noise` suffix (e.g. `AccelerometerNoise`, `GPSNoise`) |

Fields use the `...Noise` suffix — omitting it is a common mistake.

### Visualizing Results

`tunerPlotPose` is an `OutputFcn` callback — pass it to `tunerconfig` to plot pose estimates live during each tuning iteration. It is **not** a standalone post-hoc plotting function; calling it directly with filter and data arguments will error ("Too many input arguments").

```matlab
config = tunerconfig(filt);
config.OutputFcn = @tunerPlotPose;
tunedNoise = tune(filt, tunernoise(filt), sensorData, groundTruth, config);
```

For post-tuning visualization, extract the filter state and plot against your ground truth manually. Configured filters (`ahrs10filter`, `insfilterMARG`, `insfilterAsync`, `insfilterNonholonomic`, `insfilterErrorState`) have a `pose()` method — use it. **`insEKF` and `insCF` have no `pose()` method** — use `stateparts(filt, 'Orientation')`, `stateparts(filt, 'Position')`, etc. instead. For batch workflows, plot from the `estimateStates` output timetable.

For advanced patterns (controlling `TunableParameters`, custom cost functions, `OutputFcn` for logging/early stopping), see [references/insekf.md](references/insekf.md) and [references/navigation-filters.md](references/navigation-filters.md).

---

## Conventions

- **Reference frame**: default is `"NED"`. To use ENU:
  - Configured filter objects (`imufilter`, `ahrsfilter`, `complementaryFilter`, `ahrs10filter`, `insfilterMARG`, `insfilterAsync`, `insfilterNonholonomic`, `insfilterErrorState`): `filt.ReferenceFrame = "ENU"`
  - `ecompass` (a function, not an object): the `orientationFormat` positional arg is required before any name-value pairs — `ecompass(a, m, 'quaternion', 'ReferenceFrame', 'ENU')`. Omitting it errors: "Expected input number 3, FORMAT..."
  - `insEKF`/`insCF`: `ReferenceFrame` is read-only after construction; set via `insOptions`/`insCFOptions` at construction time

- **Orientation output**: `quaternion` object by default.

- **GPS position input**: LLA vector in degrees / degrees / meters.

- **Sample rate property**:
  - `imufilter`, `ahrsfilter`, `complementaryFilter`: `SampleRate`
  - `ahrs10filter`, `insfilterMARG`, `insfilterNonholonomic`, `insfilterErrorState`: `IMUSampleRate`
  - `insfilterAsync`, `insEKF`, `insCF`: no sample rate property (sensors carry their own timestamps)

- **`ReferenceLocation`**: must be set on `insfilterMARG`, `insfilterAsync`, `insfilterNonholonomic`, and `insfilterErrorState` before the fusion loop. For `insEKF`/`insCF`, set it on the `insGPS`/`insCFGPS` sensor object instead.

## Skill Feedback

If this skill's guidance was wrong, incomplete, or didn't work, emit a plain-text
feedback marker in your response, then continue with the task.

Format: `NAV-SKILL-FEEDBACK [matlab-fuse-inertial-sensors] [category]: what failed; what you did instead`
Categories: `wrong-command` (incorrect/outdated), `missing-guidance` (omitted step),
`discovery-failure` (suggested approach didn't work), `platform-issue` (environment-specific)

Copyright 2026 The MathWorks, Inc.
