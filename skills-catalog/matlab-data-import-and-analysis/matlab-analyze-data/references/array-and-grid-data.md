# Array and Grid Data

**Contents:** when to use arrays, dimension-aware operations, std/var/movstd/movvar pitfall, missing data handling, moving and cumulative statistics, mink/maxk/bounds/rms, paddata/trimdata/resize, logical indexing, grouping on arrays, smoothdata2, fillmissing2, islocalmax2/islocalmin2

## When arrays are appropriate (vs converting to table or timetable)

Arrays are the right container when data is homogeneous numeric AND either:
- Naturally 2D/grid (sensor matrices, geospatial elevation/temperature grids, data gridded along x- and y-coordinates)
- Vectorized numeric computation where all columns share the same type — operations on arrays are fully vectorized, whereas the same numeric data spread across table variables incurs per-variable overhead
- Performance-critical inner loop where table overhead matters
- Upstream tooling delivers arrays and conversion adds no value (MEX, toolbox output, legacy code)

Tables remain the default for mixed-type, labeled, or observational data. This section validates staying in arrays for legitimate cases — not as an excuse to avoid tables.

**Converting between containers:**
```matlab
T = array2table(matrix, VariableNames=["X" "Y" "Z"]);
X = table2array(T(:,vartype("numeric")));
```

For table and timetable workflows, see [tables-and-timetables.md](tables-and-timetables.md).

## Getting oriented with array data

```matlab
size(X)                    % dimensions [rows, cols, ...]
ndims(X)                   % number of dimensions
anymissing(X)              % quick health check: any NaN?
summary(X)                 % per-column NumMissing, Min, Median, Max, Mean, Std (R2024b+)
summary(X,2,Statistics=["mean" "std" "nummissing" "range"])  % choose specific per-row stats (R2024b+)

% Per-column stats
mean(X)                    % column means (1-by-n)
[s,m] = std(X,0,1);        % column std AND mean in one call (m is the mean used internally)
[lo,hi] = bounds(X);       % column min and max in one call (1-by-n each)

% Per-row stats
mean(X,2)                  % row means (m-by-1)
[s,m] = std(X,0,2);        % row std AND mean in one call
[lo,hi] = bounds(X,2);     % row min and max (m-by-1 each)
```

## Dimension-aware operations

For most array functions, the default operating dimension is the first non-singleton dimension — which is dim=1 for matrices but may differ for vectors or higher-dimensional arrays.

**`sum`, `mean`, `std`, `var`, `max`, `min`, `median` collapse along the default dimension** — for matrices this means collapsing rows, producing one value per column. To operate along a different dimension, specify it explicitly.

Other functions also accept a dimension argument but are not dim-reducing (e.g., `rmmissing`, `fillmissing`, `cumsum`, `summary`, etc). The pattern is the same: specify which dimension to operate along.

```matlab
colMeans = mean(X);        % same as mean(X,1) — one value per column
rowMeans = mean(X,2);      % one value per row
allMean  = mean(X,"all");  % scalar — collapse all dimensions

% For multidimensional arrays, collapse multiple dimensions at once:
sliceMean = mean(X,[1 2]); % collapse dims 1 and 2, keep remaining dims
```

### The std/var weight-first-arg pitfall

**`std` and `var` take a weighting scheme `w` as the SECOND argument, not a dimension.** The signature is `std(X,w,dim)` — to specify dimension, you must pass `w` first. Writing `std(X,2)` sets `w=2`, it does NOT compute std along dimension 2.

```matlab
% CORRECT — compute std along dimension 2 (per-row)
rowStd = std(X,0,2);       % w=0 (default normalization), dim=2

% WRONG — this sets w=2 and operates along the default dimension
rowStd = std(X,2);          % NOT per-row std!
```

The `w` argument serves dual purposes:
- `0` = unbiased estimate, normalizing by N-1 (sample std, default)
- `1` = biased estimate, normalizing by N (population std)
- A vector of nonneg values = actual weighted std (length must match the operating dimension)

