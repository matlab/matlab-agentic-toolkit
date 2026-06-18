% Copyright 2026 The MathWorks, Inc.
function [grad, mag] = computeGradient(field, spacing, method)
    arguments
        field (:,:) double
        spacing (1,1) double = 1.0
        method (1,1) string = "central"
    end
    switch method
        case "central"
            [gy, gx] = gradient(field, spacing);
        case "forward"
            gx = diff(field, 1, 2) / spacing;
            gy = diff(field, 1, 1) / spacing;
    end
    grad = cat(3, gx, gy);
    mag = sqrt(gx.^2 + gy.^2);
end
