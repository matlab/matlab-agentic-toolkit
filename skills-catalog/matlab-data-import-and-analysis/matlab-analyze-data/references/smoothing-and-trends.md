# Smoothing and Trends

**Contents:** smoothdata (movmean, gaussian, sgolay, movmedian), detrend, trenddecomp, islocalmax/islocalmin, ischange, histcounts/histogram

## Use `smoothdata` not `smooth` or manual windows
```matlab
ysmooth = smoothdata(y,"movmean",5);
ysmooth = smoothdata(y,"gaussian",10);
ysmooth = smoothdata(y,"loess");

% Works on tables/timetables with DataVariables
T = smoothdata(T, "movmean", 5, DataVariables="Value");
TT = smoothdata(TT, "gaussian", hours(6), DataVariables="Sensor");

% Less portable: Curve Fitting Toolbox required
ysmooth = smooth(y,5);
ysmooth = smooth(y,"loess");

% Avoid: Manual moving window
windowSize = 5;
ysmooth = zeros(size(y));
for i = 1:numel(y)
    startIdx = max(1,i - floor(windowSize/2));
    endIdx = min(numel(y),i + floor(windowSize/2));
    ysmooth(i) = mean(y(startIdx:endIdx));
end
```

**Window size formats:** The window can be a scalar or a 2-element vector:
- Scalar `k`: total window length (e.g., `smoothdata(y,"movmean",5)` uses 5 elements total)
- 2-element vector `[kb kf]`: elements before and after the current point (e.g., `smoothdata(y,"movmean",[2 2])` uses 2 before + current + 2 after = 5 elements)

This also applies to `movmean`, `movmedian`, and other `mov*` functions.

**Pitfall with time-stamped data:** When the input is a timetable, or `SamplePoints` contains datetime or duration values, the window must be a `duration`, not a number:
```matlab
% Timetable — window must be a duration
TT = sortrows(TT);  % ensure sorted by time
TT = smoothdata(TT, "movmean", days(30), DataVariables="Value");

% Table with explicit datetime SamplePoints — same rule
T = sortrows(T,"Time");
T = smoothdata(T, "movmedian", hours(12), ...
    DataVariables="Value", SamplePoints="Time");

% Table with explicit duration SamplePoints — same rule
T = smoothdata(T, "movmean", seconds(5), ...
    DataVariables="Value", SamplePoints="Elapsed");

% Numeric array — window is a scalar count (number of elements)
ysmooth = smoothdata(y,"movmean",5);

% WRONG — numeric window with datetime/duration SamplePoints errors
% T = smoothdata(T, "movmean", 5, SamplePoints="Time");
```
Also ensure the data is sorted by time before smoothing — `SamplePoints` must be in ascending order.

Available methods:
- `"movmean"` (default) - moving average, good for periodic trends
- `"movmedian"` - moving median, robust to outliers
- `"gaussian"` - Gaussian-weighted average
- `"lowess"` - local linear regression
- `"loess"` - local quadratic regression
- `"rlowess"` - robust local linear regression (outlier-resistant)
- `"rloess"` - robust local quadratic regression (outlier-resistant)
- `"sgolay"` - Savitzky-Golay polynomial filter

## Use `smoothdata(..., "sgolay")` not `sgolay`
```matlab
% Smoothing with Savitzky-Golay
ysmooth = smoothdata(y,"sgolay");
ysmooth = smoothdata(y,"sgolay",11);  % Window size
ysmooth = smoothdata(y, "sgolay", 11, Degree=3);  % Polynomial degree

% Less portable: Signal Processing Toolbox required
order = 3;
frameLen = 11;
[b,g] = sgolay(order,frameLen);
ysmooth = sgolayfilt(y,order,frameLen);
```

## Use `smoothdata(..., "movmedian")` not `medfilt1`
```matlab
% smoothdata for 1-D median filtering
ysmooth = smoothdata(y,"movmedian",7);

% Less portable: Signal Processing Toolbox required
ysmooth = medfilt1(y,7);
```

## Use `movmean` or `smoothdata` for moving average, not `conv`
```matlab
ysmooth = movmean(y,5);  % Proper edge handling

% Avoid: conv for moving average
kernel = ones(5,1)/5;
ysmooth = conv(y,kernel,"same");  % Edge artifacts
```

## Use `detrend` not manual polynomial fit
```matlab
ydetrend = detrend(y);  % Remove linear trend (default)
ycentered = detrend(y,0);  % Remove mean only
ydetrend = detrend(y,2);  % Remove quadratic trend

% Preserve breakpoints
ydetrend = detrend(y,1,[100 200]);  % Piecewise linear

% Avoid: Manual detrend or mean removal
p = polyfit((1:numel(y))',y,1);
trend = polyval(p,(1:numel(y))');
ydetrend = y - trend;
ycentered = y - mean(y);
```

## Use `trenddecomp` for seasonal decomposition of time series

