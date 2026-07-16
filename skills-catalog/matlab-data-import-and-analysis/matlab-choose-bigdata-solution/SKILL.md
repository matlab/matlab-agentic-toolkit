---
name: matlab-choose-bigdata-solution
description: >
  Guide users or agents to the correct MATLAB tool for processing large tabular
  data in file-based formats (CSV, Parquet, delimited text, spreadsheets, MDF)
  that may not fit in memory. Use when a user or agent mentions large files, big
  data, out-of-memory errors, OOM, scaling up, tall arrays, datastores, or needs
  to process multiple tabular files. Covers the decision between datastore +
  tall, datastore + transform, and parallel execution. Also use when a user or
  agent has working in-memory code (readtable, parquetread) that runs out of
  memory and needs a migration path. Do NOT use for MAT, XML, JSON, HTML files
  or Word documents.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Choose Big Data Solution

Help users and agents select the right MATLAB tool for large **tabular data in
file-based formats** (CSV, Parquet, delimited text, spreadsheets, MDF). The
skill encodes a decision flowchart — recommend one clear path, not a menu of
options.

## When to Use

- User or agent has large tabular data in file-based formats (CSV, Parquet, delimited text, spreadsheets, MDF)
- User or agent says data is "large", "big", or "huge" (even without a specific size)
- User or agent hits an out-of-memory error with `readtable`, `parquetread`, or similar
- User or agent has multiple tabular files to process as a single dataset
- User or agent has multiple tabular files to process independently (per-file)
- User or agent asks how to scale up an existing workflow on tabular file data
- User or agent asks about datastores, tall arrays, or mapreduce

## When NOT to Use

- Single file that fits in memory (file-size-to-RAM ratio < 0.5) — see Pre-Flight Check
- User or agent is working with MAT files — `matfile` provides partial I/O for large `.mat` files, different workflow
- User or agent is working with databases (SQL, ODBC) — use Database Toolbox. See the `matlab-read-database` and `matlab-use-duckdb` skills in the `reporting-and-database-access` category
- User or agent needs GPU acceleration — different domain
- User or agent is building a custom datastore class — see `doc matlab.io.Datastore`
- User or agent has large XML, JSON, HTML, or Word document files — `readtable` supports these formats but the datastores covered by this skill do not. Scaling these requires a custom datastore (see "Unsupported Formats" section below)
- Deep learning training workflows — datastore is correct for data loading, but use `minibatchqueue` for batching (not tall or transform)

## Pre-Flight Check

**ALWAYS run this check BEFORE recommending datastore or tall array patterns.**
Estimate the file-size-to-available-RAM ratio (accounting for in-memory
expansion of the file format).

| Condition | Route | Rationale |
|-----------|-------|-----------|
| Single file, ratio < 0.5 | Native MATLAB I/O (`readtable`, `parquetread`) | Fits in memory; datastore/tall adds unnecessary complexity |
| Single file, ratio ≥ 0.5, OR user/agent reports OOM | Continue to Decision Flowchart below | Data may not fit in memory |
| Multiple files | Continue to Decision Flowchart below | Datastore patterns provide unified multi-file access |
| Size unknown and user/agent describes data as "large", "big", or "huge" | Continue to Decision Flowchart below | Assume large until proven otherwise |

**If the data fits in memory (single file, ratio < 0.5):** recommend native
I/O and stop. Mention that datastore and tall array patterns exist if the
data grows beyond memory in the future, but do not implement them now.

## Decision Flowchart

Follow this flowchart strictly. Present ONE recommended path, not multiple
alternatives. Only mention alternatives if the situation is ambiguous.

```
Is the data described as "large" or causing OOM?
│
├── YES
│   │
│   ├── Is the goal to process all data as ONE continuous dataset?
│   │   │
│   │   └── YES → Datastore + Tall Arrays
│   │             Choose datastore by format:
│   │               CSV/delimited text → tabularTextDatastore
│   │               Parquet            → parquetDatastore
│   │               Excel (.xlsx/.xls) → spreadsheetDatastore
│   │               MDF (.mf4/.mdf)    → mdfDatastore (requires Vehicle Network Toolbox)
│   │
│   └── Is the goal to process each unit INDEPENDENTLY?
│       │
│       ├── One read = one FILE
│       │     CSV/delimited text → tabularTextDatastore
│       │     Excel (.xlsx/.xls) → spreadsheetDatastore
│       │
│       └── One read = one ROW GROUP
│             Parquet → parquetDatastore
│
└── NO / UNCLEAR
    └── STOP. Ask: (1) what is the file format? (2) do you need to process
        all data as one dataset, or each file/unit independently?
        Do NOT show code until these are answered.

Optional (requires Parallel Computing Toolbox):
├── Speed up tall arrays locally → Open a parallel pool
├── Speed up readall on transforms → UseParallel
└── Speed up tall arrays on Hadoop/Spark → mapreducer (also requires MATLAB Parallel Server)
```

**Critical rules:**
- **When the processing goal is unclear (continuous vs per-file), STOP and ask
  before writing any code.** Do not show code examples, do not generate scripts,
  do not demonstrate both approaches. Ask which applies and wait for the answer.
  The correct response to ambiguity is a short clarifying question, not a menu
  of options with code for each.
