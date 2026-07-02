function sceneInfo = helperSceneAwareness(rrApp, options)
%helperSceneAwareness Complete scene analysis: export HD Map, survey lanes, recommend placements.
%
%   sceneInfo = helperSceneAwareness(rrApp)
%   sceneInfo = helperSceneAwareness(rrApp, NumActors=2, ScenarioType="cut-in")
%   sceneInfo = helperSceneAwareness(rrApp, RoadFeature="bridge")
%
%   Output struct fields:
%       .SceneName, .HDMap, .LaneTable, .NumForwardLanes, .MaxLaneLength,
%       .Recommendations (struct array), .Summary (formatted string),
%       .LaneNetwork (from helperAnalyzeHDMapLanes),
%       .RoadFeatures (from helperClassifyRoadFeatures),
%       .FilteredLaneIDs (lane IDs matching RoadFeature, or empty)
%
% This is a helper function for example purposes and may be removed or
% modified in the future.

    arguments
        rrApp
        options.NumActors (1,1) double = 2
        options.ScenarioType (1,1) string = "free-drive"
        options.MinLaneLength (1,1) double = 30
        options.TravelDirection (1,1) string = "Forward"
        options.RoadFeature (1,1) string = ""
    end

    % Ensure sibling helper scripts are on path
    if ~exist('helperSurveyLanes', 'file') || ~exist('helperGetPositionFromHDMap', 'file') ...
            || ~exist('helperAnalyzeHDMapLanes', 'file')
        addpath(fileparts(mfilename('fullpath')));
    end

    %% Step 1: Get current scene
    rrStatus = status(rrApp);
    sceneName = rrStatus.Scene.Filename;
    if isempty(sceneName) || sceneName == ""
        error("helperSceneAwareness:NoScene", ...
            "No scene is currently loaded. Open a scene first.");
    end

    %% Step 2: Export scene to HD Map
    exportPath = fullfile(tempdir, "scene_awareness_temp.rrhd");
    exportScene(rrApp, exportPath, "RoadRunner HD Map");

    fInfo = dir(exportPath);
    if fInfo.bytes < 500
        error("helperSceneAwareness:EmptyScene", ...
            "Scene '%s' has no road geometry.", sceneName);
    end

    %% Step 3: Load HD Map
    rrHDMap = roadrunnerHDMap();
    read(rrHDMap, exportPath);

    %% Step 4: Build lane network (connectivity + groups)
    laneNetwork = helperAnalyzeHDMapLanes(rrHDMap);
    roadFeatures = helperClassifyRoadFeatures(laneNetwork, rrHDMap);

    %% Step 5: Determine lane filter based on RoadFeature
    filteredLaneIDs = strings(0, 1);
    if options.RoadFeature ~= "" && ~isempty(roadFeatures)
        % Find lanes belonging to requested feature
        featureTable = roadFeatures.Features;
        featureRow = find(featureTable.Label == options.RoadFeature, 1);
        if ~isempty(featureRow)
            filteredLaneIDs = featureTable.LaneIDs{featureRow};
        else
            warning("helperSceneAwareness:FeatureNotFound", ...
                "Road feature '%s' not found. Available: %s", ...
                options.RoadFeature, strjoin(featureTable.Label, ", "));
        end
    end

    %% Step 6: Survey lanes (with optional feature filter)
    if ~isempty(filteredLaneIDs)
        laneTable = helperSurveyLanes(rrHDMap, ...
            TravelDirection=options.TravelDirection, ...
            LaneType="Driving", ...
            MinLength=options.MinLaneLength, ...
            LaneIDs=filteredLaneIDs);
    else
        laneTable = helperSurveyLanes(rrHDMap, ...
            TravelDirection=options.TravelDirection, ...
            LaneType="Driving", ...
            MinLength=options.MinLaneLength);
    end

    if isempty(laneTable) || height(laneTable) == 0
        if ~isempty(filteredLaneIDs)
            laneTable = helperSurveyLanes(rrHDMap, ...
                TravelDirection=options.TravelDirection, ...
                LaneType="Driving", MinLength=10, ...
                LaneIDs=filteredLaneIDs);
        else
            laneTable = helperSurveyLanes(rrHDMap, ...
                TravelDirection=options.TravelDirection, ...
                LaneType="Driving", MinLength=10);
        end
    end

    numForwardLanes = height(laneTable);
    maxLaneLength = 0;
    if numForwardLanes > 0
        maxLaneLength = max(laneTable.Length);
    end

    %% Step 7: Compute placement recommendations
    recommendations = computeRecommendations(rrHDMap, numForwardLanes, ...
        options.NumActors, options.ScenarioType, options.TravelDirection, ...
        filteredLaneIDs);

    %% Assemble output
    sceneInfo.SceneName = sceneName;
    sceneInfo.HDMap = rrHDMap;
    sceneInfo.LaneTable = laneTable;
    sceneInfo.NumForwardLanes = numForwardLanes;
    sceneInfo.MaxLaneLength = maxLaneLength;
    sceneInfo.Recommendations = recommendations;
    sceneInfo.LaneNetwork = laneNetwork;
    sceneInfo.RoadFeatures = roadFeatures;
    sceneInfo.FilteredLaneIDs = filteredLaneIDs;

    %% Build summary
    lines = strings(0, 1);
    lines(end+1) = sprintf("Scene: %s", sceneName);

    % Show road features if detected
    if ~isempty(roadFeatures)
        lines(end+1) = roadFeatures.Summary;
    end

    if options.RoadFeature ~= "" && ~isempty(filteredLaneIDs)
        lines(end+1) = sprintf("Filtered to: %s (%d lanes)", options.RoadFeature, numel(filteredLaneIDs));
    end

    lines(end+1) = sprintf("Forward driving lanes: %d (max length: %.1fm)", numForwardLanes, maxLaneLength);

    if numForwardLanes > 0
        showCount = min(5, numForwardLanes);
        lines(end+1) = "Top lanes:";
        for i = 1:showCount
            lines(end+1) = sprintf("  Lane %d: %.1fm, start=[%.1f,%.1f,%.1f]", ...
                i, laneTable.Length(i), ...
                laneTable.StartPos(i,1), laneTable.StartPos(i,2), laneTable.StartPos(i,3)); %#ok<AGROW>
        end
    end

    if ~isempty(recommendations)
        lines(end+1) = sprintf("Placements (%s):", options.ScenarioType);
        for i = 1:numel(recommendations)
            r = recommendations(i);
            lines(end+1) = sprintf("  %s: lane %d @ %.0f%% -> [%.1f, %.1f, %.1f]", ...
                r.ActorRole, r.LaneIndex, r.Fraction*100, ...
                r.Position(1), r.Position(2), r.Position(3)); %#ok<AGROW>
        end
    end

    sceneInfo.Summary = strjoin(lines, newline);
    fprintf("%s\n", sceneInfo.Summary);
