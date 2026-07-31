# Extracting Non-Lane Elements — Discovery-Based Approach

All code below is **tested and verified on R2026a**. Execute verbatim in script context.

## Design Principle: Discover Everything, Map What's Possible

**Do NOT use a whitelist.** Instead:
1. Scan ALL ways and ALL relations
2. Categorize every element by its `type` (and `subtype` if present)
3. Map each category to the appropriate RRHD object
4. Report unmapped categories to the user (never silently drop)

## Step 3b: Discover ALL Way Types

```matlab
% Discover ALL way types — MANDATORY
% Categorize into buckets by function
stopLineWays = {};
pedestrianMarkingWays = {};
zebraMarkingWays = {};
bikeMarkingWays = {};
zigzagWays = {};
fenceWays = {};
guardRailWays = {};
jerseyBarrierWays = {};
wallWays = {};
curbstoneWays = {};
trafficSignWays = {};
trafficLightWays = {};
unmappedWays = containers.Map;  % type → count

wayKeys = ways.keys;
for i = 1:numel(wayKeys)
    w = ways(wayKeys{i});
    if ~w.tags.isKey('type'), continue; end
    wType = w.tags('type');

    % Split compound types like "traffic_sign/de205" or "curbstone/high"
    typeParts = strsplit(wType, '/');
    baseType = typeParts{1};

    switch baseType
        case 'stop_line'
            stopLineWays{end+1} = w;
        case 'pedestrian_marking'
            pedestrianMarkingWays{end+1} = w;
        case 'zebra_marking'
            zebraMarkingWays{end+1} = w;
        case 'bike_marking'
            bikeMarkingWays{end+1} = w;
        case {'zig-zag', 'zig_zag'}
            zigzagWays{end+1} = w;
        case 'fence'
            fenceWays{end+1} = w;
        case 'guard_rail'
            guardRailWays{end+1} = w;
        case 'jersey_barrier'
            jerseyBarrierWays{end+1} = w;
        case 'wall'
            wallWays{end+1} = w;
        case 'curbstone'
            curbstoneWays{end+1} = w;
        case 'traffic_sign'
            trafficSignWays{end+1} = w;
        case 'traffic_light'
            trafficLightWays{end+1} = w;
        case {'line_thin', 'line_thick', 'virtual', 'road_border', 'rail', 'keepout', 'symbol'}
            % These are boundary lines or lane-related — handled via lanelet extraction
            % No action needed
        otherwise
            if unmappedWays.isKey(wType)
                unmappedWays(wType) = unmappedWays(wType) + 1;
            else
                unmappedWays(wType) = 1;
            end
    end
end

fprintf('=== Way Discovery ===\n');
fprintf('CurveMarkings: %d stop_lines, %d ped_markings, %d zebra, %d bike, %d zig-zag\n', ...
    numel(stopLineWays), numel(pedestrianMarkingWays), numel(zebraMarkingWays), ...
    numel(bikeMarkingWays), numel(zigzagWays));
fprintf('Barriers: %d fences, %d guard_rails, %d jersey_barriers, %d walls, %d curbstones\n', ...
    numel(fenceWays), numel(guardRailWays), numel(jerseyBarrierWays), ...
    numel(wallWays), numel(curbstoneWays));
fprintf('Signs: %d traffic_sign ways, %d traffic_light ways\n', ...
    numel(trafficSignWays), numel(trafficLightWays));

if unmappedWays.Count > 0
    fprintf('UNMAPPED way types:\n');
    umKeys = unmappedWays.keys;
    for i = 1:numel(umKeys)
        fprintf('  %s: %d\n', umKeys{i}, unmappedWays(umKeys{i}));
    end
end
```

## Step 3c: Discover ALL Relation Types (beyond lanelets)

