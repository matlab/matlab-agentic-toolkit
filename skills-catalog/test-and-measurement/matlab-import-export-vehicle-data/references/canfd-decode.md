# CAN FD Decode: canFDMessageTimetable

For function syntax, run `help canFDMessageTimetable` in MATLAB.

## Pipeline

```matlab
db = canDatabase("file.dbc");
msgTT = canFDMessageTimetable(tt, db);
signals = canSignalTimetable(msgTT);
```

## canFDMessageTimetable Behavior

Converts raw CAN FD data into a decoded CAN FD message timetable. Functionally similar to `canMessageTimetable` but handles the extended CAN FD payload sizes (up to 64 bytes).

Accepts:
- A raw timetable from `mdfRead` (containing `CAN_DataFrame.*` columns with FD-length payloads)
- A CAN FD message timetable from `blfread`
- A `can.Message` array with FD frames

Returns a timetable with columns: `ID`, `Extended`, `Name`, `Data`, `Length`, `Signals`, `Error`, `Remote`, `BRS`, `ESI`.

## ARXML Limitation

**`canFDMessageTimetable` does NOT accept `arxmlDatabase`.** ARXML database support in VNT is limited to standard CAN. For CAN FD decode, you must use `canDatabase` (DBC files).

```matlab
% CORRECT: CAN FD with DBC
db = canDatabase("canfd_network.dbc");
msgTT = canFDMessageTimetable(tt, db);

% WRONG: will error
db = arxmlDatabase("network.arxml");
msgTT = canFDMessageTimetable(tt, db);  % Not supported
```

This also means `blfread` with CAN FD protocol data cannot decode using an `arxmlDatabase`.

## Signal Extraction

Use `canSignalTimetable` (same function as CAN -- there is no `canFDSignalTimetable`):

```matlab
msgTT = canFDMessageTimetable(tt, db);
signals = canSignalTimetable(msgTT);
% signals.MessageName → timetable with signal columns
```

## When to Use canFDMessageTimetable vs canMessageTimetable

- If the log contains only standard CAN (8-byte max payload): use `canMessageTimetable`
- If the log contains CAN FD frames (up to 64-byte payload): use `canFDMessageTimetable`
- If unsure, check `DataLength` column -- values > 8 indicate CAN FD

Both functions produce a message timetable compatible with `canSignalTimetable`.

----

Copyright 2026 The MathWorks, Inc.