end


function recommendations = computeRecommendations(rrHDMap, numLanes, numActors, scenarioType, travelDir, filteredLaneIDs)
%computeRecommendations Generate actor placement positions based on scenario type.

    recommendations = struct('ActorRole', {}, 'LaneIndex', {}, 'Fraction', {}, ...
        'Position', {}, 'Heading', {});

    if numLanes == 0
        return;
    end

    switch scenarioType
        case "cut-in"
            % Find adjacent parallel lanes (required for cut-in)
            [egoIdx, targetIdx] = findParallelLanes(rrHDMap, numLanes, travelDir, filteredLaneIDs);
            recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", egoIdx, 0.1, filteredLaneIDs);
            recommendations = addRec(recommendations, rrHDMap, travelDir, "target", targetIdx, 0.2, filteredLaneIDs);
            for k = 3:numActors
                recommendations = addRec(recommendations, rrHDMap, travelDir, ...
                    sprintf("target%d", k-1), min(k, numLanes), 0.1 + (k-2)*0.1, filteredLaneIDs);
            end

        case "following"
            % Same-lane placement: all actors on lane 1, safe fractions (>= 0.2)
            recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", 1, 0.2, filteredLaneIDs);
            for k = 2:numActors
                recommendations = addRec(recommendations, rrHDMap, travelDir, ...
                    sprintf("target%d", k-1), 1, min(0.2 + (k-1)*0.15, 0.8), filteredLaneIDs);
            end

        case "pedestrian"
            recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", 1, 0.1, filteredLaneIDs);
            for k = 2:numActors
                recommendations = addRec(recommendations, rrHDMap, travelDir, ...
                    sprintf("pedestrian%d", k-1), 1, 0.3 + (k-2)*0.15, filteredLaneIDs);
            end

        case "intersection"
            recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", 1, 0.1, filteredLaneIDs);
            for k = 2:numActors
                laneIdx = min(k, numLanes);
                recommendations = addRec(recommendations, rrHDMap, travelDir, ...
                    sprintf("target%d", k-1), laneIdx, 0.1, filteredLaneIDs);
            end

        otherwise % "free-drive", "overtake", or unrecognized
            recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", 1, 0.1, filteredLaneIDs);
            for k = 2:numActors
                laneIdx = min(k, numLanes);
                frac = min(0.1 + (k-1)*0.15, 0.9);
                recommendations = addRec(recommendations, rrHDMap, travelDir, ...
                    sprintf("target%d", k-1), laneIdx, frac, filteredLaneIDs);
            end
    end
