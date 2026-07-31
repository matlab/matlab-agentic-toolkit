---
name: matlab-ncap-testing
description: >
  Generate Euro NCAP test scenarios and variants using the  ADT Euro NCAP support package.
  Use when creating NCAP seed scenarios, generating variants, translating between drivingScenario
  and RoadRunner, plotting scenario descriptors, computing NCAP scores, or exporting reports.
  Triggers on: ncapScenario, euroAssessment, getScenario, getScenarioDescriptor, generateVariants,
  ScenarioDescriptor, ScenarioDescriptorPlot, ncapScore, ncapReport, exportReport, configureVUT,
  assessmentTable, Euro NCAP, CCRs, CCRm, CCRb, CCFtap, CCCscp, CPNA, CPFA, CBNA, variant generation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Generate Euro NCAP Variants

Create Euro NCAP seed scenarios, generate variants, translate between simulators, plot descriptors, and compute scores using the ADT Euro NCAP support package APIs.

## When to Use

- Creating Euro NCAP seed scenarios (any protocol year)
- Generating scenario variants from seeds
- Translating scenarios between drivingScenario and RoadRunner via descriptors
- Plotting scenario descriptors (single or multi-descriptor grids)
- Computing NCAP scores and generating/exporting reports
- Any workflow mentioning Euro NCAP test names (CCRs, CCFtap, CCCscp, CPNA, etc.)

## When NOT to Use

- Building custom drivingScenario from scratch (roads, lanes, actors) — use drivingScenario core APIs directly
- RoadRunner scene/project management (creating projects, importing assets) — use RoadRunner scene APIs
- Custom `variationProperties` for non-NCAP scenarios
- Simulink co-simulation or AEB test bench setup

## Decision Tree: Which API Path?

```
User wants Euro NCAP scenarios?
│
├─ Protocol year 2023 (or unspecified)?
│   └─ Use standalone: ncapScenario("SA AEB CCFtap")
│      - Test names use prefix: "SA AEB", "SA LSS", "VRU AEB", "VRU LSS"
│      - Supports ShowProgress name-value
│      - Returns ScenarioDescriptor
│
└─ Protocol year 2026?
    └─ Use euroAssessment path:
       1. ea = euroAssessment(2026)
       2. configureVUT(ea, ...) — if custom VUT needed
       3. descriptor = ncapScenario(ea, "CA FC CCFtap")
       - Test names use prefix: "CA FC"
       - Does NOT support ShowProgress
       - Required for scoring/reporting workflow
```

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `ncapScenario` | Generate seed descriptor(s) from test name | R2024a |
| `euroAssessment` | Store 2026 protocol specs and scores | R2025a |
| `configureVUT` | Set StabilizationTime, AssetPath on euroAssessment | R2026a |
| `getScenario` | Convert descriptor → drivingScenario or RoadRunner | R2022b |
| `getScenarioDescriptor` | Extract descriptor from existing drivingScenario | R2022b |
| `generateVariants` | Generate variant descriptors from seed + variationProperties | R2023a |
| `plot` (ScenarioDescriptor) | Plot descriptor(s), returns ScenarioDescriptorPlot | R2026a |
| `configure` (ScenarioDescriptorPlot) | Set GridSize, Title, SubPlotTitles, CropType | R2026a |
| `assessmentTable` | Create empty assessment table for a test | R2025a |
| `ncapScore` | Compute score from assessment table (returns struct) | R2025a |
| `ncapReport` | Generate visual report figure | R2025a |
| `exportReport` | Export report to PDF/PNG/JPG file | R2026a |
| `table2scenario` | Create ScenarioDescriptor from tabular data (sceneSpec, actorSpec, eventSpec) | R2024a |
| `exportScenario` (roadrunner) | Export from RoadRunner to OpenSCENARIO | R2022a |

## Pattern: Seed-Only Generation

Use when you need just the seed scenario (1 descriptor), not all variants.

