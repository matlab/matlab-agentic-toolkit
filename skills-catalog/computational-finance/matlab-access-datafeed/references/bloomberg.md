# Bloomberg Interfaces in Datafeed Toolbox

Three Bloomberg interfaces providing market data access through different underlying APIs.

## Interface Selection

### Decision 1: Which license type?

| License | Interface (Recommended) | Interface (Java — Bring Your Own) |
|---------|------------------------|-----------------------------------|
| Bloomberg Desktop/Terminal | `bloomberg` | `blp` |
| Bloomberg Server | `bloombergServer` | `blpsrv` |
| Bloomberg BPIPE | `bloombergBPIPE` | `bpipe` |
| Bloomberg Data License (Hypermedia) | `bloombergHypermedia` | — |
| Bloomberg EMSX (order execution) | `bloombergEMSX` | `emsx` |

### Decision 2: C++ vs Java?

- **Use C++ interfaces** (`bloomberg`, `bloombergServer`, `bloombergBPIPE`) — no additional third-party library setup required
- **Use Java interfaces** (`blp`, `blpsrv`, `bpipe`) only if you specifically need Java. Users must supply their own Java runtime and add `blpapi3.jar` to the MATLAB Java classpath
- If a user cannot bring their own Java, they should NOT use the Java interfaces
- **EMSX interfaces** (`bloombergEMSX`, `emsx`) are for order execution workflows, not data retrieval

### Decision 3: Data License (Hypermedia)?

`bloombergHypermedia` is a separate decision path — use it when:
- Licensed for Bloomberg Data License (also known as Hypermedia)
- Need platform-independent access (no local Bloomberg software)
- Running in server/cloud/headless environments
- Performing bulk data retrieval

## Interfaces

### bloomberg (C++ API) — Recommended for Windows users
- Uses the Bloomberg C++ API
- Windows only (Desktop/Terminal); BPIPE child class is platform independent
- Marginally faster than blp
- Has child classes for Server/BPIPE licenses
- **Recommended over blp on Windows**

### blp (Java API) — Bring Your Own Java
- Uses the Bloomberg Java API
- Windows only (Desktop/Terminal); BPIPE child class is platform independent
- Has child classes for Server/BPIPE licenses
- No plan to remove; users must supply their own Java runtime as MATLAB stops bundling it
- Behavior identical to `bloomberg` (other than different entry point constructors)

### bloombergHypermedia (Data License REST API)
- Uses the Bloomberg Data License REST API (also known as Hypermedia)
- Platform independent
- No local Bloomberg software installation required
- Suitable for server/cloud/headless deployments and bulk data retrieval

## Recommendations

| Use Case | Recommendation |
|----------|---------------|
| Windows Desktop/Terminal user | `bloomberg` (C++) |
| Non-Windows with BPIPE license | `bpipe` BPIPE child class |
| Server/cloud, no Terminal | `bloombergHypermedia` |
| Existing `blp` users | Migrate to `bloomberg` if possible (same API) |

## Key Functions and Patterns

### Connecting

```matlab
% Bloomberg Desktop (C++ — recommended)
b = bloomberg;

% Bloomberg Desktop (Java — requires blpapi3.jar on javaclasspath)
b = blp;

% Bloomberg Server (C++ — recommended)
b = bloombergServer(serverIP);

% Bloomberg BPIPE (C++ — recommended)
b = bloombergBPIPE(serverIP, port, authID);

% Bloomberg Hypermedia (Data License REST)
b = bloombergHypermedia(credentials);

% Always close when done
close(b);
```

### Reference Data (getdata)

Retrieve current/static data and bulk fields for securities:

```matlab
% Single security, single field
[d, sec] = getdata(b, "IBM US Equity", "PX_LAST");

% Multiple securities and fields — use string arrays
[d, sec] = getdata(b, ["IBM US Equity", "MSFT US Equity"], ["PX_LAST", "PX_VOLUME"]);

% With overrides — trailing positional key-value pairs (not a struct or options arg)
[d, sec] = getdata(b, "IBM US Equity", "BEST_EPS", "BEST_FPERIOD_OVERRIDE", "1BF");
%                                       ↑field      ↑override name             ↑override value

% Multiple overrides — just append more key-value pairs
[d, sec] = getdata(b, "IBM US Equity", "BEST_EPS", ...
    "BEST_FPERIOD_OVERRIDE", "1BF", "CRNCY", "USD");

% Historical dividend data (bulk field — use getdata, not history)
[d, sec] = getdata(b, "AAPL US Equity", "DVD_HIST_ALL");
```

