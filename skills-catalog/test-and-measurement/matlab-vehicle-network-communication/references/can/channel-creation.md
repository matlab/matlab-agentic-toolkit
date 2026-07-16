# Channel Creation

## canChannel

```matlab
% CAN Classic
ch = canChannel(vendor, device, chIndex);

% CAN FD via ProtocolMode
ch = canChannel(vendor, device, chIndex, 'ProtocolMode', 'CAN FD');
```

## canFDChannel

```matlab
% Dedicated CAN FD constructor
ch = canFDChannel(vendor, device, chIndex);
ch = canFDChannel(vendor, device);  % for vendors without channel index
```

## Vendor-Specific Syntax

```matlab
% Vector (3-arg: vendor, device, channel index)
ch = canChannel("Vector", "VN1610 1", 1);
ch = canChannel("Vector", "Virtual 1", 2);

% Kvaser (3-arg: vendor, device, channel index)
ch = canChannel("Kvaser", "USBcan Pro 1", 1);

% NI (2-arg: no channel index)
ch = canChannel("NI", "CAN1");

% PEAK-System (2-arg: no channel index)
ch = canChannel("PEAK-System", "PCAN_USBBUS1");

% SocketCAN (2-arg: interface name)
ch = canChannel("SocketCAN", "can0");

% MathWorks Virtual (3-arg)
ch = canChannel("MathWorks", "Virtual 1", 2);
```

## Constraints

- Device string must match `canChannelList` output exactly
- Only one object can hold **InitializationAccess** per physical channel
- **NI-XNET and PEAK-System:** cannot have more than one `canChannel` on the same device channel
- Cannot reuse the same variable — must `clear` before creating a new channel in that variable
- Cannot create arrays of CAN channel objects — each must be its own variable
- Failing to `clear`/`stop` old channel objects locks the hardware

---

Copyright 2026 The MathWorks, Inc.
