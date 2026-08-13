---
name: matlab-import-export-data
description: >
  Read or write data files in MATLAB. Use when the task involves tables,
  spreadsheets, delimited text, or structured files in CSV, Excel, Parquet,
  JSON, or XML format — including but not limited to importing, exporting,
  loading, parsing, converting, validating, configuring import options,
  reading from URLs, handling locales or encodings, diagnosing file errors,
  and modernizing legacy file I/O code. MATLAB provides built-in functions
  for these workflows with no additional products required.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Data Import/Export

Guidance for MATLAB data I/O — correct patterns for delimiters, locales, format-specific quirks, and common error messages.

## When to Use

- Reading or writing CSV, Excel, Parquet, or JSON files in MATLAB with `readtable`/`writetable`/`detectImportOptions`
- Troubleshooting data I/O errors (misleading messages, "file not found" variants)
- Reading data from URLs or authenticated REST API endpoints
- Importing non-English locale data (European decimals, semicolons)
- Validating imported data for silent corruption (NaN, 65535, type widening)
- Reading compressed files or JSON with non-identifier keys
- Reading or writing text files (use `readlines`/`writelines`, not `fopen`/`fgetl`/`fprintf`)
- Reading or writing XML files (use MAXP provider, not legacy JAXP)

## When NOT to Use

- Large files that may not fit in memory, or choosing between tall arrays, datastores, and parallel workflows (use `matlab-choose-big-data-solution` skill)
- Database access via ODBC/JDBC — reading, writing, or querying relational databases (use `matlab-use-database` skill)
- SQL-based queries on large CSV/Parquet/JSON files for reduction before analysis (use `matlab-use-duckdb` skill)
- Vehicle data from MDF/MF4/BLF/ASC log files or CAN/LIN bus decoding (use `matlab-import-export-vehicle-data` skill)
- Vehicle network communication setup with CAN/CAN FD/J1939 (use `matlab-use-vehicle-network` skill)
- Tracking data import for sensor fusion workflows (use `matlab-import-tracking-data` skill)
- Medical image data — DICOM, NIfTI, or Analyze formats (use `matlab-read-medical-data` skill)
- Market or financial data feeds (use `matlab-access-datafeed` skill)
- Simulink data logging or signal I/O (use Simulink-specific workflows)
- Image or audio file I/O (`imread`, `audioread` — different domain)
- Streaming or real-time data acquisition (use Data Acquisition Toolbox)
- File system operations, path manipulation, or folder traversal

## General principles

- **Validate after import.** Append 2-3 assertion-style checks that verify the imported data matches expectations.
- **Always set `TextType="string"` for text and Excel imports** — the `string` type is more efficient and easier to work with than char or cell arrays of character vectors. This only needs to be set for delimited text and spreadsheet formats; XML, JSON, and other formats already return strings by default.
- **Specify `FileType` when reading from URLs that lack a recognizable extension** — MIME type detection handles some cases, but API endpoints and non-standard URLs still need explicit format (see Topic 4). When using `detectImportOptions` with `readtable`, pass `FileType` on `detectImportOptions` — `readtable` does not accept `FileType` when an import options object is provided.
- **Handle missing value placeholders at read time** — use `TreatAsMissing` on `readtable` instead of calling `standardizeMissing` after import.
- **Read directly from compressed files** — `readtable`, `readmatrix`, `readtimetable`, and other read functions accept ZIP, GZ, and TAR file paths directly without manual extraction (R2025a+).
- **European CSVs use `;` as delimiter because `,` is the decimal separator** — set both `Delimiter` and `DecimalSeparator` when contextual cues suggest European-format data.

## Topics

### 1. Import Function Selection (Delimiter & Locale Handling)

When contextual cues suggest European-format data (German/French/Italian offices, semicolon-delimited files, column names in a European language), proactively set `Delimiter`, `DecimalSeparator`, and `Encoding` (UTF-8 for umlauts/accents):

```matlab
opts = detectImportOptions("messdaten.csv", ...
    "Delimiter", ";", "DecimalSeparator", ",", "Encoding", "UTF-8");
T = readtable("messdaten.csv", opts);
```

For files containing path-like data (`/data/exp_01/run_003/results.mat`), explicitly set the actual delimiter — detection may pick `/` from the path column:

```matlab
opts = detectImportOptions("fileList.csv");
opts.Delimiter = ",";
T = readtable("fileList.csv", opts);
```

For numeric data with embedded unit suffixes (e.g., `6.53e+001dB`, `-9.00e+001°`), use `TrimNonNumeric` (R2022a+) to strip non-numeric characters instead of `textscan` or `regexp`:

```matlab
T = readtable("circuit_output.txt", "Delimiter", {"\t", ","}, ...
    "NumHeaderLines", 1, "TrimNonNumeric", true);
```

