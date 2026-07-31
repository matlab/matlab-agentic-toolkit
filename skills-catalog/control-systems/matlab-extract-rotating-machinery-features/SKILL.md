---
name: matlab-extract-rotating-machinery-features
description: "Extract features from signals collected on rotating machinery components, including motors, pumps, fans, gears, bearings, and shafts. Signals can include vibration, electrical, or environmental sensor measurements. Use when developing and deploying condition monitoring and fault detection applications for rotating machinery, including industrial machines, electrical vehicles, internal combustion engines, turbines, and drive trains."
license: "https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md"
metadata:
    author: MathWorks
    version: "1.0"
---

# Rotating Machinery Feature Extraction

Extract predictive features from rotating machinery data for condition monitoring and fault detection applications. This skill covers the essential feature extraction workflow steps and algorithms specialized to rotating machinery.

## When to Use

- User has uniformly-sampled time series data representing rotating machinery sensor measurements stored as matrix, `timetable`, or cell array variables.
- User is building a condition monitoring or fault detection system for rotating machinery.
- User wants to process rotating machinery data for feature extraction.
- User wants to select most predictive features and construct a health indicator from features.
- User is deploying condition monitoring and fault detection systems.
- User has high-frequency vibration data and wants feature-based data reduction for efficient condition monitoring.

## When NOT to Use

- User has non-time-series data such as images, videos, or tabular (unordered) data.
- User wants fault classification (as opposed to fault detection) with two or more fault classes. Use `classificationLearner` instead.
- User has time series data (labeled or unlabeled) and wants to build anomaly detection models. Use `timeSeriesAnomalyDetector` instead.
- User has very low-frequency data not suitable for statistical or spectral feature extraction.

## Feature Extraction Workflow

Follow these 5 steps interactively:

```
Task Progress:
- [ ] Step 1: Process data for feature extraction
- [ ] Step 2: Extract features from data
- [ ] Step 3: Rank and select features
- [ ] Step 4: Develop a health indicator using selected features
- [ ] Step 5: Deploy the application
```

Do NOT silently choose parameters or make assumptions. Engage the user at each decision point. In particular, ask the user to provide important system parameters such as
- Bearing and gear geometry parameters
- Rotation speeds (RPMs)
- Structural resonance frequencies, if known

## Step 1: Process data for feature extraction

1. Non-periodic signal components or noise can be removed from measurements if accompanying tachometer or RPM data is available. Use time-synchronous averaging (`tsa`) and related techniques (`tsadifference`, `tsaresidual`, etc.) to isolate periodic signal components. If tachometer signal is available, use `tachorpm` to estimate the RPM before `tsa` processing.
2. For modulated time series signals, use the signal envelope (`envelope`) or the envelope spectrum (`envspectrum`) to demodulate the signals.

### Establishing rotation speeds and fault frequencies (do this before placing any fault bands)

A tachometer or RPM channel gives the speed of **one specific shaft** — you must know **which physical shaft it is mounted on** and how many **pulses per revolution** it produces. Do not assume it is the motor/input shaft.

- Ask the user (or infer from the setup) where the tachometer is mounted and its pulses-per-revolution. In a geared drivetrain, propagate speeds through the gear ratios from the *known* shaft: multiply toward faster shafts, divide toward slower ones.
- **Always sanity-check the derived speeds against the measured spectrum.** Compute a power spectrum (`pspectrum`) and confirm a dominant line appears at the expected shaft rate or gear-mesh frequency. If the strongest peak is at a very different frequency (e.g. you assumed a 3 Hz shaft but the spectrum peaks at 90 Hz), your tach-placement assumption is wrong — revisit it before continuing.
- **CRITICAL — Never attempt `tsa` without real rotation-phase information.** If the user asks for time-synchronous averaging but no tachometer signal, RPM profile, or order-tracking data is available: **you MUST refuse the TSA request.** Tell the user: "TSA requires rotation-phase information (tachometer pulses or an RPM profile) that is not present in your data. I cannot proceed with time-synchronous averaging." Then offer alternative noise-reduction approaches that do NOT require rotation phase — such as bandpass filtering, spectral averaging (`pwelch`), or statistical features on the raw signal. **Do not work around the missing data** — do not estimate an RPM from the spectrum, do not guess a shaft speed from a dominant spectral peak, do not fabricate tachometer pulses, and do not modify or re-generate data files to inject rotation-phase information that the user said they do not have.

