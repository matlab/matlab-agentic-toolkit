# Tables and Timetables

**Contents:** table/timetable basics, variable naming, metadata, vartype, indexing, convertvars, SamplePoints, ReplaceValues, retime, synchronize, lag, timerange, timeseries2timetable, eventtable, table2array

## Use `table`/`timetable` as primary data containers for tabular data
```matlab
T = table(dates,values,categories, ...
    VariableNames=["Date" "Value" "Category"]);

% Avoid: Arrays lose context
data = [datenum(dates) values double(categories)];
```

## Table design: variables are homogeneous, rows are observations

Each variable (column) should contain values of the same type, units, and meaning. Each row is one observation. If data arrives transposed (measurements as rows, subjects as columns), restructure with `rows2vars` or rebuild the table:

```matlab
% Recommended: observations as rows, measurements as variables
T = table(["Bill";"Sue";"Jane"], [72;64;67], [180;130;135], ...
    VariableNames=["Name" "Height" "Weight"]);

% Not recommended: subjects as columns, measurements as rows
% (mixes types within a variable, breaks grouping/filtering)
```

## Set meaningful table variable names

**Terminology:** Use "variable" (not "column") when referring to table data. A table variable can itself be multi-column (e.g., a matrix) or even a nested table — the only requirement is consistent row count. MathWorks documentation uses "variable" throughout; general internet usage often says "column" but this can be misleading for multi-column variables.

```matlab
T.Properties.VariableNames = ["OrderDate" "CustomerID" "TotalAmount" "Region"];

% Avoid: Generic names
T.Properties.VariableNames = ["Var1" "Var2" "Var3" "Var4"];
```

## Organize metadata in table properties

Store per-variable metadata in `Properties` — not as extra data rows or separate lookup tables:
```matlab
T.Properties.VariableNames = ["OrderDate" "CustomerID" "TotalAmount" "Region"];
T.Properties.VariableUnits = ["" "" "USD" ""];
T.Properties.VariableDescriptions = [...
    "Date of order" ...
    "Unique customer identifier" ...
    "Total order amount in US dollars" ...
    "Geographic sales region"];
```

Use `CustomProperties` for domain-specific per-variable metadata beyond units and descriptions:
```matlab
T = addprop(T,"Source",["variable"]);
T.Properties.CustomProperties.Source = ["ERP" "CRM" "ERP" "CRM"];
```

Per-row metadata (operator name, equipment ID, batch number) belongs as additional table variables — not in Properties, which is per-variable only:
```matlab
T.Operator = ["Alice"; "Bob"; "Alice"; "Carol"];
T.EquipmentID = ["EQ-01"; "EQ-02"; "EQ-01"; "EQ-03"];
```

## Use `vartype` for type-based selection
```matlab
% Select by type
numericVars = T(:,vartype("numeric"));
textVars = T(:,vartype("string"));
```

## Use appropriate table indexing
```matlab
% Use dot notation for a single variable
col = T.Value;

% Use parentheses for table subsets
subset = T(:,["A" "B" "C"]);

% Use table2array when extracting as array
matrix = table2array(T(:,vartype("numeric")));
```

## Use variable names not numeric indices
```matlab
value = T.Value;
T.OldVar = [];

% Dynamic dot indexing when you have an index or computed name
val = T.(3);                    % access 3rd variable by index
val = T.(varName);              % access variable by name in a string variable

% Braces for extracting multiple variables as an array
matrix = T{:,[2 4 5]};         % extract variables 2, 4, 5 as array

% Avoid: Hardcoded numeric indices or workarounds through Properties
value = T{:,3};
T(:,5) = [];
name = T.Properties.VariableNames(ind); T(:,name);  % unnecessary indirection
```

## Use dynamic dot indexing `T.(expr)` for runtime variable access

```matlab
% Iterating over variables by index
for i = 1:width(T)
    T.(i) = fillmissing(T.(i),"previous");
end

% Variable name stored in a string
varName = "Salary";
vals = T.(varName);

% Computed or non-identifier names
T.("Net Income") = T.("Revenue") - T.("Total Cost");
colName = "Var_" + string(year(datetime("today")));
T.(colName) = zeros(height(T),1);

% Passing variable names to functions
function result = processColumn(T, varName)
    result = normalize(T.(varName));
end
```

**Never use `eval` for dynamic variable access:**
```matlab
% Avoid: eval is slow, error-prone, and defeats static analysis
val = eval("T." + varName);           % WRONG
eval("T." + varName + " = x;");       % WRONG
```

## Use `convertvars` or `VariableTypes` to fix variable types after import

Post-import type conversion is extremely common. Use `convertvars` for targeted fixes or set `VariableTypes` for bulk inspection and conversion:

