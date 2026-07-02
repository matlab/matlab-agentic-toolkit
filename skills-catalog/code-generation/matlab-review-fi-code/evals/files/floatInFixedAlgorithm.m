function y = floatInFixedAlgorithm(x)
%floatInFixedAlgorithm Mixed float/fixed algorithm with unnecessary double cast.
%   Applies a gain, then uses log2 for compression (high dynamic range),
%   then quantizes the output.

% Copyright 2026 The MathWorks, Inc.

F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
           'SumMode','KeepLSB','SumWordLength',32, ...
           'ProductMode','KeepLSB','ProductWordLength',32);

x_fi = fi(x, 1, 16, 14, F);
gained = x_fi * fi(2.5, 1, 16, 14, F);

% High dynamic range section - cast to double for log2
wide = double(gained);
compressed = log2(abs(wide) + 1);

% Back to fixed-point output
y = fi(compressed, 1, 16, 12, F);
end