Overrides are trailing positional string arguments to `getdata` — they are NOT a struct, NOT a name-value pair with an `'Override'` keyword, and NOT a separate overrides argument.

Note: `DVD_HIST_ALL` is a bulk reference data field that returns the full dividend history including all corporate actions (special dividends, stock splits, etc.). Always retrieve it with `getdata`, not `history`.

### Historical Data (history)

Retrieve end-of-day historical data:

```matlab
% Basic history with date range
[d, sec] = history(b, "IBM US Equity", "PX_LAST", datetime(2024,1,1), datetime(2024,12,31));

% Multiple fields with periodicity
[d, sec] = history(b, "IBM US Equity", ["PX_LAST", "PX_VOLUME"], ...
    datetime(2024,1,1), datetime(2024,12,31), ...
    ["CALENDAR", "DAILY", "ALL_CALENDAR_DAYS", "PREVIOUS_VALUE"]);

% With currency conversion (currency is the argument after periodicity)
[d, sec] = history(b, "AAPL US Equity", "PX_LAST", datetime(2024,1,1), datetime(2024,12,31), ...
    ["CALENDAR", "DAILY", "ALL_CALENDAR_DAYS", "PREVIOUS_VALUE"], "JPY");
```

Default periodicity is `["ACTUAL", "DAILY", "ACTIVE_DAYS_ONLY", "NIL_VALUE"]`.

The currency argument is a positional input after periodicity — not a name-value pair or override.

### Intraday Data (timeseries)

Retrieve intraday tick data:

```matlab
% Tick data for today
d = timeseries(b, "IBM US Equity", datetime("today"));

% Tick data for a date range
d = timeseries(b, "IBM US Equity", {datetime(2024,6,1), datetime(2024,6,2)});

% Intraday bars for a specific time window across multiple days
% 3-element daterange: {dates, startTime, endTime} — requires bar interval
dates = (datetime(2024,6,3):datetime(2024,6,7))';
d = timeseries(b, "IBM US Equity", {dates, duration(9,30,0), duration(16,0,0)}, 5, "TRADE");

% Bar data (aggregated) — 5-minute intervals
d = timeseries(b, "IBM US Equity", {datetime(2024,6,1), datetime(2024,6,2)}, 5, "TRADE");

% Tick data with Bloomberg API flags (condition codes, exchange codes, broker codes)
% API flags are passed as two cell arrays of char vectors: flag names and flag values
d = timeseries(b, "F US Equity", {datetime(2024,6,1), datetime(2024,6,2)}, ...
    [], "Trade", ...
    {'includeConditionCodes', 'includeExchangeCodes', 'includeBrokerCodes'}, ...
    {'true', 'true', 'true'});
```

Bloomberg API flags for `timeseries` are passed as two trailing cell arrays of **char vectors** (single-quoted) — one for flag names, one for flag values. Do NOT use string scalars (double-quoted) inside the cell arrays — `{"flagName"}` fails the internal `ischar` validation; use `{'flagName'}` instead. The bar interval argument (empty `[]` for tick data) and event type must precede the flag arguments.

### Bloomberg Hypermedia Workflow (Data License)

The `bloombergHypermedia` interface uses a multi-step workflow: create resources (universe, field list, trigger), assemble them into a request, then retrieve data.

