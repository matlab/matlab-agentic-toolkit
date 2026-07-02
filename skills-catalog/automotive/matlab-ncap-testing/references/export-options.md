# Export Options Reference

Configuration for exporting scenarios from RoadRunner and exporting NCAP reports.

## OpenSCENARIO Export from RoadRunner

### exportScenario

```matlab
exportScenario(rrApp, filename, formatname)
exportScenario(rrApp, filename, formatname, exportoptions)
```

| Parameter | Values |
|-----------|--------|
| `formatname` | `"OpenSCENARIO XML"` or `"OpenSCENARIO DSL"` |
| `exportoptions` | `openScenarioXMLExportOptions` or `openScenarioDSLExportOptions` |

### openScenarioXMLExportOptions

```matlab
opts = openScenarioXMLExportOptions(Name=Value)
```

| Property | Default | Purpose |
|----------|---------|---------|
| `RelocateVehicleOrigin` | `false` | Set `true` for rear axle midpoint as reference |
| `OpenScenarioVersion` | `"auto"` | `1.0` or `1.1` |
| `OpenDriveFileName` | — | Custom path for .xodr file |
| `OpenDriveOptions` | `"auto"` | `openDriveExportOptions` object |
| `MoveNonInstantaneousInitActions` | `"auto"` | Move init actions to stories |
| `NoOpsAction` | `"auto"` | `"Unspecified"`, `"UserDefined"`, `"Empty"`, `"EmptyPrivate"` |
| `catalogOptions` | `"auto"` | `catalogOptions` object for catalog references |

### Rear Axle Export Pattern

When the user requests "rear axle export" or "rear axle as reference point":

```matlab
opts = openScenarioXMLExportOptions(RelocateVehicleOrigin=true);
exportScenario(rrApp, "scenario.xosc", "OpenSCENARIO XML", opts);
```

## NCAP Report Export

### exportReport (euroAssessment method)

Export assessment results to a file. Introduced in R2026a.

```matlab
exportReport(euroAssessmentObj, ncapTestName, fileName)
exportReport(euroAssessmentObj, ncapGroupName, fileName)
```

| Parameter | Description |
|-----------|-------------|
| `euroAssessmentObj` | euroAssessment object with computed scores |
| `ncapTestName` | Single test name (e.g., `"CA FC CCFtap"`) |
| `ncapGroupName` | Group name for multi-test report |
| `fileName` | Output file path with extension (`.pdf`, `.png`, `.jpg`) |

### Full Scoring + Export Pipeline

```matlab
ea = euroAssessment(2026);
configureVUT(ea, StabilizationTime=2, AssetPath="Vehicles/SK_SUV.fbx");

% Generate variants and create assessment table
[descriptors, info] = ncapScenario(ea, "CA FC CCFtap", AllScenarios=true);
at = assessmentTable(ea, "CA FC CCFtap");
at.ImpactVelocity = zeros(height(at), 1);

% Score and report
[score, updatedTable] = ncapScore(ea, "CA FC CCFtap", at);
fig = ncapReport(ea, "CA FC CCFtap");
exportReport(ea, "CA FC CCFtap", "ccftap_report.pdf");
```

### configureVUT

Configure Vehicle Under Test parameters before scenario generation.

```matlab
configureVUT(ea, StabilizationTime=2, AssetPath="Vehicles/SK_SUV.fbx")
```

| Parameter | Range | Default |
|-----------|-------|---------|
| `StabilizationTime` | [1, 3] seconds | 3 |
| `AssetPath` | Path to .fbx asset file | `"Vehicles\Sedan.fbx"` |

**Note:** `configureVUT` must be called BEFORE `ncapScenario` for the configuration to take effect.

----

Copyright 2026 The MathWorks, Inc.

----
