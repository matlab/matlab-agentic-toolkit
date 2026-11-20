# Place Actors

## Actor Types

These functions add actors to a scenario:

| Type | Function | Notes |
|---|---|---|
| Generic point actor | `actr = actor(scnro, p, Name=name)` | Generic point actor without a 3D model. Useful for representing actors that aren't cars or aircraft, such as towers and sensors. |
| Car | `c = car(scnro, p, Name=name)` | Represented using a 3D model of a sedan. |
| Aircraft | `a = aircraft(scnro, p, Name=name)` | Represented using a 3D model of a narrowbody aircraft. |

`p` is a `pointtable`, a vector of `pose` objects, or a vector of `groundTrajectory` or
`airTrajectory` objects. `Name` is the only name-value argument. Coordinate arrays such as
`actor(scnro, [lat lon ht])` are not supported.

## Specify Positions Using pointtable

These examples show how to specify positions using the `pointtable` function.

```matlab
ptTerrain = pointtable(40.7080, -74.0100);                                      % on the terrain
ptAbove = pointtable(40.7092, -74.0137, 200);                                   % 200 m above the terrain
ptSurface = pointtable(40.7092, -74.0137, HeightReference="surface");           % on the terrain or a roof
ptEllipsoid = pointtable(40.7092, -74.0137, 200, HeightReference="ellipsoid");  % 200 m above the ellipsoid
```

Note that:

- `HeightReference` is a `pointtable` argument, not an actor argument.
- To put an actor on the terrain or a roof, omit the height. A car's wheels or an aircraft's
  gear then rest on the surface. An explicit height places the actor's centroid at that
  height, so a height of `0` sinks a car 0.76 m and an aircraft 2.76 m below the surface.
- A 2D `pointtable(lat, lon)` supports only the `"terrain"` and `"surface"` height
  references. `"ellipsoid"` requires 3D points.

### Height References

The `HeightReference` name-value argument of `pointtable` accepts these values:

| HeightReference | Description |
|---|---|
| `"terrain"` (default) | Height relative to the terrain, ignoring buildings |
| `"surface"` | Height relative to the surface of the scene, which includes terrain and buildings |
| `"ellipsoid"` | Height relative to the WGS84 ellipsoid. Requires 3D points |

When the scene uses terrain (the default, `"gmted2010"`):

- `"terrain"` heights are relative to the terrain, ignoring buildings. `"surface"`
  heights are relative to the surface of the scene, which includes terrain and buildings.
- An ellipsoid height of 0 isn't at the terrain. The ellipsoid height of the terrain
  varies by location.
- To place an actor near the terrain, use `"terrain"` or `"surface"`, not `"ellipsoid"`.
- To get the ellipsoid height of the terrain at a location, see Query Surface Height.

When the scene doesn't use terrain (`Terrain="none"`), terrain heights and ellipsoid
heights are equivalent, and `"surface"` heights include building heights.

### Query Surface Height

To resolve a height against the scene, pass `scnro.Scene` as the fourth argument. The result
is an ellipsoid height:

```matlab
% Get the ellipsoid height of the surface (terrain or roof) at a location
pt = pointtable(lat, lon, 0, scnro.Scene, HeightReference="surface");
roofEllipsoidHeight = pt.Shape.Height;
```

## Place Static and Moving Actors

These examples show how to add static actors, a moving actor, and a rotated actor
to a scenario.

```matlab
scnro = scenario(StopTime=30);

% Add static actors at fixed positions
towerPos = pointtable(40.7092, -74.0137, 200);
actr = actor(scnro, towerPos, Name="Radio Tower");
carPos = pointtable(40.7080, -74.0100);
c = car(scnro, carPos, Name="Patrol Car");

% Add a moving actor by passing a trajectory as its position
waypoints = pointtable([40.70; 40.71], [-74.01; -74.00]);
traj = groundTrajectory(waypoints, GroundSpeed=12);
cMoving = car(scnro, traj, Name="Moving Car");

% Add a rotated static actor by passing a pose with [yaw pitch roll] in degrees
antennaPose = pose([40.7092 -74.0137 200], [90 0 0]);
actrRotated = actor(scnro, antennaPose, Name="Antenna");

% Add several static actors at once by passing a multi-row pointtable
positions = pointtable([40.708; 40.709; 40.710], [-74.010; -74.009; -74.008]);
actrs = actor(scnro, positions, Name=["A","B","C"]);    % 3-by-1 Actor array
```

A multi-row `pointtable` creates one static actor per row. To create one moving actor, build
a trajectory from the points instead.

For the yaw convention, see `pose-and-refframes.md`, Actor Poses.

## Place Actors on Buildings

To place an actor on a building, get the building location from the buildings data.
Don't guess coordinates. When you read buildings from an OpenStreetMap file by using
`readgeotable`, each row includes `Name`, `Centroid` (a `geopointshape` object),
`MinHeight`, and `MaxHeight` variables.

```matlab
% Read and register the buildings
buildings = readgeotable("manhattan.osm", Layer="buildings");
addCustomBuildings("manhattan", buildings, NameExistsRule="preserve");
scnro = scenario(Buildings="manhattan");

% Find the building by name (names can repeat, so take the first match)
idx = find(buildings.Name == "Continental Center", 1);
bldg = buildings(idx, :);
lat = bldg.Centroid.Latitude;
lon = bldg.Centroid.Longitude;

% Place actors on the roof and 10 m above the roof
roofPos = pointtable(lat, lon, HeightReference="surface");
onRoof = actor(scnro, roofPos, Name="Rooftop Antenna");
mastPos = pointtable(lat, lon, 10, HeightReference="surface");
aboveRoof = actor(scnro, mastPos, Name="Mast");
```

To choose the height reference and height for an actor at a building location, use
this table:

| Goal | HeightReference | Height | Note |
|---|---|---|---|
| On the roof | `"surface"` | Omit | An explicit `0` sinks cars and aircraft into the roof |
| Above the roof | `"surface"` | Meters above the roof | Sets the height of the actor's centroid |
| Street level | `"terrain"` | Omit | Inside the building footprint, the actor is inside the building. |

## Modify Actors

After you create a static actor, you can query and change its position and
orientation. These examples show how:

```matlab
% Get the position (heights relative to the terrain)
pt = position(c);

% Move the actor to a new position
newPos = pointtable(40.7085, -74.0105);
position(c, newPos);

% Move the actor 10 m along its forward axis
translate(c, [10 0 0]);

% Add 45 degrees of yaw
rotate(c, 45);

% Get the orientation as [yaw pitch roll] in degrees
p = pose(c);
eul = euler(p);

% Remove an actor from the scenario
remove(actrRotated);
```

Note that:

- These functions work only on static actors. To change an actor that has a trajectory,
  replace its trajectory (see `trajectory-design.md`, Replace a Trajectory).
- You can add, change, or remove actors only before the simulation starts. If the
  simulation has started, call `restart` first (see `simulation-execution.md`, Restart).

----

Copyright 2026 The MathWorks, Inc.

----
