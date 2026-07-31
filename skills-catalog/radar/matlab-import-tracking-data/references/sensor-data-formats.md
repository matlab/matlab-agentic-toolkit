# Task-Oriented Sensor Data Formats

## Key Principle

Never hardcode `dataFormat` fields. Properties on the sensor spec control what fields appear and their sizes. Always:

1. Create the spec
2. Configure properties based on the user's data
3. Call `dataFormat(sensorSpec)` to get the required struct
4. Map user data to those fields

---

## Prebuilt Sensor Specs

### Aerospace Monostatic Radar

```matlab
sensorSpec = trackerSensorSpec('aerospace','radar','monostatic');
```

**Properties that affect `dataFormat`:**

| Property | Default | Effect |
|---|---|---|
| `HasElevation` | `true` | Adds/removes Elevation, ElevationAccuracy, LookElevation |
| `HasRangeRate` | `true` | Adds/removes RangeRate, RangeRateAccuracy |
| `IsPlatformStationary` | `true` | When false: adds PlatformPosition (3×N), PlatformOrientation (3×3×N), PlatformVelocity (3×N), PlatformAngularVelocity (3×N) per look |
| `MaxNumLooksPerUpdate` | `30` | Size of Look* arrays |
| `MaxNumMeasurementsPerUpdate` | `10` | Size of Detection* arrays |

**Other configurable properties:** PlatformPosition, PlatformOrientation, MountingLocation, MountingAngles, FieldOfView, RangeLimits, RangeRateLimits, AzimuthResolution, RangeResolution, ElevationResolution, RangeRateResolution, DetectionProbability, FalseAlarmRate.

**Typical `dataFormat` output (stationary, full):**
```
LookTime, LookAzimuth, LookElevation,
DetectionTime, Azimuth, Elevation, Range, RangeRate,
AzimuthAccuracy, ElevationAccuracy, RangeAccuracy, RangeRateAccuracy
```

### Aerospace Bistatic Radar

```matlab
sensorSpec = trackerSensorSpec('aerospace','radar','bistatic');
```

**Properties that affect `dataFormat`:**

| Property | Default | Effect |
|---|---|---|
| `HasElevation` | `false` | Adds/removes Elevation, ElevationAccuracy |
| `HasRangeRate` | `false` | Adds/removes RangeRate, RangeRateAccuracy |
| `MeasurementMode` | `"range-angle"` | `"range-only"` removes azimuth fields |
| `IsReceiverStationary` | `true` | When false: adds ReceiverPlatformPosition/Orientation per look |
| `IsEmitterStationary` | `true` | When false: adds EmitterPlatformPosition/Orientation per look |
| `MaxNumLooksPerUpdate` | `1` | Size of Look arrays |
| `MaxNumMeasurementsPerUpdate` | `10` | Size of Detection arrays |

**Other configurable properties:** ReceiverPlatformPosition, ReceiverPlatformOrientation, ReceiverMountingLocation, ReceiverMountingAngles, ReceiverFieldOfView, ReceiverRangeLimits, ReceiverRangeRateLimits, EmitterPlatformPosition, EmitterPlatformOrientation, EmitterMountingLocation, EmitterMountingAngles, EmitterFieldOfView, EmitterRangeLimits, EmitterRangeRateLimits, AzimuthResolution, RangeResolution, DetectionProbability, FalseAlarmRate.

### Aerospace ESM / Direction-Finder

```matlab
sensorSpec = trackerSensorSpec('aerospace','radar','direction-finder');
```

Same structure as monostatic radar but angle-only: no Range or RangeRate fields in `dataFormat`. Properties: `HasElevation`, `IsPlatformStationary`, `MaxNumLooksPerUpdate`, `MaxNumMeasurementsPerUpdate`.

### Aerospace IR (Angle-Only)

```matlab
sensorSpec = trackerSensorSpec('aerospace','infrared','angle-only');
```

Same as direction-finder. Angle-only measurements (azimuth, elevation).

### Automotive Radar (Clustered Points)

```matlab
sensorSpec = trackerSensorSpec('automotive','radar','clustered-points');
```

**Properties that affect `dataFormat`:**

| Property | Default | Effect |
|---|---|---|
| `HasElevation` | `true` | Adds/removes Elevation, ElevationAccuracy |
| `MaxNumMeasurements` | `64` | Size of measurement arrays |
| `ReferenceFrame` | `'ego'` | `'ego'`: EgoSpeed + EgoAngularVelocity. `'global'`: EgoPosition + EgoVelocity + EgoOrientation + EgoAngularVelocity |

**Other properties:** MountingLocation, MountingAngles, FieldOfView, MaxRange, MaxRangeRate, DetectionProbability, NumFalsePositivesPerScan, NumNewTargetsPerScan.

**Important:** This spec expects **clustered detections** (one per object), not raw point clouds. If user has raw radar points, flag the need for preprocessing (DBSCAN, `clusterDBSCAN`, `partitionDetections`).

### Automotive Camera (Bounding Boxes)

```matlab
sensorSpec = trackerSensorSpec('automotive','camera','bounding-boxes');
```

**Properties that affect `dataFormat`:**

| Property | Default | Effect |
|---|---|---|
| `MaxNumMeasurements` | `64` | Columns of BoundingBox matrix |
| `ReferenceFrame` | `'ego'` | `'ego'`: just Time + BoundingBox. `'global'`: adds EgoPosition + EgoOrientation |

**BoundingBox format:** 4×N matrix — `[x; y; width; height]` in pixels.

**Other properties:** MountingLocation, MountingAngles, EgoOriginHeight, Intrinsics (3×3 camera matrix), ImageSize, MaxRange, CenterAccuracy, HeightAccuracy, WidthAccuracy, DetectionProbability, NumFalsePositivesPerImage, NumNewTargetsPerImage.

