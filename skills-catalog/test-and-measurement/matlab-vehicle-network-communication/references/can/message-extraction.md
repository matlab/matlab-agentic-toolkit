# Message Extraction and Timetables

## Extract Utilities — Filter message arrays after receive

All three work on **arrays of CAN message objects** (not timetables).

### extractAll — Get all instances of a specific message

```matlab
extracted = extractAll(msgs, id, extended);
extracted = extractAll(msgs, 'MessageName');
[extracted, remainder] = extractAll(msgs, id, extended);
```

- `id` — numeric CAN ID to match
- `extended` — `true` for 29-bit IDs, `false` for 11-bit standard
- `'MessageName'` — requires database attached to messages
- Second output `remainder` contains all non-matching messages

### extractRecent — Get most recent instance per message type

```matlab
recent = extractRecent(msgs);                 % one per unique ID
recent = extractRecent(msgs, id, extended);   % most recent of a specific ID
recent = extractRecent(msgs, 'MessageName');
```

- With no filter: returns one message per unique ID (the latest of each)
- With ID or name filter: returns the single most recent matching message

### extractTime — Get messages within a time window

```matlab
extracted = extractTime(msgs, startTime, endTime);
```

- `startTime`, `endTime` — seconds (relative to channel start)
- Returns all messages with timestamps within [startTime, endTime]

## Timetable Conversion — For analysis and plotting

### canMessageTimetable — Convert messages to timetable

```matlab
msgTT = canMessageTimetable(msgs);
msgTT = canMessageTimetable(msgs, db);
```

- Input: message object array, struct, or existing timetable
- With `db`: adds `Name` and `Signals` columns from database definitions
- Output columns: `Time`, `ID`, `Extended`, `Name`, `Data`, `Length`, `Signals`, `Error`, `Remote`
- Useful for `timetable` operations: filtering, sorting, synchronizing with other signals

### canSignalTimetable — Decode signals into a clean timetable

```matlab
sigTT = canSignalTimetable(msgTT);
sigTT = canSignalTimetable(msgTT, 'MessageName');
```

- Input: a message timetable (from `canMessageTimetable` with database)
- Output: timetable with **one column per signal** (numeric values, properly scaled)
- With message name: filters to only that message's signals
- **Requires** the message timetable was created with a database attached

## Key Behaviors

- `extractAll`/`extractRecent`/`extractTime` operate on **message object arrays**, NOT timetables
- `canMessageTimetable`/`canSignalTimetable` produce **timetables** for analysis
- Use `extractAll` to separate a mixed-traffic capture by message ID before decoding
- `canSignalTimetable` is the fastest path from raw receive to plotable signal data
- Signal columns in the output timetable have proper units and scaling from the DBC

## discard — Clear the receive FIFO

```matlab
discard(ch);
```

- Drops all buffered messages from the channel's receive FIFO
- Use before starting a measurement to clear stale data from a previous run
- Channel must be running (after `start`)
- Does NOT stop the channel — just empties the buffer

## Typical Patterns

**Capture, then extract by ID:**
```matlab
start(ch);
pause(5);
allMsgs = receive(ch, Inf);
engineMsgs = extractAll(allMsgs, 0x180, false);
brakeMsgs = extractAll(allMsgs, 0x250, false);
```

**Convert to signal timetable for plotting:**
```matlab
db = canDatabase('vehicle.dbc');
allMsgs = receive(ch, Inf);
msgTT = canMessageTimetable(allMsgs, db);
sigTT = canSignalTimetable(msgTT, 'EngineData');
plot(sigTT.Time, sigTT.EngineSpeed);
```

**Get latest snapshot of all ECU values:**
```matlab
allMsgs = receive(ch, Inf);
snapshot = extractRecent(allMsgs);
```

**Discard stale data before measurement:**
```matlab
start(ch);
pause(1);          % let bus stabilize
discard(ch);       % clear stale messages
pause(5);          % actual measurement window
data = receive(ch, Inf);
```

---

Copyright 2026 The MathWorks, Inc.
