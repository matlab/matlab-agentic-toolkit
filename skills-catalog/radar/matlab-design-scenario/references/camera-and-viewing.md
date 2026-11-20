# Control the Viewer and Camera

## Create a Viewer

A viewer is a 3D globe display of the scenario. It updates as the simulation advances.

```matlab
vDefault = viewer(scnro);
v = viewer(scnro, Name="My Viewer", Basemap="topographic", CameraMode="manual", AutoUpdate="off");
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `Name` | `"Scenario Viewer"` (default) \| string | Title |
| `Basemap` | `"satellite"` (default) \| other style (see Basemap) | Map imagery |
| `CameraMode` | `"auto"` (default) \| `"manual"` | `"auto"` moves the camera to each new actor until you position the camera yourself (for example, with `campos` or `zoomto`) |
| `AutoUpdate` | `"on"` (default) \| `"off"` | `"off"`: call `update(v)` to refresh visuals; visuals of actors and analyses added later stay hidden until you set their `Visible` to `"on"` |
| `Parent` | `uifigure` \| `uipanel` \| `uitab` | Container, set at creation only. Default: a new `uifigure` |

Several viewers can attach to one scenario.

## Manage Viewers

```matlab
v = gcv(scnro);              % current viewer; creates one if none is open
allViewers = viewers(scnro);
viewer(v);                   % make v current
update(v);                   % refresh when AutoUpdate is "off"
close(v);                    % close all does not close viewers
```

`close(v)` also closes the viewer's default `uifigure`. A container passed as `Parent` stays open.

### Side-by-Side Viewers

```matlab
fig = uifigure;
g = uigridlayout(fig, [1 2]);
vLeft = viewer(scnro, Parent=uipanel(g));
vRight = viewer(scnro, Parent=uipanel(g), Basemap="topographic");
```

## Basemap

Set the basemap at creation or afterward:

```matlab
v = viewer(scnro, Basemap="topographic");
v.Basemap = "streets-dark";
```

Styles: `"satellite"`, `"topographic"`, `"streets"`, `"streets-light"`, `"streets-dark"`,
`"darkwater"`, `"grayland"`, `"bluegreen"`, `"grayterrain"`, `"colorterrain"`,
`"landcover"`, or a basemap added with `addCustomBasemap`. All basemaps except `"darkwater"`
require internet access.

## Get Visuals

Each actor, trajectory, and analysis has one visual per viewer. Use `entity.Visual` with a
single viewer, or `getvisual(v, entity)` to pick the viewer.

```matlab
vis = getvisual(v, losA);    % LOSVisual (rt -> RayTraceVisual, actr.Behavior -> WaypointTrajectoryVisual)
vis.LineWidth = 3;
vis.Visible = "off";

vis = getvisual(v, c);       % ActorVisual
vis.MarkerFaceColor = [0 0.6 1];
vis.OrientationVectors.Visible = "on";   % show the actor's body axes
```

`ActorVisual` properties: `MarkerFaceColor`, `MarkerEdgeColor`, `MarkerSize`, `Alpha`,
`OrientationVectors`, `Visible`. Visuals are empty until a viewer exists. For the other visuals see
`visibility-analysis.md`, `ray-path-analysis.md`, and `trajectory-design.md`.

## Camera

```matlab
campos(v, pointtable(40.6911, -74.0188, 500, HeightReference="ellipsoid"));
camheading(v, 21.3);         % degrees, [-360, 360]
campitch(v, -21.3);          % degrees, [-90, 90]
camroll(v, 0);
pos = campos(v);             % pointtable, ellipsoid heights
heading = camheading(v);
```

`campos` takes a `pointtable` with any height reference, not a coordinate array. It returns
ellipsoid heights.

## Follow an Actor

```matlab
% Default Offset [0 -70.7 70.7]: 70.7 m south of and 70.7 m above the actor, 100 m from it
follow(v, a);
follow(v, a, Offset=[30 10 10]);       % [east north up], meters from the actor
follow(v, "none");                     % stop following
```

`Offset` is in east-north-up axes, not the actor's body axes.

## Zoom and Fly to a Place

```matlab
zoomto(v, "all");            % fit all content
zoomto(v, actr);             % actor, trajectory (actr.Behavior), or analysis
zoomto(v, [actr a]);
zoomto(actr);                % uses the current viewer
```

`zoomto` does not accept placenames. To fly to a place, geocode it and set the camera position:

```matlab
loc = geocode("Times Square, New York", FilterResults="first");   % errors if the place is not found
[latlim, lonlim] = bounds(loc.Shape);                            % works for points and areas
campos(v, pointtable(mean(latlim), mean(lonlim), 1500));
```

Be specific with placenames (for example, `"Shibuya, Tokyo"`). If geocoding fails, use map data
(`readgeotable`) or tell the user the position is approximate.

## Pick Points Interactively

`pickpoints` blocks MATLAB until the user finishes clicking in the viewer. Tell the user in
text output (for example, "Click 3 points in the viewer now") **before** the call. `disp` in the
same evaluation will not show until it returns.

```matlab
[lat3, lon3, ht3] = pickpoints(v, 3);           % ht3 is meters above terrain
[lat, lon, ht] = pickpoints(v);                 % unlimited points: finish with Enter or Escape
```

Always request all three outputs; a single output returns only latitudes. Use the results
directly with `pointtable`:

```matlab
[lat, lon, ~] = pickpoints(v, 1);
c = car(scnro, pointtable(lat, lon), Name="MyCar");

[lat, lon, ht] = pickpoints(v, 4);
traj = groundTrajectory(pointtable(lat, lon), GroundSpeed=10);
```

## Plot Lines and Points

```matlab
data = pointtable([40.70; 40.705; 40.71], [-74.0; -73.995; -74.0], [50; 80; 50]);
linevis = plotline(v, data, Color=[1 0 0], LineWidth=2, LineStyle="--", Marker="o");
pointvis = plotpoints(v, data, MarkerFaceColor=[0 1 0], MarkerSize=10);

linevis.Color = [0 1 0];
linevis.Data = pointtable([40.70; 40.71], [-74.0; -74.01], [10; 10]);
linevis.Visible = "off";
delete(linevis);
```

`LineVisual` properties: `Color`, `LineStyle` (`"-"`, `"--"`, `"none"`), `LineWidth`,
`Marker` (`"none"`, `"o"`), `MarkerSize`, `MarkerFaceColor`, `MarkerEdgeColor`, `Data`, `Visible`.
`PointsVisual` properties: `MarkerFaceColor`, `MarkerEdgeColor`, `LineWidth`, `MarkerSize`,
`Data`, `Visible`. Plotted data uses its own height reference. To plot next to an actor, use the same
height reference as that actor's position or trajectory.

----

Copyright 2026 The MathWorks, Inc.

----