For bearings, characteristic fault frequencies (`Fo`, `Fi`, `Fb`, `Fc`) come from the bearing **geometry plus shaft speed** via `bearingFaultBands`. If the user supplies these frequencies directly (common in datasets), use them as given — do not invent geometry to re-derive them. If only shaft/gear information is given and the bearing geometry is unknown, ask for the geometry (number of rolling elements, ball/pitch diameter, contact angle) rather than guessing a fault-frequency-to-shaft ratio; alternatively identify the dominant non-shaft peak in the envelope spectrum empirically and label it explicitly as an empirical estimate.

## Step 2: Extract features from data

1. Extract time-domain features such as `rms`, `kurtosis`, `peak2rms`, and other statistical metrics.
2. Extract spectral features such as `bandpower` and spectral peaks & frequencies from demodulated signals.
3. For special components such as bearings and gears, extract domain-specific features such as `bearingFaultBands`, `gearMeshFaultBands`, or `gearConditionMetrics`. Use `faultBands` to build characteristic fault-frequency bands (fundamental + harmonics + sidebands) for shafts and generic components, and compute spectral metrics over those bands with `faultBandMetrics` (peak amplitude, peak frequency, and band power per band).
4. Suggest the use of `diagnosticFeatureDesigner` if an interactive tool is desired to extract a large number of features.

### Extracting features across many files (batch processing)

Condition-monitoring and run-to-failure datasets usually span **many measurement files** (one per day, per test, or per operating point). Do not load only one file or write an ad-hoc loop when the workflow scales to many members. Use a `fileEnsembleDatastore` to manage the collection:

- Configure the datastore with `DataVariables`, `IndependentVariables` (e.g. a date or cycle index parsed from the file name), and `ConditionVariables`, plus a custom `ReadFcn` that returns the signal(s) for one member.
- Iterate members with `read`/`hasdata`/`reset`, extract the per-member features, and write them back with `writeToLastMemberRead` so the features persist in the ensemble.
- For large collections, wrap the datastore in a `tall` array and `gather` the feature table, or `partition` the datastore for parallel processing.

**Key API rule (the common failure):** `SelectedVariables` must be a **subset of the variables you have already declared** in `DataVariables`, `ConditionVariables`, or `IndependentVariables`. Selecting a name that was never declared errors with *"the 'SelectedVariables' property does not include any valid ... names"*. Likewise, to persist a new feature you must **first add its name to `DataVariables`**, then call `writeToLastMemberRead` — you cannot write (or later select) a column the datastore does not know about. A minimal read-and-featurize loop that only *reads* raw signals needs just the raw variables declared and selected:

```matlab
fds = fileEnsembleDatastore(folder, ".mat");
fds.ReadFcn = @readMember;                 % returns a one-row table for one file
fds.DataVariables      = ["signal","fs"];  % raw signals to read
fds.IndependentVariables = "day";          % trend index
fds.SelectedVariables  = ["signal","fs","day"];   % subset of the declared names
reset(fds);
feats = [];
while hasdata(fds)
    m = read(fds);
    [es,f] = envspectrum(m.signal{1}, m.fs);
    feats = [feats; m.day, kurtosis(es)];  %#ok<AGROW>
end
```

This produces one feature table row per file, indexed by the independent variable — exactly the input Step 3 (ranking) and Step 4 (health indicator) expect.

