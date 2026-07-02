function roadFeatures = helperClassifyRoadFeatures(laneNetwork, rrHDMap, options)
%helperClassifyRoadFeatures Classify lanes into semantic road features using elevation.
%
%   roadFeatures = helperClassifyRoadFeatures(laneNetwork, rrHDMap)
%   roadFeatures = helperClassifyRoadFeatures(laneNetwork, rrHDMap, ElevationThreshold=3)
%
%   Uses elevation clustering to label lanes as "bridge", "ground", "ramp",
%   or "overpass". Groups lanes by LaneGroup and elevation band.
%
%   Inputs:
%       laneNetwork - Output from helperAnalyzeHDMapLanes
%       rrHDMap     - The HD Map object
%
%   Output struct fields:
%       .Features       - Table: Label, MeanZ, ZRange, LaneIDs, TotalLength,
%                         NumLanes, ConnectedPathLength
%       .LaneToFeature  - containers.Map: laneID (string) -> feature label
%       .Summary        - Human-readable feature summary string
%
% This is a helper function for example purposes and may be removed or
% modified in the future.

    arguments
        laneNetwork (1,1) struct
        rrHDMap (1,1)
        options.ElevationThreshold (1,1) double = -1  % -1 means auto-detect
        options.MinFeatureLength (1,1) double = 20
    end

    allLanes = rrHDMap.Lanes;
    lanes = laneNetwork.Lanes;
    numLanes = height(lanes);

    %% Step 1: Compute mean elevation per lane
    meanZ = zeros(numLanes, 1);
    for i = 1:numLanes
        globalIdx = lanes.GlobalIndex(i);
        geom = allLanes(globalIdx).Geometry;
        if size(geom, 2) >= 3 && size(geom, 1) >= 1
            meanZ(i) = mean(geom(:, 3));
        end
    end

    %% Step 2: Compute elevation per LaneGroup
    laneGroups = laneNetwork.LaneGroups;
    numGroups = height(laneGroups);
    groupMeanZ = zeros(numGroups, 1);
    groupLaneIndices = cell(numGroups, 1);

    for g = 1:numGroups
        memberIDs = laneGroups.LaneIDs{g};
        memberIdxs = [];
        for m = 1:numel(memberIDs)
            idx = find(lanes.ID == memberIDs(m), 1);
            if ~isempty(idx)
                memberIdxs(end+1) = idx; %#ok<AGROW>
            end
        end
        groupLaneIndices{g} = memberIdxs;
        if ~isempty(memberIdxs)
            groupMeanZ(g) = mean(meanZ(memberIdxs));
        end
    end

    % Assign ungrouped lanes to virtual groups
    groupedLaneIDs = vertcat(laneGroups.LaneIDs{:});
    ungroupedMask = ~ismember(lanes.ID, groupedLaneIDs);
    ungroupedIdxs = find(ungroupedMask);

    %% Step 3: Detect elevation bands
    % Use per-lane mean Z directly for classification (more data points)
    validZ = meanZ(meanZ ~= 0);

    if isempty(validZ) || range(validZ) < 3.0
        % Insufficient elevation variation (< 3m) — everything is "ground"
        roadFeatures = buildSingleFeature(lanes, "ground", meanZ);
        return;
    end

    % Range-based classification: divide into ground/ramp/bridge using
    % percentile thresholds. Lanes near the bottom are ground, near the top
    % are bridge, and in between are ramp.
    zMin = min(validZ);
    zMax = max(validZ);
    zRange = zMax - zMin;

    if options.ElevationThreshold > 0
        % User-specified threshold for ground/bridge boundary
        groundCeiling = zMin + options.ElevationThreshold;
        bridgeFloor = zMax - options.ElevationThreshold;
    else
        % Auto: bottom 30% = ground, top 30% = bridge, middle = ramp
        groundCeiling = zMin + 0.30 * zRange;
        bridgeFloor = zMax - 0.30 * zRange;
    end

    % Assign bands: 1=ground, 2=ramp, 3=bridge
    numBands = 3;

    %% Step 4: Assign lanes to bands and label features
    laneBand = zeros(numLanes, 1);
    for i = 1:numLanes
        if meanZ(i) == 0
            laneBand(i) = 1;  % default to ground
        elseif meanZ(i) <= groundCeiling
            laneBand(i) = 1;  % ground
        elseif meanZ(i) >= bridgeFloor
            laneBand(i) = 3;  % bridge
        else
            laneBand(i) = 2;  % ramp
        end
    end

    % Compute band statistics
    bandMeanZ = zeros(numBands, 1);
    bandLaneIDs = cell(numBands, 1);
    bandTotalLength = zeros(numBands, 1);
    bandNumLanes = zeros(numBands, 1);

    for b = 1:numBands
        bandMask = laneBand == b;
        bandLaneIDs{b} = lanes.ID(bandMask);
        if any(bandMask)
            bandMeanZ(b) = mean(meanZ(bandMask));
        end
        bandTotalLength(b) = sum(lanes.Length(bandMask));
        bandNumLanes(b) = sum(bandMask);
    end

    % Label features
    labels = ["ground"; "ramp"; "bridge"];

    % Verify bridge has ground lanes below (XY overlap) — if not, it's "overpass"
    if bandNumLanes(3) > 0 && bandNumLanes(1) > 0
        if ~hasLanesBelow(lanes, laneBand, 3, 1, allLanes)
            labels(3) = "overpass";
        end
    end

    % Ramp lanes are already classified in band 2 — collect their IDs
    rampLaneIDs = lanes.ID(laneBand == 2);

    %% Step 5: Compute connected path lengths per feature
    connectedPathLengths = zeros(numBands, 1);
    succMap = buildSuccessorMap(laneNetwork);
    laneIDToIdx = buildLaneIDToIdx(lanes);

    for b = 1:numBands
        bandIdxs = find(laneBand == b);
        if isempty(bandIdxs)
            continue;
        end
        % Find longest connected path starting from any lane in this band
        bestLen = 0;
        for startIdx = bandIdxs'
            pathLen = computeConnectedLength(startIdx, lanes, succMap, laneIDToIdx, bandIdxs);
            if pathLen > bestLen
                bestLen = pathLen;
            end
        end
        connectedPathLengths(b) = bestLen;
    end

    %% Step 6: Build output
    featureLabels = labels;
    featureMeanZ = bandMeanZ;
    featureZRange = zeros(numBands, 2);
    featureLaneIDs = bandLaneIDs;
    featureTotalLength = bandTotalLength;
    featureNumLanes = bandNumLanes;
    featureConnectedPath = connectedPathLengths;

    for b = 1:numBands
        bandMask = laneBand == b;
        zVals = meanZ(bandMask);
        if ~isempty(zVals)
            featureZRange(b, :) = [min(zVals), max(zVals)];
        end
    end

    roadFeatures.Features = table(featureLabels, featureMeanZ, featureZRange, ...
        featureLaneIDs, featureTotalLength, featureNumLanes, featureConnectedPath, ...
        'VariableNames', {'Label', 'MeanZ', 'ZRange', 'LaneIDs', 'TotalLength', ...
        'NumLanes', 'ConnectedPathLength'});

    % Build lane-to-feature map
    laneToFeature = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for b = 1:numBands
        for k = 1:numel(bandLaneIDs{b})
            laneToFeature(char(bandLaneIDs{b}(k))) = char(labels(b));
        end
    end
    % Mark ramp lanes
    for k = 1:numel(rampLaneIDs)
        if laneToFeature.isKey(char(rampLaneIDs(k)))
            laneToFeature(char(rampLaneIDs(k))) = 'ramp';
        end
    end
    roadFeatures.LaneToFeature = laneToFeature;

    %% Step 7: Find Forward-direction connections between features
    % Identifies which Forward lanes in one feature connect (via successors
    % through ramps) to another feature. Critical for lane-following placement.
    featureConnections = findFeatureConnections(lanes, laneBand, labels, ...
        succMap, laneIDToIdx, laneToFeature);
    roadFeatures.FeatureConnections = featureConnections;

    % Build summary string
    lines = strings(0, 1);
    lines(end+1) = "Road features detected:";
    for b = 1:numBands
        if bandNumLanes(b) > 0
            lines(end+1) = sprintf("  %s: %d lanes, total %.0fm, connected path %.0fm, elevation %.1f-%.1fm", ...
                labels(b), bandNumLanes(b), bandTotalLength(b), ...
                connectedPathLengths(b), featureZRange(b,1), featureZRange(b,2)); %#ok<AGROW>
        end
    end
    if ~isempty(rampLaneIDs)
        lines(end+1) = sprintf("  ramp: %d lanes connecting elevation levels", numel(rampLaneIDs));
    end
    % Show Forward connections between features
    for c = 1:numel(featureConnections)
        conn = featureConnections(c);
        lines(end+1) = sprintf("  connection: %s -> %s (%d Forward lanes)", ...
            conn.FromFeature, conn.ToFeature, numel(conn.LaneIDs)); %#ok<AGROW>
    end
    roadFeatures.Summary = strjoin(lines, newline);
