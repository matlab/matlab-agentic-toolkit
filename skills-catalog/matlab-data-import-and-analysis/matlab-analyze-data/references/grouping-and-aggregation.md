
# Grouping and Aggregation

**Contents:** groupsummary (methods, binning), groupcounts, groupfilter, grouptransform, pivot

## Use `groupsummary` for grouping operations, not loops or `accumarray`
```matlab
G = groupsummary(T,"Category",["min" "mean" "max"],"Value");

% Multiple grouping variables
G = groupsummary(T,["Category" "Region"],"mean","Value");

% Multiple data variables
G = groupsummary(T,"Category","mean",["Sales" "Cost" "Margin"]);

% Custom aggregation with a function handle
G = groupsummary(T,"Category",@(x) quantile(x,[0.25 0.75]),"Value");

% Avoid: Loop over groups
groups = unique(T.Category);
result = table();
for i = 1:numel(groups)
    subset = T(T.Category == groups(i), :);
    result(i,:) = table(groups(i),mean(subset.Value),std(subset.Value));
end

% Avoid: accumarray (cumbersome, does not support tables)
[G,groupNames] = findgroups(T.Category);
means = accumarray(G,T.Value,[],@mean);
```

When using `groupsummary` with tabular input, the output table always includes a `GroupCount` variable, so there is no need to specify a separate count method. If you only need counts, use `groupcounts` instead.

**Note:** Do not use `"numel"` or `"counts"` as `groupsummary` method names - these are not valid and will error. Valid built-in method names: `"sum"`, `"mean"`, `"median"`, `"mode"`, `"var"`, `"std"`, `"min"`, `"max"`, `"range"`, `"nummissing"`, `"numunique"`, `"nnz"`, `"all"`.

**Prefer string method names over function handles** (e.g., `"mean"` not `@mean`). Named methods use accelerated code paths and are significantly faster on large datasets.

### Methods apply to ALL DataVariables (cartesian product)

When you specify multiple methods and multiple data variables, `groupsummary` applies **every** method to **every** variable. It does NOT map methods 1:1 to variables:
```matlab
% This applies BOTH sum and mean to BOTH Loss and Customers (4 output columns):
G = groupsummary(T,"Region",["sum" "mean"],["Loss" "Customers"]);
% → Region, GroupCount, sum_Loss, mean_Loss, sum_Customers, mean_Customers
```

**For different methods on different variables, use separate calls:**
```matlab
% Want sum of Loss and mean of Customers? Two calls + join:
G1 = groupsummary(T,"Region","sum","Loss");
G2 = groupsummary(T,"Region","mean","Customers");
G = innerjoin(G1(:,["Region","GroupCount","sum_Loss"]), G2(:,["Region","mean_Customers"]), Keys="Region");
```

**DataVariables: string array vs cell array have different behavior:**
```matlab
% String array — each variable processed independently:
G = groupsummary(T,"Region","mean",["Loss" "Customers"]);

% Cell array — variables are passed together as multiple inputs to a
% bivariate function handle (e.g., weighted mean of Loss weighted by Customers):
G = groupsummary(T,"Region",@(loss,cust) sum(loss.*cust,"omitnan")/sum(cust,"omitnan"), {"Loss","Customers"});
```

**Pitfall:** Do not use `findgroups`+`accumarray` for aggregation when `groupsummary` can do the job — `groupsummary` is simpler, faster, and works directly with tables. Use `findgroups` alone only when you need group indices without aggregation (e.g., to assign a group ID column).

### On-the-fly binning

`groupsummary` (and `groupcounts`, `groupfilter`, `grouptransform`) support binning rules as the grouping variable, so you don't need to create a binned column with `discretize` first:
```matlab
% Bin a numeric variable with custom edges
G = groupsummary(T,"Age",[0 18 35 50 Inf],"mean","Income");

% Equal-width bins
G = groupsummary(T,"Score",10,"mean","Value");   % 10 bins

% Time-based binning — sequential (one bin per calendar period)
G = groupsummary(TT,"Time","month","mean","Temperature");      % Jan 2023, Feb 2023, ...

% Time-based binning — cyclic (collapses across the higher unit to find patterns)
G = groupsummary(TT,"Time","hourofday","mean","Temperature");  % 0-23
G = groupsummary(TT,"Time","dayname","mean","Sales");          % "Monday", "Tuesday", ...

% Mix regular grouping and binning
G = groupsummary(T,{"Region","Age"},{"none",[0 18 35 50 Inf]},"mean","Salary");
```

