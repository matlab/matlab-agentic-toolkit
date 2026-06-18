# MDF/MF4/DAT File Import

For function syntax, run `help mdfInfo`, `help mdfRead`, `help mdfChannelGroupInfo`, or `help mdfChannelInfo` in MATLAB.

**Do not use the deprecated `mdf()` object constructor.** Always use the functional API: `mdfRead`, `mdfInfo`, `mdfChannelGroupInfo`, `mdfChannelInfo` (available R2023a+). The `mdf()` class and its methods (`.read()`, `.get()`, `.ChannelGroup`) are legacy and should not be used in new code.

MDF files (`.mf4`, `.mdf`, `.dat`) contain multiple "channel groups" that can hold different types of data.

## File-Level Metadata with mdfInfo

```matlab
fileInfo = mdfInfo(mdfFile);
```

Returns file-level metadata: MDF version, program that created the file, start time, and number of channel groups. Use this for a quick overview before inspecting individual groups.

## Inspecting Channel Groups

```matlab
groupInfo = mdfChannelGroupInfo(mdfFile);
```

Returns a table with columns including `NumSamples`, `AcquisitionName` (categorical, may be `<undefined>`).

## Inspecting Channels Within a Group

```matlab
channelInfo = mdfChannelInfo(mdfFile, GroupNumber=g);
channelInfo = mdfChannelInfo(mdfFile);  % all groups
channelInfo = mdfChannelInfo(mdfFile, Channel="LIN_Frame.*");  % wildcard
```

## Reading Data with mdfRead

```matlab
data = mdfRead(mdfFile, GroupNumber=g);
tt = data{1};  % timetable for that group
```

`mdfRead` always returns a cell array. Extract with `data{1}`.

Reading multiple groups returns a cell array where index is sequential (not the group number):
```matlab
data = mdfRead(mdfFile, GroupNumber=[1, 3, 5]);
% data{1} -> group 1, data{2} -> group 3, data{3} -> group 5
```

## Detecting Raw Bus Data vs Decoded Signals

**Do NOT use metadata** (`SourceBusType`, `AcquisitionSourceType`) for detection. These are vendor-specific and unreliable.

**Use ASAM MDF standard channel name prefixes:**

| Prefix | Protocol | Mandatory Channels | Action |
|--------|----------|-------------------|--------|
| `CAN_DataFrame` | CAN / CAN FD | `.ID`, `.DLC`, `.DataLength`, `.DataBytes` | Decode with `canMessageTimetable` or `canFDMessageTimetable` |
| `LIN_Frame` | LIN | `.ID`, `.ReceivedDataByteCount`, `.DataLength`, `.DataBytes` | Decode with `linMessageTimetable` (R2025a+) |
| Neither | Already decoded | N/A | Use timetable directly |

```matlab
varNames = string(tt.Properties.VariableNames);
if any(startsWith(varNames, "CAN_DataFrame"))
    % Raw CAN -- see references/can-decode.md or references/canfd-decode.md
elseif any(startsWith(varNames, "LIN_Frame"))
    % Raw LIN -- see references/lin-decode.md
else
    % Already decoded signals -- use directly
end
```

**Distinguishing CAN vs CAN FD:** Check `DataLength` values. Standard CAN has max 8 bytes; CAN FD can have up to 64 bytes.

**Finding LIN groups:**
```matlab
linChannels = mdfChannelInfo(mdfFile, Channel="LIN_Frame.*");
% GroupNumber column identifies which groups contain LIN data
```

## Decode Pipelines

For decode pipelines, see the protocol references:
- [CAN decode](can-decode.md) -- `canMessageTimetable` + `canSignalTimetable`
- [CAN FD decode](canfd-decode.md) -- `canFDMessageTimetable` + `canSignalTimetable`
- [LIN decode](lin-decode.md) -- `linMessageTimetable`, signal access

## Complete MDF Pipeline

```matlab
db = canDatabase(dbcFile);
data = mdfRead(mdfFile);
signals = struct();

for i = 1:numel(data)
    tt = data{i};
    if height(tt) == 0
        continue
    end

    varNames = string(tt.Properties.VariableNames);
    if any(startsWith(varNames, "CAN_DataFrame"))
        try
            msgTT = canMessageTimetable(tt, db);
            signals.("Group" + i) = canSignalTimetable(msgTT);
        catch
            signals.("Group" + i) = tt;
        end
    elseif any(startsWith(varNames, "LIN_Frame"))
        signals.("Group" + i) = linMessageTimetable(tt, linDb);
    else
        signals.("Group" + i) = tt;
    end
end
```

## AcquisitionName Handling

`AcquisitionName` is categorical. The value `<undefined>` is NOT a string -- `strlength()` on it throws. Always convert first:

```matlab
acqName = string(groupInfo.AcquisitionName(g));
if ~ismissing(acqName) && strlength(acqName) > 0
    groupName = matlab.lang.makeValidName(acqName);
end
```

----

Copyright 2026 The MathWorks, Inc.
