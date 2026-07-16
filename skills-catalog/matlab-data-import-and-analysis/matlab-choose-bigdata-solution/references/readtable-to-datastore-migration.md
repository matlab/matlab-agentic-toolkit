# Migrating readtable to tabularTextDatastore

`tabularTextDatastore` uses a textscan-based parser that is stricter and less
forgiving than `readtable`. When migrating code that works on small data, watch
for these differences.

## Property Mapping

Common `readtable` options and their datastore equivalents:

| `readtable` option | `tabularTextDatastore` equivalent | Notes |
|--------------------|-----------------------------------|-------|
| `TextType="string"` | `TextType="string"` | Must set at **creation time** — read-only after construction |
| `Delimiter` | `ds.Delimiter` | Writable after creation |
| `NumHeaderLines` | `ds.NumHeaderLines` | Writable after creation |
| `TreatAsMissing` | `ds.TreatAsMissing` | Writable after creation |
| `DateLocale` | `ds.DatetimeLocale` | Writable after creation |
| `opts.SelectedVariableNames` | `ds.SelectedVariableNames` | Writable after creation |
| `setvartype(opts, var, type)` | `ds.TextscanFormats{col}` | See format specifiers below |
| `TrimNonNumeric` | **Not supported** | See "Numbers with units" below |
| `ExtraColumnsRule` | **Not applicable** | See "Extra columns" below |
| `detectImportOptions` | Not used — datastore auto-detects | Configure via properties instead |

## Type Overrides via TextscanFormats

The `setvartype` idiom from import options maps to textscan format specifiers:

| readtable type | TextscanFormats specifier |
|---------------|---------------------------|
| `"double"` | `%f` |
| `"char"` / `"string"` | `%q` (reads as cell of char or string depending on TextType) |
| `"datetime"` | `%{dd-MMM-uuuu}D` (format inside braces) |
| `"duration"` | `%T` |
| `"categorical"` | `%C` |
| `"logical"` | **No equivalent** — read as `%q`, convert to logical after reading |

```matlab
% Override a column type (e.g., force column 3 to categorical):
ds = tabularTextDatastore("data.csv", TextType="string");
ds.TextscanFormats{3} = '%C';
```

## Numbers with Units (TrimNonNumeric)

`readtable` with `TrimNonNumeric` can parse "34mm" as 34.
`tabularTextDatastore` cannot. Workaround: use `%q` to read the column as text,
then convert to numeric in a transform function or on the tall array, depending
on which workflow from this skill is being used. This handles mixed columns
(some values with units, some without) correctly because `%q` reads all values
as plain text regardless of content.

## Missing or Malformed Data

`readtable` silently inserts `NaN` or `missing` for unparseable values.
`tabularTextDatastore` with `%f` errors on non-numeric content.

Workaround: read the column as `%q` (text), then convert with `str2double` or
`double(string(...))` — either in a transform function or on the tall array.
This avoids the parse error but hurts performance due to the string-to-number
conversion.

## Extra Columns

`readtable` has `ExtraColumnsRule` to handle rows with more columns than the
header. `tabularTextDatastore` has no equivalent and will error.

Workaround: append `"%*[^\r\n]"` to `TextscanFormats` at creation time — this
reads and discards all characters to the end of the line, ignoring extra columns.
The `*` means "ignore," which deselects the extra content from
`SelectedVariableNames`. This requires `ReadVariableNames=false` and
`NumHeaderLines` set manually so the datastore does not infer column count from
the header:

```matlab
ds = tabularTextDatastore("data.csv", TextType="string", ...
    ReadVariableNames=false, NumHeaderLines=1, ...
    TextscanFormats={'%q', '%f', '%*[^\r\n]'});
```

This approach works when extra columns are consistently present across rows. For
files where the number of columns varies unpredictably between rows, a custom
datastore or preprocessing step is required.

----

Copyright 2026 The MathWorks, Inc.

----
