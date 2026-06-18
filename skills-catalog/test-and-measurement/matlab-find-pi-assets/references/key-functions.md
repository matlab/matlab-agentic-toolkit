# Key Functions Reference

## PI Asset Identification Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `OSIsoft.AF.PISystems` | Enumerate available AF servers (via .NET AFSDK) | .NET interop |
| `OSIsoft.AF.PI.PIServers` | Enumerate available PI Data Archive servers (via .NET AFSDK) | .NET interop |
| `piclient` | Connect to PI Data Archive server | Industrial Communication Toolbox |
| `tags` | Search for PI tags by name pattern | Industrial Communication Toolbox |
| `read` (piclient) | Read data from PI Data Archive tags (supports DateRange, Interval, AggregateFcn) | Industrial Communication Toolbox |
| `afclient` | Connect to PI Asset Framework server | Industrial Communication Toolbox |
| `listDatabases` | List available databases on connected AF server (returns string array) | Industrial Communication Toolbox |
| `selectDatabase` | Switch AF client to a specified database | Industrial Communication Toolbox |
| `findElementByName` | Find AF elements by name (supports wildcards) | Industrial Communication Toolbox |
| `findElementByTemplate` | Find all elements of a given template | Industrial Communication Toolbox |
| `findElementByPath` | Find AF element by full path (must use string, not char) | Industrial Communication Toolbox |
| `findAttributeByPath` | Find AF attribute by full path (must use string, not char) | Industrial Communication Toolbox |
| `getAttributes` | Get attributes of an element (with optional name filter) | Industrial Communication Toolbox |
| `getChildren` | Get child elements of an element | Industrial Communication Toolbox |
| `getRootElements` | Get top-level elements in the database | Industrial Communication Toolbox |
| `read` (AF attribute) | Read current/snapshot value from an AF attribute | Industrial Communication Toolbox |
| `readHistory` | Read historical time-series data from AF attributes | Industrial Communication Toolbox |

## Attribute Properties (`icomm.af.Attribute`)

| Property | Type | Description |
|----------|------|-------------|
| `Name` | string | Attribute name |
| `Path` | string | Full path (`\\server\database\...\element|attribute`) |
| `Description` | string | Human-readable description |
| `ElementName` | string | Name of the parent element |
| `ServerDataType` | string | Data type (e.g., "Double", "String", "Int32") |
| `DefaultUnit` | string | Engineering unit (e.g., "degree Celsius", "MW") |
| `HasTimeSeriesData` | logical | Whether the attribute has time-series data |
| `ReadAccess` | logical | Whether attribute is readable |
| `WriteAccess` | logical | Whether attribute is writable |
| `Categories` | string | Semicolon-separated category list |

## Return Types

| Function | Returns | Value Column |
|----------|---------|-------------|
| `read(piObj, tagName)` (no DateRange) | timetable | string |
| `read(piObj, tagName, DateRange=...)` | timetable | double |
| `read(attr)` | table | cell (string or numeric inside) |
| `readHistory(attr, ...)` | timetable | cell (numeric inside — use `cell2mat`) |
| `tags(piObj, Name=...)` | table | Tags column is string array |
| `listDatabases(afObj)` | string array | N/A |
| `findElementByName(afObj, ...)` | Element array | N/A |
| `findElementByTemplate(afObj, ...)` | Element array | N/A |
| `getAttributes(elem, ...)` | Attribute array | N/A |

----

Copyright 2026 The MathWorks, Inc.

----
