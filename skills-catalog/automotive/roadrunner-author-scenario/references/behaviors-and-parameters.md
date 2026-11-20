# Behaviors and Behavior Parameters

Everything below was checked live in R2026b Update 2 unless marked otherwise.

## What works from MATLAB

**Create a behavior asset and assign it to an actor:**

```matlab
prj = rrApi.Project;
behavior = createAsset(prj, "Behaviors/MyBehavior.rrbehavior", "BehaviorAsset");   % built-in RoadRunner platform by default
actor.BehaviorAsset = behavior;
validate(rrs);
```

**Choose the platform** with `setPlatform(behavior, platformType)`:

| `platformType` | Returned object | Settable properties |
|---|---|---|
| (default) | `RoadRunnerPlatform` | none |
| `"SimulinkPlatform"` | `SimulinkPlatform` | `FileName` (the Simulink model) |
| `"ExternalPlatform"` | `ExternalPlatform` | `PlatformName`, `ModelLocation` |

`setPlatform` and `BehaviorAsset.Platform` are available from RoadRunner R2025b.

```matlab
platform = setPlatform(behavior, "SimulinkPlatform");
platform.FileName = "myVehicleBehavior.slx";
```

`RemoveActorAction` only works for actors on the built-in RoadRunner platform; Simulink, external and FMU behaviors raise a simulation error.

## What does not work from MATLAB (R2026b)

| Need | Status | What to tell the user |
|---|---|---|
| Set a behavior parameter (for example `FollowGround`, `RotateWheels`) | Not exposed: `RoadRunnerPlatform` has no properties and the API has no parameter classes | Set it on the behavior asset in RoadRunner |
| Change a parameter during the run (`ChangeParameterAction`) | `addAction` errors: "Object type 'ChangeParameterAction' is not registered." | Add the action in the RoadRunner Scenario editor |
| Branch on a behavior parameter (Behavior Parameter condition) | No condition class for it | Add the condition in the editor |
| User-defined actions and events | Not registered | Add them in the editor |

When a request needs one of these, build everything else from MATLAB, then list the missing pieces for the user. Don't invent property names or call unregistered types.

## Built-in behavior parameters

The built-in behavior reads two Boolean parameters from the actor's behavior asset when the actor is created:

| Parameter | Default for vehicles | Default for movable objects and props | Effect |
|---|---|---|---|
| `FollowGround` | true | false | Fits the actor to the terrain each step. While true, a vehicle ignores the height of its route: in R2026b a car on a route raised 5 m stayed at road level (verified in simulation) |
| `RotateWheels` | true | false | Animates wheel rotation |

They must be real Booleans (a string `"false"` or a numeric `0` is not read as false). A Change Parameter action can toggle them mid-run, but that action has to be authored in the editor (see above).

## Related

- Airborne routes and their limits: `routes-and-points.md` §Off-Road and Airborne Paths
- Actions available from MATLAB: `actions-and-conditions.md` §Actions

----

Copyright 2026 The MathWorks, Inc.

----
