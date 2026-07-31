---
name: matlab-compute-gnss-position
description: >
  Computes multi-constellation Global Positioning System (GPS) or Global
  Navigation Satellite System (GNSS) positions from RINEX v3 data using
  rinexread, gnssmeasurements, receiverposition, and gnssoptions. Filters by constellation, elevation
  mask, C/N0, and observation code. Reports DOP, scatter RMS, and satellite
  count. Use when processing GNSS data, computing positions from RINEX
  files, analyzing accuracy, comparing constellations, or evaluating
  satellite geometry. Do NOT use for carrier-phase RTK/PPP, IMU fusion,
  orbit propagation, NMEA streaming, or RINEX v4.
metadata:
  author: MathWorks
  version: "1.0"
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
---

# Multi-Constellation GNSS Positioning

Pseudorange-based single-point positioning (SPP) from RINEX v3 data. Supports
GPS, GLONASS, Galileo, BeiDou, QZSS, NavIC/IRNSS, and SBAS.

**Requires:** Navigation Toolbox R2026a or later.

## When to Use

- Processing RINEX observation/navigation files into position solutions
- Computing multi-constellation receiver positions
- Analyzing positioning accuracy, DOP, and satellite geometry
- Comparing single-constellation vs multi-constellation performance
- Evaluating the effect of processing options (elevation mask, C/N0, corrections)
- Teaching or demonstrating GNSS positioning concepts

## When NOT to Use

- Carrier-phase positioning (RTK, PPP, ambiguity resolution)
- Sensor fusion with IMU — use `matlab-system-identification` or INS filters
- Satellite orbit propagation or scenario simulation — use Aerospace Toolbox
- Real-time NMEA stream processing — use `nmeaParser` directly
- RINEX v4 files — nested struct format requires different handling

## Must-Follow Rules

- **Always use `rinexinfo` first** to confirm RINEX v3 and inspect available constellations/observation codes before reading
- **Use the correct observation code per constellation** — wrong code produces empty measurements (see default codes table)
- **Pre-filter satellites with missing navigation data** before calling `gnssmeasurements` — it errors on any satellite without matching nav data
- **Always apply atmospheric corrections** via `gnssoptions` — uncorrected SPP has >20 m vertical error
- **Use `tiledlayout`/`nexttile`** for multi-panel figures (never `subplot`)
- **Label all axes** with units and include titles on every plot
- **Report DOP quality** — HDOP > 6 is degraded, HDOP > 20 is unusable
- **Skyplot requires a full-size figure** — never place `skyplot` inside a tile of a compact `tiledlayout`. Use a dedicated `figure` for the skyplot, or if it must share a layout, size the figure so the skyplot tile is at least 560×560 pixels. Skyplots in small tiles produce unreadable, overlapping satellite markers.

## Workflow

1. **Inspect RINEX files** — call `rinexinfo` on each file to confirm v3, identify constellations, and list available observation codes. Use `SatelliteSystem` and `Descriptors` to iterate over `ObservationTypes`:
   ```matlab
   info = rinexinfo('rover.obs');
   for i = 1:numel(info.ObservationTypes)
       fprintf('%s: %s\n', info.ObservationTypes(i).SatelliteSystem, ...
           strjoin(info.ObservationTypes(i).Descriptors, ', '));
   end
   ```
2. **Resolve observation codes** — confirm default codes exist in the RINEX data; if not, suggest alternatives from the header
3. **Gather processing options** — constellation selection, elevation mask (degrees, default 10), C/N0 threshold (dB-Hz, default 0), observation code overrides
4. **Read data** — call `rinexread` for observation and navigation files
5. **Extract measurements** — call `gnssmeasurements` per constellation with the confirmed observation code; pre-filter observation data to remove satellites without matching nav data
6. **Filter by C/N0** — remove rows from observation timetable where signal strength column falls below threshold before calling `gnssmeasurements`
7. **Validate constellations** — solve each constellation independently first; if any produces wildly wrong positions (>1 km error, extreme altitudes), exclude it from the combination
8. **Combine constellations** — vertically concatenate validated measurement timetables: `combinedMeas = [gpsMeas; galMeas; ...]`
9. **Apply elevation mask** — compute initial position from one epoch, use `lookangles` to get satellite elevations, remove satellites below mask
10. **Solve position** — call `receiverposition` with `gnssoptions` for atmospheric corrections
11. **Report metrics** — per-epoch (HDOP, VDOP, satellite count) and aggregate (scatter RMS, mean DOP)
12. **Visualize** — skyplot, position time series, DOP and satellite count panels
13. **(Optional) Ground truth** — if user provides LLA, compute ENU error via `lla2enu`

