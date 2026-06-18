# Rotation Conventions

## Direction Cosine Matrix (DCM)

A DCM is a 3×3 orthogonal matrix that transforms vectors between frames.

**Properties:**
- Orthogonal: `DCM' * DCM = I` (transpose equals inverse)
- Determinant = +1 (proper rotation, no reflection)
- Each row and column is a unit vector
- Columns represent the axes of the "from" frame expressed in the "to" frame

**Validate a DCM:**

```matlab
err_ortho = max(abs(dcm' * dcm - eye(3)), [], 'all');
err_det = abs(det(dcm) - 1);
assert(err_ortho < 1e-10 && err_det < 1e-10, 'Invalid DCM');
```

**Compose rotations:**

```matlab
% Transform from frame A to C via B:
dcm_A2C = dcm_B2C * dcm_A2B;
% Order matters — matrix multiplication is not commutative
```

## Euler Angles

Three successive rotations about specified axes that describe orientation.

**Aerospace Toolbox conventions:**
- Angles are always in **radians** for `angle2dcm`, `dcm2angle`, `angle2quat`, `quat2angle`
- Default sequence is `'ZYX'` (yaw → pitch → roll)
- The function name describes the rotation order: `'ZYX'` rotates about Z first, then Y, then X

**All 12 valid sequences:**

| Type | Sequences |
|------|-----------|
| Tait-Bryan (3 different axes) | ZYX, ZXY, YXZ, YZX, XYZ, XZY |
| Proper Euler (first = last axis) | ZYZ, ZXZ, YXY, YZY, XYX, XZX |

**Common aerospace usage:**
- `'ZYX'` — Yaw-pitch-roll (aircraft attitude, most common)
- `'XYZ'` — Roll-pitch-yaw (some robotics conventions)
- `'ZYZ'` — Orbital mechanics (precession-nutation-spin)

## Gimbal Lock

**What it is:** When the second Euler angle reaches ±90° (for ZYX), the first and third axes align, losing one degree of freedom. The individual angles become indeterminate (only their sum/difference is defined).

**Detection:**

```matlab
[r1, r2, r3] = dcm2angle(dcm, 'ZYX');
if abs(r2) > deg2rad(85)
    % Near gimbal lock — Euler extraction unreliable
    % Use quaternion representation instead
end
```

**Why it matters:**
- `dcm2angle` will return *some* values, but yaw and roll are arbitrary (only yaw+roll or yaw-roll is meaningful)
- Interpolating through gimbal lock produces wild angle jumps
- Control systems using Euler angles can lose controllability

**Solution:** Use quaternions for computation. Convert to Euler only for human display, and warn when near singularity.

## Quaternion Representations

### Aerospace Toolbox Array Format (1×4)

Functions like `dcm2quat`, `quat2dcm`, `angle2quat`, `quat2angle` use a **1×4 row vector**:

```
q = [q0, q1, q2, q3] = [scalar, i, j, k]
```

- `q0` is the scalar (real) part
- `[q1, q2, q3]` is the vector (imaginary) part
- Unit quaternion: `q0² + q1² + q2² + q3² = 1`

### Quaternion Object

The `quaternion` class uses the same scalar-first convention internally:

```matlab
q = quaternion(w, x, y, z);  % scalar w, then vector [x y z]
parts = compact(q);           % returns [w x y z]
```

**Creating quaternion objects:**

```matlab
% From Euler angles (degrees) — must specify sequence AND frame type
q = quaternion([yaw pitch roll], 'eulerd', 'ZYX', 'frame');

% From rotation matrix — must specify 'point' or 'frame'
q = quaternion(R, 'rotmat', 'frame');

% From rotation vector (axis-angle, scaled by angle in radians)
q = quaternion([ax ay az], 'rotvec');
```

**Frame type parameter (`'point'` vs `'frame'`):**
- `'frame'` — The rotation transforms frame axes (passive rotation). This is the standard aerospace convention.
- `'point'` — The rotation transforms points (active rotation).
- These are inverses of each other: `quaternion(R,'rotmat','point')` = conjugate of `quaternion(R,'rotmat','frame')`

### Conversion Between Formats

```matlab
% Quaternion object → 1×4 array (for Aerospace Toolbox functions)
q_obj = quaternion([30 0 0], 'eulerd', 'ZYX', 'frame');
q_array = compact(q_obj);    % [w x y z] — same format as dcm2quat output

% 1×4 array → quaternion object
q_array = dcm2quat(dcm);     % [q0 q1 q2 q3]
q_obj = quaternion(q_array);  % direct construction from 1×4
```

## Quaternion Algebra

**Multiplication (composition):**