The same applies to `var`:
```matlab
rowVar = var(X,0,2);       % correct: per-row variance
```

### Specifying dimension explicitly

When operating on matrices or multidimensional arrays, consider specifying the dimension if the input shape may vary or if dim=1 is not obvious from context. This makes intent clear and prevents surprises when data comes in as a row vs. a column. For straightforward cases where the default dimension is natural, omitting it is fine — MATLAB's defaults are designed to do the right thing for common usage patterns.

### Missing value handling in array statistics

**Array stats functions do NOT automatically skip NaN.** Pass `"omitmissing"` explicitly — it works for numeric NaN and also for other missing-value types (datetime NaT, string missing, etc.):

```matlab
m = mean(X,1,"omitmissing");           % column means, skipping NaN
s = std(X,0,1,"omitmissing");          % column std, skipping NaN
[lo,hi] = bounds(X,1,"omitmissing");   % bounds, skipping NaN
```

## Missing data in arrays

### Quick check
```matlab
anymissing(X)              % scalar logical — any missing values?
sum(ismissing(X))          % count per column
sum(ismissing(X),2)        % count per row
```

### Removing missing data with `rmmissing`
```matlab
Xclean = rmmissing(X);              % remove rows with any missing
Xclean = rmmissing(X,2);            % remove columns with any missing
Xclean = rmmissing(X,1,MinNumMissing=3);  % only remove rows with 3+ missing values
```

### Filling missing data (1D) with `fillmissing`

On arrays, the key difference from table usage is the `dim` argument for controlling direction. For fill methods, `DataVariables`, and `MaxGap`, see [data-cleaning.md](data-cleaning.md).

```matlab
F = fillmissing(X,"linear");           % interpolate per column
F = fillmissing(X,"linear",2);         % interpolate along dim 2 (across columns)
```

### Filling missing data (2D) with `fillmissing2`

**Use `fillmissing2` for 2D grids — it treats the matrix as a bivariate surface** and interpolates using spatial information from both dimensions. Do not loop `fillmissing` over rows/columns for grid data.

```matlab
F = fillmissing2(X,"linear");                     % 2D linear interpolation
F = fillmissing2(X,"natural");                    % natural neighbor interpolation
F = fillmissing2(X,"cubic");                      % cubic interpolation
F = fillmissing2(X,"movmedian",{3,3});            % 3x3 moving median fill
```

**`SamplePoints` for non-uniform grids** — 2-element cell array `{xCoords, yCoords}`, one vector per dimension. The cell array allows different types per dimension (e.g., duration for time, numeric for space):
```matlab
F = fillmissing2(X,"linear",SamplePoints={lon,lat});
% mixed types, moving window maps to SamplePoints
F = fillmissing2(X,"movmedian",{hours(2),5},SamplePoints={hours(1:nCols),1:nRows});  
```

**`MissingLocations`** — use when you already have a logical mask identifying values to treat as missing (e.g., from a prior detection step). If you need to convert sentinel values like -999 to standard missing, use `standardizeMissing` first instead:
```matlab
F = fillmissing2(X,"natural",MissingLocations=badMask);
```

Available interpolation methods: `"nearest"`, `"linear"`, `"natural"`, `"cubic"`, `"v4"` (biharmonic spline).
Moving window methods: `"movmean"`, `"movmedian"`.

## Moving and cumulative statistics

### Moving window operations (1D, per column or per row)

