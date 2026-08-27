function idx = find_zero_variance_columns(X)
    if issparse(X)
        % Do not call var on sparse data — it densifies and can exhaust memory.
        D = size(X, 2);
        N = size(X, 1);
        mask = false(1, D);
        for j = 1:D
            col = X(:, j);
            vals = nonzeros(col);
            if isempty(vals)
                mask(j) = true;            % all zeros → zero variance
            elseif nnz(col) < N
                mask(j) = false;           % zeros + nonzeros → variance > 0
            else
                ref = vals(1);
                mask(j) = isempty(find(vals ~= ref, 1));
            end
        end
        idx = find(mask);
    else
        v = var(X, 0, 1, 'omitnan');
        idx = find(v == 0 | isnan(v));
    end
end

% Copyright 2026 The MathWorks, Inc.
