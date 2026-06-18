# Data Cleaning

**Contents:** missing value comparison, standardizeMissing, omitmissing (+ min/max and std/var pitfalls), fillmissing (methods, MaxGap), isoutlier/rmoutliers/filloutliers, isbetween/allbetween/clip

## Do not use `==`, `isequal`, or `ismember` for missing value comparison
```matlab
% Use ismissing or isnan
missingElements = ismissing(value);
missingElements = isnan(value);

% Avoid: value == NaN and NaN == NaN are always false
missingElements = value == NaN;
```

## Use `standardizeMissing` to convert custom missing indicators
```matlab
% Convert all custom missing indicators to standard missing
% Converts "N/A", "null", -Inf, -999 to standard missing
Tclean = standardizeMissing(T,{"N/A", "null", -Inf, -999});

% Now ismissing works correctly by identifying the standard missing
sum(ismissing(Tclean))

% Now fillmissing works correctly by filling in the standard missing
Tfilled = fillmissing(Tclean,"previous");
```

## Use `"omitmissing"` not `nan*` functions for omitting missing values

Prefer `"omitmissing"` over `"omitnan"`. Both handle numeric `NaN` identically, but `"omitmissing"` also applies to other types that define a missing value (datetime, duration, string, categorical, and others).

```matlab
m = mean(T.Value,"omitmissing");
s = std(T.Value,"omitmissing");

% Works with all these functions and more:
mean(x,"omitmissing")
std(x,"omitmissing")
var(x,"omitmissing")
sum(x,"omitmissing")
median(x,"omitmissing")
min(x,[],"omitmissing")            % note: three-argument form required
max(x,[],"omitmissing")            % note: three-argument form required

% Avoid: Legacy functions, Statistics Toolbox required
m = nanmean(T.Value);
s = nanstd(T.Value);
```

**Pitfall with `min`/`max`:** these accept an optional second argument for element-wise comparison, so `max(x,"omitmissing")` tries to compare `x` with the string and errors. Always use the three-argument form: `max(x,[],"omitmissing")`.

**Pitfall with `std`/`var`:** the first optional argument is a weight flag, not a dimension. `std(x,0)` normalizes by N-1 (sample, default). `std(x,1)` normalizes by N (population). To operate along a specific dimension, you must pass the weight first: `std(x,0,2)` for std along dimension 2. Writing `std(x,2)` computes population std with weight=2, not std along dimension 2.

## Use `fillmissing` to fill gaps in data

Choose the fill method based on the nature of the data. Operate on the whole table with `DataVariables` rather than extracting columns:

```matlab
% Constant fill - good for categorical defaults or known baselines
T = fillmissing(T, "constant", "Unknown", DataVariables="Status");
T = fillmissing(T, "constant", 0, DataVariables="Value");

% Previous/next value - good for stepwise or slowly changing data
T = fillmissing(T, "previous", DataVariables="Setting");
T = fillmissing(T, "next", DataVariables="Reading");

% Linear interpolation - good for continuously varying numeric data
T = fillmissing(T, "linear", DataVariables="Temperature");

% Moving window methods - good for noisy numeric data with gaps
T = fillmissing(T, "movmean", 5, DataVariables="Sensor");
T = fillmissing(T, "movmedian", hours(2), ...
    DataVariables="Sensor", SamplePoints="Time");
```

### Fill by type for mixed-type tables

Applying a numeric method (like `"linear"`) to the whole table will error if it contains non-numeric variables. Use `vartype` to apply different methods by type:

```matlab
T = fillmissing(T, "linear", DataVariables=vartype("numeric"));
T = fillmissing(T, "previous", DataVariables=vartype("categorical"));
T = fillmissing(T, "constant", "N/A", DataVariables=vartype("string"));
```

### Available fill methods

`"constant"`, `"previous"`, `"next"`, `"nearest"`, `"linear"`, `"spline"`, `"pchip"`, `"makima"`, `"movmean"`, `"movmedian"`, `"knn"`, `"mean"`, `"median"`, `"mode"`. Also supports function handles for custom fill logic.

### Limit the size of filled gaps

