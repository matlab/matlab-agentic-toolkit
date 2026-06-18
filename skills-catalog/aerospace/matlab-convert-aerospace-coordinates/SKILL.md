---
name: matlab-convert-aerospace-coordinates
description: >
  Perform aerospace unit conversions, time conversions, coordinate frame
  transformations, and rotation representations using Aerospace Toolbox.
  Use when converting units (length, velocity, angle, acceleration, angular
  velocity, force, mass, pressure, temperature, density), computing Julian
  dates or decimal years, transforming between coordinate frames (ECEF, ECI,
  LLA, flat Earth, geodetic/geocentric, NED, body, wind, stability), or
  working with rotation representations (Euler angles, DCM, quaternion,
  Rodrigues vector). Also use when the user asks about aerospace coordinate
  systems, reference frames, or rotation conventions.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Aerospace Fundamentals

Core Aerospace Toolbox functions for unit conversions, time conversions, coordinate transformations, and rotation representations.

## When to Use

- Converting between aerospace unit systems (SI, imperial, nautical)
- Computing Julian dates, modified Julian dates, decimal years, or TDB time
- Transforming positions between ECEF, ECI, LLA, or flat Earth frames
- Converting between geodetic and geocentric latitude
- Building DCMs for frame transformations (ECI↔ECEF, ECEF↔NED, body↔wind, body↔stability)
- Converting between Euler angles, DCMs, quaternions, and Rodrigues vectors
- Using the `quaternion` object for rotation math, interpolation, or composition
- Identifying which coordinate frame data is expressed in

## When NOT to Use

- Atmosphere models (`atmosisa`, `atmoscoesa`) — not covered here
- Airspeed corrections (`correctairspeed`) — not covered here
- Orbit propagation or satellite maneuvers — use Aerospace Blockset or Satellite Communications Toolbox
- Navigation-specific transforms (`lla2enu`, `lla2ned`) — use Navigation Toolbox
- Simulink blocks — use `/model-based-design-core:building-simulink-models`

## Workflow

1. **Identify the coordinate frame** — Determine what frame your data is in and what frame you need. See `references/coordinate-systems.md` for frame definitions and decision guide.
2. **Convert units first** — Ensure inputs match the function's expected units before calling transforms.
3. **Apply the transformation** — Use the appropriate function with correct argument ordering.
4. **Verify** — Round-trip the result back to the original frame; error should be < 1e-10.

## Key Functions

### Unit Conversions

| Function | Converts | Units |
|----------|----------|-------|
| `convlength` | Length | `'ft'`, `'m'`, `'km'`, `'in'`, `'mi'`, `'naut mi'` |
| `convvel` | Velocity | `'ft/s'`, `'m/s'`, `'km/s'`, `'in/s'`, `'km/h'`, `'mph'`, `'kts'`, `'ft/min'` |
| `convang` | Angle | `'deg'`, `'rad'`, `'rev'` |
| `convacc` | Acceleration | `'ft/s^2'`, `'m/s^2'`, `'km/s^2'`, `'in/s^2'`, `'km/h-s'`, `'mph/s'`, `'G''s'` |
| `convangacc` | Angular acceleration | `'deg/s^2'`, `'rad/s^2'`, `'rpm/s'` |
| `convangvel` | Angular velocity | `'deg/s'`, `'rad/s'`, `'rpm'` |
| `convforce` | Force | `'N'`, `'lbf'` |
| `convmass` | Mass | `'kg'`, `'lbm'`, `'slug'` |
| `convpres` | Pressure | `'Pa'`, `'psi'`, `'psf'`, `'atm'` |
| `convtemp` | Temperature | `'K'`, `'R'`, `'F'`, `'C'` |
| `convdensity` | Density | `'kg/m^3'`, `'slug/ft^3'`, `'lbm/ft^3'`, `'lbm/in^3'` |

All conversion functions use the same signature: `output = convXXX(value, fromUnit, toUnit)`

### Time Conversions

