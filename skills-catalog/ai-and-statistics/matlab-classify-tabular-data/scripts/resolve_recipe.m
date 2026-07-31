function r = resolve_recipe(r, flags)
% RESOLVE_RECIPE  Replace function-valued args with concrete scalars.
%
%   R = RESOLVE_RECIPE(R, FLAGS) walks R.args and R.innerLearner_args,
%   replacing every function-handle value V with V(FLAGS). Returns the
%   fully-static recipe. After resolution the "args values are plain
%   scalars" invariant holds and downstream code (template
%   construction, manifest matching) can treat args uniformly.
%
%   FLAGS is the data-characteristic struct produced by
%   compute_data_flags — it must carry every field the handles refer
%   to (typically nClasses, N, D, isBinary, isBig, isHighD, ...).
%
%   Idempotent: resolving an already-resolved recipe is a no-op.

    r.args              = resolve_struct(r.args, flags);
    r.innerLearner_args = resolve_struct(r.innerLearner_args, flags);
end

function s = resolve_struct(s, flags)
    fns = fieldnames(s);
    for k = 1:numel(fns)
        v = s.(fns{k});
        if isa(v, 'function_handle')
            s.(fns{k}) = v(flags);
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
