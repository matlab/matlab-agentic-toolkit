function pos = computeSafeReactionPosition(model, rxn, ctx, options)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% COMPUTESAFEREACTIONPOSITION Find a crossing-free position for a reaction node.
%
%   pos = computeSafeReactionPosition(model, rxn)
%   pos = computeSafeReactionPosition(model, rxn, ctx)
%   pos = computeSafeReactionPosition(model, rxn, ctx, 'ExtraExclusion', [cx cy], 'ExtraBuffer', 35)
%
%   Computes a position [x y 15 15] for the reaction node such that the
%   connection lines to all its reactants and products do not pass through
%   any other block (species or reaction) in the diagram.
%
%   When ctx (from buildLayoutContext) is provided, uses cached positions
%   and spatial grid for fast lookups. Otherwise queries the diagram API
%   directly (slower, legacy behavior).
%
%   Name-Value Options:
%     ExtraExclusion - [N x 2] array of center positions to avoid (e.g.,
%                      paired reaction positions). Default: empty.
%     ExtraBuffer    - Minimum distance from ExtraExclusion points (px).
%                      Default: 35.
%
%   Strategy:
%     1. Compute the ideal midpoint between connected species.
%     2. Generate candidate positions (line sampling, perpendicular
%        offsets, grid search, gap-based for inter-compartment).
%     3. For each candidate, test connection lines against nearby blocks
%        (using spatial grid when available).
%     4. Return the candidate closest to ideal with zero violations.
%     5. If no perfect position exists, return the one with fewest.
%
%   See also: buildLayoutContext, repositionAllReactions

    arguments
        model
        rxn
        ctx = []
        options.ExtraExclusion (:,2) double = zeros(0,2)
        options.ExtraBuffer (1,1) double = 35
    end

    RXN_W = 15; RXN_H = 15;
    MAX_BLOCKS = 400;
    MIN_PROXIMITY = 20;

    allRxns = model.Reactions;
    allSp   = model.Species;
    allComps = model.Compartments;
    nR = numel(allRxns);
    nS = numel(allSp);
    nC = numel(allComps);

    % Find this reaction's index
    rxnIdx = 0;
    for i = 1:nR
        if allRxns(i) == rxn
            rxnIdx = i;
            break
        end
    end

    %% Build or use context
    useCtx = ~isempty(ctx);

    if ~useCtx
        % Legacy: guard and build positions from API
        if (nR + nS) > MAX_BLOCKS
            connSp = [rxn.Reactants; rxn.Products];
            cx = 0; cy = 0; nConn = 0;
            for s = 1:numel(connSp)
                if ~isempty(connSp(s)) && ~isempty(connSp(s).Name)
                    spp = simbio.diagram.getBlock(connSp(s), 'Position');
                    cx = cx + spp(1) + spp(3)/2;
                    cy = cy + spp(2) + spp(4)/2;
                    nConn = nConn + 1;
                end
            end
            if nConn > 0
                cx = cx / nConn; cy = cy / nConn;
            else
                cx = 50; cy = 50;
            end
            pos = [round(cx - RXN_W/2), round(cy - RXN_H/2), RXN_W, RXN_H];
            return
        end
        ctx = buildLayoutContext(model);
    end

    %% Connected species info (from context)
    connSp = [rxn.Reactants; rxn.Products];
    connIndices = [];  % indices into ctx.allRect (nR + spIdx)
    connCenters = [];
    connNames = {};
    for s = 1:numel(connSp)
        if isempty(connSp(s)) || isempty(connSp(s).Name)
            continue
        end
        spName = [connSp(s).Parent.Name '.' connSp(s).Name];
        connNames{end+1} = spName; %#ok<AGROW>
        % Find species index in context
        spIdx = find(strcmp(ctx.spNames, spName), 1);
        if ~isempty(spIdx)
            connCenters(end+1,:) = ctx.spCenter(spIdx,:); %#ok<AGROW>
            connIndices(end+1) = ctx.nR + spIdx; %#ok<AGROW>
        end
    end
    nConn = size(connCenters, 1);

    if nConn == 0
        pos = [50, 50, RXN_W, RXN_H];
        return
    end

    %% Build exclusion set: block indices to skip (self + connected species)
    excludeSet = [rxnIdx, connIndices];

    %% Identify involved compartments
    involvedComps = {};
    for s = 1:numel(connSp)
        if ~isempty(connSp(s)) && ~isempty(connSp(s).Name)
            involvedComps{end+1} = connSp(s).Parent.Name; %#ok<AGROW>
        end
    end
    involvedComps = unique(involvedComps);
    isInterComp = numel(involvedComps) > 1;

    % Compartment bounds for containment check (non-involved or all if inter-comp)
    compBounds = zeros(0, 4);
    for c = 1:nC
        if isInterComp || ~any(strcmp(ctx.compNames{c}, involvedComps))
            compBounds(end+1,:) = ctx.compRect(c,:); %#ok<AGROW>
        end
    end

    %% Involved compartment positions (for candidate generation)
    involvedCompPos = zeros(numel(involvedComps), 4);
    for ic = 1:numel(involvedComps)
        cIdx = find(strcmp(ctx.compNames, involvedComps{ic}), 1);
        if ~isempty(cIdx)
            involvedCompPos(ic,:) = ctx.compPos(cIdx,:);
        end
    end

    %% Compute ideal midpoint
    idealCx = mean(connCenters(:,1));
    idealCy = mean(connCenters(:,2));

    %% Elimination reaction handling
    isElimination = false;
    if isscalar(involvedComps)
        if numel(rxn.Reactants) == 0 || numel(rxn.Products) == 0
            isElimination = true;
        end
    end

    if isElimination
        cp = involvedCompPos(1,:);
        % Connected species center (there's only one real species)
        spCx = connCenters(1,1);
        spCy = connCenters(1,2);
        innerMargin = 30;
        ELIM_OFFSET = 50; % distance from species to place reaction node

        % Determine reaction direction semantics:
        %   synthesis (null -> X): prefer above or left of species
        %   degradation (X -> null): prefer below or right of species
        isSynthesis = (numel(rxn.Reactants) == 0);

        % Compute available space in each direction from species to comp edge
        spaceLeft  = spCx - (cp(1) + innerMargin);
        spaceRight = (cp(1) + cp(3) - innerMargin) - spCx;
        spaceUp    = spCy - (cp(2) + innerMargin);
        spaceDown  = (cp(2) + cp(4) - innerMargin) - spCy;

        % Build directional candidates ordered by semantic preference
        % Each is [x, y, priority_bonus] — lower bonus = preferred
        dirCandidates = zeros(0, 3);
        if isSynthesis
            % Prefer above, then left, then right, then below
            if spaceUp >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx, spCy - ELIM_OFFSET, 0];
            end
            if spaceLeft >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx - ELIM_OFFSET, spCy, 5];
            end
            if spaceRight >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx + ELIM_OFFSET, spCy, 10];
            end
            if spaceDown >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx, spCy + ELIM_OFFSET, 15];
            end
        else
            % Degradation: prefer below, then right, then left, then above
            if spaceDown >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx, spCy + ELIM_OFFSET, 0];
            end
            if spaceRight >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx + ELIM_OFFSET, spCy, 5];
            end
            if spaceLeft >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx - ELIM_OFFSET, spCy, 10];
            end
            if spaceUp >= ELIM_OFFSET
                dirCandidates(end+1,:) = [spCx, spCy - ELIM_OFFSET, 15];
            end
        end

        % Also add diagonal offsets for more spread options
        diagOffset = round(ELIM_OFFSET * 0.7);
        if isSynthesis
            if spaceUp >= diagOffset && spaceLeft >= diagOffset
                dirCandidates(end+1,:) = [spCx - diagOffset, spCy - diagOffset, 3];
            end
            if spaceUp >= diagOffset && spaceRight >= diagOffset
                dirCandidates(end+1,:) = [spCx + diagOffset, spCy - diagOffset, 7];
            end
        else
            if spaceDown >= diagOffset && spaceRight >= diagOffset
                dirCandidates(end+1,:) = [spCx + diagOffset, spCy + diagOffset, 3];
            end
            if spaceDown >= diagOffset && spaceLeft >= diagOffset
                dirCandidates(end+1,:) = [spCx - diagOffset, spCy + diagOffset, 7];
            end
        end

        % Pick the best unoccupied direction (check for other reaction nodes nearby)
        if ~isempty(dirCandidates)
            % Sort by priority bonus (prefer semantic direction)
            [~, sortIdx] = sort(dirCandidates(:,3));
            dirCandidates = dirCandidates(sortIdx, :);

            % Find the first direction not blocked by another reaction
            bestDir = 1;
            for di = 1:size(dirCandidates, 1)
                dcx = dirCandidates(di, 1);
                dcy = dirCandidates(di, 2);
                tooClose = false;
                for ri = 1:nR
                    if ri == rxnIdx, continue; end
                    rd = sqrt((dcx - ctx.rxnCenter(ri,1))^2 + (dcy - ctx.rxnCenter(ri,2))^2);
                    if rd < 25
                        tooClose = true;
                        break
                    end
                end
                if ~tooClose
                    bestDir = di;
                    break
                end
            end
            idealCx = dirCandidates(bestDir, 1);
            idealCy = dirCandidates(bestDir, 2);
        else
            % Fallback: offset from species toward compartment center
            cpCx = cp(1) + cp(3)/2;
            cpCy = cp(2) + cp(4)/2;
            dirX = cpCx - spCx; dirY = cpCy - spCy;
            dirLen = sqrt(dirX^2 + dirY^2);
            if dirLen > 0
                idealCx = spCx + ELIM_OFFSET * dirX / dirLen;
                idealCy = spCy + ELIM_OFFSET * dirY / dirLen;
            else
                idealCx = spCx + ELIM_OFFSET;
                idealCy = spCy;
            end
            idealCx = max(cp(1)+innerMargin, min(cp(1)+cp(3)-innerMargin, idealCx));
            idealCy = max(cp(2)+innerMargin, min(cp(2)+cp(4)-innerMargin, idealCy));
        end
    end

    %% Generate candidate positions
    candidates = generateCandidates(connCenters, idealCx, idealCy, ...
        isInterComp, isElimination, involvedComps, involvedCompPos, ctx, ...
        options.ExtraExclusion);

    %% Parent compartment rect for elimination containment preference
    if isElimination && size(involvedCompPos, 1) >= 1
        cp = involvedCompPos(1,:);
        parentRect = [cp(1), cp(2), cp(1)+cp(3), cp(2)+cp(4)];
    else
        parentRect = [];
    end

    %% Gap center for inter-compartment reactions
    %  Heavily penalize candidates far from the natural gap between
    %  connected compartments to prevent reactions flying to random locations.
    gapCenter = [];
    if isInterComp && size(involvedCompPos, 1) >= 2
        cp1 = involvedCompPos(1,:); cp2 = involvedCompPos(2,:);
        % Find gap between the two compartments (horizontal or vertical)
        c1Cx = cp1(1)+cp1(3)/2; c1Cy = cp1(2)+cp1(4)/2;
        c2Cx = cp2(1)+cp2(3)/2; c2Cy = cp2(2)+cp2(4)/2;
        gapCenter = [(c1Cx+c2Cx)/2, (c1Cy+c2Cy)/2];
    end

    %% Evaluate candidates using spatial grid
    nCand = size(candidates, 1);
    scores = evaluateCandidates(candidates, nCand, connCenters, nConn, ...
        excludeSet, compBounds, idealCx, idealCy, RXN_W, RXN_H, MIN_PROXIMITY, ctx, ...
        options.ExtraExclusion, options.ExtraBuffer, parentRect, gapCenter);

    %% Check if we need a wider search
    [bestScore, ~] = min(scores);
    if bestScore >= 10000
        candidates2 = generateWideCandidates(idealCx, idealCy, isInterComp, involvedCompPos);
        nCand2 = size(candidates2, 1);
        scores2 = evaluateCandidates(candidates2, nCand2, connCenters, nConn, ...
            excludeSet, compBounds, idealCx, idealCy, RXN_W, RXN_H, MIN_PROXIMITY, ctx, ...
            options.ExtraExclusion, options.ExtraBuffer, parentRect, gapCenter);
        candidates = [candidates; candidates2];
        scores = [scores; scores2];
    end

    %% Select best
    [~, bestIdx] = min(scores);
    bestCx = candidates(bestIdx, 1);
    bestCy = candidates(bestIdx, 2);
    pos = [round(bestCx - RXN_W/2), round(bestCy - RXN_H/2), RXN_W, RXN_H];
