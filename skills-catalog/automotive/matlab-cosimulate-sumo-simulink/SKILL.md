---
name: matlab-cosimulate-sumo-simulink
description: >
  Build Simulink models that co-simulate with Eclipse SUMO traffic simulator.
  Use when creating SUMO-Simulink co-simulation, traffic simulation, TraCI
  connection, vehicle-in-the-loop testing, or ADAS scenario validation with
  SUMO. Covers Server/Client setup, Reader/Writer/Actor block configuration,
  random traffic generation, ego vehicle control, and SUMO file creation.
  Also use when the user mentions SumoInterfaceLibrary, .sumocfg files,
  or wants to connect Simulink to an external traffic simulator.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Build SUMO-Simulink Co-simulation

Create Simulink models that run synchronized co-simulation with Eclipse SUMO using the `SumoInterfaceLibrary` blocks from the Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator.

## When to Use

- Building a Simulink model that connects to Eclipse SUMO
- Setting up traffic co-simulation for ADAS/AD controller testing
- Reading vehicle states (position, speed) from SUMO into Simulink
- Controlling an ego vehicle in SUMO from a Simulink controller
- Spawning or removing vehicles dynamically during simulation
- Generating random background traffic without writing route files

## When NOT to Use

- Pure SUMO simulation without Simulink (use SUMO's CLI or Python TraCI directly)
- Vehicle dynamics modeling (use Vehicle Dynamics Blockset)
- Scenario design with Driving Scenario Designer (different workflow)

## Prerequisites

1. **Eclipse SUMO installed** with `SUMO_HOME` environment variable set
2. **Support package installed**: "Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator"
3. **Windows: append trailing separator to `SUMO_HOME`** — The Server block's launcher concatenates `SUMO_HOME + "bin\..."` without a separator. If `SUMO_HOME` lacks a trailing `\` or `/`, every `sim()` fails with "Failed to launch Eclipse SUMO simulator" even though SUMO is installed correctly. Always run before building/simulating:

```matlab
if ~endsWith(getenv('SUMO_HOME'), filesep)
    setenv('SUMO_HOME', [getenv('SUMO_HOME') filesep]);
end
```

4. **Verify**: `getenv('SUMO_HOME')` must return a valid path ending with a separator.

## Preferred Construction Path

When `mcp__matlab__model_edit` (SATK) is available, prefer it over raw `add_block`/`add_line`. It applies auto-layout after every edit, produces clean wiring with no overlap, and lets you reference newly-added blocks by `ref` within the same call. The patterns below still apply — express them as `add_block`/`connect`/`configure` operations in a single JSON payload. Fall back to `add_block`/`add_line` only when SATK is unavailable or when the operation is not expressible in the schema (e.g., setting MATLAB Function `Script` via `sfroot`).

**Note:** When wiring `EnablePort` on a freshly-created Enabled Subsystem whose default `In1`/`Out1` have been deleted, `model_edit` cannot resolve the Enable port. Workaround: `add_line(model, 'Source/1', 'SubsystemName/Enable', 'autorouting','smart')`.

## Workflow

### Idempotent Build Template

```matlab
modelName = 'sumo_cosim';
workDir = fileparts(mfilename('fullpath'));
% SUMO_HOME workaround (Windows)
sh = getenv('SUMO_HOME');
if ~endsWith(sh, filesep), setenv('SUMO_HOME', [sh filesep]); end
% Idempotent rebuild
if bdIsLoaded(modelName), close_system(modelName, 0); end
slxPath = fullfile(workDir, [modelName '.slx']);
if isfile(slxPath), delete(slxPath); end
new_system(modelName);
open_system(modelName);
set_param(modelName, 'StopTime','100', 'SolverType','Fixed-step', 'FixedStep','0.1');
% ... build model ...
save_system(modelName, slxPath);
```

### 1. Prepare SUMO Scenario Files

Ask the user for their existing `.sumocfg`. Only generate new files if explicitly requested. For quick networks use `netgenerate`:

```matlab
sumoHome = getenv('SUMO_HOME');
cmd = sprintf('"%s" --grid --grid.number 2 --grid.length 200 --output-file "%s"', ...
    fullfile(sumoHome,'bin','netgenerate'), fullfile(pwd,'network.net.xml'));
system(cmd);
```

Minimal `.sumocfg` (route-files optional when using `EnableRandomTraffic`):

```xml
<configuration>
    <input><net-file value="network.net.xml"/></input>
    <time><begin value="0"/><end value="100"/><step-length value="0.1"/></time>
</configuration>
```

**Route file rules:** All `<vehicle>`, `<person>`, and `<personFlow>` entries MUST be sorted by `depart` time (`begin` for flows). Out-of-order entries are silently ignored. Routes used by Actor blocks must be standalone `<route>` elements — not embedded in `<flow>`.

**OpenDRIVE import:** Use `netconvert --opendrive-files file.xodr -o network.net.xml`. Note: SUMO applies a `netOffset` (visible in `.net.xml` `<location>` element) — all SUMO coordinates = OpenDRIVE coordinates + netOffset.

### 2. Create Server and Client

```matlab
add_block('SumoInterfaceLibrary/Server', [modelName '/SUMO Server']);
set_param([modelName '/SUMO Server'], 'ServerFile',fullfile(pwd,'cosim.sumocfg'), ...
    'ServerPort','8813', 'ServerNumClients','1', 'EnablePacing','on', ...
    'PacingRate','1', 'SampleTime','0.1');
add_block('SumoInterfaceLibrary/Client', [modelName '/SUMO Client']);
set_param([modelName '/SUMO Client'], 'ClientAddress','127.0.0.1', ...
    'ClientPort','8813', 'ClientOrder','1', 'SampleTime','0.1');
```

**Critical:** `ClientPort` must equal `ServerPort`. `FixedStep` must match SUMO `step-length`. Enable pacing (`EnablePacing='on'`) so the GUI doesn't flash by in 2 seconds.

### 3–6. Add Readers, Writers, Actors, Save and Run

See Block Reference and Patterns sections below. Always `save_system(modelName)` before `sim(modelName)` when the model has been modified programmatically.

## Block Reference

### Server Block

| Parameter | Purpose | Default |
|-----------|---------|---------|
| `ServerFile` | Path to `.sumocfg` | — |
| `ServerPort` | TraCI port | `'8813'` |
| `ServerNumClients` | Number of clients | `'1'` |
| `EnableRandomTraffic` | Spawn vehicles without route file | `'off'` |
| `RandomTraffic` | Vehicle count when random traffic enabled | `'0'` |
| `EnablePacing` | Real-time pacing (recommended for demos) | `'off'` |
| `PacingRate` | Pacing multiplier | `'1'` |
| `SampleTime` | Step interval | `'-1'` |

**Note:** SUMO default `time-to-teleport=300s` — any vehicle stuck >300s gets teleported. This can surprise when deliberately stopping an ego at a bus stop.

### Client Block

| Parameter | Purpose | Default |
|-----------|---------|---------|
| `ClientAddress` | Server IP | `'127.0.0.1'` |
| `ClientPort` | Must match ServerPort | `'8813'` |
| `ClientOrder` | Client priority | `'1'` |

### Reader Block — Vehicle Topics

**All Vehicle-topic Readers AND Writers crash if the target vehicle does not exist.** Gate them in Enabled Subsystems when the vehicle spawns after t=0. See Safe Vehicle State Access.

| Topic | Input | Output |
|-------|-------|--------|
| `Speed` | Vehicle Id | Speed (scalar) |
| `Position` | Vehicle Id | Position [x, y] |
| `Position3D` | Vehicle Id | Position [x, y, z] |
| `Acceleration` | Vehicle Id | Acceleration |
| `Angle` | Vehicle Id | Heading (degrees, 0=north, CW) |

Vehicle Id inputs must come from a String Constant block — never from another Reader's output.

### Reader Block — Simulation Topics (no input port)

| Topic | Output |
|-------|--------|
| `ID list` | Vehicle ID strings |
| `ID count` | Scalar count |
| `Arrived list` | IDs that reached destination |
| `Departed list` | IDs that entered network |

### Writer Block — Vehicle Topics

**Writers crash if the target vehicle does not exist** — same failure mode as Readers. Gate in Enabled Subsystems for delayed-spawn vehicles.

| Topic | Input Ports | Notes |
|-------|------------|-------|
| `Speed` | Vehicle Id, Speed | Sets **desired** speed; SUMO car-following still brakes for leaders |
| `Position` (RouteFlag off) | Vehicle Id, X, Y, Angle | — |
| `Position` (RouteFlag on) | Vehicle Id, Edge Id, Lane Index, X, Y, Angle, Keep Route | See type table below |
| `Min gap` | Vehicle Id, Gap | — |
| `Speed mode` | Vehicle Id, Mode | — |

**Writer(Vehicle/Position, RouteFlag=on) port types** — type mismatches silently fail:

| Port | Signal | Type |
|------|--------|------|
| 1 | Vehicle Id | `string` |
| 2 | Edge Id | `string` |
| 3 | Lane Index | **`int32`** |
| 4 | X | `double` |
| 5 | Y | `double` |
| 6 | Angle | `double` (degrees) |
| 7 | Keep Route | **`uint8`** (use `uint8(1)`) |

**Warning:** `Writer(Vehicle/Position)` does no collision-checking. Teleporting near other vehicles causes pile-ups. Place spawned vehicles in a different lane from nearby traffic.

### Writer Block — Visualization Topics

Use `TopicCategory='Visualization'` with `GUITopic` parameter. **Visualization commands are sticky** — once SUMO receives Schema/Track/Zoom, it retains the setting. Always wrap in a one-shot Enabled Subsystem. Do NOT leave running every step.

| GUITopic | Input Ports | Valid Values |
|----------|------------|--------------|
| `Track Vehicle` | View Id, Vehicle Id | — |
| `Zoom factor` | View Id, Zoom | — |
| `Schema` | View Id, Schema | `"standard"`, `"real world"`, `"fast standard"`, `"fast real world"` |

All Visualization topics require a View Id input on port 1. The default SUMO GUI view name is `"View #0"` — always use this exact string.

```matlab
% Track Vehicle example (one-shot): camera follows ego
add_block('SumoInterfaceLibrary/Writer', [subsysPath '/Track Writer'], ...
    'TopicCategory','Visualization', 'GUITopic','Track Vehicle', 'SampleTime','0.1');
add_block('simulink/String/String Constant', [subsysPath '/View Id'], ...
    'String','"View #0"');  % Default SUMO GUI view — always "View #0"
add_block('simulink/String/String Constant', [subsysPath '/Vehicle Id'], ...
    'String','"ego_vehicle"');
add_line(subsysPath, 'View Id/1', 'Track Writer/1');
add_line(subsysPath, 'Vehicle Id/1', 'Track Writer/2');
% Wrap in one-shot Enabled Subsystem (Constant(0)->IC(1)->Enable)
```

```matlab
% Schema example (one-shot): switch GUI to "real world"
add_block('SumoInterfaceLibrary/Writer', [modelName '/Set Schema'], ...
    'TopicCategory','Visualization', 'GUITopic','Schema', 'SampleTime','0.1');
add_block('simulink/String/String Constant', [modelName '/View Id'], ...
    'String','"View #0"');  % Default SUMO GUI view — always "View #0"
add_block('simulink/String/String Constant', [modelName '/Schema Name'], ...
    'String','"real world"');
% Wrap in one-shot Enabled Subsystem (Constant(0)->IC(1)->Enable)
```

### Actor Block

| Parameter | Purpose |
|-----------|---------|
| `VehicleState` | `'Add'` or `'Remove'` |
| `SpawnMethod` | `'Lane'` (use this) or `'Position'` (broken — see Known Issues) |
| `departLane` | `'random'`, `'free'`, `'allowed'`, `'first'`, `'best'` |
| `departSpeed` | `'max'` (recommended), `'random'`, `'desired'`, `'speedLimit'` |
| `enableRouteID` | `'on'`/`'off'` |
| `routeID` | Route ID from `.rou.xml` (requires `enableRouteID='on'`) |
| `typeID` | Vehicle type ID (default: `'DEFAULT_VEHTYPE'`) |

Always place Actor blocks inside Enabled Subsystems. Set `Priority='1'` on Spawn subsystem so it executes before Readers (`Priority='10'`).

## Patterns

### Single-Shot Triggers

| Trigger | Pattern |
|---------|---------|
| Spawn at t=0 only | `Constant(0)` -> `IC(Value=1)` -> Enabled Subsystem |
| Spawn at simulation time T | `Clock` -> `MATLAB Function (persistent fired)` -> Enabled Subsystem |
| Continuous from T onward (e.g., speed writer) | `Clock` -> `Compare To Constant (>=T)` -> Enabled Subsystem |
| Spawn when condition true | `Clock`/sensor -> `MATLAB Function (persistent fired)` checking condition |

**Time-based one-shot (spawn at t=1.2):**

```matlab
% MATLAB Function code:
% function pulse = fcn(t)
% %#codegen
% persistent fired
% if isempty(fired), fired = false; end
% if (t >= 1.2) && ~fired, pulse = 1.0; fired = true;
% else, pulse = 0.0; end
% end
```

### Ego Vehicle Control (Route-File Approach — Recommended)

Define ego in `.rou.xml` with `depart="0"` so Readers work from t=0:

```xml
<routes>
    <vType id="ego_type" accel="2.6" decel="4.5" sigma="0" length="5" maxSpeed="25"/>
    <route id="ego_route" edges="B1B2 B2B3 B3B4 B4B1 B1B2 B2B3 B3B4 B4B1"/>
    <vehicle id="ego_veh" type="ego_type" route="ego_route" depart="0"
             departLane="free" departSpeed="max"/>
</routes>
```

If Simulink owns longitudinal control via `Writer(Vehicle/Speed)`, do NOT put `<stop>` clauses in the ego's route — SUMO's stop directive overrides the Speed Writer.

### Gated Writer(Vehicle/Speed) for Delayed-Spawn Vehicles

```matlab
% Latched enable: HIGH from t >= spawnTime onwards
% Clock -> Compare To Constant (relop='>=', const=spawnTime) -> Enable
% Inside Enabled Subsystem:
%   String Constant("veh_1") -> Writer(Vehicle/Speed) port 1
%   Constant(desiredSpeed)   -> Writer(Vehicle/Speed) port 2
```

Use `Compare To Constant >= spawnTime` (stays HIGH) rather than one-shot — speed must be continuously asserted while the vehicle is alive.

### Distinct Routes Per Vehicle (Dynamic Spawning)

```xml
<routes>
    <route id="ego_route"   edges="A0A1 A1A2 A2B2 B2C2 C2C1 C1C0"/>
    <route id="veh_1_route" edges="A1B1 B1B2 B2C2 C2C1 C1C0 C0B0"/>
    <route id="veh_2_route" edges="B0B1 B1A1 A1A2 A2B2 B2C2 C2C1"/>
</routes>
```

```matlab
% Per Actor block: set_param(actorPath, 'routeID', sprintf('veh_%d_route', k));
```

### Spawn-Then-Teleport (Position Workaround)

Since `SpawnMethod='Position'` is broken (see Known Issues), use this two-step pattern:

```
Step N:   Actor(Add, SpawnMethod='Lane', routeID=...) -> vehicle at edge start
Step N+1: Writer(Vehicle/Position, RouteFlag=on) with (VehId, EdgeId, int32(LaneIdx),
          X, Y, Angle, uint8(1)) -> vehicle teleports to (X,Y)
```

A one-step delay between Spawn and Move is mandatory — use a `Unit Delay` on the enable signal. The vehicle does not exist on the SUMO side until one step after the Actor fires.

### Periodic Batch Spawn Near Moving Reference

```
Clock -> PulseGen (persistent, fires every 5s, increments batch id)
       -> SpawnBatch (Enabled SS, Priority=1): N IDGen -> N Actor(Add)
       -> [Unit Delay z^-1]
       -> MoveBatch (Enabled SS, Priority=10): N Writer(Vehicle/Position)
Reader(Vehicle/Position) on ego feeds PosGen so batch lands at egoPos + offset.
```

### MATLAB Function with String Outputs

For dynamically generated vehicle IDs (e.g., `"dyn_" + string(batch) + "_1"`):

```matlab
chart = sf.find('-isa','Stateflow.EMChart','Path',chartPath);
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '0.1';
outData = chart.find('-isa','Stateflow.Data','Scope','Output');
outData.DataType = 'string';
outData.Props.Array.Size = '1';
```

### Safe Vehicle State Access

All Vehicle-topic Readers AND Writers dereference the Vehicle Id at every step. They crash if the vehicle does not exist. This applies to Reader(Vehicle/...), Writer(Vehicle/...), AND Writer(Visualization/Track Vehicle).

For vehicles spawning after t=0, gate in an Enabled Subsystem:

```matlab
% Clock -> Compare To Constant (>= spawnTime) -> Enabled Subsystem
% Inside: String Constant + Reader/Writer blocks
```

For ego defined in `.rou.xml` with `depart="0"` — no gating needed.

### Random Traffic Quick-Start

```matlab
set_param([modelName '/SUMO Server'], 'EnableRandomTraffic','on', 'RandomTraffic','10');
```

No `<route-files>` needed. Random vehicles are named `SpawnedVehicle_1`, `SpawnedVehicle_2`, etc.

## Known Issues (Support Package Bugs)

| Issue | Impact | Workaround |
|-------|--------|------------|
| `SUMO_HOME` without trailing separator → launch failure (Windows) | P0 blocker | `setenv('SUMO_HOME', [getenv('SUMO_HOME') filesep])` |
| `SpawnMethod='Position'` passes wrong `RouteFlag` in internal `moveToXY` | Vehicle lands at edge start, not requested position | Use spawn-then-teleport pattern (Actor + Unit Delay + Writer(Vehicle/Position)) |

## Common Mistakes

| Mistake | Why It Fails | Fix |
|---------|-------------|-----|
| Reader/Writer on vehicle before it exists | S-function crash in `mdlOutputs` | Gate in Enabled Subsystem; use `depart="0"` for ego |
| Reader output -> Reader input | ID List is variable-length; Vehicle readers need single string | Use String Constant for Vehicle Id |
| ClientPort != ServerPort | Client can't connect | Match both (default `'8813'`) |
| Variable-step solver | SUMO requires lockstep | Fixed-step, match `step-length` |
| Actor fires repeatedly | "Vehicle already exists" | Enabled Subsystem with one-shot logic |
| Writer(Vehicle/Speed) ungated for delayed-spawn vehicle | Crash at t=0 | Gate with `Clock >= spawnTime` |
| Visualization Writer running every step | Wastes sim time; crashes if vehicle missing | One-shot Enabled Subsystem |
| Route entries not sorted by depart time | Silently dropped | Sort all entries by `depart`/`begin` |
| Route embedded in `<flow>` | Actor can't find it | Define standalone `<route>` elements |
| `<stop>` in ego route + Speed Writer | SUMO stop overrides Writer | Remove `<stop>`; use Simulink speed profile |
| Multiple Clock blocks | Clutter; all output same time | Single Clock, fan out to all consumers |
| `double` for Lane Index or Keep Route in Position Writer | Type mismatch rejection | `int32(laneIdx)`, `uint8(keepRoute)` |
| Teleport into occupied lane | Pile-ups, stuck vehicles | Teleport to different lane from nearby traffic |
| Missing `save_system` before `sim` | "Unapplied changes" mask error | Always save after programmatic changes |
| Ego `depart="2"` with Reader at t=0 | Garbage/crash from undefined vehicle | Set ego `depart="0"` |
| Spawning at fractional times with FixedStep=1.0 | Solver never hits target time | Match `FixedStep`, `step-length`, and all `SampleTime` |

## Conventions

- Always use Fixed-step solver with step size matching SUMO `step-length` and all block `SampleTime` values
- Always `save_system(modelName)` before `sim(modelName)` after programmatic changes
- Always match `ClientPort` to `ServerPort`
- Use a single Clock at model root — fan out to all comparators/pulse generators
- Prefer defining ego in `.rou.xml` with `depart="0"` over Actor block
- Give ego a long/circular route to prevent mid-simulation removal
- Use `departSpeed='max'` as the practical default for vehicles that should land moving
- Writer(Speed) sets desired speed — SUMO handles gap maintenance via car-following
- Enable pacing (`EnablePacing='on'`) for demos so the GUI doesn't flash by
- Wrap Visualization writers (Track, Schema, Zoom) in one-shot Enabled Subsystems — they are sticky
- Always place Actor blocks inside Enabled/Triggered Subsystems
- Every dynamically spawned vehicle needs a unique ID and a valid standalone route
- Validate `.sumocfg` with SUMO CLI before Simulink: `system(sprintf('"%s" -c "%s" --end 0.1', sumoExe, cfgFile))`
- When using `mcp__matlab__model_edit`, fall back to `add_line` for Enable port wiring

----

Copyright 2026 The MathWorks, Inc.

----
