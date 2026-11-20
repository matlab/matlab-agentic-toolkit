# Build RRHD Objects

Direct construction of `roadrunnerHDMap` entities without external builder functions.

## Critical Pattern: Create-Then-Assign

Never pass **positional** constructor arguments to `roadrunner.hdmap.*` classes. Create-then-assign works in every release; Name=Value constructors work for every class (verified R2026b).

```matlab
% CORRECT (create-then-assign):
ref = roadrunner.hdmap.Reference;
ref.ID = "myID";

% CORRECT (Name=Value constructors):
rap = roadrunner.hdmap.RelativeAssetPath(AssetPath="Assets/Markings/StopLine.rrlms");
ar = roadrunner.hdmap.AlignedReference(Reference=ref, Alignment="Forward");

% WRONG (positional args will error with "A name is expected"):
ref = roadrunner.hdmap.Reference("myID");
rap = roadrunner.hdmap.RelativeAssetPath("Assets/...");
ar = roadrunner.hdmap.AlignedReference(bndID, "Forward");
```

**Important:** You must create a `roadrunnerHDMap` object before using `roadrunner.hdmap.*` classes (lazy namespace loading):
```matlab
rrMap = roadrunnerHDMap;  % ensures namespace is loaded
```

## Empty Typed Arrays

Never use `[]` for typed properties — MATLAB will error. Use `.empty`:
```matlab
lane.Predecessors = roadrunner.hdmap.AlignedReference.empty;  % CORRECT
lane.Predecessors = [];  % WRONG: "Value must be of type AlignedReference"
rrMap.Junctions = roadrunner.hdmap.Junction.empty;  % CORRECT for empty collections
```

## Actual Property Names (R2026a — tested and confirmed)

These are the **verified** property names — do NOT guess alternatives:

| Class | Properties |
|---|---|
| `Lane` | `ID`, `Geometry`, `TravelDirection`, `LeftLaneBoundary`, `RightLaneBoundary`, `Predecessors`, `Successors`, `LaneType`, `Metadata`, `ParametricAttributes` |
| `LaneBoundary` | `ID`, `Geometry`, `ParametricAttributes` |
| `LaneMarking` | `ID`, `AssetPath` |
| `SpeedLimit` | `ID`, `Value` (int32), `VelocityUnit` (`"Kph"` or `"Mph"`) |
| `ParametricAttribution` | `Span`, `MarkingReference`, `SpeedLimitReference`, `SignalReference` |
| `MarkingReference` | `MarkingID` (Reference obj), `FlipLaterally` (logical) |
| `SpeedLimitReference` | `SpeedLimitID` (Reference obj) |
| `AlignedReference` | `Reference` (Reference obj), `Alignment` (`"Forward"` or `"Backward"`) |
| `Reference` | `ID` (string) |
| `RelativeAssetPath` | `AssetPath` (string) |
| `Junction` | `ID`, `Geometry`, `Lanes`, `Configurations` |
| `JunctionConfiguration` | `ID`, `Name`, `Phases` |
| `Phase` | `ID`, `Name`, `Time` (int32), `JunctionLaneStates` |
| `JunctionLaneState` | `LaneID` (Reference obj), `State` |
| `BarrierType` | `ID`, `ExtrusionPath` (RelativeAssetPath obj) |
| `Barrier` | `ID`, `Geometry`, `BarrierTypeReference` (Reference obj), `FlipLaterally` (logical), `Metadata` |
| `CurveMarkingType` | `ID`, `AssetPath` (RelativeAssetPath obj) |
| `CurveMarking` | `ID`, `Geometry`, `MarkingTypeReference` (Reference obj), `Flip` (logical), `Reverse` (logical), `Metadata` |

**Common mistakes to avoid:**
- Lane boundary property is `LeftLaneBoundary` / `RightLaneBoundary` (NOT `LeftBoundary`)
- Speed limit property is `Value` (NOT `Speed`), unit is `VelocityUnit` (NOT `Unit`)
- Unit values are `"Kph"` / `"Mph"` (NOT `"KPH"` / `"KilometersPerHour"`)
- Parametric attributes class is `ParametricAttribution` (NOT `ParametricAttrib`)
- `ParametricAttribution` has direct `.MarkingReference` and `.SpeedLimitReference` properties (NOT a generic `.Value`)
- Phase class is `Phase` (NOT `JunctionPhase`)

## Lane Markings

