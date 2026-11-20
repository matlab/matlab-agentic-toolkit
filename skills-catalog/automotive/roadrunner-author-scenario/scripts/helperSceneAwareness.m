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

    % Clean up temp file
    if exist(exportPath, 'file')
        delete(exportPath);
    end

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
    % For crossing scenarios, include both Forward and Backward lanes
    surveyDir = options.TravelDirection;
    if options.ScenarioType == "crossing"
        surveyDir = "";
    end

    if ~isempty(filteredLaneIDs)
        laneTable = helperSurveyLanes(rrHDMap, ...
            TravelDirection=surveyDir, ...
            LaneType="Driving", ...
            MinLength=options.MinLaneLength, ...
            LaneIDs=filteredLaneIDs);
    else
        laneTable = helperSurveyLanes(rrHDMap, ...
            TravelDirection=surveyDir, ...
            LaneType="Driving", ...
            MinLength=options.MinLaneLength);
    end

    retryWarning = "";
    if isempty(laneTable) || height(laneTable) == 0
        retryWarning = sprintf("WARNING: No lanes found with MinLaneLength=%d. Retried with MinLaneLength=10.", options.MinLaneLength);
        if ~isempty(filteredLaneIDs)
            laneTable = helperSurveyLanes(rrHDMap, ...
                TravelDirection=surveyDir, ...
                LaneType="Driving", MinLength=10, ...
                LaneIDs=filteredLaneIDs);
        else
            laneTable = helperSurveyLanes(rrHDMap, ...
                TravelDirection=surveyDir, ...
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
        filteredLaneIDs, laneNetwork);

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
    if retryWarning ~= ""
        lines(end+1) = retryWarning;
    end

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
            if ~isempty(r.ExitPosition)
                lines(end+1) = sprintf("  %s: lane %d @ %.0f%% -> [%.1f, %.1f, %.1f], exit -> [%.1f, %.1f, %.1f]", ...
                    r.ActorRole, r.LaneIndex, r.Fraction*100, ...
                    r.Position(1), r.Position(2), r.Position(3), ...
                    r.ExitPosition(1), r.ExitPosition(2), r.ExitPosition(3)); %#ok<AGROW>
            else
                lines(end+1) = sprintf("  %s: lane %d @ %.0f%% -> [%.1f, %.1f, %.1f]", ...
                    r.ActorRole, r.LaneIndex, r.Fraction*100, ...
                    r.Position(1), r.Position(2), r.Position(3)); %#ok<AGROW>
            end
        end
    end

    sceneInfo.Summary = strjoin(lines, newline);
    fprintf("%s\n", sceneInfo.Summary);
    if nargout == 0
        clear sceneInfo   % no auto-display when called without an output
    end
end


