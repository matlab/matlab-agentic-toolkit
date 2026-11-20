# Parse OSM

## Description
Parses a Lanelet2 `.osm` file into a structured MATLAB representation. Extracts all nodes (with lat, lon, ele, local_x, local_y), ways (with node references and tags), and relations (with members and tags).

## Inputs
| Parameter | Type | Description |
|-----------|------|-------------|
| `osmFile` | string | Path to a Lanelet2 `.osm` file |

## Output
`ll2` — struct with:
| Field | Type | Description |
|-------|------|-------------|
| `.nodes` | containers.Map | nodeID -> struct(lat, lon, ele, local_x, local_y) |
| `.ways` | containers.Map | wayID -> struct(nodeRefs, tags) |
| `.relations` | containers.Map | relID -> struct(members, tags) |
| `.sourceFile` | string | Input file path |

## Validated Implementation Pattern
Use `xmlread` (Java DOM parser) — works for files up to ~10MB:

```matlab
doc = xmlread(osmFile);

% Nodes
nodeElems = doc.getElementsByTagName('node');
nodes = containers.Map('KeyType','char','ValueType','any');
for i = 0:nodeElems.getLength()-1
    elem = nodeElems.item(i);
    nid = char(elem.getAttribute('id'));
    s.lat = str2double(elem.getAttribute('lat'));
    s.lon = str2double(elem.getAttribute('lon'));
    s.ele = 0; s.local_x = NaN; s.local_y = NaN;
    tags = elem.getElementsByTagName('tag');
    for t = 0:tags.getLength()-1
        tag = tags.item(t);
        k = char(tag.getAttribute('k'));
        v = str2double(tag.getAttribute('v'));
        switch k
            case 'ele',     s.ele = v;
            case 'local_x', s.local_x = v;
            case 'local_y', s.local_y = v;
        end
    end
    nodes(nid) = s;
end

% Ways — nodeRefs as string array, tags as containers.Map
wayElems = doc.getElementsByTagName('way');
ways = containers.Map('KeyType','char','ValueType','any');
for i = 0:wayElems.getLength()-1
    elem = wayElems.item(i);
    wid = char(elem.getAttribute('id'));
    nds = elem.getElementsByTagName('nd');
    nodeRefs = strings(1, nds.getLength());
    for n = 0:nds.getLength()-1
        nodeRefs(n+1) = string(nds.item(n).getAttribute('ref'));
    end
    s.nodeRefs = nodeRefs;
    s.tags = containers.Map('KeyType','char','ValueType','char');
    tags = elem.getElementsByTagName('tag');
    for t = 0:tags.getLength()-1
        tag = tags.item(t);
        s.tags(char(tag.getAttribute('k'))) = char(tag.getAttribute('v'));
    end
    ways(wid) = s;
end

% Relations — members as struct array, tags as containers.Map
relElems = doc.getElementsByTagName('relation');
relations = containers.Map('KeyType','char','ValueType','any');
for i = 0:relElems.getLength()-1
    elem = relElems.item(i);
    rid = char(elem.getAttribute('id'));
    members = elem.getElementsByTagName('member');
    s.members = struct('type',{},'ref',{},'role',{});
    for m = 0:members.getLength()-1
        mem = members.item(m);
        s.members(end+1).type = string(mem.getAttribute('type'));
        s.members(end).ref = string(mem.getAttribute('ref'));
        s.members(end).role = string(mem.getAttribute('role'));
    end
    s.tags = containers.Map('KeyType','char','ValueType','char');
    tags = elem.getElementsByTagName('tag');
    for t = 0:tags.getLength()-1
        tag = tags.item(t);
        s.tags(char(tag.getAttribute('k'))) = char(tag.getAttribute('v'));
    end
    relations(rid) = s;
end
```

### Typical OSM Structure
```xml
<node id="3" lat="0.00068" lon="0.000099">
    <tag k="ele" v="0.1524"/>
    <tag k="local_x" v="11.0482"/>
    <tag k="local_y" v="75.259"/>
</node>
<way id="2">
    <nd ref="3"/><nd ref="4"/>...
    <tag k="type" v="line_thin"/>
    <tag k="subtype" v="solid"/>
</way>
<relation id="1">
    <member type="way" ref="2" role="center"/>
    <member type="way" ref="33" role="left"/>
    <member type="way" ref="64" role="right"/>
    <tag k="type" v="lanelet"/>
    <tag k="subtype" v="road"/>
    <tag k="one_way" v="yes"/>
</relation>
```

## Example
```matlab
fprintf("Nodes: %d, Ways: %d, Relations: %d\n", nodes.Count, ways.Count, relations.Count);
```

----

Copyright 2026 The MathWorks, Inc.

----