end


function roadFeatures = buildSingleFeature(lanes, label, meanZ)
%buildSingleFeature Create output when only one elevation level exists.
    laneIDs = lanes.ID;
    totalLen = sum(lanes.Length);
    zVals = meanZ(meanZ ~= 0);
    zRange = [0 0];
    mZ = 0;
    if ~isempty(zVals)
        zRange = [min(zVals), max(zVals)];
        mZ = mean(zVals);
    end

    roadFeatures.Features = table(label, mZ, zRange, {laneIDs}, totalLen, ...
        height(lanes), totalLen, ...
        'VariableNames', {'Label', 'MeanZ', 'ZRange', 'LaneIDs', 'TotalLength', ...
        'NumLanes', 'ConnectedPathLength'});
    roadFeatures.LaneToFeature = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for k = 1:numel(laneIDs)
        roadFeatures.LaneToFeature(char(laneIDs(k))) = char(label);
    end
    roadFeatures.Summary = sprintf("Road features detected:\n  %s: %d lanes, total %.0fm, elevation %.1f-%.1fm", ...
        label, height(lanes), totalLen, zRange(1), zRange(2));
end


function result = hasLanesBelow(lanes, laneBand, elevBand, groundBand, allLanes)
%hasLanesBelow Check if ground-level lanes exist spatially below the elevated band.
    elevMask = laneBand == elevBand;
    groundMask = laneBand == groundBand;

    % Get XY bounding box of elevated lanes
    elevIdxs = find(elevMask);
    xMin = inf; xMax = -inf; yMin = inf; yMax = -inf;
    for i = elevIdxs'
        geom = allLanes(lanes.GlobalIndex(i)).Geometry;
        xMin = min(xMin, min(geom(:,1)));
        xMax = max(xMax, max(geom(:,1)));
        yMin = min(yMin, min(geom(:,2)));
        yMax = max(yMax, max(geom(:,2)));
    end

    % Check if any ground lane has geometry within that XY box
    groundIdxs = find(groundMask);
    for i = groundIdxs'
        geom = allLanes(lanes.GlobalIndex(i)).Geometry;
        inBox = geom(:,1) >= xMin & geom(:,1) <= xMax & ...
                geom(:,2) >= yMin & geom(:,2) <= yMax;
        if any(inBox)
            result = true;
            return;
        end
    end
    result = false;
