# Importing External Color Schemes

See the semantic token vocabulary in `matlab-theming` for the full cross-path guide.

## Material Design Example

```matlab
function theme = createTheme(mode)
    % Material Design Indigo + Pink
    theme.primary    = [0.22 0.29 0.67];  % Indigo 600
    theme.onPrimary  = [1 1 1];
    theme.secondary  = [0.93 0.25 0.48];  % Pink 400
    theme.error      = [0.83 0.18 0.18];  % Red 700
    theme.success    = [0.22 0.56 0.24];  % Green 700
    theme.warning    = [0.96 0.49 0.00];  % Orange 700
    theme.border     = [0.88 0.88 0.88];  % Grey 300
    theme.plotColors = [
        0.22 0.29 0.67   % Indigo 600
        0.93 0.25 0.48   % Pink 400
        0.00 0.59 0.53   % Teal 500
        1.00 0.60 0.00   % Amber 800
        0.38 0.49 0.55   % Blue Grey 500
    ];
    if mode == "dark"
        theme.primary   = fliplightness(theme.primary);
        theme.onPrimary = fliplightness(theme.onPrimary);
        theme.secondary = fliplightness(theme.secondary);
        theme.error     = fliplightness(theme.error);
        theme.success   = fliplightness(theme.success);
        theme.warning   = fliplightness(theme.warning);
        theme.border    = fliplightness(theme.border);
        theme.plotColors = fliplightness(theme.plotColors);
    end
end
```

## Converting Hex to RGB for MATLAB

```matlab
% Manual: divide each pair by 255
% #3949AB -> [0x39/255, 0x49/255, 0xAB/255] = [0.22, 0.29, 0.67]

% Or use sscanf:
hex = '#3949AB';
rgb = sscanf(hex(2:end), '%2x', 3)' / 255;
```

## Import Workflow

1. **Pick a scheme** from Material Design, Adobe Color, Tailwind, etc.
2. **Extract 5-7 key colors**: primary, secondary, error, success, warning, border + 5-7 chart series colors
3. **Convert hex to [R G B]** normalized 0-1 using the formula above
4. **Map to theme struct fields**: `theme.primary`, `theme.secondary`, etc.
5. **Test both modes**: verify `fliplightness()` produces acceptable dark variants; override manually if not
6. **Apply via `applyBrandColors`**: the function reads the struct and sets tagged components

----

Copyright 2026 The MathWorks, Inc.

----
