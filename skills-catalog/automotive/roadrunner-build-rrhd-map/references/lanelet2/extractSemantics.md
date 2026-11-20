# Extract Semantics

## Description
Extracts semantic information from Lanelet2 data and maps it to RRHD equivalents:
- **Lane markings:** Maps linestring `type`/`subtype` tags (e.g. `line_thin`/`solid`) to RRHD marking asset paths
- **Speed limits:** Collects unique speed limit values and groups lanelets by value
- **Lane types:** Maps lanelet `subtype` (road, highway, crosswalk, etc.) to RRHD `LaneType`

### Linestring Type Mapping
Colour comes from the way's `color` tag when present; otherwise from `region` ([coordinates.md](coordinates.md)): double and dashed-solid lines are **yellow in the US**, **white elsewhere** (German StVO and Japanese centre lines are white). Single lines are white unless tagged yellow.

| Lanelet2 subtype | White (default outside US) | Yellow (US default, or `color=yellow`) |
|---|---|---|
| `solid` | `SolidSingleWhite.rrlms` | `SolidSingleYellow.rrlms` |
| `dashed` | `DashedSingleWhite.rrlms` | `DashedSingleYellow.rrlms` |
| `solid_solid` | `SolidDoubleWhite.rrlms` | `SolidDoubleYellow.rrlms` |
| `dashed_solid` | `DashedSolidWhite.rrlms` | `DashedSolidYellow.rrlms` |
| `solid_dashed` | `DashedSolidWhite.rrlms` (+ `FlipLaterally=true`) | `DashedSolidYellow.rrlms` (+ `FlipLaterally=true`) |

## Inputs
| Parameter | Type | Description |
|-----------|------|-------------|
| `lanelets` | struct array | From `extractLanelets` |
| `region` | string | `"Japan"`/`"Germany"`/`"US"` from [coordinates.md](coordinates.md) |
| `ll2` | struct | Parsed Lanelet2 data from `readOSM` |

## Output
`sem` — struct with:
| Field | Type | Description |
|-------|------|-------------|
| `.markingMap` | containers.Map | wayID -> struct(type, subtype, rrhdAsset, rrhdMarkingID) |
| `.speedLimits` | struct array | Each with `.value` (double), `.laneletIDs` (string array) |
| `.laneTypeMap` | containers.Map | laneletID -> RRHD lane type string |

## Validated Implementation Pattern
```matlab
% Marking lookup: way subtype + colour -> RRHD asset/ID (colour: `color` tag, else region default)
markingStyle = containers.Map( ...
    {'solid','dashed','solid_solid','dashed_solid','solid_dashed'}, ...
    {{'SolidSingle', false, false}, {'DashedSingle', false, false}, {'SolidDouble', true, false}, ...
     {'DashedSolid', true, false}, {'DashedSolid', true, true}});   % {base, isDoubleLine, flip}

sem.markingMap = containers.Map('KeyType','char','ValueType','any');
sem.markingDefs = containers.Map('KeyType','char','ValueType','any');
wayKeys = ways.keys;
for i = 1:numel(wayKeys)
    w = ways(wayKeys{i});
    if ~w.tags.isKey('subtype') || ~markingStyle.isKey(w.tags('subtype')), continue; end
    st = markingStyle(w.tags('subtype'));
    if w.tags.isKey('color')
        isYellow = strcmpi(w.tags('color'), 'yellow');
    else
        isYellow = st{2} && region == "US";
    end
    colour = 'White'; if isYellow, colour = 'Yellow'; end
    info = struct('asset', ['Assets/Markings/' st{1} colour '.rrlms'], 'id', [st{1} colour], 'flip', st{3});
    sem.markingMap(wayKeys{i}) = info;
    sem.markingDefs(info.id) = info;  % unique marking definitions
end

% Lane type mapping
ltLookup = containers.Map( ...
    {'road','highway','parking','bicycle_lane','emergency_lane','bus_lane'}, ...
    {'Driving','Driving','Parking','Biking','Shoulder','Driving'});
% NOTE: 'crosswalk' and 'walkway' subtypes are NOT lanes — they become CurveMarkings (Step 8b)

% Participant tags take precedence over subtype (Lanelet2 participant:* overrides the subtype default).
% e.g. an urban map: subtype=road with participant:vehicle=no, participant:bicycle=yes -> Biking.
isTag = @(t, k, v) t.isKey(k) && strcmp(t(k), v);
sem.laneTypeMap = containers.Map('KeyType','char','ValueType','char');
for i = 1:numel(lanelets)
    t = lanelets(i).tags;
    st = char(lanelets(i).subtype);
    if isTag(t, 'participant:vehicle', 'no') && isTag(t, 'participant:bicycle', 'yes')
        lt = 'Biking';
    elseif isTag(t, 'participant:vehicle', 'no') && isTag(t, 'participant:pedestrian', 'yes')
        lt = 'Sidewalk';
    elseif ltLookup.isKey(st)
        lt = ltLookup(st);
    else
        lt = 'Driving';
    end
    sem.laneTypeMap(char(lanelets(i).id)) = lt;
end
```

> **Note:** Ways without `type`/`subtype` tags have no lane markings — their boundaries
> should get no `ParametricAttributes` (unmarked/virtual boundaries).

## Example
```matlab
info = sem.markingMap('70');  % Get marking info for way ID "70"
```

----

Copyright 2026 The MathWorks, Inc.

----
