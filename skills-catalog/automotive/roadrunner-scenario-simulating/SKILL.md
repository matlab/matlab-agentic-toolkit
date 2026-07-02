---
name: roadrunner-scenario-simulating
description: >
  Expert guidance for simulating RoadRunner scenarios via the MATLAB programmatic
  API and Simulink co-simulation. Use when the user wants to run a simulation,
  step through a simulation, control actors during co-simulation, add observers,
  attach sensors, retrieve simulation logs, or read/write scenario variables.
  Covers simulateScenario, createSimulation, ScenarioSimulation set/get,
  ActorSimulation getAttribute/setAttribute, addObserver, SensorSimulation,
  Simulink co-sim blocks, and publishActorBehavior.
  NOT for project setup, scene building, scenario authoring, or trajectory export.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# RoadRunner Scenario Simulation

Simulate RoadRunner scenarios, step through simulations, control actors in co-simulation, add observers, attach sensors, and retrieve results — from MATLAB and Simulink.

## When to Use

- User wants to run a RoadRunner scenario simulation
- User wants to step through a simulation frame-by-frame
- User wants to control an actor externally (co-simulation)
- User wants to observe simulation state (read-only monitoring)
- User wants to add sensors and read target poses or lane boundaries
- User wants to retrieve simulation logs programmatically
- User wants to read or write scenario variables
- User asks about co-simulation with Simulink
- User asks about publishing actor behaviors

## When NOT to Use

- Launching or connecting to RoadRunner
- Authoring scenarios (adding actors, paths, behaviors in the editor)
- Building or editing scenes (roads, terrain, assets)
- Exporting actor trajectories to CSV — use `exportActorTrajectoryToCSV` directly
- Working with `drivingScenario` (that is a DIFFERENT toolbox — Automated Driving Toolbox)

## Critical: Do NOT Confuse With drivingScenario

`drivingScenario` (from Automated Driving Toolbox) is a MATLAB-native scenario tool.
RoadRunner Scenario simulation uses completely different APIs on the `roadrunner` object.
**Never mix these two — they are unrelated.**

---

## Decision Tree

```
User wants to simulate →
  ├── Just run to completion? → Workflow A (simulateScenario)
  ├── Need step control OR programmatic log? → Workflow B (createSimulation)
  ├── Need to read actor state during sim? → Workflow C (getAttribute)
  ├── Need external actor control? →
  │     ├── From MATLAB? → Workflow D (System object co-sim)
  │     └── From Simulink? → Workflow E (Simulink blocks)
  ├── Need read-only monitoring? → Workflow F (Observers)
  └── Need sensor data during sim? → Workflow G (SensorSimulation)
```

---

## Workflow A: Simple Simulation (run to completion)

Use when the user just wants to simulate an already-open scenario:

```matlab
openScenario(rrApp, "MyScenario");
simulateScenario(rrApp, EnableLogging=true);
```

Options: `Pacing`, `IsBlocking`, `IsSteppingStart`, `EnableLogging`.

**Important:** `simulateScenario` does NOT return a log object. Use it when you only need to run to completion. If you need **programmatic access** to the simulation log in MATLAB, use `createSimulation` (Workflow B) instead.

---

## Workflow B: Step-by-Step Simulation

Use when the user needs frame-by-frame control or programmatic log access.

**CRITICAL call order:** `createSimulation` must be called BEFORE `simulateScenario`. The Scenario Server rejects new connections while a simulation is running or paused. Also, do NOT use `set(rrSim, SimulationCommand="Start")` then `"Step"` — `"Start"` runs the sim freely to completion.

```matlab
% 1. Get the simulation handle FIRST (before anything is running)
rrSim = createSimulation(rrApp);
stepSize = 0.01;
set(rrSim, StepSize=stepSize);
set(rrSim, MaxSimulationTime=30);

% 2. THEN start simulation in stepping mode
simulateScenario(rrApp, IsSteppingStart=true, IsBlocking=false, EnableLogging=true);
pause(0.5);  % Allow sim to initialize before stepping

% 3. Step through the simulation
for i = 1:numSteps
    set(rrSim, SimulationCommand="Step");
    pause(stepSize);  % REQUIRED — Step is async, must wait for frame to complete
end
set(rrSim, SimulationCommand="Stop");

simLog = get(rrSim, "SimulationLog");
```