## Use `groupsummary` not `grpstats`
```matlab
G = groupsummary(T,"Category",["min" "mean" "max"],"Value");
G = groupsummary(T,"Category",@(x) [min(x,[],"omitnan") mean(x,"omitnan") max(x,[],"omitnan")],"Value");

% Less portable: Statistics Toolbox required
[means,groups] = grpstats(T.Value,T.Category,"mean");
```

## Use `groupcounts` not manual tabulation
```matlab
G = groupcounts(T,"Category");

% Avoid: Manual counting
categories = unique(T.Category);
counts = zeros(numel(categories),1);
for i = 1:numel(categories)
    counts(i) = sum(T.Category == categories(i));
end

% Less portable: Statistics Toolbox required, does not support tables
counts = tabulate(T.Category);
```

When using `groupcounts` or `groupsummary`, consider:
- `IncludeMissingGroups=false` to exclude groups defined by a missing value (such as `NaN` for numeric types), which can otherwise dominate results (default: `true`).
- `IncludeEmptyGroups=true` to include all categories of a categorical variable, even those with no rows (default: `false`). Useful when you need a complete picture of all possible groups.

## Use `groupfilter` to filter rows based on group properties

`groupfilter` has two distinct use cases:

**Use case 1: Keep or remove entire groups based on a group-level condition.**
For example, keep only categories that have enough observations to be meaningful:
```matlab
% Keep only groups with at least 10 observations
T = groupfilter(T,"Category",@(x) numel(x) >= 10);

% Keep only groups where the mean value exceeds a threshold
T = groupfilter(T,"Region",@(x) mean(x) > 50,"Sales");
```

**Use case 2: Filter individual rows within each group.**
For example, remove outliers separately within each group rather than globally:
```matlab
% Remove per-group outliers (2 std from mean within each group)
T = groupfilter(T,"Category",@(x) ~isoutlier(x,"mean",ThresholdFactor=2),"Value");

% Keep only the top 3 rows per group by Value
T = groupfilter(T,"Category",@topN,"Value");

function tf = topN(x)
    [~,idx] = maxk(x,3,ComparisonMethod="abs");
    tf = false(size(x));
    tf(idx) = true;
end
```

The key distinction: when the function returns one logical per group, it filters entire groups. When it returns one logical per row, it filters individual rows within each group.

## Use `grouptransform` to transform data within each group

`grouptransform` applies a transformation within each group and returns a same-size table — assign the result back to the table variable (`T = grouptransform(T,...)`), not to a single column.

**Valid built-in methods (exhaustive list):** `"zscore"`, `"norm"`, `"meancenter"`, `"rescale"`, `"meanfill"`, `"linearfill"`. Aggregation methods like `"sum"`, `"mean"`, `"std"` are NOT valid for `grouptransform` — use `groupsummary` for aggregation.

```matlab
% Normalize values within each group (per-group z-score), overwriting original column
T = grouptransform(T,"Category","zscore","Value");

% Add result as a NEW column (keep original intact) with ReplaceValues=false
T = grouptransform(T,"Category","zscore","Value",ReplaceValues=false);
% This appends a column named "zscore_Value" to T (named method → "<method>_<Var>")
% With a function handle, the new column is named "fun_<Var>" (e.g., "fun_Value")

% Custom function handle for operations not in the built-in list:
T = grouptransform(T,"Category",@(x) x / sum(x) * 100,"Value");
```

**`ReplaceValues` (default: `true`):** By default, `grouptransform` replaces the input column with the transformed result. Set `ReplaceValues=false` when you want to keep the original data and add the transformation as a new column — common for z-scores, percentiles, or group-relative metrics where both raw and normalized values are needed.

## Use `pivot` not `unstack` workarounds
```matlab
% Direct pivot (introduced in R2023a)
% Default (no DataVariable/Method) returns counts per group for non-numeric
% data variables and sum for numeric
P = pivot(T, Rows="Category", Columns="Region");

% Aggregate a specific variable with DataVariable and Method
P = pivot(T, Rows="Category", Columns="Region", DataVariable="Sales", Method="sum");

% Avoid: Manual pivot
G = groupsummary(T,["Row" "Col"],"sum","Value");
P = unstack(G,"sum_Value","Col");
```

---

Copyright 2026 The MathWorks, Inc.
