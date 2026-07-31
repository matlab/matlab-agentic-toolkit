# MDF Writing Reference

Detailed patterns and examples for writing MATLAB timetable data to MDF/MF4 files using `mdfWrite`.

Key points:
- File is created automatically if it does not exist (warning issued).
- Each call without `GroupNumber` appends a new channel group -- repeated calls on the same file add more groups.
- `GroupNumber=N` overwrites the data in group N (must read with `IncludeMetadata=true` first).
- File format depends on the extension: `.mf4` writes MDF v4.x, `.mdf` writes MDF v3.x, `.dat` writes MDF v3.x.

## Creating MDF Files with Header Metadata

To set file-level metadata during creation, use `mdfCreate` with `FileInfo` parameter (not `mdfWrite`):

```matlab
minfo = mdfInfo;
minfo.Author = 'John Doe';
minfo.Department = 'Engineering';
minfo.Project = 'Vehicle Telemetry';
minfo.Comment = 'Test data from 2026-06-23';
mdfCreate('vehicle_data.mf4', FileInfo=minfo);
mdfWrite('vehicle_data.mf4', timetable(seconds(0:0.1:10)', rand(101,1)*100));
```

**Note:** `mdfWrite` alone cannot set metadata on new files. Supported fields: Author, Department, Project, Subject, Comment, Version.

## Type Compatibility

**Supported types:** `double`, `single`, `int8`-`int64`, `uint8`-`uint32`, `string`. Write these directly.

### Unsupported types (must convert before writing)

| Type | Error | Workaround |
|------|-------|-----------|
| `logical` | "unexpected type" | `uint8(logicalVar)` |
| `categorical` | "unexpected type" | `double(catVar)` -- stores category index (1,2,3...) |
| `cell` | "unexpected type" | Remove column, or convert: `string(cellVar)` if char contents |
| `datetime` (column) | "unexpected type" | `posixtime(datetimeVar)` -- stores as double |
| `duration` (column) | "unexpected type" | `seconds(durationVar)` -- stores as double |
| Multi-column (Nx3) | "each row must have one element" | Split into separate scalar variables |

### Conversion helper pattern

```matlab
function tt = prepareMDFData(tt)
    for i = 1:width(tt)
        v = tt.(i);
        if islogical(v)
            tt.(i) = uint8(v);
        elseif iscategorical(v)
            tt.(i) = double(v);
        elseif isduration(v)
            tt.(i) = seconds(v);
        elseif isdatetime(v)
            tt.(i) = posixtime(v);
        elseif iscell(v)
            tt.(i) = string(v);
        elseif size(v, 2) > 1
            baseName = tt.Properties.VariableNames{i};
            for col = 1:size(v,2)
                tt.(sprintf('%s_%d', baseName, col)) = v(:,col);
            end
            tt.(baseName) = [];
        end
    end
end
```

## Datetime RowTimes

RowTimes can be `duration` or `datetime`:

- **`duration`** -- Always works. Recommended.
- **`datetime`** -- Requires TimeZone. Without it: *"Inconsistent time zone settings on timetable row times and initial timestamp of MDF file."*

```matlab
tt.Time.TimeZone = 'UTC';

% Or convert to duration (preferred for reliable roundtrips):
tt.Time = tt.Time - tt.Time(1);
```

**Known issue (R2026a):** datetime RowTimes may produce incorrect values on read-back even with timezone set.

## Overwriting an Existing Channel Group

Read with `IncludeMetadata=true`, modify, then write with `GroupNumber=N`:

```matlab
data = mdfRead(fileName, GroupNumber=N, IncludeMetadata=true);
tt = data{1};
tt.SignalName = newValues;
mdfWrite(fileName, tt, GroupNumber=N);
```

**Critical:** Without `IncludeMetadata=true`, the overwrite fails. If the `GroupNumber` does not yet exist, `mdfWrite` creates it.

## Custom Properties Behavior

| Property | Preserved in roundtrip? |
|----------|------------------------|
| `VariableUnits` | Yes |
| `VariableDescriptions` | Yes |
| `Description` | No (silently lost) |
| `UserData` | No (silently lost) |

## Decoded signals (simplest path)

### CAN Signals 

