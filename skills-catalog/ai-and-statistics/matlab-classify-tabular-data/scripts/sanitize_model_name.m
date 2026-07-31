function s = sanitize_model_name(name)
% SANITIZE_MODEL_NAME  Convert a model display name into a valid MATLAB identifier.
%
%   S = SANITIZE_MODEL_NAME(NAME) replaces every non-word character in NAME
%   with '_'. If the result begins with anything other than a letter or an
%   underscore, an 'm_' prefix is prepended so the identifier is a valid
%   variable name (safe for use as a struct field name, save target, or
%   dynamic field lookup).
%
%   Used by save_selected_models and by the retraining script emitted by
%   export_workflow_script so the two sides sanitize identically.

    arguments
        name (1,:) char
    end

    s = regexprep(name, '\W', '_');
    if ~isempty(s) && ~isletter(s(1)) && s(1) ~= '_'
        s = ['m_', s];
    end
end

% Copyright 2026 The MathWorks, Inc.