| Function | Purpose | Since |
|----------|---------|-------|
| `juliandate` | Calendar → Julian Date | R2006b |
| `mjuliandate` | Calendar → Modified Julian Date (JD − 2400000.5) | R2006b |
| `decyear` | Calendar → decimal year | R2006b |
| `leapyear` | Test if year is leap year | R2006b |
| `tdbjuliandate` | Terrestrial Time → TDB Julian Date | R2015a |

### Coordinate Transformations

| Function | From | To | Since |
|----------|------|-----|-------|
| `lla2ecef` | LLA (geodetic) | ECEF | R2006b |
| `ecef2lla` | ECEF | LLA (geodetic) | R2006b |
| `lla2eci` | LLA | ECI | R2014a |
| `eci2lla` | ECI | LLA | R2014a |
| `ecef2eci` | ECEF (pos/vel/acc) | ECI | R2019a |
| `eci2ecef` | ECI (pos/vel/acc) | ECEF | R2019a |
| `eci2aer` | ECI | AER (azimuth, elevation, range) | R2015a |
| `lla2flat` | LLA | Flat Earth | R2011a |
| `flat2lla` | Flat Earth | LLA | R2011a |
| `geod2geoc` | Geodetic latitude | Geocentric latitude | R2006b |
| `geoc2geod` | Geocentric latitude | Geodetic latitude | R2006b |
| `dcmeci2ecef` | — | ECI-to-ECEF DCM | R2013b |
| `dcmecef2ned` | — | ECEF-to-NED DCM | R2006b |
| `dcm2latlon` | ECEF-to-NED DCM | Lat/Lon | R2006b |
| `dcmbody2wind` | Alpha, Beta | Body-to-Wind DCM | R2006b |
| `dcm2alphabeta` | Body-to-Wind DCM | Alpha, Beta | R2006b |
| `dcmbody2stability` | Alpha | Body-to-Stability DCM | R2022a |

### Rotation Representations

| Function | From | To | Since |
|----------|------|-----|-------|
| `angle2dcm` | Euler angles | DCM | R2006b |
| `dcm2angle` | DCM | Euler angles | R2006b |
| `angle2quat` | Euler angles | Quaternion (1×4) | R2006b |
| `quat2angle` | Quaternion (1×4) | Euler angles | R2007b |
| `dcm2quat` | DCM | Quaternion (1×4) | R2006b |
| `quat2dcm` | Quaternion (1×4) | DCM | R2006b |
| `angle2rod` | Euler angles | Rodrigues vector | R2017a |
| `rod2angle` | Rodrigues vector | Euler angles | R2017a |
| `dcm2rod` | DCM | Rodrigues vector | R2017a |
| `rod2dcm` | Rodrigues vector | DCM | R2017a |
| `quat2rod` | Quaternion (1×4) | Rodrigues vector | R2017a |
| `rod2quat` | Rodrigues vector | Quaternion (1×4) | R2017a |

### Quaternion Object

| Method | Purpose |
|--------|---------|
| `quaternion(E,'eulerd',RS,PF)` | Create from Euler angles (degrees) |
| `quaternion(E,'euler',RS,PF)` | Create from Euler angles (radians) |
| `quaternion(RM,'rotmat',PF)` | Create from rotation matrix |
| `quaternion(RV,'rotvec')` | Create from rotation vector (radians) |
| `compact(q)` | Extract [w x y z] array |
| `eulerd(q,RS,PF)` | Convert to Euler angles (degrees) |
| `euler(q,RS,PF)` | Convert to Euler angles (radians) |
| `rotmat(q,PF)` | Convert to rotation matrix |
| `rotvec(q)` / `rotvecd(q)` | Convert to rotation vector (rad/deg) |
| `rotatepoint(q,pts)` | Rotate points (active rotation) |
| `rotateframe(q,pts)` | Rotate frame (passive rotation) |
| `normalize(q)` | Normalize to unit quaternion |
| `slerp(q1,q2,t)` | Spherical linear interpolation |
| `meanrot(q)` | Mean rotation of array |
| `dist(q1,q2)` | Angular distance (radians) |
| `angvel(q,dt,PF)` | Angular velocity from quaternion array |
| `randrot(n)` | Uniform random rotations |

