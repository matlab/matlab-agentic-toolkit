# Build Non-Lane Elements — Curve Markings, Barriers, Speed Limits, Signs

Discover everything, build what RRHD supports, report the rest. Inputs from earlier steps: `ways`, `relations`, `geomMap` and `xyz`/`nodeIdx` ([coordinates.md](coordinates.md)), `geoRef`, the built `lanes`, and the discovery buckets.

## Step 3b/3c: Discovery

```matlab
disc = discoverWayTypes(ways);   % scripts/discoverWayTypes.m — every way struct carries .wayID
stopLineWays = disc.stopLineWays; pedestrianMarkingWays = disc.pedestrianMarkingWays;
zebraMarkingWays = disc.zebraMarkingWays; bikeMarkingWays = disc.bikeMarkingWays; zigzagWays = disc.zigzagWays;
fenceWays = disc.fenceWays; guardRailWays = disc.guardRailWays; jerseyBarrierWays = disc.jerseyBarrierWays;
wallWays = disc.wallWays; curbstoneWays = disc.curbstoneWays;
trafficSignWays = disc.trafficSignWays; trafficLightWays = disc.trafficLightWays;
fprintf('CurveMarkings: %d stop lines, %d pedestrian, %d zebra, %d bike, %d zig-zag\n', numel(stopLineWays), ...
    numel(pedestrianMarkingWays), numel(zebraMarkingWays), numel(bikeMarkingWays), numel(zigzagWays));
fprintf('Barriers: %d fence, %d guard rail, %d jersey, %d wall | curbstones: %d\n', numel(fenceWays), ...
    numel(guardRailWays), numel(jerseyBarrierWays), numel(wallWays), numel(curbstoneWays));
fprintf('Signs: %d sign ways | traffic lights: %d ways\n', numel(trafficSignWays), numel(trafficLightWays));
uk = disc.unmapped.keys;
for k = 1:numel(uk), fprintf('UNMAPPED way type %s: %d\n', uk{k}, disc.unmapped(uk{k})); end
```

Relations: run [discoverRelations.md](discoverRelations.md) (`trafficSignRels`, `speedLimitRels`, `rightOfWayRels`, `trafficLightRels`, `multipolygonRels`, `unmappedRels`).

## Step 9a: Curve Markings

Stop lines are `.rrlms`; crosswalks are `.rrcws` — see [assetCatalog.md](../assets/assetCatalog.md). Crosswalk/walkway lanelets become `SimpleCrosswalk` markings along their center line. Autoware maps also draw the zebra stripes as `pedestrian_marking` ways **inside** those lanelets — skip a pedestrian marking within 3 m of a crosswalk-lanelet center line so each crossing is built once.

