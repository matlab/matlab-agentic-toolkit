# CAN Decode: canMessageTimetable and canSignalTimetable

For function syntax, run `help canMessageTimetable` or `help canSignalTimetable` in MATLAB.

## Pipeline

```matlab
db = canDatabase("file.dbc");
msgTT = canMessageTimetable(tt, db);
signals = canSignalTimetable(msgTT);
```

`canMessageTimetable` converts raw CAN data (from mdfRead, blfread, or can.Message arrays) into a decoded message timetable. `canSignalTimetable` then extracts individual signal timetables.

## canMessageTimetable Behavior

Accepts:
- A raw timetable from `mdfRead` (containing `CAN_DataFrame.*` columns)
- A CAN message timetable from `blfread` (with `Database=` specified)
- A `can.Message` array (legacy)

Returns a timetable with columns: `ID`, `Extended`, `Name`, `Data`, `Length`, `Signals`, `Error`, `Remote`.

**Database compatibility:**
- `canDatabase` (DBC) -- fully supported
- `arxmlDatabase` (ARXML) -- fully supported (R2025a+)

**Error handling:** Throws if the database doesn't contain definitions matching the message IDs in the timetable. Always wrap with try/catch:

```matlab
try
    msgTT = canMessageTimetable(tt, db);
    signals = canSignalTimetable(msgTT);
catch
    signals = tt;
end
```

## canSignalTimetable Behavior

Returns a **struct of timetables** -- one field per decoded message. Each field contains a timetable with signal columns.

```matlab
signals = canSignalTimetable(msgTT);
% signals.EngineData → timetable with columns: EngineSpeed, EngineLoad, etc.
% signals.ABSdata → timetable with columns: WheelSpeed_FL, WheelSpeed_FR, etc.
```

Filter to specific messages:
```matlab
signals = canSignalTimetable(msgTT, "EngineData");
signals = canSignalTimetable(msgTT, {'ABSdata', 'EngineData'});
```

**Also accepts CAN FD message timetables** (output of `canFDMessageTimetable`). There is no separate `canFDSignalTimetable` function.

## Multiple Databases

```matlab
db1 = canDatabase("powertrain.dbc");
db2 = canDatabase("chassis.dbc");
msgTT = canMessageTimetable(tt, [db1, db2]);
```

----

Copyright 2026 The MathWorks, Inc.
