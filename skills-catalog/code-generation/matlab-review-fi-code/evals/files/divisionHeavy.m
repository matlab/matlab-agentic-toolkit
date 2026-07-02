function y = divisionHeavy(x)
%divisionHeavy Normalize fixed-point signal using division.
%   y = divisionHeavy(x) normalizes x by dividing by constants.
%   Contains inefficient division operations for fixed-point targets.

% Copyright 2026 The MathWorks, Inc.

%#codegen
F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
           'ProductMode','KeepLSB','ProductWordLength',32, ...
           'SumMode','KeepLSB','SumWordLength',32);

x_fi = fi(x, 1, 16, 14, F);
y = fi(zeros(size(x)), 1, 16, 14, F);

for k = 1:numel(x_fi)
    y(k) = x_fi(k) / 8;
    y(k) = y(k) / 5;
end
end
