# databaseImportOptions & rowfilter — Column Selection, Filtering, Deduplication

## Creating Import Options

```matlab
% From a table name
opts = databaseImportOptions(conn, "myTable");

% From a SQL query
opts = databaseImportOptions(conn, "SELECT * FROM myTable WHERE id > 100");
```

## SQLImportOptions Properties

| Property | Description | Default |
|----------|-------------|---------|
| `SelectedVariableNames` | Subset of columns to import | All columns |
| `ExcludeDuplicates` | `true`/`false` — adds DISTINCT on database side | `false` |
| `RowFilter` | `matlab.io.RowFilter` object for row filtering | Unfiltered |
| `VariableNames` | All column names (read-only from metadata) | — |
| `VariableTypes` | MATLAB data types per column | Auto-detected |
| `FillValues` | Values for missing data | Type defaults |

**Accepted by:** `sqlread`, `fetch`, `DatabaseDatastore` — **NOT** by `sqlinnerjoin`/`sqlouterjoin`.

## Column Selection

```matlab
opts = databaseImportOptions(conn, "orders");
opts.SelectedVariableNames = ["OrderKey", "OrderStatus", "TotalPrice"];
T = sqlread(conn, "orders", opts);
% Only 3 columns transferred from database
```

## Deduplication

```matlab
opts = databaseImportOptions(conn, "productTable");
opts.SelectedVariableNames = "ProductType";
opts.ExcludeDuplicates = true;
T = sqlread(conn, "productTable", opts);
% Equivalent to: SELECT DISTINCT ProductType FROM productTable
```

## Row Filtering with `rowfilter`

```matlab
% Create a standalone RowFilter
rf = rowfilter(["Region", "Revenue"]);
filter = rf.Region == "West" & rf.Revenue > 10000;

% Use as name-value arg (simple cases)
T = sqlread(conn, "sales", RowFilter=filter);

% Use via opts (when combining with column selection or deduplication)
opts = databaseImportOptions(conn, "sales");
opts.SelectedVariableNames = ["Region", "Revenue", "Product"];
opts.RowFilter = opts.RowFilter.Region == "West" & opts.RowFilter.Revenue > 10000;
T = sqlread(conn, "sales", opts);
```

### Supported RowFilter Operators

| Operator | Example |
|----------|---------|
| `==`, `~=` | `rf.Status == "Active"` |
| `>`, `>=`, `<`, `<=` | `rf.Price > 100` |
| `&` (AND) | `rf.Price > 10 & rf.Price < 100` |
| `\|` (OR) | `rf.Status == "A" \| rf.Status == "B"` |
| `isnan`, `ismissing` | `isnan(rf.Value)` |
| `contains`, `matches` | `contains(rf.Name, "widget")` |

## Overriding Variable Types

```matlab
opts = databaseImportOptions(conn, "employees");
opts = setoptions(opts, "EmployeeID", Type="int32");
opts = setoptions(opts, "HireDate", Type="datetime");
T = sqlread(conn, "employees", opts);
```

## Combined Pattern: Filter + Select + Deduplicate

```matlab
opts = databaseImportOptions(conn, "orders");
opts.SelectedVariableNames = ["OrderKey", "OrderStatus"];
opts.RowFilter = opts.RowFilter.OrderPriority == "URGENT";
opts.ExcludeDuplicates = true;
T = sqlread(conn, "orders", opts);
```

## Gotchas

- `ExcludeDuplicates` applies to the combination of ALL selected variables. Narrow columns with `SelectedVariableNames` first.
- Do NOT pass `opts` to `sqlinnerjoin`/`sqlouterjoin` — they don't accept it.
- Do NOT mix `opts` and a separate `RowFilter` NV arg in the same `sqlread`/`fetch` call.
- `databaseImportOptions` executes a metadata query — if the SQL has syntax errors, it fails at this step.

----

Copyright 2026 The MathWorks, Inc.

----
