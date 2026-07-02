function [actors, placementReport] = helperPlaceActors(rrs, rrprj, phaseLogic, rrHDMap, actorSpecs)
%helperPlaceActors Batch place, anchor, and verify multiple actors.
%
%   [actors, report] = helperPlaceActors(rrs, rrprj, phaseLogic, rrHDMap, actorSpecs)
%
%   actorSpecs is a struct array with fields:
%       .Name           - string (e.g., "Ego")
%       .AssetPath      - string (e.g., "Vehicles/Sedan.fbx")
%       .AssetType      - string ("VehicleAsset" or "CharacterAsset")
%       .LaneIndex      - integer (rank by length, 1=longest within filter)
%       .Fraction       - double [0,1] (position along lane)
%       .Speed          - double (m/s)
%   Optional fields:
%       .TravelDirection - string (default "Forward")
%       .LateralOffset   - double in meters (default 0)
%       .FilterLaneIDs   - string array of lane IDs to restrict placement to
%
%   Returns:
%       actors - cell array of actor handles
%       placementReport - struct with .AllValid, .Details, .Summary
%
% This is a helper function for example purposes and may be removed or
% modified in the future.

    arguments
        rrs
        rrprj
        phaseLogic
        rrHDMap
        actorSpecs (1,:) struct
    end

    % Ensure sibling helper scripts are on path
    if ~exist('helperGetPositionFromHDMap', 'file')
        addpath(fileparts(mfilename('fullpath')));
    end

    numActors = numel(actorSpecs);
    actors = cell(1, numActors);
    details = struct('Name', {}, 'Position', {}, 'Status', {}, 'Message', {});
    assetCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
    allValid = true;

    for i = 1:numActors
        spec = actorSpecs(i);

        % Defaults for optional fields
        if ~isfield(spec, 'TravelDirection') || isempty(spec.TravelDirection)
            spec.TravelDirection = "Forward";
        end
        if ~isfield(spec, 'LateralOffset') || isempty(spec.LateralOffset)
            spec.LateralOffset = 0;
        end
        if ~isfield(spec, 'FilterLaneIDs')
            spec.FilterLaneIDs = "";
        end

        detail.Name = spec.Name;
        detail.Position = [0, 0, 0];
        detail.Status = "FAIL";
        detail.Message = "";

        try
            % Get position from HD Map (with optional lane ID filter)
            laneIDArgs = {};
            filterIDs = string(spec.FilterLaneIDs);
            filterIDs = filterIDs(filterIDs ~= "");
            if ~isempty(filterIDs)
                laneIDArgs = {"LaneIDs", filterIDs};
            end
            [position, ~] = helperGetPositionFromHDMap(rrHDMap, ...
                spec.LaneIndex, spec.Fraction, ...
                "TravelDirection", spec.TravelDirection, ...
                "LaneType", "Driving", ...
                "Offset", spec.LateralOffset, ...
                "MinLength", 10, ...
                laneIDArgs{:});

            % Get or cache asset
            assetKey = char(spec.AssetPath + "|" + spec.AssetType);
            if assetCache.isKey(assetKey)
                asset = assetCache(assetKey);
            else
                asset = getAsset(rrprj, spec.AssetPath, spec.AssetType);
                assetCache(assetKey) = asset;
            end

            % Place actor and anchor
            actor = addActor(rrs, asset, position);
            actor.Name = spec.Name;
            autoAnchor(actor.InitialPoint);

            % Set initial speed
            initPhase = initialPhaseForActor(phaseLogic, actor);
            initPhase.Actions(1).Speed = spec.Speed;

            % Verify placement — WorldPosition must not be [0,0,0]
            worldPos = actor.InitialPoint.WorldPosition;
            if norm(worldPos(1:2)) < 0.01
                detail.Status = "FAIL";
                detail.Message = "autoAnchor failed — WorldPosition is [0,0,0].";
                allValid = false;
            else
                detail.Status = "OK";
                detail.Message = "Placed and verified.";
            end

            detail.Position = worldPos;
            actors{i} = actor;

        catch ME
            detail.Status = "FAIL";
            detail.Message = sprintf("Error: %s", ME.message);
            allValid = false;
            actors{i} = [];
        end

        details(end+1) = detail; %#ok<AGROW>
    end

    %% Check for bounding box overlaps between placed actors
    minSeparation = 6.0;  % meters (sedan ~4.7m + 1.3m buffer)
    overlapWarnings = strings(0, 1);
    for i = 1:numActors
        if isempty(details(i).Position) || all(details(i).Position == 0)
            continue;
        end
        for j = (i+1):numActors
            if isempty(details(j).Position) || all(details(j).Position == 0)
                continue;
            end
            dist = norm(details(i).Position - details(j).Position);
            if dist < minSeparation
                overlapWarnings(end+1) = sprintf( ...
                    "WARNING: %s and %s are %.1fm apart (min safe: %.1fm) — bounding boxes may overlap", ...
                    details(i).Name, details(j).Name, dist, minSeparation); %#ok<AGROW>
                allValid = false;
                details(i).Status = "OVERLAP";
                details(j).Status = "OVERLAP";
            end
        end
    end

    %% Build report
    placementReport.AllValid = allValid;
    placementReport.Details = details;

    lines = strings(0, 1);
    lines(end+1) = sprintf("Placement: %d actors, AllValid=%s", numActors, string(allValid));
    for i = 1:numel(details)
        d = details(i);
        lines(end+1) = sprintf("  [%s] %s: [%.1f,%.1f,%.1f] %s", ...
            d.Status, d.Name, d.Position(1), d.Position(2), d.Position(3), d.Message); %#ok<AGROW>
    end
    for w = 1:numel(overlapWarnings)
        lines(end+1) = overlapWarnings(w); %#ok<AGROW>
    end
    placementReport.Summary = strjoin(lines, newline);
    fprintf("%s\n", placementReport.Summary);
end
% Copyright 2026 The MathWorks, Inc.
