% Copyright 2026 The MathWorks, Inc.
function probeSlxModel(modelPath)
%PROBESLXMODEL Extract complete model structure and parameters as JSON.
%   probeSlxModel('path/to/model.slx') loads the model, recursively
%   walks every subsystem and block, captures all dialog parameters
%   with their current values, and writes the result to a JSON file.

    [modelDir, mdlName, ~] = fileparts(modelPath);
    if ~isempty(modelDir)
        addpath(modelDir);
    end

    load_system(modelPath);
    cleanupObj = onCleanup(@() close_system(mdlName, 0));

    info = struct();
    info.modelName       = mdlName;
    info.fileName        = modelPath;
    info.probeTimestamp   = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    info.matlabVersion   = version;
    info.simulinkVersion = '';
    slVer = ver('simulink');
    if ~isempty(slVer)
        info.simulinkVersion = slVer.Version;
    end

    %% ---- Model-level configuration ----
    cfg = struct();
    modelParams = {
        'Solver', 'SolverType', 'SolverName'
        'StartTime', 'StopTime', 'FixedStep', 'MaxStep', 'MinStep'
        'RelTol', 'AbsTol'
        'SimulationMode', 'SystemTargetFile'
        'ReturnWorkspaceOutputs', 'SaveOutput', 'SaveTime'
        'SignalLogging', 'SignalLoggingName'
        'InvariantConstants', 'BufferReuse'
        'ModelBrowserVisibility', 'ModelBrowserWidth'
    };
    for i = 1:numel(modelParams)
        pName = modelParams{i};
        try
            cfg.(pName) = get_param(mdlName, pName);
        catch
            cfg.(pName) = '<not available>';
        end
    end
    info.configuration = cfg;

    %% ---- Mask workspace variables (model-level) ----
    try
        ws = get_param(mdlName, 'ModelWorkspace');
        varNames = evalin(ws, 'whos');
        wsVars = struct();
        for i = 1:length(varNames)
            try
                val = evalin(ws, varNames(i).name);
                wsVars.(varNames(i).name) = val;
            catch
                wsVars.(varNames(i).name) = '<cannot read>';
            end
        end
        info.modelWorkspace = wsVars;
    catch
        info.modelWorkspace = struct();
    end

    %% ---- Recursive block hierarchy ----
    info.hierarchy = probeSubsystem(mdlName);

    %% ---- Signal lines (top-level connectivity) ----
    try
        lines = find_system(mdlName, 'FindAll', 'on', ...
                            'SearchDepth', 1, 'Type', 'line');
        lineInfo = {};
        for i = 1:length(lines)
            li = struct();
            li.srcBlock = get_param(lines(i), 'SrcBlockHandle');
            li.dstBlock = get_param(lines(i), 'DstBlockHandle');
            try
                li.srcBlockName = getfullname(li.srcBlock);
                li.dstBlockName = getfullname(li.dstBlock);
            catch
                li.srcBlockName = ''; li.dstBlockName = '';
            end
            li.srcPort = get_param(lines(i), 'SrcPortHandle');
            li.dstPort = get_param(lines(i), 'DstPortHandle');
            lineInfo{end+1} = li; %#ok<AGROW>
        end
        info.topLevelLines = lineInfo;
    catch
        info.topLevelLines = {};
    end

    %% ---- Write JSON output ----
    outFile = fullfile(pwd, [mdlName '_probe.json']);
    jsonText = jsonencode(info, 'PrettyPrint', true);
    fid = fopen(outFile, 'w');
    fprintf(fid, '%s', jsonText);
    fclose(fid);
    fprintf('Probe complete. Output: %s\n', outFile);
end


%% =====================================================================
function sysInfo = probeSubsystem(sysPath)
%PROBESUBSYSTEM Recursively extract block tree from a (sub)system.

    sysInfo       = struct();
    sysInfo.path  = sysPath;
    sysInfo.blocks = {};

    blocks = find_system(sysPath, 'SearchDepth', 1);
    % Remove the system itself (first result is always the parent)
    blocks = blocks(2:end);

    for i = 1:length(blocks)
        blk = blocks{i};
        b   = struct();

        %% -- Identity --
        b.name      = get_param(blk, 'Name');
        b.fullPath  = blk;
        b.blockType = get_param(blk, 'BlockType');
        try b.maskType = get_param(blk, 'MaskType'); catch; b.maskType = ''; end

        %% -- Dialog parameters (the key payload) --
        b.parameters = struct();
        try
            dlg = get_param(blk, 'DialogParameters');
            if isstruct(dlg)
                pNames = fieldnames(dlg);
                for j = 1:length(pNames)
                    pEntry = struct();
                    pEntry.value = '';
                    pEntry.type  = '';
                    pEntry.enum  = {};
                    try
                        pEntry.value = get_param(blk, pNames{j});
                    catch
                        pEntry.value = '<error>';
                    end
                    try pEntry.type = dlg.(pNames{j}).Type;   catch; end
                    try pEntry.enum = dlg.(pNames{j}).Enum;   catch; end
                    b.parameters.(pNames{j}) = pEntry;
                end
            end
        catch
        end

        %% -- Mask information --
        try
            mask = Simulink.Mask.get(blk);
            if ~isempty(mask)
                b.hasMask = true;
                b.maskDisplay = mask.Display;
                maskParams = {};
                for mp = 1:length(mask.Parameters)
                    p = mask.Parameters(mp);
                    mpi = struct();
                    mpi.name     = p.Name;
                    mpi.prompt   = p.Prompt;
                    mpi.value    = p.Value;
                    mpi.type     = p.Type;
                    mpi.evaluate = p.Evaluate;
                    try mpi.typeoptions = p.TypeOptions; catch; end
                    maskParams{end+1} = mpi; %#ok<AGROW>
                end
                b.maskParameters = maskParams;
                b.maskCallbacks = struct();
                try b.maskCallbacks.init   = mask.Initialization; catch; end
                try b.maskCallbacks.icon   = mask.Display;        catch; end
            else
                b.hasMask = false;
            end
        catch
            b.hasMask = false;
        end

        %% -- Port info --
        try
            ports = get_param(blk, 'Ports');
            b.ports = struct('inports', ports(1), 'outports', ports(2));
        catch
            b.ports = struct('inports', 0, 'outports', 0);
        end

        %% -- Position & annotations --
        try b.position = get_param(blk, 'Position'); catch; b.position = []; end

        %% -- Recurse into subsystems --
        if strcmp(b.blockType, 'SubSystem')
            try
                b.children = probeSubsystem(blk);
            catch e
                b.children = struct('error', e.message);
            end
        end

        sysInfo.blocks{end+1} = b;
    end
end
