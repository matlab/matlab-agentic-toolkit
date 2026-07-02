function laneTable = helperSurveyLanes(rrHDMap, options)
%helperSurveyLanes Filter and sort lanes from an HD Map by type, direction, and length.
%
%   laneTable = helperSurveyLanes(rrHDMap)
%   laneTable = helperSurveyLanes(rrHDMap, LaneType="Sidewalk", MinLength=50)
%
%   Returns a table sorted by length descending with columns:
%       Index, LaneID, Length, Direction, LaneType, StartPos, EndPos
%
% This is a helper function for example purposes and may be removed or
% modified in the future.

    arguments
        rrHDMap
        options.LaneType (1,1) string = "Driving"
        options.MinLength (1,1) double = 0
        options.TravelDirection (1,1) string = ""
        options.LaneIDs (:,1) string = ""
    end

    % Build lane ID filter set (empty means no filter)
    laneIDFilter = options.LaneIDs(options.LaneIDs ~= "");
    hasLaneIDFilter = ~isempty(laneIDFilter);

    allLanes = rrHDMap.Lanes;

    indices = [];
    laneIDs = {};
    lengths = [];
    directions = {};
    laneTypes = {};
    startPositions = {};
    endPositions = {};

    filtIdx = 0;
    for i = 1:numel(allLanes)
        lane = allLanes(i);

        if hasLaneIDFilter && ~ismember(string(lane.ID), laneIDFilter)
            continue;
        end
        if ~strcmpi(lane.LaneType, options.LaneType)
            continue;
        end
        if options.TravelDirection ~= "" && ~strcmpi(lane.TravelDirection, options.TravelDirection)
            continue;
        end

        geom = lane.Geometry;
        if size(geom, 1) < 2
            continue;
        end
        if size(geom, 2) == 2
            geom = [geom, zeros(size(geom, 1), 1)]; %#ok<AGROW>
        end

        laneLen = sum(sqrt(sum(diff(geom).^2, 2)));
        if laneLen < options.MinLength
            continue;
        end

        filtIdx = filtIdx + 1;
        indices(end+1) = filtIdx; %#ok<AGROW>
        laneIDs{end+1} = string(lane.ID); %#ok<AGROW>
        lengths(end+1) = round(laneLen, 2); %#ok<AGROW>
        directions{end+1} = string(lane.TravelDirection); %#ok<AGROW>
        laneTypes{end+1} = string(lane.LaneType); %#ok<AGROW>
        startPositions{end+1} = geom(1, :); %#ok<AGROW>
        endPositions{end+1} = geom(end, :); %#ok<AGROW>
    end

    if filtIdx == 0
        warning("helperSurveyLanes:NoLanes", ...
            "No lanes found matching filters (LaneType=%s, Direction=%s, MinLength=%.1f).", ...
            options.LaneType, options.TravelDirection, options.MinLength);
        laneTable = table();
        return;
    end

    laneTable = table( ...
        indices(:), ...
        vertcat(laneIDs{:}), ...
        lengths(:), ...
        vertcat(directions{:}), ...
        vertcat(laneTypes{:}), ...
        vertcat(startPositions{:}), ...
        vertcat(endPositions{:}), ...
        'VariableNames', {'Index', 'LaneID', 'Length', 'Direction', 'LaneType', 'StartPos', 'EndPos'});

    laneTable = sortrows(laneTable, 'Length', 'descend');
    laneTable.Index = (1:height(laneTable))';
end
% Copyright 2026 The MathWorks, Inc.
