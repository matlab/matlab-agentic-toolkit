# BLF Writing Reference

Detailed patterns and examples for writing MATLAB timetable data to Vector BLF (Binary Logging Format) files using `blfwrite`.

**Scope:** CAN and CAN FD only. LIN is not supported by VNT's `blfwrite`.

Key points:
- All four arguments are required: `blfwrite(blffile, msgtable, chanID, protocol)`
  - `blffile`: Output BLF file path
  - `msgtable`: Timetable containing message data
  - `chanID`: Channel ID (integer)
  - `protocol`: `'CAN'` or `'CAN FD'`
- BLF files are created automatically if they do not exist.
- Repeated `blfwrite` calls append messages (not replace).

## Writing CAN Messages to BLF

Convert CAN message timetable to BLF format. Provide the timetable, channel ID, and network protocol:

```matlab
% From canMessageTimetable output
msgTT = canMessageTimetable(rawMsgs, canDb);

% Write to BLF (chanID=1 for first channel)
blfwrite('can_data.blf', msgTT, 1, 'CAN');
```

### Formatting timetables for blfwrite

**Always use `canMessageTimetable` or `canFDMessageTimetable` to create timetables for `blfwrite`.** Do not manually construct timetables with raw `ID`, `DLC`, `Data` columns -- `blfwrite` expects the internal format produced by these functions, and manual construction fails silently or errors.

```matlab
% From raw CAN message objects
msgTT = canMessageTimetable(canMsgs);
blfwrite('can_output.blf', msgTT, 1, 'CAN');

% From raw CAN FD message objects
fdTT = canFDMessageTimetable(canFDMsgs);
blfwrite('canfd_output.blf', fdTT, 1, 'CAN FD');
```

If you have signal data in a plain timetable (e.g., decoded signals), you must first encode it back into CAN message objects using a DBC database, then convert to a message timetable:

```matlab
db = canDatabase('myNetwork.dbc');
msgs = canMessage(db, 'EngineData', numFrames);
% Pack signals into messages, then:
msgTT = canMessageTimetable(msgs);
blfwrite('encoded.blf', msgTT, 1, 'CAN');
```

## Writing CAN FD Messages to BLF

CAN FD extends classical CAN with up to 64-byte payloads. Use `canFDMessageTimetable` to format data, then specify `'CAN FD'` as the protocol:

```matlab
% From CAN FD message objects (up to 64 bytes per message)
fdMsgs = canFDMessage(db, 'HighSpeedData', numFrames);
% ... pack signal data into messages ...
fdTT = canFDMessageTimetable(fdMsgs);
blfwrite('canfd_output.blf', fdTT, 1, 'CAN FD');
```

### Constructing CAN FD Message Timetables from Scratch

When you don't have existing CAN FD message objects, you must build a raw timetable with all required columns before calling `canFDMessageTimetable`. The function validates that every column exists.

**Required columns for `canFDMessageTimetable` input:**

| Column | Type | Description |
|--------|------|-------------|
| `ID` | `uint32` | CAN identifier (11-bit or 29-bit) |
| `Extended` | `logical` | `true` for 29-bit extended IDs |
| `Name` | cell of char | Message name (e.g., `{'RadarMsg'}`) |
| `Data` | cell of `uint8` row vectors | Payload bytes (up to 64 per message) |
| `Length` | `uint8` | Actual data length in bytes |
| `DLC` | `uint8` | DLC code (0-15 for CAN FD) |
| `Signals` | cell of struct | Signal decode info (use `{struct()}` if none) |
| `Error` | `logical` | Error frame flag |
| `Remote` | `logical` | Remote frame flag |
| `ProtocolMode` | cell of char | Must be `{'CAN FD'}` |
| `BRS` | `logical` | Bit Rate Switch flag |
| `EDL` | `logical` | Extended Data Length flag (true for FD) |
| `ESI` | `logical` | Error State Indicator |

**Important:** `Name`, `Data`, `Signals`, and `ProtocolMode` must be cell arrays (not string arrays). Use `{'text'}` syntax, not `"text"`.

