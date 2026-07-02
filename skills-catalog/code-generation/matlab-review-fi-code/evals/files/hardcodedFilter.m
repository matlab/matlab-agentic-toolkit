function y = hardcodedFilter(b, x)
%hardcodedFilter FIR filter with hardcoded fixed-point types.
%   y = hardcodedFilter(b, x) applies an FIR filter with coefficients b
%   to input signal x. Types are hardcoded inside the algorithm.

% Copyright 2026 The MathWorks, Inc.

b_fi = fi(b, 1, 16, 15);
x_fi = fi(x, 1, 16, 15);
z = fi(zeros(length(b), 1), 1, 16, 15);
y = fi(zeros(size(x)), 1, 16, 14);

for n = 1:length(x_fi)
    z = [x_fi(n); z(1:end-1)];
    y(n) = b_fi * z;
end
end