```matlab
% 2023 standalone — single seed
descriptor = ncapScenario("SA AEB CCFtap");

% 2026 via euroAssessment — single seed
ea = euroAssessment(2026);
descriptor = ncapScenario(ea, "CA FC CCFtap");
```

`AllScenarios=true` generates the seed AND all protocol-defined variants. Do NOT use it when only the seed is requested.

**Output arguments:** The two-output form `[descriptors, scenarioInfo] = ncapScenario(...)` requires `AllScenarios=true`. Without it, only one output is allowed — requesting two outputs errors with "Too many output arguments".

## Pattern: All Variants Generation

Use when the user wants all test variants for a given scenario.

```matlab
% 2023 — all variants with progress
[descriptors, scenarioInfo] = ncapScenario("SA AEB CCCscp", AllScenarios=true);

% 2026 — all variants
ea = euroAssessment(2026);
[descriptors, scenarioInfo] = ncapScenario(ea, "CA FC CCCscp", AllScenarios=true);
```

## Pattern: ShowProgress

The `ShowProgress` name-value controls built-in progress display during generation.

```matlab
% Show command-line progress (default behavior)
descriptor = ncapScenario("SA AEB CCRs", ShowProgress="CommandLine");

% Suppress progress
descriptor = ncapScenario("SA AEB CCRs", ShowProgress="No");
```

**Important:** `ShowProgress` is only supported on the standalone `ncapScenario(testName)` call. It is NOT supported when using the `euroAssessment` overload `ncapScenario(ea, testName)`.

