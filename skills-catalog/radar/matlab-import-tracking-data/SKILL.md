---
name: matlab-import-tracking-data
description: "Import raw data (CSV, XLSX, TXT, or MATLAB tables) into formats used by Sensor Fusion and Tracking Toolbox. Handles both ground truth trajectories and sensor detection data. For truth: builds trackingScenarioRecording, tuning timetable, truthlog, or converted table. For sensor data: builds task-oriented dataFormat structs (preferred) or objectDetection arrays (legacy). Use when importing flight logs, GPS logs, radar detections, IR measurements, lidar/camera bounding boxes, ADS-B data, AIS ship tracks, or any recorded data for use with trackers, filter tuning, or tracker evaluation."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# Tracking Data Import

Import raw data into MATLAB for use with Sensor Fusion and Tracking Toolbox. Handles ground truth trajectories and sensor detection data. Writes plain MATLAB code.

## When to Use

- User has recorded trajectory/position data and wants to replay, tune filters, or evaluate trackers
- User has sensor measurements (radar, IR, lidar, camera, sonar) and wants to feed them to a tracker
- User mentions flight logs, GPS logs, ADS-B, AIS, radar recordings, lidar point clouds, camera detections
- User asks about `trackingDataImporter`, `objectDetection`, `trackerSensorSpec`, `dataFormat`, or importing data for trackers

## When NOT to Use

- User is generating synthetic scenarios from scratch (use `trackingScenario`)
- User already has data in the correct SFTT format
- User needs to design a tracker or write tracking algorithms (use the multi-object-tracking skill)
- User is working with raw signal processing (waveform design, range-Doppler maps)

---

## Routing: What Kind of Data?

### Step 1: Determine data type

Ask: "What kind of data are you importing?"

| User's data | Route |
|---|---|
| Recorded positions/trajectories (truth, GPS, flight logs) | **Truth pathway** |
| Sensor measurements (radar detections, IR bearings, lidar boxes, camera boxes) | **Sensor pathway** |

Inference signals from column inspection:
- Truth-like: continuous position per object ID over time, no noise/accuracy columns
- Sensor-like: measurement quantities (range, azimuth, RCS), accuracy columns, multiple detections per timestep without guaranteed ID continuity

### Step 2 (sensor data only): Identify sensor type and target application

**Important:** If Step 1 determined the data is truth/trajectory (positions per platform over time), stay in the Truth Pathway. Do NOT enter this step just because the user mentions IMM, UKF, or filter tuning — those refer to what the tuner will produce, not how to format the input data. Truth data → timetable. Sensor data → objectDetection or dataFormat struct.

Ask: "What sensor produced this data?" and "What are you tracking?"

Then decide the API internally (do NOT ask the user about APIs):

**Use task-oriented path (preferred) when:**
- A prebuilt `trackerSensorSpec` matches, OR
- Measurements fit a `sensorMeasurementModel` (any combo of az/el/range/rr, position, position-velocity)
- AND user does not need TOMHT/PHD/GridRFS tracker or non-EKF filters

**Use legacy objectDetection path when:**
- User needs TOMHT, PHD, or GridRFS tracker (task-oriented only supports GNN/JIPDA)
- User needs UKF, CKF, IMM, particle filter (task-oriented uses EKF internally)
- Measurements don't fit any `sensorMeasurementModel` (TDOA, custom geometry)
- User explicitly requests objectDetection (for `trackingFilterTuner` or existing code)

---

## Truth Pathway

Truth/trajectory data (positions, velocities per platform over time) **always** produces timetables or struct arrays — never objectDetection. This applies even when the user mentions filter tuning, IMM, UKF, or other filter types. For tuning, the truth pathway produces timetables with `Time` (duration) and `Position`, `Velocity` columns (or a single `State` vector). The tuner's *detection* input must come from separate sensor measurement data — do NOT fabricate objectDetection from truth positions.

### Step 1: Ask the User (2 questions only)

1. **What output do you need?** (recording / tuning data / truth log / converted table)
2. **Where is the data?** (file path or workspace variable name)

### Step 2: Inspect the Data

