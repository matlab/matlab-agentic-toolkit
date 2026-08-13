# Vendor and Platform Limitations

## Kvaser

- Must connect device **before** starting MATLAB
- If connected while MATLAB is running, you'll see:
  > "Vehicle Network Toolbox has detected a supported Kvaser device. To enable the device, shut down MATLAB. Then with the device connected, restart MATLAB."
- **Linux support:** Two paths available:
  - `'Kvaser'` vendor string — requires Kvaser CANlib drivers (linuxcan package)
  - `'SocketCAN'` vendor string — uses kernel SocketCAN layer; Kvaser hardware registers as `can0`, `can1`, etc.
  - Both are valid; `'Kvaser'` gives direct access, `'SocketCAN'` abstracts behind the kernel

## Vector

- **Windows only**
- Maximum 64 physical or 32 virtual simultaneous connections
- Exceeding gives: `"Unable to query hardware information for the selected CAN channel object."`

## NI (NI-XNET)

- **Windows only**
- Cannot have more than one `canChannel` on the same NI-XNET device channel

## PEAK-System

- Cannot have more than one `canChannel` on the same PEAK-System device channel
- **Self-receive (CAN and CAN FD) supported only on Windows**
- On Linux: use SocketCAN functionality as workaround

## SocketCAN

- **Linux only**
- `configBusSpeed` not supported — configure speed at OS level:
  ```bash
  sudo ip link set can0 type can bitrate 500000
  sudo ip link set can0 up
  ```
- Supports virtual channels via `vcan` interface

## General

- Cannot create arrays of CAN channel objects — each must be its own variable
- Cannot reuse a variable for a new channel without clearing it first
- Only one object can hold InitializationAccess per physical channel
- CAN requires at least one other node to acknowledge transmissions

----

Copyright 2026 The MathWorks, Inc.

----
