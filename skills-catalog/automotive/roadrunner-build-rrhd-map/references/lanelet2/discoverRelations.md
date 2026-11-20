# Discover ALL Relation Types (Step 3c)

Run in the same script as Steps 3a and 3b. Each collected relation gains `.relID` (char). Subtypes are normalized (`traffic-island` → `traffic_island`).

```matlab
trafficSignRels = {}; speedLimitRels = {}; rightOfWayRels = {}; trafficLightRels = {};
multipolygonRels = struct('building',{{}},'parking',{{}},'vegetation',{{}},...
    'traffic_island',{{}},'walkway',{{}},'exit',{{}},'keepout',{{}});
unmappedRels = containers.Map;

relKeys = relations.keys;
for i = 1:numel(relKeys)
    rel = relations(relKeys{i});
    rel.relID = relKeys{i};
    if ~rel.tags.isKey('type'), continue; end
    relType = rel.tags('type');
    if strcmp(relType,'lanelet'), continue; end
    relSubtype = '';
    if rel.tags.isKey('subtype'), relSubtype = strrep(rel.tags('subtype'), '-', '_'); end
    if strcmp(relType,'regulatory_element')
        switch relSubtype
            case 'traffic_sign', trafficSignRels{end+1} = rel;
            case 'speed_limit', speedLimitRels{end+1} = rel;
            case 'right_of_way', rightOfWayRels{end+1} = rel;
            case 'traffic_light', trafficLightRels{end+1} = rel;
            otherwise
                key = ['regulatory_element/' relSubtype];
                if unmappedRels.isKey(key), unmappedRels(key)=unmappedRels(key)+1;
                else, unmappedRels(key)=1; end
        end
    elseif strcmp(relType,'multipolygon')
        switch relSubtype
            case 'building', multipolygonRels.building{end+1} = rel;
            case 'parking', multipolygonRels.parking{end+1} = rel;
            case 'vegetation', multipolygonRels.vegetation{end+1} = rel;
            case 'traffic_island', multipolygonRels.traffic_island{end+1} = rel;
            case 'walkway', multipolygonRels.walkway{end+1} = rel;
            case 'exit', multipolygonRels.exit{end+1} = rel;
            case 'keepout', multipolygonRels.keepout{end+1} = rel;
            otherwise
                key = ['multipolygon/' relSubtype];
                if unmappedRels.isKey(key), unmappedRels(key)=unmappedRels(key)+1;
                else, unmappedRels(key)=1; end
        end
    else
        if unmappedRels.isKey(relType), unmappedRels(relType)=unmappedRels(relType)+1;
        else, unmappedRels(relType)=1; end
    end
end
```

**Print discovery summary and unmapped elements.** Never silently drop anything.

----

Copyright 2026 The MathWorks, Inc.

----