```matlab
laneMarkings = roadrunner.hdmap.LaneMarking.empty;
defs = sem.markingDefs.values;            % one per marking ID (extractSemantics.md)
for i = 1:numel(defs)
    lm = roadrunner.hdmap.LaneMarking;
    lm.ID = defs{i}.id;                    % e.g. "SolidDoubleWhite"
    lm.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=defs{i}.asset);
    laneMarkings(end+1) = lm;
end
```

## Speed Limits

```matlab
speedLimits = roadrunner.hdmap.SpeedLimit.empty;
for i = 1:numel(slSpecs)
    sl = roadrunner.hdmap.SpeedLimit;
    sl.ID = slSpecs(i).id;        % e.g. "SL_50"
    sl.Value = int32(slSpecs(i).value);  % int32 speed value
    sl.VelocityUnit = "Kph";      % "Kph" or "Mph"
    speedLimits(end+1) = sl;
end
```

## Lane Boundaries

**CRITICAL: Boundary geometry must be ORIGINAL way geometry from OSM — never modified.**
Boundaries are shared between multiple lanes (including opposing-direction lanes via `Alignment="Backward"`). Modifying boundary geometry (flipping, endpoint projection, resampling) corrupts it for other lanes referencing the same way.

**One boundary per way:** Use a `wayToBndID` map to deduplicate. The first lanelet that references a way creates the boundary object; all subsequent lanes share it and use `Alignment` to handle direction.

```matlab
% Build boundaries from ORIGINAL way geometry (deduplicated by way ID)
wayToBndID = containers.Map('KeyType','char','ValueType','char');   % way IDs are char keys
laneBoundaries = roadrunner.hdmap.LaneBoundary.empty;
bndCount = 0;

for i = regularLaneIndices
    ll = lanelets(i);
    sides = [ll.leftWayID, ll.rightWayID];
    for s = 1:2
        wID = char(sides(s));
        if isempty(wID) || wayToBndID.isKey(wID), continue; end

        bndCount = bndCount + 1;
        bndID = sprintf('Bnd_%d', bndCount);
        lb = roadrunner.hdmap.LaneBoundary;
        lb.ID = bndID;

        % ORIGINAL way geometry from geomMap (coordinates.md) — NO modification
        lb.Geometry = geomMap(wID);

        % Parametric attributes for markings (skip if junction boundary)
        isJunction = ismember(i, junctionLaneIndices);
        if ~isJunction && sem.markingMap.isKey(wID)   % keyed by way: carries colour and flip
            mInfo = sem.markingMap(wID);
            pa = roadrunner.hdmap.ParametricAttribution;
            pa.Span = [0 1];
            mr = roadrunner.hdmap.MarkingReference;
            mr.MarkingID = roadrunner.hdmap.Reference(ID=mInfo.id);
            mr.FlipLaterally = mInfo.flip;
            pa.MarkingReference = mr;
            lb.ParametricAttributes = pa;
        end

        laneBoundaries(end+1) = lb;
        wayToBndID(wID) = bndID;
    end
end
```

## Lanes

