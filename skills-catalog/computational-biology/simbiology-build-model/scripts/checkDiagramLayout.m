function results = checkDiagramLayout(model, ctx)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% CHECKDIAGRAMLAYOUT Run all diagram layout checks in one call.
%
%   results = checkDiagramLayout(model)
%   results = checkDiagramLayout(model, ctx)
%
%   Runs containment check, connection-line-through-block check, and
%   overlap/proximity check on the model's diagram. When ctx (from
%   buildLayoutContext) is provided, uses cached positions.
%
%   Returns a struct with fields:
%     .containment  — struct array of containment violations
%     .lineThrough  — struct array of line-through-block violations
%     .overlap      — struct array of block overlap/proximity violations
%     .nContainment, .nLineThrough, .nOverlap, .nTotal — counts
%
%   See also: buildLayoutContext, repositionAllReactions

    MAX_BLOCKS = 400;

    allRxns  = model.Reactions;
    allSp    = model.Species;
    allComps = model.Compartments;
    nR = numel(allRxns);
    nS = numel(allSp);
    nC = numel(allComps);

    % Guard for very large models
    if (nR + nS) > MAX_BLOCKS
        warning('checkDiagramLayout:modelTooLarge', ...
            'Model has %d blocks (limit: %d). Skipping layout check.', nR+nS, MAX_BLOCKS);
        results.containment  = struct('rxnIndex',{},'reaction',{},'compartment',{},'type',{});
        results.lineThrough  = struct('rxnIndex',{},'reaction',{},'species',{},'blockedBy',{},'blockedByType',{});
        results.overlap      = struct('block1',{},'block2',{},'block1Type',{},'block2Type',{},'distance',{});
        results.outOfBounds  = struct('blockIndex',{},'blockName',{},'blockType',{},'position',{},'reason',{});
        results.nContainment = -1;
        results.nLineThrough = -1;
        results.nOverlap     = -1;
        results.nOutOfBounds = -1;
        results.nTotal       = -1;
        return
    end

    % Build or use context
    if nargin < 2 || isempty(ctx)
        ctx = buildLayoutContext(model);
    end

    %% === Containment Check ===
    contViols = struct('rxnIndex',{},'reaction',{},'compartment',{},'type',{});
    for i = 1:nR
        rb = ctx.rxnRect(i,:);
        involvedComps = getInvolvedComps(allRxns(i));
        isInterComp = numel(involvedComps) > 1;

        for c = 1:nC
            cb = ctx.compRect(c,:);
            if rb(1) < cb(3) && rb(3) > cb(1) && rb(2) < cb(4) && rb(4) > cb(2)
                isInvolved = any(strcmp(ctx.compNames{c}, involvedComps));
                if ~isInvolved
                    v.rxnIndex = i; v.reaction = allRxns(i).Reaction;
                    v.compartment = ctx.compNames{c}; v.type = 'WRONG_COMP';
                    contViols(end+1) = v; %#ok<AGROW>
                elseif isInterComp
                    v.rxnIndex = i; v.reaction = allRxns(i).Reaction;
                    v.compartment = ctx.compNames{c}; v.type = 'INTER_COMP_INSIDE_OWN';
                    contViols(end+1) = v; %#ok<AGROW>
                end
            end
        end
    end

    %% === Line-Through-Block Check (using spatial grid) ===
    lineViols = struct('rxnIndex',{},'reaction',{},'species',{},'blockedBy',{},'blockedByType',{});
    for i = 1:nR
        rcx = ctx.rxnCenter(i,1);
        rcy = ctx.rxnCenter(i,2);
        connSp = [allRxns(i).Reactants; allRxns(i).Products];

        for s = 1:numel(connSp)
            if isempty(connSp(s)) || isempty(connSp(s).Name)
                continue
            end
            sp = connSp(s);
            spName = [sp.Parent.Name '.' sp.Name];
            spIdx = find(strcmp(ctx.spNames, spName), 1);
            if isempty(spIdx), continue; end
            scx = ctx.spCenter(spIdx, 1);
            scy = ctx.spCenter(spIdx, 2);

            % Use spatial grid to find nearby blocks
            nearbyBlocks = queryGridForLine(ctx.grid, rcx, rcy, scx, scy);
            for nb = nearbyBlocks
                % Skip self (reaction) and connected species
                if nb == i, continue; end
                if nb > ctx.nR && strcmp(ctx.spNames{nb - ctx.nR}, spName), continue; end

                if lineIntersectsRect(rcx, rcy, scx, scy, ctx.allRect(nb,:))
                    lv.rxnIndex = i; lv.reaction = allRxns(i).Reaction;
                    lv.species = spName;
                    lv.blockedBy = ctx.allNames{nb};
                    lv.blockedByType = ctx.allTypes{nb};
                    lineViols(end+1) = lv; %#ok<AGROW>
                end
            end
        end
    end

    %% === Overlap / Proximity Check ===
    MIN_DIST = 10;
    nBlk = nR + nS;
    overlapViols = struct('block1',{},'block2',{},'block1Type',{},'block2Type',{},'distance',{});

    % Use spatial grid: for each block, check nearby blocks
    for a = 1:nBlk
        aCx = ctx.allCenter(a,1); aCy = ctx.allCenter(a,2);
        searchRect = [aCx-MIN_DIST, aCy-MIN_DIST, aCx+MIN_DIST, aCy+MIN_DIST];
        nearby = queryGridForRect(ctx.grid, searchRect);
        for nb = nearby
            if nb <= a, continue; end  % avoid duplicates (only check b > a)
            d = sqrt((ctx.allCenter(a,1)-ctx.allCenter(nb,1)).^2 + ...
                     (ctx.allCenter(a,2)-ctx.allCenter(nb,2)).^2);
            if d < MIN_DIST
                ov.block1 = ctx.allNames{a}; ov.block2 = ctx.allNames{nb};
                ov.block1Type = ctx.allTypes{a}; ov.block2Type = ctx.allTypes{nb};
                ov.distance = round(d, 1);
                overlapViols(end+1) = ov; %#ok<AGROW>
            end
        end
    end

    %% === Out-of-Bounds Check ===
    OOB_MARGIN = 100;  % pixels beyond outermost compartment edge

    % Compute model bounding box from compartments
    if nC > 0
        modelMinX = min(ctx.compRect(:,1));
        modelMinY = min(ctx.compRect(:,2));
        modelMaxX = max(ctx.compRect(:,3));
        modelMaxY = max(ctx.compRect(:,4));
    else
        modelMinX = 0; modelMinY = 0; modelMaxX = 1000; modelMaxY = 1000;
    end

    oobViols = struct('blockIndex',{},'blockName',{},'blockType',{},...
        'position',{},'reason',{});

    for a = 1:nBlk
        bx = ctx.allCenter(a, 1);
        by = ctx.allCenter(a, 2);
        reason = '';

        if bx < 0 || by < 0
            reason = 'NEGATIVE_COORD';
        elseif bx < modelMinX - OOB_MARGIN || bx > modelMaxX + OOB_MARGIN || ...
               by < modelMinY - OOB_MARGIN || by > modelMaxY + OOB_MARGIN
            reason = 'BEYOND_MARGIN';
        end

        if ~isempty(reason)
            ov.blockIndex = a;
            ov.blockName = ctx.allNames{a};
            ov.blockType = ctx.allTypes{a};
            ov.position = round(ctx.allCenter(a,:));
            ov.reason = reason;
            oobViols(end+1) = ov; %#ok<AGROW>
        end
    end

    %% === Build results ===
    results.containment  = contViols;
    results.lineThrough  = lineViols;
    results.overlap      = overlapViols;
    results.outOfBounds  = oobViols;
    results.nContainment = numel(contViols);
    results.nLineThrough = numel(lineViols);
    results.nOverlap     = numel(overlapViols);
    results.nOutOfBounds = numel(oobViols);
    results.nTotal       = numel(contViols) + numel(lineViols) + numel(overlapViols) + numel(oobViols);
end

%% === Helper: get compartment names involved in a reaction ===
function comps = getInvolvedComps(rxn)
    connSp = [rxn.Reactants; rxn.Products];
    comps = {};
    for s = 1:numel(connSp)
        if ~isempty(connSp(s)) && ~isempty(connSp(s).Name)
            comps{end+1} = connSp(s).Parent.Name; %#ok<AGROW>
        end
    end
    comps = unique(comps);
end

%% === Helper: grid query for a rectangle ===
function blockIndices = queryGridForRect(grid, rect)
    cs = grid.cellSize;
    c1 = max(1, floor((rect(1) - grid.minX) / cs) + 1);
    r1 = max(1, floor((rect(2) - grid.minY) / cs) + 1);
    c2 = min(grid.nCols, floor((rect(3) - grid.minX) / cs) + 1);
    r2 = min(grid.nRows, floor((rect(4) - grid.minY) / cs) + 1);
    blockIndices = [];
    for r = r1:r2
        for c = c1:c2
            blockIndices = [blockIndices, grid.cells{r,c}]; %#ok<AGROW>
        end
    end
    blockIndices = unique(blockIndices);
end

% Copyright 2026 The MathWorks, Inc.
