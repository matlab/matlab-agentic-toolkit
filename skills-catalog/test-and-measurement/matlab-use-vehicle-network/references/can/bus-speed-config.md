# Bus Speed Configuration

## configBusSpeed

Must be called while channel is **offline** (before `start`). Channel must have initialization access.

**Not supported for SocketCAN** — speed is configured at OS level via `ip link`.

## CAN Classic

```matlab
% Simple form (all vendors except SocketCAN)
configBusSpeed(ch, busspeed);

% Advanced timing
configBusSpeed(ch, busspeed, SJW, TSeg1, TSeg2, numsamples);
```

## CAN FD — Vendor-Specific Syntax

### NI and MathWorks Virtual (simple form)
```matlab
configBusSpeed(ch, arbBusSpeed, dataBusSpeed);
```
Example:
```matlab
ch = canChannel('MathWorks', 'Virtual 1', 1, 'ProtocolMode', 'CAN FD');
configBusSpeed(ch, 1000000, 2000000);
```

### Kvaser and Vector (advanced form, required)
```matlab
configBusSpeed(ch, arbSpeed, arbSJW, arbTSeg1, arbTSeg2, dataSpeed, dataSJW, dataTSeg1, dataTSeg2);
```
Example:
```matlab
ch = canChannel('Vector', 'VN1610 1', 1, 'ProtocolMode', 'CAN FD');
configBusSpeed(ch, 1e6, 2, 6, 3, 2e6, 2, 6, 3);
```

### PEAK-System (clock-based form)
```matlab
configBusSpeed(ch, clockFreq, arbBRP, arbSJW, arbTSeg1, arbTSeg2, dataBRP, dataSJW, dataTSeg1, dataTSeg2);
```
Example:
```matlab
ch = canChannel('PEAK-System', 'PCAN_USBBUS1', 'ProtocolMode', 'CAN FD');
configBusSpeed(ch, 20, 5, 1, 2, 1, 2, 1, 3, 1);
```

## Defaults

| Parameter | Default |
|-----------|---------|
| busspeed / arbBusSpeed | 500000 |
| dataBusSpeed | 2000000 |
| SJW / arbSJW | 1 (Kvaser), 2 (Vector), 1 (PEAK) |
| TSeg1 / arbTSeg1 | 4 (classic), 6 (Vector FD), 5 (PEAK FD) |
| TSeg2 / arbTSeg2 | 3 (classic/Vector FD), 2 (PEAK FD) |
| arbBRP | 5 |
| dataBRP | 2 |

## Important

- For CAN FD channels, you **must** call `configBusSpeed` before `start`
- **Vector/Kvaser/PEAK:** The simple 3-arg form `configBusSpeed(ch, arbSpeed, dataSpeed)` does NOT work — you must use the full advanced form with timing parameters. If defaults (500k/2M) are acceptable, you can skip `configBusSpeed` entirely, but if you need non-default speeds, the advanced form is mandatory.
- **NI/MathWorks Virtual:** The simple 3-arg form works.
- All nodes on the bus must agree on speed settings
- SJW controls resynchronization width — keeps clock drift between nodes in check

----

Copyright 2026 The MathWorks, Inc.

----
