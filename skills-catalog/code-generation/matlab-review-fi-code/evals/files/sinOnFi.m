function y = sinOnFi(theta)
%sinOnFi Compute sine of fixed-point angle values.
%   y = sinOnFi(theta) computes sin(theta) where theta is in radians.
%   Uses direct sin() call on fi input which is inefficient for codegen.

% Copyright 2026 The MathWorks, Inc.

%#codegen
F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
           'ProductMode','KeepLSB','ProductWordLength',32, ...
           'SumMode','KeepLSB','SumWordLength',32);

theta_fi = fi(theta, 1, 16, 14, F);
y = sin(theta_fi);
end
