function y = growingArray(x, alpha)
%growingArray Filter values using EMA and collect deviations.
%   y = growingArray(x, alpha) computes an exponential moving average and
%   collects values that exceed the running average into an output array.

% Copyright 2026 The MathWorks, Inc.

x_fi = fi(x, 1, 16, 14);
alpha_fi = fi(alpha, 1, 16, 15);
one_minus_alpha = fi(1 - alpha, 1, 16, 15);

y = [];
ema = fi(0, 1, 16, 14);
for k = 1:numel(x_fi)
    ema(:) = alpha_fi * x_fi(k) + one_minus_alpha * ema;
    if x_fi(k) > ema
        y = [y, x_fi(k)]; %#ok<AGROW>
    end
end
end