### Automotive Lidar (Bounding Boxes)

```matlab
sensorSpec = trackerSensorSpec('automotive','lidar','bounding-boxes');
```

**Properties that affect `dataFormat`:**

| Property | Default | Effect |
|---|---|---|
| `MaxNumMeasurements` | `64` | Columns of BoundingBox matrix |
| `ReferenceFrame` | `'ego'` | `'ego'`: just Time + BoundingBox. `'global'`: adds EgoPosition + EgoOrientation |

**BoundingBox format:** 9×N matrix — `[x; y; z; length; width; height; yaw; pitch; roll]`.

**Other properties:** MountingLocation, MountingAngles, AzimuthLimits, ElevationLimits, MaxRange, DetectionProbability, CenterAccuracy, DimensionAccuracy, OrientationAccuracy, NumFalsePositivesPerScan, NumNewTargetsPerScan.

---

## Custom Sensor Spec

Use when no prebuilt spec matches but measurements fit a standard model.

```matlab
sensorSpec = trackerSensorSpec('custom');
sensorSpec.MeasurementModel = sensorMeasurementModel('<modelName>');
sensorSpec.DetectabilityModel = sensorDetectabilityModel('<modelName>');
sensorSpec.ClutterModel = sensorClutterModel('<modelName>');
sensorSpec.BirthModel = sensorBirthModel('<modelName>');
```

**Properties:**

| Property | Default | Effect |
|---|---|---|
| `MaxNumMeasurements` | `32` | Columns of Measurements matrix |
| `MaxNumTimestamps` | `50` | Size of Time array (when UpdateModels=true) |
| `UpdateModels` | `false` | When true: adds Time, TimeVaryingModelData, MeasurementVaryingModelData |
| `ModelUpdateFcn` | `[]` | Function to update model params from TimeVaryingModelData |

**`dataFormat` output:**

- `UpdateModels=false`: `MeasurementTime` (1×N), `Measurements` (M×N)
- `UpdateModels=true`: `Time` (1×MaxNumTimestamps), `TimeVaryingModelData` (1×MaxNumTimestamps struct), `MeasurementTime` (1×N), `Measurements` (M×N), `MeasurementVaryingModelData` (1×N struct)

Where M = measurement dimension (from model), N = MaxNumMeasurements.

### sensorMeasurementModel Catalog

| Model Name | Dim | Properties | Use Case |
|---|---|---|---|
| `"azimuth"` | 1 | OriginPosition, Orientation, AzimuthVariance | Passive bearing-only (ESM, DF) |
| `"azimuth-range"` | 2 | OriginPosition, Orientation, AzimuthVariance, RangeVariance | 2D radar |
| `"azimuth-range-rangerate"` | 3 | OriginPosition, OriginVelocity, Orientation, AzimuthVariance, RangeVariance, RangeRateVariance | 2D radar with Doppler |
| `"azimuth-elevation"` | 2 | OriginPosition, Orientation, AzimuthVariance, ElevationVariance | Angle-only (IR, passive) |
| `"azimuth-elevation-range"` | 3 | OriginPosition, Orientation, AzimuthVariance, ElevationVariance, RangeVariance | 3D radar |
| `"azimuth-elevation-range-rangerate"` | 4 | OriginPosition, OriginVelocity, Orientation, AzimuthVariance, ElevationVariance, RangeVariance, RangeRateVariance | Full 3D radar |
| `"range"` | 1 | OriginPosition, Orientation, RangeVariance | Range-only |
| `"range-rangerate"` | 2 | OriginPosition, OriginVelocity, Orientation, RangeVariance, RangeRateVariance | Range + Doppler |
| `"position"` | 2 or 3 | NumMeasurementDimensions, OriginPosition, Orientation, PositionVariance | Cartesian (GPS, fused) |
| `"position-velocity"` | 4 or 6 | NumMeasurementDimensions, OriginPosition, OriginVelocity, Orientation, PositionVariance, VelocityVariance | Cartesian pos+vel |

### sensorDetectabilityModel Catalog

| Model Name | Properties |
|---|---|
| `"field-of-view"` | OriginPosition, Orientation, AzimuthLimits, ElevationLimits, RangeLimits, DetectionProbability |
| `"field-of-view-with-rangerate"` | Same + OriginVelocity, RangeRateLimits |
| `"composite-field-of-view"` | FieldsOfView (cell of FOV models), NumModels |
| `"uniform"` | DetectionProbability |

### sensorClutterModel Catalog

| Model Name | Properties |
|---|---|
| `"uniform-poisson"` | ClutterDensity |
| `"nonuniform-poisson"` | ClutterDensityFcn, ModelData |

### sensorBirthModel Catalog

| Model Name | Properties |
|---|---|
| `"uniform-poisson"` | BirthDensity |
| `"nonuniform-poisson"` | BirthDensityFcn, ModelData |

---

## ReferenceFrame Inference (Automotive Only)

| User's data has... | Set |
|---|---|
| Only sensor-relative measurements (typical raw sensor output) | `ReferenceFrame = 'ego'` |
| Ego vehicle position/orientation in a global frame (from GPS/INS) | `ReferenceFrame = 'global'` |

---

## Padding and Array Sizing

When the user's data has fewer detections than `MaxNumMeasurements` at a given timestep, fill unused slots with zeros. Set the max to match the largest number of detections in the dataset, or leave at default if data fits.

```matlab
% Example: populate struct with N detections out of MaxNum slots
data = dataFormat(sensorSpec);
data.DetectionTime(1:N) = detTimes;
data.Azimuth(1:N) = azValues;
% Remaining slots stay zero (indicates no detection)
```

----

Copyright 2026 The MathWorks, Inc.