When the user asks to "show progress" or "display progress", use `ShowProgress="CommandLine"` (or omit it since it's the default). Do NOT set `ShowProgress="No"` and then implement manual fprintf progress.

## Pattern: DSD ↔ RoadRunner Translation

Use `getScenario` to translate a descriptor to either simulator. Never export to OpenSCENARIO and re-import as a translation method.

```matlab
% Descriptor → drivingScenario
ds = getScenario(descriptor, Simulator="DrivingScenario");

% Descriptor → RoadRunner (requires active RoadRunner instance)
rrApp = roadrunner("C:/path/to/project");
rrScen = getScenario(descriptor, Simulator="RoadRunner", SimulatorInstance=rrApp);
```

**Key rules:**
- `getScenario` requires Name-Value syntax. `Simulator` must be specified as a Name-Value pair, not a positional argument.
- With `Simulator="DrivingScenario"`: accepts an array of descriptors and returns an array of `drivingScenario` objects.
- With `Simulator="RoadRunner"`: accepts only a **single descriptor** per call — returns one `Simulink.ScenarioSimulation` object. Passing an array errors with "Too many input arguments". Loop over descriptors individually for batch RoadRunner translation.

## Pattern: ScenarioDescriptorPlot

### Configure options

| Property | Values | Notes |
|----------|--------|-------|
| `GridSize` | `[rows cols]`, max product = 20 | Error if > 20 subplots |
| `Title` | string | Figure title |
| `SubPlotTitles` | string array | Must match descriptor count exactly |
| `CropType` | `"None"`, `"GlobalWaypoint"`, `"DynamicWaypoint"`, `"RuntimeActorsCrop"` | Controls plot cropping |

### Single or small array (≤20 descriptors)

```matlab
sdp = plot(descriptors);
configure(sdp, Title="My Scenarios", GridSize=[3 4], ...
    SubPlotTitles=["Variant 1", "Variant 2", "Variant 3"]);
```

### Large array (>20 descriptors)

`ScenarioDescriptorPlot` supports a maximum of 20 subplots per figure via `GridSize`. For larger arrays, split across multiple calls:

```matlab
% Plot first 20
sdp1 = plot(descriptors(1:20));
configure(sdp1, Title="Variants 1-20", GridSize=[4 5]);

% Plot remaining
sdp2 = plot(descriptors(21:end));
configure(sdp2, Title="Variants 21-30", GridSize=[2 5]);
```

### Play/seek for animation

```matlab
sdp = plot(descriptor);
play(sdp);          % Animate the scenario
seek(sdp, 2.5);    % Jump to t=2.5s
close(sdp);        % Close figure
```

## Pattern: 2026 Full Pipeline (Score + Report)

```matlab
% 1. Create assessment object
ea = euroAssessment(2026);

% 2. Configure VUT (optional)
configureVUT(ea, StabilizationTime=2, AssetPath="Vehicles/SK_SUV.fbx");

% 3. Generate all variants
[descriptors, scenarioInfo] = ncapScenario(ea, "CA FC CCFtap", AllScenarios=true);

% 4. Create assessment table and populate results
% Column names are test-dependent — inspect with at.Properties.VariableNames
% Common columns: ImpactVelocity (CCFtap, CCCscp) or RelativeImpactVelocity (CCRs, CCRm, CCRb)
at = assessmentTable(ea, "CA FC CCFtap");
at.ImpactVelocity = zeros(height(at), 1);  % Replace with actual sim results

% 5. Compute score (returns struct, not scalar)
[score, updatedTable] = ncapScore(ea, "CA FC CCFtap", at);
fprintf("Total score: %.2f / %.2f\n", score.AggregateScore.Total, score.AvailableScore.Total);

% 6. Generate report figure
fig = ncapReport(ea, "CA FC CCFtap");

% 7. Export report to file
exportReport(ea, "CA FC CCFtap", "ncap_report.pdf");
```

## Pattern: table2scenario (Custom Descriptors from Tables)

Use `table2scenario` to create a `ScenarioDescriptor` from user-defined tabular data. This is the programmatic entry point when you have scenario parameters in table form rather than using the predefined NCAP test definitions.

```matlab
% Scene: straight road, 100m
sceneSpec = table(1, {'Straight'}, 100, 0, NaN, ...
    VariableNames=["RoadElementID", "RoadElementType", "Length_Radius", ...
                   "DeltaHeading", "ParentIntersectionID"]);

% Actor: one car (Ego) on road 1, lane 1
actorSpec = table(1, 1, 1, {'Car'}, {'Ego'}, ...
    {'4.7, 1.8, 1.4, 0.5, 0.9, 2.8'}, {'Along'}, {'10%, 50%'}, ...
    VariableNames=["ActorID", "RoadID", "LaneID", "ActorType", ...
                   "ActorName", "Dimension", "Heading", "RelativePosition"]);

% Event: fixed velocity start at 15 m/s
eventSpec = table(1, 1, {'FixedVelocityStart'}, 15, NaN, NaN, ...
    VariableNames=["EventID", "ActorID", "EventType", "Speed", ...
                   "Distance", "EventTrigger"]);

descriptor = table2scenario(sceneSpec, actorSpec, eventSpec);
```

**Key rules:**
- `sceneSpec` columns: `RoadElementID`, `RoadElementType`, `Length_Radius`, `DeltaHeading`, `ParentIntersectionID`
- `actorSpec` columns: `ActorID`, `RoadID`, `LaneID`, `ActorType`, `ActorName`, `Dimension`, `Heading`, `RelativePosition`
- `eventSpec` columns: `EventID`, `ActorID`, `EventType`, `Speed`, `Distance`, `EventTrigger`
- Returns a `ScenarioDescriptor` — same type as `ncapScenario` output
- The returned descriptor works with all downstream APIs: `getScenario`, `plot`, `generateVariants`
- Used internally by the NCAP pipeline; users can call it directly for custom (non-NCAP) scenarios

## Pattern: OpenSCENARIO Export with Rear Axle

```matlab
% Configure export options
opts = openScenarioXMLExportOptions(RelocateVehicleOrigin=true);

% Export from RoadRunner
exportScenario(rrApp, "output.xosc", "OpenSCENARIO XML", opts);
```

See `references/export-options.md` for full export configuration details.

## Test Name Conventions

**Critical:** Euro NCAP test names must be specified in full. Short names like `"CCFtap"` or `"CCCscp"` are NOT valid.

| Protocol | Prefix Pattern | Example |
|----------|---------------|---------|
| 2023 standalone | `"SA AEB ..."`, `"SA LSS ..."`, `"VRU AEB ..."`, `"VRU LSS ..."` | `"SA AEB CCFtap"` |
| 2026 euroAssessment | `"CA FC ..."` | `"CA FC CCFtap"` |

The short code (e.g., `CCFtap`, `CCCscp`, `CCRs`) is always the LAST part of the full name.

See `references/ncap-test-names.md` for the complete lookup table of all valid test names.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `ncapScenario("CCFtap")` | Short names are not valid | `ncapScenario("SA AEB CCFtap")` |
| `ncapScenario("SA AEB CCFtap")` for 2026 | Wrong prefix for 2026 protocol | `ncapScenario(ea, "CA FC CCFtap")` with `ea = euroAssessment(2026)` |
| `getScenario(d, "RoadRunner")` | Positional arg not supported | `getScenario(d, Simulator="RoadRunner", SimulatorInstance=rrApp)` |
| Setting `ShowProgress="No"` then using fprintf | Defeats built-in progress | Omit ShowProgress (default is "CommandLine") or set `ShowProgress="CommandLine"` |
| Using `AllScenarios=true` for seed-only | Generates all variants unnecessarily | Omit `AllScenarios` for seed only |
| DSD export → OpenSCENARIO → importScenario for RR | Roundabout, breaks pedestrians | `getScenario(d, Simulator="RoadRunner", SimulatorInstance=rrApp)` |
| Inventing `VUTType` or `NcapYear` params | These don't exist | Use `configureVUT(ea, AssetPath=...)` and `euroAssessment(2026)` |
| `ShowProgress` with euroAssessment overload | Not supported on that overload | Only use with standalone `ncapScenario(testName)` |
| `[d, info] = ncapScenario(ea, name)` without AllScenarios | "Too many output arguments" error | Use single output for seed, or add `AllScenarios=true` for two outputs |
| `configureVUT` called AFTER `ncapScenario` | Silently has no effect — config not applied | Always call `configureVUT` BEFORE `ncapScenario` |
| `SubPlotTitles` count ≠ descriptor count | "Invalid size of subplot titles" error | Provide exactly one title per descriptor |
| `CropType="tight"` or other invented values | Invalid value error | Use: `"None"`, `"GlobalWaypoint"`, `"DynamicWaypoint"`, or `"RuntimeActorsCrop"` |
| `plot(descriptors)` with GridSize > [4 5] | Max 20 subplots per figure | Split array into chunks of ≤20 |
| `fprintf("%.2f", score)` after `ncapScore` | `score` is a struct, not scalar | Access `score.AggregateScore.Total` for the numeric value |
| `exportReport(ea, name, "report.html")` | HTML not supported | Use `.pdf`, `.png`, or `.jpg` extension |
| `at.ImpactVelocity = ...` for CCRs/CCRm/CCRb tests | Column is `RelativeImpactVelocity`, not `ImpactVelocity` | Check `at.Properties.VariableNames` after `assessmentTable` — use the actual column name |
| `getScenario(descriptors, Simulator="RoadRunner", ...)` with array | RoadRunner only accepts one descriptor at a time | Loop: `for i=1:numel(descriptors), getScenario(descriptors(i), ...); end` |

## Conventions

- Always use full test names — never abbreviate
- Use `euroAssessment(2026)` for any 2026-protocol workflow (scoring, reporting, configureVUT)
- Use standalone `ncapScenario(testName)` for simple 2023 generation without scoring
- Use `getScenario` for ALL simulator translations — never export+reimport
- Use `exportReport` (R2026a) for file export — do not write custom report export code
- Use `exportScenario` (roadrunner method) for OpenSCENARIO export from RoadRunner
- Set `RelocateVehicleOrigin=true` in export options when rear axle reference is needed

## Required Toolboxes

- Automated Driving Toolbox (R2026a)
- Automated Driving Toolbox Test Suite for Euro NCAP Protocols (support package, R2024a+)

----

Copyright 2026 The MathWorks, Inc.

----
