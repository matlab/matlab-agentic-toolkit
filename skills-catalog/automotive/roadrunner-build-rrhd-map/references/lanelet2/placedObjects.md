# Placed Objects (Custom Relations)

Lanelet2 files exported from RRHD encode placed objects as custom relations.

## Relation Type Patterns

### Type Definitions (`custom:*_type`)

Relations with `type` matching `custom:{category}_type` define asset types:

| Relation type tag | Category | Fields |
|---|---|---|
| `custom:sign_type` | Sign | `custom:id`, `custom:asset_path` |
| `custom:signal_type` | Signal | `custom:id`, `custom:asset_path` |
| `custom:static_object_type` | StaticObject | `custom:id`, `custom:asset_path` |
| `custom:stencil_marking_type` | StencilMarking | `custom:id`, `custom:asset_path` |
| `custom:curve_marking_type` | CurveMarking | `custom:id`, `custom:asset_path` |

### Placed Instances (Bounding Box)

Relations with `type` matching `custom:sign`, `custom:signal`, `custom:static_object`, or `custom:stencil_marking`:

| Tag | Description |
|---|---|
| `custom:id` | Instance ID |
| `custom:type_ref` | Reference to type definition ID |
| `custom:center_x/y/z` | Position in ENU meters |
| `custom:dim_x/y/z` | Bounding box dimensions |
| `custom:rot_x/y/z` | Rotation in degrees |
| `custom:metadata` | Optional metadata string |

### CurveMarking Instances

Relations with `type=custom:curve_marking`:

| Tag | Description |
|---|---|
| `custom:id` | Instance ID |
| `custom:type_ref` | Reference to type definition ID |
| `custom:flip` | `"true"` or `"false"` |
| `custom:reverse` | `"true"` or `"false"` |
| Member with `role="geometry"` | Way reference containing polyline geometry |

### LaneGroup Definitions

Relations with `type=custom:lane_group`:

| Tag/Member | Description |
|---|---|
| `custom:id` | Group ID |
| Member with `role="geometry"`, `type="way"` | Reference line geometry |
| Members with `type="relation"`, `role="lane_{alignment}"` | Lane references with alignment suffix |

## Building RRHD Placed Objects

### SignTypes / SignalTypes / StaticObjectTypes / StencilMarkingTypes / CurveMarkingTypes

```matlab
% For each type definition:
typeObj = roadrunner.hdmap.SignType;  % (or SignalType, etc.)
typeObj.ID = typeID;
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = assetPath;
typeObj.AssetPath = rap;
```

### Sign / Signal / StaticObject / StencilMarking Instances

Type-reference property per class (verified):

| Class | Type reference property |
|---|---|
| `Sign` | `SignTypeReference` |
| `Signal` | `SignalTypeReference` |
| `StaticObject` | `ObjectTypeReference` |
| `StencilMarking` | `MarkingTypeReference` |

```matlab
% For each placed instance:
obj = roadrunner.hdmap.Sign;      % or Signal, StaticObject, StencilMarking
obj.ID = instanceID;

typeRef = roadrunner.hdmap.Reference;
typeRef.ID = typeRefID;
obj.SignTypeReference = typeRef;  % SignalTypeReference / ObjectTypeReference / MarkingTypeReference

% Geometry: GeoOrientedBoundingBox (NOT BoundingBox)
bb = roadrunner.hdmap.GeoOrientedBoundingBox;
bb.Center = center;                    % [x y z] from custom:center_x/y/z
bb.Dimension = dimension;              % half-lengths, as written by the RRHD exporter (custom:dim_x/y/z)
bb.GeoOrientation = deg2rad(rotDeg);   % custom:rot_x/y/z degrees -> [roll pitch heading] radians
obj.Geometry = bb;
```

### CurveMarking Instances

```matlab
obj = roadrunner.hdmap.CurveMarking;
obj.ID = instanceID;
typeRef = roadrunner.hdmap.Reference;
typeRef.ID = typeRefID;
obj.MarkingTypeReference = typeRef;   % NOT CurveMarkingTypeID
obj.Geometry = geometry;              % Nx3 from the way member (geomMap)
obj.Flip = logical(flip);
obj.Reverse = logical(reverse);
```

### LaneGroups

```matlab
obj = roadrunner.hdmap.LaneGroup;
obj.ID = groupID;
obj.Geometry = geometry;  % from way member

% Lane references with alignment
for k = 1:numel(laneRefs)                 % laneRefs: struct array with .laneID, .alignment (role suffix)
    ref = roadrunner.hdmap.Reference;
    ref.ID = laneRefs(k).laneID;
    obj.Lanes(end+1) = roadrunner.hdmap.AlignedReference(Reference=ref, Alignment=laneRefs(k).alignment);
end
```

## Assembly

After building all placed object arrays, assign to the map:

```matlab
rrMap.SignTypes = signTypeArray;
rrMap.Signs = signArray;
rrMap.SignalTypes = signalTypeArray;
rrMap.Signals = signalArray;
rrMap.StaticObjectTypes = staticObjTypeArray;
rrMap.StaticObjects = staticObjArray;
rrMap.StencilMarkingTypes = stencilTypeArray;
rrMap.StencilMarkings = stencilArray;
rrMap.CurveMarkingTypes = curveMarkingTypeArray;
rrMap.CurveMarkings = curveMarkingArray;
rrMap.LaneGroups = laneGroupArray;
```

----

Copyright 2026 The MathWorks, Inc.

----