```matlab
% Discover ALL non-lanelet relations — MANDATORY
trafficSignRels = {};
speedLimitRels = {};
rightOfWayRels = {};
trafficLightRels = {};
multipolygonRels = struct('building', {{}}, 'parking', {{}}, 'vegetation', {{}}, ...
    'traffic_island', {{}}, 'walkway', {{}}, 'exit', {{}}, 'keepout', {{}});
unmappedRels = containers.Map;

relKeys = relations.keys;
for i = 1:numel(relKeys)
    rel = relations(relKeys{i});
    if ~rel.tags.isKey('type'), continue; end
    relType = rel.tags('type');

    if strcmp(relType, 'lanelet')
        continue;  % Already handled
    end

    relSubtype = '';
    if rel.tags.isKey('subtype')
        relSubtype = rel.tags('subtype');
    end

    if strcmp(relType, 'regulatory_element')
        switch relSubtype
            case 'traffic_sign'
                trafficSignRels{end+1} = rel;
            case 'speed_limit'
                speedLimitRels{end+1} = rel;
            case 'right_of_way'
                rightOfWayRels{end+1} = rel;
            case 'traffic_light'
                trafficLightRels{end+1} = rel;
            otherwise
                key = ['regulatory_element/', relSubtype];
                if unmappedRels.isKey(key)
                    unmappedRels(key) = unmappedRels(key) + 1;
                else
                    unmappedRels(key) = 1;
                end
        end
    elseif strcmp(relType, 'multipolygon')
        switch relSubtype
            case 'building'
                multipolygonRels.building{end+1} = rel;
            case 'parking'
                multipolygonRels.parking{end+1} = rel;
            case 'vegetation'
                multipolygonRels.vegetation{end+1} = rel;
            case 'traffic_island'
                multipolygonRels.traffic_island{end+1} = rel;
            case 'walkway'
                multipolygonRels.walkway{end+1} = rel;
            case 'exit'
                multipolygonRels.exit{end+1} = rel;
            case 'keepout'
                multipolygonRels.keepout{end+1} = rel;
            otherwise
                key = ['multipolygon/', relSubtype];
                if unmappedRels.isKey(key)
                    unmappedRels(key) = unmappedRels(key) + 1;
                else
                    unmappedRels(key) = 1;
                end
        end
    else
        if unmappedRels.isKey(relType)
            unmappedRels(relType) = unmappedRels(relType) + 1;
        else
            unmappedRels(relType) = 1;
        end
    end
end

fprintf('\n=== Relation Discovery ===\n');
fprintf('Regulatory: %d traffic_sign, %d speed_limit, %d right_of_way, %d traffic_light\n', ...
    numel(trafficSignRels), numel(speedLimitRels), numel(rightOfWayRels), numel(trafficLightRels));
fprintf('Multipolygons: %d building, %d parking, %d vegetation, %d traffic_island, %d walkway\n', ...
    numel(multipolygonRels.building), numel(multipolygonRels.parking), ...
    numel(multipolygonRels.vegetation), numel(multipolygonRels.traffic_island), ...
    numel(multipolygonRels.walkway));

if unmappedRels.Count > 0
    fprintf('UNMAPPED relation types:\n');
    umKeys = unmappedRels.keys;
    for i = 1:numel(umKeys)
        fprintf('  %s: %d\n', umKeys{i}, unmappedRels(umKeys{i}));
    end
end
```

## Build CurveMarkings (ALL types)

**WARNING — Extension matters:** Stop lines use `.rrlms` (lane marking style), NOT `.rrcws` (crosswalk style). Only crosswalks use `.rrcws`. Using the wrong extension causes "Asset file is missing" errors on import.

