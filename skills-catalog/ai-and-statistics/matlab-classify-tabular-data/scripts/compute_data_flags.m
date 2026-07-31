function flags = compute_data_flags(X, Y)
%COMPUTE_DATA_FLAGS  Dataset-characteristic flags consumed by Step 5.
%
%   FLAGS = COMPUTE_DATA_FLAGS(X, Y) returns a struct with the fields
%   the branch table (classifier_branches.m) and build_model_definitions
%   dispatch on:
%
%       N, D                   size(X)
%       nClasses, classSize    class count and per-class observation count
%       smallestClassSize      min(classSize)
%       classRatio             max(classSize) / min(classSize)
%       isBinary               nClasses == 2
%       isImbalanced           classRatio > 5
%       isWide                 D >= N
%       isHighD                D > 100
%       isBig                  N > 50000
%       hasManyMissing         >5% of rows contain a missing value
%       isSparse               issparse(X) — true for sparse numeric X
%       hasCategorical         true iff X is a table containing at least
%                              one categorical / cellstr / string column

    [N, D] = size(X);

    classes  = local_unique(Y);
    nClasses = numel(classes);
    classSize = zeros(nClasses, 1);
    for k = 1:nClasses
        classSize(k) = local_count(Y, classes, k);
    end

    classRatio        = max(classSize) / min(classSize);
    smallestClassSize = double(min(classSize));

    flags = struct();
    flags.N                 = N;
    flags.D                 = D;
    flags.nClasses          = nClasses;
    flags.classSize         = classSize;
    flags.smallestClassSize = smallestClassSize;
    flags.classRatio        = classRatio;
    flags.isBinary          = nClasses == 2;
    flags.isImbalanced      = classRatio > 5;
    flags.isWide            = D >= N;
    flags.isHighD           = D > 100;
    flags.isBig             = N > 50000;
    flags.hasManyMissing    = local_has_many_missing(X, N);
    flags.isSparse          = issparse(X);
    flags.hasCategorical    = local_has_categorical(X);
end

function u = local_unique(Y)
    u = unique(Y);
end

function n = local_count(Y, classes, k)
    if iscell(Y)
        n = sum(strcmp(Y, classes{k}));
    elseif isstring(Y)
        n = sum(Y == classes(k));
    else
        n = sum(Y == classes(k));
    end
end

function tf = local_has_many_missing(X, N)
    if istable(X)
        tf = sum(any(ismissing(X), 2)) / N > 0.05;
    elseif issparse(X)
        % ismissing(sparse) errors; sparse numeric X has no NaNs by construction.
        tf = false;
    else
        tf = sum(any(ismissing(X), 2)) / N > 0.05;
    end
end

function tf = local_has_categorical(X)
    if ~istable(X)
        tf = false;
        return
    end
    tf = false;
    for c = 1:width(X)
        v = X{:, c};
        if iscategorical(v) || iscellstr(v) || isstring(v)
            tf = true;
            return
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
