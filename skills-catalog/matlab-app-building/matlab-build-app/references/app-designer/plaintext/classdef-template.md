# MATLAB Classdef Template

## Minimal App (no callbacks)

```matlab
classdef AppName < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './AppName.xml';
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = AppName(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end
```

## Full App with Callbacks and Custom Properties

```matlab
classdef AppName < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './AppName.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        MainGrid                        matlab.ui.container.GridLayout
        DisplayPanel                    matlab.ui.container.Panel
        MainAxes                        matlab.ui.control.UIAxes
        ControlPanel                    matlab.ui.container.Panel
        StatusLabel                     matlab.ui.control.Label
        RunButton                       matlab.ui.control.Button
        InputEditField                  matlab.ui.control.EditField
        InputEditFieldLabel             matlab.ui.control.Label
    end

    % Custom app data
    properties (Access = private)
        Data
        IsProcessing = false
    end

    % Helper methods
    methods (Access = private)

        function updateDisplay(app)
            plot(app.MainAxes, app.Data);
            app.StatusLabel.Text = sprintf('Showing %d points', numel(app.Data));
        end
    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            app.Data = [];
            app.StatusLabel.Text = 'Ready';
        end

        % Button pushed function: RunButton
        function RunButtonPushed(app, event)
            app.IsProcessing = true;
            app.StatusLabel.Text = 'Processing...';
            app.Data = randn(1, 100);
            updateDisplay(app);
            app.IsProcessing = false;
        end

        % Value changed function: InputEditField
        function InputEditFieldValueChanged(app, event)
            value = app.InputEditField.Value;
            % Process the input
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = AppName(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end
```

## Invalid app
### Does not inherit from `matlab.apps.App`
### Does not include comment after AppConfigFilename (% File path to the app configuration file containing component layout and settings)
### Custom code (lifecycle hook) added to constructor
### Custom properties block after custom methods block
### Custom methods block after callbacks methods block

```matlab
classdef AppName < handle

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './AppName.xml';
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        RunButton                       matlab.ui.control.Button
    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            app.IsProcessing = false;
        end

        % Button pushed function: RunButton
        function RunButtonPushed(app, event)
            updateDisplay(app);
        end
    end

    % Helper methods (INVALID: must appear before callbacks block)
    methods (Access = private)

        function updateDisplay(app)
            app.IsProcessing = true;
        end
    end

    % Custom app data (INVALID: must appear before custom methods and callbacks)
    properties (Access = private)
        IsProcessing = false
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = AppName(varargin)
            app = app@matlab.apps.App(varargin{:});

            % INVALID: custom lifecycle code added to constructor
            addlistener(app.UIFigure, 'ObjectBeingDestroyed', @(src, evt) onAppClosing(app));

            if nargout == 0
                clear app
            end
        end
    end
end
```

## Structure Rules

App Designer enforces a strict block ordering. **All user-added code (custom properties and methods) MUST appear between the component properties block and the callbacks block.** Any custom code placed after the callbacks block is removed with a warning by App Designer.

```
1. properties (Access = public, Constant)  — AppConfigFilename
2. properties (Access = public)            — component properties
3. [custom properties blocks]              — user-added (any access level)
4. [custom methods blocks]                 — user-added helpers (any access level), including app lifecycle-related methods (e.g., delete(app)) 
5. methods                                 — callbacks (App Designer-managed)
6. methods (Access = public)               — constructor (always last)
```

### Block details - MUST be in this order

1. **Class declaration**: Always `classdef AppName < matlab.apps.App`

2. **AppConfigFilename** (required, first properties block):
   ```matlab
   properties (Access = public, Constant)
       AppConfigFilename = './AppName.xml'; % File path to the app configuration file containing component layout and settings
   end
   ```

3. **Component properties** (required, declares all UI components):
   ```matlab
   properties (Access = public)
       ComponentName                   matlab.ui.package.ClassName
   end
   ```
   - Align type annotations at column 40
   - List ALL components that appear in the XML (by their `name` attribute)
   - Use fully-qualified MATLAB type
   - **Ordering**: Use reverse depth-first traversal of the XML component tree (see below)

4. **Custom properties** (optional, MUST come after Component properties AND before Callback methods):
   ```matlab
   properties (Access = private)
       PropertyName = defaultValue
   end
   ```

5. **Custom methods** (optional, MUST come after Component properties AND before Callback methods):
   ```matlab
   methods (Access = private)
       function result = helperMethod(app, input)
       end
   end
   ```
   Put ALL helper/utility/lifecycle methods here — never after the callbacks.
   Use multiple methods blocks when different attributes are required (e.g., `Access = private`, `Access = public`)

