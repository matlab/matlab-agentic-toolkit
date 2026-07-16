# Animation and Streaming Data

## Update in Place (Primary Pattern)

Create the plot object once, then update its data properties:

```matlab
p = plot(ax, x, y, 'LineWidth', 1.5);
xlim(ax, [0 10]);
ylim(ax, [-1 1]);

for k = 1:N
    p.YData = newData(k, :);
    drawnow limitrate
end
```

MUST set axis limits before the loop to skip auto-limit recalculation.

## animatedline (Growing/Streaming Data)

```matlab
a = animatedline(ax, 'Color', [0 0.45 0.74], 'LineWidth', 1.5);
a.MaximumNumPoints = 500;  % rolling window — auto-drops old points

xlim(ax, [0 20]);
ylim(ax, [-1 1]);

for k = 1:N
    addpoints(a, t(k), signal(k));
    drawnow limitrate
end
```

**Key methods:** `addpoints(a, x, y)`, `clearpoints(a)`, `getpoints(a)`

## Preallocate with NaN

```matlab
p = plot(ax, NaN(1, 1000), NaN(1, 1000));
for i = 1:1000
    p.XData(i) = t(i);
    p.YData(i) = signal(i);
    if mod(i, 10) == 0  % update display every 10 points
        drawnow limitrate
    end
end
```

## Batch Multi-Property Update

```matlab
set(p, 'XData', newX, 'YData', newY, 'Color', [1 0 0]);
```

## Timer-Based Streaming

```matlab
tmr = timer('ExecutionMode', 'fixedRate', 'Period', 0.05, ...
    'TimerFcn', @(~,~) updateSignal(), 'BusyMode', 'drop');
start(tmr);

fig.CloseRequestFcn = @(~,~) cleanup();

function cleanup()
    stop(tmr);
    delete(tmr);
    delete(fig);
end
```

Use `'BusyMode', 'drop'` to skip missed frames rather than queuing them.

## Performance Summary

| Technique | Benefit |
|---|---|
| `p.XData = newX` not `plot()` | Avoids object recreation |
| `animatedline` + `addpoints` | Optimal for streaming data |
| `drawnow limitrate` | Caps at ~20 fps, prevents backlog |
| Set `xlim`/`ylim` before loop | Skips auto-limit recalculation |
| `ax.Toolbar = []` | Removes toolbar overhead |
| `disableDefaultInteractivity(ax)` | Removes interaction overhead |
| Batch `addpoints` calls | Reduces render frequency |
| Combine scatter objects | 1 scatter with N points vs N scatter with 1 point |
| `set()` for multi-property | Single render pass |

----

Copyright 2026 The MathWorks, Inc.

----
