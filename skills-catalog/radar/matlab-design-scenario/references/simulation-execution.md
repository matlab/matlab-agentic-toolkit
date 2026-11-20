# Run the Simulation

## Advance Loop

`advance` moves every actor one step along its trajectory and updates the analyses.

```matlab
scnro = scenario(StopTime=60);
actr = actor(scnro, pointtable(40.7092, -74.0137, 200), Name="Radio Tower");
waypoints = pointtable([40.7080; 40.7100], [-74.0100; -74.0080]);
c = car(scnro, groundTrajectory(waypoints, GroundSpeed=10), Name="Patrol Car");
losA = losAnalysis(actr, c);
while advance(scnro)
    visible = hasLOS(losA);
    fprintf("T=%.1fs: visible=%d\n", seconds(scnro.SimulationTime), visible);
end
```

- `advance(scnro)` takes no step size. The first call runs t = 0; each later call steps by
  the smallest `TimeStep` of the behaviors stored in the moving actors (default `seconds(0.1)`).
- It returns `true` while running and `false` on the call that completes the simulation.
  The loop body does not run for that final call.
- The run ends at the earlier of `StopTime` or the end of the last trajectory. A finite
  `StopTime` can only shorten a run.
- An actor whose trajectory has ended stays in the scenario and holds its final position
  and orientation until the run ends. Analyses keep evaluating it at that pose (for example,
  `hasLOS` still returns a value each step). Its pose `Velocity` keeps the last nonzero value.
- With only static actors, the first `advance` returns `false` and the loop body never runs.
  Query analyses directly instead (for example, `hasLOS(losA)` without a loop).
- Steps accumulate in floating point: `StopTime=0.3` with 0.1 s steps ends at 0.2 s. Add a
  small margin when the exact final time matters.

## Restart

```matlab
restart(scnro);   % t = 0, actors back to initial poses, status "notstarted"
```

After the simulation starts (even after one `advance`), the scenario, actors, behaviors,
and analyses are locked. Adding, removing, or changing actors and analyses, or setting
`StopTime` or `TimeStep`, errors until you call `restart`. Calling `advance` after completion
also errors until you call `restart`.

## Record Results Per Step

```matlab
t = [];
visible = [];
while advance(scnro)
    t(end+1) = seconds(scnro.SimulationTime);  %#ok<SAGROW>
    visible(end+1) = hasLOS(losA);             %#ok<SAGROW>
end
stairs(t, visible);
xlabel("Time (s)");
ylabel("LOS visible");
```

## Simulation Properties

| Property | Values | Description |
|---|---|---|
| `SimulationTime` | `seconds(0)` (default) \| `duration` | Current time; `seconds(scnro.SimulationTime)` gives a double |
| `SimulationStatus` | `"notstarted"` (default) \| `"running"` \| `"complete"` | Read-only enumeration; compare with strings, for example `scnro.SimulationStatus == "complete"` |
| `StopTime` | `seconds(Inf)` (default) \| positive number or `duration` | Stored as a `duration`. Set it before the run starts |

----

Copyright 2026 The MathWorks, Inc.

----