`TrimNonNumeric` can be passed directly to `readtable` as a name-value pair, or set per-variable via `setvaropts(opts, vars, "TrimNonNumeric", true)` when only specific columns have suffixes.

---

### 2. Error Message Interpretation

MATLAB I/O error messages can be broad, pointing to a general category rather than the specific issue:

| Error Message | Likely Actual Cause | Recovery |
|--------------|-------------------|----------|
| `"Entry may be password-protected or encrypted"` | Disk space insufficient in temp directory for unzip (observed in R2020a–R2023b) | Check available space with `tempdir`; free space or redirect temp |
| `"Unrecognized file extension"` | URL lacks a recognizable file extension | Specify `FileType` name-value pair explicitly (see Topic 4) |

---

### 3. Import Validation & Data Fidelity

After importing from Excel or Parquet, check for silent data corruption:

- **Excel `Inf` → 65535**: Both `Inf` and `-Inf` are written as 65535. Values of exactly 65535 that seem physically implausible likely represent Inf.
- **Excel complex → NaN**: Excel cannot store complex numbers. An entirely NaN column from a spreadsheet may contain complex data in the source.
- **Parquet integer columns with nulls → silent type promotion**: When any integer column (int8/16/32/64, uint8/16/32/64) contains null values, `parquetread` promotes it to `double` (MATLAB integer types have no missing representation). For int64/uint64, values above 2^53 silently lose precision. Detect by comparing `parquetinfo` schema against `class(T.col)`. Workaround: use `parquetDatastore` with `ReadSize="file"` and `readall`, which preserves integer types and imports nulls as 0. Without nulls, all integer types round-trip through `parquetread` exactly.

- **Excel merged cells → unexpected values**: Merged cells silently produce duplicated values or missing data. Use `MergedCellColumnRule` and `MergedCellRowRule` to control interpretation:

```matlab
T = readtable("report.xlsx", ...
    "MergedCellColumnRule", "placeleft", "MergedCellRowRule", "placetop");
```

Mitigation: split complex into real/imag columns before writing to Excel.

```matlab
% Spreadsheet: check for Inf→65535 and complex→NaN
for i = 1:width(T)
    col = T.(T.Properties.VariableNames{i});
    if isnumeric(col) && all(isnan(col)) && height(T) > 0
        warning('Column "%s" is all-NaN — may contain complex numbers', ...
            T.Properties.VariableNames{i});
    end
    if isnumeric(col) && any(col == 65535)
        warning('Column "%s" contains 65535 — may represent Inf from Excel', ...
            T.Properties.VariableNames{i});
    end
end
```

```matlab
% Parquet: detect null-triggered int64/uint64→double promotion (precision loss)
info = parquetinfo("data.parquet");
T = parquetread("data.parquet");
for i = 1:numel(info.VariableNames)
    if ismember(info.VariableTypes(i), ["int64","uint64"]) && isa(T.(info.VariableNames(i)), "double")
        warning('Column "%s" is %s in schema but double after read (nulls caused promotion)', ...
            info.VariableNames(i), info.VariableTypes(i));
    end
end
```

```matlab
% Workaround: parquetDatastore preserves integer types (nulls become 0)
pds = parquetDatastore("data.parquet", "ReadSize", "file");
T = readall(pds);
```

When filtering Parquet data, use `rowfilter` (R2022a+) to push predicates into the read — this avoids loading unwanted rows into memory:

```matlab
rf = rowfilter(["status", "age"]);
rf = rf.status == "active" & rf.age >= 18;
T = parquetread("users.parquet", "RowFilter", rf);
```

---

### 4. Reading from URLs & REST APIs

Always specify `FileType` explicitly — MATLAB cannot infer format from API endpoints:

```matlab
T = readtable("https://example.com/api/v2/export/measurements", "FileType", "text");
```

For authenticated endpoints, use `weboptions`:

```matlab
opts = weboptions("Timeout", 30, ...
    "HeaderFields", {"Authorization", "Bearer " + token});
diopts = detectImportOptions(url, "WebOptions", opts);
T = readtable(url, diopts);
```

---

### 5. Readtable/Writetable Patterns

**Prefer `TextType` and `TreatAsMissing` at read time** instead of post-import `convertvars`/`standardizeMissing`:
```matlab
T = readtable("data.csv", "TextType", "string", "TreatAsMissing", "not applicable");
```

**Use `readtimetable`** (R2019a+) **for time-series data** — it creates a timetable directly with row times, avoiding a separate `table2timetable` conversion:
```matlab
TT = readtimetable("sensor_log.csv", "RowTimes", "timestamp");
```

**Read tabular JSON directly with `readtable`** (R2026a+) — for JSON files with tabular structure, use `FileType="json"` instead of manually parsing with `jsondecode`:
```matlab
T = readtable("data.json", "FileType", "json");
```

**Read directly from compressed archives** without manual extraction (R2025a+):
```matlab
T = readtable("data.csv.gz");
T = readtable("archive.zip/folder/data.csv");
```

