function startBackground(app, taskName, varargin)
% startBackground  Launch a background task. Pass task arguments after the name.
%   app.startBackground('TaskName', arg1, arg2, ...)
    task = app.(taskName);
    if task.Running
        error('Background work is already running. Cancel it first.');
    end
    task.Running = true;
    task.StopRequested = false;
    task.Generation = task.Generation + 1;
    generation = task.Generation;
    nOut = max(0, nargout(task.Fcn));
    if ~isempty(task.ProgressFcn)
        task.Queue = parallel.pool.DataQueue;
        afterEach(task.Queue, @(d) app.safeProgress(taskName, d, generation));
        queue = task.Queue;
        sendProgress = @(data) send(queue, struct(Type="Progress", Data={data}));
        task.Future = parfeval(backgroundPool, task.Fcn, nOut, varargin{:}, sendProgress);
        afterAll(task.Future, @(~) send(queue, struct(Type="Finished")), 0, 'PassFuture', true);
    else
        task.Future = parfeval(backgroundPool, task.Fcn, nOut, varargin{:});
        afterAll(task.Future, @(f) app.handleBackgroundComplete(taskName, f, generation), 0, 'PassFuture', true);
    end
    app.(taskName) = task;
end

% Copyright 2026 The MathWorks, Inc.
