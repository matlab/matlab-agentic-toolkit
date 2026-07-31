# RoadRunner HD Map API Reference (Verified R2025a+)

## Namespace Loading

**REQUIRED:** Create `roadrunnerHDMap` before using any `roadrunner.hdmap.*` class:
```matlab
rrMap = roadrunnerHDMap;  % loads namespace
```

## Class Property Table

| Class | Properties |
|---|---|
| `roadrunnerHDMap` | `Lanes`, `LaneBoundaries`, `LaneMarkings`, `SpeedLimits`, `Junctions`, `GeoReference`, `SignTypes`, `Signs`, `SignalTypes`, `Signals`, `StaticObjectTypes`, `StaticObjects`, `StencilMarkingTypes`, `StencilMarkings`, `CurveMarkingTypes`, `CurveMarkings`, `LaneGroups`, `Barriers`, `BarrierTypes` |
| `Lane` | `ID`, `Geometry` (Nx3), `TravelDirection`, `LeftLaneBoundary` (AlignedRef), `RightLaneBoundary` (AlignedRef), `Predecessors` (AlignedRef[]), `Successors` (AlignedRef[]), `LaneType`, `Metadata`, `ParametricAttributes` (ParametricAttribution[]) |
| `LaneBoundary` | `ID`, `Geometry` (Nx3), `ParametricAttributes` (ParametricAttribution[]) |
| `LaneMarking` | `ID`, `AssetPath` (RelativeAssetPath) |
| `SpeedLimit` | `ID`, `Value` (int32), `VelocityUnit` (`"Kph"` or `"Mph"`) |
| `ParametricAttribution` | `Span` ([start end], 0-1), `MarkingReference`, `SpeedLimitReference`, `SignalReference` |
| `MarkingReference` | `MarkingID` (Reference), `FlipLaterally` (logical) |
| `SpeedLimitReference` | `SpeedLimitID` (Reference) |
| `SignalReference` | `SignalID` (Reference) |
| `AlignedReference` | `Reference` (Reference), `Alignment` (`"Forward"` or `"Backward"`) |
| `Reference` | `ID` (string) |
| `RelativeAssetPath` | `AssetPath` (string) |
| `Junction` | `ID`, `Geometry` (MultiPolygon), `Lanes` (Reference[]), `Configurations` (JunctionConfiguration[]) |
| `JunctionConfiguration` | `ID`, `Name`, `Phases` (Phase[]) |
| `Phase` | `ID`, `Name`, `Time` (int32 seconds), `JunctionLaneStates` (JunctionLaneState[]) |
| `JunctionLaneState` | `LaneID` (Reference), `State` (string) |
| `MultiPolygon` | `Polygons` (Polygon[]) |
| `Polygon` | `ExteriorRing` (Nx3), `InteriorRings` |
| `Sign` | `ID`, `Geometry` (GeoOrientedBoundingBox), `SignTypeReference` (Reference), `Metadata` |
| `SignType` | `ID`, `AssetPath` (RelativeAssetPath) |
| `Signal` | `ID`, `Geometry` (GeoOrientedBoundingBox), `SignalTypeReference` (Reference), `Metadata` |
| `SignalType` | `ID`, `AssetPath` (RelativeAssetPath) |
| `StaticObject` | `ID`, `Geometry` (GeoOrientedBoundingBox), `StaticObjectTypeReference` (Reference), `Metadata` |
| `StaticObjectType` | `ID`, `AssetPath` (RelativeAssetPath) |
| `StencilMarking` | `ID`, `Geometry` (GeoOrientedBoundingBox), `StencilMarkingTypeReference` (Reference), `Metadata` |
| `StencilMarkingType` | `ID`, `AssetPath` (RelativeAssetPath) |
| `CurveMarking` | `ID`, `Geometry` (Nx3), `MarkingTypeReference` (Reference), `Flip` (logical), `Reverse` (logical), `Metadata` |
| `CurveMarkingType` | `ID`, `AssetPath` (RelativeAssetPath) |
| `LaneGroup` | `ID`, `Geometry` (Nx3), `Lanes` (AlignedReference[]) |
| `Barrier` | `ID`, `Geometry` (Nx3), `BarrierTypeReference` (Reference), `FlipLaterally` (logical), `Metadata` |
| `BarrierType` | `ID`, `ExtrusionPath` (RelativeAssetPath) |
| `ParkingSpace` | `ID`, `Edges` (Reference[]), `Metadata` |
| `ParkingEdge` | `ID`, `Geometry` (Nx3), `Open` (logical — `true` = entry/exit edge), `MarkingReference` (MarkingReference) |
| `GeoOrientedBoundingBox` | `Center` ([x y z]), `Dimension` ([dx dy dz]), `GeoOrientation` ([heading pitch roll] degrees, double array — NOT a class) |
| `Metadata` | `Key`, `Value` |

