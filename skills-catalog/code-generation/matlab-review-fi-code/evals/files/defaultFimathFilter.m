function y = defaultFimathFilter(b, x)
%defaultFimathFilter FIR filter using default fimath settings.
%   y = defaultFimathFilter(b, x) applies an FIR filter with fixed-point
%   coefficients using default fimath (Nearest/Saturate/FullPrecision).

% Copyright 2026 The MathWorks, Inc.

b_fi = fi(b, 1, 16, 15);
x_fi = fi(x, 1, 16, 14);

N = length(x_fi);
M = length(b_fi);
y = fi(zeros(1, N), 1, 32, 28);

for n = M:N
    acc = fi(0, 1, 32, 28);
    for k = 1:M
        acc = acc + b_fi(k) * x_fi(n - k + 1);
    end
    y(n) = acc;
end
end
