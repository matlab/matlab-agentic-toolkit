# Coordinates, Transforms & Output Analysis

## DetectionCoordinates

Controls the format of `.Measurement` in each detection:

| Value | Measurement format | Notes |
|-------|-------------------|-------|
| `'Body'` (default) | [x, y, z] in platform body frame | Cartesian, meters |
| `'Scenario'` | [x, y, z] in scenario frame | Cartesian, meters |
| `'Sensor rectangular'` | [x, y, z] in sensor frame | Cartesian, meters. **Frame rotates with the beam** — each detection's coordinate system depends on where the beam was pointing at detection time. |
| `'Sensor spherical'` | **[azimuth, elevation, range]** | deg, deg, meters |

**Warning:** Spherical order is [az, el, range], NOT [range, az, el]. Common assumption error.

If `HasRangeRate = true`, an additional element is appended: `[az, el, range, rangeRate]` for spherical, or `[x, y, z, vx, vy, vz]` for Cartesian modes.

### Measurement Interpretation per Mode

What "0" means in each coordinate depends entirely on the mode origin:

| Mode | Origin (0,0,0) | "0 azimuth" means | "0 elevation" means |
|------|---------------|-------------------|---------------------|
| `'Body'` | Platform center of mass | Along platform +x (body forward) | In the body x-y plane |
| `'Sensor rectangular'` | Sensor mounting point | Along sensor boresight | In the sensor boresight plane |
| `'Sensor spherical'` | Sensor mounting point | Sensor boresight direction | Sensor boresight plane (not horizon) |
| `'Scenario'` | Scenario origin | Along scenario +x (North in NED) | N/A (Cartesian) |

**Critical implication:** A detection at `[0, 0, 50000]` in sensor spherical means "50 km along sensor boresight" — NOT "50 km due north" or "50 km along body axis." If the platform has non-zero `MountingAngles`, boresight differs from body axis. If the platform is moving with heading, body axis differs from scenario north.

### Converting Detections to Scenario Frame for Plotting

Detections in non-scenario frames **cannot** be plotted directly against truth positions. Convert first.

**Key concept:** For `'Sensor rectangular'`, the measurement frame rotates with the beam. Each detection carries its own `MeasurementParameters` with `Orientation` and `OriginPosition` fields that encode the beam direction at detection time. Use these per-detection values to transform back to scenario frame: `scenarioPos = Orientation * Measurement + OriginPosition`.

**`MeasurementParameters` structure:** Each detection has a `.MeasurementParameters` field — a struct array (1 or 2 elements). Use element `(1)` for position. Fields: `Frame` ('Spherical' or 'Rectangular'), `Orientation` (3×3 rotation matrix), `OriginPosition` (1×3), `IsParentToChild` (0 = child-to-parent rotation).

**When `IsParentToChild = 0`:** `Orientation` rotates FROM sensor/body frame TO scenario frame. Apply directly (no transpose):

```matlab
% Sensor spherical → scenario frame
meas = dets{k}.Measurement;  % [az; el; range] or [az; el; range; rr] (column)
az = meas(1); el = meas(2); R = meas(3);

% Step 1: spherical → sensor-frame Cartesian
posSensor = [R * cosd(el) * cosd(az); R * cosd(el) * sind(az); R * sind(el)];

% Step 2: sensor frame → scenario frame
mp = dets{k}.MeasurementParameters(1);  % use first element for position
posScenario = mp.Orientation * posSensor + mp.OriginPosition;
```

```matlab
% Sensor rectangular or Body frame → scenario frame
% Measurement and OriginPosition are both 3x1 column vectors
mp = dets{k}.MeasurementParameters(1);
posScenario = mp.Orientation * dets{k}.Measurement(1:3) + mp.OriginPosition;
```

```matlab
% Scenario frame — already in scenario coordinates, plot directly
posScenario = dets{k}.Measurement(1:3);
```

**Common errors:**
- Using `mp.Orientation'` (transpose) — WRONG when `IsParentToChild=0`. The matrix is already child→parent.
- Using `mp` without indexing — `MeasurementParameters` is an array (2 elements for spherical mode). Use `mp(1)`.
- `Measurement` and `OriginPosition` are both **column vectors (3×1)**. No transpose or `(:)` reshaping needed for the matrix multiply.

**Rule:** Never plot raw `.Measurement` values from Body/Sensor modes on the same axes as scenario-frame truth without converting. The numerical values will look plausible but represent entirely different coordinate systems.

### Verification: Spot-Check Detections Against Truth

