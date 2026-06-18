# ASC and TXT File Import

For function syntax, run `help canSignalImport` or `help canMessageImport` in MATLAB.

## Supported Formats

| Extension | Vendor Argument | Source |
|-----------|-----------------|--------|
| `.asc` | `"Vector"` | Vector CANalyzer/CANoe logs |
| `.txt` | `"Kvaser"` | Kvaser logs |

## Choosing canSignalImport vs canMessageImport

- **Want decoded signals?** Use `canSignalImport` -- it decodes in one call.
- **Want raw message timetables?** Use `canMessageImport` -- returns undecoded frames.

When the goal is to get signal values from an ASC/TXT file, **always use `canSignalImport`**. Do not use `canMessageImport` followed by manual decode unless you specifically need the raw message timetable.

## canSignalImport -- Decoded Signals in One Call

```matlab
result = canSignalImport(file, "Vector", db);
result = canSignalImport(file, "Kvaser", db);
```

### CRITICAL: Return Type is Polymorphic

The return type depends on the file content and parameters. **Do NOT assume a fixed type.**

### Case 1: Single CAN channel with single decodable message
Returns a **timetable directly** (not in a cell or struct):
```matlab
result = canSignalImport(file, "Vector", db);
% class(result) -> 'timetable'
% result.Properties.VariableNames -> signal names
```

### Case 2: Multiple CAN channels (or with ChannelID)
Without `ChannelID`: returns a **cell{N,1}** where N = number of CAN channels. Cell index = CAN channel ID.

With `ChannelID`: returns a **single struct** for that channel.

Each cell element (or the single struct) is one of:
- **struct** -- multiple messages decoded on that channel. Fields are message names, each containing a signal timetable.
- **timetable** -- exactly one message decoded on that channel.
- **empty timetable** (0x0) -- no decodable messages matched the DBC on that channel.

### Correct Handling Pattern

```matlab
result = canSignalImport(filePath, "Vector", db);

if istimetable(result)
    signals = struct("Channel1", result);
else
    signals = struct();
    for i = 1:numel(result)
        ch = result{i};
        if isstruct(ch)
            signals.("Channel" + i) = ch;
        elseif istimetable(ch) && height(ch) > 0
            signals.("Channel" + i) = ch;
        end
    end
end
```

---

## canMessageImport -- Raw Messages

```matlab
msgTT = canMessageImport(file, "Vector", OutputFormat="timetable");
msgTT = canMessageImport(file, "Kvaser", OutputFormat="timetable");
```

Without `OutputFormat="timetable"`, the default return is a legacy `can.Message` array. Always specify `OutputFormat="timetable"`.

### Return Type is Polymorphic (like canSignalImport)

Without `ChannelID`, if the file contains multiple CAN channels: returns a cell array of timetables, one per channel. With `ChannelID`: returns a single message timetable.

### Decode raw messages to signals

```matlab
msgTT = canMessageImport(file, "Vector", db, OutputFormat="timetable");
signals = canSignalTimetable(msgTT);
```

For CAN FD messages, use `canFDMessageTimetable` before `canSignalTimetable`:
```matlab
msgTT = canMessageImport(file, "Vector", OutputFormat="timetable");
fdMsgTT = canFDMessageTimetable(msgTT, db);
signals = canSignalTimetable(fdMsgTT);
```

See [CAN decode](can-decode.md) and [CAN FD decode](canfd-decode.md) for details.

---

## Protocol Support

ASC and TXT files contain **CAN and CAN FD data only**. LIN data is not supported. For LIN, use BLF or MDF sources.

----

Copyright 2026 The MathWorks, Inc.
