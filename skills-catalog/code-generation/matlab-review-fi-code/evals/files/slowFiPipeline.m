function y = slowFiPipeline(x)
%slowFiPipeline Fixed-point pipeline that is slow but correct.
%   Applies cascaded gain stages with fi objects in a loop.
%   Performance is poor due to fi object construction overhead.

% Copyright 2026 The MathWorks, Inc.

gains = [0.5, 1.2, 0.8, 1.5];
N = numel(x);

for k = 1:N
    val = fi(x(k), 1, 16, 14);
    for g = 1:length(gains)
        gain_fi = fi(gains(g), 1, 16, 14);
        val = val * gain_fi;
        val = fi(double(val), 1, 16, 14);
    end
    y(k) = val;
end
end
