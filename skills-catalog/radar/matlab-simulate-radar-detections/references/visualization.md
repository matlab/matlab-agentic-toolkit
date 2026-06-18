# Visualization Tools

| Function | Purpose |
|----------|---------|
| `theaterplot` | Scenario visualization (platforms, detections, coverage) |
| `coverageConfig` | Coverage diagram configuration |
| `surfaceplot` | Terrain visualization |
| `radarmetricplot` | Plot any metric vs range with objective/threshold lines and stoplight chart |

## radarmetricplot

General-purpose function for plotting radar performance metrics against target range. Supports objective and threshold requirement lines, multiple radar comparison, stoplight charts, and max-range requirements.

```matlab
% SNR vs range with detection requirement
ranges = linspace(1e3, 100e3, 100)';
snr = radareqsnr(lambda, ranges, Pt, tau, 'Gain', G, 'Ts', Ts);
reqSNR = albersheim(0.9, 1e-6, 1);

radarmetricplot(ranges, snr, reqSNR, reqSNR - 3, ...
    'MetricName', 'SNR', ...
    'MetricUnit', 'dB', ...
    'RangeUnit', 'km', ...
    'RequirementName', 'Pd = 0.9', ...
    'RadarName', {'Ground Surveillance'}, ...
    'ShowStoplight', true, ...
    'MaxRangeRequirement', 80e3);
```

| Parameter | Purpose |
|-----------|---------|
| `metric` | Any column vector (SNR, Pd, range resolution, etc.) — matrix for multi-radar comparison |
| `objective` | Green/pass threshold (scalar, vector, or matrix) |
| `threshold` | Red/fail threshold (scalar, vector, or matrix) |
| `MaxRangeRequirement` | Vertical line(s) marking required detection range |
| `ShowStoplight` | `true` adds a pass/marginal/fail summary panel |
| `RadarName` | Cell array of legend labels for multi-radar comparison |

**Typical metrics to plot:**
- SNR vs range (from `radareqsnr`)
- Pd vs range (from `rocinterp` applied to SNR curve)
- Detectability factor vs range (from `detectability`)
- Range resolution vs range (constant, but useful in trade studies)

## theaterPlot Plotters

`theaterPlot` provides specialized plotters for different visualization needs:

| Plotter | Purpose |
|---------|---------|
| `platformPlotter` | Show platform positions and labels |
| `detectionPlotter` | Show detection measurements |
| `orientationPlotter` | Show beam/platform orientation (local axes triad) |
| `trackPlotter` | Show tracker outputs |
| `coveragePlotter` | Show sensor coverage volumes |
| `trajectoryPlotter` | Show platform paths |
| `surfacePlotter` | Show terrain/sea surface |
| `clutterRegionPlotter` | Show clutter generation regions |

## detectionPlotter

Shows detection positions on a theater plot. `plotDetection` expects positions as **Nx3** (each row is `[x y z]`). Passing 3xN errors: "Expected positions to be an array with number of columns equal to 3."

```matlab
tp = theaterPlot('XLimits', [-5e3 40e3], 'YLimits', [-20e3 20e3]);
dplt = detectionPlotter(tp, 'DisplayName', 'Detections');

% DetectionCoordinates='Scenario': Measurement is [x;y;z] column vector
% Transpose each to 1x3 row, then stack into Nx3
detPos = cell2mat(cellfun(@(d) d.Measurement', dets, 'UniformOutput', false));
plotDetection(dplt, detPos);
```

**Critical:** This pattern only works when `DetectionCoordinates='Scenario'`. For any other frame (`'Body'`, `'Sensor rectangular'`, `'Sensor spherical'`), you must convert to scenario-frame coordinates before plotting. Use the general pattern below.

### Converting Non-Scenario Detections to Scenario Frame

Works for all `DetectionCoordinates` settings. Uses `MeasurementParameters` from each detection to walk the transform chain back to the scenario frame.

```matlab
nDets = numel(dets);
detPos = zeros(nDets, 3);
for i = 1:nDets
    meas = dets{i}.Measurement;
    mp = dets{i}.MeasurementParameters;
    % If spherical, convert to Cartesian first
    if strcmp(mp(1).Frame, 'Spherical')
        az = meas(1); el = meas(2); r = meas(3);  % degrees, meters
        pos = [r*cosd(el)*cosd(az); r*cosd(el)*sind(az); r*sind(el)];
    else
        pos = meas;  % already [x; y; z] column vector
    end
    % Apply MeasurementParameters chain to scenario frame
    for k = 1:numel(mp)
        if mp(k).IsParentToChild
            pos = mp(k).Orientation' * pos + mp(k).OriginPosition;
        else
            pos = mp(k).Orientation * pos + mp(k).OriginPosition;
        end
    end
    detPos(i,:) = pos';
end
plotDetection(dplt, detPos);
```

