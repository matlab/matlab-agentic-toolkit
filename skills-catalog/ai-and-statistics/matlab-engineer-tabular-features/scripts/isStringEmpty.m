function Tf = isStringEmpty(Index)
%isStringEmpty True when an optional Index argument was effectively omitted.
%
%   Tf = isStringEmpty(Index) returns true when Index is an empty string or char
%   array -- the default the contract verbs (transformFeatures, describeFeatures)
%   use to mean "no subset requested, return the whole pool". A numeric, logical,
%   or non-empty string Index returns false (a real subset was asked for).

% Copyright 2026 The MathWorks, Inc.

    arguments
        Index
    end

    Tf = (isstring(Index) || ischar(Index)) && isempty(Index);
end