function recommendations = computeRecommendations(rrHDMap, numLanes, numActors, scenarioType, travelDir, filteredLaneIDs, laneNetwork)
%computeRecommendations Generate actor placement positions based on scenario type.

    recommendations = struct('ActorRole', {}, 'LaneIndex', {}, 'Fraction', {}, ...
        'Position', {}, 'Heading', {}, 'ExitLaneID', {}, 'ExitPosition', {});

    if numLanes == 0
        return;
    end

    switch scenarioType
        case "cut-in"
            % Find adjacent parallel lanes (required for cut-in)
            [egoIdx, targetIdx] = findParallelLanes(rrHDMap, numLanes, travelDir, filteredLaneIDs);
            % Fractions stay within 0.2-0.8 (constraint #19); extra actors share the same two lanes
            recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", egoIdx, 0.2, filteredLaneIDs);
            recommendations = addRec(recommendations, rrHDMap, travelDir, "target", targetIdx, 0.3, filteredLaneIDs);
            pairLanes = [egoIdx, targetIdx];
            for k = 3:numActors
                recommendations = addRec(recommendations, rrHDMap, travelDir, ...
                    sprintf("target%d", k-1), pairLanes(mod(k-1, 2) + 1), min(0.3 + (k-2)*0.15, 0.8), filteredLaneIDs);
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

        case "crossing"
            % Find two approach lanes on different junction arms with crossing routes
            if ~isempty(laneNetwork) && isfield(laneNetwork, 'JunctionPaths') ...
                    && numel(laneNetwork.JunctionPaths) >= 2
                jPaths = laneNetwork.JunctionPaths;
                % Precompute exit headings for all paths
                exitHdgs = zeros(numel(jPaths), 2);
                for kk = 1:numel(jPaths)
                    eIdx = find(string({rrHDMap.Lanes.ID}') == jPaths(kk).ExitLaneID, 1);
                    if ~isempty(eIdx)
                        eGeom = rrHDMap.Lanes(eIdx).Geometry;
                        eVec = eGeom(end,1:2) - eGeom(1,1:2);
                        exitHdgs(kk,:) = eVec / max(norm(eVec), 1e-6);
                    end
                end
                % Find pair: approach angles differ AND exit directions differ
                bestPair = [1, 2];
                bestScore = 0;
                for ii = 1:numel(jPaths)
                    for jj = (ii+1):numel(jPaths)
                        relAngle = acosd(abs(dot(jPaths(ii).ApproachHeading, ...
                            jPaths(jj).ApproachHeading)));
                        if relAngle <= 45
                            continue;
                        end
                        exitAngle = acosd(abs(dot(exitHdgs(ii,:), exitHdgs(jj,:))));
                        if exitAngle <= 30
                            continue;
                        end
                        score = 1 - abs(relAngle - 90) / 90;
                        if score > bestScore
                            bestScore = score;
                            bestPair = [ii, jj];
                        end
                    end
                end
                % Place actors using LaneIDs filter to target specific approach lanes
                path1 = jPaths(bestPair(1));
                path2 = jPaths(bestPair(2));
                % Use each path's own TravelDirection for correct sampling
                pathDir1 = string(path1.TravelDirection);
                pathDir2 = string(path2.TravelDirection);
                recommendations = addRec(recommendations, rrHDMap, pathDir1, "ego", 1, 0.4, path1.ApproachLaneID);
                if ~isempty(recommendations)
                    recommendations(end).ExitLaneID = path1.ExitLaneID;
                    try
                        [exitPos1, ~] = helperGetPositionFromHDMap(rrHDMap, 1, 0.3, ...
                            "LaneIDs", path1.ExitLaneID, "TravelDirection", pathDir1, ...
                            "LaneType", "Driving", "MinLength", 5);
                        recommendations(end).ExitPosition = exitPos1;
                    catch
                        recommendations(end).ExitPosition = [];
                    end
                end
                recommendations = addRec(recommendations, rrHDMap, pathDir2, "target", 1, 0.4, path2.ApproachLaneID);
                if ~isempty(recommendations) && numel(recommendations) >= 2
                    recommendations(end).ExitLaneID = path2.ExitLaneID;
                    try
                        [exitPos2, ~] = helperGetPositionFromHDMap(rrHDMap, 1, 0.3, ...
                            "LaneIDs", path2.ExitLaneID, "TravelDirection", pathDir2, ...
                            "LaneType", "Driving", "MinLength", 5);
                        recommendations(end).ExitPosition = exitPos2;
                    catch
                        recommendations(end).ExitPosition = [];
                    end
                end
            else
                % No junction paths available — fall back to intersection placement
                recommendations = addRec(recommendations, rrHDMap, travelDir, "ego", 1, 0.3, filteredLaneIDs);
                recommendations = addRec(recommendations, rrHDMap, travelDir, "target", min(2, numLanes), 0.3, filteredLaneIDs);
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
%   Lanes are adjacent when the midpoint of one lies one lane width (2-5.5 m) from
%   the nearest point on the other, with headings aligned (dot > 0.95). Comparing
%   midpoint to midpoint misses adjacent lanes of different lengths. Prefers the pair
%   with the longest shorter lane. Falls back to lanes 1 and 2 if no pair is found.

    bestScore = 0;
    egoIdx = 1;
    targetIdx = min(2, numLanes);
    searchLimit = min(numLanes, 20);

    laneIDArgs = {};
    if ~isempty(filteredLaneIDs)
        laneIDArgs = {"LaneIDs", filteredLaneIDs};
    end

    mids = nan(searchLimit, 2); hdgs = nan(searchLimit, 2);
    geoms = cell(searchLimit, 1); lens = zeros(searchLimit, 1);
    for i = 1:searchLimit
        try
            [pos, hdg, info] = helperGetPositionFromHDMap(rrHDMap, i, 0.5, ...
                "TravelDirection", travelDir, "LaneType", "Driving", "MinLength", 30, ...
                laneIDArgs{:});
        catch
            continue;
        end
        mids(i, :) = pos(1:2);
        hdgs(i, :) = hdg(1:2) / norm(hdg(1:2));
        geoms{i} = info.Geometry(:, 1:2);
        lens(i) = sum(vecnorm(diff(geoms{i}), 2, 2));
    end

    for i = 1:searchLimit
        for j = (i+1):searchLimit
            if isempty(geoms{i}) || isempty(geoms{j})
                continue;
            end
            [gap, alignment] = gapToLane(mids(i, :), hdgs(i, :), geoms{j});
            if alignment > 0.95 && gap >= 2 && gap <= 5.5
                score = min(lens(i), lens(j));   % usable side-by-side length
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
            "No adjacent parallel lanes found among lanes >= MinLaneLength. Using lanes 1 and 2 (verify manually). " + ...
            "Roads are split into short HD-map pieces: lower MinLaneLength and chain pieces through " + ...
            "LaneNetwork.LongitudinalAdj successors for longer stretches (references/lane-connectivity.md).");
    end
end


function [gap, alignment] = gapToLane(point, heading, laneGeom)
%gapToLane Distance from a point to a lane polyline, and heading alignment there.
%   A closest point at either end of the polyline does not count as side by side.
    [gap, k] = min(vecnorm(laneGeom - point, 2, 2));
    n = size(laneGeom, 1);
    if n < 3 || k == 1 || k == n
        gap = inf; alignment = 0;
        return;
    end
    seg = laneGeom(k + 1, :) - laneGeom(k - 1, :);
    alignment = abs(dot(heading, seg / max(norm(seg), 1e-6)));
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
        rec.ExitLaneID = "";
        rec.ExitPosition = [];
        recommendations(end+1) = rec;
    catch ME
        warning("helperSceneAwareness:PlacementFailed", ...
            "Could not compute position for %s: %s", role, ME.message);
    end
end
% Copyright 2026 The MathWorks, Inc.
