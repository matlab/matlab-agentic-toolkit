function y = scalarFiLoop(x)
%scalarFiLoop Apply fixed-point quantization element-by-element.
%   y = scalarFiLoop(x) quantizes each element of x to signed 16-bit
%   fixed-point with 14 fractional bits.

% Copyright 2026 The MathWorks, Inc.

F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
           'ProductMode','KeepLSB','ProductWordLength',32, ...
           'SumMode','KeepLSB','SumWordLength',32);

N = numel(x);
for k = 1:N
    y(k) = fi(x(k), 1, 16, 14, F);
end
y = reshape(y, size(x));
end
