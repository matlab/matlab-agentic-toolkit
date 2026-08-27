function [X, Y] = apply_preproc(preproc, X, Y)
% APPLY_PREPROC  Replay recorded data-preparation operations on new data.
%
%   [X, Y] = APPLY_PREPROC(PREPROC, X, Y) walks PREPROC (a struct array
%   written by the parent skill during Step 2 "Analyze and clean data")
%   and applies each recorded operation to X (and Y where relevant) in
%   order.
%
%   Every PREPROC entry has:
%       .op          char, one of 'omitColumns', 'dropZeroVariance',
%                    'removeClasses', 'mergeClasses'
%       .payload     op-specific data:
%           omitColumns.columnNames    cellstr (table X) OR
%           omitColumns.columnIndices  numeric row vector (matrix X)
%           dropZeroVariance.columnNames  cellstr (table X) OR
%           dropZeroVariance.columnIndices  numeric row vector (matrix X)
%           removeClasses.classes      cellstr of class labels
%           mergeClasses.map           struct with fields:
%                                        .from — cellstr of source labels
%                                        .to   — char, target label
%       .note        (optional) char — human-readable description
%
%   Y may be any label container the skill supports (categorical, string,
%   cellstr, or numeric). Class-editing ops only apply when Y is
%   categorical or coercible to one.

    arguments
        preproc struct
        X
        Y
    end

    for k = 1:numel(preproc)
        op = preproc(k).op;
        payload = preproc(k).payload;
        switch op
            case 'omitColumns'
                X = drop_columns(X, payload);
            case 'dropZeroVariance'
                X = drop_columns(X, payload);
            case 'removeClasses'
                [X, Y] = remove_classes(X, Y, payload.classes);
            case 'mergeClasses'
                Y = merge_classes(Y, payload.map);
            otherwise
                error('apply_preproc:unknownOp', ...
                    'Unknown preproc op "%s"', op);
        end
    end
end

% -------------------------------------------------------------------------
function X = drop_columns(X, payload)
    if istable(X)
        if isfield(payload, 'columnNames') && ~isempty(payload.columnNames)
            keep = ~ismember(X.Properties.VariableNames, payload.columnNames);
            X = X(:, keep);
        elseif isfield(payload, 'columnIndices') && ~isempty(payload.columnIndices)
            keep = true(1, width(X));
            keep(payload.columnIndices) = false;
            X = X(:, keep);
        end
    else
        if isfield(payload, 'columnIndices') && ~isempty(payload.columnIndices)
            keep = true(1, size(X, 2));
            keep(payload.columnIndices) = false;
            X = X(:, keep);
        elseif isfield(payload, 'columnNames') && ~isempty(payload.columnNames)
            error('apply_preproc:namedDropOnMatrix', ...
                'Cannot drop columns by name from a numeric matrix.');
        end
    end
end

% -------------------------------------------------------------------------
function [X, Y] = remove_classes(X, Y, classes)
    if iscategorical(Y)
        mask = ismember(Y, classes);
    elseif isstring(Y) || iscellstr(Y)
        mask = ismember(cellstr(Y), classes);
    else
        mask = ismember(Y, classes);
    end
    keep = ~mask;
    X = X(keep, :);
    Y = Y(keep);
    if iscategorical(Y)
        Y = removecats(Y);
    end
end

% -------------------------------------------------------------------------
function Y = merge_classes(Y, mapSpec)
    from = mapSpec.from;
    to   = mapSpec.to;
    if iscategorical(Y)
        Y = mergecats(Y, from, to);
    elseif isstring(Y)
        Y = arrayfun(@(v) merge_scalar(v, from, to), Y);
    elseif iscellstr(Y)
        Y = cellfun(@(v) char(merge_scalar(string(v), from, to)), Y, 'UniformOutput', false);
    else
        error('apply_preproc:mergeUnsupportedY', ...
            'mergeClasses op requires Y to be categorical, string, or cellstr.');
    end
end

% -------------------------------------------------------------------------
function v = merge_scalar(v, from, to)
    if any(v == string(from))
        v = string(to);
    end
end

% Copyright 2026 The MathWorks, Inc.
