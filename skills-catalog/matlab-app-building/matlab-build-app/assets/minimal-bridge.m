% minimal-bridge.m  —  Copy-paste starting point for a uihtml app.
%
% Demonstrates bidirectional bridge communication:
%   MATLAB → JS : h.Data (Pattern 1)
%   JS → MATLAB : sendEventToMATLAB / HTMLEventReceivedFcn (Pattern 2)
%   MATLAB → JS : sendEventToHTMLSource (Pattern 3)
%
% Pair with minimal-bridge.html in the same folder.

function app()
    fig = uifigure('Name', 'Bridge Test', 'Position', [100 100 400 300]);
    gl = uigridlayout(fig, [1 1]);
    gl.Padding = [0 0 0 0];

    h = uihtml(gl);
    h.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'minimal-bridge.html');
    h.Data = struct('greeting', 'Hello from MATLAB!');
    h.HTMLEventReceivedFcn = @(src, event) handleEvent(src, event);
end

function handleEvent(src, event)
    try
        switch event.HTMLEventName
            case 'Ping'
                sendEventToHTMLSource(src, 'Pong', struct( ...
                    'message',   'MATLAB received your ping', ...
                    'timestamp', char(datetime('now'))));

            otherwise
                warning('bridge:unknownEvent', 'Unknown event: %s', event.HTMLEventName);
        end

    catch ME
        sendEventToHTMLSource(src, 'Error', ME.message);
    end
end

% Copyright 2026 The MathWorks, Inc.
