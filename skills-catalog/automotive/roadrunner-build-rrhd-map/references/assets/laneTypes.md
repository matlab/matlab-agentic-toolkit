# Lane Type Mapping

Maps lane types from all source formats to RoadRunner lane type enums.

## Unified Lane Type Table

| Source Type | Source Format | RR Lane Type |
|---|---|---|
| `driving` / `road` / `highway` | Lanelet2, Apollo | `Driving` |
| `DRIVABLE_LANE` | TomTom | `Driving` |
| `through` | Apollo | `Driving` |
| `connectingRamp` | Apollo | `Driving` |
| `parallel` | Apollo | `Driving` |
| `emergencyParkingStrip` | Apollo | `Driving` |
| `divisionZone` | Apollo | `Driving` |
| `BUS_LANE` / `bus_lane` | TomTom, Lanelet2 | `Driving` |
| `HOV_LANE` | TomTom | `Driving` |
| `RESTRICTED_LANE` | TomTom | `Driving` |
| `biking` / `bicycle_lane` | Apollo, Lanelet2 | `Biking` |
| `BICYLCE_LANE` | TomTom | `Biking` |
| `parking` | Apollo, Lanelet2 | `Parking` |
| `PARKING_LANE` | TomTom | `Parking` |
| `shoulder` / `emergency_lane` / `road_shoulder` | Apollo, Lanelet2 | `Shoulder` |
| `EMERGENCY_LANE` | TomTom | `Shoulder` |
| `onRamp` | Apollo | `Onramp` |
| `offRamp` | Apollo | `Offramp` |
| `entrance` | Apollo | `Entry` |
| `exit` | Apollo | `Exit` |
| `walkway` / `sidewalk` | Lanelet2 | `Sidewalk` |
| `curb` | Lanelet2 | `Curb` |
| `center_turn` | Lanelet2 | `CenterTurn` |
| `none` / `NON_DRIVABLE_LANE` | Apollo, TomTom | `None` |

## HERE Functional Class → Road Type

| Functional Class | Road Type |
|---|---|
| `FC_1` | `motorway` |
| `FC_2` | `town` |
| `FC_3` | `rural` |
| `FC_4` | `lowSpeed` |
| `FC_5` | `lowSpeed` |
| `unknown` | `unknown` |

## Lanelet2 Subtype → Lane Type (with special cases)

| Lanelet2 `subtype` | RR Lane Type | Notes |
|---|---|---|
| `road` | `Driving` | Default |
| `highway` | `Driving` | |
| `bus_lane` | `Driving` | |
| `bicycle_lane` | `Biking` | |
| `parking` | `Parking` | |
| `emergency_lane` | `Shoulder` | |
| `road_shoulder` | `Shoulder` | |
| `walkway` | `Sidewalk` | |
| `curb` | `Curb` | |
| `center_turn` | `CenterTurn` | |
| `crosswalk` | — | **NOT a lane** → CurveMarking |
| (unknown) | `Driving` | Fallback default |

## Available RoadRunner Lane Types (enum)

From `roadrunner.hdmap.LaneType`:
- `Driving`
- `Shoulder`
- `Biking`
- `Parking`
- `Sidewalk`
- `Curb`
- `CenterTurn`
- `Onramp`
- `Offramp`
- `Entry`
- `Exit`
- `None`
- `Border`
- `Median`

----

Copyright 2026 The MathWorks, Inc.

----
