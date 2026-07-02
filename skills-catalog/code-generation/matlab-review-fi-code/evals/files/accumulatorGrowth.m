function y = accumulatorGrowth(x)
%accumulatorGrowth Sum fixed-point values with bit growth issue.
%   y = accumulatorGrowth(x) sums elements of x using a 32-bit accumulator.
%   Contains a common bug: accumulator type grows each iteration.

% Copyright 2026 The MathWorks, Inc.

acc = fi(0, 1, 32, 16);
for n = 1:numel(x)
    acc = acc + x(n);
end
y = acc;
end
