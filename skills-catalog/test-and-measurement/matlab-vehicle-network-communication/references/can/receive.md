# Receive

## receive

```matlab
msgs = receive(ch, numMsgs, OutputFormat="timetable");
msgs = receive(ch, numMsgs);
```

## Timetable Output (recommended)

```matlab
msgs = receive(ch, Inf, OutputFormat="timetable");
```

- Returns a timetable with columns: `Time`, `ID`, `Extended`, `Data`, `Length`, `Error`, `Remote`
- CAN FD timetables also include: `ProtocolMode`, `DLC`, `BRS`, `ESI`
- `Data` column is a cell array of `uint8` vectors
- `Inf` returns all available messages
- Returns empty timetable if nothing available (non-blocking)

## Object Output

```matlab
msgs = receive(ch, numMsgs);
```

- CAN Classic channels: returns array of message objects
- CAN FD channels: **always** returns a timetable regardless of `OutputFormat`

## Behavior

- Messages stored in FIFO buffer — oldest returned first
- Returns fewer messages if fewer are available than `numMsgs`
- Non-blocking — returns immediately with whatever is available
- Must poll in a loop; no callback/event-driven mode in script context

## Silent Mode — Receive-only, no bus impact

```matlab
ch.SilentMode = true;   % set before start
start(ch);
```

- Channel observes bus traffic without participating (no ACK, no error frames)
- Useful for bus monitoring and diagnostic tools that must not affect bus state
- Must be set **before** `start(ch)`
- Default is `false` (normal active participation)

## Typical Patterns

**Poll for messages with timeout:**
```matlab
deadline = tic;
timeout = 2.0; % seconds
received = [];
while toc(deadline) < timeout
    msgs = receive(ch, Inf, OutputFormat="timetable");
    if ~isempty(msgs)
        received = [received; msgs];
        break;
    end
    pause(0.05);
end
```

**Passive bus monitor (no bus impact):**
```matlab
ch = canChannel('MathWorks', 'Virtual 1', 1);
ch.SilentMode = true;
configBusSpeed(ch, 500000);
start(ch);
pause(10);
msgs = receive(ch, Inf);
stop(ch);
```

----

Copyright 2026 The MathWorks, Inc.

----
