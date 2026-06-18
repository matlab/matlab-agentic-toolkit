% Copyright 2026 The MathWorks, Inc.
function nodes = readTreeNodes(filePath, depth)
    arguments
        filePath (1,1) string
        depth (1,1) double = Inf
    end
    nodes = struct('path', filePath, 'depth', depth);
end
