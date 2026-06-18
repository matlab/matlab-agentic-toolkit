% Copyright 2026 The MathWorks, Inc.
function sz = blocksize(data, maxMemory)
    arguments
        data (:,:) double
        maxMemory (1,1) double = 1e9
    end
    bytesPerElement = 8;
    elementsPerBlock = floor(maxMemory / bytesPerElement);
    sz = min(size(data,1), floor(elementsPerBlock / size(data,2)));
end
