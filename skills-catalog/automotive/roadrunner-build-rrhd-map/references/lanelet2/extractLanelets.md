# Extract Lanelets

## Description
Filters relations with `type=lanelet` from parsed Lanelet2 data. Extracts center/left/right boundary way IDs, subtype, one-way flag, speed limit, location, and participant types.

## Inputs
| Parameter | Type | Description |
|-----------|------|-------------|
| `ll2` | struct | Parsed Lanelet2 data from `readOSM` |

## Output
`lanelets` — struct array, each with:
| Field | Type | Description |
|-------|------|-------------|
| `.id` | string | Relation ID |
| `.centerWayID` | string | Center way ID |
| `.leftWayID` | string | Left boundary way ID |
| `.rightWayID` | string | Right boundary way ID |
| `.subtype` | string | e.g. `"road"`, `"highway"`, `"crosswalk"` |
| `.oneWay` | logical | `false` only if `one_way=no` — Lanelet2 default for vehicle lanelets is `yes` |
| `.speedLimit` | double | Speed limit value (NaN if not set) |
| `.location` | string | e.g. `"urban"` |
| `.participants` | string array | e.g. `["vehicle"]` |
| `.tags` | containers.Map | All raw tags |

## Validated Implementation Pattern
```matlab
keys = relations.keys;
lanelets = struct('id',{},'centerWayID',{},'leftWayID',{},'rightWayID',{}, ...
    'subtype',{},'oneWay',{},'speedLimit',{},'tags',{});
for i = 1:numel(keys)
    rel = relations(keys{i});
    if ~rel.tags.isKey('type') || ~strcmp(rel.tags('type'), 'lanelet')
        continue
    end
    ll = struct('id', string(keys{i}), 'centerWayID', "", 'leftWayID', "", 'rightWayID', "", ...
        'subtype', "road", 'oneWay', true, 'speedLimit', NaN, 'tags', rel.tags);   % fresh struct every iteration
    for m = 1:numel(rel.members)
        switch rel.members(m).role
            case {"centerline", "center"}, ll.centerWayID = rel.members(m).ref;
            case "left",   ll.leftWayID   = rel.members(m).ref;
            case "right",  ll.rightWayID  = rel.members(m).ref;
        end
    end
    ll.subtype = "road";
    if rel.tags.isKey('subtype'), ll.subtype = string(rel.tags('subtype')); end
    ll.oneWay = true;
    if rel.tags.isKey('one_way'), ll.oneWay = strcmp(rel.tags('one_way'),'yes'); end
    ll.speedLimit = NaN;
    if rel.tags.isKey('speed_limit')
        ll.speedLimit = str2double(regexp(rel.tags('speed_limit'), '^\s*([\d.]+)', 'tokens', 'once'));  % "100.000000 km/h" -> 100
    end
    lanelets(end+1) = ll; %#ok<AGROW>
end
```

> **Note:** Filter by `type=lanelet` only. Other relation types (regulatory_element, etc.)
> are not lanelets and should be skipped. Speed limit `0` means "no limit" — treat as NaN.

## Example
```matlab
fprintf("Found %d lanelets\n", numel(lanelets));
```

----

Copyright 2026 The MathWorks, Inc.

----
