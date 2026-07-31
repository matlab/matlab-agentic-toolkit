# Database

## canDatabase — Load a DBC file

```matlab
db = canDatabase('filename.dbc');
```

- Parses a Vector DBC file and returns a `can.Database` object
- Provides message definitions (ID, name, DLC) and signal definitions (start bit, length, byte order, factor, offset, units)
- `db.Messages` returns a cell array of message name strings
- `db.MessageInfo` returns a struct with per-message details

## Inspecting the Database

```matlab
msgNames = db.Messages;              % cell array of message names
info = db.MessageInfo;               % struct array with message details
```

## attachDatabase — Attach to messages (not channels)

```matlab
attachDatabase(msg, db);
attachDatabase(msg, []);    % detach
```

- `attachDatabase` operates on **message objects**, not channel objects
- After attachment, the message gains a `.Signals` struct for signal-level read/write
- Use on received messages to decode signals from raw bytes
- Pass `[]` to detach (remove signal decode capability)

## canMessage with Database — Auto-Attached on Creation

```matlab
msg = canMessage(db, 'EngineData');
```

- Creates a message with the correct ID and DLC from the database definition
- Database is **automatically attached** — `.Signals` is immediately available
- Signal assignment handles factor/offset/byte-order automatically:

```matlab
msg = canMessage(db, 'EngineData');
msg.Signals.EngineSpeed = 3000;
msg.Signals.EngineTemp = 90;
transmit(ch, msg);
```

## Decoding Received Messages

Received messages are raw (no database attached). Attach after receive:

```matlab
rx = receive(ch, 1);             % returns message object(s)
attachDatabase(rx, db);          % now rx.Signals is available
speed = rx.Signals.EngineSpeed;
temp = rx.Signals.EngineTemp;
```

**With timetable output:** Timetables don't support `attachDatabase`. Extract raw data and decode manually, or receive as objects:

```matlab
rx = receive(ch, 1);            % object output (not timetable)
attachDatabase(rx, db);
disp(rx.Signals.EngineSpeed);
```

## Key Behaviors

- DBC is the only supported database format for CAN (not ARXML — that's for system-level)
- `attachDatabase` is per-message, not per-channel
- Messages created via `canMessage(db, 'Name')` are auto-attached
- Signals with `ValueTable` entries map numeric values to string labels
- Database object is read-only after construction
- Signal assignment respects factor and offset from DBC: physical = raw * factor + offset

## Typical Pattern

```matlab
db = canDatabase('my_vehicle.dbc');
ch1 = canChannel('MathWorks', 'Virtual 1', 1);
ch2 = canChannel('MathWorks', 'Virtual 1', 2);
configBusSpeed(ch1, 500000);
configBusSpeed(ch2, 500000);
start(ch1);
start(ch2);

% Transmit using signal names (auto-attached from db)
msg = canMessage(db, 'EngineData');
msg.Signals.EngineSpeed = 3000;
msg.Signals.EngineTemp = 90;
transmit(ch1, msg);

pause(0.2);

% Receive and decode
rx = receive(ch2, 1);
attachDatabase(rx, db);
disp(rx.Signals.EngineSpeed);
disp(rx.Signals.EngineTemp);

stop(ch1);
stop(ch2);
```

----

Copyright 2026 The MathWorks, Inc.

----
