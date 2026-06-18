# Data Transformation

**Contents:** logical indexing, sortrows, topkrows, rowfun, varfun, convertvars, renamevars/movevars/addvars/removevars, splitvars/mergevars, discretize, normalize, clip/rescale, pivot/stack/unstack/rows2vars, join/innerjoin/outerjoin

## Use logical indexing for basic row filtering
```matlab
Thigh = T(T.Value > 100, :);
TBob = T(T.Name == "Bob", :);
Trecent = T(T.Date > datetime(2024,1,1), :);
```

**Exception**: Use `find` when you need the actual indices (e.g., for reporting positions).

## Use `sortrows` for sorting tables
```matlab
T = sortrows(T,"Date");                                       % ascending (default)
T = sortrows(T,"Value","descend");                            % descending
T = sortrows(T,["Group" "Value"],["ascend" "descend"]);       % multi-key sort
```

## Use `topkrows` for top/bottom N rows
```matlab
top5 = topkrows(T,5,"Sales");                                 % top 5 by Sales (descending)
bot5 = topkrows(T,5,"Sales","ascend");                        % bottom 5
top10 = topkrows(T,10,["Region" "Sales"],["ascend" "descend"]); % mixed sort
```

## Use vectorization or `rowfun` for row operations, not loops
```matlab
% For simple operations - vectorized arithmetic
T.Total = T.A + T.B + T.C;
T.BMI = T.Weight ./ (T.Height / 100).^2;

% For complicated row operations - rowfun
T.Result = rowfun(@(a,b,c) customCalc(a,b,c), T, ...
    InputVariables=["A" "B" "C"], OutputFormat="uniform");

% OutputFormat options: "auto" (default), "table", "timetable", "uniform", "cell"

% Avoid: Loop over rows with per-element table indexing
for i = 1:height(T)
    T.Total(i) = T.A(i) + T.B(i) + T.C(i);  % slow — indexing overhead each iteration
end
```

## Hoist non-vectorizable code into functions

When computation genuinely requires iteration (each row depends on the previous), extract the variables into arrays, perform the loop in a helper function, then assign the result back. This avoids repeated table indexing inside the loop:

```matlab
% Recommended: extract, compute, assign back
temp = simulateCooling(T.InitialTemp, T.AmbientTemp, T.Duration, k);
T.FinalTemp = temp;

function temp = simulateCooling(T0, Tambient, dt, k)
    temp = zeros(size(T0));
    temp(1) = T0(1);
    for i = 2:numel(T0)
        temp(i) = temp(i-1) + dt(i) * k * (Tambient(i) - temp(i-1));
    end
end

% Avoid: iterating with table dot-indexing in the loop body
for i = 2:height(T)
    T.FinalTemp(i) = T.FinalTemp(i-1) + T.Duration(i) * k * (T.AmbientTemp(i) - T.FinalTemp(i-1));
end
```

## Use `varfun` for variable-wise operations
```matlab
% Apply a function to each variable independently
T2 = varfun(@mean, T, InputVariables=vartype("numeric"));

% Apply a custom function to specific variables
T2 = varfun(@(x) x ./ max(x), T, InputVariables=["Score1" "Score2"]);
```

`varfun` applies a function to entire variables; `rowfun` applies a function across variables for each row. For grouped statistics, prefer `groupsummary` over `varfun` with `GroupingVariables`.

## Use `convertvars` for type conversion
```matlab
T = convertvars(T,"Status","categorical");            % string to categorical
T = convertvars(T,vartype("cellstr"),"string");       % all cellstr vars to string
T = convertvars(T,["X" "Y" "Z"],"double");            % convert specific vars
```

Check current types with `T.Properties.VariableTypes` - this is also writeable, so you can convert types directly:
```matlab
T.Properties.VariableTypes("Status") = "categorical";
```

## Use `renamevars`, `movevars`, `addvars`, `removevars` for variable management
```matlab
T = renamevars(T,"OldName","NewName");
T = renamevars(T,["A" "B"],["Alpha" "Beta"]);         % rename multiple
T = movevars(T,"Key", Before="Value");                % reorder variables
T = addvars(T, x, y, Before="Value", ...             % add with placement and naming
    NewVariableNames=["X" "Y"]);
T = removevars(T,["Temp1" "Temp2"]);                  % drop variables
```

Note: for a single variable at the end, dot indexing is simpler (`T.NewVar = x`). Use `addvars` when you need custom placement, multiple additions, or variable naming in one call.

## Use `splitvars` and `mergevars` for multicolumn variables
```matlab
% Split a multicolumn variable into separate variables
T = splitvars(T,"Coordinates", NewVariableNames=["X" "Y" "Z"]);

% Merge separate variables into one multicolumn variable
T = mergevars(T,["X" "Y" "Z"], NewVariableName="Coordinates");
```

