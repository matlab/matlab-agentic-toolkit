# LIN Decode: linMessageTimetable

For function syntax, run `help linMessageTimetable` in MATLAB.

Requires R2025a+.

## Pipeline

```matlab
linDb = linDatabase("network.ldf");
linMsgs = linMessageTimetable(tt, linDb);
```

## linMessageTimetable Behavior

Converts raw LIN data (from mdfRead or blfread) into a decoded LIN message timetable.

Returns a timetable with columns: `ID`, `Name`, `Data`, `Length`, `Signals`, `ErrorType`, `ChecksumType`, `Checksum`.

## Signal Access (No Separate Signal Function)

Unlike CAN (which has `canMessageTimetable` -> `canSignalTimetable`), LIN decode stops at `linMessageTimetable`. There is no further decode step.

Signal values are accessed from the `Signals` column of the decoded timetable:

```matlab
linMsgs = linMessageTimetable(tt, linDb);
sigValues = linMsgs.Signals{rowIdx};
% Returns struct: sigValues.SignalName1, sigValues.SignalName2, etc.
```

## Extracting All Signals Into Timetables

To extract signals into a more usable format similar to canSignalTimetable output:

```matlab
linMsgs = linMessageTimetable(tt, linDb);
msgNames = unique(linMsgs.Name);
signals = struct();
for i = 1:numel(msgNames)
    msgName = msgNames(i);
    rows = linMsgs(linMsgs.Name == msgName, :);
    if isempty(rows) || isempty(rows.Signals{1})
        continue
    end
    sigFields = fieldnames(rows.Signals{1});
    sigData = timetable(rows.Time);
    for j = 1:numel(sigFields)
        vals = cellfun(@(s) s.(sigFields{j}), rows.Signals);
        sigData.(sigFields{j}) = vals;
    end
    signals.(matlab.lang.makeValidName(msgName)) = sigData;
end
```

## Database Compatibility

`linMessageTimetable` accepts only `linDatabase` (LDF files). It does **not** accept `canDatabase` or `arxmlDatabase`.

## Source Data

LIN raw data can come from:
- **BLF files:** `blfread(f, Database=linDb, ProtocolMode="LIN")`
- **MDF files:** `mdfRead(f, GroupNumber=g)` where the group contains `LIN_Frame.*` channels

See [BLF import](blf-import.md) and [MDF import](mdf-import.md) for details on reading from each format.

----

Copyright 2026 The MathWorks, Inc.
