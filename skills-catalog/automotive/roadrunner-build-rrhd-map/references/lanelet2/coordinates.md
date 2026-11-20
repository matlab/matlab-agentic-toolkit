# Resolve Map Origin, Project Coordinates, Build Way Geometry

Run once, right after parsing. Every later step reads way geometry from `geomMap` — never re-project or modify it.

## Origin (GeoReference) — resolution order

| Priority | Source | Keys |
|---|---|---|
| 1 | `map_projector_info.yaml` next to the `.osm` | `MapOrigin: Latitude / Longitude` (TransverseMercator, LocalCartesianUTM) |
| 2 | `map_config.yaml` next to the `.osm` (Autoware) | `map_origin: latitude / longitude` |
| 3 | Centroid of all node `lat`/`lon` | — |

- Ignore an origin of `[0, 0]`; fall through to the next source.
- **Sanity check:** reject a file origin more than 10 km from the node centroid (warn and use the centroid). Autoware `map_config.yaml` origins can be unrelated to MGRS map data (e.g. sample-map-planning: 74 km away).
- `ProjectorType: MGRS` (Autoware) has no origin in `map_projector_info.yaml` — use priority 2 or 3.
- Match keys case-insensitively — Autoware writes `latitude`, Lanelet2 tooling writes `Latitude`.

## Coordinate mode

| Node data | Projector | Use |
|---|---|---|
| `local_x`/`local_y` tags | not MGRS (TransverseMercator, LocalCartesian, or no projector file) | Local tags directly — they are the metric source of truth |
| `local_x`/`local_y` tags | MGRS | **lat/lon → Transverse Mercator** — MGRS local coordinates are relative to the grid square, not to the GeoReference |
| `lat`/`lon` only | any | lat/lon → Transverse Mercator about the GeoReference |

Z is always the `ele` tag (default 0). Keep source elevation — do not flatten it.

## Implementation

```matlab
%% Origin
osmDir = fileparts(osmFile);
geoRef = [];
for cfgFile = ["map_projector_info.yaml", "map_config.yaml"]
    p = fullfile(osmDir, cfgFile);
    if isempty(geoRef) && isfile(p)
        txt = fileread(p);
        la = regexp(txt, '(?i)latitude:\s*([-\d.eE+]+)', 'tokens', 'once');
        lo = regexp(txt, '(?i)longitude:\s*([-\d.eE+]+)', 'tokens', 'once');
        if ~isempty(la) && ~isempty(lo)
            cand = [str2double(la{1}), str2double(lo{1})];
            if all(isfinite(cand)) && any(cand ~= 0), geoRef = cand; end
        end
    end
end
projType = "";
pf = fullfile(osmDir, "map_projector_info.yaml");
if isfile(pf)
    t = regexp(fileread(pf), '(?i)projector_?type:\s*(\S+)', 'tokens', 'once');
    if ~isempty(t), projType = string(t{1}); end
end

%% Node arrays
nodeKeys = nodes.keys;
nodeVals = nodes.values;
nodeArr = [nodeVals{:}];
lat = [nodeArr.lat]'; lon = [nodeArr.lon]'; ele = [nodeArr.ele]';
centroid = [mean(lat), mean(lon)];
if ~isempty(geoRef) && norm((geoRef - centroid) .* [111e3, 111e3*cosd(centroid(1))]) > 10e3
    warning('Origin from projector/config file is %.0f km from the map data — using node centroid.', ...
        norm((geoRef - centroid) .* [111, 111*cosd(centroid(1))]));
    geoRef = [];
end
if isempty(geoRef), geoRef = centroid; end
geoRef = double(geoRef);

% Region from the origin — selects sign sets (signs.md) and marking colours (extractSemantics.md)
if geoRef(1) >= 24 && geoRef(1) <= 46 && geoRef(2) >= 122 && geoRef(2) <= 154, region = "Japan";
elseif geoRef(1) >= 35 && geoRef(1) <= 72 && geoRef(2) >= -10 && geoRef(2) <= 25, region = "Germany";
else, region = "US"; end

hasLocal = all(~isnan([nodeArr.local_x]));
useLocal = hasLocal && projType ~= "MGRS";
if useLocal
    xyz = [[nodeArr.local_x]', [nodeArr.local_y]', ele];
else
    % WGS-84 Transverse Mercator centred on geoRef (k0 = 1) — the projection RoadRunner applies
    % about the GeoReference, so geometry stays consistent with it far from the origin
    a = 6378137.0; f = 1/298.257223563; e2 = 2*f - f^2; ep2 = e2/(1 - e2);
    meridArc = @(p) a*((1 - e2/4 - 3*e2^2/64 - 5*e2^3/256)*p - (3*e2/8 + 3*e2^2/32 + 45*e2^3/1024)*sin(2*p) ...
        + (15*e2^2/256 + 45*e2^3/1024)*sin(4*p) - (35*e2^3/3072)*sin(6*p));
    phi = deg2rad(lat); dLam = deg2rad(lon - geoRef(2));
    N = a ./ sqrt(1 - e2*sin(phi).^2); T = tan(phi).^2; C = ep2*cos(phi).^2; A = dLam .* cos(phi);
    xE = N .* (A + (1 - T + C).*A.^3/6 + (5 - 18*T + T.^2 + 72*C - 58*ep2).*A.^5/120);
    yN = meridArc(phi) - meridArc(deg2rad(geoRef(1))) + N .* tan(phi) .* (A.^2/2 ...
        + (5 - T + 9*C + 4*C.^2).*A.^4/24 + (61 - 58*T + T.^2 + 600*C - 330*ep2).*A.^6/720);
    xyz = [xE, yN, ele];
end
nodeIdx = containers.Map(nodeKeys, num2cell(1:numel(nodeKeys)));

%% Way geometry — wayID -> Nx3 (immutable from here on)
geomMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
wayKeys = ways.keys;
for i = 1:numel(wayKeys)
    w = ways(wayKeys{i});
    idx = cellfun(@(k) nodeIdx(k), cellstr(w.nodeRefs));
    geomMap(wayKeys{i}) = xyz(idx, :);
end
fprintf('GeoReference [%.7f, %.7f] (%s) | coordinates: %s\n', geoRef(1), geoRef(2), ...
    projType, string(useLocal).replace(["true","false"], ["local_x/local_y","lat/lon -> TM"]));
```

Set `rrMap.GeoReference = geoRef` (1x2 `[lat, lon]`) before `write()`.

----

Copyright 2026 The MathWorks, Inc.

----