## Enum Values

### TravelDirection
`"Forward"`, `"Backward"`, `"Bidirectional"`, `"Undirected"`

### LaneType
`"Driving"`, `"Shoulder"`, `"Biking"`, `"Border"`, `"Restricted"`, `"Parking"`, `"Curb"`, `"Sidewalk"`, `"CenterTurn"`

### VelocityUnit
`"Kph"`, `"Mph"`, `"Unspecified"`

### Alignment
`"Forward"`, `"Backward"`

### JunctionLaneState.State
`"GoAlways"`, `"Yield"`, `"Stop"`, `"Stop/Yield"`

## Construction Patterns

### LaneMarking
```matlab
lm = roadrunner.hdmap.LaneMarking;
lm.ID = "SolidSingleWhite";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Markings/SolidSingleWhite.rrlms";
lm.AssetPath = rap;
```

### SpeedLimit
```matlab
sl = roadrunner.hdmap.SpeedLimit;
sl.ID = "SL_50";
sl.Value = int32(50);
sl.VelocityUnit = "Kph";
```

### LaneBoundary with Marking
```matlab
lb = roadrunner.hdmap.LaneBoundary;
lb.ID = "LB_1";
lb.Geometry = [0 0 0; 50 0 0; 100 0 0];  % Nx3

pa = roadrunner.hdmap.ParametricAttribution;
pa.Span = [0 1];
ref = roadrunner.hdmap.Reference; ref.ID = "SolidSingleWhite";
mr = roadrunner.hdmap.MarkingReference;
mr.MarkingID = ref;
mr.FlipLaterally = false;
pa.MarkingReference = mr;
lb.ParametricAttributes = pa;
```

### Lane with Boundaries and Speed Limit
```matlab
ln = roadrunner.hdmap.Lane;
ln.ID = "Lane_1";
ln.Geometry = [0 2 0; 50 2 0; 100 2 0];  % center line Nx3
ln.TravelDirection = "Forward";
ln.LaneType = "Driving";

% Left boundary
arL = roadrunner.hdmap.AlignedReference;
refL = roadrunner.hdmap.Reference; refL.ID = "LB_0";
arL.Reference = refL; arL.Alignment = "Forward";
ln.LeftLaneBoundary = arL;

% Right boundary
arR = roadrunner.hdmap.AlignedReference;
refR = roadrunner.hdmap.Reference; refR.ID = "LB_1";
arR.Reference = refR; arR.Alignment = "Forward";
ln.RightLaneBoundary = arR;

% Speed limit parametric attribution
pa = roadrunner.hdmap.ParametricAttribution;
pa.Span = [0 1];
slRef = roadrunner.hdmap.SpeedLimitReference;
ref = roadrunner.hdmap.Reference; ref.ID = "SL_50";
slRef.SpeedLimitID = ref;
pa.SpeedLimitReference = slRef;
ln.ParametricAttributes = pa;

% Predecessor/Successor
ar = roadrunner.hdmap.AlignedReference;
ref = roadrunner.hdmap.Reference; ref.ID = "Lane_0";
ar.Reference = ref; ar.Alignment = "Forward";
ln.Predecessors(end+1) = ar;
```

