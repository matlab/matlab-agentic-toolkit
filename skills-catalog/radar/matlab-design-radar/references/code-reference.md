# Code Reference — Radar Designer Patterns & Examples

## Reading Results

### Read the Full Results Table

```matlab
T = radarDesignerResults(h, 'read');
```

Returns a MATLAB table with 16 rows (one per metric) and columns:
- `Metric` — metric name (string)
- `Units` — display units (string)
- `Threshold` — requirement threshold in display units
- `Objective` — requirement objective in display units
- `Result_<radarName>` — computed value in display units (one column per radar)
- `Status_<radarName>` — `'PASS'`, `'WARN'`, or `'FAIL'` (one column per radar)

### Print Only Metrics That Fail

```matlab
T = radarDesignerResults(h, 'read');
names = radarDesignerMultiRadar(h, 'names');

for r = 1:numel(names)
    statusCol = "Status_" + names{r};
    resultCol = "Result_" + names{r};
    failRows = T.(statusCol) == "FAIL";
    if any(failRows)
        fprintf('\n%s — Requirements NOT met:\n', names{r});
        failT = T(failRows, {'Metric', 'Units', 'Threshold', 'Objective', resultCol, statusCol});
        disp(failT);
    else
        fprintf('\n%s — All requirements met.\n', names{r});
    end
end
```

---

## Range Auto-Tuning

> **MANDATORY**: When the user specifies a target range, ALWAYS run auto-tune before reading results.

```matlab
result = radarDesignerResults(h, 'autoTune', 300e3);  % 300 km
fprintf('Requested: %.1f km, Achieved: %.1f km (ratio: %.2f)\n', ...
    result.requestedRange_km, result.achievedRange_km, result.ratio);
```

The auto-tune:
1. Temporarily uncaps the MaxRange objective to read the true detection range
2. Adjusts peak power using R⁴ law (up to 5 iterations)
3. Falls back to gain adjustment if power hits bounds (100 W floor, 50 MW ceiling)
4. Sets the MaxRange requirement threshold/objective to the user's requested range
5. Returns a struct with `requestedRange_km`, `achievedRange_km`, `ratio`, `converged`

### When User Does NOT Specify a Range

Skip auto-tuning and report the template defaults as-is.

---

## Multi-Radar Comparison

### Clone and Compare at Different Frequencies

```matlab
% Start with airport radar at default frequency
radarDesignerSession('startNew', h, 'AirportRadarSpec');

% Clone and change frequency on the copy
radarDesignerMultiRadar(h, 'clone');
radarDesignerMultiRadar(h, 'select', 2);
radarDesignerParam(h, 'set', 'Radar', 'Frequency', 5.6e9);

% Read comparison table
T = radarDesignerResults(h, 'read');
disp(T);
```

### Add a Different Radar Template

```matlab
radarDesignerMultiRadar(h, 'add', 'TrackingRadar');
names = radarDesignerMultiRadar(h, 'names');
disp(names);
```

### Delete Current Radar

```matlab
radarDesignerMultiRadar(h, 'delete');
```

---

## Session Management

```matlab
% Save current session
radarDesignerSession('save', h, 'C:/path/to/mydesign.mat');

% Start a new session
radarDesignerSession('startNew', h, 'TrackingRadarSpec');

% Load a saved session
radarDesignerSession('load', h, 'C:/path/to/mydesign.mat');
```

---

## Export to MATLAB Script

```matlab
% Export SNR vs Range analysis script
radarDesignerExport(h, 'snr');

% Export Radar Metrics Report
radarDesignerExport(h, 'report');

% Export Vertical Coverage script
radarDesignerExport(h, 'coverage');

% Export Range-Doppler Grid script
radarDesignerExport(h, 'rdgrid');
```

Export opens the generated script automatically in the MATLAB editor.

---

## Example Conversations

### "Design a tracking radar at 5 GHz with 2 MW power at 300 km"

```matlab
if ~exist('h','var') || ~isvalid(h)
    h = radarDesignerSession('launch');
end
radarDesignerSession('startNew', h, 'TrackingRadarSpec');
radarDesignerParam(h, 'set', 'Radar', 'Frequency', 5e9);
radarDesignerParam(h, 'set', 'Radar', 'PeakPower', 2e6);
radarDesignerParam(h, 'set', 'Target', 'RCS', 1);

% Auto-tune to 300 km
result = radarDesignerResults(h, 'autoTune', 300e3);

% Read full results
T = radarDesignerResults(h, 'read');
disp(T);
```

### "Compare airport radar at 2.8 GHz vs 5.6 GHz for 150 km range"

```matlab
if ~exist('h','var') || ~isvalid(h)
    h = radarDesignerSession('launch');
end
radarDesignerSession('startNew', h, 'AirportRadarSpec');

% Set range requirement on both
radarDesignerParam(h, 'setRequirement', 2, 'Threshold', 150e3);
radarDesignerParam(h, 'setRequirement', 2, 'Objective', 150e3);

% Auto-tune first radar
radarDesignerResults(h, 'autoTune', 150e3);

% Clone and change frequency on the copy
radarDesignerMultiRadar(h, 'clone');
radarDesignerMultiRadar(h, 'select', 2);
radarDesignerParam(h, 'set', 'Radar', 'Frequency', 5.6e9);

% Auto-tune clone too
radarDesignerResults(h, 'autoTune', 150e3);

% Read comparison
T = radarDesignerResults(h, 'read');
disp(T);
```

### "What's the detection range if I increase pulses to 20?"

```matlab
radarDesignerParam(h, 'set', 'Radar', 'NumPulses', 20);
T = radarDesignerResults(h, 'read');
fprintf('Max Range: %.1f %s [%s]\n', ...
    T.Result_TrackingRadar(2), T.Units(2), T.Status_TrackingRadar(2));
```

### "Add rain at 8 mm/hr and show impact"

```matlab
% Read baseline before rain
T_before = radarDesignerResults(h, 'read');
baseline_range = T_before.Result_TrackingRadar(2);

% Add rain
radarDesignerParam(h, 'set', 'Environment', 'RainRate', 8);

% Read after rain
T_after = radarDesignerResults(h, 'read');
rain_range = T_after.Result_TrackingRadar(2);

fprintf('Max Range: %.1f km (clear) -> %.1f km (8 mm/hr rain)\n', ...
    baseline_range, rain_range);
```

### "Save and reload my session"

```matlab
radarDesignerSession('save', h, fullfile(pwd, 'my_radar_session.mat'));
radarDesignerSession('startNew', h, 'TrackingRadarSpec');
radarDesignerSession('load', h, fullfile(pwd, 'my_radar_session.mat'));
```

----

Copyright 2026 The MathWorks, Inc.

----