```matlab
% --- CurveMarkingTypes (expanded) ---
curveMarkingTypes = roadrunner.hdmap.CurveMarkingType.empty;

cmtDefs = { ...
    'StopLine',          'Assets/Markings/StopLine.rrlms'; ...
    'SimpleCrosswalk',   'Assets/Markings/SimpleCrosswalk.rrcws'; ...
    'ZebraCrosswalk',    'Assets/Markings/ContinentalCrosswalk.rrcws'; ...
    'BikeMarking',       'Assets/Markings/DashedSingleWhite.rrlms'; ...
    'ZigZag',            'Assets/Markings/DashedSingleWhite.rrlms'};

for d = 1:size(cmtDefs,1)
    cmt = roadrunner.hdmap.CurveMarkingType;
    cmt.ID = cmtDefs{d,1};
    cmt.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=cmtDefs{d,2});
    curveMarkingTypes(end+1) = cmt;
end

% --- Build CurveMarkings from ALL way types ---
curveMarkings = roadrunner.hdmap.CurveMarking.empty;
cmCount = 0;

% Helper: build CurveMarkings from a way list
% wayList: cell array of way structs
% typeID: string — CurveMarkingType ID to reference
allCMWays = { ...
    stopLineWays,          'StopLine'; ...
    pedestrianMarkingWays, 'SimpleCrosswalk'; ...
    zebraMarkingWays,      'ZebraCrosswalk'; ...
    bikeMarkingWays,       'BikeMarking'; ...
    zigzagWays,            'ZigZag'};

for c = 1:size(allCMWays, 1)
    wayList = allCMWays{c,1};
    typeID = allCMWays{c,2};
    for i = 1:numel(wayList)
        w = wayList{i};
        geom = zeros(numel(w.nodeRefs), 3);
        for n = 1:numel(w.nodeRefs)
            nd = nodes(w.nodeRefs{n});
            geom(n,:) = [nd.x, nd.y, nd.z];
        end
        cmCount = cmCount + 1;
        cm = roadrunner.hdmap.CurveMarking;
        cm.ID = sprintf("CM_%s_%d", typeID, cmCount);
        cm.Geometry = geom;
        typeRef = roadrunner.hdmap.Reference;
        typeRef.ID = typeID;
        cm.MarkingTypeReference = typeRef;
        cm.Flip = false;
        cm.Reverse = false;
        curveMarkings(end+1) = cm;
    end
end

% Crosswalk lanelets
for i = 1:numel(crosswalkLanelets)
    cmCount = cmCount + 1;
    cm = roadrunner.hdmap.CurveMarking;
    cm.ID = sprintf("CM_LaneletCW_%d", cmCount);
    cm.Geometry = crosswalkLanelets(i).centerGeom;
    typeRef = roadrunner.hdmap.Reference;
    typeRef.ID = "SimpleCrosswalk";
    cm.MarkingTypeReference = typeRef;
    cm.Flip = false;
    cm.Reverse = false;
    curveMarkings(end+1) = cm;
end

fprintf('CurveMarkings: %d total\n', numel(curveMarkings));
```

## Build Barriers (ALL types including curbstones)

```matlab
% --- BarrierTypes (expanded with curbstone) ---
barrierTypes = roadrunner.hdmap.BarrierType.empty;
barrierTypeMap = containers.Map;

barrierDefs = { ...
    'fence',          'Fence',          'Assets/Extrusions/Fence.rrext.rrmeta'; ...
    'guard_rail',     'GuardRail',      'Assets/Extrusions/GuardRail.rrext.rrmeta'; ...
    'jersey_barrier', 'JerseyBarrier',  'Assets/Extrusions/JerseyBarrier.rrext.rrmeta'; ...
    'wall',           'ConcreteWall',   'Assets/Extrusions/ConcreteWall.rrext.rrmeta'; ...
    'curbstone',      'Curb',           'Assets/Extrusions/Curb.rrext.rrmeta'};

for d = 1:size(barrierDefs,1)
    osmType = barrierDefs{d,1};
    btID = barrierDefs{d,2};
    assetPath = barrierDefs{d,3};
    barrierTypeMap(osmType) = btID;
    bt = roadrunner.hdmap.BarrierType;
    bt.ID = btID;
    bt.ExtrusionPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=assetPath);
    barrierTypes(end+1) = bt;
end

% --- Barrier instances (ALL types) ---
barriers = roadrunner.hdmap.Barrier.empty;
allBarrierWays = [fenceWays, guardRailWays, jerseyBarrierWays, wallWays, curbstoneWays];
bCount = 0;

for i = 1:numel(allBarrierWays)
    w = allBarrierWays{i};
    wType = w.tags('type');
    % Extract base type (e.g., "curbstone/high" → "curbstone")
    typeParts = strsplit(wType, '/');
    baseType = typeParts{1};

    if ~barrierTypeMap.isKey(baseType), continue; end

    geom = zeros(numel(w.nodeRefs), 3);
    for n = 1:numel(w.nodeRefs)
        nd = nodes(w.nodeRefs{n});
        geom(n,:) = [nd.x, nd.y, nd.z];
    end
    bCount = bCount + 1;
    b = roadrunner.hdmap.Barrier;
    b.ID = sprintf("Barrier_%s_%d", barrierTypeMap(baseType), bCount);
    b.Geometry = geom;
    typeRef = roadrunner.hdmap.Reference;
    typeRef.ID = barrierTypeMap(baseType);
    b.BarrierTypeReference = typeRef;
    b.FlipLaterally = false;
    barriers(end+1) = b;
end

fprintf('Barriers: %d instances, %d types\n', numel(barriers), numel(barrierTypes));
```

