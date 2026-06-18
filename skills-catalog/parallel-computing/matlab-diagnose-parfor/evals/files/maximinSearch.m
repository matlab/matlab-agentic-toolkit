function [X, bestscore] = maximinSearch
n = 5;
p = 3;
maxiter = 50;

X = getsample(n, p);
bestscore = score(X);

parfor j = 2:maxiter
    x = getsample(n, p);
    newscore = score(x);
    if newscore > bestscore
        X = x;
        bestscore = newscore;
    end
end
end

function x = getsample(n, p)
x = rand(n, p);
end

function s = score(x)
d = pdist(x);
s = min(d);
end
% Copyright 2026 The MathWorks, Inc.