end


function [egoIdx, targetIdx] = findParallelLanes(rrHDMap, numLanes, travelDir, filteredLaneIDs)
%findParallelLanes Find two adjacent parallel lanes suitable for cut-in.
%   Checks heading alignment (dot > 0.95) and lateral distance (< 10m).
%   Falls back to lanes 1 and 2 if no parallel pair is found.

    bestScore = 0;
    egoIdx = 1;
    targetIdx = min(2, numLanes);
    searchLimit = min(numLanes, 12);

    laneIDArgs = {};
    if ~isempty(filteredLaneIDs)
        laneIDArgs = {"LaneIDs", filteredLaneIDs};
    end

    for i = 1:searchLimit
        try
            [posI, hdgI] = helperGetPositionFromHDMap(rrHDMap, i, 0.5, ...
                "TravelDirection", travelDir, "LaneType", "Driving", "MinLength", 50, ...
                laneIDArgs{:});
        catch
            continue;
        end
        hdgI2D = hdgI(1:2) / norm(hdgI(1:2));

        for j = (i+1):searchLimit
            try
                [posJ, hdgJ] = helperGetPositionFromHDMap(rrHDMap, j, 0.5, ...
                    "TravelDirection", travelDir, "LaneType", "Driving", "MinLength", 50, ...
                    laneIDArgs{:});
            catch
                continue;
            end
            hdgJ2D = hdgJ(1:2) / norm(hdgJ(1:2));

            alignment = abs(dot(hdgI2D, hdgJ2D));
            lateralDist = norm(posI(1:2) - posJ(1:2));

            if alignment > 0.95 && lateralDist < 10
                % Score by combined lane length (prefer longer lanes)
                score = alignment * (1 / max(lateralDist, 1));
                if score > bestScore
                    bestScore = score;
                    egoIdx = i;
                    targetIdx = j;
                end
            end
        end
    end

    if bestScore == 0
        warning("helperSceneAwareness:NoParallelLanes", ...
            "No adjacent parallel lanes found. Using lanes 1 and 2 (verify manually).");
    end
end


function recommendations = addRec(recommendations, rrHDMap, travelDir, role, laneIdx, fraction, filteredLaneIDs)
%addRec Add one placement recommendation by querying the HD Map.
    laneIDArgs = {};
    if ~isempty(filteredLaneIDs)
        laneIDArgs = {"LaneIDs", filteredLaneIDs};
    end

    try
        [pos, hdg] = helperGetPositionFromHDMap(rrHDMap, laneIdx, fraction, ...
            "TravelDirection", travelDir, "LaneType", "Driving", "MinLength", 10, ...
            laneIDArgs{:});
        rec.ActorRole = role;
        rec.LaneIndex = laneIdx;
        rec.Fraction = fraction;
        rec.Position = pos;
        rec.Heading = hdg;
        recommendations(end+1) = rec;
    catch ME
        warning("helperSceneAwareness:PlacementFailed", ...
            "Could not compute position for %s: %s", role, ME.message);
    end
end
% Copyright 2026 The MathWorks, Inc.