## Default Observation Codes (Band 1 Preferred)

**Prefer frequency band 1 codes across all constellations.** Consistent band-1
codes produce more robust multi-constellation solutions by avoiding inter-frequency bias.

| Constellation | RINEX Field | Default Code | C/N0 Column | Notes |
|---------------|-------------|-------------|-------------|-------|
| GPS | `.GPS` | `"C1C"` | `S1C` | L1 C/A (band 1) |
| GLONASS | `.GLONASS` | `"C1C"` | `S1C` | L1 C/A (band 1) |
| Galileo | `.Galileo` | `"C1C"` | `S1C` | E1; use `"C1X"` if `C1C` unavailable |
| BeiDou | `.BeiDou` | `"C1P"` or `"C1X"` | `S1P` or `S1X` | Band 1 preferred (C1P, C1X, or any C1*) |
| QZSS | `.QZSS` | `"C1C"` | `S1C` | L1 C/A (band 1) |
| NavIC/IRNSS | `.NavIC` | `"C5A"` | `S5A` | L5 SPS (only band available) |
| SBAS | `.SBAS` | `"C1C"` | `S1C` | L1 C/A (band 1) |

**C/N0 column pattern:** Replace the `C` prefix in the observation code with `S` (e.g., `C1C` → `S1C`, `C1P` → `S1P`).

**Band-1 codes may have higher NaN rates** than higher-band alternatives but produce
more robust positions in multi-constellation solutions. Always check code availability
with `rinexinfo` and prefer band 1.

## Processing Defaults

| Parameter | Default | Units | Valid Range |
|-----------|---------|-------|-------------|
| Constellation selection | All available | — | Any subset of supported systems |
| Elevation mask | 10 | degrees | 0–90 |
| C/N0 threshold | 0 (no filtering) | dB-Hz | 0–60 |
| Observation code | Per-constellation default | — | Must exist in RINEX observation fields |

> **Elevation mask and C/N0 filtering are not independent in urban environments.** C/N0 filtering typically removes the same low-elevation, multipath-affected satellites. Applying both rarely improves results beyond C/N0 filtering alone. Elevation mask is most effective when the receiver does not report signal strength.

## Key Functions

| Function | Purpose |
|----------|---------|
| `rinexinfo` | Inspect RINEX file metadata (version, systems, obs types) without reading |
| `rinexread` | Read RINEX v3 observation and navigation files |
| `gnssmeasurements` | Extract pseudorange, satellite position, clock bias from obs+nav data |
| `gnssoptions` | Configure atmospheric corrections and bias accuracy |
| `gnssIonosphere` | Klobuchar ionospheric delay model |
| `gnssTroposphere` | Saastamoinen tropospheric delay model |
| `receiverposition` | Weighted least-squares position solution; returns `[pos, vel, hdop, vdop, info]` |
| `lookangles` | Satellite azimuth, elevation, visibility from receiver position |
| `skyplot` | Polar plot of satellite positions with constellation grouping |
| `lla2enu` | Geodetic to local ENU coordinate conversion (for ground truth error) |

## Patterns

### GPS-Only Positioning

```matlab
dataDir = fullfile(matlabroot, 'toolbox', 'nav', 'positioning', ...
    'core', 'positioningdata');

obsData = rinexread(fullfile(dataDir, ...
    'GODS00USA_R_20211750000_01H_30S_MO.rnx'));
gpsNav = rinexread(fullfile(dataDir, ...
    'GODS00USA_R_20211750000_01D_GN.rnx'));

gpsMeas = gnssmeasurements(obsData.GPS, gpsNav.GPS);
opts = gnssoptions( ...
    Ionosphere=gnssIonosphere("klobuchar"), ...
    Troposphere=gnssTroposphere("saastamoinen"));

[recPos, recVel, hdop, vdop, info] = receiverposition(gpsMeas, opts);
```

### Multi-Constellation (GPS + Galileo)

