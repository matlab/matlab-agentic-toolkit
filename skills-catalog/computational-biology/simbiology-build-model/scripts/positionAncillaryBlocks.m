function nPositioned = positionAncillaryBlocks(model, options)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% POSITIONANCILLARYBLOCKS Position rule and parameter blocks outside the
% model bounding box, distributed vertically near their referenced compartments.
%
%   nPositioned = positionAncillaryBlocks(model)
%   nPositioned = positionAncillaryBlocks(model, 'PairGap', 30, ...)
%
%   Groups rule-parameter pairs and positions them to the right of the
%   entire model bounding box (compartments + reactions), at vertical
%   positions corresponding to the compartments they reference. This avoids
%   overlap with compartments and inter-compartment reaction nodes while
%   keeping connection lines short and non-crossing.
%
%   Name-Value Options:
%     PairGap     - Horizontal gap between paired rule/param blocks (30)
%     Margin      - Gap from model right edge to first block column (60)
%     BlockSize   - [width height] for positioned blocks ([20 20])
%     StackGap    - Vertical gap between blocks at the same Y-band (40)
%
%   Returns the number of blocks that were repositioned.
%
%   See also: repositionAllReactions, checkDiagramLayout

    arguments
        model
        options.PairGap (1,1) double = 30
        options.Margin (1,1) double = 60
        options.BlockSize (1,2) double = [20 20]
        options.StackGap (1,1) double = 40
    end

    nPositioned = 0;

    % Compute full model bounding box (compartments + reactions)
    [modelRight, ~, compCenters] = computeModelExtent(model);

    if modelRight == 0
        return
    end

    % Collect rule-parameter pairs and orphan parameters
    [pairs, orphans] = collectAncillaryGroups(model);

    if isempty(pairs) && isempty(orphans)
        return
    end

    % Anchor column X: to the right of everything
    colX = modelRight + options.Margin;

    % Assign each group a target Y based on referenced compartment centroids
    % Track used Y-slots to prevent vertical overlap
    usedSlots = []; % [y_center] values already taken

    % Position rule-parameter pairs
    for i = 1:numel(pairs)
        pair = pairs{i};
        targetY = computeTargetY(pair.compartments, compCenters);
        actualY = resolveSlot(targetY, usedSlots, options.StackGap, options.BlockSize(2));
        usedSlots(end+1) = actualY; %#ok<AGROW>

        % Rule block
        rulePos = [colX, actualY, options.BlockSize(1), options.BlockSize(2)];
        try
            simbio.diagram.setBlock(pair.ruleHandle, 'Position', rulePos);
            nPositioned = nPositioned + 1;
        catch
        end

        % Parameter block beside it
        paramPos = [colX + options.BlockSize(1) + options.PairGap, actualY, ...
                    options.BlockSize(1), options.BlockSize(2)];
        try
            simbio.diagram.setBlock(pair.paramHandle, 'Position', paramPos);
            nPositioned = nPositioned + 1;
        catch
        end
    end

    % Position orphan parameters
    for i = 1:numel(orphans)
        orph = orphans{i};
        targetY = computeTargetY(orph.compartments, compCenters);
        actualY = resolveSlot(targetY, usedSlots, options.StackGap, options.BlockSize(2));
        usedSlots(end+1) = actualY; %#ok<AGROW>

        paramPos = [colX, actualY, options.BlockSize(1), options.BlockSize(2)];
        try
            simbio.diagram.setBlock(orph.handle, 'Position', paramPos);
            nPositioned = nPositioned + 1;
        catch
        end
    end

    if nPositioned > 0
        fprintf('positionAncillaryBlocks: %d block(s) positioned at x=%d, spread across y=%d..%d.\n', ...
            nPositioned, round(colX), round(min(usedSlots)), round(max(usedSlots)));
    end
end

%% Helper: Compute full model extent and compartment centers
function [modelRight, modelBottom, compCenters] = computeModelExtent(model)
    modelRight = 0;
    modelBottom = 0;
    compCenters = containers.Map();

    % Compartments
    for c = 1:numel(model.Compartments)
        pos = simbio.diagram.getBlock(model.Compartments(c), 'Position');
        modelRight = max(modelRight, pos(1) + pos(3));
        modelBottom = max(modelBottom, pos(2) + pos(4));
        compCenters(model.Compartments(c).Name) = pos(2) + pos(4)/2;
    end

    % Reactions (they may extend beyond compartments in gaps)
    for r = 1:numel(model.Reactions)
        try
            pos = simbio.diagram.getBlock(model.Reactions(r), 'Position');
            modelRight = max(modelRight, pos(1) + pos(3));
            modelBottom = max(modelBottom, pos(2) + pos(4));
        catch
        end
    end
end

