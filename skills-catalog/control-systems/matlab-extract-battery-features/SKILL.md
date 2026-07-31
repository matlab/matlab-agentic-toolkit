---
name: matlab-extract-battery-features
description: >
  Extract battery features for degradation analysis and health monitoring in MATLAB.
  Covers cycling test features, differential curves (IC/DV/DT), and measurement
  statistics. Use when working with battery cycling data, SOH estimation, RUL
  prediction, or any battery test data analysis in MATLAB. Triggers on battery*
  functions such as batteryTestDataParser, batteryTestFeatureExtractor,
  batteryMeasurementFeatures, batteryDifferentialCurves.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Battery Feature Extraction


## When to Use

- Any task involving battery test data feature extraction: cycling degradation trending, SOH estimation, RUL prediction, capacity fade analysis
- Differential curve analysis (IC dQ/dV, DV dV/dQ, DT dT/dV) for electrode degradation diagnosis
- Single-segment measurement statistics from partial or full charge/discharge data
- Batch processing of multiple battery cycling test files

## When NOT to Use

- The task has no battery test data context (no cycling or differential-curve data)
- The primary goal is battery simulation, equivalent circuit modeling, or Simulink battery plant models
- The task is general signal processing, machine learning model training, or visualization without feature extraction
- The data is not from electrochemical battery tests (e.g., fuel cells, supercapacitors, or generic sensor data)

This skill covers the 5 released PMT battery feature extraction functions. These functions work natively with MATLAB tables and vectors, handle segmentation and peak detection internally, and are performance-optimized. Prefer these PMT functions over manual feature computation (e.g., hand-coded cumtrapz loops, manual peak finding). Override only if the user explicitly requests otherwise.

---

## API Overview

The Predictive Maintenance Toolbox provides **5 public functions** for battery feature extraction:

```
                        Battery Cycling Test Data
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
              Full Pipeline               Individual Functions
                    │                           │
             batteryTest-                       ├── batteryMeasurementFeatures
             DataParser                         ├── batteryDifferentialCurves
                 +                              └── batteryDifferentialCurveFeatures
             batteryTest-
             Feature-
             Extractor
                 │
                 ▼
             Feature table
```

| Function | Input | Output | Use When | Available From |
|----------|-------|--------|----------|----------------|
| `batteryTestDataParser` | Raw cycling table | Parser object (segmented data) | You have multi-cycle data needing segmentation | R2024b |
| `batteryTestFeatureExtractor` | Options | Extractor object | Full pipeline: parser → all cycling features | R2024b |
| `batteryMeasurementFeatures` | V, I, T, t vectors | Statistical + cumulative feature table | Any single-phase segment (partial or full charge/discharge) | R2026a |
| `batteryDifferentialCurves` | V, I, T, t vectors | dQ/dV, dV/dQ, dT/dV tables | Constant-current segment only (CC charge or CC discharge) | R2026a |
| `batteryDifferentialCurveFeatures` | Curve + x-axis | Peak feature table | Extracting features from differential curves | R2026a |

---

## Interaction Model: Stop or Proceed

Do not stop and ask before every extraction. Most decisions have a deterministic rule — apply it,
extract, and **report what you did** so the user can correct it. Only stop when a decision is
genuinely ambiguous *and* guessing it wrong would fail silently (plausible-but-wrong features).

**STOP and ask the user first** — but only when one of these is true:

1. **Two or more time-column candidates of the same type** (e.g. two numeric elapsed-time columns) —
   no rule can choose between them.
2. **Raw unnamed numeric matrix** — column roles must be inferred, not read from names.
3. **`checkCyclingProtocol` finds neither phase consistent** — no phase can be recommended.
4. **Anomalous cycles detected** — never silently exclude them (see CyclingPhase Selection, step 5).
5. **A required variable cannot be mapped** — a needed column is missing or its role is unclear.

**Otherwise PROCEED, then REPORT.** Apply the deterministic rules — datetime/duration beats numeric
time; use `checkCyclingProtocol`'s `RecommendedPhase`; set `DT=true` iff temperature is present; set
`CC=true` whenever IC/DV/DT is requested — write and run the extraction, then present in one turn:

- the column mappings used (noting any alternatives considered and why the chosen one won),
- the CyclingPhase and the consistency reason for it,
- any goal-vs-data tension, if present (see CyclingPhase Selection, step 4 — a report line, not a stop),
- the resulting feature table, followed by the "what next?" offer.

Close the report with an explicit undo invitation, e.g. *"If any mapping or the phase choice looks
wrong, tell me and I'll re-run."* This preserves the safety net without a blocking question.