**Read the user's actual file** — never generate synthetic data when the user provides a file path. Use `readtable` or equivalent to load the file, then display columns + sample rows. Infer the data model — do not ask yet:
- Geo vs Cartesian, category, time column & format, platform/class ID columns
- Position, velocity, orientation, dimension columns
- Units (default degrees/meters/m-per-s; adjust if names hint otherwise)

See `references/interpreter-categories.md` for category selection and column name patterns.

### Step 3: Propose Mapping — Let User Confirm/Edit

**Always present a data summary before writing any conversion code**, even when the mapping is obvious. Include ALL of:
- Column names found in the data
- Detected units (from column name hints or defaults)
- Number of platforms/objects
- Time span (first/last timestamp, total duration)
- Proposed column-to-field mapping table (show unmapped columns)

Present inferred mappings as a table. Iterate until confirmed.

### Step 4: Ask About Output Frame (geo data only)

Options: Cartesian ECEF, Cartesian Fixed NED/ENU (needs origin), Geodetic Local NED/ENU. Default: same as input. See `references/coordinate-transforms.md`.

### Step 5: Generate and Run Code

**Read `references/output-formats.md`** before generating code — it defines required fields and defaults for missing states. Follow patterns in `references/code-patterns.md`. Key steps:
1. Read data → extract columns → convert units → parse time
2. Remap platform IDs to sequential integers
3. Transform coordinates if needed
4. Build output structure (see `references/output-formats.md`)
5. Sort by time before building output

### Step 6: Visualize

See `references/visualization.md`. Geo → `trackingGlobeViewer`; Non-geo → `theaterPlot`.

**Stop here — do NOT run downstream tools** (trackers, `trackOSPAMetric`, `trackingFilterTuner`, etc.). The user's data is now in the correct format. Tell the user what they have and show the calling convention for their intended use case.

---

## Sensor Pathway: Task-Oriented (Preferred)

Use when measurements fit a prebuilt or custom `trackerSensorSpec`. The key insight: **`dataFormat` is dynamic** — it changes based on sensor spec properties. Never hardcode the struct; always query it.

### Step 1: Select sensor spec

| Sensor description | Spec |
|---|---|
| Aerospace monostatic radar | `trackerSensorSpec('aerospace','radar','monostatic')` |
| Aerospace bistatic radar | `trackerSensorSpec('aerospace','radar','bistatic')` |
| ESM / direction finder | `trackerSensorSpec('aerospace','radar','direction-finder')` |
| Aerospace IR (angle-only) | `trackerSensorSpec('aerospace','infrared','angle-only')` |
| Automotive radar (clustered detections) | `trackerSensorSpec('automotive','radar','clustered-points')` |
| Automotive camera (2D bounding boxes) | `trackerSensorSpec('automotive','camera','bounding-boxes')` |
| Automotive lidar (3D bounding boxes) | `trackerSensorSpec('automotive','lidar','bounding-boxes')` |
| Other standard measurements | `trackerSensorSpec('custom')` — see Step 2b |

### Step 2a: Configure spec properties from the data

Inspect the user's data and set properties that affect `dataFormat`:

**Aerospace monostatic / ESM / IR:**
- `HasElevation` — does data have elevation measurements?
- `HasRangeRate` — does data have range-rate / Doppler? (radar only)
- `IsPlatformStationary` — is sensor position fixed or moving? (false adds PlatformPosition/Orientation/Velocity per look)
- `MaxNumLooksPerUpdate` — max scan dwells per update in the data
- `MaxNumMeasurementsPerUpdate` — max detections per update in the data

**Aerospace bistatic:**
- `HasElevation`, `HasRangeRate` — as above
- `MeasurementMode` — `"range-angle"` or `"range-only"`
- `IsReceiverStationary`, `IsEmitterStationary` — adds platform fields when false

**Automotive radar:**
- `HasElevation`, `MaxNumMeasurements`
- `ReferenceFrame` — `'ego'` (measurements in body frame) or `'global'` (ego pose in global frame available)

**Automotive camera / lidar:**
- `MaxNumMeasurements`
- `ReferenceFrame` — `'ego'` or `'global'`

### Step 2b: Custom sensor spec (when no prebuilt fits)