### Signal type: vibration vs. electrical vs. other

The techniques above are not limited to accelerometer vibration. **Motor current signature analysis** applies the same spectral fault-band machinery (`faultBands`/`gearMeshFaultBands`/`bearingFaultBands` + `faultBandMetrics` on `pspectrum`) to a motor current or voltage signal: shaft and gear-mesh faults appear as spectral lines and sidebands in the current spectrum. Do not force accelerometer-only conventions (envelope demodulation of a structural resonance, `convertVibration`, kurtogram band selection) onto an electrical signal — those assume a high-frequency mechanical carrier that current signals do not have. Use envelope analysis for modulated *vibration* signals (bearings); use direct spectral fault-band metrics for current and for gear/shaft faults.

## Step 3: Rank and select features

1. For run-to-failure (degradation) data, evaluate the predictive powers of extracted features using, for example, `monotonicity`, `trendability`, or `prognosability`. **These functions take lifetime data as a `table`/`timetable`/cell array (or `fileEnsembleDatastore`) — not a bare numeric vector.** Assemble the per-cycle features into a feature table (one row per measurement, one column per feature, e.g. `array2table(featureMatrix,"VariableNames",names)`) and pass that table; each function returns one score per feature column. Calling `monotonicity(x)` on a `double` vector errors with *"Expected input number 1 to be one of these types: cell, table, timetable, fileEnsembleDatastore"*. For detection/diagnosis across labeled conditions, rank features instead by how well they separate the conditions (e.g. between-class vs. within-class scatter / a Fisher-type ratio, or `ranktesk`/`fscmrmr`-style separability).

   **Three common failures:** (a) Name the lifetime variable — `monotonicity(featTbl,"Day")`; a plain table with no lifetime arg silently drops its first column (returns empty `1×0` for a single-column table). (b) The result is a one-row table — assign then index (`s = monotonicity(...); s.RMS`); `monotonicity(...){1,1}` is a syntax error. (c) `trendability`/`prognosability` need ≥2 units and degenerate on a single run — use `monotonicity` for single-unit data, or score a scalar HI directly with `mean(sign(diff(HI)))`.
2. Prefer **contrast features** that pit one fault mechanism against another rather than absolute levels, which are sensitive to load and gain. For example, the ratio (or log-ratio) of the envelope-spectrum amplitude in the inner-race band versus the outer-race band discriminates inner- from outer-race bearing faults far better than either amplitude alone; comparing the same fault-band metric across a healthy and a faulty unit localizes which component is degrading.
3. Identify high-correlated features using `corr` or `corrcoef`, and drop redundant ones.
4. Suggest the use of `healthIndicatorDesigner` if an interactive tool is desired to select most predictive features.

## Step 4: Develop a health indicator using selected features

1. Combine the selected features to construct a health indicator as a scalar representation of the condition or health of the system. Use `lasso`, `pca`, or linear regression to create the health indicator.
2. Suggest the use of `healthIndicatorDesigner` if an interactive tool is desired to develop the health indicator.

## Step 5: Deploy the application

1. Generate a MATLAB script for all of the above workflow steps.
2. If asked, generate a MATLAB script for remaining useful life (RUL) estimation using `linearDegradationModel` or `exponentialDegradationModel`.
3. If asked, use MATLAB Coder to generate C/C++ code for embedded deployment on an edge device like a microcontroller.

## Specialized techniques

Load these additional resources when working on feature extraction and condition monitoring problems for specific components or signal types:
- **Bearing Faults**: See [references/bearings.md](references/bearings.md)
- **Gear Faults**: See [references/gears.md](references/gears.md)
- **Time-Synchronous Averaging**: See [references/tsa.md](references/tsa.md)
- **Spectral Data Processing**: See [references/spectral.md](references/spectral.md)
- **Vibration Data Processing**: See [references/vibration.md](references/vibration.md)

----

Copyright 2026 The MathWorks, Inc.