---

## Full Pipeline: Cycling Test Feature Extraction

For multi-cycle battery test data (the most common workflow):

```matlab
% Step 1: Parse and segment the raw cycling data
parser = batteryTestDataParser(tbl, ...
    CurrentVariable="Current_A", ...
    VoltageVariable="Voltage_V", ...
    TimeVariable="Time", ...
    CycleIndexVariable="Cycle", ...
    StepIndexVariable="Step", ...
    TemperatureVariable="Temperature_C", ...
    ExcludedCycles=[], ...
    Tolerance=5e-5, ...
    NumInterpolatedPoints=1000, ...
    WindowSize=10);

% Step 2: Create extractor with desired feature categories
extractor = batteryTestFeatureExtractor( ...
    CyclingPhase="Charge", ...  % 'Charge', 'Discharge', or 'Both'
    Statistics=true, ...         % Voltage/current/temp statistics
    CycleCumulative=true, ...   % Capacity, energy, duration
    CC=true, ...                 % Constant-current segment features
    CV=true, ...                 % Constant-voltage segment features
    CCCV=true, ...               % CC+CV combined features
    IC=true, ...                 % Incremental capacity curve features
    DV=false, ...                % Differential voltage curve features
    DT=false);                   % Differential temperature curve features

% Step 3: Extract features
featureTable = extract(extractor, parser);
```

### CyclingPhase Selection

Features are only meaningful for degradation trending when extracted from phases with a consistent protocol (same C-rate, same voltage limits) across all cycles.

