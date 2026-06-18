---
name: matlab-find-pi-assets
description: >
  Find and query PI assets using MATLAB's Industrial Communication Toolbox.
  Two paths: (1) direct PI tag lookup via piclient + tags when user provides a tag name or
  description (R2022a+), (2) Asset Framework navigation via afclient when user needs
  element/attribute hierarchy (R2026a+). Use when working with PI AF servers, PI Data Archive
  tags, asset hierarchies, element templates, attribute lookup, or historical data from
  OSIsoft PI systems.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# PI Asset Identification & Data Query

Connect to PI systems, locate assets, and read historical data using MATLAB's Industrial Communication Toolbox wrappers — not raw .NET SDK interop.

## Release Requirements

| Workflow | Minimum Release | Functions |
|----------|----------------|-----------|
| A: PI Data Archive (tag lookup) | R2022a+ | `piclient`, `tags`, `read` (piclient) |
| B: PI Asset Framework (AF navigation) | R2026a+ | `afclient`, `findElementByName`, `getAttributes`, `readHistory`, etc. |

## When to Use

- User wants to find or query PI Asset Framework elements or attributes
- User provides a PI tag name or tag description and wants to look it up
- User needs historical data from a PI AF attribute or PI tag
- User mentions PI AF server, PI Data Archive, OSIsoft, AVEVA PI, or asset hierarchy
- User wants to list elements by template (e.g., "all generation units")

## When NOT to Use

- Creating or modifying AF elements/templates (administration)
- Real-time streaming, event frames, or notifications
- PI Vision or PI Web API access
- Writing data back to PI AF or PI Data Archive

## Decision Logic

Choose the workflow based on what information the user provides:

| User provides | Workflow | Entry function |
|---------------|----------|----------------|
| A PI tag name (e.g., `"GU1.ActivePower"`) | A: Direct Tag Lookup | `piclient` → `tags` |
| A tag description or partial tag name | A: Direct Tag Lookup | `piclient` → `tags` |
| An element name, template, or attribute in AF | B: AF Navigation | `afclient` |
| A request to browse/explore the asset hierarchy | B: AF Navigation | `afclient` |

If unclear, ask the user: "Do you have a specific PI tag name, or do you need to navigate the Asset Framework hierarchy?"

## Workflow A: Direct Tag Lookup (R2022a+)

Use when the user provides a PI tag name or description.

