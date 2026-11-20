function laneNetwork = helperAnalyzeHDMapLanes(rrHDMap)
    % helperAnalyzeHDMapLanes - Build a lane connectivity model from a RoadRunner HD Map.
    %
    %   laneNetwork = helperAnalyzeHDMapLanes(rrHDMap)
    %
    %   Analyzes the HD Map to extract lateral adjacency (shared boundaries),
    %   longitudinal connectivity (predecessors/successors), and lane group
    %   membership. Returns a struct that enables topology-aware actor placement.
    %
    %   Output struct fields:
    %       .Lanes          - Table with columns: ID, GlobalIndex, LaneType,
    %                         TravelDirection, Length, LaneGroupID,
    %                         LeftBoundaryID, RightBoundaryID
    %       .LateralAdj     - Table with columns: LaneID_A, LaneID_B,
    %                         SharedBoundaryID, Relation ("A_right_of_B" or
    %                         "A_left_of_B")
    %       .LongitudinalAdj - Table with columns: FromLaneID, ToLaneID,
    %                          Relation ("successor" or "predecessor"),
    %                          Alignment
    %       .LaneGroups     - Table with columns: GroupID, LaneIDs (cell),
    %                         NumDrivingLanes
    %       .JunctionLaneIDs - Cell array of lane IDs that are inside junctions
    %       .JunctionPaths  - Struct array: ApproachLaneID, JunctionLaneIDs
    %                         (cell), ExitLaneID, ApproachHeading (1x2),
    %                         TotalLength. Pre-computed approach-to-exit
    %                         chains through junctions.
    %
    %   Key methods on the output:
    %       Use helperFindAdjacentLanes(laneNetwork, laneID) to get lateral neighbors.
    %       Use helperFindLanesOnSameRoad(laneNetwork, laneID) to get co-group lanes.
    %       Use helperCanCutIn(laneNetwork, fromLaneID, toLaneID) to check cut-in feasibility.
    %
    % This is a helper function for example purposes and may be removed or
    % modified in the future.

    % Copyright 2025-2026 The MathWorks, Inc.

    arguments
        rrHDMap (1,1)
    end

    allLanes = rrHDMap.Lanes;
    numLanes = numel(allLanes);

    %% Build lane info table
    laneIDs = strings(numLanes, 1);
    laneTypes = strings(numLanes, 1);
    travelDirs = strings(numLanes, 1);
    lengths = zeros(numLanes, 1);
    leftBndIDs = strings(numLanes, 1);
    rightBndIDs = strings(numLanes, 1);
    laneGroupIDs = strings(numLanes, 1);

    for i = 1:numLanes
        lane = allLanes(i);
        laneIDs(i) = string(lane.ID);
        laneTypes(i) = string(lane.LaneType);
        travelDirs(i) = string(lane.TravelDirection);

        % Compute lane length from geometry
        geom = lane.Geometry;
        if size(geom, 1) >= 2
            lengths(i) = sum(sqrt(sum(diff(geom).^2, 2)));
        end

        % Extract boundary IDs
        if ~isempty(lane.LeftLaneBoundary)
            leftBndIDs(i) = string(lane.LeftLaneBoundary.Reference.ID);
        end
        if ~isempty(lane.RightLaneBoundary)
            rightBndIDs(i) = string(lane.RightLaneBoundary.Reference.ID);
        end
    end

    %% Build lane group membership
    allGroups = rrHDMap.LaneGroups;
    numGroups = numel(allGroups);
    groupIDs = strings(numGroups, 1);
    groupLaneIDs = cell(numGroups, 1);
    numDrivingLanes = zeros(numGroups, 1);

    for g = 1:numGroups
        grp = allGroups(g);
        groupIDs(g) = string(grp.ID);
        memberIDs = strings(numel(grp.Lanes), 1);
        for m = 1:numel(grp.Lanes)
            memberIDs(m) = string(grp.Lanes(m).Reference.ID);
        end
        groupLaneIDs{g} = memberIDs;

        % Mark lanes with their group ID
        for m = 1:numel(memberIDs)
            idx = find(laneIDs == memberIDs(m), 1);
            if ~isempty(idx)
                laneGroupIDs(idx) = groupIDs(g);
            end
        end

        % Count driving lanes in group
        drivingCount = 0;
        for m = 1:numel(memberIDs)
            idx = find(laneIDs == memberIDs(m), 1);
            if ~isempty(idx) && strcmpi(laneTypes(idx), "Driving")
                drivingCount = drivingCount + 1;
            end
        end
        numDrivingLanes(g) = drivingCount;
    end

    %% Build lateral adjacency from shared boundaries
    % Two lanes are laterally adjacent if one's RightBoundary == other's LeftBoundary
    latAdjFrom = {};
    latAdjTo = {};
    latAdjBnd = {};
    latAdjRel = {};

    for i = 1:numLanes
        if rightBndIDs(i) == ""
            continue;
        end
        for j = 1:numLanes
            if i == j
                continue;
            end
            % Lane i's right boundary == Lane j's left boundary
            % means Lane j is to the right of Lane i
            if rightBndIDs(i) == leftBndIDs(j)
                latAdjFrom{end+1} = laneIDs(i); %#ok<AGROW>
                latAdjTo{end+1} = laneIDs(j); %#ok<AGROW>
                latAdjBnd{end+1} = rightBndIDs(i); %#ok<AGROW>
                latAdjRel{end+1} = "B_right_of_A"; %#ok<AGROW>
            end
        end
    end

    %% Build longitudinal connectivity from predecessors/successors
    longFrom = {};
    longTo = {};
    longRel = {};
    longAlign = {};

    for i = 1:numLanes
        lane = allLanes(i);

        % Successors
        if ~isempty(lane.Successors)
            for s = 1:numel(lane.Successors)
                longFrom{end+1} = laneIDs(i); %#ok<AGROW>
                longTo{end+1} = string(lane.Successors(s).Reference.ID); %#ok<AGROW>
                longRel{end+1} = "successor"; %#ok<AGROW>
                longAlign{end+1} = string(lane.Successors(s).Alignment); %#ok<AGROW>
            end
        end

        % Predecessors
        if ~isempty(lane.Predecessors)
            for p = 1:numel(lane.Predecessors)
                longFrom{end+1} = laneIDs(i); %#ok<AGROW>
                longTo{end+1} = string(lane.Predecessors(p).Reference.ID); %#ok<AGROW>
                longRel{end+1} = "predecessor"; %#ok<AGROW>
                longAlign{end+1} = string(lane.Predecessors(p).Alignment); %#ok<AGROW>
            end
        end
    end

    %% Identify junction lanes
    junctionLaneIDs = {};
    if ~isempty(rrHDMap.Junctions)
        for j = 1:numel(rrHDMap.Junctions)
            junc = rrHDMap.Junctions(j);
            if ~isempty(junc.Lanes)
                for lRef = 1:numel(junc.Lanes)
                    junctionLaneIDs{end+1} = string(junc.Lanes(lRef).ID); %#ok<AGROW>
                end
            end
        end
    end

    %% Compute junction paths (approach → junction connector → exit chains)
    junctionPaths = struct('ApproachLaneID', {}, 'JunctionLaneIDs', {}, ...
        'ExitLaneID', {}, 'ApproachHeading', {}, 'TotalLength', {}, ...
        'TravelDirection', {});

    if ~isempty(junctionLaneIDs)
        junctionSet = unique(string(junctionLaneIDs));
        minApproachLength = 30;
        for i = 1:numLanes
            if lengths(i) < minApproachLength || ismember(laneIDs(i), junctionSet)
                continue;
            end
            % Only consider driving lanes (both Forward and Backward)
            if ~strcmpi(laneTypes(i), "Driving")
                continue;
            end
            isBackward = strcmpi(travelDirs(i), "Backward");
            % For Forward lanes, follow Successors to reach junction.
            % For Backward lanes, follow Predecessors (travel-start is at
            % geometry-end, predecessor chain leads toward the junction).
            startID = laneIDs(i);
            currentID = startID;
            reachedJunction = false;
            juncGatewayIdx = [];
            for hop = 1:5
                hopIdx = find(laneIDs == currentID, 1);
                if isBackward
                    connectors = allLanes(hopIdx).Predecessors;
                else
                    connectors = allLanes(hopIdx).Successors;
                end
                if isempty(hopIdx) || isempty(connectors)
                    break;
                end
                % Check if any connected lane is a junction lane
                for s = 1:numel(connectors)
                    connID = string(connectors(s).Reference.ID);
                    if ismember(connID, junctionSet)
                        reachedJunction = true;
                        juncGatewayIdx = hopIdx;
                        break;
                    end
                end
                if reachedJunction
                    break;
                end
                % Follow first non-junction connected lane (intermediate)
                nextID = string(connectors(1).Reference.ID);
                if nextID == startID || ismember(nextID, junctionSet)
                    break;
                end
                currentID = nextID;
            end
            if ~reachedJunction
                continue;
            end
            % BFS through junction to find ALL reachable exit lanes
            geom = allLanes(i).Geometry;
            if size(geom, 1) >= 2
                if isBackward
                    % Backward lane: travel toward geometry-start, junction is at geometry-start
                    tailVec = geom(1, 1:2) - geom(min(end, 2), 1:2);
                else
                    tailVec = geom(end, 1:2) - geom(max(1, end-1), 1:2);
                end
                hdg = tailVec / max(norm(tailVec), 1e-6);
            else
                hdg = [1, 0];
            end
            % Collect all junction entry points from the gateway
            if isBackward
                gatewayConnectors = allLanes(juncGatewayIdx).Predecessors;
            else
                gatewayConnectors = allLanes(juncGatewayIdx).Successors;
            end
            entryIDs = strings(0, 1);
            for s = 1:numel(gatewayConnectors)
                sid = string(gatewayConnectors(s).Reference.ID);
                if ismember(sid, junctionSet)
                    entryIDs(end+1) = sid; %#ok<AGROW>
                end
            end
            % BFS from all entry points to find all non-junction exits.
            % For Backward approach lanes, traffic flows through junction
            % via Predecessors (not Successors) of each connector lane.
            visited = strings(0, 1);
            queue = cellstr(entryIDs);
            exitIDs = strings(0, 1);
            while ~isempty(queue)
                curr = string(queue{1});
                queue(1) = [];
                if ismember(curr, visited), continue; end
                visited(end+1) = curr; %#ok<AGROW>
                cIdx = find(laneIDs == curr, 1);
                if isempty(cIdx)
                    continue;
                end
                if isBackward
                    bfsConnectors = allLanes(cIdx).Predecessors;
                else
                    bfsConnectors = allLanes(cIdx).Successors;
                end
                if isempty(bfsConnectors)
                    continue;
                end
                for s = 1:numel(bfsConnectors)
                    nxt = string(bfsConnectors(s).Reference.ID);
                    if ~ismember(nxt, junctionSet)
                        if ~ismember(nxt, exitIDs)
                            exitIDs(end+1) = nxt; %#ok<AGROW>
                        end
                    elseif ~ismember(nxt, visited)
                        queue{end+1} = char(nxt); %#ok<AGROW>
                    end
                end
            end
            % Create one JunctionPath per unique exit
            for e = 1:numel(exitIDs)
                exitID = exitIDs(e);
                if exitID == startID, continue; end
                jp.ApproachLaneID = laneIDs(i);
                jp.JunctionLaneIDs = cellstr(visited);
                jp.ExitLaneID = exitID;
                jp.ApproachHeading = hdg;
                jp.TotalLength = lengths(i);
                jp.TravelDirection = travelDirs(i);
                junctionPaths(end+1) = jp; %#ok<AGROW>
            end
        end
    end

    %% Assemble output struct
    laneNetwork.Lanes = table(laneIDs, (1:numLanes)', laneTypes, travelDirs, ...
        lengths, laneGroupIDs, leftBndIDs, rightBndIDs, ...
        'VariableNames', {'ID', 'GlobalIndex', 'LaneType', 'TravelDirection', ...
        'Length', 'LaneGroupID', 'LeftBoundaryID', 'RightBoundaryID'});

    if ~isempty(latAdjFrom)
        laneNetwork.LateralAdj = table(latAdjFrom', latAdjTo', latAdjBnd', latAdjRel', ...
            'VariableNames', {'LaneID_A', 'LaneID_B', 'SharedBoundaryID', 'Relation'});
    else
        laneNetwork.LateralAdj = table('Size', [0 4], ...
            'VariableTypes', {'string', 'string', 'string', 'string'}, ...
            'VariableNames', {'LaneID_A', 'LaneID_B', 'SharedBoundaryID', 'Relation'});
    end

    if ~isempty(longFrom)
        laneNetwork.LongitudinalAdj = table(longFrom', longTo', longRel', longAlign', ...
            'VariableNames', {'FromLaneID', 'ToLaneID', 'Relation', 'Alignment'});
    else
        laneNetwork.LongitudinalAdj = table('Size', [0 4], ...
            'VariableTypes', {'string', 'string', 'string', 'string'}, ...
            'VariableNames', {'FromLaneID', 'ToLaneID', 'Relation', 'Alignment'});
    end

    laneNetwork.LaneGroups = table(groupIDs, groupLaneIDs, numDrivingLanes, ...
        'VariableNames', {'GroupID', 'LaneIDs', 'NumDrivingLanes'});

    laneNetwork.JunctionLaneIDs = unique(string(junctionLaneIDs));
    laneNetwork.JunctionPaths = junctionPaths;
    if nargout == 0
        clear laneNetwork   % no auto-display when called without an output
    end
end
