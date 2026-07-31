function savedPath = save_selected_models(selectedNames, modelDefs, trainedModels, X, Y, savePath, metadata, useCompact)
% SAVE_SELECTED_MODELS  Save user-selected trained classifiers to a .mat file.
%
%   SAVE_SELECTED_MODELS(NAMES, MODELDEFS, TRAINED, X, Y, PATH, META, USECOMPACT)
%   writes a MAT file at PATH containing one variable per selected model
%   plus a scalar METADATA struct with dataset-shape and workflow context.
%
%   Inputs:
%       selectedNames  cellstr — subset of {modelDefs.name}
%       modelDefs      struct array from build_model_definitions (must
%                        include .fitFcn for the CV path)
%       trainedModels  cell array aligned with modelDefs. On the HOLDOUT
%                        path each cell holds a trained model returned by
%                        train_and_score_holdout. On the CV path each cell
%                        holds the cross-validated model returned by
%                        train_and_score_cv (a CV wrapper — NOT deployable);
%                        the helper detects this and RETRAINS on (X, Y)
%                        via modelDefs(k).fitFcn to produce a deployable
%                        single model before saving.
%       X, Y           full training data (CV path) OR training subset
%                        (holdout path). Only used when a CV-wrapped model
%                        must be retrained.
%       savePath       full path to the output .mat file
%       metadata       scalar struct — free-form context to store alongside
%                        the models (e.g., dataset name, evaluation path,
%                        accuracies, CI). At minimum should carry .savedAt.
%       useCompact     scalar logical (default true). When true, models
%                        that support compact() are compacted before save;
%                        models without a compact method are saved as-is.
%                        Compact models drop the training data reference,
%                        producing a much smaller .mat file suitable for
%                        deployment but no longer capable of resubstitution
%                        loss or CV.
%
%   Output:
%       savedPath      the actual path the file was written to (same as
%                        the input, but returned for logging).
%
%   Model variable names are sanitized: hyphens and other non-identifier
%   characters in modelDefs(k).name become underscores so save() and
%   subsequent load() work. The original name is preserved in
%   metadata.modelNameMap.

    arguments
        selectedNames (1,:) cell
        modelDefs (1,:) struct
        trainedModels (1,:) cell
        X
        Y
        savePath (1,:) char
        metadata (1,1) struct
        useCompact (1,1) logical = true
    end

    allNames = {modelDefs.name};
    saveStruct = struct();
    nameMap = struct();

    for k = 1:numel(selectedNames)
        name = selectedNames{k};
        idx = find(strcmp(allNames, name), 1);
        if isempty(idx)
            error('save_selected_models:unknownModel', ...
                'Model "%s" is not in modelDefs.', name);
        end
        mdl = trainedModels{idx};
        if is_cv_wrapper(mdl)
            mdl = modelDefs(idx).fitFcn(X, Y);
        end
        if useCompact && ismethod(mdl, 'compact')
            mdl = compact(mdl);
        end
        varName = sanitize_model_name(name);
        saveStruct.(varName) = mdl;
        nameMap.(varName) = name;
    end

    metadata.savedAt = datetime('now');
    metadata.useCompact = useCompact;
    metadata.modelNameMap = nameMap;
    saveStruct.metadata = metadata;

    saveDir = fileparts(savePath);
    if ~isempty(saveDir) && ~isfolder(saveDir)
        mkdir(saveDir);
    end
    save(savePath, '-struct', 'saveStruct');
    savedPath = savePath;
end

% -------------------------------------------------------------------------
function tf = is_cv_wrapper(mdl)
% CV-partitioned classification models expose kfoldLoss. Deployable
% single models do not.
    tf = ismethod(mdl, 'kfoldLoss');
end

% Copyright 2026 The MathWorks, Inc.
