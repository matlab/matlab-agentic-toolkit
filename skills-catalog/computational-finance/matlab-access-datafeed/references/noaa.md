# NOAA Climate Data Online (CDO) — @noaa Interface

The `@noaa` class provides access to the NOAA Climate Data Online (CDO) Web Services API v2 from MATLAB. It is a GitHub-hosted interface, not part of the Datafeed Toolbox.

## Installation

Clone the repository and add it to the MATLAB path:

```matlab
% From a terminal:
%   git clone https://github.com/mathworks/noaa.git

% In MATLAB:
addpath("C:\work\noaa")   % adjust to your clone location
```

Requires MATLAB R2026b+.

## Connecting

Create a connection using your CDO API token (register at ncdc.noaa.gov/cdo-web/token):

```matlab
token = getSecret("NOAA_CDO_TOKEN");
c = noaa(token);
```

The constructor validates the token by issuing a GET request to the API base URL. If the token is invalid, it throws `datafeed:noaa:connectFailure`.

## Discovery Methods

Six methods share the same calling pattern and all return **tables** (via `struct2table`):

```matlab
[d, response] = methodName(c, id, Name1, Value1, ...)
```

- `id` — optional record identifier; pass `[]` to omit
- Name-value pairs map directly to CDO REST API query parameters
- Default limit is 25 records per request; maximum is 1000 (`"limit", "1000"`)
- `response` is a `matlab.net.http.ResponseMessage`

### datasets

```matlab
d = datasets(c);                                  % all datasets (up to 25)
d = datasets(c, "GHCND");                         % specific dataset by ID
```

Returns table: `uid`, `name`, `id` (string); `mindate`, `maxdate` (datetime).

### datacategories

```matlab
d = datacategories(c);
d = datacategories(c, [], "limit", "42");         % all 42 categories
```

Returns table: `name`, `id` (string). No date columns.

### datatypes

```matlab
d = datatypes(c);
d = datatypes(c, [], "datasetid", "GHCND", "limit", "1000");
d = datatypes(c, [], "datacategoryid", "TEMP", "datasetid", "GSOM", "limit", "100");
```

Returns table: `name`, `id` (string); `mindate`, `maxdate` (datetime).

### locationcategories

```matlab
d = locationcategories(c);
```

Returns table: `name`, `id` (string). No date columns.

### locations

```matlab
d = locations(c);
d = locations(c, [], "datasetid", "GHCND", "locationcategoryid", "ST", "limit", "52");
```

Returns table: `name`, `id` (string); `mindate`, `maxdate` (datetime).

### stations

```matlab
d = stations(c);
d = stations(c, [], "datasetid", "GHCND", "locationid", "FIPS:12", "limit", "1000");
d = stations(c, "GHCND:USW00012839");            % specific station
```

Returns table: `name`, `id`, `elevationUnit` (string); `mindate`, `maxdate` (datetime).

**Known issue:** `stations()` can error on large result sets where station records have inconsistent fields. The `struct2table` call fails when some records have fields others lack. If this happens, filter by dataset, location, or limit to reduce the result set. For very large station queries, use direct HTTP requests with `matlab.net.http` as a fallback.

## getdata — Retrieve Observations

```matlab
[d, response] = getdata(c, datasetID, startdate, enddate, Name1, Value1, ...)
```

All four positional arguments are required:

| Argument | Type | Notes |
|----------|------|-------|
| `datasetID` | string | e.g. `"GHCND"`, `"GSOM"`, `"GSOY"` |
| `startdate` | datetime or datenum |  |
| `enddate` | datetime or datenum |  |

Common name-value parameters: `stationid`, `datatypeid`, `locationid`, `limit`, `units`.

```matlab
[d, ~] = getdata(c, "GHCND", datetime(2023,1,1), datetime(2023,12,31), ...
    "stationid", "GHCND:USW00012839", ...
    "datatypeid", "TMAX", ...
    "units", "metric", ...
    "limit", "1000");
```

Returns a **table** with **no column type conversion** — all columns retain their JSON-deserialized types. This is different from discovery methods which convert specific columns to string and datetime. Typical columns: `date` (string), `datatype` (string), `station` (string), `value` (numeric).

To convert dates from `getdata` results:

```matlab
dates = datetime(d.date, InputFormat="yyyy-MM-dd'T'HH:mm:ss");
```

## Common Datasets and Data Types

| Dataset | ID | Description |
|---------|----|-------------|
| Daily Summaries | `"GHCND"` | Daily observations from ~100k stations worldwide |
| Monthly Summaries | `"GSOM"` | Monthly aggregates |
| Annual Summaries | `"GSOY"` | Annual aggregates |

| Data Type | ID | Unit (metric) |
|-----------|----|---------------|
| Average temperature | `"TAVG"` | tenths of °C |
| Maximum temperature | `"TMAX"` | tenths of °C |
| Minimum temperature | `"TMIN"` | tenths of °C |
| Precipitation | `"PRCP"` | tenths of mm |
| Snowfall | `"SNOW"` | mm |

## Year-by-Year Looping for Large Requests

The API returns at most 1000 records per request. For multi-year daily data, loop year by year and concatenate:

```matlab
allData = table();
for yr = 2020:2023
    [d, ~] = getdata(c, "GHCND", datetime(yr,1,1), datetime(yr,12,31), ...
        "stationid", "GHCND:USW00012839", ...
        "datatypeid", "TMAX", ...
        "units", "metric", ...
        "limit", "1000");
    if istable(d) && ~isempty(d)
        allData = [allData; d]; %#ok<AGROW>
    end
end
```

## Building a Timetable from Results

```matlab
dates = datetime(allData.date, InputFormat="yyyy-MM-dd'T'HH:mm:ss");
values = allData.value / 10;    % tenths of °C to °C
tt = timetable(dates, values, VariableNames="TMAX_C");
```

## Notes

- The `@noaa` class is hosted on GitHub (github.com/mathworks/noaa), not shipped with the Datafeed Toolbox. It requires `addpath` after cloning.
- Name-value parameter values should be passed as strings (e.g. `"limit", "1000"` not `"limit", 1000`).
- Do not name variables `datatypes` or `datasets` — these shadow the `@noaa` method names.
- Large API responses (1000+ items) may deserialize as cell arrays of structs instead of struct arrays, causing `struct2table` to fail. Reduce the result set with filters or `limit`.

----

Copyright 2026 The MathWorks, Inc.

----
