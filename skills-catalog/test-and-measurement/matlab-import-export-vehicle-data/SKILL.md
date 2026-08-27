---
name: matlab-import-export-vehicle-data
description: Use when importing or exporting vehicle data from/to log files (MDF/MF4/DAT, BLF, ASC/TXT), decoding CAN/CAN FD/LIN messages to signals via DBC, ARXML, or LDF databases, writing timetable data to MDF or BLF files, or calling blfread, blfinfo, blfwrite, mdfRead, mdfWrite, mdfCreate, mdfInfo, canSignalImport, canMessageImport, canMessageTimetable, canFDMessageTimetable, canSignalTimetable, or linMessageTimetable.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.3"
---

# Import, Export, and Decode Vehicle Data

Import, decode, and export vehicle network log files in MATLAB using Vehicle Network Toolbox (VNT).

## When to Use

- Reading `.mf4`/`.mdf`/`.dat`, `.blf`, `.asc`, or `.txt` vehicle bus log files
- Decoding raw CAN/CAN FD frames to signals via DBC or ARXML databases
- Demultiplex signals from raw CAN/CAN FD frames via DBC databases in the case of simple multiplexing (R2026a or earlier)
- Decoding LIN frames via LDF databases (R2025a+)
- Handling polymorphic return types from VNT read functions
- Writing MATLAB timetable data to MDF/MF4 files with `mdfWrite`
- Writing CAN/CAN FD message data to BLF files with `blfwrite`
- Converting unsupported timetable types (logical, categorical, cell, datetime columns) for MDF export

## When Not To Use

