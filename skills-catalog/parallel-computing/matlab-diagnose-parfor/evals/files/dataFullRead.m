function data = dataFullRead(in)
n = 20;
data = zeros(n, 1, 'like', in);

parfor i = 1:n
    var = in(i) + rand(1, 10, 'like', data);
    data(i) = prod(var(var>0.2));
end
end
% Copyright 2026 The MathWorks, Inc.

