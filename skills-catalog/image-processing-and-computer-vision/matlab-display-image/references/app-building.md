# Image Display App Building

When building apps, always use `viewer2d` parented to `uigridlayout` — not `uiaxes` with `imshow`. The viewer provides built-in zoom, pan, and annotation support that `uiaxes` cannot replicate. Call `imageshow` with the `viewer` as the parent. Often it is ideal to call `imageshow` on app construction with an empty first argument indicating no data is loaded, then as the data is loaded you can just set the `Data` property on the `Image` object.

```matlab
classdef MyApp < handle
    %MyApp Short description of the app.

    properties (Access = private)
        UIFigure     matlab.ui.Figure
        GridLayout   matlab.ui.container.GridLayout
        Viewer       images.ui.graphics.Viewer
        Image        images.ui.graphics.Image
    end

    methods (Access = public)
        function app = MyApp()
            createComponents(app);
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'My App', ...
                'Position', [100 100 640 480]);

            app.GridLayout = uigridlayout(app.UIFigure, [1 1]);
            app.GridLayout.RowHeight = {'fit'};
            app.GridLayout.ColumnWidth = {'fit'};

            app.Viewer = viewer2d(app.GridLayout);
            app.Viewer.Layout.Row = 1;
            app.Viewer.Layout.Column = 1;

            app.Image = imageshow([],Parent=app.Viewer);
        end

        function updateImage(app, im)
            app.Image.Data = im;
        end
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
