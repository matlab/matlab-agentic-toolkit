---
name: matlab-design-radar
description: Launch and control the MATLAB Radar Designer app programmatically via MCP. Use when designing radar systems, configuring parameters, comparing radar types, analyzing performance metrics, or managing radar design sessions.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Radar Designer MCP Control

Launch and control the MATLAB Radar Designer app programmatically via MCP. Use this skill when a user asks about radar design parameters, wants to configure a radar system, compare radar types, analyze radar performance, or visualize radar metrics interactively in the Radar Designer app.

## On Entry

When this skill is first invoked without a specific user request, present the following example prompts to inspire the user:

1. Design a tracking radar at 5 GHz with 2 MW peak power at 1500 km range for a 1 sq meter target
2. Compare airport radar performance at 2.8 GHz vs 5.6 GHz — which can achieve 150 km range for a 10 sq meter target?
3. Set up a weather radar and show how heavy rain (16 mm/hr) degrades detection range
4. Configure an automotive radar at 77 GHz with electronic scanning for 100 meters range
5. Add a 200 km max range requirement to my current radar design and check if it meets the objective

Then wait for the user to type their own radar design question.

**IMPORTANT**
- Never generate MATLAB scripts for the user that call the wrapper functions directly. These are for the agent's internal use only. When the user asks for a script, use only the built-in export commands via `radarDesignerExport`.
- When greeting the user, simply ask about their radar design goals (type, frequency, power, requirements) without referencing the underlying mechanism.

## When to Use

- User asks to design, configure, or analyze a radar system
- User wants to launch or open the Radar Designer app
- User asks to change radar parameters (frequency, power, antenna, etc.)
- User wants to compare different radar types (tracking, airport, airborne, etc.)
- User asks about radar performance metrics (max range, SNR, detection probability, etc.)
- User wants to load or save a radar design session (.mat file)
- User asks about target or environment configuration for radar analysis
- User wants to set requirements/objectives for a radar design

## When NOT to Use

- User asks about general MATLAB programming unrelated to radar design
- User wants to use Radar Toolbox functions directly (without the Radar Designer app)
- User asks about Simulink radar models or Phased Array System Toolbox without the app
- User wants to create radar waveforms or signals outside the app context
- User asks about radar theory or equations without wanting to use the app

## Prerequisites

- MATLAB MCP server must be running and connected
- The `mcp__matlab__evaluate_matlab_code` tool must be available
- The Radar Toolbox must be installed in the MATLAB instance
- The skill's `scripts/` directory must be on the MATLAB path (set via `project_path`)

## Code Reference

Consult [code-reference.md](references/code-reference.md) for detailed code patterns — including multi-radar comparison, session management, export, and range auto-tuning examples. The patterns below are summaries; `code-reference.md` is authoritative.

---

## Wrapper Scripts

All Radar Designer operations go through 5 p-coded wrapper scripts in `scripts/`. Always set `project_path` to the skill's root directory when calling `mcp__matlab__evaluate_matlab_code` so the scripts are on the MATLAB path.

### radarDesignerSession — App lifecycle and sessions

| Action | Call | Returns |
|--------|------|---------|
| Launch app | `h = radarDesignerSession('launch')` | App handle `h` |
| Reuse existing | `h = radarDesignerSession('launch', h)` | Same `h` if valid |
| Start new | `radarDesignerSession('startNew', h, templateName)` | — |
| Save session | `radarDesignerSession('save', h, filePath)` | — |
| Load session | `radarDesignerSession('load', h, filePath)` | — |

**Templates:** `'AirborneRadarSpec'`, `'AirportRadarSpec'`, `'AutomotiveRadarSpec'`, `'TrackingRadarSpec'`, `'WeatherRadarSpec'`

### radarDesignerParam — Get/set parameters and requirements

| Action | Call | Returns |
|--------|------|---------|
| Set parameter | `radarDesignerParam(h, 'set', specType, propName, value)` | — |
| Get parameter | `val = radarDesignerParam(h, 'get', specType, propName)` | Property value |
| Set requirement | `radarDesignerParam(h, 'setRequirement', reqIndex, propName, value)` | — |

