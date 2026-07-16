---
name: matlab-compute-aerospace-environment
description: >
  Compute aerospace environment properties including atmosphere (ISA, COESA,
  NRLMSISE-00, non-standard, CIRA), gravity (spherical harmonic, WGS84, zonal,
  centrifugal), horizontal wind (HWM), magnetic field (WMM, IGRF), geoid height,
  geocentric radius, space weather data, planetary ephemeris, Earth orientation
  (polar motion, nutation, delta-UT1, CIP). Use when computing atmospheric
  density, temperature, pressure, gravity vectors, wind profiles, magnetic field
  components, geoid undulation, solar flux indices, planet positions, or Earth
  orientation parameters for aerospace vehicle analysis, spacecraft environment
  modeling, or navigation corrections.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# Compute Aerospace Environment

Calculate environment properties for aerospace vehicle analysis: atmosphere, gravity, wind, magnetic field, geoid, space weather, planetary ephemeris, and Earth orientation using Aerospace Toolbox functions.

## When to Use

- Computing atmospheric properties (temperature, pressure, density, speed of sound)
- Calculating gravity vectors or acceleration for any planet
- Modeling horizontal wind at altitude
- Getting magnetic field components for navigation or compass correction
- Computing geoid height or geocentric radius
- Reading space weather data for NRLMSISE-00 inputs
- Computing planet or Moon positions (ephemeris)
- Getting Earth orientation parameters (polar motion, nutation, UT1-UTC, CIP)
- Any prompt mentioning: atmosphere model, ISA, COESA, NRLMSISE, pressure, temperature, density, speed of sound, gravity model, WGS84, wind model, HWM, magnetic model, WMM, IGRF, geoid, space weather, solar flux, F10.7, Ap index, planet ephemeris, Moon position, Earth nutation, polar motion, UT1, IERS

## When NOT to Use

- Coordinate frame conversions or rotations — use `matlab-convert-aerospace-coordinates`
- Orbital mechanics or trajectory propagation (use ephemeris for positions, not orbit propagation)
- Aerodynamic coefficient calculations
- Simulink environment model blocks — use Aerospace Blockset 

## Workflow

1. **Identify the quantity needed** — use the decision table below
2. **Call the function** — follow the patterns in this skill for correct syntax
3. **Verify results** — check units and magnitude are physically reasonable

## Decision Table

| Need | Function | Key Input |
|------|----------|-----------|
| Standard atmosphere (quick) | `atmosisa` | altitude (m) |
| 1976 COESA atmosphere | `atmoscoesa` | altitude (m) |
| NRLMSISE-00 (detailed upper atmosphere) | `atmosnrlmsise00` | alt, lat, lon, year, day, UTsec |
| Non-standard atmosphere (MIL-STD) | `atmosnonstd` | alt + positional string args |
| CIRA 1986 reference atmosphere | `atmoscira` | lat, ctype, coord, month |
| Lapse rate atmosphere (custom) | `atmoslapse` | altitude (m) + 9 physical params |
| Pressure altitude | `atmospalt` | pressure (Pa) |
| Horizontal wind (HWM07/14) | `atmoshwm` | lat, lon, alt + name-value |
| Spherical harmonic gravity (any planet) | `gravitysphericalharmonic` | PCPF [x,y,z] (m) |
| WGS84 gravity (Earth, geodetic) | `gravitywgs84` | h, lat (+ lon, method, flags) |
| Zonal harmonic gravity (any planet) | `gravityzonal` | PCPF [x,y,z] (m) |
| Centrifugal acceleration | `gravitycentrifugal` | PCPF [x,y,z] (m) |
| WMM magnetic field | `wrldmagm` | height(m), lat, lon, decimalYear |
| IGRF magnetic field | `igrfmagm` | height(m), lat, lon, decimalYear, generation |
| Geoid height (undulation) | `geoidheight` | lat, lon |
| Geocentric radius | `geocradius` | geocentric lat (deg) |
| Read space weather CSV | `aeroReadSpaceWeatherData` | CSV file path |
| Extract solar flux / Ap indices | `fluxSolarAndGeomagnetic` | datetime or [year,day,UTCsec], MAT file |
| Planet/Moon position and velocity | `planetEphemeris` | Julian date, center, target |
| Earth nutation angles | `earthNutation` | Julian date |
| Moon libration angles | `moonLibration` | Julian date |
| Earth polar motion | `polarMotion` | UTC (Julian date) |
| Celestial Intermediate Pole adjustment | `deltaCIP` | UTC (Julian date) |
| Difference between UT1 and UTC | `deltaUT1` | UTC (Julian date) |
| Read IERS Earth orientation data | `aeroReadIERSData` | folder path |