For sensors with standard measurement types but no prebuilt spec (e.g., marine radar, sonar):

```matlab
sensorSpec = trackerSensorSpec('custom');
sensorSpec.MeasurementModel = sensorMeasurementModel('<modelName>');
sensorSpec.DetectabilityModel = sensorDetectabilityModel('<modelName>');
sensorSpec.ClutterModel = sensorClutterModel('<modelName>');
sensorSpec.BirthModel = sensorBirthModel('<modelName>');
```

See `references/sensor-data-formats.md` for the complete model catalogs and property details.

For moving sensors, set `UpdateModels = true` — this adds `Time`, `TimeVaryingModelData`, and `MeasurementVaryingModelData` to the `dataFormat`.

### Step 3: Inspect data — infer units, time, and reference frame

**Read the user's actual file** — never generate synthetic data when the user provides a file path. Determine:

1. **Time column & format** — detect using the same heuristics as truth pathway (see `references/time-and-units.md`). Convert to elapsed seconds from first timestamp.
2. **Measurement units** — infer from column name suffixes (`_deg`, `_rad`, `_km`, `_kts`, etc.) or ask. Target units for the `dataFormat`:
   - Angles: **degrees**
   - Ranges: **meters**
   - Range-rate: **m/s**
   - Position: **meters**
   - Velocity: **m/s**
3. **Reference frame** — if measurements are NOT in the sensor's native frame, plan a transform:
   - Sensor-native = the frame the sensor naturally reports in (spherical for radar/ESM/IR, body-relative for automotive, image pixels for camera)
   - If user's data is in a world frame (e.g., Cartesian NED positions from a fused tracker) but the sensor spec expects spherical measurements, convert back to sensor-native using sensor pose
   - If user's data is in a different body frame convention (e.g., NED vs ENU), rotate accordingly
   - If already in sensor-native frame (the common case), no transform needed

### Step 4: Query `dataFormat` and propose mapping

```matlab
fmt = dataFormat(sensorSpec);
disp(fmt)
```

Present a mapping table for user confirmation:

```
Your column          →  dataFormat field        Action
"azimuth_deg"        →  LookAzimuth (1×N)      direct (deg→deg)
"range_km"           →  Range (M×N)            convert km→m (×1000)
"doppler_mps"        →  RangeRate (M×N)        direct
"timestamp_epoch"    →  MeasurementTime (1×N)  parse epoch→elapsed sec
"elev_rad"           →  LookElevation (1×N)    convert rad→deg
[unmapped: "snr"]    →  (not used)
```

Include unit conversions and frame transforms in the "Action" column. Show unmapped columns. **Iterate until user confirms.**

### Step 5: Configure sensor performance properties

Set from user input or use defaults: MountingLocation, MountingAngles, FieldOfView, RangeLimits, DetectionProbability, FalseAlarmRate/NumFalsePositivesPerScan.

### Step 6: Generate code

Write code that populates the `dataFormat` struct per timestep in a loop. The output is an array of structs (one per update) ready to be passed to a tracker. **Stop here — do NOT create or run a tracker.** Tell the user their data is ready and show them the calling convention: `tracker = multiSensorTargetTracker(targetSpec, sensorSpec, algorithm); tracks = tracker(sensorData(iUpdate))`.

**Rotation matrices from Euler angles:** When data has yaw/pitch/roll and you need a 3×3 rotation matrix (e.g., for `PlatformOrientation`), build it from a quaternion:

```matlab
R = rotmat(quaternion([yaw pitch roll], 'eulerd', 'ZYX', 'frame'), 'frame');
```

### Preprocessing flags

| Data looks like... | Action |
|---|---|
| Raw radar point cloud (many points per scan, no object association) | Flag: needs clustering. Tools: `dbscan`, `clusterDBSCAN` (Radar Toolbox), `partitionDetections`. Offer to create a working example. |
| Raw lidar XYZ points (no bounding boxes) | Flag: needs bounding box extraction. Offer example. |
| Raw camera images (no detections) | Out of scope — needs an object detector first. |

---

## Sensor Pathway: Legacy objectDetection

Use when task-oriented API doesn't fit (TOMHT/PHD tracker, non-EKF filter, custom measurements, or explicit user need).