**CRITICAL:** `"Step"` is **asynchronous** — you MUST add `pause(stepSize)` after each Step. Without it, commands pile up and are silently dropped. Do NOT use dot-method syntax (`rrSim.step()`) — always use `set(rrSim, SimulationCommand=...)`. Do NOT set `Logging="On"` during stepping — use `EnableLogging=true` in the `simulateScenario` call.

### SimulationCommand values

`"Start"`, `"Step"`, `"Pause"`, `"Continue"`, `"Stop"`, `"Replay"`

Replay uses positional syntax: `set(rrSim, "SimulationCommand", "Replay", fileName)`

### Polling SimulationStatus

`get(rrSim, "SimulationStatus")` returns: `"Inactive"`, `"Running"`, `"Paused"`, `"Done"`

Use in wait loops when running non-blocking simulations. Check BOTH `"Done"` and `"Inactive"` — short scenarios may transition past `"Done"` before the poll catches it:
```matlab
status = get(rrSim, "SimulationStatus");
while ~ismember(status, ["Done", "Inactive"])
    pause(0.1);
    status = get(rrSim, "SimulationStatus");
end
```

---

## Workflow C: Reading Actor State

To get actor information during a step-by-step simulation:

**Note:** `get(rrSim, "ActorSimulation")` always includes the **world actor** (ID 0) at index 1. This is a non-movable root actor, not a vehicle. Skip it or filter by ID when iterating.

**Note:** Actors are only queryable while the simulation is active (Running or Paused). After `"Stop"`, `get(rrSim, "ActorSimulation")` returns empty.

```matlab
% Get all actors — returns a CELL ARRAY, use {idx} not (idx)
actors = get(rrSim, "ActorSimulation");
actorSim = actors{2};  % cell indexing required; index 1 is world actor (ID 0)

% Or find a specific actor by ID (returns a single object)
% NOTE: ActorID must be uint64 — double will fail silently or error
actorSim = Simulink.ScenarioSimulation.find("ActorSimulation", ActorID=uint64(1));

% Read runtime attributes — use getAttribute, NOT property access
pose = getAttribute(actorSim, "Pose");              % 4x4 matrix
velocity = getAttribute(actorSim, "Velocity");      % 1x3 vector
angVel = getAttribute(actorSim, "AngularVelocity"); % 1x3 vector
```

**CRITICAL:** Do NOT use `actorSim.Pose` or `actorSim.Velocity` — these are NOT public properties. Always use `getAttribute(actorSim, "AttrName")`.

Runtime attributes: `"ID"`, `"Pose"`, `"Velocity"`, `"AngularVelocity"`, `"WheelPoses"`, `"LaneLocation"`, `"Children"`, `"Parent"`, `"PhaseStatus"`, `"ActorType"`, `"TrafficSignalRuntime"`, `"TrafficSignalControllerRuntime"`

### Static Attributes (Name, BoundingBox, etc.)

To get an actor's **name** or other static properties, use `ActorModel` — NOT `getAttribute(actorSim, "Name")` (which does not exist):

```matlab
actorModel = get(actorSim, "ActorModel");
actorName = getAttribute(actorModel, "Name");
boundingBox = getAttribute(actorModel, "BoundingBox");
```

Static attributes on `ActorModel`: `"ID"`, `"Name"`, `"PaintColor"`, `"BoundingBox"`, `"WheelSpec"`, `"TrafficSignalSpec"`, `"TrafficSignalControllerSpec"`

---

## Workflow D: Co-Simulation with MATLAB System Object

### Architecture

1. **Assign a behavior to the actor** (see below)
2. **In MATLAB**: Write a System object that controls the actor at runtime
3. The System object finds itself using `Simulink.ScenarioSimulation.find`

### Assigning Behaviors