## Patterns

### Standard and COESA Atmosphere

```matlab
% International Standard Atmosphere
[T, a, P, rho] = atmosisa(1000);

% 1976 COESA (valid 0-1000 km)
[T, a, P, rho] = atmoscoesa(1000);
```

### Pressure Altitude (atmospalt)

Converts pressure (Pa) to altitude (m) using the International Standard Atmosphere.

```matlab
% Pressure altitude at standard sea-level pressure
alt = atmospalt(101325);  % returns 0 m

% Pressure altitude at multiple pressures
alt = atmospalt([101325, 79501, 54048, 26500]);

% Typical use: convert measured pressure to altitude
measuredPressure_Pa = 75000;
pressureAltitude_m = atmospalt(measuredPressure_Pa);
```

Input: pressure in **Pascals**. Output: geometric altitude in **meters** based on 1976 COESA.

### Non-Standard Atmosphere (atmosnonstd)

Uses **positional string arguments** — not name-value pairs.

**Profile type** (single altitude extreme):
```matlab
[T, a, P, rho] = atmosnonstd(height, 'Profile', extremeParam, frequency, extremeAltitude)
```

**Envelope type** (altitude range extreme — NO extremeAltitude argument):
```matlab
[T, a, P, rho] = atmosnonstd(height, 'Envelope', extremeParam, frequency)
```

Optional trailing args: `action` ('Warning'|'Error'|'None'), `specification` ('310'|'210c').

```matlab
% Profile: high density, 1% of time, at 5 km altitude (extremeAltitude is NUMERIC)
[T, a, P, rho] = atmosnonstd(5000, 'Profile', 'High density', '1%', 5);

% Envelope: high pressure, 20% of time, MIL-STD-210C
[T, a, P, rho] = atmosnonstd([1000; 11000; 20000], 'Envelope', ...
    'High pressure', '20%', 'None', '210c');
```

Valid `extremeParam`: 'High temperature', 'Low temperature', 'High density', 'Low density', 'High pressure', 'Low pressure'

Valid `frequency`: 'Extreme values', '1%', '5%', '10%', '20%'

Valid `extremeAltitude` (Profile only, **numeric**): 5, 10, 20, 30, 40

### CIRA 1986 Model

```matlab
% By geopotential height, monthly mean, October
[T, P, zonalWind] = atmoscira(45, 'GPHeight', 20000, 'Monthly', 10);

% By pressure level
[T, alt, zonalWind] = atmoscira(45, 'Pressure', 101300, 'Monthly', 1);
```

Arguments: `(latitude, ctype, coord, mtype, month)` where `ctype` is 'Pressure' or 'GPHeight'.

### NRLMSISE-00

```matlab
% Basic call (uses default flux values)
[T, rho] = atmosnrlmsise00(altitude, latitude, longitude, year, dayOfYear, UTseconds);

% With flux data and no anomalous oxygen
[T, rho] = atmosnrlmsise00(altitude, lat, lon, year, dayOfYear, UTsec, ...
    f107Average, f107Daily, magneticIndex, 'NoOxygen');
```

Output: `T` is N-by-2 [exospheric temp, local temp]. `rho` is N-by-9 (densities).

### Lapse Rate Atmosphere (atmoslapse)

