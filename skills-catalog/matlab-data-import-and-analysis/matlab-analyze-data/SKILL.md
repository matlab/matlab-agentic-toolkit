---
name: matlab-analyze-data
description: Analyze tabular data using MATLAB. Use when the task involves tables, timetables, or time-series data — including but not limited to exploring, filtering, sorting, cleaning, transforming, aggregating, smoothing, and answering questions about data. MATLAB provides extensive, easy-to-use built-in functions for these workflows with no additional products required.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Data Analysis

Generate idiomatic MATLAB code for tabular data analysis tasks using tables and timetables.

## When to Use

- Any task involving tabular data: exploring, cleaning, transforming, or aggregating tables
- Time-series analysis: resampling, synchronizing, trend detection, smoothing
- Answering questions about data in tables (top-N, filtering, group comparisons)
- Data cleaning: missing values, outliers, type conversion, normalization

## When NOT to Use

- The task has no tabular data context (no tables, timetables, or structured datasets)
- The primary goal is visualization or plotting, not data analysis
- The task is purely symbolic math, simulation, or app building

This skill covers core MATLAB functions for tabular and time-series workflows. These functions work natively with `table` and `timetable`, handle missing data correctly, and are performance-optimized. Prefer the modern functions recommended here (e.g., `groupsummary`, `datetime`, `fillmissing`) over legacy alternatives (e.g., `accumarray`, `nanmean`, `datenum`). Override only if the user explicitly requests otherwise.

### Key Functions — Available From

Most functions in this skill are available in R2023a or earlier. The following require a newer release:

| Function | Available From | Purpose |
|----------|---------------|---------|
| `clip` | R2024a | Clamp values to a range |
| `summary` (enhanced) | R2024b | Supports arrays (numeric, datetime, duration, logical); adds `Statistics`, `DataVariables`, `Detail` name-value args |
| `isbetween` (numeric) | R2024b | Check elements within a numeric range |
| `numunique` | R2025a | Count distinct values in a variable |
| `allbetween` | R2025a | Validate all values are within a range |
| `allunique` | R2025a | Validate all values are unique |

## Getting Oriented with Data

When data is already in a workspace variable, start by understanding its structure and contents. Use JSON output for reliable parsing — table display is designed for human-readable grids, but as text it is easy to misinterpret which values belong to which variables:

```matlab
jsonencode(summary(T))      % per-variable stats as nested struct
jsonencode(head(T))         % first 8 rows as structured JSON
```

**When getting oriented with unknown data, `summary(T)` already contains per-variable type, size, NumMissing, and — for numeric/datetime/duration — Min, Max, Mean, Median, Std. For categoricals it includes category names and counts.** This is usually sufficient for an initial overview.

If producing a standalone script, leave the semicolon off to invoke the `display` method — it shows dimensions, variable names, and a truncated preview. Avoid `disp` (omits headers and prints every row, flooding output on large tables) and `fprintf` in a loop (verbose, old-style):

```matlab
summary(T)                  % types, ranges, missing counts per variable
T                           % dimensions + header + truncated preview
```

> Systematic exploration checklist: [exploration.md](references/exploration.md)

---

## Data Types

Use modern MATLAB types. These are faster, more readable, and work better with table functions.

| Instead of | Use | Why |
|---|---|---|
| `datenum`, `datestr` | `datetime` | Proper arithmetic, timezone support |
| `char`, `cellstr`, `strcmp` | `string`, `==`/`matches` | `==` for scalar, `matches` for vector comparison |
| Numeric codes or strings with few unique values | `categorical` | Self-documenting, works with grouping functions, memory-efficient |

```matlab
dt = datetime("2024-01-15",TimeZone="America/New_York");
names = ["Alice" "Bob"];           % not {'Alice', 'Bob'}
T.Status = categorical(T.Status);  % not numeric codes
```

Use ordinal categorical for ordered data like rankings or severity levels:
```matlab
T.Priority = categorical(T.Priority, ...
    ["Low" "Medium" "High" "Critical"], Ordinal=true);
urgent = T(T.Priority >= "High",:);
```

