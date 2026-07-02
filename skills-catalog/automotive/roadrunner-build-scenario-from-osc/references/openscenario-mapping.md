# OpenSCENARIO to RoadRunner API Mapping

## Actions

| ASAM OpenSCENARIO | RoadRunner Scenario Representation | API Action Type |
|---|---|---|
| SpeedAction (AbsoluteTargetSpeed) | Change Speed action | `ChangeSpeedAction` |
| SpeedAction (RelativeTargetSpeed) | Change Speed action (relative) | `ChangeSpeedAction` with `SpeedReference="actor"` |
| LaneChangeAction | Change Lane action | `ChangeLaneAction` |
| LaneOffsetAction | Change Lateral Offset action | `ChangeLateralOffsetAction` |
| LongitudinalDistanceAction | Change Longitudinal Distance action | `ChangeLongitudinalDistanceAction` |
| SetAction of ParameterAction | Change Global Parameter action | `ChangeGlobalParameterAction` |
| SetAction of VariableAction | Change Global Parameter action | `ChangeGlobalParameterAction` |
| FollowTrajectoryAction | Change Speed action where actor has a defined path | `ChangeSpeedAction` with route + `SpeedReference="route-time-data"` |
| AssignRouteAction | Change Speed action where actor has a defined path | `ChangeSpeedAction` with route |
| TeleportAction | Initial position of the associated actor | `addActor` with world position |
| SynchronizeAction | Synchronize action | `SynchronizeAction` |
| UserDefinedAction (CustomCommandAction type="MW_WaitAction") | Wait action | `WaitAction` |
| UserDefinedAction (other CustomCommandAction types) | User Defined action | `UserDefinedAction` |
| AddEntityAction | Wait action + actor placement | `WaitAction` → then `addActor` at translated world position from the action's Position element |
| DeleteEntityAction | Remove Actor action | `RemoveActorAction` |

## Conditions

| ASAM OpenSCENARIO | RoadRunner Scenario Representation | API Condition Type |
|---|---|---|
| SimulationTimeCondition | Simulation Time condition | `SimulationTimeCondition` (property: `.Time`) |
| RelativeDistanceCondition (cartesianDistance) | Distance To Actor condition | `DistanceToActorCondition` |
| RelativeDistanceCondition (euclideanDistance) | Distance To Actor condition | `DistanceToActorCondition` |
| RelativeDistanceCondition (longitudinal) | Longitudinal Distance to Actor condition | `LongitudinalDistanceToActorCondition` |
| DistanceCondition (to world point) | Distance To Point condition | `DistanceToPointCondition` (`.Point` = route Point object) |
| SpeedCondition | Actor Speed condition | `ActorSpeedCondition` |
| RelativeSpeedCondition | Actor Speed condition (relative) | `ActorSpeedCondition` with Relative to Actor + ReferenceActor |
| ParameterCondition | Global Parameter condition | `GlobalParameterCondition` |
| VariableCondition | Global Parameter condition | `GlobalParameterCondition` |
| CollisionCondition | Collision condition | `CollisionCondition` |
| StoryboardElementStateCondition | Phase State condition | `PhaseStateCondition` (`.PhaseState`: "idle"/"start"/"run"/"end") |
| DurationCondition | Duration condition | `DurationCondition` (property: `.Duration`) |
| TimeToCollisionCondition | Time To Actor condition | `TimeToActorCondition` — **NOT SUPPORTED** in RoadRunner API |
| RelativeDistanceCondition (lateral) | Lateral Distance to Actor condition | `LateralDistanceToActorCondition` — **NOT SUPPORTED** in RoadRunner API |

## Structural Mapping

| OpenSCENARIO Structure | RoadRunner Equivalent |
|---|---|
| Story > Act > ManeuverGroup > Maneuver > Event | Phase Logic (RootPhase > serial/parallel phases) |
| Parallel Events in same ManeuverGroup | `addPhaseInParallel` |
| Sequential Events (StoryboardElementState trigger) | `addPhaseInSerial` |
| Act StartTrigger | `setEndCondition` on preceding phase |
| Act StopTrigger | `setEndCondition` on the phase representing that Act |
| StopTrigger (scenario level) | `setEndCondition` or `setFailCondition` on RootPhase |
| ParameterDeclaration / VariableDeclaration | Resolve expressions at parse time to concrete values |
| CatalogReference | Read catalog XML, resolve to asset path at parse time |
| OpenDRIVE LanePosition | Parse .xodr geometry → world [x, y, z] |
| OpenDRIVE RoadPosition | Parse .xodr geometry → world [x, y, z] |
| RelativeRoadPosition (ds, dt from entity) | Resolve base entity position + heading, apply offsets |
| RelativeWorldPosition (dx, dy, dz from entity) | Resolve base entity position, add offsets |

## State Mapping (StoryboardElementStateCondition → PhaseStateCondition)

| XOSC State | API `.PhaseState` Value |
|---|---|
| `completeState` | `"end"` |
| `runningState` | `"run"` |
| `startTransition` | `"start"` |
| `standbyState` | `"idle"` |

## Rule Mapping (Condition rule attributes)

| XOSC Rule | API `.Rule` Value |
|---|---|
| `greaterOrEqual` | `"ge"` |
| `greaterThan` | `"gt"` |
| `lessOrEqual` | `"le"` |
| `lessThan` | `"lt"` |
| `equalTo` | `"eq"` |

## SpeedAction Property Mapping

| XOSC Attribute | RoadRunner Property | Values |
|---|---|---|
| dynamicsShape | `DynamicsShape` | `"step"`, `"linear"`, `"cubic"` |
| dynamicsDimension | `DynamicsDimension` | `"time"`, `"distance"`, `"rate"` |
| value (of dynamics) | `DynamicsValue` | numeric |
| AbsoluteTargetSpeed.value | `Speed` | numeric (m/s) |
| RelativeTargetSpeed.entityRef | `ReferenceActor` | actor object |
| RelativeTargetSpeed.value | `Speed` + `Direction` | See relative speed rules |
| RelativeTargetSpeed.speedTargetValueType | `Direction` | "delta" → faster/slower based on sign |

## ChangeLaneAction Property Mapping

| XOSC Attribute | RoadRunner Property | Values |
|---|---|---|
| RelativeTargetLane.entityRef | `ReferenceActor` | actor object |
| RelativeTargetLane.value = 0 | `LaneChangeReference = "actor"` | Changes to same lane as actor |
| AbsoluteTargetLane / numeric offset | `LaneChangeReference = "lane"`, `Direction`, `NumLanesOffset` | "left" or "right" + count |
| dynamicsShape | `DynamicsShape` | `"cubic"`, `"linear"`, `"step"` |
| dynamicsDimension | `DynamicsDimension` | `"time"`, `"distance"` |
| value | `DynamicsValue` | numeric |

----

Copyright 2026 The MathWorks, Inc.

----