### Quaternion Math (Array-Based)

| Function | Purpose | Since |
|----------|---------|-------|
| `quatmultiply(q,r)` | Quaternion product (compose rotations) | R2006b |
| `quatconj(q)` | Conjugate (negate vector part) | R2006b |
| `quatinv(q)` | Inverse (conjugate / norm²) | R2006b |
| `quatnormalize(q)` | Normalize to unit quaternion | R2006b |
| `quatnorm(q)` | Squared norm (q·q) | R2006b |
| `quatmod(q)` | Modulus (sqrt of norm) | R2006b |
| `quatrotate(q,v)` | Rotate vector by quaternion | R2006b |
| `quatdivide(q,r)` | Divide quaternion by quaternion | R2006b |
| `quatinterp(p,q,f,method)` | Interpolate (`'slerp'`, `'lerp'`, `'nlerp'`) | R2016a |
| `quatexp(q)` | Exponential of quaternion | R2016a |
| `quatlog(q)` | Natural logarithm of quaternion | R2016a |
| `quatpower(q,pow)` | Quaternion raised to a power | R2016a |

## Patterns

### Unit Conversion

```matlab
% Always: convXXX(value, 'from', 'to')
alt_m = convlength(35000, 'ft', 'm');        % 10668.0 m
speed_ms = convvel(250, 'kts', 'm/s');       % 128.61 m/s
angle_rad = convang(45, 'deg', 'rad');       % 0.7854 rad
accel_g = convacc(9.81, 'm/s^2', 'G''s');   % 1.0 G
omega_rpm = convangvel(360, 'deg/s', 'rpm'); % 60 rpm
```

### Time Conversion

```matlab
% Julian Date from components (year, month, day, hour, min, sec)
jd = juliandate(2024, 6, 15, 12, 0, 0);     % 2460477.0

% Modified Julian Date
mjd = mjuliandate(2024, 6, 15, 12, 0, 0);   % 60476.5

% From datetime objects
dt = datetime(2024, 6, 15, 12, 0, 0);
jd = juliandate(dt);

% Decimal year
dy = decyear(2024, 6, 15);                   % 2024.4536

% TDB Julian Date from Terrestrial Time [yr mo day hr min sec]
tt = [2024 6 15 12 0 0];
jdTDB = tdbjuliandate(tt);
```

### LLA ↔ ECEF

```matlab
% LLA is [latitude_deg, longitude_deg, altitude_m]
lla = [40, -74, 0];
ecef = lla2ecef(lla);           % [1348613.0, -4703172.4, 4077985.6] m

% Round-trip verification
lla_check = ecef2lla(ecef);     % [40.0, -74.0, 0.0]
```

### LLA ↔ ECI (time-dependent)

```matlab
% ECI transforms require UTC time
lla = [40, -74, 1000];
utc = [2024 6 15 12 0 0];
posECI = lla2eci(lla, utc);

% Back to LLA
lla_check = eci2lla(posECI, utc);
```

### Flat Earth Approximation

```matlab
% Good for short-range simulations (< ~100 km from reference)
llo = [40, -74];    % reference lat/lon (deg)
psio = 0;           % angular direction of flat Earth x-axis (rad, 0=North)
href = 0;           % reference height (m)

lla_point = [40.01, -73.99, 100];
flatPos = lla2flat(lla_point, llo, psio, href);  % [x, y, z] in meters
lla_back = flat2lla(flatPos, llo, psio, href);
```

### Euler Angles ↔ DCM

```matlab
% CRITICAL: angle2dcm expects RADIANS, not degrees
yaw = deg2rad(30); pitch = deg2rad(10); roll = deg2rad(5);
dcm = angle2dcm(yaw, pitch, roll, 'ZYX');

% Extract angles back (returns radians)
[y, p, r] = dcm2angle(dcm, 'ZYX');
fprintf('Yaw=%.1f, Pitch=%.1f, Roll=%.1f deg\n', rad2deg(y), rad2deg(p), rad2deg(r));
```

