---
name: matlab-simulate-wireless-network
description: >
  Set up and run wireless network simulations using the Wireless Network Toolbox.
  Use this skill when creating system-level simulations with wirelessNetworkSimulator,
  adding traffic sources (networkTrafficOnOff, networkTrafficFTP, networkTrafficVoIP, networkTrafficVideoConference),
  configuring node mobility, logging events or IQ samples, visualizing traffic,
  scheduling actions during simulation, running parametric sweeps, writing PCAP
  files with pcapWriter or technology-specific PCAP writers,
  registering event callbacks on wireless nodes, accessing event data fields,
  or combining multiple capture/visualization tools in a simulation.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
compatibility: ">=R2026a"
metadata:
  author: MathWorks
  version: "1.0"
---

# Wireless Network Simulation Fundamentals

Foundation patterns for system-level wireless simulation. Technology-specific skills build on these for node creation, connection configuration, and KPI extraction.

## When to Use

- Creating system-level wireless network simulations with `wirelessNetworkSimulator`
- Adding traffic sources (`networkTrafficOnOff`, `networkTrafficFTP`, `networkTrafficVoIP`, `networkTrafficVideoConference`)
- Configuring node mobility (random waypoint, custom models)
- Logging events or IQ samples with `wirelessNetworkEventTracer` or IQ logger
- Visualizing traffic with `wirelessTrafficViewer` and network layout with `wirelessNetworkViewer`
- Scheduling actions during simulation with `scheduleAction`
- Running parametric sweeps over simulation parameters
- Writing PCAP files with `pcapWriter` or technology-specific PCAP writers
- Creating custom nodes by subclassing `wnet.Node`
- Registering event callbacks on wireless nodes

## When Not to Use

- PHY-layer or link-level simulations without `wirelessNetworkSimulator`
- Bluetooth-specific topology setup (use `matlab-simulate-bluetooth-network` instead)
- WLAN-specific or 5G NR-specific configuration (use the respective technology skills)
- Signal processing or waveform generation tasks

## Node Creation

All nodes in the simulator inherit from `wnet.Node`. Choose the correct node type:

| Technology | Node Constructor | Notes |
|-----------|-----------------|-------|
| Bluetooth LE | `bluetoothLENode("central")` / `bluetoothLENode("peripheral")` | Use the `matlab-simulate-bluetooth-network` skill |
| Classic Bluetooth BR/EDR | `bluetoothNode("central")` / `bluetoothNode("peripheral")` | Use the `matlab-simulate-bluetooth-network` skill |
| WLAN | `wlanNode(...)` | Requires WLAN Toolbox |
| 5G NR | `nrGNB(...)` / `nrUE(...)` | Requires 5G Toolbox |
| **Any other / custom** | **Subclass `wnet.Node`** | See `references/custom-node.md` |

**`wnet.Node` is abstract — never instantiate it directly.** If the scenario does not use a specific technology listed above, you MUST create a custom node class that inherits from `wnet.Node`. Technology nodes (`bluetoothLENode`, `bluetoothNode`, `wlanNode`, `nrGNB`, `nrUE`) implement the `wnet.Node` interface internally — properties like `Position`, `ID`, `Name`, `Velocity`, `addMobility`, `registerEventCallback`, and `statistics` work on all node types.

## Workflow

Every system-level simulation follows this order:

1. `wirelessNetworkSimulator.init` (MUST be first)
2. Create nodes — use technology-specific constructors when available, otherwise subclass `wnet.Node` (see `references/custom-node.md`)
3. Configure connections (technology-specific)
4. `addTrafficSource` (technology nodes only, vectorized for multiple destinations; custom nodes generate traffic in `run()`)
5. `addMobility` (optional)
6. Instrumentation — event tracer, IQ logger, traffic viewer (optional)
7. `addNodes(sim, nodes)` (batch, one call per technology type)
8. `run(sim, duration)` or multi-step with `IsLastStep=false`
9. `statistics()` or technology-specific KPI functions

## Simulator Initialization

