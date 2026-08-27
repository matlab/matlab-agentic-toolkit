function blockIndices = queryGridForLine(grid, x1, y1, x2, y2)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% QUERYGRIDFORLINE Return block indices in cells along a line segment.
%
%   blockIndices = queryGridForLine(grid, x1, y1, x2, y2) returns the
%   unique block indices from all grid cells that the line segment from
%   (x1,y1) to (x2,y2) passes through.
%
%   This reduces intersection checks from O(allBlocks) to O(nearby blocks).
%
%   See also: buildLayoutContext, lineIntersectsRect

    cs = grid.cellSize;
    minX = grid.minX;
    minY = grid.minY;
    nRows = grid.nRows;
    nCols = grid.nCols;

    % Bounding box of the line segment
    lx1 = min(x1, x2);
    ly1 = min(y1, y2);
    lx2 = max(x1, x2);
    ly2 = max(y1, y2);

    % Grid cell range covering the bounding box
    c1 = max(1, floor((lx1 - minX) / cs) + 1);
    r1 = max(1, floor((ly1 - minY) / cs) + 1);
    c2 = min(nCols, floor((lx2 - minX) / cs) + 1);
    r2 = min(nRows, floor((ly2 - minY) / cs) + 1);

    % Collect all block indices from covered cells
    blockIndices = [];
    for r = r1:r2
        for c = c1:c2
            blockIndices = [blockIndices, grid.cells{r,c}]; %#ok<AGROW>
        end
    end
    blockIndices = unique(blockIndices);
end

% Copyright 2026 The MathWorks, Inc.
