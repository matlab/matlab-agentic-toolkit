% Copyright 2026 The MathWorks, Inc.
function result = interpolateData(xData, yData, queryPoints, method, opts)
    arguments
        xData (1,:) double
        yData (1,:) double
        queryPoints (1,:) double
        method (1,1) string = "linear"
        opts.Tolerance (1,1) double = 1e-6
        opts.ExtrapolationMethod (1,1) string = "none"
    end
    result = interp1(xData, yData, queryPoints, method);
end