## Build Speed Limits (from regulatory_element/speed_limit relations)

```matlab
% Extract speed limits from regulatory_element relations
speedLimitValues = [];

% From lanelet tags
for i = 1:numel(lanelets)
    if lanelets(i).tags.isKey('speed_limit')
        slVal = str2double(lanelets(i).tags('speed_limit'));
        if ~isnan(slVal) && ~ismember(slVal, speedLimitValues)
            speedLimitValues(end+1) = slVal;
        end
    end
end

% From speed_limit regulatory elements (extract the value from refers way tags)
for i = 1:numel(speedLimitRels)
    rel = speedLimitRels{i};
    % Check relation tags for speed value
    if rel.tags.isKey('speed_limit')
        slVal = str2double(rel.tags('speed_limit'));
        if ~isnan(slVal) && ~ismember(slVal, speedLimitValues)
            speedLimitValues(end+1) = slVal;
        end
    end
    % Also check sign_type tag pattern "de274-30" → 30 km/h
    if rel.tags.isKey('sign_type')
        nums = regexp(rel.tags('sign_type'), '\d+', 'match');
        if ~isempty(nums)
            slVal = str2double(nums{end});  % last number is usually the speed
            if ~isnan(slVal) && slVal > 0 && slVal < 300 && ~ismember(slVal, speedLimitValues)
                speedLimitValues(end+1) = slVal;
            end
        end
    end
end

speedLimits = roadrunner.hdmap.SpeedLimit.empty;
for i = 1:numel(speedLimitValues)
    sl = roadrunner.hdmap.SpeedLimit;
    sl.ID = sprintf("SL_%d", speedLimitValues(i));
    sl.Value = int32(speedLimitValues(i));
    sl.VelocityUnit = "Kph";
    speedLimits(end+1) = sl;
end
fprintf('SpeedLimits: %d unique values\n', numel(speedLimits));
```

## Build Signs (from BOTH regulatory_element relations AND traffic_sign ways)

