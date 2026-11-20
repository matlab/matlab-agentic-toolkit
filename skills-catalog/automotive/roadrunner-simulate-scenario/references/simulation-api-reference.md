# RoadRunner Scenario Simulation API Reference

## simulateScenario (R2024a+)

```matlab
simulateScenario(rrApp)
simulateScenario(rrApp, Name=Value)
```

| Name-Value | Type | Default | Description |
|-----------|------|---------|-------------|
| `Pacing` | numeric | — | Pacing multiplier |
| `IsBlocking` | logical | `true` | Block MATLAB during simulation |
| `IsSteppingStart` | logical | `false` | Single step start |
| `EnableLogging` | logical | `false` | Enable simulation logging |

## createSimulation (R2022a+)

```matlab
rrSim = createSimulation(rrApp)
```

Returns a `Simulink.ScenarioSimulation` object for step-by-step control.

## prepareSimulation (R2024a+)

```matlab
prepareSimulation(rrApp)
```

Submits simulation data to the engine. Call before co-sim clients connect.

## ScenarioSimulation set (R2022a+)

```matlab
set(rrSim, Name=Value)
```

| Name-Value | Type | Description |
|-----------|------|-------------|
| `SimulationCommand` | string | `"Start"`, `"Pause"`, `"Continue"`, `"Stop"`, `"Step"`, `"Replay"` |
| `StepSize` | double | Step size in seconds (default 0.02) |
| `MaxSimulationTime` | double | Max simulation time (default 1000) |
| `PacerStatus` | string | `"On"` or `"Off"` |
| `SimulationPace` | double | Pacing multiplier |
| `Logging` | string | `"On"` or `"Off"` |

Replay uses positional syntax: `set(rrSim, "SimulationCommand", "Replay", fileName)`

## ScenarioSimulation get (R2022a+)

```matlab
output = get(rrSim, param)
```

| Parameter | Returns |
|-----------|---------|
| `"StepSize"` | double |
| `"MaxSimulationTime"` | double |
| `"PacerStatus"` | string |
| `"SimulationPace"` | double |
| `"SimulationStatus"` | char |
| `"SimulationLog"` | ScenarioLog object |
| `"Logging"` | string |
| `"ActorSimulation"` | ActorSimulation object array |
| `"Observers"` | observer info |
| `"SimulationTime"` | double |
| `"SensorSimulation"` | SensorSimulation object |
| `"Map"` | roadrunnerHDMap object |
| `"ScenarioServices"` | ScenarioServices object (R2024b+) |

## ScenarioSimulation addObserver/removeObserver (R2022a+)

```matlab
success = addObserver(rrSim, observerName, fileName)
removeObserver(rrSim, observerName)
```

- `observerName` — unique string identifier
- `fileName` — System object `.m` file or Simulink model `.slx` (R2024b+)
- Returns logical 1/0 for success/failure

## ScenarioSimulation save/load (R2023a+)

```matlab
save(rrSim, "SimulationLog", fileName)
log = load(rrSim, "SimulationLog", fileName)
```

## Simulink.ScenarioSimulation.find (R2022a+)

```matlab
ss = Simulink.ScenarioSimulation.find("ScenarioSimulation")
actor = Simulink.ScenarioSimulation.find("ActorSimulation", ActorID=id)
actor = Simulink.ScenarioSimulation.find("ActorSimulation", SystemObject=obj)
```

## ActorSimulation getAttribute (R2022a+)

```matlab
runtimeAttr = getAttribute(actorSim, runtimeAttrName)
```

| Attribute | Returns |
|-----------|---------|
| `"ID"` | scalar |
| `"Pose"` | 4x4 matrix |
| `"Velocity"` | 1x3 vector |
| `"AngularVelocity"` | 1x3 vector |
| `"WheelPoses"` | array |
| `"LaneLocation"` | struct |
| `"Children"` | — |
| `"Parent"` | — |
| `"PhaseStatus"` | — |
| `"ActorType"` | char |
| `"TrafficSignalRuntime"` | — |
| `"TrafficSignalControllerRuntime"` | — |

