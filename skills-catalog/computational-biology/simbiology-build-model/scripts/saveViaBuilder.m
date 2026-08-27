function saveViaBuilder(filePath)
% Internal use only
% Used by the simbiology-build-model agent skill during file operations.
% NOT FOR EXTERNAL USE - Subject to change.
%
% SAVEVIABUILDER Save the current model via the Builder's toolstrip save.
%   saveViaBuilder(filePath) saves the model currently open in the Builder
%   by programmatically clicking the Builder's save button. This preserves
%   diagram layout, styling (colors, font weight, text location), and
%   species block sizes — unlike sbiosaveproject which loses diagram data.
%
%   If the model was opened from an .sbproj file (via loadViaBuilder or
%   simBiologyModelBuilder(file)), clicking Save writes back to that file
%   without a dialog. If the model was created programmatically (not from
%   a file), the function uses SimBiology.internal.Project to save the
%   model with its diagram data directly.
%
%   The Builder must be open with a model loaded. Use openLiveBuilder or
%   loadViaBuilder first.
%
%   Example:
%       model = sbiomodel('Test');
%       openLiveBuilder(model);
%       % ... build model, arrange diagram ...
%       saveViaBuilder('Test.sbproj');
%
%   See also loadViaBuilder, openLiveBuilder

    if nargin < 1 || isempty(filePath)
        error('saveViaBuilder:noPath', ...
            'A file path is required. Usage: saveViaBuilder(''mymodel.sbproj'')');
    end

    if ~isAppOpen('builder')
        error('saveViaBuilder:noBuilder', ...
            'The Model Builder is not open. Open it first with openLiveBuilder or loadViaBuilder.');
    end

    mb = SimBiology.web.desktophandler.getModelBuilder();
    if isempty(mb) || ~isfield(mb, 'webWindow') || ~isvalid(mb.webWindow)
        error('saveViaBuilder:invalidBuilder', ...
            'Cannot access the Builder web window.');
    end

    filePath = char(java.io.File(filePath).getCanonicalPath());

    % Check if the Builder already has a file association by testing
    % whether clicking Save would update the target file. If the file
    % doesn't exist yet, the model was created programmatically and
    % clicking Save will open a native OS Save-As dialog that can't be
    % dismissed programmatically — skip straight to the fallback.
    %
    % NOTE ON SAVE STRATEGY:
    % We use executeJS to click the Save button as the primary path because
    % it saves whatever model the Builder has open — no model handle needed.
    % The alternative (SimBiology.internal.Project.save) preserves diagram
    % data but requires the correct model handle, which is not reliably
    % identifiable when multiple models exist on sbioroot.
    %
    % Fragility: aria-label="Save" could change in future MATLAB releases.
    % If this breaks, the fallback (internal.Project with models(end)) will
    % still work for the common single-model case.
    preInfo = dir(filePath);
    if ~isempty(preInfo)
        preDatenum = preInfo.datenum;

        % File exists — try clicking Save (may work if file is associated)
        mb.webWindow.executeJS([ ...
            'var saveBtn = document.querySelector(''[aria-label="Save"]'');' ...
            'if (saveBtn) { saveBtn.click(); }' ...
            'else { throw new Error("Save button not found"); }']);

        % Poll until file timestamp changes (save complete)
        MAX_WAIT = 10;
        elapsed = 0;
        saved = false;
        while elapsed < MAX_WAIT
            postInfo = dir(filePath);
            if ~isempty(postInfo) && postInfo.datenum > preDatenum
                saved = true;
                break
            end
            pause(0.5);
            elapsed = elapsed + 0.5;
        end
        if saved
            fprintf('Saved via Builder to %s\n', filePath);
            return;
        end
    end

    % No file association (new model or file doesn't exist yet).
    % Use SimBiology.internal.Project to save model + diagram directly.
    root = sbioroot;
    models = root.Models;
    if isempty(models)
        error('saveViaBuilder:noModel', 'No model found on sbioroot.');
    end

    proj = SimBiology.internal.Project;
    proj.Models = models(end);
    proj.save(filePath);
    fprintf('Saved via Project to %s\n', filePath);
end

% Copyright 2026 The MathWorks, Inc.