```matlab
lanes = roadrunner.hdmap.Lane.empty;
for i = 1:numel(laneSpecs)
    ln = roadrunner.hdmap.Lane;
    ln.ID = laneSpecs(i).id;  % e.g. "Lane_100"
    ln.Geometry = laneSpecs(i).geometry;  % Nx3 center line
    ln.TravelDirection = laneSpecs(i).travelDirection;  % "Forward", "Backward", "Bidirectional", "Undirected"
    ln.LaneType = laneSpecs(i).laneType;  % "Driving", "Sidewalk", etc.

    % Left boundary (AlignedReference)
    % CRITICAL: Alignment uses proximity detection + spatial verification:
    % 1. Compare d_starts vs d_cross to detect same/opposite boundary flow
    % 2. Use leftNormal spatial check to confirm left is geometrically on left
    % See references/authoring/alignmentRules.md for full algorithm
    if strlength(laneSpecs(i).leftBoundaryID) > 0
        ar = roadrunner.hdmap.AlignedReference;
        ref = roadrunner.hdmap.Reference;
        ref.ID = laneSpecs(i).leftBoundaryID;
        ar.Reference = ref;
        ar.Alignment = laneSpecs(i).leftAlignment;  % "Forward" or "Backward"
        ln.LeftLaneBoundary = ar;
    end

    % Right boundary (AlignedReference)
    if strlength(laneSpecs(i).rightBoundaryID) > 0
        ar = roadrunner.hdmap.AlignedReference;
        ref = roadrunner.hdmap.Reference;
        ref.ID = laneSpecs(i).rightBoundaryID;
        ar.Reference = ref;
        ar.Alignment = laneSpecs(i).rightAlignment;
        ln.RightLaneBoundary = ar;
    end

    % Predecessors
    for p = 1:numel(laneSpecs(i).predecessors)
        ar = roadrunner.hdmap.AlignedReference;
        ref = roadrunner.hdmap.Reference;
        ref.ID = laneSpecs(i).predecessors(p).id;
        ar.Reference = ref;
        ar.Alignment = "Forward";
        ln.Predecessors(end+1) = ar;
    end

    % Successors
    for s = 1:numel(laneSpecs(i).successors)
        ar = roadrunner.hdmap.AlignedReference;
        ref = roadrunner.hdmap.Reference;
        ref.ID = laneSpecs(i).successors(s).id;
        ar.Reference = ref;
        ar.Alignment = "Forward";
        ln.Successors(end+1) = ar;
    end

    % Speed limits (ParametricAttribution with SpeedLimitReference)
    for sl = 1:numel(laneSpecs(i).speedLimits)
        pa = roadrunner.hdmap.ParametricAttribution;
        pa.Span = laneSpecs(i).speedLimits(sl).span;  % [0 1]
        ref = roadrunner.hdmap.Reference;
        ref.ID = laneSpecs(i).speedLimits(sl).speedLimitID;
        slRef = roadrunner.hdmap.SpeedLimitReference;
        slRef.SpeedLimitID = ref;
        pa.SpeedLimitReference = slRef;
        ln.ParametricAttributes(end+1) = pa;
    end

    lanes(end+1) = ln;
end
```

## Junctions

```matlab
junctions = roadrunner.hdmap.Junction.empty;
for j = 1:numel(juncSpecs)
    jObj = roadrunner.hdmap.Junction;
    jObj.ID = juncSpecs(j).id;

    % Lane references
    for k = 1:numel(juncSpecs(j).laneIDs)
        ref = roadrunner.hdmap.Reference;
        ref.ID = juncSpecs(j).laneIDs(k);
        jObj.Lanes(end+1) = ref;
    end

    % MultiPolygon geometry
    mp = roadrunner.hdmap.MultiPolygon;
    for k = 1:numel(juncSpecs(j).polygons)
        pg = roadrunner.hdmap.Polygon;
        pg.ExteriorRing = juncSpecs(j).polygons(k).exteriorRing;
        for ir = 1:numel(juncSpecs(j).polygons(k).interiorRings)
            pg.InteriorRings(end+1) = {juncSpecs(j).polygons(k).interiorRings{ir}};
        end
        mp.Polygons(end+1) = pg;
    end
    jObj.Geometry = mp;

    % Signal configurations
    for c = 1:numel(juncSpecs(j).configurations)
        cfg = juncSpecs(j).configurations(c);
        jcObj = roadrunner.hdmap.JunctionConfiguration;
        jcObj.ID = cfg.id;
        jcObj.Name = cfg.name;

        for p = 1:numel(cfg.phases)
            ph = roadrunner.hdmap.Phase;
            ph.ID = sprintf("Phase_%d", p);
            ph.Name = cfg.phases(p).name;
            ph.Time = cfg.phases(p).time;  % int32 seconds

            for ls = 1:numel(cfg.phases(p).laneStates)
                jls = roadrunner.hdmap.JunctionLaneState;
                ref = roadrunner.hdmap.Reference;
                ref.ID = cfg.phases(p).laneStates(ls).laneID;
                jls.LaneID = ref;
                jls.State = cfg.phases(p).laneStates(ls).state;
                ph.JunctionLaneStates(end+1) = jls;
            end

            jcObj.Phases(end+1) = ph;
        end
        jObj.Configurations(end+1) = jcObj;
    end

    junctions(end+1) = jObj;
end
```

## Signal State Mapping (Custom Tags → RRHD Build API)

OSM `custom:phase_*` tags store RRHD read-back state names. Map before building:

| OSM tag value | RRHD Build API state |
|---|---|
| `Go` | `GoAlways` |
| `GoYield` | `Yield` |
| `Stop` | `Stop` |
| `StopYield` | `Stop/Yield` |

## Endpoint Snapping

Connected lanes (predecessor/successor pairs) must have exactly matching endpoints:

