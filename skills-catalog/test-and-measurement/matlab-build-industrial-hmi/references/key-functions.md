# Key Functions

Every function an HMI built by this skill calls, with the toolbox that ships it and the release it
became available. Look up the release **before** writing a call: the four bold entries are the ones
that fail on an older install, and they fail differently — a missing toolbox errors at the call,
while a too-old release reports `Unrecognized function or variable`, which reads like a typo.

The skill's floor is **R2023b** (`manifest.yaml`), set by OPC UA `subscribe()`. Verify an unknown
install with `mcp__matlab__detect_matlab_toolboxes`.

## Widgets and graphics — core MATLAB

| Function | Purpose | Available From |
|---|---|---|
| `uigauge('linear'\|'circular'\|'semicircular'\|'ninetydegree')` | Single value, known range | R2016a |
| `uigauge.ScaleColors` / `.ScaleColorLimits` | Alarm bands at source — all four gauge styles; bands outside `Limits` are silently clipped (`common-mistakes.md` #23) | R2018a |
| `uilamp` | Binary state indicator | R2016a |
| `animatedline` with `MaximumNumPoints` | Rolling trend buffer | R2014b |
| `addpoints` / `clearpoints` | Trend update / reset | R2014b |
| `yline` | Threshold or setpoint line on trend | R2018b |
| `uiconfirm` | Modal write confirmation | R2017b |
| `uispinner` with `Limits` | Bounded numeric input | R2016a |
| `uieditfield('numeric','Editable',false)` | Precise read-only numeric display | R2016a |
| `uitable` | Tabular display for >8 nodes | R2017b |
| `uitree` + `uitreenode` | OPC UA namespace navigation | R2017b |
| `timer` (`BusyMode='drop'`, `ExecutionMode='fixedSpacing'`) | Modbus / PI / PI AF poll loop, or non-OPC periodic UI work | base |

## Protocol clients — Industrial Communication Toolbox

| Function | Purpose | Available From |
|---|---|---|
| `opcua` / `connect` | Open OPC UA client | R2022a |
| `findNodeByName` / `readValue` / `writeValue` | Browse and read/write nodes | R2022a |
| `subscribe(uaClient, nodeList, dataChangeFcn, PublishInterval=...)` | Live node updates — preferred over `timer` at any node count | **R2023b** |
| `modbus('tcpip', host, port)` / `read` / `write` | Modbus client and register R/W | R2022a |
| `mqttclient(brokerAddr)` / `subscribe(c, topic, Callback=...)` / `write` | MQTT publish/subscribe | R2022a |
| `piclient(server, ...)` | OSI / AVEVA PI Data Archive client | **R2022a** |
| `tags(piClient, Name=q)` / `read(piClient, tag, DateRange=, Interval=, AggregateFcn=)` | PI tag search, current and archive/aggregated reads (returns `table`/`timetable`) | R2022a |
| `write(piClient, tag, value, TimeInstance=...)` | PI setpoint write | **R2024a** |
| `afclient(server, Database=...)` | PI Asset Framework client | **R2026a** |
| `getRootElements` / `getChildren` / `getAttributes` / `findElementByName` / `findElementByPath` / `findElementByTemplate` | AF tree browse → drill-down layout | R2026a |
| `read(attr, Unit=...)` / `readHistory(attr, t0, t1, ...)` / `listSupportedUnits` | AF attribute current value, history, units | R2026a |

Calling conventions, argument order, and callback shapes for all of these are in
`references/protocol-cheatsheet.md` (OPC UA / Modbus / MQTT) and `references/pi-af-cheatsheet.md`
(PI Data Archive / PI AF) — this file answers *whether* a function exists, those answer *how to
call it*.

## Release gates that change the design, not just the call

- **Below R2023b** there is no OPC UA `subscribe()`. A polling `timer` is then the only option, and
  the skill's "subscribe is the default" rule does not apply — say so rather than emitting a call
  that errors.
- **PI writes need R2024a.** On R2022a–R2023b `piclient` reads but cannot write, so a PI setpoint
  panel cannot be built; raise it as an open question in the spec instead of shipping a dead
  control.
- **PI AF needs R2026a**, and even there **AF current-value writes are not exposed** — route them
  through `Attribute.PITag` and the PI client (`references/pi-af-cheatsheet.md`).
- **Real App Designer output** (`.mlapp`) needs R2025a+ via `matlab-build-app`; plain-text `.m`+`.xml`
  needs R2026b+. Below that, the programmatic `.m` fallback is the only path.

----

Copyright 2026 The MathWorks, Inc.

----