**specType:** `'Radar'`, `'Target'`, `'Environment'`

### radarDesignerResults — Read results and auto-tune

| Action | Call | Returns |
|--------|------|---------|
| Read results | `T = radarDesignerResults(h, 'read')` | Table (16 metrics) |
| Auto-tune range | `result = radarDesignerResults(h, 'autoTune', range_m)` | Struct |

**Results table columns:** `Metric`, `Units`, `Threshold`, `Objective`, `Result_<radarName>`, `Status_<radarName>` (PASS/WARN/FAIL)

**Auto-tune result fields:** `requestedRange_km`, `achievedRange_km`, `ratio`, `converged`

### radarDesignerMultiRadar — Multiple radar management

| Action | Call | Returns |
|--------|------|---------|
| Add template | `radarDesignerMultiRadar(h, 'add', templateName)` | — |
| Clone current | `radarDesignerMultiRadar(h, 'clone')` | — |
| Select by index | `radarDesignerMultiRadar(h, 'select', index)` | — |
| Delete current | `radarDesignerMultiRadar(h, 'delete')` | — |
| List names | `names = radarDesignerMultiRadar(h, 'names')` | Cell array |

**Add templates:** `'AirborneRadar'`, `'AirportRadar'`, `'AutomotiveRadar'`, `'TrackingRadar'`, `'WeatherRadar'`

### radarDesignerExport — Built-in export

| Action | Call | Description |
|--------|------|-------------|
| SNR vs Range | `radarDesignerExport(h, 'snr')` | Opens SNR vs Range script in editor |
| Metrics Report | `radarDesignerExport(h, 'report')` | Opens Radar Metrics Report |
| Vertical Coverage | `radarDesignerExport(h, 'coverage')` | Opens Vertical Coverage script |
| Range-Doppler Grid | `radarDesignerExport(h, 'rdgrid')` | Opens Range-Doppler Grid script |

---

## Workflow

### Step 1: Launch the App

```matlab
h = radarDesignerSession('launch');
```

Always check if `h` already exists:

```matlab
if ~exist('h','var') || ~isvalid(h)
    h = radarDesignerSession('launch');
end
```

### Step 2: Select a Radar Template

```matlab
radarDesignerSession('startNew', h, 'TrackingRadarSpec');
```

### Step 3: Set Parameters

```matlab
radarDesignerParam(h, 'set', 'Radar', 'Frequency', 5e9);     % 5 GHz
radarDesignerParam(h, 'set', 'Radar', 'PeakPower', 2e6);     % 2 MW
radarDesignerParam(h, 'set', 'Target', 'RCS', 1);             % 1 m²
radarDesignerParam(h, 'set', 'Environment', 'RainRate', 4);   % 4 mm/hr
```

**All values in SI units:** frequency in Hz, power in W, range in m, etc.

### Step 3a: Map User Objectives to Requirements

When the user states a performance goal, set it as the Threshold on the matching requirement.

| User says | Req Index | Example call |
|-----------|-----------|--------------|
| "150 km range" | 2 (`MaxRange`) | `radarDesignerParam(h, 'setRequirement', 2, 'Threshold', 150e3)` |
| "10 m range resolution" | 6 (`RangeResolution`) | `radarDesignerParam(h, 'setRequirement', 6, 'Threshold', 10)` |
| "0.5° azimuth accuracy" | 10 (`AzimuthAccuracy`) | `radarDesignerParam(h, 'setRequirement', 10, 'Threshold', 0.5)` |
| "100 m/s first blind speed" | 7 (`FirstBlindSpeed`) | `radarDesignerParam(h, 'setRequirement', 7, 'Threshold', 100)` |
| "5 km min range" | 4 (`MinRange`) | `radarDesignerParam(h, 'setRequirement', 4, 'Threshold', 5e3)` |

