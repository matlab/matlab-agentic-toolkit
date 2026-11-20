# Static Objects & Props Asset Mapping

Maps object types from source formats to RoadRunner prop assets.

## Trees & Vegetation

| Type | Asset Path | Notes |
|---|---|---|
| `tree` (default) | `Props/Trees/Eucalyptus_Sm01.fbx` | OpenDRIVE default |
| `vegetation` (default) | `Props/Trees/Bush_Sm01.fbx` | OpenDRIVE default |
| tree (various) | `Props/Trees/Ash01.fbx_rrx` | Multiple species available |
| tree (various) | `Props/Trees/Birch01.fbx_rrx` | |
| tree (various) | `Props/Trees/Elm01.fbx_rrx` | |
| tree (various) | `Props/Trees/Maple01.fbx_rrx` | |
| tree (palm) | `Props/Trees/CalPalm_Full_Lg01.fbx_rrx` | Multiple sizes |
| tree (pine) | `Props/Trees/CoulPine_Lg01.fbx_rrx` | Multiple sizes |
| tree (cypress) | `Props/Trees/Cypress_Lg01.fbx_rrx` | |

## Poles & Posts

| Type | Height | Asset Path |
|---|---|---|
| Sign post (10ft) | 3.0m | `Props/Signals/SignPost_10ft.fbx` |
| Sign post (8ft) | 1.2m | `Props/Signals/SignPost_8ft.fbx_rrx` |
| Signal post (30ft) | 9.1m | `Props/Signals/Signal_Post_30ft.fbx` |
| Signal post (17ft) | 5.2m | `Props/Signals/Signal_Post_17ft.fbx_rrx` |
| Signal post (12ft) | 3.7m | `Props/Signals/Signal_Post_12ft.fbx_rrx` |
| Signal mast arm (15-45ft) | varies | `Props/Signals/Signal_MastArm_<15|25|35|45>ft.fbx` / `Props/Signals/Signal_MastArm_<20|30|40>ft.fbx_rrx` |
| Street light | — | `Props/Signals/StreetLight_30ft.rrpa` |
| Utility pole (30-60ft) | varies | `Props/ElectricPoles/UtilityPole_<30|40|50|60>ft.fbx_rrx` |
| Electrical tower | — | `Props/ElectricPoles/ElectricalTower01_100ft.fbx_rrx` |
| Wood post (8-10ft) | varies | `Props/Signals/WoodPost_<8|10>ft.fbx_rrx` |
| Metal cylinder post | varies | `Props/Signals/Metal_CylinderPost_<3|8|10|12>ft.fbx_rrx` |

## Traffic Control

| Type | Asset Path |
|---|---|
| Traffic cone | `Props/TrafficControl/TrafficCone01.fbx` |
| Barricade | `Props/TrafficControl/Barricade01.fbx_rrx` |
| Drum | `Props/TrafficControl/Drum01.fbx_rrx` |
| Grabber/delineator | `Props/TrafficControl/Grabber01.fbx_rrx` |
| Leitpfosten (DE) | `Props/TrafficControl/Leitpfosten01.fbx_rrx` |
| Arrow board | `Props/TrafficControl/ArrowBoard01.fbx_rrx` |
| Chevron sign | `Props/TrafficControl/ChevronSign01.fbx_rrx` |
| Stripe sign | `Props/TrafficControl/StripeSign01.fbx_rrx` |

## Misc Props

| Type | Asset Path |
|---|---|
| Rock (multiple) | `Props/Misc/Rock01.fbx_rrx` through `Rock04.fbx` |
| Wall | `Props/Misc/Wall.fbx_rrx` |
| Trashcan | `Props/Construction/Trashcan01.fbx_rrx` |
| Dumpster (large) | `Props/Construction/Dumpster_Lg01.fbx_rrx` |
| Dumpster (small) | `Props/Construction/Dumpster_Sm01.fbx_rrx` |
| Construction cart | `Props/Construction/ConstructionCart.fbx_rrx` |
| Vending machine (JP) | `Props/Japan/VendingMachine_01.fbx_rrx` |

## Vehicles (OpenSCENARIO)

| Type | Asset Path |
|---|---|
| Sedan | `Vehicles/Sedan.fbx` |
| SUV | `Vehicles/Suv.fbx_rrx` |
| Compact car | `Vehicles/CompactCar.fbx_rrx` |
| Pickup truck | `Vehicles/PickupTruck.fbx_rrx` |
| Delivery van | `Vehicles/DeliveryVan.fbx_rrx` |
| Semi truck | `Vehicles/SemiTruck.fbx_rrx` |
| School bus | `Vehicles/SchoolBus.fbx_rrx` |
| Ambulance | `Vehicles/Ambulance.fbx_rrx` |
| Garbage truck | `Vehicles/GarbageTruck.fbx_rrx` |
| Utility truck | `Vehicles/UtilityTruck.fbx_rrx` |
| Cement truck | `Vehicles/CementTruck.fbx_rrx` |
| Backhoe | `Vehicles/Backhoe.fbx_rrx` |

## Pedestrians (OpenSCENARIO)

| Type | Asset Path |
|---|---|
| Female business | `Characters/Citizen Female Business01.rrchar` |
| Female casual | `Characters/Citizen Female Casual01.rrchar` |
| Female elder | `Characters/Citizen Female Elder01.rrchar` |
| Male business | `Characters/Citizen Male Business01.rrchar` |
| Male casual | `Characters/Citizen Male Casual01.rrchar` |
| Male child | `Characters/Citizen Male Child01.rrchar` |
| Male elder | `Characters/Citizen Male Elder01.rrchar` |

## OpenDRIVE Object Type → Asset Mapping

| `<object type="...">` | Default Asset |
|---|---|
| `obstacle` | `Props/TrafficControl/TrafficCone01.fbx` |
| `pole` | `Props/Signals/SignPost_10ft.fbx` (Height=3m) |
| `tree` | `Props/Trees/Eucalyptus_Sm01.fbx` |
| `vegetation` | `Props/Trees/Bush_Sm01.fbx` |
| `barrier` | `Props/Construction/Barricade01.fbx_rrx` |
| `trafficIsland` | `Materials/Concrete1.rrmtl` (material, not prop) |
| `crosswalk` | `Markings/ContinentalCrosswalk.rrcws` |
| `roadMark` (StopLine) | `Markings/StopLine.rrlms` |
| `roadMark` (arrow) | `Stencils/Stencil_ArrowType4L.svg` |
| `patch` | `Damage/AsphaltPatch01.rrpms` |

## MATLAB Construction Pattern

```matlab
% StaticObjectType
sot = roadrunner.hdmap.StaticObjectType;
sot.ID = "TrafficCone";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Props/TrafficControl/TrafficCone01.fbx";
sot.AssetPath = rap;

% StaticObject instance
so = roadrunner.hdmap.StaticObject;
so.ID = "Object_1";
gobb = roadrunner.hdmap.GeoOrientedBoundingBox;
gobb.Center = [x, y, z];
gobb.Dimension = [0.15, 0.15, 0.35];  % half-lengths: 0.3 x 0.3 x 0.7 m
gobb.GeoOrientation = [0, 0, deg2rad(yawDeg)];  % [roll pitch heading], radians
so.Geometry = gobb;
typeRef = roadrunner.hdmap.Reference;
typeRef.ID = "TrafficCone";
so.ObjectTypeReference = typeRef;
```

----

Copyright 2026 The MathWorks, Inc.

----