**R2024a:** Assign behaviors in the RoadRunner Scenario Editor UI only (no MATLAB API).

**R2025a+:** Assign behaviors programmatically via the `roadrunnerAPI` authoring interface:

```matlab
rrApi = roadrunnerAPI(rrApp);
prj = rrApi.Project;
scnro = rrApi.Scenario;

% Get or create a behavior asset
behaviorAsset = getAsset(prj, "Behaviors/MyBehavior.rrbehavior", "BehaviorAsset");

% Assign to an existing actor
car.BehaviorAsset = behaviorAsset;
```

Key points:
- `roadrunnerAPI(rrApp)` provides access to `Project` and `Scenario` objects
- Use `getAsset(prj, path, "BehaviorAsset")` to retrieve existing `.rrbehavior` assets
- Use `createAsset(prj, path, "BehaviorAsset")` to create new behavior assets
- After creating a behavior asset, set its platform: `setPlatform(behaviorAsset, "SimulinkPlatform")` — this is correct for BOTH MATLAB System objects and Simulink models. Do NOT use `"MATLAB"`, `"External"`, or `"MATLABSystem"` (they are not registered)
- Assign via the `BehaviorAsset` property on `Vehicle`/`Character`/`MovableObject`
- There is NO `setBehavior()` function — use property assignment instead

### System Object Pattern

```matlab
classdef MyActorController < matlab.System
    properties (Access = private)
        ActorSim  % ActorSimulation handle
    end

    methods (Access = protected)
        function setupImpl(obj)
            obj.ActorSim = Simulink.ScenarioSimulation.find( ...
                "ActorSimulation", SystemObject=obj);
        end

        function stepImpl(obj)
            action = getAction(obj.ActorSim, "PathAction");
            currentPose = getAttribute(obj.ActorSim, "Pose");

            % Modify pose
            currentPose(1,4) = currentPose(1,4) + 0.5;
            setAttribute(obj.ActorSim, Pose=currentPose);

            % Signal action completion (guard: ActionID may not exist)
            if ~isempty(action) && isfield(action, "ActionID")
                sendEvent(obj.ActorSim, "ActionComplete", action.ActionID);
            end
        end
    end
end
```

### Actor Control Methods

```matlab
setAttribute(actorSim, Pose=poseMatrix);            % 4x4
setAttribute(actorSim, Velocity=[vx vy vz]);        % 1x3
setAttribute(actorSim, AngularVelocity=[wx wy wz]); % 1x3

action = getAction(actorSim, "PathAction");
action = getAction(actorSim, "SpeedAction");
action = getAction(actorSim, "LaneChangeAction");

sendEvent(actorSim, "ActionComplete", actionID);
sendEvent(actorSim, "UserDefinedEvent", eventName, eventStruct);
eventData = receiveEvent(actorSim, "UserDefinedEvent", eventName);
```

---

## Workflow E: Co-Simulation with Simulink

### Architecture

1. Create a Simulink model with the **RoadRunner Scenario** block at root level
2. Use **RoadRunner Scenario Reader** blocks to receive data from RoadRunner
3. Use **RoadRunner Scenario Writer** blocks to send data back
4. Publish the behavior: `Simulink.publish.publishActorBehavior("myModel", OutputFile="output.slprotodata")`
5. Assign the behavior to an actor (via RoadRunner UI, or programmatically in R2025a+ — see Workflow D)
6. Start simulation via `set_param("myModel", SimulationCommand="start")` — NOT `sim()`

### Key Constraints

- The RoadRunner Scenario block **must** be at the model root level
- Use `set_param(..., SimulationCommand="start")` to start — **never** `sim("model")`
- Sample time in the RoadRunner Scenario block defines the co-sim step size (default 0.02s)
- One MATLAB instance connects to one RoadRunner co-sim at a time
- Bus types are loaded from `rrScenarioSimTypes.mat`

### Reader Topics

Actor Pose, Specifications, Lane Location, Vehicle Wheel Poses, Traffic Signals, Target Poses, Lane Boundaries, Actions (Path/Speed/Lane Change/etc.), User-Defined Events

