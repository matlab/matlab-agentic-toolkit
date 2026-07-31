# objectDetection Patterns for Legacy Trackers

## The Standard MeasurementParameters Struct

All built-in measurement models (`cvmeas`, `cameas`, `ctmeas`, `ctrvmeas`, `singermeas`) expect this struct:

```matlab
mp = struct( ...
    'Frame', 'spherical', ...           % 'spherical' or 'rectangular'
    'OriginPosition', [0;0;0], ...      % sensor position in parent frame (3×1)
    'OriginVelocity', [0;0;0], ...      % sensor velocity in parent frame (3×1)
    'Orientation', eye(3), ...          % 3×3 rotation matrix (parent→child)
    'IsParentToChild', true, ...        % rotation direction
    'HasAzimuth', true, ...             % include azimuth angle?
    'HasElevation', true, ...           % include elevation angle?
    'HasRange', true, ...               % include range/position?
    'HasVelocity', true);               % include range-rate/velocity?
```

**Critical rule:** If using any built-in filter init function (`initcvekf`, `initcaukf`, `initctekf`, etc.), `MeasurementParameters` MUST be this struct. The built-in inits wire up `cvmeas`/`cameas`/`ctmeas` as the measurement function, which expects exactly these fields.

## Measurement Vector Ordering

### Spherical frame

Order is always: `[azimuth, elevation, range, range-rate]` with missing elements removed based on flags:

| Flags | Measurement vector |
|---|---|
| All true | `[az, el, range, rr]` (4) |
| HasVelocity=false | `[az, el, range]` (3) |
| HasElevation=false | `[az, range, rr]` (3) |
| HasElevation=false, HasVelocity=false | `[az, range]` (2) |
| HasRange=false, HasVelocity=false | `[az, el]` (2) |
| HasElevation=false, HasRange=false, HasVelocity=false | `[az]` (1) |
| HasAzimuth=false, HasElevation=false | `[range, rr]` (2) |
| HasAzimuth=false, HasElevation=false, HasVelocity=false | `[range]` (1) |

### Rectangular frame

Order: `[x, y, z, vx, vy, vz]` with missing elements removed:

| Flags | Measurement vector |
|---|---|
| HasRange=true, HasVelocity=true | `[x, y, z, vx, vy, vz]` (6) |
| HasRange=true, HasVelocity=false | `[x, y, z]` (3) |

For rectangular: `HasAzimuth` and `HasElevation` must be `false`.

## MeasurementNoise

Must match the measurement vector size:
- 4-element measurement → 4×4 covariance
- 2-element measurement → 2×2 covariance

Diagonal is common: `diag([azVar, elVar, rngVar, rrVar])`.

Units: azimuth/elevation variance in deg², range in m², range-rate in (m/s)².

## Rotation Specification

Convert Euler angles (yaw, pitch, roll) to rotation matrix:

```matlab
rotQuat = quaternion([yaw pitch roll], 'eulerd', 'ZYX', 'frame');
rotMatrix = rotmat(rotQuat, 'frame');
mp.Orientation = rotMatrix;
mp.IsParentToChild = true;
```

## Building objectDetection — Complete Example

### Stationary radar, full spherical measurements

```matlab
% Data: table with columns Time, Azimuth, Elevation, Range, RangeRate, AzAccuracy, ...
nDets = height(detTable);
detections = cell(nDets, 1);

mp = struct('Frame','spherical', 'OriginPosition',[radarX;radarY;radarZ], ...
    'OriginVelocity',[0;0;0], 'Orientation',eye(3), 'IsParentToChild',true, ...
    'HasAzimuth',true, 'HasElevation',true, 'HasRange',true, 'HasVelocity',true);

for k = 1:nDets
    meas = [detTable.Azimuth(k); detTable.Elevation(k); detTable.Range(k); detTable.RangeRate(k)];
    noise = diag([detTable.AzAccuracy(k)^2, detTable.ElAccuracy(k)^2, ...
                  detTable.RngAccuracy(k)^2, detTable.RRAccuracy(k)^2]);
    detections{k} = objectDetection(detTable.Time(k), meas, ...
        'MeasurementNoise', noise, 'MeasurementParameters', mp, 'SensorIndex', 1);
end
```

### Moving sensor (pose changes per detection)

```matlab
for k = 1:nDets
    rotQuat = quaternion([detTable.Yaw(k) detTable.Pitch(k) detTable.Roll(k)], 'eulerd', 'ZYX', 'frame');
    mp = struct('Frame','spherical', ...
        'OriginPosition',[detTable.SensorX(k); detTable.SensorY(k); detTable.SensorZ(k)], ...
        'OriginVelocity',[detTable.SensorVx(k); detTable.SensorVy(k); detTable.SensorVz(k)], ...
        'Orientation',rotmat(rotQuat,'frame'), 'IsParentToChild',true, ...
        'HasAzimuth',true, 'HasElevation',true, 'HasRange',true, 'HasVelocity',true);
    meas = [detTable.Azimuth(k); detTable.Elevation(k); detTable.Range(k); detTable.RangeRate(k)];
    noise = diag([1, 1, 100, 4]);  % fixed noise or from data
    detections{k} = objectDetection(detTable.Time(k), meas, ...
        'MeasurementNoise', noise, 'MeasurementParameters', mp, 'SensorIndex', 1);
end
```

