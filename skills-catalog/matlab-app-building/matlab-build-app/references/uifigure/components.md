# Common UI Components

## Controls

| Function | Widget | Key Properties |
|---|---|---|
| `uibutton` | Push button | `Text`, `ButtonPushedFcn`, `Icon` |
| `uislider` | Slider | `Value`, `Limits`, `ValueChangedFcn`, `ValueChangingFcn` |
| `uidropdown` | Dropdown | `Items`, `Value`, `ValueChangedFcn` |
| `uieditfield` | Text input | `Value`, `ValueChangedFcn`, `Placeholder` |
| `uieditfield('numeric')` | Numeric input | `Value`, `Limits`, `ValueChangedFcn` |
| `uicheckbox` | Checkbox | `Value`, `Text`, `ValueChangedFcn` |
| `uiswitch` | Toggle switch | `Value`, `Items`, `ValueChangedFcn` |
| `uispinner` | Numeric spinner | `Value`, `Limits`, `Step`, `ValueChangedFcn` |
| `uitextarea` | Multi-line text | `Value` (cell array of strings) |
| `uilistbox` | List box | `Items`, `Value`, `Multiselect`, `ValueChangedFcn` |

## Display

| Function | Widget | Key Properties |
|---|---|---|
| `uilabel` | Static text | `Text`, `FontWeight`, `HorizontalAlignment` |
| `uiimage` | Image display | `ImageSource`, `ScaleMethod` |
| `uilamp` | Status indicator | `Color` |
| `uigauge` | Circular gauge | `Value`, `Limits` |
| `uiprogressdlg` | Progress dialog | `Value`, `Message`, `Title` |
| `uitable` | Data table | `Data`, `ColumnName`, `ColumnEditable` |
| `uiaxes` | Plot axes | Standard axes properties |

## Creation Pattern

Always create components with the parent as the first argument:

```matlab
% Component belongs to grid
btn = uibutton(gl, 'Text', 'Run');
btn.Layout.Row = 1;
btn.Layout.Column = 1;

% Set properties inline
btn = uibutton(gl, 'push', ...
    'Text', 'Run', ...
    'ButtonPushedFcn', @(src, event) runAnalysis(src));
```

----

Copyright 2026 The MathWorks, Inc.

----