```matlab
galNav = rinexread(fullfile(dataDir, ...
    'GODS00USA_R_20211750000_01D_EN.rnx'));

gpsMeas = gnssmeasurements(obsData.GPS, gpsNav.GPS);
galMeas = gnssmeasurements(obsData.Galileo, galNav.Galileo, "C1X");

combinedMeas = [gpsMeas; galMeas];
[recPos, recVel, hdop, vdop] = receiverposition(combinedMeas, opts);
```

### Pre-Filter Satellites Missing Navigation Data

BeiDou and other constellations may have observed satellites without matching
navigation messages. `gnssmeasurements` errors if any satellite lacks nav data.

```matlab
bdsNav = rinexread(fullfile(dataDir, ...
    'GODS00USA_R_20211750000_01D_CN.rnx'));

% Find satellite IDs present in both obs and nav
obsIDs = unique(obsData.BeiDou.SatelliteID);
navIDs = unique(bdsNav.BeiDou.SatelliteID);
validIDs = intersect(obsIDs, navIDs);

% Filter observation data to valid satellites only
bdsObs = obsData.BeiDou(ismember(obsData.BeiDou.SatelliteID, validIDs), :);
bdsMeas = gnssmeasurements(bdsObs, bdsNav.BeiDou, "C1X");  % Use C1P or C1X or any C1* (band 1 preferred)
```

### C/N0 Signal Strength Filtering

Filter weak signals before extracting measurements. The C/N0 column name
follows the pattern: replace the `C` prefix of the observation code with `S`.

```matlab
% Filter GPS observations with C/N0 < 30 dB-Hz
cn0Threshold = 30;
gpsObs = obsData.GPS;
gpsObs = gpsObs(gpsObs.S1C >= cn0Threshold, :);  % S1C corresponds to C1C

gpsMeas = gnssmeasurements(gpsObs, gpsNav.GPS);
```

### Elevation Mask Filtering

Elevation filtering requires a position estimate. Use an initial fix from one
epoch, then apply `lookangles` to filter low-elevation satellites.

```matlab
% Remove rows with non-finite satellite positions (can occur in multi-GNSS data)
validRows = all(isfinite(combinedMeas.SatellitePosition), 2);
combinedMeas = combinedMeas(validRows, :);

% Get initial position from first epoch (unfiltered)
[initPos] = receiverposition(combinedMeas);
recLLA = initPos(1,:);  % [lat lon alt]

% Get unique epochs
epochs = unique(combinedMeas.Time);
filteredMeas = timetable();

for i = 1:numel(epochs)
    epochMeas = combinedMeas(combinedMeas.Time == epochs(i), :);
    satPos = epochMeas.SatellitePosition;
    [~, el, vis] = lookangles(recLLA, satPos, elevationMask);
    filteredMeas = [filteredMeas; epochMeas(vis, :)]; %#ok<AGROW>
end
```

### Atmospheric Corrections

```matlab
opts = gnssoptions( ...
    Ionosphere=gnssIonosphere("klobuchar"), ...
    Troposphere=gnssTroposphere("saastamoinen"));

[recPos, recVel, hdop, vdop, info] = receiverposition(combinedMeas, opts);
% info.ClockBias, info.ClockDrift, info.TDOP also available
```

### Quality Metrics

```matlab
% Per-epoch metrics from receiverposition outputs
nSats = arrayfun(@(t) sum(combinedMeas.Time == t), unique(combinedMeas.Time));

% Aggregate scatter RMS (no ground truth needed)
meanPos = mean(recPos, 1, 'omitnan');
enu = lla2enu(recPos, meanPos, 'ellipsoid');
hRMS = rms(vecnorm(enu(:,1:2), 2, 2));  % Horizontal scatter
vRMS = rms(enu(:,3));                     % Vertical scatter

fprintf('Horizontal scatter RMS: %.2f m\n', hRMS);
fprintf('Vertical scatter RMS:   %.2f m\n', vRMS);
fprintf('Mean HDOP: %.2f\n', mean(hdop, 'omitnan'));
fprintf('Mean VDOP: %.2f\n', mean(vdop, 'omitnan'));
```

**Choosing a C/N0 threshold.** Sweep a small set of thresholds (e.g., 25, 30, 35, 40 dB-Hz) and use the appropriate quality signal to select the best value:

| Scenario | Quality signal | Stop when |
|---|---|---|
| Ground truth available | H RMS and V RMS vs truth | Improvement plateaus or epoch loss is unacceptable |
| No ground truth, static receiver | Position scatter RMS | Scatter plateaus or epoch loss is significant |
| No ground truth, kinematic receiver | HDOP and valid epoch count | HDOP degrades or epoch loss is significant |

