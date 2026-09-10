function handleBackgroundComplete(app, taskName, future, generation)
% handleBackgroundComplete  Routes results/errors to the task's CompleteFcn.
    if ~isvalid(app); return; end
    task = app.(taskName);
    if generation ~= task.Generation; return; end
    task.Running = false;
    task.Future = [];
    task.Queue = [];
    app.(taskName) = task;
    wasCancelled = task.StopRequested || ...
        (~isempty(future.Error) && ...
         strcmp(future.Error.identifier, "parallel:fevalqueue:ExecutionCancelled"));
    try
        if wasCancelled
            task.CompleteFcn([], [], true);
        elseif ~isempty(future.Error)
            task.CompleteFcn([], future.Error, false);
        else
            nOut = max(0, nargout(task.Fcn));
            if nOut == 0
                task.CompleteFcn([], [], false);
            elseif nOut == 1
                task.CompleteFcn(fetchOutputs(future), [], false);
            else
                results = cell(1, nOut);
                [results{:}] = fetchOutputs(future);
                task.CompleteFcn(results, [], false);
            end
        end
    catch cbErr
        fprintf(2, 'Error in CompleteFcn for task ''%s'': %s\n', taskName, cbErr.getReport());
        if isvalid(app)
            uialert(app.UIFigure, cbErr.message, 'Background Task Error');
        end
    end
end

% Copyright 2026 The MathWorks, Inc.
