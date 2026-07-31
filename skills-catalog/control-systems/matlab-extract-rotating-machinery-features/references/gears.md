---
name: gear-fault-features
description: "Extract features suitable for detecting faults in meshing gears. Gear mesh frequency and its sidebands, along with condition metrics computed from the time-synchronous average, characterize gear health. Use when developing condition monitoring or fault detection capabilities for gear components in rotating machinery."
---

# Extract Features from Gear Vibration Signals

Extract predictive features from gear vibration signals for condition monitoring and fault detection. This reference covers the feature extraction techniques specialized to meshing gears.

Gear faults manifest as changes at the gear mesh frequency and its harmonics, together with sidebands spaced at shaft rotation frequencies. Because these effects are periodic with shaft rotation, gear analysis works best on the time-synchronous average (TSA) of the vibration signal. See [tsa.md](tsa.md) to compute the TSA before extracting gear features.

Specialized features for gear condition monitoring, available through the `gearConditionMetrics` command, include:
- Root-mean square
- Kurtosis
- Crest factor
- FM4
- M6A
- M8A
- FM0
- Energy ratio
- NA4

## When to Use

- User wants to generate features for gear condition monitoring.
- User knows the number of teeth on the meshing gears and the shaft rotation speed.
- User wants to identify gear mesh frequencies and sidebands of interest for condition monitoring.

## When NOT to Use

- When no tachometer or RPM information is available to compute the time-synchronous average.
- When the rotation speed during data collection is highly variable (use order tracking `ordertrack` as a preliminary step first).

## Workflow

- Use the same steps as the main rotating machinery feature extraction workflow plus the specialized steps below for gears.
- Compute the time-synchronous average of the vibration signal using `tsa` (see [tsa.md](tsa.md)).
- Identify gear mesh fault bands from the number of teeth and shaft speed using `gearMeshFaultBands`.
- Extract standard gear condition metrics from the TSA using `gearConditionMetrics`.
- Extract spectral metrics for the gear mesh fault bands using `faultBandMetrics`.

## API Reference

The signatures below are the ones needed for this workflow. Two common mistakes to avoid: `gearConditionMetrics` takes the TSA data (vector, timetable, or table) directly — **not** a `(signal, fs)` pair — and `faultBandMetrics` takes the PSD plus its frequency grid and the fault-band array — **not** band labels or an `info` struct. Follow the syntax exactly; consult the linked documentation for name-value arguments not shown here.

### Characteristic Fault Frequencies

- **`gearMeshFaultBands`** (Predictive Maintenance Toolbox, R2019b) — frequency bands around gear-mesh characteristic frequencies.
  - `[FB,info] = gearMeshFaultBands(FR,Ni,No)` — `FR` input-gear rotational speed (positive scalar, Hz), `Ni` teeth on input gear, `No` teeth on output gear (both positive integers). **`Ni` and `No` are separate scalars, not a vector.** `FB` is an Nx2 array of `[lower upper]` band edges; `info` describes the bands (centers, labels).
  - Name-value: `Harmonics` (default 1), `Sidebands` (default 0), `Width` (default 10% of fundamental), `Domain` (`'frequency'` default | `'order'`).
  - Docs: <https://www.mathworks.com/help/predmaint/ref/gearmeshfaultbands.html>

- **`faultBands`** (Predictive Maintenance Toolbox, R2019b) — generic fault frequency bands from a fundamental and its sidebands.
  - `[FB,info] = faultBands(F0,N0)` — `F0` fundamental frequency, `N0` harmonics; add sideband spacing/orders with `faultBands(F0,N0,F1,N1)`. `FB` is an Nx2 array.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/faultbands.html>

### Spectral Feature (Metrics) Extraction

- **`faultBandMetrics`** (Predictive Maintenance Toolbox, R2019b) — spectral metrics for the specified fault bands of a PSD.
  - `spectralMetrics = faultBandMetrics(psd,freqGrid,FB)` — `psd` power spectral density (vector/array), `freqGrid` matching frequency vector, `FB` the Nx2 fault-band array from `gearMeshFaultBands`/`faultBands`. **Three positional inputs; do not pass labels or an info struct.**
  - **Output shape:** `spectralMetrics` is a one-row table with a `PeakAmplitude`_k_, `PeakFrequency`_k_, `BandPower`_k_ triplet **per band** (k = 1…N for the N rows of `FB`) plus a final `TotalBandPower`. There is **no scalar `BandPower` column** — index a specific band as `spectralMetrics.BandPower1`, or use `spectralMetrics.TotalBandPower` for the aggregate.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/faultbandmetrics.html>

### Gear Condition Metrics

- **`gearConditionMetrics`** (Predictive Maintenance Toolbox, R2019a) — standard gear condition metrics (FM4, M6A, M8A, FM0, NA4, energy ratio, plus RMS/kurtosis/crest).
  - `gearMetrics = gearConditionMetrics(T)` — `T` is the TSA data: a **timetable**, a cell array of matrices/timetables, or a `fileEnsembleDatastore`. For a single TSA segment, wrap it as a one-column timetable: `tt = timetable(seconds((0:N-1)'/fs), seg(:)); gearConditionMetrics(tt)`.
  - **Do not call `gearConditionMetrics(signal, fs)`** — there is no sample-rate argument; the metrics are computed on the TSA signal(s) directly.
  - To feed the difference/regular/residual signals too, put each in its own **timetable variable** and name them: `gearConditionMetrics(TT,sigVar,diffVar,regVar,resVar)` where `TT` is a multi-variable timetable. **Pass `''` (empty char), not `[]`, for a signal you are omitting** (e.g. `gearConditionMetrics(TT,'TSA','TSADifference','','TSAResidual')` when there is no regular signal). A plain `table` of numeric column-vectors errors with *"Brace indexing is not supported for variables of type double"* — use a timetable (or a table whose variables are themselves cells/timetables).
  - `[gearMetrics,info] = gearConditionMetrics(___)` also returns signal-assignment info.
  - Docs: <https://www.mathworks.com/help/predmaint/ref/gearconditionmetrics.html>

### Additional References
- When applicable, fetch [Condition Indicators for Gear Condition Monitoring](https://www.mathworks.com/help/predmaint/ug/condition-indicators-for-gear-condition-monitoring.html)

----

Copyright 2026 The MathWorks, Inc.

