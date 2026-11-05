# US Government Data Interfaces

Four MATLAB interfaces for accessing data from US government agencies: Bureau of Economic Analysis (BEA), Bureau of Labor Statistics (BLS), Census Bureau, and Energy Information Administration (EIA). These are GitHub-hosted community interfaces — not shipped with the Datafeed Toolbox.

## Installation

Download from GitHub (mathworks/Access-Public-US-Government-Data-from-MATLAB) and add to the MATLAB path:

```matlab
addpath("path/to/us-government-data")
```

Requires MATLAB R2026b+ and Datafeed Toolbox R2026b+.

## API Key Registration

Each agency requires a free API key:

| Agency | Class | Registration |
|--------|-------|-------------|
| Bureau of Economic Analysis | `usbea` | https://apps.bea.gov/api/signup/ |
| Bureau of Labor Statistics | `usbls` | https://data.bls.gov/registrationEngine/ |
| Census Bureau | `uscensus` | https://api.census.gov/data/key_signup.html |
| Energy Information Administration | `useia` | https://www.eia.gov/opendata/register.php |

Class names are `usbea`, `usbls`, `uscensus`, `useia` — NOT `bea`, `bls`, `census`, `eia`.

## BEA (`usbea`)

### Connection

```matlab
c = usbea(getSecret("usbeacreds"));
```

### Discovery Methods

BEA has four dedicated discovery methods that wrap `getData` with the appropriate BEA API method parameter:

```matlab
% List all available datasets
dsList = getDatasetList(c);

% Get parameters for a specific dataset
params = getParameterList(c, "Regional");

% Get valid values for a parameter
values = getParameterValues(c, "IntlServTrade", "TradeDirection");

% Get filtered values based on other parameter constraints
values = getParameterValuesFiltered(c, "Regional", "LineCode", "TableName", "SAINC1");
values = getParameterValuesFiltered(c, "Regional", "Year", "TableName", "CAINC5N", "GeoFips", "01001");
```

All discovery methods return tables.

### Data Retrieval

`getData` uses a method-dispatch pattern — the BEA API method is passed as a name-value pair:

```matlab
data = getData(c, "GET", "data", "method", "GETDATA", ...
               "DatasetName", "NIPA", ...
               "TableName", "T10101", ...
               "Frequency", "A,Q", ...
               "Year", "ALL");
```

### Return Types

`getData` returns a table via `struct2table`. For NIPA and similar datasets, the actual data rows are in a nested field:

```matlab
data = getData(c, "GET", "data", "method", "GETDATA", ...
               "DatasetName", "NIPA", "TableName", "T10101", ...
               "Frequency", "A", "Year", "ALL");
GDP = struct2table(data.Data{:});    % extract the nested data rows
```

## BLS (`usbls`)

### Connection

```matlab
c = usbls(getSecret("usblscreds"));
```

An API key is optional but recommended (registered users get higher rate limits and access to additional features like calculations and catalog data).

### Time Series Retrieval

Use `timeseries` — NOT `fetch` or `getData`:

```matlab
% Single series
data = timeseries(c, "LAUCN040010000000005");

% Multiple series with date range and additional features
data = timeseries(c, ["LAUCN040010000000005", "LAUCN040010000000006"], ...
                  "startyear", "2020", ...
                  "endyear", "2023", ...
                  "catalog", "true", ...
                  "calculations", "true");
```

Parameter conventions — all lowercase strings:
- `"startyear"` and `"endyear"` — NOT `"StartYear"` or `"startYear"`
- Year values as strings: `"2020"` — NOT numeric `2020`
- Boolean values as strings: `"true"` — NOT logical `true`
- `"catalog"`, `"calculations"`, `"annualaverage"`, `"aspects"` — all lowercase

### Browsing Methods

```matlab
% List all surveys
s = surveys(c);

% Specific survey metadata
s = surveys(c, "TU");

% 25 most popular series overall
p = popular(c);

% Popular series for a specific survey
p = popular(c, "LA");
```

`surveys` and `popular` return tables (converted from struct via `struct2table`).

### Return Types

`timeseries` returns a table via `struct2table`. The table contains series results, metadata, and (if requested) calculations.

