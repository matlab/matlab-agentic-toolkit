# Hardware Discovery

## canChannelList

```matlab
t = canChannelList;
```

Returns a table with columns: `Vendor`, `Device`, `Channel`, `DeviceModel`, `ProtocolMode`, `SerialNumber`.

## Platform and Driver Requirements

**Always available (no driver needed):**
- MathWorks Virtual — works on Windows and Linux

**Requires vendor driver installed:**
- Vector Virtual / Kvaser Virtual — only if their drivers are installed
- All physical devices require vendor-specific drivers

**Platform support:**
- **Windows:** Vector, NI, Kvaser, PEAK-System
- **Linux:** Kvaser, PEAK-System, SocketCAN (any hardware via socket interface)
- **Linux virtual:** SocketCAN virtual channels (`vcan`)
- **Windows-only:** Vector, NI

## Key Behaviors

- Physical hardware must be plugged in **before** MATLAB starts
- Kvaser specifically: if connected while MATLAB is running, must restart MATLAB
- `canChannelList` discovers all available devices across all installed vendors
- Use `ProtocolMode` column to verify CAN FD support before creating FD channels

---

Copyright 2026 The MathWorks, Inc.
