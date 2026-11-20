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

### Vehicles not in the catalog (a branded car, a prototype)

Never invent an asset path such as `"Vehicles/TeslaRoadster.fbx"`: `getAsset` fails. Two options, both verified in R2026b:

1. **Stand-in (preferred):** the closest catalog vehicle, recoloured with `actor.Color` (RGBA, values 0–1). Tell the user it is a stand-in.
   ```matlab
   car = addActor(rrs, getAsset(rrprj, "Vehicles/Sedan.fbx", "VehicleAsset"), position);
   car.Color = [1 0 0 1];   % red
   ```
2. **Custom-size placeholder:** `createAsset(rrprj, "Vehicles/Name.rrvehicle", "VehicleAsset")` creates a *placeholder* vehicle (`AssetDetailType = "placeholder"`, default 1.8 × 4.7 × 1.4 m). Its dimensions are settable (`Size`, `FrontOverhang`, `RearOverhang`, `WheelRadius`, …), so collision boxes and spacing match the real vehicle, but it has no 3D model. `WheelBase` is read-only: it is derived as length − `FrontOverhang` − `RearOverhang` (verified R2026b Update 2). A real model can only be imported in RoadRunner. `createAsset` writes the asset file (`.rrmeta`) into the project immediately, and it stays there if the scenario is discarded; tell the user which files were created.

**Licensing:** use only 3D models the user has rights to. Don't download branded models (for example a Tesla Roadster) without a license.

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
| Traffic Cone | `"Props/TrafficControl/TrafficCone01.fbx"` | In the default project |
| Barricade | `"Props/TrafficControl/Barricade01.fbx_rrx"` | Asset Library only — exists only if the project was created with the RoadRunner Asset Library |

Check that an asset file exists in the project before calling `getAsset` (a missing asset throws "Invalid asset"). If it is missing, do not stop the build:
- **Vehicles:** use `"Vehicles/Sedan.fbx"` (present in every project) and keep building.
- **Characters:** use `"Characters/Citizen_Male.rrchar"` if present.
- **Props / misc objects:** use `"Props/TrafficControl/TrafficCone01.fbx"` (present in the default project) as a stand-in at the same position. Do not drop the object — for `.xosc` recreations every source entity must still become an actor.

Always list every substitution in the output (and in the Scenario Description for `.xosc` recreations) — never substitute silently.

**Placing props on the road ahead of an actor:** query the HD map for a point ahead of the actor, restricted to the actor's lane, then `autoAnchor` the prop so it snaps to the road:

```matlab
egoPos = ego.InitialPoint.WorldPosition;
[~, egoHdg, egoLane] = helperGetPositionFromHDMap(hdMap, egoPos);
props = ["Cone",      "Props/TrafficControl/TrafficCone01.fbx",    30;
         "Barricade", "Props/TrafficControl/Barricade01.fbx_rrx",  40];
for i = 1:size(props, 1)
    assetPath = props(i,2);
    if ~isfile(fullfile(rrprj.FullPath, "Assets", assetPath))
        fprintf("%s not in this project; using TrafficCone01 as a stand-in\n", assetPath);
        assetPath = "Props/TrafficControl/TrafficCone01.fbx";
    end
    asset = getAsset(rrprj, assetPath, "MovableObjectAsset");
    ahead = egoPos + str2double(props(i,3)) * egoHdg / norm(egoHdg);
    pos = helperGetPositionFromHDMap(hdMap, ahead, LaneIDs=egoLane.ID);
    obj = addActor(rrs, asset, pos);
    obj.Name = props(i,1);
    autoAnchor(obj.InitialPoint);
end
```

Do not attach props to another actor's point (`anchorToPoint` + `ForwardOffset`) — anchor them to the road.

**Exception — `.xosc` recreations:** place each prop (or its `TrafficCone01` stand-in) at the position translated from the source and do NOT `autoAnchor` it. The source position is exact, often off the lane (e.g. on the shoulder), and anchoring would snap it onto the lane (see `references/openscenario-analysis.md`, Anchoring rules).

**Note:** Movable objects are in `Props/`, NOT `MovableObjects/`. Any actor added via `addActor` (including movable objects) automatically gets an initial phase in phase logic. Truly static objects that should NOT appear in phase logic must be placed via the RoadRunner scene editor, not the scenario API.

## Creating Custom Assets

Create new vehicle, character, or behavior assets programmatically:

```matlab
% Create a new vehicle asset
newVehicle = createAsset(rrprj, "Vehicles/CustomCar.rrvehicle", "VehicleAsset");

% Create a new character asset
newChar = createAsset(rrprj, "Characters/CustomPed.rrchar", "CharacterAsset");

% Create a behavior asset and assign a platform
newBehavior = createAsset(rrprj, "Behaviors/Custom.rrbehavior", "BehaviorAsset");
platform = setPlatform(newBehavior, "SimulinkPlatform");   % setPlatform: RoadRunner R2025b or later
platform.FileName = "myController.slx";
```

Supported asset types for `createAsset`: `"VehicleAsset"`, `"CharacterAsset"`, `"BehaviorAsset"`, `"LaneMarkingStyle"`

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