Set both Threshold and Objective to the same value unless the user distinguishes a minimum acceptable (Threshold) from a desired goal (Objective).

### Step 3b: Range Auto-Tuning (MANDATORY when user specifies a range)

**If the user specifies a target range**, you MUST run auto-tune BEFORE reading/reporting results:

```matlab
result = radarDesignerResults(h, 'autoTune', 300e3);  % 300 km target
```

The auto-tune adjusts peak power (and gain if needed) so the achieved range is within ±15% of the user's request. It also sets the MaxRange requirement threshold to the user's requested range.

Skip this step ONLY if the user did not mention a specific range target.

### Step 4: Read Analysis Results

```matlab
T = radarDesignerResults(h, 'read');
```

The returned table has 16 rows (one per metric) with columns: `Metric`, `Units`, `Threshold`, `Objective`, and per-radar `Result_<name>` and `Status_<name>` columns.

Status values: `PASS` (meets objective), `WARN` (between threshold and objective), `FAIL` (does not meet threshold).

### Step 5: Multi-Radar, Sessions, Export

See [code-reference.md](references/code-reference.md) for complete patterns.

---

## Complete Property Reference

### Radar Properties (Settable)

#### Waveform
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `Frequency` | Carrier frequency | Hz | `3e9` |
| `PulseBandwidth` | Pulse bandwidth | Hz | `20e6` |
| `PeakPower` | Peak transmit power | W | `15e6` |
| `pulsewidth` | Pulse duration | s | `1e-3` |
| `prf` | Pulse repetition frequency | Hz | `1000` |
| `CarrierWaveInput` | Input type for carrier wave | enum | `'Frequency'` or `'Wavelength'` |
| `PowerInput` | Input type for power | enum | `'PeakPower'` or `'AveragePower'` |
| `PulseDurationInput` | Input type for duration | enum | `'PulseWidth'` or `'DutyCycle'` |
| `PulseRepetitionInput` | Input type for PRF | enum | `'PRF'` or `'PRI'` |

#### Noise
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `SystemNoiseInput` | Noise input type | enum | `'Temperature'` or `'Figure'` |
| `NoiseTemperature` | System noise temperature | K | `290` |
| `referenceNoiseTemperature` | Reference noise temp | K | `290` |
| `QuantizationNoise` | Enable quantization noise | logical | `true`/`false` |
| `QuantizationNumBits` | ADC bits | integer | `12` |
| `QuantizationDynamicRange` | ADC dynamic range | dB | `60` |

#### Antenna
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `AntennaHeight` | Antenna height above ground | m | `75` |
| `TiltAngle` | Antenna tilt angle | deg | `0` |
| `Polarization` | Antenna polarization | enum | `'H'`, `'V'`, `'Circular'` |
| `TxGain` | Transmit antenna gain | dBi | `40` |
| `TxAzBeamwidth` | Tx azimuth beamwidth | deg | `2` |
| `TxElBeamwidth` | Tx elevation beamwidth | deg | `2` |
| `DifferentRx` | Use different Rx antenna | logical | `false` |
| `RxGain` | Receive antenna gain | dBi | `40` |
| `RxAzBeamwidth` | Rx azimuth beamwidth | deg | `2` |
| `RxElBeamwidth` | Rx elevation beamwidth | deg | `2` |
| `TxGainInput` | Tx gain input mode | enum | `'GainBeamwidth'`, `'GainOnly'`, `'Imported'` |
| `RxGainInput` | Rx gain input mode | enum | `'GainBeamwidth'`, `'GainOnly'`, `'Imported'` |
| `TxSincInput` | Tx sinc pattern option | enum | `'Sinc'` or `'Gaussian'` |

#### Scanning
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `Scanning` | Scan type | enum | `'None'`, `'Mechanical'`, `'Electronic'` |
| `AzScanSectorMech` | Mechanical az scan sector | deg | `360` |
| `AzScanSectorElec` | Electronic az scan sector | deg | `120` |
| `ElScanStart` | Elevation scan start | deg | `0` |
| `ElScanStop` | Elevation scan stop | deg | `30` |