end




function succMap = buildSuccessorMap(laneNetwork)
%buildSuccessorMap Build a containers.Map of laneID -> successor lane IDs.
    succMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    longAdj = laneNetwork.LongitudinalAdj;

    % Convert cell columns to string arrays for comparison
    if iscell(longAdj.Relation)
        relCol = string(cellfun(@(x) x, longAdj.Relation));
    else
        relCol = string(longAdj.Relation);
    end
    succMask = relCol == "successor";

    if iscell(longAdj.FromLaneID)
        fromCol = string(cellfun(@(x) x, longAdj.FromLaneID));
    else
        fromCol = string(longAdj.FromLaneID);
    end
    if iscell(longAdj.ToLaneID)
        toCol = string(cellfun(@(x) x, longAdj.ToLaneID));
    else
        toCol = string(longAdj.ToLaneID);
    end

    fromIDs = fromCol(succMask);
    toIDs = toCol(succMask);

    for i = 1:numel(fromIDs)
        fromID = char(fromIDs(i));
        toID = toIDs(i);
        if succMap.isKey(fromID)
            succMap(fromID) = [succMap(fromID); toID];
        else
            succMap(fromID) = toID;
        end
    end
end


function laneIDToIdx = buildLaneIDToIdx(lanes)
%buildLaneIDToIdx Build a map from lane ID to table row index.
    laneIDToIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:height(lanes)
        laneIDToIdx(char(lanes.ID(i))) = i;
    end