Requires **10 positional arguments** — not just altitude. All physical parameters must be specified explicitly.

```matlab
% TEMPLATE — not executable (shows calling convention)
[T, a, P, rho] = atmoslapse(altitude, g, gamma, R, lapseRate, ...
    heightTroposphere, heightTropopause, density0, pressure0, temperature0);

% Example: ISA conditions
[T, a, P, rho] = atmoslapse([0 5000 11000 20000], ...
    9.80665, 1.4, 287.0531, 0.0065, 11000, 20000, 1.225, 101325, 288.15);
```

Arguments: `(height, g, heatRatio, gasConstant, lapseRate, hTroposphere, hTropopause, rho0, P0, T0)`. Use for custom planetary atmospheres or non-standard sea-level conditions.

### Horizontal Wind Model (atmoshwm)

Uses **name-value arguments**. Returns M-by-2 array [meridional, zonal] in m/s.

```matlab
% Total wind with Ap index
wind = atmoshwm(-45, -85, 25000, model='total', day=150, ...
    seconds=11*3600, apindex=80);

% Quiet wind at multiple altitudes (day/seconds must match array size)
wind = atmoshwm([50; 50], [-20; -20], [100000; 150000], ...
    model='quiet', day=[30; 30], seconds=[0; 0]);

% Disturbed wind
wind = atmoshwm(70, -65, 150000, model='disturbance', day=166, seconds=0);
```

Name-value options: `model` ('quiet'|'disturbance'|'total'), `day`, `seconds`, `apindex`, `version` ('14'|'07').

### Gravity: Spherical Harmonic

Input is **Planet-Centered Planet-Fixed (PCPF) [x,y,z] coordinates in meters** — NOT lat/lon/alt.

```matlab
% Earth: 25,000 m over South Pole (z-axis = polar axis)
[gx, gy, gz] = gravitysphericalharmonic([0, 0, -(6356752 + 25000)]);

% Mars GMM2B: equator + pole
pos = [3396200 + 15000, 0, 0;   % equator
       0, 0, 3376200 + 11000];  % north pole
[gx, gy, gz] = gravitysphericalharmonic(pos, 'GMM2B');
```

Models: 'EGM2008' (default), 'EGM96', 'LP100K', 'LP165P', 'GMM2B', 'EIGENGL04C', 'Custom'.

Note: Polar positions on oblate bodies will trigger a "Radial position is less than equatorial radius" warning — this is expected (polar radius < equatorial radius) and results are still valid.

### Gravity: WGS84

Uses **geodetic coordinates** (height in meters, latitude/longitude in degrees).

For the Exact method with optional effects, pass flags as a **single vector** `[noatm, nocent, prec, jd]`:

```matlab
% Taylor series (default) — only h and lat, no method string
g = gravitywgs84(1000, 45);

% CloseApprox — requires lon as 3rd argument
g = gravitywgs84(1000, 45, 20, 'CloseApprox');

% Exact with precession — requires lon + flag vector
[gn, gt] = gravitywgs84(1000, 0, 20, 'Exact', [false, false, true, 2451545]);
```

Calling conventions:
- **Default (Taylor series):** `gravitywgs84(h, lat)` — do NOT pass 'TaylorSeries' as a string
- **CloseApprox:** `gravitywgs84(h, lat, lon, 'CloseApprox')` — requires lon
- **Exact:** `gravitywgs84(h, lat, lon, 'Exact', [noatm, nocent, prec, jd])` — requires lon + flag vector

Flag vector `[noatm, nocent, prec, jd]`:
- `noatm`: true = exclude atmosphere correction
- `nocent`: true = exclude centrifugal effect
- `prec`: true = include precession
- `jd`: Julian date (0 = no precession date)

### Gravity: Zonal Harmonic

Input is **PCPF [x,y,z] in meters**. Degree is a numeric scalar.

