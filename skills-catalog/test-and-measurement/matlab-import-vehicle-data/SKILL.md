---
name: matlab-import-vehicle-data
description: Use when importing vehicle data from log files (MDF/MF4/DAT, BLF, ASC/TXT), decoding CAN/CAN FD/LIN messages to signals via DBC, ARXML, or LDF databases, or calling blfread, blfinfo, mdfRead, canSignalImport, canMessageImport, canMessageTimetable, canFDMessageTimetable, canSignalTimetable, or linMessageTimetable.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
disable-model-invocation: false
allowed-tools: mcp__matlab__detect_matlab_toolboxes, mcp__matlab__evaluate_matlab_code, mcp__matlab__check_matlab_code, mcp__matlab__run_matlab_file, mcp__matlab__run_matlab_test_file
---

# Import and Decode Vehicle Data

Import and decode vehicle network log files in MATLAB using Vehicle Network Toolbox (VNT).

## When to Use

- Reading `.mf4`/`.mdf`/`.dat`, `.blf`, `.asc`, or `.txt` vehicle bus log files
- Decoding raw CAN/CAN FD frames to signals via DBC or ARXML databases
- Decoding LIN frames via LDF databases (R2025a+)
- Handling polymorphic return types from VNT read functions

## When Not To Use

- Simulink CAN configuration
- Live CAN channel access
- XCP/A2L workflows

## Prerequisites

Before calling BLF/ASC/TXT import or CAN/CAN FD/LIN decode functions, call `detect_matlab_toolboxes` to confirm Vehicle Network Toolbox is installed. If unavailable, tell the user. Once confirmed in a session, do not re-check.

MDF functions (`mdfRead`, `mdfChannelGroupInfo`, `mdfInfo`, `mdfChannelInfo`) are base MATLAB (R2023a+) and do not require VNT. Do not use the deprecated `mdf()` object constructor -- always use the functional API.

## Decode Pipeline

| Source Format | CAN | CAN FD | LIN | Raw (no decode) |
|---------------|-----|--------|-----|-----------------|
| **ASC** | `canSignalImport(f,"Vector",db)` | same | -- | `canMessageImport(f,"Vector",OutputFormat="timetable")` |
| **TXT** | `canSignalImport(f,"Kvaser",db)` | same | -- | `canMessageImport(f,"Kvaser",OutputFormat="timetable")` |
| **BLF** | `blfread(f,Database=db)` -> `canSignalTimetable` | `blfread(f,Database=db)` -> `canFDMessageTimetable` -> `canSignalTimetable` | `blfread(f,Database=linDb,ProtocolMode="LIN")` -> `linMessageTimetable` | `blfread(f)` |
| **MDF/MF4/DAT** | `mdfRead` -> `canMessageTimetable(tt,db)` -> `canSignalTimetable` | `mdfRead` -> `canFDMessageTimetable(tt,db)` -> `canSignalTimetable` | `mdfRead` -> `linMessageTimetable(tt,linDb)` | `mdfRead` -> timetable directly |

## Database Loading

```matlab
db = canDatabase("path/to/file.dbc");       % CAN and CAN FD
db = arxmlDatabase("path/to/file.arxml");   % CAN only (not CAN FD)
linDb = linDatabase("path/to/file.ldf");    % LIN (R2025a+)
```

Load once, pass to all decode calls. Multiple databases: `canMessageTimetable(tt, [db1, db2])`.

## Key Constraints

- **Polymorphic returns:** All VNT read functions (`canSignalImport`, `blfread`, `mdfRead`, `canMessageImport`) return different types based on channel count and parameters. Always guard with `iscell()`/`istimetable()`/`isstruct()`.
- **ARXML + CAN FD:** `arxmlDatabase` does not work with `canFDMessageTimetable` or CAN FD data. Use `canDatabase` (DBC) for CAN FD.
- **No `canFDSignalTimetable`:** Use `canSignalTimetable` for both CAN and CAN FD signals.
- **BLF LIN requires `ProtocolMode="LIN"`:** Without it, `blfread` returns only CAN data.
- **No signal-level LIN decode:** Only `linMessageTimetable` exists. Access signal values from timetable columns directly.
- **MDF raw CAN detection:** Use channel name prefixes `CAN_DataFrame` / `LIN_Frame` (ASAM standard). Do not use `SourceBusType` metadata -- it is vendor-specific and unreliable.
- **`canMessageImport` default format:** Returns legacy `can.Message` array. Always pass `OutputFormat="timetable"`.
- **Cell extraction:** Multi-channel calls to `blfread`, `mdfRead`, and `canMessageImport` return cell arrays. Extract with `{n}` before processing.
- **Use `canSignalImport` for ASC/TXT signals:** It decodes in one call. Only use `canMessageImport` when raw message timetables are needed.

## File-Specific References

- [ASC import](references/asc-import.md) -- `canSignalImport`/`canMessageImport` with Vector and Kvaser vendors, polymorphic return type handling for multi-channel files
- [BLF import](references/blf-import.md) -- `blfinfo` for file inspection, `blfread` with and without ChannelID, CAN vs LIN protocol selection
- [MDF import](references/mdf-import.md) -- `mdfRead`/`mdfChannelGroupInfo`/`mdfChannelInfo`, detecting raw CAN/LIN groups by channel name, reading specific groups

## Protocol References

- [CAN decode](references/can-decode.md) -- `canMessageTimetable` and `canSignalTimetable` pipelines, DBC and ARXML database usage
- [CAN FD decode](references/canfd-decode.md) -- `canFDMessageTimetable` pipeline, why ARXML does not work for CAN FD
- [LIN decode](references/lin-decode.md) -- `linMessageTimetable` usage, accessing signal values from timetable columns (no signal-level function exists)
- [Database objects](references/database-objects.md) -- `canDatabase` vs `arxmlDatabase` vs `linDatabase`, which decode functions accept which database type

----

Copyright 2026 The MathWorks, Inc.