- When data is described as "large", NEVER lead with `readtable` or `parquetread`
- For per-file or per-row-group processing, NEVER suggest tall arrays (tall merges all data into one dataset and has no concept of file or row group boundaries)
- For Parquet, the natural independent unit is the **row group**, not the file — `parquetDatastore` defaults to `ReadSize = "rowgroup"`. Do NOT force `ReadSize = "file"` on a Parquet datastore unless the workflow truly needs whole-file granularity
- For parallelism, recommend parallel pool FIRST; mapreducer is only for Hadoop/Spark
- Do NOT present manual chunking (while/read loops) as the first option — tall arrays handle chunking automatically
- Do NOT present multiple options — follow the flowchart and recommend ONE clear path

## Datastore + Tall Arrays (continuous dataset)

Use when: processing one large file OR multiple files as a single dataset.
Use the datastore matching the format (see Decision Flowchart above).

```matlab
% Single file
ds = tabularTextDatastore("largedata.csv");
tt = tall(ds);

% Multiple files
ds = tabularTextDatastore("data/*.csv");
tt = tall(ds);

% For example, compute statistics with the tall array and gather results.
% Tall handles chunking automatically
result = groupsummary(tt, "GroupVar", {"mean", "std", "min", "max"});
result = gather(result);
```

**Key points:**
- Most common functions work on tall: `mean`, `std`, `min`, `max`, `groupsummary`, `sortrows`, `topkrows`
- Combine multiple gathers: `[a, b] = gather(tallA, tallB)`

**DuckDB alternative (R2026a+):** When the goal is to filter, aggregate,
deduplicate, or sample a large file down to a small in-memory result, a
single DuckDB query may be faster than datastore + tall for these
operations. DuckDB queries CSV/Parquet/JSON files directly without loading
them. Requires Database Toolbox. See the `matlab-use-duckdb` skill in the
`reporting-and-database-access` category.

**Migrating from readtable (OOM on large files):**

```matlab
% Before:
T = readtable("large.csv");
stats = groupsummary(T, "Category", "mean");

% After:
ds = tabularTextDatastore("large.csv");
tt = tall(ds);
stats = gather(groupsummary(tt, "Category", "mean"));
```

`tabularTextDatastore` uses a stricter textscan-based parser. Key gotchas:
- `TextType` must be set at **creation time** — read-only after construction
- `TrimNonNumeric` unsupported — read as `%q`, strip on the tall array
- `%f` errors on non-numeric content — read as `%q`, convert with `str2double`
- `ExtraColumnsRule` does not exist — append `"%*[^\r\n]"` to `TextscanFormats`
- `detectImportOptions` does not apply — configure via datastore properties directly

See `references/readtable-to-datastore-migration.md` for the full property mapping.

**Migrating from parquetread:** Replace with `parquetDatastore` + `tall`. Types
are preserved exactly — no format specifier issues. All `parquetread` options
map 1:1 to datastore properties. See `references/parquetread-to-datastore-migration.md`.

## Datastore + Transform (per-file)

Use when: each file in a folder should be processed independently (per-file
statistics, per-file transformations, file-level aggregation).

```matlab
% Set up datastore to read one file at a time
ds = tabularTextDatastore("data/*.csv");
ds.ReadSize = "file";

% For example, compute statistics by transforming the datastore with a custom function.
tds = transform(ds, @computeFileStats);
results = readall(tds);

function out = computeFileStats(data)
    numVars = vartype("numeric");
    out = table( ...
        min(data{:, numVars}, [], 1, "omitmissing"), ...
        max(data{:, numVars}, [], 1, "omitmissing"), ...
        mean(data{:, numVars}, 1, "omitmissing"), ...
        VariableNames=["Min", "Max", "Mean"]);
end
```

For Excel files, use `spreadsheetDatastore` instead of `tabularTextDatastore`.
`spreadsheetDatastore` defaults to `ReadSize = "file"` so no override is needed.
For per-sheet processing (e.g., statistics per worksheet), set `ReadSize = "sheet"`
so each `read` returns exactly one sheet's data.

**Key points:**
- For `tabularTextDatastore`, set `ReadSize = "file"` so each `read` returns
  exactly one file's data. The default `ReadSize` is a row count, which can
  split a single file across multiple reads but it will not go across file
  boundaries
- `transform` applies a function to each read — the datastore output contains only the
  transformed results, not the original data. The transform function does not
  need to return the same number of rows as its input (e.g., computing the mean
  of each variable produces a single row per read)
- `readall` on the transformed datastore collects all per-file results

**Do NOT use tall arrays for per-file processing.** Tall arrays treat all files
as one continuous dataset — they have no concept of file boundaries.

## Datastore + Transform (per-row-group, Parquet)

Use when: a Parquet dataset is partitioned by row group (e.g., one row group
per item, sensor, region, or time bucket) and each row group must be processed
independently. Row groups are the natural unit of independence in Parquet —
data from different row groups should not be mixed when the partitioning
encodes a meaningful grouping.

