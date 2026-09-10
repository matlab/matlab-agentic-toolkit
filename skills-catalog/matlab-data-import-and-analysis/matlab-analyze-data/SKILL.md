---
name: matlab-analyze-data
description: Analyze data using MATLAB. Use when the task involves tables, timetables, time-series data, numeric arrays, sensor matrices, or gridded data — including but not limited to exploring, filtering, sorting, cleaning, transforming, aggregating, smoothing, padding, trimming, and answering questions about data. MATLAB provides extensive, easy-to-use built-in functions for these workflows with no additional products required.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.4"
---

# MATLAB Data Analysis

Generate idiomatic MATLAB code for tabular data analysis tasks using tables and timetables.

## When to Use

- Any task involving tabular data: exploring, cleaning, transforming, or aggregating tables
- Time-series analysis: resampling, synchronizing, trend detection, smoothing
- Answering questions about data in tables (top-N, filtering, group comparisons)
- Data cleaning: missing values, outliers, type conversion, normalization

## When NOT to Use

- The task has no data context (no tables, timetables, arrays, or date/time values to work with)
- The primary goal is visualization or plotting, not data analysis (use `matlab-build-chart` instead)
- The task is purely symbolic math, simulation, or app building
- Reading or writing files — CSV, Excel, Parquet, MAT-file (use `matlab-import-export-data` instead)
- Data doesn't fit in memory or requires out-of-core processing (use `matlab-choose-big-data-solution` instead)
- Storing or retrieving passwords, tokens, or API keys (use `matlab-secure-credentials` instead)
- Data lives in a relational database (use `matlab-use-database` or `matlab-use-duckdb` instead)
- Building an ML training pipeline from labeled signal files (use `matlab-prepare-signal-data` instead)
- Code migration or replacing deprecated APIs (use `matlab-modernize-code` instead)

## How to Use This Skill

This skill covers core MATLAB functions for tabular, time-series, and array-based data workflows — including numeric arrays, sensor matrices, and gridded data. These functions work natively with `table`, `timetable`, and numeric arrays, handle missing data correctly, and are performance-optimized. Prefer the modern functions recommended here (e.g., `groupsummary`, `datetime`, `fillmissing`, `smoothdata2`) over legacy alternatives (e.g., `accumarray`, `nanmean`, `datenum`). Override only if the user explicitly requests otherwise.

**Each section below links to a reference file. ALWAYS read the reference file for the relevant topic before writing code.** Reference files contain correct syntax, common pitfalls, and "Avoid" patterns that prevent silent bugs. Skipping the reference risks using a deprecated approach or hitting a known pitfall.

### Key Functions — Available From

Most functions in this skill are available in R2023a or earlier. The following require a newer release:

| Function | Available From | Purpose |
|----------|---------------|---------|
| `paddata`, `trimdata`, `resize` | R2023b | Pad, trim, or resize arrays to target length |
| `smoothdata2` | R2023b | Smooth 2-D gridded data over rectangular windows |
| `clip` | R2024a | Clamp values to a range |
| `islocalmax2`, `islocalmin2` | R2024a | Detect local extrema in 2-D gridded data |
| `summary` (enhanced) | R2024b | Supports arrays (numeric, datetime, duration, logical); adds `Statistics`, `DataVariables`, `Detail` name-value args |
| `isapprox` | R2024b | Tolerance-aware floating-point comparison (use instead of `==` for computed values) |
| `isbetween` (numeric) | R2024b | Check elements within a numeric range |
| `numunique` | R2025a | Count distinct values in a variable |
| `allbetween` | R2025a | Validate all values are within a range |
| `allunique` | R2025a | Validate all values are unique |

---

## Getting Oriented with Data

When data is already in a workspace variable, start by understanding its structure and contents before writing analysis code.

**Topics:**
- Summarizing structure, shape, and variable types
- Assessing how much data is missing and where
- Understanding distributions (numeric quartiles, categorical value counts)
- Finding correlations and relationships between variables
- Checking for duplicates, unique keys, and cardinality
- Exploring time range, regularity, and temporal patterns

**Functions:** `summary`, `head`, `size`, `jsonencode`, `anymissing`, `allfinite`, `ismissing`, `groupcounts`, `numunique`, `corrcoef`, `pivot`, `unique`, `isregular`, `isuniform`, `retime`