## ActorSimulation setAttribute (R2022a+)

```matlab
setAttribute(actorSim, Name=Value)
```

| Name-Value | Type |
|-----------|------|
| `Pose` | 4x4 matrix |
| `Velocity` | 1x3 vector |
| `AngularVelocity` | 1x3 vector |
| `WheelPoses` | array |

## ActorSimulation getAction (R2022a+)

```matlab
action = getAction(actorSim, actionName)
action = getAction(actorSim, "UserDefinedAction", userActionName)
```

Action names: `"PathAction"`, `"SpeedAction"`, `"LaneChangeAction"`, `"LateralOffsetAction"`, `"ChangeParameterAction"`, `"LongitudinalDistanceAction"`, `"UserDefinedAction"`

## ActorSimulation sendEvent (R2022b+)

```matlab
sendEvent(actorSim, "ActionComplete", actionID)
sendEvent(actorSim, "UserDefinedEvent", eventName, eventStruct)
```

## ActorSimulation receiveEvent (R2023a+)

```matlab
eventStruct = receiveEvent(actorSim, "UserDefinedEvent", eventName)
```

## ActorSimulation get (R2022a+)

```matlab
actorModel = get(actorSim, "ActorModel")
scenarioSim = get(actorSim, "ScenarioSimulation")
```

## SensorSimulation (R2023a+)

### Getting the object

```matlab
sensorSim = get(rrSim, "SensorSimulation");
```

### addSensors

```matlab
addSensors(sensorSim, sensors, actorID)
```

- `sensors` — single sensor or cell array `{sensor1, sensor2, ...}`
- `actorID` — positive integer (host vehicle)
- Each sensor must have unique `SensorIndex`

### targetPoses

```matlab
poses = targetPoses(sensorSim, sensorID)
```

Returns struct array with: `ActorID`, `ClassID`, `Position`, `Velocity`, `Roll`, `Pitch`, `Yaw`, `AngularVelocity` (all in ego frame)

### laneBoundaries

```matlab
lbData = laneBoundaries(sensorSim, sensorID)
lbData = laneBoundaries(sensorSim, sensorID, OutputOption="AllLanes")
lbData = laneBoundaries(sensorSim, sensorID, inHostCoordinate=false)
```

| Name-Value | Type | Default | Description |
|-----------|------|---------|-------------|
| `OutputOption` | string | `"EgoLane"` | `"EgoLane"`, `"EgoAdjacentLanes"`, `"AllLanes"` |
| `inHostCoordinate` | logical | `true` | `false` returns world coordinates |

Returns struct array with: `Coordinates`, `Curvature`, `CurvatureDerivative`, `HeadingAngle`, `LateralOffset`, `BoundaryType`, `Strength`, `Width`, `Length`, `Space`

### Supported Sensors

- `visionDetectionGenerator` (Automated Driving Toolbox)
- `drivingRadarDataGenerator` (Automated Driving Toolbox)
- `ultrasonicDetectionGenerator` (Automated Driving Toolbox)
- `lidarPointCloudGenerator` (Automated Driving Toolbox)
- `lidarSensor` (Lidar Toolbox)

### GPU Acceleration

`sensorSim.UseGPU` — `"auto"` (default), `"on"`, `"off"` — applies to lidar/GNSS sensors only.

## Scenario Variables (R2022a+)

```matlab
value = getScenarioVariable(rrApp, name)
setScenarioVariable(rrApp, name, value)   % value must be string
allVars = getAllScenarioVariables(rrApp)   % returns struct array with Name/Value
```

## openScenario (R2022a+)

```matlab
openScenario(rrApp, filename)
openScenario(rrApp, filename, true)  % keep current scene (don't reload)
```

Use `keepCurrentScene=true` when you want to load a different scenario's actors/behaviors into an already-loaded scene (avoids reloading scene assets).

## getCoSimPort (R2022b+)

```matlab
simPortNum = getCoSimPort(rrApp)
```

Returns the co-simulation API server port number.

----

Copyright 2026 The MathWorks, Inc.

----
