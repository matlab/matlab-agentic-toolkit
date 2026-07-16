# Answering Questions About Data

Strategies for answering data analysis questions about tabular data accurately.

## 1. Idiomatic MATLAB for Tables

Prefer these functions for tabular data workflows:

- `groupsummary` for grouped statistics (not `accumarray`). When using `groupsummary` with tabular input, the output table always includes a `GroupCount` variable, so there is no need to specify a separate count method. If you only need counts, use `groupcounts` instead.
- Do not use `"numel"` or `"counts"` as `groupsummary` method names - these are not valid and will error. Valid methods: `"sum"`, `"mean"`, `"median"`, `"mode"`, `"var"`, `"std"`, `"min"`, `"max"`, `"range"`, `"nummissing"`, `"numunique"`, `"nnz"`, `"all"`. Named methods automatically ignore missing values.
- `sortrows` for sorting tables by one or more variables.
- `pivot` for reshaping when available.
- `convertvars` and `vartype` for working with variable types.
- Dot notation (`T.VarName`) to access variables rather than indexing by number.

## 2. Handle Missing Data

Be thoughtful about missing data rather than blindly removing it.

- **Be cautious with `rmmissing` on an entire table** — it drops any row with a missing value in *any* variable, which can discard valid data unnecessarily. Prefer handling missingness per-variable. Use `rmmissing` when you genuinely need complete cases across all variables.
- For sorting, use the `MissingPlacement` argument of `sort` or `sortrows` (options: `"auto"`, `"first"`, `"last"`) to control where missing values appear rather than removing them.
- Use `ismissing` to check for missing values.
- **Look for sentinel values** that represent missing data but are not yet marked as such - for example, `"N/A"`, `"n/a"`, `"NA"`, `"None"`, `""`, `"-"`, or sentinel numbers like `-999` or `0` in variables where zero is not meaningful. Use `standardizeMissing` to convert these to proper MATLAB missing indicators (`<missing>`, `NaN`, `NaT`, `<undefined>`) so that data analysis functions handle them correctly.
- When using `groupcounts` or `groupsummary`, consider setting `IncludeMissingGroups=false` to exclude groups defined by a missing value (such as `NaN` for numeric types), which can otherwise dominate results. The default is `true`.

## 3. Sorting and Selecting Top/Bottom N

When asked for the "top N", "highest N", "lowest N", or "largest N" values of a variable:

- For quick retrieval of the top N rows by a column, use `topkrows`:
  ```matlab
  top5 = topkrows(T,5,"Sales");               % top 5 by Sales descending
  bot5 = topkrows(T,5,"Sales","ascend");      % bottom 5 by Sales ascending
  ```
  `topkrows` is cleaner and avoids a full sort, so it can also be faster on large tables.
- Missing values (NaN, NaT) are automatically placed last by `topkrows`. Use `sortrows` with `MissingPlacement="last"` only when you need the full sorted table for subsequent operations.
- Return exactly N values from the sorted result.
- Consider whether the question is asking for N distinct/unique values or the N largest individual entries (which may include duplicates).
- **Think carefully about sort direction** - some columns have inverse semantics. For example, "highest rank" or "top rank" typically means the lowest numeric value (rank #1 is the top), while "highest salary" means the largest numeric value. Consider the meaning of the column before choosing `"ascend"` or `"descend"`.
- When asked for a value from a **different column** for the top/bottom N rows (e.g., "ages of the top 4 by pregnancies"), sort the entire table by the ranking column using `sortrows`, then read the requested column from the first N rows.

## 4. Return Data Values as Stored

Always return the actual values from the dataset, not interpretations or mappings.

- If a variable stores numeric codes (e.g., `VendorID=2`, `PaymentType=1`), return those codes.
- If a question references a variable by a recognizable name (e.g., "complaint key", "complaint number", "unique key"), look for a matching variable and return its literal values.
- Do not substitute category names, labels, or descriptions unless explicitly asked.

## 5. Filtering and Matching

When filtering data, consider whether exact matching (`==`, `matches`) or partial matching (`contains`, `startsWith`) is more appropriate for the use case.

- For row counting after filtering, use `height(filteredTable)` or `nnz(logicalIndex)`.
- Verify the magnitude of results against the known table size.

## 6. Answer Format

Respond concisely. Give the answer directly without unnecessary elaboration.

---

Copyright 2026 The MathWorks, Inc.