end


function totalLen = computeConnectedLength(startIdx, lanes, succMap, laneIDToIdx, validIdxs)
%computeConnectedLength Compute total forward-reachable path length from startIdx.
    visited = startIdx;
    totalLen = lanes.Length(startIdx);
    current = startIdx;

    for iter = 1:100  % Safety limit
        currentID = char(lanes.ID(current));
        if ~succMap.isKey(currentID)
            break;
        end
        nextIDs = succMap(currentID);
        found = false;
        for n = 1:numel(nextIDs)
            nID = char(nextIDs(n));
            if ~laneIDToIdx.isKey(nID)
                continue;
            end
            nIdx = laneIDToIdx(nID);
            if ~ismember(nIdx, visited) && ismember(nIdx, validIdxs)
                visited(end+1) = nIdx; %#ok<AGROW>
                totalLen = totalLen + lanes.Length(nIdx);
                current = nIdx;
                found = true;
                break;
            end
        end
        if ~found
            break;
        end
    end
end


function connections = findFeatureConnections(lanes, laneBand, labels, succMap, laneIDToIdx, laneToFeature)
%findFeatureConnections Find Forward lanes that connect between features via successors.
%   Returns struct array with FromFeature, ToFeature, LaneIDs fields.
%   Only considers lanes with TravelDirection="Forward" to ensure lane-following works.

    connections = struct('FromFeature', {}, 'ToFeature', {}, 'LaneIDs', {});
    numBands = numel(labels);

    for fromBand = 1:numBands
        for toBand = 1:numBands
            if fromBand == toBand
                continue;
            end

            % Find Forward lanes in fromBand whose successor chain reaches toBand
            fromIdxs = find(laneBand == fromBand & lanes.TravelDirection == "Forward");
            connectingIDs = strings(0, 1);

            for idx = fromIdxs'
                if reachesFeature(idx, lanes, succMap, laneIDToIdx, laneToFeature, char(labels(toBand)))
                    connectingIDs(end+1) = lanes.ID(idx); %#ok<AGROW>
                end
            end

            if ~isempty(connectingIDs)
                conn.FromFeature = labels(fromBand);
                conn.ToFeature = labels(toBand);
                conn.LaneIDs = connectingIDs;
                connections(end+1) = conn; %#ok<AGROW>
            end
        end
    end
end


function result = reachesFeature(startIdx, lanes, succMap, laneIDToIdx, laneToFeature, targetFeature)
%reachesFeature Check if a lane reaches the target feature via successor chain.
%   Follows up to 30 successor links (through ramps) to find if the path
%   eventually reaches a lane labeled with targetFeature.

    result = false;
    currentID = char(lanes.ID(startIdx));
    visited = string(currentID);

    for iter = 1:30
        if ~succMap.isKey(currentID)
            return;
        end
        nextIDs = succMap(currentID);
        advanced = false;
        for n = 1:numel(nextIDs)
            nID = char(nextIDs(n));
            if ismember(string(nID), visited)
                continue;
            end
            % Check if this successor is in the target feature
            if laneToFeature.isKey(nID) && strcmp(laneToFeature(nID), targetFeature)
                result = true;
                return;
            end
            % Follow through ramp lanes
            if laneToFeature.isKey(nID) && strcmp(laneToFeature(nID), 'ramp')
                visited(end+1) = string(nID); %#ok<AGROW>
                currentID = nID;
                advanced = true;
                break;
            end
            % Also follow same-feature lanes (to traverse within feature)
            if laneIDToIdx.isKey(nID)
                nIdx = laneIDToIdx(nID);
                if lanes.TravelDirection(nIdx) == "Forward"
                    visited(end+1) = string(nID); %#ok<AGROW>
                    currentID = nID;
                    advanced = true;
                    break;
                end
            end
        end
        if ~advanced
            return;
        end
    end
end
% Copyright 2026 The MathWorks, Inc.
