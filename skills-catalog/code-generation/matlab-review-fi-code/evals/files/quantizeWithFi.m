function y = quantizeWithFi(x)
%quantizeWithFi Quantize a double signal using fi objects unnecessarily.
%   y = quantizeWithFi(x) applies 12-bit quantization to the input signal
%   but keeps the result in double for further processing.

% Copyright 2026 The MathWorks, Inc.

N = numel(x);
y = zeros(size(x));

for k = 1:N
    temp = fi(x(k), 1, 12, 10, 'RoundingMethod', 'Floor', 'OverflowAction', 'Wrap');
    y(k) = double(temp);
end
end
