# Simple demultiplexing

Decode multiplexed CAN messages using simple multiplexing by filtering signal values based on the multiplexor value.

## Pipeline

**Read DBC using canDatabase()**

Read the DBC file calling `canDatabase()`. For those messages that do not use multiplexing, and for those that use simple multiplexing,  `canDatabase()` provides the structured metadata needed for decoding.
```matlab
db = canDatabase("path/to/file.dbc");
```
Map the IDs of messages using extended/hierarchical multiplexing to message names using `db.MessageInfo` and inform the user:

> "Message [name] uses extended/hierarchical multiplexing, which is out of scope for simple demultiplexing. Only messages with simple multiplexing (one multiplexor, flat multiplexed signals) will be decoded correctly."

Only proceed with messages whose ID is not in `extendedMuxMsgIds` and that use simple multiplexing, or with messages that don't use any multiplexing (i.e. containing regular signals).
Just skip any processing of messages in `extendedMuxMsgIds`.

**Extract multiplexing metadata if applicable:**

```matlab
msgInfo = db.MessageInfo;
```
For each message that uses simple multiplexing, check its multiplexing metadata and prepare to filter signals:
```matlab
for m = 1:numel(msgInfo)
    signals = msgInfo(m).SignalInfo;
    hasMultiplexor = any([signals.Multiplexor]);
    hasMultiplexed = any([signals.Multiplexed]);
    if hasMultiplexor && hasMultiplexed
        fprintf("Message ""%s"" uses multiplexing.\n", msgInfo(m).Name);
    end
end
```
The `SignalInfo` struct has these multiplexing fields:

| Field | Type | Meaning |
|-------|------|---------|
| `Multiplexor` | logical | `true` if this signal is the multiplexor (selector) |
| `Multiplexed` | logical | `true` if this signal is conditionally present |
| `MultiplexMode` | double | The multiplexor value that makes this signal valid |

**Decode Signals Using `canSignalTimetable()`**

Given a CAN message timetable (from any source — `blfread`, `canChannel`, log file import, or workspace variable), extract signal values.
`canSignalTimetable` extracts ALL signals from a message timetable, for given message names, and it does not account for multiplexing. The resulting timetable contains columns for every signal in the message, including multiplexed signals that may be invalid in some rows.
Call `canSignalTimetable` for messages that uses simple multiplexing or no multiplexing.

**Filter by Multiplexor Value**

For each multiplexed signal, replace values with `NaN` in rows where the multiplexor value does not match that signal's `MultiplexMode`.
Example code - Extract signal timetable and filter by multiplexor value:
```matlab
msgName = "OBD2_Message";
thisMsg = msgInfo(strcmp({msgInfo.Name}, msgName));
signals = thisMsg.SignalInfo;

% Find the multiplexor signal name
muxorIdx = [signals.Multiplexor];
muxorName = signals(muxorIdx).Name;

% Filter multiplexed signals
for i = 1:numel(signals)
    if signals(i).Multiplexed
        validRows = sigTT.(muxorName) == signals(i).MultiplexMode;
        sigTT.(signals(i).Name)(~validRows) = NaN;
    end
end
```

After filtering, the timetable contains:
- Multiplexor column: always valid (the selector value)
- Regular signals: always valid (non-multiplexed)
- Multiplexed signals (with simple multiplexing): valid only in rows where multiplexor matches their `MultiplexMode`; `NaN` otherwise


## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Calling `messageNames()` on canDatabase | This method does not exist | Use `db.MessageInfo` for the struct array with signal metadata, or `db.Messages` for the cell array of message names |
| Using `SignalInfo.Length` | Field does not exist | The field is `SignalInfo.SignalSize` |
| Skipping `canSignalTimetable()` | Building custom decoding logic is error-prone and misses scaling/offset | Always use `canSignalTimetable(msgTT, msgName)` |
| Showing all signal values without filtering | Multiplexed signals contain garbage in non-matching rows | Filter with `NaN` using `MultiplexMode` comparison |
| Attempting to decode extended-multiplexed messages | Simple filtering logic does not handle hierarchical multiplexors | Detect extended/hierarchical multiplexing and inform the user it is out of scope and skip those messages |
| Trying to infer the multiplexing scheme from the `canDatabase` object instance | For R2026a and earlier, the object instance does not contain enough information to determine the multiplexing scheme | Detect extended multiplexing by reading the database file as text and inform the user it is out of scope |

## Conventions

- Always replace invalid multiplexed values with `NaN`, not with zero or empty
- Never attempt decoding of extended/hierarchical multiplexing — just inform the user

----

Copyright 2026 The MathWorks, Inc.