**Read:** [exploration.md](references/exploration.md)

---

## Data Types

Use modern MATLAB types instead of legacy alternatives. Modern types are faster, more readable, and work better with table functions.

**Topics:**
- Dates and times (parsing, arithmetic, timezones, extracting year/month/day/hour)
- Elapsed time and calendar offsets
- Text data (comparing, searching, splitting, editing strings)
- Categorical data (ordinal rankings, merging/renaming/reordering levels)

**Functions:** `datetime`, `dateshift`, `year`, `month`, `day`, `weekday`, `quarter`, `hour`, `ymd`, `hms`, `hours`, `days`, `minutes`, `seconds`, `calmonths`, `caldays`, `string`, `matches`, `contains`, `startsWith`, `extractAfter`, `extractBefore`, `replace`, `erase`, `strip`, `split`, `count`, `categorical`, `mergecats`, `renamecats`, `removecats`, `reordercats`, `countcats`

**Read:** [data-types.md](references/data-types.md)

---

## Tables and Timetables

Tables are the primary container for tabular data. Use `timetable` when the data has timestamps, a time vector, or a known sample rate — it unlocks time-aware operations (automatic spacing-aware smoothing, filling, and resampling).

**Topics:**
- Creating and structuring tables (variables vs rows, metadata, properties)
- Selecting variables by type; dot indexing vs braces vs parentheses
- Converting variable types after import
- Working with non-uniformly spaced data (`SamplePoints`)
- Resampling, aligning, and synchronizing time series
- Filtering by date range or time tolerance
- Converting legacy `timeseries` objects

**Functions:** `table`, `timetable`, `table2timetable`, `vartype`, `convertvars`, `retime`, `synchronize`, `lag`, `timerange`, `withtol`, `timeseries2timetable`, `table2array`, `array2table`

**Read:** [tables-and-timetables.md](references/tables-and-timetables.md)

---

## Eventtables

Use `eventtable` when tagging or annotating timetable rows with events, episodes, or phases (sensor anomalies, storms, maintenance windows, alarms). Do NOT add boolean columns, string labels, or categorical state variables to the timetable itself.

**Topics:**
- Creating an eventtable from timestamps and labels (instantaneous or interval)
- Attaching events to a timetable
- Filtering timetable rows by event properties
- Extracting events from patterns in data (peaks, threshold crossings)
- Pushing event data into timetable rows for export or grouping
- Automatic event overlays in plots

**Functions:** `eventtable`, `eventfilter`, `extractevents`, `syncevents`, `withtol`, `stackedplot`

**Read:** [eventtables.md](references/eventtables.md)

---

## Data Cleaning

Handle missing values and outliers using MATLAB's built-in detection and fill functions. Never compare with `==` for missing values. Use `standardizeMissing` to convert sentinel values before filling or removing.

**Topics:**
- Detecting missing values (NaN, NaT, missing strings, undefined categoricals)
- Converting placeholder values ("N/A", -999, "") to standard missing
- Filling gaps (interpolation, forward-fill, moving window, per-type strategies)
- Limiting fill across long gaps
- Skipping missing values in aggregation (mean, std, min, max) — correct calling syntax
- Detecting, removing, or replacing outliers
- Checking whether values fall within an expected range; clamping

**Functions:** `ismissing`, `anymissing`, `standardizeMissing`, `fillmissing`, `rmmissing`, `isoutlier`, `rmoutliers`, `filloutliers`, `isbetween`, `allbetween`, `clip`, `isapprox`

**Read:** [data-cleaning.md](references/data-cleaning.md)

---

## Data Transformation

Filter, sort, reshape, normalize, bin, join, and manage table variables. Use vectorized operations and built-in functions — not loops over rows or manual if-else chains.

**Topics:**
- Filtering rows by condition or value range
- Sorting and retrieving top/bottom N rows
- Applying functions across rows or across variables
- Renaming, reordering, adding, removing, splitting, merging variables
- Converting types and applying in-place transforms
- Binning continuous values into categories
- Normalizing, scaling, z-scoring
- Reshaping between wide and tall formats (pivot, stack, unstack)
- Joining/merging tables on key variables

