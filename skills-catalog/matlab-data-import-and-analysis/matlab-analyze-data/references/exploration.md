# Data Exploration

**Contents:** first look (head/summary/size), missing data assessment, variable distributions, relationships (corrcoef/pivot), uniqueness/cardinality, duplicates, outlier screening, time-based exploration

Strategies for systematic data exploration: understanding structure, identifying patterns, summarizing distributions, and forming hypotheses before deeper analysis.

## General Guidance

- **Explore before transforming.** Understand the data before cleaning or reshaping it. Premature cleaning can mask important signals (e.g., removing "outliers" that are actually a meaningful subgroup).
- **Check your assumptions.** If a variable is called "Age", verify it contains plausible age values. Sentinel values (-1, 999, 0) are common.
- **Start broad, then narrow.** Use `summary` and `groupcounts` to get the big picture before drilling into specific rows or subsets.
- **Document what you find.** If exploring interactively, note surprises: unexpected missing patterns, outliers, duplicate keys, or variables that don't contain what their name suggests.
- **Add value where AI helps most.** Text-heavy tasks like populating `VariableDescriptions`, `VariableUnits`, or renaming variables to be more descriptive are a natural fit for AI assistance. Offer to enrich table metadata when it is sparse or missing.

## 1. First Look

Start with structure and shape before any analysis:

```matlab
head(T)                         % first 8 rows - see what the data looks like
summary(T)                      % per-variable: type, stats, missing counts
size(T)                         % [nRows, nVars]
T.Properties.VariableNames      % variable names
T.Properties.VariableTypes      % programmatic access to types
```

`summary` is the single most informative exploration command: it shows the data type of every variable, descriptive statistics (min, median, max for numeric; counts for categorical), and missing value counts. For wide tables it is more useful than `head` since it shows every variable without truncation. From R2024b, use `Statistics`, `DataVariables`, and `Detail` name-value arguments to customize:
```matlab
summary(T, Statistics=["mean" "std" "min" "max"], DataVariables=vartype("numeric"))  % R2024b+
summary(T, Statistics="allstats")    % everything available; silently skips stats that don't apply to a given type
summary(T, Detail="high")            % show all metadata (descriptions, units, category counts)
```

Note: `Detail="high"` only affects the printed display. When capturing output (`s = summary(T)`), the returned struct always includes all metadata regardless of `Detail`.

## 2. Missing Data Assessment

Understand the extent of missingness before deciding how to handle it:

```matlab
anymissing(T)                               % quick check: any missing values at all?
allfinite(T)                                % quick check: all values finite? (catches NaN and Inf)
sum(ismissing(T))                           % missing count per variable
sum(ismissing(T)) ./ height(T) * 100        % missing percentage per variable
T.Properties.VariableNames(sum(ismissing(T)) > 0)  % which variables have any missing
```

Look for patterns: is missingness concentrated in a few variables, or scattered? Are rows with missing values in one variable also missing in others? This informs whether to fill, drop, or ignore.

```matlab
% Variables with >50% missing — candidates for dropping
pctMissing = sum(ismissing(T)) ./ height(T) * 100;
T.Properties.VariableNames(pctMissing > 50)
```

## 3. Variable Distributions

Summarize differently depending on type:

**Numeric variables:**
```matlab
% Or per-variable
[min(T.Age) median(T.Age) max(T.Age) std(T.Age)]
prctile(T.Price,[25 50 75])         % quartiles
```

**Categorical/string variables:**
```matlab
groupcounts(T,"Status")                     % value counts with percentages
numunique(T.City)                           % number of distinct values (R2025a+)
countcats(T.Category)                       % counts for each defined category
categories(T.Category)                      % list defined category names
```

## 4. Relationships Between Variables

These are examples of common techniques, not an exhaustive list. Choose what is appropriate for the data and question — consider other approaches beyond these based on the dataset's characteristics:

```matlab
% Correlation matrix for numeric variables (corrcoef is core MATLAB; corr requires Statistics Toolbox)
% Use Rows="complete" to drop rows with any NaN (default propagates NaN)
R = corrcoef(T{:,vartype("numeric")}, Rows="complete");

% Cross-tabulation of two categorical variables
pivot(T, Rows="Department", Columns="Status", Method="count")

% Group means - does a numeric variable differ across groups?
groupsummary(T,"Region","mean","Revenue")
```

## 5. Uniqueness and Cardinality

Understanding cardinality helps decide how to use a variable (group by it? filter on it? ignore it?):

```matlab
% Unique value counts for all variables at once
summary(T, Statistics="numunique")

% Check if a variable could serve as an ID (all unique, no missing)
allunique(T.ID) && ~anymissing(T.ID)       % allunique: R2025a+
```

## 6. Duplicates

```matlab
% Find duplicate rows (all variables)
[~,idx] = unique(T,"rows","stable");
dupIdx = setdiff(1:height(T),idx);
T(dupIdx, :)                                % inspect duplicate rows

% Duplicates in a key variable
[~,ia] = unique(T.CustomerID,"stable");
dupKeys = T.CustomerID(setdiff(1:height(T),ia));
T(ismember(T.CustomerID,dupKeys), :)        % all rows with duplicated keys
```

## 7. Outlier Screening

Use `isoutlier` for quick detection:

```matlab
isoutlier(T.Price)                          % default: median + 3 scaled MAD
isoutlier(T.Price,"quartiles")              % IQR-based (1.5x IQR beyond Q1/Q3)
isoutlier(T.Price,"grubbs")                % Grubbs' test (assumes normality)
isoutlier(T.Price,"movmedian",20)          % sliding window (good for time series with drift)

% Per-group outlier detection (via groupfilter)
T = groupfilter(T,"Department",@(x) ~isoutlier(x),"Salary");
```

See [data-cleaning.md](data-cleaning.md) for handling outliers after detection.

## 8. Time-Based Exploration

For timetables or tables with datetime variables:

```matlab
[min(TT.Time) max(TT.Time)]                % date range
TT.Time(end) - TT.Time(1)                  % total span

% Check regularity and get step size
[tf,step] = isregular(TT);                 % timetables, datetime, and duration arrays
[tf,step] = isuniform(x);                  % numeric arrays

issorted(TT.Time,"strictascend")            % check for monotonically increasing timestamps

% Quick resample to see trends
daily = retime(TT,"daily","mean");
monthly = retime(TT,"monthly","mean");
```

---

Copyright 2026 The MathWorks, Inc.