### Writer Topics

Actor Pose, Vehicle Pose, Action Complete, User-Defined Events, Diagnostics

See `references/simulink-cosim-details.md` for block configuration and bus types.

---

## Workflow F: Observers (Read-Only Monitoring)

Observers monitor simulation state without modifying it. Unlike co-sim behaviors (assigned in UI), observers are added **programmatically**.

```matlab
rrSim = createSimulation(rrApp);
addObserver(rrSim, "VelocityMonitor", "MyVelocityObserver");
simulateScenario(rrApp, IsBlocking=false);
% Observer's stepImpl is called each step automatically
```

**Note:** The observer `.m` file must be on the MATLAB path. Use `addpath` if needed. Call `addObserver` BEFORE starting the simulation.

### Observer System Object Pattern

```matlab
classdef MyVelocityObserver < matlab.System
    properties (Access = private)
        ScenarioSim
    end

    methods (Access = protected)
        function setupImpl(obj)
            obj.ScenarioSim = Simulink.ScenarioSimulation.find( ...
                "ScenarioSimulation");
        end

        function stepImpl(obj)
            actors = get(obj.ScenarioSim, "ActorSimulation");
            for idx = 1:numel(actors)
                vel = getAttribute(actors{idx}, "Velocity");
                % Read-only analysis — logging, visualization, etc.
            end
        end
    end
end
```

**CRITICAL:** Observers are READ-ONLY. They may call `getAttribute` but must NOT call `setAttribute`. They find the `ScenarioSimulation` (not `ActorSimulation`) in `setupImpl`.

**Management:**
- `addObserver(rrSim, name, fileName)` — add (returns logical success)
- `removeObserver(rrSim, name)` — remove
- `get(rrSim, "Observers")` — query registered observers

Observers can also be Simulink models (`.slx`) since R2024b.

---

## Workflow G: Sensor Simulation

Attach driving sensors to actors and read ground-truth data during simulation.

```matlab
rrSim = createSimulation(rrApp);
sensorSim = get(rrSim, "SensorSimulation");

% Create and attach sensors to ego vehicle (actor ID 1)
visionSensor = visionDetectionGenerator(SensorIndex=1, ...
    SensorLocation=[2.4 0], MaxRange=50);
radarSensor = drivingRadarDataGenerator(SensorIndex=2, ...
    MountingLocation=[1.8 0 0.2]);
addSensors(sensorSim, {visionSensor, radarSensor}, 1);

% During step loop
set(rrSim, SimulationCommand="Start");
for i = 1:numSteps
    set(rrSim, SimulationCommand="Step");
    targets = targetPoses(sensorSim, 1);       % struct array in ego frame
    lanes = laneBoundaries(sensorSim, 1);      % lane boundary data
end
set(rrSim, SimulationCommand="Stop");
```

**Key points:**
- `SensorSimulation` is obtained via `get(rrSim, "SensorSimulation")` — NOT constructed directly
- Each sensor must have a unique `SensorIndex`
- The second argument in `targetPoses(sensorSim, actorID)` is the **actorID** of the ego vehicle (the one you attached sensors to via `addSensors`) — NOT the SensorIndex
- `targetPoses` returns positions/velocities relative to the host vehicle
- `laneBoundaries` supports `OutputOption`: `"EgoLane"`, `"EgoAdjacentLanes"`, `"AllLanes"`

Supported sensors: `visionDetectionGenerator`, `drivingRadarDataGenerator`, `ultrasonicDetectionGenerator`, `lidarPointCloudGenerator`, `lidarSensor`

---

## Scenario Variables

```matlab
% Get a variable
value = getScenarioVariable(rrApp, "EgoSpeed");

% Set a variable (value MUST be a string)
setScenarioVariable(rrApp, "EgoSpeed", "30");

% Get all variables — returns struct ARRAY with Name/Value fields
allVars = getAllScenarioVariables(rrApp);
for i = 1:numel(allVars)
    fprintf("%s = %s\n", allVars(i).Name, allVars(i).Value);
end
```