After generating detections, verify that measurement errors are physically reasonable. This catches "code runs but produces garbage" silently:

```matlab
% Mode-aware verification (works for any DetectionCoordinates setting)
for k = 1:numel(dets)
    meas = dets{k}.Measurement;
    mp = dets{k}.MeasurementParameters(1);  % first element = position transform
    tgtIdx = dets{k}.ObjectAttributes{1}.TargetIndex;
    if tgtIdx <= 0, continue; end  % skip clutter/false alarms
    
    % Get truth position in scenario frame
    truthPos = scene.Platforms{tgtIdx}.Position(:);
    
    % Convert measurement to scenario frame (IsParentToChild=0: no transpose)
    switch mp.Frame
        case 'Spherical'
            az = meas(1); el = meas(2); R = meas(3);
            posSensor = [R*cosd(el)*cosd(az); R*cosd(el)*sind(az); R*sind(el)];
            measScenario = mp.Orientation * posSensor + mp.OriginPosition;
        case 'Rectangular'
            measScenario = mp.Orientation * meas(1:3) + mp.OriginPosition;
    end
    
    % Compare
    posError = norm(measScenario - truthPos);
    expectedSigma = sqrt(trace(dets{k}.MeasurementNoise(1:3,1:3)));
    
    % Sanity: error should be within ~3*sigma for 99% of detections
    if posError > 5 * expectedSigma
        warning('Detection %d: error %.1f m >> expected sigma %.1f m', k, posError, expectedSigma);
    end
end
```