```matlab
signalTT = canSignalTimetable(msgTimetable);
msgNames = fieldnames(signalTT);
for i = 1:numel(msgNames)
    mdfWrite(fileName, signalTT.(msgNames{i}));
end
```

### LIN Signals

Extract decoded signals from `linMessageTimetable` output. LIN does not have a corresponding `linSignalTimetable`, so signals must be extracted per message type from the `Signals` column (struct array). Each message type in the timetable may have different signal structs.

```matlab
msgTT = linMessageTimetable(linMsgs, linDb);

% Get unique message names in the timetable
msgNames = unique(msgTT.Name);

for i = 1:numel(msgNames)
    % Extract rows for this message type
    msgRows = msgTT(msgTT.Name == msgNames{i}, :);
    
    % Extract signal structs from Signals column
    signalColumn = msgRows.Signals;
    signalStructs = [signalColumn{:}];
    
    % Get signal names from the struct
    signalNames = fieldnames(signalStructs);
    signalNames = matlab.lang.makeValidName(signalNames);
    
    % Create signal timetable for this message type
    signalTT = timetable(msgRows.Time);
    for j = 1:numel(signalNames)
        signalTT.(signalNames{j}) = [signalStructs.(signalNames{j})]';
    end
    
    mdfWrite(fileName, signalTT);
end
```

**Note:** Each message type's signals are written to a separate channel group.

## Writing Raw CAN Data to MDF

To write raw CAN message data, use the `CAN_DataFrame.X` column naming convention. This follows the ASAM MDF standard naming and allows re-import via `mdfRead` + `canMessageTimetable`.

Mandatory columns: `CAN_DataFrame.ID`, `CAN_DataFrame.DLC`, `CAN_DataFrame.DataLength`, `CAN_DataFrame.DataBytes`

```matlab
% Build ASAM-style CAN timetable from canMessageTimetable output
msgTT = canMessageTimetable(rawMsgs, canDb);
canTT = timetable(msgTT.Time, ...
    uint32(msgTT.ID), ...
    uint8(msgTT.DLC), ...
    uint16(msgTT.Length), ...
    uint8(msgTT.Data), ...
    'VariableNames', {'CAN_DataFrame.ID', 'CAN_DataFrame.DLC', ...
                      'CAN_DataFrame.DataLength', 'CAN_DataFrame.DataBytes'});
mdfWrite(fileName, canTT);
```

**Note:** This does not produce the exact ASAM MDF CAN channel group structure (which includes bus-specific metadata nodes), but it preserves the data in a form that `mdfRead` and `canMessageTimetable` can consume. 

## Writing Raw LIN Data to MDF

Use the `LIN_Frame.X` column naming convention, following the same ASAM MDF pattern as CAN.

Mandatory columns: `LIN_Frame.ID`, `LIN_Frame.ReceivedDataByteCount`, `LIN_Frame.DataLength`, `LIN_Frame.DataBytes`

```matlab
linTT = timetable(timeVec, ...
    uint8(linIDs), ...
    uint8(rxByteCount), ...
    uint16(dataLength), ...
    uint8(dataBytes), ...
    'VariableNames', {'LIN_Frame.ID', 'LIN_Frame.ReceivedDataByteCount', ...
                      'LIN_Frame.DataLength', 'LIN_Frame.DataBytes'});
mdfWrite(fileName, linTT);
```

## Edge Cases

- **Empty timetable:** Rejected. Use `height(tt) > 0` check.
- **Re-running without deleting:** Repeated `mdfWrite` calls append new channel groups (not replace). Delete or use a new filename if you need a fresh write.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Logical columns in timetable | "unexpected type" | `uint8(col)` |
| datetime RowTimes without timezone | "Inconsistent time zone" | Set `.TimeZone = 'UTC'` or convert to duration |
| Overwrite without metadata | "metadata must be present" | Read with `IncludeMetadata=true` first |
| Multi-column variable (e.g., Nx3 position) | "each row must have one element" | Split into scalar columns |
| Assuming .mf4 extension always | Wrong format version | Use `.mf4` for MDF4, `.mdf`/`.dat` for MDF3 |

----

Copyright 2026 The MathWorks, Inc.

----
