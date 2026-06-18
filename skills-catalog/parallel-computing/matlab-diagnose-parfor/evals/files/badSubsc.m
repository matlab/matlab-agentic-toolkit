n = 100;
parfor i = 1:n
    out(i, abs(randi([1 7]))) = myFcn();
    out2(i, 1:4, i) = myNextFcn();
    for j = 1:(n-1)
        out3(i,j) = thirdFcn(i,j);
    end
end
% Copyright 2026 The MathWorks, Inc.