```matlab
% Earth, 4th degree, at equator surface
Re = 6378137;
[gx, gy, gz] = gravityzonal([Re, 0, 0], 'Earth', 4);

% Mars at two positions
[gx, gy, gz] = gravityzonal([3396200+15000, 0, 0; 0, 0, 3376200+11000], 'Mars');
```

### Gravity: Centrifugal

Input is **PCPF [x,y,z] in meters**.

```matlab
% Earth at equator surface
[gx, gy, gz] = gravitycentrifugal([6378137, 0, 0]);

% Mars
[gx, gy, gz] = gravitycentrifugal([3396200, 0, 0], 'Mars');
```

### Magnetic Field Models

Both `wrldmagm` and `igrfmagm` take height in **meters**, latitude/longitude in degrees, and decimal year. Use `decyear` to convert calendar dates.

```matlab
% WMM-2025
[XYZ, H, D, I, F] = wrldmagm(1000, 40.44, -79.99, decyear(2025,7,4), '2025');

% IGRF-14
[XYZ, H, D, I, F] = igrfmagm(3000, 41.50, -81.69, decyear(2028,7,4), 14);
```

Output: XYZ = [North, East, Down] in nT; H = horizontal intensity; D = declination (deg); I = inclination (deg); F = total intensity (nT).

### Geoid Height and Geocentric Radius

```matlab
% Geoid undulation (EGM96 default) — longitude must be [0, 360]
N = geoidheight(42.4, 289.0);

% EGM2008
N = geoidheight(42.4, 289.0, 'EGM2008');

% Geocentric radius at multiple latitudes (input: geocentric lat in degrees)
r = geocradius([0, 45, 90]);           % default WGS84
r = geocradius([0, 45, 90], 'WGS84');  % explicit model
```

### Planetary Ephemeris and Earth Orientation

Ephemeris functions require data from `aeroDataPackage`. All take **Julian dates** as time input.

```matlab
% Planet/Moon position and velocity (km, km/s by default)
jd = juliandate(2022, 10, 27, 12, 0, 0);
[pos, vel] = planetEphemeris(jd, 'Earth', 'Moon');
[pos, vel] = planetEphemeris(jd, 'SolarSystem', 'Mars', '430', 'AU');

% Earth nutation (radians)
[angles, rates] = earthNutation(jd);  % angles = [dpsi, depsilon]

% Moon libration (radians)
[angles, rates] = moonLibration(jd);  % 3 Euler angles + rates

% Earth polar motion (radians) — input is UTC as Julian date
utc = juliandate(2020, 1, 1);
[pm, pmError] = polarMotion(utc);  % pm = [xp, yp]

% Celestial Intermediate Pole adjustment (radians)
[dcip, dcipError] = deltaCIP(utc);  % dcip = [dX, dY]

% UT1-UTC difference (seconds)
[dut1, dut1Error] = deltaUT1(utc);
```

Valid `planetEphemeris` targets/centers: 'Sun', 'Mercury', 'Venus', 'Earth', 'Moon', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto', 'SolarSystem', 'EarthMoon'.

Models: '405' (default), '421', '423', '430', '432t'.

Note: `polarMotion`, `deltaCIP`, and `deltaUT1` use IERS data from `aeroiersdata.mat` (shipped) or a custom source. To get updated IERS data:

```matlab
% Download latest Earth orientation data and save as MAT file
iersFile = aeroReadIERSData(pwd);
% Then pass to Earth orientation functions via Source name-value
[pm, pmError] = polarMotion(utc, Source=iersFile);
[dcip, dcipError] = deltaCIP(utc, Source=iersFile);
[dut1, dut1Error] = deltaUT1(utc, Source=iersFile);
```

### Space Weather Pipeline

The full pipeline for realistic NRLMSISE-00 inputs:

