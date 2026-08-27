function tf = isAppOpen(appName)
% Internal use only
% Used by the simbiology-build-model agent skill during app lifecycle.
% NOT FOR EXTERNAL USE - Subject to change.
%
% ISAPPOPEN Check if a SimBiology app is currently open.
%   tf = isAppOpen('builder')
%   tf = isAppOpen('analyzer')
    tf = false;
    try
        switch lower(appName)
            case 'builder'
                h = SimBiology.web.desktophandler.getModelBuilder();
            case 'analyzer'
                h = SimBiology.web.desktophandler.getModelAnalyzer();
            otherwise
                return;
        end
        if ~isempty(h) && isfield(h, 'webWindow') && isvalid(h.webWindow)
            tf = true;
        end
    catch
    end
end

% Copyright 2026 The MathWorks, Inc.
