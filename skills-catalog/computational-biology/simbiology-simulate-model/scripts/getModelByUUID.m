function model = getModelByUUID(uuid)
% Internal use only
% Used by the simbiology-build-model agent skill during model lookup.
% NOT FOR EXTERNAL USE - Subject to change.
%
% GETMODELBYUUID Look up a SimBiology model by its UUID on sbioroot.
%   model = getModelByUUID('abc-123-...')
    root = sbioroot;
    for i = 1:numel(root.Models)
        if strcmp(root.Models(i).uuid, uuid)
            model = root.Models(i);
            return;
        end
    end
    error('getModelByUUID:notFound', ...
        'Model with UUID "%s" not found. Use sbioroot.Models to see available models.', uuid);
end

% Copyright 2026 The MathWorks, Inc.
