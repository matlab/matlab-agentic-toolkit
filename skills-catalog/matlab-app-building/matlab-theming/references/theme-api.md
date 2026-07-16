# R2025a Theme API

## Lock a Figure to a Theme

```matlab
fig = uifigure(Theme="light");   % Always light, regardless of OS
fig = uifigure(Theme="dark");    % Always dark
fig = uifigure;                  % Follows OS/MATLAB desktop preference (default)
```

## Detect Current Theme

```matlab
baseStyle = fig.Theme.BaseColorStyle;  % Returns "light" or "dark"
```

## React to Theme Changes

```matlab
fig.ThemeChangedFcn = @(src, ~) onThemeChanged(src);

function onThemeChanged(fig)
    if fig.Theme.BaseColorStyle == "light"
        % Apply light brand colors
    else
        % Apply dark brand colors
    end
end
```

## What the Theme API Handles Automatically

When `ColorMode` stays `"auto"` (the default), these adapt to light/dark without any code:
- Figure background
- Panel, tab group, grid layout backgrounds
- Edit field, dropdown, listbox, spinner backgrounds and text
- Label text color
- Axes background, grid lines, tick labels
- Default plot series colors (gem palette for light, glow for dark)

## What Breaks Automatic Theming

Setting any color explicitly switches `ColorMode` to `"manual"`:

```matlab
btn.BackgroundColor = [0.2 0.4 0.8];  % Now manual — won't adapt to theme
btn.BackgroundColorMode = "auto";       % Restore theme control
```

Three ways `ColorMode` becomes `"manual"`:
1. Set the color property: `btn.BackgroundColor = [...]`
2. Set the mode explicitly: `btn.BackgroundColorMode = "manual"`
3. Pass color to a plot call: `plot(x, y, "-red")`

----

Copyright 2026 The MathWorks, Inc.

----
