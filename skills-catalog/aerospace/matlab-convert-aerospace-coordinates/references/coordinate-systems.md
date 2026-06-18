# Aerospace Coordinate Systems

## Fundamental Frames

### Earth-Centered Earth-Fixed (ECEF)

- **Origin:** Earth's center of mass
- **X-axis:** Points to intersection of prime meridian and equator
- **Y-axis:** Completes right-hand system (90°E on equator)
- **Z-axis:** Points toward geographic North Pole (along Earth's spin axis)
- **Rotates with Earth** — a fixed point on Earth has constant ECEF coordinates
- **Use for:** Ground-based positions, GPS coordinates, terrestrial navigation

### Earth-Centered Inertial (ECI)

- **Origin:** Earth's center of mass
- **X-axis:** Points toward vernal equinox (mean equinox of J2000.0 epoch)
- **Y-axis:** Completes right-hand system in equatorial plane
- **Z-axis:** Points toward celestial North Pole
- **Does NOT rotate with Earth** — Earth rotates beneath this frame
- **Use for:** Orbital mechanics, satellite tracking, celestial navigation
- **Time-dependent:** Converting to/from ECI requires knowing Earth's orientation at a specific UTC time

### Geodetic Coordinates (LLA)

- **Latitude:** Angle between equatorial plane and surface normal (not center-of-Earth line)
- **Longitude:** Angle east of prime meridian
- **Altitude:** Height above reference ellipsoid (WGS84)
- **Not a Cartesian frame** — curvilinear coordinates on an ellipsoid
- **Use for:** Expressing positions on or near Earth's surface

### Geocentric Coordinates

- **Geocentric latitude:** Angle between equatorial plane and the line from Earth's center to the point
- **Differs from geodetic latitude** because Earth is oblate (flattened at poles)
- **Difference:** Up to ~0.19° at 45° latitude
- **Use for:** Some gravity models, simple orbital calculations

### North-East-Down (NED)

- **Origin:** A reference point on Earth's surface (local tangent plane)
- **X-axis:** Points North (geodetic north along meridian)
- **Y-axis:** Points East
- **Z-axis:** Points Down (toward Earth center, perpendicular to ellipsoid)
- **Local frame** — orientation depends on the origin's latitude/longitude
- **Use for:** Navigation, flight dynamics, expressing local velocity/acceleration

### Body Frame

- **Origin:** Vehicle center of mass (or reference point)
- **X-axis (x_b):** Points forward (out the nose)
- **Y-axis (y_b):** Points right (starboard wing)
- **Z-axis (z_b):** Points down (through belly)
- **Fixed to vehicle** — rotates with it
- **Use for:** Expressing forces and moments acting on the vehicle, inertia tensors

### Wind Frame

- **Origin:** Vehicle center of mass
- **X-axis (x_w):** Aligned with velocity vector (aerodynamic velocity)
- **Y-axis (y_w):** Perpendicular, in a horizontal-like plane
- **Z-axis (z_w):** Completes right-hand system
- **Related to body frame by angle of attack (α) and sideslip (β)**
- **Use for:** Expressing aerodynamic forces (lift is in z_w, drag opposes x_w)

### Stability Frame

- **Origin:** Vehicle center of mass
- **X-axis:** Projection of velocity vector onto the body XZ-plane
- **Y-axis:** Same as body Y-axis
- **Z-axis:** Completes right-hand system
- **Related to body frame by angle of attack (α) only** — no sideslip rotation
- **Use for:** Stability derivatives, longitudinal aerodynamic analysis

### Flat Earth Frame

- **Origin:** A reference point defined by `[lat0, lon0]` and heading `psi0`
- **Approximation:** Treats Earth as locally flat (valid within ~100 km)
- **X-axis:** Direction defined by `psi0` (0 = North)
- **Y-axis:** Perpendicular to X in local horizontal
- **Z-axis:** Points down
- **Use for:** Short-range simulations, autopilot design, local navigation

## Decision Guide: Choosing the Right Frame

| I want to... | Use this frame | Key function |
|--------------|---------------|--------------|
| Express a GPS position | LLA | — |
| Compute distance between two Earth positions | ECEF | `lla2ecef` |
| Track a satellite orbit | ECI | `lla2eci`, `ecef2eci` |
| Express local velocity/heading | NED | `dcmecef2ned` |
| Apply aerodynamic forces | Wind | `dcmbody2wind` |
| Analyze longitudinal stability | Stability | `dcmbody2stability` |
| Simulate short-range flight | Flat Earth | `lla2flat` |
| Express vehicle attitude | Body | `angle2dcm` |
| Compute gravity at a point | ECEF or LLA | `gravitywgs84` |

## Identifying Which Frame You're In

Ask these questions:

1. **Does the data rotate with Earth?** → ECEF. Does it stay fixed while Earth rotates? → ECI.
2. **Is it latitude/longitude/altitude?** → LLA (geodetic). Watch for geocentric latitude.
3. **Is origin at vehicle CG?** → Body, wind, or stability frame.
4. **Is X along the velocity vector?** → Wind frame. Along the nose? → Body frame.
5. **Is it a local tangent plane?** → NED (if Z=down, X=north) or flat Earth (if X=heading direction).

## Axis Convention: Right-Hand Rule

All aerospace frames follow the right-hand rule:
- Curl fingers from X toward Y → thumb points along Z
- Positive rotations: right-hand curl around the axis

## Common Pitfalls

- **NED vs ENU:** Aerospace convention is NED (Z-down). Navigation Toolbox uses ENU (Z-up). Do not mix.
- **Geodetic vs geocentric latitude:** `lla2ecef` expects geodetic. If you have geocentric, convert first with `geoc2geod`.
- **LLA column order:** Always `[lat, lon, alt]` — not `[lon, lat, alt]`.
- **ECI is epoch-dependent:** The vernal equinox precesses. Aerospace Toolbox uses IAU-2000/2006 by default.
- **Body frame is vehicle-specific:** The axes are defined by the vehicle, not by external references.

----

Copyright 2026 The MathWorks, Inc.

----