### DCM ↔ Quaternion (Aerospace Toolbox format)

```matlab
% Aerospace Toolbox quaternion format: [q0 q1 q2 q3] = [scalar, vector]
q = dcm2quat(dcm);       % 1x4, scalar-first
dcm_back = quat2dcm(q);  % 3x3

% Verify orthogonality
err = max(abs(dcm' * dcm - eye(3)), [], 'all');
assert(err < 1e-14, 'DCM is not orthogonal');
```

### Quaternion Object (Modern Approach)

```matlab
% Create from Euler angles — specify sequence AND frame type
q = quaternion([30 10 5], 'eulerd', 'ZYX', 'frame');

% Rotate a point (active rotation)
pt = [1 0 0];
pt_rotated = rotatepoint(q, pt);   % [0.8529, 0.4924, -0.1736]

% Compose rotations by multiplication
q_total = q2 * q1;  % applies q1 first, then q2

% Always normalize after arithmetic accumulation
q = normalize(q);
```

### Quaternion Interpolation (SLERP)

```matlab
% Smooth interpolation between two orientations
q1 = quaternion([0 0 0], 'eulerd', 'ZYX', 'frame');
q2 = quaternion([90 0 0], 'eulerd', 'ZYX', 'frame');
t = linspace(0, 1, 5)';
q_interp = slerp(q1, q2, t);

% Verify: yaw progresses linearly for pure yaw rotation
e = eulerd(q_interp, 'ZYX', 'frame');
% e(:,1) = [0, 22.5, 45, 67.5, 90]
```

### Quaternion Math (Array-Based Functions)

```matlab
% Compose two rotations: q2 applied after q1
q1 = angle2quat(deg2rad(30), 0, 0, 'ZYX');
q2 = angle2quat(0, deg2rad(10), 0, 'ZYX');
q_total = quatmultiply(q2, q1);  % q2 * q1 (apply q1 first)

% Inverse rotation
q_inv = quatinv(q1);
q_identity = quatmultiply(q1, q_inv);  % [1 0 0 0]

% Rotate a vector
v = [1 0 0];
v_rot = quatrotate(q1, v);  % rotate v by q1

% Normalize after accumulation
q_accumulated = quatnormalize(q_total);

% Interpolation (slerp, lerp, nlerp)
q_mid = quatinterp(q1, q2, 0.5, 'slerp');

% Relative rotation: what rotation takes q1 to q2?
q_rel = quatdivide(q2, q1);  % q_rel such that q2 = q_rel * q1

% Exponential/logarithm (useful for angular velocity integration)
q_log = quatlog(q1);         % maps to tangent space
q_back = quatexp(q_log);     % back to quaternion

% Fractional rotation (half the rotation of q1)
q_half = quatpower(q1, 0.5);
```

### Rodrigues Vector

```matlab
% Compact 3-element representation (singular at 180 deg)
rod = dcm2rod(dcm);           % 1x3 vector
dcm_back = rod2dcm(rod);

% Convert between all representations
rod = quat2rod(q_array);      % q is M×4 (scalar-first)
q_back = rod2quat(rod);
```

### Body-to-Wind and Stability Frames

```matlab
% Body-to-wind DCM from angle of attack and sideslip
alpha = deg2rad(5);
beta = deg2rad(2);
dcm_bw = dcmbody2wind(alpha, beta);

% Extract alpha/beta from a DCM
[alpha_out, beta_out] = dcm2alphabeta(dcm_bw);

% Body-to-stability (alpha only, no sideslip)
dcm_bs = dcmbody2stability(alpha);
```

### ECEF-to-NED Frame DCM

```matlab
% Get the DCM to rotate vectors from ECEF to local NED
lat = deg2rad(40);
lon = deg2rad(-74);
dcm_ecef2ned = dcmecef2ned(lat, lon);

% Transform an ECEF velocity to NED
v_ecef = [10; 20; 30];
v_ned = dcm_ecef2ned * v_ecef;
```