### Sign with Geometry (GeoOrientedBoundingBox)
```matlab
% Type
st = roadrunner.hdmap.SignType;
st.ID = "StopSign";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Signs/US/Stop_US.svg_rrx";
st.AssetPath = rap;

% Instance
s = roadrunner.hdmap.Sign;
s.ID = "Sign_1";
typeRef = roadrunner.hdmap.Reference; typeRef.ID = "StopSign";
s.SignTypeReference = typeRef;
bb = roadrunner.hdmap.GeoOrientedBoundingBox;
bb.Center = [10 5 2.5];
bb.Dimension = [0 0.6 0.6];
bb.GeoOrientation = [0 0 90];  % [heading, pitch, roll] — plain double array
s.Geometry = bb;
```

### CurveMarking (stop lines, crosswalks)
```matlab
% Type
cmt = roadrunner.hdmap.CurveMarkingType;
cmt.ID = "StopLine";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Markings/StopLine.rrlms";
cmt.AssetPath = rap;

% Instance
cm = roadrunner.hdmap.CurveMarking;
cm.ID = "StopLine_1";
cm.Geometry = [0 0 0; 3.7 0 0];  % Nx3 polyline
typeRef = roadrunner.hdmap.Reference; typeRef.ID = "StopLine";
cm.MarkingTypeReference = typeRef;
cm.Flip = false;
cm.Reverse = false;
```

### Barrier
```matlab
% Type
bt = roadrunner.hdmap.BarrierType;
bt.ID = "GuardRail";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Extrusions/GuardRail.rrext";
bt.ExtrusionPath = rap;

% Instance
b = roadrunner.hdmap.Barrier;
b.ID = "Barrier_1";
b.Geometry = [0 5 0; 50 5 0; 100 5 0];  % Nx3
typeRef = roadrunner.hdmap.Reference; typeRef.ID = "GuardRail";
b.BarrierTypeReference = typeRef;
b.FlipLaterally = false;
```

### Junction with Signal Configuration
```matlab
jn = roadrunner.hdmap.Junction;
jn.ID = "Junc_1";

% Lane references
ref = roadrunner.hdmap.Reference; ref.ID = "Lane_1";
jn.Lanes(end+1) = ref;

% Polygon geometry
mp = roadrunner.hdmap.MultiPolygon;
pg = roadrunner.hdmap.Polygon;
pg.ExteriorRing = [0 0 0; 10 0 0; 10 10 0; 0 10 0; 0 0 0];
mp.Polygons(end+1) = pg;
jn.Geometry = mp;

% Configuration with phases
cfg = roadrunner.hdmap.JunctionConfiguration;
cfg.ID = "Config_1"; cfg.Name = "Main";

ph = roadrunner.hdmap.Phase;
ph.ID = "Phase_1"; ph.Name = "Green"; ph.Time = int32(30);
jls = roadrunner.hdmap.JunctionLaneState;
lRef = roadrunner.hdmap.Reference; lRef.ID = "Lane_1";
jls.LaneID = lRef; jls.State = "GoAlways";
ph.JunctionLaneStates(end+1) = jls;
cfg.Phases(end+1) = ph;

jn.Configurations(end+1) = cfg;
```

### Assembly and Write
```matlab
rrMap = roadrunnerHDMap;
rrMap.Lanes = lanes;
rrMap.LaneBoundaries = laneBoundaries;
rrMap.LaneMarkings = laneMarkings;
rrMap.SpeedLimits = speedLimits;
rrMap.Junctions = junctions;
rrMap.SignTypes = signTypes;
rrMap.Signs = signs;
% ... etc

% Set geo reference [lat, lon] — 2 elements only (altitude not supported)
rrMap.GeoReference = [42.3, -71.35];

% Write to file
write(rrMap, "output.rrhd");
```

### Read existing map
```matlab
rrMap = roadrunnerHDMap;
read(rrMap, "existing.rrhd");
% Now rrMap.Lanes, rrMap.LaneBoundaries etc. are populated
```

----

Copyright 2026 The MathWorks, Inc.
