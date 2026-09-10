# LSEG Datastream Web Services (datastreamws) in Datafeed Toolbox

Connect to LSEG Datastream Web Services and retrieve historical financial data. Available since R2018b.

## Connection

```matlab
c = datastreamws(getSecret("datastreamwsUser"), getSecret("datastreamwsPassword"));
```

## Properties

| Property | Description | Default |
|----------|-------------|---------|
| `UserName` | Datastream user name used to connect | Value passed to constructor |
| `TimeOut` | Request timeout in milliseconds | 100 |

```matlab
c.TimeOut = 200;
```

## history — The Only Retrieval Method

`history` is the sole data retrieval method. Do NOT use `fetch` (that belongs to fredrs/haver).

### Calling Forms

| Form | Syntax | Behavior |
|------|--------|----------|
| Full | `history(c, sec, fields, startDate, endDate, freq)` | Time series with specified periodicity |
| Minimal | `history(c, sec)` | All available data for the security |
| Snapshot | `history(c, sec, fields, date)` | Single-date cross-section (4 args triggers Kind=0) |

### Full Form

```matlab
data = history(c, "VOD", "P", "01/01/2023", "12/31/2023", "D");
```

### Minimal Form — All Available Data

```matlab
data = history(c, "VOD");
```

### Snapshot Form (4 Arguments)

When exactly 4 arguments are passed (connection, security, fields, date), the request is a snapshot — a single-date retrieval across multiple fields:

```matlab
data = history(c, "VOD", ["PO"; "PH"; "PL"; "P"], "2024-06-15");
```

### Multiple Securities

```matlab
securities = {"MKS", "BARC", "BP.", "BA."};
data = history(c, securities, "P", startDate, endDate, "Q");
```

### Second Output — Raw Response

```matlab
[data, response] = history(c, securities, fields, startDate, endDate, "D");
```

## Output

`history` always returns a timetable — for single securities, multiple securities, and error conditions.

## Date Handling

### Absolute Dates

String, datetime, and datenum are all accepted:

```matlab
history(c, "VOD", "P", "01/01/2023", "12/31/2023", "D")
history(c, "VOD", "P", datetime(2023,1,1), datetime(2023,12,31), "D")
```

### Relative Dates

Relative date strings pass through to the Datastream server:

| Syntax | Meaning |
|--------|---------|
| `-1Y` | One year ago |
| `-6M` | Six months ago |
| `-0D` | Today |

```matlab
data = history(c, "VOD", "P", "-1Y", "-0D", "D");
```

### Special Date Keywords

| Keyword | Meaning |
|---------|---------|
| `BDATE` | Base date (server-defined) |
| `TIME` | Current server time |

These are accepted as date arguments and interpreted server-side.

## Periodicity

| Code | Frequency |
|------|-----------|
| `"D"` | Daily |
| `"W"` | Weekly |
| `"M"` | Monthly |
| `"Q"` | Quarterly |
| `"Y"` | Yearly |

## Datastream Expressions

Use `IsExpression` and `IsSymbolSet` flags for computed expressions instead of plain securities:

```matlab
exprs = ["PCH#(ALD,1D)", "PCH#(BARC,1D)", "PCH#(BP.,1D)"];
data = history(c, exprs, "", startDate, endDate, "D", ...
    "IsExpression", "true", "IsSymbolSet", "true");
```

- Pass empty string `""` for fields — the expression encodes the computation
- `IsExpression` — securities are Datastream expressions, not instrument codes
- `IsSymbolSet` — input is a set of individual expressions, not a list name

---

Copyright 2026 The MathWorks, Inc.