#### Detection
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `Pfa` | Probability of false alarm | probability | `1e-6` |
| `NumPulses` | Number of pulses integrated | integer | `10` |
| `PulseIntegration` | Integration type | enum | `'Coherent'`, `'Noncoherent'` |
| `NumCPIs` | Number of CPIs | integer | `1` |
| `BinaryIntegration` | Enable binary integration | logical | `false` |
| `NumBinaryDetections` | Binary detection threshold | integer | depends |
| `MofNCPIIntegration` | Enable M-of-N CPI integration | logical | `false` |
| `MNumCPIs` | M threshold for M-of-N | integer | depends |

#### Track Confirmation
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `ConfirmationThreshM` | M for M/N confirmation | integer | `3` |
| `ConfirmationThreshN` | N for M/N confirmation | integer | `5` |
| `TrackUpdateInput` | Track update input type | enum | `'TrackUpdateRate'` or `'TrackUpdateTime'` |
| `TrackUpdateTime` | Track update time | s | `1` |

#### Signal Processing
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `STC` | Enable STC | logical | `false` |
| `STCCutOffRange` | STC cutoff range | m | `50000` |
| `STCExponent` | STC exponent | scalar | `4` |
| `CFAR` | Enable CFAR | logical | `false` |
| `CFARNumCells` | CFAR reference cells | integer | `20` |
| `CFARMethod` | CFAR method | enum | `'CA'`, `'OS'`, `'GO'`, `'SO'` |
| `MTI` | Enable MTI filter | logical | `false` |
| `MTICanceller` | MTI canceller order | integer | `2` |
| `MTINullVelocity` | MTI null velocity | m/s | `0` |
| `MTIMethod` | MTI method | enum | depends |
| `Eclipsing` | Enable eclipsing loss | logical | `false` |
| `CustomLoss` | Additional custom loss | dB | `0` |

### Target Properties
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `RCS` | Radar cross section | m² | `1` |
| `SwerlingModel` | Swerling fluctuation model | enum | `'Swerling0'`...`'Swerling4'` |
| `TargetPositionInputType` | Input type | enum | `'Height'` or `'Elevation'` |
| `TargetHeight` | Target height/altitude | m | `10000` |
| `TargetElevation` | Target elevation angle | deg | `5` |
| `MaxAcceleration` | Max target acceleration | m/s² | `50` |
| `Name` | Target name | string | `'Target 1'` |

### Environment Properties
| Property | Description | Units | Example |
|----------|-------------|-------|---------|
| `FreeSpace` | Free space propagation | logical | `true` |
| `AtmosphericGasLoss` | Gas absorption enabled | logical | `true` |
| `LensLoss` | Lens effect enabled | logical | `true` |
| `PropagationFactor` | Propagation factor model | logical | `true` |
| `EarthModel` | Earth model type | enum | `'Flat'`, `'Curved'` |
| `SurfaceType` | Surface type | enum | `'Sea'`, `'Land'`, `'Custom'` |
| `RainRate` | Rain rate | mm/hr | `4` |
| `PrecipitationType` | Precipitation type | enum | `'Rain'`, `'Snow'`, `'Fog'`, `'Cloud'` |
| `SeaStateNumber` | Sea state (0-7) | integer | `3` |
| `LandType` | Land type | enum | depends |
| `VegetationType` | Vegetation type | enum | depends |
| `EffectiveEarthRadius` | Effective earth radius | m | `8500000` |
| `Name` | Environment name | string | `'Environment 1'` |

### Requirement Specifications