6. **Callback methods** (optional, default access, MUST come before constructor):
   ```matlab
   methods
       % Code that executes after component creation
       function startupFcn(app)
       end

       % Button pushed function: ButtonName
       function CallbackName(app, event)
       end
   end
   ```

7. **Constructor** (required, always last methods block. DO NOT add additional code here):
   ```matlab
   methods (Access = public)
       function app = AppName(varargin)
           app = app@matlab.apps.App(varargin{:});
           if nargout == 0
               clear app
           end
       end
   end
   ```

## Component Property Ordering

Component properties must be ordered by **reverse depth-first traversal** of the XML component tree:

1. Start with `UIFigure`
2. Process its immediate `<Children>` in **reverse XML order**
3. For each child that is a container, immediately recurse into it (also processing its children in reverse XML order) before moving to the next sibling

### Worked example

Given this XML tree:
```xml
<UIFigure name='UIFigure'>
    <Children>
        <GridLayout name='MainGrid'>
            <Children>
                <Panel name='ControlPanel'>
                    <Children>
                        <Button name='RunButton'/>
                        <Label name='StatusLabel'/>
                    </Children>
                </Panel>
                <Panel name='DisplayPanel'>
                    <Children>
                        <UIAxes name='MainAxes'/>
                    </Children>
                </Panel>
            </Children>
        </GridLayout>
    </Children>
</UIFigure>
```

The classdef property order is:
```matlab
UIFigure            % root
MainGrid            % only child of UIFigure
DisplayPanel        % last child of MainGrid (reverse order)
MainAxes            % child of DisplayPanel
ControlPanel        % first child of MainGrid (reverse order)
StatusLabel         % last child of ControlPanel (reverse order)
RunButton           % first child of ControlPanel (reverse order)
```

## Callback Naming Conventions

| Component Type | Callback Property | Typical Name |
|---------------|------------------|--------------|
| Button | `ButtonPushedFcn` | `ButtonNamePushed` |
| EditField | `ValueChangedFcn` | `EditFieldNameValueChanged` |
| EditField | `ValueChangingFcn` | `EditFieldNameValueChanging` |
| DropDown | `ValueChangedFcn` | `DropDownNameValueChanged` |
| CheckBox | `ValueChangedFcn` | `CheckBoxNameValueChanged` |
| Switch | `ValueChangedFcn` | `SwitchNameValueChanged` |
| Slider | `ValueChangedFcn` | `SliderNameValueChanged` |
| Slider | `ValueChangingFcn` | `SliderNameValueChanging` |
| Spinner | `ValueChangedFcn` | `SpinnerNameValueChanged` |
| Table | `CellSelectionCallback` | `UITableCellSelection` |
| TabGroup | `SelectionChangedFcn` | `TabGroupSelectionChanged` |
| UIFigure | `SizeChangedFcn` | `updateAppLayout` |
| StartupFcn | `StartupFcn` | `startupFcn` |

## MATLAB UI Type Quick Reference

| XML Element | MATLAB Type |
|-------------|-------------|
| UIFigure | `matlab.ui.Figure` |
| Panel | `matlab.ui.container.Panel` |
| GridLayout | `matlab.ui.container.GridLayout` |
| TabGroup | `matlab.ui.container.TabGroup` |
| Tab | `matlab.ui.container.Tab` |
| ButtonGroup | `matlab.ui.container.ButtonGroup` |
| Tree | `matlab.ui.container.Tree` |
| CheckBoxTree | `matlab.ui.container.CheckBoxTree` |
| TreeNode | `matlab.ui.container.TreeNode` |
| Menu | `matlab.ui.container.Menu` |
| ContextMenu | `matlab.ui.container.ContextMenu` |
| Toolbar | `matlab.ui.container.Toolbar` |
| Button | `matlab.ui.control.Button` |
| StateButton | `matlab.ui.control.StateButton` |
| Label | `matlab.ui.control.Label` |
| EditField | `matlab.ui.control.EditField` |
| NumericEditField | `matlab.ui.control.NumericEditField` |
| DropDown | `matlab.ui.control.DropDown` |
| CheckBox | `matlab.ui.control.CheckBox` |
| RadioButton | `matlab.ui.control.RadioButton` |
| Switch | `matlab.ui.control.Switch` |
| Slider | `matlab.ui.control.Slider` |
| Spinner | `matlab.ui.control.Spinner` |
| TextArea | `matlab.ui.control.TextArea` |
| Table | `matlab.ui.control.Table` |
| UIAxes | `matlab.ui.control.UIAxes` |
| Gauge | `matlab.ui.control.Gauge` |
| ColorPicker | `matlab.ui.control.ColorPicker` |
| PushTool | `matlab.ui.control.PushTool` |
| ToggleTool | `matlab.ui.control.ToggleTool` |

----

Copyright 2026 The MathWorks, Inc.

----
