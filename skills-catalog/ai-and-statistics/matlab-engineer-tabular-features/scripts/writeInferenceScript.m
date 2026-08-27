function [ScriptPath, MatPath] = writeInferenceScript(Recipe, SelectedNames, OutputDir, Options)
%writeInferenceScript Emit a self-contained inference function + companion .mat.
%
%   [ScriptPath, MatPath] = writeInferenceScript(Recipe, SelectedNames, ...
%       OutputDir) writes two deliverables to OutputDir:
%     1. fe_transform_<dataset>.mat  - the pool recipe plus the selected column
%        names (the complete inference state).
%     2. fe_transform_<dataset>.m    - a function that loads the .mat, reproduces
%        the engineered pool, and subsets to the selected columns, so new raw
%        data is turned into the exact engineered+selected feature set with one
%        call.
%
%   The recipe IS the inference recipe, and it is generator-agnostic -- the same
%   two producer shapes the pool contract handles (see transformFeatures):
%     - an SMLT FeatureTransformer (from generateFeatures / gencfeatures /
%       genrfeatures): transform(Transformer, NewRawTbl, SelectedNames) reproduces
%       the selected columns natively.
%     - a domain recipe struct (Kind == "domain"): its .Apply handle replays the
%       captured extraction, and the emitted function subsets that pool to the
%       selected names. If the recipe also carries an optional .ApplySelected
%       handle, the emitted function calls it to compute only the selected columns
%       directly, sparing a large pool the full-then-discard cost.
%   Either way no op-log replay is needed. The emitted function INLINES its logic
%   (it never calls this skill's scripts/, which are not on the path at inference
%   time) and loads its companion .mat from its own folder via mfilename, so the
%   pair is relocatable together.
%
%   Inputs:
%     Recipe        - the pool recipe: an SMLT FeatureTransformer from
%                     generateFeatures, or a domain recipe struct (Kind=="domain"
%                     with an Apply function handle)
%     SelectedNames - (1,:) string, the delivered feature column names
%     OutputDir     - (1,1) string, destination folder (created if absent)
%     Options.DatasetName (1,1) string = "dataset"  names the file pair
%     Options.ResponseVar (1,1) string = ""         documented as optional /
%                                                    ignored on new data
%
%   Outputs:
%     ScriptPath - full path to the emitted .m function
%     MatPath    - full path to the companion .mat

% Copyright 2026 The MathWorks, Inc.

    arguments
        Recipe
        SelectedNames (1,:) string
        OutputDir (1,1) string
        Options.DatasetName (1,1) string = "dataset"
        Options.ResponseVar (1,1) string = ""
    end

    if ~isfolder(OutputDir)
        mkdir(OutputDir);
    end

    % The emitted function's name must be a valid MATLAB identifier; the file
    % stem and the companion .mat share it so the pair is unambiguous.
    FcnName = "fe_transform_" + matlab.lang.makeValidName(Options.DatasetName);
    ScriptPath = fullfile(OutputDir, FcnName + ".m");
    MatPath = fullfile(OutputDir, FcnName + ".mat");

    SelectedNames = string(SelectedNames);

    % Dispatch on the recipe shape. The companion .mat stores the recipe under a
    % shape-specific variable name, and the emitted function reproduces the
    % selected set with the matching call -- both branches inline everything the
    % deliverable needs so it depends on nothing from this skill at inference time.
    if isa(Recipe, "FeatureTransformer")
        Transformer = Recipe; % named for the emitted loader's load() call
        save(MatPath, "Transformer", "SelectedNames");
        writeSmltFunctionFile(ScriptPath, FcnName, Options.ResponseVar);
    elseif isDomainRecipe(Recipe, "Apply")
        save(MatPath, "Recipe", "SelectedNames");
        writeDomainFunctionFile(ScriptPath, FcnName, Options.ResponseVar);
    else
        error("writeInferenceScript:unknownRecipe", ...
            ['Recipe must be an SMLT FeatureTransformer or a domain recipe ' ...
            'struct (Kind == "domain" with an Apply function handle).']);
    end

    fprintf('Wrote inference function to %s\n', ScriptPath);
    fprintf('Wrote inference state to    %s\n', MatPath);
end


function writeSmltFunctionFile(ScriptPath, FcnName, ResponseVar)
%writeSmltFunctionFile Emit the SMLT-transformer inference function source.
    FcnChar = char(FcnName);
    Body = { ...
        '', ...
        '    % The transformer reproduces engineered columns deterministically and', ...
        '    % subsets to the consensus-selected set natively -- passing the names to', ...
        '    % transform returns just those columns, in order, and errors on any that', ...
        '    % are unknown. (This may be the whole pool if selection kept everything.)', ...
        '    Features = transform(S.Transformer, RawTbl, string(S.SelectedNames));' };
    % The SMLT transformer consumes a table -- constrain the input to one.
    emitFunctionFile(ScriptPath, FcnChar, ResponseVar, ...
        'the fitted FeatureTransformer', ["Transformer", "SelectedNames"], Body, ...
        InputName = "RawTbl", ConstrainTable = true);
end


