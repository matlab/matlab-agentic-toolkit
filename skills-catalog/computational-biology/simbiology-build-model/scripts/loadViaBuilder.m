function model = loadViaBuilder(filePath)
% Internal use only
% Used by the simbiology-build-model agent skill during file operations.
% NOT FOR EXTERNAL USE - Subject to change.
%
% LOADVIABUILDER Load an .sbproj file directly into the Builder.
%   model = loadViaBuilder(filePath) opens the .sbproj file in the Model
%   Builder by passing the file path directly to simBiologyModelBuilder.
%   This preserves diagram layout, styling (colors, font weight, text
%   location), and species block sizes — unlike sbioloadproject followed
%   by simBiologyModelBuilder(model) which loses diagram data.
%
%   The function closes any existing Builder instance before opening.
%
%   Example:
%       model = loadViaBuilder('MyModel.sbproj');
%       disp(model.uuid)
%
%   See also saveViaBuilder, openLiveBuilder

    if ~isfile(filePath)
        error('loadViaBuilder:fileNotFound', ...
            'File not found: %s', filePath);
    end

    filePath = char(java.io.File(filePath).getCanonicalPath());

    % Close existing Builder if open
    if isAppOpen('builder')
        try
            mb = SimBiology.web.desktophandler.getModelBuilder();
            if ~isempty(mb) && isfield(mb, 'webWindow') && isvalid(mb.webWindow)
                mb.webWindow.close();
            end
        catch
        end
        waitForBuilderClosed();
    end

    % Open the project file directly in the Builder
    simBiologyModelBuilder(filePath);

    % Poll until model appears on sbioroot
    model = waitForModelLoaded(filePath);

    fprintf('Loaded %s from %s (layout and styling preserved).\n', ...
        model.Name, filePath);
end

%% === Helper: poll until Builder is closed ===
function waitForBuilderClosed()
    MAX_WAIT = 10;  % seconds
    elapsed = 0;
    while elapsed < MAX_WAIT
        if ~isAppOpen('builder')
            return
        end
        pause(0.5);
        elapsed = elapsed + 0.5;
    end
    warning('loadViaBuilder:closeSlow', ...
        'Builder did not close within %d seconds.', MAX_WAIT);
end

%% === Helper: poll until model appears on sbioroot and diagram is ready ===
function model = waitForModelLoaded(filePath)
    MAX_WAIT = 15;  % seconds
    elapsed = 0;
    while elapsed < MAX_WAIT
        root = sbioroot;
        if ~isempty(root.Models)
            model = root.Models(end);
            % Verify diagram is accessible
            try
                if ~isempty(model.Compartments)
                    simbio.diagram.getBlock(model.Compartments(1), 'Position');
                    return
                elseif ~isempty(model.Species)
                    simbio.diagram.getBlock(model.Species(1), 'Position');
                    return
                else
                    return  % Empty model, nothing to verify diagram on
                end
            catch
                % Model loaded but diagram not ready yet
            end
        end
        pause(0.5);
        elapsed = elapsed + 0.5;
    end
    error('loadViaBuilder:noModel', ...
        'No model with ready diagram found on sbioroot after loading %s (waited %d s).', ...
        filePath, MAX_WAIT);
end

% Copyright 2026 The MathWorks, Inc.