## Census Bureau (`uscensus`)

### Connection

```matlab
c = uscensus(getSecret("uscensuscreds"));
```

### Data Retrieval

`getData` uses path-based endpoint routing. The endpoint path specifies the dataset and year:

```matlab
% Population estimates by state (2021)
data = getData(c, "GET", "2021/pep/population", ...
               "get", "POP_2021,NAME", ...
               "for", "state:*");

% American Community Survey: median household income by state
data = getData(c, "GET", "2021/acs/acs1", ...
               "get", "B19013_001E,NAME", ...
               "for", "state:*");

% ACS data with nested geography (counties in a state)
data = getData(c, "GET", "2021/acs/acs5", ...
               "get", "B01001_001E,NAME", ...
               "for", "county:*", ...
               "in", "state:06");
```

Census-specific query parameters:
- `"get"` — comma-separated list of variables to retrieve
- `"for"` — target geography (e.g., `"state:*"`, `"county:*"`, `"state:06"`)
- `"in"` — parent geography for nested filtering (e.g., `"state:06"` to filter counties within California)

The endpoint path (e.g., `"2021/pep/population"`, `"2021/acs/acs1"`) determines which Census dataset to query. Browse available endpoints at https://www.census.gov/data/developers.html.

### Return Types

Census API returns JSON arrays. The `getData` method converts the response depending on its type:
- Cell arrays (most common): converted via `cell2table` using the first row as variable names
- Structs: converted via `struct2table`
- Tables/strings: returned directly

## EIA (`useia`)

### Connection

```matlab
c = useia(getSecret("useiacreds"));
```

The constructor validates the API key by making a test request.

### Route Browsing

The EIA API is hierarchical. Browse by calling `getData` with progressively deeper paths:

```matlab
% Top-level routes
data = getData(c, "GET");

% Explore a category
data = getData(c, "GET", "petroleum");

% Drill deeper
data = getData(c, "GET", "petroleum/pri/spt");
```

Route responses include a `routes` field containing a table of available sub-routes.

### Data Retrieval

Retrieve data by navigating to a `/data` endpoint and specifying columns and filters:

```matlab
% Crude oil prices, annual
data = getData(c, "GET", "petroleum/pri/spt/data", ...
               "frequency", "annual");

% Electricity generation filtered by location
data = getData(c, "GET", "electricity/electric-power-operational-data/data", ...
               "frequency", "annual", ...
               "Data", ["generation"], ...
               "Facets", struct("location", ["90"]));
```

EIA-specific parameters:
- `"Data"` — string array of data columns to retrieve (e.g., `["generation"]`, `["price", "sales"]`)
- `"Facets"` — struct whose fields are facet names and values are string arrays of filter values (e.g., `struct("location", ["90"])`, `struct("stateid", ["CA", "TX"])`)
- `"frequency"` — data frequency (e.g., `"annual"`, `"monthly"`, `"quarterly"`)

The `expandParams` method internally converts `"Data"` and `"Facets"` into bracket-encoded URL parameters:
- `"Data", ["price", "sales"]` → `data[]=price&data[]=sales`
- `"Facets", struct("stateid", ["CA", "TX"])` → `facets[stateid][]=CA&facets[stateid][]=TX`

### Return Types

`getData` returns a table. For data responses, the table includes a `data` field containing a nested table with the actual data rows:

```matlab
result = getData(c, "GET", "petroleum/pri/spt/data", "frequency", "annual");
priceData = result.data{1};    % nested table with the data rows
```

Route responses include a `routes` field with a nested table of sub-routes, and optionally a `facets` field with available filter dimensions.

## Notes

- Class names are `usbea`, `usbls`, `uscensus`, `useia` — not abbreviated forms like `bea` or `eia`
- The API key is automatically included in requests by each class
- BEA uses a method-dispatch pattern (`"method", "GETDATA"`) unique among these interfaces
- BLS uses POST requests for `timeseries` and requires all-lowercase string parameters
- Census uses path-based endpoint routing and geographic query parameters (`"get"`, `"for"`, `"in"`)
- EIA uses `"Data"` and `"Facets"` parameters with automatic bracket encoding

----

Copyright 2026 The MathWorks, Inc.

----