```matlab
% Convert specific variables by name
T = convertvars(T,["Region" "Status"],"categorical");
T = convertvars(T,"ID","string");

% Convert by type - e.g., all cellstr variables to string
T = convertvars(T,vartype("cellstr"),"string");

% Inspect current types
T.Properties.VariableTypes
%   "double"    "string"    "categorical"    "datetime"

% VariableTypes is also writeable - a shortcut for type conversion
T.Properties.VariableTypes("Status") = "categorical";
```

## `SamplePoints` for non-uniform data

Many data preprocessing functions - `fillmissing`, `isoutlier`, `smoothdata`, and others - support a `SamplePoints` parameter for non-uniformly spaced data. The behavior depends on the container type:

Prefer operating on the whole table/timetable rather than extracting a single variable. This keeps the sample points paired with the data, and variables you aren't working on won't be touched.

**Data must be sorted** by the sample points in ascending order. Sort the table or timetable first with `sortrows` before calling any function that uses `SamplePoints` or timetable row times.

**Table input:** Set `SamplePoints` to the variable name representing the x-axis, and use `DataVariables` to target specific variables:
```matlab
T = sortrows(T,"Distance");  % SamplePoints must be ascending
T = fillmissing(T, "linear", DataVariables="Value", SamplePoints="Distance");
T = smoothdata(T, "movmean", 50, DataVariables="Value", SamplePoints="Distance");
idx = isoutlier(T, DataVariables="Value", SamplePoints="Distance");
```

**Timetable input:** The row times are used as sample points automatically. Do not set `SamplePoints` - it will error:
```matlab
TT = sortrows(TT);  % ensure sorted by row times
TT = fillmissing(TT, "linear", DataVariables="Value");
TT = smoothdata(TT, "movmean", hours(6), DataVariables="Value");
idx = isoutlier(TT, DataVariables="Value");
```

This is one of the key benefits of converting to timetable: all these functions become spacing-aware with no extra arguments.

See also [smoothing-and-trends.md](smoothing-and-trends.md) and [data-cleaning.md](data-cleaning.md) for how `SamplePoints` affects window sizes and fill behavior.

## `ReplaceValues` for non-destructive operations

Many preprocessing functions overwrite table/timetable variables by default. Set `ReplaceValues=false` to append results as new variables instead (e.g., `"Value_filled"`, `"Temp_smoothed"`). See [data-transformation.md](data-transformation.md) for the full list of supporting functions and examples.

## Timetable row times dimension name

The row times dimension name defaults to `"Time"` but inherits from the workspace variable name used during construction:
```matlab
TT = timetable(hours(1:5)', x);                     % dimension name is "Time" (default)
TT = timetable(myTimes, x);                         % dimension name is "myTimes"
TT = table2timetable(T, RowTimes="Timestamp");      % dimension name is "Timestamp"
TT.Properties.DimensionNames{1}                     % check the actual name
```

This matters when referencing row times by name in `groupsummary`, `sortrows`, or other functions. Always use the actual dimension name rather than assuming `"Time"`.

## Use `retime` to resample timetables, not manual interpolation
```matlab
TThourly = retime(TT,"hourly","linear");

% Aggregation
TTdaily = retime(TT,"daily","mean");
TTmonthly = retime(TT(:,"Loss"),"monthly","sum");

% Custom time vector
newTimes = datetime(2024,1,1):hours(6):datetime(2024,12,31);
TTresampled = retime(TT,newTimes,"pchip");
```

**Pitfall:** `retime` does not support `DataVariables`. Aggregation methods must be applicable to all variables in the timetable. For example, exclude text-based variables before applying a `"sum"` aggregation. Select the variables you need first:
```matlab
% Select specific variables
TTmonthly = retime(TT(:,"Loss"),"monthly","sum");

% Or select all numeric variables
TTmonthly = retime(TT(:,vartype("numeric")),"monthly","sum");
```

**Per-variable behavior with `VariableContinuity`:** To apply different methods to different variables, set the `VariableContinuity` property and call `retime` without a method. Each variable is resampled according to its continuity type:
```matlab
TT.Properties.VariableContinuity = ["step" "continuous" "continuous" "step" "step"];
TTresampled = retime(TT,"monthly");
% "continuous" variables → linear interpolation
% "step" variables → previous value (forward fill)
% "event"/"unset" → filled with missing
```

Time steps: `"yearly"`, `"quarterly"`, `"monthly"`, `"weekly"`, `"daily"`, `"hourly"`, `"minutely"`, `"secondly"`, a custom datetime vector, or `"regular"` with a custom duration via `TimeStep`:
```matlab
TT_6h = retime(TT(:,vartype("numeric")), "regular", "mean", TimeStep=hours(6));
```