%% Helper: Compute target Y from referenced compartment centroids
function targetY = computeTargetY(refComps, compCenters)
    if isempty(refComps)
        % No affinity — use middle of model
        allValues = cell2mat(compCenters.values());
        if isempty(allValues)
            targetY = 100;
        else
            targetY = mean(allValues);
        end
        return
    end

    ys = [];
    for i = 1:numel(refComps)
        if compCenters.isKey(refComps{i})
            ys(end+1) = compCenters(refComps{i}); %#ok<AGROW>
        end
    end

    if isempty(ys)
        allValues = cell2mat(compCenters.values());
        targetY = mean(allValues);
    else
        targetY = mean(ys);
    end
end

%% Helper: Resolve vertical slot to avoid overlap with already-placed blocks
function actualY = resolveSlot(targetY, usedSlots, stackGap, blockHeight)
    actualY = round(targetY - blockHeight/2);

    if isempty(usedSlots)
        return
    end

    % Check for conflicts and nudge if needed
    maxAttempts = 20;
    for attempt = 1:maxAttempts
        conflict = false;
        for s = 1:numel(usedSlots)
            if abs(actualY - usedSlots(s)) < stackGap
                conflict = true;
                break
            end
        end
        if ~conflict
            return
        end
        % Nudge down
        actualY = actualY + stackGap;
    end
end

%% Helper: Collect rule-parameter pairs and orphan parameters
function [pairs, orphans] = collectAncillaryGroups(model)
    pairs = {};
    orphans = {};
    pairedParamNames = {};

    % Find rule-parameter pairs
    for i = 1:numel(model.Rules)
        try
            simbio.diagram.getBlock(model.Rules(i), 'Position');
        catch
            continue
        end

        blk = simbio.diagram.getBlock(model.Rules(i));
        conn = blk.Connections;
        if isempty(conn)
            continue
        end

        paramHandle = conn(1);
        paramName = paramHandle.Name;

        try
            simbio.diagram.getBlock(paramHandle, 'Position');
        catch
            continue
        end

        refComps = parseRuleCompartments(model, model.Rules(i).Rule);

        pairs{end+1} = struct('ruleHandle', model.Rules(i), ...
            'paramHandle', paramHandle, ...
            'paramName', paramName, ...
            'compartments', {refComps}); %#ok<AGROW>
        pairedParamNames{end+1} = paramName; %#ok<AGROW>
    end

    % Find orphan parameters (have diagram blocks but not paired with a rule)
    for i = 1:numel(model.Parameters)
        try
            simbio.diagram.getBlock(model.Parameters(i), 'Position');
        catch
            continue
        end

        if ismember(model.Parameters(i).Name, pairedParamNames)
            continue
        end

        refComps = findParamCompartmentAffinity(model, model.Parameters(i));

        orphans{end+1} = struct('handle', model.Parameters(i), ...
            'name', model.Parameters(i).Name, ...
            'compartments', {refComps}); %#ok<AGROW>
    end
end

%% Helper: Parse compartment references from a rule expression
function refComps = parseRuleCompartments(model, ruleStr)
    tokens = regexp(ruleStr, '(\w+)\.\w+', 'tokens');
    refComps = {};
    for j = 1:numel(tokens)
        name = tokens{j}{1};
        if ~isempty(sbioselect(model, 'Type', 'compartment', 'Name', name))
            refComps{end+1} = name; %#ok<AGROW>
        end
    end
    refComps = unique(refComps);
end

%% Helper: Find compartment affinity for orphan parameters
function refComps = findParamCompartmentAffinity(model, param)
    refComps = {};
    paramName = param.Name;

    % Search events for references to this parameter
    for i = 1:numel(model.Events)
        ev = model.Events(i);
        trigger = ev.Trigger;
        actions = ev.EventFcns;

        allText = trigger;
        for a = 1:numel(actions)
            allText = [allText ' ' actions{a}]; %#ok<AGROW>
        end

        if ~contains(allText, paramName)
            continue
        end

        tokens = regexp(allText, '(\w+)\.\w+', 'tokens');
        for j = 1:numel(tokens)
            name = tokens{j}{1};
            if ~isempty(sbioselect(model, 'Type', 'compartment', 'Name', name))
                refComps{end+1} = name; %#ok<AGROW>
            end
        end
    end

    % Also search reactions that use this parameter in their rate
    for i = 1:numel(model.Reactions)
        rx = model.Reactions(i);
        if contains(rx.ReactionRate, paramName)
            tokens = regexp(rx.Reaction, '(\w+)\.\w+', 'tokens');
            for j = 1:numel(tokens)
                name = tokens{j}{1};
                if ~isempty(sbioselect(model, 'Type', 'compartment', 'Name', name))
                    refComps{end+1} = name; %#ok<AGROW>
                end
            end
        end
    end

    refComps = unique(refComps);
end

% Copyright 2026 The MathWorks, Inc.