```matlab
% Step 1: Read CSV (downloaded from CelesTrack) into MAT file
% TEMPLATE — requires user-provided CSV file
matFile = aeroReadSpaceWeatherData('spaceWeatherFile.csv');

% Step 2: Extract flux and magnetic indices for a specific date/time
dt = datetime(2022, 10, 27, 6, 30, 0, 'TimeZone', 'UTC');
[f107avg, f107daily, magIdx] = fluxSolarAndGeomagnetic(dt, matFile, ...
    F107ExtrapMethod='constant', MagneticIndexExtrapMethod='constant');

% Step 3: Feed into NRLMSISE-00
dayOfYear = day(dt, 'dayofyear');
UTsec = seconds(timeofday(dt));
[T, rho] = atmosnrlmsise00(400e3, 45, -50, dt.Year, dayOfYear, UTsec, ...
    f107avg, f107daily, magIdx, 'NoOxygen');
```

Notes:
- `aeroReadSpaceWeatherData` takes a **user-provided CSV** (CelesTrack format) — no sample ships with the toolbox
- It returns a **MAT file containing the space weather data** for use with `fluxSolarAndGeomagnetic`
- The pre-built `aeroSpaceWeatherData.mat` (via `which('aeroSpaceWeatherData.mat')`) is available if no CSV is provided
- `fluxSolarAndGeomagnetic` accepts either `(datetime, matFile)` or `(year, dayOfYear, UTCseconds, matFile)`

## Common Mistakes

| Mistake | Why It Fails | Correct Approach |
|---------|-------------|-----------------|
| Passing lat/lon/alt to `gravitysphericalharmonic` | Expects PCPF [x,y,z] in meters | Convert to Cartesian: equator surface = `[Re, 0, 0]`, pole = `[0, 0, Rp]` |
| Name-value pairs for `atmosnonstd` | Uses positional strings, not NV | `atmosnonstd(h, 'Envelope', 'High pressure', '20%')` |
| Separate boolean args to `gravitywgs84` Exact | Flags must be a single vector | `gravitywgs84(h, lat, lon, 'Exact', [noatm, nocent, prec, jd])` |
| Passing 'TaylorSeries' as method string | Method argument is third argument when required | Use 2-arg form: `gravitywgs84(h, lat)` — no method string |
| Calling `gravitywgs84(h, lat, 'CloseApprox')` without lon | CloseApprox requires longitude | `gravitywgs84(h, lat, lon, 'CloseApprox')` |
| Including `extremeAltitude` with Envelope type | Only valid for Profile type | Omit for Envelope: `atmosnonstd(h, 'Envelope', param, freq)` |
| Using `atmosnrlmsise00` for wind | Wrong function | Use `atmoshwm` for horizontal wind |
| Calling `gravitywgs84` for centrifugal effect | No centrifugal-only mode | Use `gravitycentrifugal([x, y, z])` |
| Wrong function name `gravityzonalharmonic` | Does not exist | Use `gravityzonal` |
| Passing string degree to `gravityzonal` | Expects numeric scalar | `gravityzonal(coords, 'Earth', 4)` not `'4thDegree'` |
| Ignoring `aeroReadSpaceWeatherData` output | Returns a MAT file containing space weather data | Pass the returned MAT file to `fluxSolarAndGeomagnetic` |

## Conventions

- **Height units:** All atmosphere, gravity, and magnetic functions use **meters** (not km, not feet)
- **Latitude/longitude:** Degrees for geodetic functions; PCPF [x,y,z] meters for `gravitysphericalharmonic`, `gravityzonal`, `gravitycentrifugal`
- **Decimal year:** Use `decyear(year, month, day)` for magnetic model date inputs
- **Time:** `day` = day of year (1-366); `seconds` = seconds since midnight UTC
- **PCPF coordinates:** x-axis through 0N/0E, y-axis through 0N/90E, z-axis through North Pole
- **`geoidheight` longitude:** Must be in [0, 360] degrees (east positive). Use `mod(lon, 360)` to convert from [-180, 180]
- **South Pole in PCPF:** `[0, 0, -(Rp + altitude)]` where Rp is polar radius
- **Equator in PCPF:** `[Re + altitude, 0, 0]` where Re is equatorial radius

----

Copyright 2026 The MathWorks, Inc.

----