| DetectionCoordinates | MP(1).Frame | Transform chain |
|---|---|---|
| `'Scenario'` | — | No conversion needed — use `Measurement'` directly |
| `'Body'` | Rectangular | body → scenario (1 MP entry) |
| `'Sensor rectangular'` | Rectangular | sensor → body → scenario (2 MP entries) |
| `'Sensor spherical'` | Spherical | sph2cart → sensor → body → scenario (2 MP entries) |

## orientationPlotter (Beam/Platform Orientation Visualization)

Shows local coordinate axes (triad) at a position. Use quaternions to specify orientation — avoids error-prone Euler angle sign mapping.

### Orientation Conventions

- `plotOrientation(oplt, quat, positions)` — quaternion form (preferred)
- `plotOrientation(oplt, roll, pitch, yaw, positions, labels)` — Euler form
- Positions are **Nx3** (same as `plotDetection`)
- Quaternions: use `quaternion([yaw pitch roll], "eulerd", "ZYX", "frame")`

### Composing Platform + Sensor Orientation

The sensor orientation in the scenario frame is the composition of platform orientation and mounting angles:

```matlab
platQuat = quaternion(plat.Orientation, "eulerd", "ZYX", "frame");
mountAngles = plat.Sensors{1}.MountingAngles;  % [yaw, pitch, roll]
sensorQuat = platQuat * quaternion(mountAngles, "eulerd", "ZYX", "frame");
```

### Visualization Loop with Detections

```matlab
tp = theaterPlot('XLimits', [-5e3 30e3], 'YLimits', [-15e3 15e3]);
oplt = orientationPlotter(tp, 'DisplayName', 'Sensor', 'LocalAxesLength', 3000);
pplt = platformPlotter(tp, 'DisplayName', 'Platforms');
dplt = detectionPlotter(tp, 'DisplayName', 'Detections');

% In simulation loop:
advance(scene);
dets = detect(scene);

% Get beam orientation from coverageConfig (struct array, one per sensor)
configs = coverageConfig(scene);
% configs.Orientation = platform + mounting quaternion (boresight at rest)
% configs.LookAngle = [az; el] current scan offset from boresight
beamQuats = arrayfun(@(c) c.Orientation * quaternion([c.LookAngle(1) c.LookAngle(2) 0], ...
    "eulerd", "ZYX", "frame"), configs);
positions = vertcat(configs.Position);  % Nx3

plotOrientation(oplt, beamQuats, positions);
plotPlatform(pplt, tgtPositions, labels);
if ~isempty(dets)
    detPos = cell2mat(cellfun(@(d) d.Measurement', dets, 'UniformOutput', false));
    plotDetection(dplt, detPos);
end
```

| Property | Default | Notes |
|----------|---------|-------|
| `LocalAxesLength` | 1 | Length of triad arms (meters) — scale to scenario |
| `HistoryDepth` | 0 | Show N previous orientations (breadcrumb trail) |

**Key behavior:** The scan angle only advances on `detect()` calls, not `advance()` alone. `coverageConfig(scene)` returns a struct array (one entry per sensor) containing `Orientation` (platform + mounting quaternion) and `LookAngle` (current scan offset). Compose both to get the current beam direction quaternion.

## coveragePlotter (Scan Sector Visualization)

Shows sensor coverage volumes (scan sector wedge) on a theater plot. Uses the same `coverageConfig(scene)` struct array as `orientationPlotter`.

```matlab
tp = theaterPlot('XLimits', [-10e3 90e3], 'YLimits', [-50e3 50e3]);
cplt = coveragePlotter(tp, 'DisplayName', 'Scan Sector', 'Alpha', [0.3 0.1]);

% coverageConfig returns struct array — one entry per sensor across all platforms
configs = coverageConfig(scene);
plotCoverage(cplt, configs);
```

| Property | Default | Notes |
|----------|---------|-------|
| `Alpha` | `[0.7, 0.05]` | **Must be 2-element vector** `[coverageArea, sensorBeam]`. Scalar produces error: "Expected Alpha to be an array with number of elements equal to 2." |
| `Color` | `'auto'` | RGB triplet, hex, or color name |

**`plotCoverage` signature:** `plotCoverage(cplt, configs)` where `configs = coverageConfig(scene)`. The struct array contains `Index`, `LookAngle`, `FieldOfView`, `ScanLimits`, `Range`, `Position`, `Orientation` (quaternion). `plotCoverage` uses `LookAngle` internally to position the wedge at the current scan angle. Do NOT pass these fields as individual arguments.

----

Copyright 2026 The MathWorks, Inc.

----