function writeDomainFunctionFile(ScriptPath, FcnName, ResponseVar)
%writeDomainFunctionFile Emit the domain-recipe inference function source.
%   The subset-by-name logic mirrors transformFeatures/subsetDomainPool, inlined
%   here because scripts/ is not on the path at inference time.
    FcnChar = char(FcnName);
    Body = { ...
        '', ...
        '    % Reproduce the selected columns from the captured domain extraction.', ...
        '    % If the recipe carries an ApplySelected handle it computes ONLY the', ...
        '    % requested columns (cheaper for a large pool); otherwise replay the full', ...
        '    % Apply and subset by name. Both are self-contained -- the recipe carries', ...
        '    % whatever the extraction needs -- and both subset in requested order.', ...
        '    Names = string(S.SelectedNames);', ...
        '    if isfield(S.Recipe, ''ApplySelected'') && ...', ...
        '            isa(S.Recipe.ApplySelected, ''function_handle'')', ...
        '        Pool = S.Recipe.ApplySelected(RawInput, Names);', ...
        '    else', ...
        '        Pool = S.Recipe.Apply(RawInput);', ...
        '    end', ...
        '    if ~istable(Pool)', ...
        sprintf('        error(''%s:notTable'', ...', FcnChar), ...
        '            ''The captured extraction must return a table.'');', ...
        '    end', ...
        '    Have = string(Pool.Properties.VariableNames);', ...
        '    Missing = setdiff(Names, Have, ''stable'');', ...
        '    if ~isempty(Missing)', ...
        sprintf('        error(''%s:missingColumns'', ...', FcnChar), ...
        '            ''Reproduced pool is missing selected column(s): %s.'', ...', ...
        '            strjoin(Missing, '', ''));', ...
        '    end', ...
        '    Features = Pool(:, Names);' };
    % A domain extraction consumes the raw data in its native form (table, signal
    % matrix, image cell array, datastore) -- do NOT constrain the input to a table.
    emitFunctionFile(ScriptPath, FcnChar, ResponseVar, ...
        'the captured domain extraction recipe', ["Recipe", "SelectedNames"], Body, ...
        InputName = "RawInput", ConstrainTable = false);
end


function emitFunctionFile(ScriptPath, FcnChar, ResponseVar, StateDesc, LoadVars, BodyLines, Options)
%emitFunctionFile Write a fe_transform_<dataset>.m file: shared header + body.
%   StateDesc names what the companion .mat holds; LoadVars are the variables the
%   emitted loader pulls from it; BodyLines are the branch-specific reproduce +
%   subset statements.
%   Options.InputName      the emitted function's input argument name (the SMLT
%                          branch consumes a table, "RawTbl"; the domain branch
%                          consumes raw data in its native form, "RawInput").
%   Options.ConstrainTable whether the arguments block types the input as a table
%                          (true for SMLT; false for a domain extraction, whose
%                          raw input may be a matrix, cell array, datastore, ...).
    arguments
        ScriptPath
        FcnChar
        ResponseVar
        StateDesc
        LoadVars
        BodyLines
        Options.InputName (1,1) string = "RawTbl"
        Options.ConstrainTable (1,1) logical = true
    end

    InArg = char(Options.InputName);

    Fid = fopen(ScriptPath, 'w');
    if Fid < 0
        error('writeInferenceScript:cannotOpen', ...
            'Could not open "%s" for writing.', ScriptPath);
    end
    Closer = onCleanup(@() fclose(Fid));

    if strlength(ResponseVar) > 0
        RespNote = sprintf(['%%   The response column ("%s") is optional in %s and is ' ...
            'ignored if present.'], char(ResponseVar), InArg);
    else
        RespNote = sprintf(['%%   The response column is optional in %s and is ignored ' ...
            'if present.'], InArg);
    end

    LoadList = char(strjoin("'" + LoadVars + "'", ', '));

    % The SMLT transformer needs a table; a domain extraction takes the raw data in
    % whatever form it consumes, so its input is left unconstrained.
    if Options.ConstrainTable
        ArgLine = sprintf('        %s table', InArg);
        InputNote = sprintf(['%%   + consensus-selected feature set. %s must contain the ' ...
            'same predictor'], InArg);
        InputNote2 = '%   columns that were present when the recipe was built.';
    else
        ArgLine = sprintf('        %s', InArg);
        InputNote = sprintf(['%%   + consensus-selected feature set. %s is the raw data in ' ...
            'the same form the'], InArg);
        InputNote2 = '%   captured extraction consumed when the recipe was built.';
    end

    Head = { ...
        sprintf('function Features = %s(%s)', FcnChar, InArg), ...
        sprintf('%%%s Reproduce the engineered + selected feature set on new raw data.', FcnChar), ...
        sprintf('%%   Features = %s(%s) turns new raw data into the exact engineered', FcnChar, InArg), ...
        InputNote, ...
        InputNote2, ...
        RespNote, ...
        '%', ...
        sprintf('%%   Companion data (%s.mat, in this file''s folder) holds %s', FcnChar, StateDesc), ...
        '%   and the selected column names.', ...
        '', ...
        '% Generated by the matlab-engineer-tabular-features skill.', ...
        '', ...
        '    arguments', ...
        ArgLine, ...
        '    end', ...
        '', ...
        '    Here = fileparts(mfilename(''fullpath''));', ...
        sprintf('    S = load(fullfile(Here, ''%s.mat''), %s);', FcnChar, LoadList) };

    Tail = { 'end', '' };
    L = [Head, BodyLines, Tail];

    fprintf(Fid, '%s\n', L{:});
end