`MaxGap` specifies the maximum gap to fill **in terms of sample points**, not row count. The gap size is the distance between the nonmissing values surrounding the cluster of NaNs, measured along the sample points axis. Without explicit sample points, the default is `[1 2 3 ...]` (integer-valued row indices), so `MaxGap=5` means "5 rows apart."

```matlab
% Numeric sample points — MaxGap is in those units
T = fillmissing(T, "linear", MaxGap=50, ...
    DataVariables="Reading", SamplePoints="Distance");

% Timetable — row times are the implicit sample points, so MaxGap is a duration
TT = fillmissing(TT, "linear", MaxGap=hours(24), DataVariables="Loss");
```

**Pitfall:** Extracting a column from a timetable (`TT.Value`) discards the row times. `fillmissing(TT.Value, "linear", MaxGap=hours(24))` errors because the extracted vector has default integer-valued sample points. Operate on the full timetable with `DataVariables`, or pass `SamplePoints` explicitly.

## Use `isoutlier`/`rmoutliers`/`filloutliers` not manual IQR

Consider the data's domain expectations when choosing a detection method. The default (`"median"`) flags values more than 3 scaled MAD from the median, which may be too aggressive or too lenient depending on the distribution:

```matlab
% Detect outliers (default: 3 scaled MAD from median)
isOut = isoutlier(T, DataVariables="Value");
isOut = isoutlier(T, "quartiles", DataVariables="Value");           % IQR method
isOut = isoutlier(T, "percentiles", [5 95], DataVariables="Value"); % custom bounds
isOut = isoutlier(T, "mean", ThresholdFactor=3, DataVariables="Value"); % 3 std from mean

% Remove outlier rows
Tclean = rmoutliers(T, "quartiles", DataVariables="Value");

% Replace outliers (preserves row count - better for time series or paired data)
T = filloutliers(T, NaN, "quartiles", DataVariables="Value");      % mark as missing, handle later with fillmissing
T = filloutliers(T, "linear", "quartiles", DataVariables="Value"); % interpolate over outliers
T = filloutliers(T, "clip", "percentiles", [1 99], DataVariables="Value"); % clamp to bounds
T = filloutliers(T, "previous", "movmedian", 5, DataVariables="Value");

% Avoid: Manual IQR or z-score outlier detection
Q1 = prctile(T.Value,25);
Q3 = prctile(T.Value,75);
IQRval = Q3 - Q1;
isOut = T.Value < (Q1 - 1.5*IQRval) | T.Value > (Q3 + 1.5*IQRval);
```

Detection methods and their `ThresholdFactor` defaults (controls how aggressively outliers are flagged):

| Method | Outlier criterion | ThresholdFactor default |
|--------|-------------------|------------------------|
| `"median"` (default), `"movmedian"` | Scaled MADs from median | 3 |
| `"mean"`, `"movmean"` | Standard deviations from mean | 3 |
| `"quartiles"` | IQR multiplier beyond Q1/Q3 | 1.5 |
| `"grubbs"`, `"gesd"` | Significance level (0 = fewer, 1 = more) | 0.05 |
| `"percentiles"` | Custom bounds (no ThresholdFactor) | — |

```matlab
isoutlier(x,"mean",ThresholdFactor=2)        % flag values > 2 std from mean
isoutlier(x,"quartiles",ThresholdFactor=3)   % widen IQR bounds (fewer outliers)
```

Fill methods for `filloutliers`: `"center"`, `"clip"`, `"previous"`, `"next"`, `"nearest"`, `"linear"`, `"spline"`, `"pchip"`, `"makima"`, or a numeric scalar (e.g., `NaN` to convert outliers to missing values).

## Use `isbetween`, `allbetween`, and `clip` for range operations

```matlab
% Check which values are in range
tf = isbetween(T.Age,18,65);                % numeric support R2024b+
Tadults = T(tf,:);

% Validate that all values fall within an expected range
allbetween(T.Age,0,120)                    % returns true/false (R2025a+)

% Clamp values to a range (e.g., cap outliers instead of removing them)
T = clip(T, 0, 100, DataVariables="Score");  % (R2024a+)
```

`isbetween` supports interval types (`"open"`, `"closed"`, `"openleft"`, `"openright"`) and works with numeric (R2024b+), datetime, and duration data.

---

Copyright 2026 The MathWorks, Inc.