C/N0 filtering typically improves vertical accuracy more than horizontal. Persistent horizontal errors after filtering are structural multipath that SPP cannot resolve. Note: scatter RMS is only meaningful for static receivers — for a moving receiver it reflects vehicle trajectory, not positioning error.

### Ground Truth Comparison (Optional)

```matlab
% User provides known ground truth LLA
truthLLA = [39.020734 -76.826657 -8.95];  % Example: GODS station

enuError = lla2enu(recPos, truthLLA, 'ellipsoid');
error2D = vecnorm(enuError(:,1:2), 2, 2);
error3D = vecnorm(enuError, 2, 2);

fprintf('2D RMS error: %.2f m\n', rms(error2D));
fprintf('3D RMS error: %.2f m\n', rms(error3D));
fprintf('Mean East error:  %.2f m\n', mean(enuError(:,1)));
fprintf('Mean North error: %.2f m\n', mean(enuError(:,2)));
fprintf('Mean Up error:    %.2f m\n', mean(enuError(:,3)));
```

### Visualization

```matlab
% Satellite skyplot — always in its own dedicated figure (never inside tiledlayout).
figure;
epochs = unique(combinedMeas.Time);
epoch1 = combinedMeas(combinedMeas.Time == epochs(1), :);
satPos1 = epoch1.SatellitePosition;
[az, el] = lookangles(recPos(1,:), satPos1);
skyplot(az, el, string(epoch1.SatelliteID))
title('Satellite Skyplot — First Epoch')

% Multi-panel metrics (separate figure)
figure;
t = tiledlayout(2, 2);
title(t, 'GNSS Positioning Metrics')

nexttile
plot(epochs, hdop, 'b-', epochs, vdop, 'r-', 'LineWidth', 1.5)
legend('HDOP', 'VDOP')
ylabel('DOP')
title('Dilution of Precision')
grid on

nexttile
plot(epochs, nSats, 'k-', 'LineWidth', 1.5)
ylabel('Count')
title('Satellites Used per Epoch')
grid on

nexttile
plot(epochs, recPos(:,1), 'b-', 'LineWidth', 1.5)
ylabel('Latitude (deg)')
title('Position — Latitude')
grid on

nexttile
plot(epochs, recPos(:,3), 'b-', 'LineWidth', 1.5)
ylabel('Altitude (m)')
title('Position — Altitude')
grid on
```

### Iterative Refinement

Store results across runs to compare processing configurations.

```matlab
% Initialize or append to run history
if ~exist('runHistory', 'var')
    runHistory = table('Size', [0 6], ...
        'VariableTypes', ["string","double","double","double","double","double"], ...
        'VariableNames', ["Config","MeanHDOP","MeanVDOP","HorizRMS","VertRMS","MeanSats"]);
end

newRow = table(configLabel, mean(hdop,'omitnan'), mean(vdop,'omitnan'), ...
    hRMS, vRMS, mean(nSats), ...
    'VariableNames', runHistory.Properties.VariableNames);
runHistory = [runHistory; newRow];
disp(runHistory)
```

## Gotchas