### Standard sub-path (built-in measurement models)

For measurements that fit `cvmeas`/`cameas`/`ctmeas` — any combo of az/el/range/rr in spherical, or position/velocity in rectangular.

**Workflow:**
1. Identify measurement elements from data columns
2. **Infer units, time, and reference frame** (same as task-oriented Step 3):
   - Parse time column → elapsed seconds (see `references/time-and-units.md`)
   - Detect units from column names → convert angles to degrees, ranges to meters, velocities to m/s
   - If measurements are in a world frame but need to be in sensor-native frame (spherical or rectangular relative to sensor), transform using sensor pose
3. Set `Has*` flags: `HasAzimuth`, `HasElevation`, `HasRange`, `HasVelocity`
4. Determine `Frame`: `'spherical'` or `'rectangular'`
5. Get sensor pose per timestep (position, velocity, orientation) — or fixed values if stationary
6. **Propose mapping table** — present columns → objectDetection fields with unit/frame actions. Iterate until user confirms.
7. Build standard `MeasurementParameters` struct (see `references/objectDetection-patterns.md`)
8. Construct measurement vector in correct order:
   - Spherical: `[az, el, range, rr]` with missing elements removed
   - Rectangular: `[x, y, z, vx, vy, vz]` with missing elements removed
9. Set `MeasurementNoise` from accuracy columns or user-specified values
10. Generate `objectDetection` cell array
11. **Filter tuning data (when user has sensor measurement data for `trackingFilterTuner`):** The tuner requires detection-to-target association. If the sensor data contains a target ID column (e.g., `TargetID`, `PlatformID`, `ObjectID`):
    - Separate detections per target. Produce a cell array of detection logs (one per platform).
    - The tuner also needs truth timetables — but those come from a *separate* truth data source via the Truth Pathway. Do NOT fabricate truth from sensor measurements or vice versa.
    - If no target ID column: inform the user that `trackingFilterTuner` requires detection-to-target association and ask how they want to proceed (provide IDs, or use single-target subset)
12. **Stop here — do NOT create or run a tracker.** Tell user: "These detections work with built-in filter inits: `initcvekf`, `initcaukf`, `initctekf`, `initcvukf`, etc."

### Custom sub-path (non-standard measurements)

For measurements that don't fit built-in models (TDOA, custom geometry, etc.):

1. Identify non-standard nature of measurements
2. **Infer units, time, and reference frame** — parse time, convert units, transform to sensor-native frame if needed (same rules as above)
3. Ask: what is your state vector? what motion model?
4. Design custom `MeasurementParameters` — must carry info needed by measurement function and include a discriminator field if multi-sensor
5. Write custom `measurementFcn(state, mp)` mapping state → expected measurement
6. Write custom `filterInitFcn(detection)` using the inverse measurement model
7. Generate `objectDetection` array with custom MeasurementParameters
8. Deliver measurement function + filter init as a matched pair
9. **Stop here — do NOT create or run a tracker.** Tell the user their detections are ready.

See `references/objectDetection-patterns.md` for the standard struct, measurement ordering, and multi-sensor design patterns. See `references/custom-measurement-models.md` for custom function templates.

---

## Reference Documents

Read on-demand when you need details:

- `references/output-formats.md` — Truth output struct/table schemas (recording, tuning, truthlog)
- `references/code-patterns.md` — End-to-end truth import code examples
- `references/coordinate-transforms.md` — Frame transforms (LLA→ECEF, NED→ECEF, etc.)
- `references/visualization.md` — trackingGlobeViewer and theaterPlot usage
- `references/interpreter-categories.md` — Truth data categories, state elements, column name patterns
- `references/time-and-units.md` — Time parsing and unit conversion
- `references/sensor-data-formats.md` — Task-oriented: all prebuilt/custom sensor spec properties, model catalogs, dataFormat behavior
- `references/objectDetection-patterns.md` — Legacy: MeasurementParameters struct, measurement vector ordering, multi-sensor patterns
- `references/custom-measurement-models.md` — Custom measurementFcn + filterInitFcn templates

----

Copyright 2026 The MathWorks, Inc.
