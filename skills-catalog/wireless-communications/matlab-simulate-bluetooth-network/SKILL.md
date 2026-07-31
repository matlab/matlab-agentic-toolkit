---
name: matlab-simulate-bluetooth-network
description: >
    Simulate Bluetooth system-level networks using the Bluetooth Toolbox. Use this skill for any Bluetooth topology: BLE ACL (Asynchronous Connection-Less) data connections, CIS (Connected Isochronous Stream) and LE Audio for stereo speakers or hearing aids, BLE GAP (Generic Access Profile) connection establishment with advertising and scanning, Classic BR/EDR piconets with ACL data and SCO (Synchronous Connection-Oriented) voice links, and BLE+BR/EDR coexistence with adaptive frequency hopping. Covers bluetoothLENode, bluetoothNode, bluetoothLEConnectionConfig, bluetoothLECISConfig, bluetoothLEGAPConfig, bluetoothConnectionConfig, configureConnection, kpi (), updateChannelList, and all Bluetooth statistics.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2026a"
metadata:
  author: MathWorks
  version: "1.0"
---

# Bluetooth System-Level Simulation

Entry point for all Bluetooth system-level simulation. All Bluetooth simulations use `sim = wirelessNetworkSimulator.init` and follow the workflow defined in `matlab-simulate-wireless-network` (simulator init, traffic, mobility, instrumentation, addNodes, run).

## When to Use

- BLE ACL point-to-point or star network connections
- LE Audio unicast with CIS/CIG (stereo speakers, hearing aids)
- BLE GAP connection establishment (advertising, scanning, connection timing)
- Classic BR/EDR piconets with ACL data or SCO voice
- BLE + BR/EDR coexistence with adaptive frequency hopping
- Any simulation using `bluetoothLENode`, `bluetoothNode`

## When Not to Use

- Non-Bluetooth wireless simulations (use `matlab-simulate-wireless-network` instead)
- PHY-layer or link level Bluetooth waveform generation, receiver analysis or BER analysis
- Generic simulator setup, traffic models, or mobility (use `matlab-simulate-wireless-network`)

## Scenario → Reference Routing

| Scenario | Reference |
|----------|-----------|
| BLE realistic connection setup (advertising, scanning, GAP) | `references/ble-gap-connection.md` |
| BLE point-to-point data, star network, ACL connections | `references/ble-connection.md` |
| LE Audio unicast (stereo speakers, hearing aids, CIS/CIG) | `references/ble-cis.md` |
| Classic Bluetooth earbuds, SCO voice, ACL data | `references/bluetooth-bredr.md` |
| BLE + BR/EDR coexistence, adaptive frequency hopping | `references/bluetooth-coexistence.md` |
| Capture and visualization (PCAP, IQ, event tracing, traffic viewer) | See `matlab-simulate-wireless-network` skill |

## Node Roles

- BLE (ACL, CIS): `bluetoothLENode("central")`, `bluetoothLENode("peripheral")`
- BR/EDR: `bluetoothNode("central")`, `bluetoothNode("peripheral")` — max 7 peripherals per central

## Traffic Attachment Rules

`addTrafficSource(sourceNode, traffic, ...)`:
- **ACL/CIS/BR/EDR**: `DestinationNode=peer` required. CIS also needs `CISConfig=cfgCISOut`.
- **BR/EDR SCO**: No traffic call — implicit via `SCOPacketType` in connection config.

## kpi() Availability

| Topology | `"throughput"` | `"latency"` | `"PLR"` / `"PDR"` | Layer |
|----------|:-:|:-:|:-:|-------|
| BLE ACL | LL only | App only | Both LL and App | `"LL"` or `"App"` |
| BLE CIS | LL only | App only | Both LL and App | `"LL"` or `"App"` |
| BR/EDR | Baseband | — | Baseband | `"Baseband"` |

## Connection/Configuration Setup

| Topology | Config Object | Function | Notes |
|----------|--------------|----------|-------|
| BLE ACL | `bluetoothLEConnectionConfig` | `configureConnection(cfg, central, peripheral)` | Per-peripheral in loop; unique `AccessAddress` per connection |
| BLE CIS | `bluetoothLEConnectionConfig` + `bluetoothLECISConfig` | `[~, cfgCISOut] = configureConnection(cfg, central, peripheral, CISConfig=cfgCIS)` | Pass `cfgCISOut` to `addTrafficSource(..., CISConfig=cfgCISOut)` |
| BR/EDR | `bluetoothConnectionConfig` | `configureConnection(cfg, central, peripherals)` | Single call with vector of peripherals |

## Common Mistakes

- **`bluetoothNode` for BLE** (or vice versa): BR/EDR = `bluetoothNode`, BLE = `bluetoothLENode`
- **Wrong kpi Layer**: BLE throughput → `"LL"`, BLE latency → `"App"`, BR/EDR → `"Baseband"` only
- **Properties locked after `run()`**: Node/connection properties cannot change mid-sim. Use `updateChannelList` for mid-sim channel updates.
- **`configureConnection` with peripheral vector for BLE**: Must call per-peripheral in loop (BR/EDR accepts vector)
- **Unique `AccessAddress` per connection**: Each BLE connection on same central needs different AccessAddress
- **DataRate in Kbps**: `DataRate=100` means 100 Kbps, not 100 bps
- **`GeneratePacket=true` is not valid**: Not applicable for network-level simulation. Use `OnTime=Inf` for continuous traffic.

<!-- Copyright 2026 The MathWorks, Inc. -->

