function nFixed = repositionAllReactions(model, ctx)
% Internal use only
% Used by the matlab-build-simbiology-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% REPOSITIONALLREACTIONS Batch-reposition reaction nodes to crossing-free positions.
%
%   nFixed = repositionAllReactions(model)
%   nFixed = repositionAllReactions(model, ctx)
%
%   Repositions reactions using cooperative logic:
%     1. For each reaction with violations, identify blocking reactions.
%     2. If a blocker is an intra-compartment reaction blocking an
%        inter-compartment reaction, reposition the blocker first.
%     3. Re-check the original reaction — if violation resolved, skip it.
%     4. After targeted passes, a settle pass re-evaluates all moved
%        reactions against the stable final layout.
%
%   When ctx (from buildLayoutContext) is provided, uses cached positions
%   and spatial grid. Otherwise builds context internally. Context is
%   updated incrementally as reactions are moved.
%
%   Returns the total number of reactions repositioned.
%
%   See also: computeSafeReactionPosition, checkDiagramLayout, buildLayoutContext

    MAX_BLOCKS = 400;
    MAX_PASSES = 3;

    allRxns = model.Reactions;
    allSp   = model.Species;
    nR = numel(allRxns);
    nS = numel(allSp);
    nFixed = 0;

    if (nR + nS) > MAX_BLOCKS
        warning('repositionAllReactions:modelTooLarge', ...
            'Model has %d blocks (limit: %d). Skipping repositioning.', nR+nS, MAX_BLOCKS);
        return
    end

    % Build or use context
    if nargin < 2 || isempty(ctx)
        ctx = buildLayoutContext(model);
    end

    movedIndices = false(nR, 1);
    cooperativeMoved = false(nR, 1);  % track reactions moved to avoid others' lines

    %% Classify reactions
    isInterComp = false(nR, 1);
    for i = 1:nR
        comps = getInvolvedCompartments(allRxns(i));
        isInterComp(i) = numel(comps) > 1;
    end

    %% Detect forward/reverse pairs
    pairs = detectReversePairs(allRxns, ctx);

    %% Targeted passes with cooperative repositioning
    pass = 0;
    for p = 1:MAX_PASSES
        pass = p;
        movedThisPass = 0;
        for i = 1:nR
            if ~reactionHasViolation(i, ctx)
                continue
            end

            % Cooperative fix: move intra-compartment blockers first
            if isInterComp(i)
                allVictimLines = getAllConnectionLines(i, ctx);
                [blockers, ~] = findBlockingReactions(i, ctx);
                for bi = 1:numel(blockers)
                    bIdx = blockers(bi);
                    if ~isInterComp(bIdx)
                        lineExcl = sampleLineExclusion(allVictimLines);
                        newBPos = computeSafeReactionPosition(model, allRxns(bIdx), ctx, ...
                            'ExtraExclusion', lineExcl, 'ExtraBuffer', 15);
                        if ~isequal(ctx.rxnPos(bIdx,:), newBPos)
                            simbio.diagram.setBlock(allRxns(bIdx), 'Position', newBPos);
                            ctx = updateContextBlock(ctx, bIdx, newBPos);
                            movedThisPass = movedThisPass + 1;
                            movedIndices(bIdx) = true;
                            cooperativeMoved(bIdx) = true;
                        end
                    end
                end
                if ~reactionHasViolation(i, ctx)
                    continue
                end
            end

            % Standard repositioning (with pair-awareness)
            if pairs(i) > 0 && movedIndices(pairs(i))
                pairedCenter = ctx.rxnCenter(pairs(i),:);
                newPos = computeSafeReactionPosition(model, allRxns(i), ctx, ...
                    'ExtraExclusion', pairedCenter, 'ExtraBuffer', 35);
            else
                newPos = computeSafeReactionPosition(model, allRxns(i), ctx);
            end
            if ~isequal(ctx.rxnPos(i,:), newPos)
                simbio.diagram.setBlock(allRxns(i), 'Position', newPos);
                ctx = updateContextBlock(ctx, i, newPos);
                movedThisPass = movedThisPass + 1;
                movedIndices(i) = true;
            elseif reactionHasViolation(i, ctx)
                % Can't fix self — try moving blockers cooperatively
                % Pass ALL victim's connection lines as exclusions to prevent oscillation
                allVictimLines = getAllConnectionLines(i, ctx);
                [blockers, ~] = findBlockingReactions(i, ctx);
                for bi = 1:numel(blockers)
                    bIdx = blockers(bi);
                    lineExcl = sampleLineExclusion(allVictimLines);
                    newBPos = computeSafeReactionPosition(model, allRxns(bIdx), ctx, ...
                        'ExtraExclusion', lineExcl, 'ExtraBuffer', 15);
                    if ~isequal(ctx.rxnPos(bIdx,:), newBPos)
                        simbio.diagram.setBlock(allRxns(bIdx), 'Position', newBPos);
                        ctx = updateContextBlock(ctx, bIdx, newBPos);
                        movedThisPass = movedThisPass + 1;
                        movedIndices(bIdx) = true;
                        cooperativeMoved(bIdx) = true;
                    end
                end
            end
        end
        nFixed = nFixed + movedThisPass;

        if movedThisPass == 0
            break
        end
    end

    %% Settle pass: re-evaluate moved reactions against final layout
    %  Skip cooperatively-moved reactions (their position avoids others' lines)
    if any(movedIndices)
        settleCount = 0;
        for i = 1:nR
            if ~movedIndices(i), continue; end
            if cooperativeMoved(i), continue; end
            if pairs(i) > 0
                pairedCenter = ctx.rxnCenter(pairs(i),:);
                newPos = computeSafeReactionPosition(model, allRxns(i), ctx, ...
                    'ExtraExclusion', pairedCenter, 'ExtraBuffer', 35);
            else
                newPos = computeSafeReactionPosition(model, allRxns(i), ctx);
            end
            if ~isequal(ctx.rxnPos(i,:), newPos)
                simbio.diagram.setBlock(allRxns(i), 'Position', newPos);
                ctx = updateContextBlock(ctx, i, newPos);
                settleCount = settleCount + 1;
            end
        end
        nFixed = nFixed + settleCount;
    end

    %% Pair-separation pass: force separation of pairs that are too close
    PAIR_MIN_DIST = 35;
    pairSepCount = 0;
    for i = 1:nR
        if pairs(i) == 0, continue; end
        j = pairs(i);
        d = sqrt((ctx.rxnCenter(i,1)-ctx.rxnCenter(j,1))^2 + ...
                 (ctx.rxnCenter(i,2)-ctx.rxnCenter(j,2))^2);
        if d < PAIR_MIN_DIST
            % Reposition the later reaction (i) away from its partner (j)
            pairedCenter = ctx.rxnCenter(j,:);
            newPos = computeSafeReactionPosition(model, allRxns(i), ctx, ...
                'ExtraExclusion', pairedCenter, 'ExtraBuffer', PAIR_MIN_DIST);
            if ~isequal(ctx.rxnPos(i,:), newPos)
                simbio.diagram.setBlock(allRxns(i), 'Position', newPos);
                ctx = updateContextBlock(ctx, i, newPos);
                pairSepCount = pairSepCount + 1;
            end
        end
    end
    nFixed = nFixed + pairSepCount;

    %% Post-pair fix pass: resolve violations introduced by pair separation
    if pairSepCount > 0
        postPairCount = 0;
        for i = 1:nR
            if ~reactionHasViolation(i, ctx), continue; end
            if pairs(i) > 0
                pairedCenter = ctx.rxnCenter(pairs(i),:);
                newPos = computeSafeReactionPosition(model, allRxns(i), ctx, ...
                    'ExtraExclusion', pairedCenter, 'ExtraBuffer', PAIR_MIN_DIST);
            else
                newPos = computeSafeReactionPosition(model, allRxns(i), ctx);
            end
            if ~isequal(ctx.rxnPos(i,:), newPos)
                simbio.diagram.setBlock(allRxns(i), 'Position', newPos);
                ctx = updateContextBlock(ctx, i, newPos);
                postPairCount = postPairCount + 1;
            end
        end
        nFixed = nFixed + postPairCount;
    end

    %% Hub-sibling separation: separate reactions sharing a species endpoint
    SIBLING_MIN_DIST = 25;
    siblingCount = 0;
    siblings = buildSiblingMap(allRxns, ctx);
    for i = 1:nR
        sibIndices = siblings{i};
        if isempty(sibIndices), continue; end
        % Collect positions of already-placed siblings that are too close
        exclusions = zeros(0, 2);
        for si = sibIndices
            if si >= i, continue; end  % only check earlier-placed siblings
            d = sqrt((ctx.rxnCenter(i,1)-ctx.rxnCenter(si,1))^2 + ...
                     (ctx.rxnCenter(i,2)-ctx.rxnCenter(si,2))^2);
            if d < SIBLING_MIN_DIST
                exclusions(end+1,:) = ctx.rxnCenter(si,:); %#ok<AGROW>
            end
        end
        if isempty(exclusions), continue; end
        % Also include pair exclusion if applicable
        if pairs(i) > 0
            exclusions(end+1,:) = ctx.rxnCenter(pairs(i),:);
        end
        newPos = computeSafeReactionPosition(model, allRxns(i), ctx, ...
            'ExtraExclusion', exclusions, 'ExtraBuffer', SIBLING_MIN_DIST);
        if ~isequal(ctx.rxnPos(i,:), newPos)
            simbio.diagram.setBlock(allRxns(i), 'Position', newPos);
            ctx = updateContextBlock(ctx, i, newPos);
            siblingCount = siblingCount + 1;
        end
    end
    nFixed = nFixed + siblingCount;

    %% Final fix pass: clean up any violations from sibling separation
    if siblingCount > 0
        finalFixCount = 0;
        for i = 1:nR
            if ~reactionHasViolation(i, ctx), continue; end
            newPos = computeSafeReactionPosition(model, allRxns(i), ctx);
            if ~isequal(ctx.rxnPos(i,:), newPos)
                simbio.diagram.setBlock(allRxns(i), 'Position', newPos);
                ctx = updateContextBlock(ctx, i, newPos);
                finalFixCount = finalFixCount + 1;
            end
        end
        nFixed = nFixed + finalFixCount;
    end

    % Final report
    results = checkDiagramLayout(model, ctx);
    fprintf('repositionAllReactions: %d reactions moved across %d pass(es). ', nFixed, pass);
    fprintf('Remaining violations: %d\n', results.nTotal);
end

%% === Helper: check if a single reaction has a violation (using context) ===
function hasViol = reactionHasViolation(rxnIdx, ctx)
    MIN_PROXIMITY = 20;
    MIN_SPECIES_DIST = 40;  % minimum distance to connected species
    hasViol = false;

    rxnCx = ctx.rxnCenter(rxnIdx, 1);
    rxnCy = ctx.rxnCenter(rxnIdx, 2);

    % Get connected species
    rxn = ctx.model.Reactions(rxnIdx);
    connSp = [rxn.Reactants; rxn.Products];
    connIndices = [];
    connCenters = [];
    involvedComps = {};
    for s = 1:numel(connSp)
        if isempty(connSp(s)) || isempty(connSp(s).Name)
            continue
        end
        spName = [connSp(s).Parent.Name '.' connSp(s).Name];
        spIdx = find(strcmp(ctx.spNames, spName), 1);
        if ~isempty(spIdx)
            connCenters(end+1,:) = ctx.spCenter(spIdx,:); %#ok<AGROW>
            connIndices(end+1) = ctx.nR + spIdx; %#ok<AGROW>
        end
        involvedComps{end+1} = connSp(s).Parent.Name; %#ok<AGROW>
    end
    involvedComps = unique(involvedComps);
    isInterComp = numel(involvedComps) > 1;
    nConn = size(connCenters, 1);
    if nConn == 0, return; end

    excludeSet = [rxnIdx, connIndices];

    % Minimum distance to connected species (prevents reaction sitting on
    % top of its endpoint species — especially elimination/synthesis nodes)
    for s = 1:nConn
        d = sqrt((rxnCx - connCenters(s,1))^2 + (rxnCy - connCenters(s,2))^2);
        if d < MIN_SPECIES_DIST
            hasViol = true;
            return
        end
    end

    % Containment check for inter-compartment reactions
    if isInterComp
        rxnRect = ctx.rxnRect(rxnIdx,:);
        for c = 1:ctx.nC
            cb = ctx.compRect(c,:);
            if rxnRect(1) >= cb(1) && rxnRect(3) <= cb(3) && ...
               rxnRect(2) >= cb(2) && rxnRect(4) <= cb(4)
                hasViol = true;
                return
            end
        end
    end

    % Elimination/synthesis outside parent compartment check
    if ~isInterComp && (numel(rxn.Reactants) == 0 || numel(rxn.Products) == 0)
        if isscalar(involvedComps)
            cIdx = find(strcmp(ctx.compNames, involvedComps{1}), 1);
            if ~isempty(cIdx)
                cr = ctx.compRect(cIdx,:);
                if rxnCx < cr(1) || rxnCx > cr(3) || rxnCy < cr(2) || rxnCy > cr(4)
                    hasViol = true;
                    return
                end
            end
        end
    end

    % Line-through-block (using spatial grid)
    for s = 1:nConn
        scx = connCenters(s,1); scy = connCenters(s,2);
        nearbyBlocks = queryGridForLine(ctx.grid, rxnCx, rxnCy, scx, scy);
        for nb = nearbyBlocks
            if any(nb == excludeSet), continue; end
            if lineIntersectsRect(rxnCx, rxnCy, scx, scy, ctx.allRect(nb,:))
                hasViol = true;
                return
            end
        end
    end

    % Proximity check (using spatial grid)
    candRect = [rxnCx-MIN_PROXIMITY, rxnCy-MIN_PROXIMITY, rxnCx+MIN_PROXIMITY, rxnCy+MIN_PROXIMITY];
    nearbyForProx = queryGridForRect(ctx.grid, candRect);
    for nb = nearbyForProx
        if any(nb == excludeSet), continue; end
        d = sqrt((rxnCx - ctx.allCenter(nb,1)).^2 + (rxnCy - ctx.allCenter(nb,2)).^2);
        if d < MIN_PROXIMITY
            hasViol = true;
            return
        end
    end
end

%% === Helper: find blocking reactions (using context) ===
function [blockerIndices, blockedLines] = findBlockingReactions(rxnIdx, ctx)
    blockerIndices = [];
    blockedLines = {};  % cell array of [N x 4] matrices (all blocked line endpoints per blocker)
    rxnCx = ctx.rxnCenter(rxnIdx,1);
    rxnCy = ctx.rxnCenter(rxnIdx,2);

    rxn = ctx.model.Reactions(rxnIdx);
    connSp = [rxn.Reactants; rxn.Products];
    connCenters = [];
    for s = 1:numel(connSp)
        if isempty(connSp(s)) || isempty(connSp(s).Name)
            continue
        end
        spName = [connSp(s).Parent.Name '.' connSp(s).Name];
        spIdx = find(strcmp(ctx.spNames, spName), 1);
        if ~isempty(spIdx)
            connCenters(end+1,:) = ctx.spCenter(spIdx,:); %#ok<AGROW>
        end
    end
    nConn = size(connCenters, 1);

    % Check which other reactions block connection lines (collect ALL blocked lines)
    for i = 1:ctx.nR
        if i == rxnIdx, continue; end
        blockRect = ctx.rxnRect(i,:);
        linesForThis = zeros(0, 4);
        for s = 1:nConn
            if lineIntersectsRect(rxnCx, rxnCy, connCenters(s,1), connCenters(s,2), blockRect)
                linesForThis(end+1,:) = [rxnCx, rxnCy, connCenters(s,:)]; %#ok<AGROW>
            end
        end
        if ~isempty(linesForThis)
            blockerIndices(end+1) = i; %#ok<AGROW>
            blockedLines{end+1} = linesForThis; %#ok<AGROW>
        end
    end
end

%% === Helper: get involved compartments ===
function comps = getInvolvedCompartments(rxn)
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

%% === Helper: build sibling map (reactions sharing a species endpoint) ===
function siblings = buildSiblingMap(allRxns, ~)
% For each reaction, find other reactions that share at least one connected species.
    nR = numel(allRxns);
    siblings = cell(nR, 1);

    % Build species-to-reaction index
    sp2rxn = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:nR
        connSp = [allRxns(i).Reactants; allRxns(i).Products];
        for s = 1:numel(connSp)
            if isempty(connSp(s)) || isempty(connSp(s).Name), continue; end
            spName = [connSp(s).Parent.Name '.' connSp(s).Name];
            if sp2rxn.isKey(spName)
                sp2rxn(spName) = [sp2rxn(spName), i];
            else
                sp2rxn(spName) = i;
            end
        end
    end

    % For each reaction, collect siblings (other reactions sharing any endpoint)
    for i = 1:nR
        connSp = [allRxns(i).Reactants; allRxns(i).Products];
        sibs = [];
        for s = 1:numel(connSp)
            if isempty(connSp(s)) || isempty(connSp(s).Name), continue; end
            spName = [connSp(s).Parent.Name '.' connSp(s).Name];
            if sp2rxn.isKey(spName)
                sibs = [sibs, sp2rxn(spName)]; %#ok<AGROW>
            end
        end
        sibs = unique(sibs);
        sibs(sibs == i) = [];  % remove self
        siblings{i} = sibs;
    end
end

%% === Helper: detect forward/reverse reaction pairs ===
function pairs = detectReversePairs(allRxns, ctx)
% Find reactions that connect the same set of species (forward/reverse pairs).
% Returns pairs(i) = j where j < i is the earlier partner, or 0 if unpaired.
    nR = numel(allRxns);
    pairs = zeros(nR, 1);
    speciesSets = cell(nR, 1);

    for i = 1:nR
        connSp = [allRxns(i).Reactants; allRxns(i).Products];
        names = {};
        for s = 1:numel(connSp)
            if ~isempty(connSp(s)) && ~isempty(connSp(s).Name)
                spName = [connSp(s).Parent.Name '.' connSp(s).Name];
                spIdx = find(strcmp(ctx.spNames, spName), 1);
                if ~isempty(spIdx)
                    names{end+1} = spName; %#ok<AGROW>
                end
            end
        end
        speciesSets{i} = sort(names);
    end

    for i = 2:nR
        if numel(speciesSets{i}) < 2
            continue
        end
        for j = 1:(i-1)
            if numel(speciesSets{i}) == numel(speciesSets{j}) && ...
               all(strcmp(speciesSets{i}, speciesSets{j}))
                pairs(i) = j;
                break
            end
        end
    end
end

%% === Helper: get ALL connection lines for a reaction ===
function lines = getAllConnectionLines(rxnIdx, ctx)
% Returns [N x 4] matrix of all connection lines [x1 y1 x2 y2] for a reaction.
    rxnCx = ctx.rxnCenter(rxnIdx, 1);
    rxnCy = ctx.rxnCenter(rxnIdx, 2);
    rxn = ctx.model.Reactions(rxnIdx);
    connSp = [rxn.Reactants; rxn.Products];
    lines = zeros(0, 4);
    for s = 1:numel(connSp)
        if isempty(connSp(s)) || isempty(connSp(s).Name), continue; end
        spName = [connSp(s).Parent.Name '.' connSp(s).Name];
        spIdx = find(strcmp(ctx.spNames, spName), 1);
        if ~isempty(spIdx)
            lines(end+1,:) = [rxnCx, rxnCy, ctx.spCenter(spIdx,:)]; %#ok<AGROW>
        end
    end
end

%% === Helper: sample exclusion points along blocked lines ===
function pts = sampleLineExclusion(linesMatrix)
% Generate evenly-spaced points along blocked lines for use as ExtraExclusion.
% linesMatrix: [N x 4] where each row is [x1 y1 x2 y2]
    nSamples = 5;
    nLines = size(linesMatrix, 1);
    pts = zeros(nLines * nSamples, 2);
    idx = 0;
    for li = 1:nLines
        p1 = linesMatrix(li, 1:2);
        p2 = linesMatrix(li, 3:4);
        for k = 1:nSamples
            t = (k-1) / (nSamples-1);
            idx = idx + 1;
            pts(idx,:) = p1 + t*(p2-p1);
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