end

%% === Candidate Generation ===
function candidates = generateCandidates(connCenters, idealCx, idealCy, ...
    isInterComp, isElimination, ~, involvedCompPos, ~, extraExclusion)

    candidates = zeros(0, 2);
    nConn = size(connCenters, 1);

    % Line sampling for 2-species reactions
    if nConn == 2
        p1 = connCenters(1,:);
        p2 = connCenters(2,:);
        tValues = [0.5 0.45 0.55 0.4 0.6 0.35 0.65 0.3 0.7 0.25 0.75 0.2 0.8];
        for t = tValues
            candidates(end+1,:) = p1 + t*(p2-p1); %#ok<AGROW>
        end
        % Perpendicular offsets
        lineDir = p2 - p1;
        lineLen = norm(lineDir);
        if lineLen > 0
            perpDir = [-lineDir(2), lineDir(1)] / lineLen;
            for t = [0.3 0.5 0.7]
                basePt = p1 + t*(p2-p1);
                for po = [-80 -40 -20 20 40 80]
                    candidates(end+1,:) = basePt + po*perpDir; %#ok<AGROW>
                end
            end
        end
    end

    % Grid around ideal midpoint
    offsets = [-100 -60 -30 0 30 60 100];
    for dx = offsets
        for dy = offsets
            candidates(end+1,:) = [idealCx + dx, idealCy + dy]; %#ok<AGROW>
        end
    end

    % Gap-based for inter-compartment
    if isInterComp && size(involvedCompPos, 1) >= 2
        cp1 = involvedCompPos(1,:); cp2 = involvedCompPos(2,:);
        c1R = cp1(1)+cp1(3); c2L = cp2(1);
        c1B = cp1(2)+cp1(4); c2T = cp2(2);
        if c1R < c2L
            hGapX = (c1R + c2L) / 2;
            for gy = linspace(min(cp1(2),cp2(2))-20, max(cp1(2)+cp1(4),cp2(2)+cp2(4))+20, 7)
                candidates(end+1,:) = [hGapX, gy]; %#ok<AGROW>
            end
        end
        if c1B < c2T
            vGapY = (c1B + c2T) / 2;
            for gx = linspace(min(cp1(1),cp2(1))-20, max(cp1(1)+cp1(3),cp2(1)+cp2(3))+20, 7)
                candidates(end+1,:) = [gx, vGapY]; %#ok<AGROW>
            end
        end
        % Edge margins
        for ic = 1:size(involvedCompPos,1)
            cp = involvedCompPos(ic,:);
            cpCx = cp(1)+cp(3)/2; cpCy = cp(2)+cp(4)/2;
            for em = [20 40 60]
                candidates(end+1,:) = [cp(1)-em, cpCy]; %#ok<AGROW>
                candidates(end+1,:) = [cp(1)+cp(3)+em, cpCy]; %#ok<AGROW>
                candidates(end+1,:) = [cpCx, cp(2)-em]; %#ok<AGROW>
                candidates(end+1,:) = [cpCx, cp(2)+cp(4)+em]; %#ok<AGROW>
            end
        end
    end

    % Elimination: candidates INSIDE the parent compartment
    if isElimination && size(involvedCompPos,1) >= 1
        cp = involvedCompPos(1,:);
        cpCx = cp(1)+cp(3)/2; cpCy = cp(2)+cp(4)/2;
        % Inside each edge at increasing depths
        for em = [20 40 60 80]
            candidates(end+1,:) = [cp(1)+em, cpCy]; %#ok<AGROW>
            candidates(end+1,:) = [cp(1)+cp(3)-em, cpCy]; %#ok<AGROW>
            candidates(end+1,:) = [cpCx, cp(2)+em]; %#ok<AGROW>
            candidates(end+1,:) = [cpCx, cp(2)+cp(4)-em]; %#ok<AGROW>
        end
        % Offsets relative to the connected species
        if nConn >= 1
            spCx = connCenters(1,1); spCy = connCenters(1,2);
            for offset = [40 60 80]
                candidates(end+1,:) = [spCx + offset, spCy]; %#ok<AGROW>
                candidates(end+1,:) = [spCx - offset, spCy]; %#ok<AGROW>
                candidates(end+1,:) = [spCx, spCy + offset]; %#ok<AGROW>
                candidates(end+1,:) = [spCx, spCy - offset]; %#ok<AGROW>
            end
        end
    end

    % Paired reaction: perpendicular offset candidates away from partner
    if ~isempty(extraExclusion) && nConn == 2
        lineDir = connCenters(2,:) - connCenters(1,:);
        lineLen = norm(lineDir);
        if lineLen > 0
            perpDir = [-lineDir(2), lineDir(1)] / lineLen;
            midPt = (connCenters(1,:) + connCenters(2,:)) / 2;
            for po = [-50 -35 35 50]
                candidates(end+1,:) = midPt + po*perpDir; %#ok<AGROW>
            end
        end
    end
