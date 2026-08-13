# Filters

## filterAllowOnly — Pass specific IDs

**By numeric ID (requires identifier type):**
```matlab
filterAllowOnly(ch, ids, 'Standard');    % standard (11-bit) IDs
filterAllowOnly(ch, ids, 'Extended');    % extended (29-bit) IDs
```

**By message name (requires `ch.Database` set first):**
```matlab
ch.Database = db;
filterAllowOnly(ch, 'MessageName');
filterAllowOnly(ch, {'Msg1', 'Msg2'});
```

- `ids` — numeric scalar or vector of CAN IDs to allow through
- The `type` argument (`'Standard'` or `'Extended'`) is **required** when filtering by numeric ID
- All other IDs are blocked at the hardware level (never reach MATLAB FIFO)
- Must be called **before** `start(ch)` — error if channel is already running
- Calling again **replaces** the previous filter (does not append)

## filterBlockAll — Block all messages of a type

```matlab
filterBlockAll(ch, 'Standard');    % block all standard (11-bit) IDs
filterBlockAll(ch, 'Extended');    % block all extended (29-bit) IDs
```

- The `type` argument is **required** — there is no zero-argument form
- Blocks all incoming messages of the specified ID type at the hardware level
- To block both standard and extended, call twice:
  ```matlab
  filterBlockAll(ch, 'Standard');
  filterBlockAll(ch, 'Extended');
  ```
- Useful when channel is transmit-only or before selectively opening IDs
- Must be called before `start(ch)`

## filterAllowAll — Reset to pass everything of a type

```matlab
filterAllowAll(ch, 'Standard');    % allow all standard (11-bit) IDs
filterAllowAll(ch, 'Extended');    % allow all extended (29-bit) IDs
```

- The `type` argument is **required** — there is no zero-argument form
- Removes filter restrictions for the specified ID type — those IDs pass through
- This is the default state of a newly created channel (both types allowed)
- Must be called before `start(ch)`

## Key Behaviors

- Filters operate at the **hardware/driver level**, not in MATLAB — reduces CPU load and FIFO overflow risk on busy buses
- Filter state resets to allow-all when channel is cleared or recreated
- Combining standard and extended: call `filterAllowOnly` twice with different ID type arguments
- **SocketCAN:** filters are supported via kernel-level filtering
- **MathWorks Virtual:** filters work identically to physical hardware

## Typical Patterns

**Monitor a single ECU (standard IDs):**
```matlab
ch = canChannel('MathWorks', 'Virtual 1', 1);
filterAllowOnly(ch, [0x180 0x181 0x182], 'Standard');
start(ch);
```

**Transmit-only channel (suppress all receive):**
```matlab
ch = canChannel('MathWorks', 'Virtual 1', 2);
filterBlockAll(ch, 'Standard');
filterBlockAll(ch, 'Extended');
start(ch);
```

**Standard + Extended mix:**
```matlab
filterAllowOnly(ch, [0x100 0x200], 'Standard');
filterAllowOnly(ch, [0x18FEF100], 'Extended');
```

----

Copyright 2026 The MathWorks, Inc.

----