```matlab
% Connect with JSON credentials (contains client_id and client_secret), secret is user defined
b = bloombergHypermedia(getSecret("bhapicredentials"));

% Your account catalog ID
catalog = "myAccountId";

% Step 1: Create a Universe (securities)
uPayload.type = "Universe";
uPayload.identifier = "u" + bloombergHypermedia.generateResourcePostfix;
uPayload.title = "My Universe";
uPayload.description = "Equity universe";
uPayload.contains{1}.type = "Identifier";
uPayload.contains{1}.identifierType = "TICKER";
uPayload.contains{1}.identifierValue = "IBM US Equity";
uPayload.contains{2}.type = "Identifier";
uPayload.contains{2}.identifierType = "TICKER";
uPayload.contains{2}.identifierValue = "AAPL US Equity";
universeID = createUniverse(b, catalog, uPayload);

% Step 2: Create a Field List
fPayload.type = "DataFieldList";
fPayload.identifier = "f" + bloombergHypermedia.generateResourcePostfix;
fPayload.title = "My Fields";
fPayload.description = "EOD price fields";
fPayload.contains(1).mnemonic = "PX_LAST";
fPayload.contains(2).mnemonic = "PX_OPEN";
fPayload.contains(3).mnemonic = "PX_HIGH";
fPayload.contains(4).mnemonic = "PX_LOW";
fieldListID = createFieldList(b, catalog, fPayload);

% Step 3: Create a Trigger (optional — defaults to immediate submit)
tPayload.type = "SubmitTrigger";
tPayload.identifier = "t" + bloombergHypermedia.generateResourcePostfix;
tPayload.title = "Submit Now";
tPayload.description = "Immediate submission";
triggerID = createTrigger(b, catalog, tPayload);

% Step 4a: Create a Reference Data Request (ties universe + field list + trigger)
requestID = createRequest(b, catalog, universeID, fieldListID, triggerID);
% or use default trigger
requestID = createRequest(b, catalog, universeID, fieldListID);

% Step 4b: Create a Historical Data Request (requires full payload with runtime options)
reqPayload.identifier = "r" + bloombergHypermedia.generateResourcePostfix;
reqPayload.title = "My History Request";
reqPayload.description = "Daily historical prices";
reqPayload.universe = strcat(b.URL, "/eap/catalogs/", catalog, "/universes/", universeID);
reqPayload.fieldList = strcat(b.URL, "/eap/catalogs/", catalog, "/fieldLists/", fieldListID);
reqPayload.trigger = strcat(b.URL, "/eap/catalogs/bbg/triggers/oneshot/");
reqPayload.formatting.type = "HistoryFormat";
reqPayload.formatting.dateFormat = "yyyymmdd";
reqPayload.formatting.fileType = "unixFileType";
reqPayload.formatting.displayPricingSource = true;
reqPayload.runtimeOptions.type = "HistoryRuntimeOptions";
reqPayload.runtimeOptions.historyPriceCurrency = "USD";
reqPayload.runtimeOptions.period = "daily";
reqPayload.runtimeOptions.dateRange.type = "IntervalDateRange";
reqPayload.runtimeOptions.dateRange.startDate = string(datetime("today") - calyears(1), "yyyy-MM-dd");
reqPayload.runtimeOptions.dateRange.endDate = string(datetime("today"), "yyyy-MM-dd");
reqPayload.pricingSourceOptions.type = "HistoryPricingSourceOptions";
reqPayload.pricingSourceOptions.exclusive = true;
requestID = createRequest(b, catalog, reqPayload);

% Step 5: Retrieve data
requestDate = string(datetime("today", "Format", "yyyyMMdd"));
data = getData(b, catalog, requestID, requestDate);

close(b);
```

**Reference vs. Historical requests:** For reference/bulk data (e.g., `DVD_HIST_ALL`), use the simple `createRequest(b, catalog, universeID, fieldListID)`. For historical time series data (e.g., daily `PX_LAST` over a date range), build a full request payload with `HistoryRuntimeOptions` specifying period, date range, and currency. The `oneshot` trigger at `"/eap/catalogs/bbg/triggers/oneshot/"` submits immediately.

### Output Format Properties

```matlab
b = bloomberg;
b.DataReturnFormat = "timetable";   % 'table', 'timetable', or default (struct/cell)
b.DatetimeType = "datetime";       % use datetime instead of datenum
```

## Code Generation: Input Types

When generating code for `bloomberg`/`blp` methods, do **not** use cell arrays of strings for list inputs:

```matlab
% OK — string arrays
securities = ["IBM US Equity", "MSFT US Equity"];

% OK — char vectors and cellstr
securities = {'IBM US Equity', 'MSFT US Equity'};

% WRONG — cell arrays of strings (fails internal validation)
securities = {"IBM US Equity", "MSFT US Equity"};
```

The methods accept `char`, `string`, or `cellstr` — but cell arrays of strings (`{"a","b"}`) fail the internal `~ischar(s{1})` check.

## Notes

- `blp` and `bloomberg` provide identical functionality and methods — migration is a drop-in replacement
- `blp` remains available; users must provide their own Java runtime once MATLAB stops bundling it
- Only BPIPE child classes and bloombergHypermedia are platform independent

---

Copyright 2026 The MathWorks, Inc.