```matlab
% --- Region detection ---
lat = geoRef(1); lon = geoRef(2);
if lat >= 24 && lat <= 46 && lon >= 122 && lon <= 154
    region = "Japan";
elseif lat >= 35 && lat <= 72 && lon >= -10 && lon <= 25
    region = "Germany";
else
    region = "US";
end

% --- Sign asset resolution (CRITICAL: use .svg_rrx extension, descriptive names) ---
% See roadrunner-asset-mapping skill's references/signs.md for full lookup table.
% Sign assets use descriptive English names: <Description>_<Region>.svg_rrx
signAssetMap = containers.Map;
switch region
    case "Japan"
        signAssetMap('stop_sign') = "Assets/Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx";
        signAssetMap('stop') = "Assets/Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx";
        signAssetMap('no_entry') = "Assets/Signs/Japan/Regulatory Signs/NoEntryForVehicles_JP.svg_rrx";
        signAssetMap('no_parking') = "Assets/Signs/Japan/Regulatory Signs/NoParking_JP.svg_rrx";
        signAssetMap('no_stopping') = "Assets/Signs/Japan/Regulatory Signs/NoStopping_JP.svg_rrx";
        signAssetMap('one_way') = "Assets/Signs/Japan/Regulatory Signs/OneWay_JP_01.svg_rrx";
        signAssetMap('no_overtaking') = "Assets/Signs/Japan/Regulatory Signs/NoOvertaking_JP.svg_rrx";
        signAssetMap('no_u_turn') = "Assets/Signs/Japan/Regulatory Signs/NoUTurns_JP.svg_rrx";
        signAssetMap('default') = "Assets/Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx";
    case "Germany"
        signAssetMap('stop_sign') = "Assets/Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx";
        signAssetMap('stop') = "Assets/Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx";
        signAssetMap('de205') = "Assets/Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx";
        signAssetMap('de206') = "Assets/Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx";
        signAssetMap('default') = "Assets/Signs/Germany/Warning Signs/Danger_DE.svg_rrx";
    otherwise
        signAssetMap('stop_sign') = "Assets/Signs/US/Stop_US.svg_rrx";
        signAssetMap('stop') = "Assets/Signs/US/Stop_US.svg_rrx";
        signAssetMap('yield') = "Assets/Signs/US/Yield_US.svg_rrx";
        signAssetMap('no_u_turn') = "Assets/Signs/US/NoUTurns_US.svg_rrx";
        signAssetMap('default') = "Assets/Signs/US/White_Blank_US.svg_rrx";
end

% --- Build Signs from traffic_sign WAYS (direct geometry) ---
signTypes = roadrunner.hdmap.SignType.empty;
signs = roadrunner.hdmap.Sign.empty;
createdSignTypes = containers.Map;
sgnCount = 0;

for i = 1:numel(trafficSignWays)
    w = trafficSignWays{i};
    wType = w.tags('type');  % e.g., "traffic_sign/de205"
    typeParts = strsplit(wType, '/');
    signCode = 'default';
    if numel(typeParts) > 1
        signCode = typeParts{2};
    end

    % Resolve asset path
    if signAssetMap.isKey(signCode)
        assetPath = signAssetMap(signCode);
    elseif contains(signCode, 'speed') || contains(signCode, '274')
        % Speed limit sign — extract numeric value
        nums = regexp(signCode, '\d+', 'match');
        if numel(nums) > 1
            N = nums{end};  % last number is speed value
        elseif numel(nums) == 1
            N = nums{1};
        else
            N = '30';
        end
        switch region
            case "Japan"
                assetPath = sprintf("Assets/Signs/Japan/Regulatory Signs/MaxSpeedLimit_%s_JP.svg_rrx", N);
            case "Germany"
                assetPath = sprintf("Assets/Signs/Germany/Regulatory Signs/MaxSpeedLimit_%s_DE.svg_rrx", N);
            otherwise
                assetPath = sprintf("Assets/Signs/US/Regulatory Signs/MaxSpeedLimit_%s_US.svg_rrx", N);
        end
    else
        assetPath = signAssetMap('default');
    end

    % Create SignType
    typeID = sprintf("SignType_%s", signCode);
    if ~createdSignTypes.isKey(char(typeID))
        st = roadrunner.hdmap.SignType;
        st.ID = typeID;
        st.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=assetPath);
        signTypes(end+1) = st;
        createdSignTypes(char(typeID)) = true;
    end

    % Build geometry from way nodes
    geom = zeros(numel(w.nodeRefs), 3);
    for n = 1:numel(w.nodeRefs)
        nd = nodes(w.nodeRefs{n});
        geom(n,:) = [nd.x, nd.y, nd.z];
    end
    center = mean(geom, 1);
    dir = geom(end,:) - geom(1,:);
    heading = atan2d(dir(2), dir(1));

    % Create Sign
    sgnCount = sgnCount + 1;
    sgn = roadrunner.hdmap.Sign;
    sgn.ID = sprintf("Sign_%d", sgnCount);
    bbox = roadrunner.hdmap.GeoOrientedBoundingBox;
    bbox.Center = center;
    bbox.Dimension = [0.8, 0.8, 0.05];
    bbox.GeoOrientation = [heading, 0, 0];
    sgn.Geometry = bbox;
    typeRef = roadrunner.hdmap.Reference;
    typeRef.ID = typeID;
    sgn.SignTypeReference = typeRef;
    signs(end+1) = sgn;
end

% --- Also build Signs from regulatory_element/traffic_sign relations ---
for i = 1:numel(trafficSignRels)
    rel = trafficSignRels{i};
    refersWayID = "";
    for m = 1:numel(rel.members)
        if strcmp(rel.members(m).role, 'refers') && strcmp(rel.members(m).type, 'way')
            refersWayID = rel.members(m).ref;
            break;
        end
    end
    if strlength(refersWayID) == 0 || ~ways.isKey(refersWayID), continue; end

    refWay = ways(refersWayID);
    signSubtype = "default";
    if refWay.tags.isKey('subtype')
        signSubtype = string(refWay.tags('subtype'));
    end

    if signAssetMap.isKey(char(signSubtype))
        assetPath = signAssetMap(char(signSubtype));
    else
        assetPath = signAssetMap('default');
    end

    typeID = sprintf("SignType_%s", signSubtype);
    if ~createdSignTypes.isKey(char(typeID))
        st = roadrunner.hdmap.SignType;
        st.ID = typeID;
        st.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=assetPath);
        signTypes(end+1) = st;
        createdSignTypes(char(typeID)) = true;
    end

    geom = zeros(numel(refWay.nodeRefs), 3);
    for n = 1:numel(refWay.nodeRefs)
        nd = nodes(refWay.nodeRefs{n});
        geom(n,:) = [nd.x, nd.y, nd.z];
    end
    center = mean(geom, 1);
    dir = geom(end,:) - geom(1,:);
    heading = atan2d(dir(2), dir(1));

    sgnCount = sgnCount + 1;
    sgn = roadrunner.hdmap.Sign;
    sgn.ID = sprintf("Sign_%d", sgnCount);
    bbox = roadrunner.hdmap.GeoOrientedBoundingBox;
    bbox.Center = center;
    bbox.Dimension = [0.8, 0.8, 0.05];
    bbox.GeoOrientation = [heading, 0, 0];
    sgn.Geometry = bbox;
    typeRef = roadrunner.hdmap.Reference;
    typeRef.ID = typeID;
    sgn.SignTypeReference = typeRef;
    signs(end+1) = sgn;
end

fprintf('Signs: %d instances, %d types (region: %s)\n', numel(signs), numel(signTypes), region);
```