end

function candidates = generateWideCandidates(idealCx, idealCy, isInterComp, involvedCompPos)
    candidates = zeros(0, 2);
    wideOffsets = [-200 -120 -60 0 60 120 200];
    for dx = wideOffsets
        for dy = wideOffsets
            candidates(end+1,:) = [idealCx + dx, idealCy + dy]; %#ok<AGROW>
        end
    end
    if isInterComp && size(involvedCompPos,1) >= 2
        cp1 = involvedCompPos(1,:); cp2 = involvedCompPos(2,:);
        gapMidX = (cp1(1)+cp1(3)/2 + cp2(1)+cp2(3)/2) / 2;
        gapMidY = (cp1(2)+cp1(4)/2 + cp2(2)+cp2(4)/2) / 2;
        for dx = -40:10:40
            for dy = -40:10:40
                candidates(end+1,:) = [gapMidX+dx, gapMidY+dy]; %#ok<AGROW>
            end
        end
    end
end

%% === Candidate Evaluation (with spatial grid) ===
function scores = evaluateCandidates(candidates, nCand, connCenters, nConn, ...
    excludeSet, compBounds, idealCx, idealCy, RXN_W, RXN_H, MIN_PROXIMITY, ctx, ...
    extraExclusion, extraBuffer, parentRect, gapCenter)

    scores = zeros(nCand, 1);
    nExtra = size(extraExclusion, 1);
    MIN_SPECIES_DIST = 40;  % minimum distance from connected species
    hasParent = ~isempty(parentRect);
    hasGap = ~isempty(gapCenter);
    GAP_PENALTY_WEIGHT = 50;  % penalize distance from gap center heavily

    for ci = 1:nCand
        cx = candidates(ci,1);
        cy = candidates(ci,2);
        violations = 0;
        proximityViols = 0;
        speciesTooClose = 0;
        outsideParent = false;
        inComp = false;

        rxnRect = [cx-RXN_W/2, cy-RXN_H/2, cx+RXN_W/2, cy+RXN_H/2];

        % Containment check (non-parent compartments)
        for cc = 1:size(compBounds,1)
            cb = compBounds(cc,:);
            if rxnRect(1) < cb(3) && rxnRect(3) > cb(1) && rxnRect(2) < cb(4) && rxnRect(4) > cb(2)
                inComp = true;
                break
            end
        end

        % Elimination parent containment preference
        if hasParent
            if cx < parentRect(1) || cx > parentRect(3) || ...
               cy < parentRect(2) || cy > parentRect(4)
                outsideParent = true;
            end
        end

        % Minimum distance to connected species (prevent overlapping endpoints)
        for s = 1:nConn
            d = sqrt((cx - connCenters(s,1))^2 + (cy - connCenters(s,2))^2);
            if d < MIN_SPECIES_DIST
                speciesTooClose = speciesTooClose + 1;
            end
        end

        % Line-through-block using spatial grid
        for s = 1:nConn
            scx = connCenters(s,1);
            scy = connCenters(s,2);
            nearbyBlocks = queryGridForLine(ctx.grid, cx, cy, scx, scy);
            for nb = nearbyBlocks
                if any(nb == excludeSet), continue; end
                if lineIntersectsRect(cx, cy, scx, scy, ctx.allRect(nb,:))
                    violations = violations + 1;
                end
            end
        end

        % Proximity check using spatial grid (query cells near candidate)
        candRect = [cx-MIN_PROXIMITY, cy-MIN_PROXIMITY, cx+MIN_PROXIMITY, cy+MIN_PROXIMITY];
        nearbyForProx = queryGridForRect(ctx.grid, candRect);
        for nb = nearbyForProx
            if any(nb == excludeSet), continue; end
            d = sqrt((cx - ctx.allCenter(nb,1)).^2 + (cy - ctx.allCenter(nb,2)).^2);
            if d < MIN_PROXIMITY
                proximityViols = proximityViols + 1;
            end
        end

        % Extra exclusion check (for paired reactions)
        for ei = 1:nExtra
            d = sqrt((cx - extraExclusion(ei,1))^2 + (cy - extraExclusion(ei,2))^2);
            if d < extraBuffer
                proximityViols = proximityViols + 1;
            end
        end

        % Gap-priority penalty for inter-compartment reactions:
        % strongly prefer candidates near the natural gap between compartments
        gapPenalty = 0;
        if hasGap
            gapPenalty = sqrt((cx - gapCenter(1))^2 + (cy - gapCenter(2))^2) * GAP_PENALTY_WEIGHT;
        end

        distToIdeal = sqrt((cx - idealCx).^2 + (cy - idealCy).^2);
        scores(ci) = violations*10000 + inComp*50000 + proximityViols*5000 ...
            + speciesTooClose*3000 + outsideParent*2000 + gapPenalty + distToIdeal;
    end
end

%% === Grid query for a rectangle (for proximity) ===
function blockIndices = queryGridForRect(grid, rect)
    cs = grid.cellSize;
    minX = grid.minX;
    minY = grid.minY;
    c1 = max(1, floor((rect(1) - minX) / cs) + 1);
    r1 = max(1, floor((rect(2) - minY) / cs) + 1);
    c2 = min(grid.nCols, floor((rect(3) - minX) / cs) + 1);
    r2 = min(grid.nRows, floor((rect(4) - minY) / cs) + 1);
    blockIndices = [];
    for r = r1:r2
        for c = c1:c2
            blockIndices = [blockIndices, grid.cells{r,c}]; %#ok<AGROW>
        end
    end
    blockIndices = unique(blockIndices);
end

% Copyright 2026 The MathWorks, Inc.
