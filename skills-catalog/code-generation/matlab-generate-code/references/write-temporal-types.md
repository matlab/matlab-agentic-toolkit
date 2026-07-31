# Temporal Types: datetime, duration, and timetable

Codegen support for MATLAB temporal types. Metadata (time zones, units, variable names) doesn't map to C/C++, but numeric operations are fully supported.

## Support Summary

| Type | Entry-Point Input | Class Property | Arithmetic | Comparison | Conversion to double |
|------|------------------|----------------|-----------|------------|---------------------|
| `datetime` | Yes | Yes | Yes (+, -) | Yes (<, >, ==) | `posixtime(dt)`, `datenum(dt)` |
| `duration` | Yes | Yes | Yes (+, -, *, /) | Yes (<, >, ==) | `seconds(d)`, `minutes(d)`, `hours(d)` |
| `timetable` | Yes | No | No (operate on variables) | No | Extract with `{:,idx}` or dot notation |

## duration — Full Support

### Supported operations

- Construction: `seconds(x)`, `minutes(x)`, `hours(x)`, `days(x)`
- Arithmetic: `d1 + d2`, `d1 - d2`, `d * scalar`, `d / scalar`, `d1 / d2`
- Comparison: `d1 < d2`, `d1 == d2`
- Conversion: `seconds(d)` → double
- `ceil`, `floor`, `round` on durations
- As class property with typed default

### Example

```matlab
function windowSamples = durToSamples(samplePeriod, windowDur) %#codegen
    arguments
        samplePeriod (1,1) duration
        windowDur (1,1) duration
    end
    windowSamples = ceil(windowDur / samplePeriod);
end
```

## datetime — Full Support

### Supported operations

- Construction: `datetime(Y,M,D)`, `datetime(Y,M,D,H,MI,S)`
- Arithmetic: `dt + duration`, `dt - dt` (returns duration)
- Comparison: `dt1 < dt2`, `dt1 == dt2`
- Extraction: `year(dt)`, `month(dt)`, `day(dt)`, `hour(dt)`, `minute(dt)`, `second(dt)`
- Conversion: `posixtime(dt)` → double
- `dateshift`, `between`

### Example

```matlab
function elapsed = timeSinceRef(t, refTime) %#codegen
    arguments
        t (1,1) datetime
        refTime (1,1) datetime
    end
    elapsed = seconds(t - refTime);
end
```

## timetable — Extensive Support with Constraints

Construction, indexing, and table operations are supported. Requires explicit metadata at creation; no dynamic resizing or post-creation property changes.

### Constructor Requirements

When creating a timetable in generated code, you **must** supply both `'RowTimes'` and `'VariableNames'` name-value arguments:

```matlab
TT = timetable(A, B, C, 'RowTimes', rtimes, 'VariableNames', {'VarA','VarB','VarC'});
```

Row times must be `datetime` or `duration` values. The first dimension name defaults to `'Time'` unless specified via `'DimensionNames'`.

**Exception:** `'VariableNames'` is not required when preallocating with the `'Size'` name-value argument.

#### Preallocated timetables

When using `'Size'`, `'VariableTypes'` is restricted to: `'double'`, `'single'`, `'doubleNaN'`, `'singleNaN'`, `'int8'`, `'int16'`, `'int32'`, `'int64'`, `'uint8'`, `'uint16'`, `'uint32'`, `'uint64'`, `'logical'`, `'datetime'`, `'duration'`, `'cellstr'`, `'char'`.

#### Regular timetables

To create a regular timetable when `'SampleRate'`, `'StartTime'`, or `'TimeStep'` are passed via entry-point input, use `coder.Constant` to make those values constant; otherwise row times are treated as irregular.

### Indexing

- **Parentheses `()`** — returns a subtable
- **Curly braces `{}`** — extracts contents as arrays
- **Dot notation** — access a variable by name
- Supports position, variable name, row time, logical, `timerange`, and `withtol` indexing

**Key constraint:** Variable indices (second dimension) passed as entry-point inputs must be compile-time constants — use `coder.Constant`.

**Note:** Indexing a regular timetable with `duration` or `timerange`/`withtol` objects makes the output irregular.

### Modification Restrictions

After creation, you **cannot**:

- Change `VariableNames`, `DimensionNames`, or `UserData` properties
- Access the `VariableTypes` property
- Add custom metadata (`addprop` / `rmprop` not supported)
- Change the size of a timetable by assignment (no adding/deleting rows or variables via `=`)