**Do NOT** use `fieldnames(allVars)` — that gives struct field names (`Name`, `Value`), not variable names.

---

## Simulation Log

Programmatic log access requires stepping mode or a completed simulation:

```matlab
% After simulation completes (or during stepping)
simLog = get(rrSim, "SimulationLog");

% Query actor pose history — returns struct array with .Time and .Pose fields
poseLog = get(simLog, "Pose", "ActorID", 1);
% poseLog(i).Time  — scalar timestamp
% poseLog(i).Pose  — 4x4 transform matrix

% Extract positions for plotting
positions = arrayfun(@(s) s.Pose(1:3,4)', poseLog, UniformOutput=false);
positions = vertcat(positions{:});  % Nx3 matrix

% Save/load logs
save(rrSim, "SimulationLog", "myLog.mat");
log = load(rrSim, "SimulationLog", "myLog.mat");
```

**Log return format:** `get(simLog, "Pose", "ActorID", id)` returns a **struct array** (not a numeric array). Each element has `.Time` (scalar) and `.Pose` (4x4 matrix). Use `arrayfun` to extract positions for plotting.

---

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `simulateScenario(rrApp)` | Run simulation to completion | R2024a |
| `createSimulation(rrApp)` | Create ScenarioSimulation for step control | R2022a |
| `prepareSimulation(rrApp)` | Submit sim data before co-sim clients connect | R2024a |
| `set(rrSim, SimulationCommand=cmd)` | Control simulation | R2022a |
| `get(rrSim, param)` | Query simulation state | R2022a |
| `addObserver(rrSim, name, file)` | Add read-only observer | R2022a |
| `getAttribute(actorSim, attr)` | Read actor runtime state | R2022a |
| `setAttribute(actorSim, NV)` | Set actor state (co-sim only) | R2022a |
| `getAction(actorSim, name)` | Get assigned action | R2022a |
| `sendEvent(actorSim, event, ...)` | Send event to scenario | R2022b |
| `receiveEvent(actorSim, event, name)` | Receive event from scenario | R2023a |
| `addSensors(sensorSim, sensors, actorID)` | Attach sensors | R2023a |
| `targetPoses(sensorSim, sensorID)` | Get target poses in ego frame | R2023a |
| `laneBoundaries(sensorSim, sensorID)` | Get lane boundary data | R2023a |
| `Simulink.ScenarioSimulation.find(...)` | Find active simulation/actors | R2022a |
| `Simulink.publish.publishActorBehavior(model)` | Publish Simulink behavior | R2022a |
| `roadrunnerAPI(rrApp)` | Get authoring API (Project, Scenario) | R2025a |
| `getAsset(prj, path, type)` | Retrieve asset (BehaviorAsset, VehicleAsset, etc.) | R2025a |
| `createAsset(prj, path, type)` | Create new asset in project | R2025a |
| `addActor(scnro, asset, position)` | Add actor to scenario programmatically | R2025a |

See `references/simulation-api-reference.md` for full function signatures, name-value pairs, and return types.

---

## Architecture: Actor Behavior Types

**R2024a:** Behaviors are assigned in the RoadRunner Scenario Editor UI only.
**R2025a+:** Behaviors can also be assigned programmatically via `car.BehaviorAsset = behaviorAsset` (see Workflow D).

| Behavior Type | What It Means | MATLAB Role |
|---------------|---------------|-------------|
| **Ready-to-Run** | Actor follows built-in path/logic | No code needed — just observe |
| **MATLAB System** | Actor controlled by a System object | Write System object (Workflow D) |
| **Simulink Model** | Actor controlled by Simulink model | Build model with RR blocks (Workflow E) |

