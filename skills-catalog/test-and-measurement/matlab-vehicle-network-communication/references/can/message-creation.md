# Message Creation

## canMessage — CAN Classic or CAN FD

```matlab
% CAN Classic (DLC 0–8)
msg = canMessage(id, isExtended, dlc);

% CAN FD via ProtocolMode
msg = canMessage(id, isExtended, dlc, ProtocolMode="CAN FD");

% From database definition
msg = canMessage(candb, "MessageName");
```

- `id`: numeric CAN identifier
- `isExtended`: `false` = 11-bit ID (0x000–0x7FF), `true` = 29-bit ID (0x00000000–0x1FFFFFFF)
- `dlc`: data length in bytes
- Database messages inherit `ProtocolMode` from the DB — cannot override

## canFDMessage — CAN FD Only

```matlab
msg = canFDMessage(id, isExtended, dlc);
msg = canFDMessage(candb, "MessageName");
```

Equivalent to `canMessage(..., ProtocolMode="CAN FD")`.

## Setting Data

```matlab
msg.Data = uint8([0xDE 0xAD 0xBE 0xEF 0x01 0x02 0x03 0x04]);
```

- Data must be `uint8` array matching the specified DLC

## Valid DLC Sizes

| Protocol | Valid DLC values |
|----------|-----------------|
| CAN Classic | 0, 1, 2, 3, 4, 5, 6, 7, 8 |
| CAN FD | 0, 8, 12, 16, 20, 24, 32, 48, 64 |

## Common Mistake

Using `canMessage(id, ext, 64)` without `ProtocolMode="CAN FD"` gives:
```
Error: Expected DATALENGTH to be an array with all of the values <= 8.
```
Fix: use `canFDMessage` or add `ProtocolMode="CAN FD"`.

----

Copyright 2026 The MathWorks, Inc.

----
