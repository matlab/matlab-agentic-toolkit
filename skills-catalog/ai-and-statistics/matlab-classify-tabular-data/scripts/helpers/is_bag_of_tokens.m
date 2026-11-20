function tf = is_bag_of_tokens(X)
    nzVals = nonzeros(X);
    tf = ~isempty(nzVals) && all(nzVals >= 0) && all(nzVals == floor(nzVals));

    if nargout == 0
        clear tf
    end
end

% Copyright 2026 The MathWorks, Inc.
