nIter = 200;
counts = zeros(1, 5);

parfor i = 1:nIter
    bin = randi(5);
    counts(bin) = counts(bin) + 1;
end
% Copyright 2026 The MathWorks, Inc.
