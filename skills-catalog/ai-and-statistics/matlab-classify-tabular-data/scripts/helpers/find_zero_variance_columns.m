function idx = find_zero_variance_columns(X)
%FIND_ZERO_VARIANCE_COLUMNS  Columns with at most one distinct non-missing value.
%
%   IDX = FIND_ZERO_VARIANCE_COLUMNS(X) returns the indices of the columns
%   (table variables, for a table X) that are constant: every non-missing
%   value is the same, or the column is entirely missing. A missing value is
%   never counted as a value, so a constant column with a few NaNs, and an
%   all-NaN column, are both zero-variance on every input shape.
%
%   Dense matrix: var(..., 'omitnan') is 0 (constant) or NaN (all missing).
%   Sparse matrix: walks each column's nonzeros, so the matrix is never
%       densified. A stored NaN is missing; an implicit zero is a value.
%   Table: each variable is tested on its own type — numeric and logical
%       by variance, categorical / string / cellstr by its distinct
%       non-missing values.
    if istable(X)
        D = width(X);
        mask = false(1, D);
        for j = 1:D
            mask(j) = is_constant_variable(X{:, j});
        end
        idx = find(mask);
    elseif issparse(X)
        % Do not call var on sparse data — it densifies and can exhaust memory.
        D = size(X, 2);
        N = size(X, 1);
        mask = false(1, D);
        for j = 1:D
            col = X(:, j);
            vals = nonzeros(col);
            vals = vals(~isnan(vals));
            hasImplicitZero = nnz(col) < N;
            if isempty(vals)
                mask(j) = true;                    % all zeros and/or NaNs
            elseif hasImplicitZero
                mask(j) = false;                   % zeros + nonzeros → variance > 0
            else
                mask(j) = all(vals == vals(1));    % no zeros: constant iff all equal
            end
        end
        idx = find(mask);
    else
        v = var(X, 0, 1, 'omitnan');
        idx = find(v == 0 | isnan(v));
    end

    if nargout == 0
        clear idx
    end
end

% -------------------------------------------------------------------------
function tf = is_constant_variable(v)
    if isnumeric(v) || islogical(v)
        s = var(double(v), 0, 1, 'omitnan');   % NaN for an all-missing column
        tf = all(s == 0 | isnan(s));
    else
        % categorical, string, cellstr, datetime: distinct non-missing values.
        u = unique(v(~ismissing(v)));
        tf = numel(u) <= 1;
    end
end

% Copyright 2026 The MathWorks, Inc.