**Silent failure:** Assigning a new row via a new row time does not error but silently fails to add the row.

### Concatenation Rules

| Direction | Requirement |
|-----------|-------------|
| Vertical (`vertcat`) | Timetables must have variables with the same names in the same order |
| Horizontal (`horzcat`) | Timetables must have the same number of rows and the same row times in the same order |

N-D cell array variables cannot be vertically concatenated, and curly-brace extraction across multiple N-D cell array variables is not supported.

### Function-Specific Limitations

#### `retime` and `synchronize`

- Output row times are always considered irregular (even when synchronized to regular time steps)
- `'makima'` interpolation method not supported
- `'weekly'`, `'monthly'`, and `'quarterly'` time steps not supported
- For `datetime` row times, `'daily'` and `'yearly'` time steps also not supported
- If `VariableContinuity` properties of inputs are not constant, they are ignored

#### `convertvars`

- Function handles not supported as conversion target
- Second and third inputs (`vars` and `dataType`) must be constant
- Cannot specify `dataType` as `'cell'`, `'cellstr'`, or `'char'`

#### `innerjoin` / `join` / `outerjoin`

- Input timetables generally cannot have nonkey variables with the same names (unless using `'LeftVariables'`/`'RightVariables'` to avoid overlap)
- `'Keys'`, `'LeftKeys'`, `'RightKeys'`, `'LeftVariables'`, `'RightVariables'` must be constant
- Nested timetables not supported
- For `outerjoin`: key variables cannot share names unless `'MergeKeys'` is `true`

#### `sortrows` / `issortedrows`

- Input `vars` must be constant
- Multi-column timetable variables must have fixed widths (for `issortedrows`)

#### `isregular`

- `timeComponent` input must be constant via `coder.Constant`
- `timeComponent` cannot be a calendar unit; if specified, must be `'time'`

#### `varfun`

- Function handle `func` must be constant (can be input to `varfun` but not to the entry-point function)
- All name-value argument values must be constant
- `'ErrorHandler'` not supported
- Variable-size input arguments not supported
- `'GroupingVariables'` always produces irregular output; grouping variables cannot have duplicate values

#### `stack` / `unstack`

- `vars` input must be constant
- For `unstack`: `'NewDataVariableNames'` must be specified and constant

#### `splitvars`

- `'NewVariableNames'` must be constant
- Variables being split cannot have a variable number of columns

#### `timerange` / `withtol`

- `datetimeUnit` input not supported
- Event filters not supported

### Example

```matlab
function TT = buildTimetable(data, timestamps) %#codegen
    arguments
        data (:,3) double
        timestamps (:,1) duration
    end
    A = data(:,1);
    B = data(:,2);
    C = data(:,3);
    TT = timetable(A, B, C, ...
        'RowTimes', timestamps, ...
        'VariableNames', {'Pressure','Temperature','Flow'});
end
```

### Early Conversion Pattern

Extract numeric data at entry point when downstream code doesn't need the timetable:

```matlab
function [psd, freq] = mySpectralFunc(tt) %#codegen
    arguments
        tt timetable
    end
    data = tt{:, 1};
    dt = seconds(tt.Properties.RowTimes(2) - tt.Properties.RowTimes(1));
    fs = 1 / dt;
    [psd, freq] = computePSD(data, fs);
end
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Removing `duration` inputs "for codegen" | Keep them — `duration` is fully supported |
| Removing `datetime` properties from class | Keep them — `datetime` is fully supported |
| Creating timetable without `'VariableNames'` | Always specify `'VariableNames'` (and `'RowTimes'`) in the constructor |
| Trying to add/delete rows or variables via assignment | Use supported functions (`addvars`, `removevars`) or rebuild the timetable |
| Modifying `VariableNames` after creation | Set names at construction time; they are immutable in generated code |
| Passing variable index as runtime value | Use `coder.Constant` for variable (column) indices from entry-point inputs |
| Using `'makima'` with `retime`/`synchronize` | Use `'linear'`, `'nearest'`, `'previous'`, `'next'`, or `'spline'` instead |
| Using `'weekly'`/`'monthly'`/`'quarterly'` time steps | Use explicit `duration` time steps instead |
| Converting `duration` to `double` unnecessarily | Use `duration` directly — arithmetic is supported |
| Assuming temporal types need `coder.extrinsic` | They don't — they are natively supported |
| Expecting `retime`/`synchronize` output to be regular | Output is always irregular in generated code; check `isregular` if needed |

----

Copyright 2026 The MathWorks, Inc.

----
