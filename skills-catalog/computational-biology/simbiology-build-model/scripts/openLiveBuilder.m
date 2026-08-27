function openLiveBuilder(model)
% Internal use only
% Used by the simbiology-build-model agent skill during app lifecycle.
% NOT FOR EXTERNAL USE - Subject to change.
%
% OPENLIVEBUILDER Open the SimBiology Model Builder with safe-open pattern.
%   openLiveBuilder(model) opens the Builder for the given model. If the
%   Builder is already open with the same model, this is a no-op. If it is
%   open with a different model (or in a stale state), it is closed and
%   reopened.
%
%   Example:
%     model = sbiomodel('MyModel');
%     openLiveBuilder(model);

    % Check if Builder is already open with this model
    if isAppOpen('builder')
        if builderHasModel(model)
            return  % Already showing the right model — nothing to do
        end

        % Builder is open but with a different model — close it
        try
            mb = SimBiology.web.desktophandler.getModelBuilder();
            if ~isempty(mb) && isfield(mb, 'webWindow') && isvalid(mb.webWindow)
                mb.webWindow.close();
            end
        catch
        end
        waitForBuilderClosed();
    end

    % Open Builder — can't pass model arg when Analyzer is open
    if isAppOpen('analyzer')
        simBiologyModelBuilder();
    else
        simBiologyModelBuilder(model);
    end
    waitForDiagramReady(model);
end

%% === Helper: test if Builder currently has the target model loaded ===
function tf = builderHasModel(model)
% Tests diagram access on the model's first compartment or species.
% If getBlock succeeds, the Builder has this model's diagram active.
    tf = false;
    try
        if ~isempty(model.Compartments)
            simbio.diagram.getBlock(model.Compartments(1), 'Position');
            tf = true;
        elseif ~isempty(model.Species)
            simbio.diagram.getBlock(model.Species(1), 'Position');
            tf = true;
        end
    catch
    end
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
    warning('openLiveBuilder:closeSlow', ...
        'Builder did not close within %d seconds.', MAX_WAIT);
end

%% === Helper: poll until diagram is ready for the model ===
function waitForDiagramReady(model)
    MAX_WAIT = 15;  % seconds
    elapsed = 0;
    while elapsed < MAX_WAIT
        if builderHasModel(model)
            return
        end
        pause(0.5);
        elapsed = elapsed + 0.5;
    end
    warning('openLiveBuilder:diagramSlow', ...
        'Diagram not ready within %d seconds.', MAX_WAIT);
end

% Copyright 2026 The MathWorks, Inc.