- Simulink CAN configuration
- Live CAN channel access
- XCP/A2L workflows
- Demultiplexing of signals in the case of hierarchical or extended multiplexing
- Demultiplexing of signals via ARXML or LIN databases
- Writing LIN data to BLF (unsupported by VNT's `blfwrite` -- use MDF instead)
- Writing to ASC or TXT files (no `canMessageExport` exists -- use BLF or MDF instead)

## Prerequisites

Before running any operations, determine the MATLAB version:
```matlab
r = matlabRelease;
tok = regexp(r.Release, 'R(\d{4})([ab])', 'tokens');
matlabYear = str2double(tok{1}{1});
matlabLetter = tok{1}{2};
```

Before calling BLF/ASC/TXT import or CAN/CAN FD/LIN decode functions, call `detect_matlab_toolboxes` to confirm Vehicle Network Toolbox is installed. If unavailable, tell the user. Once confirmed in a session, do not re-check.

MDF functions (`mdfRead`, `mdfChannelGroupInfo`, `mdfInfo`, `mdfChannelInfo`) are base MATLAB (R2023a+) and do not require VNT. Do not use the deprecated `mdf()` object constructor -- always use the functional API. For reading all groups blindly, `mdfRead` alone is acceptable. To selectively read or inspect structure first, use `mdfChannelGroupInfo` or `mdfInfo`.

For R2026a and earlier, multiplexing is not natively supported in Vehicle Network Toolbox. Apply the demultiplexing modifications described below to decoded signals.

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

## Database inspection for DBC files and classification of the multiplexing scheme

In case of DBC files only, determine whether the file contains definitions of multiplexed signals that use extended or hierarchical multiplexing.
For MATLAB R2026a or earlier, it is not possible to determine the multiplexing scheme from the `canDatabase` object directly. Therefore, inspect the raw DBC text to classify the multiplexing scheme, by 
reading the DBC file as text using `fileread()`:
```matlab
dbcText = fileread("path/to/file.dbc");
```
Check for extended multiplexing indicators. See `references/dbc-multiplexing-syntax.md` for the full syntax guide — consult it when parsing unfamiliar DBC signal markers or `SG_MUL_VAL_` entries.
```matlab
hasSgMulValEntries = ~isempty(regexp(dbcText, '^SG_MUL_VAL_\s+\d+', 'once', 'lineanchors'));
hasNestedMuxor = ~isempty(regexp(dbcText, 'SG_\s+\w+\s+m\d+M\s', 'once'));
hasExtendedMux = hasSgMulValEntries || hasNestedMuxor;
```
Note: `SG_MUL_VAL_` may appear in the `NS_` (namespace) section as a keyword declaration — this does NOT indicate extended multiplexing. Only match actual data entries that start at the beginning of a line followed by a numeric message ID.
If `hasExtendedMux` is true, identify which specific messages are affected by parsing the message IDs from `SG_MUL_VAL_` entries:
```matlab
sgMulValMsgIds = regexp(dbcText, '^SG_MUL_VAL_\s+(\d+)', 'tokens', 'lineanchors');
extendedMuxMsgIds = unique(cellfun(@(x) str2double(x{1}), sgMulValMsgIds));
```
For R2026a and earlier, filter out messages with extended multiplexing (identified in `extendedMuxMsgIds`) and inform the user.

## Key Constraints

- **Polymorphic returns:** All VNT read functions (`canSignalImport`, `blfread`, `mdfRead`, `canMessageImport`) return different types based on channel count and parameters. Always guard with `iscell()`/`istimetable()`/`isstruct()`. When checking multi-channel results, use `iscell()` as the primary guard to branch between cell array (multi-channel) vs direct timetable (single channel), then iterate or extract with `{n}` or `{i}`.
- **ARXML + CAN FD:** `arxmlDatabase` does not support CAN FD in MATLAB. It cannot be used with `canFDMessageTimetable`. When the user provides an ARXML file for CAN FD data, always explain that ARXML does not support CAN FD and they must use `canDatabase` with a DBC file instead. Do not silently switch to DBC without explaining why.
- **ARXML for CAN (non-FD):** When the user provides an ARXML file for standard CAN decode, use `arxmlDatabase` exclusively. Do not also load `canDatabase` as a fallback -- the ARXML database object works identically in `canMessageTimetable` and `canSignalTimetable`. Only use `canDatabase` when the user provides a DBC file.
- **No `canFDSignalTimetable`:** This function does not exist. Use `canSignalTimetable` for both CAN and CAN FD signals.
- **BLF LIN requires `ProtocolMode="LIN"`:** Without it, `blfread` returns only CAN data.
- **No signal-level LIN decode:** Only `linMessageTimetable` exists. Access signal values from timetable columns directly.
- **MDF raw CAN detection:** Use channel name prefixes `CAN_DataFrame` / `LIN_Frame` (ASAM standard). NEVER use `SourceBusType` or `AcquisitionSourceType` metadata -- not even as a fallback. These fields are vendor-specific and unreliable.
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

## Demultiplexing References

- [Simple demultiplexing](references/simple-demultiplexing.md) -- `canDatabase`, `canMessageTimetable`, `canFDMessageTimetable`, `canSignalTimetable` pipelines and signal demultiplexing

## Export Workflows

### MDF Writing

Writing MATLAB timetable data to MDF/MF4 files with `mdfWrite`.

| Task | Function | Notes |
|------|----------|-------|
| Write timetable to new file | `mdfWrite(file, tt)` | Appends channel group; file created with warning if missing |
| Overwrite existing group | `mdfWrite(file, tt, GroupNumber=N)` | Must read with `IncludeMetadata=true` first |
| Set file metadata | `mdfCreate(file, FileInfo=minfo)` then `mdfWrite()` | Supported: Author, Department, Project, Subject, Comment |
| Convert unsupported types | See `references/mdf-writing.md` | `logical` -> `uint8()`, `categorical` -> `double()` (stores category index), `cell` -> `string()`, `datetime` col -> `posixtime()` |
| Write raw CAN frames | Use `CAN_DataFrame.ID/DLC/DataLength/DataBytes` column naming (ASAM standard) | All 4 columns mandatory (ID, DLC, DataLength, DataBytes). Omitting any one breaks `canMessageTimetable` re-import. |
| Write raw LIN frames | Use `LIN_Frame.ID/ReceivedDataByteCount/DataLength/DataBytes` column naming | ASAM standard LIN frame naming |
| Handle datetime RowTimes | **Required step:** Set `.TimeZone = 'UTC'` before writing: `tt.Properties.RowTimes.TimeZone = 'UTC';` | Alternatively convert to `duration` -- both work. Omitting this causes mdfWrite to error or produce unreadable timestamps. |

### BLF Writing

Writing CAN and CAN FD message data to BLF files with `blfwrite`.

| Task | Function | Notes |
|------|----------|-------|
| Write CAN messages | `blfwrite(file, tt, chanID, 'CAN')` | Use `canMessageTimetable` to format `tt`; do not manually build columns |
| Write CAN FD messages | `blfwrite(file, tt, chanID, 'CAN FD')` | Use `canFDMessageTimetable` to format `tt`; up to 64-byte payloads. See `references/blf-writing.md` for the 13 required columns when building from scratch. |
| CAN/CAN FD mixed | Both supported in one BLF file | Use explicit protocol string per call |

**LIN is not supported** by VNT's `blfwrite`. Use MDF for LIN logging. When the user asks to write LIN data to BLF, state this limitation immediately -- do not attempt workarounds or partial solutions before explaining the constraint.

**ASC/TXT writing is not supported.** There is no `canMessageExport` counterpart to `canMessageImport`. Use BLF or MDF for export.

## Export References

- [MDF writing](references/mdf-writing.md) -- `mdfWrite`/`mdfCreate`, type conversion, ASAM CAN/LIN naming, overwriting groups, metadata preservation
- [BLF writing](references/blf-writing.md) -- `blfwrite` with CAN/CAN FD, `canMessageTimetable`/`canFDMessageTimetable` formatting, channel callbacks

----

Copyright 2026 The MathWorks, Inc.
