# FRED (Federal Reserve Economic Data) in Datafeed Toolbox

The `fred` command is obsolete. Users should use the `fredrs` interface instead (available since R2026a).

## Core API

Create a connection (requires a FRED API key):

```matlab
c = fredrs(getSecret("fredrscreds"));
```

Retrieve data using `series` with `"observations"` or `fetch`:

```matlab
% Using series with observations flag — returns table via d.observations{1}
d = series(c, "GNP", "observations");
t = d.observations{1};                            % table

% Using fetch — returns timetable via d.DATA{1}
d = fetch(c, "GNP");
tt = d.DATA{1};                                   % timetable

% Both support date ranges
d = series(c, "GNP", "observations", "01/01/2020", "12/31/2024");
d = fetch(c, "GNP", "01/01/2020", "12/31/2024");
```

Note: `series` returns a table in `d.observations{1}`, while `fetch` returns a timetable in `d.DATA{1}`.

## Search

Find series by keyword:

```matlab
d = search(c, "unemployment rate");              % keyword search
d = search(c, "CPI", "limit", "10");            % limit results
d = search(c, "GDP", "order_by", "popularity"); % sort by popularity
```

Returns a table with columns including `id`, `title`, `frequency`, and `observation_start`/`observation_end`.

## Discovery and Metadata Methods

All discovery methods follow the pattern: `method(c, id, subtype, Name, Value, ...)` where the optional subtype drills into related data.

### category — Browse the FRED category tree

Category IDs are not listed in a flat endpoint — FRED uses a tree starting at root `"0"`. Navigate by requesting children:

```matlab
d = category(c, "0", "children");         % top-level categories (root)
d = category(c, "32991", "children");     % drill into a specific category
d = category(c, "125");                   % category info
d = category(c, "125", "series");         % series within a category
d = category(c, "125", "tags");           % tags for a category
d = category(c, "125", "related_tags", "tag_names", "services");  % related tags (requires tag_names)
```

### tags — Search and browse tags

```matlab
d = tags(c, "gdp");                     % find tags
d = tags(c, "gdp", "series");           % series for a tag
d = tags(c, "gdp", "related_tags");     % related tags
```

### release — Info about a specific release (by release ID)

```matlab
d = release(c, "53");                % release info (e.g., GDP release)
d = release(c, "53", "dates");       % release dates
d = release(c, "53", "series");      % series in this release
d = release(c, "53", "sources");     % sources for this release
d = release(c, "53", "tags");        % tags for this release
d = release(c, "53", "tables");      % data tables in this release
```

### releases — List all FRED releases

```matlab
d = releases(c);                     % all releases
d = releases(c, "dates");            % all release dates
```

### source — Data source info

```matlab
d = source(c);                       % list all sources
d = source(c, "1");                  % specific source info
d = source(c, "1", "releases");      % releases from a source
```

All methods return tables with automatic date and type conversion.

## Return Value Indexing

Discovery methods return data in varying formats depending on the method and subtype:

```matlab
% category children — returns a table directly
cats = category(c, "0", "children");
firstCatID = string(cats.id(1));           % direct table column access

% releases — returns nested cell arrays
allReleases = releases(c);
firstReleaseID = string(allReleases.releases{1}{1}.id);

% series in a category
seriesData = category(c, "125", "series");
```

Return formats are not uniform. Some methods return structured tables (access via `result.field(row)`), others return unstructured nested cell arrays (access via `result.field{1}{row}.property`). Inspect the return value to determine the appropriate indexing.

## Notes

- `fred` is obsolete — always use `fredrs`
- Available since R2026a in Datafeed Toolbox
- Use `series(c, id, "observations", ...)` to retrieve data (replaces the old `fetch` syntax)

---

Copyright 2026 The MathWorks, Inc.