**Agent should:**
1. After determining column mappings, run `checkCyclingProtocol` to assess protocol consistency. This helper ships with the skill at `scripts/checkCyclingProtocol.m`. Make it callable by setting the MATLAB current folder to that `scripts/` directory (pass its absolute path as the MCP tool's `project_path`) — do **not** call `addpath`. Reference the user's data by absolute path.
   ```matlab
   result = checkCyclingProtocol(data, ...
       CurrentVariable="<mapped>", VoltageVariable="<mapped>", ...
       TimeVariable="<mapped>", CycleIndexVariable="<mapped>", ...
       StepIndexVariable="<mapped>", TemperatureVariable="<mapped>");
   ```

   **`checkCyclingProtocol` interface:**
   - **Input:** `data` (table of cycling data) plus the Name-Value column mappings above. `TemperatureVariable` is optional (default `""`, disabled).
   - **Output:** a struct `result` with fields:
     - `RecommendedPhase` — `"Charge"`, `"Discharge"`, or `"Both"` (the proposed CyclingPhase)
     - `ChargeConsistent` / `DischargeConsistent` — logical; whether each phase has a stable repeating protocol across cycles
     - `AnomalousCycles` — cycle indices with non-standard step sequences (candidates for `ExcludedCycles`)
     - `MajorityCycles` — cycle indices matching the dominant protocol
     - `NumCycles` — number of cycles in the data
     - `StepTable` — per-step reference protocol (phase, CC/CV/rest %, median current, voltage range, duration)
   - The function also prints a human-readable protocol summary to stdout.

2. Use the output to propose CyclingPhase based **solely** on protocol consistency — justify your choice by citing the repeating C-rate and voltage limits shown in the reference protocol table.

3. **Do NOT mention the user's analysis goal** (SOH, RUL, degradation, health tracking, etc.) as part of the CyclingPhase justification. The choice is purely about which phase has a fixed, repeating protocol — the analysis goal is irrelevant to this decision.

4. **Surface any goal-vs-data tension — but do not let it change the phase choice.** The phase you chose above is final and consistency-driven. Separately, if the consistent phase is **not** the one conventionally associated with the user's stated goal (charge-side IC / dQ-dV for SOH and lithium-inventory loss; discharge for delivered-capacity fade), say so explicitly instead of silently extracting from the phase the data happens to support:
   > You asked about **<goal>**, which conventionally leans on **<charge/discharge>**-side features (e.g. IC peak shifts for SOH). In your data, though, the **<charge/discharge>** protocol varies across cycles, so those features would not trend on a fixed baseline. Only the **<other>** protocol is consistent, so I'm extracting from there. Here's what the consistent phase can still tell you about **<goal>**: <what it can/can't deliver>.

   This is a **communication** step, not a phase-selection input. Never pick the inconsistent phase just because the goal would normally prefer it — report the tension and proceed with the consistent phase (or ask the user whether they can supply data with a stable protocol on the phase they need).

5. **If anomalous cycles are detected**, inform the user and ask whether to exclude them:
   > The protocol check found **N anomalous cycles** (X.X%) with non-standard step sequences: [list or first 10].
   > These cycles likely have data collection issues (missing steps). Would you like to exclude them?
   > If yes, I'll set `ExcludedCycles=[...]` on the parser.

   Only add `ExcludedCycles` after the user confirms. Do not silently exclude them.

6. Report the CyclingPhase choice (and any tension from step 4) alongside the NV-pair mappings — in the after-extraction report if you proceeded, or in the confirmation if a STOP condition applied.

If protocol consistency cannot be determined from the data (neither phase is consistent), this is a STOP condition — ask the user which phase has a fixed protocol before extracting.

### Feature Categories (165+ features total)

| Category | Property | Features | Tracks |
|----------|----------|----------|--------|
| **Statistics** | `Statistics=true` | max, min, mean, std, skewness, kurtosis of V, I, T | General degradation trends |
| **CycleCumulative** | `CycleCumulative=true` | Capacity (Ah), energy (Wh), duration, start voltage | Capacity fade, energy efficiency |
| **CC** | `CC=true` | CC duration, median current, slope, energy, skewness, kurtosis | CC phase degradation |
| **CV** | `CV=true` | CV duration, median voltage, slope, energy, skewness, kurtosis | CV phase degradation |
| **CCCV** | `CCCV=true` | Energy ratio (CC/CV), energy difference | Phase balance shift |
| **IC** | `IC=true` | Peak value, width, location, prominence, area, slopes | Electrode degradation mechanisms |
| **DV** | `DV=true` | Peak features from dV/dQ curve | Electrode capacity balance |
| **DT** | `DT=true` | Peak features from dT/dV curve | Thermal degradation signatures |

**Dependency: IC, DV, and DT require `CC=true`.** These differential curve features are computed from CC segments identified by the parser. If `CC=false`, no CC segments are identified and IC/DV/DT will silently produce no features. Always set `CC=true` when enabling IC, DV, or DT.

---

## Individual Functions

### `batteryMeasurementFeatures` — Statistics and Cumulative

Extracts statistical and cumulative features from **any single-phase segment** — works on partial or full charge/discharge data (CC, CV, or mixed CC+CV). Only requirement: current must not change sign within the segment.

```matlab
featureTable = batteryMeasurementFeatures(V, I, T, t, ...
    NoiseTolerance=1e-4);

% T and t are optional:
featureTable = batteryMeasurementFeatures(V, I);          % stats only
featureTable = batteryMeasurementFeatures(V, I, [], t);   % stats + cumulative (no temp)
featureTable = batteryMeasurementFeatures(V, I, T, t);    % all features
```

**Output features:**
- Voltage: max, min, mean, std, skewness, kurtosis
- Current: max, min, mean, std, skewness, kurtosis
- Temperature (if provided): max, min, mean, std
- Cumulative (if time provided): capacity (Ah), energy (Wh), duration, start voltage

### `batteryDifferentialCurves` — IC, DV, DT Curves

Computes differential curves from a **constant-current (CC) segment** — charge or discharge. Requires current to be approximately constant (95% of samples must have dI/dt < tolerance). Does NOT work on CV or mixed CC+CV segments.

```matlab
[dQdV, dVdQ, dTdV] = batteryDifferentialCurves(V, I, T, t, ...
    NoiseTolerance=1e-4, ...
    PreSmoothingMethod="none", ...          % "none","movmean","sgolay", etc.
    PreSmoothingWindowSize=10, ...
    PostSmoothingMethod="gaussian", ...     % default: "gaussian"
    PostSmoothingWindowSize=10, ...
    NumInterpolatedPoints=1000, ...
    InterpolationMethod="linear");
```

**Output tables:**
- `dQdV` — columns: IC, interpolatedVoltage, interpolatedTime
- `dVdQ` — columns: DV, interpolatedTime, interpolatedVoltage
- `dTdV` — columns: DT, interpolatedVoltage, interpolatedTemperature (empty if T not provided)

### `batteryDifferentialCurveFeatures` — Peak Features from Curves

Extracts peak-based features from a differential curve:

```matlab
% From table output of batteryDifferentialCurves:
features = batteryDifferentialCurveFeatures(dQdV);

% Or from raw vectors:
features = batteryDifferentialCurveFeatures(curveValues, xAxisValues);
```

**Output features per peak:** value, width, location (x-axis), prominence, area, left/right slopes, total area under curve, statistical features.

---

## Mappings, Phase, and Next Steps

### Stop After Extraction — Offer Next Steps

Once the feature table is extracted and displayed, **stop and present available next steps** to the user. Do not autonomously proceed to visualization, feature ranking, or script saving. Example:

> Feature extraction complete — 70 features across 5 cycles.
>
> What would you like to do next?
> - **Visualize:** Plot feature trends over cycles (e.g., capacity fade, IC peak shift)
> - **Rank features:** Identify most discriminative features for your analysis goal
> - **Export:** Save the feature table to a .mat or .csv file
> - **Refine:** Adjust feature categories, CyclingPhase, or smoothing parameters

Only execute a next step when the user explicitly requests it. This applies even if the original prompt contains phrasing like "show me" or "plot" — extract first, present the table, then offer to visualize.

### Column Mapping: Ambiguity Resolution

When inspecting data columns, **multiple columns may be plausible candidates** for a single variable (e.g., both `Test_Time` and `DateTime` could be `TimeVariable`). Apply the deterministic rule when one exists; only stop when it doesn't (see Interaction Model: Stop or Proceed):

1. **Prefer datetime/duration over numeric elapsed time.** If one candidate is `datetime`/`duration` type and another is numeric seconds, the datetime column wins — this is a rule, not a judgment call, so apply it and **report it** rather than asking. In your report, note the alternative you considered (e.g., "I found both `Test_Time` (numeric) and `DateTime` (datetime type) — used `DateTime` as it is a proper datetime column").
2. **Stop only when the rule can't decide.** If two candidates share the same type (e.g. two numeric elapsed-time columns) so no rule can pick, ask the user which to use. Likewise if a required variable has no clear column.
3. **When you proceed, report the mappings, CyclingPhase, and DT decision after extracting** — with an undo invitation. When you stop (per the Interaction Model), present the proposed mappings first. Example report/proposal block:

> Column mappings used:
> - `CurrentVariable` → "Current"
> - `VoltageVariable` → "Voltage"
> - `TimeVariable` → "DateTime"  (also saw numeric `Test_Time`; chose the datetime column)
> - `CycleIndexVariable` → "Cycle_Index"
> - `StepIndexVariable` → "Step_Index"
> - `TemperatureVariable` → "Temperature"
>
> If any mapping or the phase choice looks wrong, tell me and I'll re-run.

### Unnamed Data (Matrices Without Column Names)

When cycling data arrives as a raw numeric matrix (no column names), infer column roles from value characteristics, then confirm with the user before proceeding:

- Current alternates sign (charge/discharge)
- Voltage stays within cell limits (monotonic within a phase)
- Time is monotonically increasing
- Cycle and step indices are integer-valued and repeat across cycles

Present the inferred mapping and ask the user to confirm before extracting.

### For cycling test analysis

**Inspect first, don't interrogate.** Load the data and read its column names and types yourself
rather than asking the user to describe them. Map the columns by rule, run `checkCyclingProtocol` for
the phase choice, and select feature categories from the user's stated goal via the Feature Selection
Guide below. Only ask the user when a STOP condition applies (Interaction Model) — e.g. the format is
a raw unnamed matrix, or a time/required column is genuinely ambiguous. If the goal itself is unclear
(no SOH/RUL/diagnosis stated), ask what they want to learn — that drives feature selection.

---

## Feature Selection Guide

### For SOH / Capacity Estimation
- **Primary:** CycleCumulative (capacity, energy), IC peak features (track electrode degradation)
- **Supporting:** Statistics (voltage mean shift), CC duration (charging time increase)
- **Why IC:** Peak positions shift and heights decrease as electrodes degrade — most physically meaningful

### For RUL / End-of-Life Prediction
- **Primary:** IC + CycleCumulative trending over cycles
- **Supporting:** CCCV energy ratio (CC/CV balance shifts as internal resistance grows)

### For Fast Charging Optimization
- **Primary:** CV features (CV duration increase = lithium plating risk)
- **Supporting:** DT features (thermal signature of plating), Statistics (temperature rise)

---

## Common Pitfalls

1. **Mixing charge and discharge data.** Both functions require single-phase data (current must not change sign). `batteryMeasurementFeatures` accepts any partial or full charge/discharge segment (CC, CV, or mixed). `batteryDifferentialCurves` is stricter — requires constant-current data specifically.

2. **Time format.** Time must be `datetime` or `duration`, NOT numeric seconds. Convert: `t = seconds(numericTime)` or `t = datetime(numericTime, 'ConvertFrom', 'posixtime')`.

3. **Over-smoothing IC/DV curves.** Large `PostSmoothingWindowSize` destroys degradation-sensitive peaks. Start with default (10), increase only if data is very noisy. Validate visually.

4. **Extracting all features blindly.** 165+ features with <50 cycles = overfitting risk. Use the feature selection guide above to pick physically meaningful subsets.

5. **Wrong units.** Current in Amps (not mA), voltage in Volts, time in seconds-based duration. Capacity is computed as Ah internally using `cumtrapz(I, t)/3600`.

6. **Missing temperature for DT curves.** `batteryDifferentialCurves` returns empty `dTdV` if T is not provided. Set `DT=true` when temperature data is present; set `DT=false` when it is not.

7. **When to use individual functions vs full pipeline.** `batteryTestFeatureExtractor` + `batteryTestDataParser` is for multi-cycle data. For individual segments (partial charge, single discharge phase, etc.), use `batteryMeasurementFeatures` or `batteryDifferentialCurves` directly — they don't require full cycling data.

8. **CCCV requires both CC and CV.** If either `CC=false` or `CV=false`, CCCV features cannot be computed. The extractor handles this automatically.

9. **IC/DV/DT require `CC=true`.** Differential curve features (IC, DV, DT) are computed from the CC segments identified by the parser. Setting `IC=true` with `CC=false` silently produces no IC features. Always enable `CC=true` when using IC, DV, or DT.

10. **`batteryDifferentialCurves` requires pure CC data.** If a step contains both CC and CV portions (common in discharge steps), passing the full step data will error with "Current must remain constant and non-zero during CC mode." Use the segmented data from `batteryTestDataParser` to filter:
    ```matlab
    segmented = segmentData(parser);
    ccMask = segmented.CyclingModes == "CC" & segmented.CyclingPhases == "Discharge";
    ccData = segmented(ccMask, :);
    % Then extract per-cycle CC segments for batteryDifferentialCurves
    ```
    Prefer using the full pipeline (`batteryTestFeatureExtractor` + `extract`) which handles this filtering internally. Only use `batteryDifferentialCurves` directly when you need the raw IC/DV curve data (e.g., for overlaid curve plots).

---

## Typical Workflows

**Before running any workflow:** Apply the Interaction Model (Stop or Proceed). If no STOP condition holds, run the extraction and report the mappings, CyclingPhase, and feature configuration afterward; if one does, present the proposal and wait for confirmation first.

### Workflow 1: Track degradation across cycles
```matlab
% Check protocol consistency first (run with the MATLAB current folder set to the
% skill's scripts/ directory via the MCP project_path — do not use addpath)
result = checkCyclingProtocol(cyclingData, ...
    CurrentVariable="I", VoltageVariable="V", ...
    TimeVariable="t", CycleIndexVariable="Cycle", ...
    StepIndexVariable="Step");

% Parse multi-cycle data (exclude anomalous cycles if user confirmed)
parser = batteryTestDataParser(cyclingData, ...
    CurrentVariable="I", VoltageVariable="V", ...
    TimeVariable="t", CycleIndexVariable="Cycle", ...
    StepIndexVariable="Step", ...
    ExcludedCycles=result.AnomalousCycles);

% Extract IC + capacity features per cycle
% Note: CC=true is required for IC/DV/DT to work
extractor = batteryTestFeatureExtractor( ...
    CyclingPhase="Charge", IC=true, CycleCumulative=true, ...
    Statistics=false, CC=true, CV=false, CCCV=false);
features = extract(extractor, parser);

% features is a table: 1 row per cycle, columns = feature values
% Use for trending, anomaly detection, or RUL model training
```

### Workflow 2: Partial charge segment analysis
```matlab
% batteryMeasurementFeatures works on ANY single-phase segment:
% partial charge, partial discharge, CC, CV, or mixed CC+CV
V = partialChargeData.Voltage;
I = partialChargeData.Current;
T = partialChargeData.Temperature;
t = partialChargeData.Time;
stats = batteryMeasurementFeatures(V, I, T, t);

% For differential curves, data MUST be constant-current:
idx = data.Mode == "CC";
[dQdV, ~, ~] = batteryDifferentialCurves(V(idx), I(idx), T(idx), t(idx), ...
    PostSmoothingMethod="gaussian", PostSmoothingWindowSize=15);
icFeatures = batteryDifferentialCurveFeatures(dQdV);
```

(For the full function list with availability and selection guidance, see the API Overview table near the top of this skill.)

----

Copyright 2026 The MathWorks, Inc.

----
