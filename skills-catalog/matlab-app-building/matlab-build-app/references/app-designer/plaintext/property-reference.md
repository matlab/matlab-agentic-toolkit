# Component Property Reference

Properties listed here are validated by the XSD schema. Only serialize non-default values.

---

## UIFigure (`matlab.ui.Figure`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Name` | `'string'` | `''` |
| `Position` | `[left bottom width height]` | system dependent |
| `Color` | RGB triplet, hex, named color | system dependent |
| `WindowStyle` | `'normal'`, `'modal'`, `'alwaysontop'` | `'normal'` |
| `WindowState` | `'normal'`, `'minimized'`, `'maximized'`, `'fullscreen'` | `'normal'` |
| `Resize` | `'on'`, `'off'` | `'on'` |
| `AutoResizeChildren` | `'on'`, `'off'` | `'on'` |
| `Scrollable` | `'on'`, `'off'` | `'off'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Icon` | file path or image array | `''` |
| `Pointer` | `'arrow'`, `'ibeam'`, `'crosshair'`, `'watch'`, `'custom'`, etc. | `'arrow'` |
| `Colormap` | m-by-3 RGB array | parula |
| `CloseRequestFcn` | callback | `'closereq'` |
| `KeyPressFcn` | callback | `''` |
| `KeyReleaseFcn` | callback | `''` |
| `SizeChangedFcn` | callback | `''` |
| `WindowButtonDownFcn` | callback | `''` |
| `WindowButtonMotionFcn` | callback | `''` |
| `WindowButtonUpFcn` | callback | `''` |
| `WindowKeyPressFcn` | callback | `''` |
| `WindowKeyReleaseFcn` | callback | `''` |
| `WindowScrollWheelFcn` | callback | `''` |
| `HandleVisibility` | `'on'`, `'callback'`, `'off'` | `'off'` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## GridLayout (`matlab.ui.container.GridLayout`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `ColumnWidth` | cell array (`'1x'`, `'2x'`, `'fit'`, pixels) | `{'1x','1x'}` |
| `RowHeight` | cell array (`'1x'`, `'2x'`, `'fit'`, pixels) | `{'1x','1x'}` |
| `ColumnSpacing` | number (pixels) | `10` |
| `RowSpacing` | number (pixels) | `10` |
| `Padding` | `[left bottom right top]` | `[10 10 10 10]` |
| `BackgroundColor` | RGB triplet, hex, named color | container default |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Scrollable` | `'on'`, `'off'` | `'off'` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Panel (`matlab.ui.container.Panel`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Title` | `'string'` | `""` |
| `TitlePosition` | `'lefttop'`, `'centertop'`, `'righttop'` | `'lefttop'` |
| `ForegroundColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `BorderType` | `'line'`, `'none'` | `'line'` |
| `BorderWidth` | positive integer | `1` |
| `BorderColor` | RGB triplet, hex, named color | system dependent |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Scrollable` | `'on'`, `'off'` | `'off'` |
| `AutoResizeChildren` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `SizeChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## TabGroup (`matlab.ui.container.TabGroup`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `TabLocation` | `'top'`, `'bottom'`, `'left'`, `'right'` | `'top'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `AutoResizeChildren` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `SelectionChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Tab (`matlab.ui.container.Tab`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Title` | `'string'` | `""` |
| `ForegroundColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Scrollable` | `'on'`, `'off'` | `'off'` |
| `AutoResizeChildren` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## ButtonGroup (`matlab.ui.container.ButtonGroup`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Title` | `'string'` | `""` |
| `TitlePosition` | `'lefttop'`, `'centertop'`, `'righttop'` | `'lefttop'` |
| `ForegroundColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `BorderType` | `'line'`, `'none'` | `'line'` |
| `BorderWidth` | positive integer | `1` |
| `BorderColor` | RGB triplet, hex, named color | system dependent |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Scrollable` | `'on'`, `'off'` | `'off'` |
| `AutoResizeChildren` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `SelectionChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Tree (`matlab.ui.container.Tree`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Multiselect` | `'on'`, `'off'` | `'off'` |
| `Editable` | `'on'`, `'off'` | `'off'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `SelectionChangedFcn` | callback | `''` |
| `NodeExpandedFcn` | callback | `''` |
| `NodeCollapsedFcn` | callback | `''` |
| `NodeTextChangedFcn` | callback | `''` |
| `ClickedFcn` | callback | `''` |
| `DoubleClickedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## CheckBoxTree (`matlab.ui.container.CheckBoxTree`)

