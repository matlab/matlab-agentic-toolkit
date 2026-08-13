# Pack / Unpack

## pack — Encode a signal value into message data bytes

```matlab
pack(msg, value, startBit, signalLength, byteOrder);
```

- `msg` — `canMessage` or `canFDMessage` object
- `value` — numeric value to encode (cast determines signedness: `int16`, `uint8`, etc.)
- `startBit` — 0-based bit position where signal starts
- `signalLength` — number of bits the signal occupies
- `byteOrder` — `'LittleEndian'` or `'BigEndian'`

**Writes directly to `msg.Data`** — triggers `transmitEvent` if enabled.

## unpack — Decode a signal value from message data bytes

```matlab
value = unpack(msg, startBit, signalLength, byteOrder, dataType);
```

- `dataType` — output type string: `'int8'`, `'uint16'`, `'single'`, `'double'`, etc.
- Returns the decoded numeric value

## Key Behaviors

- `pack`/`unpack` work on **message objects**, not timetables
- For received timetables: extract the message first, then unpack:
  ```matlab
  msgs = receive(ch, Inf, 'OutputFormat', 'timetable');
  rawData = msgs.Data{1};  % uint8 array
  value = typecast(rawData(1:2), 'int16');  % manual decode
  ```
- Byte order must match the DBC/signal specification exactly
- The `value` type in `pack` determines sign extension: use `int16(-500)` for signed signals
- For CAN FD messages with DLC > 8, bit positions extend beyond 63

## pack vs Database Signals

| Approach | When to Use |
|----------|-------------|
| `pack`/`unpack` | No DBC available, or working with raw proprietary protocols |
| `msg.Signals.Name = value` | DBC attached — handles factor, offset, byte order automatically |

Database signals are higher-level: `msg.Signals.EngineSpeed = 3000` internally calls the equivalent of `pack` with the correct parameters from the DBC definition.

## Typical Patterns

**Manual encode/decode (no database):**
```matlab
msg = canMessage(0x180, false, 8);
pack(msg, int16(3000), 0, 16, 'LittleEndian');   % speed at bits 0-15
pack(msg, uint8(85), 16, 8, 'LittleEndian');     % temp at bits 16-23
transmit(ch, msg);

% On receive side:
rxMsg = receive(ch, 1);
speed = unpack(rxMsg, 0, 16, 'LittleEndian', 'int16');
temp = unpack(rxMsg, 16, 8, 'LittleEndian', 'uint8');
```

**CAN FD with large payload:**
```matlab
msg = canFDMessage(0x300, false, 64);
pack(msg, single(3.14), 0, 32, 'LittleEndian');    % float at bits 0-31
pack(msg, uint32(12345), 32, 32, 'LittleEndian');  % counter at bits 32-63
```

**Event-triggered transmit with pack:**
```matlab
msg = canMessage(0x200, false, 8);
transmitEvent(ch, msg, 'On');
start(ch);

% Each pack writes .Data, triggering auto-transmit
pack(msg, int16(value), 0, 16, 'LittleEndian');
```

----

Copyright 2026 The MathWorks, Inc.

----
