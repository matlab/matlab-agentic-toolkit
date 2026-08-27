function ctx = updateContextBlock(ctx, blockIdx, newPos)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% UPDATECONTEXTBLOCK Update cached position of a block after repositioning.
%
%   ctx = updateContextBlock(ctx, blockIdx, newPos) updates the context
%   struct after a block has been moved. blockIdx is the index into
%   ctx.allRect (reactions 1..nR, species nR+1..nR+nS). newPos is [x y w h].
%
%   This avoids re-querying the diagram API and rebuilds only the affected
%   grid cells.
%
%   See also: buildLayoutContext, computeSafeReactionPosition

    oldRect = ctx.allRect(blockIdx,:);
    newRect = [newPos(1), newPos(2), newPos(1)+newPos(3), newPos(2)+newPos(4)];
    newCenter = [(newRect(1)+newRect(3))/2, (newRect(2)+newRect(4))/2];

    % Update arrays
    ctx.allRect(blockIdx,:) = newRect;
    ctx.allCenter(blockIdx,:) = newCenter;

    % Update typed arrays
    if blockIdx <= ctx.nR
        ctx.rxnPos(blockIdx,:) = newPos;
        ctx.rxnRect(blockIdx,:) = newRect;
        ctx.rxnCenter(blockIdx,:) = newCenter;
    else
        spIdx = blockIdx - ctx.nR;
        ctx.spPos(spIdx,:) = newPos;
        ctx.spRect(spIdx,:) = newRect;
        ctx.spCenter(spIdx,:) = newCenter;
    end

    % Update spatial grid: remove from old cells, add to new cells
    grid = ctx.grid;
    cs = grid.cellSize;
    minX = grid.minX;
    minY = grid.minY;

    % Remove from old cells
    oc1 = max(1, floor((oldRect(1) - minX) / cs) + 1);
    or1 = max(1, floor((oldRect(2) - minY) / cs) + 1);
    oc2 = min(grid.nCols, floor((oldRect(3) - minX) / cs) + 1);
    or2 = min(grid.nRows, floor((oldRect(4) - minY) / cs) + 1);
    for r = or1:or2
        for c = oc1:oc2
            grid.cells{r,c}(grid.cells{r,c} == blockIdx) = [];
        end
    end

    % Add to new cells (clamp to grid bounds)
    nc1 = max(1, floor((newRect(1) - minX) / cs) + 1);
    nr1 = max(1, floor((newRect(2) - minY) / cs) + 1);
    nc2 = min(grid.nCols, floor((newRect(3) - minX) / cs) + 1);
    nr2 = min(grid.nRows, floor((newRect(4) - minY) / cs) + 1);
    for r = nr1:nr2
        for c = nc1:nc2
            grid.cells{r,c}(end+1) = blockIdx;
        end
    end

    ctx.grid = grid;
end

% Copyright 2026 The MathWorks, Inc.