```matlab
numMsgs = 50;
timestamps = seconds((0:numMsgs-1)' / 100);

rawTT = timetable( ...
    repmat(uint32(hex2dec('2A0')), numMsgs, 1), ...    % ID
    false(numMsgs, 1), ...                              % Extended
    repmat({'RadarMsg'}, numMsgs, 1), ...               % Name
    arrayfun(@(~) uint8(randi([0 255], 1, 64)), ...
        (1:numMsgs)', 'UniformOutput', false), ...      % Data
    repmat(uint8(64), numMsgs, 1), ...                  % Length
    repmat(uint8(15), numMsgs, 1), ...                  % DLC
    repmat({struct()}, numMsgs, 1), ...                 % Signals
    false(numMsgs, 1), ...                              % Error
    false(numMsgs, 1), ...                              % Remote
    repmat({'CAN FD'}, numMsgs, 1), ...                 % ProtocolMode
    true(numMsgs, 1), ...                               % BRS
    true(numMsgs, 1), ...                               % EDL
    false(numMsgs, 1), ...                              % ESI
    'VariableNames', {'ID','Extended','Name','Data','Length','DLC', ...
        'Signals','Error','Remote','ProtocolMode','BRS','EDL','ESI'}, ...
    'RowTimes', timestamps);

fdTT = canFDMessageTimetable(rawTT);
blfwrite('canfd_output.blf', fdTT, 2, 'CAN FD');
```

## Logging CAN Messages via Channel Callbacks

Vector BLF files are well-suited for real-time logging via channel callbacks. This is a common use case:

```matlab
% Create a callback to log messages
function logCANMessages(msgs, fileName, chanID)
    % msgs is a canMessage array
    if isempty(msgs)
        return
    end
    msgTT = canMessageTimetable(msgs);
    % Always specify all four arguments: file, table, chanID, protocol
    blfwrite(fileName, msgTT, chanID, 'CAN');
end

% Set up channel listener
chan = canChannel(...);
addlistener(chan, 'MessageReceived', @(src, evt) logCANMessages(evt.Message, 'logged.blf', 1));
```

## Type Compatibility

BLF has fewer type restrictions than MDF:
- **Supported:** uint8, uint32, arrays (for data bytes)
- **RowTimes:** Both `duration` and `datetime` work; `datetime` does not require TimeZone specification

Conversion recommendations:
- Use `uint32` for CAN IDs (allows 29-bit extended IDs)
- Use `uint8` arrays for data payload (up to 64 bytes in CAN FD)
- Use `uint8` for DLC (0-8 for CAN, 0-15 for CAN FD when encoded with FDF flag)

## BLF Format Limitations

Vehicle Network Toolbox has known constraints for BLF:

1. **No metadata storage** -- BLF does not store signal names, units, or descriptions for decoded signals. Metadata must be preserved separately (e.g., in a companion DBC file or CSV).

2. **LIN not supported by blfwrite** -- The Vehicle Network Toolbox does not support writing LIN messages to BLF files. Use MDF for LIN logging.

3. **Read-back with database required** -- To recover signal names and scaling info, you must provide a CAN database (DBC) file when reading with `blfread`.

## Edge Cases

- **Empty timetable:** Rejected. Use `height(tt) > 0` check.
- **Appending to existing BLF:** Repeated `blfwrite` calls append new messages (not replace).
- **Mixed CAN and CAN FD:** BLF can store both in one file, but use explicit `NetworkType` to avoid ambiguity.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Missing `chanID` or `protocol` argument | Function call fails | All four args required: `blfwrite(file, tbl, chanID, protocol)` |
| DLC value >8 for classical CAN | Truncated or corrupted frames | Use `'CAN FD'` as protocol if DLC >8 |
| Assuming metadata in BLF after write | Signal names/units missing on read | Provide external DBC file to `blfread` for metadata |
| Trying to write LIN to BLF | "LIN not supported" error | Use MDF for LIN; BLF is CAN/CAN FD only in VNT |
| Writing cell or string types | "unexpected type" error | Use `uint8` arrays for binary data |
| Manually building timetable with custom columns | `blfwrite` errors | Use `canMessageTimetable` or `canFDMessageTimetable` to format data |

----

Copyright 2026 The MathWorks, Inc.

----
