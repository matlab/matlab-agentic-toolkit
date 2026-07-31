function result = benchmarkMex(mexName, inputs, opts)
%benchmarkMex Convergence-based GPU MEX benchmark using gputimeit.
%
%   result = benchmarkMex(mexName, inputs) measures end-to-end execution
%   time of a GPU Coder MEX function using gputimeit in an adaptive loop
%   that stops when measurements converge.
%
%   result = benchmarkMex(mexName, inputs, WarmupIter=5, Tolerance=0.03)
%   overrides default parameters.
%
%   Inputs:
%     mexName - Name of the MEX function (string)
%     inputs  - Cell array of input arguments to pass to the MEX
%
%   Output struct fields:
%     result.MedianTime      - Median of converged measurements (seconds)
%     result.AllTimes        - All recorded gputimeit values (seconds)
%     result.NumIterations   - Total number of gputimeit calls made
%     result.Converged       - true if CV dropped below tolerance before MaxIter
%
%   Example:
%     result = benchmarkMex("myDesign_mex", {randn(256), randn(256,1)});
%     fprintf("Time: %.4f ms\n", result.MedianTime * 1000);

    arguments
        mexName (1,1) string
        inputs (1,:) cell
        opts.WarmupIter (1,1) double {mustBePositive, mustBeInteger} = 3
        opts.WindowSize (1,1) double {mustBePositive, mustBeInteger} = 5
        opts.MaxIter (1,1) double {mustBePositive, mustBeInteger} = 50
        opts.Tolerance (1,1) double {mustBePositive} = 0.02
    end

    fcn = @() feval(mexName, inputs{:});

    % Warmup: lazy init, cuBLAS/cuDNN handle creation, memory pool allocation
    for i = 1:opts.WarmupIter
        fcn();
    end
    wait(gpuDevice);

    % Convergence-based measurement
    times = [];
    window = [];

    while true
        t = gputimeit(fcn);
        times(end+1) = t; %#ok<AGROW>

        window(end+1) = t; %#ok<AGROW>
        if numel(window) > opts.WindowSize
            window(1) = [];
        end

        if numel(times) >= opts.MaxIter
            break;
        end

        if numel(window) >= opts.WindowSize
            cv = std(window) / mean(window);
            if cv <= opts.Tolerance
                break;
            end
        end
    end

    result.MedianTime = median(times);
    result.AllTimes = times;
    result.NumIterations = numel(times);
    result.Converged = numel(times) < opts.MaxIter;

    fprintf("Benchmark: %.4f ms (median, %d iterations, %s)\n", ...
        result.MedianTime * 1000, result.NumIterations, ...
        string(tern(result.Converged, "converged", "hit max")));
end

function out = tern(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

% Copyright 2026 The MathWorks, Inc.