Same properties as Tree, plus:

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `CheckedNodesChangedFcn` | callback | `''` |

---

## TreeNode (`matlab.ui.container.TreeNode`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Text` | `'string'` | `'Tree Node'` |
| `NodeData` | any | `[]` |
| `Icon` | file path or image array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Button (`matlab.ui.control.Button`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Text` | `'string'` or cell array | `'Button'` |
| `Interpreter` | `'none'`, `'tex'`, `'latex'`, `'html'` | `'none'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `Icon` | file path, image array, or predefined | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'center'` |
| `VerticalAlignment` | `'top'`, `'center'`, `'bottom'` | `'center'` |
| `IconAlignment` | `'left'`, `'right'`, `'center'`, `'leftmargin'`, `'rightmargin'`, `'top'`, `'bottom'` | `'left'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ButtonPushedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## StateButton (`matlab.ui.control.StateButton`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | `true`, `false` (0 or 1) | `false` |
| `Text` | `'string'` or cell array | `'State Button'` |
| `Interpreter` | `'none'`, `'tex'`, `'latex'`, `'html'` | `'none'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `Icon` | file path or predefined | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'center'` |
| `VerticalAlignment` | `'top'`, `'center'`, `'bottom'` | `'center'` |
| `IconAlignment` | `'left'`, `'right'`, `'center'`, `'leftmargin'`, `'rightmargin'`, `'top'`, `'bottom'` | `'left'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## ToggleButton (`matlab.ui.control.ToggleButton`)

Only valid inside a ButtonGroup.

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | 0 or 1 | 1 (first), 0 (subsequent) |
| `Text` | `'string'` or cell array | `'Toggle Button'` |
| `Interpreter` | `'none'`, `'tex'`, `'latex'`, `'html'` | `'none'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `Icon` | file path or predefined | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'center'` |
| `VerticalAlignment` | `'top'`, `'center'`, `'bottom'` | `'center'` |
| `IconAlignment` | `'left'`, `'right'`, `'center'`, `'leftmargin'`, `'rightmargin'`, `'top'`, `'bottom'` | `'left'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Label (`matlab.ui.control.Label`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Text` | `'string'` or cell array | `'Label'` |
| `Interpreter` | `'none'`, `'tex'`, `'latex'`, `'html'` | `'none'` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'left'` |
| `VerticalAlignment` | `'top'`, `'center'`, `'bottom'` | `'center'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color, `'none'` | `'none'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## EditField (`matlab.ui.control.EditField`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | `'string'` | `''` |
| `CharacterLimits` | two-element numeric array | `[0 Inf]` |
| `InputType` | `'text'`, `'letters'`, `'digits'`, `'alphanumerics'` | `'text'` |
| `Placeholder` | `'string'` | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'left'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Editable` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ValueChangingFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## NumericEditField (`matlab.ui.control.NumericEditField`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[-Inf Inf]` |
| `LowerLimitInclusive` | `'on'`, `'off'` | `'on'` |
| `UpperLimitInclusive` | `'on'`, `'off'` | `'on'` |
| `RoundFractionalValues` | `'on'`, `'off'` | `'off'` |
| `ValueDisplayFormat` | printf format string | `'%11.4g'` |
| `AllowEmpty` | `'on'`, `'off'` | `'off'` |
| `Placeholder` | `'string'` | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'right'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Editable` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## TextArea (`matlab.ui.control.TextArea`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | cell array or string array | `{''}` |
| `Placeholder` | `'string'` | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'left'` |
| `WordWrap` | `'on'`, `'off'` | `'on'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Editable` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ValueChangingFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## DropDown (`matlab.ui.control.DropDown`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | element of Items or ItemsData | first element |
| `Items` | cell array or string array | `{'Option 1','Option 2','Option 3','Option 4'}` |
| `ItemsData` | numeric array or cell array | `[]` |
| `ValueIndex` | positive integer | `1` |
| `Placeholder` | `'string'` | `''` |
| `Editable` | `'on'`, `'off'` | `'off'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `DropDownOpeningFcn` | callback | `''` |
| `ClickedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## ListBox (`matlab.ui.control.ListBox`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | element of Items/ItemsData or cell | first element |
| `Items` | cell array or string array | `{'Item 1','Item 2','Item 3','Item 4'}` |
| `ItemsData` | numeric array or cell array | `[]` |
| `ValueIndex` | positive integer | `1` |
| `Multiselect` | `'on'`, `'off'` | `'off'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ClickedFcn` | callback | `''` |
| `DoubleClickedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## CheckBox (`matlab.ui.control.CheckBox`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | `true`, `false` (0 or 1) | `false` |
| `Text` | `'string'` or cell array | `'Check Box'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## RadioButton (`matlab.ui.control.RadioButton`)

Only valid inside a ButtonGroup.

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | 0 or 1 | 1 (first), 0 (subsequent) |
| `Text` | `'string'` or cell array | `'Radio Button'` |
| `Interpreter` | `'none'`, `'tex'`, `'latex'`, `'html'` | `'none'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Slider (`matlab.ui.control.Slider`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[0 100]` |
| `Orientation` | `'horizontal'`, `'vertical'` | `'horizontal'` |
| `Step` | positive number | `0.1` |
| `StepMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTicks` | numeric vector or `[]` | `[0 20 40 60 80 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','20','40','60','80','100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ValueChangingFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## RangeSlider (`matlab.ui.control.RangeSlider`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | two-element numeric array | `[0 100]` |
| `Limits` | `[min max]` | `[0 100]` |
| `Orientation` | `'horizontal'`, `'vertical'` | `'horizontal'` |
| `Step` | positive number | `0.1` |
| `StepMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTicks` | numeric vector or `[]` | `[0 20 40 60 80 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','20','40','60','80','100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ValueChangingFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Spinner (`matlab.ui.control.Spinner`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[-Inf Inf]` |
| `Step` | positive number | `1` |
| `LowerLimitInclusive` | `'on'`, `'off'` | `'on'` |
| `UpperLimitInclusive` | `'on'`, `'off'` | `'on'` |
| `RoundFractionalValues` | `'on'`, `'off'` | `'off'` |
| `ValueDisplayFormat` | printf format string | `'%11.4g'` |
| `AllowEmpty` | `'on'`, `'off'` | `'off'` |
| `Placeholder` | `'string'` | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'right'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Editable` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ValueChangingFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Switch (`matlab.ui.control.Switch`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | element of Items or ItemsData | first element |
| `Items` | 1-by-2 cell/string array | `{'Off','On'}` |
| `ItemsData` | 1-by-2 numeric or cell array | `[]` |
| `ValueIndex` | positive integer | `1` |
| `Orientation` | `'horizontal'`, `'vertical'` | `'horizontal'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## ToggleSwitch (`matlab.ui.control.ToggleSwitch`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | element of Items or ItemsData | first element |
| `Items` | 1-by-2 cell/string array | `{'Off','On'}` |
| `ItemsData` | 1-by-2 numeric or cell array | `[]` |
| `ValueIndex` | positive integer | `1` |
| `Orientation` | `'horizontal'`, `'vertical'` | `'vertical'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## RockerSwitch (`matlab.ui.control.RockerSwitch`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | element of Items or ItemsData | first element |
| `Items` | 1-by-2 cell/string array | `{'Off','On'}` |
| `ItemsData` | 1-by-2 numeric or cell array | `[]` |
| `ValueIndex` | positive integer | `1` |
| `Orientation` | `'horizontal'`, `'vertical'` | `'vertical'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Table (`matlab.ui.control.Table`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Data` | table, numeric, logical, cell, or string array | empty |
| `ColumnName` | `'numbered'`, cell array, string array, `{}` | `'numbered'` |
| `ColumnWidth` | `'auto'`, `'fit'`, `'1x'`, cell array | `'auto'` |
| `ColumnEditable` | logical array or scalar | `[]` |
| `ColumnSortable` | logical array or scalar | `[]` |
| `ColumnRearrangeable` | `'on'`, `'off'` | `'off'` |
| `ColumnFormat` | cell array of format strings | `{}` |
| `RowName` | `'numbered'`, cell array, string array, `{}` | `'numbered'` |
| `RowStriping` | `'on'`, `'off'` | `'on'` |
| `SelectionType` | `'cell'`, `'row'`, `'column'` | `'cell'` |
| `Multiselect` | `'on'`, `'off'` | `'on'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `ForegroundColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB matrix (n-by-3) | `[1 1 1; 0.94 0.94 0.94]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'`, `'inactive'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `CellEditCallback` | callback | `''` |
| `CellSelectionCallback` | callback | `''` |
| `SelectionChangedFcn` | callback | `''` |
| `DisplayDataChangedFcn` | callback | `''` |
| `ClickedFcn` | callback | `''` |
| `DoubleClickedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## UIAxes (`matlab.ui.control.UIAxes`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `BackgroundColor` | RGB triplet, hex, named color | `[1 1 1]` |
| `XLabel` | nested `<String>'text'</String>` | `''` |
| `YLabel` | nested `<String>'text'</String>` | `''` |
| `ZLabel` | nested `<String>'text'</String>` | `''` |
| `Title` | nested `<String>'text'</String>` | `''` |
| `XLim` | `[min max]` | auto |
| `YLim` | `[min max]` | auto |
| `ZLim` | `[min max]` | auto |
| `XScale` | `'linear'`, `'log'` | `'linear'` |
| `YScale` | `'linear'`, `'log'` | `'linear'` |
| `ZScale` | `'linear'`, `'log'` | `'linear'` |
| `XDir` | `'normal'`, `'reverse'` | `'normal'` |
| `YDir` | `'normal'`, `'reverse'` | `'normal'` |
| `ZDir` | `'normal'`, `'reverse'` | `'normal'` |
| `XGrid` | `'on'`, `'off'` | `'off'` |
| `YGrid` | `'on'`, `'off'` | `'off'` |
| `ZGrid` | `'on'`, `'off'` | `'off'` |
| `XTick` | numeric vector | auto |
| `YTick` | numeric vector | auto |
| `XTickLabel` | cell array | auto |
| `YTickLabel` | cell array | auto |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | `10` |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `Box` | `'on'`, `'off'` | `'on'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

**UIAxes sub-properties** use nested elements:
```xml
<UIAxes name='MainAxes'>
    <XLabel>
        <String>'X Data'</String>
    </XLabel>
    <YLabel>
        <String>'Y Data'</String>
    </YLabel>
</UIAxes>
```

---

## Gauge (`matlab.ui.control.Gauge`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[0 100]` |
| `ScaleDirection` | `'clockwise'`, `'counterclockwise'` | `'clockwise'` |
| `ScaleColors` | string/cell array of colors | `[]` |
| `ScaleColorLimits` | n-by-2 numeric array | `[]` |
| `MajorTicks` | numeric vector or `[]` | `[0 20 40 60 80 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','20','40','60','80','100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## SemicircularGauge (`matlab.ui.control.SemicircularGauge`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[0 100]` |
| `Orientation` | `'north'`, `'south'`, `'east'`, `'west'` | `'north'` |
| `ScaleDirection` | `'clockwise'`, `'counterclockwise'` | `'clockwise'` |
| `ScaleColors` | string/cell array of colors | `[]` |
| `ScaleColorLimits` | n-by-2 numeric array | `[]` |
| `MajorTicks` | numeric vector or `[]` | `[0 20 40 60 80 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','20','40','60','80','100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## NinetyDegreeGauge (`matlab.ui.control.NinetyDegreeGauge`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[0 100]` |
| `Orientation` | `'northwest'`, `'northeast'`, `'southwest'`, `'southeast'` | `'northwest'` |
| `ScaleDirection` | `'clockwise'`, `'counterclockwise'` | `'clockwise'` |
| `ScaleColors` | string/cell array of colors | `[]` |
| `ScaleColorLimits` | n-by-2 numeric array | `[]` |
| `MajorTicks` | numeric vector or `[]` | `[0 25 50 75 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','25','50','75','100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## LinearGauge (`matlab.ui.control.LinearGauge`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[0 100]` |
| `Orientation` | `'horizontal'`, `'vertical'` | `'horizontal'` |
| `ScaleColors` | string/cell array of colors | `[]` |
| `ScaleColorLimits` | n-by-2 numeric array | `[]` |
| `MajorTicks` | numeric vector or `[]` | `[0 20 40 60 80 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','20','40','60','80','100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Knob (`matlab.ui.control.Knob`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | numeric | `0` |
| `Limits` | `[min max]` | `[0 100]` |
| `MajorTicks` | numeric vector or `[]` | `[0 10 20 ... 100]` |
| `MajorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `MajorTickLabels` | cell array or string array | `{'0','10','20',...,'100'}` |
| `MajorTickLabelsMode` | `'auto'`, `'manual'` | `'auto'` |
| `MinorTicks` | numeric vector or `[]` | auto-generated |
| `MinorTicksMode` | `'auto'`, `'manual'` | `'auto'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `ValueChangingFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## DiscreteKnob (`matlab.ui.control.DiscreteKnob`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | element of Items or ItemsData | first element |
| `Items` | cell array or string array | `{'Off','Low','Medium','High'}` |
| `ItemsData` | numeric or cell array | `[]` |
| `ValueIndex` | positive integer | `1` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Lamp (`matlab.ui.control.Lamp`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Color` | RGB triplet, hex, named color | `[0 1 0]` (green) |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## ColorPicker (`matlab.ui.control.ColorPicker`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | RGB triplet, hex, named color | `[1 0 0]` |
| `Icon` | `''`, `'fill'`, `'line'`, `'text'`, file path, image array | `''` |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## DatePicker (`matlab.ui.control.DatePicker`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Value` | datetime object | `NaT` |
| `Placeholder` | `'string'` | `''` |
| `Limits` | 1-by-2 datetime array | full range |
| `DisplayFormat` | format string | locale dependent |
| `DisabledDates` | datetime array | empty |
| `DisabledDaysOfWeek` | numeric vector [1-7] | `[]` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | system dependent |
| `BackgroundColor` | RGB triplet, hex, named color | system dependent |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Editable` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ValueChangedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Hyperlink (`matlab.ui.control.Hyperlink`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Text` | `'string'` or cell array | `'Hyperlink'` |
| `URL` | `'string'` | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'left'` |
| `VerticalAlignment` | `'top'`, `'center'`, `'bottom'` | `'center'` |
| `WordWrap` | `'on'`, `'off'` | `'off'` |
| `FontName` | font name | system dependent |
| `FontSize` | positive number | system dependent |
| `FontWeight` | `'normal'`, `'bold'` | `'normal'` |
| `FontAngle` | `'normal'`, `'italic'` | `'normal'` |
| `FontColor` | RGB triplet, hex, named color | `[0.1294 0.1294 0.1294]` |
| `VisitedColor` | RGB triplet, hex, named color | purple |
| `BackgroundColor` | RGB triplet, hex, named color, `'none'` | `'none'` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `HyperlinkClickedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Image (`matlab.ui.control.Image`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `ImageSource` | file path, m-by-n-by-3 array, m-by-n array | `''` |
| `HorizontalAlignment` | `'left'`, `'center'`, `'right'` | `'center'` |
| `VerticalAlignment` | `'top'`, `'center'`, `'bottom'` | `'center'` |
| `ScaleMethod` | `'fit'`, `'fill'`, `'none'`, `'scaledown'`, `'scaleup'`, `'stretch'` | `'fit'` |
| `BackgroundColor` | RGB triplet, hex, named color, `'none'` | `'none'` |
| `URL` | `'string'` | `''` |
| `AltText` | `'string'` | `''` |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `ImageClickedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## HTML (`matlab.ui.control.HTML`)

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `HTMLSource` | `'string'` (HTML content or file path) | `''` |
| `Data` | any MATLAB data type | unspecified |
| `Visible` | `'on'`, `'off'` | `'on'` |
| `Tooltip` | string or cell array | `''` |
| `DataChangedFcn` | callback | `''` |
| `HTMLEventReceivedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## ContextMenu (`matlab.ui.container.ContextMenu`)

Declared as a child of `<UIFigure>` (never nested inside another component). Any component that supports a context menu references it by codeName from its own `<ContextMenu>` property — see "Handle-typed property references" below.

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `ContextMenuOpeningFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

Children: `<Menu>` entries (each with its own `<Text>` and `MenuSelectedFcn`).

Example:

```xml
<UIFigure name='UIFigure'>
    <Children>
        <ContextMenu name='MyCtx'>
            <Children>
                <Menu name='CopyItem'>
                    <Text>'Copy'</Text>
                    <MenuSelectedFcn>onCopy</MenuSelectedFcn>
                </Menu>
            </Children>
        </ContextMenu>
        <Button name='MyBtn'>
            <Text>'Right-click me'</Text>
            <ContextMenu>'MyCtx'</ContextMenu>
        </Button>
    </Children>
</UIFigure>
```

---

## Menu (`matlab.ui.container.Menu`)

A menu item — child of a `<ContextMenu>` (for context menus) or of another `<Menu>` (submenu).

| Property | Type/Valid Values | Default |
|----------|-------------------|---------|
| `Text` | `'string'` | `'Menu Item'` |
| `Accelerator` | `'string'` | `''` |
| `Checked` | `'on'`, `'off'` | `'off'` |
| `Enable` | `'on'`, `'off'` | `'on'` |
| `Separator` | `'on'`, `'off'` | `'off'` |
| `Tooltip` | string | `''` |
| `ForegroundColor` | RGB triplet, hex, named color | system dependent |
| `MenuSelectedFcn` | callback | `''` |
| `Tag` | string | `""` |
| `UserData` | any | `[]` |

---

## Handle-typed property references (component -> component)

Some properties hold a *handle to another component*, not a primitive value. `<ContextMenu>` (on any component that supports one) is the canonical case.

**In the XML, reference the target by its `codeName` as a quoted string literal**, exactly like any other string value:

```xml
<Button name='MyBtn'>
    <ContextMenu>'MyCtx'</ContextMenu>
</Button>
```

Rules:

- The quotes are non-negotiable. A bare `<ContextMenu>MyCtx</ContextMenu>` fails the value parse (`PlainTextBackend:unparseableValue`), the same gate a bare `<Text>Go</Text>` would fail.
- The referenced component (`MyCtx` above) must exist elsewhere in the same `<UIFigure>` tree — typically as a `<ContextMenu>` child of the figure. The product loader resolves the codeName to the live component handle at load time.
- Do NOT write a `<Handle>` sub-element, an object literal, or the placeholder text — just the quoted codeName.

The same shape applies to any other handle-typed slot (rare in App Designer, but the rule is uniform).

---

## Layout (Grid Children Only)

Components inside a GridLayout use `<Layout>` with sub-elements. **Do NOT add
`<Layout>` to a component whose parent is UIFigure** (the direct child of the
figure). A stray `<Layout>` on a non-grid child loads without error but renders
a blank canvas.

```xml
<Layout>
    <Column>2</Column>
    <Row>1</Row>
</Layout>
```

For spanning multiple rows/columns: `<Column>[1 3]</Column>` or `<Row>[2 4]</Row>`

---

## Value Formatting Rules

| Type | Format | Example |
|------|--------|---------|
| String | Single-quoted char literal | `'Hello World'` |
| Number | Bare numeric | `42` or `3.14` |
| Boolean | Bare `true` or `false` | `true` |
| Position | Bracketed 4-element array | `[100 100 640 480]` |
| Color (RGB) | Bracketed 3-element array (0-1) | `[0.94 0.94 0.94]` |
| Cell array | Braces with quoted elements | `{'Option A', 'Option B'}` |
| Numeric array | Bracketed space-separated | `[1 2 3 4 5]` |
| On/Off | Single-quoted | `'on'` or `'off'` |
| Callback | Bare function name | `ButtonPushed` |
| Component handle ref | Quoted codeName (same shape as a string) | `'MyCtx'` |

---

## Callback Properties Quick Reference

| Callback Property | Components |
|-------------------|-----------|
| `ButtonPushedFcn` | Button |
| `ValueChangedFcn` | EditField, NumericEditField, DropDown, CheckBox, Switch, ToggleSwitch, RockerSwitch, Slider, RangeSlider, Spinner, Knob, DiscreteKnob, StateButton, ColorPicker, DatePicker, ListBox |
| `ValueChangingFcn` | EditField, TextArea, Slider, RangeSlider, Spinner, Knob |
| `SelectionChangedFcn` | ButtonGroup, TabGroup, Tree, Table |
| `CellEditCallback` | Table |
| `CellSelectionCallback` | Table |
| `ClickedFcn` | DropDown, Table, Tree, ListBox |
| `DoubleClickedFcn` | Table, Tree, ListBox |
| `DropDownOpeningFcn` | DropDown |
| `ImageClickedFcn` | Image |
| `HyperlinkClickedFcn` | Hyperlink |
| `NodeExpandedFcn` | Tree |
| `NodeCollapsedFcn` | Tree |
| `NodeTextChangedFcn` | Tree |
| `DataChangedFcn` | HTML |
| `HTMLEventReceivedFcn` | HTML |
| `SizeChangedFcn` | UIFigure, Panel, TabGroup, Tab, ButtonGroup |
| `KeyPressFcn` | UIFigure, Table |
| `KeyReleaseFcn` | UIFigure, Table |
| `CloseRequestFcn` | UIFigure |
| `WindowButtonDownFcn` | UIFigure |
| `WindowButtonMotionFcn` | UIFigure |
| `WindowButtonUpFcn` | UIFigure |
| `WindowKeyPressFcn` | UIFigure |
| `WindowKeyReleaseFcn` | UIFigure |
| `WindowScrollWheelFcn` | UIFigure |
| `ContextMenuOpeningFcn` | ContextMenu |
| `MenuSelectedFcn` | Menu |

Format in XML: bare function name (no quotes), e.g., `ButtonPushed`

---

## Default Positions (Typical)

| Component | Default Size |
|-----------|-------------|
| Button | `[100 100 100 22]` |
| EditField | `[100 100 100 22]` |
| NumericEditField | `[100 100 100 22]` |
| DropDown | `[100 100 100 22]` |
| ListBox | `[100 100 100 74]` |
| Label | `[100 100 31 22]` |
| CheckBox | `[100 100 84 22]` |
| Slider | `[100 100 150 3]` |
| Spinner | `[100 100 100 22]` |
| TextArea | `[100 100 150 60]` |
| Table | `[100 100 300 200]` |
| UIAxes | `[100 100 400 300]` |
| Image | `[100 100 100 100]` |
| HTML | `[100 100 100 100]` |
| Gauge | `[100 100 120 120]` |
| SemicircularGauge | `[100 100 120 65]` |
| NinetyDegreeGauge | `[100 100 90 90]` |
| LinearGauge | `[100 100 120 40]` |
| Knob | `[100 100 60 60]` |
| DiscreteKnob | `[100 100 60 60]` |
| Lamp | `[100 100 20 20]` |
| Switch | `[100 100 45 20]` |
| ToggleSwitch | `[100 100 20 45]` |
| RockerSwitch | `[100 100 20 45]` |
| ColorPicker | `[100 100 38 22]` |
| DatePicker | `[100 100 150 22]` |
| UIFigure | `[100 100 640 480]` |

----

Copyright 2026 The MathWorks, Inc.

----
