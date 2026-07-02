# Haver Analytics Interfaces in Datafeed Toolbox

Three Haver Analytics interfaces providing access to the same underlying economic data through different access methods.

## Interfaces

### haver (Local Data Files)
- Accesses data in local data files via file pathname
- No authentication required
- Windows only
- Methods: aggregation, close, delete, fetch, get, havertool, info, isconnection, nextinfo

### haverdirect (Remote Data Servers)
- Same functionality and API as `haver` (except `havertool`)
- Takes a database name (not file path) and authenticates the user outside of MATLAB on connect
- Retrieves data from remote servers
- Windows only
- Methods: aggregation, close, delete, fetch, get, info, isconnection, nextinfo
- Does NOT support `havertool` — loading the full variable list from remote servers is too resource-intensive

### haverview (Cloud REST API)
- Cloud-based offering using an underlying REST API
- Provides access to the same data as haver and haverdirect
- Platform independent
- Different API surface — not a drop-in replacement for haver/haverdirect
- Methods: currencies, databases, fetch, haverview, info, search, series
- **haverview has NO `close` method — NEVER call `close()` on a haverview object**

## Recommendations

| Use Case | Recommendation |
|----------|---------------|
| Windows with local Haver data files | `haver` |
| Windows needing remote data access | `haverdirect` |
| Non-Windows (Linux/Mac) | `haverview` |
| Server/cloud deployments | `haverview` |

## Key Functions and Patterns

### Connecting

```matlab
% Local data files (Windows only)
c = haver("C:\DLX\DATA\USECON.dat");

% Remote data servers (Windows only, auth handled externally)
% haverdirect takes a database NAME, not a file path
c = haverdirect("USECON");   % correct — database name only
% c = haverdirect("C:\DLX\DATA\USECON.dat");  % WRONG — file paths are for haver()

% Cloud REST API (platform independent)
c = haverview(apiToken);

% Close haver and haverdirect connections when done
close(c);
% IMPORTANT: haverview has NO close method — NEVER call close() on haverview objects.
% haverview connections are stateless REST — they do not need cleanup.
```

### Fetching Data (fetch)

`fetch` and `info` behave the same across all three interfaces.

```matlab
% haver/haverdirect — fetch with frequency as 5th positional argument
% Frequency codes: "D" (daily), "M" (monthly), "Q" (quarterly), "A" (annual), "W" (weekly)
d = fetch(c, "GDPQ", datetime(2020,1,1), datetime(2024,12,31), "Q");
%       ↑conn  ↑var     ↑startDate          ↑endDate            ↑freq (5th arg)

% haverview — fetch without frequency (no frequency argument)
d = fetch(c, "GDPQ", datetime(2020,1,1), datetime(2024,12,31));
%       ↑conn  ↑var     ↑startDate          ↑endDate     ← NO 5th arg
```

All date formats are supported: datetime, datenum, and date strings.

The frequency code is always the 5th positional argument for `haver`/`haverdirect` — never a name-value pair like `'Frequency', "M"`.

`haverview`'s `fetch` does NOT accept a frequency argument — only `haver` and `haverdirect` do. Passing a frequency to `haverview` will error.

### Variable Information (info)

```matlab
% Get info about a specific variable
varInfo = info(c, "GDPQ");
```

`info` takes a variable name — it does not return info about the whole database.

### Iterating Through Variables (nextinfo — haver/haverdirect only)

```matlab
% Get the FIRST variable in the database (pass empty string)
firstVar = nextinfo(c, "");

% Get the NEXT variable using the VarName field from the previous result
nextVar = nextinfo(c, firstVar.VarName);
```

`nextinfo` is only available on `haver` and `haverdirect`. Pass an empty string `""` to get the first variable — not an empty call with no arguments.

### Interactive Database Browser (havertool — haver only)

```matlab
% Open interactive UI to browse variables in the connected database
havertool(c);
```

`havertool` creates a UI that scans the database file and generates an interactive list of all variables. It takes no additional arguments — the database is determined from the connection handle.

Note: `havertool` is only available for `haver` (local files) — not `haverdirect`. Loading the full variable list from remote servers is too resource-intensive.

## Notes

- None of the Haver interfaces face deprecation
- `haver` and `haverdirect` are API-identical (drop-in replacements for each other)
- `haverview` has a different, discovery-oriented API — migration from haver/haverdirect requires code changes
- Shared methods across all three: `fetch`, `info`
- `haver`/`haverdirect` only: `nextinfo`, `aggregation`, `delete`, `get`, `close`, `havertool`
- `haverview` only: `currencies`, `databases`, `search`, `series` — **no `close` method** (do not call `close` on haverview objects)

---

Copyright 2026 The MathWorks, Inc.