```matlab
% For each lane with successors:
%   lane.Geometry(end,:) must exactly equal successor.Geometry(1,:)
%   Corresponding boundary endpoints must also match
% Snap the successor's start to the predecessor's end (overwrite)
```

## Height Conflict Resolution

Overlapping lanes at the same Z level cause grass artifacts. Detect and bump:

```matlab
% 1. Build adjacency graph: lanes connected by topology are in same component
% 2. Find lane pairs from DIFFERENT components whose bounding boxes overlap
% 3. Assign Z levels via graph coloring (connected = same level, overlapping = different)
% 4. Bump each level by +0.05m * level_index
% 5. Apply Z offset to lane geometry AND both boundaries
```

## Final Assembly

```matlab
rrMap = roadrunnerHDMap;
rrMap.Lanes = lanes;
rrMap.LaneBoundaries = laneBoundaries;
rrMap.LaneMarkings = laneMarkings;
rrMap.SpeedLimits = speedLimits;
rrMap.Junctions = junctions;

% CurveMarkings (stop lines, crosswalks)
rrMap.CurveMarkingTypes = curveMarkingTypes;
rrMap.CurveMarkings = curveMarkings;

% Barriers (fence, guard_rail, etc.)
rrMap.BarrierTypes = barrierTypes;
rrMap.Barriers = barriers;

% Signs (if any)
rrMap.SignTypes = signTypes;
rrMap.Signs = signs;
% NOTE: SignalTypes/Signals are NOT supported via RRHD import — omit them

% GeoReference — 2 elements only: [lat, lon]
rrMap.GeoReference = [geoRef(1), geoRef(2)];

% Write
if strlength(outputFile) > 0
    write(rrMap, outputFile);
end
```

## Barriers

```matlab
barrierTypes = roadrunner.hdmap.BarrierType.empty;
barriers = roadrunner.hdmap.Barrier.empty;

% Define barrier type
bt = roadrunner.hdmap.BarrierType;
bt.ID = "GuardRail";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Extrusions/GuardRail.rrext";
bt.ExtrusionPath = rap;
barrierTypes(end+1) = bt;

% Create barrier instance
b = roadrunner.hdmap.Barrier;
b.ID = "Barrier_GuardRail_1";
b.Geometry = wayGeometry;  % Nx3 polyline
typeRef = roadrunner.hdmap.Reference;
typeRef.ID = "GuardRail";
b.BarrierTypeReference = typeRef;
b.FlipLaterally = false;
barriers(end+1) = b;
```

**Barrier type mapping from Lanelet2 way types:**

| OSM way `type` | BarrierType ID | Asset Path |
|---|---|---|
| `fence` | `Fence` | `Assets/Extrusions/Fence.rrext` |
| `guard_rail` | `GuardRail` | `Assets/Extrusions/GuardRail.rrext` |
| `jersey_barrier` | `JerseyBarrier` | `Assets/Extrusions/JerseyBarrier.rrext` |
| `wall` | `Wall` | `Assets/Extrusions/HighwayBorderwall01.rrext` |
| `railing` | `Railing` | `Assets/Extrusions/BridgeRailing.rrext` |

## CurveMarkings (Stop Lines, Crosswalks)

```matlab
curveMarkingTypes = roadrunner.hdmap.CurveMarkingType.empty;
curveMarkings = roadrunner.hdmap.CurveMarking.empty;

% Define type
cmt = roadrunner.hdmap.CurveMarkingType;
cmt.ID = "StopLine";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Markings/StopLine.rrlms";
cmt.AssetPath = rap;
curveMarkingTypes(end+1) = cmt;

% Create instance
cm = roadrunner.hdmap.CurveMarking;
cm.ID = "CM_StopLine_1";
typeRef = roadrunner.hdmap.Reference;
typeRef.ID = "StopLine";
cm.MarkingTypeReference = typeRef;  % NOT CurveMarkingTypeID
cm.Geometry = wayGeometry;  % Nx3
cm.Flip = false;
cm.Reverse = false;
curveMarkings(end+1) = cm;
```

**Important:** The property is `MarkingTypeReference` (NOT `CurveMarkingTypeID`).

| OSM way `type` | CurveMarkingType ID | Asset Path |
|---|---|---|
| `stop_line` | `StopLine` | `Assets/Markings/StopLine.rrlms` |
| `pedestrian_marking` | `Crosswalk` | `Assets/Markings/SimpleCrosswalk.rrcws` |

----

Copyright 2026 The MathWorks, Inc.

----
