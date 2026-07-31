# Script Interfaces

Function signatures and output contracts for all diagnostic scripts. The agent calls these via `mcp__matlab__evaluate_matlab_code` — never read source.

---

## Phase 0: Automation Scripts

| Function | Arguments | Output (command window) | Side Effects |
|----------|-----------|------------------------|--------------|
| `canHardwareDiscovery()` | none | Available channels table or `NO_PHYSICAL_HARDWARE` | None |
| `canSupportSummary()` | none | Driver/plugin status summary | Creates `cansupport.txt` |
| `canChannelHealthCheck(vendor, device, chIndex, useFD)` | vendor (string), device (string), chIndex (double), useFD (logical) | Health snapshot: BusStatus, TEC, REC, traffic sample | Starts/stops channel |
| `canLoopbackSelfTest()` | none | `PASS` or `FAIL` with received messages | Creates/destroys virtual channels |
| `canBaudRateScanPassive(vendor, device, chIndex)` | vendor (string), device (string), chIndex (double) | Detected baud or `NO_TRAFFIC_AT_ANY_RATE` | Starts/stops channels at each rate |
| `canBaudRateScanActive(vendor, device, chIndex)` | vendor (string), device (string), chIndex (double) | `ACK RECEIVED` or `No ACK` per rate | Transmits test frames |
| `canDiagnosticProbe(canCh)` | canCh (started channel object) | TEC/REC/BusStatus after probe | Transmits 1 frame, may toggle SilentMode |

## Phase 2: L2 Analysis Scripts

| Function | Arguments | Output (command window) | Side Effects |
|----------|-----------|------------------------|--------------|
| `canTrafficOverview(rawMsgs)` | rawMsgs (timetable) | Per-ID breakdown, dropout detection, node presence | None |
| `canCycleTimeAnalysis(rawMsgs)` | rawMsgs (timetable) | Jitter stats per ID (mean, std, jitter%, timeouts) | None |
| `canBusLoadCalc(rawMsgs, busSpeedBps)` | rawMsgs (timetable), busSpeedBps (double, default 500000) | Bus load %, arbitration starvation warning | None |
| `canBurstDetection(rawMsgs, busSpeedBps)` | rawMsgs (timetable), busSpeedBps (double, default 500000) | Temporal burst profile (1s windows) | None |

## Invocation Pattern

```matlab
% Phase 0 — no prior state needed
canHardwareDiscovery()
canChannelHealthCheck("Vector", "VN1610 1", 1, false)

% Phase 2 — requires rawMsgs captured earlier
rawMsgs = receive(canCh, Inf, "OutputFormat", "timetable");
canTrafficOverview(rawMsgs)
canBusLoadCalc(rawMsgs, 500000)
```

All functions print to the command window. The agent uses `mcp__matlab__evaluate_matlab_code` with `project_path` set to the skill's `scripts/can/troubleshooting/` directory so MATLAB can find the functions on path.

----

Copyright 2026 The MathWorks, Inc.

----
