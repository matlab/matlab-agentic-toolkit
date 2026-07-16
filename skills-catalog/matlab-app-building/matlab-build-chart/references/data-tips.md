# Data Tips

## Customizing Hover Tooltips

Every plot object has a `DataTipTemplate` property:

```matlab
s = scatter(ax, x, y);
s.DataTipTemplate.DataTipRows(1).Label = "Time";
s.DataTipTemplate.DataTipRows(2).Label = "Value";
```

## Adding Custom Rows

```matlab
% From a data array
row = dataTipTextRow("Category", categoryLabels);
s.DataTipTemplate.DataTipRows(end+1) = row;

% From a function (computed per point)
row = dataTipTextRow("Ratio", @(~, evt) sprintf("%.1f%%", evt.Y/evt.X*100));
s.DataTipTemplate.DataTipRows(end+1) = row;

% With format string
row = dataTipTextRow("Price", priceData, '$%,.2f');
```

## Programmatic Data Tips

```matlab
dt = datatip(p, 5, 25);                         % at coordinates
dt = datatip(p, 'DataIndex', 10);                % at 10th data point
dt.Location = 'northeast';                       % tip position
delete(findobj(ax, 'Type', 'datatip'));           % clear all tips
```

----

Copyright 2026 The MathWorks, Inc.

----