---

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `rrSim.start()` / `.step()` / `.stop()` | Dot-method syntax does not exist | `set(rrSim, SimulationCommand="Start"\|"Step"\|"Stop")` |
| `actorSim.Pose` or `actorSim.Velocity` | Not public properties | `getAttribute(actorSim, "Pose")` |
| `get(rrSim, "Actors")` | Wrong parameter name | `get(rrSim, "ActorSimulation")` |
| `set(rrSim, Logging=true)` | Value must be string | `set(rrSim, Logging="On")` |
| Using `drivingScenario` for RoadRunner | Completely different toolbox | Use `simulateScenario`/`createSimulation` |
| `roadrunnerScenario(name)` | This class does not exist | `openScenario(rrApp, name)` then simulate |
| `sim("model")` for co-sim | Wrong command for co-simulation | `set_param("model", SimulationCommand="start")` |
| `setBehavior(actor, ...)` | This function does not exist | Use `car.BehaviorAsset = behaviorAsset` (R2025a+) or assign in RoadRunner UI |
| `fieldnames(getAllScenarioVariables(rrApp))` | Gets struct fields, not variable names | `allVars(i).Name` |
| `log = simulateScenario(rrApp, ...)` | No return value | Use `createSimulation` + `get(rrSim, "SimulationLog")` |
| `setAttribute` in observer | Observers are read-only | Use `getAttribute` only |
| `addSensors(rrSim, ...)` | Wrong object | `addSensors(sensorSim, ...)` on SensorSimulation |
| `getAttribute(actorSim, "Name")` | Name is static, not runtime | `get(actorSim, "ActorModel")` then `getAttribute(actorModel, "Name")` |
| `actors(idx)` after `get(rrSim, "ActorSimulation")` | Returns a cell array, not an object array | Use `actors{idx}` (cell indexing) |
| `set(rrSim, SimulationCommand="Start")` then `"Step"` | `"Start"` runs freely — sim completes before you can step | Use `simulateScenario(rrApp, IsSteppingStart=true, IsBlocking=false)` first |
| Step loop without `pause(stepSize)` | `"Step"` is async — commands pile up and are silently dropped | Add `pause(stepSize)` after each `set(rrSim, SimulationCommand="Step")` |
| `set(rrSim, Logging="On")` during stepping | Errors "Failed to enable or disable logging while simulation is running" | Use `simulateScenario(rrApp, ..., EnableLogging=true)` before `createSimulation` |
| Treating `actors{1}` as the ego vehicle | Index 1 is always the world actor (ID 0), not a vehicle | Use `actors{2}` or find by ID with `Simulink.ScenarioSimulation.find("ActorSimulation", ActorID=uint64(id))` |
| `Simulink.ScenarioSimulation.find(..., ActorID=1)` | ActorID must be `uint64`, not `double` | Use `ActorID=uint64(1)` |
| `createSimulation` after `simulateScenario` in stepping mode | Server rejects connections while sim is paused | Call `createSimulation(rrApp)` BEFORE `simulateScenario(rrApp, IsSteppingStart=true, ...)` |
| `targetPoses(sensorSim, sensorIndex)` | Second argument is the actorID, not sensorIndex | Use `targetPoses(sensorSim, actorID)` where actorID is the ego vehicle's ID |
| `setPlatform(behaviorAsset, "MATLAB")` | Not a registered type string | Use `setPlatform(behaviorAsset, "SimulinkPlatform")` for both MATLAB and Simulink behaviors |

## Conventions

- **Always use** `set`/`get` with ScenarioSimulation — never dot-methods
- **Always use** `getAttribute`/`setAttribute` for actor runtime state
- **Use `simulateScenario`** for simple run-to-completion — don't over-engineer with `createSimulation`
- **Use `createSimulation`** when you need step control, actor introspection, or log access
- **Behavior assignment:** In R2024a, use RoadRunner UI. In R2025a+, use `car.BehaviorAsset = getAsset(prj, path, "BehaviorAsset")`
- **Co-sim System objects** must use `Simulink.ScenarioSimulation.find("ActorSimulation", SystemObject=obj)` in `setupImpl`
- **Observers** find `"ScenarioSimulation"` (not `"ActorSimulation"`) and are read-only
- **Lifecycle:** Opening a new scenario (`openScenario`) invalidates any existing `rrSim` — call `createSimulation` again

----
Copyright 2026 The MathWorks, Inc.
----