| Index | Name | Description |
|-------|------|-------------|
| 1 | `MaxRangePd` | Max range at detection probability |
| 2 | `MaxRange` | Maximum detection range |
| 3 | `MDS` | Minimum detectable signal |
| 4 | `MinRange` | Minimum range |
| 5 | `UnambiguousRange` | Unambiguous range |
| 6 | `RangeResolution` | Range resolution |
| 7 | `FirstBlindSpeed` | First blind speed |
| 8 | `RangeRateResolution` | Range-rate resolution |
| 9 | `RangeAccuracy` | Range accuracy |
| 10 | `AzimuthAccuracy` | Azimuth accuracy |
| 11 | `ElevationAccuracy` | Elevation accuracy |
| 12 | `RangeRateAccuracy` | Range-rate accuracy |
| 13 | `PtrueTrack` | True track probability |
| 14 | `PfalseTrack` | False track probability |
| 15 | `EIRP` | EIRP |
| 16 | `PowerAperture` | Power-aperture product |

Each requirement has: `Objective`, `Threshold`.

---

## Presenting Results

Always present results to the user in the following structured format:

### 1. Summary Table

Use Unicode box-drawing characters to render a clean table.

**Single radar:**

```
┌───────────────────────┬────────────┬────────┐
│        Metric         │   Value    │ Status │
├───────────────────────┼────────────┼────────┤
│ Max Range             │ 315.1 km   │ PASS   │
├───────────────────────┼────────────┼────────┤
│ Range Resolution      │ 7.5 m      │ PASS   │
├───────────────────────┼────────────┼────────┤
│ First Blind Speed     │ 53.5 m/s   │ WARN   │
└───────────────────────┴────────────┴────────┘
```

**Multi-radar comparison:**

```
┌───────────────────────┬────────────┬────────────┬─────────┐
│        Metric         │  Radar A   │  Radar B   │ Winner  │
├───────────────────────┼────────────┼────────────┼─────────┤
│ Max Range             │ 315.1 km   │ 222.6 km   │ Radar A │
├───────────────────────┼────────────┼────────────┼─────────┤
│ First Blind Speed     │ 53.5 m/s   │ 26.8 m/s   │ Radar A │
└───────────────────────┴────────────┴────────────┴─────────┘
```

**Table rules:**
- Show only metrics that are relevant to the user's question or that differ meaningfully between radars (not all 16 by default)
- If the user asks for a "full report", show all 16 metrics
- Include display units in the value cells (km, m/s, dBW, etc.)
- Use the Status column values directly from the results table (PASS/WARN/FAIL)

### 2. Key Takeaways

After the table, provide 2-4 bullet points covering:
- The most significant performance tradeoffs
- Any surprising results or requirement failures
- What factor is limiting performance (e.g., rain loss, duty cycle, antenna gain)
- Impact of the user's parameter change (if they modified something)

### 3. Verdict

End with a 1-2 sentence summary or recommendation.

---

## Conventions

1. **UI Auto-Updates**: All parameter changes fire events that update the web UI automatically — no manual refresh needed.

2. **Handle Persistence**: The variable `h` must persist in the MATLAB base workspace between calls. Each `evaluate_matlab_code` call shares the same workspace, so `h` remains available.

3. **Startup Timing**: The app takes 5-10 seconds to initialize. `radarDesignerSession('launch')` handles the wait automatically.

4. **Always Use project_path**: When calling `mcp__matlab__evaluate_matlab_code`, set `project_path` to the skill's root directory so the wrapper scripts in `scripts/` are on the MATLAB path.

5. **Property Names Are Case-Sensitive**: Use exact names from the property reference tables above.

6. **Range Auto-Tuning Is Mandatory**: When the user specifies a target range, ALWAYS run `radarDesignerResults(h, 'autoTune', range_m)` BEFORE reading results. Never report a design that overshoots or undershoots the user's requested range by more than 30%.

7. **Always Report Pass/Fail**: When presenting results, always include the Status (PASS/WARN/FAIL) for each metric and explicitly call out which requirements are not met.

8. **SI Units**: All parameter values must be in SI units — frequency in Hz (not GHz), power in W (not MW), range in m (not km).

9. **Always Consult code-reference.md**: Before writing code for multi-radar comparison, session management, export, or before/after analysis, load and follow the patterns in [code-reference.md](references/code-reference.md).

----

Copyright 2026 The MathWorks, Inc.

----