`wirelessNetworkSimulator.init` MUST be the first executable statement. The simulator is a singleton — calling `.init` reinitializes it. Never use a constructor (`wirelessNetworkSimulator()` — doesn't exist).

```matlab
clearvars;
rng("default");
sim = wirelessNetworkSimulator.init;
```

## Custom Node (`wnet.Node` Subclass)

Override 5 methods: `run`, `pullTransmittedPacket`, `pushReceivedPacket`, `isPacketRelevant`, `statistics`. **Always use `pkt = wirelessPacket` to create packet structures** — this initializes all required fields including `Metadata.Channel` (needed by the channel model). Use `wnet.TechnologyType.Custom1`–`Custom9` for the TechnologyType field. See `references/custom-node.md` for the full method table, packet fields, receive buffering pattern, and example.

**Access specifiers:** All overridden methods must match the parent `wnet.Node` access specifier. In R2026a, `run`, `pullTransmittedPacket`, `pushReceivedPacket`, `isPacketRelevant`, and `statistics` are all `public` in `wnet.Node`. Place them in a single `methods` block (default public) alongside the constructor. Using a different access specifier (e.g., `protected`) causes a MATLAB error.

**Critical:** `run()` must guard transmissions with `NextTxTime` and `round(..., 9)` — the simulator re-invokes `run()` at the same `currentTime` after delivering received packets. Without the guard, 2+ nodes cause an infinite loop.

**Troubleshooting:** If encountering errors with custom node creation, refer to the built-in example for a working implementation: `openExample("wnet/CreateAndSimulateWirelessNetworkOfCustomNodesExample")`. Inspect the custom node class code for correct method signatures and access specifiers.

## Vectorized Node Creation

Any supported node type can create multiple nodes with `Position=[N×3]` and `Name=[1×N string]`:

```matlab
nodes = NodeConstructor(Position=[5 0 0; 0 5 0; -5 0 0], Name=["N1", "N2", "N3"]);
```

### Random Placement with `nodePositionRandom`

```matlab
region = nsidedpoly(6, Center=[0 0], SideLength=50);
positions = nodePositionRandom(region, NumNodes=10, ZCoordinate=0);
nodes = NodeConstructor(Position=positions, Name="N"+(1:10));
```

## Batch addNodes

One `addNodes` per technology type. Never call per-node.

```matlab
addNodes(sim, [sourceNode; destNodes(:)]);    % same type
addNodes(sim, nodesTypeA);                     % mixed sim: separate calls
addNodes(sim, nodesTypeB);
```

## Traffic Sources

**`addTrafficSource` is available only on technology nodes** (BLE, BR/EDR, WLAN, NR) — not on custom `wnet.Node` subclasses.

`networkTrafficOnOff` DataRate is in **Kbps** (kilobits/s). The `generate()` method returns inter-packet time in ms.

```matlab
traffic = networkTrafficOnOff(DataRate=100, PacketSize=50, OnTime=Inf);
```

**Common mistake:** `DataRate=100000` for 100 Kbps — this is 100 Mbps (1000× too high). Runs without error but produces unrealistic traffic. See `references/traffic-models.md` for all traffic source types and their parameters.

Reuse a single traffic object for identical flows — `DestinationNode` accepts vectors:

```matlab
addTrafficSource(central, traffic, DestinationNode=[p1; p2; p3]);
```

## Vectorized Statistics

For technology nodes (BLE, BR/EDR, WLAN, NR), vectorized `statistics` returns a 1×N struct array:

```matlab
allStats = statistics(nodes);  % 1×N struct array (technology nodes)
rxBytes = [allStats.App];      % Concatenate sub-structs
```

For custom `wnet.Node` subclasses, vectorized behavior depends on the `statistics()` method implementation — call per-node if the return struct varies.

## Mobility

`addMobility` on the node vector directly (not per-node). Bounds = `[x_center, y_center, width, height]` (NOT `[xmin, ymin, xmax, ymax]`).

```matlab
addMobility(nodes, MobilityModel="random-waypoint", SpeedRange=[1.0 1.5], Bounds=[10 0 12 4]);
```

Models: `"random-waypoint"`, `"random-walk"`, `"constant-velocity"`. Every node must be within ±width/2 of x_center and ±height/2 of y_center. See `references/mobility-models.md` for detailed examples.

## Multi-Step Simulation

Each `run` specifies **additional duration** (relative), not absolute end time:

```matlab
run(sim, 0.3, IsLastStep=false);   % Run 0.3s, keep state
stats_mid = statistics(node);
run(sim, 0.2);                      % Additional 0.2s (0.5s total)
```

## Scheduled Actions

```matlab
scheduleAction(sim, @myCallback, userData, 0.3);         % one-shot at t=0.3s
scheduleAction(sim, @myCallback, userData, 0.1, 0.05);   % periodic: start 0.1s, repeat 0.05s
```

Callback signature — **two arguments** `(actionID, userData)`:

```matlab
function myCallback(actionID, userData)
    stats = statistics(userData.node);
end
```

**Valid mid-sim operations:** `statistics(node)`, change `node.Position`, technology-specific mid-sim methods. Most RF properties are locked after `run()` starts.

## Custom Channel Model

```matlab
addChannelModel(sim, @myChannelModel);

function txData = myChannelModel(rxInfo, txData)
    dist = norm(rxInfo.Position - txData.TransmitterPosition);
    fspl = 20*log10(dist) + 20*log10(txData.CenterFrequency) - 147.55;
    txData.Metadata.Channel.PathDelays = 0;
    txData.Metadata.Channel.PathGains = -fspl;
end
```

Signature: `function txData = fcn(rxInfo, txData)` — **two inputs**, not one.

`rxInfo` fields: `ID`, `Position`, `Velocity`, `NumReceiveAntennas`.

Key `txData` fields: `Power`, `CenterFrequency`, `StartTime`, `TransmitterPosition`, `TransmitterVelocity`, `Bandwidth`, `Metadata.Channel` (`PathGains`, `PathDelays`, `PathFilters`, `SampleTimes`).

Default uses FSPL. Use `addChannelModel` for distance-dependent fading, multipath, or environment-specific propagation.

## Parametric Sweeps

`wirelessNetworkSimulator.init` MUST be at the top of **every** loop iteration (singleton retains state). See `references/parametric-sweep-pattern.md` for multi-dim and `parfor` patterns.

## Instrumentation (R2026a)

All tools must be created **before** `run()`. See `references/event-tracing-iq-logging.md` for full details.

```matlab
eventTracer = wirelessNetworkEventTracer(FileName="events.mat");
addNodes(eventTracer, nodes, EventName=["TransmissionStarted", "ReceptionEnded"]);

iqLogger = wirelessIQLogger(receiverNodes, FileName="iq_samples.mat");

viewer = wirelessTrafficViewer;
addNodes(viewer, nodes);
```

- **Event Tracer**: Works with all node types. `addNodes` calls `registerEventCallback` on each node for each specified `EventName` — for custom `wnet.Node` subclasses, your node must override `registerEventCallback` to support the event names (see `references/custom-node.md`). Errors if MAT file already exists. Read with `read(eventTracer, EventName=..., NodeName=..., TimeRange=...)`.
- **IQ Logger**: Nodes fixed at construction (no `addNodes`). ~4–5 MB per node per 0.1s at 80 MHz. **Technology nodes only** — custom `wnet.Node` subclasses are not supported.
- **Network Viewer**: `wirelessNetworkViewer(NetworkSimulator=sim)` + `addNodes(viewer, nodes, Type="Transmitter"/"Receiver")` + `showBoundary(viewer, BoundaryShape="circle", Bounds=radius, Position=[x y z])`. Shapes: `"circle"`, `"rectangle"`, `"hexagon"`.
- **Traffic Viewer**: Real-time state transitions and channel occupancy. **Technology nodes only** — custom `wnet.Node` subclasses are not supported.

## PCAP Capture

Generic `pcapWriter` for any technology; technology-specific writers (`blePCAPWriter`, `wlanPCAPWriter`, `nrPCAPWriter`) auto-capture from nodes via `Node=` property.

```matlab
% Generic (manual write)
pcapObj = pcapWriter(FileName="my_capture");
writeGlobalHeader(pcapObj, linkType);
write(pcapObj, packetBytes, round(simTime * 1e6));  % timestamp in microseconds (integer)

% Technology-specific (auto-capture, no write calls needed)
blePcap = blePCAPWriter(FileName="ble_capture", Node=[central; peripheral]);
```

Common link types: `LINKTYPE_USER0` (147), `LINKTYPE_IEEE802_11` (105). Reading: `readAll(pcapReader("file.pcap"))`.

For Bluetooth-specific PCAP capture, see `references/bluetooth-capture.md`.

## Event Callbacks (`registerEventCallback`)

Register a callback on a node to be invoked when a specific event occurs. Callback receives a **single argument** (event data struct).

```matlab
registerEventCallback(node, "ReceptionEnded", @myCallback);

function myCallback(eventData)
    disp(eventData.Timestamp);          % sim time (seconds)
    disp(eventData.EventData.SINR);     % technology-specific nested payload
end
```

**Technology nodes** (BLE, BR/EDR, WLAN, NR): Call `registerEventCallback` to register — the node's internal implementation automatically invokes the callback at the correct moments during simulation.

**Custom `wnet.Node` subclasses**: The base `wnet.Node.registerEventCallback` is a no-op stub — it accepts arguments but does not store or fire callbacks. You MUST override `registerEventCallback` in your subclass to store callbacks, then explicitly invoke them at the appropriate points (e.g., after transmitting in `run()`, after receiving in `pushReceivedPacket()`). See `references/custom-node.md` for the full implementation pattern.

Top-level fields: `EventName`, `NodeName`, `NodeID`, `Timestamp`, `TechnologyType`, `EventData` (nested struct).

For Bluetooth-specific event data fields, see `references/bluetooth-capture.md`.

## Common Mistakes

| Mistake | Correct |
|---------|---------|
| `node = wnet.Node(...)` or creating a bare `wnet.Node` | `wnet.Node` is abstract — subclass it: `classdef MyNode < wnet.Node` |
| Using `bluetoothLENode`/`bluetoothNode` for non-Bluetooth scenarios | Use a custom `wnet.Node` subclass for generic/custom wireless nodes |
| `TechnologyType = "custom"` (string) | Use `wnet.TechnologyType.Custom1` (numeric constant 101–109) |
| `Bounds=[0 0 20 20]` as [xmin,ymin,xmax,ymax] | `Bounds=[x_center, y_center, width, height]` |
| `function myFcn(userData)` for scheduleAction | `function myFcn(actionID, userData)` — 2 args |
| `function txData = fcn(txData)` for addChannelModel | `function txData = fcn(rxInfo, txData)` — 2 inputs |
| `addMobility(sim, nodes, ...)` | `addMobility(nodes, ...)` — node method, not sim |
| `DataRate=100000` for 100 Kbps | `DataRate=100` — unit is Kbps |
| `pcapWriter()` without `writeGlobalHeader` | Must call `writeGlobalHeader(pcapObj, linkType)` before any `write()` |
| Building file-write callbacks for logging | Use `wirelessNetworkEventTracer` instead |
| Calling `registerEventCallback` on a custom node without overriding it | Base `wnet.Node.registerEventCallback` is a no-op — override it to store callbacks, fire them manually from `run()`/`pushReceivedPacket()` |
| `addTrafficSource(customNode, traffic, ...)` on a custom `wnet.Node` | `addTrafficSource` is technology-node-only |
| Ignoring received packets in `pushReceivedPacket` | Use `wnet.internal.interferenceBuffer` with `addPacket` to store received packets |

<!-- Copyright 2026 The MathWorks, Inc. -->
