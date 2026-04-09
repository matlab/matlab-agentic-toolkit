function dumpVars(label, varargin)
%dumpVars Print variable names, sizes, and values for debugging.
%
%   dumpVars(label, name1, val1, name2, val2, ...)
%
%   Prints a labeled summary of each variable's name, size, class, and
%   value (for scalars and strings). Use to inspect variable state at a
%   point in execution without pausing.

    fprintf('\n=== %s ===\n', label);
    for k = 1:2:numel(varargin)
        name = varargin{k};
        val = varargin{k+1};
        fprintf('  %s: [%s %s]', name, ...
            strjoin(string(size(val)), 'x'), class(val));
        if isscalar(val) && isnumeric(val)
            fprintf(' = %.6g', val);
        elseif isstring(val) || ischar(val)
            fprintf(' = "%s"', string(val));
        end
        fprintf('\n');
    end
end
