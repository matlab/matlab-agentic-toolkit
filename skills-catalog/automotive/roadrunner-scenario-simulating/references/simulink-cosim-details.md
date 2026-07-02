# Simulink Co-Simulation Details

## RoadRunner Scenario Block

The root-level block that defines the actor interface for co-simulation.

**Parameters:**
- `Sample time` — Co-sim step size (default 0.02s, range 1e-5 to 10s)
- `Actor ID` — Which actor this model controls
- Actions tab — Configure which actions the actor receives
- Events tab — Configure user-defined events

**Constraint:** Must be placed at the model root level. Cannot be inside a subsystem.

## RoadRunner Scenario Reader Block

Reads data FROM RoadRunner into Simulink. Outputs Simulink messages.

### Reader Topics

| Category | Topic | Output |
|----------|-------|--------|
| Actor | Pose | 4x4 matrix + velocity + angular velocity |
| Actor | Specifications | Static actor properties |
| Actor | Lane Location | Lane info struct |
| Actor | Vehicle Wheel Poses | Wheel pose array |
| Actor | Traffic Signals | Signal state |
| Sensor | Target Poses | Struct array in host frame |
| Sensor | Lane Boundaries | Lane boundary struct |
| Action | Path Following | Path action data |
| Action | Speed Change | Speed action data |
| Action | Lane Change | Lane change action data |
| Action | Lateral Offset | Lateral offset data |
| Action | Longitudinal Distance | Distance data |
| Action | Change Parameter | Parameter change data |
| Action | User Defined | Custom action struct |
| Event | User-Defined | Custom event struct |

### Filter Options

- `Self` — Only data for the actor running this behavior
- `Actor ID` — Specific actor by ID
- `All` — All actors in scenario

## RoadRunner Scenario Writer Block

Writes data FROM Simulink back to RoadRunner. Accepts Simulink messages.

### Writer Topics

| Topic | Data |
|-------|------|
| Actor Pose | Position, velocity, roll/pitch/yaw, angular velocity |
| Vehicle Pose | Includes wheel poses (up to 18 wheels) |
| Action Complete | ActionID + status (Unspecified/Dispatched/Skipped/Interrupted/Done) |
| User-Defined Events | Custom event bus |
| Diagnostics | Type + message string |

## Bus Types

Bus definitions are loaded from `rrScenarioSimTypes.mat`. Key buses:
- `BusActorPose`
- `BusActorRuntime`
- `BusVehicleRuntime`
- `BusActionComplete`
- `BusDiagnostics`

## Publishing a Behavior

```matlab
Simulink.publish.publishActorBehavior("myModel", OutputFile="myBehavior.slprotodata")
```

This generates a `.slprotodata` file that RoadRunner can interpret. After publishing:
1. Open RoadRunner Scenario Editor
2. Select the actor
3. Assign the published behavior via the Behavior dropdown

## Starting Co-Simulation

From the Simulink side:
```matlab
set_param("myModel", SimulationCommand="start");
```

From the MATLAB side (after behavior is assigned in RR):
```matlab
simulateScenario(rrApp);
% or
rrSim = createSimulation(rrApp);
set(rrSim, SimulationCommand="Start");
```

**Never use `sim("myModel")` for co-simulation — it does not support the RoadRunner co-sim protocol.**

## prepareSimulation

Call before external co-sim clients connect:
```matlab
prepareSimulation(rrApp);
```

This submits scenario/map data to the simulation engine so clients can connect before simulation starts. Use when coordinating multiple co-sim clients.

----

Copyright 2026 The MathWorks, Inc.

----