```matlab
cmtDefs = {'StopLine', 'Assets/Markings/StopLine.rrlms'; 'SimpleCrosswalk', 'Assets/Markings/SimpleCrosswalk.rrcws'; ...
    'ZebraCrosswalk', 'Assets/Markings/ContinentalCrosswalk.rrcws'; 'BikeMarking', 'Assets/Markings/DashedSingleWhite.rrlms'; ...
    'ZigZag', 'Assets/Markings/DashedSingleWhite.rrlms'};

% Crosswalk lanelet center lines (left/right ways averaged after aligning their direction)
cwCenters = cell(1, numel(crosswalkLanelets));
for i = 1:numel(crosswalkLanelets)
    lp = geomMap(char(crosswalkLanelets(i).leftWayID)); rp = geomMap(char(crosswalkLanelets(i).rightWayID));
    if dot(lp(end,1:2) - lp(1,1:2), rp(end,1:2) - rp(1,1:2)) < 0, rp = flipud(rp); end
    [tl, il] = unique([0; cumsum(vecnorm(diff(lp), 2, 2))] / sum(vecnorm(diff(lp), 2, 2)), 'stable');
    [tr, ir] = unique([0; cumsum(vecnorm(diff(rp), 2, 2))] / sum(vecnorm(diff(rp), 2, 2)), 'stable');
    tq = linspace(0, 1, max([10, numel(tl), numel(tr)]))';
    cwCenters{i} = (interp1(tl, lp(il,:), tq) + interp1(tr, rp(ir,:), tq)) / 2;
end
nearCrosswalk = @(g) any(cellfun(@(c) min(vecnorm(c(:,1:2) - mean(g(:,1:2), 1), 2, 2)) < 3, cwCenters));

cmSources = {stopLineWays, 'StopLine'; pedestrianMarkingWays, 'SimpleCrosswalk'; zebraMarkingWays, 'ZebraCrosswalk'; ...
    bikeMarkingWays, 'BikeMarking'; zigzagWays, 'ZigZag'};
curveMarkingTypes = roadrunner.hdmap.CurveMarkingType.empty;
curveMarkings = roadrunner.hdmap.CurveMarking.empty;
usedTypes = strings(0, 1); nSkippedPed = 0;
addCM = @(id, g, typeID) struct('id', id, 'g', g, 'typeID', typeID);
cmList = {};
for s = 1:size(cmSources, 1)
    for k = 1:numel(cmSources{s, 1})
        g = geomMap(cmSources{s, 1}{k}.wayID);
        if size(g, 1) < 2, continue; end
        if s == 2 && ~isempty(cwCenters) && nearCrosswalk(g), nSkippedPed = nSkippedPed + 1; continue; end
        cmList{end+1} = addCM(sprintf("CM_%s_%d", cmSources{s, 2}, numel(cmList) + 1), g, cmSources{s, 2}); %#ok<SAGROW>
    end
end
for i = 1:numel(cwCenters)
    cmList{end+1} = addCM(sprintf("CM_LaneletCW_%d", numel(cmList) + 1), cwCenters{i}, 'SimpleCrosswalk'); %#ok<SAGROW>
end
for i = 1:numel(cmList)
    c = cmList{i};
    if ~ismember(string(c.typeID), usedTypes)
        cmt = roadrunner.hdmap.CurveMarkingType; cmt.ID = c.typeID;
        cmt.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=cmtDefs{strcmp(cmtDefs(:,1), c.typeID), 2});
        curveMarkingTypes(end+1) = cmt; usedTypes(end+1) = c.typeID; %#ok<SAGROW>
    end
    cm = roadrunner.hdmap.CurveMarking; cm.ID = c.id; cm.Geometry = c.g;
    ref = roadrunner.hdmap.Reference; ref.ID = c.typeID;
    cm.MarkingTypeReference = ref; cm.Flip = false; cm.Reverse = false;
    curveMarkings(end+1) = cm; %#ok<SAGROW>
end
fprintf('CurveMarkings: %d built (%d pedestrian markings inside crosswalk lanelets skipped)\n', numel(curveMarkings), nSkippedPed);
```

## Step 9b: Barriers

Asset paths from [barriers.md](../assets/barriers.md) — extrusions are `<Name>.rrext` (never `.rrext.rrmeta`, which is the metadata sidecar). The asset library has no curb extrusion: report curbstones, do not build them as barriers.

```matlab
barrierDefs = {fenceWays, 'Fence', 'Assets/Extrusions/Fence.rrext'; ...
    guardRailWays, 'GuardRail', 'Assets/Extrusions/GuardRail.rrext'; ...
    jerseyBarrierWays, 'JerseyBarrier', 'Assets/Extrusions/JerseyBarrier.rrext'; ...
    wallWays, 'Wall', 'Assets/Extrusions/HighwayBorderwall01.rrext'};
barrierTypes = roadrunner.hdmap.BarrierType.empty;
barriers = roadrunner.hdmap.Barrier.empty;
for d = 1:size(barrierDefs, 1)
    if isempty(barrierDefs{d, 1}), continue; end
    bt = roadrunner.hdmap.BarrierType; bt.ID = barrierDefs{d, 2};
    bt.ExtrusionPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=barrierDefs{d, 3});
    barrierTypes(end+1) = bt; %#ok<SAGROW>
    for k = 1:numel(barrierDefs{d, 1})
        g = geomMap(barrierDefs{d, 1}{k}.wayID);
        if size(g, 1) < 2, continue; end
        b = roadrunner.hdmap.Barrier;
        b.ID = sprintf("Barrier_%s_%d", barrierDefs{d, 2}, numel(barriers) + 1);
        b.Geometry = g;
        ref = roadrunner.hdmap.Reference; ref.ID = barrierDefs{d, 2};
        b.BarrierTypeReference = ref; b.FlipLaterally = false;
        barriers(end+1) = b; %#ok<SAGROW>
    end
end
fprintf('Barriers: %d instances, %d types | curbstones not built (no curb extrusion): %d\n', ...
    numel(barriers), numel(barrierTypes), numel(curbstoneWays));
```

## Step 9d: Speed Limits

Tag values may carry units (`"100.000000 km/h"`, `"30 mph"`). Regulatory elements use `max_speed`, `speed_limit`, or a trailing number in `sign_type` (`de274-30`, `jp_323-40`).