**Functions:** `sortrows`, `topkrows`, `rowfun`, `varfun`, `convertvars`, `renamevars`, `movevars`, `addvars`, `removevars`, `splitvars`, `mergevars`, `discretize`, `normalize`, `clip`, `rescale`, `pivot`, `stack`, `unstack`, `rows2vars`, `innerjoin`, `outerjoin`, `join`

**Read:** [data-transformation.md](references/data-transformation.md)

---

## Grouping and Aggregation

`groupsummary` is the go-to for grouped statistics — not `findgroups`+`accumarray` or manual loops. Use `groupfilter` for per-group row filtering, `grouptransform` for per-group normalization, and `pivot` for cross-tabulation.

**Topics:**
- Computing statistics by group (mean, sum, std, min, max, custom)
- Binning on the fly (numeric edges, hourly/monthly/seasonal time bins)
- Handling missing or empty groups
- Filtering rows based on group-level conditions (e.g., minimum group size)
- Removing per-group outliers
- Normalizing within each group (z-score, rescale)
- Cross-tabulating counts or aggregated values

**Functions:** `groupsummary`, `groupcounts`, `groupfilter`, `grouptransform`, `pivot`, `findgroups`

**Read:** [grouping-and-aggregation.md](references/grouping-and-aggregation.md)

---

## Smoothing, Trends, and Patterns

`smoothdata` is the unified entry point for smoothing (not `smooth`, which requires Curve Fitting Toolbox). Use `detrend` or `trenddecomp` for trend removal/decomposition, and `islocalmax`/`islocalmin`/`ischange` for pattern detection.

**Topics:**
- Smoothing noisy data (moving average, Gaussian, Savitzky-Golay, median)
- Choosing window size (element count vs duration for time-stamped data)
- Removing linear or polynomial trends
- Separating trend from seasonality (seasonal decomposition)
- Finding peaks, valleys, and local extrema
- Detecting abrupt changes in mean, variance, or slope
- Summarizing distributions (bin counts, histograms)

**Functions:** `smoothdata`, `movmean`, `movmedian`, `detrend`, `trenddecomp`, `islocalmax`, `islocalmin`, `ischange`, `histcounts`, `histogram`

**Read:** [smoothing-and-trends.md](references/smoothing-and-trends.md)

---

## Array and Grid Data

Use arrays when data is homogeneous numeric AND either naturally 2D/grid, performance-critical, or delivered by upstream tooling. For 2D grids, use dedicated 2D functions — do not loop 1D functions over rows/columns.

**Topics:**
- When to stay in arrays vs converting to table
- Operating along a specific dimension (row-wise vs column-wise)
- Common pitfalls with dimension arguments in std, var, movstd, movvar
- Handling NaN in array computations (not automatic)
- Moving window and cumulative statistics
- Padding, trimming, or resizing arrays to a target length
- 2D spatial smoothing, gap filling, and peak detection on grids
- Grouped operations using a grouping vector

**Functions:** `smoothdata2`, `fillmissing2`, `islocalmax2`, `islocalmin2`, `paddata`, `trimdata`, `resize`, `mink`, `maxk`, `bounds`, `rms`, `prctile`, `quantile`, `iqr`, `cumsum`, `cummax`, `cummin`, `cumprod`, `movmean`, `movmedian`, `movsum`, `movstd`, `movvar`, `isuniform`, `isregular`

**Read:** [array-and-grid-data.md](references/array-and-grid-data.md)

---

## Answering Questions About Data

When the task is answering a specific question about data (top-N, filtering, lookups, comparisons), read the strategies reference to avoid common mistakes with sorting direction, missing data, and value interpretation.

**Topics:**
- Finding the highest/lowest/top/bottom N entries
- Looking up values in one column based on ranking in another
- Accounting for missing or placeholder values in answers
- Returning raw data values without substitution or mapping
- Counting rows that match a condition (exact vs partial text matching)

**Functions:** `topkrows`, `sortrows`, `groupsummary`, `standardizeMissing`, `matches`, `contains`, `height`, `nnz`

**Read:** [answering-data-questions.md](references/answering-data-questions.md)

---

Copyright 2026 The MathWorks, Inc.
