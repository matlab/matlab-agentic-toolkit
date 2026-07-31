# Measuring dlaccelerate Speedup

Measure the actual execution time improvement from dlaccelerate after verifying tracing correctness (Step 4 in [dlaccelerate-workflow.md](dlaccelerate-workflow.md)).

If the `matlab-optimize-performance` skill is available, use it to measure end-to-end speedup as it handles warmup, `timeit`/`gputimeit`, etc.

**Critical: Run benchmarks in isolation.** Do NOT launch multiple MATLAB sessions that measure performance simultaneously. CPU/GPU contention between parallel sessions produces meaningless timing data. Run one benchmark at a time.

**Critical: Prefer functions over scripts.** Wrap any benchmarking code to a function rather running it directly in a script.

## Manual A/B Test Using accFcn.Enabled

If `matlab-optimize-performance` is not available, use the `accFcn.Enabled` property to A/B test acceleration with adaptive stopping:

```matlab
nWarmup = 5;    % increase for very fast functions
nMaxRuns = 100; % upper bound
tolCoV = 0.05;  % stop early when coefficient of variation < 5%
nMinRuns = 10;  % minimum runs before checking convergence

% Measure CPU execution time.
accFcn.Enabled = false;
for i = 1:nWarmup, dlfeval(accFcn, x, y); end
times = zeros(1, nMaxRuns);
for i = 1:nMaxRuns
    tic; dlfeval(accFcn, x, y); times(i) = toc;
    if i >= nMinRuns && std(times(1:i))/mean(times(1:i)) < tolCoV
        times = times(1:i); break;
    end
end
tBase = median(times);

accFcn.Enabled = true;
clearCache(accFcn);
for i = 1:nWarmup, dlfeval(accFcn, x, y); end
times = zeros(1, nMaxRuns);
for i = 1:nMaxRuns
    tic; dlfeval(accFcn, x, y); times(i) = toc;
    if i >= nMinRuns && std(times(1:i))/mean(times(1:i)) < tolCoV
        times = times(1:i); break;
    end
end
tAccel = median(times);

fprintf('Speedup: %.3fx\n', tBase / tAccel);
```

## GPU Timing

For GPU execution, use `wait(gpuDevice)` to synchronize before timing:

```matlab
% Measure GPU execution time (requires wait for accurate timing).
accFcn.Enabled = false;
for i = 1:nWarmup, dlfeval(accFcn, x, y); end
times = zeros(1, nMaxRuns);
for i = 1:nMaxRuns
    wait(gpuDevice); tic; dlfeval(accFcn, x, y); wait(gpuDevice); times(i) = toc;
    if i >= nMinRuns && std(times(1:i))/mean(times(1:i)) < tolCoV
        times = times(1:i); break;
    end
end
tBase = median(times);

accFcn.Enabled = true;
clearCache(accFcn);
for i = 1:nWarmup, dlfeval(accFcn, x, y); end
times = zeros(1, nMaxRuns);
for i = 1:nMaxRuns
    wait(gpuDevice); tic; dlfeval(accFcn, x, y); wait(gpuDevice); times(i) = toc;
    if i >= nMinRuns && std(times(1:i))/mean(times(1:i)) < tolCoV
        times = times(1:i); break;
    end
end
tAccel = median(times);

fprintf('Speedup: %.3fx\n', tBase / tAccel);
```

## Interpreting Results

If tAccel > tBase, acceleration is harmful, likely due to constant re-tracing. Return to [dlaccelerate-workflow.md](dlaccelerate-workflow.md) Step 2 to identify the breaking pattern.

----

Copyright 2026 The MathWorks, Inc.
