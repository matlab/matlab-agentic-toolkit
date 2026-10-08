# Interactive Plots

## Click on Plot Objects

`ButtonDownFcn` works on plot objects (lines, scatter, bars) but NOT reliably on uiaxes itself:

```matlab
p = plot(ax, x, y);
p.ButtonDownFcn = @(src, event) onLineClicked(src, event);

function onLineClicked(~, event)
    pt = event.IntersectionPoint;  % [x, y, z] in data coordinates
    fprintf('Clicked at x=%.2f, y=%.2f\n', pt(1), pt(2));
end
```

## Mouse Callbacks on Figure

```matlab
fig.WindowButtonDownFcn   = @(src, evt) onMouseDown(src, evt, ax);
fig.WindowButtonMotionFcn = @(src, evt) onMouseMove(src, evt, ax);
fig.WindowButtonUpFcn     = @(src, evt) onMouseUp(src, evt);
fig.WindowScrollWheelFcn  = @(src, evt) onScroll(src, evt, ax);
fig.WindowKeyPressFcn     = @(src, evt) onKeyPress(src, evt);
```

**Cursor position in data coordinates:**
```matlab
function onMouseMove(~, ~, ax)
    pt = ax.CurrentPoint;     % 2x3 matrix
    xData = pt(1,1);
    yData = pt(1,2);
end
```

**Key event data:** `evt.Key` (name), `evt.Character` (char), `evt.Modifier` (cell array)

**Scroll event data:** `evt.VerticalScrollCount` — positive = scroll down

## Drag Interaction Pattern

```matlab
function setupDrag(fig, ax, marker)
    fig.WindowButtonDownFcn = @startDrag;

    function startDrag(~, ~)
        fig.WindowButtonMotionFcn = @doDrag;
        fig.WindowButtonUpFcn = @endDrag;
    end

    function doDrag(~, ~)
        pt = ax.CurrentPoint;
        marker.XData = pt(1,1);
        marker.YData = pt(1,2);
    end

    function endDrag(~, ~)
        fig.WindowButtonMotionFcn = '';
        fig.WindowButtonUpFcn = '';
    end
end
```

## HitTest and PickableParts

```matlab
p.HitTest = 'off';         % clicks pass through to object below
p.PickableParts = 'none';  % never picks up clicks
```

## Controlling Built-In Interactions

```matlab
% Default set
ax.Interactions = [zoomInteraction rulerPanInteraction dataTipInteraction];

% 3D rotation
ax.Interactions = [rotateInteraction dataTipInteraction];

% Zoom only
ax.Interactions = zoomInteraction;

% Disable all
disableDefaultInteractivity(ax);
```

**Fine-grained options:**
```matlab
ax.InteractionOptions.PanSupported = "off";
ax.InteractionOptions.LimitsDimensions = "x";       % zoom x-axis only
```

**Toolbar:**
```matlab
ax.Toolbar.Visible = 'off';   % hide toolbar
ax.Toolbar = [];               % remove entirely (performance boost)
```

## Enable, Disable, and Customize Built-In Interactions

- The following callbacks can cause MATLAB to disable built-in axes interactions:

  - `WindowButtonDownFcn`
  - `WindowButtonMotionFcn`
  - `WindowButtonUpFcn`
  - `WindowScrollWheelFcn`
  - `ButtonDownFcn`

- Use `ax.InteractionOptions` to customize supported interaction behavior, such as disabling pan or limiting zoom to specific dimensions.
- Use `disableDefaultInteractivity(ax)` / `enableDefaultInteractivity(ax)` to disable or enable the built-in interaction set as a whole.

----

Copyright 2026 The MathWorks, Inc.

----
