# Multithreaded Read & Write (R2026a+)

Requires: Parallel Computing Toolbox

Supported connections: `mysql()`, `postgresql()`, `sqlite()`, ODBC via `odbc()`.

## Critical Rules

- **Each thread must create its own connection.** Database connections are NOT thread-safe — never share a connection across threads.
- **Use `parpool("Threads")`** — not `"Processes"`. Thread pools share memory and avoid data serialization overhead.
- **Use `parallel.pool.Constant`** to wrap large data for write operations — avoids copying the full dataset to each thread.
- **Divide work into row-range batches** — each thread handles a contiguous slice.

## Multithreaded Write

```matlab
% Prepare data (wrap in Constant to avoid copies)
data = parallel.pool.Constant(largeTable);

% Connection parameters
server = "myserver.example.com";
databaseName = "production";
username = getSecret("dbUser");
password = getSecret("dbPass");
portNumber = 3306;
tablename = "measurements";

nRow = height(data.Value);
numTasks = 5;
batchSize = floor(nRow / numTasks);
startRow = 1;
endRow = 1 + batchSize;

pool = parpool("Threads");
writeFutures(1:numTasks) = parallel.FevalFuture;

for i = 1:numTasks
    writeFutures(i) = parfeval(pool, @hsqlwriteMT, 1, ...
        server, databaseName, username, password, portNumber, ...
        tablename, data, startRow, endRow);
    startRow = endRow;
    endRow = endRow + batchSize;
    if i == numTasks - 1
        endRow = nRow + 1;
    end
end

results = writeFutures.fetchOutputs("UniformOutput", false);

function finished = hsqlwriteMT(server, databaseName, username, password, portNumber, tablename, data, startRow, endRow)
    conn = mysql(username, password, Server=server, DatabaseName=databaseName, PortNumber=portNumber);
    sqlwrite(conn, tablename, data.Value(startRow:endRow-1, :));
    close(conn);
    finished = true;
end
```

## Multithreaded Read

Partition by a column (e.g., a categorical or ID range) so each thread reads a disjoint subset. Avoid `OFFSET`/`LIMIT` — it forces the database to scan skipped rows, which negates parallelization gains at high offsets and is not supported by all databases.

**Choose a partition column** that distributes rows evenly across threads. Good candidates: categorical columns with known distinct values, or numeric ID columns that can be divided into ranges.

### Partition by Distinct Values (categorical column)

```matlab
% Get distinct partition values using sqlStatistics (R2025a+)
conn = postgresql(getSecret("dbUser"), getSecret("dbPass"), ...
    Server="myserver.example.com", DatabaseName="analytics");
tblName = "events";
partitionCol = "Region";
stats = sqlStatistics(conn, tblName, VariableNames=partitionCol, StatsInfo="unique");
partitionValues = stats.Unique{1};
close(conn);

% Parallel read — one thread per partition value
pool = parpool("Threads");
numFutures = numel(partitionValues);
futures(1:numFutures) = parallel.FevalFuture;

for i = 1:numFutures
    futures(i) = parfeval(pool, @hfetchMT, 1, ...
        tblName, partitionCol, partitionValues(i));
end

data = futures.fetchOutputs("UniformOutput", false);
allData = vertcat(data{:});

function data = hfetchMT(tblName, partitionCol, partitionValue)
    conn = postgresql(getSecret("dbUser"), getSecret("dbPass"), ...
        Server="myserver.example.com", DatabaseName="analytics");
    rf = rowfilter(partitionCol);
    data = sqlread(conn, tblName, RowFilter=rf.(partitionCol) == partitionValue);
    close(conn);
end
```

### Partition by ID Range (numeric column)

```matlab
% Get ID range using sqlStatistics (R2025a+)
conn = postgresql(getSecret("dbUser"), getSecret("dbPass"), ...
    Server="myserver.example.com", DatabaseName="analytics");
tblName = "events";
partitionCol = "EventID";
stats = sqlStatistics(conn, tblName, VariableNames=partitionCol, StatsInfo=["min", "max"]);
bounds.minID = stats.Min;
bounds.maxID = stats.Max;
close(conn);

% Divide range into batches
pool = parpool("Threads");
numFutures = 5;
rangeSize = bounds.maxID - bounds.minID + 1;
batchSize = ceil(rangeSize / numFutures);
futures(1:numFutures) = parallel.FevalFuture;

for i = 1:numFutures
    lo = bounds.minID + (i - 1) * batchSize;
    hi = min(bounds.minID + i * batchSize - 1, bounds.maxID);
    futures(i) = parfeval(pool, @hfetchRangeMT, 1, tblName, partitionCol, lo, hi);
end

data = futures.fetchOutputs("UniformOutput", false);
allData = vertcat(data{:});

function data = hfetchRangeMT(tblName, partitionCol, lo, hi)
    conn = postgresql(getSecret("dbUser"), getSecret("dbPass"), ...
        Server="myserver.example.com", DatabaseName="analytics");
    rf = rowfilter(partitionCol);
    data = sqlread(conn, tblName, ...
        RowFilter=rf.(partitionCol) >= lo & rf.(partitionCol) <= hi);
    close(conn);
end
```

## Adapting for Other Databases

Replace the connection call in the helper function:

| Database | Connection in helper |
|----------|---------------------|
| MySQL | `conn = mysql(user, pass, Server=s, DatabaseName=db, PortNumber=p)` |
| PostgreSQL | `conn = postgresql(user, pass, Server=s, DatabaseName=db)` |
| SQLite | `conn = sqlite(filePath)` |
| ODBC | `conn = odbc(connectionString)` |

## Recommended Approach by Scenario

| Scenario | Approach |
|----------|----------|
| Large read/write, Parallel Computing Toolbox available | Multithreaded (`parfeval` + per-thread connections) |
| Large write, no Parallel Computing Toolbox | Single-threaded chunked `sqlwrite` loop |
| Small dataset (< 100K rows) | Single `sqlread` or `sqlwrite` call |
| Read with complex SQL (joins, aggregation) | Single `fetch` with SQL — hard to partition |

## Common Mistakes

```matlab
% WRONG — sharing a connection across threads
conn = mysql(user, pass, Server=s, DatabaseName=db);
for i = 1:numTasks
    futures(i) = parfeval(pool, @sqlwrite, 0, conn, tbl, batch);  % NOT thread-safe!
end

% CORRECT — each thread creates its own connection
for i = 1:numTasks
    futures(i) = parfeval(pool, @helperWrite, 1, connParams, batch);
end

% WRONG — using parpool("Processes") (serializes data across process boundaries)
pool = parpool("Processes");

% CORRECT — threads share memory
pool = parpool("Threads");

% WRONG — passing large table directly (copied to each thread)
parfeval(pool, @helperWrite, 1, largeTable, startRow, endRow);

% CORRECT — wrap in parallel.pool.Constant
data = parallel.pool.Constant(largeTable);
parfeval(pool, @helperWrite, 1, data, startRow, endRow);

% WRONG — using OFFSET/LIMIT for parallel reads (scans skipped rows, slow at high offsets)
fetch(conn, "SELECT * FROM events OFFSET 1000000 LIMIT 200000");

% CORRECT — partition by column values or ID ranges
rf = rowfilter("Region");
sqlread(conn, "events", RowFilter=rf.Region == "US-West");
```

----

Copyright 2026 The MathWorks, Inc.

----
