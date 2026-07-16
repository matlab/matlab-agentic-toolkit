# Migrating parquetread to parquetDatastore

Parquet is self-describing: types are encoded in file metadata and preserved
exactly by both `parquetread` and `parquetDatastore`. No format specifiers or
type conversion workarounds are needed.

## Property Mapping

All `parquetread` Name-Value pairs map 1:1 to writable datastore properties:

| `parquetread` option | `parquetDatastore` property | Notes |
|---------------------|----------------------------|-------|
| `SelectedVariableNames` | `pds.SelectedVariableNames` | Writable after creation |
| `RowFilter` | `pds.RowFilter` | Writable after creation |
| `OutputType` | `pds.OutputType` | Writable after creation |
| `RowTimes` | `pds.RowTimes` | Writable after creation |
| `VariableNamingRule` | `pds.VariableNamingRule` | Writable after creation |
| `RowGroups` | **No direct equivalent** | Datastore iterates row groups sequentially via `ReadSize="rowgroup"` |

All properties are writable after creation — no creation-time-only restrictions.

## Basic Migration Pattern

```matlab
% Before (OOM on large files):
T = parquetread("measurements.parquet", ...
    SelectedVariableNames=["Timestamp","Value","Region"], ...
    RowFilter=(rowfilter("Value").Value > 100));
stats = groupsummary(T, "Region", "mean", "Value");

% After (works on any size):
pds = parquetDatastore("measurements.parquet");
tt = tall(pds);
tt = tt(tt.Value > 100, ["Timestamp","Value","Region"]);
stats = gather(groupsummary(tt, "Region", "mean", "Value"));
```

Tall transparently leverages both projection pushdown and predicate pushdown
when the user indexes columns or filters rows. No explicit `SelectedVariableNames`
or `RowFilter` on the datastore is needed — indexing directly on the tall array
achieves the same I/O optimization.

## RowGroups Parameter

`parquetread(..., RowGroups=N)` reads specific row groups by index.
`parquetDatastore` has no equivalent — it iterates row groups sequentially when
`ReadSize="rowgroup"` (the default). For workflows that need specific row group
access, keep using `parquetread` with `parquetinfo` to identify target row
groups, or iterate the datastore and filter by position.

----

Copyright 2026 The MathWorks, Inc.

----