Extract datetime components for computed variables, filtering, or display:
```matlab
T.Month = month(T.Date);                   % numeric (1-12)
T.Weekday = weekday(T.Date);
T.MonthStart = dateshift(T.Date,"start","month");
```

String arrays support search, edit, and extraction:
```matlab
T.Domain = extractAfter(T.Email,"@");
T.Status = replace(T.Status,"N/A","Unknown");
T.Name = strip(T.Name);
```

Manage categorical levels with `mergecats`, `renamecats`, `removecats`, `reordercats`:
```matlab
T.Region = mergecats(T.Region,["Northeast" "Southeast"],"East");
T.Size = reordercats(T.Size,["Small" "Medium" "Large"]);
```

> Full examples and "avoid" patterns: [data-types.md](references/data-types.md)

## Tables and Timetables

Tables are the primary container for tabular data. Each table variable can be single-column or multi-column (e.g., a matrix); the only requirement is consistent row count. Use "variable" (not "column") to match MathWorks documentation. Prefer dot notation and named access over numeric indexing.

**It is rarely better to use a `for` loop to iterate over table variables.** MATLAB's table functions operate on multiple variables at once via `DataVariables` and `vartype` — prefer these over column-by-column loops.

```matlab
val = T.Value;                          % dot notation for a single variable
subset = T(:,["A" "B" "C"]);           % parentheses for table subsets
matrix = table2array(T(:,vartype("numeric")));   % extract as array
numericVars = T(:,vartype("numeric"));  % vartype for type-based selection
```

**Fix variable types after import** with `convertvars`:
```matlab
T = convertvars(T,["Region" "Status"],"categorical");
T = convertvars(T,vartype("cellstr"),"string");
```

**Use `timetable` when your data has timestamps.** If a table has a datetime variable representing when each row was observed, convert it to a timetable. This unlocks time-aware operations that would otherwise require manual date logic:

```matlab
TT = table2timetable(T,RowTimes="Timestamp");
% Now you can:
daily = retime(TT(:,vartype("numeric")),"daily","mean"); % resample (numeric vars only)
TT = retime(TT, unique(TT.Time), "firstvalue");  % resolve duplicate timestamps
TT2 = synchronize(TT_a,TT_b,"hourly");          % align two time series
TT_range = timerange("2024-01-01","2024-06-01");
subset = TT(TT_range,:);                        % filter by date range
TT_prev = lag(TT,1);                            % time-shift data
```

Another benefit of timetables: functions like `fillmissing`, `smoothdata`, and `isoutlier` automatically use row times for spacing-aware computation. With a plain table, you need to pass `SamplePoints="TimeVar"` explicitly to get the same behavior.

If working with legacy `timeseries` objects, consider converting with `timeseries2timetable(ts)` — the modern `timetable` is recommended.

> `retime`, `synchronize`, `lag`, `timerange`, `eventtable`, `SamplePoints`, `ReplaceValues` details: [tables-and-timetables.md](references/tables-and-timetables.md)

## Data Cleaning

### Missing values

Never compare with `==` for missing values (`NaN == NaN` is `false`). Use `ismissing` or `isnan`. For a quick boolean check, use `anymissing` — more readable and performant than `any(ismissing(...))`:
```matlab
anymissing(T.Value)                    % true/false: any missing values?
sum(ismissing(T))                      % missing count per variable (numeric vector)
summary(T, Statistics="nummissing")    % missing counts with variable labels (R2024b+)
```

**Standardize first, then fill.** Real data often uses sentinel values (`"N/A"`, `""`, `-999`, `0` where zero is meaningless) that MATLAB doesn't recognize as missing:
```matlab
T = standardizeMissing(T,{"N/A", "null", "", -999});   % convert to standard missing
sum(ismissing(T))                                        % now these show up
```