```matlab
parseSpeed = @(s) str2double(regexp(char(s), '^\s*([\d.]+)', 'tokens', 'once'));
key = @(v, mph) sprintf("SL_%d_%s", round(v), string(mph).replace(["true","false"], ["Mph","Kph"]));
slMap = containers.Map;    % key -> [value, isMph]
laneSpeedKey = strings(1, numel(regular));
for i = 1:numel(regular)
    t = regular(i).tags;
    if t.isKey('speed_limit')
        v = parseSpeed(t('speed_limit'));
        if ~isnan(v)
            mph = contains(lower(string(t('speed_limit'))), "mph");
            laneSpeedKey(i) = key(v, mph); slMap(char(laneSpeedKey(i))) = [v, mph];
        end
    end
end
for i = 1:numel(speedLimitRels)
    t = speedLimitRels{i}.tags; v = NaN;
    for f = ["max_speed", "speed_limit"]
        if isnan(v) && t.isKey(char(f)), v = parseSpeed(t(char(f))); end
    end
    if isnan(v) && t.isKey('sign_type')
        v = str2double(regexp(t('sign_type'), '(\d+)$', 'match', 'once'));
    end
    unitTag = "";
    for f = ["max_speed_unit", "speed_limit_unit"], if t.isKey(char(f)), unitTag = string(t(char(f))); end, end
    if ~isnan(v) && v > 0 && v < 300
        mph = contains(lower(unitTag), "mph"); slMap(char(key(v, mph))) = [v, mph];
    end
end
speedLimits = roadrunner.hdmap.SpeedLimit.empty;
for k = string(slMap.keys)
    vm = slMap(char(k));
    sl = roadrunner.hdmap.SpeedLimit; sl.ID = k; sl.Value = int32(round(vm(1)));
    sl.VelocityUnit = string(logical(vm(2))).replace(["true","false"], ["Mph","Kph"]);
    speedLimits(end+1) = sl; %#ok<SAGROW>
end
fprintf('SpeedLimits: %d unique (%s); lanes with a limit: %d/%d\n', numel(speedLimits), ...
    strjoin(string(slMap.keys), ", "), nnz(laneSpeedKey ~= ""), numel(regular));
```
Attach `laneSpeedKey(i)` to lane `i` as a `ParametricAttribution` with `SpeedLimitReference` (see [buildRRHD.md](buildRRHD.md)).

## Step 9c: Signs — one per physical sign

A physical sign can appear twice: as a `traffic_sign` (or `roadsign`) way **and** as the `refers` member of a `regulatory_element/traffic_sign` relation — and some maps (Autoware sample-map-planning) also carry identical copies under different way IDs. Build from relations first, record the referred way IDs, then add only the sign ways no relation referred to. Resolve codes with `resolveSignAsset` and orient signs as in [signs.md](../assets/signs.md).

Code priority — relation: `sign_type`, `traffic_sign_id`, then the referred way's code; way: `type` suffix (`traffic_sign/de205`), `subtype` (if not just `traffic_sign`/`roadsign`), `RoadSign:Type`, `sign_type`; else `"unknown"`.