### ECI to AER (Azimuth, Elevation, Slant Range)

```matlab
% Compute look angles from a ground station to a satellite in ECI
posECI = [-2981784, 5207055, 3161595];  % satellite ECI position (m)
utc = [2019 1 4 12 0 0];               % observation time
lla0 = [28.5, -80.5, 0];               % ground station [lat, lon, alt] (deg, deg, m)

aer = eci2aer(posECI, utc, lla0);
% aer = [azimuth_deg, elevation_deg, slant_range_m]
```

## Conventions

- **`angle2dcm` and `angle2quat` expect radians** — always convert with `deg2rad()` or `convang` first
- **Rotation sequence default is `'ZYX'`** (yaw-pitch-roll) — always specify explicitly for clarity
- **Aerospace Toolbox quaternion format is `[scalar, i, j, k]`** — the 1×4 array functions use scalar-first
- **`quaternion` object also uses scalar-first** (`compact` returns `[w x y z]`)
- **`rotatepoint` vs `rotateframe`** — `rotatepoint` rotates the point (active); `rotateframe` rotates the frame (passive). They are inverses.
- **LLA ordering is `[lat, lon, alt]`** in degrees and meters
- **`geod2geoc` and `geoc2geod` expect radians** for latitude, meters for height/radius
- **ECI functions require UTC time** — results change with Earth's rotation
- **Normalize quaternions** after arithmetic operations to prevent drift
- **Rodrigues vector is singular at 180°** — use quaternions for arbitrary rotations

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Pass degrees to `angle2dcm` | Function expects radians | Use `deg2rad()` or `convang(val,'deg','rad')` |
| Omit rotation sequence | Default ZYX may not match your convention | Always pass `'ZYX'`, `'XYZ'`, etc. explicitly |
| Assume quaternion is `[x y z w]` | Aerospace Toolbox uses `[w x y z]` (scalar-first) | Check format; use `compact(q)` to verify |
| Use `rotatepoint` when meaning `rotateframe` | They are inverses — wrong one flips the rotation | Active rotation = `rotatepoint`; passive = `rotateframe` |
| Skip normalization after quaternion math | Quaternion drift causes non-unit norm, distorted rotations | Call `normalize(q)` after accumulating rotations |
| Pass degrees to `geod2geoc` | Expects radians for latitude | Convert: `geod2geoc(deg2rad(lat), alt)` |
| Forget UTC for ECI transforms | ECI position depends on Earth rotation at that instant | Always provide `[yr mo day hr min sec]` |
| Use Rodrigues near 180° rotation | Rodrigues vector has a singularity at π | Use quaternion representation instead |
| Ignore gimbal lock near ±90° pitch | Euler angle extraction loses a degree of freedom | Use quaternion or DCM directly for computations |

## Gimbal Lock

Euler angle representations lose one degree of freedom when the second rotation reaches ±90° (for ZYX: pitch = ±90°). Symptoms:

- `dcm2angle` returns unexpected yaw/roll values near pitch = ±90°
- Interpolating Euler angles produces erratic paths near singularity

**Solution:** Use quaternions for computation and interpolation. Only convert to Euler angles for display or human interpretation.

```matlab
% Detect gimbal lock risk
[~, pitch, ~] = dcm2angle(dcm, 'ZYX');
if abs(pitch) > deg2rad(85)
    warning('Near gimbal lock — use quaternion representation');
end
```

## References

- See `references/coordinate-systems.md` for detailed frame definitions (ECEF, ECI, NED, body, wind, stability), axis conventions, and a decision guide for choosing the right frame.
- See `references/rotation-conventions.md` for detailed rotation math: DCM properties, quaternion algebra, gimbal lock theory, and conversion paths between all representations.
- See `references/unit-conversion-guide.md` for complete unit string tables and chaining conversions.

----

Copyright 2026 The MathWorks, Inc.

----