## Use `discretize` not manual if-else
```matlab
edges = [0 18 35 50 Inf];
labels = ["Child" "Young Adult" "Adult" "Senior"];
T.AgeGroup = discretize(T.Age,edges,categorical(labels));

% Numeric bins
T.Bin = discretize(T.Value,10);  % 10 equal-width bins
T.Bin = discretize(T.Value,[0 10 50 100 500]);  % Custom edges

% Avoid: Manual binning
T.AgeGroup = strings(height(T),1);
for i = 1:height(T)
    if T.Age(i) < 18
        T.AgeGroup(i) = "Child";
    elseif T.Age(i) < 35
        T.AgeGroup(i) = "Young Adult";
    elseif T.Age(i) < 50
        T.AgeGroup(i) = "Adult";
    else
        T.AgeGroup(i) = "Senior";
    end
end
```

Note: if the binning is for a subsequent grouping step, `groupsummary`, `groupfilter`, `grouptransform`, and `pivot` all support binning on the fly via binning rules — no need to create a separate variable. See the grouping deep dive for examples.

## Use `normalize` not `zscore`
```matlab
xnorm = normalize(x);                % Default: z-score
xnorm = normalize(x,"range");        % Scale to [0, 1]
xnorm = normalize(x,"center");       % Subtract mean
xnorm = normalize(x,"scale");        % Divide by std
xnorm = normalize(x,"norm",Inf);     % Divide by max value (scales to [0,1] for positive data)

% Works on tables with DataVariables pattern
T = normalize(T, DataVariables=vartype("numeric"));       % all numeric variables
T = normalize(T,"zscore", DataVariables="Value");         % specific variable
```

## Use `clip` or `rescale` for clipping/bounding values
```matlab
x = clip(x,0,100);                % Clip to [0, 100] (R2024a+)
x = rescale(x,0,100);             % Scale to [0, 100]

% clip works on tables with DataVariables (R2024a+)
T = clip(T,0,100, DataVariables="Value");
```

## Reshape tables with `pivot`, `stack`, `unstack`, and `rows2vars`

Choose the right reshape operation based on what you need:

**`pivot` - cross-tabulate or aggregate into a wide format (R2023a+).**
Best for "I want one row per X and one column per Y":
```matlab
% Count of orders by category and region
P = pivot(T, Rows="Category", Columns="Region");

% Total sales by category and region
P = pivot(T, Rows="Category", Columns="Region", ...
    DataVariable="Sales", Method="sum");

% Multiple row groupings
P = pivot(T, Rows=["Year" "Category"], Columns="Region", ...
    DataVariable="Sales", Method="mean");
```

`pivot` supports several useful options:
```matlab
% Bin numeric or datetime variables on the fly (no need for discretize first)
P = pivot(T, Rows="Age", Columns="Region", ...
    DataVariable="Salary", Method="mean", ...
    RowsBinMethod=[0 18 35 50 Inf]);           % custom bin edges for Rows

P = pivot(TT, Rows="Time", Columns="Sensor", ...
    DataVariable="Reading", Method="mean", ...
    RowsBinMethod="hour");                     % time-unit binning

% Include row/column totals
P = pivot(T, Rows="Category", Columns="Region", ...
    DataVariable="Sales", Method="sum", IncludeTotals=true);

% Exclude missing and show empty categories
P = pivot(T, Rows="Category", Columns="Region", ...
    IncludeMissingGroups=false, IncludeEmptyGroups=true);

% Method options: "count", "sum", "mean", "median", "std", "var",
%   "min", "max", "range", "mode", "percentage", "nummissing",
%   "numunique", "nnz", "none", or a function handle
```

**`stack` - gather multiple variables into one (wide to tall).**
Use when separate variables represent the same measurement under different conditions:
```matlab
% Variables Q1, Q2, Q3, Q4 represent quarterly sales
Ttall = stack(T,["Q1" "Q2" "Q3" "Q4"], ...
    NewDataVariableName="Sales", IndexVariableName="Quarter");
```

**`unstack` - spread one variable into many (tall to wide).**
The inverse of `stack`:
```matlab
Twide = unstack(Ttall,"Sales","Quarter");
```

**`rows2vars` - transpose a table so rows become variables.**
Useful when data arrives with observations in columns instead of rows:
```matlab
Ttransposed = rows2vars(T);
```

## Use `ReplaceValues=false` to preserve originals during transformation

When transforming table/timetable variables with preprocessing functions, the default behavior overwrites the input variable. Set `ReplaceValues=false` to append the result as a new variable instead:

```matlab
T = normalize(T,"zscore", DataVariables="Score", ReplaceValues=false);
% T now has both "Score" (original) and "Score_normalized"

T = clip(T,0,100, DataVariables="Value", ReplaceValues=false);
% T now has both "Value" (original) and "Value_clipped"
```

Functions that support `ReplaceValues`: `fillmissing`, `filloutliers`, `smoothdata`, `normalize`, `standardizeMissing`, `detrend`, `clip`, `grouptransform`, and the `mov*` functions (`movmean`, `movmedian`, etc. — table/timetable support added in R2025a).

## Use `join`/`innerjoin`/`outerjoin` for joining tables, not loops
```matlab
T = innerjoin(T1,T2, Keys="Key");                            % only matching rows
T = outerjoin(T1,T2, Keys="Key", MergeKeys=true);            % all rows, fill missing
T = join(T1,T2);                                             % assumes matching key names
```

---

Copyright 2026 The MathWorks, Inc.