These operate on 1D slices of the array — one column or one row at a time. For 2D grid smoothing, see [smoothdata2](#2d-smoothing-with-smoothdata2) below. The options below (`[kb kf]`, `"omitmissing"`, `EndPoints`, `SamplePoints`) apply to all `mov*` functions: `movmean`, `movmedian`, `movsum`, `movstd`, `movvar`, `movmad`, `movprod`, `movmin`, `movmax`.

```matlab
M = movmean(X,5);              % 5-element moving mean per column
M = movmedian(X,7,2);          % 7-element moving median per row (along dim 2)
M = movsum(X,10);              % 10-element moving sum per column
M = movmad(X,5);               % moving median absolute deviation per column

% Asymmetric (trailing) window: [kb kf] = elements before + after current
M = movmean(X,[4 0]);          % trailing 5-point average (current + 4 preceding)
M = movmedian(X,[0 4]);        % leading 5-point median (current + 4 following)

% Missing value handling
M = movsum(X,5,"omitmissing"); % skip NaN in computation

% Endpoint handling
M = movmean(X,5,EndPoints="discard");   % omit values where window doesn't fully overlap
M = movmedian(X,5,EndPoints="fill");    % NaN where window is incomplete
M = movmean(X,5,EndPoints=0);           % substitute 0 for missing boundary elements

% Non-uniform spacing
M = movmean(X,hours(2),SamplePoints=t); % window in sample-point units (t is datetime/duration)
```

### The movstd/movvar weight-first-arg pitfall

**`movstd` and `movvar` have the same pitfall as `std`/`var`:** the third positional argument is a normalization weight, NOT a dimension. To specify dimension, pass weight as the third arg and dimension as the fourth.

```matlab
% CORRECT — moving std along dimension 2 (across columns)
M = movstd(X,k,0,2);       % window=k, weight=0 (N-1), dim=2

% WRONG — this sets weight=2, does NOT operate along dim 2
M = movstd(X,k,2);          % third arg is weight, not dim!

% Population-normalized moving std (weight=1 means normalize by N)
M = movstd(X,k,1,1);       % window=k, weight=1 (N), dim=1

% More examples
M = movstd(X,5,0,1);       % window=5, sample std, per column
M = movvar(X,5,0,2);       % window=5, sample var, per row
```

### Cumulative operations
```matlab
C = cumsum(X);                      % running sum per column
C = cumsum(X,2);                    % running sum per row
C = cumsum(X,"reverse");            % running sum from end to start (right-to-left / bottom-to-top)
C = cumsum(X,2,"reverse");          % reverse along dim 2
C = cummax(X);                      % running maximum per column
C = cummin(X,2);                    % running minimum per row
C = cumprod(X,"omitmissing");       % running product, skipping NaN
```

Direction (`"forward"`/`"reverse"`) and `"omitmissing"`/`"includemissing"` apply to `cumsum`, `cummax`, `cummin`, and `cumprod`.

### Single-value statistics
```matlab
[lo,hi] = bounds(X);                  % min and max per column
[lo,hi] = bounds(X,2);                % min and max per row
[lo,hi] = bounds(X,"all");            % global min and max
B = mink(X,3);                        % 3 smallest per column
B = mink(X,3,2);                      % 3 smallest per row
[B,I] = maxk(X,5);                    % 5 largest per column with indices
r = rms(X);                           % root mean square per column
r = rms(X,2);                         % root mean square per row
r = rms(X,1,"omitmissing");           % skip NaN (base MATLAB since R2022a)
```

**`prctile`, `quantile`, and `iqr` are base MATLAB (since R2022a) — no Statistics Toolbox required:**
```matlab
p = prctile(X,[25 50 75]);            % percentiles per column
p = prctile(X,[25 50 75],2);          % percentiles per row
q = quantile(X,4);                    % quartile boundaries per column
r = iqr(X);                           % interquartile range per column
r = iqr(X,2);                         % interquartile range per row
```

## Resizing and alignment

**Use `paddata`, `trimdata`, and `resize` (R2023b) instead of manual indexing or NaN concatenation.**

```matlab
% Pad to target length (default: trailing zeros along first non-singleton dim)
B = paddata(X,100);                        % pad to 100 rows
B = paddata(X,100,FillValue=NaN);          % pad with NaN
B = paddata(X,100,Side="leading");         % prepend instead of append
B = paddata(X,100,Dimension=2);            % pad columns instead of rows
B = paddata(X,1024,Pattern="edge");        % extend by repeating boundary values

% Trim to target length (default: remove trailing)
B = trimdata(X,50);                        % trim to 50 rows
B = trimdata(X,50,Side="leading");         % trim from beginning
B = trimdata(X,50,Dimension=2);            % trim columns

% Resize — pads or trims as needed to hit exact target
B = resize(X,100);                         % single dimension
B = resize(X,[100 8],Dimension=[1 2]);     % target both dimensions
```

Note: the dimension argument for `paddata`, `trimdata`, and `resize` is a **name-value** (`Dimension=`), unlike most stats functions where it is positional.

**Padding patterns** for `paddata` and `resize`:
| Pattern | Behavior |
|---------|----------|
| `"constant"` (default) | Fill with zeros (or custom `FillValue`) |
| `"edge"` | Repeat the last element |
| `"circular"` | Wrap around (periodic extension) |
| `"flip"` | Mirror without repeating boundary |
| `"reflect"` | Mirror including boundary element |

`Side` options: `"trailing"` (default), `"leading"`, `"both"`.

These functions also work on tables, timetables, cell arrays, and structure arrays.

### Checking uniform spacing

Use `isuniform` for numeric vectors and `isregular` for datetime/duration vectors and timetables:
```matlab
[tf,step] = isuniform(t);      % numeric vectors — step returned as double
[tf,step] = isregular(TT);     % timetables, datetime, duration — step returned as duration or calendarDuration
```

These are not interchangeable — subtle differences exist:
- `isuniform` returns true when spacing is zero (e.g., `isuniform([1 1 1])` is true); `isregular` returns false for zero spacing
- The second output of `isuniform` is always a double, regardless of input type
- `isuniform` errors if the computed step exceeds `realmax`

Verify uniform spacing before operations that require it (e.g., `trenddecomp`, FFT-based analysis). Also covered in [exploration.md](exploration.md).

## Logical indexing and filtering

**Index with logical masks directly — this is cleaner and more performant than `find`.** Use `find` only when you specifically need the numeric indices (e.g., for reporting positions or non-contiguous assignment).

**Floating-point pitfall:** Do not use `==` to compare computed numeric values — floating-point arithmetic introduces round-off error. Use `isapprox` (R2024b) for tolerance-aware comparison:
```matlab
mask = isapprox(X(:,3), 1.5);                  % approximate equality (default tol ~1e-15)
mask = isapprox(X(:,3), 1.5, "loose");          % wider tolerance (~1e-8)
mask = isapprox(X(:,3), target, RelativeTolerance=1e-6);  % custom relative tolerance
```

```matlab
% Preferred: logical indexing
mask = X(:,3) > 100;                   % rows where column 3 exceeds 100
subset = X(mask,:);                     % extract matching rows

% Combine conditions
mask = X(:,1) > 0 & X(:,2) < 50;
subset = X(mask,:);

% any/all along dimensions
rowsWithNaN = any(ismissing(X),2);      % logical column: true if row has any missing
colsAllPositive = all(X > 0,1);         % logical row: true if column is all positive

% find — use ONLY when you need the actual index values
[row,col] = find(X == max(X,[],"all")); % subscript location of global maximum
idx = find(X(:,1) > threshold, 1);      % index of first row exceeding threshold
```

## Grouping on arrays

`groupsummary`, `grouptransform`, and `groupfilter` work on arrays — the syntax uses a grouping vector instead of a variable name. For table syntax, see [grouping-and-aggregation.md](grouping-and-aggregation.md).

### `groupsummary` on arrays
```matlab
% Basic: summarize X by groups defined in g
[grpMeans,grpIDs,grpCounts] = groupsummary(X,g,"mean");

% Multiple methods
[result,grpIDs,grpCounts] = groupsummary(X,g,["mean" "std"]);

% With binning (bin the grouping variable)
[result,grpIDs,grpCounts] = groupsummary(X,g,[0 10 20 30 Inf],"mean");

% Multiple grouping vectors
[result,grpIDs,grpCounts] = groupsummary(X,{g1,g2},"sum");
```

**Key difference from table syntax:** the method argument is required for arrays (tables can omit it to get counts only). Additionally, array syntax has multiple outputs to hold results, group ids and group counts, rather than one table holding all the information.

### `grouptransform` on arrays
```matlab
B = grouptransform(X,g,"zscore");          % per-group z-score
B = grouptransform(X,g,"rescale");         % per-group rescale to [0,1]
B = grouptransform(X,g,"meanfill");        % fill NaN with group mean
```

Available methods: `"zscore"`, `"norm"`, `"meancenter"`, `"rescale"`, `"meanfill"`, `"linearfill"`, or a function handle.

### `groupfilter` on arrays
```matlab
B = groupfilter(X,g,@(x) size(x,1) >= 5);   % keep groups with 5+ members
B = groupfilter(X,g,@(x) ~isoutlier(x));    % remove per-group outliers
```

## 2D smoothing with `smoothdata2`

**Use `smoothdata2` for 2D grids — do not loop `smoothdata` over rows/columns.** It treats the matrix as a surface and smooths in both directions simultaneously. For 1D smoothing details, see [smoothing-and-trends.md](smoothing-and-trends.md).

```matlab
S = smoothdata2(X,"movmean");                     % automatic window
S = smoothdata2(X,"gaussian",{5,5});              % 5-by-5 Gaussian window
S = smoothdata2(X,"movmedian",{3,7});             % 3 rows by 7 columns
```

Available methods: `"movmean"` (default), `"movmedian"`, `"gaussian"`, `"lowess"`, `"loess"`, `"sgolay"`.

Window specification:
- Scalar `k`: symmetric k-by-k window
- Cell array `{m,n}`: m-by-n block
- Cell array `{[bRow fRow],[bCol fCol]}`: asymmetric (preceding/following per dimension)

**`SamplePoints` for non-uniform grids** — 2-element cell array `{xCoords, yCoords}`. The cell array allows different types per dimension (e.g., duration for time, numeric for space):
```matlab
S = smoothdata2(X,"gaussian",SamplePoints={lon,lat});
S = smoothdata2(X,"movmean",SamplePoints={hours(1:nCols),1:nRows});
```

## 2D detection with `islocalmax2` / `islocalmin2`

**Use `islocalmax2` for peak detection in 2D grids (elevation, temperature, pressure).** It examines a 2D neighborhood — do not flatten or loop. For 1D peak detection, see [smoothing-and-trends.md](smoothing-and-trends.md).

```matlab
TF = islocalmax2(X);                              % local maxima in 2D
TF = islocalmax2(X,MinProminence=10);             % ignore small bumps
TF = islocalmax2(X,MaxNumExtrema=5);              % top 5 most prominent peaks
TF = islocalmax2(X,MinSeparation=3);              % minimum Euclidean distance apart
[TF,P] = islocalmax2(X);                          % also get prominence values
TF = islocalmin2(X,MinProminence=10);             % 2D valleys (same options)
```

**Key name-value arguments** (same for both `islocalmax2` and `islocalmin2`):
- `MinProminence` — minimum prominence threshold (default: 0). Increase for noisy data.
- `MaxNumExtrema` — return only the N most prominent peaks
- `MinSeparation` — minimum Euclidean distance between peaks
- `FlatSelection` — how to handle plateaus: `"center"` (default), `"first"`, `"all"`
- `ProminenceWindow` — restrict prominence calculation region: scalar `k` for k-by-k, `{m,n}` for rectangular
- `SamplePoints` — 2-element cell array `{xCoords, yCoords}` for non-uniform grids

---

Copyright 2026 The MathWorks, Inc.