**What this catches:**
- Wrong `MountingAngles` (position error is systematic, proportional to range × angle error)
- Misinterpreted coordinate frame (errors are large and directional)
- Wrong `ReferenceRange` or detection model config (SNR-driven sigma won't match observed errors)

### SNR Verification Against Link Budget

Verify the reported SNR against analytical prediction:

```matlab
% Expected SNR from detection model
RLG = radar.RadarLoopGain;  % read-only property (dB)
rcs_dBsm = 10*log10(targetRCS_m2);  % target RCS
R = slantRange;  % meters to target

expectedSNR = RLG + rcs_dBsm - 40*log10(R);
reportedSNR = dets{k}.ObjectAttributes{1}.SNR;

snrError = abs(reportedSNR - expectedSNR);
if snrError > 1.0  % dB
    warning('SNR mismatch: expected %.1f dB, got %.1f dB (delta %.1f dB)', ...
        expectedSNR, reportedSNR, snrError);
end
```

**Acceptable deviation:** ~0.5 dB from Swerling fluctuation and noise. >1 dB indicates a configuration problem (wrong RCS, wrong range, or wrong ReferenceRange).

## Coordinate Frames

| Setting | Effect |
|---------|--------|
| `IsEarthCentered = false` | Local flat-earth frame; use `waypointTrajectory` or `kinematicTrajectory` |
| `IsEarthCentered = true` | Earth-centered (ECEF); use `geoTrajectory` only |
| `waypointTrajectory` `'ReferenceFrame'` | `'NED'` or `'ENU'` — sets coordinate convention |
| `kinematicTrajectory` | NO `ReferenceFrame` property — inherits from scenario |
| `geoTrajectory` | Waypoints as [lat, lon, alt] in [deg, deg, m]. Has `'ReferenceFrame'` for velocity/orientation. Also supports `Course`/`GroundSpeed`/`ClimbRate` |
| NED sensor spherical elevation | **Negative** for targets above radar (sensor +z = Down) |
| ENU sensor spherical elevation | **Positive** for targets above radar (sensor +z = Up) |

**Trajectory–scenario coupling (enforced, will error if violated):**
- `IsEarthCentered = false` → `waypointTrajectory` or `kinematicTrajectory`
- `IsEarthCentered = true` → `geoTrajectory`

**`geoTrajectory` gotchas:**
- `DetectionCoordinates = 'Scenario'` reports ECEF [x,y,z] in meters, not geodetic
- Single waypoint = stationary; `TimeOfArrival` is ignored (warning issued)
- Use when earth curvature matters: long-range surveillance, over-the-horizon, or when user thinks in lat/lon/alt

Pick ONE frame. Use it consistently. Validate by computing expected angles analytically.

## NED Output Analysis Recipes

### NED Elevation Angles

```matlab
dx = targetPositions - radarPosition;       % [N, E, D] relative
horizontalRange = vecnorm(dx(:,1:2), 2, 2);
% NEGATE the D-component: in NED, negative D = above ground
heightAboveRadar = -dx(:,3);
elevationDeg = atand(heightAboveRadar ./ horizontalRange);
% All elevations should be POSITIVE for airborne targets
```

**Sanity check:** radar at z=-20 (20m tower), target at z=-500 (500m altitude). `dx(3) = -500 - (-20) = -480`. `heightAboveRadar = -(-480) = +480`. Elevation = `atand(480/range)` = positive. Correct.

### Sensor Spherical Elevation vs Geometric Elevation

These are **different quantities with opposite signs** for NED:

| Quantity | Definition | Positive means | Formula |
|----------|-----------|----------------|---------|
| Geometric elevation | Angle above local horizon | Target above radar | `atand(-dx(3) / horizRange)` |
| Sensor spherical elevation | Angle from sensor x-y plane toward sensor +z | Toward sensor +z axis | `atand(z_sensor / horizRange_sensor)` |

**General rule:** Sensor spherical elevation = angle from sensor x-y plane toward sensor +z. What +z means physically depends on `MountingAngles` and platform orientation.

**NED with `MountingAngles=[0,0,0]`:** Sensor +z = body +z = Down. Therefore:
- Airborne targets (above radar) → `z_sensor < 0` → **negative** sensor elevation
- Below-radar targets → `z_sensor > 0` → **positive** sensor elevation
- Relationship: `sensor_el = -geometric_el` (sign flip)

**Conversion from NED geometry to expected sensor spherical:**

```matlab
dx = targetPos - radarPos;  % [N, E, D] relative
% Sensor +z = Down for NED with default mounting
% z_sensor = dx(3) directly (D-component)
horizRange = norm(dx(1:2));
expected_sensor_el = atand(dx(3) / horizRange);  % positive for D>0 (below)
expected_sensor_az = atan2d(dx(2), dx(1));        % atan2d(East, North)
expected_range = norm(dx);
```

**Verification:** For a target at z=-5000 (5 km altitude) with radar at z=-20: `dx(3) = -5000 - (-20) = -4980`. Expected sensor elevation = `atand(-4980 / horizRange)` = **negative**. If the measured sensor elevation is negative and magnitude matches, the measurement is correct.

### NED Azimuth (From North, Clockwise)

```matlab
dx = targetPositions - radarPosition;
% NED: x=North, y=East. Azimuth from North = atan2d(East, North)
azimuthDeg = atan2d(dx(:,2), dx(:,1));
```

**Common mistake:** `atan2d(dx(:,1), dx(:,2))` = `atan2d(North, East)` gives angle from East axis, not North. This rotates all azimuths by 90 degrees.

**Verification:** targets placed at azimuths -40° to +40° (from `scene_verification_scenario.m`) should compute to azimuths within that range. If they show -50° to +50° or are offset by 90°, the formula is wrong.

### Empirical Pd vs Range

```matlab
% Count detections per target over nScans complete scans
% TargetIndex is platform ID: radar=1, first target=2, etc.
nScans = scenarioStopTime * updateRate / stepsPerScan;  % or known from scenario config
empiricalPd = zeros(nTargets, 1);
for i = 1:nTargets
    empiricalPd(i) = sum(detTargetIdx == i + 1) / nScans;
end
targetRanges = vecnorm(targetPositions - radarPosition, 2, 2);
```

### Plan-View Plotting

```matlab
% For DetectionCoordinates = 'Scenario': measurements are already in NED frame
% Plot directly — no coordinate transform needed
figure;
plot(targetPositions(:,2)/1e3, targetPositions(:,1)/1e3, 'bo', 'DisplayName', 'Targets');
hold on;
plot(detMeas(:,2)/1e3, detMeas(:,1)/1e3, 'r.', 'DisplayName', 'Detections');
plot(radarPosition(2)/1e3, radarPosition(1)/1e3, 'k^', 'MarkerSize', 12, 'DisplayName', 'Radar');

% Scan sector lines (±45° from North)
sectorRange = 90;  % km
for az = [-45, 45]
    lineN = sectorRange * cosd(az);
    lineE = sectorRange * sind(az);
    plot([0, lineE], [0, lineN], 'k--', 'HandleVisibility', 'off');
end

xlabel('East (km)'); ylabel('North (km)');
legend('Location', 'best');
axis equal; grid on;
```

**Axis convention choice:** Map-style plots put East on x-axis, North on y-axis (so "up" = North). This means plotting `(y_NED, x_NED)` as `(plotX, plotY)`. Alternatively, keep NED native with North on x-axis — just label clearly.

----

Copyright 2026 The MathWorks, Inc.

----