### Angle-only IR sensor

```matlab
mp = struct('Frame','spherical', 'OriginPosition',sensorPos, ...
    'OriginVelocity',[0;0;0], 'Orientation',eye(3), 'IsParentToChild',true, ...
    'HasAzimuth',true, 'HasElevation',true, 'HasRange',false, 'HasVelocity',false);

for k = 1:nDets
    meas = [detTable.Azimuth(k); detTable.Elevation(k)];
    noise = diag([azVar, elVar]);
    detections{k} = objectDetection(detTable.Time(k), meas, ...
        'MeasurementNoise', noise, 'MeasurementParameters', mp, 'SensorIndex', 2);
end
```

### Rectangular position (e.g., GPS/fused tracker output)

```matlab
mp = struct('Frame','rectangular', 'OriginPosition',[0;0;0], ...
    'OriginVelocity',[0;0;0], 'Orientation',eye(3), 'IsParentToChild',true, ...
    'HasAzimuth',false, 'HasElevation',false, 'HasRange',true, 'HasVelocity',false);

for k = 1:nDets
    meas = [detTable.X(k); detTable.Y(k); detTable.Z(k)];
    noise = diag([xVar, yVar, zVar]);
    detections{k} = objectDetection(detTable.Time(k), meas, ...
        'MeasurementNoise', noise, 'MeasurementParameters', mp, 'SensorIndex', 3);
end
```

## Multi-Sensor: Sensor-Agnostic Struct

For multi-sensor legacy tracking, ALL detections must share the same `MeasurementParameters` struct fields. The measurement function branches on flags:

```matlab
% Sensor 1: full radar (spherical, all measurements)
mp1 = struct('Frame','spherical', 'OriginPosition',radarPos, 'OriginVelocity',[0;0;0], ...
    'Orientation',eye(3), 'IsParentToChild',true, ...
    'HasAzimuth',true, 'HasElevation',true, 'HasRange',true, 'HasVelocity',true);

% Sensor 2: angle-only IR (spherical, no range/velocity)
mp2 = struct('Frame','spherical', 'OriginPosition',irPos, 'OriginVelocity',[0;0;0], ...
    'Orientation',eye(3), 'IsParentToChild',true, ...
    'HasAzimuth',true, 'HasElevation',true, 'HasRange',false, 'HasVelocity',false);
```

Both structs have the same fields — only values differ. `cvmeas`/`cameas`/`ctmeas` handle this automatically by reading the flags.

**Limitation:** Measurement vector SIZE differs between sensors. The tracker handles variable-size measurements internally, but `MeasurementNoise` must match each detection's measurement size.

## Chained MeasurementParameters (Multiple Rotations)

When a sensor has an additional rotation relative to the platform (e.g., gimbal, boresight offset), pass an array of structs:

```matlab
% MP for platform pose (car body in scenario frame)
mpPlatform = struct('Frame','rectangular', 'OriginPosition',carPos, ...
    'OriginVelocity',carVel, 'Orientation',carRotMat, 'IsParentToChild',true, ...
    'HasAzimuth',false, 'HasElevation',false, 'HasRange',true, 'HasVelocity',true);

% MP for sensor rotation relative to platform
mpSensor = struct('Frame','spherical', 'OriginPosition',[0;0;0], ...
    'OriginVelocity',[0;0;0], 'Orientation',sensorRotMat, 'IsParentToChild',true, ...
    'HasAzimuth',true, 'HasElevation',true, 'HasRange',true, 'HasVelocity',true);

% Chain: first mpPlatform is applied, then mpSensor
mpChained = [mpSensor, mpPlatform];
```

The sequence matters: transformations apply right to left (last element first).

## Compatible Filter Init Functions

When using the standard `MeasurementParameters` struct, these built-in inits work directly:

| Init Function | Motion Model | Filter Type |
|---|---|---|
| `initcvekf` | Constant velocity | EKF |
| `initcaekf` | Constant acceleration | EKF |
| `initctekf` | Constant turn rate | EKF |
| `initcvukf` | Constant velocity | UKF |
| `initcaukf` | Constant acceleration | UKF |
| `initctukf` | Constant turn rate | UKF |
| `initcvckf` | Constant velocity | CKF |
| `initcvpf` | Constant velocity | PF |
| `initsingerekf` | Singer acceleration | EKF |
| `initrpekf` | Range-parameterized | EKF |
| `initapekf` | Angle-parameterized | EKF |
| `initekfimm` | IMM (CV+CA+CT) | IMM |
| `initcvimm` | IMM (two CV) | IMM |
| `initctrvekf` | CTRV | EKF |
| `initctrvukf` | CTRV | UKF |

For angle-only sensors (HasRange=false), prefer `initrpekf` or `initapekf` — standard inits struggle with range-unobservable initializations.

## Verification with cvmeas

After building detections, verify MeasurementParameters are correct:

```matlab
% Given a known target state [x;vx;y;vy;z;vz] and the MP struct,
% cvmeas should reproduce approximately the same measurement
expectedMeas = cvmeas(knownState, mp);
% Compare with actual detection.Measurement
```

----

Copyright 2026 The MathWorks, Inc.
