# Performance Optimization

## Lazy-Load Tab Content

Only build tab contents when the user first selects a tab:

```matlab
tabGroup = uitabgroup(gl);
tab1 = uitab(tabGroup, 'Title', 'Input');
tab2 = uitab(tabGroup, 'Title', 'Results');

% Build tab1 immediately (it's visible at startup)
buildInputTab(tab1);

% Defer tab2 until selected
tabGroup.SelectionChangedFcn = @(src, event) onTabChanged(src, event);

function onTabChanged(src, event)
    if strcmp(event.NewValue.Title, 'Results') && isempty(event.NewValue.Children)
        buildResultsTab(event.NewValue);
    end
end
```

## Lazy-Load Tree Nodes

Expand tree nodes on demand instead of building the full tree at startup:

```matlab
tree = uitree(gl);
topNode = uitreenode(tree, 'Text', 'Root', 'NodeData', '/data');

% Add placeholder so expand arrow appears
uitreenode(topNode, 'Text', 'Loading...');

tree.NodeExpandedFcn = @(src, event) onNodeExpanded(event.Node);

function onNodeExpanded(node)
    if numel(node.Children) == 1 && strcmp(node.Children(1).Text, 'Loading...')
        delete(node.Children);
        files = dir(node.NodeData);
        for i = 1:numel(files)
            if files(i).isdir && ~startsWith(files(i).name, '.')
                child = uitreenode(node, 'Text', files(i).name, ...
                    'NodeData', fullfile(files(i).folder, files(i).name));
                uitreenode(child, 'Text', 'Loading...');
            end
        end
    end
end
```

## Batch Table Updates

Update table data in one operation, not column by column:

```matlab
% Bad: triggers multiple redraws
tbl.Data.Var1 = newCol1;
tbl.Data.Var2 = newCol2;
tbl.Data.Var3 = newCol3;

% Good: single update
newData = tbl.Data;
newData.Var1 = newCol1;
newData.Var2 = newCol2;
newData.Var3 = newCol3;
tbl.Data = newData;
```

## Throttling ValueChangingFcn

For sliders/knobs connected to expensive operations:

```matlab
slider.ValueChangingFcn = @(src, event) onSliderMoving(src, event, ax);

function onSliderMoving(src, event, ax)
    persistent lastUpdate
    now = tic;
    if isempty(lastUpdate) || toc(lastUpdate) > 0.05  % Max 20 fps
        lastUpdate = now;
        ax.Title.String = sprintf('Value: %.1f', event.Value);
    end
end
```

## Background Computation

Offload heavy computation so the UI stays responsive:

```matlab
btn.ButtonPushedFcn = @(src, event) onRunClicked(src, fig);

function onRunClicked(src, fig)
    src.Enable = 'off';
    dlg = uiprogressdlg(fig, 'Title', 'Computing...', 'Indeterminate', 'on');

    f = parfeval(backgroundPool, @heavyComputation, 1, inputData);
    afterEach(f, @(result) onComputeComplete(result, fig, src, dlg), 0);
end

function onComputeComplete(result, fig, btn, dlg)
    close(dlg);
    btn.Enable = 'on';
    fig.UserData.result = result;
    updateDisplay(fig);
end
```

## Startup Optimization Checklist

1. Create figure and main grid first
2. Build only the initially visible tab/panel
3. Defer expensive data loading (tables, trees) until needed
4. Use `'fit'` row heights for controls — avoids unnecessary space calculations
5. Profile with `profile on` / `profile viewer` if startup is slow

## Graphics Performance

| Technique | Benefit |
|---|---|
| `p.XData = newX` not `plot()` | Avoids object recreation |
| `animatedline` + `addpoints` | Optimal for streaming |
| `drawnow limitrate` | Caps at ~20 fps |
| Set `xlim`/`ylim` before loop | Skips auto-limit recalculation |
| `ax.Toolbar = []` | Removes toolbar overhead |
| Combine scatter objects | Fewer graphics objects |
| `set()` for multi-property | Single render pass |

## What to Profile First

Use `profile on` / `profile viewer`. Common culprits:
1. Recreating plot objects in a loop (fix: create once, update XData/YData)
2. Auto-limit recalculation (fix: set xlim/ylim before loop)
3. Too many separate graphics objects (fix: combine into one with vectorized data)
4. Full `drawnow` in tight loop (fix: use `drawnow limitrate`)
5. Building all tabs at startup (fix: lazy-load)
6. Column-by-column table updates (fix: batch into single assignment)

----

Copyright 2026 The MathWorks, Inc.

----
