function report = validateRRHD(rrMap)
%validateRRHD Validate a roadrunnerHDMap for structural correctness
%   report = validateRRHD(rrMap) checks for duplicate IDs, dangling
%   references, geometry issues, parametric span bounds, and type-instance
%   reference integrity. Run before write() as an enforcement gate.
%
%   Input:
%       rrMap - roadrunnerHDMap object to validate
%
%   Output:
%       report - Struct with fields:
%           .errors   - String array of blocking issues
%           .warnings - String array of non-blocking issues
%           .isValid  - Logical, true if no errors

% Copyright 2026 The MathWorks, Inc.

    arguments
        rrMap (1,1) roadrunnerHDMap
    end

    errors = string.empty;
    warnings = string.empty;

    % Check duplicate IDs across all entity types
    errors = checkDuplicateIDs(rrMap, errors);

    % Check geometry has >= 2 points
    errors = checkGeometry(rrMap, errors);

    % Check dangling references
    errors = checkDanglingReferences(rrMap, errors);

    % Check parametric spans within [0,1]
    errors = checkParametricSpans(rrMap, errors);

    % Check GeoReference within valid lat/lon bounds
    warnings = checkGeoReference(rrMap, warnings);

    report.errors = errors;
    report.warnings = warnings;
    report.isValid = isempty(errors);

    if nargout == 0, clear report; end
end

function errors = checkDuplicateIDs(rrMap, errors)
    allIDs = collectAllIDs(rrMap);
    [~, uniqueIdx] = unique(allIDs);
    duplicateIdx = setdiff(1:numel(allIDs), uniqueIdx);
    for i = 1:numel(duplicateIdx)
        errors(end + 1) = "Duplicate ID: " + allIDs(duplicateIdx(i)); %#ok<AGROW>
    end
end

function errors = checkGeometry(rrMap, errors)
    % Lanes
    for i = 1:numel(rrMap.Lanes)
        if size(rrMap.Lanes(i).Geometry, 1) < 2
            errors(end + 1) = sprintf("Lane %s has < 2 geometry points", rrMap.Lanes(i).ID); %#ok<AGROW>
        end
    end

    % LaneBoundaries
    for i = 1:numel(rrMap.LaneBoundaries)
        if size(rrMap.LaneBoundaries(i).Geometry, 1) < 2
            errors(end + 1) = sprintf("LaneBoundary %s has < 2 geometry points", rrMap.LaneBoundaries(i).ID); %#ok<AGROW>
        end
    end

    % Barriers
    for i = 1:numel(rrMap.Barriers)
        if size(rrMap.Barriers(i).Geometry, 1) < 2
            errors(end + 1) = sprintf("Barrier %s has < 2 geometry points", rrMap.Barriers(i).ID); %#ok<AGROW>
        end
    end
end

function errors = checkDanglingReferences(rrMap, errors)
    % Build ID sets for lookup
    boundaryIDs = collectIDs(rrMap.LaneBoundaries);
    laneIDs = collectIDs(rrMap.Lanes);

    % Lane -> boundary references
    for i = 1:numel(rrMap.Lanes)
        lane = rrMap.Lanes(i);
        leftRef = string(lane.LeftLaneBoundary.Reference.ID);
        if strlength(leftRef) > 0 && ~ismember(leftRef, boundaryIDs)
            errors(end + 1) = sprintf("Lane %s references missing left boundary %s", lane.ID, leftRef); %#ok<AGROW>
        end
        rightRef = string(lane.RightLaneBoundary.Reference.ID);
        if strlength(rightRef) > 0 && ~ismember(rightRef, boundaryIDs)
            errors(end + 1) = sprintf("Lane %s references missing right boundary %s", lane.ID, rightRef); %#ok<AGROW>
        end

        % Predecessor/Successor references
        for j = 1:numel(lane.Predecessors)
            predID = string(lane.Predecessors(j).Reference.ID);
            if strlength(predID) > 0 && ~ismember(predID, laneIDs)
                errors(end + 1) = sprintf("Lane %s references missing predecessor %s", lane.ID, predID); %#ok<AGROW>
            end
        end
        for j = 1:numel(lane.Successors)
            succID = string(lane.Successors(j).Reference.ID);
            if strlength(succID) > 0 && ~ismember(succID, laneIDs)
                errors(end + 1) = sprintf("Lane %s references missing successor %s", lane.ID, succID); %#ok<AGROW>
            end
        end
    end

    % Type-instance references (Signs, Barriers, etc.)
    errors = checkTypeReferences(rrMap.Signs, rrMap.SignTypes, "Sign", "SignType", errors);
    errors = checkTypeReferences(rrMap.Barriers, rrMap.BarrierTypes, "Barrier", "BarrierType", errors);
end

function errors = checkParametricSpans(rrMap, errors)
    for i = 1:numel(rrMap.LaneBoundaries)
        bnd = rrMap.LaneBoundaries(i);
        if ~isprop(bnd, "ParametricAttribution")
            continue
        end
        attribs = bnd.ParametricAttribution;
        for j = 1:numel(attribs)
            if attribs(j).Span(1) < 0 || attribs(j).Span(2) > 1
                errors(end + 1) = sprintf("LaneBoundary %s has parametric span outside [0,1]", bnd.ID); %#ok<AGROW>
                break
            end
        end
    end
end

function warnings = checkGeoReference(rrMap, warnings)
    if isprop(rrMap, "GeoReference") && ~isempty(rrMap.GeoReference)
        lat = rrMap.GeoReference(1);
        lon = rrMap.GeoReference(2);
        if lat < -90 || lat > 90
            warnings(end + 1) = sprintf("GeoReference latitude %f is out of [-90, 90]", lat);
        end
        if lon < -180 || lon > 180
            warnings(end + 1) = sprintf("GeoReference longitude %f is out of [-180, 180]", lon);
        end
    end
end

function allIDs = collectAllIDs(rrMap)
    allIDs = string.empty;
    allIDs = [allIDs, collectIDs(rrMap.Lanes)];
    allIDs = [allIDs, collectIDs(rrMap.LaneBoundaries)];
    allIDs = [allIDs, collectIDs(rrMap.LaneGroups)];
    if ~isempty(rrMap.Barriers)
        allIDs = [allIDs, collectIDs(rrMap.Barriers)];
    end
    if ~isempty(rrMap.Signs)
        allIDs = [allIDs, collectIDs(rrMap.Signs)];
    end
    if ~isempty(rrMap.Junctions)
        allIDs = [allIDs, collectIDs(rrMap.Junctions)];
    end
end

function ids = collectIDs(objects)
    n = numel(objects);
    ids = strings(1, n);
    for i = 1:n
        ids(i) = string(objects(i).ID);
    end
end

function errors = checkTypeReferences(instances, types, instanceLabel, typeLabel, errors)
    typeIDs = collectIDs(types);
    for i = 1:numel(instances)
        inst = instances(i);
        refField = typeLabel + "Reference";
        if isprop(inst, refField)
            refID = string(inst.(refField).ID);
            if strlength(refID) > 0 && ~ismember(refID, typeIDs)
                errors(end + 1) = sprintf("%s %s references missing %s %s", ...
                    instanceLabel, inst.ID, typeLabel, refID); %#ok<AGROW>
            end
        end
    end
end
