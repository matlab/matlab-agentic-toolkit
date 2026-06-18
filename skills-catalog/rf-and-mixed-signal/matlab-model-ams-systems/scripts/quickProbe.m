% Copyright 2026 The MathWorks, Inc.
function quickProbe(modelPath, blockPath)
%QUICKPROBE Extract parameters for a single block as JSON.
%   quickProbe('model.slx', 'model/BlockName') loads the model and
%   writes all dialog parameters for the specified block to quickprobe.json.

    [~, mdlName] = fileparts(modelPath);
    load_system(modelPath);
    cleanup = onCleanup(@() close_system(mdlName, 0));
    dlg = get_param(blockPath, 'DialogParameters');
    info = struct();
    if isstruct(dlg)
        for p = fieldnames(dlg)'
            info.(p{1}) = get_param(blockPath, p{1});
        end
    end
    jsonText = jsonencode(info, 'PrettyPrint', true);
    fid = fopen('quickprobe.json','w'); fprintf(fid,'%s',jsonText); fclose(fid);
    fprintf('Done: quickprobe.json\n');
end
