function cancelBackground(app, taskName)
% cancelBackground  Cancel a running background task (no-op if idle).
    task = app.(taskName);
    hadFuture = ~isempty(task.Future);
    task.StopRequested = true;
    task.Running = false;
    app.(taskName) = task;
    if hadFuture
        cancel(task.Future);
    end
end

% Copyright 2026 The MathWorks, Inc.
