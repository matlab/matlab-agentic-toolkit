function ll2 = parseOSM(osmFile)
%parseOSM Parse a Lanelet2 .osm file into structured MATLAB containers
%   ll2 = parseOSM(osmFile) reads a Lanelet2 OSM file and returns a struct
%   with nodes, ways, and relations stored as containers.Map objects.
%
%   Input:
%       osmFile - Path to a Lanelet2 .osm file (string or char)
%
%   Output:
%       ll2 - Struct with fields:
%           .nodes      - containers.Map (nodeID -> struct with lat, lon, ele, local_x, local_y)
%           .ways       - containers.Map (wayID -> struct with nodeRefs, tags)
%           .relations  - containers.Map (relID -> struct with members, tags)
%           .sourceFile - Input file path

% Copyright 2026 The MathWorks, Inc.

    arguments
        osmFile (1,1) string {mustBeFile}
    end

    fprintf(1, 'parseOSM: reading %s\n', osmFile);
    doc = xmlread(osmFile);

    nodes = parseNodes(doc);
    fprintf(1, 'parseOSM: %d nodes\n', nodes.Count);
    ways = parseWays(doc);
    fprintf(1, 'parseOSM: %d ways\n', ways.Count);
    relations = parseRelations(doc);
    fprintf(1, 'parseOSM: %d relations\n', relations.Count);

    ll2.nodes = nodes;
    ll2.ways = ways;
    ll2.relations = relations;
    ll2.sourceFile = osmFile;

    if nargout == 0, clear ll2; end
end

function nodes = parseNodes(doc)
    nodeElems = doc.getElementsByTagName("node");
    nodes = containers.Map("KeyType", "char", "ValueType", "any");

    for i = 0:nodeElems.getLength() - 1
        elem = nodeElems.item(i);
        nid = char(elem.getAttribute("id"));

        s.lat = str2double(elem.getAttribute("lat"));
        s.lon = str2double(elem.getAttribute("lon"));
        s.ele = 0;
        s.local_x = NaN;
        s.local_y = NaN;

        tags = elem.getElementsByTagName("tag");
        for t = 0:tags.getLength() - 1
            tag = tags.item(t);
            k = char(tag.getAttribute("k"));
            v = str2double(tag.getAttribute("v"));
            switch k
                case "ele"
                    s.ele = v;
                case "local_x"
                    s.local_x = v;
                case "local_y"
                    s.local_y = v;
            end
        end

        nodes(nid) = s;
    end
end

function ways = parseWays(doc)
    wayElems = doc.getElementsByTagName("way");
    ways = containers.Map("KeyType", "char", "ValueType", "any");

    for i = 0:wayElems.getLength() - 1
        elem = wayElems.item(i);
        wid = char(elem.getAttribute("id"));

        nds = elem.getElementsByTagName("nd");
        nodeRefs = strings(1, nds.getLength());
        for n = 0:nds.getLength() - 1
            nodeRefs(n + 1) = string(nds.item(n).getAttribute("ref"));
        end

        s.nodeRefs = nodeRefs;
        s.tags = containers.Map("KeyType", "char", "ValueType", "char");

        tags = elem.getElementsByTagName("tag");
        for t = 0:tags.getLength() - 1
            tag = tags.item(t);
            s.tags(char(tag.getAttribute("k"))) = char(tag.getAttribute("v"));
        end

        ways(wid) = s;
    end
end

function relations = parseRelations(doc)
    relElems = doc.getElementsByTagName("relation");
    relations = containers.Map("KeyType", "char", "ValueType", "any");

    for i = 0:relElems.getLength() - 1
        elem = relElems.item(i);
        rid = char(elem.getAttribute("id"));

        members = elem.getElementsByTagName("member");
        nMembers = members.getLength();
        s.members = struct("type", cell(1, nMembers), "ref", cell(1, nMembers), "role", cell(1, nMembers));
        for m = 0:nMembers - 1
            mem = members.item(m);
            s.members(m + 1).type = string(mem.getAttribute("type"));
            s.members(m + 1).ref = string(mem.getAttribute("ref"));
            s.members(m + 1).role = string(mem.getAttribute("role"));
        end

        s.tags = containers.Map("KeyType", "char", "ValueType", "char");
        tags = elem.getElementsByTagName("tag");
        for t = 0:tags.getLength() - 1
            tag = tags.item(t);
            s.tags(char(tag.getAttribute("k"))) = char(tag.getAttribute("v"));
        end

        relations(rid) = s;
    end
end