When data has both trend and seasonal components, `trenddecomp` separates them:
```matlab
% SSA (default) - good when seasonal period is unknown
[LT,ST,R] = trenddecomp(TT.Value);

% SSA with explicit lag (larger lag = better separation, max N/2)
[LT,ST,R] = trenddecomp(TT.Value,"ssa",50);

% Extract multiple seasonal components
[LT,ST,R] = trenddecomp(TT.Value, NumSeasonal=2);

% STL - use when you know the seasonal period
[LT,ST,R] = trenddecomp(TT.Value,"stl",12);   % yearly cycle in monthly data

% STL with multiple known periods (e.g., daily + weekly in hourly data)
[LT,ST,R] = trenddecomp(TT.Value,"stl",[24 168]);

% Works on timetable variables directly (returns a table of components)
D = trenddecomp(TT);
```

**Pitfall:** `trenddecomp` requires uniformly spaced data and does not support `SamplePoints`. If your timetable has irregular spacing, use `retime` to resample to a regular time step first:
```matlab
TT = retime(TT,"hourly","linear");    % resample to uniform spacing before decomposing
[LT,ST,R] = trenddecomp(TT.Value);
```

Use `detrend` when you just need to remove a polynomial trend. Use `trenddecomp` when you need to separate trend from seasonality.

## Use `islocalmax`/`islocalmin` not manual loops

`islocalmax`/`islocalmin` are the portable (no toolbox) alternative to `findpeaks` (Signal Processing Toolbox). Use `islocalmax` for peak detection in data analysis workflows.

```matlab
% islocalmax / islocalmin for local peaks and valleys
isPeak = islocalmax(y);
isValley = islocalmin(y);

% With prominence filter (ignore small bumps)
isPeak = islocalmax(y,MinProminence=5);

% Limit number of results (returns the N most prominent)
isPeak = islocalmax(y,MaxNumExtrema=5);

% Enforce minimum distance between peaks
isPeak = islocalmax(y,MinSeparation=10);

% For flat plateaus: pick "first", "last", "center" (default), or "all"
isPeak = islocalmax(y,FlatSelection="first");

% Works on tables/timetables with DataVariables
TT.IsPeak = islocalmax(TT,DataVariables="Value");
peakTimes = TT.Time(TT.IsPeak);

% OutputFormat="tabular": returns a table/timetable of logicals (keeps variable names)
peaks = islocalmax(TT, OutputFormat="tabular", DataVariables=["Temp","Pressure"]);
TT.Time(peaks.Temp)    % peak times for Temp — no positional indexing needed

% Avoid: Manual peak detection
isPeak = false(size(y));
for i = 2:numel(y)-1
    if y(i) > y(i-1) && y(i) > y(i+1)
        isPeak(i) = true;
    end
end
```

## Use `ischange` not manual diff thresholds
```matlab
changes = ischange(y,"mean");       % Mean shift points
changes = ischange(y,"variance");   % Variance change points
changes = ischange(y,"linear");     % Slope change points

% Limit number of change points
changes = ischange(y, "mean", MaxNumChanges=3);

% Adjust sensitivity (higher threshold = fewer changes, default 1)
changes = ischange(y, "mean", Threshold=2);

% Works on tables/timetables with DataVariables and SamplePoints
changes = ischange(T, "mean", DataVariables="Value", SamplePoints="Time");

% OutputFormat="tabular": returns a table/timetable of logicals (keeps variable names)
changes = ischange(T, "mean", OutputFormat="tabular", DataVariables=["Temp","Pressure"]);
T(changes.Pressure, :)  % rows where Pressure has a mean shift

% Avoid: Manual change detection
changes = [false; abs(diff(y)) > threshold];
```

## Use `histcounts`/`histogram` not `histc`/`hist`

Use `histcounts` when you need bin counts as part of data analysis. Use `histogram` when the user wants a distribution plot — while this skill focuses on analysis rather than visualization, understanding distributions is a common analysis step.

```matlab
% For counts only (no plot)
[counts,edges] = histcounts(T.Value,20);

% For plotting
histogram(T.Value,20)

% Normalized
histogram(T.Value,Normalization="pdf")

% Categorical
histogram(T.Category)

% Return the handle to query or modify properties
h = histogram(T.Value);
h.NumBins = 30;                    % adjust bins after creation
h.Normalization = "probability";   % switch normalization
h.FaceColor = [0.2 0.4 0.8];       % customize appearance
counts = h.BinCounts;              % read computed bin counts
edges = h.BinEdges;                % read computed bin edges

% Avoid: Legacy histogram functions
[counts,centers] = hist(T.Value,20);
counts = histc(T.Value,edges);
```

For 2D smoothing (`smoothdata2`) and 2D peak detection (`islocalmax2`/`islocalmin2`) on grid data, see [array-and-grid-data.md](array-and-grid-data.md).

---

Copyright 2026 The MathWorks, Inc.