```matlab
% Object: q_total = q2 * q1 applies q1 first, then q2
q_total = q_yaw * q_pitch * q_roll;

% Array: use quatmultiply (Aerospace Toolbox)
q_total = quatmultiply(q2, q1);
```

**Inverse (conjugate for unit quaternions):**

```matlab
q_inv = conj(q);  % quaternion object
% For 1×4 array:
q_inv = quatinv(q);   % general inverse (handles non-unit)
q_inv = quatconj(q);  % conjugate (equals inverse for unit quaternions)
```

**Normalization:**

```matlab
q = normalize(q);          % quaternion object
q = quatnormalize(q);      % 1×4 array
```

**Division (relative rotation):**

```matlab
% What rotation takes q1 to q2? Answer: q_rel = q2 / q1
q_rel = quatdivide(q2, q1);  % such that quatmultiply(q_rel, q1) ≈ q2
```

**Exponential and logarithm:**

```matlab
% Logarithm maps unit quaternion to tangent space (pure quaternion)
q_log = quatlog(q);    % [0, θ/2·e] where e is rotation axis, θ is angle

% Exponential maps back
q_back = quatexp(q_log);  % returns unit quaternion

% Power: fractional rotation
q_half = quatpower(q, 0.5);   % half the rotation angle
q_double = quatpower(q, 2);   % double the rotation angle
```

**Norm vs modulus:**

```matlab
n = quatnorm(q);   % squared norm: q0² + q1² + q2² + q3²
m = quatmod(q);    % modulus: sqrt(quatnorm(q))
% For unit quaternions: quatnorm = 1, quatmod = 1
```

**Rotate a vector:**

```matlab
v_rot = quatrotate(q, v);  % rotates 1×3 vector v by quaternion q
% Equivalent to: q * [0,v] * conj(q) (Hamilton product)
```

**Angular distance between two orientations:**

```matlab
d = dist(q1, q2);  % quaternion object — returns radians (0 to pi)
```

## Quaternion Interpolation

### SLERP (Spherical Linear Interpolation)

Produces constant angular velocity between two orientations:

```matlab
q1 = quaternion([0 0 0], 'eulerd', 'ZYX', 'frame');
q2 = quaternion([90 45 0], 'eulerd', 'ZYX', 'frame');
t = linspace(0, 1, 100)';  % must be column vector
q_path = slerp(q1, q2, t);
```

**Properties:**
- Shortest path on the unit sphere (great arc)
- Constant angular speed
- `t=0` gives `q1`, `t=1` gives `q2`
- If `q1` and `q2` are nearly antipodal (angle ≈ 180°), the path is not unique

### Mean Rotation

```matlab
q_array = [q1; q2; q3; q4];  % Nx1 quaternion array
q_avg = meanrot(q_array);    % geodesic mean on SO(3)
```

### Angular Velocity from Quaternion Time Series

```matlab
% q is Nx1 quaternion array sampled at intervals dt
dt = 0.01;  % seconds
omega = angvel(q, dt, 'frame');  % Nx3 angular velocity in rad/s
```

## Rodrigues Vector

The Euler-Rodrigues vector `r` encodes a rotation as:

```
r = e * tan(θ/2)
```

where `e` is the unit rotation axis and `θ` is the rotation angle.

**Properties:**
- 3-element vector (minimal parameterization)
- Composition: not as simple as quaternion multiplication
- **Singular at θ = 180°** (tan(90°) = ∞)
- Useful for: small-angle approximations, optimization (3 parameters vs 4 for quaternion)

**When to use:**
- Optimization problems where minimal parameters matter
- Small perturbation analysis
- Linearized attitude estimation

**When NOT to use:**
- Rotations that may approach 180°
- Interpolation (use SLERP with quaternions)
- Long time integration

## Conversion Map

All representations can be converted to any other via Aerospace Toolbox:

```
         angle2dcm          dcm2quat          quat2rod
Euler ──────────────► DCM ──────────────► Quat ─────────────► Rod
  ▲                    ▲                    ▲                   │
  │    dcm2angle       │    quat2dcm        │    rod2quat       │
  ◄────────────────────◄────────────────────◄───────────────────┘
  │                                                             │
  │                    angle2quat                                │
  ├──────────────────────────────────────────►                  │
  │                    quat2angle                                │
  ◄──────────────────────────────────────────                   │
  │                    angle2rod                                 │
  ├─────────────────────────────────────────────────────────────►
  │                    rod2angle                                 │
  ◄─────────────────────────────────────────────────────────────┘
```

Direct conversions are available between every pair — you never need to go through an intermediate.

----

Copyright 2026 The MathWorks, Inc.

----