## Build LaneMarkings

```matlab
markingDefs = { ...
    'solid',         'SolidSingleWhite',    'Assets/Markings/SolidSingleWhite.rrlms'; ...
    'dashed',        'DashedSingleWhite',   'Assets/Markings/DashedSingleWhite.rrlms'; ...
    'solid_solid',   'SolidDoubleYellow',   'Assets/Markings/SolidDoubleYellow.rrlms'; ...
    'dashed_solid',  'DashedSolidYellow',   'Assets/Markings/DashedSolidYellow.rrlms'; ...
    'solid_dashed',  'SolidDashedYellow',   'Assets/Markings/SolidDashedYellow.rrlms'};

laneMarkings = roadrunner.hdmap.LaneMarking.empty;
for d = 1:size(markingDefs,1)
    lm = roadrunner.hdmap.LaneMarking;
    lm.ID = markingDefs{d,2};
    lm.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=markingDefs{d,3});
    laneMarkings(end+1) = lm;
end
```

## RRHD Limitations — Elements That Cannot Be Mapped

Report these to the user; do NOT silently drop:

| Lanelet2 Element | Reason Not Mapped |
|---|---|
| `multipolygon/building` | RRHD has no Building object type. Would need StaticObject + specific 3D asset. |
| `multipolygon/vegetation` | RRHD has no vegetation polygon. Would need StaticObject per tree/bush. |
| `multipolygon/traffic_island` | Could be represented as Junction or keep-out zone, but no standard mapping. |
| `regulatory_element/traffic_light` | RoadRunner does NOT support signal import via RRHD. |
| `regulatory_element/right_of_way` | No RRHD equivalent — right-of-way is implicit in junction configuration. |

Always print a summary of unmapped elements so the user is aware:
```matlab
fprintf('\n=== UNMAPPED ELEMENTS (no RRHD equivalent) ===\n');
fprintf('Buildings: %d (no RRHD Building type)\n', numel(multipolygonRels.building));
fprintf('Vegetation: %d (no RRHD vegetation polygon)\n', numel(multipolygonRels.vegetation));
fprintf('Traffic islands: %d (no standard mapping)\n', numel(multipolygonRels.traffic_island));
fprintf('Traffic lights: %d (RRHD does not support signal import)\n', numel(trafficLightRels));
fprintf('Right-of-way: %d (no RRHD equivalent)\n', numel(rightOfWayRels));
```

----

Copyright 2026 The MathWorks, Inc.