- **`skyplot` in a compact tiledlayout is unreadable.** Satellite markers and labels overlap when the axes are smaller than the default figure size. Always give `skyplot` its own dedicated figure. If you must include it in a tiledlayout, size the figure so the skyplot tile is at least 560×560 pixels.
- **`gnssmeasurements` errors on missing nav data.** If any observed satellite ID is absent from the navigation timetable, the function throws an error. Always pre-filter observation data to satellites that have matching navigation messages using `intersect` on satellite IDs.
- **Non-finite satellite positions in multi-GNSS data.** Some rows from `gnssmeasurements` may have NaN/Inf in `SatellitePosition` or `Pseudorange`. Filter these before calling `lookangles` or `receiverposition`: `validRows = all(isfinite(meas.SatellitePosition), 2);`
- **Validate each constellation independently before combining.** A constellation with poor pseudorange quality (e.g., heavy urban multipath) can corrupt the entire multi-constellation solution. Test each system alone first — if its standalone position is wildly wrong (>1 km error or extreme altitude), exclude it or try a different observation code.
- **Constellation standalone failure is not always recoverable.** Any constellation can produce wildly wrong altitudes (e.g., ±tens of km) even when other constellations give consistent positions at the same location. The root cause may be receiver-specific pseudorange biases, poor satellite geometry, or incomplete clock corrections — and is not always diagnosable from the RINEX files alone. If a constellation fails standalone validation and C/N0 filtering does not fix it, exclude it rather than continuing to tune parameters.
- **Prefer band-1 observation codes for all constellations.** Consistent band-1 codes (C1C for GPS/GLONASS/Galileo/QZSS, C1P or C1X for BeiDou) produce more robust multi-constellation solutions. Higher-band codes may have more data but can degrade accuracy.
- **Observation code varies by receiver.** Galileo may use `"C1X"` or `"C1C"` depending on the receiver. Always check with `rinexinfo` first.
- **C/N0 filtering happens on the observation timetable, not the measurements timetable.** Filter `obsData.GPS` rows by the `S1C` column before passing to `gnssmeasurements`.
- **Elevation mask needs a position estimate.** You cannot filter by elevation before computing a position. Use an initial unfiltered fix, then apply `lookangles` to identify low-elevation satellites.
- **`receiverposition` returns NaN for epochs with < 4 satellites.** Check the output for NaN rows and report skipped epochs to the user.
- **RINEX v4 mixed nav files have nested structs** (e.g., `navData.GPS.LNAV.EPH`), unlike v3 flat timetables. This skill targets v3 only.
- **GLONASS orbital validity is ±15 minutes** vs ±2 hours for GPS/Galileo/BeiDou. Use navigation data close in time to the observations.
- **Time system alignment** across constellations (GPST, GLONASS UTC, GST, BDT) is handled by MATLAB's datetime indexing in the timetable — no manual conversion needed.
- **HDOP quality scale:** < 1 = ideal, 1–2 = excellent, 2–5 = good, 5–10 = moderate, 10–20 = fair, > 20 = poor. Flag > 6 as degraded.

## Sample Data

Shipped RINEX v3 files for testing are at `fullfile(matlabroot, 'toolbox', 'nav', 'positioning', 'core', 'positioningdata')`:

| File | Type | System |
|------|------|--------|
| `GODS00USA_R_20211750000_01H_30S_MO.rnx` | Observation | GPS, GLONASS, Galileo, BeiDou |
| `GODS00USA_R_20211750000_01D_GN.rnx` | GPS Nav | GPS |
| `GODS00USA_R_20211750000_01D_EN.rnx` | Galileo Nav | Galileo |
| `GODS00USA_R_20211750000_01D_RN.rnx` | GLONASS Nav | GLONASS |
| `GODS00USA_R_20211750000_01D_CN.rnx` | BeiDou Nav | BeiDou |

GODS station approximate ground truth: `[39.020734, -76.826657, -8.95]` (LLA from RINEX header).

Public RINEX data sources: [IGS Data Centers](https://igs.org/data/), [CORS Network](https://geodesy.noaa.gov/CORS/).

## Error Handling

| Symptom | Cause | Fix |
|---------|-------|-----|
| `gnssmeasurements` error: "Missing navigation message for satellite X" | Observed satellite has no matching nav data | Pre-filter obs timetable to satellites present in nav data using `intersect` on `SatelliteID` |
| Empty timetable from `gnssmeasurements` | Wrong observation code or no matching time span | Check available obs codes with `rinexinfo`; verify obs and nav time ranges overlap |
| `receiverposition` returns all NaN | Fewer than 4 satellites per epoch | Relax elevation mask, lower C/N0 threshold, or add more constellations |
| HDOP/VDOP very high (> 20) | Poor satellite geometry | Add constellations, reduce elevation mask, check for blocked sky sectors |
| Position scatter > 50 m | No atmospheric corrections applied | Add `gnssoptions` with Klobuchar ionosphere and Saastamoinen troposphere |
| `rinexread` error on file | RINEX v2, v4, or corrupted file | Check version with `rinexinfo`; this skill requires v3 |

## Skill Feedback

If this skill's guidance was wrong, incomplete, or didn't work, emit a plain-text
feedback marker in your response, then continue with the task.

Format: `NAV-SKILL-FEEDBACK [matlab-compute-gnss-position] [category]: what failed; what you did instead`
Categories: `wrong-command` (incorrect/outdated), `missing-guidance` (omitted step),
`discovery-failure` (suggested approach didn't work), `platform-issue` (environment-specific)

Copyright 2026 The MathWorks, Inc.