```matlab
% parquetDatastore defaults ReadSize to "rowgroup" — one read = one row group.
% Do NOT set ReadSize = "file": that would mix row groups within the same file.
pds = parquetDatastore("data/");

% For example, compute statistics by transforming the datastore with a custom function.
tds = transform(pds, @computeRowGroupStats);
results = readall(tds);

function out = computeRowGroupStats(data)
    out = table( ...
        unique(data.item), ...
        mean(data.val, "omitmissing"), ...
        std(data.val, "omitmissing"), ...
        VariableNames=["Item", "Mean", "Std"]);
end
```

**Key points:**
- `parquetDatastore` defaults to `ReadSize = "rowgroup"`. Each `read` returns
  exactly one row group — leave the default
- A row group is the smallest independently readable unit inside a Parquet file.
  Writers commonly assign one row group per partition key (item, sensor, day),
  so per-row-group processing preserves those boundaries

**Do NOT set `ReadSize = "file"` on a Parquet datastore for this workflow** —
it merges all row groups in a file into a single read and silently mixes data
that was meant to stay separate. Use file-level granularity only when each file
already contains exactly one logical group.

## Parallelizing readall (transform workflows)

The `readall` call in both per-file and per-row-group transform workflows
supports parallel execution when Parallel Computing Toolbox is installed and
licensed. Suggest this only when the toolbox is available:

```matlab
results = readall(tds, UseParallel=true);
```

- `UseParallel=true` parallelizes reads across workers in an open parallel
  pool. If no pool is open, MATLAB opens one automatically
- Only suggest `UseParallel` if Parallel Computing Toolbox is available

## Parallel Pool (local parallelism for tall arrays)

Use when: the goal is to speed up a tall array workflow with local cores.
Only recommend if Parallel Computing Toolbox is installed and licensed.

```matlab
% Start a thread or process pool
parpool("Threads");
% parpool("Processes");

ds = tabularTextDatastore("data/*.csv");
tt = tall(ds);
result = gather(mean(tt, "omitmissing"));
```

Tall array computations automatically distribute across available workers when
a parallel pool is open. No code changes needed beyond opening the pool.

Do NOT suggest `parpool` or parallel pool workflows unless Parallel Computing
Toolbox is available — `parpool` errors without it.

## Mapreducer (Hadoop/Spark only)

Use ONLY when the user or agent explicitly has a Hadoop or Spark environment.
Requires both Parallel Computing Toolbox and MATLAB Parallel Server.

```matlab
mr = mapreducer(cluster);
ds = tabularTextDatastore("hdfs:///data/*.csv");
tt = tall(ds);
result = gather(mean(tt, "omitmissing"));
```

**Do NOT recommend mapreducer for local parallel processing** — a parallel pool
is simpler and sufficient for local multi-core execution.

Do NOT suggest `mapreducer` for Hadoop/Spark execution unless the user or agent
has Parallel Computing Toolbox and a Hadoop or Spark environment with MATLAB
Parallel Server installed and licensed.

## Key Functions

| Function | Purpose | When to Use |
|----------|---------|-------------|
| `tabularTextDatastore` | Chunked access to CSV/text files | Large CSV/text files |
| `parquetDatastore` | Chunked access to Parquet files | Large Parquet files |
| `spreadsheetDatastore` | Chunked access to Excel files | Large .xlsx/.xls files |
| `mdfDatastore` | Chunked access to MDF files | Large .mf4/.mdf files (requires Vehicle Network Toolbox) |
| `tall` | Lazy evaluation over a datastore | Continuous dataset processing |
| `gather` | Execute deferred tall computations | Collect results into memory |
| `transform` | Apply function to each datastore read | Per-file (text) or per-row-group (Parquet) processing |
| `groupsummary` | Grouped statistics (tall-compatible) | Aggregation by category |
| `parpool` | Open parallel worker pool | Speed up tall computations |
| `mapreducer` | Connect to Hadoop/Spark cluster | Hadoop/Spark environments only |

## Unsupported Formats (JSON, XML, HTML, Word)

The datastores covered by this skill (`tabularTextDatastore`, `parquetDatastore`,
`spreadsheetDatastore`, `mdfDatastore`) do NOT support JSON, XML, HTML, or Word
documents. If the user or agent has an OOM error with `readtable` on one of these formats,
do NOT recommend converting to Parquet/CSV first — `readtable` itself would OOM
during the conversion, creating a circular dependency.

**Why not `fileDatastore` with `readtable`?** A common instinct is to use
`fileDatastore(@readtable)` — but if `readtable` OOMs on the file, wrapping it
in `fileDatastore` does not help because the read function still loads the
entire file into memory.

Instead, recommend building a **custom datastore** with a chunked read function
that processes the file in manageable pieces without loading it entirely into
memory (e.g., reading N lines of XML at a time, or parsing JSON arrays
incrementally). A `fileDatastore` with such a chunked read function is one
option; implementing the full `matlab.io.Datastore` interface is another. Point
the user to `doc matlab.io.Datastore` for the interface specification.

A custom datastore can then be used with `tall` or `transform` just like the
built-in datastores.

----

Copyright 2026 The MathWorks, Inc.

----
