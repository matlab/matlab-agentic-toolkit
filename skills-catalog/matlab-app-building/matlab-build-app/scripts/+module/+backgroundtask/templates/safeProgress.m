function safeProgress(app, taskName, msg, generation)
% safeProgress  Wraps progress callbacks so errors appear in Command Window.
    if ~isvalid(app); return; end
    task = app.(taskName);
    if generation ~= task.Generation; return; end
    if msg.Type == "Progress"
        if ~task.Running; return; end
        if isempty(task.ProgressFcn); return; end
        try
            task.ProgressFcn(msg.Data);
        catch bgErr
            fprintf(2, 'Progress callback error (disabling): %s\n', bgErr.getReport());
            task.ProgressFcn = [];
            app.(taskName) = task;
        end
    else
        app.handleBackgroundComplete(taskName, task.Future, generation);
    end
end

% Copyright 2026 The MathWorks, Inc.