1. **Identify PI Data Archive server (MUST ask user)** — If the user has not specified a server name, run the PI server discovery pattern (see [Discover Available PI Data Archive Servers](#discover-available-pi-data-archive-servers)) to enumerate available servers. If no servers are found, inform the user that no PI Data Archive servers are discoverable on the host machine and ask them to provide the server name manually. If servers are found, you **MUST** present the list to the user and ask them to select a server — never auto-select or assume which server to use. Include descriptions (if available) and a "None of these" option. If the user selects "None of these", ask them to provide the server name manually. **Do not proceed to the next step until the user has confirmed a server.**
2. **Connect** — `piObj = piclient('serverName')`
3. **Search for tags** — `tagList = tags(piObj, Name='pattern*')` using the name or description the user provided
4. **Present results** — Show the matching tags to the user for confirmation. `tags()` returns a table with a `Tags` column (string array).
5. **Read data** — Extract the tag name with `tagName = tagList.Tags(N)`, then choose based on what the user asked:
   - **Current value or no time range specified:** `data = read(piObj, tagName)` — returns the snapshot/current value of the tag
   - **Historical data with time range:** `data = read(piObj, tagName, DateRange=[start end], Interval=..., AggregateFcn=...)`
   
   If the user says "get the value", "what is the current reading", or requests data without specifying a date range, use `read(piObj, tagName)` without DateRange.

## Workflow B: Asset Framework Navigation (R2026a+)

Use when the user needs to navigate the element/attribute hierarchy.

1. **Identify AF server (MUST ask user)** — If the user has not specified a server name, run the AF server discovery pattern (see [Discover Available AF Servers](#discover-available-af-servers)) to enumerate available servers. If no servers are found, inform the user that no AF servers are discoverable on the host machine and ask them to provide the server name manually. If servers are found, you **MUST** present the list to the user and ask them to select a server — never auto-select or assume which server to use. Include descriptions (if available) and a "None of these" option. If the user selects "None of these", ask them to provide the server name manually. **Do not proceed to the next step until the user has confirmed a server.**
2. **Connect** — `afObj = afclient('serverName')`
3. **Clarify database (MUST ask user)** — Use `listDatabases(afObj)` to show available databases and you **MUST** ask the user to select one — never auto-select or assume which database to use, even if only one database exists. `listDatabases` returns a **string array** of names only — to show descriptions alongside names, use the .NET SDK fallback (see [List Databases with Descriptions](#list-databases-with-descriptions)). If the user is unsure which database contains their element, run the cross-database search pattern (see [Search for Element Across All Databases](#search-for-element-across-all-databases)) to find the correct database. **Do not proceed to the next step until the user has confirmed a database.** Once identified, connect with `selectDatabase(afObj, dbList(N))` or `afObj = afclient('serverName', Database='dbName')`.
4. **Find elements with disambiguation** — Always use a wildcard search to discover related elements:
   - Search: `results = findElementByName(afObj, 'baseIdentifier*')` where `baseIdentifier` is the shortest identifier the user mentioned (e.g., `'GU1'` from "GU1 generator")
   - By template (if searching by type): `elems = findElementByTemplate(afObj, 'templateName')`
   - By path (when full path is known): `elem = findElementByPath(afObj, "\\server\database\path\to\element")` — **MUST use string (double-quoted), NEVER char (single-quoted)** — char input silently fails and returns an error even when the path is correct
   
   **Always present results for user confirmation:** Regardless of how many elements are returned, present a table to the user showing Name, Template, Description, hierarchy path using arrow notation (e.g., `Flynn River Hydro->Flynn I->GU1->GU1 Generator` — strip `\\server\database\` prefix and join with `->`), and NumChildren. Ask the user to confirm which element they mean. If the user asks for more detail, use `getChildren` or `getAttributes` on a specific element to help them navigate. Only proceed once the user confirms.

5. **Get attributes and confirm** — Use `getAttributes(elem, 'attributeName*')` with a wildcard name filter. If only one attribute matches and it clearly corresponds to the user's request, proceed directly. **Important** If multiple attributes match or there is ambiguity (e.g., "Active Power" vs "Active Power Generated", or multiple attributes with the same name from different elements), present the matching attributes in a table showing Name, ElementName, ServerDataType, DefaultUnit, HasTimeSeriesData, and Description — then ask the user to select the correct one(s). The element name and data type help the user distinguish between identically-named attributes on different elements.
6. **Validate attribute** — After the user confirms an attribute, perform these checks before reading data:
   - **Verify parent element:** Confirm `attr.ElementName` matches the user's intended asset. For full hierarchy verification, use `attr.Path` (format: `\\server\database\...\element|attribute`) — when displaying to the user, strip the `\\server\database\` prefix and join with `->` (e.g., `Flynn River Hydro->Flynn I->GU1->GU1 Generator|Active Power`). If the element suggests a different asset than what the user asked for (e.g., a similarly-named attribute on a sibling element), flag this to the user before proceeding.
   - **Check time series availability:** If the user requested historical/range-based data and `HasTimeSeriesData` is `false`, inform the user that the selected attribute does not contain time series data and ask whether they would still like to proceed with reading the current value instead.
7. **Read data** — Choose based on what the user asked:
   - **Current value or no time range specified:** `data = read(attr)` — returns the snapshot/current value of the attribute
   - **Historical data with time range:** `data = readHistory(attr, startTime, endTime, Interval=hours(1), AggregateFcn="average")`
   
   If the user says "get the value", "what is the current reading", or requests data without specifying a date range, use `read(attr)`.
8. **Verify** — Check that returned data has valid status (not all "Bad" or NaN)

## Key Functions

See [references/key-functions.md](references/key-functions.md) for the full function table, attribute properties, and return types.

## Patterns

### Discover Available AF Servers

```matlab
NET.addAssembly('OSIsoft.AFSDK');
ps = OSIsoft.AF.PISystems;
numServers = ps.Count;
if numServers == 0
    fprintf('No AF servers discovered on this machine.\n');
else
    fprintf('Available AF Servers:\n');
    for i = 0:numServers-1
        serverName = string(ps.Item(i).Name);
        desc = string(ps.Item(i).Description);
        fprintf('  %d. %s\n', i+1, serverName);
        if strlength(desc) > 0
            fprintf('     Description: %s\n', desc);
        end
    end
end
```

If `numServers == 0`, ask the user to provide the AF server name manually — no servers are discoverable on the host machine.

### Discover Available PI Data Archive Servers

```matlab
NET.addAssembly('OSIsoft.AFSDK');
piServers = OSIsoft.AF.PI.PIServers;
numServers = piServers.Count;
if numServers == 0
    fprintf('No PI Data Archive servers discovered on this machine.\n');
else
    fprintf('Available PI Data Archive Servers:\n');
    for i = 0:numServers-1
        serverName = string(piServers.Item(i).Name);
        desc = string(piServers.Item(i).Description);
        fprintf('  %d. %s\n', i+1, serverName);
        if strlength(desc) > 0
            fprintf('     Description: %s\n', desc);
        end
    end
end
```

If `numServers == 0`, ask the user to provide the PI Data Archive server name manually — no servers are discoverable on the host machine.

### Direct Tag Lookup by Name

```matlab
piObj = piclient('myPIServer');
tagList = tags(piObj, Name='GU1*');
disp(tagList)
```

`tags()` returns a table with a `Tags` column (string array). Extract a tag name with `tagList.Tags(N)` before passing to `read()`.

### Read Current Value from PI Tag

Use when the user asks for the current/snapshot value of a PI tag without specifying a time range.

```matlab
piObj = piclient('myPIServer');
tagList = tags(piObj, Name='GU1.Active Power*');
tagName = tagList.Tags(1);
data = read(piObj, tagName);
disp(data)
```

### Read Historical Data from PI Tag

```matlab
piObj = piclient('myPIServer');
tagList = tags(piObj, Name='GU1.Active Power*');
tagName = tagList.Tags(1);
startTime = datetime(2025, 1, 1);
endTime = datetime(2025, 2, 1);
data = read(piObj, tagName, DateRange=[startTime endTime], ...
    Interval=hours(1), AggregateFcn="average");
disp(data)
```

### AF Connection with Server and Database Clarification

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
fprintf('Connected to: %s\n', afObj.ServerName);
fprintf('Database: %s\n', afObj.Database);
```

### List Databases with Descriptions

Use after connecting to an AF server to present databases. `listDatabases` returns a **string array** of database names (no descriptions). To show descriptions alongside names, use the .NET SDK fallback below.

```matlab
afObj = afclient('myAFServer');
dbList = listDatabases(afObj);
fprintf('Available Databases on %s:\n', afObj.ServerName);
for i = 1:numel(dbList)
    fprintf('  %d. %s\n', i, dbList(i));
end
```

To retrieve descriptions (requires .NET AFSDK):

```matlab
NET.addAssembly('OSIsoft.AFSDK');
ps = OSIsoft.AF.PISystems;
afServer = ps.Item('myAFServer');
afServer.Connect();
fprintf('Available Databases on %s:\n', string(afServer.Name));
for i = 0:afServer.Databases.Count-1
    db = afServer.Databases.Item(i);
    dbName = string(db.Name);
    desc = string(db.Description);
    fprintf('  %d. %s\n', i+1, dbName);
    if strlength(desc) > 0
        fprintf('     Description: %s\n', desc);
    end
end
```

### Find Elements by Template

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
genUnits = findElementByTemplate(afObj, 'GenerationUnit');
disp(genUnits)
```

### Find Element with Wildcard and Confirm

Always wildcard the base identifier to discover parent and child elements. Present results for user confirmation — even when only one element is found.

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
results = findElementByName(afObj, 'GU1*');
fprintf('Found %d element(s) matching "GU1*":\n', numel(results));
for i = 1:numel(results)
    pathParts = split(results(i).Path, '\');
    hierarchy = strjoin(pathParts(4:end), '->');
    fprintf('  %d. %s  [Template: %s]  Path: %s\n', ...
        i, results(i).Name, results(i).Template, hierarchy);
    if strlength(results(i).Description) > 0
        fprintf('     Description: %s\n', results(i).Description);
    end
end
fprintf('Which element would you like to proceed with?\n');
```

After the user confirms (e.g., element 2 = "GU1 Generator"), get attributes with a wildcard and show metadata:

```matlab
selectedElem = results(2);
attrs = getAttributes(selectedElem, 'Active Power*');
fprintf('Matching attributes on "%s":\n', selectedElem.Name);
fprintf('  %-4s %-20s %-20s %-14s %-14s %-10s %s\n', ...
    '#', 'Name', 'Element', 'ServerDataType', 'Unit', 'TimeSeries', 'Description');
for i = 1:numel(attrs)
    desc = attrs(i).Description;
    if strlength(desc) == 0
        desc = "(none)";
    end
    fprintf('  %-4d %-20s %-20s %-14s %-14s %-10d %s\n', ...
        i, attrs(i).Name, attrs(i).ElementName, attrs(i).ServerDataType, ...
        attrs(i).DefaultUnit, attrs(i).HasTimeSeriesData, desc);
end
```

If only one attribute matches and it clearly corresponds to the user's request, proceed directly. If multiple attributes match or there is ambiguity (including multiple attributes with the same name from different elements), present the table above and ask the user to select. The `ElementName` and data type help distinguish identically-named attributes.

Note: Attribute names may differ between parent and child elements (e.g., `GU1` has "Active Power Generated" while `GU1 Generator` has "Active Power"). A wildcard query may also return the same attribute from multiple sibling elements (e.g., all generators in a wind farm). Use the `ElementName` column to disambiguate.

### Find Element by Name (Single Result)

Even when only one match is returned, present it for user confirmation before proceeding.

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
results = findElementByName(afObj, 'GU3 Turbine*');
fprintf('Found %d element(s) matching "GU3 Turbine*":\n', numel(results));
for i = 1:numel(results)
    pathParts = split(results(i).Path, '\');
    hierarchy = strjoin(pathParts(4:end), '->');
    fprintf('  %d. %s  [Template: %s]  Path: %s\n', ...
        i, results(i).Name, results(i).Template, hierarchy);
end
fprintf('Proceed with this element?\n');
```

After confirmation:

```matlab
elem = results(1);
attr = getAttributes(elem, 'Active Power');
fprintf('Name: %s\n', attr.Name);
fprintf('Unit: %s\n', attr.DefaultUnit);
fprintf('Has Time Series: %d\n', attr.HasTimeSeriesData);
```

### Read Current Value from AF Attribute

Use when the user asks for the current value, snapshot, or data without specifying a time range.

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
results = findElementByName(afObj, 'GU1*');
selectedElem = results(2);
attr = getAttributes(selectedElem, 'Active Power');
data = read(attr);
disp(data)
```

### Historical Data Read with Aggregation

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
elem = findElementByName(afObj, 'GU3 Turbine');
attr = getAttributes(elem, 'Cooling Water Output Temperature');

startTime = datetime(2025, 1, 1);
endTime = datetime(2025, 2, 1);
data = readHistory(attr, startTime, endTime, Interval=hours(1), AggregateFcn="average");
disp(data)
```

### Verify Data Quality

`readHistory` and `read` return a table with a `Status` column. Check for "Bad" status before using the values:

```matlab
badRows = data.Status == "Bad";
if all(badRows)
    warning('All returned data has "Bad" status — no valid values in this time range.');
elseif any(badRows)
    fprintf('%d of %d rows have "Bad" status.\n', sum(badRows), height(data));
end
```

**Value column types differ by source:**
- **AF** (`readHistory`, `read(attr)`): `Value` is a **cell array** — use `cell2mat(data.Value)` to extract numeric values, or index with `data.Value{i}`
- **PI Data Archive** (`read(piObj, tagName, DateRange=...)`): `Value` is a **double** array (direct numeric access)
- **PI Data Archive current** (`read(piObj, tagName)` without DateRange): `Value` is a **string** (e.g., `"Pt Created"` or the numeric value as text)

### Browse Hierarchy with getChildren

```matlab
afObj = afclient('myAFServer', Database='OSIDemo_PG_HydroPlant');
roots = getRootElements(afObj);
disp(roots)

children = getChildren(roots(1));
disp(children)
```

### Search for Element Across All Databases

Use when the user is unsure which database contains the element they are looking for.

```matlab
afObj = afclient('myAFServer');
dbList = listDatabases(afObj);
elementName = 'GU1';
foundIn = {};
for i = 1:numel(dbList)
    selectDatabase(afObj, dbList(i));
    results = findElementByName(afObj, elementName);
    if ~isempty(results)
        foundIn{end+1} = dbList(i); %#ok<SAGROW>
    end
end
if isempty(foundIn)
    fprintf('Element "%s" not found in any database.\n', elementName);
else
    fprintf('Element "%s" found in:\n', elementName);
    for i = 1:numel(foundIn)
        fprintf('  %d. %s\n', i, foundIn{i});
    end
end
```

If the element is found in multiple databases, present the list and ask the user to select the correct one. If not found in any database, ask the user to verify the element name.

## Conventions

- Always use `afclient` for Asset Framework access — never raw .NET `OSIsoft.AFSDK` interop (exception: server discovery via `OSIsoft.AF.PISystems` / `OSIsoft.AF.PI.PIServers` is acceptable)
- Always use `piclient` for PI Data Archive tag access — never raw .NET interop (exception: server discovery)
- **MUST present discovered servers to the user and ask them to select** — never auto-select, assume, or skip server selection. Do not proceed until the user confirms a server
- When presenting server or database lists, display descriptions alongside names when available (descriptions require .NET SDK fallback — `listDatabases` returns names only)
- **MUST present discovered databases to the user and ask them to select** — never auto-select, assume, or skip database selection (even if only one database exists). Do not proceed until the user confirms a database
- Never assume server name is `'localhost'` — ask the user to specify or select from available servers
- **MUST use string (double-quoted) for `findElementByPath` and `findAttributeByPath` path arguments** — char (single-quoted) silently fails. Write `findElementByPath(afObj, "\\server\db\path")`, NEVER `findElementByPath(afObj, '\\server\db\path')`
- Use `getAttributes(elem, 'name')` with the name filter — never retrieve all attributes and string-compare
- Use `findElementByTemplate` to find elements by type — never manually traverse the hierarchy comparing template names
- Always wildcard `findElementByName(afObj, 'baseIdentifier*')` to discover both parent and child elements — never search with an exact name only
- Always present element search results (Name, Template, Description, hierarchy path) for user confirmation before proceeding — even when only one element is found
- When multiple attributes match a wildcard or there is ambiguity, present a metadata table (Name, ElementName, ServerDataType, DefaultUnit, HasTimeSeriesData) and ask the user to select — if only one attribute clearly matches, proceed directly
- If the user asks for more hierarchy detail, use `getChildren(elem)` to show children of a specific element
- Use `read(attr)` or `read(piObj, tagName)` (without DateRange) when the user asks for "current value", "get the data", or any request without a time range — use `readHistory` or `read(..., DateRange=...)` only when a date range is specified
- Prefer `piclient` + `tags` when the user already knows the tag name — do not route through AF unnecessarily

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `NET.addAssembly('OSIsoft.AFSDK')` for data queries | Verbose, fragile, unnecessary — MATLAB wrappers exist | Use `afclient` or `piclient` (AFSDK is only acceptable for server discovery) |
| Using `piclient` for AF element queries | `piclient` is for PI Data Archive tags, not AF hierarchy | Use `afclient` for element/attribute navigation |
| Using `afclient` when user provides a tag name | AF navigation is overkill for direct tag lookup | Use `piclient` + `tags(..., Name=...)` |
| Assuming server is `'localhost'` | Server name varies by environment | Ask the user for the server name |
| Scanning all databases without asking the user first | Resource-intensive and slow on large systems | Ask the user first; only scan all databases if user is unsure |
| Retrieving all attributes then filtering by string | Inefficient for elements with many attributes | Use `getAttributes(elem, 'name')` with name filter |
| Manually traversing hierarchy to find elements by template | Slow and error-prone for deep hierarchies | Use `findElementByTemplate(afObj, 'templateName')` |
| Picking a `findElementByName` result without showing it to the user | Parent and child elements often share name prefixes (e.g., `GU1` vs `GU1 Generator`) — the first match may be the parent when the user means the child | Always wildcard search (`'GU1*'`), present all results with Template/Path/Description, and ask the user to confirm — even for single results |
| Proceeding to `readHistory` without confirming the attribute | Attribute names may differ across elements (e.g., "Active Power" vs "Active Power Generated") and wildcard may return multiple matches — or multiple sibling elements may share the same attribute name (e.g., all generators in a wind farm) | When multiple attributes match or there is ambiguity, show metadata (Name, ElementName, ServerDataType, Unit, HasTimeSeriesData, Description) and ask user to select |
| Using `readHistory` when user asks for current value | `readHistory` requires a time range — overkill for a snapshot value | Use `read(attr)` for AF attributes or `read(piObj, tagName)` without DateRange for PI tags; reserve `readHistory`/DateRange for historical queries |
| Using char (single-quoted) paths with `findElementByPath` or `findAttributeByPath` | These functions silently fail with char inputs — returns "Unable to find" error even when the path is correct | Always use string (double-quoted): `findElementByPath(afObj, "\\server\db\path")` |
| Treating `listDatabases` result as a struct (e.g., `dbList(i).Name`) | `listDatabases` returns a **string array**, not a struct — accessing `.Name` errors | Use `dbList(i)` directly: it's already a string. Pass to `selectDatabase(afObj, dbList(i))` |
| Using `attrs(i).DataType` on attributes | Property does not exist on `icomm.af.Attribute` — errors at runtime | Use `attrs(i).ServerDataType` for the data type string |
| Using `data.Value` directly for math on AF results | AF `readHistory`/`read(attr)` returns Value as a **cell array** — arithmetic fails | Use `cell2mat(data.Value)` to extract numeric values from AF data |

----

Copyright 2026 The MathWorks, Inc.

----