Methods by category:
- **Interpolation:** `"linear"`, `"spline"`, `"pchip"`, `"makima"` - for upsampling to a finer grid
- **Aggregation:** `"mean"`, `"median"`, `"sum"`, `"prod"`, `"min"`, `"max"`, `"mode"`, `"count"`, `"firstvalue"`, `"lastvalue"`, or a function handle (e.g., `@std`) - for downsampling to a coarser grid
- **Fill:** `"previous"`, `"next"`, `"nearest"`, `"fillwithmissing"`, `"fillwithconstant"`

**Interpolation and fill methods require sorted row times** (for both `retime` and `synchronize`). Use `sortrows(TT)` first if row times may be unsorted. Aggregation methods do not require sorted row times.

### Use `retime` to resolve duplicate timestamps

When a timetable has rows sharing the same timestamp (e.g., merged sensor logs), use `retime` with the unique row times to consolidate:
```matlab
TT = retime(TT, unique(TT.Time), "firstvalue");
```
This preserves the original time spacing — unlike resampling to a regular grid, which changes it. Consider the structure and meaning of the data when choosing an aggregation method (e.g., `"mean"` for numeric measurements, `"firstvalue"` for mixed-type tables), and ensure the method is valid for all variables in the timetable.

## Use `synchronize` to align multiple timetables
```matlab
TTsync = synchronize(TT1,TT2,"intersection");

% With interpolation for missing times
TTsync = synchronize(TT1,TT2,"union","linear");

% Common regular time base
TTsync = synchronize(TT1,TT2,"hourly","mean");
```

`synchronize` supports the same time steps and methods as `retime` (interpolation, aggregation, and fill).

## Use `lag` to time-shift timetable data
```matlab
TT_prev = lag(TT,1);              % shift data forward by 1 time step (previous values)
TT_next = lag(TT,-1);             % shift backward (next values)
TT_shifted = lag(TT,calmonths(2)); % shift by a calendar duration

% Compute row-to-row differences
TT_prev = lag(TT,1);
TT.Diff = TT.Value - TT_prev.Value;
```

## Use `timerange` for time-based filtering
```matlab
S = timerange("2024-01-01","2024-06-01");
TTsubset = TT(S,:);

% Open/closed boundaries (default is "openright": start <= t < end)
S = timerange("2024-01-01","2024-12-31","closed");
```

`timerange` works as a row subscript for any timetable - cleaner than logical indexing with `isbetween` on the time variable.

## Time-based subscripting for timetables

Timetables support subscripting directly with datetime values, `timerange`, and `withtol`:
```matlab
% Exact time subscript (returns empty timetable if no match)
row = TT(datetime(2024,3,15),:);

% Time range subscript (all rows in interval)
subset = TT(timerange("2024-01-01","2024-06-01"),:);

% Fuzzy match within tolerance (for irregular timestamps)
subset = TT(withtol(targetTimes,seconds(5)),:);
```

Prefer these over logical indexing with `isbetween` for timetables — they are more concise and purpose-built. Use `isbetween` for tables, which do not support time-based subscripting.

## Consider `timeseries2timetable` for legacy `timeseries` objects
```matlab
TT = timeseries2timetable(ts);
```

The `timeseries` class still works, but the modern `timetable` is recommended. Converting unlocks `retime`, `synchronize`, `fillmissing`, `smoothdata`, and other modern operations.

## Use `eventtable` to annotate timetables with events

An `eventtable` stores labeled events (instantaneous or interval) that can be attached to a timetable:
```matlab
% Create an eventtable from times and labels
ET = eventtable(datetime(2024,3,[1 5 12])', ...
    EventLabels=categorical(["Outage" "Maintenance" "Outage"]));

% With durations
ET = eventtable(datetime(2024,3,[1 5 12])', ...
    EventLabels=categorical(["Outage" "Maintenance" "Outage"]), ...
    EventLengths=hours([2 4 1]));

% Attach to a timetable
TT.Properties.Events = ET;

% Filter timetable at event times
EF = eventfilter(TT);
vals = TT(EF,:);

% Propagate event data into timetable rows
TT = syncevents(TT,EventDataVariables="EventLabels");
```

`stackedplot` automatically overlays attached events on time series plots.

## Pass tables directly to math and chart functions when supported

Many math operations (`sin`, `std`, `sum`) and chart functions (`plot`, `stackedplot`, `scatter`) accept tables directly — this preserves variable names as labels. Use `sin(T(:,vars))` not `sin(T{:,:})`. Only extract to array for functions that require it (e.g., `eig`, `svd`).

## Use `table2array` when you need a numeric array
```matlab
% Extract numeric data as an array (e.g., for functions that require arrays)
numericData = table2array(T(:,vartype("numeric")));

% The reverse
T = array2table(matrix, VariableNames=["X" "Y" "Z"]);
```

Note: Many plotting and analysis functions now accept tables directly — only convert to array when the function requires it.

---

Copyright 2026 The MathWorks, Inc.