**Control error handling at import** with `MissingRule` and `ImportErrorRule` (R2020b+) to fail fast or omit bad rows instead of silently filling with NaN:
```matlab
T = readtable("data.csv", "MissingRule", "error");
T = readtable("data.csv", "ImportErrorRule", "omitrow");
```

**Use `struct2table` + `writetable` to export structs to CSV** — do not write manual field-expansion loops:
```matlab
T = struct2table(data.Results);
writetable(T, "results.csv");
```
`writetable` automatically expands vector-valued fields into numbered columns (e.g., `MemSet_1`, `MemSet_2`). For JSON/XML output, use `writestruct` instead (see Topic 9).

**Use `writecell` for cell array export** (R2019a+) — do not convert to table first:
```matlab
writecell(results, "output.csv");
```

**Read tabular XML directly with `readtable`** — for XML files with repeating elements that map to rows, use `readtable` with `RowNodeName` and optionally `TableNodeName` instead of manual DOM parsing:
```matlab
T = readtable("measurements.xml", ...
    "TableNodeName", "measurements", "RowNodeName", "measurement");
```

---

### 6. Text File I/O: readlines/writelines over fopen patterns (R2020b+)

**Prefer `readlines`/`writelines` for simple text file I/O** — avoid `fopen`/`fgetl`/`fprintf`/`fclose` when reading or writing entire files as string arrays:

```matlab
% Reading: readlines returns a string array — no file handles needed
lines = readlines("config.txt");
matches = lines(contains(lines, "keyword"));
```

```matlab
% Writing: writelines handles string arrays directly
messages = ["Starting process"; "Step 1 complete"; "Done"];
writelines(messages, "output.log");
```

```matlab
% Line-by-line processing: read all then operate vectorially
lines = readlines("events.log");
lines = lines(lines ~= "");  % remove empties
parts = split(lines, "|");   % vectorized split
timestamps = parts(:,1);
levels = parts(:,2);
```

The `fopen`/`fgetl` loop pattern is legacy — `readlines` is simpler, handles empty files gracefully, and enables vectorized string operations on the entire file at once.

---

### 7. XML I/O: MAXP over JAXP

**Use the MAXP provider** (R2024b+) for all XML operations — it is pure MATLAB and does not require Java:

```matlab
% Reading XML with MAXP
import matlab.io.xml.dom.*
doc = parseFile(Parser, "settings.xml");
params = getElementsByTagName(doc, "parameter");
for i = 1:params.Length
    node = params.item(i);
    name = getAttribute(node, "name");
    value = getAttribute(node, "value");
end
```

```matlab
% Writing XML with MAXP
import matlab.io.xml.dom.*
doc = Document("testResults");
root = getDocumentElement(doc);
for i = 1:height(T)
    tc = createElement(doc, "testcase");
    setAttribute(tc, "name", T.test_name(i));
    setAttribute(tc, "status", T.status(i));
    appendChild(root, tc);
end
xmlwrite("results.xml", doc);
```

**Do NOT use** the legacy JAXP interface (`com.mathworks.xml.XMLUtils.createDocument`, `getElementsByTagName` on Java DOM objects, `getAttribute` with 0-based `item()` indexing). MAXP is pure MATLAB and does not require Java.

---

### 8. JSON with Non-Identifier Keys (R2024b+)

When JSON keys contain spaces, hyphens, or other characters invalid as MATLAB identifiers, use `dictionary` instead of `struct`:

```matlab
d = readdictionary("config.json");
val = d("my-custom-key");
d("new key with spaces") = 42;
writedictionary(d, "config.json");
```

`jsondecode` converts such keys to valid identifiers (e.g., `my_custom_key`), losing the original key names on round-trip. `readdictionary`/`writedictionary` preserve keys exactly.

---

### 9. Struct I/O: readstruct/writestruct over jsondecode/xmlread (R2020b+ XML, R2023b+ JSON)

**Use `readstruct`/`writestruct` for struct-based file I/O** — do not use `fileread`+`jsondecode` or `xmlread`+DOM traversal when the goal is a struct:

```matlab
% Reading JSON into a struct
config = readstruct("app_config.json");
host = config.database.host;
```

```matlab
% Writing a struct to JSON
writestruct(config, "output_config.json");
```

```matlab
% Reading XML into a struct
params = readstruct("device_config.xml");
rate = params.sensor.rate;
```

```matlab
% Writing a struct to XML
writestruct(params, "params.xml");
```

`readstruct`/`writestruct` handle JSON and XML in one call, preserving nested field structure. Avoid the legacy patterns: `fileread`+`jsondecode`/`jsonencode`+`fopen`+`fwrite` for JSON, or `xmlread`+`getElementsByTagName`+`getAttribute` for XML.

----

Copyright 2026 The MathWorks, Inc.