**Choose a fill method that matches your data.** Operate on the whole table with `DataVariables` to target specific columns rather than extracting individual columns:
```matlab
T = fillmissing(T,"constant","Unknown", DataVariables="Status");     % categorical default
T = fillmissing(T,"median", DataVariables=vartype("numeric"));       % column median
T = fillmissing(T,"linear", DataVariables="Temperature");            % smooth numeric
T = fillmissing(T,"previous", DataVariables="Setting");              % stepwise data
T = fillmissing(T,"movmedian",hours(2), ...                          % noisy, time-based
    DataVariables="Sensor", SamplePoints="Time");
```

For mixed-type tables, use `vartype` to apply different methods by type:
```matlab
T = fillmissing(T,"linear", DataVariables=vartype("numeric"));
T = fillmissing(T,"previous", DataVariables=vartype("categorical"));
```

Use `MaxGap` to avoid interpolating over long stretches of missing data. MaxGap is measured in sample-point units — for timetables, use a `duration` or `calendarDuration`:
```matlab
TT = fillmissing(TT,"linear", MaxGap=hours(24), DataVariables="Loss");
```

**Be cautious with `rmmissing` on an entire table** — it drops any row that has a missing value in *any* column, which can discard valid data unnecessarily. Prefer handling missingness per-variable with `fillmissing` or targeted column selection. Use `rmmissing` when you genuinely need complete cases across all columns.

### Outliers and range checking

Consider the data's domain expectations when choosing a detection method. The default (`"median"`) flags values more than 3 scaled MAD from the median:

```matlab
isOut = isoutlier(T,"quartiles", DataVariables="Value");     % IQR method
isOut = isoutlier(T,"mean", ThresholdFactor=2, DataVariables="Value"); % 2 std from mean
Tclean = rmoutliers(T, DataVariables="Value");               % remove outlier rows (default: median)
T = filloutliers(T,"linear","movmedian",5, DataVariables="Value"); % interpolate over local outliers
```

Detection methods: `"median"` (default), `"mean"`, `"quartiles"`, `"percentiles"`, `"grubbs"`, `"gesd"`, `"movmedian"`, `"movmean"`. **Use `ThresholdFactor` to control sensitivity** — it sets the number of scaled MADs (`"median"`), standard deviations (`"mean"`), or IQR multiplier (`"quartiles"`). Default is 3 for median/mean, 1.5 for quartiles.

**Range operations:** check, validate, or clamp values to a range:
```matlab
tf = isbetween(T.Age,18,65);                    % which rows are in range (R2024b+ for numeric)
allbetween(T.Age,0,120)                          % validate: all values plausible? (R2025a+)
T = clip(T,0,100, DataVariables="Score");        % clamp Score to [0, 100] (R2024a+)
```

### Aggregation statistics and missing values

Most aggregation functions (`mean`, `sum`, `std`, `min`, `max`, `median`) accept `"omitmissing"` to skip missing values. Prefer `"omitmissing"` over `"omitnan"` — it handles numeric data identically but also works with datetime, duration, string, and categorical types. Avoid legacy `nanmean`/`nanstd` (which require Statistics Toolbox).

```matlab
m = mean(T.Value,"omitmissing");
```

**Pitfall with `min`/`max`:** these take an optional second argument for comparison, so `max(x,"omitmissing")` tries to compare `x` with the string. Use the three-argument form:
```matlab
mx = max(x,[],"omitmissing");         % correct
mn = min(x,[],"omitmissing");         % correct
% max(x,"omitmissing")               % WRONG - errors
```

**Pitfall with `std`/`var`:** the first optional argument is a weight flag (0=sample, 1=population), not a dimension. To specify dimension, pass the weight first: `std(x,0,2)`. Writing `std(x,2)` does not compute std along dimension 2.

> `fillmissing` methods, `filloutliers` options, `isoutlier` detection methods: [data-cleaning.md](references/data-cleaning.md)

## Data Transformation

### Row filtering and sorting

**Prefer `isbetween` over manual `>=` & `<=` for range checks.** It handles boundary semantics (open/closed intervals), works consistently across numeric, datetime, and duration types, and is less error-prone than compound expressions:

```matlab
Thigh = T(T.Value > 100,:);                       % logical indexing (single bound)
TBob = T(T.Name == "Bob",:);                      % equality
Trange = T(isbetween(T.Age,18,65),:);             % range filtering (two bounds)
T = sortrows(T,"Date");                           % ascending by Date
T = sortrows(T,["Group" "Value"],["ascend" "descend"]);  % multi-key sort
top5 = topkrows(T,5,"Sales");                     % top 5 by Sales (descending)
```

### Binning

```matlab
edges = [0 18 35 50 Inf];
labels = ["Child" "Young Adult" "Adult" "Senior"];
T.AgeGroup = discretize(T.Age,edges,categorical(labels));
```

Note: if binning is for a subsequent `groupsummary`, `groupfilter`, `grouptransform`, or `pivot`, those functions support binning on the fly - no need to create a binned column first. See [Grouping and Aggregation](#grouping-and-aggregation).

### Normalization and scaling

```matlab
xnorm = normalize(x);                                       % z-score (default)
xnorm = normalize(x,"range");                               % scale to [0, 1]
xnorm = normalize(x,"norm",Inf);                            % divide by max (scales to [0,1] for positive data)
T = normalize(T,DataVariables=vartype("numeric"));           % all numeric variables
T = normalize(T,"zscore", DataVariables="Value");            % specific variable
```

### Type conversion and variable management

Check current types with `T.Properties.VariableTypes` (also writeable as a shortcut for conversion).

```matlab
T = convertvars(T,"Status","categorical");               % string to categorical
T = convertvars(T,vartype("cellstr"),"string");           % cellstr to string
T = renamevars(T,"OldName","NewName");
T = movevars(T,"Key", Before="Value");
T = addvars(T,x,y, Before="Value", NewVariableNames=["X" "Y"]);
T = removevars(T,["Temp1" "Temp2"]);
T = splitvars(T,"Coords", NewVariableNames=["X" "Y"]);    % split multicolumn variable
T = mergevars(T,["X" "Y"], NewVariableName="Coords");     % merge into multicolumn
```

### Adding computed variables

Prefer vectorized table arithmetic where possible. For iterative code where each row depends on the previous, extract variables into arrays, compute in a helper function, and assign back — do not index `T.Var(i)` inside a loop.

```matlab
T.Total = T.A + T.B + T.C;                               % vectorized arithmetic
T.BMI = T.Weight ./ (T.Height / 100).^2;                  % element-wise ops
Tsum = sum(T(:,["A" "B" "C"]),2);                         % math functions work on tables: sum, mean, max, etc.
T.Result = rowfun(@myFcn, T, ...                           % complicated row operations
    InputVariables=["A" "B" "C"], OutputFormat="uniform");
```

### Reshaping and aggregation

Choose based on whether you need aggregation, reshaping, or both:

- **`groupsummary`** - aggregate only (no reshape): multiple methods, multiple data variables. See [Grouping and Aggregation](#grouping-and-aggregation).
- **`unstack`** - reshape only (tall to wide, inverse of `stack`): spread one variable into many
- **`pivot`** - aggregate AND reshape (one row per X, one variable per Y): one data variable, one method, multiple grouping variables

```matlab
% Reshape without aggregation — use unstack
Twide = unstack(Ttall,"Value","Category");

% Aggregate and reshape — use pivot
P = pivot(T, Rows="Category", Columns="Region", DataVariable="Sales", Method="sum");
```

- **`stack`** - gather multiple variables into one (wide to tall):
  ```matlab
  Ttall = stack(T,["Q1" "Q2" "Q3" "Q4"], NewDataVariableName="Sales", IndexVariableName="Quarter");
  ```
- **`rows2vars`** - transpose a table (rows become variables)

### Joining

```matlab
T = innerjoin(T1,T2, Keys="Key");
T = outerjoin(T1,T2, Keys="Key", MergeKeys=true);
```

> `topkrows`, `varfun`, `splitvars`/`mergevars`, reshape examples: [data-transformation.md](references/data-transformation.md)

## Grouping and Aggregation

**`groupsummary`** is the go-to for grouped statistics. Do not use `findgroups`+`accumarray` or manual loops for aggregation — `groupsummary` is faster and works directly with tables. Use `findgroups` alone only when you need group indices without aggregation.

```matlab
G = groupsummary(T,"Category",["mean" "std"],"Value");        % multiple methods on one variable
G = groupsummary(T,["Category" "Region"],"mean","Value");     % multiple grouping vars
```

Notes:
- Output always includes `GroupCount` - no need to specify a count method separately. For counts only, use `groupcounts`.
- Valid method names: `"mean"`, `"sum"`, `"std"`, `"min"`, `"max"`, `"median"`, `"mode"`, `"var"`, `"range"`, `"nummissing"`, `"numunique"`, `"nnz"`, `"all"`. Do **not** use `"numel"` or `"counts"` (these will error).
- **Prefer string method names over function handles** (e.g., `"mean"` not `@mean`). Named methods use accelerated code paths and are significantly faster on large datasets.
- Consider `IncludeMissingGroups=false` to exclude groups defined by a missing value (such as `NaN` for numeric types) that can dominate results.
- Use `IncludeEmptyGroups=true` to include all categories of a categorical variable, even those with no rows.
- Supports on-the-fly binning: `groupsummary(T,"Age",[0 18 35 50 Inf],"mean","Income")` - no need for `discretize` first. Works with `groupcounts`, `groupfilter`, and `grouptransform` too.
- **Time binning has two forms** — sequential (`"hour"`, `"month"`, `"year"`) creates one bin per calendar period in the data (e.g., Jan 2023, Feb 2023, ...). Cyclic (`"hourofday"`, `"dayofweek"`, `"monthofyear"`) collapses across the higher unit to reveal repeating patterns (e.g., all Mondays together). Choose based on whether you want a timeline or a cycle. No need to extract components with `hour()`/`month()` first — pass the binning rule directly to `groupsummary`.
- **Multiple binning methods:** use a cell array when types are mixed (e.g., a named method and custom edges), or a string array when all are named methods:
  ```matlab
  G = groupsummary(TT,["Time" "Time"],["year" "month"],"mean","Value");   % all named — string array
  G = groupsummary(T,["Region" "Age"],{"none" [0 18 35 50 Inf]},"mean","Income");  % mixed — cell array
  ```
  Variable name inputs (grouping variables, data variables) must be string arrays — not cell arrays. See [Use variable names not numeric indices](references/tables-and-timetables.md) for the general rule.

**`groupfilter`** filters rows based on group properties. Two use cases:

```matlab
% (a) Keep entire groups meeting a condition (e.g., groups with enough data)
T = groupfilter(T,"Category",@(x) numel(x) >= 10);

% (b) Filter individual rows within each group (e.g., per-group outlier removal)
T = groupfilter(T,"Category",@(x) ~isoutlier(x),"Value");
```

**When the filter logic matches a built-in detection function (`isoutlier`, `ismissing`, `ischange`), use it inside the function handle rather than reimplementing the arithmetic.** Built-in functions handle edge cases (NaN, constant groups) and accept tuning parameters like `ThresholdFactor`.

**`grouptransform`** transforms data within each group, returning a same-size result (normalize, fill, center, or custom):

```matlab
T = grouptransform(T,"Category","zscore","Value");     % overwrites Value with per-Category z-score
```

**`pivot`** for cross-tabulation:

```matlab
P = pivot(T, Rows="Category", Columns="Region");                                % counts
P = pivot(T, Rows="Category", Columns="Region", DataVariable="Sales", Method="sum");  % aggregation
```

> Binning rules, `groupfilter`/`grouptransform` use cases, `pivot` options: [grouping-and-aggregation.md](references/grouping-and-aggregation.md)

## Smoothing, Trends, and Patterns

**`smoothdata`** is the unified entry point for smoothing (not `smooth`, which requires Curve Fitting Toolbox):
```matlab
ysmooth = smoothdata(y,"movmean",5);
ysmooth = smoothdata(y,"gaussian",10);
ysmooth = smoothdata(y,"sgolay",11, Degree=3);       % Savitzky-Golay
ysmooth = smoothdata(y,"movmedian",7);               % robust to outliers

% Target specific variables in a table/timetable
T = smoothdata(T,"movmean",5, DataVariables="Value");
```

**Window size formats:** The window can be a scalar or a 2-element vector:
- Scalar `k`: total window length (e.g., `smoothdata(y,"movmean",5)` uses 5 elements total)
- 2-element vector `[kb kf]`: elements before and after the current point (e.g., `smoothdata(y,"movmean",[2 2])` uses 2 before + current + 2 after = 5 elements)

**Pitfall with time-stamped data:** When smoothing a timetable or using `SamplePoints` with datetime or duration values, the window must be a `duration`, not a number. Sort by time first — `SamplePoints` must be ascending:
```matlab
TT = sortrows(TT);
TT = smoothdata(TT,"movmean",days(30), DataVariables="Value");
% WRONG: smoothdata(TT,"movmean",5, ...)  — numeric window errors with time data
```

**Trends:**
```matlab
ydetrend = detrend(y);                                % remove linear trend
ydetrend = detrend(y,2);                              % remove quadratic trend
[LT,ST,R] = trenddecomp(TT.Value);                   % separate trend + seasonality
```

**Pattern detection:**
```matlab
isPeak = islocalmax(y,MinProminence=5);               % local peaks
isValley = islocalmin(y);                             % local valleys
changes = ischange(y,"mean");                         % mean shift points
changes = ischange(y,"linear");                       % slope/trend direction changes
changes = ischange(y,"variance");                     % variance change points
```

> `smoothdata` methods, `trenddecomp` options, `ischange` details: [smoothing-and-trends.md](references/smoothing-and-trends.md)

---

## Data Exploration

The following are common starting points, not an exhaustive checklist. Use your judgment about what is relevant for the specific dataset and question — explore beyond these examples based on the data's characteristics:

```matlab
head(T)                         % first 8 rows
tail(T)                         % last 8 rows
summary(T)                      % types, ranges, missing counts
size(T)                         % [nRows, nVars]
sum(ismissing(T))               % missing count per variable
groupcounts(T,"Category")      % value counts for a categorical column
```

Check cardinality (`numunique(T.Col)` (R2025a+) or `groupcounts` for value counts), duplicates, and outliers (`isoutlier`) early. For wide tables, `summary` is more informative than `head`.

> Systematic exploration checklist: [exploration.md](references/exploration.md)

---

## Answering Questions About Data

Strategies for producing correct answers when querying tabular data:

### Top/Bottom N queries

Use `topkrows` for quick retrieval:
```matlab
top5 = topkrows(T,5,"Sales");               % top 5 by Sales descending
bot5 = topkrows(T,5,"Sales","ascend");      % bottom 5
```

For more control, use `sortrows` with `MissingPlacement="last"`:
```matlab
Ts = sortrows(T,"Sales","descend", MissingPlacement="last");
result = Ts(1:5,:);
```

**Think about sort direction.** "Highest rank" means rank #1 (lowest number). "Highest salary" means the largest number. Consider variable semantics before choosing `"ascend"` or `"descend"`.

For cross-variable lookups ("ages of the top 4 by pregnancies"), sort by the ranking variable and read the answer variable from the first N rows.

### Missing data in analysis

- Watch for sentinel values (0, -999, "N/A") that aren't marked as missing but shouldn't participate in analysis. Use `standardizeMissing` to fix them.
- Set `IncludeMissingGroups=false` in `groupcounts`/`groupsummary` when groups defined by a missing value (such as `NaN` for numeric types) would dominate.
- **Never apply `rmmissing` to an entire table** just to answer a question about one variable.

### Return data as stored

Return the actual values from the dataset, not interpretations. If a variable stores numeric codes, return the codes. If it stores category labels, return the labels. Don't substitute or map unless asked.

### Filtering

Consider whether exact matching (`==`, `matches`) or partial matching (`contains`, `startsWith`) is appropriate. For counting after filtering, use `height(filtered)` or `nnz(logicalIdx)`.

> Full strategies and examples: [answering-data-questions.md](references/answering-data-questions.md)

---

Copyright 2026 The MathWorks, Inc.
