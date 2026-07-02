function [y1, y2, y3] = slowFiConstructor(a, b, c)
%slowFiConstructor Create fi values using name-value pair syntax.
%   Uses the slow name-value constructor form in a loop.

% Copyright 2026 The MathWorks, Inc.

N = numel(a);
for k = 1:N
    y1(k) = fi(a(k), 'Signed', true, 'WordLength', 16, 'FractionLength', 14);
    y2(k) = fi(b(k), 'Signed', true, 'WordLength', 24, 'FractionLength', 20);
    y3(k) = fi(c(k), 'Signed', false, 'WordLength', 8, 'FractionLength', 6);
end
end
