# Asset Catalog

## Vehicle Assets

Load with: `getAsset(rrprj, path, "VehicleAsset")`

| Asset | API Path | Notes |
|-------|----------|-------|
| Sedan | `"Vehicles/Sedan.fbx"` | Default vehicle, 4.7m x 1.8m |
| Compact Car | `"Vehicles/CompactCar.fbx"` | |
| SUV | `"Vehicles/Suv.fbx"` | **lowercase 'uv'** — NOT `SUV.fbx` |
| Pickup Truck | `"Vehicles/PickupTruck.fbx"` | 5.5m x 2.0m |
| Delivery Van | `"Vehicles/DeliveryVan.fbx"` | |
| Ambulance | `"Vehicles/Ambulance.fbx"` | |
| School Bus | `"Vehicles/SchoolBus.fbx"` | |
| Cement Truck | `"Vehicles/CementTruck.fbx"` | |
| Garbage Truck | `"Vehicles/GarbageTruck.fbx"` | |
| Utility Truck | `"Vehicles/UtilityTruck.fbx"` | |
| Semi Truck | `"Vehicles/SemiTruck.fbx"` | 12m x 2.5m |
| Semi Trailer 01 | `"Vehicles/SemiTruck_Trailer01.fbx"` | |
| Semi Trailer 02 | `"Vehicles/SemiTruck_Trailer02.fbx"` | |
| Semi Trailer 03 | `"Vehicles/SemiTruck_Trailer03.fbx"` | |
| Semi Trailer 04 | `"Vehicles/SemiTruck_Trailer04.fbx"` | |
| Backhoe | `"Vehicles/Backhoe.fbx"` | Construction equipment |

## Character Assets (Pedestrians)

Load with: `getAsset(rrprj, path, "CharacterAsset")`

**WARNING:** Character asset paths are project-specific. The paths below are defaults for new RoadRunner projects. EuroNCAP projects use different paths (e.g., `EuroNCAPTestSuite/Pedestrian.rrchar`). **Always verify with a try/catch pattern before use.**

| Asset | API Path | Notes |
|-------|----------|-------|
| Male (default) | `"Characters/Citizen_Male.rrchar"` | Default projects |
| Male Business | `"Characters/Citizen Male Business01.rrchar"` | Default projects |
| Male Casual | `"Characters/Citizen Male Casual01.rrchar"` | Default projects |
| Male Elder | `"Characters/Citizen Male Elder01.rrchar"` | Default projects |
| Male Child | `"Characters/Citizen Male Child01.rrchar"` | Default projects |
| Female Business | `"Characters/Citizen Female Business01.rrchar"` | Default projects |
| Female Casual | `"Characters/Citizen Female Casual01.rrchar"` | Default projects |
| Female Elder | `"Characters/Citizen Female Elder01.rrchar"` | Default projects |
| EuroNCAP Pedestrian | `"EuroNCAPTestSuite/Pedestrian.rrchar"` | EuroNCAP projects |
| EuroNCAP Child | `"EuroNCAPTestSuite/Child.rrchar"` | EuroNCAP projects |

**Note:** Character file extension is `.rrchar`, not `.fbx`. On disk the file may appear as `.rrchar_rrx` — always use `.rrchar` in the API call.

**Recommended verification pattern:**
```matlab
% Try default path first, fall back to project-specific paths
try
    charAsset = getAsset(rrprj, "Characters/Citizen_Male.rrchar", "CharacterAsset");
catch
    % Try EuroNCAP path — adjust based on project
    charAsset = getAsset(rrprj, "EuroNCAPTestSuite/Pedestrian.rrchar", "CharacterAsset");
end
```

## Movable Object Assets (Props)

Load with: `getAsset(rrprj, path, "MovableObjectAsset")`

| Asset | API Path | Notes |
|-------|----------|-------|
| Traffic Cone | `"Props/TrafficControl/TrafficCone01.fbx"` | |
| Barricade | `"Props/TrafficControl/Barricade01.fbx"` | |

**Note:** Movable objects are in `Props/`, NOT `MovableObjects/`. Any actor added via `addActor` (including movable objects) automatically gets an initial phase in phase logic. Truly static objects that should NOT appear in phase logic must be placed via the RoadRunner scene editor, not the scenario API.

## Discovering Assets Programmatically

No `listAssets()` API exists. To enumerate available assets, browse the project filesystem:

```matlab
proj = rrApi.Project;
assetsDir = fullfile(proj.FullPath, "Assets", "Vehicles");
files = dir(fullfile(assetsDir, "*.fbx*"));
for i = 1:numel(files)
    if ~endsWith(files(i).name, ".rrmeta")
        apiPath = "Vehicles/" + regexprep(files(i).name, '_rrx$', '');
        disp(apiPath);
    end
end
```

## Vehicle Dimensions (for spacing calculations)

| Vehicle | Length | Width |
|---------|--------|-------|
| Sedan | 4.7 m | 1.8 m |
| SUV | 4.9 m | 2.0 m |
| Pickup Truck | 5.5 m | 2.0 m |
| Semi Truck | 12.0 m | 2.5 m |
| School Bus | 10.0 m | 2.5 m |

## Actor Spacing Rules

- Same lane: minimum 10m between actors
- Adjacent lanes: natural lane width (~3.5m) provides lateral separation
- Always verify spacing after placement

----

Copyright 2026 The MathWorks, Inc.

----
