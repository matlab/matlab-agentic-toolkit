# Transmit

## transmit — One-shot send

```matlab
transmit(ch, msg);
```

- Non-blocking — returns immediately
- Ignores `Timestamp` and `Error` properties on the message
- **CAN is peer-to-peer:** at least one other node must be present on the physical bus to acknowledge. Without another node, transmission fails as an error frame and the device retries continuously.

## transmitPeriodic — Fixed interval

```matlab
transmitPeriodic(ch, msg, 'On', period);   % enable (period in seconds, default 0.5)
transmitPeriodic(ch, msg, 'Off');           % disable
```

- Can enable/disable **while channel is running**
- Changing `msg.Data` (e.g., via `pack`) updates what gets sent on next cycle
- Period is in seconds (numeric)

## transmitEvent — Send on data write

```matlab
transmitEvent(ch, msg, 'On');
transmitEvent(ch, msg, 'Off');
```

- Triggers transmission on any `.Data` property **assignment** — even if the value is identical
- `pack(msg, ...)` triggers event transmit because it writes to `.Data` internally
- Typically used with `pack(msg, value, startBit, length, byteOrder)` for signal-level updates
- Multiple messages can be event-enabled on the same channel independently

## Combining Periodic + Event

Different messages on the same channel can have independent transmit modes:

```matlab
statusMsg = canMessage(0x180, false, 8);   % telemetry
alarmMsg = canMessage(0x700, false, 8);    % fault notification

transmitPeriodic(ch, statusMsg, 'On', 0.1);  % 100ms cycle
transmitEvent(ch, alarmMsg, 'On');           % only on fault

start(ch);

% Update periodic data live — next cycle uses new value
pack(statusMsg, int16(3000), 0, 16, 'LittleEndian');

% Trigger alarm only when needed
alarmMsg.Data = uint8([0x01 92 0 0 0 0 0 0]);
```

**Typical pattern:** Periodic for status/telemetry, event-based for alarms/faults.

## replay — Retransmit with original timing

```matlab
replay(ch, msgs);
```

- Retransmits messages based on relative differences of their timestamps
- Input: timetable of messages, message object, or array of message objects
- Also works from MATLAB to Simulink

## transmitConfiguration — View current setup

```matlab
transmitConfiguration(ch);
```

- Displays all periodic and event-based messages configured on the channel
- Shows: ID, Extended flag, Name, Data, Rate (for periodic)

----

Copyright 2026 The MathWorks, Inc.

----
