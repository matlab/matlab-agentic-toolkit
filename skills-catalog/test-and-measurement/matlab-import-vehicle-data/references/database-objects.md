# Database Objects: canDatabase, arxmlDatabase, linDatabase

For function syntax, run `help canDatabase`, `help arxmlDatabase`, or `help linDatabase` in MATLAB.

Vehicle Network Toolbox provides three database object types for decoding raw bus messages into named signals.

## canDatabase -- DBC Files (CAN / CAN FD)

```matlab
db = canDatabase("path/to/file.dbc");
```

The most common database type. DBC files define message IDs, signal names, bit positions, scaling, and units. Supports both standard CAN and CAN FD.

**Multiple databases:**
```matlab
db1 = canDatabase("powertrain.dbc");
db2 = canDatabase("chassis.dbc");
msgTT = canMessageTimetable(tt, [db1, db2]);
```

Introduced in R2009a.

---

## arxmlDatabase -- ARXML Files (CAN Only)

```matlab
db = arxmlDatabase("path/to/file.arxml");
```

Alternative to `canDatabase` for AUTOSAR-based workflows. Use when the team's database of record is ARXML rather than DBC.

**CAN FD limitation:** `arxmlDatabase` does **not** support CAN FD. It cannot be used with `canFDMessageTimetable` or with CAN FD data in BLF files. For CAN FD, use `canDatabase` (DBC).

Introduced in R2025a.

---

## linDatabase -- LDF Files (LIN)

```matlab
db = linDatabase("path/to/file.ldf");
```

For LIN (Local Interconnect Network) protocol decoding. LDF files define LIN frame IDs, signal layouts, and scheduling tables.

See [LIN decode](lin-decode.md) for the full decode pipeline and signal access patterns.

Introduced in R2025a.

---

## Choosing the Right Database

| Protocol | File Format | Function | Minimum Release |
|----------|-------------|----------|-----------------|
| CAN | `.dbc` | `canDatabase` | R2009a |
| CAN FD | `.dbc` | `canDatabase` | R2009a |
| CAN (AUTOSAR) | `.arxml` | `arxmlDatabase` | R2025a |
| LIN | `.ldf` | `linDatabase` | R2025a |

## Compatibility Matrix

| Decode Function | canDatabase | arxmlDatabase | linDatabase |
|----------------|-------------|---------------|-------------|
| `canSignalImport` | Yes | Yes (R2025a+) | No |
| `canMessageImport` | Yes | Yes | No |
| `canMessageTimetable` | Yes | Yes | No |
| `canFDMessageTimetable` | Yes | **No** | No |
| `canSignalTimetable` | Yes (CAN + CAN FD) | Yes (CAN only) | No |
| `blfread` (CAN) | Yes | Yes | No |
| `blfread` (CAN FD) | Yes | **No** | No |
| `blfread` (LIN) | No | No | Yes (with ProtocolMode="LIN") |
| `linMessageTimetable` | No | No | Yes |

----

Copyright 2026 The MathWorks, Inc.