```matlab
% region comes from coordinates.md (Japan / Germany / US)
signSrc = cell(0, 3);       % {code, Nx3 geometry, source}
usedSignWays = containers.Map;
for i = 1:numel(trafficSignRels)
    rel = trafficSignRels{i}; t = rel.tags;
    relCode = "";
    for f = ["sign_type", "traffic_sign_id"], if relCode == "" && t.isKey(char(f)), relCode = string(t(char(f))); end, end
    for m = 1:numel(rel.members)
        mem = rel.members(m);
        if mem.role ~= "refers", continue; end
        if mem.type == "way" && ways.isKey(char(mem.ref))
            if usedSignWays.isKey(char(mem.ref)), continue; end
            usedSignWays(char(mem.ref)) = true;
            g = geomMap(char(mem.ref)); wt = ways(char(mem.ref)).tags; code = relCode;
            if code == "" && wt.isKey('subtype') && ~ismember(string(wt('subtype')), ["traffic_sign", "roadsign"]), code = string(wt('subtype')); end
        elseif mem.type == "node" && nodeIdx.isKey(char(mem.ref))
            g = xyz(nodeIdx(char(mem.ref)), :); code = relCode;
        else
            continue
        end
        if code == "", code = "unknown"; end
        signSrc(end+1, :) = {code, g, "relation " + string(rel.relID)}; %#ok<SAGROW>
    end
end
for i = 1:numel(trafficSignWays)
    w = trafficSignWays{i};
    if usedSignWays.isKey(w.wayID), continue; end
    t = w.tags; parts = strsplit(t('type'), '/'); code = "";
    if numel(parts) > 1, code = string(parts{2}); end
    if code == "" && t.isKey('subtype') && ~ismember(string(t('subtype')), ["traffic_sign", "roadsign"]), code = string(t('subtype')); end
    for f = ["RoadSign:Type", "sign_type"], if code == "" && t.isKey(char(f)), code = string(t(char(f))); end, end
    if code == "", code = "unknown"; end
    signSrc(end+1, :) = {code, geomMap(w.wayID), "way " + w.wayID}; %#ok<SAGROW>
end

% Source maps can also contain copies of the same sign under different way IDs (same code, same place).
keep = true(size(signSrc, 1), 1);
for i = 2:size(signSrc, 1)
    for j = 1:i-1
        if keep(j) && string(signSrc{i, 1}) == string(signSrc{j, 1}) && ...
                norm(mean(signSrc{i, 2}, 1) - mean(signSrc{j, 2}, 1)) < 0.3
            keep(i) = false; break
        end
    end
end
nDupSigns = nnz(~keep); signSrc = signSrc(keep, :);

laneCenters = arrayfun(@(l) l.Geometry, lanes, 'UniformOutput', false);
signTypes = roadrunner.hdmap.SignType.empty;
signs = roadrunner.hdmap.Sign.empty;
typeForPath = containers.Map; nFallback = 0; nSignals = 0;
for i = 1:size(signSrc, 1)
    if exist('projectFolder', 'var') && strlength(projectFolder) > 0
        [ap, ot, code, fb] = resolveSignAsset(signSrc{i, 1}, region, ProjectFolder=projectFolder);
    else
        [ap, ot, code, fb] = resolveSignAsset(signSrc{i, 1}, region);
    end
    if ot == "signal", nSignals = nSignals + 1; continue; end
    nFallback = nFallback + fb;
    if ~typeForPath.isKey(char(ap))
        st = roadrunner.hdmap.SignType; st.ID = "SignType_" + code;
        if ~isempty(signTypes) && any(arrayfun(@(x) string(x.ID), signTypes) == st.ID), st.ID = st.ID + "_" + numel(signTypes); end
        st.AssetPath = roadrunner.hdmap.RelativeAssetPath(AssetPath=ap);
        signTypes(end+1) = st; typeForPath(char(ap)) = char(st.ID); %#ok<SAGROW>
    end
    g = signSrc{i, 2}; c = mean(g, 1);
    best = inf; heading = 0;
    for k = 1:numel(laneCenters)
        lc = laneCenters{k};
        [dmin, j] = min(vecnorm(lc(:,1:2) - c(1:2), 2, 2));
        if dmin < best
            j = min(max(j, 1), size(lc, 1) - 1); seg = lc(j+1,1:2) - lc(j,1:2);
            heading = atan2(-seg(2), -seg(1)); best = dmin;
        end
    end
    bb = roadrunner.hdmap.GeoOrientedBoundingBox;
    bb.Center = c; bb.Dimension = [0.02 0.3 0.3]; bb.GeoOrientation = [0 0 heading];
    sgn = roadrunner.hdmap.Sign; sgn.ID = sprintf("Sign_%d", numel(signs) + 1); sgn.Geometry = bb;
    ref = roadrunner.hdmap.Reference; ref.ID = typeForPath(char(ap)); sgn.SignTypeReference = ref;
    signs(end+1) = sgn; %#ok<SAGROW>
end
fprintf('Signs: %d physical signs, %d types (region %s) | duplicates in source skipped: %d | unrecognized codes -> blank: %d | signals skipped: %d\n', ...
    numel(signs), numel(signTypes), region, nDupSigns, nFallback, nSignals);
```

## Not Representable in RRHD — report, never drop silently

| Lanelet2 element | Reason |
|---|---|
| `regulatory_element/traffic_light`, `traffic_light` / `light_bulbs` ways | RoadRunner ignores signals on RRHD import |
| `regulatory_element/right_of_way` | No RRHD equivalent (implicit in junctions) |
| `multipolygon/building`, `vegetation`, `freespace` | No RRHD polygon type |
| `multipolygon/traffic_island`, `keepout` | No standard mapping |
| `curbstone` ways | No curb extrusion in the asset library |
| `object` (poles), `roadpainting` (arrows), `painting_outline` | No mapping yet (stencils/static objects need per-type assets) |

```matlab
fprintf('\n=== NOT REPRESENTABLE ===\n');
fprintf('Traffic lights: %d relations, %d ways | right-of-way: %d\n', numel(trafficLightRels), numel(trafficLightWays), numel(rightOfWayRels));
fprintf('Buildings: %d | vegetation: %d | traffic islands: %d | keepout: %d | curbstones: %d\n', ...
    numel(multipolygonRels.building), numel(multipolygonRels.vegetation), numel(multipolygonRels.traffic_island), ...
    numel(multipolygonRels.keepout), numel(curbstoneWays));
```

----

Copyright 2026 The MathWorks, Inc.

----
