# BLF File Import

For function syntax, run `help blfinfo` or `help blfread` in MATLAB.

## Step 0: Inspect with blfinfo

Always inspect a BLF file before reading to understand its channel/protocol structure:

```matlab
info = blfinfo(blfFile);
disp(info.ChannelList)
%   ChannelID    Protocol    Objects
%   _________    ________    _______
%       1        "CAN"        2500
%       2        "CAN FD"     1200
%       3        "LIN"         800
```

The `ChannelList` table shows which protocols are present. Use this to decide which blfread calls to make.

**blfinfo struct fields:** `Name`, `Path`, `Application`, `ApplicationVersion`, `Objects`, `StartTime`, `EndTime`, `ChannelList`.

---

## blfread Usage Matrix

Usage depends on two axes: **protocol** (CAN/CAN FD vs LIN) and **database** (with DBC/LDF vs without).

### CAN / CAN FD with Database (DBC)

```matlab
db = canDatabase("network.dbc");
result = blfread(blfFile, Database=db);
msgTT = result{1};
signals = canSignalTimetable(msgTT);
```

For CAN FD signals, use `canFDMessageTimetable` if the data has FD-length payloads:
```matlab
db = canDatabase("canfd_network.dbc");
result = blfread(blfFile, Database=db);
msgTT = result{1};
fdMsgTT = canFDMessageTimetable(msgTT, db);
signals = canSignalTimetable(fdMsgTT);
```

See [CAN decode](can-decode.md) and [CAN FD decode](canfd-decode.md) for details.

### CAN / CAN FD without Database (raw)

```matlab
result = blfread(blfFile);
msgTT = result{1};
% msgTT is a raw message timetable -- ID, Data, Length columns
```

Or read a specific channel directly:
```matlab
msgTT = blfread(blfFile, ChannelID=2);
```

### LIN with Database (LDF)

`ProtocolMode="LIN"` is **required** for all LIN reads from BLF. Without it, blfread only returns CAN data.

```matlab
linDb = linDatabase("lin_network.ldf");
result = blfread(blfFile, Database=linDb, ProtocolMode="LIN");
msgTT = result{1};
linMsgs = linMessageTimetable(msgTT, linDb);
```

See [LIN decode](lin-decode.md) for signal access patterns.

### LIN without Database (raw)

```matlab
result = blfread(blfFile, ProtocolMode="LIN");
msgTT = result{1};
% Raw LIN frames -- ID, Data, Length columns
```

---

## CRITICAL: Return Type Depends on ChannelID

The return type changes based on whether `ChannelID` is specified. When demonstrating blfread, always show both approaches.

### Without ChannelID (default): Returns a cell array
```matlab
result = blfread(blfFile, Database=db);
% Returns cell{N,1} where N = number of channels for the given protocol
msgTT = result{1};  % extract channel 1 timetable from the cell
signals = canSignalTimetable(msgTT);
```

You **must** extract with `result{n}` before passing to decode functions.

### With ChannelID: Returns a single timetable directly
```matlab
msgTT = blfread(blfFile, Database=db, ChannelID=3);
% Returns a single message timetable directly (NOT in a cell)
signals = canSignalTimetable(msgTT);
```

No cell extraction needed -- the timetable is returned directly.

---

## ARXML Limitation with CAN FD

`blfread(f, Database=arxmlDb)` works for standard CAN data. It does **not** work for CAN FD data with an `arxmlDatabase`. For CAN FD, use `canDatabase` (DBC) instead:

```matlab
db = canDatabase("canfd_network.dbc");
result = blfread(blfFile, Database=db);
msgTT = result{1};
fdMsgTT = canFDMessageTimetable(msgTT, db);
signals = canSignalTimetable(fdMsgTT);
```

---

## Filtering

```matlab
msgTT = blfread(blfFile, Database=db, ChannelID=2, ...
    CANStandardFilter=[hex2dec('100'), hex2dec('200')], ...
    TimeRange=[seconds(5), seconds(30)]);
```

Requires R2019a+. LIN via ProtocolMode requires R2025a+.

----

Copyright 2026 The MathWorks, Inc.
