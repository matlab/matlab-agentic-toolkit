function ctx = buildLayoutContext(model)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% BUILDLAYOUTCONTEXT Query all block positions once and build spatial index.
%
%   ctx = buildLayoutContext(model) returns a struct containing cached
%   positions for all blocks (reactions, species, compartments) and a
%   spatial grid for fast intersection pruning.
%
%   The context eliminates redundant simbio.diagram.getBlock calls. Pass
%   it to computeSafeReactionPosition, checkDiagramLayout, and
%   repositionAllReactions to avoid re-querying the diagram API.
%
%   Fields:
%     .model        - The model handle
%     .rxnPos       - [nR x 4] array of reaction positions [x y w h]
%     .rxnRect      - [nR x 4] array of reaction rects [x1 y1 x2 y2]
%     .rxnCenter    - [nR x 2] array of reaction centers
%     .spPos        - [nS x 4] array of species positions
%     .spRect       - [nS x 4] array of species rects
%     .spCenter     - [nS x 2] array of species centers
%     .spNames      - {nS x 1} cell of qualified species names
%     .compPos      - [nC x 4] array of compartment positions
%     .compRect     - [nC x 4] array of compartment rects [x1 y1 x2 y2]
%     .compNames    - {nC x 1} cell of compartment names
%     .allRect      - [(nR+nS) x 4] combined block rects (reactions first)
%     .allCenter    - [(nR+nS) x 2] combined block centers
%     .allNames     - {(nR+nS) x 1} combined block names
%     .allTypes     - {(nR+nS) x 1} 'rxn' or 'sp'
%     .nR, .nS, .nC - counts
%     .grid         - spatial grid struct for fast lookup
%
%   See also: updateContextBlock, computeSafeReactionPosition

    allRxns  = model.Reactions;
    allSp    = model.Species;
    allComps = model.Compartments;
    nR = numel(allRxns);
    nS = numel(allSp);
    nC = numel(allComps);

    % Query all positions in one pass
    rxnPos = zeros(nR, 4);
    for i = 1:nR
        rxnPos(i,:) = simbio.diagram.getBlock(allRxns(i), 'Position');
    end

    spPos = zeros(nS, 4);
    spNames = cell(nS, 1);
    for i = 1:nS
        spPos(i,:) = simbio.diagram.getBlock(allSp(i), 'Position');
        spNames{i} = [allSp(i).Parent.Name '.' allSp(i).Name];
    end

    compPos = zeros(nC, 4);
    compNames = cell(nC, 1);
    for i = 1:nC
        compPos(i,:) = simbio.diagram.getBlock(allComps(i), 'Position');
        compNames{i} = allComps(i).Name;
    end

    % Convert positions [x y w h] to rects [x1 y1 x2 y2]
    rxnRect = [rxnPos(:,1), rxnPos(:,2), rxnPos(:,1)+rxnPos(:,3), rxnPos(:,2)+rxnPos(:,4)];
    spRect  = [spPos(:,1),  spPos(:,2),  spPos(:,1)+spPos(:,3),   spPos(:,2)+spPos(:,4)];
    compRect = [compPos(:,1), compPos(:,2), compPos(:,1)+compPos(:,3), compPos(:,2)+compPos(:,4)];

    % Centers
    rxnCenter = [(rxnRect(:,1)+rxnRect(:,3))/2, (rxnRect(:,2)+rxnRect(:,4))/2];
    spCenter  = [(spRect(:,1)+spRect(:,3))/2,   (spRect(:,2)+spRect(:,4))/2];

    % Combined arrays (reactions first, then species)
    allRect   = [rxnRect; spRect];
    allCenter = [rxnCenter; spCenter];
    allNames  = [cell(nR,1); spNames];
    allTypes  = [repmat({'rxn'}, nR, 1); repmat({'sp'}, nS, 1)];
    for i = 1:nR
        allNames{i} = allRxns(i).Reaction;
    end

    % Build spatial grid
    grid = buildGrid(allRect);

    % Assemble context
    ctx.model     = model;
    ctx.rxnPos    = rxnPos;
    ctx.rxnRect   = rxnRect;
    ctx.rxnCenter = rxnCenter;
    ctx.spPos     = spPos;
    ctx.spRect    = spRect;
    ctx.spCenter  = spCenter;
    ctx.spNames   = spNames;
    ctx.compPos   = compPos;
    ctx.compRect  = compRect;
    ctx.compNames = compNames;
    ctx.allRect   = allRect;
    ctx.allCenter = allCenter;
    ctx.allNames  = allNames;
    ctx.allTypes  = allTypes;
    ctx.nR = nR;
    ctx.nS = nS;
    ctx.nC = nC;
    ctx.grid = grid;
end

function grid = buildGrid(allRect)
% Build a spatial grid for fast block lookup.
% Each cell covers CELL_SIZE x CELL_SIZE pixels. Blocks are assigned to
% all cells they overlap.

    CELL_SIZE = 50;

    if isempty(allRect)
        grid.cellSize = CELL_SIZE;
        grid.cells = containers.Map('KeyType', 'char', 'ValueType', 'any');
        grid.minX = 0; grid.minY = 0;
        return
    end

    % Grid bounds from block extents
    minX = min(allRect(:,1)) - CELL_SIZE;
    minY = min(allRect(:,2)) - CELL_SIZE;
    maxX = max(allRect(:,3)) + CELL_SIZE;
    maxY = max(allRect(:,4)) + CELL_SIZE;

    grid.cellSize = CELL_SIZE;
    grid.minX = minX;
    grid.minY = minY;
    grid.maxX = maxX;
    grid.maxY = maxY;
    grid.nCols = ceil((maxX - minX) / CELL_SIZE);
    grid.nRows = ceil((maxY - minY) / CELL_SIZE);

    % Preallocate cell arrays (use a 2D cell array indexed by row, col)
    grid.cells = cell(grid.nRows, grid.nCols);
    for r = 1:grid.nRows
        for c = 1:grid.nCols
            grid.cells{r,c} = [];
        end
    end

    % Assign blocks to cells
    nBlk = size(allRect, 1);
    for b = 1:nBlk
        c1 = max(1, floor((allRect(b,1) - minX) / CELL_SIZE) + 1);
        r1 = max(1, floor((allRect(b,2) - minY) / CELL_SIZE) + 1);
        c2 = min(grid.nCols, floor((allRect(b,3) - minX) / CELL_SIZE) + 1);
        r2 = min(grid.nRows, floor((allRect(b,4) - minY) / CELL_SIZE) + 1);
        for r = r1:r2
            for c = c1:c2
                grid.cells{r,c}(end+1) = b;
            end
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
